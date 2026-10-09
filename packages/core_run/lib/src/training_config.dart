import 'dart:math' as math;

import 'package:core_models/core_models.dart';
import 'package:meta/meta.dart';

import 'jelly_cost.dart';

/// 훈련소 설정(2026-09-29 사장님 확정, `battle.json → training`).
///
/// 곤충마다 결투 능력치 5종([TrainStat])을 훈련한다. **모든 능력치를 끝까지 올릴 수 있지만
/// 끝(최대 단계)이 곤충마다 다르다** — 기본 + 포텐셜 + 기질·주특기·혈통 특성 보정.
/// 그래서 한 종류 곤충만 키우기보다 역할이 다른 곤충을 섞어 팀을 짜게 된다.
///
/// 비용 = 키틴·미네랄·수액 각각 `baseCost × costGrowth^(단계-1) × 등급 배수`(부위 강화와 같은 곡선) ·
/// 시간 = `baseSeconds × timeGrowth^(단계-1)` · 젤리 즉시 완료(분당 단가가 긴 대기일수록 싸진다).
@immutable
class TrainingConfig {
  const TrainingConfig({
    this.perLevel = const {
      TrainStat.attack: 0.015,
      TrainStat.defense: 0.015,
      TrainStat.evade: 0.01,
      TrainStat.crit: 0.01,
      TrainStat.recovery: 0.02,
    },
    this.baseCap = 6,
    this.capPerPotential = 1,
    this.temperamentMods = const {},
    this.specialtyMods = const {},
    this.traitMods = const {},
    this.baseCost = 20,
    this.costGrowth = 1.25,
    this.gradeMult = const {},
    this.baseSeconds = 900,
    this.timeGrowth = 1.6,
    this.instantJellyPerMinute = 0.5,
    this.instantJellyExponent = 0.58,
    this.resetRefund = 0.5,
    this.petScale = 0.005,
    this.duelLevelBonus = 0.005,
    this.pointsPerPotential = 6,
    this.levelsPerPoint = 5,
    this.breakthroughPoints = const [6, 10, 16, 24],
    this.slotEffect = kDefaultSlotEffect,
    this.legacySlotEffect = kLegacySlotEffect,
    this.slotBaseCap = kDefaultSlotCap,
    this.slotTemperamentMods = const {},
    this.slotSpecialtyMods = const {},
    this.slotTraitMods = const {},
    this.massSpeedPenalty = 0.005,
    this.techBySpecialty = const {
      Specialty.strike: 0.04,
      Specialty.grip: 0.03,
      Specialty.toss: 0.03,
    },
    this.pointCostGrowth = 1.03,
    this.pointTimeGrowth = 1.03,
    this.respecBaseMinutes = 30,
    this.respecPerPointMinutes = 3,
    this.respecMaxMinutes = 480,
    this.petPerPoint = 0.0025,
    this.legacyEnhancePetScale = 0.005,
    this.stones = const DuelStoneConfig(),
    this.presets = const {},
    this.presetFor = const {},
  });

  // ── 훈련 v2(2026-10-08, docs/design_training_v2.md) ─────────────────────
  //
  // 곤충마다 **훈련 포인트**(포텐셜·수련·돌파로 무료로 생긴다)를 칸 10종([TrainSlot])에 골라 찍는다.
  // 칸 상한 합 ≫ 포인트라 다 못 찍는다. 포인트를 **처음 쓸 때만** 재료·시간이 들고(그 곤충이 지금까지
  // 재료를 낸 포인트 수로 비용이 오른다), 다시 찍기는 무료 + 대기(젤리로 당긴다).
  // 아래 v1 필드(perLevel·baseCap·…)는 **이전(옛 훈련 단계 → 칸) 환산용**으로만 남는다.

  /// 포텐셜 1성당 포인트(5성 30).
  final int pointsPerPotential;

  /// 수련 몇 레벨마다 1포인트(80레벨 16).
  final int levelsPerPoint;

  /// 돌파 단계별 포인트(1단·2단·…). 누적으로 더한다(합 56).
  final List<int> breakthroughPoints;

  /// 칸 1포인트 효과. 공격·방어·체력·밀어내기 힘·체급 = 배율 +, 회피·치명·회복력 = 확률·비율 +,
  /// 근성 = 단계(1). 주특기 기술은 [techBySpecialty] 가 정한다(여기 값은 쓰지 않는다).
  final Map<TrainSlot, double> slotEffect;

