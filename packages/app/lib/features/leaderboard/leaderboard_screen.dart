import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/providers.dart';
import '../../domain/pvp_backend.dart';
import '../../domain/save_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/format.dart';

const _honey = Color(0xFFEBA52F);

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
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6),
            color: const Color(0x22000000),
            child: Text(
              backend.isRemote
                  ? l.leaderboardOnlineNote
                  : l.leaderboardLocalNote,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 11),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<LeaderboardEntry>>(
              future: backend.leaderboard(me: me, limit: 50),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final entries = snap.data!;
                final myRank = entries
                    .firstWhere(
                      (e) => e.isMe,
                      orElse: () =>
                          LeaderboardEntry(rank: 0, profile: me, isMe: true),
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
                        padding: const EdgeInsets.symmetric(vertical: 6),
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
