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
  bool get isRemote => true;

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

  /// 내 방어팀 스냅샷을 `defenders` 테이블에 업서트(id = auth.uid()).
  /// 오프라인/에러는 조용히 무시 — 다음 진입 때 다시 등록된다.
  @override
  Future<void> registerDefender({
    required PvpProfile me,
    required List<DefenderBug> team,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await _client.from('defenders').upsert({
        'id': uid,
        'team': [for (final b in team) b.toJson()],
        'trophies': me.trophies,
      });
    } catch (_) {
      // 등록 실패는 게임 흐름을 막지 않는다.
    }
  }

  /// 내 트로피 근처의 다른 유저 방어팀을 RPC(`nearby_defenders`)로 조회.
  /// 실패하면 빈 리스트 → 호출측이 로컬 합성 상대로 채운다.
  @override
  Future<List<DefenderTeam>> fetchOpponents({
    required PvpProfile me,
    int count = 3,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const [];
    try {
      final rows =
          (await _client.rpc(
                'nearby_defenders',
                params: {'my_trophies': me.trophies, 'lim': count},
              ))
              as List;
      final teams = <DefenderTeam>[];
      for (final r in rows.cast<Map<String, dynamic>>()) {
        final raw = (r['team'] as List?) ?? const [];
        final bugs = <DefenderBug>[
          for (final b in raw)
            DefenderBug.fromJson(Map<String, dynamic>.from(b as Map)),
        ];
        if (bugs.isEmpty) continue;
        final name = (r['nickname'] as String?) ?? '';
        teams.add(
          DefenderTeam(
            ownerId: r['id'] as String,
            ownerName: name.isEmpty ? '???' : name,
            trophies: (r['trophies'] as num?)?.toInt() ?? 0,
            bugs: bugs,
          ),
        );
      }
      return teams;
    } catch (_) {
      return const [];
    }
  }

  /// 승패 후 내 트로피를 즉시 반영: 리더보드 프로필 upsert + 방어팀 행 트로피 갱신.
  /// 방어팀 미등록이면 update 는 0행(무시). 실패는 조용히 무시.
  @override
  Future<void> pushTrophies({required PvpProfile me}) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await _client.from('profiles').upsert({
        'id': uid,
        'nickname': me.nickname,
        'trophies': me.trophies,
      });
      await _client
          .from('defenders')
          .update({'trophies': me.trophies})
          .eq('id', uid);
    } catch (_) {
      // 트로피 반영 실패는 다음 진입/전투 때 재시도된다.
    }
  }
}
