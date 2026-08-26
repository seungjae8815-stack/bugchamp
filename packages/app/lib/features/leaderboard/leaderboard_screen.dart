import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/auth_service.dart';
import '../../domain/providers.dart';
import '../../domain/pvp_backend.dart';
import '../../domain/save_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/art.dart';
import '../../ui/format.dart';
import '../../ui/labels.dart';
import '../../ui/event_badge.dart';

const _honey = Color(0xFFEBA52F);

/// 로그인(비익명) 시 내 현재 랭킹. 미로그인·실패·미확정이면 null.
/// 트로피/닉네임이 바뀔 때만 재조회(select) — 매 세이브마다 네트워크 호출 방지.
final myRankProvider = FutureProvider<int?>((ref) async {
  final auth = ref.watch(authServiceProvider);
  if (!auth.available || !auth.isSignedIn) return null;
  final trophies = ref.watch(
    saveControllerProvider.select((s) => s.asData?.value.pvpTrophies ?? 0),
  );
  final nickname = ref.watch(
    saveControllerProvider.select((s) => s.asData?.value.nickname ?? ''),
  );
  final backend = ref.watch(pvpBackendProvider);
  try {
    final board = await backend.leaderboard(
      me: PvpProfile(id: 'me', nickname: nickname, trophies: trophies),
      limit: 50,
    );
    if (!board.live) return null; // 폴백(NPC)은 순위로 쓰지 않는다
    for (final e in board.entries) {
      if (e.isMe) return e.rank;
    }
  } catch (_) {}
  return null;
});

