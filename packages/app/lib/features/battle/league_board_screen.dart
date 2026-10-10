import 'dart:async';

import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart' hide Element;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/game_data.dart';
import 'duel_bug_build.dart';
import '../../domain/chat_service.dart';
import '../../domain/game_server.dart';
import '../../domain/providers.dart';
import '../../domain/save_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/art.dart';
import '../../ui/format.dart';
import '../../ui/game_dialog.dart';
import '../../ui/labels.dart';
import '../../ui/skin_badges.dart';
import '../../ui/skins.dart';
import 'board_preview.dart';
import 'duel_bug_info.dart';
import '../../ui/colors.dart';
import '../../ui/avatar.dart';

/// 순위표(2026-09-29 사장님 요청 — 다른 게임의 리그 화면을 참고).
///
/// - **결투 리그**: 리그 = 등급 하나. 같은 리그의 이번 주 승리 점수 순위 상위 100명 · 상위 20% 승급 ·
///   하위 20% 강등. 월 09시 시작 → 일 09시 마감 → 월 09시까지 정산 기간(서버가 결산).
/// - **심연**: 이번 주 전체 최고 층 순위(층 → 벽 보스 피해 → 먼저 도달). 같은 시간표.
///
/// 순위는 전부 **서버 전용 기록**에서 온다(앱이 쓰는 `profiles.trophies` 가 아니다).
/// 결투 탭은 [LeagueBoardView] 를 화면 안에 그대로 넣고, 이 화면은 탭 두 개로 감싼 것이다.
class LeagueBoardScreen extends ConsumerStatefulWidget {
  const LeagueBoardScreen({super.key, this.abyssFirst = false});

  /// 심연 탭으로 열기.
  final bool abyssFirst;

  @override
  ConsumerState<LeagueBoardScreen> createState() => _LeagueBoardScreenState();
}

class _LeagueBoardScreenState extends ConsumerState<LeagueBoardScreen> {
  late bool _abyss = widget.abyssFirst;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: boardBackground,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2F333E),
        title: Text(l.boardTitle),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                for (final (abyss, label) in [
                  (false, l.boardTabDuel),
                  (true, l.boardTabAbyss),
                ])
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _abyss = abyss),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _abyss == abyss
                              ? kHoney
                              : const Color(0x22FFFFFF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          label,
                          style: TextStyle(
                            color: _abyss == abyss
                                ? const Color(0xFF3A2410)
                                : Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: LeagueBoardView(key: ValueKey(_abyss), abyss: _abyss),
          ),
        ],
      ),
    );
  }
}

/// 순위표 바탕색(결투 탭과 순위표 화면 공용).
const boardBackground = Color(0xFF3F4452);

/// 순위표 한 판 — 머리(엠블럼·리그·남은 시간) · 1~100위 목록 · 하단 고정 내 줄 · [footer].
class LeagueBoardView extends ConsumerStatefulWidget {
  const LeagueBoardView({
    super.key,
    this.abyss = false,
    this.footer,
    this.rewardExtra,
    this.headerHeight = 84,
    this.showHeader = true,
    this.myTeam,
  });

  final bool abyss;

  /// 내 줄 아래에 붙는 것(결투 탭의 전투 시작 버튼).
  final Widget? footer;

  /// 보상 창 아래에 덧붙일 것(승급 보상 받기 등).
  final Widget? rewardExtra;

  /// 엠블럼 높이 — 결투 탭은 자리가 좁아 줄인다.
  final double headerHeight;

  /// 머리(엠블럼·리그·남은 시간)를 그리나 — 결투 탭은 앱바에 올려서 끈다.
  final bool showHeader;

  /// 내 결투 팀(출정 순서) — 하단 내 줄을 누르면 이 곤충들을 보여 주고, 미리보기 전투력도 이 합으로.
  final List<DuelBug>? myTeam;

  @override
  ConsumerState<LeagueBoardView> createState() => LeagueBoardViewState();
}

class LeagueBoardViewState extends ConsumerState<LeagueBoardView> {
  Map<String, dynamic>? _data;

