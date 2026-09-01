import 'dart:math';

import 'package:core_models/core_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 비동기 PvP·리더보드 백엔드 추상화 (Phase 4).
///
/// `Clock` 과 같은 "인터페이스 + 로컬 구현, 추후 교체" 패턴이다. 지금은
/// [LocalPvpBackend] 가 로컬로 리더보드를 만들고, Supabase 연동 시
/// [SupabasePvpBackend] 같은 구현으로 [pvpBackendProvider] 를 오버라이드한다.
/// (Supabase 스키마·연동 절차: docs/backend_supabase.md)

/// 랭킹 종류 — 무엇으로 줄을 세우는가.
///
/// 트로피 하나만 있으면 **결투를 안 하는 유저에게는 랭킹이 없다**. 이 게임의
/// 주된 플레이는 방치 런(레벨·스테이지)이라, 그쪽 진행도 겨룰 자리가 필요하다.
enum RankingKind {
  /// 결투 트로피(§2.7) — 전투 실력.
  trophies('trophies'),

  /// 캐릭터 레벨 — 누적 플레이.
  level('level'),

  /// 도달 스테이지 — 진행도.
  stage('stage');

  const RankingKind(this.key);
  final String key;
}

/// PvP 플레이어 프로필(리더보드 표시 단위).
class PvpProfile {
  const PvpProfile({
    required this.id,
    required this.nickname,
    required this.trophies,
    this.level = 1,
    this.stageNumber = 1,
    this.difficultyTier = 0,
  });

  final String id;
  final String nickname;
  final int trophies;

  /// 캐릭터 레벨([RankingKind.level] 정렬 기준). **현재 회차의 레벨** 그대로다 —
  /// 순서는 [difficultyTier] 와 묶어서 정한다([scoreFor]).
  final int level;

  /// 도달 스테이지([RankingKind.stage] 정렬 기준).
  final int stageNumber;

  /// 난이도 회차(0=쉬움). 진행도 랭킹은 **회차가 먼저**다 —
  /// 보통 1스테이지가 쉬움 1000스테이지보다 위다.
  final int difficultyTier;

  /// 이 랭킹 종류에서 줄 세우기에 쓰는 점수.
  int scoreFor(RankingKind kind) => switch (kind) {
    RankingKind.trophies => trophies,
    // ⚠️ 레벨도 **회차가 먼저**다. 최고 기록으로 세면 '쉬움에 눌러앉아 레벨만
    // 올리는 것'이 최적이 되고(2026-08-31 지적), 현재 레벨만 세면 회차를
    // 넘긴 유저가 꼴찌가 된다. 진행도와 같은 규칙으로 둘 다 막는다.
    RankingKind.level => difficultyTier * _tierScoreStep + level,
    // ⚠️ 회차를 위에 얹는다. 스테이지만 비교하면 회차를 넘어간 유저가
    // 1 로 돌아가는 순간 꼴찌가 된다 — 넘어갈 이유가 사라진다.
    RankingKind.stage => difficultyTier * _tierScoreStep + stageNumber,
  };
}

/// 랭킹 점수에서 회차 한 칸의 크기. 진행도(스테이지 1000)와 레벨 양쪽에 쓴다.
/// 한 회차에서 도달 가능한 값보다 넉넉히 커야 **회차가 항상 이긴다** —
/// 작으면 앞 회차의 높은 값이 뒤 회차를 넘는다.
const int _tierScoreStep = 100000;

