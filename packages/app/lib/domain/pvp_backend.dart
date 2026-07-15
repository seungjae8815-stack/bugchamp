import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 비동기 PvP·리더보드 백엔드 추상화 (Phase 4).
///
/// `Clock` 과 같은 "인터페이스 + 로컬 구현, 추후 교체" 패턴이다. 지금은
/// [LocalPvpBackend] 가 로컬로 리더보드를 만들고, Supabase 연동 시
/// [SupabasePvpBackend] 같은 구현으로 [pvpBackendProvider] 를 오버라이드한다.
/// (Supabase 스키마·연동 절차: docs/backend_supabase.md)

/// PvP 플레이어 프로필(리더보드 표시 단위).
class PvpProfile {
  const PvpProfile({
    required this.id,
    required this.nickname,
    required this.trophies,
  });

  final String id;
  final String nickname;
  final int trophies;
}

/// 리더보드 한 줄.
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.profile,
    required this.isMe,
  });

  final int rank;
  final PvpProfile profile;
  final bool isMe;
}

/// 비동기 PvP 백엔드 계약. 구현은 로컬/Supabase 등으로 교체 가능.
abstract interface class PvpBackend {
  /// 내 프로필([me])을 반영한 리더보드 상위 [limit] 줄을 반환한다.
  /// 결과에는 **항상 나(me)** 가 포함되며(상위권 밖이면 말미에 덧붙임) `isMe` 로 표시된다.
  Future<List<LeaderboardEntry>> leaderboard({
    required PvpProfile me,
    int limit,
  });
}

/// 로컬 리더보드 — 결정론적 NPC 사다리(고정 seed) + 내 트로피로 순위 삽입.
/// 온라인 연동 전까지 랭킹 화면이 동작하도록 하는 자리표시 구현.
class LocalPvpBackend implements PvpBackend {
  const LocalPvpBackend();

  static const _npcCount = 80;
  static const _handles = [
    '풍뎅이왕',
    '사슴벌레러',
    '채집의달인',
    '곤충마스터',
    '숲속강자',
    '왕턱집게',
    '반딧불이',
    '장수풍뎅이',
    '거미왕',
    '나비의꿈',
    '초원의지배자',
    '벌꿀사냥꾼',
    '표본수집가',
    '야행성포식자',
    '허물벗기',
    '더듬이전사',
  ];

  String _npcName(int i) {
    final base = _handles[i % _handles.length];
    final tier = i ~/ _handles.length;
    return tier == 0 ? base : '$base${tier + 1}';
  }

  @override
  Future<List<LeaderboardEntry>> leaderboard({
    required PvpProfile me,
    int limit = 50,
  }) async {
    // 고정 seed → 안정적인 사다리. 최상단은 내 점수보다 항상 높게 잡아 몰입 유지.
    final topBound = max(3200, me.trophies + 400);
    final npcs = <PvpProfile>[
      for (var i = 0; i < _npcCount; i++)
        PvpProfile(
          id: 'npc$i',
          nickname: _npcName(i),
          // 상위일수록 촘촘, 하위로 갈수록 완만한 하강 곡선.
          trophies: (topBound * pow(1 - i / _npcCount, 1.7)).round(),
        ),
    ];
    final all = [...npcs, me]..sort((a, b) => b.trophies.compareTo(a.trophies));
    final ranked = [
      for (var i = 0; i < all.length; i++)
        LeaderboardEntry(
          rank: i + 1,
          profile: all[i],
          isMe: all[i].id == me.id,
        ),
    ];
    final top = ranked.take(limit).toList();
    if (!top.any((e) => e.isMe)) {
      top.add(ranked.firstWhere((e) => e.isMe));
    }
    return top;
  }
}

/// 교체 가능한 백엔드 제공자. 기본은 로컬. Supabase 연동 시 override.
final pvpBackendProvider = Provider<PvpBackend>(
  (ref) => const LocalPvpBackend(),
);
