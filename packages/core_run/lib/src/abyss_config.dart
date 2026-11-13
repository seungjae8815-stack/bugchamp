import 'dart:math' as math;

import 'package:meta/meta.dart';

import 'battle_config.dart' show SeasonRankReward;
import 'character_stats.dart';
import 'enums.dart' show UpgradeKind;

/// 심연 — 극한 이후 무한 층 + 주간 최고 층 순위(docs/design_abyss.md, 2026-09-28 사장님 확정).
///
/// 심연에 있는 동안 난이도는 극한, 스테이지는 극한 최종 사냥터로 고정된다 — 표에서 나오는
/// 몬스터·골드 기준값이 이미 "극한 끝"이다. 층은 그 위에 **배율만** 곱한다(`abyssScale`).
/// 스테이지를 늘리는 방식이 아닌 이유: 재료 수량이 `1.008^(스테이지)` 라 스테이지 축을 늘리면
/// 지수로 폭주한다. 수치는 `run_config.json → abyss`.
@immutable
class AbyssConfig {
  const AbyssConfig({
    this.hpGrowth = 1.03,
    this.threatGrowth = 1.025,
    this.goldGrowth = 1.03,
    this.milestoneEvery = 10,
    this.milestoneShards = 10,
    this.milestoneFossil = 100,
    this.minSecondsPerFloor = 90,
    this.rankRewards = const [],
    this.crystalPerMilestone = 0,
    this.capStep = 0,
    this.capCosts = const [],
    this.capExclude = const {},
    this.mutations = const [],
    this.imprint = const {},
    this.imprintCostBase = 0,
    this.imprintCostGrowth = 1,
  });

  /// 심연 각인(2026-11-10) — 결정으로 사는 **영구 능력치**. 키(`attack`·`maxHp`·`defense`·`bossDamage`) → 1레벨당 배율 몫.
  /// 상한 돌파는 강화를 다 찍은 최상위만 쓰고(시뮬 유저는 골드에서 먼저 막힌다), 각인은 모두에게 벽을 민다.
  /// 극한을 깬 뒤에만 생기는 결정으로 사므로 90일 표 밖이다.
  final Map<String, double> imprint;
  final double imprintCostBase;
  final double imprintCostGrowth;

  bool get imprintOn => imprint.isNotEmpty && imprintCostBase > 0;

  /// 각인 [level] → +1 비용(결정, 정수 올림).
  int imprintCost(int level) =>
      (imprintCostBase * math.pow(imprintCostGrowth, level)).ceil();

  /// 심연 결정(2026-11-10 사장님 확정, `capBreak`) — **그 주에** [milestoneEvery] 배수 층을 깰 때마다
  /// (층 ÷ milestoneEvery) × 이 값. 매주 1층부터라 매주 다시 번다(조각·화석 마일스톤은 역대 최고 기준 한 번뿐).
  /// ❌ 젤리가 아니다 — 무한 통로라 강화 상한 돌파에만 쓴다.
  final int crystalPerMilestone;

  /// 상한 돌파 한 단계에 여는 레벨 수.
  final int capStep;

  /// 단계별 결정 비용(길이 = 최대 단계 수).
  final List<int> capCosts;

  /// 상한 돌파가 없는 강화 키 — 치명·회피는 강화 예산에 딱 맞춘 줄이라 넘으면 헛돈이다.
  final Set<String> capExclude;

  /// 주간 변이(2026-11-10 사장님 확정) — 매주 하나가 모든 유저에게 같이 걸린다([mutationFor]).
  final List<AbyssMutation> mutations;

  bool get capBreakOn =>
      crystalPerMilestone > 0 && capStep > 0 && capCosts.isNotEmpty;

  /// [kind] 가 상한 돌파 대상인가.
  bool capBreakable(UpgradeKind kind) =>
      capBreakOn && !capExclude.contains(kind.key);

  /// [steps] 단계까지 연 상태에서 다음 단계 비용(다 열었으면 null).
  int? capStepCost(int steps) =>
      steps < 0 || steps >= capCosts.length ? null : capCosts[steps];

  /// [floor] 층을 깼을 때 받는 결정.
  int crystalsAt(int floor) =>
      capBreakOn &&
          milestoneEvery > 0 &&
          floor > 0 &&
          floor % milestoneEvery == 0
      ? floor ~/ milestoneEvery * crystalPerMilestone
      : 0;

  /// [from] 층부터 [to] 층 **직전까지** 깼을 때 받는 결정 합(서버 허용치).
  int crystalsBetween(int from, int to) {
    var n = 0;
    for (var f = math.max(1, from); f < to; f++) {
      n += crystalsAt(f);
    }
    return n;
  }

