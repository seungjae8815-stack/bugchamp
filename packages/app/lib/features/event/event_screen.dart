import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/game_data.dart';
import '../../domain/game_server.dart';
import '../../domain/providers.dart';
import '../../domain/save_controller.dart';
import '../../domain/server_sync.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/art.dart';
import '../../ui/format.dart';
import '../../ui/jelly_confirm.dart';
import '../../ui/labels.dart';
import '../../ui/skins.dart';
import '../../ui/toast.dart';
import '../battle/duel_bug_build.dart';
import 'event_battle.dart';
import 'event_duel_play.dart';
import '../battle/duel_bug_info.dart';
import 'event_hall.dart';
import 'event_intro.dart';
import '../../ui/event_badge.dart';
import '../../ui/colors.dart';
import '../../ui/avatar.dart';

const _honey = kHoney;

/// 홈 배너용 이벤트 현황. 서버가 없거나 이벤트가 닫혀 있으면 null 이라
/// 배너 자체가 뜨지 않는다 — 이벤트는 서버 없이는 성립하지 않는다.
final eventStateProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final server = ref.watch(gameServerProvider);
  if (!server.available) return null;
  final r = await server.eventState();
  return r.isOk ? r.data : null;
});

/// 실물 경품 랭킹 이벤트 — 「왕충 선발대회」(docs/event_ranking_prize.md).
///
/// ⚠️ **서버 없이는 열리지 않는다.** 순위가 그대로 실물 상품이라 로컬 계산으로
/// 점수를 만들 수 있으면 안 된다. 이 화면은 서버가 확정한 결과를 보여주고
/// 재생할 뿐, 점수를 스스로 계산하지 않는다.
class EventScreen extends ConsumerStatefulWidget {
  const EventScreen({super.key});

