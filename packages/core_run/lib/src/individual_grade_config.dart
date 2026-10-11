import 'dart:math' as math;

import 'package:core_models/core_models.dart';

/// 개체 등급 개편(2026-10-11 사장님 확정, docs/design_individual_grade.md) — `pets.json → individualGrade`.
///
/// 개체 등급 = 포텐셜(1 일반 ~ 5 전설). 종의 `grade` 는 이제 **종 희귀도**(드롭·부화 시간·뽑기 종 선택)다.
/// 값이 없으면 [enabled] = false — 앱·서버가 옛 규칙(포텐셜·종 등급)으로 돈다(단계적 배포).
class IndividualGradeConfig {
  const IndividualGradeConfig({
    this.enabled = false,
    this.statMult = const [1.0, 1.1, 1.22, 1.36, 1.52],
    this.rollWidth = 0.10,
    this.innateMax = const {},
    this.wildWeights = const [0.80, 0.15, 0.04, 0.01, 0.0],
    this.breedChildWild = true,
    this.essenceCosts = const [6, 6, 6, 10],
    this.essenceRarity = const {},
    this.potionFloorStep = 5,
    this.potionMaxPerUse = 3,
    this.gachaGradeWeights = const [0, 0, 0.70, 0.27, 0.03],
    this.gachaPityMinPotential = 4,
    this.potionJelly = 10,
    this.potionDailyBuy = 10,
    this.potionEliteChance = 0.003,
    this.potionBossChance = 0.02,
    this.potionBossFirst = 1,
    this.potionAbyss10 = 3,
  });

  final bool enabled;

  /// 등급별 체력·공격·방어 배율(일반 → 전설). **전설 = 지금 다 키운 5★** — 실제 배율은 [statMultOf](÷ 전설 값).
  final List<double> statMult;

  /// 능력치 롤 폭 — 롤 0 = ×(1 − 폭), 50 = ×1, 100 = ×(1 + 폭).
  final double rollWidth;

  /// 타고난 치명·회피·회복력(롤 100 일 때 최대치, 0~1)과 밀어내기(롤 100 일 때 +폭, 롤 0 일 때 −폭).
  /// 키 = [StatRoll.key](crit·evade·recovery·push). 훈련 포인트는 이 위에 더한다.
  final Map<String, double> innateMax;

  /// 야생 알의 개체 등급 확률(일반 → 전설). 짝짓기 자식도 [breedChildWild] 면 같은 확률.
  final List<double> wildWeights;
  final bool breedChildWild;

  /// 등급 올리기 배수(일반→고급, 고급→희귀, 희귀→영웅, 영웅→전설).
  final List<int> essenceCosts;

  /// 종 희귀도별 정수 가치(곤충 1마리 = 등급 누적 × 이 값). 뽑기 출신은 1.
  final Map<Grade, double> essenceRarity;

  /// 물약 1개당 새로 굴리는 롤의 바닥(0~100 점) · 한 번에 넣을 수 있는 최대 수.
  final int potionFloorStep;
  final int potionMaxPerUse;

  /// 뽑기 개체 등급 확률(일반 → 전설) · 천장(이 포텐셜 이상 확정).
  final List<double> gachaGradeWeights;
  final int gachaPityMinPotential;

  /// 성장물약 — 젤리 가격·하루 구매 상한(§2.8 예외, 사장님 확정) · 무료 획득(직접 사냥만).
  final int potionJelly;
  final int potionDailyBuy;
  final double potionEliteChance;
  final double potionBossChance;
  final int potionBossFirst;
  final int potionAbyss10;

  /// 등급 [potential] 의 누적 정수 가치(그 등급 1마리 = 일반 몇 마리분). 1 → 1, 2 → c0, 3 → c0·c1 …
  int cumulative(int potential) {
    var v = 1;
    for (var i = 0; i < potential - 1 && i < essenceCosts.length; i++) {
      v *= essenceCosts[i];
    }
    return v;
  }

  /// [potential] 에서 한 등급 올리는 데 드는 정수(전설이면 0).
  int upgradeCost(int potential) =>
      potential >= 5 ? 0 : cumulative(potential + 1) - cumulative(potential);

  /// 곤충 1마리를 정수로 바꿀 때 받는 양. **알은 0**(애벌레 이상만 — 부화기를 거치게).
  /// 종 희귀도 가치는 **태어난 등급 몫에만** 곱한다 — 등급 올리기로 얹은 몫은 들인 정수 그대로 돌려준다.
  /// (다 곱하면 정수 30 으로 올린 전설 종이 1,008 로 돌아와 올리기·바꾸기 반복이 무한 정수가 됐다.)
  int essenceOf(IndividualBug bug, Grade speciesRarity) {
    if (bug.stage == LifeStage.egg) return 0;
    final r = bug.fromGacha ? 1.0 : (essenceRarity[speciesRarity] ?? 1.0);
    final born = (bug.potential - bug.synthUps).clamp(1, bug.potential);
    return (cumulative(born) * r).round() +
        cumulative(bug.potential) -
        cumulative(born);
  }

  /// 체력·공격·방어 등급 배율(전설 = 1).
  double statMultOf(int potential) {
    final i = (potential - 1).clamp(0, statMult.length - 1);
    return statMult[i] / statMult.last;
  }

  /// 롤 점수(0~100) → 능력치 배율.
  double rollFactor(int roll) => 1 + (roll.clamp(0, 100) - 50) / 50 * rollWidth;

  /// 타고난 확률·비율(치명·회피·회복력): 롤 100 일 때 [innateMax].
  double innate(StatRoll stat, int roll) =>
      (innateMax[stat.key] ?? 0) * roll.clamp(0, 100) / 100;

