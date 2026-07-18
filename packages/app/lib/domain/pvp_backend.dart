import 'dart:math';

import 'package:core_models/core_models.dart';
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

/// 방어팀 스냅샷 속 곤충 한 마리(비동기 PvP 매칭용).
///
/// 다른 유저가 이 곤충을 상대하므로 **전투에 필요한 해석된 스탯**을 그대로 담는다.
/// 이름/선호 스탠스는 보는 쪽이 자신의 언어·데이터로 [speciesId] 에서 재해석한다.
class DefenderBug {
  const DefenderBug({
    required this.speciesId,
    required this.element,
    required this.temperament,
    required this.maxHp,
    required this.atk,
    required this.def,
    required this.spd,
  });

  final String speciesId;
  final Element element;
  final Temperament temperament;
  final double maxHp;
  final double atk;
  final double def;
  final double spd;

  Map<String, dynamic> toJson() => {
    'sp': speciesId,
    'el': element.key,
    'tm': temperament.key,
    'hp': maxHp,
    'atk': atk,
    'def': def,
    'spd': spd,
  };

  factory DefenderBug.fromJson(Map<String, dynamic> j) => DefenderBug(
    speciesId: j['sp'] as String,
    element: Element.fromKey(j['el'] as String),
    temperament: Temperament.fromKey(j['tm'] as String),
    maxHp: (j['hp'] as num).toDouble(),
    atk: (j['atk'] as num).toDouble(),
    def: (j['def'] as num).toDouble(),
    spd: (j['spd'] as num).toDouble(),
  );
}

/// 한 유저의 방어팀 스냅샷(성충 최대 3마리). 스카우트 보드에서 상대로 노출된다.
class DefenderTeam {
  const DefenderTeam({
    required this.ownerId,
    required this.ownerName,
    required this.trophies,
    required this.bugs,
  });

  final String ownerId;
  final String ownerName;
  final int trophies;
  final List<DefenderBug> bugs;
}

/// 비동기 PvP 백엔드 계약. 구현은 로컬/Supabase 등으로 교체 가능.
abstract interface class PvpBackend {
  /// 실서버(Supabase 등)에 연결된 백엔드면 true, 로컬 자리표시면 false.
  /// UI 안내 문구(로컬 랭킹 vs 온라인)·방어팀 등록 표시에 사용.
  bool get isRemote;

  /// 내 프로필([me])을 반영한 리더보드 상위 [limit] 줄을 반환한다.
  /// 결과에는 **항상 나(me)** 가 포함되며(상위권 밖이면 말미에 덧붙임) `isMe` 로 표시된다.
  Future<List<LeaderboardEntry>> leaderboard({
    required PvpProfile me,
    int limit,
  });

  /// 내 방어팀 스냅샷([team])을 서버에 등록(업서트)한다.
  /// 로컬 백엔드는 no-op. 네트워크 실패는 조용히 무시(앱 흐름을 막지 않음).
  Future<void> registerDefender({
    required PvpProfile me,
    required List<DefenderBug> team,
  });

  /// 내 트로피 근처의 **다른 유저** 방어팀을 최대 [count]개 가져온다(나 제외).
  /// 실데이터가 없으면 빈 리스트를 반환하고, 호출측이 로컬 합성 상대로 채운다.
  Future<List<DefenderTeam>> fetchOpponents({
    required PvpProfile me,
    int count,
  });

  /// 승패 후 내 트로피를 서버(리더보드 프로필·방어팀 브래킷)에 즉시 반영한다.
  /// 로컬 백엔드는 no-op. 네트워크 실패는 조용히 무시(게임 흐름을 막지 않음).
  Future<void> pushTrophies({required PvpProfile me});
}

/// 로컬 리더보드 — 결정론적 NPC 사다리(고정 seed) + 내 트로피로 순위 삽입.
/// 온라인 연동 전까지 랭킹 화면이 동작하도록 하는 자리표시 구현.
class LocalPvpBackend implements PvpBackend {
  const LocalPvpBackend();

  @override
  bool get isRemote => false;

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

  /// 로컬 모드엔 실제 다른 유저가 없다 — 등록은 no-op.
  @override
  Future<void> registerDefender({
    required PvpProfile me,
    required List<DefenderBug> team,
  }) async {}

  /// 로컬 모드엔 실제 방어팀이 없다 — 빈 리스트(호출측이 로컬 합성으로 채움).
  @override
  Future<List<DefenderTeam>> fetchOpponents({
    required PvpProfile me,
    int count = 3,
  }) async => const [];

  /// 로컬 모드엔 반영할 서버가 없다 — no-op.
  @override
  Future<void> pushTrophies({required PvpProfile me}) async {}
}

/// 교체 가능한 백엔드 제공자. 기본은 로컬. Supabase 연동 시 override.
final pvpBackendProvider = Provider<PvpBackend>(
  (ref) => const LocalPvpBackend(),
);