/// 랭킹(리더보드) 화면. [PvpBackend] 를 통해 순위를 가져온다(로컬→추후 Supabase).
///
/// 축이 셋이다(트로피/레벨/진행도). 트로피 하나만 두면 **결투를 안 하는
/// 유저에겐 랭킹이 없다** — 이 게임의 주된 플레이는 방치 런이다.
class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  RankingKind _kind = RankingKind.trophies;

  String _kindLabel(AppLocalizations l, RankingKind k) => switch (k) {
    RankingKind.trophies => l.rankKindTrophies,
    RankingKind.level => l.rankKindLevel,
    RankingKind.stage => l.rankKindStage,
  };

  /// 축 아이콘. 애셋이 있으면 그림, 없으면 글리프로 폴백한다(§6 아트 규칙).
  Widget _kindIcon(RankingKind k, {double size = 15}) => switch (k) {
    RankingKind.trophies => Text('🏆', style: TextStyle(fontSize: size)),
    RankingKind.level => Text(
      'Lv',
      style: TextStyle(
        fontSize: size - 2,
        color: _honey,
        fontWeight: FontWeight.w900,
      ),
    ),
    // 진행도(도달 스테이지) — 핀 이모지는 "위치"로 읽혀 진행도로 안 보인다.
    // 애셋을 넣으면 자동으로 그림으로 바뀐다.
    RankingKind.stage => gameImage(
      'assets/images/ui/rank_stage.webp',
      width: size,
      height: size,
      fallback: Icon(Icons.flag_rounded, size: size, color: _honey),
    ),
  };

  /// 축마다 점수 표기가 다르다 — 전부 🏆 로 쓰면 레벨 랭킹이 트로피처럼 보인다.
  String _scoreText(AppLocalizations l, PvpProfile p, RankingKind k) =>
      switch (k) {
        RankingKind.trophies => formatCompact(p.trophies),
        RankingKind.level => formatCompact(p.level),
        RankingKind.stage => formatCompact(p.stageNumber),
      };

  /// 점수 칸 — **고정 폭**. 자연 크기로 두면 줄마다 아이콘·숫자 위치가
  /// 제각각이라 "내 순위" 줄과도 안 맞는다(세로로 흐트러져 읽힌다).
  Widget _scoreCell(
    AppLocalizations l,
    PvpProfile p,
    RankingKind k, {
    required bool emphasize,
  }) => SizedBox(
    width: 96,
    child: Row(
      children: [
        // 진행도 아이콘은 그림(타일 프레임 포함)이라 글리프보다 여백이 필요하다.
        SizedBox(
          width: 24,
          child: Center(
            child: _kindIcon(k, size: k == RankingKind.stage ? 22 : 15),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            _scoreText(l, p, k),
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: emphasize ? _honey : const Color(0xCCFFFFFF),
              fontWeight: emphasize ? FontWeight.w900 : FontWeight.w700,
              fontSize: emphasize ? 14 : 12.5,
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final save = ref.watch(saveControllerProvider).requireValue;
    final data = ref.watch(gameDataProvider).requireValue;
    final cfg = data.battleConfig ?? const BattleConfig();
    final rules = data.chatRules ?? const ChatRules();
    final backend = ref.watch(pvpBackendProvider);
    final me = PvpProfile(
      id: 'me',
      nickname: save.nickname,
      trophies: save.pvpTrophies,
      level: save.level,
      stageNumber: save.stageNumber,
    );

    return Scaffold(
      appBar: AppBar(title: Text(l.rankingTitle)),
      body: FutureBuilder<Leaderboard>(
        // 축을 바꾸면 다시 조회한다 — key 가 없으면 FutureBuilder 가 이전
        // 결과를 그대로 들고 있어 탭만 바뀌고 목록은 그대로다.
        key: ValueKey(_kind),
        future: backend.leaderboard(me: me, limit: 50, kind: _kind),
        builder: (context, snap) {
          if (!snap.hasData) {
            return Column(
              children: [
                _kindTabs(l),
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            );
          }
          final board = snap.data!;
          return Column(
            children: [
              _kindTabs(l),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6),
                color: const Color(0x22000000),
                child: Text(
                  // **이번 조회가 실제로 서버에서 왔는지**로 안내한다.
                  // 백엔드 종류로 쓰면 조회 실패로 NPC 를 보여주면서도
                  // "온라인 랭킹"이라고 우기게 된다.
                  board.live ? l.leaderboardOnlineNote : l.leaderboardLocalNote,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0x99FFFFFF),
                    fontSize: 11,
                  ),
                ),
              ),
              Expanded(
                child: Builder(
                  builder: (context) {
                    final entries = board.entries;
                    final myRank = entries
                        .firstWhere(
                          (e) => e.isMe,
                          orElse: () => LeaderboardEntry(
                            rank: 0,
                            profile: me,
                            isMe: true,
                          ),
                        )
                        .rank;
                    return Column(
                      children: [
                        Padding(
                          // 좌우 여백은 **목록 줄과 같은 24**(margin 12 +
                          // padding 12). 다르면 내 점수와 목록 점수가
                          // 세로로 어긋나 보인다.
                          padding: const EdgeInsets.fromLTRB(24, 10, 24, 6),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.emoji_events_rounded,
                                color: _honey,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  l.leaderboardMyRank(myRank),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              _scoreCell(l, me, _kind, emphasize: true),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: Color(0x22FFFFFF)),
                        Expanded(
                          child: ListView.builder(
                            // 마지막 줄이 **기기 하단 바에 가려지지 않게** 그만큼 더
                            // 띄운다. 안드로이드 제스처 바·아이폰 홈 인디케이터 높이가
                            // viewPadding.bottom 이다(0인 기기도 있어 그대로 더한다).
                            padding: EdgeInsets.only(
                              top: 6,
                              bottom:
                                  6 + MediaQuery.viewPaddingOf(context).bottom,
                            ),
                            itemCount: entries.length,
                            itemBuilder: (context, i) =>
                                _row(cfg, entries[i], rules, l),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 랭킹 축 선택 탭.
  Widget _kindTabs(AppLocalizations l) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
    child: Row(
      children: [
        for (final k in RankingKind.values)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: GestureDetector(
                onTap: () => setState(() => _kind = k),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _kind == k
                        ? _honey.withValues(alpha: 0.22)
                        : const Color(0x18FFFFFF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _kind == k ? _honey : const Color(0x22FFFFFF),
                    ),
                  ),
                  child: Text(
                    _kindLabel(l, k),
                    style: TextStyle(
                      color: _kind == k ? _honey : const Color(0x99FFFFFF),
                      fontWeight: FontWeight.w900,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _row(
    BattleConfig cfg,
    LeaderboardEntry e,
    ChatRules rules,
    AppLocalizations l,
  ) {
    final league = cfg.leagueFor(e.profile.trophies);
    final rankColor = switch (e.rank) {
      1 => const Color(0xFFEBC24A),
      2 => const Color(0xFFC0C7D0),
      3 => const Color(0xFFB87333),
      _ => const Color(0x99FFFFFF),
    };
    // 상위 3위는 **줄 자체가 달라야** 한다. 숫자 색만 바꿔서는 스크롤하며
    // 훑을 때 1등이 어디인지 안 보인다 — 순위표의 목적이 "누가 위인가"다.
    final top = e.rank <= 3;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: top ? 12 : 9),
      decoration: BoxDecoration(
        color: e.isMe
            ? _honey.withValues(alpha: 0.16)
            : (top
                  ? rankColor.withValues(alpha: 0.13)
                  : const Color(0x18000000)),
        borderRadius: BorderRadius.circular(10),
        border: e.isMe
            ? Border.all(color: _honey.withValues(alpha: 0.7))
            : (top
                  ? Border.all(color: rankColor.withValues(alpha: 0.55))
                  : null),
        boxShadow: top
            ? [
                BoxShadow(
                  color: rankColor.withValues(alpha: 0.22),
                  blurRadius: 10,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              '${e.rank}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: rankColor,
                fontWeight: FontWeight.w900,
                fontSize: top ? 19 : 15,
                shadows: top
                    ? [
                        Shadow(
                          color: rankColor.withValues(alpha: 0.6),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 6),
          // 리그 뱃지는 **트로피 랭킹에서만** 의미가 있다 — 레벨/진행도 줄에
          // 붙이면 그 유저의 결투 등급인 것처럼 읽힌다.
          if (_kind == RankingKind.trophies) ...[
            leagueIcon(league.id, size: top ? 24 : 16),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              // 부적절한 닉네임은 표시 단계에서 대체(채팅과 같은 기준).
              rules.maskNickname(
                e.profile.nickname,
                fallback: l.nicknameFallback,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontWeight: (e.isMe || top) ? FontWeight.w900 : FontWeight.w600,
                fontSize: top ? 15 : 13.5,
              ),
            ),
          ),
          // 대회 회차 뱃지 — 리그 뱃지와 달리 **모든 축**에 붙는다.
          // 결투를 안 하는 유저도 대회에는 나가고, 그게 이 표식의 요지다.
          EventBadgeChip(id: e.badge, size: top ? 12 : 10.5),
          const Spacer(),
          _scoreCell(l, e.profile, _kind, emphasize: e.isMe),
        ],
      ),
    );
  }
}
