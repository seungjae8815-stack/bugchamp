import 'dart:async';
import 'dart:math' as math;

import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart' hide Element;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/game_data.dart';
import '../../domain/audio_service.dart';
import '../../domain/combat_power.dart';
import '../../domain/game_server.dart';
import '../../domain/providers.dart';
import '../../domain/pvp_backend.dart';
import '../../domain/save_controller.dart';
import 'package:core_save/core_save.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/ad_gate.dart';
import '../../ui/art.dart';
import '../../ui/jelly_confirm.dart';
import '../../ui/format.dart';
import '../../ui/game_dialog.dart';
import '../../ui/labels.dart';
import '../../ui/skins.dart';
import 'board_preview.dart';
import 'duel_arena_screen.dart';
import 'duel_bug_build.dart';
import 'duel_driver.dart';
import 'league_board_screen.dart';
import 'training_screen.dart';
import '../../ui/toast.dart';
import '../../domain/server_sync.dart';
import '../../ui/colors.dart';

const _honey = kHoney;

/// 결투 티켓 바 — 잔량·다음 충전 카운트다운·충전 버튼(광고/젤리).
///
/// 1초 타이머를 **이 위젯 안에만** 둔다. 결투 화면 전체를 매초 다시 그리면
/// 스카우트 카드·초상까지 같이 리빌드된다.
class TicketBar extends ConsumerStatefulWidget {
  const TicketBar({super.key});

  @override
  ConsumerState<TicketBar> createState() => _TicketBarState();
}

class _TicketBarState extends ConsumerState<TicketBar> {
  Timer? _tick;
  bool _busy = false; // 광고·서버 왕복 중 중복 탭 방지

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _snack(String msg) => showCenterToast(context, msg);

  /// 충전 결과 → 안내 문구. 실패 사유를 삼키지 않는다(왜 안 됐는지 알려준다).
  void _report(AppLocalizations l, TicketCharge r, {required String okMsg}) {
    final cfg = _cfg;
    _snack(switch (r) {
      TicketCharge.ok => okMsg,
      TicketCharge.seasonClosed => l.battleSeasonClosed,
      TicketCharge.adLimit => l.adDailyLimit(cfg.ticketAdDailyLimit),
      TicketCharge.notEnoughJelly => l.notEnoughJelly,
      TicketCharge.refillLimit => l.pvpRefillLimit(cfg.ticketRefillDailyLimit),
      TicketCharge.alreadyFull => l.pvpTicketAlreadyFull,
      TicketCharge.failed => l.pvpTicketChargeFailed,
    });
    if (r == TicketCharge.ok) AudioService.instance.sfxReward();
  }

  BattleConfig get _cfg =>
      ref.read(gameDataProvider).value?.battleConfig ?? const BattleConfig();