  /// **이전 환산 전용** 1포인트 효과 — 옛 부위 강화·옛 훈련 단계를 몇 포인트로 옮길지 정한다.
  /// 칸 효과([slotEffect])를 밸런스로 바꿔도 이 값은 **고정**이다: 바꾸면 이전된 곤충의 포인트·보너스
  /// 포인트·칸 상한이 따라 움직인다(2026-10-09 사장님 확정 — 옛 고인물 보너스 포인트는 그대로).
  /// 처음 이전(2026-10-08)의 칸 효과 값이며, 날개(옛 속도) 몫은 밀어내기 힘 칸으로 같은 수만큼 옮긴다.
  final Map<TrainSlot, double> legacySlotEffect;

  /// 칸 기본 상한(기질·주특기·혈통 특성 보정을 더한다).
  final Map<TrainSlot, int> slotBaseCap;
  final Map<Temperament, Map<TrainSlot, int>> slotTemperamentMods;
  final Map<Specialty, Map<TrainSlot, int>> slotSpecialtyMods;
  final Map<BugTrait, Map<TrainSlot, int>> slotTraitMods;

  /// 체급 1포인트당 속도 감소(무게 + 의 대가).
  final double massSpeedPenalty;

  /// 주특기 기술 1포인트 효과(치기 뒤집기 확률 · 집기 무는 힘 · 던지기 쿨타임 감소).
  final Map<Specialty, double> techBySpecialty;

  /// 포인트 재료비·시간의 성장률 — n번째로 재료를 내는 포인트 = base × growth^(n-1).
  /// v1 단계 곡선(1.25·1.3)을 포인트 102개에 그대로 걸면 끝이 수십억이라, 102번째가 v1 의
  /// 14단계와 비슷하게 닿도록 낮춘 값이다(합계 재료·시간도 v1 전부 훈련과 비슷).
  final double pointCostGrowth;
  final double pointTimeGrowth;

  /// 다시 찍기 대기 = base + 재료를 낸 포인트당 perPoint 분, 최대 max 분.
  final int respecBaseMinutes;
  final int respecPerPointMinutes;
  final int respecMaxMinutes;

  /// 방치(펫) 기여 = 1 + 찍은 포인트 × petPerPoint(최대 ×1.26 — 옛 부위 강화 ×1.25 자리).
  final double petPerPoint;

  /// 옛 부위 강화의 펫 기여 계수(`pets.json → enhanceScale` 의 옛 값). 이전된 곤충이 **약해지지 않게**
  /// 펫 기여는 max(새 식, 옛 식)이다 — 옛 식에만 쓴다.
  final double legacyEnhancePetScale;

  /// 결투석(오행석·기질석).
  final DuelStoneConfig stones;

  /// 훈련소 "추천 배분"(2026-10-09) — 이름(`balanced`·`tank`·…) → 칸 비율. 순서 = 화면 순서.
  /// 측정(빌드 리그전)에서 강했던 배분이다. 비율이라 합이 예산과 같을 필요는 없다(core_save `distributeTrainPoints`).
  final Map<String, Map<TrainSlot, int>> presets;

  /// 주특기마다 먼저 고르는 추천 배분 이름(없으면 [presets] 의 첫 번째).
  final Map<Specialty, String> presetFor;

  /// [specialty] 의 기본 추천 배분 이름(없으면 null).
  String? presetIdFor(Specialty specialty) {
    final id = presetFor[specialty];
    if (id != null && presets.containsKey(id)) return id;
    return presets.keys.firstOrNull;
  }

  /// 이 곤충의 포인트 예산(보너스 제외). [level] 은 호출자가 돌파 상한으로 자른 값을 넘긴다.
  int pointBudget({
    required int potential,
    required int level,
    required int breakthroughTier,
  }) {
    var bt = 0;
    for (
      var i = 0;
      i < breakthroughTier && i < breakthroughPoints.length;
      i++
    ) {
      bt += breakthroughPoints[i];
    }
    final lv = levelsPerPoint <= 0 ? 0 : math.max(0, level) ~/ levelsPerPoint;
    return math.max(0, potential) * pointsPerPotential + lv + bt;
  }

