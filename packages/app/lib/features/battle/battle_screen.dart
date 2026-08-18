import 'dart:async';
import 'dart:math' as math;

import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:flutter/material.dart' hide Element;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/game_data.dart';
import '../../domain/audio_service.dart';
import '../../domain/game_server.dart';
import '../../domain/providers.dart';
import '../../domain/pvp_backend.dart';
import '../../domain/save_controller.dart';
import 'package:core_save/core_save.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/ad_gate.dart';
import '../../ui/art.dart';
import '../../ui/format.dart';
import '../../ui/game_dialog.dart';
import '../../ui/labels.dart';
import 'arena_widgets.dart';
import '../../ui/skins.dart';
import 'battle_arena.dart';
import 'manual_battle_screen.dart';
import 'manual_driver.dart';
import '../../ui/toast.dart';
import '../../domain/server_sync.dart';

const _honey = Color(0xFFEBA52F);

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
      TicketCharge.adLimit => l.adDailyLimit(cfg.ticketAdDailyLimit),
      TicketCharge.notEnoughJelly => l.notEnoughJelly,
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 9),
        decoration: BoxDecoration(
          color: const Color(0x22000000),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: empty ? const Color(0x66C1502E) : const Color(0x33FFFFFF),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Text('⚔️', style: TextStyle(fontSize: 15)),
                const SizedBox(width: 5),
                Text(
                  l.pvpTicketTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  l.pvpTicketCount(tickets, cfg.ticketMax),
                  style: TextStyle(
                    color: empty
                        ? const Color(0xFFE07A5F)
                        : const Color(0xFFBFE3A6),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                Text(
                  left == null
                      ? l.pvpTicketFullLabel
                      : l.pvpTicketNextIn(formatClock(left)),
                  style: const TextStyle(
                    color: Color(0x99FFFFFF),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(
                  child: _chargeBtn(
                    // 광고제거·패스는 광고를 건너뛰고 즉시 받는다(ad_gate).
                    '📺 ${l.pvpTicketAdBtn(cfg.ticketAdGrant)}',
                    l.pvpTicketAdLeft(adUsed, cfg.ticketAdDailyLimit),
                    const Color(0xFF3E7D4F),
                    () => _watchAd(l),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _chargeBtn(
                    l.pvpTicketJellyBtn(cfg.ticketRefillJelly),
                    null,
                    const Color(0xFF3F5E86),
                    () => _refill(l),
                  ),
                ),
              ],
            ),
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
    Future<void> Function() onTap,
  ) => FilledButton(
    onPressed: _busy ? null : () => onTap(),
    style: FilledButton.styleFrom(
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(vertical: 7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
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

/// 스카우트된 상대 후보 1팀(난이도 티어 + 상대 3마리 + 전투 장소).
/// [ownerName] 이 있으면 **실제 다른 유저**의 방어팀, null 이면 로컬 합성 상대.
/// [location] = 상대 리드 곤충의 오행(그 오행 곤충이 강화되는 장소, §장소 상성).
class _Scout {
  _Scout({
    required this.tier,
    required this.team,
    required this.location,
    this.ownerName,
    this.ownerId,
  });
  final ScoutTier tier;
  final List<({BattleBug bug, String speciesId})> team;
  final Element location;
  final String? ownerName;

  /// 실제 유저 상대의 계정 id. 있으면 **서버가 전투를 확정**할 수 있다.
  /// null 이면 로컬 합성 상대(야생) — 아직 로컬 계산이다(P3 에서 서버 이관).
  final String? ownerId;
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

  List<_Scout> _scouts = [];
  int _selectedScout = 1; // 기본 '대등' 티어
  bool _manual = true; // 전투 모드 토글(수동/자동), 기본 수동(심리전)
  bool _scoutsFetched = false; // 실 유저 방어팀 fetch 를 이번 세션에 시도했는지
  String? _registeredSig; // 마지막으로 등록한 방어팀 시그니처(중복 업서트 방지)

  /// 직전 서버 전투 요청이 **티켓 부족**으로 거절됐는지.
  /// 이 경우 낙관 차감분을 되돌리면 안 된다(서버 잔량으로 이미 맞췄다).
  bool _lastRejectedForTickets = false;

  double _power(BattleBug b) => b.atk + b.def + b.spd + b.maxHp * 0.15;

  PvpProfile _me(SaveGame save) =>
      PvpProfile(id: 'me', nickname: save.nickname, trophies: save.pvpTrophies);

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
  BattleBug _toBattleBug(IndividualBug bug, GameData data, String locale) {
    final enh = data.enhanceConfig;
    final pet = data.petConfig;
    double per(BugPart p, double d) => enh?.spec(p).effectPerLevel ?? d;
    return buildBattleBug(
      bug: bug,
      species: data.species(bug.speciesId),
      locale: locale,
      hornJawPerLevel: per(BugPart.hornJaw, 0.04),
      cuticlePerLevel: per(BugPart.cuticle, 0.04),
      wingPerLevel: per(BugPart.wing, 0.03),
      buildPerLevel: per(BugPart.build, 0.05),
      // 혈통 특성(§2.5)은 전투에도 실린다. 배율은 `traitBattleScale` —
      // 서버(`GameActions._buildTeam`)와 **같은 값**이어야 승패가 안 갈린다.
      traitAtkBonus: pet?.traitBattleAtk(bug.trait) ?? 0,
      traitHpBonus: pet?.traitBattleHp(bug.trait) ?? 0,
    );
  }

  /// 로스터 파워 상위 3마리의 평균 스탯(스카우트 상대 스케일 기준). 성충 없으면 null.
  ({double hp, double atk, double def, double spd})? _rosterAvg(
    List<IndividualBug> adults,
    GameData data,
    String locale,
  ) {
    if (adults.isEmpty) return null;
    final bb = adults.map((b) => _toBattleBug(b, data, locale)).toList()
      ..sort((a, b) => _power(b).compareTo(_power(a)));
    final top = bb.take(3).toList();
    final n = top.length;
    return (
      hp: top.fold(0.0, (s, b) => s + b.maxHp) / n,
      atk: top.fold(0.0, (s, b) => s + b.atk) / n,
      def: top.fold(0.0, (s, b) => s + b.def) / n,
      spd: top.fold(0.0, (s, b) => s + b.spd) / n,
    );
  }

  /// 기준 평균 × [powerMult] 로 상대 3마리 생성. [salt] 로 id 충돌 방지.
  List<({BattleBug bug, String speciesId})> _genFoeTeam(
    ({double hp, double atk, double def, double spd}) avg,
    double powerMult,
    GameData data,
    String locale,
    int salt,
  ) {
    final species = data.allSpecies;
    return List.generate(3, (i) {
      final sp = species[_rng.nextInt(species.length)];
      final f = (0.9 + _rng.nextDouble() * 0.2) * powerMult;
      return (
        speciesId: sp.id,
        bug: BattleBug(
          id: 'opp${salt}_$i',
          name: sp.name.resolve(locale),
          element: Element.values[_rng.nextInt(Element.values.length)],
          temperament:
              Temperament.values[_rng.nextInt(Temperament.values.length)],
          preferredStance: preferredStanceOf(sp.specialty),
          maxHp: avg.hp * f,
          atk: avg.atk * f,
          def: avg.def * f,
          spd: avg.spd * f,
        ),
      );
    });
  }

  /// 팀·티어 → 스카우트(장소 = 리드 곤충 오행).
  _Scout _scoutOf(
    ScoutTier tier,
    List<({BattleBug bug, String speciesId})> team, {
    String? owner,
    String? ownerId,
  }) => _Scout(
    tier: tier,
    team: team,
    location: team.first.bug.element,
    ownerName: owner,
    ownerId: ownerId,
  );

  /// 스카우트 보드 갱신(난이도 티어별 상대 1팀씩).
  void _rollScouts(
    GameData data,
    String locale,
    ({double hp, double atk, double def, double spd}) avg,
  ) {
    final cfg = data.battleConfig ?? const BattleConfig();
    _scouts = [
      for (var i = 0; i < cfg.scoutTiers.length; i++)
        _scoutOf(
          cfg.scoutTiers[i],
          _genFoeTeam(avg, cfg.scoutTiers[i].powerMult, data, locale, i),
        ),
    ];
    if (_selectedScout >= _scouts.length) _selectedScout = _scouts.length ~/ 2;
  }

  Species? _speciesOrNull(GameData data, String id) {
    try {
      return data.species(id);
    } catch (_) {
      return null;
    }
  }

  double _teamPower(Iterable<BattleBug> team) {
    if (team.isEmpty) return 0;
    return team.map(_power).reduce((a, b) => a + b) / team.length;
  }

  /// 방어팀 스냅샷([dt]) → 전투용 팀. 종을 못 찾으면(데이터 변경) null 로 스킵.
  List<({BattleBug bug, String speciesId})>? _defenderTeam(
    DefenderTeam dt,
    GameData data,
    String locale,
    int salt,
  ) {
    final out = <({BattleBug bug, String speciesId})>[];
    for (var i = 0; i < dt.bugs.length; i++) {
      final d = dt.bugs[i];
      final sp = _speciesOrNull(data, d.speciesId);
      if (sp == null) return null;
      out.add((
        speciesId: d.speciesId,
        bug: BattleBug(
          id: 'def${salt}_$i',
          name: sp.name.resolve(locale),
          element: d.element,
          temperament: d.temperament,
          preferredStance: preferredStanceOf(sp.specialty),
          maxHp: d.maxHp,
          atk: d.atk,
          def: d.def,
          spd: d.spd,
        ),
      ));
    }
    return out.isEmpty ? null : out;
  }

  /// 내 편성([_team]) → 방어팀 스냅샷(서버 등록용).
  DefenderBug _defenderBugOf(IndividualBug bug, GameData data, String locale) {
    final bb = _toBattleBug(bug, data, locale);
    return DefenderBug(
      speciesId: bug.speciesId,
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
    final sig = '${ids.join(',')}|${save.pvpTrophies}';
    if (sig == _registeredSig) return;
    _registeredSig = sig;
    final team = [
      for (final id in ids)
        _defenderBugOf(save.bugs.firstWhere((b) => b.id == id), data, locale),
    ];
    ref.read(pvpBackendProvider).registerDefender(me: _me(save), team: team);
  }

  /// [ratio] 에 powerMult 가 가장 가까운 **빈** 티어 슬롯 index. 없으면 -1.
  int _closestFreeTier(
    double ratio,
    List<_Scout?> slots,
    List<ScoutTier> tiers,
  ) {
    var best = -1;
    var bestD = double.infinity;
    for (var i = 0; i < tiers.length; i++) {
      if (slots[i] != null) continue;
      final d = (tiers[i].powerMult - ratio).abs();
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    return best;
  }

  /// 실 유저 방어팀을 fetch 해 스카우트 보드에 병합.
  /// 각 방어팀을 내 로스터 대비 파워 비율로 난이도 티어에 배치하고,
  /// 남는 티어는 로컬 합성 상대로 채운다(실데이터가 없으면 전부 합성 유지).
  Future<void> _fetchRealScouts(
    GameData data,
    String locale,
    ({double hp, double atk, double def, double spd}) avg,
    SaveGame save,
  ) async {
    final backend = ref.read(pvpBackendProvider);
    final cfg = data.battleConfig ?? const BattleConfig();
    final tiers = cfg.scoutTiers;
    final reals = await backend.fetchOpponents(
      me: _me(save),
      count: tiers.length,
    );
    if (!mounted || reals.isEmpty) return;

    final myPower = avg.atk + avg.def + avg.spd + avg.hp * 0.15;
    // 실 방어팀 → (전투팀, 파워비율). 종을 못 찾으면 스킵.
    final built =
        <
          ({
            List<({BattleBug bug, String speciesId})> team,
            double ratio,
            String owner,
            String ownerId,
          })
        >[];
    for (var r = 0; r < reals.length; r++) {
      final team = _defenderTeam(reals[r], data, locale, r);
      if (team == null) continue;
      final ratio =
          _teamPower(team.map((e) => e.bug)) / (myPower <= 0 ? 1 : myPower);
      built.add((
        team: team,
        ratio: ratio,
        owner: reals[r].ownerName,
        ownerId: reals[r].ownerId,
      ));
    }
    if (built.isEmpty) return;

    // 파워 낮은 순으로 가장 가까운 빈 티어에 배치(약→easy, 강→hard 경향).
    built.sort((a, b) => a.ratio.compareTo(b.ratio));
    final slots = List<_Scout?>.filled(tiers.length, null);
    for (final b in built) {
      final idx = _closestFreeTier(b.ratio, slots, tiers);
      if (idx < 0) break;
      slots[idx] = _scoutOf(
        tiers[idx],
        b.team,
        owner: b.owner,
        ownerId: b.ownerId,
      );
    }
    // 빈 티어는 로컬 합성 상대로 채움.
    for (var i = 0; i < tiers.length; i++) {
      slots[i] ??= _scoutOf(
        tiers[i],
        _genFoeTeam(avg, tiers[i].powerMult, data, locale, 100 + i),
      );
    }
    setState(() {
      _scouts = [for (final s in slots) s!];
      if (_selectedScout >= _scouts.length) {
        _selectedScout = _scouts.length ~/ 2;
      }
    });
  }

  /// 티어 id → 현지화 라벨/색.
  (String, Color) _tierStyle(AppLocalizations l, String id) => switch (id) {
    'easy' => (l.scoutEasy, const Color(0xFF6FCF6F)),
    'even' => (l.scoutEven, const Color(0xFFE9D9A6)),
    'hard' => (l.scoutHard, const Color(0xFFEF6B4A)),
    _ => (id, const Color(0xFFBFC4CC)),
  };

  /// 리그 id → 현지화 라벨·색·엠블럼.
  (String, Color, String) _leagueStyle(AppLocalizations l, String id) =>
      switch (id) {
        'bronze' => (l.leagueBronze, const Color(0xFFB87333), '🥉'),
        'silver' => (l.leagueSilver, const Color(0xFFB8C4CE), '🥈'),
        'gold' => (l.leagueGold, const Color(0xFFEBC24A), '🥇'),
        'platinum' => (l.leaguePlatinum, const Color(0xFF5FD3C8), '💠'),
        'diamond' => (l.leagueDiamond, const Color(0xFF6FA8FF), '💎'),
        _ => (id, const Color(0xFFBFC4CC), '🏅'),
      };

  /// 시즌 종료까지 남은 시간 표기(일 포함). "13d 04:22" / "04:22".
  String _seasonLeft(Duration d) {
    if (d.isNegative) d = Duration.zero;
    final days = d.inDays;
    final h = d.inHours % 24;
    final m = d.inMinutes % 60;
    final hm =
        '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    return days > 0 ? '${days}d $hm' : hm;
  }

  /// 리그 패널 — 현재 등급 엠블럼·트로피·다음 티어 진행바·시즌 카운트다운·승급 보상 수령.
  Widget _leaguePanel(
    AppLocalizations l,
    BattleConfig cfg,
    SaveGame save,
    DateTime now,
  ) {
    final trophies = save.pvpTrophies;
    final cur = cfg.leagueFor(trophies);
    final next = cfg.nextLeagueAfter(cur);
    final progress = cfg.leagueProgress(trophies);
    final claimable = cfg.claimableLeagues(trophies, save.claimedLeagues);
    final (label, color, emoji) = _leagueStyle(l, cur.id);
    // 시즌 종료 = 다음 리셋(요일·시각 앵커). 모든 유저가 같은 순간에 끝난다.
    final seasonRemaining = seasonEndAt(now, cfg).difference(now);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0x22000000),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              leagueIcon(cur.id, size: 26),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Text(
                '$trophies',
                style: const TextStyle(
                  color: _honey,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: const Color(0x33000000),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 5),
          // ⚠️ 예전엔 "시즌 종료"와 "다음 리그까지"를 **한 줄에** 넣고 둘 다
          // `Flexible`+생략 처리했다. 그래서 "실버까지 7..." 처럼 정작 중요한
          // 숫자가 잘렸다(실기 지적). 각자 한 줄씩 준다.
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              next == null
                  ? l.leagueMaxRank
                  : l.leagueToNext(
                      next.minTrophy - trophies,
                      _leagueStyle(l, next.id).$1,
                    ),
              style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 12),
            ),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              const Icon(
                Icons.hourglass_bottom_rounded,
                size: 12,
                color: Color(0x99FFFFFF),
              ),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  l.seasonEndsIn(_seasonLeft(seasonRemaining)),
                  style: const TextStyle(
                    color: Color(0x99FFFFFF),
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // **보상이 무엇인지 화면에 없었다**(실기 지적). 승급 보상은 리그마다
          // 다르고 계정당 1회뿐이라(§2.6), 목록으로 보여야 목표가 생긴다.
          _leagueRewardList(l, cfg, save, trophies),
          if (claimable.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: FilledButton.icon(
                onPressed: () => _claimLeague(l),
                icon: const Icon(Icons.military_tech_rounded, size: 18),
                label: Text(
                  l.leagueClaimReward,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF3E7D4F),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 리그별 승급 보상 목록 — 받은 것/받을 수 있는 것/아직 먼 것을 한눈에.
  ///
  /// 승급 보상은 **계정당 1회**다(§2.6 — `claimedLeagues` 는 시즌 리셋에서
  /// 초기화되지 않는다). 그래서 "이번 시즌에 또 받는 것"으로 오해하지 않게
  /// 받은 리그는 확실히 지워 표시한다.
  Widget _leagueRewardList(
    AppLocalizations l,
    BattleConfig cfg,
    SaveGame save,
    int trophies,
  ) {
    final rows = <Widget>[];
    final here = cfg.leagueFor(trophies);
    // **위에서 아래로 다이아 → 실버.** 목표가 위에 있어야 "저기까지 가자"가 된다
    // (실기 지적). 오름차순이면 이미 지난 리그부터 읽게 된다.
    for (final lg in cfg.leagues.reversed) {
      if (!lg.hasReward) continue; // 브론즈는 시작 리그라 보상이 없다
      final claimed = save.claimedLeagues.contains(lg.id);
      final reached = trophies >= lg.minTrophy;
      final canClaim = reached && !claimed;
      final isHere = lg.id == here.id;
      final (name, color, _) = _leagueStyle(l, lg.id);
      rows.add(
        Container(
          margin: const EdgeInsets.symmetric(vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          decoration: isHere
              // 지금 내 리그 — 목록에서 **내 위치**가 보여야 남은 거리가 읽힌다.
              ? BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: color.withValues(alpha: 0.6)),
                )
              : null,
          child: Opacity(
            opacity: reached ? 1 : 0.5,
            // ⚠️ 예전엔 한 Row 에 아이콘·이름·트로피·골드·젤리·상태를 전부
            // 넣어서 좁은 화면에서 **넘쳤다**(실기 지적). 이름/트로피는 왼쪽에서
            // 줄어들 수 있게 Expanded 로 감싸고, 보상은 Wrap 으로 흘린다.
            child: Row(
              children: [
                leagueIcon(lg.id, size: 17),
                const SizedBox(width: 5),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: color,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        l.leagueNeedTrophy(lg.minTrophy),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0x99FFFFFF),
                          fontSize: 9.5,
                        ),
                      ),
                    ],
                  ),
                ),
                goldIcon(size: 12),
                const SizedBox(width: 2),
                Text(
                  formatCompact(lg.rewardGold),
                  style: const TextStyle(
                    color: Color(0xFFEBD24A),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (lg.rewardJelly > 0) ...[
                  const SizedBox(width: 6),
                  materialImage(
                    MaterialKind.jelly,
                    size: 12,
                    fallback: const SizedBox(width: 12),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${lg.rewardJelly}',
                    style: const TextStyle(
                      color: Color(0xFF9BE7FF),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
                const SizedBox(width: 4),
                claimed
                    ? const Icon(
                        Icons.check_circle_rounded,
                        size: 13,
                        color: Color(0xFF7CE38B),
                      )
                    : (canClaim
                          ? const Icon(
                              Icons.card_giftcard_rounded,
                              size: 13,
                              color: Color(0xFFEBC24A),
                            )
                          : const Icon(
                              Icons.lock_rounded,
                              size: 11,
                              color: Color(0x66FFFFFF),
                            )),
              ],
            ),
          ),
        ),
      );
    }
    // 보상은 **두 종류**다. 화면에 하나(최초 달성)만 있어서 "브론즈면 아무것도
    // 못 받나?"로 읽혔다(실기 지적) — 실은 시즌 종료 보상이 매주 나온다.
    final season = cfg.seasonReward(trophies);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x18000000),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ① 매주 나오는 것 — 지금 내 등급 기준이라 "지금 끝나면 얼마"가 보인다.
          Row(
            children: [
              const Icon(
                Icons.event_repeat_rounded,
                size: 14,
                color: Color(0xFF7CE38B),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  l.seasonRewardNow(_leagueStyle(l, here.id).$1),
                  style: const TextStyle(
                    color: Color(0xFF7CE38B),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              goldIcon(size: 13),
              const SizedBox(width: 2),
              Text(
                formatCompact(season.gold),
                style: const TextStyle(
                  color: Color(0xFFEBD24A),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (season.jelly > 0) ...[
                const SizedBox(width: 6),
                materialImage(
                  MaterialKind.jelly,
                  size: 13,
                  fallback: const SizedBox(width: 13),
                ),
                const SizedBox(width: 2),
                Text(
                  '${season.jelly}',
                  style: const TextStyle(
                    color: Color(0xFF9BE7FF),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 3),
          Text(
            l.seasonRewardHint,
            style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 10),
          ),
          const Divider(color: Color(0x22FFFFFF), height: 14),
          // ② 처음 그 리그에 닿았을 때 한 번 — 목표판이다.
          Text(
            l.leagueRewardListTitle,
            style: const TextStyle(
              color: Color(0xCCFFFFFF),
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          ...rows,
        ],
      ),
    );
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
      icon: Icons.military_tech_rounded,
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
      icon: Icons.workspace_premium_rounded,
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
              '💰 ${formatCompact(r.rewardGold)}    💎 ${r.rewardJelly}',
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
            (a, b) => _power(
              _toBattleBug(b, data, locale),
            ).compareTo(_power(_toBattleBug(a, data, locale))),
          );
      for (var i = 0; i < 3 && i < sorted.length; i++) {
        _team[i] = sorted[i].id;
      }
    }
    // 사라진(진화/분해) · 부상당한 곤충은 편성에서 자동 제외.
    final adultIds = adults.map((b) => b.id).toSet();
    _team = [
      for (final id in _team)
        (id != null && adultIds.contains(id) && !save.isInjured(id, now))
            ? id
            : null,
    ];

    final teamCount = _team.whereType<String>().length;

    // 스카우트 보드: 로스터가 있으면 합성 상대로 즉시 채우고(빈 보드 방지),
    // 실 유저 방어팀은 비동기로 fetch 해 병합(있으면 교체).
    final battleCfg = data.battleConfig ?? const BattleConfig();
    final avg = _rosterAvg(adults, data, locale);
    if (avg != null && _scouts.isEmpty) _rollScouts(data, locale, avg);
    if (avg != null && !_scoutsFetched) {
      _scoutsFetched = true;
      _fetchRealScouts(data, locale, avg, save);
    }
    // 현재 편성을 내 방어팀으로 등록(다른 유저가 나를 상대하게).
    _maybeRegisterDefender(data, save, locale);
    final canBattle = teamCount > 0 && _scouts.isNotEmpty;

    // 시즌 종료 정산(로드 시 계산됨) → 1회 다이얼로그.
    final notifier = ref.read(saveControllerProvider.notifier);
    final season = notifier.pendingSeason;
    if (season != null) {
      notifier.consumeSeason();
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showSeasonEnd(season),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l.battleTitle),
        actions: [
          // 이모지는 기기 폰트마다 모양이 달라 앱바처럼 작은 자리에서 안 읽힌다.
          Center(
            child: Row(
              children: [
                stanceArt(Stance.attack, size: 15),
                const SizedBox(width: 4),
                Text(
                  '${ref.read(saveControllerProvider.notifier).ticketsNow}'
                  '/${battleCfg.ticketMax}',
                  style: const TextStyle(
                    color: Color(0xFFBFE3A6),
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Center(
              child: Row(
                children: [
                  leagueIcon(
                    battleCfg.leagueFor(save.pvpTrophies).id,
                    size: 17,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${save.pvpTrophies}',
                    style: const TextStyle(
                      color: _honey,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: adults.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  l.battleNeedBugs,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xB3FFFFFF)),
                ),
              ),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  // **무대가 먼저 온다.** 예전엔 리그·티켓·설정 카드가 줄줄이
                  // 먼저 나오고 상대는 한참 아래에 있어서, 결투 탭이 전투가
                  // 아니라 설정 화면처럼 읽혔다(실기: "끌리는 게 없다").
                  _matchupBanner(l, data, battleCfg, save, locale),
                  const SizedBox(height: 10),
                  _leagueStrip(l, battleCfg, save, now),
                  const SizedBox(height: 8),
                  const TicketBar(),
                  const SizedBox(height: 12),
                  _matchupCard(l, data, battleCfg, save, locale),
                  const SizedBox(height: 14),
                  // ── 상대 고르기(스카우트) ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.travel_explore_rounded,
                          color: _honey,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          l.opponentPick,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: avg == null
                              ? null
                              : () async {
                                  // 광고가 없어진 대신 **하루 상한**을 건다.
                                  // 예전엔 광고 시청 30초가 비용이었는데, 공짜
                                  // 무제한이면 제일 약한 상대가 나올 때까지
                                  // 무한 리롤하게 된다.
                                  if (!await _takeFreeRefresh(l)) return;
                                  if (!mounted) return;
                                  setState(
                                    () => _rollScouts(data, locale, avg),
                                  );
                                  _fetchRealScouts(data, locale, avg, save);
                                },
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: Text(l.scoutRefresh),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFE9D9A6),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      // 스크롤(높이 무한) 안이라 stretch 금지 — 대신 카드 내용이
                      // 항상 같은 줄 수(닉네임/'야생' 한 줄)라 높이가 맞는다.
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < _scouts.length; i++)
                          Expanded(
                            child: _scoutCard(l, data, battleCfg, save, i),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _modeToggle(l),
                  // 결투 버튼은 하단 고정이라 여기선 자리만 비운다.
                  const SizedBox(height: 20),
                ],
              ),
            ),
      // 결투 버튼은 **항상 보인다.** 스크롤 끝에 있으면 상대를 고른 뒤 또
      // 내려야 해서, 정작 이 화면에서 제일 중요한 행동이 화면 밖에 있었다.
      bottomNavigationBar: adults.isEmpty
          ? null
          : _battleBar(l, data, save, locale, canBattle),
    );
  }

  /// 매치업 무대 — 내 팀과 상대 팀이 **실제로 마주 선 그림**.
  ///
  /// 예전엔 팀 편성도 상대도 회색 카드 안의 목록이라, 누구와 싸우는지가
  /// 정보로만 있고 장면으로는 없었다.
  Widget _matchupBanner(
    AppLocalizations l,
    GameData data,
    BattleConfig cfg,
    SaveGame save,
    String locale,
  ) {
    final scout = (_scouts.isNotEmpty && _selectedScout < _scouts.length)
        ? _scouts[_selectedScout]
        : null;
    final mine = [
      for (final id in _team.whereType<String>())
        save.bugs.cast<IndividualBug?>().firstWhere(
          (b) => b!.id == id,
          orElse: () => null,
        ),
    ].whereType<IndividualBug>().toList();
    return Container(
      height: 168,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _honey.withValues(alpha: 0.45)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: scout == null
                ? const ColoredBox(color: Color(0xFF1E3B28))
                : biomeBackground(
                    scout.location,
                    fallback: const ColoredBox(color: Color(0xFF1E3B28)),
                  ),
          ),
          // 그림 위에 글자가 얹히므로 어둡게 깔아 준다.
          const Positioned.fill(child: ColoredBox(color: Color(0x66000000))),
          // 두 팀을 **같은 선 위에 같은 크기로** 세운다(아레나와 같은 규칙).
          // 원근을 주면 크기가 전력 차이로 오해된다.
          Positioned(
            left: 10,
            right: 10,
            bottom: 10,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final b in mine.take(3))
                  Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: bugStageImage(
                      b.speciesId,
                      LifeStage.adult,
                      size: 46,
                      fallback: const SizedBox(width: 46, height: 46),
                      skin: ref.read(skinOfProvider)(b.speciesId),
                    ),
                  ),
                const Spacer(),
                if (scout != null)
                  for (final e in scout.team.take(3))
                    Padding(
                      padding: const EdgeInsets.only(left: 2),
                      // 좌우 반전해 서로 마주 본다.
                      child: Transform.flip(
                        flipX: true,
                        child: bugStageImage(
                          e.speciesId,
                          LifeStage.adult,
                          size: 46,
                          fallback: const SizedBox(width: 46, height: 46),
                        ),
                      ),
                    ),
              ],
            ),
          ),
          // 내 전투력(왼쪽 위) / 상대(오른쪽 아래) — 비교가 이 화면의 핵심이다.
          Positioned(
            left: 10,
            top: 8,
            child: _powerTag(
              l.sideMineTeam,
              formatCompact(_myTeamPowerSum(data, save, locale)),
              const Color(0xFF7CE38B),
            ),
          ),
          if (scout != null)
            Positioned(
              right: 10,
              top: 8,
              child: Row(
                children: [
                  if (scout.ownerName != null) ...[
                    Text(
                      _maskName(scout.ownerName!),
                      style: const TextStyle(
                        color: Color(0xCCE9D9A6),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 5),
                  ],
                  _powerTag(
                    l.sideFoeTeam,
                    formatCompact(
                      scout.team.fold<double>(0, (a, e) => a + _power(e.bug)),
                    ),
                    const Color(0xFFFF8A6B),
                  ),
                ],
              ),
            ),
          Center(
            child: Text(
              'VS',
              style: const TextStyle(
                color: arenaHoney,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                shadows: [
                  Shadow(color: Colors.black, blurRadius: 8),
                  Shadow(color: Color(0x99EBA52F), blurRadius: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 전투력 태그 — **누구 것인지**를 먼저 쓰고 숫자를 뒤에 둔다.
  /// 숫자만 있으면 둘 중 어느 쪽이 내 것인지 위치로 추측해야 했다(실기 지적).
  Widget _powerTag(String who, String power, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: const Color(0xB30E1408),
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: c.withValues(alpha: 0.7)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          who,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          power,
          style: TextStyle(
            color: c,
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );

  /// 오토/수동 전환만 남긴 줄(버튼은 하단 고정으로 갔다).
  Widget _modeToggle(AppLocalizations l) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24),
    child: Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0x22000000),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: Row(
        children: [
          _modeTab(
            l.modeManual,
            Icons.psychology_rounded,
            _manual,
            () => setState(() => _manual = true),
          ),
          _modeTab(
            l.modeAuto,
            Icons.fast_forward_rounded,
            !_manual,
            () => setState(() => _manual = false),
          ),
        ],
      ),
    ),
  );

  /// 하단 고정 결투 바.
  Widget _battleBar(
    AppLocalizations l,
    GameData data,
    SaveGame save,
    String locale,
    bool canBattle,
  ) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: SizedBox(
        height: 56,
        child: FilledButton.icon(
          onPressed: canBattle
              ? () {
                  final scout = _scouts[_selectedScout];
                  if (_manual) {
                    _battleManual(data, save, locale, scout);
                  } else {
                    _battle(data, save, locale, scout);
                  }
                }
              : null,
          icon: const Icon(Icons.sports_mma_rounded),
          label: Text(
            l.battleStart,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: _manual
                ? const Color(0xFFC1502E)
                : const Color(0xFF3E7D4F),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    ),
  );

  /// 스카우트 무료 새로고침 사용권(기기 단위, 하루 10회).
  ///
  /// 서버 소유 값이 아니어도 된다 — 새로고침은 상대 **선택**일 뿐이고 승패·보상
  /// 확정은 어차피 서버가 한다. 세이브 채택으로 초기화되지 않게 기기에 둔다.
  Future<bool> _takeFreeRefresh(AppLocalizations l) async {
    const cap = 10;
    final prefs = await SharedPreferences.getInstance();
    final now = ref.read(clockProvider).now().toUtc();
    final today = dailyDateKey(now);
    final parts = (prefs.getString('scout_refresh_v1') ?? '|').split('|');
    final used = parts[0] == today ? (int.tryParse(parts[1]) ?? 0) : 0;
    if (used >= cap) {
      if (mounted) showCenterToast(context, l.adDailyLimit(cap));
      return false;
    }
    await prefs.setString('scout_refresh_v1', '$today|${used + 1}');
    return true;
  }

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
          skin: ref.read(skinOfProvider)(bug.speciesId),
        ),
      ),
    ),
  );

  /// 리그·시즌 요약 스트립(한 줄). 탭하면 상세(진행바·승급 보상) 다이얼로그.
  Widget _leagueStrip(
    AppLocalizations l,
    BattleConfig cfg,
    SaveGame save,
    DateTime now,
  ) {
    final cur = cfg.leagueFor(save.pvpTrophies);
    final (label, color, emoji) = _leagueStyle(l, cur.id);
    final left = seasonEndAt(now, cfg).difference(now);
    final hasReward = cfg
        .claimableLeagues(save.pvpTrophies, save.claimedLeagues)
        .isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        color: const Color(0x22000000),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showLeagueDetail(l, cfg, save, now),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                leagueIcon(cur.id, size: 20),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '🏆${save.pvpTrophies}',
                  style: const TextStyle(
                    color: _honey,
                    fontWeight: FontWeight.w900,
                    fontSize: 12.5,
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.hourglass_bottom_rounded,
                  size: 11,
                  color: Color(0x99FFFFFF),
                ),
                const SizedBox(width: 3),
                Text(
                  l.seasonEndsIn(_seasonLeft(left)),
                  style: const TextStyle(
                    color: Color(0x99FFFFFF),
                    fontSize: 10.5,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  hasReward
                      ? Icons.card_giftcard_rounded
                      : Icons.chevron_right_rounded,
                  size: 16,
                  color: hasReward
                      ? const Color(0xFF6FCF6F)
                      : const Color(0x99FFFFFF),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showLeagueDetail(
    AppLocalizations l,
    BattleConfig cfg,
    SaveGame save,
    DateTime now,
  ) => showGameDialog<void>(
    context,
    title: l.leagueSeasonTitle,
    icon: Icons.emoji_events_rounded,
    content: _leaguePanel(l, cfg, save, now),
    actions: [gameDialogButton(l.actionClose, () => Navigator.pop(context))],
  );

  /// 상대(선택된 스카우트) 1마리 포트레이트 — 이미지 + 오행 글리프.
  Widget _oppPortrait(({BattleBug bug, String speciesId}) e) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 3),
    child: Column(
      children: [
        bugStageImage(
          e.speciesId,
          LifeStage.adult,
          size: 46,
          fallback: elementIcon(e.bug.element, size: 30),
        ),
        const SizedBox(height: 2),
        elementIcon(e.bug.element, size: 15),
      ],
    ),
  );

  /// 전투 장소 칩 — 장소 이모지·이름 + 상성(그 오행 곤충 강화).
  Widget _locationChip(AppLocalizations l, Element loc) => Center(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: elementColor(loc).withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: elementColor(loc).withValues(alpha: 0.5)),
      ),
      child: Text(
        '${biomeEmoji(loc)} ${biomeName(l, loc)} · ${l.locationAffinity(elementLabel(l, loc))}',
        style: TextStyle(
          color: elementColor(loc),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );

  /// VS 매치업 카드 — 내 팀(편성·드래그)과 선택 상대·상생·승리 보상.
  Widget _matchupCard(
    AppLocalizations l,
    GameData data,
    BattleConfig cfg,
    SaveGame save,
    String locale,
  ) {
    final scout = (_scouts.isNotEmpty && _selectedScout < _scouts.length)
        ? _scouts[_selectedScout]
        : null;
    final (tierLabel, tierColor) = scout != null
        ? _tierStyle(l, scout.tier.id)
        : ('', const Color(0xFFBFC4CC));
    final gold = scout != null
        ? cfg.winGold(save.pvpTrophies, scout.tier.rewardMult)
        : 0;
    final trophy = scout != null ? cfg.trophyOnWin(scout.tier.rewardMult) : 0;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0x22000000),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _honey.withValues(alpha: 0.45)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.groups_rounded, color: _honey, size: 16),
              const SizedBox(width: 5),
              Text(
                l.battleMyTeam,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 8),
              // 팀 전투력 — 편성을 바꿀 때마다 즉시 반영된다.
              Text(
                l.teamPower(formatCompact(_myTeamPowerSum(data, save, locale))),
                style: const TextStyle(
                  color: _honey,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _autoTeam(data, save, locale),
                icon: const Icon(Icons.auto_awesome, size: 14),
                label: Text(l.autoTeam, style: const TextStyle(fontSize: 11.5)),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFBFE3A6),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: const Size(0, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          Row(
            children: [
              const Icon(
                Icons.drag_indicator_rounded,
                color: Color(0x77FFFFFF),
                size: 13,
              ),
              const SizedBox(width: 2),
              Text(
                l.teamReorderHint,
                style: const TextStyle(color: Color(0x77FFFFFF), fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < 3; i++)
                Expanded(child: _teamSlot(data, save, locale, i)),
            ],
          ),
          const SizedBox(height: 6),
          _synergyBar(l, data, save, locale),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const Expanded(child: Divider(color: Color(0x33FFFFFF))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: const [
                      Icon(
                        Icons.sports_mma_rounded,
                        color: Color(0xFFEF6B4A),
                        size: 16,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'VS',
                        style: TextStyle(
                          color: Color(0xFFEF6B4A),
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Expanded(child: Divider(color: Color(0x33FFFFFF))),
              ],
            ),
          ),
          if (scout != null) ...[
            _locationChip(l, scout.location),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: tierColor.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    tierLabel,
                    style: TextStyle(
                      color: tierColor,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (scout.ownerName != null) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '👤 ${_maskName(scout.ownerName!)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xCCE9D9A6),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  '💰${formatCompact(gold)}  🏆+$trophy',
                  style: const TextStyle(
                    color: Color(0xFFEBD24A),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final e in scout.team) Expanded(child: _oppPortrait(e)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _modeTab(
    String label,
    IconData icon,
    bool selected,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? _honey : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected
                    ? const Color(0xFF3A2600)
                    : const Color(0x99FFFFFF),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? const Color(0xFF3A2600)
                      : const Color(0x99FFFFFF),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
    final card = GestureDetector(
      onTap: () => _showPicker(data, save, locale, index),
      child: Container(
        width: double.infinity, // 셀(1/3)을 꽉 채워 3슬롯 균등 정렬
        height: 150,
        decoration: BoxDecoration(
          color: const Color(0x22000000),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: bug == null ? const Color(0x33FFFFFF) : _honey,
            width: bug == null ? 1 : 1.6,
          ),
        ),
        child: bug == null
            ? const Center(
                child: Icon(
                  Icons.add_circle_outline,
                  color: Color(0x66FFFFFF),
                  size: 28,
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: bugStageImage(
                      bug.speciesId,
                      LifeStage.adult,
                      size: 60,
                      fallback: bugAvatar(sp!, size: 52),
                      skin: ref.watch(skinOfProvider)(bug.speciesId),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(bottom: 2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: elementColor(bug.element).withValues(alpha: 0.25),
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      sp.name.resolve(locale),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
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
        color: Color(0xFF3A2600),
        fontSize: 11,
        fontWeight: FontWeight.w900,
      ),
    ),
  );

  /// 편성 순서대로 오행 상생(生) 연결·팀 시너지% 미리보기.
  Widget _synergyBar(
    AppLocalizations l,
    GameData data,
    SaveGame save,
    String locale,
  ) {
    final mine = [
      for (final id in _team.whereType<String>())
        _toBattleBug(save.bugs.firstWhere((b) => b.id == id), data, locale),
    ];
    if (mine.length < 2) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          l.synergyHint,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0x77FFFFFF), fontSize: 10.5),
        ),
      );
    }
    final pct = ((teamSynergy(mine) - 1) * 100).round();
    final active = pct > 0;
    final color = active ? const Color(0xFF6FCF6F) : const Color(0xFFBFC4CC);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < mine.length; i++) ...[
          if (i > 0) _linkGlyph(mine[i - 1].element.generates(mine[i].element)),
          elementIcon(mine[i].element, size: 16),
        ],
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '${l.synergyLabel} ${active ? '+' : ''}$pct%',
            style: TextStyle(
              color: active ? const Color(0xFF6FCF6F) : const Color(0xCCFFFFFF),
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _linkGlyph(bool gen) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Text(
      gen ? '→' : '·',
      style: TextStyle(
        color: gen ? const Color(0xFF6FCF6F) : const Color(0x55FFFFFF),
        fontSize: gen ? 16 : 15,
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
                  constraints: const BoxConstraints(maxHeight: 340),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        // 강한 순으로 보여준다 — 고르려고 여는 화면이다.
                        for (final b in _byPower(data, save, locale, adults))
                          _pickTile(ctx, data, save, locale, now, b, slot),
                      ],
                    ),
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
    final until = save.injuredUntil(bug.id);
    final injured = until != null && now.isBefore(until);
    return Opacity(
      opacity: injured ? 0.45 : 1,
      child: GestureDetector(
        onTap: injured
            ? null
            : () {
                setState(() {
                  // 다른 슬롯에 이미 있으면 제거(중복 방지) 후 배치.
                  for (var i = 0; i < 3; i++) {
                    if (_team[i] == bug.id) _team[i] = null;
                  }
                  _team[slot] = bug.id;
                });
                Navigator.pop(ctx);
              },
        child: SizedBox(
          width: 84,
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
                bugStageImage(
                  bug.speciesId,
                  LifeStage.adult,
                  size: 44,
                  fallback: bugAvatar(sp, size: 38),
                  skin: ref.watch(skinOfProvider)(bug.speciesId),
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
                  '⚔ ${formatCompact(_power(_toBattleBug(bug, data, locale)))}',
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
      if (bug != null) sum += _power(_toBattleBug(bug, data, locale));
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
      final d = _power(
        _toBattleBug(b, data, locale),
      ).compareTo(_power(_toBattleBug(a, data, locale)));
      return d != 0 ? d : a.id.compareTo(b.id); // 동점이어도 순서가 흔들리지 않게
    });

  /// 자동 편성 — 부상이 아닌 성충 중 전투력 상위 3마리.
  ///
  /// 오행 상생(순서 보너스)까지 최적화하지는 않는다. 그건 플레이어가 직접
  /// 짜는 재미의 핵심이라(§2.3 "순서가 전략") 자동이 대신해버리면 안 된다.
  /// 여기서는 "일단 센 놈들로 채워주는" 역할만 한다.
  void _autoTeam(GameData data, SaveGame save, String locale) {
    final now = ref.read(clockProvider).now().toUtc();
    final pool = _byPower(data, save, locale, [
      for (final b in _adults(save, data, now))
        if (!save.isInjured(b.id, now)) b,
    ]);
    final picked = [for (final b in pool.take(3)) b.id];
    final l = AppLocalizations.of(context);
    final same =
        picked.length == _team.whereType<String>().length &&
        List.generate(
          picked.length,
          (i) => picked[i] == _team[i],
        ).every((x) => x);
    if (same) {
      showCenterToast(context, l.autoTeamAlready);
      return;
    }
    setState(() {
      _team = [
        for (var i = 0; i < 3; i++) i < picked.length ? picked[i] : null,
      ];
    });
    AudioService.instance.sfxReward();
    showCenterToast(context, l.autoTeamDone);
  }

  /// 편성된 팀 + 선택한 스카우트 상대 → 전투용 팀·표시용 종 맵·시드.
  ({
    List<BattleBug> mine,
    List<BattleBug> foe,
    Map<String, String> speciesOf,
    int seed,
  })
  _buildMatch(GameData data, SaveGame save, String locale, _Scout scout) {
    final speciesOf = <String, String>{};
    final mine = <BattleBug>[];
    for (final id in _team.whereType<String>()) {
      final bug = save.bugs.firstWhere((b) => b.id == id);
      speciesOf[bug.id] = bug.speciesId;
      mine.add(_toBattleBug(bug, data, locale));
    }
    final foe = <BattleBug>[];
    for (final e in scout.team) {
      speciesOf[e.bug.id] = e.speciesId;
      foe.add(e.bug);
    }
    return (
      mine: mine,
      foe: foe,
      speciesOf: speciesOf,
      seed: _rng.nextInt(1 << 31),
    );
  }

  Future<void> _applyReward(
    int gold,
    int trophyDelta,
    List<String> koedBugIds,
  ) async {
    await ref
        .read(saveControllerProvider.notifier)
        .applyBattleResult(
          gold: gold,
          trophyDelta: trophyDelta,
          koedBugIds: koedBugIds,
        );
    // 승패 반영 후 트로피를 백엔드에 즉시 push(비동기 대전 라이브).
    // 네트워크가 UI(아레나 전환)를 막지 않도록 fire-and-forget.
    final save = ref.read(saveControllerProvider).requireValue;
    unawaited(ref.read(pvpBackendProvider).pushTrophies(me: _me(save)));
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

  Future<bool> _serverBattle(
    GameData data,
    String locale,
    _Scout scout,
    // ↓ 아레나로 넘어가기 직전에 부른다("결투 시작!" 오버레이 닫기).
    ({
      List<BattleBug> mine,
      List<BattleBug> foe,
      Map<String, String> speciesOf,
      int seed,
    })
    m, {
    VoidCallback? onReady,
  }) async {
    final l = AppLocalizations.of(context);
    // 이번 요청의 결과로만 판단하도록 **매번 초기화**한다. 남겨두면 세이브
    // 업로드 실패(티켓과 무관)로 돌아왔을 때 직전의 '티켓 없음' 값이 남아
    // 낙관 차감한 티켓을 되돌리지 않는다 = 티켓 1장이 그냥 사라진다.
    _lastRejectedForTickets = false;
    // 전투 전 최신 세이브를 서버에 올린다 — 서버가 **최신 곤충·골드**로 전투를
    // 확정하고, 승패·보상을 그 위에 얹는다(기기 권위 진행이 묻히지 않게).
    // 업로드 실패 시 전투를 진행하지 않는다 — 낡은 세이브로 싸우고 adopt 하면
    // 최근 진행이 사라진다. 다음 주기 업로드가 따라잡은 뒤 다시 시도하면 된다.
    if (!await _flushSave()) {
      if (!mounted) return false;
      showCenterToast(context, l.battleServerFailed);
      return false;
    }
    final res = await ref
        .read(gameServerProvider)
        .battle(
          teamBugIds: [for (final b in m.mine) b.id],
          opponentUserId: scout.ownerId,
          tierId: scout.ownerId == null ? scout.tier.id : null,
        );
    if (!res.isOk || res.save == null) {
      final noTicket = await _syncTicketRejection(res);
      if (!mounted) return false;
      showCenterToast(
        context,
        noTicket ? l.pvpTicketNone : l.battleServerFailed,
      );
      return false;
    }

    await ref.read(saveControllerProvider.notifier).adoptServerSave(res.save!);
    if (!mounted) return false;

    // 서버가 준 시드로 같은 전투를 재현해 연출한다.
    //
    // 상대도 **서버가 준 것**을 쓴다. 야생은 서버가 만들기 때문에 앱이
    // 만든 상대로 재생하면 연출이 서버가 확정한 승패와 어긋난다.
    final cfg = data.battleConfig ?? const BattleConfig();
    final seed = (res.data!['seed'] as num?)?.toInt() ?? m.seed;
    final srvFoe = foeTeamFromServer(res.data!['foe']);
    final foe = srvFoe.isEmpty ? m.foe : [for (final e in srvFoe) e.bug];
    final speciesOf = {
      ...m.speciesOf,
      for (final e in srvFoe) e.bug.id: e.speciesId,
    };
    // 장소 = 상대 리드 곤충의 오행(서버와 같은 규칙).
    final location = foe.isEmpty ? scout.location : foe.first.element;
    final result = simulate(
      seed,
      m.mine,
      foe,
      location: location,
      locationBonus: cfg.locationAffinityBonus,
    );
    onReady?.call();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BattleArenaScreen(
          data: data,
          myTeam: m.mine,
          foeTeam: foe,
          speciesOf: speciesOf,
          result: result,
          gold: (res.data!['gold'] as num?)?.toInt() ?? 0,
          trophyDelta: (res.data!['trophyDelta'] as num?)?.toInt() ?? 0,
          location: location,
          skinOf: ref.read(skinOfProvider),
          arenaTheme: ref.read(arenaThemeOwnedProvider),
        ),
      ),
    );
    return true;
  }

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

  Future<void> _battle(
    GameData data,
    SaveGame save,
    String locale,
    _Scout scout,
  ) async {
    final l = AppLocalizations.of(context);
    final m = _buildMatch(data, save, locale, scout);
    if (m.mine.isEmpty) return;
    if (!await _takeTicket(l)) return;

    // 권위 서버가 붙어 있으면 **서버가 승패를 확정**한다.
    // 야생 상대도 서버가 만든다 — 앱이 만들면 약한 상대를 골라
    // 트로피를 쓸어담을 수 있다.
    final server = ref.read(gameServerProvider);
    if (server.available) {
      // 서버가 거부/불통이면 아래 로컬 경로로 폴백하지 않는다 —
      // 폴백하면 서버 권위가 무의미해진다. 알리고 끝내되, 싸우지도 못했으니
      // 낙관 차감한 티켓은 돌려준다(성공 시엔 서버 값이 덮어쓴다).
      // 단 "티켓 없음"으로 거절당한 경우는 _serverBattle 이 서버 잔량으로
      // 맞춰 놓았으므로 되돌리면 안 된다.
      final close = _showStartOverlay(l);
      try {
        final ok = await _serverBattle(data, locale, scout, m, onReady: close);
        if (!ok && !_lastRejectedForTickets) await _returnTicket();
      } finally {
        close();
      }
      return;
    }

    final cfg = data.battleConfig ?? const BattleConfig();
    final result = simulate(
      m.seed,
      m.mine,
      m.foe,
      location: scout.location,
      locationBonus: cfg.locationAffinityBonus,
    );
    final rw = pvpReward(
      won: result.outcome == BattleOutcome.teamA,
      draw: result.outcome == BattleOutcome.draw,
      trophies: save.pvpTrophies,
      cfg: cfg,
      rewardMult: scout.tier.rewardMult,
    );
    await _applyReward(
      rw.gold,
      rw.trophyDelta,
      koedTeamAIds(m.mine, result.events),
    );
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BattleArenaScreen(
          data: data,
          myTeam: m.mine,
          foeTeam: m.foe,
          speciesOf: m.speciesOf,
          result: result,
          gold: rw.gold,
          trophyDelta: rw.trophyDelta,
          location: scout.location,
          skinOf: ref.read(skinOfProvider),
          arenaTheme: ref.read(arenaThemeOwnedProvider),
        ),
      ),
    );
  }

  /// 수동 전투 — 심리전. 보상은 결착 후 적용(승패가 그때 결정).
  Future<void> _battleManual(
    GameData data,
    SaveGame save,
    String locale,
    _Scout scout,
  ) async {
    final l = AppLocalizations.of(context);
    final m = _buildMatch(data, save, locale, scout);
    if (m.mine.isEmpty) return;
    // 수동 전투도 **시작할 때** 한 장. 중간에 나가도 돌려주지 않는다
    // (돌려주면 불리한 판을 나가버리는 것으로 무한 재시도가 된다).
    if (!await _takeTicket(l)) return;

    // 수동도 서버 세션을 여는 동안 기다린다 — 오토와 같은 전환으로 덮는다.
    // 실패로 빠져나가는 길이 여럿이라 `try/finally` 로 반드시 닫는다.
    final closeStart = _showStartOverlay(l);
    try {
      // 권위 서버가 붙어 있으면 서버 세션이 매 수를 확정한다(야생 포함).
      ManualBattleDriver? driver;
      var foe = m.foe;
      var speciesOf = m.speciesOf;
      var location = scout.location;

      final server = ref.read(gameServerProvider);
      if (server.available) {
        // 전투 전 최신 세이브 업로드(기기 권위 진행이 묻히지 않게).
        // 실패 시 시작하지 않는다 — 낡은 세이브로 세션을 열면 진행이 사라진다.
        if (!await _flushSave()) {
          await _returnTicket();
          if (!mounted) return;
          showCenterToast(context, l.battleServerFailed);
          return;
        }
        final res = await server.startManualBattle(
          teamBugIds: [for (final b in m.mine) b.id],
          opponentUserId: scout.ownerId,
          tierId: scout.ownerId == null ? scout.tier.id : null,
        );
        if (!res.isOk || res.data?['sessionId'] == null) {
          // 서버가 "티켓 없음"이라 했으면 되돌리지 않는다 — 서버가 진실이다.
          final noTicket = await _syncTicketRejection(res);
          if (!noTicket) await _returnTicket();
          if (!mounted) return;
          showCenterToast(
            context,
            noTicket ? l.pvpTicketNone : l.battleServerFailed,
          );
          return; // 로컬로 폴백하지 않는다 — 폴백하면 서버 권위가 무의미해진다.
        }
        // 서버가 확정한 티켓 잔량으로 맞춘다(낙관 차감과 어긋나지 않게).
        // 세이브 전체가 아니라 몇 바이트만 온다 — 이그레스 절약.
        await ref
            .read(saveControllerProvider.notifier)
            .adoptTicketState(res.data!);
        driver = ServerManualDriver(
          server: server,
          sessionId: res.data!['sessionId'].toString(),
          startEnergy: (res.data!['energyA'] as num?)?.toInt() ?? 1,
        );
        // 서버가 싸울 상대를 그대로 그린다.
        final srvFoe = foeTeamFromServer(res.data!['foe']);
        if (srvFoe.isNotEmpty) {
          foe = [for (final e in srvFoe) e.bug];
          speciesOf = {
            ...m.speciesOf,
            for (final e in srvFoe) e.bug.id: e.speciesId,
          };
          location = foe.first.element;
        }
      }
      if (!mounted) return;

      closeStart();
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ManualBattleScreen(
            driver: driver,
            onAdoptSave: (srv) =>
                ref.read(saveControllerProvider.notifier).adoptServerSave(srv),
            data: data,
            myTeam: m.mine,
            foeTeam: foe,
            speciesOf: speciesOf,
            seed: m.seed,
            trophiesAtStart: save.pvpTrophies,
            config: data.battleConfig ?? const BattleConfig(),
            rewardMult: scout.tier.rewardMult,
            onApply: _applyReward,
            location: location,
            skinOf: ref.read(skinOfProvider),
            arenaTheme: ref.read(arenaThemeOwnedProvider),
          ),
        ),
      );
    } finally {
      closeStart();
    }
  }

  /// 스카우트 카드 — 난이도 배지·상대 3마리 미리보기·승리 보상, 탭하면 선택.
  Widget _scoutCard(
    AppLocalizations l,
    GameData data,
    BattleConfig cfg,
    SaveGame save,
    int index,
  ) {
    final scout = _scouts[index];
    final selected = index == _selectedScout;
    final (label, color) = _tierStyle(l, scout.tier.id);
    final gold = cfg.winGold(save.pvpTrophies, scout.tier.rewardMult);
    final trophy = cfg.trophyOnWin(scout.tier.rewardMult);
    return GestureDetector(
      onTap: () => setState(() => _selectedScout = index),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.14)
              : const Color(0x22000000),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : const Color(0x33FFFFFF),
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            // 실제 유저면 닉네임, 합성 상대면 '야생' — 항상 한 줄을 차지해
            // 카드 3개의 높이가 어긋나지 않게 한다.
            const SizedBox(height: 3),
            Text(
              scout.ownerName == null
                  ? '🌿 ${l.opponentWild}'
                  : '👤 ${_maskName(scout.ownerName!)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: scout.ownerName == null
                    ? const Color(0x8899BB88)
                    : const Color(0xCCE9D9A6),
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final e in scout.team)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: bugStageImage(
                      e.speciesId,
                      LifeStage.adult,
                      size: 26,
                      fallback: elementIcon(e.bug.element, size: 18),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '💰${formatCompact(gold)}',
              style: const TextStyle(
                color: Color(0xFFEBD24A),
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              '🏆+$trophy',
              style: const TextStyle(
                color: Color(0xFFE9D9A6),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
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