  Future<void> _watchAd(AppLocalizations l) async {
    final cfg = _cfg;
    setState(() => _busy = true);
    try {
      // 광고를 끝까지 본 경우에만 지급(하루 상한도 여기서 먼저 확인).
      if (!await watchAdForReward(
        context,
        ref,
        l,
        feature: kAdFeaturePvpTicket,
        dailyLimit: cfg.ticketAdDailyLimit,
      )) {
        return;
      }
      final r = await ref
          .read(saveControllerProvider.notifier)
          .grantAdTickets();
      if (!mounted) return;
      _report(l, r, okMsg: l.pvpTicketCharged(cfg.ticketAdGrant));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refill(AppLocalizations l) async {
    final cfg = _cfg;
    // 젤리를 쓰는 즉시 버튼 — 확인부터(09-30 원칙). 모자라면 확인 창이 상점 안내로 바뀐다.
    if (!await confirmJellySpend(
      context,
      title: l.pvpTicketRefillTitle,
      body: l.pvpTicketRefillBody(
        cfg.ticketRefillAmount,
        cfg.ticketRefillDailyLimit -
            (ref
                    .read(saveControllerProvider)
                    .value
                    ?.adUseCount(
                      kAdFeaturePvpRefill,
                      dailyDateKey(ref.read(clockProvider).now().toUtc()),
                    ) ??
                0),
      ),
      jelly: cfg.ticketRefillJelly,
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final r = await ref
          .read(saveControllerProvider.notifier)
          .refillTicketsWithJelly();
      if (!mounted) return;
      _report(l, r, okMsg: l.pvpTicketFilled);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final save = ref.watch(saveControllerProvider).value;
    if (save == null) return const SizedBox.shrink();
    final ctrl = ref.read(saveControllerProvider.notifier);
    final cfg = _cfg;
    final tickets = ctrl.ticketsNow;
    final left = ctrl.ticketRemaining;
    final today = dailyDateKey(ref.read(clockProvider).now().toUtc());
    final adUsed = save.adUseCount(kAdFeaturePvpTicket, today);
    final empty = tickets <= 0;
    // 정산 기간(일 09시~월 09시)엔 결투를 받지 않는다 — 충전 버튼도 거둔다(2026-10-04 사장님 지적:
    // 무료 충전이 열려 있었다). 서버도 거절하지만, 눌러 보고 실패하는 것보다 처음부터 안 보이는 게 맞다.
    final closed = seasonClosed(ref.read(clockProvider).now().toUtc(), cfg);

    // 한 줄로(2026-09-29) — 결투 탭은 출정 칸·순위표까지 한 화면에 들어가야 한다.
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
        decoration: BoxDecoration(
          color: const Color(0x99000000),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: empty ? const Color(0x66C1502E) : const Color(0x33FFFFFF),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text('⚔️', style: TextStyle(fontSize: 13)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          l.pvpTicketTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        l.pvpTicketCount(tickets, cfg.ticketMax),
                        style: TextStyle(
                          color: empty
                              ? const Color(0xFFE07A5F)
                              : const Color(0xFFBFE3A6),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    left == null
                        ? l.pvpTicketFullLabel
                        : l.pvpTicketNextIn(formatClock(left)),
                    style: const TextStyle(
                      color: Color(0x99FFFFFF),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (closed)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  l.pvpTicketSettling,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Color(0xCCFFFFFF),
                    fontSize: 11.5,
                    height: 1.3,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            if (!closed) ...[
              SizedBox(
                width: 96,
                height: 44,
                child: _chargeBtn(
                  l.pvpTicketAdBtn(cfg.ticketAdGrant),
                  l.pvpTicketAdLeft(adUsed, cfg.ticketAdDailyLimit),
                  const Color(0xFF3E7D4F),
                  () => _watchAd(l),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 96,
                height: 44,
                child: _chargeBtn(
                  cfg.ticketRefillAmount > 0
                      ? l.pvpTicketJellyGive(cfg.ticketRefillAmount)
                      : l.pvpTicketJellyBtn(cfg.ticketRefillJelly),
                  null,
                  const Color(0xFF3F5E86),
                  () => _refill(l),
                  jelly: cfg.ticketRefillAmount > 0
                      ? cfg.ticketRefillJelly
                      : null,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 재화·상한이 모자라도 **버튼은 눌린다** — 비활성 대신 이유를 알려준다
  /// (2026-08 정책). 눌리지 않는 버튼은 왜 안 되는지 알 방법이 없다.
  Widget _chargeBtn(
    String label,
    String? sub,
    Color color,
    Future<void> Function() onTap, {
    int? jelly,
  }) => FilledButton(
    onPressed: _busy ? null : () => onTap(),
    style: FilledButton.styleFrom(
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(vertical: 7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 좁은 폰에서 말줄임 대신 **통째로 축소** — 버튼 라벨이 잘리면
        // 무슨 버튼인지 모른다(부화기 즉시부화와 같은 규칙, 2026-08-20).
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 젤리 가격은 아이콘으로(글자 '젤리'는 다른 재화와 눈으로 안 갈린다).
              if (jelly != null) ...[
                jellyIcon(size: 15),
                const SizedBox(width: 2),
                Text(
                  '$jelly',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        if (sub != null)
          Text(
            sub,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: Color(0xCCFFFFFF),
            ),
          ),
      ],
    ),
  );
}

/// 곤충 결투(PvP). 성충 3마리 팀 vs 상대(실제 다른 유저 방어팀 또는 로컬 합성).
/// 결정론적 simulate 사용. Supabase 연동 시 스카우트 보드가 실 유저 방어팀으로 채워진다.
class BattleScreen extends ConsumerStatefulWidget {
  const BattleScreen({super.key});

  @override
  ConsumerState<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends ConsumerState<BattleScreen> {
  final _rng = math.Random();
  List<String?> _team = [null, null, null];
  bool _initialized = false;

  // 기본 '대등' 티어
  // 전투 모드 토글(수동/자동), 기본 수동(심리전)
  // 실 유저 방어팀 fetch 를 이번 세션에 시도했는지

  String? _registeredSig; // 마지막으로 등록한 방어팀 시그니처(중복 업서트 방지)

  /// 직전 서버 전투 요청이 **티켓 부족**으로 거절됐는지.
  /// 이 경우 낙관 차감분을 되돌리면 안 된다(서버 잔량으로 이미 맞췄다).
  bool _lastRejectedForTickets = false;

  /// 곤충 한 마리의 **결투 전투력** — 상세 창·순위표·서버 편성 검증과 같은 값(훈련소·수련 레벨 포함).
  /// ⚠️ 선택 목록이 `_power(_toBattleBug(...))`(훈련·수련 빠짐)를 쓰던 시절, 목록 384 · 상세 437 처럼
  /// 같은 곤충이 두 숫자로 보였다(2026-10-01 실기 지적). 정렬·자동 편성도 실제 세기와 어긋났다.
  double _bugPower(IndividualBug bug, GameData data, String locale) =>
      _toDuelBug(bug, data, locale).power;

  PvpProfile _me(SaveGame save) => PvpProfile.me(
    save,
    power: displayCombatPower(
      save,
      ref.read(gameDataProvider).value,
      ref.read(clockProvider).now().toUtc(),
    ),
  );

  /// 성충 개체 목록.
  List<IndividualBug> _adults(SaveGame save, GameData data, DateTime now) {
    final cfg = data.petConfig;
    return save.bugs.where((b) {
      final st = cfg == null
          ? b.stage
          : effectiveStage(b.stage, b.stageSince, now, cfg);
      return st == LifeStage.adult;
    }).toList();
  }

  /// 개체 → 전투 유닛. 변환 로직은 `core_battle` 에 있다 —
  /// **서버도 같은 함수를 쓴다**(결과가 어긋나면 승패가 갈린다).
  BattleBug _toBattleBug(IndividualBug bug, GameData data, String locale) =>
      battleBugFor(bug, data, locale);

  /// 내 편성([_team]) → 방어팀 스냅샷(서버 등록용).
  DefenderBug _defenderBugOf(
    IndividualBug bug,
    GameData data,
    SaveGame save,
    String locale,
  ) {
    final bb = _toBattleBug(bug, data, locale);
    return DefenderBug(
      speciesId: bug.speciesId,
      // 내가 산 스킨을 상대 화면에도 보이게 실어 보낸다.
      skin: data.iapConfig?.skinEffectFor(save.ownedSkins, bug.speciesId),
      element: bb.element,
      temperament: bb.temperament,
      maxHp: bb.maxHp,
      atk: bb.atk,
      def: bb.def,
      spd: bb.spd,
    );
  }

  /// 현재 편성을 내 방어팀으로 등록(업서트). 시그니처가 같으면 스킵.
  /// 로컬 백엔드는 no-op — fire-and-forget(에러 무시).
  void _maybeRegisterDefender(GameData data, SaveGame save, String locale) {
    final ids = _team.whereType<String>().toList();
    if (ids.isEmpty) return;
    // ⚠️ 스킨도 시그니처에 넣는다. 안 넣으면 스킨을 사도 편성이 그대로라
    // 재등록이 스킵되어 **산 스킨이 남에게 영영 안 보인다**.
    final sig =
        '${ids.join(',')}|${save.pvpTrophies}|${(save.ownedSkins.toList()..sort()).join(',')}';
    if (sig == _registeredSig) return;
    _registeredSig = sig;
    final team = [
      for (final id in ids)
        _defenderBugOf(
          save.bugs.firstWhere((b) => b.id == id),
          data,
          save,
          locale,
        ),
    ];
    ref.read(pvpBackendProvider).registerDefender(me: _me(save), team: team);
  }

  /// 리그 id → 현지화 라벨·색.
  ///
  /// 엠블럼은 여기서 주지 않는다 — 그리는 곳은 전부 `leagueIcon()`(그림)이고,
  /// 예전에 같이 넘기던 이모지(🥉🥈🥇💠💎)는 아무도 안 쓰는 죽은 값이었다.
  /// 남겨두면 "다이아 리그 = 💎 = 젤리"라는 옛 오해가 다시 살아난다.
  (String, Color) _leagueStyle(AppLocalizations l, String id) => switch (id) {
    'bronze' => (l.leagueBronze, const Color(0xFFB87333)),
    'silver' => (l.leagueSilver, const Color(0xFFB8C4CE)),
    'gold' => (l.leagueGold, kHoney),
    'platinum' => (l.leaguePlatinum, const Color(0xFF5FD3C8)),
    'diamond' => (l.leagueDiamond, const Color(0xFF6FA8FF)),
    _ => (id, const Color(0xFFBFC4CC)),
  };

  /// 출정 칸에 표시할 쉬는 이유 — 부상이 먼저, 그다음 훈련 중. 없으면 null.
  ({bool training, DateTime until})? _restOf(SaveGame save, String bugId) {
    final now = ref.read(clockProvider).now().toUtc();
    if (save.isInjured(bugId, now)) {
      return (training: false, until: save.injuredUntil(bugId)!);
    }
    final job = save.trainingJob;
    if (job != null && job.bugId == bugId && !job.doneAt(now)) {
      return (training: true, until: job.until);
    }
    return null;
  }

  Future<void> _claimLeague(AppLocalizations l) async {
    final r = await ref
        .read(saveControllerProvider.notifier)
        .claimLeagueRewards();
    if (r == null || !mounted) return;
    AudioService.instance.sfxPromote();
    await showGameDialog<void>(
      context,
      title: l.leaguePromoTitle,
      iconWidget: rankImageDlg('promote'),
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          goldIcon(size: 20),
          const SizedBox(width: 5),
          Text(
            formatCompact(r.gold),
            style: const TextStyle(
              color: Color(0xFFEBD24A),
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          // 등급 보상은 골드만이라(2026-09-28) 젤리가 0 이면 줄을 싣지 않는다.
          if (r.jelly > 0) ...[
            const SizedBox(width: 14),
            materialImage(
              MaterialKind.jelly,
              size: 20,
              fallback: const SizedBox(width: 20),
            ),
            const SizedBox(width: 5),
            Text(
              '${r.jelly}',
              style: const TextStyle(
                color: Color(0xFF9BE7FF),
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ],
        ],
      ),
      actions: [gameDialogButton(l.actionClose, () => Navigator.pop(context))],
    );
  }

  Future<void> _showSeasonEnd(SeasonReport r) async {
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    final cfg =
        ref.read(gameDataProvider).requireValue.battleConfig ??
        const BattleConfig();
    final endLabel = _leagueStyle(l, cfg.leagueFor(r.endTrophies).id).$1;
    final hasReward = r.rewardGold > 0 || r.rewardJelly > 0;
    await showGameDialog<void>(
      context,
      title: l.seasonEndTitle,
      iconWidget: rankImageDlg('crown'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            l.seasonPeak(endLabel),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l.seasonTrophyReset(r.fromTrophies, r.toTrophies),
            style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 13),
          ),
          if (hasReward) ...[
            const SizedBox(height: 12),
            Text(
              formatCompact(r.rewardGold),
              style: const TextStyle(
                color: Color(0xFFEBD24A),
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ],
        ],
      ),
      actions: [gameDialogButton(l.actionClose, () => Navigator.pop(context))],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final data = ref.watch(gameDataProvider).requireValue;
    final save = ref.watch(saveControllerProvider).requireValue;
    final now = ref.read(clockProvider).now().toUtc();
    final locale = Localizations.localeOf(context).languageCode;
    final adults = _adults(save, data, now);

    // 최초 진입: 파워 상위 3마리 자동 편성(부상 곤충 제외).
    if (!_initialized) {
      _initialized = true;
      final sorted =
          [
            for (final b in adults)
              if (!save.isInjured(b.id, now)) b,
          ]..sort(
            (a, b) => _bugPower(
              b,
              data,
              locale,
            ).compareTo(_bugPower(a, data, locale)),
          );
      for (var i = 0; i < 3 && i < sorted.length; i++) {
        _team[i] = sorted[i].id;
      }
    }
    // 사라진(진화/분해) · 부상당한 곤충은 편성에서 자동 제외.
    final adultIds = adults.map((b) => b.id).toSet();
    _team = [
      for (final id in _team)
        // 다친 곤충은 **빼지 않는다** — 칸에서 사라지면 왜 없어졌는지 모른다(2026-09-29 실기 지적).
        // 칸에 "회복 중"으로 남기고, 전투 시작 때 막는다.
        (id != null && adultIds.contains(id)) ? id : null,
    ];

    final battleCfg = data.battleConfig ?? const BattleConfig();
    // 현재 편성을 내 방어팀으로 등록(다른 유저가 나를 상대하게).
    _maybeRegisterDefender(data, save, locale);

    // 시즌 종료 정산(로드 시 계산됨) → 1회 다이얼로그.
    final notifier = ref.read(saveControllerProvider.notifier);
    final season = notifier.pendingSeason;
    if (season != null) {
      notifier.consumeSeason();
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showSeasonEnd(season),
      );
    }

    final closed = seasonClosed(now, battleCfg);
    final claimable = battleCfg
        .claimableUpTo(pvpLeagueOf(save, battleCfg), save.claimedLeagues)
        .isNotEmpty;
    final injured = _injuredBugs(save, now).length;

    return Scaffold(
      backgroundColor: const Color(0xFF1C1A12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2417),
        titleSpacing: 12,
        // 지금 리그 · 남은 시간(누르면 리그 보상)이 앱바 전체 — '곤충 결투' 제목은 뺐다
        // (2026-09-30 사장님 요청: 탭 이름과 겹치고, 리그가 더 중요하다).
        title: _LeagueClock(
          league: pvpLeagueNow(save, battleCfg).id,
          cfg: battleCfg,
          onTap: () => _showLeagueRewards(l, data, save, battleCfg),
        ),
      ),
      // 결투장 로비 그림 — 장면은 위쪽 1/3(출정 칸 뒤), 아래는 어두워 순위표 글씨가 읽힌다.
      body: Stack(
        children: [
          Positioned.fill(
            child: gameImageChain(
              ['assets/images/duel/battle_hub_bg.webp'],
              size: 720,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              fallback: const SizedBox.shrink(),
            ),
          ),
          Column(
            children: [
              const TicketBar(),
              // ── 출정 곤충 3칸(순서 = 1·2·3판) ──
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 2, 6, 0),
                child: Row(
                  children: [
                    Text(
                      l.duelSquadTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: adults.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: Text(
                          l.battleNeedBugs,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xB3FFFFFF)),
                        ),
                      )
                    : Row(
                        children: [
                          for (var i = 0; i < 3; i++)
                            Expanded(child: _teamSlot(data, save, locale, i)),
                        ],
                      ),
              ),
              // ── 전투 시작(출정 칸 아래 · 길게) ──
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: _startButton(l, data, save, locale, closed, adults),
              ),
              // ── 회복실 · 훈련소 ──
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
                child: Row(
                  children: [
                    Expanded(
                      child: _facilityButton(
                        art: 'hub_recovery',
                        icon: Icons.healing_rounded,
                        color: const Color(0xFF5FD38D),
                        label: l.recoveryRoom,
                        badge: injured,
                        onTap: () => _openRecovery(data),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _facilityButton(
                        art: 'hub_training',
                        icon: Icons.fitness_center_rounded,
                        color: const Color(0xFFFFA24A),
                        label: l.trainingCenter,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const TrainingScreen(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // ── 리그 순위표(내 줄·전투 시작 버튼은 하단 고정) ──
              Expanded(
                child: LeagueBoardView(
                  key: _boardKey,
                  headerHeight: 42,
                  rewardExtra: claimable
                      ? SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _claimLeague(l);
                            },
                            icon: const Icon(Icons.card_giftcard_rounded),
                            label: Text(l.leagueClaimPromo),
                          ),
                        )
                      : null,
                  showHeader: false,
                  myTeam: _myDuelTeam(data, save, locale),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  final _boardKey = GlobalKey<LeagueBoardViewState>();

  /// 리그 보상 — 지금 리그의 주간 순위 보상(젤리) · 시즌 종료 보상(골드) · 리그별 표 · 승급 보상 받기.
  Future<void> _showLeagueRewards(
    AppLocalizations l,
    GameData data,
    SaveGame save,
    BattleConfig cfg,
  ) {
    final cur = pvpLeagueOf(save, cfg);
    final curId = cfg.leagueAt(cur).id;
    final claimable = cfg.claimableUpTo(cur, save.claimedLeagues).isNotEmpty;
    const head = TextStyle(
      color: _honey,
      fontSize: 12.5,
      fontWeight: FontWeight.w900,
    );
    const cell = TextStyle(
      color: Colors.white,
      fontSize: 12,
      fontWeight: FontWeight.w800,
    );
    Widget jelly(int n) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        jellyIcon(size: 13),
        const SizedBox(width: 2),
        Text(
          '$n',
          style: const TextStyle(
            color: Color(0xFF9BE7FF),
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
    // 내 위치(순위표가 받아 둔 값) — 몇 위 · 승강 구간 · 이대로 끝나면 받는 보상.
    final board = _boardKey.currentState?.data;
    final me = board?['me'] is Map ? board!['me'] as Map : null;
    final myRank = (me?['rank'] as num?)?.toInt();
    final myScore = (me?['trophies'] as num?)?.toInt() ?? 0;
    final total = (board?['total'] as num?)?.toInt() ?? 0;
    final promote = (board?['promote'] as num?)?.toInt() ?? 0;
    final demote = (board?['demote'] as num?)?.toInt() ?? 0;
    // 지금 리그의 순위 구간 표.
    final table = cfg.leagueRankRewards[curId] ?? cfg.seasonRankRewards;
    var myJelly = 0;
    if (myRank != null && myScore > 0) {
      for (final r in table) {
        if (myRank <= r.maxRank) {
          myJelly = r.jelly;
          break;
        }
      }
    }
    final rankRows = <Widget>[];
    var from = 1;
    for (final r in table) {
      if (r.maxRank < from) continue;
      final hit = myRank != null && myRank >= from && myRank <= r.maxRank;
      rankRows.add(
        Container(
          margin: const EdgeInsets.symmetric(vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: hit ? const Color(0x331FA2F5) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  r.maxRank == from
                      ? l.pvpRankN(from)
                      : l.eventRankRange(from, r.maxRank),
                  style: cell,
                ),
              ),
              jelly(r.jelly),
            ],
          ),
        ),
      );
      from = r.maxRank + 1;
    }
    final seasonGold = cfg.seasonRewardAt(cur).gold;
    // 다음 주 리그(승급권·유지·강등권) — 서버 결산과 같은 함수.
    final nextIdx = myRank == null
        ? cur
        : cfg.leagueAfterSeason(
            cur,
            rank: myRank,
            total: total,
            trophies: myScore,
          );
    final zone = nextIdx > cur
        ? l.leagueMyPromote(leagueName(l, cfg.leagueAt(nextIdx).id))
        : nextIdx < cur
        ? l.leagueMyDemote(leagueName(l, cfg.leagueAt(nextIdx).id))
        : l.leagueMyStay;
    final zoneColor = nextIdx > cur
        ? const Color(0xFF6FCF6F)
        : nextIdx < cur
        ? const Color(0xFFEF6B6B)
        : const Color(0xFFE9D9A6);
    final myBox = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0x331FA2F5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1FA2F5)),
      ),
      child: myRank == null
          ? Text(
              l.boardMeNone,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        l.leagueMyNow(myRank, total),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.star_rounded,
                      size: 16,
                      color: Color(0xFFFFC928),
                    ),
                    Text(
                      '$myScore',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  zone,
                  style: TextStyle(
                    color: zoneColor,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (promote > 0 || demote > 0)
                  Text(
                    l.boardZonesHint(promote, demote),
                    style: const TextStyle(
                      color: Color(0x99FFFFFF),
                      fontSize: 10.5,
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  l.leagueMyIfEnds,
                  style: const TextStyle(
                    color: Color(0xCCFFFFFF),
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    jelly(myJelly),
                    const SizedBox(width: 12),
                    goldIcon(size: 14),
                    const SizedBox(width: 3),
                    Text(
                      formatCompact(seasonGold),
                      style: const TextStyle(
                        color: Color(0xFFEBD24A),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
    return showGameDialog<void>(
      context,
      title: l.leagueInfoTitle(leagueName(l, curId)),
      iconWidget: leagueIcon(curId, size: 56),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              myBox,
              Text(
                l.leagueZoneHint,
                style: const TextStyle(
                  color: Color(0xAAFFFFFF),
                  fontSize: 11.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(l.leagueInfoRank, style: head),
              const SizedBox(height: 4),
              ...rankRows,
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: Text(l.leagueInfoSeason, style: head)),
                  goldIcon(size: 14),
                  const SizedBox(width: 3),
                  Text(
                    formatCompact(seasonGold),
                    style: const TextStyle(
                      color: Color(0xFFEBD24A),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(l.leagueInfoAll, style: head),
              const SizedBox(height: 4),
              for (var i = cfg.leagues.length - 1; i >= 0; i--)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: i == cur
                        ? const Color(0x33EBA52F)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: i == cur ? Border.all(color: _honey) : null,
                  ),
                  child: Row(
                    children: [
                      leagueIcon(cfg.leagues[i].id, size: 20),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          i == cur
                              ? '${leagueName(l, cfg.leagues[i].id)} · ${l.leagueInfoCurrent}'
                              : leagueName(l, cfg.leagues[i].id),
                          style: cell,
                        ),
                      ),
                      // 1위 젤리 · 시즌 종료 골드
                      jelly(
                        (cfg.leagueRankRewards[cfg.leagues[i].id] ??
                                    cfg.seasonRankRewards)
                                .isEmpty
                            ? 0
                            : (cfg.leagueRankRewards[cfg.leagues[i].id] ??
                                      cfg.seasonRankRewards)
                                  .first
                                  .jelly,
                      ),
                      const SizedBox(width: 8),
                      goldIcon(size: 12),
                      const SizedBox(width: 2),
                      Text(
                        formatCompact(cfg.seasonRewardAt(i).gold),
                        style: const TextStyle(
                          color: Color(0xFFEBD24A),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                l.leagueInfoAllHint,
                style: const TextStyle(
                  color: Color(0x88FFFFFF),
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (claimable)
          gameDialogButton(l.leagueClaimPromo, () {
            Navigator.pop(context);
            _claimLeague(l);
          }),
        gameDialogButton(
          l.actionClose,
          () => Navigator.pop(context),
          primary: !claimable,
        ),
      ],
    );
  }

  /// 회복실·훈련소 버튼.
  Widget _facilityButton({
    required String art,
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
    int badge = 0,
  }) => Material(
    color: const Color(0xE62A2417),
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            gameImageChain(
              ['assets/images/duel/$art.webp'],
              size: 40,
              fallback: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
            if (badge > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF5350),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$badge',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );

  /// 하단 고정 전투 시작 버튼 — 정산 기간이면 "시즌이 종료되었습니다!".
  /// 전투 시작 — 출정 곤충 제목 줄 오른쪽(2026-09-29 사장님 요청). 정산 기간이면 "시즌 종료".
  Widget _startButton(
    AppLocalizations l,
    GameData data,
    SaveGame save,
    String locale,
    bool closed,
    List<IndividualBug> adults,
  ) {
    if (closed) {
      return Container(
        width: double.infinity,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xB3000000),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          l.battleSeasonClosed,
          style: const TextStyle(
            color: Color(0xFFBDBDBD),
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFEF5350),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: adults.isEmpty || _starting
            ? null
            : () => _startMatch(data, save, locale),
        icon: _starting
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            // 결투 티켓과 같은 표식 — 누르면 티켓 한 장이 나간다는 걸 그림으로.
            : const Text('⚔️', style: TextStyle(fontSize: 18)),
        label: Text(
          l.battleStart,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  bool _starting = false;

  /// 지금 출정 칸의 결투 유닛(빈 칸은 뺀다) — 순위표 내 줄·미리보기 전투력.
  List<DuelBug> _myDuelTeam(GameData data, SaveGame save, String locale) => [
    for (final id in _team.whereType<String>())
      for (final b in save.bugs)
        if (b.id == id) _toDuelBug(b, data, locale),
  ];

  // ── 회복실 ─────────────────────────────────────────────────────────

  /// 아직 회복 중인 내 곤충(보유 중인 것만).
  List<(IndividualBug, DateTime)> _injuredBugs(SaveGame save, DateTime now) => [
    for (final b in save.bugs)
      if (save.injured[b.id] != null && now.isBefore(save.injured[b.id]!))
        (b, save.injured[b.id]!),
  ];

  /// 회복실 — 회복 중인 곤충과 남은 시간, 젤리 즉시 회복.
  void _openRecovery(GameData data) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xF22F333E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final l = AppLocalizations.of(ctx);
          final save = ref.watch(saveControllerProvider).requireValue;
          final now = ref.read(clockProvider).now().toUtc();
          final cfg = data.petConfig;
          final locale = Localizations.localeOf(ctx).languageCode;
          // 먼저 회복할 곤충이 위로(2026-10-01 실기 지적): 출정 칸에 든 곤충 → 등급 → 결투 전투력.
          final list = _injuredBugs(save, now)
            ..sort((a, b) {
              final ta = _team.contains(a.$1.id) ? 0 : 1;
              final tb = _team.contains(b.$1.id) ? 0 : 1;
              if (ta != tb) return ta - tb;
              final g = data
                  .species(b.$1.speciesId)
                  .grade
                  .index
                  .compareTo(data.species(a.$1.speciesId).grade.index);
              if (g != 0) return g;
              return _bugPower(
                b.$1,
                data,
                locale,
              ).compareTo(_bugPower(a.$1, data, locale));
            });
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      gameImageChain(
                        ['assets/images/duel/hub_recovery.webp'],
                        size: 34,
                        fallback: const Icon(
                          Icons.healing_rounded,
                          color: Color(0xFF5FD38D),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        l.recoveryRoom,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l.injuryDesc,
                    style: const TextStyle(
                      color: Color(0xAAFFFFFF),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (list.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          l.recoveryEmpty,
                          style: const TextStyle(color: Color(0xCCFFFFFF)),
                        ),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(ctx).size.height * 0.5,
                      ),
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          for (final (bug, until) in list)
                            _recoveryRow(
                              l,
                              data,
                              locale,
                              bug,
                              until.difference(now),
                              cfg?.injuryJelly(until.difference(now)) ?? 0,
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 젤리로 즉시 회복(확인 후). 회복실 줄 버튼 · 상세 창 공용.
  Future<void> _healWithJelly(IndividualBug bug, int jelly) async {
    final l = AppLocalizations.of(context);
    if (!await confirmJellySpend(
      context,
      title: l.injuryHealConfirmTitle,
      body: l.injuryHealConfirm(jelly),
      jelly: jelly,
    )) {
      return;
    }
    if (!mounted) return;
    final ok = await ref
        .read(saveControllerProvider.notifier)
        .healInjury(bug.id, viaJelly: true);
    if (!ok && mounted) showCenterToast(context, l.notEnoughJelly);
  }

  /// 회복 중인 곤충 상세 — 능력치(출정 칸에서 보는 것과 같은 값) + 즉시 회복.
  Future<void> _showRecoveryDetail(
    GameData data,
    String locale,
    IndividualBug bug,
    int jelly,
  ) async {
    final l = AppLocalizations.of(context);
    final heal = await showGameDialog<bool>(
      context,
      title: l.squadDetailTitle,
      icon: Icons.healing_rounded,
      content: _bugStats(
        l,
        data,
        locale,
        _toDuelBug(bug, data, locale),
        bug: bug,
        skin: bugView(ref.read(skinOfProvider), bug),
      ),
      actions: [
        gameDialogButton(
          l.actionClose,
          () => Navigator.pop(context, false),
          primary: false,
        ),
        gameDialogButton(
          l.injuryHealJelly(jelly),
          () => Navigator.pop(context, true),
        ),
      ],
    );
    if (heal == true && mounted) await _healWithJelly(bug, jelly);
  }

  Widget _recoveryRow(
    AppLocalizations l,
    GameData data,
    String locale,
    IndividualBug bug,
    Duration left,
    int jelly,
  ) {
    final sp = data.species(bug.speciesId);
    final m = left.inMinutes;
    final time = m >= 60
        ? '${m ~/ 60}:${(m % 60).toString().padLeft(2, '0')}'
        : '${m + 1}m';
    final slot = _team.indexOf(bug.id); // 출정 칸(0~2), 없으면 -1
    final grade = gradeColor(sp.grade);
    final stars = List.filled(bug.potential, '★').join();
    return GestureDetector(
      // 누르면 상세(능력치·특성) — 어떤 곤충을 먼저 회복할지 고르게(2026-10-01).
      onTap: () => _showRecoveryDetail(data, locale, bug, jelly),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0x22FFFFFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: slot >= 0 ? _honey : grade.withValues(alpha: 0.6),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: bugStageImage(
                bug.speciesId,
                LifeStage.adult,
                size: 44,
                fallback: bugAvatar(sp, size: 40),
                skin: bugView(ref.read(skinOfProvider), bug),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: grade.withValues(alpha: 0.28),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          gradeLabel(l, sp.grade),
                          style: TextStyle(
                            color: grade,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          sp.name.resolve(locale),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (slot >= 0) ...[
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: _honey,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            l.duelPickDeployed(slot + 1),
                            style: const TextStyle(
                              color: kHoneyInk,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '⚔ ${formatCompact(_bugPower(bug, data, locale).round())}'
                    ' · Lv.${bug.level} · $stars',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFEBD24A),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${l.injuryTitle} · $time',
                    style: const TextStyle(
                      color: Color(0xFFEF9A9A),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2E7DBA),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              onPressed: () => _healWithJelly(bug, jelly),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  jellyIcon(size: 15),
                  const SizedBox(width: 3),
                  Text(
                    '$jelly',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 상대 고르기(후보 5명) ───────────────────────────────────────────

  /// 전투 시작 — 후보 5명을 받아 고르게 하고, 고른 상대와 직접 던지기 결투.
  Future<void> _startMatch(GameData data, SaveGame save, String locale) async {
    final l = AppLocalizations.of(context);
    // 출정 칸이 다 차지 않았으면 가장 센 곤충으로 채우고, 확인하고 다시 누르게 한다.
    if (_team.whereType<String>().length < 3) {
      final now = ref.read(clockProvider).now().toUtc();
      final pool = _byPower(data, save, locale, [
        for (final b in _adults(save, data, now))
          if (!save.isInjured(b.id, now) &&
              !(save.trainingJob != null &&
                  !save.trainingJob!.doneAt(now) &&
                  save.trainingJob!.bugId == b.id))
            b,
      ]);
      setState(() {
        final left = [
          for (final b in pool)
            if (!_team.contains(b.id)) b.id,
        ];
        for (var i = 0; i < 3 && left.isNotEmpty; i++) {
          _team[i] ??= left.removeAt(0);
        }
      });
      showCenterToast(context, l.squadAutoFilled);
      return;
    }
    final ids = _duelTeamIds(l);
    if (ids == null) return;
    final server = ref.read(gameServerProvider);
    List<_Candidate> cands;
    String? offerId;
    if (server.available) {
      setState(() => _starting = true);
      try {
        // 후보를 뽑기 전에 최신 세이브를 올린다(서버가 내 리그·전력을 본다).
        if (!await _flushSave()) {
          if (mounted) showCenterToast(context, l.battleServerFailed);
          return;
        }
        final res = await server.duelOffer(locale: locale);
        if (!mounted) return;
        if (!res.isOk) {
          showCenterToast(
            context,
            res.error == 'season_closed'
                ? l.battleSeasonClosed
                : l.battleServerFailed,
          );
          return;
        }
        offerId = res.data!['offerId']?.toString();
        cands = [
          for (final s in (res.data!['slots'] as List? ?? const []))
            _Candidate.fromServer(Map<String, dynamic>.from(s as Map)),
        ];
      } finally {
        if (mounted) setState(() => _starting = false);
      }
    } else if (kReleaseMode) {
      // 릴리즈에서 서버 없이 켜졌으면(첫 실행 오프라인·장애) 결투를 막는다 — 로컬 후보·로컬
      // 결투로 흘러가면 골드가 기기에 쌓였다(2026-09-30 점검). 개발 실행에서만 로컬 미리보기.
      showCenterToast(context, l.battleNeedServer);
      return;
    } else {
      cands = _localCandidates(data, save, locale, ids);
    }
    if (!mounted || cands.isEmpty) return;
    final pick = await _pickOpponent(l, data, locale, cands);
    if (pick == null || !mounted) return;
    await _battleManual(
      data,
      ref.read(saveControllerProvider).requireValue,
      locale,
      pick,
      offerId: offerId,
    );
  }

  /// 서버 없이(개발 실행) — 내 팀을 세기만 바꿔 다섯 후보를 만든다(점수 5~1).
  List<_Candidate> _localCandidates(
    GameData data,
    SaveGame save,
    String locale,
    List<String> ids,
  ) {
    final cfg = data.battleConfig ?? const BattleConfig();
    final pts = [...cfg.matchAbovePoints.reversed, ...cfg.matchBelowPoints];
    const mults = [1.25, 1.12, 1.0, 0.9, 0.8];
    final species = data.allSpecies;
    // 순위표 미리보기와 같은 명단에서 내 위 3명·아래 2명을 고른다(서버와 같은 함수).
    final now = ref.read(clockProvider).now().toUtc();
    final board = previewLeagueBoard(
      league: pvpLeagueNow(save, cfg).id,
      myNickname: save.nickname,
      myTrophies: save.pvpTrophies,
      myPower: _myDuelTeam(
        data,
        save,
        locale,
      ).fold<double>(0, (a, x) => a + x.power),
      speciesIds: [for (final sp in species) sp.id],
      cfg: cfg,
      now: now,
      myId: kPreviewMyId,
    );
    final rows = [
      for (final r in (board['top'] as List))
        Map<String, dynamic>.from(r as Map),
    ];
    final slots = pickMatchSlots(
      ranked: [
        for (final r in rows)
          (userId: '${r['user_id']}', rank: (r['rank'] as num).toInt()),
      ],
      myRank: (board['me'] as Map)['rank'] as int,
      myUserId: kPreviewMyId,
      cfg: cfg,
    );
    return [
      for (var i = 0; i < pts.length; i++)
        () {
          final foe = [
            for (var k = 0; k < ids.length; k++)
              () {
                final mine = _toDuelBug(
                  save.bugs.firstWhere((b) => b.id == ids[k]),
                  data,
                  locale,
                );
                final sp = species[_rng.nextInt(species.length)];
                final m = mults[i % mults.length];
                return DuelBug(
                  id: 'local${i}_$k',
                  name: sp.name.resolve(locale),
                  speciesId: sp.id,
                  element: Element.values[_rng.nextInt(Element.values.length)],
                  temperament: Temperament
                      .values[_rng.nextInt(Temperament.values.length)],
                  specialty: sp.specialty,
                  sizeMm: (sp.sizeMinMm + sp.sizeMaxMm) / 2,
                  maxHp: mine.maxHp * m,
                  atk: mine.atk * m,
                  def: mine.def * m,
                  spd: mine.spd * m,
                );
              }(),
          ];
          final power = foe.fold<double>(0, (a, x) => a + _duelPower(x));
          final slot = i < slots.length ? slots[i] : null;
          final row = slot?.userId == null
              ? null
              : rows.where((r) => r['user_id'] == slot!.userId).firstOrNull;
          return _Candidate(
            index: i,
            nickname: row == null ? '' : '${row['nickname']}',
            rank: slot?.rank,
            points: slot?.points ?? pts[i],
            power: power,
            team: [
              for (final b in foe)
                (
                  sp: b.speciesId,
                  element: b.element,
                  power: _duelPower(b),
                  skin: null,
                  bug: b,
                ),
            ],
            localFoe: foe,
          );
        }(),
    ];
  }

  double _duelPower(DuelBug b) => b.atk + b.def + b.spd + b.maxHp * 0.15;

  /// 후보 5명 고르기 — 이기면 받는 점수를 크게 보여 준다(지면 0점).
  Future<_Candidate?> _pickOpponent(
    AppLocalizations l,
    GameData data,
    String locale,
    List<_Candidate> cands,
  ) {
    final ids = _team.whereType<String>().toList();
    final save = ref.read(saveControllerProvider).requireValue;
    final myPower = ids.fold<double>(
      0,
      (a, id) =>
          a +
          _duelPower(
            _toDuelBug(save.bugs.firstWhere((b) => b.id == id), data, locale),
          ),
    );
    return showModalBottomSheet<_Candidate>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xF22F333E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.opponentPickTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                l.opponentPickHint(formatCompact(myPower.round())),
                style: const TextStyle(color: Color(0xAAFFFFFF), fontSize: 12),
              ),
              const SizedBox(height: 10),
              for (final c in cands)
                _candidateCard(l, data, locale, c, myPower, ctx),
            ],
          ),
        ),
      ),
    );
  }

  Widget _candidateCard(
    AppLocalizations l,
    GameData data,
    String locale,
    _Candidate c,
    double myPower,
    BuildContext sheet,
  ) {
    final ratio = myPower <= 0 ? 1.0 : c.teamPower / myPower;
    final tone = ratio > 1.1
        ? const Color(0xFFEF6B4A)
        : (ratio < 0.9 ? const Color(0xFF6FCF6F) : const Color(0xFFE9D9A6));
    return GestureDetector(
      // 카드(이름)를 누르면 상대 곤충 상세, 공격 버튼을 눌러야 시작한다.
      onTap: () => _showFoeDetail(l, data, locale, c),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: const Color(0xFF3F4452),
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: tone, width: 4)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Center(
                child: Text(
                  c.rank == null ? '-' : '${c.rank}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.nickname.isEmpty ? l.opponentWild : _maskName(c.nickname),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      for (final t in c.team)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: SizedBox(
                            width: 30,
                            height: 30,
                            child: gameImageChain(
                              ['assets/images/bugs/${t.sp}_adult.webp'],
                              size: 30,
                              fallback: const Icon(
                                Icons.bug_report,
                                color: Colors.white54,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(width: 4),
                      Icon(Icons.flash_on_rounded, size: 14, color: tone),
                      Text(
                        formatCompact(c.teamPower.round()),
                        style: TextStyle(
                          color: tone,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF22252E),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 18,
                        color: Color(0xFFFFC928),
                      ),
                      Text(
                        '+${c.points}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    l.opponentWinOnly,
                    style: const TextStyle(
                      color: Color(0x99FFFFFF),
                      fontSize: 9.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            FilledButton(
              onPressed: () => Navigator.of(sheet).pop(c),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEF5350),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(0, 40),
              ),
              child: Text(
                l.duelAttackBtn,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 결투 화면으로. 끝나면 순위표를 새로 받는다.
  Future<void> _pushDuel({
    required GameData data,
    required List<DuelBug> mine,
    required List<DuelBug> foe,
    required DuelDriver driver,
    required Map<String, SkinView?> mySkins,
    required Map<String, SkinView?> foeSkins,
    required Future<void> Function(DuelStep last) onFinished,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DuelArenaScreen(
          mine: mine,
          foe: foe,
          driver: driver,
          params: _duelParams(data),
          arena: foe.first.element,
          mySkins: mySkins,
          foeSkins: foeSkins,
          onFinished: onFinished,
        ),
      ),
    );
    unawaited(_boardKey.currentState?.reload());
  }

  /// **직접 던지기 결투** — 판마다 게이지 → 서버가 그 판을 확정 → 재생.
  ///
  /// 이기면 고른 후보의 점수, 지면 0점(트로피 선차감 없음). 부상은 시작할 때 먼저 걸고
  /// 결착에서 이긴 곤충은 풀어 준다 — 도중에 나가면 그대로 패배.
  Future<void> _battleManual(
    GameData data,
    SaveGame save,
    String locale,
    _Candidate c, {
    String? offerId,
  }) async {
    final l = AppLocalizations.of(context);
    final ids = _duelTeamIds(l);
    if (ids == null) return;
    if (!await _takeTicket(l)) return;
    await ref.read(saveControllerProvider.notifier).setPvpDefense(ids);
    final mine = [
      for (final id in ids)
        _toDuelBug(save.bugs.firstWhere((b) => b.id == id), data, locale),
    ];
    final mySkins = _mySkins(save, ids);

    final server = ref.read(gameServerProvider);
    if (server.available && offerId != null) {
      final close = _showStartOverlay(l);
      try {
        final res = await server.duelStart(
          teamBugIds: ids,
          offerId: offerId,
          pick: c.index,
        );
        if (!res.isOk || res.data?['sessionId'] == null) {
          await _duelRejected(l, res);
          return;
        }
        // 서버가 확정한 티켓 잔량으로 맞춘다(세이브 전체가 아니라 몇 바이트).
        await ref
            .read(saveControllerProvider.notifier)
            .adoptTicketState(res.data!);
        // 세션이 열렸다 — 이제 이탈해도 패배다. 부상 선차감을 앱 세이브에도 건다.
        await ref.read(saveControllerProvider.notifier).preInjureTeam(ids);
        if (!mounted) return;
        final f = _foeFromServer(res.data!['foe']);
        close();
        await _pushDuel(
          data: data,
          mine: mine,
          foe: f.foe,
          driver: ServerDuelDriver(
            server: server,
            sessionId: res.data!['sessionId'].toString(),
          ),
          mySkins: mySkins,
          foeSkins: f.skins,
          onFinished: _adoptDuel,
        );
      } finally {
        close();
      }
      return;
    }

    // 로컬(개발 실행).
    final foe = c.localFoe ?? const <DuelBug>[];
    if (foe.isEmpty) return;
    await ref.read(saveControllerProvider.notifier).preInjureTeam(ids);
    _localWinPoints = c.points;
    final local = _RecordingLocalDriver(
      LocalDuelDriver(
        seed: _rng.nextInt(1 << 31),
        mine: mine,
        foe: foe,
        params: _duelParams(data),
        battle: data.battleConfig ?? const BattleConfig(),
        trophies: save.pvpTrophies,
        rewardMult: 1.0,
      ),
      onBout: (i, won) {
        if (i == 0) _localLosers.clear();
        // 승자 연속 — 지면 지금 나가 있던 곤충(앞에서부터 진 수번째)이 쓰러진다.
        if (!won) {
          _localLosers.add(ids[_localLosers.length.clamp(0, ids.length - 1)]);
        }
      },
    );
    if (!mounted) return;
    await _pushDuel(
      data: data,
      mine: mine,
      foe: foe,
      driver: local,
      mySkins: mySkins,
      foeSkins: const {},
      onFinished: (last) => _applyLocalDuel(last, ids),
    );
  }

  /// 로컬 결투에서 이기면 받을 점수(고른 후보).
  int _localWinPoints = 0;

  /// 다른 유저 닉네임 표시용 — 부적절한 이름은 중립 이름으로 대체.
  /// 이미 서버에 등록된 이름은 되돌릴 수 없으므로 보여줄 때 가린다.
  String _maskName(String name) =>
      (ref.read(gameDataProvider).value?.chatRules ?? const ChatRules())
          .maskNickname(
            name,
            fallback: AppLocalizations.of(context).nicknameFallback,
          );

  /// 슬롯 [from] 의 곤충을 [to] 위치로 이동(삽입 재배치, 나머지는 밀림).
  /// 오행 상생(生)이 앞→뒤 인접으로 작동하므로 순서가 곧 전략.
  void _reorderSlots(int from, int to) {
    if (from == to) return;
    final item = _team.removeAt(from);
    _team.insert(to, item);
  }

  /// 드래그 중 손가락을 따라오는 축소 피드백(종 초상).
  Widget _dragFeedback(IndividualBug bug, Species sp) => Material(
    type: MaterialType.transparency,
    child: Transform.translate(
      offset: const Offset(-30, -30),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: const Color(0xE6141F0E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _honey, width: 1.6),
        ),
        child: bugStageImage(
          bug.speciesId,
          LifeStage.adult,
          size: 48,
          fallback: bugAvatar(sp, size: 42),
          skin: bugView(ref.read(skinOfProvider), bug),
        ),
      ),
    ),
  );

  /// 수동/자동 토글 + 큰 전투 시작 버튼.
  Widget _teamSlot(GameData data, SaveGame save, String locale, int index) {
    final id = _team[index];
    final bug = id == null
        ? null
        : save.bugs.cast<IndividualBug?>().firstWhere(
            (b) => b!.id == id,
            orElse: () => null,
          );
    final sp = bug == null ? null : data.species(bug.speciesId);
    const slotH = 128.0;
    final card = GestureDetector(
      onTap: () => bug == null
          ? _showPicker(data, save, locale, index)
          : _showBugDetail(
              null,
              data,
              save,
              locale,
              bug,
              index,
              save.isInjured(bug.id, ref.read(clockProvider).now().toUtc()),
            ),
      child: SizedBox(
        width: double.infinity, // 셀(1/3)을 꽉 채워 3슬롯 균등 정렬
        height: slotH,
        child: Stack(
          children: [
            // 받침대 틀(나무껍질 + 그루터기). 그림이 없으면 예전 상자.
            Positioned.fill(
              child: Opacity(
                opacity: bug == null ? 0.7 : 1,
                child: gameImageChain(
                  ['assets/images/duel/squad_slot.webp'],
                  size: slotH,
                  fit: BoxFit.fill,
                  fallback: Container(
                    decoration: BoxDecoration(
                      color: const Color(0x22000000),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: bug == null ? const Color(0x33FFFFFF) : _honey,
                        width: bug == null ? 1 : 1.6,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (bug == null)
              const Center(
                child: Icon(
                  Icons.add_circle_outline,
                  color: Color(0x99FFFFFF),
                  size: 30,
                ),
              )
            // 쉬는 곤충 — 부상(빨강) 또는 훈련 중(파랑). 훈련 중인 곤충도 출정할 수 없는데
            // 칸에는 멀쩡히 보여 전투 시작을 눌러야 알았다(2026-09-30 점검).
            else if (_restOf(save, bug.id) case final rest?)
              Positioned.fill(
                child: Container(
                  margin: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0x99000000),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Opacity(
                        opacity: 0.5,
                        child: bugStageImage(
                          bug.speciesId,
                          LifeStage.adult,
                          size: 52,
                          fallback: bugAvatar(sp!, size: 44),
                        ),
                      ),
                      Text(
                        rest.training
                            ? AppLocalizations.of(context).squadTrainingBadge
                            : AppLocalizations.of(context).injuryTitle,
                        style: TextStyle(
                          color: rest.training
                              ? const Color(0xFF8EC9FF)
                              : const Color(0xFFEF9A9A),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        formatClock(
                          rest.until.difference(
                            ref.read(clockProvider).now().toUtc(),
                          ),
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Padding(
                // 위: 이름·오행 · 아래: 그루터기 윗면에 발이 닿게.
                padding: const EdgeInsets.fromLTRB(8, 12, 8, slotH * 0.13),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: gradeColor(sp!.grade).withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        gradeLabel(AppLocalizations.of(context), sp.grade),
                        style: const TextStyle(
                          color: Color(0xFF1B1A14),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sp.name.resolve(locale),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        shadows: [Shadow(color: Colors.black, blurRadius: 3)],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: elementColor(
                          bug.element,
                        ).withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          elementIcon(bug.element, size: 11),
                          const SizedBox(width: 3),
                          Text(
                            elementLabel(
                              AppLocalizations.of(context),
                              bug.element,
                            ),
                            style: TextStyle(
                              color: elementColor(bug.element),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: bugStageImage(
                          bug.speciesId,
                          LifeStage.adult,
                          size: 66,
                          fallback: bugAvatar(sp, size: 52),
                          skin: bugView(ref.watch(skinOfProvider), bug),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
    // 채워진 슬롯은 드래그 가능(탭=선택 유지). 빈 슬롯은 드롭 대상만.
    final Widget content = (bug == null)
        ? card
        : Draggable<int>(
            data: index,
            dragAnchorStrategy: pointerDragAnchorStrategy,
            feedback: _dragFeedback(bug, sp!),
            childWhenDragging: Opacity(opacity: 0.35, child: card),
            child: card,
          );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: DragTarget<int>(
        onWillAcceptWithDetails: (d) => d.data != index,
        onAcceptWithDetails: (d) =>
            setState(() => _reorderSlots(d.data, index)),
        builder: (ctx, candidate, rejected) => Stack(
          clipBehavior: Clip.none,
          children: [
            content,
            // 드롭 대상 하이라이트.
            if (candidate.isNotEmpty)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      color: _honey.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _honey, width: 2),
                    ),
                  ),
                ),
              ),
            // 전투 순서 배지 ①②③
            Positioned(top: -6, left: -2, child: _orderBadge(index)),
          ],
        ),
      ),
    );
  }

  Widget _orderBadge(int index) => Container(
    width: 19,
    height: 19,
    decoration: const BoxDecoration(color: _honey, shape: BoxShape.circle),
    alignment: Alignment.center,
    child: Text(
      '${index + 1}',
      style: const TextStyle(
        color: kHoneyInk,
        fontSize: 11,
        fontWeight: FontWeight.w900,
      ),
    ),
  );

  void _showPicker(GameData data, SaveGame save, String locale, int slot) {
    final now = ref.read(clockProvider).now().toUtc();
    final adults = _adults(save, data, now);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xF2141F0E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final l = AppLocalizations.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      l.battlePickTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const Spacer(),
                    // 지금 편성의 전투력 — 무엇을 바꿔야 세지는지 바로 보인다.
                    Text(
                      l.teamPower(
                        formatCompact(_myTeamPowerSum(data, save, locale)),
                      ),
                      style: const TextStyle(
                        color: _honey,
                        fontWeight: FontWeight.w900,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: LayoutBuilder(
                    // 칸 너비를 화면에 맞춰 나눈다 — 고정 폭이면 오른쪽이 들쭉날쭉했다.
                    builder: (_, box) {
                      const cols = 4, gap = 8.0;
                      final tileW = (box.maxWidth - gap * (cols - 1)) / cols;
                      return SingleChildScrollView(
                        child: Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [
                            // 강한 순으로 보여준다 — 고르려고 여는 화면이다.
                            for (final b in _byPower(
                              data,
                              save,
                              locale,
                              adults,
                            ))
                              SizedBox(
                                width: tileW,
                                child: _pickTile(
                                  ctx,
                                  data,
                                  save,
                                  locale,
                                  now,
                                  b,
                                  slot,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _pickTile(
    BuildContext ctx,
    GameData data,
    SaveGame save,
    String locale,
    DateTime now,
    IndividualBug bug,
    int slot,
  ) {
    final sp = data.species(bug.speciesId);
    final used = _team.contains(bug.id);
    final usedAt = _team.indexOf(bug.id); // 0~2 — 몇 번 칸에 출정 중인지
    final until = save.injuredUntil(bug.id);
    final injured = until != null && now.isBefore(until);
    return Opacity(
      opacity: injured ? 0.45 : 1,
      child: GestureDetector(
        // 누르면 상세 창(능력치·특성) → 출정/취소.
        onTap: () =>
            _showBugDetail(ctx, data, save, locale, bug, slot, injured),
        child: SizedBox(
          width: double.infinity,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0x22000000),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: injured
                    ? const Color(0x66EF9A9A)
                    : (used
                          ? _honey
                          : gradeColor(sp.grade).withValues(alpha: 0.7)),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 출정 중 표시(2026-10-01 실기 지적 — 테두리 색만으로는 몰랐다). 몇 번 칸인지까지.
                if (used)
                  Container(
                    margin: const EdgeInsets.only(bottom: 2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: _honey,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      AppLocalizations.of(ctx).duelPickDeployed(usedAt + 1),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: kHoneyInk,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                bugStageImage(
                  bug.speciesId,
                  LifeStage.adult,
                  size: 44,
                  fallback: bugAvatar(sp, size: 38),
                  skin: bugView(ref.watch(skinOfProvider), bug),
                ),
                const SizedBox(height: 2),
                // 등급은 테두리 색만으로는 구분이 어렵다 — 글자로 못 박는다.
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: gradeColor(sp.grade).withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    gradeLabel(AppLocalizations.of(ctx), sp.grade),
                    style: TextStyle(
                      color: gradeColor(sp.grade),
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  sp.name.resolve(locale),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
                Text(
                  '⚔ ${formatCompact(_bugPower(bug, data, locale).round())}',
                  style: const TextStyle(
                    color: Color(0xFFEBD24A),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                injured
                    ? Text(
                        '🩹 ${formatClock(until.difference(now))}',
                        style: const TextStyle(
                          color: Color(0xFFEF9A9A),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : Text(
                        'Lv.${bug.level}',
                        style: const TextStyle(
                          color: Color(0x99FFFFFF),
                          fontSize: 9,
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── 곤충 능력치 창(내 곤충 고르기 · 상대 곤충 보기 공용) ─────────────────

  /// 능력치 한 줄.
  Widget _statRow(String label, String value, {Color? color, Widget? lead}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              child: Text(
                label,
                style: const TextStyle(color: Color(0xAAFFFFFF), fontSize: 12),
              ),
            ),
            if (lead != null) ...[lead, const SizedBox(width: 4)],
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  color: color ?? Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      );

  /// 결투 유닛 [d] 의 능력치 카드. 내 곤충이면 [bug] 로 포텐셜·혈통 특성·레벨까지.
  Widget _bugStats(
    AppLocalizations l,
    GameData data,
    String locale,
    DuelBug d, {
    IndividualBug? bug,
    SkinView? skin,
  }) {
    Species? sp;
    try {
      sp = data.species(d.speciesId);
    } catch (_) {}
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: bugPoseImage(
                d.speciesId,
                BugPose.idle,
                size: 72,
                skin: skin,
                fallback: const Icon(Icons.bug_report, color: Colors.white54),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sp?.name.resolve(locale) ?? d.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 4,
                    runSpacing: 3,
                    children: [
                      if (sp != null)
                        _chip(gradeLabel(l, sp.grade), gradeColor(sp.grade)),
                      _chip(
                        elementLabel(l, d.element),
                        elementColor(d.element),
                        lead: elementIcon(d.element, size: 11),
                      ),
                      if (bug != null && !bug.trait.isNone)
                        _chip(
                          traitLabel(l, bug.trait),
                          traitColor(bug.trait),
                          lead: traitIcon(bug.trait, size: 11),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _statRow(
          l.statCombatPower,
          formatCompact(d.power.round()),
          color: const Color(0xFFEBD24A),
        ),
        _statRow(l.statHp, formatCompact(d.maxHp.round())),
        _statRow(l.bugInfoAtk, formatCompact(d.atk.round())),
        _statRow(l.bugInfoDef, formatCompact(d.def.round())),
        _statRow(l.bugInfoSpd, formatCompact(d.spd.round())),
        _statRow(l.bugInfoSpecialty, specialtyLabel(l, d.specialty)),
        _statRow(
          l.bugInfoTemperament,
          temperamentLabel(l, d.temperament),
          lead: temperamentIcon(d.temperament, size: 14),
        ),
        _statRow(l.bugInfoSize, l.bugSize(d.sizeMm.toStringAsFixed(1))),
        // 훈련소 단계(내 곤충) · 회피·치명·회복력(상대 곤충 — 훈련이 들어간 값).
        if (bug != null)
          for (final st in TrainStat.values)
            if ((trainLevelsOf(
                      ref.read(saveControllerProvider).requireValue,
                      bug.id,
                    )[st] ??
                    0) >
                0)
              _statRow(
                trainStatLabel(l, st),
                l.trainingLevel(
                  trainLevelsOf(
                    ref.read(saveControllerProvider).requireValue,
                    bug.id,
                  )[st]!,
                  trainCapOf(
                    bug,
                    data.species(bug.speciesId),
                    st,
                    (data.battleConfig ?? const BattleConfig()).training,
                  ),
                ),
                color: trainStatColor(st),
              ),
        if (bug == null) ...[
          if (d.evade > 0)
            _statRow(l.trainEvade, '${(d.evade * 100).toStringAsFixed(1)}%'),
          if (d.crit > 0)
            _statRow(l.trainCrit, '+${(d.crit * 100).toStringAsFixed(1)}%'),
          if (d.recovery > 0)
            _statRow(
              l.trainRecovery,
              '+${(d.recovery * 100).toStringAsFixed(1)}%',
            ),
        ],
        if (bug != null) ...[
          _statRow(
            l.bugInfoPotential,
            '★' * bug.potential,
            color: const Color(0xFFFFC928),
          ),
          _statRow('Lv', '${bug.level}'),
        ],
      ],
    );
  }

  Widget _chip(String text, Color c, {Widget? lead}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: c.withValues(alpha: 0.22),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (lead != null) ...[lead, const SizedBox(width: 3)],
        Text(
          text,
          style: TextStyle(
            color: c,
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );

  /// 내 곤충 상세 — 출정 / 취소.
  Future<void> _showBugDetail(
    BuildContext? sheet,
    GameData data,
    SaveGame save,
    String locale,
    IndividualBug bug,
    int slot,
    bool injured,
  ) async {
    final l = AppLocalizations.of(context);
    final inTeam = _team.contains(bug.id);
    // 'deploy' 출정 · 'release' 해제 · 'swap' 다른 곤충으로 교체.
    final act = await showGameDialog<String>(
      context,
      title: l.squadDetailTitle,
      icon: Icons.bug_report_rounded,
      content: _bugStats(
        l,
        data,
        locale,
        _toDuelBug(bug, data, locale),
        bug: bug,
        skin: bugView(ref.read(skinOfProvider), bug),
      ),
      actions: [
        if (inTeam)
          gameDialogButton(
            l.squadRelease,
            () => Navigator.pop(context, 'release'),
            primary: false,
          )
        else
          gameDialogButton(
            l.actionCancel,
            () => Navigator.pop(context),
            primary: false,
          ),
        // 칸에서 연 곤충은 이미 그 자리 — 출정 대신 교체.
        if (sheet == null)
          gameDialogButton(l.squadSwap, () => Navigator.pop(context, 'swap'))
        else
          gameDialogButton(
            injured ? l.injuryTitle : l.squadDeploy,
            injured ? () {} : () => Navigator.pop(context, 'deploy'),
          ),
      ],
    );
    if (act == null || !mounted) return;
    switch (act) {
      case 'release':
        setState(() {
          for (var i = 0; i < 3; i++) {
            if (_team[i] == bug.id) _team[i] = null;
          }
        });
      case 'swap':
        _showPicker(
          data,
          ref.read(saveControllerProvider).requireValue,
          locale,
          slot,
        );
        return;
      case 'deploy':
        setState(() {
          // 다른 슬롯에 이미 있으면 제거(중복 방지) 후 배치.
          for (var i = 0; i < 3; i++) {
            if (_team[i] == bug.id) _team[i] = null;
          }
          _team[slot] = bug.id;
        });
    }
    if (sheet != null && sheet.mounted) Navigator.pop(sheet);
  }

  /// 상대 팀 상세 — 곤충마다 능력치·주특기·기질(전략을 짜게).
  Future<void> _showFoeDetail(
    AppLocalizations l,
    GameData data,
    String locale,
    _Candidate c,
  ) => showGameDialog<void>(
    context,
    title: c.nickname.isEmpty ? l.opponentWild : _maskName(c.nickname),
    icon: Icons.groups_rounded,
    content: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.55,
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            for (var i = 0; i < c.team.length; i++)
              if (c.team[i].bug != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0x22FFFFFF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.squadOrder(i + 1),
                        style: const TextStyle(
                          color: _honey,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      _bugStats(l, data, locale, c.team[i].bug!),
                    ],
                  ),
                ),
          ],
        ),
      ),
    ),
    actions: [gameDialogButton(l.actionClose, () => Navigator.pop(context))],
  );

  /// 현재 편성의 전투력 **합**(빈 슬롯은 0).
  ///
  /// `_teamPower` 는 상대 스케일 계산용 **평균**이라 용도가 다르다 — 화면에는
  /// "팀 전체가 얼마나 센가"인 합이 맞다.
  double _myTeamPowerSum(GameData data, SaveGame save, String locale) {
    var sum = 0.0;
    for (final id in _team.whereType<String>()) {
      final bug = save.bugs.cast<IndividualBug?>().firstWhere(
        (b) => b!.id == id,
        orElse: () => null,
      );
      if (bug != null) sum += _bugPower(bug, data, locale);
    }
    return sum;
  }

  /// 전투력이 높은 순으로 정렬한 사본.
  List<IndividualBug> _byPower(
    GameData data,
    SaveGame save,
    String locale,
    List<IndividualBug> bugs,
  ) => [...bugs]
    ..sort((a, b) {
      final d = _bugPower(
        b,
        data,
        locale,
      ).compareTo(_bugPower(a, data, locale));
      return d != 0 ? d : a.id.compareTo(b.id); // 동점이어도 순서가 흔들리지 않게
    });

  /// 스카우트 팀 → **상대 곤충 id별** 스킨 필터.
  ///
  /// 종이 아니라 id 로 푼다 — 같은 종이라도 상대가 샀는지 여부가 다르다.
  /// 상대 스킨 효과 키 → 그리기 정보. 전용 그림 유무는 iap.json 이 정한다.
  SkinView? _viewOf(String? effect, String speciesId) {
    if (effect == null) return null;
    final cfg = ref.read(gameDataProvider).value?.iapConfig;
    return SkinView(
      effect,
      hasArt: cfg?.skinHasArt(effect, speciesId) ?? false,
    );
  }

  /// 서버 권위 전투 — 승패·보상을 서버가 확정하고, 앱은 결과를 재생만 한다.
  ///
  /// 서버가 같은 시드로 같은 `core_battle` 을 돌리므로 클라이언트가
  /// 그 시드로 재시뮬레이션하면 **완전히 같은 전개**가 나온다.
  /// 전투 전 최신 로컬 세이브를 서버에 올린다(기기 권위 → 서버가 최신으로 전투).
  /// 저장본이 없으면(신규) 부트스트랩으로 대신한다.
  ///
  /// **성공했을 때만 true.** 실패(네트워크·5xx)면 서버엔 낡은 세이브가 남아 있어,
  /// 그 위에서 전투를 돌리고 결과를 adopt 하면 **최근 로컬 진행이 통째로 사라진다.**
  /// 그래서 호출부는 실패 시 전투를 진행하지 않는다.
  Future<bool> _flushSave() => flushSaveBeforeServerAction(
    ref.read(gameServerProvider),
    ref.read(saveControllerProvider).value,
  );

  /// 결투 1판분 티켓을 확보한다. 없으면 이유를 알리고 false.
  ///
  /// 로컬에서 먼저 깎는 이유: 서버 응답을 기다리는 동안에도 화면의 잔량이
  /// 즉시 줄어야 연타로 여러 판이 시작되지 않는다. 진짜 잔량은 서버가 확정한다.
  Future<bool> _takeTicket(AppLocalizations l) async {
    final ok = await ref
        .read(saveControllerProvider.notifier)
        .consumePvpTicket();
    if (!ok && mounted) showCenterToast(context, l.pvpTicketNone);
    return ok;
  }

  /// 전투를 시작하지 못했을 때 낙관 차감분을 되돌린다.
  Future<void> _returnTicket() =>
      ref.read(saveControllerProvider.notifier).restorePvpTicket();

  /// 서버가 "티켓 없음"으로 거절했는지. 맞으면 **서버가 알려준 잔량으로 맞춘다**
  /// (앱이 재설치·구버전 세이브로 서버보다 많이 갖고 있다고 착각한 경우).
  /// 되돌리기(_returnTicket)보다 이쪽이 우선이라 호출부는 이 값을 보고 분기한다.
  Future<bool> _syncTicketRejection(ServerResult res) async {
    _lastRejectedForTickets = res.error == 'no_tickets';
    if (!_lastRejectedForTickets) return false;
    await ref
        .read(saveControllerProvider.notifier)
        .adoptTicketState(res.errorData);
    return true;
  }

  /// 자동 전투 — 결정론 simulate 후 아레나 재생.
  /// "결투 시작!" 전환 — **서버 왕복을 덮는다**.
  ///
  /// 서버가 붙어 있으면 승패를 서버가 확정하므로(§3 기기 권위 아님) 버튼을 누른 뒤
  /// Cloud Run 왕복만큼 기다린다. 예전엔 그동안 **아무 일도 안 일어나서** 버튼이
  /// 안 먹은 줄 알았다(실기 지적). 없앨 수 없는 대기라면 **기다림을 연출로 덮는다**.
  ///
  /// 돌려주는 함수를 부르면 닫힌다. **아레나로 넘어가기 직전**에 부르고,
  /// 실패 경로를 위해 `finally` 에서도 부른다 — 두 번 불러도 안전하다.
  ///
  /// ⚠️ `finally` 에만 두면 안 된다. 전투 진입은 `await Navigator.push` 라
  /// **전투가 끝날 때까지 반환되지 않는다** — 그동안 "결투 시작!" 이 화면에
  /// 그대로 떠 있었다(실기 지적).
  VoidCallback _showStartOverlay(AppLocalizations l) {
    final entry = OverlayEntry(builder: (_) => const _BattleStartOverlay());
    Overlay.of(context, rootOverlay: true).insert(entry);
    var closed = false;
    return () {
      if (closed) return;
      closed = true;
      entry.remove();
    };
  }

  // ── 결투(곤충 배틀 스타디움, 2026-09-28) ───────────────────────────
  //
  // 1:1 · 3판 2선승 · 판마다 던지기(docs/design_duel.md). 승패는 서버가 확정하고 앱은
  // 궤적을 재생만 한다. 서버가 없으면(개발 실행) 같은 엔진을 앱에서 돌린다.

  DuelParams _duelParams(GameData data) =>
      DuelParams.fromJson((data.battleConfig ?? const BattleConfig()).duelJson);

  /// 보유 곤충 → 결투 유닛(서버 `validateDuelTeam` 과 같은 스탯 계산).
  DuelBug _toDuelBug(IndividualBug bug, GameData data, String locale) =>
      duelBugFor(
        bug,
        data,
        ref.read(saveControllerProvider).requireValue,
        locale,
      );

  /// 출전 순서 3마리. 3마리가 아니거나 회복 중인 곤충이 있으면 null.
  List<String>? _duelTeamIds(AppLocalizations l) {
    final ids = _team.whereType<String>().toList();
    if (ids.length != 3) {
      showCenterToast(context, l.duelNeedThree);
      return null;
    }
    final save = ref.read(saveControllerProvider).requireValue;
    final now = ref.read(clockProvider).now().toUtc();
    if (ids.any((id) => save.isInjured(id, now))) {
      showCenterToast(context, l.squadInjured);
      return null;
    }
    final job = save.trainingJob;
    if (job != null && !job.doneAt(now) && ids.contains(job.bugId)) {
      showCenterToast(context, l.squadTraining);
      return null;
    }
    return ids;
  }

  /// 서버가 준 상대 목록(`_duelFoeJson`) → 결투 유닛 + 스킨.
  ({List<DuelBug> foe, Map<String, SkinView?> skins}) _foeFromServer(
    Object? raw,
  ) {
    final foe = <DuelBug>[];
    final skins = <String, SkinView?>{};
    for (final e in (raw as List? ?? const [])) {
      final m = Map<String, dynamic>.from(e as Map);
      final b = DuelBug.fromJson(m);
      foe.add(b);
      skins[b.id] = _viewOf(m['skin']?.toString(), b.speciesId);
    }
    return (foe: foe, skins: skins);
  }

  Map<String, SkinView?> _mySkins(SaveGame save, List<String> ids) => {
    for (final id in ids)
      id: bugView(
        ref.read(skinOfProvider),
        save.bugs.firstWhere((b) => b.id == id),
      ),
  };

  /// 로컬(서버 없음) 결투 결과 반영 — 진 판의 곤충만 부상, 나머지 선차감 부상은 푼다.
  Future<void> _applyLocalDuel(DuelStep last, List<String> ids) async {
    // 로컬 진행기는 판별 결과를 따로 안 들고 있어서, 마지막 판까지의 승패로 재구성한다.
    await ref
        .read(saveControllerProvider.notifier)
        .applyBattleResult(
          gold: last.gold,
          // 승리 점수 방식(2026-09-29) — 이기면 고른 후보의 점수, 지면 0.
          trophyDelta: last.winsA > last.winsB ? _localWinPoints : 0,
          koedBugIds: _localLosers,
          healBugIds: [
            for (final id in ids)
              if (!_localLosers.contains(id)) id,
          ],
        );
    final s2 = ref.read(saveControllerProvider).requireValue;
    unawaited(ref.read(pvpBackendProvider).pushTrophies(me: _me(s2)));
  }

  /// 로컬 결투에서 진 판의 내 곤충 id(판마다 채운다).
  final List<String> _localLosers = [];

  /// 서버 결투가 끝났을 때 — 서버 세이브를 통째로 채택한다(보상·트로피·부상 모두 서버 값).
  Future<void> _adoptDuel(DuelStep last) async {
    final srv = last.save;
    if (srv != null) {
      await ref.read(saveControllerProvider.notifier).adoptServerSave(srv);
    }
    final s2 = ref.read(saveControllerProvider).requireValue;
    unawaited(ref.read(pvpBackendProvider).pushTrophies(me: _me(s2)));
  }

  /// 서버 거절 알림 + 티켓 정리(티켓 없음이면 서버 잔량으로, 아니면 낙관 차감을 되돌린다).
  Future<void> _duelRejected(AppLocalizations l, ServerResult res) async {
    final noTicket = await _syncTicketRejection(res);
    if (!noTicket) await _returnTicket();
    if (!mounted) return;
    showCenterToast(
      context,
      noTicket
          ? l.pvpTicketNone
          : (res.error == 'bug_injured' ? l.injuryDesc : l.battleServerFailed),
    );
  }
}

/// "결투 시작!" 전환 화면. 서버가 승패를 확정하는 동안(왕복 0.3~2초) 덮는다.
///
/// 스피너 대신 **글자가 튀어 들어오게** 한 이유: 스피너는 "로딩 중"이라 기다림을
/// 드러내지만, 이건 전투의 시작으로 읽혀서 같은 시간이 짧게 느껴진다.
class _BattleStartOverlay extends StatefulWidget {
  const _BattleStartOverlay();

  @override
  State<_BattleStartOverlay> createState() => _BattleStartOverlayState();
}

class _BattleStartOverlayState extends State<_BattleStartOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        final t = Curves.easeOutBack.transform(_c.value);
        return Material(
          color: Colors.black.withValues(alpha: 0.62 * _c.value),
          child: Center(
            child: Transform.scale(
              scale: 0.5 + t * 0.5,
              // ⚠️ easeOutBack 은 1.0 을 넘긴다 — Opacity 에 그대로 주면
              // 단언에 걸려 빨간 오류 화면이 뜬다(아레나에서 겪은 것).
              child: Opacity(
                opacity: _c.value.clamp(0.0, 1.0),
                child: Text(
                  l.battleStarting,
                  style: const TextStyle(
                    color: _honey,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    shadows: [
                      Shadow(color: Colors.black, blurRadius: 10),
                      Shadow(color: Color(0xAAEBA52F), blurRadius: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 로컬 결투의 판별 승패를 기록한다(끝날 때 진 곤충만 부상을 걸려고).
class _RecordingLocalDriver implements DuelDriver {
  _RecordingLocalDriver(this._inner, {required this.onBout});

  final LocalDuelDriver _inner;
  final void Function(int index, bool won) onBout;
  int _i = 0;

  @override
  bool get interactive => _inner.interactive;

  @override
  String? get error => _inner.error;

  @override
  Future<DuelStep?> next(double launch) async {
    final s = await _inner.next(launch);
    if (s != null) onBout(_i++, s.bout.aWon);
    return s;
  }
}

/// 상대 후보 한 명(서버 제안의 한 칸, 또는 개발 실행의 로컬 상대).
class _Candidate {
  const _Candidate({
    required this.index,
    required this.nickname,
    required this.points,
    required this.power,
    required this.team,
    this.userId,
    this.rank,
    this.teamPowerOverride,
    this.localFoe,
  });

  factory _Candidate.fromServer(Map<String, dynamic> m) => _Candidate(
    index: (m['i'] as num).toInt(),
    userId: m['userId']?.toString(),
    nickname: '${m['nickname'] ?? ''}',
    rank: (m['rank'] as num?)?.toInt(),
    points: (m['points'] as num?)?.toInt() ?? 1,
    power: (m['power'] as num?)?.toDouble() ?? 0,
    teamPowerOverride: (m['teamPower'] as num?)?.toDouble(),
    team: [
      for (final t in (m['team'] as List? ?? const []))
        (
          sp: '${(t as Map)['sp']}',
          element: Element.values
              .where((e) => e.name == t['element'])
              .firstOrNull,
          power: (t['power'] as num?)?.toDouble() ?? 0,
          skin: t['skin']?.toString(),
          bug: t['bug'] is Map
              ? DuelBug.fromJson(Map<String, dynamic>.from(t['bug'] as Map))
              : null,
        ),
    ],
  );

  /// 제안 안의 칸 번호(`/duel/start` 의 pick).
  final int index;
  final String? userId;

  /// 빈 문자열 = 야생.
  final String nickname;
  final int? rank;

  /// 이기면 받는 점수(지면 0).
  final int points;

  /// 순위표 전투력(야생이면 팀 전투력).
  final double power;
  final double? teamPowerOverride;
  final List<
    ({String sp, Element? element, double power, String? skin, DuelBug? bug})
  >
  team;

  /// 개발 실행(서버 없음)에서 쓰는 상대 팀.
  final List<DuelBug>? localFoe;

  /// 내 팀과 견줄 전투력 — 곤충 3마리 합.
  double get teamPower =>
      teamPowerOverride ?? team.fold<double>(0, (a, t) => a + t.power);
}

/// 앱바 제목 옆 — 지금 리그 · 남은 시간(집계 중이면 마감까지, 정산 기간이면 새 시즌까지). 누르면 리그 보상.
class _LeagueClock extends StatefulWidget {
  const _LeagueClock({
    required this.league,
    required this.cfg,
    required this.onTap,
  });

  final String league;
  final BattleConfig cfg;
  final VoidCallback onTap;

  @override
  State<_LeagueClock> createState() => _LeagueClockState();
}

class _LeagueClockState extends State<_LeagueClock> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final now = DateTime.now().toUtc();
    final closed = seasonClosed(now, widget.cfg);
    var left =
        (closed ? seasonEndAt(now, widget.cfg) : seasonCloseAt(now, widget.cfg))
            .difference(now);
    if (left.isNegative) left = Duration.zero;
    final d = left.inDays, h = left.inHours % 24, m = left.inMinutes % 60;
    final time = d > 0 ? l.boardTimeLeftDays(d, h, m) : l.boardTimeLeft(h, m);
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: widget.onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1812),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0x66EBA52F)),
        ),
        child: Row(
          children: [
            leagueIcon(widget.league, size: 32),
            const SizedBox(width: 6),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  l.boardLeagueTitle(leagueName(l, widget.league)),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const Spacer(),
            const SizedBox(width: 8),
            const Icon(
              Icons.card_giftcard_rounded,
              color: Color(0xFFFF6B6B),
              size: 17,
            ),
            const SizedBox(width: 3),
            Text(
              time,
              style: TextStyle(
                color: closed ? const Color(0xFF6CFF6C) : Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