/// 리더보드 한 줄.
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.profile,
    required this.isMe,
    this.badge = '',
  });

  final int rank;
  final PvpProfile profile;
  final bool isMe;

  /// 대회 회차 뱃지(`champion:1`). 없으면 빈 문자열.
  /// **서버가 쓴 값**이다(앱은 `profiles.badge` 를 쓸 권한이 없다).
  final String badge;
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
    this.skin,
  });

  final String speciesId;
  final Element element;
  final Temperament temperament;
  final double maxHp;
  final double atk;
  final double def;
  final double spd;

  /// 이 곤충에 걸린 스킨 **효과 키**(`gold`/`albino`). 없으면 null.
  ///
  /// 스킨을 산 사람만 보면 살 이유가 약하다 — 남이 봐야 사고 싶어진다
  /// (2026-08-19). 그래서 방어팀 스냅샷에 함께 싣는다.
  /// ⚠️ 순수 표시용이다. 보유 여부는 클라가 주장하는 값이라 위조할 수 있지만
  /// **이득이 0** 이라 위조할 이유가 없다. 스킨에 효과를 붙이는 날에는
  /// 그 효과를 **소유자 세이브**(서버 검증)에만 적용하고, 이 필드는 계속
  /// 그림에만 쓴다.
  final String? skin;

  Map<String, dynamic> toJson() => {
    'sp': speciesId,
    if (skin != null) 'skin': skin,
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
    skin: j['skin'] as String?,
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

/// 리더보드 조회 결과.
///
/// [live] = 이 목록이 **서버 실데이터**인지. false 면 NPC 사다리(폴백)다.
/// 화면 안내 문구는 반드시 이 값으로 정한다 — 백엔드 종류가 아니라
/// "이번 조회가 성공했는지"가 사용자에게 의미 있는 사실이다.
class Leaderboard {
  const Leaderboard({required this.entries, required this.live});

  const Leaderboard.local(this.entries) : live = false;

  final List<LeaderboardEntry> entries;
  final bool live;
}

/// 비동기 PvP 백엔드 계약. 구현은 로컬/Supabase 등으로 교체 가능.
abstract interface class PvpBackend {
  /// 실서버(Supabase 등)에 연결된 백엔드면 true, 로컬 자리표시면 false.
  /// UI 안내 문구(로컬 랭킹 vs 온라인)·방어팀 등록 표시에 사용.
  bool get isRemote;

  /// 내 프로필([me])을 반영한 리더보드 상위 [limit] 줄을 반환한다.
  /// 결과에는 **항상 나(me)** 가 포함되며(상위권 밖이면 말미에 덧붙임) `isMe` 로 표시된다.
  ///
  /// 반환값의 [Leaderboard.live] 가 **실제로 서버에서 받아온 것인지**를 말한다.
  /// [isRemote] 와 다르다 — 서버 백엔드라도 조회에 실패하면 화면이 비지 않게
  /// NPC 사다리로 폴백하는데, 그때 "온라인 랭킹"이라고 쓰면 거짓말이 된다.
  ///
  /// [kind] 는 줄 세우는 기준(트로피/레벨/진행도). 기본은 트로피라
  /// 기존 호출부는 그대로 동작한다.
  Future<Leaderboard> leaderboard({
    required PvpProfile me,
    int limit,
    RankingKind kind,
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
  /// 내 랭킹 프로필(트로피·레벨·진행도·회차)을 서버에 올린다.
  ///
  /// 이름은 트로피에서 왔지만 **세 축을 모두** 올린다 — 한 번 쓰는 upsert 라
  /// 나눠 쓸 이유가 없고, 나누면 안 올린 축이 낡은 채로 남는다.
  Future<void> pushTrophies({required PvpProfile me});

  /// 리더보드 상의 **내 순위**(1-based). 확정할 수 없으면 null.
  ///
  /// null 을 돌려주는 경우: 로컬 백엔드(NPC 사다리라 의미 없음)·미로그인·
  /// 세션 준비 전·네트워크 실패·상위권 밖. **폴백 순위를 지어내지 않는다** —
  /// [leaderboard] 는 화면이 비지 않게 로컬로 폴백하는데, 그 값을 순위로 쓰면
  /// 로그인 직후 경쟁 상황에서 엉뚱한 등수(예: 77위)가 캐시된다.
  Future<int?> myRank({required PvpProfile me});

  /// [name] 을 **다른 유저**가 이미 쓰고 있는지(대소문자 무시).
  ///
  /// 닉네임 설정/변경 전에 확인해 "이미 사용 중" 안내에 쓴다. 로컬 백엔드·
  /// 네트워크 실패 시 false(막지 않음 — 확인 못 했다고 이름 짓기를 막으면
  /// 오프라인 전환 때 게임이 잠긴다). 완전한 중복 차단은 서버 unique 인덱스가
  /// 담당하고, 이 검사는 UX 용 사전 안내다.
  Future<bool> isNicknameTaken(String name);
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
  Future<Leaderboard> leaderboard({
    required PvpProfile me,
    int limit = 50,
    RankingKind kind = RankingKind.trophies,
  }) async {
    // 고정 곡선 → 안정적인 사다리. 최상단은 내 점수보다 항상 높게 잡아 몰입 유지.
    // 축마다 단위가 다르므로(트로피 수천 / 레벨 수십 / 스테이지 수백)
    // **기준선도 축마다** 잡는다 — 하나로 쓰면 레벨 랭킹이 전부 999가 된다.
    final myScore = me.scoreFor(kind);
    final topBound = switch (kind) {
      RankingKind.trophies => max(3200, myScore + 400),
      RankingKind.level => max(60, myScore + 8),
      RankingKind.stage => max(600, (myScore * 1.3).round() + 40),
    };
    int scoreAt(int i) =>
        (topBound * pow(1 - i / _npcCount, 1.7)).round().clamp(1, 1 << 30);
    final npcs = <PvpProfile>[
      for (var i = 0; i < _npcCount; i++)
        PvpProfile(
          id: 'npc$i',
          nickname: _npcName(i),
          // 상위일수록 촘촘, 하위로 갈수록 완만한 하강 곡선.
          // 보고 있는 축만 곡선을 태우고 나머지는 대략값을 채운다(표시용).
          trophies: kind == RankingKind.trophies ? scoreAt(i) : 0,
          level: kind == RankingKind.level ? scoreAt(i) : 1,
          // 진행도 점수는 `회차*100000 + 스테이지` 합성값이라 그대로 넣으면
          // 화면에 `쉬움 1000-32` 같은 없는 구간이 뜬다 — 도로 쪼갠다.
          stageNumber: kind == RankingKind.stage
              ? scoreAt(i) % _tierScoreStep
              : 1,
          difficultyTier: kind == RankingKind.stage
              ? scoreAt(i) ~/ _tierScoreStep
              : 0,
        ),
    ];
    final all = [...npcs, me]
      ..sort((a, b) => b.scoreFor(kind).compareTo(a.scoreFor(kind)));
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
    return Leaderboard.local(top);
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

  /// 로컬 모드엔 다른 유저가 없다 — 항상 사용 가능.
  @override
  Future<bool> isNicknameTaken(String name) async => false;

  /// NPC 사다리 순위는 실제 경쟁이 아니다 — 표시하지 않는다.
  @override
  Future<int?> myRank({required PvpProfile me}) async => null;
}

/// 교체 가능한 백엔드 제공자. 기본은 로컬. Supabase 연동 시 override.
final pvpBackendProvider = Provider<PvpBackend>(
  (ref) => const LocalPvpBackend(),
);
