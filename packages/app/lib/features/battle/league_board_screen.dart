import 'dart:async';

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:flutter/material.dart' hide Element;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/game_data.dart';
import '../../domain/chat_service.dart';
import '../../domain/game_server.dart';
import '../../domain/providers.dart';
import '../../domain/save_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/art.dart';
import '../../ui/format.dart';
import '../../ui/game_dialog.dart';

/// 순위표(2026-09-29 사장님 요청 — 다른 게임의 리그 화면을 참고).
///
/// - **결투 리그**: 리그 = 등급 하나. 같은 리그의 이번 주 트로피 순위 상위 100명 · 상위 20% 승급 ·
///   하위 20% 강등(서버가 일요일 24시에 결산). 선물 아이콘 = 이 리그의 순위 보상표.
/// - **심연**: 이번 주 전체 최고 층 순위(층 → 벽 보스 피해 → 먼저 도달).
///
/// 순위는 전부 **서버 전용 기록**에서 온다(앱이 쓰는 `profiles.trophies` 가 아니다).
class LeagueBoardScreen extends ConsumerStatefulWidget {
  const LeagueBoardScreen({super.key, this.abyssFirst = false});

  /// 심연 탭으로 열기.
  final bool abyssFirst;

  @override
  ConsumerState<LeagueBoardScreen> createState() => _LeagueBoardScreenState();
}

