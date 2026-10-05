import 'dart:math' as math;

import 'package:meta/meta.dart';

import 'guild_mission.dart' show fnv1a32;

/// 길드전(docs/design_guild.md §4, 2026-10-01 5단계) — 7일 한 판, 티어 매칭.
///
/// 일정(시즌 시간표 그대로): 월 09:00 KST 시작 → 1~6일차 활동 경쟁(하루 = 09시~다음 날 09시) →
/// **7일차(일 09시~) 전투력 대결**(서버가 결투 엔진으로 멤버 1:1) → 결과·보상 → 월 09시 새 대전.
///
/// ⚠️ 돈이 승패를 정하지 않게: 활동 점수는 **멤버별 하루 상한**이 있고(→ "몇 명이 참여했나"가 승부),
/// 젤리로 당긴 완료는 세지 않는다. 7일차는 결투 방어팀(서버 검증)만 — 요정·스킬·장비·길드 버프 X.
@immutable
class GuildWarDay {
  const GuildWarDay({required this.theme, required this.cap});

  /// `breed` · `forge` · `hunt` · `duel` · `train` · `boss` · `clash`(7일차).
  final String theme;

  /// 멤버 하루 상한(점). clash 는 0.
  final int cap;

  factory GuildWarDay.fromJson(Map<String, dynamic> j) => GuildWarDay(
    theme: '${j['theme']}',
    cap: (j['cap'] as num?)?.toInt() ?? 0,
  );
}

@immutable
class GuildWarTier {
  const GuildWarTier({
    required this.id,
    required this.minGr,
    required this.coins,
    required this.jelly,
  });
  final String id;
  final int minGr;

  /// 승리 보상(멤버 한 명당). 패배는 [GuildWarConfig.loseShare] 만큼.
  final int coins;
  final int jelly;

  factory GuildWarTier.fromJson(Map<String, dynamic> j) => GuildWarTier(
    id: '${j['id']}',
    minGr: (j['minGr'] as num?)?.toInt() ?? 0,
    coins: (j['coins'] as num?)?.toInt() ?? 0,
    jelly: (j['jelly'] as num?)?.toInt() ?? 0,
  );
}

@immutable
class GuildWarConfig {
  const GuildWarConfig({
    this.startWeek = '',
    this.minMembers = 5,
    this.days = const [],
    this.points = const {},
    this.dayPoints = const [1, 2, 2, 3, 3, 4, 6],
    this.grWin = 30,
    this.grLose = -20,
    this.loseShare = 0.5,
    this.tiers = const [],
    this.forgeBase = 1,
    this.forgeGrowth = 1.6,
  });

  /// 첫 대전 주(월 시작 날짜, `2026-10-12`). 비면 열리지 않는다 — 출시 주에는 길드 만들기만(§8).
  /// 서버는 환경변수 `GUILD_WAR_START_WEEK` 로 덮는다([withStartWeek]) — 재빌드 없이 연다.
  final String startWeek;

  /// 대전 참가 최소 인원(매칭 때).
  final int minMembers;

  /// 1~7일차(길이 7).
  final List<GuildWarDay> days;

  /// 행동 → 점수(`breedDone` · `hatch` · `synth` · `elite` · `bossKill` · `zoneClear` ·
  /// `duelWin` · `bugLevel` · `trainStep` · `skillTrain` · `bossAttack`).
  final Map<String, int> points;

  /// 일차별 승점(길이 7, 2026-10-05 사장님 확정 `[1,2,2,3,3,4,6]`). 그날 **이긴 쪽만** 가져간다 —
  /// 하루 무승부는 없다([guildWarDayWinner]). 합이 홀수라 한 주 결과는 동점이 될 수 없다
  /// (`data_test` 가 홀수를 검사한다).
  final List<int> dayPoints;

  /// [day](1~7)일차 승점. 표가 짧으면 0.
  int pointsOn(int day) =>
      day >= 1 && day <= dayPoints.length ? dayPoints[day - 1] : 0;

  /// 길드 등급점 증감.
  final int grWin;
  final int grLose;

  /// 패배 보상 = 승리 보상 × 이 비율(사장님 확정 50%).
  final double loseShare;
  final List<GuildWarTier> tiers;