  /// 밀어내기 배율: 롤 50 = 1.
  double pushFactor(int roll) =>
      1 + (roll.clamp(0, 100) - 50) / 50 * (innateMax[StatRoll.push.key] ?? 0);

  /// 결투·대회 능력치 보정(앱 `duelBugFor`·서버 `validateDuelTeam` 이 같은 함수로 입힌다).
  /// 체력·공격·방어 = 등급 배율 × 종 배율 × 롤 · 속도 = 롤 · 치명·회피·회복력 = 타고난 값 · 밀어내기 = 롤.
  /// 꺼져 있으면 모두 중립(1·0) — 옛 규칙 그대로.
  ({
    double hp,
    double atk,
    double def,
    double spd,
    double crit,
    double evade,
    double recovery,
    double push,
  })
  battleMods(IndividualBug bug, Species species) {
    if (!enabled) {
      return (
        hp: 1,
        atk: 1,
        def: 1,
        spd: 1,
        crit: 0,
        evade: 0,
        recovery: 0,
        push: 1,
      );
    }
    final r = bug.statRolls;
    int at(StatRoll s) => s.index < r.length ? r[s.index] : 50;
    final g = statMultOf(bug.potential) * species.gradeScale;
    return (
      hp: g * rollFactor(at(StatRoll.hp)),
      atk: g * rollFactor(at(StatRoll.atk)),
      def: g * rollFactor(at(StatRoll.def)),
      spd: rollFactor(at(StatRoll.spd)),
      crit: innate(StatRoll.crit, at(StatRoll.crit)),
      evade: innate(StatRoll.evade, at(StatRoll.evade)),
      recovery: innate(StatRoll.recovery, at(StatRoll.recovery)),
      push: pushFactor(at(StatRoll.push)),
    );
  }

  /// 등급 올리기 — 칸마다 다시 굴려 **기존 값과 큰 쪽**(내려가지 않는다). 물약이 새 롤의 바닥을 올린다.
  List<int> rollUp(List<int> old, math.Random rng, int potions) {
    final floor = (potions.clamp(0, potionMaxPerUse) * potionFloorStep).clamp(
      0,
      100,
    );
    return [for (final v in old) math.max(v, floor + rng.nextInt(101 - floor))];
  }

  /// [weights](일반 → 전설)에서 [r](0~1) 로 포텐셜(1~5)을 고른다 — 호출부가 난수를 넘긴다(소비 횟수를 맞추려고).
  static int pickWith(List<double> weights, double r) {
    final total = weights.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return 1;
    var x = r * total;
    for (var i = 0; i < weights.length; i++) {
      x -= weights[i];
      if (x < 0) return i + 1;
    }
    return weights.length;
  }

  /// [weights](일반 → 전설)에서 포텐셜(1~5)을 하나 고른다.
  static int pick(List<double> weights, math.Random rng) {
    final total = weights.fold<double>(0, (a, b) => a + b);
    var r = rng.nextDouble() * total;
    for (var i = 0; i < weights.length; i++) {
      r -= weights[i];
      if (r < 0) return i + 1;
    }
    return weights.length;
  }

  factory IndividualGradeConfig.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const IndividualGradeConfig();
    const d = IndividualGradeConfig();
    List<double> dl(String k, List<double> v) => j[k] is List
        ? [for (final x in j[k] as List) (x as num).toDouble()]
        : v;
    return IndividualGradeConfig(
      enabled: j['enabled'] as bool? ?? false,
      statMult: dl('statMult', d.statMult),
      rollWidth: (j['rollWidth'] as num?)?.toDouble() ?? d.rollWidth,
      innateMax: {
        for (final e in ((j['innateMax'] as Map?) ?? const {}).entries)
          '${e.key}': (e.value as num).toDouble(),
      },
      wildWeights: dl('wildWeights', d.wildWeights),
      breedChildWild: j['breedChildWild'] as bool? ?? d.breedChildWild,
      essenceCosts: j['essenceCosts'] is List
          ? [for (final x in j['essenceCosts'] as List) (x as num).toInt()]
          : d.essenceCosts,
      essenceRarity: {
        for (final e in ((j['essenceRarity'] as Map?) ?? const {}).entries)
          Grade.fromKey('${e.key}'): (e.value as num).toDouble(),
      },
      potionFloorStep:
          (j['potionFloorStep'] as num?)?.toInt() ?? d.potionFloorStep,
      potionMaxPerUse:
          (j['potionMaxPerUse'] as num?)?.toInt() ?? d.potionMaxPerUse,
      gachaGradeWeights: dl('gachaGradeWeights', d.gachaGradeWeights),
      gachaPityMinPotential:
          (j['gachaPityMinPotential'] as num?)?.toInt() ??
          d.gachaPityMinPotential,
      potionJelly: (j['potionJelly'] as num?)?.toInt() ?? d.potionJelly,
      potionDailyBuy:
          (j['potionDailyBuy'] as num?)?.toInt() ?? d.potionDailyBuy,
      potionEliteChance:
          (j['potionEliteChance'] as num?)?.toDouble() ?? d.potionEliteChance,
      potionBossChance:
          (j['potionBossChance'] as num?)?.toDouble() ?? d.potionBossChance,
      potionBossFirst:
          (j['potionBossFirst'] as num?)?.toInt() ?? d.potionBossFirst,
      potionAbyss10: (j['potionAbyss10'] as num?)?.toInt() ?? d.potionAbyss10,
    );
  }
}