  @override
  ConsumerState<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends ConsumerState<EventScreen> {
  Map<String, dynamic>? _state;
  List<Map<String, dynamic>> _ranks = const [];
  final List<String> _team = [];

  /// 2회차부터 곤충 1마리 · 결투 엔진 웨이브전(`event.json → duelWave`).
  bool get _duelMode =>
      ref.read(gameDataProvider).value?.eventConfig?.duelMode ?? false;
  int get _teamSize => _duelMode ? 1 : 3;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  /// 전단지를 **오늘** 봤는지(기기 단위, 값은 KST 날짜). 세이브가 아니라 로컬
  /// 설정이다 — 서버에 올릴 값도, 계정을 옮길 값도 아니다.
  ///
  /// 예전엔 "한 번이라도 봤으면 끝"이었다. 그런데 이 대회는 회차가 짧고 상품이
  /// 실물이라, **매일 한 번은 상기시켜야** 기간·상품·응모 조건을 잊지 않는다.
  /// 하루에 여러 번 들락거려도 한 번만 뜬다 — 매번 뜨면 방해가 된다.
  static const _seenIntroKey = 'event_intro_seen_date';

  @override
  void initState() {
    super.initState();
    _refresh();
    // 첫 진입이면 설명을 먼저 보여준다. 이 대회는 평소와 규칙이 두 군데
    // 다르므로(스탯 평준화·출전 피로), 설명 없이 들여보내면 문의가 온다.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowIntro());
  }

  Future<void> _maybeShowIntro() async {
    final prefs = await SharedPreferences.getInstance();
    // KST 기준 날짜 — 기기 시간대를 그대로 쓰면 해외 유저는 경계가 달라진다.
    final kst = ref
        .read(clockProvider)
        .now()
        .toUtc()
        .add(const Duration(hours: 9));
    final today = '${kst.year}-${kst.month}-${kst.day}';
    if (prefs.getString(_seenIntroKey) == today) return;
    if (!mounted) return;
    await _showIntro();
    await prefs.setString(_seenIntroKey, today);
  }

  Future<void> _showIntro() => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const EventIntroScreen()));

  Future<void> _refresh() async {
    final server = ref.read(gameServerProvider);
    if (!server.available) {
      setState(() {
        _loading = false;
        _error = 'no_server';
      });
      return;
    }
    final st = await server.eventState();
    final lb = await server.eventLeaderboard();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = st.isOk ? null : (st.error ?? 'failed');
      _state = st.isOk ? st.data : null;
      _ranks = lb.isOk
          ? ((lb.data?['entries'] as List?) ?? const [])
                .cast<Map<String, dynamic>>()
          : const [];
    });
  }

  /// 도전 — 서버가 참가권을 깎고 **1웨이브**를 치른 뒤, 이후는 전투 화면에서
  /// 카드를 고르며 이어간다(로그라이크). 판 전체를 한 번에 돌리지 않는다.
  Future<void> _challenge(AppLocalizations l) async {
    if (_team.length != _teamSize || _busy) return;
    if (_duelMode) return _challengeDuel(l);
    setState(() => _busy = true);
    final server = ref.read(gameServerProvider);
    // ⚠️ 서버를 부르기 **전에** 최신 로컬 세이브를 올린다. 서버는 자기 저장본
    // 위에서 계산해 돌려주고 우리는 그걸 채택하므로, 안 올리면 마지막 업로드
    // 이후의 진행(부화 수령·획득 곤충·골드)이 통째로 사라진다 — 결투·우편·결제는
    // 이미 이렇게 한다(2026-09-25 대회 경로만 빠져 있던 것을 고침).
    // 올리기 → 서버 행동 → 채택은 한 줄로 돈다([withServerSaveLock]).
    final ctrl = ref.read(saveControllerProvider.notifier);
    final teamIds = List<String>.from(_team);
    final r = await withServerSaveLock(() async {
      if (!await flushSaveBeforeServerAction(server, () => ctrl.latestSave)) {
        return null;
      }
      final r = await server.eventStart(teamIds);
      final save = r.save;
      if (r.isOk && save != null) await ctrl.adoptServerSave(save);
      return r;
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (r == null) {
      showCenterToast(context, l.cloudFailed);
      return;
    }
    if (!r.isOk) {
      showCenterToast(context, _errorText(l, r.error));
      return;
    }

    // 출전한 곤충을 순서 그대로 넘긴다(재생용). 세이브가 서버 값으로 바뀐
    // 뒤에도 개체는 남아 있다 — 피로만 붙는다.
    final current = ref.read(saveControllerProvider).requireValue;
    final byId = {for (final b in current.bugs) b.id: b};
    final team = [
      for (final id in _team)
        if (byId[id] != null) byId[id]!,
    ];
    final data = ref.read(gameDataProvider).requireValue;
    _team.clear();
    if (!mounted) return;

    if (team.length == 3 && r.data != null) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              EventBattleScreen(data: data, team: team, first: r.data!),
        ),
      );
    }
    await _refresh();
  }

  /// 1마리 도전 — 서버가 참가권·부상을 확정하고 세션을 연다. 판은 결투 무대에서 하나씩.
  Future<void> _challengeDuel(AppLocalizations l) async {
    setState(() => _busy = true);
    final server = ref.read(gameServerProvider);
    // 서버를 부르기 **전에** 최신 로컬 세이브를 올린다(서버 저장본 위에서 계산해 돌려준다).
    // 올리기 → 서버 행동 → 채택은 한 줄로 돈다([withServerSaveLock]).
    final ctrl = ref.read(saveControllerProvider.notifier);
    final bugId = _team.first;
    final r = await withServerSaveLock(() async {
      if (!await flushSaveBeforeServerAction(server, () => ctrl.latestSave)) {
        return null;
      }
      final r = await server.eventDuelStart(bugId);
      final save = r.save;
      if (r.isOk && r.data?['bug'] is Map && save != null) {
        await ctrl.adoptServerSave(save);
      }
      return r;
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (r == null) {
      showCenterToast(context, l.cloudFailed);
      return;
    }
    final d = r.data;
    if (!r.isOk || d == null || d['bug'] is! Map) {
      showCenterToast(context, _errorText(l, r.error));
      return;
    }
    final data = ref.read(gameDataProvider).requireValue;
    final cfg = data.eventConfig!;
    final bug = ref
        .read(saveControllerProvider)
        .requireValue
        .bugs
        .where((b) => b.id == bugId)
        .firstOrNull;
    _team.clear();
    if (!mounted || bug == null) return;
    await playEventDuel(
      context: context,
      ref: ref,
      data: data,
      bug: bug,
      mine: DuelBug.fromJson(Map<String, dynamic>.from(d['bug'] as Map)),
      roundSeed: (d['roundSeed'] as num).toInt(),
      driver: ServerEventDuelDriver(
        spec: EventDuelSpec.fromJson(cfg.duelWaveJson),
        cfg: cfg,
        server: server,
        sessionId: '${d['sessionId']}',
      ),
    );
    await _refresh();
  }

  /// 개발자 체험 — 서버 없이 같은 규칙을 앱에서 돌린다(참가권·부상·기록·보상 없음).
  /// 개발 빌드에서만 보인다. 회차가 열리기 전에도 새 방식을 미리 해 볼 수 있게.
  Future<void> _devTry() async {
    if (_team.isEmpty) return;
    final data = ref.read(gameDataProvider).requireValue;
    final cfg = data.eventConfig;
    if (cfg == null) return;
    final save = ref.read(saveControllerProvider).requireValue;
    final bug = save.bugs.where((b) => b.id == _team.first).firstOrNull;
    if (bug == null) return;
    final locale = Localizations.localeOf(context).languageCode;
    final spec = EventDuelSpec.fromJson(cfg.duelWaveJson);
    final now = ref.read(clockProvider).now().toUtc();
    final roundSeed = EventConfig.roundSeedOf(
      cfg.roundIdAt(cfg.startsAt ?? now),
    );
    await playEventDuel(
      context: context,
      ref: ref,
      data: data,
      bug: bug,
      mine: duelBugFor(bug, data, save, locale),
      roundSeed: roundSeed,
      dev: true,
      driver: LocalEventDuelDriver(
        spec: spec,
        cfg: cfg,
        seed: now.microsecondsSinceEpoch & 0x7fffffff,
        roundSeed: roundSeed,
        bug: duelBugFor(bug, data, save, locale),
        enemyOf: (w) => eventEnemyFor(data, spec, roundSeed, w, locale),
        // 대회 전용 압축(`duelWave.statCompress`) — 서버 `eventDuelParams` 와 같은 함수.
        params: eventDuelParamsOf(
          (data.battleConfig ?? const BattleConfig()).duelJson,
          spec,
        ),
      ),
    );
  }

  Widget _devTryButton(AppLocalizations l) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
    child: OutlinedButton.icon(
      onPressed: _team.isEmpty ? null : _devTry,
      icon: const Icon(Icons.science_rounded, size: 18),
      label: Text(l.eventDevTry),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF9BE7FF),
        side: const BorderSide(color: Color(0x669BE7FF)),
        minimumSize: const Size(double.infinity, 42),
      ),
    ),
  );

  String _errorText(AppLocalizations l, String? code) => switch (code) {
    'no_ticket' => l.eventNoTicket,
    'fatigued' => l.eventFatigueLeft(''),
    'ad_limit' => l.eventAdLimit,
    'ticket_full' => l.eventTicketFull,
    'no_jelly' => l.eventNoJelly,
    'event_closed' => l.eventClosed,
    'bug_injured' => l.squadInjured,
    'bug_training' => l.squadTraining,
    // 구버전 경로 차단(426) — "잠시 후 다시"로 보이면 계속 눌러 본다(2026-09-30 점검).
    'event_update' => l.updateRequiredBody,
    'not_adult' ||
    'bug_not_owned' ||
    'team_size' ||
    'duplicate_bug' => l.eventBugUnavailable,
    final c? when c.startsWith('bug_forged') => l.eventBugUnavailable,
    _ => l.cloudFailed,
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final save = ref.watch(saveControllerProvider).requireValue;
    final data = ref.watch(gameDataProvider).requireValue;
    final now = ref.read(clockProvider).now().toUtc();

    return Scaffold(
      appBar: AppBar(
        title: Text(l.eventTitle),
        actions: [
          // 대회가 열려 있는 동안에도 지난 회차를 볼 수 있게. 닫혀 있을 땐
          // 본문이 곧 명예의 전당이라 버튼이 필요 없다.
          if (!_loading && _error == null)
            IconButton(
              tooltip: l.eventHallTitle,
              icon: const Icon(Icons.workspace_premium_rounded),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const EventHallScreen(),
                ),
              ),
            ),
          IconButton(
            tooltip: l.eventHelp,
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: _showIntro,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _closed(l)
          : ListView(
              padding: EdgeInsets.only(
                bottom: 24 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              children: [
                _header(l),
                // 실물 배송 범위는 **상시 표시**한다. 공지 한 줄로는 부족하다 —
                // 해외 유저가 1등을 하고 못 받는 게 가장 나쁜 그림이다.
                _notice(l.eventKoreaOnly, const Color(0xFFFFD08A)),
                _rewardsCard(l, data.eventConfig),
                if (_state?['rankEligible'] == false)
                  _notice(l.eventAnonWarn, const Color(0xFFFF8A65)),
                _normalizeCard(l),
                _teamPicker(context, l, data, save, now),
                _challengeButton(l, save),
                if (!kReleaseMode && _duelMode) _devTryButton(l),
                const Divider(height: 24, color: Color(0x22FFFFFF)),
                _rankList(l),
              ],
            ),
    );
  }

  /// 못 들어가는 상태. **"아직 안 열림"과 "끝남"은 다른 화면**이어야 한다 —
  /// 끝난 건 닫으면 그만이지만, 시작 전이면 언제 열리는지 알려야 사람이 기다린다.
  ///
  /// 회차 사이(2026-09-15~)에는 **대회 대기중 + 명예의 전당**이다. 예전엔
  /// "열린 대회가 없어요" 한 줄이라, 2주를 뛴 사람들의 이름이 어디에도 안 남았고
  /// 다음 회차가 언제인지도 알 수 없었다.
  Widget _closed(AppLocalizations l) {
    // 개발 빌드는 서버가 없어도(로그인 전·오프라인) 체험 칸을 보여 준다 — 체험은 앱에서만 돈다.
    if (_error == 'no_server' && !kReleaseMode && _duelMode) {
      return ListView(
        padding: EdgeInsets.only(
          bottom: 24 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              l.eventNeedServer,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0x99FFFFFF)),
            ),
          ),
          _teamPicker(
            context,
            l,
            ref.read(gameDataProvider).requireValue,
            ref.read(saveControllerProvider).requireValue,
            ref.read(clockProvider).now().toUtc(),
          ),
          _devTryButton(l),
        ],
      );
    }
    if (_error == 'no_server') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l.eventNeedServer,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0x99FFFFFF), height: 1.4),
          ),
        ),
      );
    }
    return ListView(
      padding: EdgeInsets.only(
        bottom: 24 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      children: [
        _waitingCard(l),
        // 개발 빌드 — 회차가 열리기 전에도 새 방식(1마리 결투 웨이브전)을 해 본다.
        if (!kReleaseMode && _duelMode) ...[
          _teamPicker(
            context,
            l,
            ref.read(gameDataProvider).requireValue,
            ref.read(saveControllerProvider).requireValue,
            ref.read(clockProvider).now().toUtc(),
          ),
          _devTryButton(l),
        ],
        const EventHallSection(),
      ],
    );
  }

  /// 대기 안내 — 다음 회차가 잡혀 있으면 번호·개막일·기간·D-day, 없으면 닫힘 문구.
  Widget _waitingCard(AppLocalizations l) {
    final cfg = ref.watch(gameDataProvider).asData?.value.eventConfig;
    final now = ref.read(clockProvider).now().toUtc();
    final left = cfg?.untilOpen(now);
    final next = left == null ? null : cfg!.currentRound;
    // 종료 시각은 **다음 날 0시**라, 그대로 적으면 하루 긴 기간으로 읽힌다.
    String md(DateTime t) => l.eventDateMd(t.month, t.day);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x22000000),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _honey.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          const Icon(Icons.hourglass_top_rounded, size: 34, color: _honey),
          const SizedBox(height: 6),
          Text(
            next == null ? l.eventClosed : l.eventWaitingTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (next != null) ...[
            const SizedBox(height: 8),
            Text(
              l.eventNextRound(next.no, md(next.startsAt.toLocal())),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _honey,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${l.eventPeriodLabel} · ${md(next.startsAt.toLocal())} ~ '
              '${md(next.endsAt.subtract(const Duration(seconds: 1)).toLocal())}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xBBFFFFFF), fontSize: 12.5),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: _honey.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _honey),
              ),
              child: Text(
                _untilText(l, left!),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // 기다리는 동안 **뭘 준비해야 하는지**는 전단지에 다 있다.
            OutlinedButton.icon(
              onPressed: _showIntro,
              icon: const Icon(Icons.article_rounded, size: 16),
              label: Text(l.eventSeeFlyer),
              style: OutlinedButton.styleFrom(
                foregroundColor: _honey,
                side: const BorderSide(color: Color(0x66EBA52F)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// "3일 12시간 뒤" — 하루 넘게 남으면 날짜 단위로만 말한다(분까지 세면 조급하다).
  String _untilText(AppLocalizations l, Duration d) {
    if (d.inDays >= 1) return l.eventOpensInDays(d.inDays + 1);
    if (d.inHours >= 1) return l.eventOpensInHours(d.inHours);
    return l.eventOpensInMinutes(d.inMinutes + 1);
  }

  Widget _header(AppLocalizations l) {
    final tickets = (_state?['tickets'] as num?)?.toInt() ?? 0;
    final max = (_state?['ticketMax'] as num?)?.toInt() ?? 5;
    final bestWave = (_state?['bestWave'] as num?)?.toInt() ?? 0;
    final bestScore = (_state?['bestScore'] as num?)?.toInt() ?? 0;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x22000000),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _honey.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.eventBestRecord,
                  style: const TextStyle(
                    color: Color(0x99FFFFFF),
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  bestWave <= 0
                      ? l.eventNoRecord
                      : '${l.eventWaveRecord('$bestWave')} · ${l.eventScore(formatCompact(bestScore))}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _honey.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _honey),
            ),
            child: Text(
              l.eventTickets(tickets, max),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 순위 보상 표 — `event.json → rewards` 를 **그대로 그린다**(§6).
  ///
  /// 전단지가 1등 실물만 강조해서 "그 밖엔 아무것도 없다"로 읽혔다
  /// (2026-08-27 지적). 젤리·뱃지가 몇 위까지 나가는지 보여야 4~10위권
  /// 유저에게도 참가할 이유가 생긴다.
  /// 순위 보상 표 — `event.json → rewards` 를 **그대로 그린다**(§6).
  /// 전단지(`event_intro.dart`)와 같은 규칙으로 그린다 — 두 곳이 다르게
  /// 보이면 어느 쪽이 진짜인지 유저가 헷갈린다.
  Widget _rewardsCard(AppLocalizations l, EventConfig? cfg) {
    if (cfg == null || cfg.rewardTiers.isEmpty) return const SizedBox.shrink();

    String rankLabel(int from, int to) =>
        from == to && from == 1 ? l.eventRankOne : l.eventRankRange(from, to);

    /// 보상 한 줄. 아이콘 칸은 **고정폭** — 그림 크기가 제각각이면 글자
    /// 시작점이 줄마다 어긋난다.
    Widget item(Widget icon, String text, {Color? color, bool bold = false}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Row(
            children: [
              SizedBox(width: 18, child: Center(child: icon)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color ?? const Color(0xDDFFFFFF),
                    fontSize: 12,
                    height: 1.25,
                    fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );

    /// 순위 칸의 폭은 **가장 긴 라벨**("참가 (1판 이상)") 기준이다.
    /// 좁으면 그 줄만 접혀 표가 어긋난다.
    Widget row(String rank, List<Widget> rewards, {bool highlight = false}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 96,
                child: Text(
                  rank,
                  maxLines: 1,
                  style: TextStyle(
                    color: highlight ? kHoney : Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12.5,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: rewards,
                ),
              ),
            ],
          ),
        );

    /// 칭호는 칩이 아니라 **"무엇을 받는지"** 로 적는다(`eventBadgeName`).
    String titleName(String badgeId) => eventBadgeName(l, badgeId);

    final rows = <Widget>[];
    var from = 1;
    for (final t in cfg.rewardTiers) {
      final name = t.badge.isEmpty
          ? ''
          : titleName('${t.badge}:${cfg.roundNo}');
      rows.add(
        row(rankLabel(from, t.maxRank), highlight: t.physical, [
          if (t.physical)
            item(
              const Icon(Icons.emoji_nature_rounded, size: 15, color: kHoney),
              l.eventRewardRealBug,
              color: kHoney,
              bold: true,
            ),
          if (t.jelly > 0)
            item(jellyIcon(size: 15), l.eventRewardJelly(t.jelly)),
          if (name.isNotEmpty)
            item(
              const Icon(
                Icons.workspace_premium_rounded,
                size: 15,
                color: Color(0xFFFFC24D),
              ),
              l.eventRewardTitleAward(name),
              color: const Color(0xFFFFD98A),
            ),
        ]),
      );
      from = t.maxRank + 1;
    }
    final entrant = titleName(cfg.participantBadgeId(cfg.roundNo) ?? '');
    if (cfg.participationMaterials.isNotEmpty) {
      rows.add(
        row(l.eventRewardParticipationRow, [
          for (final e in cfg.participationMaterials.entries)
            item(
              materialImage(
                e.key,
                size: 15,
                fallback: Icon(materialIcon(e.key), size: 13),
              ),
              '${materialLabel(l, e.key)} ${e.value}',
              color: const Color(0xBBFFFFFF),
            ),
          // 참가 뱃지(2026-09-15) — 순위권 밖이어도 표식이 남는다.
          if (entrant.isNotEmpty)
            item(
              const Icon(
                Icons.workspace_premium_rounded,
                size: 15,
                color: Color(0xFF8FD19E),
              ),
              l.eventRewardTitleAward(entrant),
              color: const Color(0xFFB9E4C2),
            ),
        ]),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(
        color: const Color(0x1AEBC24A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x55EBC24A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events_rounded, size: 16, color: kHoney),
              const SizedBox(width: 6),
              Text(
                l.eventRewardsTitle,
                style: const TextStyle(
                  color: kHoney,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...rows,
        ],
      ),
    );
  }

  Widget _notice(String text, Color color) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 11.5, height: 1.35),
    ),
  );

  /// 정규화 안내 — **크게 적는다.** 안 적으면 "강화한 곤충이 약해졌다"는
  /// 문의가 반드시 들어온다. 이건 UI 문제가 아니라 신뢰 문제다.
  Widget _normalizeCard(AppLocalizations l) => Container(
    margin: const EdgeInsets.fromLTRB(12, 4, 12, 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0x1A2E6DA4),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0x662E6DA4)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.balance_rounded, size: 16, color: _honey),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                l.eventNormalizeTitle,
                style: const TextStyle(
                  color: _honey,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          l.eventNormalizeBody(
            (EventDuelSpec.fromJson(
                      ref
                          .read(gameDataProvider)
                          .value
                          ?.eventConfig
                          ?.duelWaveJson,
                    ).fallPenalty *
                    100)
                .round(),
          ),
          style: const TextStyle(
            color: Color(0xDDFFFFFF),
            fontSize: 12,
            height: 1.4,
          ),
        ),
      ],
    ),
  );

  /// 출전 확인 — 결투와 같은 능력치 창에 `취소 · 출전`(이미 출전 중이면 `해제`).
  Future<void> _confirmEntry(
    AppLocalizations l,
    GameData data,
    SaveGame save,
    IndividualBug bug,
    bool picked,
  ) async {
    final locale = Localizations.localeOf(context).languageCode;
    final ok = await showDuelBugInfo(
      context,
      data,
      duelBugFor(bug, data, save, locale),
      confirm: picked ? l.squadRelease : l.squadDeploy,
    );
    if (ok != true || !mounted) return;
    setState(() {
      _team.clear();
      if (!picked) _team.add(bug.id);
    });
  }

  /// 출전 무대(1마리 모드) — 고른 곤충이 무대 위에 올라선다. 비어 있으면 물음표 실루엣.
  /// 무대 그림은 `assets/images/duel/event_entry_stage.webp`(없으면 출정 칸 그림으로).
  Widget _entryStage(AppLocalizations l, GameData data, SaveGame save) {
    final locale = Localizations.localeOf(context).languageCode;
    final bug = _team.isEmpty
        ? null
        : save.bugs.where((b) => b.id == _team.first).firstOrNull;
    final sp = bug == null ? null : data.speciesById[bug.speciesId];
    final d = bug == null ? null : duelBugFor(bug, data, save, locale);
    const h = 210.0;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      height: h,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: sp == null
              ? const Color(0x44FFFFFF)
              : gradeColor(sp.grade).withValues(alpha: 0.8),
          width: 1.6,
        ),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2E2414), Color(0xFF14100A)],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, box) => Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: gameImage(
                'assets/images/duel/event_entry_stage.webp',
                width: box.maxWidth,
                height: h,
                fit: BoxFit.cover,
                fallback: const SizedBox.shrink(),
              ),
            ),
            // 출전하는 곤충 — 바뀔 때 무대 위로 튀어 오르듯 등장.
            Positioned(
              left: 0,
              right: 0,
              // 그루터기 윗면(그림 높이의 약 70%)에 발이 닿게.
              bottom: 50,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 420),
                switchInCurve: Curves.easeOutBack,
                transitionBuilder: (child, a) => FadeTransition(
                  opacity: a,
                  child: ScaleTransition(
                    scale: Tween(begin: 0.6, end: 1.0).animate(a),
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0, 0.35),
                        end: Offset.zero,
                      ).animate(a),
                      child: child,
                    ),
                  ),
                ),
                child: bug == null
                    ? Text(
                        '?',
                        key: const ValueKey('empty'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.25),
                          fontSize: 72,
                          fontWeight: FontWeight.w900,
                        ),
                      )
                    : GestureDetector(
                        key: ValueKey(bug.id),
                        onTap: () => _confirmEntry(l, data, save, bug, true),
                        child: bugPoseImage(
                          bug.speciesId,
                          BugPose.idle,
                          size: 108,
                          skin: bugView(ref.read(skinOfProvider), bug),
                          fallback: bugAvatar(sp!, size: 90),
                        ),
                      ),
              ),
            ),
            // 머리표: 출전 곤충
            Positioned(
              top: 8,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xCC000000),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  l.eventEntryLabel,
                  style: const TextStyle(
                    color: _honey,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            // 아래 띠: 이름 · 등급 · 전투력 (비었으면 안내)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                color: const Color(0xB3000000),
                child: bug == null || sp == null || d == null
                    ? Text(
                        l.eventEntryEmpty,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xCCFFFFFF),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: gradeColor(
                                sp.grade,
                              ).withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              gradeLabel(l, sp.grade),
                              style: TextStyle(
                                color: gradeColor(sp.grade),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          elementIcon(bug.element, size: 14),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              sp.name.resolve(locale),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.flash_on_rounded,
                            size: 15,
                            color: kHoney,
                          ),
                          Text(
                            formatCompact(duelPowerOf(d, data).round()),
                            style: const TextStyle(
                              color: kHoney,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _teamPicker(
    BuildContext context,
    AppLocalizations l,
    GameData data,
    SaveGame save,
    DateTime now,
  ) {
    final cfg = data.petConfig;
    final adults = save.bugs.where((b) {
      final st = cfg == null
          ? b.stage
          : effectiveStage(b.stage, b.stageSince, now, cfg);
      return st == LifeStage.adult;
    }).toList();
    // 쉬고 있는 곤충은 뒤로 — 지금 고를 수 없으니 눈에 먼저 들어올 이유가 없다.
    int gradeIdx(IndividualBug b) =>
        data.speciesById[b.speciesId]?.grade.index ?? -1;
    final duel = _duelMode;
    final locale = Localizations.localeOf(context).languageCode;
    // 1마리 모드: 결투와 같은 능력치의 전투력 — 가장 잘 키운 곤충이 맨 앞.
    final power = duel
        ? {
            for (final b in adults)
              b.id: duelPowerOf(duelBugFor(b, data, save, locale), data),
          }
        : const <String, double>{};
    DateTime? restUntil(IndividualBug b) {
      if (!duel) return save.eventFatigue[b.id];
      // 대회 부상은 서버 소유 기록(`eventFatigue`)이 기준 — 결투 부상과 둘 중 늦은 쪽.
      final ev = save.eventOnFatigue(b.id, now)
          ? save.eventFatigue[b.id]
          : null;
      final inj = save.isInjured(b.id, now) ? save.injuredUntil(b.id) : null;
      if (ev != null || inj != null) {
        if (ev == null) return inj;
        if (inj == null) return ev;
        return ev.isAfter(inj) ? ev : inj;
      }
      // 훈련 v2 — 포인트 찍는 중 · 다시 찍기 대기 중.
      return trainBusyUntil(save, b.id, now);
    }

    bool resting(IndividualBug b) {
      final u = restUntil(b);
      return u != null && now.isBefore(u);
    }

    adults.sort((a, b) {
      final af = resting(a) ? 1 : 0;
      final bf = resting(b) ? 1 : 0;
      if (af != bf) return af - bf;
      if (duel) return (power[b.id] ?? 0).compareTo(power[a.id] ?? 0);
      return gradeIdx(b).compareTo(gradeIdx(a));
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (duel) _entryStage(l, data, save),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 2),
          child: Text(
            l.eventPickTeam,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 13.5,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          child: Text(
            l.eventPickOrder,
            style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 11),
          ),
        ),
        SizedBox(
          height: 116,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemCount: adults.length,
            itemBuilder: (c, i) {
              final bug = adults[i];
              final sp = data.speciesById[bug.speciesId];
              if (sp == null) return const SizedBox.shrink();
              final until = restUntil(bug);
              final rest = until != null && now.isBefore(until);
              final picked = _team.indexOf(bug.id);
              return _bugTile(
                l,
                bug,
                sp,
                order: picked < 0 ? null : picked + 1,
                resting: rest ? until.difference(now) : null,
                // 쉬는 곤충을 누르면 이유를 알려 준다(예전엔 아무 반응이 없었다, 2026-09-30).
                onRestTap: () => showCenterToast(
                  context,
                  trainBusy(save, bug.id, now)
                      ? l.squadTraining
                      : l.squadInjured,
                ),
                power: power[bug.id],
                onTap: duel
                    // 1마리 — 누르면 상세 창(능력치) → 출전 / 이미 나가 있으면 해제.
                    ? () => _confirmEntry(l, data, save, bug, picked >= 0)
                    : () => setState(() {
                        if (picked >= 0) {
                          _team.removeAt(picked);
                        } else if (_team.length < 3) {
                          _team.add(bug.id);
                        }
                      }),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _bugTile(
    AppLocalizations l,
    IndividualBug bug,
    Species sp, {
    required int? order,
    required Duration? resting,
    required VoidCallback onTap,
    VoidCallback? onRestTap,
    double? power,
  }) {
    final locale = Localizations.localeOf(context).languageCode;
    return GestureDetector(
      onTap: resting == null ? onTap : onRestTap,
      child: Opacity(
        opacity: resting == null ? 1 : 0.4,
        child: Container(
          width: 92,
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: order != null
                ? _honey.withValues(alpha: 0.2)
                : const Color(0x22000000),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: order != null
                  ? _honey
                  : gradeColor(sp.grade).withValues(alpha: 0.6),
              width: order != null ? 2 : 1.2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.topRight,
                children: [
                  // 이색·스킨도 목록에서 보이게(2026-10-09 — 고르기 목록만 기본 색이라 이색이 출전 못 하는 줄 알았다).
                  bugStageImage(
                    bug.speciesId,
                    LifeStage.adult,
                    size: 44,
                    fallback: bugAvatar(sp, size: 40),
                    skin: bugView(ref.read(skinOfProvider), bug),
                  ),
                  if (order != null)
                    Container(
                      width: 18,
                      height: 18,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: _honey,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$order',
                        style: const TextStyle(
                          color: kHoneyInk,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                sp.name.resolve(locale),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 10.5),
              ),
              // 타일이 좁아서(86px) "23시간 45분 후 출전 가능"은 들어가지 않는다.
              // 여기선 **얼마나 남았는지만** 보여주고, 이유는 눌렀을 때 알린다.
              if (resting == null && power != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    elementIcon(bug.element, size: 12),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Text(
                        formatCompact(power.round()),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: kHoney,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                )
              else if (resting == null)
                elementIcon(bug.element, size: 14)
              else
                Text(
                  resting.inHours >= 1
                      ? l.eventRestHours(resting.inHours)
                      : l.eventRestMinutes(resting.inMinutes + 1),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFFFB0A0),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _challengeButton(AppLocalizations l, SaveGame save) {
    final cfg = ref.watch(gameDataProvider).value?.eventConfig;
    final tickets = (_state?['tickets'] as num?)?.toInt() ?? 0;
    final ready = _team.length == _teamSize && tickets > 0 && !_busy;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: ready ? () => _challenge(l) : null,
              style: FilledButton.styleFrom(
                backgroundColor: _honey,
                foregroundColor: kHoneyInk,
                minimumSize: const Size(0, 46),
              ),
              child: Text(
                tickets > 0 ? l.eventChallenge : l.eventNoTicket,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: _busy
                ? null
                : () async {
                    // 오늘 횟수를 다 썼거나 참가권이 가득이면 묻기 전에 막는다 — 확인하고 나서
                    // 서버가 거절하면 헛걸음이다(2026-10-05 출시 전 점검).
                    final usedNow = ref
                        .read(saveControllerProvider)
                        .requireValue
                        .adUseCount(
                          kAdFeatureEventTicket,
                          dailyDateKey(ref.read(clockProvider).now().toUtc()),
                        );
                    final limit = cfg?.ticketAdDailyLimit ?? 0;
                    if (limit > 0 && usedNow >= limit) {
                      showCenterToast(context, l.eventAdLimit);
                      return;
                    }
                    final have = (_state?['tickets'] as num?)?.toInt() ?? 0;
                    final cap = (_state?['ticketMax'] as num?)?.toInt() ?? 5;
                    if (have >= cap) {
                      showCenterToast(context, l.eventTicketFull);
                      return;
                    }
                    // 젤리를 쓰는 버튼 — 서버에 가기 전에(세이브 업로드보다도 먼저)
                    // 확인부터 받는다. 모자라면 확인 창이 상점 안내로 바뀐다.
                    if (!await confirmJellySpend(
                      context,
                      title: l.eventJellyTicket,
                      body: l.eventJellyTicketConfirm(
                        cfg?.ticketJelly ?? 0,
                        cfg?.ticketAdGrant ?? 1,
                        // 아래에서 같은 이름 `save` 를 새로 선언하므로 여기선 세이브를 직접 읽는다.
                        ref
                            .read(saveControllerProvider)
                            .requireValue
                            .adUseCount(
                              kAdFeatureEventTicket,
                              dailyDateKey(
                                ref.read(clockProvider).now().toUtc(),
                              ),
                            ),
                        cfg?.ticketAdDailyLimit ?? 0,
                      ),
                      jelly: cfg?.ticketJelly ?? 0,
                      actionLabel: l.jellyActCharge,
                    )) {
                      return;
                    }
                    if (!mounted) return;
                    // 젤리를 쓴 행동이라 **결과를 말해 줘야 한다** — 조용히
                    // 끝나면 빠졌는지 안 빠졌는지 알 수 없다. 몇 장 늘었는지는
                    // 서버 세이브 차이로 센다(지급량이 바뀌어도 따라간다).
                    final before = ref
                        .read(saveControllerProvider)
                        .requireValue
                        .eventTickets;
                    // 서버가 자기 저장본 위에 티켓을 얹어 돌려준다 — 먼저 올린다.
                    // 올리기 → 충전 → 채택은 한 줄로 돈다([withServerSaveLock]).
                    final server = ref.read(gameServerProvider);
                    final ctrl = ref.read(saveControllerProvider.notifier);
                    final r = await withServerSaveLock(() async {
                      if (!await flushSaveBeforeServerAction(
                        server,
                        () => ctrl.latestSave,
                      )) {
                        return null;
                      }
                      final r = await server.eventAdTicket();
                      final save = r.save;
                      if (r.isOk && save != null) {
                        await ctrl.adoptServerSave(save);
                      }
                      return r;
                    });
                    if (!mounted) return;
                    if (r == null) {
                      showCenterToast(context, l.cloudFailed);
                      return;
                    }
                    if (!r.isOk) {
                      showCenterToast(context, _errorText(l, r.error));
                      return;
                    }
                    if (!mounted) return;
                    final after = ref
                        .read(saveControllerProvider)
                        .requireValue
                        .eventTickets;
                    final gained = after - before;
                    showCenterToast(
                      context,
                      l.eventTicketBought(gained > 0 ? gained : 1),
                    );
                    await _refresh();
                  },
            icon: const SizedBox.shrink(),
            // 무료가 아니라 **젤리**다 — 누르기 전에 값이 보여야 한다.
            // "참가권 충전" 뒤에 아이콘+숫자를 붙인다(글자 '젤리'는 다른
            // 재화와 눈으로 안 갈린다 — 결투 새로고침과 같은 표기).
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l.eventJellyTicket),
                const SizedBox(width: 5),
                jellyIcon(size: 15),
                const SizedBox(width: 2),
                Text(
                  '(${cfg?.ticketJelly ?? 0})',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(width: 6),
                // 하루 한도를 **누르기 전에** 보여준다. 값(젤리)만 있고 한도가
                // 안 보이면 세 번째에 ad_limit 로 거절당하고서야 알게 된다
                // (2026-09-02 실기 지적). 날짜 경계는 서버와 같은 UTC 키다 —
                // 기기 자정으로 세면 리셋 시각이 서버와 어긋난다.
                Text(
                  l.eventTicketDaily(
                    save.adUseCount(
                      kAdFeatureEventTicket,
                      dailyDateKey(ref.read(clockProvider).now().toUtc()),
                    ),
                    cfg?.ticketAdDailyLimit ?? 0,
                  ),
                  style: const TextStyle(
                    color: Color(0x88FFFFFF),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF9BE7FF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rankList(AppLocalizations l) {
    // 닉네임 규칙(마스킹)은 다른 랭킹·채팅과 같은 곳에서 온다.
    final rules =
        ref.watch(gameDataProvider).value?.chatRules ?? const ChatRules();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
          child: Text(
            l.eventRanking,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ),
        if (_ranks.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Text(
              l.eventRankEmpty,
              style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 12),
            ),
          )
        else
          for (final e in _ranks)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: e['isMe'] == true
                    ? _honey.withValues(alpha: 0.16)
                    : const Color(0x18000000),
                borderRadius: BorderRadius.circular(10),
                border: e['isMe'] == true
                    ? Border.all(color: _honey.withValues(alpha: 0.7))
                    : null,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 30,
                    child: Text(
                      '${e['rank']}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xCCFFFFFF),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // 프로필 그림(2026-10-10) — 서버가 순위 함수의 `avatar` 를 그대로 실어 준다.
                  AvatarCircle(id: e['avatar'] as String?, size: 28),
                  const SizedBox(width: 6),
                  // 이름 칸이 **남는 폭을 전부** 가져간다(Expanded). Flexible +
                  // Spacer 로 두면 이름 길이에 따라 웨이브 칸의 시작점이 줄마다
                  // 달라진다(2026-09-02 지적).
                  Expanded(
                    // 뱃지는 이름 **위** — 옆에 두면 이름이 잘린다(랭킹과 같은 이유).
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        EventBadgeChip(
                          id: '${e['badge'] ?? ''}',
                          size: 10,
                          margin: EventBadgeChip.aboveName,
                        ),
                        // 닉네임은 **마스킹해서** 쓴다 — 다른 랭킹·채팅과 같은 규칙.
                        Text(
                          rules.maskNickname(
                            '${e['nickname'] ?? ''}',
                            fallback: l.nicknameFallback,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  // 웨이브 — **고정 폭 + 세 자리 채움 + 같은 폭 숫자**.
                  // 셋이 다 있어야 이름 길이와 무관하게 같은 자리에 선다.
                  SizedBox(
                    width: 96,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l.eventWaveRecord(
                            ((e['wave'] as num?)?.toInt() ?? 0)
                                .toString()
                                .padLeft(3, '0'),
                          ),
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          style: const TextStyle(
                            color: _honey,
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        // 같은 웨이브인데 순위가 갈리는 **이유**를 보여준다.
                        // 웨이브만 있으면 "왜 저 사람이 나보다 위지?"에 답이
                        // 없다 — 갈리는 건 진입 체력·생존 수·속도이고, 그게
                        // 전부 이 숫자에 들어 있다.
                        //
                        // ⚠️ 축약(1,002만)하면 안 된다. 동률을 가르는 자리가
                        // **아래 여섯 자리**라, 축약하는 순간 두 사람이 같은
                        // 숫자로 보여 이걸 붙인 이유가 사라진다.
                        Text(
                          formatThousands((e['score'] as num?)?.toInt() ?? 0),
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          style: const TextStyle(
                            color: Color(0x99FFFFFF),
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}