  /// 칸 [slot] 의 상한(기본 + 기질·주특기·특성 보정).
  int slotCap(
    TrainSlot slot, {
    required Temperament temperament,
    required Specialty specialty,
    BugTrait trait = BugTrait.none,
  }) => math.max(
    0,
    (slotBaseCap[slot] ?? 0) +
        (slotTemperamentMods[temperament]?[slot] ?? 0) +
        (slotSpecialtyMods[specialty]?[slot] ?? 0) +
        (slotTraitMods[trait]?[slot] ?? 0),
  );

  /// [n]번째로 재료를 내는 포인트의 재료비(키틴·미네랄·수액 **각각**).
  int pointCost(int n, Grade grade) =>
      (baseCost * math.pow(pointCostGrowth, n - 1) * (gradeMult[grade] ?? 1))
          .round();

  /// [n]번째로 재료를 내는 포인트의 훈련 시간.
  Duration pointTime(int n) => Duration(
    seconds: (baseSeconds * math.pow(pointTimeGrowth, n - 1)).round(),
  );

  /// 다시 찍기 대기 — 재료를 낸 포인트 [paid] 기준.
  Duration respecWait(int paid) => Duration(
    minutes: math.min(
      respecMaxMinutes,
      respecBaseMinutes + respecPerPointMinutes * math.max(0, paid),
    ),
  );

  /// 배분 [alloc] → 결투 보너스(수련 레벨 보너스는 호출자가 곱한다).
  ({
    double atkMult,
    double defMult,
    double hpMult,
    double spdMult,
    double evade,
    double crit,
    double recovery,
    double massMult,
    double pushMult,
    double tech,
    int grit,
  })
  slotBonuses(Map<TrainSlot, int> alloc, Specialty specialty) {
    int n(TrainSlot s) => math.max(0, alloc[s] ?? 0);
    double v(TrainSlot s) => n(s) * (slotEffect[s] ?? 0);
    return (
      atkMult: 1 + v(TrainSlot.attack),
      defMult: 1 + v(TrainSlot.defense),
      hpMult: 1 + v(TrainSlot.hp),
      // 속도 칸은 2026-10-09 밀어내기 힘으로 바뀌었다 — 속도는 체급의 대가로만 준다.
      spdMult: math.max(0.0, 1 - n(TrainSlot.mass) * massSpeedPenalty),
      evade: v(TrainSlot.evade),
      crit: v(TrainSlot.crit),
      recovery: v(TrainSlot.recovery),
      massMult: 1 + v(TrainSlot.mass),
      pushMult: 1 + v(TrainSlot.push),
      tech: n(TrainSlot.tech) * (techBySpecialty[specialty] ?? 0),
      grit: n(TrainSlot.grit),
    );
  }

  /// 한 단계 효과(공격·방어 = 배율 +, 회피·치명·회복력 = 확률·비율 +).
  final Map<TrainStat, double> perLevel;

  /// 최대 단계 = baseCap + capPerPotential × 포텐셜 + 기질·주특기·특성 보정.
  final int baseCap;
  final int capPerPotential;
  final Map<Temperament, Map<TrainStat, int>> temperamentMods;
  final Map<Specialty, Map<TrainStat, int>> specialtyMods;
  final Map<BugTrait, Map<TrainStat, int>> traitMods;

  final double baseCost;
  final double costGrowth;
  final Map<Grade, double> gradeMult;
  final double baseSeconds;
  final double timeGrowth;
  final double instantJellyPerMinute;
  final double instantJellyExponent;

  /// 초기화 때 돌려받는 재료 비율.
  final double resetRefund;

  /// 훈련 → 방치(펫): 훈련 단계 합계 1당 펫 기여 +petScale(부위 강화 `enhanceScale` 과 같은 자리).
  final double petScale;

  /// 수련 → 결투: 레벨 1당 체력·공격 +duelLevelBonus(돌파 티어 레벨 상한으로 자른다).
  final double duelLevelBonus;

  /// 이 곤충의 [stat] 최대 단계.
  int cap(
    TrainStat stat, {
    required int potential,
    required Temperament temperament,
    required Specialty specialty,
    BugTrait trait = BugTrait.none,
  }) {
    final c =
        baseCap +
        capPerPotential * potential +
        (temperamentMods[temperament]?[stat] ?? 0) +
        (specialtyMods[specialty]?[stat] ?? 0) +
        (traitMods[trait]?[stat] ?? 0);
    return math.max(0, c);
  }