  /// 이번 주([weekId] = 시즌 시작 날짜 `yyyy-mm-dd`) 변이. 주 번호에 목록 길이와 서로소인 보폭을 곱해 돌린다 —
  /// 목록을 다 돌기 전에는 같은 변이가 다시 나오지 않고, 두 주 연속 같지도 않다(순서는 목록 순서와 다르다).
  AbyssMutation? mutationFor(String? weekId) {
    final n = mutations.length;
    final day = weekId == null
        ? null
        : DateTime.tryParse('${weekId}T00:00:00Z');
    if (n == 0 || day == null) return null;
    final week = day.millisecondsSinceEpoch ~/ (7 * 86400000);
    var step = 3;
    while (_gcd(step, n) != 1) {
      step++;
    }
    return mutations[(week * step) % n];
  }

  static int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);

  /// 층마다 몬스터·보스 체력 배율.
  final double hpGrowth;

  /// 층마다 표 위협 배율(적응형 위협과 큰 쪽이 쓰인다).
  final double threatGrowth;

  /// 층마다 골드 배율. **체력보다 빠르지 않게** — 강화 비용이 지수라 같은 배율이어도 벽에 닿는다.
  final double goldGrowth;

  /// 이 층수마다 **처음 도달**하면 조각·화석 일시금(역대 최고 층 기준이라 주간 리셋에도 한 번뿐).
  final int milestoneEvery;
  final int milestoneShards;
  final int milestoneFossil;

  /// 층 하나를 깨는 데 걸릴 수 있는 **최소 시간**(초) — 서버가 업로드마다 층 증가 상한을 건다.
  /// 몬스터 100마리 + 보스라 정상 플레이로는 이보다 빠를 수 없다(심연은 기기 권위라
  /// 세이브를 고쳐 999층을 적는 위조를 여기서 막는다).
  final double minSecondsPerFloor;

  /// 주간 최고 층 순위 보상(젤리) — 결투 시즌 순위와 같은 구조.
  final List<SeasonRankReward> rankRewards;

  /// [floor] 층의 배율(1층 = 1). 0 이하는 심연 밖.
  double scale(double growth, int floor) =>
      floor <= 1 ? 1.0 : math.pow(growth, floor - 1).toDouble();

  int rankJelly(int rank) {
    if (rank < 1) return 0;
    for (final r in rankRewards) {
      if (rank <= r.maxRank) return r.jelly;
    }
    return 0;
  }

  factory AbyssConfig.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const AbyssConfig();
    const d = AbyssConfig();
    double n(String k, double v) => (j[k] as num?)?.toDouble() ?? v;
    int i(String k, int v) => (j[k] as num?)?.toInt() ?? v;
    final cap = j['capBreak'] as Map<String, dynamic>?;
    int i2(Map<String, dynamic>? m, String k) => (m?[k] as num?)?.toInt() ?? 0;
    return AbyssConfig(
      hpGrowth: n('hpGrowth', d.hpGrowth),
      threatGrowth: n('threatGrowth', d.threatGrowth),
      goldGrowth: n('goldGrowth', d.goldGrowth),
      milestoneEvery: i('milestoneEvery', d.milestoneEvery),
      milestoneShards: i('milestoneShards', d.milestoneShards),
      milestoneFossil: i('milestoneFossil', d.milestoneFossil),
      minSecondsPerFloor: n('minSecondsPerFloor', d.minSecondsPerFloor),
      rankRewards: [
        for (final r in (j['rankRewards'] as List? ?? const []))
          SeasonRankReward.fromJson(r as Map<String, dynamic>),
      ],
      crystalPerMilestone: i2(cap, 'crystalPerMilestone'),
      capStep: i2(cap, 'step'),
      capCosts: [
        for (final x in (cap?['costs'] as List? ?? const []))
          (x as num).toInt(),
      ],
      capExclude: {
        for (final x in (cap?['exclude'] as List? ?? const [])) '$x',
      },
      imprint: {
        for (final e
            in ((j['imprint'] as Map?)?['perLevel'] as Map? ?? const {})
                .entries)
          '${e.key}': (e.value as num).toDouble(),
      },
      imprintCostBase:
          ((j['imprint'] as Map?)?['costBase'] as num?)?.toDouble() ?? 0,
      imprintCostGrowth:
          ((j['imprint'] as Map?)?['costGrowth'] as num?)?.toDouble() ?? 1,
      mutations: [
        for (final m in (j['mutations'] as List? ?? const []))
          AbyssMutation.fromJson(m as Map<String, dynamic>),
      ],
    );
  }
}

