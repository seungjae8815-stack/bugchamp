import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/auth_service.dart';
import '../../domain/providers.dart';
import '../../domain/pvp_backend.dart';
import '../../domain/save_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/format.dart';

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
class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  static String _leagueEmoji(String id) => switch (id) {
    'bronze' => '🥉',
    'silver' => '🥈',
    'gold' => '🥇',
    'platinum' => '💠',
    'diamond' => '💎',
    _ => '🏅',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    );

    return Scaffold(
      appBar: AppBar(title: Text(l.rankingTitle)),
      body: FutureBuilder<Leaderboard>(
        future: backend.leaderboard(me: me, limit: 50),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final board = snap.data!;
          return Column(
            children: [
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
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.emoji_events_rounded,
                                color: _honey,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                l.leaderboardMyRank(myRank),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '🏆 ${save.pvpTrophies}',
                                style: const TextStyle(
                                  color: _honey,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: e.isMe
            ? _honey.withValues(alpha: 0.16)
            : const Color(0x18000000),
        borderRadius: BorderRadius.circular(10),
        border: e.isMe
            ? Border.all(color: _honey.withValues(alpha: 0.7))
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
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(_leagueEmoji(league.id), style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
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
                fontWeight: e.isMe ? FontWeight.w900 : FontWeight.w600,
                fontSize: 13.5,
              ),
            ),
          ),
          Text(
            '🏆 ${formatCompact(e.profile.trophies)}',
            style: const TextStyle(
              color: Color(0xCCFFFFFF),
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}