  /// [level]단계로 올리는 재료비(키틴·미네랄·수액 **각각**).
  int costFor(int level, Grade grade) =>
      (baseCost * math.pow(costGrowth, level - 1) * (gradeMult[grade] ?? 1))
          .round();

  /// [level]단계로 올리는 훈련 시간.
  Duration timeFor(int level) => Duration(
    seconds: (baseSeconds * math.pow(timeGrowth, level - 1)).round(),
  );

  /// 남은 [remaining] 을 젤리로 즉시 끝내는 값(5·10 단위).
  int instantJelly(Duration remaining) {
    if (remaining <= Duration.zero) return 0;
    final minutes = remaining.inSeconds / 60;
    return roundJellyCost(
      instantJellyPerMinute * math.pow(minutes, instantJellyExponent),
    );
  }

  /// 단계 [levels] → 결투 보너스.
  ({double atkMult, double defMult, double evade, double crit, double recovery})
  bonuses(Map<TrainStat, int> levels) {
    double v(TrainStat s) => (levels[s] ?? 0) * (perLevel[s] ?? 0);
    return (
      atkMult: 1 + v(TrainStat.attack),
      defMult: 1 + v(TrainStat.defense),
      evade: v(TrainStat.evade),
      crit: v(TrainStat.crit),
      recovery: v(TrainStat.recovery),
    );
  }