/// 심연 주간 변이 하나(`run_config.json → abyss.mutations`). 이름·설명은 게임 데이터 다국어({ko,en,ja}).
///
/// [mult] 키: 몬스터 쪽 `monsterHp`·`bossHp`·`threat`, 내 쪽 `attack`·`attackSpeed`·`critChance`·
/// `critDamage`·`bossDamage`·`maxHp`·`defense`·`hpRegen`·`evade`. 없으면 1. 심연 안에서만 걸린다.
@immutable
class AbyssMutation {
  const AbyssMutation({
    required this.id,
    this.name = const {},
    this.desc = const {},
    this.mult = const {},
  });

  final String id;
  final Map<String, String> name;
  final Map<String, String> desc;
  final Map<String, double> mult;

  static const keys = {
    'monsterHp',
    'bossHp',
    'threat',
    'attack',
    'attackSpeed',
    'critChance',
    'critDamage',
    'bossDamage',
    'maxHp',
    'defense',
    'hpRegen',
    'evade',
  };

  double of(String k) => mult[k] ?? 1.0;

  /// 몬스터 쪽 배율(클수록 불리) — 나머지는 내 쪽(작을수록 불리).
  static const _monsterKeys = {'monsterHp', 'bossHp', 'threat'};

  /// 심연 연구 "변이 길들이기"(2026-11-12) — **불리한 배율만** 1 쪽으로 [v](0~1) 만큼 당긴다. 유리한 쪽은 그대로.
  AbyssMutation tamed(double v) {
    if (v <= 0) return this;
    final t = v.clamp(0.0, 1.0);
    return AbyssMutation(
      id: id,
      name: name,
      desc: desc,
      mult: {
        for (final e in mult.entries)
          e.key: _monsterKeys.contains(e.key)
              ? (e.value > 1 ? 1 + (e.value - 1) * (1 - t) : e.value)
              : (e.value < 1 ? 1 - (1 - e.value) * (1 - t) : e.value),
      },
    );
  }

  factory AbyssMutation.fromJson(Map<String, dynamic> j) {
    Map<String, String> text(Object? v) => {
      for (final e in ((v as Map?) ?? const {}).entries)
        '${e.key}': '${e.value}',
    };
    return AbyssMutation(
      id: j['id'] as String,
      name: text(j['name']),
      desc: text(j['desc']),
      mult: {
        for (final e in ((j['mult'] as Map?) ?? const {}).entries)
          '${e.key}': (e.value as num).toDouble(),
      },
    );
  }
}

/// 주간 변이의 **내 쪽** 배율을 능력치에 입힌다(심연 안에서만 부른다). 방어는 맷집 `100 + 방어` 에 곱한다
/// (펫 패시브·연구와 같은 해석 — `defenseScaled`). [m] 이 null 이면 그대로.
CharacterStats applyAbyssMutation(CharacterStats s, AbyssMutation? m) {
  if (m == null || m.mult.isEmpty) return s;
  return CharacterStats(
    attack: s.attack * m.of('attack'),
    attackSpeed: s.attackSpeed * m.of('attackSpeed'),
    rewardMultiplier: s.rewardMultiplier,
    critChance: s.critChance * m.of('critChance'),
    critDamage: s.critDamage * m.of('critDamage'),
    bossDamage: s.bossDamage * m.of('bossDamage'),
    maxHp: s.maxHp * m.of('maxHp'),
    defense: (100 + s.defense) * m.of('defense') - 100,
    hpRegen: s.hpRegen * m.of('hpRegen'),
    xpMultiplier: s.xpMultiplier,
    bugFind: s.bugFind,
    materialFind: s.materialFind,
    evade: s.evade * m.of('evade'),
    boostBonus: s.boostBonus,
  );
}

/// 심연 각인을 능력치에 입힌다(2026-11-10). 공격·체력·보스 피해는 곱, 방어는 맷집 `100 + 방어` 에 곱한다.
CharacterStats applyAbyssImprint(
  CharacterStats s,
  AbyssConfig cfg,
  Map<String, int> levels,
) {
  if (!cfg.imprintOn || levels.isEmpty) return s;
  double m(String k) => 1 + (cfg.imprint[k] ?? 0) * (levels[k] ?? 0);
  return CharacterStats(
    attack: s.attack * m('attack'),
    attackSpeed: s.attackSpeed,
    rewardMultiplier: s.rewardMultiplier,
    critChance: s.critChance,
    critDamage: s.critDamage,
    bossDamage: s.bossDamage * m('bossDamage'),
    maxHp: s.maxHp * m('maxHp'),
    defense: (100 + s.defense) * m('defense') - 100,
    hpRegen: s.hpRegen * m('maxHp'),
    xpMultiplier: s.xpMultiplier,
    bugFind: s.bugFind,
    materialFind: s.materialFind,
    evade: s.evade,
    boostBonus: s.boostBonus,
  );
}
