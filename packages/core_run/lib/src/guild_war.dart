import 'dart:math' as math;

import 'package:meta/meta.dart';

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
    this.dayWin = 2,
    this.dayTie = 1,
    this.clashWin = 4,
    this.clashTie = 2,
    this.grWin = 30,
    this.grLose = -20,
    this.loseShare = 0.5,
    this.tiers = const [],
    this.forgeBase = 1,
    this.forgeGrowth = 1.6,
  });

  /// 첫 대전 주(월 시작 날짜, `2026-10-12`). 비면 열리지 않는다 — 출시 주에는 길드 만들기만(§8).
  final String startWeek;

  /// 대전 참가 최소 인원(매칭 때).
  final int minMembers;

  /// 1~7일차(길이 7).
  final List<GuildWarDay> days;

  /// 행동 → 점수(`breedDone` · `hatch` · `synth` · `elite` · `bossKill` · `zoneClear` ·
  /// `duelWin` · `bugLevel` · `trainStep` · `skillTrain` · `bossAttack`).
  final Map<String, int> points;

  /// 1~6일차 그날 합이 높은 쪽 승점(동점이면 양쪽 [dayTie]) · 7일차 대결 승리 승점.
  final int dayWin;
  final int dayTie;
  final int clashWin;
  final int clashTie;

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
      dayWin: i('dayWin', d.dayWin),
      dayTie: i('dayTie', d.dayTie),
      clashWin: i('clashWin', d.clashWin),
      clashTie: i('clashTie', d.clashTie),
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

/// 대전 결과 — 1~6일차 합([dayA]·[dayB], 길이 6)과 7일차 대결 승수로 승점을 낸다.
/// 동점이면 7일차 승수 → 1~6일차 점수 총합.
({int pointsA, int pointsB, int winner, List<int> dayWinners}) guildWarOutcome(
  GuildWarConfig c, {
  required List<int> dayA,
  required List<int> dayB,
  required int clashA,
  required int clashB,
}) {
  var pa = 0, pb = 0;
  final winners = <int>[];
  for (var i = 0; i < 6; i++) {
    final a = i < dayA.length ? dayA[i] : 0;
    final b = i < dayB.length ? dayB[i] : 0;
    if (a > b) {
      pa += c.dayWin;
      winners.add(0);
    } else if (b > a) {
      pb += c.dayWin;
      winners.add(1);
    } else {
      pa += c.dayTie;
      pb += c.dayTie;
      winners.add(-1);
    }
  }
  if (clashA > clashB) {
    pa += c.clashWin;
  } else if (clashB > clashA) {
    pb += c.clashWin;
  } else {
    pa += c.clashTie;
    pb += c.clashTie;
  }
  int winner;
  if (pa != pb) {
    winner = pa > pb ? 0 : 1;
  } else if (clashA != clashB) {
    winner = clashA > clashB ? 0 : 1;
  } else {
    final sa = dayA.fold(0, (x, y) => x + y);
    final sb = dayB.fold(0, (x, y) => x + y);
    winner = sa == sb ? -1 : (sa > sb ? 0 : 1);
  }
  return (pointsA: pa, pointsB: pb, winner: winner, dayWinners: winners);
}
