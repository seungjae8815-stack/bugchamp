import 'package:core_battle/core_battle.dart';

/// 결투(곤충 배틀 스타디움) 세션 — 판마다 던지기 게이지를 받아 서버가 한 판씩 확정한다.
///
/// 옛 수동 전투(`BattleSession`)와 같은 `battle_sessions` 테이블에 `kind: 'duel'` 로 저장한다
/// (RLS 정책 없음 = service_role 전용). **시드는 앱에 주지 않는다** — 알면 게이지 값을
/// 바꿔 가며 미리 결과를 돌려 볼 수 있다.
class DuelSession {
  const DuelSession({
    required this.id,
    required this.userId,
    required this.seed,
    required this.myTeamBugIds,
    required this.foe,
    required this.foeSpecies,
    required this.foeSkins,
    required this.rewardMult,
    required this.winners,
    required this.launches,
    required this.finished,
    required this.trophiesAtStart,
    required this.trophyPrepaid,
    this.winPoints,
    this.hpA = 1,
    this.hpB = 1,
    this.clutchScores,
    this.pendingLaunch,
    this.pendingIndex,
  });

  final String id;
  final String userId;
  final int seed;

  /// 내 출전 순서(1·2·3번).
  final List<String> myTeamBugIds;

  /// 상대 3마리 스냅샷(시작 때 확정 — 도중에 상대가 강화해도 바뀌지 않는다).
  final List<DuelBug> foe;
  final List<String> foeSpecies;
  final List<String?> foeSkins;
  final double rewardMult;

  /// 지금까지 판별 승자(0 = 나, 1 = 상대).
  final List<int> winners;

  /// 판별로 받은 게이지 값.
  final List<double> launches;
  final bool finished;
  final int trophiesAtStart;
  final int trophyPrepaid;

  /// 이기면 받는 점수(상대 후보 제안에서 서버가 정한 값, 2026-09-29). 지면 0점.
  /// null = 옛 세션(트로피 공식).
  final int? winPoints;

  /// 다음 판 시작 체력(승자 연속 — 이긴 곤충은 남은 체력 + 판 사이 회복, 2026-09-29).
  final double hpA;
  final double hpB;

  /// 탭 반격(훈련 v2 §4) — **지금 판**에서 받은 탭 점수(순서대로). 판이 끝나면 비운다.
  /// 앱이 탭 반격을 안다고 알렸을 때만 쓴다(구버전은 자동 점수 — 이 값은 늘 null).
  final List<double>? clutchScores;

  /// 위기에서 멈춘 판의 던지기 값 — 점수를 받으면 같은 값·같은 seed 로 처음부터 다시 계산한다.
  /// null = 멈춘 판 없음.
  final double? pendingLaunch;

  /// 멈춘 위기의 번호(= 지금 판에서 받은 점수 수). `/duel/clutch` 의 index 가 이 값이어야 한다
  /// (같은 위기에 점수를 두 번 넣거나 앞질러 넣지 못하게).
  final int? pendingIndex;

  /// 위기에서 멈춰 탭 점수를 기다리는 중인가.
  bool get clutchPending => pendingLaunch != null && pendingIndex != null;

  int get winsA => winners.where((w) => w == 0).length;
  int get winsB => winners.where((w) => w == 1).length;
  int get nextBout => winners.length;

  DuelSession copyWith({
    List<int>? winners,
    List<double>? launches,
    bool? finished,
    double? hpA,
    double? hpB,
    List<double>? clutchScores,
    double? pendingLaunch,
    int? pendingIndex,
    bool clearClutch = false,
  }) => DuelSession(
    id: id,
    userId: userId,
    seed: seed,
    myTeamBugIds: myTeamBugIds,
    foe: foe,
    foeSpecies: foeSpecies,
    foeSkins: foeSkins,
    rewardMult: rewardMult,
    winners: winners ?? this.winners,
    launches: launches ?? this.launches,
    finished: finished ?? this.finished,
    trophiesAtStart: trophiesAtStart,
    trophyPrepaid: trophyPrepaid,
    winPoints: winPoints,
    hpA: hpA ?? this.hpA,
    hpB: hpB ?? this.hpB,
    clutchScores: clearClutch ? null : clutchScores ?? this.clutchScores,
    pendingLaunch: clearClutch ? null : pendingLaunch ?? this.pendingLaunch,
    pendingIndex: clearClutch ? null : pendingIndex ?? this.pendingIndex,
  );

  Map<String, dynamic> toJson() => {
    'kind': 'duel',
    'id': id,
    'userId': userId,
    'seed': seed,
    'my': myTeamBugIds,
    'foe': [for (final b in foe) b.toJson()],
    'foeSp': foeSpecies,
    'foeSkins': foeSkins,
    'rewardMult': rewardMult,
    'winners': winners,
    'launches': launches,
    'finished': finished,
    'trophiesAtStart': trophiesAtStart,
    'trophyPrepaid': trophyPrepaid,
    'winPoints': ?winPoints,
    'hpA': hpA,
    'hpB': hpB,
    'clutch': ?clutchScores,
    'pendLaunch': ?pendingLaunch,
    'pendIdx': ?pendingIndex,
  };

  static bool isDuel(Map<String, dynamic> j) => j['kind'] == 'duel';

  factory DuelSession.fromJson(Map<String, dynamic> j) => DuelSession(
    id: '${j['id']}',
    userId: '${j['userId']}',
    seed: (j['seed'] as num).toInt(),
    myTeamBugIds: [for (final e in (j['my'] as List)) '$e'],
    foe: [
      for (final b in (j['foe'] as List))
        DuelBug.fromJson(Map<String, dynamic>.from(b as Map)),
    ],
    foeSpecies: [for (final e in (j['foeSp'] as List? ?? const [])) '$e'],
    foeSkins: [
      for (final e in (j['foeSkins'] as List? ?? const [])) e?.toString(),
    ],
    rewardMult: (j['rewardMult'] as num?)?.toDouble() ?? 1.0,
    winners: [
      for (final e in (j['winners'] as List? ?? const [])) (e as num).toInt(),
    ],
    launches: [
      for (final e in (j['launches'] as List? ?? const []))
        (e as num).toDouble(),
    ],
    finished: j['finished'] as bool? ?? false,
    trophiesAtStart: (j['trophiesAtStart'] as num?)?.toInt() ?? 0,
    trophyPrepaid: (j['trophyPrepaid'] as num?)?.toInt() ?? 0,
    winPoints: (j['winPoints'] as num?)?.toInt(),
    hpA: (j['hpA'] as num?)?.toDouble() ?? 1,
    hpB: (j['hpB'] as num?)?.toDouble() ?? 1,
    clutchScores: j['clutch'] is List
        ? [for (final e in (j['clutch'] as List)) (e as num).toDouble()]
        : null,
    pendingLaunch: (j['pendLaunch'] as num?)?.toDouble(),
    pendingIndex: (j['pendIdx'] as num?)?.toInt(),
  );
}

/// 탭 반격 위기 자리(응답 `clutch`) — 앱은 [tick] 까지 재생하고 게이지를 띄운 뒤 [index] 와 점수를
/// `/duel/clutch`(대회는 `/event/duel/clutch`)로 보낸다. [bout] 은 경기 안의 판 번호(대회는 0).
Map<String, dynamic> duelClutchJson(DuelClutchPending p, int bout) => {
  'kind': p.kind.key,
  'index': p.index,
  'bout': bout,
  'tick': p.tick,
};