  /// 2일차(제련) — 결과 장비 등급 단계 g(0 = 풀잎)당 `forgeBase × forgeGrowth^g` 점.
  final double forgeBase;
  final double forgeGrowth;

  int forgePoints(int gradeIndex) =>
      (forgeBase * math.pow(forgeGrowth, math.max(0, gradeIndex))).round();

  factory GuildWarConfig.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const GuildWarConfig();
    const d = GuildWarConfig();
    int i(String k, int v) => (j[k] as num?)?.toInt() ?? v;
    return GuildWarConfig(
      startWeek: j['startWeek'] as String? ?? '',
      minMembers: i('minMembers', d.minMembers),
      days: [
        for (final x in (j['days'] as List? ?? const []))
          GuildWarDay.fromJson(x as Map<String, dynamic>),
      ],
      points: {
        for (final e in ((j['points'] as Map?) ?? const {}).entries)
          '${e.key}': (e.value as num).toInt(),
      },
      dayPoints: j['dayPoints'] is List
          ? [for (final x in j['dayPoints'] as List) (x as num).toInt()]
          : d.dayPoints,
      grWin: i('grWin', d.grWin),
      grLose: i('grLose', d.grLose),
      loseShare: (j['loseShare'] as num?)?.toDouble() ?? d.loseShare,
      tiers: [
        for (final x in (j['tiers'] as List? ?? const []))
          GuildWarTier.fromJson(x as Map<String, dynamic>),
      ],
      forgeBase: (j['forgeBase'] as num?)?.toDouble() ?? d.forgeBase,
      forgeGrowth: (j['forgeGrowth'] as num?)?.toDouble() ?? d.forgeGrowth,
    );
  }

  /// [startWeek] 만 바꾼 사본(서버 환경변수 덮어쓰기).
  GuildWarConfig withStartWeek(String week) => GuildWarConfig(
    startWeek: week,
    minMembers: minMembers,
    days: days,
    points: points,
    dayPoints: dayPoints,
    grWin: grWin,
    grLose: grLose,
    loseShare: loseShare,
    tiers: tiers,
    forgeBase: forgeBase,
    forgeGrowth: forgeGrowth,
  );

  /// [week] 주에 대전이 열리나.
  bool openOn(String week) =>
      startWeek.isNotEmpty &&
      week.compareTo(startWeek) >= 0 &&
      days.length == 7;

  GuildWarDay? dayDef(int day) =>
      day >= 1 && day <= days.length ? days[day - 1] : null;

  /// 등급점 → 티어(가장 높은 조건을 만족하는 것).
  GuildWarTier tierOf(int gr) {
    var out = tiers.isEmpty
        ? const GuildWarTier(id: 'bronze', minGr: 0, coins: 0, jelly: 0)
        : tiers.first;
    for (final t in tiers) {
      if (gr >= t.minGr) out = t;
    }
    return out;
  }

  GuildWarTier? tierById(String id) =>
      tiers.where((t) => t.id == id).firstOrNull;

  /// 그날 주제에 맞는 행동만 세어 점수(상한으로 자른다). [counts] = 그날 누적 행동 수.
  int dayScore(int day, Map<String, int> counts) {
    final d = dayDef(day);
    if (d == null || d.cap <= 0) return 0;
    var sum = 0;
    for (final e in counts.entries) {
      if (!actionOn(d.theme, e.key)) continue;
      final per = e.key.startsWith('forge:')
          ? forgePoints(int.tryParse(e.key.substring(6)) ?? 0)
          : (points[e.key] ?? 0);
      sum += per * math.max(0, e.value);
    }
    return math.min(sum, d.cap);
  }

  /// 행동이 그 주제에 속하나.
  static bool actionOn(String theme, String action) => switch (theme) {
    'breed' => const {'breedDone', 'hatch', 'synth'}.contains(action),
    'forge' => action.startsWith('forge:'),
    'hunt' => const {'elite', 'bossKill', 'zoneClear'}.contains(action),
    'duel' => action == 'duelWin',
    'train' => const {'bugLevel', 'trainStep', 'skillTrain'}.contains(action),
    'boss' => action == 'bossAttack',
    _ => false,
  };

  /// 앱이 세는 주제(나머지 — 결투·보스 — 는 서버가 확정 결과로 센다).
  static bool appCounted(String theme) =>
      const {'breed', 'forge', 'hunt', 'train'}.contains(theme);
}