  /// 서버 시각 − 기기 시각(받은 순간). 남은 시간을 기기 시계가 아니라 서버 기준으로 잰다.
  Duration _clockSkew = Duration.zero;

  /// 마지막으로 받은 순위표(내 순위·인원·승강 인원) — 리그 보상 창이 내 위치를 보여 줄 때 쓴다.
  Map<String, dynamic>? get data => _data;
  bool _loading = false;
  bool _failed = false;
  Timer? _clock;

  bool get _abyss => widget.abyss;

  @override
  void initState() {
    super.initState();
    reload();
    // 남은 시간을 분 단위로 갱신한다.
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  /// 순위표를 다시 받는다(결투를 마치고 돌아왔을 때 등).
  Future<void> reload() async {
    final server = ref.read(gameServerProvider);
    setState(() {
      _loading = true;
      _failed = false;
    });
    // 개발판(서버 없음)에서는 가짜 명단으로 **모양만** 미리 본다 — 릴리즈에서는 절대 타지 않는다.
    if (!server.available && !kReleaseMode) {
      setState(() {
        _loading = false;
        _data = _preview();
      });
      return;
    }
    final ServerResult res = _abyss
        ? await server.abyssBoard()
        : await server.pvpLeagueBoard();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.isOk) {
        _data = res.data;
        final serverNow = DateTime.tryParse('${res.data?['now']}')?.toUtc();
        _clockSkew = serverNow == null
            ? Duration.zero
            : serverNow.difference(DateTime.now().toUtc());
      } else {
        _failed = true;
      }
    });
  }

  /// 내 id — 개발판 미리보기에서는 가짜 id.
  String? get _myId =>
      ref.read(chatMyUserIdProvider) ??
      (!ref.read(gameServerProvider).available && !kReleaseMode
          ? kPreviewMyId
          : null);

  Map<String, dynamic> _preview() {
    final data = ref.read(gameDataProvider).requireValue;
    final save = ref.read(saveControllerProvider).requireValue;
    final cfg = data.battleConfig ?? const BattleConfig();
    final now = ref.read(clockProvider).now().toUtc();
    final species = [for (final sp in data.allSpecies) sp.id];
    final nick = save.nickname;
    return _abyss
        ? previewAbyssBoard(
            myNickname: nick,
            speciesIds: species,
            cfg: cfg,
            now: now,
            myId: _myId,
          )
        : previewLeagueBoard(
            league: pvpLeagueNow(save, cfg).id,
            myNickname: nick,
            myTrophies: save.pvpTrophies,
            // 결투 팀 전투력만(홈 전투력은 캐릭터 포함이라 결투 화면에 쓰지 않는다 — 모르면 0 = 숨김).
            myPower: widget.myTeam == null || widget.myTeam!.isEmpty
                ? 0
                : widget.myTeam!.fold<double>(
                    0,
                    (a, x) =>
                        a + duelPowerOf(x, ref.read(gameDataProvider).value),
                  ),
            speciesIds: species,
            cfg: cfg,
            now: now,
            myId: _myId,
          );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final d = _data;
    if (d == null) {
      return Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _failed
                ? _message(l.battleServerFailed, retry: true)
                : const SizedBox.shrink(),
          ),
          ?widget.footer,
        ],
      );
    }
    return _board(l, d);
  }

  Widget _message(String text, {bool retry = false}) => Center(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xCCFFFFFF)),
          ),
          if (retry)
            TextButton(
              onPressed: reload,
              child: const Icon(Icons.refresh_rounded, color: Colors.white),
            ),
        ],
      ),
    ),
  );

  // ── 판 ────────────────────────────────────────────────────────────

  Widget _board(AppLocalizations l, Map<String, dynamic> d) {
    final top = [
      for (final r in (d['top'] as List? ?? const []))
        Map<String, dynamic>.from(r as Map),
    ];
    final me = d['me'] is Map
        ? Map<String, dynamic>.from(d['me'] as Map)
        : null;
    final myId = _myId;
    final total = (d['total'] as num?)?.toInt() ?? top.length;
    final promote = (d['promote'] as num?)?.toInt() ?? 0;
    final demote = (d['demote'] as num?)?.toInt() ?? 0;
    final myRow = top.where((r) => r['user_id'] == myId).firstOrNull;

    return Column(
      children: [
        if (widget.showHeader) _header(l, d),
        Expanded(
          child: top.isEmpty
              ? _message(l.boardEmpty)
              : RefreshIndicator(
                  onRefresh: reload,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    itemCount: top.length,
                    itemBuilder: (_, i) {
                      final r = top[i];
                      final rank = (r['rank'] as num?)?.toInt() ?? i + 1;
                      // 승급·강등 경계 — 목록 **사이에** 줄을 넣어 어디까지가 구간인지 보이게.
                      final promoteLine =
                          !_abyss && promote > 0 && rank == promote + 1;
                      final demoteLine =
                          !_abyss && demote > 0 && rank == total - demote + 1;
                      final zone = _abyss
                          ? 0
                          : (rank <= promote
                                ? 1
                                : (demote > 0 && rank > total - demote
                                      ? -1
                                      : 0));
                      final mine = r['user_id'] == myId;
                      final row = _row(
                        l,
                        r,
                        rank,
                        mine: mine,
                        zone: zone,
                        onTap: _abyss || mine || r['user_id'] == null
                            ? null
                            : () => _showProfile(l, r),
                      );
                      if (!promoteLine && !demoteLine) return row;
                      return Column(
                        children: [
                          if (promoteLine)
                            _zoneLine(
                              l.boardPromoteLine,
                              const Color(0xFF6FCF6F),
                            ),
                          if (demoteLine)
                            _zoneLine(
                              l.boardDemoteLine,
                              const Color(0xFFEF6B6B),
                            ),
                          row,
                        ],
                      );
                    },
                  ),
                ),
        ),
        // 하단 고정 — 내 줄 + (결투 탭이면) 전투 시작 버튼.
        Container(
          // 배경 그림과 어울리게 반투명 검정(예전 회색은 떠 보였다).
          color: const Color(0xCC000000),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                me == null
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          _abyss ? l.boardAbyssMeNone : l.boardMeNone,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xCCFFFFFF),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : _row(
                        l,
                        myRow ??
                            {
                              'nickname': ref
                                  .read(saveControllerProvider)
                                  .value
                                  ?.nickname,
                              'trophies': me['trophies'],
                              'floor': me['floor'],
                            },
                        (me['rank'] as num).toInt(),
                        mine: true,
                        zone: 0,
                        onTap: _abyss || (widget.myTeam?.isEmpty ?? true)
                            ? null
                            : () => _showMyTeam(l),
                      ),
                ?widget.footer,
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _header(AppLocalizations l, Map<String, dynamic> d) {
    final closed = d['closed'] == true;
    final ends = DateTime.tryParse('${d['endsAt']}');
    final left = ends == null
        ? Duration.zero
        : ends.difference(DateTime.now().toUtc().add(_clockSkew));
    final league = '${d['league'] ?? ''}';
    final data = ref.read(gameDataProvider).value;
    final promote = (d['promote'] as num?)?.toInt() ?? 0;
    final demote = (d['demote'] as num?)?.toInt() ?? 0;
    final h = widget.headerHeight;
    // 집계 중에는 마감까지, 정산 기간에는 새 시즌까지 남은 시간.
    final timeLabel = closed
        ? l.boardSeasonEndsIn(_left(l, left))
        : l.boardSeasonClosesIn(_left(l, left));
    if (_abyss) {
      // 심연 — 엠블럼 대신 **심연 풍경 배너**(docs/art_prompts_battle_hub.md #5). 아래로 어둡게 빠지는 그림 위에
      // 제목·남은 시간·순위 기준을 얹는다. 그림이 없으면 보라색 그라데이션.
      return SizedBox(
        height: 190,
        child: Stack(
          fit: StackFit.expand,
          children: [
            gameImageChain(
              [
                'assets/images/ui/abyss_banner.webp',
                'assets/images/ui/abyss_banner.png',
              ],
              size: 190,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              fallback: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF3A2466), Color(0xFF120B22)],
                  ),
                ),
              ),
            ),
            // 아래쪽을 바탕색으로 흐려 목록과 이어지게.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x00000000),
                    Color(0x00000000),
                    boardBackground,
                  ],
                  stops: [0, 0.45, 1],
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l.boardAbyssTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      shadows: [Shadow(color: Colors.black, blurRadius: 6)],
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: data == null ? null : () => _showRewards(l, data, d),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(6, 4, 16, 4),
                      decoration: BoxDecoration(
                        color: const Color(0xCC22252E),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: const Color(0xFF111318),
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.card_giftcard_rounded,
                            color: Color(0xFFFF6B6B),
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              timeLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: closed
                                    ? const Color(0xFF6CFF6C)
                                    : Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    l.boardAbyssHint,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xCCFFFFFF),
                      fontSize: 11,
                      shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    if (h < 70 && !_abyss) {
      // 결투 탭 안 — 자리가 좁아 엠블럼 | 리그 이름 · 남은 시간(누르면 보상)으로 한 줄.
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
        child: Row(
          children: [
            gameImageChain(
              ['assets/images/ui/league/$league.png'],
              size: h,
              fallback: Icon(
                Icons.emoji_events_rounded,
                size: h * 0.85,
                color: kHoney,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l.boardLeagueTitle(leagueName(l, league)),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (promote > 0 || demote > 0)
                    Text(
                      l.boardZonesHint(promote, demote),
                      style: const TextStyle(
                        color: Color(0xAAFFFFFF),
                        fontSize: 10.5,
                      ),
                    ),
                ],
              ),
            ),
            GestureDetector(
              onTap: data == null ? null : () => _showRewards(l, data, d),
              child: Container(
                padding: const EdgeInsets.fromLTRB(4, 3, 10, 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF22252E),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.card_giftcard_rounded,
                      color: Color(0xFFFF6B6B),
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _left(l, left),
                      style: TextStyle(
                        color: closed ? const Color(0xFF6CFF6C) : Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Column(
        children: [
          SizedBox(
            height: h,
            child: _abyss
                ? gameImageChain(
                    // 심연 엠블럼(docs/art_prompts_battle_hub.md #5) — 없으면 달 아이콘.
                    [
                      'assets/images/ui/abyss_emblem.webp',
                      'assets/images/ui/abyss_emblem.png',
                    ],
                    size: h,
                    fallback: Icon(
                      Icons.nights_stay_rounded,
                      size: h * 0.85,
                      color: const Color(0xFFB388FF),
                    ),
                  )
                : gameImageChain(
                    ['assets/images/ui/league/$league.png'],
                    size: h,
                    fallback: Icon(
                      Icons.emoji_events_rounded,
                      size: h * 0.85,
                      color: kHoney,
                    ),
                  ),
          ),
          const SizedBox(height: 2),
          Text(
            _abyss
                ? l.boardAbyssTitle
                : l.boardLeagueTitle(leagueName(l, league)),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: data == null ? null : () => _showRewards(l, data, d),
            child: Container(
              padding: const EdgeInsets.fromLTRB(6, 4, 16, 4),
              decoration: BoxDecoration(
                color: const Color(0xFF22252E),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFF111318), width: 2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.card_giftcard_rounded,
                    color: Color(0xFFFF6B6B),
                    size: 26,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      timeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: closed ? const Color(0xFF6CFF6C) : Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!_abyss && (promote > 0 || demote > 0)) ...[
            const SizedBox(height: 5),
            Text(
              l.boardZonesHint(promote, demote),
              style: const TextStyle(color: Color(0xAAFFFFFF), fontSize: 11.5),
            ),
          ],
          // 심연 순위 기준 — "보스 %"가 무엇인지(정복률이 아니다).
          if (_abyss) ...[
            const SizedBox(height: 5),
            Text(
              l.boardAbyssHint,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xAAFFFFFF), fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _zoneLine(String text, Color c) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(child: Container(height: 2, color: c)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            text,
            style: TextStyle(
              color: c,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Expanded(child: Container(height: 2, color: c)),
      ],
    ),
  );

  String _left(AppLocalizations l, Duration d) {
    if (d.isNegative) d = Duration.zero;
    final days = d.inDays;
    final h = d.inHours % 24;
    final m = d.inMinutes % 60;
    return days > 0 ? l.boardTimeLeftDays(days, h, m) : l.boardTimeLeft(h, m);
  }

  Widget _row(
    AppLocalizations l,
    Map<String, dynamic> r,
    int rank, {
    required bool mine,
    required int zone,
    VoidCallback? onTap,
  }) {
    // 내 줄은 **지금 내 출정 팀**으로 직접 잰다(서버 기록은 결투를 해야 생기고, 비어 있으면 숫자가
    // 빠졌다 — 2026-10-01 실기). 홈 전투력(캐릭터 포함)은 결투 화면에 쓰지 않는다.
    final myTeam = widget.myTeam;
    final power = mine && !_abyss && myTeam != null && myTeam.isNotEmpty
        ? myTeam.fold<double>(
            0,
            (a, x) => a + duelPowerOf(x, ref.read(gameDataProvider).value),
          )
        : (r['power'] as num?)?.toDouble() ?? 0;
    final score = _abyss
        ? l.boardFloorShort((r['floor'] as num?)?.toInt() ?? 0)
        : '${(r['trophies'] as num?)?.toInt() ?? 0}';
    final bossPm = (r['boss_pm'] as num?)?.toInt() ?? 0;
    final bg = mine ? const Color(0xFF1FA2F5) : const Color(0xFF2F333E);
    final edge = zone > 0
        ? const Color(0xFF6FCF6F)
        : (zone < 0 ? const Color(0xFFEF6B6B) : Colors.transparent);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: edge, width: 4)),
        ),
        child: Row(
          children: [
            SizedBox(width: 44, child: Center(child: _rankBadge(rank))),
            const SizedBox(width: 6),
            // 프로필 그림(2026-10-10 사장님 — 대표 곤충 그림 자리를 대신한다). 내 줄은 지금 고른 그림.
            AvatarCircle(
              id: mine
                  ? ref.watch(
                      saveControllerProvider.select((s) => s.value?.avatar),
                    )
                  : r['avatar'] as String?,
              size: 50,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${r['nickname'] ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (power > 0)
                    Row(
                      children: [
                        const Icon(
                          Icons.flash_on_rounded,
                          size: 14,
                          color: kHoney,
                        ),
                        Text(
                          formatCompact(power.round()),
                          style: const TextStyle(
                            color: kHoney,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            Container(
              // 점수 칸은 **고정 폭** — `보스 54%` 와 `보스 8%` 처럼 글자 수가 달라도 칸이 같아야 줄이 맞는다.
              width: _abyss ? 78 : 72,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              decoration: BoxDecoration(
                color: mine ? const Color(0x55003A66) : const Color(0xFF22252E),
                borderRadius: BorderRadius.circular(10),
              ),
              // 심연은 층 아래에 벽 보스 피해를 작게 쌓는다 — 한 줄이면 좁은 폰(360)에서 넘친다.
              // 칸이 고정 폭이라 큰 글꼴 설정에서는 내용을 줄여 넣는다(넘치지 않게).
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!_abyss) ...[
                          const Icon(
                            Icons.star_rounded,
                            size: 18,
                            color: Color(0xFFFFC928),
                          ),
                          const SizedBox(width: 3),
                        ],
                        Text(
                          score,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    if (_abyss && bossPm > 0)
                      Text(
                        l.boardBossPct(bossPm ~/ 10),
                        style: const TextStyle(
                          color: Color(0xCCFFFFFF),
                          fontSize: 10.5,
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

  Widget _rankBadge(int rank) {
    if (rank <= 3) {
      // 금·은·동 원 + 숫자(아이콘 위에 숫자를 얹으면 작은 화면에서 안 읽혔다).
      const colors = [Color(0xFFFFC928), Color(0xFFD5DAE1), Color(0xFFE0955F)];
      const rims = [Color(0xFFB8860B), Color(0xFF8A939E), Color(0xFF9A5A2E)];
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors[rank - 1],
          border: Border.all(color: rims[rank - 1], width: 3),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 3)],
        ),
        alignment: Alignment.center,
        child: Text(
          '$rank',
          style: const TextStyle(
            color: Color(0xFF2A1A08),
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    }
    return Text(
      '$rank',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  /// 선물 아이콘 — **지금 순위로 받을 보상** + 이 리그(또는 심연)의 순위 보상표.
  Future<void> _showRewards(
    AppLocalizations l,
    GameData data,
    Map<String, dynamic> d,
  ) {
    final b = data.battleConfig ?? const BattleConfig();
    final league = '${d['league'] ?? ''}';
    final table = _abyss
        ? (data.runConfig?.abyss.rankRewards ?? const <SeasonRankReward>[])
        : (b.leagueRankRewards[league] ?? b.seasonRankRewards);
    final me = d['me'] is Map ? d['me'] as Map : null;
    final myRank = (me?['rank'] as num?)?.toInt();
    final myScore = _abyss
        ? (me?['floor'] as num?)?.toInt() ?? 0
        : (me?['trophies'] as num?)?.toInt() ?? 0;
    int jellyAt(int rank) {
      for (final r in table) {
        if (rank <= r.maxRank) return r.jelly;
      }
      return 0;
    }

    final nowJelly = myRank == null || myScore <= (_abyss ? 1 : 0)
        ? 0
        : jellyAt(myRank);
    var from = 1;
    final rows = <Widget>[];
    for (final r in table) {
      if (r.maxRank < from) continue;
      final hit = myRank != null && myRank >= from && myRank <= r.maxRank;
      rows.add(
        Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: hit ? const Color(0x331FA2F5) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  r.maxRank == from
                      ? l.pvpRankN(from)
                      : l.eventRankRange(from, r.maxRank),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              jellyIcon(size: 16),
              const SizedBox(width: 4),
              Text(
                '${r.jelly}',
                style: const TextStyle(
                  color: Color(0xFF9BE7FF),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      );
      from = r.maxRank + 1;
    }
    return showGameDialog<void>(
      context,
      title: _abyss
          ? l.boardAbyssRewardsTitle
          : l.boardRewardsTitle(leagueName(l, league)),
      iconWidget: rankImageDlg('trophy'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0x22FFFFFF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    myRank == null
                        ? (_abyss ? l.boardAbyssMeNone : l.boardMeNone)
                        : l.boardMyRankNow(myRank),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (myRank != null) ...[
                  jellyIcon(size: 18),
                  const SizedBox(width: 4),
                  Text(
                    '$nowJelly',
                    style: const TextStyle(
                      color: Color(0xFF9BE7FF),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ...rows,
          if (widget.rewardExtra != null) ...[
            const SizedBox(height: 10),
            widget.rewardExtra!,
          ],
        ],
      ),
      actions: [
        gameDialogButton(l.duelResultOk, () => Navigator.of(context).pop()),
      ],
    );
  }

  /// 내 결투 팀(출정 순서) — 곤충을 누르면 능력치.
  Future<void> _showMyTeam(AppLocalizations l) {
    final data = ref.read(gameDataProvider).value;
    final team = widget.myTeam!;
    final power = team.fold<double>(0, (a, x) => a + duelPowerOf(x, data));
    // 내 곤충의 이색·스킨 — 결투 곤충 id 가 곧 내 곤충 id 다.
    final bugs = {
      for (final b
          in ref.read(saveControllerProvider).value?.bugs ??
              const <IndividualBug>[])
        b.id: b,
    };
    final skinOf = ref.read(skinOfProvider);
    bool isVariant(String id) =>
        (bugs[id]?.variant ?? BugVariant.none) != BugVariant.none;
    return showGameDialog<void>(
      context,
      title: ref.read(saveControllerProvider).value?.nickname ?? '',
      // 내 스킨 뱃지 — 남들이 내 프로필에서 보는 것과 같은 규칙(곤충 스킨만).
      titleTrailing: skinBadges(
        publicSkins(
          data?.iapConfig,
          ref.read(saveControllerProvider).value?.ownedSkins ??
              const <String>{},
        ),
      ),
      icon: Icons.person_rounded,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.flash_on_rounded, size: 18, color: kHoney),
              Text(
                l.profileCombatPower(formatCompact(power.round())),
                style: const TextStyle(
                  color: kHoney,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final b in team)
                Expanded(
                  child: GestureDetector(
                    onTap: () => showDuelBugInfo(
                      context,
                      data,
                      b,
                      skin: bugs[b.id] == null
                          ? null
                          : bugView(skinOf, bugs[b.id]!),
                      variant: isVariant(b.id),
                    ),
                    child: _profileBug(
                      l,
                      data,
                      Localizations.localeOf(context).languageCode,
                      {
                        'sp': b.speciesId,
                        'element': b.element.name,
                        'power': duelPowerOf(b, data),
                        if (isVariant(b.id)) 'variant': bugs[b.id]!.variant.key,
                        'skin': ?skinOf(b.speciesId)?.effect,
                      },
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      actions: [
        gameDialogButton(l.duelResultOk, () => Navigator.of(context).pop()),
      ],
    );
  }

  /// 상대 프로필 응답 캐시(사람 → 받은 시각·응답) — 같은 사람을 다시 누르면 기다리지 않는다.
  static final Map<String, ({DateTime at, ServerResult res})> _profileCache =
      {};
  static const _profileTtl = Duration(minutes: 3);

  /// [previewPower] 는 서버 없는 개발 빌드의 가짜 프로필 전투력.
  Future<ServerResult> _loadProfile(String id, double previewPower) async {
    final hit = _profileCache[id];
    final now = DateTime.now();
    if (hit != null && now.difference(hit.at) < _profileTtl) return hit.res;
    final server = ref.read(gameServerProvider);
    final res = !server.available && !kReleaseMode
        ? ServerResult.ok(
            previewProfile(id, [
              for (final sp
                  in ref.read(gameDataProvider).requireValue.allSpecies)
                sp.id,
            ], previewPower),
          )
        : await server.pvpProfile(id);
    if (res.isOk) _profileCache[id] = (at: now, res: res);
    return res;
  }

  /// 상대 프로필 — 방어팀 곤충 3마리와 전투력(서버가 그 사람의 세이브로 계산).
  ///
  /// 창은 **누르자마자** 연다(2026-10-10 실기 지적). 예전엔 서버 응답(0.2~0.5초, 새 서버 인스턴스면 더)을 받은 뒤에야
  /// 열어서, 그동안 아무 반응이 없어 "느리다"로 읽혔다. 이름·전투력은 순위표 값으로 바로 그리고 곤충만 받아서 채운다.
  Future<void> _showProfile(AppLocalizations l, Map<String, dynamic> r) async {
    final id = '${r['user_id']}';
    final power = (r['power'] as num?)?.toDouble() ?? 0;
    final profile = _loadProfile(id, power > 0 ? power : 1e6);
    final data = ref.read(gameDataProvider).value;
    final locale = Localizations.localeOf(context).languageCode;
    await showGameDialog<void>(
      context,
      title: '${r['nickname'] ?? ''}',
      // 그 사람이 산 곤충 스킨(서버가 세이브의 ownedSkins 에서 골라 준다). 구서버면 없음.
      titleTrailing: FutureBuilder<ServerResult>(
        future: profile,
        builder: (_, snap) {
          final res = snap.data;
          return skinBadges(
            res != null && res.isOk
                ? skinsFromJson(res.data?['skins'])
                : const [],
          );
        },
      ),
      // 그 사람의 프로필 그림(2026-10-10).
      iconWidget: AvatarCircle(id: r['avatar'] as String?, size: 40),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (power > 0)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.flash_on_rounded, size: 18, color: kHoney),
                Text(
                  l.profileCombatPower(formatCompact(power.round())),
                  style: const TextStyle(
                    color: kHoney,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 10),
          FutureBuilder<ServerResult>(
            future: profile,
            builder: (context, snap) {
              final res = snap.data;
              if (res == null) {
                return const SizedBox(
                  height: 96,
                  child: Center(
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: kHoney,
                      ),
                    ),
                  ),
                );
              }
              final team = res.isOk
                  ? [
                      for (final t in (res.data?['team'] as List? ?? const []))
                        Map<String, dynamic>.from(t as Map),
                    ]
                  : const <Map<String, dynamic>>[];
              if (team.isEmpty) {
                return Text(
                  res.isOk ? l.profileNoTeam : l.battleServerFailed,
                  style: const TextStyle(color: Color(0xCCFFFFFF)),
                );
              }
              return Row(
                children: [
                  for (final t in team)
                    Expanded(
                      child: GestureDetector(
                        // 곤충을 누르면 능력치(서버가 그 사람 세이브로 계산한 값).
                        onTap: t['bug'] is Map
                            ? () => showDuelBugInfo(
                                context,
                                data,
                                DuelBug.fromJson(
                                  Map<String, dynamic>.from(t['bug'] as Map),
                                ),
                                skin: foeBugView(
                                  data?.iapConfig,
                                  '${t['sp']}',
                                  variant: t['variant']?.toString(),
                                  skin: t['skin']?.toString(),
                                ),
                                variant: isVariantKey(t['variant']?.toString()),
                              )
                            : null,
                        child: _profileBug(l, data, locale, t),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      actions: [
        gameDialogButton(l.duelResultOk, () => Navigator.of(context).pop()),
      ],
    );
  }

  Widget _profileBug(
    AppLocalizations l,
    GameData? data,
    String locale,
    Map<String, dynamic> t,
  ) => duelProfileBugTile(l, data, locale, t);
}

/// 방어팀 곤충 한 칸(그림·이름·오행·전투력) — `/pvp/profile` 의 `team` 한 줄 모양.
/// 리그 순위표 프로필과 길드원 정보 시트가 같은 칸을 쓴다.
/// `variant`(이색 키)·`skin`(스킨 효과 키)이 있으면 그 외형으로 그리고, 이색이면 칩을 단다.
Widget duelProfileBugTile(
  AppLocalizations l,
  GameData? data,
  String locale,
  Map<String, dynamic> t,
) {
  final sp = '${t['sp']}';
  final el = Element.values.where((e) => e.name == t['element']).firstOrNull;
  final variant = isVariantKey(t['variant']?.toString());
  String name = sp;
  try {
    name = data?.species(sp).name.resolve(locale) ?? sp;
  } catch (_) {}
  return Column(
    children: [
      Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: const Color(0x22FFFFFF),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.all(4),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: bugStageImage(
                sp,
                LifeStage.adult,
                size: 56,
                skin: foeBugView(
                  data?.iapConfig,
                  sp,
                  variant: t['variant']?.toString(),
                  skin: t['skin']?.toString(),
                ),
                fallback: const Icon(Icons.bug_report, color: Colors.white54),
              ),
            ),
            if (variant)
              Positioned(
                top: -2,
                left: -2,
                child: duelInfoChip(l.dexVariant, kVariantChipColor),
              ),
          ],
        ),
      ),
      const SizedBox(height: 4),
      Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
      if (el != null)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            elementIcon(el, size: 12),
            const SizedBox(width: 2),
            Text(
              elementLabel(l, el),
              style: TextStyle(color: elementColor(el), fontSize: 10.5),
            ),
          ],
        ),
      Text(
        formatCompact(((t['power'] as num?) ?? 0).round()),
        style: const TextStyle(
          color: kHoney,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    ],
  );
}

/// 리그 id → 화면 이름(결투 화면·순위표·결산 팝업 공용).
String leagueName(AppLocalizations l, String id) => switch (id) {
  'bronze' => l.leagueBronze,
  'silver' => l.leagueSilver,
  'gold' => l.leagueGold,
  'platinum' => l.leaguePlatinum,
  'diamond' => l.leagueDiamond,
  _ => id,
};