  factory TrainingConfig.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const TrainingConfig();
    const d = TrainingConfig();
    Map<TrainStat, int> mods(Object? raw) => {
      for (final e in ((raw as Map?) ?? const {}).entries)
        if (TrainStat.fromKeyOrNull('${e.key}') != null)
          TrainStat.fromKeyOrNull('${e.key}')!: (e.value as num).toInt(),
    };
    Map<K, Map<TrainStat, int>> table<K>(Object? raw, K Function(String) key) =>
        {
          for (final e in ((raw as Map?) ?? const {}).entries)
            key('${e.key}'): mods(e.value),
        };
    Map<TrainSlot, int> slotMods(Object? raw) => {
      for (final e in ((raw as Map?) ?? const {}).entries)
        if (TrainSlot.fromKeyOrNull('${e.key}') != null)
          TrainSlot.fromKeyOrNull('${e.key}')!: (e.value as num).toInt(),
    };
    Map<K, Map<TrainSlot, int>> slotTable<K>(
      Object? raw,
      K Function(String) key,
    ) => {
      for (final e in ((raw as Map?) ?? const {}).entries)
        key('${e.key}'): slotMods(e.value),
    };
    final pts = (j['points'] as Map?) ?? const {};
    final slots = <TrainSlot, Map>{
      for (final e in ((j['slots'] as Map?) ?? const {}).entries)
        if (TrainSlot.fromKeyOrNull('${e.key}') != null && e.value is Map)
          TrainSlot.fromKeyOrNull('${e.key}')!: e.value as Map,
    };
    final respec = (j['respec'] as Map?) ?? const {};
    final per = mods(null).map((k, v) => MapEntry(k, v.toDouble()));
    for (final e in ((j['perLevel'] as Map?) ?? const {}).entries) {
      final k = TrainStat.fromKeyOrNull('${e.key}');
      if (k != null) per[k] = (e.value as num).toDouble();
    }
    return TrainingConfig(
      perLevel: per.isEmpty ? d.perLevel : per,
      baseCap: (j['baseCap'] as num?)?.toInt() ?? d.baseCap,
      capPerPotential:
          (j['capPerPotential'] as num?)?.toInt() ?? d.capPerPotential,
      temperamentMods: table(j['temperamentMods'], Temperament.fromKey),
      specialtyMods: table(j['specialtyMods'], Specialty.fromKey),
      traitMods: table(j['traitMods'], BugTrait.fromKey),
      baseCost: (j['baseCost'] as num?)?.toDouble() ?? d.baseCost,
      costGrowth: (j['costGrowth'] as num?)?.toDouble() ?? d.costGrowth,
      gradeMult: {
        for (final e in ((j['gradeMult'] as Map?) ?? const {}).entries)
          Grade.fromKey('${e.key}'): (e.value as num).toDouble(),
      },
      baseSeconds: (j['baseSeconds'] as num?)?.toDouble() ?? d.baseSeconds,
      timeGrowth: (j['timeGrowth'] as num?)?.toDouble() ?? d.timeGrowth,
      instantJellyPerMinute:
          (j['instantJellyPerMinute'] as num?)?.toDouble() ??
          d.instantJellyPerMinute,
      instantJellyExponent:
          (j['instantJellyExponent'] as num?)?.toDouble() ??
          d.instantJellyExponent,
      resetRefund: (j['resetRefund'] as num?)?.toDouble() ?? d.resetRefund,
      petScale: (j['petScale'] as num?)?.toDouble() ?? d.petScale,
      duelLevelBonus:
          (j['duelLevelBonus'] as num?)?.toDouble() ?? d.duelLevelBonus,
      pointsPerPotential:
          (pts['perPotential'] as num?)?.toInt() ?? d.pointsPerPotential,
      levelsPerPoint:
          (pts['levelsPerPoint'] as num?)?.toInt() ?? d.levelsPerPoint,
      breakthroughPoints: pts['breakthrough'] is List
          ? [for (final x in pts['breakthrough'] as List) (x as num).toInt()]
          : d.breakthroughPoints,
      slotEffect: {
        ...d.slotEffect,
        for (final e in slots.entries)
          if (e.value['effect'] is num)
            e.key: (e.value['effect'] as num).toDouble(),
      },
      legacySlotEffect: {
        ...d.legacySlotEffect,
        for (final e in ((j['legacySlotEffect'] as Map?) ?? const {}).entries)
          if (TrainSlot.fromKeyOrNull('${e.key}') != null && e.value is num)
            TrainSlot.fromKeyOrNull('${e.key}')!: (e.value as num).toDouble(),
      },
      slotBaseCap: {
        ...d.slotBaseCap,
        for (final e in slots.entries)
          if (e.value['cap'] is num) e.key: (e.value['cap'] as num).toInt(),
      },
      slotTemperamentMods: slotTable(
        j['slotTemperamentMods'],
        Temperament.fromKey,
      ),
      slotSpecialtyMods: slotTable(j['slotSpecialtyMods'], Specialty.fromKey),
      slotTraitMods: slotTable(j['slotTraitMods'], BugTrait.fromKey),
      massSpeedPenalty:
          (j['massSpeedPenalty'] as num?)?.toDouble() ?? d.massSpeedPenalty,
      techBySpecialty: j['techBySpecialty'] is Map
          ? {
              for (final e in (j['techBySpecialty'] as Map).entries)
                Specialty.fromKey('${e.key}'): (e.value as num).toDouble(),
            }
          : d.techBySpecialty,
      pointCostGrowth:
          (j['pointCostGrowth'] as num?)?.toDouble() ?? d.pointCostGrowth,
      pointTimeGrowth:
          (j['pointTimeGrowth'] as num?)?.toDouble() ?? d.pointTimeGrowth,
      respecBaseMinutes:
          (respec['baseMinutes'] as num?)?.toInt() ?? d.respecBaseMinutes,
      respecPerPointMinutes:
          (respec['perPointMinutes'] as num?)?.toInt() ??
          d.respecPerPointMinutes,
      respecMaxMinutes:
          (respec['maxMinutes'] as num?)?.toInt() ?? d.respecMaxMinutes,
      petPerPoint: (j['petPerPoint'] as num?)?.toDouble() ?? d.petPerPoint,
      legacyEnhancePetScale:
          (j['legacyEnhancePetScale'] as num?)?.toDouble() ??
          d.legacyEnhancePetScale,
      stones: DuelStoneConfig.fromJson(j['stones'] as Map<String, dynamic>?),
      presets: {
        for (final e in ((j['presets'] as Map?) ?? const {}).entries)
          if (!'${e.key}'.startsWith('_') && e.value is Map)
            '${e.key}': slotMods(e.value),
      },
      presetFor: {
        for (final e in ((j['presetFor'] as Map?) ?? const {}).entries)
          if (!'${e.key}'.startsWith('_'))
            Specialty.fromKey('${e.key}'): '${e.value}',
      },
    );
  }
}