class _LeagueBoardScreenState extends ConsumerState<LeagueBoardScreen> {
  late bool _abyss = widget.abyssFirst;
  Map<String, dynamic>? _duel;
  Map<String, dynamic>? _abyssData;
  bool _loading = false;
  bool _failed = false;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _load();
    // 결산 카운트다운을 분 단위로 갱신한다.
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final server = ref.read(gameServerProvider);
    setState(() {
      _loading = true;
      _failed = false;
    });
    final ServerResult res = _abyss
        ? await server.abyssBoard()
        : await server.pvpLeagueBoard();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.isOk) {
        if (_abyss) {
          _abyssData = res.data;
        } else {
          _duel = res.data;
        }
      } else {
        _failed = true;
      }
    });
  }

  void _switch(bool abyss) {
    if (abyss == _abyss) return;
    setState(() => _abyss = abyss);
    if ((abyss ? _abyssData : _duel) == null) _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final data = _abyss ? _abyssData : _duel;
    return Scaffold(
      backgroundColor: const Color(0xFF3F4452),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2F333E),
        title: Text(l.boardTitle),
      ),
      body: Column(
        children: [
          _tabs(l),
          Expanded(
            child: _loading && data == null
                ? const Center(child: CircularProgressIndicator())
                : _failed && data == null
                ? _message(l.battleServerFailed, retry: true)
                : data == null
                ? const SizedBox.shrink()
                : _board(l, data),
          ),
        ],
      ),
    );
  }

  Widget _tabs(AppLocalizations l) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
    child: Row(
      children: [
        for (final (abyss, label) in [
          (false, l.boardTabDuel),
          (true, l.boardTabAbyss),
        ])
          Expanded(
            child: GestureDetector(
              onTap: () => _switch(abyss),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _abyss == abyss
                      ? const Color(0xFFEBA52F)
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
  );

  Widget _message(String text, {bool retry = false}) => Center(
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
            onPressed: _load,
            child: const Icon(Icons.refresh_rounded, color: Colors.white),
          ),
      ],
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
    final myId = ref.read(chatMyUserIdProvider);
    final total = (d['total'] as num?)?.toInt() ?? top.length;
    final promote = (d['promote'] as num?)?.toInt() ?? 0;
    final demote = (d['demote'] as num?)?.toInt() ?? 0;
    final myRow = top.where((r) => r['user_id'] == myId).firstOrNull;

    return Column(
      children: [
        _header(l, d),
        Expanded(
          child: top.isEmpty
              ? _message(l.boardEmpty)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    itemCount: top.length,
                    itemBuilder: (_, i) {
                      final r = top[i];
                      final rank = (r['rank'] as num?)?.toInt() ?? i + 1;
                      final zone = _abyss
                          ? 0
                          : (rank <= promote
                                ? 1
                                : (demote > 0 && rank > total - demote
                                      ? -1
                                      : 0));
                      return _row(
                        l,
                        r,
                        rank,
                        mine: r['user_id'] == myId,
                        zone: zone,
                      );
                    },
                  ),
                ),
        ),
        // 하단 고정 — 내 줄.
        Container(
          color: const Color(0xFF2F333E),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: SafeArea(
            top: false,
            child: me == null
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                      _abyss ? l.boardAbyssMeNone : l.boardMeNone,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xCCFFFFFF)),
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
                  ),
          ),
        ),
      ],
    );
  }

  Widget _header(AppLocalizations l, Map<String, dynamic> d) {
    final ends = DateTime.tryParse('${d['endsAt']}');
    final left = ends == null
        ? Duration.zero
        : ends.difference(DateTime.now().toUtc());
    final league = '${d['league'] ?? ''}';
    final data = ref.read(gameDataProvider).value;
    final promote = (d['promote'] as num?)?.toInt() ?? 0;
    final demote = (d['demote'] as num?)?.toInt() ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Column(
        children: [
          SizedBox(
            height: 84,
            child: _abyss
                ? const Icon(
                    Icons.nights_stay_rounded,
                    size: 72,
                    color: Color(0xFFB388FF),
                  )
                : gameImageChain(
                    ['assets/images/ui/league/$league.png'],
                    size: 84,
                    fallback: const Icon(
                      Icons.emoji_events_rounded,
                      size: 72,
                      color: Color(0xFFEBC24A),
                    ),
                  ),
          ),
          const SizedBox(height: 4),
          Text(
            _abyss
                ? l.boardAbyssTitle
                : l.boardLeagueTitle(leagueName(l, league)),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: data == null ? null : () => _showRewards(l, data, league),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
                  const SizedBox(width: 8),
                  Text(
                    l.boardSeasonEndsIn(_left(l, left)),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!_abyss && (promote > 0 || demote > 0)) ...[
            const SizedBox(height: 6),
            Text(
              l.boardZonesHint(promote, demote),
              style: const TextStyle(color: Color(0xAAFFFFFF), fontSize: 11.5),
            ),
          ],
        ],
      ),
    );
  }

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
  }) {
    final sp = '${r['sp'] ?? ''}';
    final power = (r['power'] as num?)?.toDouble() ?? 0;
    final score = _abyss
        ? l.boardFloorShort((r['floor'] as num?)?.toInt() ?? 0)
        : '${(r['trophies'] as num?)?.toInt() ?? 0}';
    final bossPm = (r['boss_pm'] as num?)?.toInt() ?? 0;
    final bg = mine ? const Color(0xFF1FA2F5) : const Color(0xFF2F333E);
    final edge = zone > 0
        ? const Color(0xFF6FCF6F)
        : (zone < 0 ? const Color(0xFFEF6B6B) : Colors.transparent);
    return Container(
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
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(3),
            child: gameImageChain(
              [
                'assets/images/bugs/${sp}_adult.webp',
                'assets/images/bugs/$sp.webp',
              ],
              size: 42,
              fallback: const Icon(Icons.bug_report, color: Colors.black45),
            ),
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
                        color: Color(0xFFEBC24A),
                      ),
                      Text(
                        formatCompact(power.round()),
                        style: const TextStyle(
                          color: Color(0xFFEBC24A),
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: mine ? const Color(0x55003A66) : const Color(0xFF22252E),
              borderRadius: BorderRadius.circular(10),
            ),
            // 심연은 층 아래에 벽 보스 피해를 작게 쌓는다 — 한 줄이면 좁은 폰(360)에서 넘친다.
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_abyss) ...[
                      rankImage('trophy', size: 16, fallback: const SizedBox()),
                      const SizedBox(width: 4),
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
                    '${bossPm ~/ 10}%',
                    style: const TextStyle(
                      color: Color(0xCCFFFFFF),
                      fontSize: 10.5,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rankBadge(int rank) {
    if (rank <= 3) {
      const colors = [Color(0xFFFFC928), Color(0xFFC9CED6), Color(0xFFD9895B)];
      return Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.workspace_premium_rounded,
            size: 40,
            color: colors[rank - 1],
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              '$rank',
              style: const TextStyle(
                color: Color(0xFF3A2410),
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
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

  /// 선물 아이콘 — 이 리그(또는 심연)의 순위 보상표.
  Future<void> _showRewards(AppLocalizations l, GameData data, String league) {
    final b = data.battleConfig ?? const BattleConfig();
    final table = _abyss
        ? (data.runConfig?.abyss.rankRewards ?? const <SeasonRankReward>[])
        : (b.leagueRankRewards[league] ?? b.seasonRankRewards);
    var from = 1;
    final rows = <Widget>[];
    for (final r in table) {
      if (r.maxRank < from) continue;
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
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
              materialImage(
                MaterialKind.jelly,
                size: 16,
                fallback: const SizedBox(width: 16),
              ),
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
      content: Column(mainAxisSize: MainAxisSize.min, children: rows),
      actions: [
        gameDialogButton(l.duelResultOk, () => Navigator.of(context).pop()),
      ],
    );
  }
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