/// 대전 N일차(1~7). 주 시작 = 월 09:00 KST = 월 00:00 UTC.
int guildWarDayIndex(DateTime utc, DateTime weekStart) =>
    (utc.toUtc().difference(weekStart).inHours ~/ 24 + 1).clamp(1, 7);

/// 한 길드의 하루 성적 — 무승부 없이 승자를 가르는 재료.
@immutable
class GuildWarDayStat {
  const GuildWarDayStat({this.total = 0, this.members = 0, this.reachedAt});

  /// 그날 길드 점수 합.
  final int total;

  /// 그날 점수를 1 이상 낸 길드원 수.
  final int members;

  /// 그날 마지막으로 점수가 오른 시각(= 지금 합에 도달한 시각). 모르면 null(가상 길드 등).
  final DateTime? reachedAt;
}

/// 하루 승자(0 = A, 1 = B) — **무승부 없음**(2026-10-05 사장님 확정).
/// 점수 합 → 점수 낸 인원(많은 쪽) → 그 합에 먼저 도달한 쪽 → 둘 중 하나라도 시각을 모르면 [seed]
/// (결정론 — 같은 대전·같은 날은 언제 다시 계산해도 같다). 양쪽 다 0점인 날도 이 순서로 갈린다.
int guildWarDayWinner(
  GuildWarDayStat a,
  GuildWarDayStat b, {
  required int seed,
  required int day,
}) {
  if (a.total != b.total) return a.total > b.total ? 0 : 1;
  if (a.members != b.members) return a.members > b.members ? 0 : 1;
  final ta = a.reachedAt, tb = b.reachedAt;
  if (ta != null && tb != null && ta != tb) return ta.isBefore(tb) ? 0 : 1;
  return fnv1a32('$seed|day$day') & 1;
}

/// 대전 결과 — 1~6일차 성적([dayA]·[dayB])과 7일차 대결 승수로 승점을 낸다.
/// 날마다 이긴 쪽만 [GuildWarConfig.pointsOn] 승점(무승부 없음). 7일차 승수가 같으면 [topWinA]
/// (전투력 1위끼리 대결 결과, 대결이 없었으면 null → [seed]). 승점 합이 같을 수 있는 표(합이 짝수)면
/// 7일차 승자가 이긴다 — 실데이터는 합이 홀수라 그럴 일이 없다.
({int pointsA, int pointsB, int winner, List<int> dayWinners, int clashWinner})
guildWarOutcome(
  GuildWarConfig c, {
  required List<GuildWarDayStat> dayA,
  required List<GuildWarDayStat> dayB,
  required int clashA,
  required int clashB,
  bool? topWinA,
  required int seed,
}) {
  var pa = 0, pb = 0;
  final winners = <int>[];
  for (var i = 0; i < 6; i++) {
    final a = i < dayA.length ? dayA[i] : const GuildWarDayStat();
    final b = i < dayB.length ? dayB[i] : const GuildWarDayStat();
    final w = guildWarDayWinner(a, b, seed: seed, day: i + 1);
    w == 0 ? pa += c.pointsOn(i + 1) : pb += c.pointsOn(i + 1);
    winners.add(w);
  }
  final int clashWinner;
  if (clashA != clashB) {
    clashWinner = clashA > clashB ? 0 : 1;
  } else if (topWinA != null) {
    clashWinner = topWinA ? 0 : 1;
  } else {
    clashWinner = fnv1a32('$seed|day7') & 1;
  }
  clashWinner == 0 ? pa += c.pointsOn(7) : pb += c.pointsOn(7);
  final winner = pa != pb ? (pa > pb ? 0 : 1) : clashWinner;
  return (
    pointsA: pa,
    pointsB: pb,
    winner: winner,
    dayWinners: winners,
    clashWinner: clashWinner,
  );
}