/// 칸 1포인트 효과 기본값(design_training_v2.md §1.2 · 2026-10-09 출시 전 점검 반영 — `battle.json` 과 같은 값).
const kDefaultSlotEffect = <TrainSlot, double>{
  TrainSlot.attack: 0.05,
  TrainSlot.defense: 0.055,
  TrainSlot.hp: 0.09,
  TrainSlot.push: 0.025,
  TrainSlot.evade: 0.0085,
  TrainSlot.crit: 0.023,
  TrainSlot.recovery: 0.016,
  TrainSlot.mass: 0.010,
  TrainSlot.tech: 0,
  TrainSlot.grit: 1,
};

/// 이전 환산 전용 1포인트 효과(2026-10-08 처음 이전 때의 칸 효과 — **고정**, [TrainingConfig.legacySlotEffect]).
const kLegacySlotEffect = <TrainSlot, double>{
  TrainSlot.attack: 0.03,
  TrainSlot.defense: 0.03,
  TrainSlot.hp: 0.04,
  TrainSlot.push: 0.02,
  TrainSlot.evade: 0.006,
  TrainSlot.crit: 0.01,
  TrainSlot.recovery: 0.015,
};

/// 칸 기본 상한(design_training_v2.md §1.2).
const kDefaultSlotCap = <TrainSlot, int>{
  TrainSlot.attack: 30,
  TrainSlot.defense: 30,
  TrainSlot.hp: 30,
  TrainSlot.push: 20,
  TrainSlot.evade: 20,
  TrainSlot.crit: 20,
  TrainSlot.recovery: 20,
  TrainSlot.mass: 10,
  TrainSlot.tech: 10,
  TrainSlot.grit: 10,
};

/// 결투석 설정(`battle.json → training.stones`, design_training_v2.md §3).
///
/// 무료 경로 = 정예·보스 재처치 확률 드롭 + 심연 10층마다 첫 도달. 젤리 구매 = 시간 판매(§2.8 예외 —
/// 오행·기질은 능력치가 아니라 **선택**이고 짝짓기 상속·드롭으로도 닿는다).
@immutable
class DuelStoneConfig {
  const DuelStoneConfig({
    this.jelly = const {DuelStone.element: 40, DuelStone.temperament: 60},
    this.eliteChance = const {DuelStone.element: 0.002},
    this.bossRepeatChance = const {
      DuelStone.element: 0.01,
      DuelStone.temperament: 0.005,
    },
    this.abyssEvery = 10,
    this.abyssCount = const {DuelStone.element: 2, DuelStone.temperament: 1},
  });

  /// 1개 젤리 값(5·10 단위로 둔다).
  final Map<DuelStone, int> jelly;

  /// 정예 처치 1번에 나올 확률.
  final Map<DuelStone, double> eliteChance;

  /// 보스 재처치(첫 처치·되찾기 제외) 1번에 나올 확률.
  final Map<DuelStone, double> bossRepeatChance;

  /// 심연 몇 층마다 첫 도달 보상(`run_config.json → abyss.milestoneEvery` 와 같은 값으로 둔다).
  final int abyssEvery;
  final Map<DuelStone, int> abyssCount;

  factory DuelStoneConfig.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const DuelStoneConfig();
    const d = DuelStoneConfig();
    Map<DuelStone, T> m<T>(
      Object? raw,
      T Function(num) f,
      Map<DuelStone, T> def,
    ) => raw is Map
        ? {
            for (final e in raw.entries)
              if (DuelStone.fromKeyOrNull('${e.key}') != null)
                DuelStone.fromKeyOrNull('${e.key}')!: f(e.value as num),
          }
        : def;
    return DuelStoneConfig(
      jelly: m(j['jelly'], (x) => x.toInt(), d.jelly),
      eliteChance: m(j['eliteChance'], (x) => x.toDouble(), d.eliteChance),
      bossRepeatChance: m(
        j['bossRepeatChance'],
        (x) => x.toDouble(),
        d.bossRepeatChance,
      ),
      abyssEvery: (j['abyssEvery'] as num?)?.toInt() ?? d.abyssEvery,
      abyssCount: m(j['abyssCount'], (x) => x.toInt(), d.abyssCount),
    );
  }
}
