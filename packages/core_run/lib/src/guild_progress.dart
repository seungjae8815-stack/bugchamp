import 'dart:math' as math;

import 'package:meta/meta.dart';

import 'character_stats.dart';

/// 길드 레벨·버프 스킬·출석·상점(docs/design_guild.md §5·§6, 2026-10-01 3단계).
///
/// 길드 상태(경험치·스킬·코인)는 **서버 테이블이 소유**한다. 이 파일은 앱(표시·버프 적용)과
/// 서버(검사·지급)가 같은 규칙을 보려고 둔다. 수치는 `guild.json → level·donate·skills·shop`.
@immutable
class GuildLevelConfig {
  const GuildLevelConfig({
    this.max = 30,
    this.expBase = 100,
    this.expGrowth = 1.15,
    this.membersPerLevel = 1,
    this.membersCap = 30,
    this.pointsPerLevel = 1,
  });

  final int max;

  /// 레벨 L → L+1 에 필요한 경험치 = expBase × expGrowth^(L−1).
  final double expBase;
  final double expGrowth;

  /// 레벨마다 늘어나는 인원(기본 인원 `maxMembers` 에 더한다) · 상한.
  final int membersPerLevel;
  final int membersCap;

  /// 레벨마다 받는 스킬 포인트(1레벨은 0).
  final int pointsPerLevel;

  factory GuildLevelConfig.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const GuildLevelConfig();
    const d = GuildLevelConfig();
    return GuildLevelConfig(
      max: (j['max'] as num?)?.toInt() ?? d.max,
      expBase: (j['expBase'] as num?)?.toDouble() ?? d.expBase,
      expGrowth: (j['expGrowth'] as num?)?.toDouble() ?? d.expGrowth,
      membersPerLevel:
          (j['membersPerLevel'] as num?)?.toInt() ?? d.membersPerLevel,
      membersCap: (j['membersCap'] as num?)?.toInt() ?? d.membersCap,
      pointsPerLevel:
          (j['pointsPerLevel'] as num?)?.toInt() ?? d.pointsPerLevel,
    );
  }

  int expFor(int level) => (expBase * math.pow(expGrowth, level - 1)).round();

  /// 누적 경험치 → (레벨, 이번 레벨에서 쌓은 양, 다음 레벨까지 필요량 — 만렙이면 0).
  ({int level, int into, int need}) levelOf(int exp) {
    var lv = 1;
    var left = exp < 0 ? 0 : exp;
    while (lv < max && left >= expFor(lv)) {
      left -= expFor(lv);
      lv++;
    }
    return (
      level: lv,
      into: lv >= max ? 0 : left,
      need: lv >= max ? 0 : expFor(lv),
    );
  }

  int maxMembers(int baseMembers, int level) =>
      math.min(membersCap, baseMembers + (level - 1) * membersPerLevel);

  int points(int level) => (level - 1) * pointsPerLevel;
}

/// 길드 버프 스킬 하나. [stat] 은 [applyGuildStats]·[GuildBonus] 가 아는 키.
@immutable
class GuildSkillDef {
  const GuildSkillDef({
    required this.id,
    required this.stat,
    required this.perLevel,
    required this.max,
  });
  final String id;

  /// `attack` · `hp` · `gold` · `materialFind` · `xp` · `missionReward`.
  final String stat;
  final double perLevel;
  final int max;

  factory GuildSkillDef.fromJson(Map<String, dynamic> j) => GuildSkillDef(
    id: '${j['id']}',
    stat: '${j['stat']}',
    perLevel: (j['perLevel'] as num).toDouble(),
    max: (j['max'] as num).toInt(),
  );
}

/// 스킬 레벨 → 능력치 합(stat → 값). 모르는 스킬 id 는 버린다.
Map<String, double> guildBonus(
  List<GuildSkillDef> defs,
  Map<String, int> levels,
) {
  final out = <String, double>{};
  for (final d in defs) {
    final lv = math.min(levels[d.id] ?? 0, d.max);
    if (lv <= 0) continue;
    out[d.stat] = (out[d.stat] ?? 0) + d.perLevel * lv;
  }
  return out;
}

/// 쓴 포인트.
int guildPointsUsed(List<GuildSkillDef> defs, Map<String, int> levels) {
  var n = 0;
  for (final d in defs) {
    n += (levels[d.id] ?? 0).clamp(0, d.max);
  }
  return n;
}

/// 방치 런 스탯에 길드 버프를 건다 — **적응형 기준 밖**(§7, 버프·장비와 같은 층).
/// 결투·대회에는 싣지 않는다(이 함수는 방치 런 `_stats()` 에서만 부른다).
CharacterStats applyGuildStats(CharacterStats s, Map<String, double> bonus) {
  if (bonus.isEmpty) return s;
  double v(String k) => bonus[k] ?? 0;
  return CharacterStats(
    attack: s.attack * (1 + v('attack')),
    attackSpeed: s.attackSpeed,
    rewardMultiplier: s.rewardMultiplier * (1 + v('gold')),
    critChance: s.critChance,
    critDamage: s.critDamage,
    bossDamage: s.bossDamage,
    maxHp: s.maxHp * (1 + v('hp')),
    defense: s.defense,
    hpRegen: s.hpRegen,
    xpMultiplier: s.xpMultiplier * (1 + v('xp')),
    bugFind: s.bugFind,
    materialFind: s.materialFind * (1 + v('materialFind')),
    evade: s.evade,
    boostBonus: s.boostBonus,
  );
}

