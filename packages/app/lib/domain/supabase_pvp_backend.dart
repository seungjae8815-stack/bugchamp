import 'package:supabase_flutter/supabase_flutter.dart';

import 'pvp_backend.dart';

/// Supabase 기반 [PvpBackend] (Phase 4 실연동).
///
/// 스키마·RLS·RPC 는 `docs/backend_supabase.md` 참조. 네트워크/인증 실패 시
/// [fallback](기본 로컬)로 자동 폴백해 랭킹 화면이 항상 동작하게 한다.
class SupabasePvpBackend implements PvpBackend {
  SupabasePvpBackend(this._client, {this.fallback = const LocalPvpBackend()});

  final SupabaseClient _client;
  final PvpBackend fallback;

  @override
  Future<List<LeaderboardEntry>> leaderboard({
    required PvpProfile me,
    int limit = 50,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return fallback.leaderboard(me: me, limit: limit);
    try {
      // 1) 내 프로필 upsert(닉네임·트로피).
      await _client.from('profiles').upsert({
        'id': uid,
        'nickname': me.nickname,
        'trophies': me.trophies,
      });
      // 2) 상위 N 조회(RPC).
      final rows =
          (await _client.rpc('leaderboard_top', params: {'lim': limit}))
              as List;
      final entries = <LeaderboardEntry>[
        for (final r in rows.cast<Map<String, dynamic>>())
          LeaderboardEntry(
            rank: (r['rank'] as num).toInt(),
            isMe: r['id'] == uid,
            profile: PvpProfile(
              id: r['id'] as String,
              nickname: (r['nickname'] as String?) ?? '',
              trophies: (r['trophies'] as num?)?.toInt() ?? 0,
            ),
          ),
      ];
      // 내가 상위권 밖이면 표시용으로 말미에 덧붙임(정확한 순위는 후속 인크리먼트).
      if (!entries.any((e) => e.isMe)) {
        entries.add(
          LeaderboardEntry(rank: entries.length + 1, profile: me, isMe: true),
        );
      }
      return entries;
    } catch (_) {
      return fallback.leaderboard(me: me, limit: limit);
    }
  }
}
