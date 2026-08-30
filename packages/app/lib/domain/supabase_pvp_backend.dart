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
  Future<Leaderboard> leaderboard({
    required PvpProfile me,
    int limit = 50,
    RankingKind kind = RankingKind.trophies,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      return fallback.leaderboard(me: me, limit: limit, kind: kind);
    }
    try {
      // 1) 내 프로필 upsert(닉네임·트로피·레벨·진행도).
      //    레벨/스테이지도 올려야 그 축의 랭킹이 성립한다.
      await _client.from('profiles').upsert({
        'id': uid,
        'nickname': me.nickname,
        'trophies': me.trophies,
        'level': me.level,
        'stage': me.stageNumber,
        // 회차를 안 올리면 서버는 회차를 넘어간 유저를 스테이지 1 로 본다 —
        // 넘어가는 순간 진행도 랭킹 꼴찌가 되어 넘어갈 이유가 사라진다.
        'tier': me.difficultyTier,
      });
      // 2) 상위 N 조회(RPC). 정렬 축은 서버가 받는다 — 클라가 받아서
      //    다시 정렬하면 상위 N 이 트로피 기준으로 잘린 뒤라 틀린 목록이 된다.
      final rows =
          (await _client.rpc(
                'leaderboard_top',
                params: {'lim': limit, 'sort': kind.key},
              ))
              as List;
      final entries = <LeaderboardEntry>[
        for (final r in rows.cast<Map<String, dynamic>>())
          LeaderboardEntry(
            rank: (r['rank'] as num).toInt(),
            isMe: r['id'] == uid,
            badge: (r['badge'] as String?) ?? '',
            profile: PvpProfile(
              id: r['id'] as String,
              nickname: (r['nickname'] as String?) ?? '',
              trophies: (r['trophies'] as num?)?.toInt() ?? 0,
              level: (r['level'] as num?)?.toInt() ?? 1,
              stageNumber: (r['stage'] as num?)?.toInt() ?? 1,
              difficultyTier: (r['tier'] as num?)?.toInt() ?? 0,
            ),
          ),
      ];
      // 내가 상위권 밖이면 표시용으로 말미에 덧붙임(정확한 순위는 후속 인크리먼트).
      if (!entries.any((e) => e.isMe)) {
        entries.add(
          LeaderboardEntry(rank: entries.length + 1, profile: me, isMe: true),
        );
      }
      return Leaderboard(entries: entries, live: true);
    } catch (_) {
      // 화면이 비지 않게 NPC 사다리로 폴백하되, live=false 로 **사실대로** 알린다.
      return fallback.leaderboard(me: me, limit: limit, kind: kind);
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
        // ⚠️ **나 자신은 상대로 뜨면 안 된다.** RPC 가 걸러 주길 기대하지 말고
        // 여기서도 막는다. 유저가 적을 땐 근처 트로피 방어팀이 내 것뿐이라
        // 내가 나와 싸우게 되는데, 스킨이 붙고 나서야 그게 드러났다
        // ("왜 상대도 내 스킨이 보이지?" — 실기 지적 2026-08-19).
        if (r['id'] == uid) continue;
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

  /// 상위 [_rankScanLimit] 안에서 내 순위를 찾는다. 밖이면 null(= "순위권 밖").
  ///
  /// 세션(uid)이 없으면 **폴백하지 않고 null** — 로컬 사다리 순위가 진짜 순위인
  /// 것처럼 캐시되는 사고를 막는다(2026-08: 77위로 굳던 버그).
  @override
  Future<int?> myRank({required PvpProfile me}) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    try {
      await _client.from('profiles').upsert({
        'id': uid,
        'nickname': me.nickname,
        'trophies': me.trophies,
      });
      final rows =
          (await _client.rpc(
                'leaderboard_top',
                params: {'lim': _rankScanLimit},
              ))
              as List;
      for (final r in rows.cast<Map<String, dynamic>>()) {
        if (r['id'] == uid) return (r['rank'] as num).toInt();
      }
      return null; // 상위권 밖 — 지어내지 않는다.
    } catch (_) {
      return null;
    }
  }

  /// 순위를 훑어볼 상위 인원. 플레이어 수가 커지면 전용 RPC 로 교체할 것.
  static const _rankScanLimit = 200;

  /// RPC `nickname_taken`(SECURITY DEFINER) — profiles 는 RLS 로 본인 행만
  /// 보이므로 직접 select 로는 다른 유저의 닉네임을 확인할 수 없다.
  /// 함수 SQL 은 docs/backend_supabase.md §9. 실패·미배포 시 false(막지 않음).
  @override
  Future<bool> isNicknameTaken(String name) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return false;
    try {
      final r = await _client.rpc(
        'nickname_taken',
        params: {'p_name': name.trim()},
      );
      return r == true;
    } catch (_) {
      return false;
    }
  }
}