/// 길드 상점 품목. [kind] = `materials`(자기 사냥터 [hours] 시간치 키틴·미네랄·수액) · `fossil` ·
/// `fairyEgg`([grade]) · `fairyDust` · `skillShard`([grade] 만능 조각). [period] = `day` · `week`.
/// ❌ 젤리·결투 티켓·대회 참가권은 팔지 않는다(§6 — 판수 = 순위).
@immutable
class GuildShopItem {
  const GuildShopItem({
    required this.id,
    required this.kind,
    required this.cost,
    required this.limit,
    this.period = 'day',
    this.amount = 1,
    this.hours = 0,
    this.grade = '',
  });
  final String id;
  final String kind;
  final int cost;
  final int limit;
  final String period;
  final int amount;
  final double hours;
  final String grade;

  factory GuildShopItem.fromJson(Map<String, dynamic> j) => GuildShopItem(
    id: '${j['id']}',
    kind: '${j['kind']}',
    cost: (j['cost'] as num).toInt(),
    limit: (j['limit'] as num).toInt(),
    period: j['period'] as String? ?? 'day',
    amount: (j['amount'] as num?)?.toInt() ?? 1,
    hours: (j['hours'] as num?)?.toDouble() ?? 0,
    grade: j['grade'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'cost': cost,
    'limit': limit,
    'period': period,
    'amount': amount,
    'hours': hours,
    'grade': grade,
  };
}

/// 주 키 — 월요일 09:00 KST 시작 날짜(결투 시즌·심연과 같은 경계). 09시 KST = 00시 UTC.
String guildWeekKey(DateTime utc) {
  final t = utc.toUtc();
  final day = DateTime.utc(t.year, t.month, t.day);
  final monday = day.subtract(Duration(days: day.weekday - DateTime.monday));
  String two(int n) => n.toString().padLeft(2, '0');
  return '${monday.year}-${two(monday.month)}-${two(monday.day)}';
}

/// 이번 주 시작(월 09:00 KST = 월 00:00 UTC).
DateTime guildWeekStart(DateTime utc) {
  final t = utc.toUtc();
  final day = DateTime.utc(t.year, t.month, t.day);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

/// 출석 표의 큰 보상 한 칸(`guild.json → donate.bonuses`). [day] 일차에 기본 출석 보상(코인·길드 경험치)
/// **위에** 더 준다. 화석·요정 가루는 서버가 서버 세이브에 넣는다(앱이 더하면 업로드 상한에 잘린다).
/// ❌ 젤리는 없다 — 35일마다 계속 도는 통로다(§2.6 젤리 수도꼭지 규칙).
@immutable
class GuildAttendBonus {
  const GuildAttendBonus({
    required this.day,
    this.coins = 0,
    this.fossil = 0,
    this.fairyDust = 0,
  });

  final int day;
  final int coins;
  final int fossil;
  final int fairyDust;

  /// 세이브에 넣을 것이 있나(화석·가루). 코인만이면 서버 세이브를 건드리지 않는다.
  bool get hasItems => fossil > 0 || fairyDust > 0;

  factory GuildAttendBonus.fromJson(Map<String, dynamic> j) => GuildAttendBonus(
    day: (j['day'] as num?)?.toInt() ?? 0,
    coins: (j['coins'] as num?)?.toInt() ?? 0,
    fossil: (j['fossil'] as num?)?.toInt() ?? 0,
    fairyDust: (j['fairyDust'] as num?)?.toInt() ?? 0,
  );
}

/// 길드 출석 표(2026-10-05 사장님 확정) — [cycleDays] 칸(7일 × 5줄)을 **출석한 날만** 한 칸씩 채운다.
/// 연속이 아니다(빠져도 이어서). 다 채우면 다음 출석은 1일차로 돌아간다.
/// 출석 횟수는 서버 소유(`guild_members.attend_count`)라 **길드를 옮기면(탈퇴·추방) 처음부터**다.
/// 앱(달력 표시)과 서버(지급)가 같은 함수를 본다.
@immutable
class GuildAttendConfig {
  const GuildAttendConfig({this.cycleDays = 35, this.bonuses = const []});

  final int cycleDays;
  final List<GuildAttendBonus> bonuses;

  int get _cycle => cycleDays < 1 ? 1 : cycleDays;

  /// [count] 번째 출석이 몇 일차인가(1~[cycleDays]). 0 이면 0.
  int dayOf(int count) => count <= 0 ? 0 : ((count - 1) % _cycle) + 1;

  /// 다음 출석이 몇 일차인가 — 표를 다 채웠으면 1.
  int nextDay(int count) => count <= 0 ? 1 : (count % _cycle) + 1;

  /// 그 일차의 큰 보상(없으면 null).
  GuildAttendBonus? bonusOn(int day) =>
      bonuses.where((b) => b.day == day).firstOrNull;

  /// 일차별 보너스 코인(인덱스 0 = 1일차) — 서버가 출석 RPC 에 넘겨 코인을 **한 번에** 더한다.
  List<int> bonusCoinsTable() => [
    for (var d = 1; d <= _cycle; d++) bonusOn(d)?.coins ?? 0,
  ];

  factory GuildAttendConfig.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const GuildAttendConfig();
    return GuildAttendConfig(
      cycleDays: (j['cycleDays'] as num?)?.toInt() ?? 35,
      bonuses: [
        for (final x in (j['bonuses'] as List? ?? const []))
          GuildAttendBonus.fromJson(x as Map<String, dynamic>),
      ].where((b) => b.day >= 1).toList(),
    );
  }
}
