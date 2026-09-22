import 'dart:math' as math;

import 'package:core_models/core_models.dart';
import 'package:meta/meta.dart';

import 'character_stats.dart';
import 'enums.dart';
import 'jelly_cost.dart';
import 'pet_config.dart' show applySpeciesPassives;
import 'run_math.dart' show baselineHitPower;

/// 스킬이 액티브인지 패시브인지. **칸은 나누지 않는다** — 액티브 5개로 화력을
/// 몰든 패시브 5개로 방치 효율을 올리든 본인이 고른다. 나누는 순간 선택이 사라진다.
enum SkillKind {
  active('active'),
  passive('passive');

  const SkillKind(this.key);
  final String key;

  static SkillKind fromKey(String key) => values.firstWhere(
    (e) => e.key == key,
    orElse: () => throw ArgumentError('Unknown SkillKind key: $key'),
  );
}

/// 스킬이 쓰는 등급 4단계(CLAUDE.md §2.8). 곤충의 고급(uncommon)은 안 쓴다 —
/// 12종을 5칸으로 쪼개면 칸마다 2~3종이라 등급이 읽히지 않는다.
const List<Grade> kSkillGrades = [
  Grade.common,
  Grade.rare,
  Grade.epic,
  Grade.legendary,
];

/// 스킬 1종의 정의 (assets/data/skills.json).
@immutable
class SkillDef {
  const SkillDef({
    required this.id,
    required this.kind,
    required this.grade,
    required this.name,
    required this.effect,
    required this.base,
    required this.perLevel,
    this.cooldown = Duration.zero,
    this.duration = Duration.zero,
    this.timing = const {},
  });

  final String id;
  final SkillKind kind;
  final Grade grade;
  final LocalizedText name;

  /// 효과 종류 키(`bossDamage`·`revive` 등). 해석은 호출부가 한다 —
  /// 효과마다 붙는 자리가 달라 enum 하나로 묶으면 오히려 분기가 는다.
  final String effect;

  /// 레벨 1 효과값.
  final double base;

  /// 레벨당 증가분.
  final double perLevel;

  final Duration cooldown;
  final Duration duration;

  /// 직접 눌렀을 때만 붙는 타이밍 보너스 수치(스킬마다 키가 다르다). 없으면 빈 맵.
  final Map<String, double> timing;

  double timingValue(String key, [double fallback = 0]) =>
      timing[key] ?? fallback;

  bool get isActive => kind == SkillKind.active;

  /// 레벨 [level](1부터)에서의 효과값.
  double valueAt(int level) => base + perLevel * (level - 1).clamp(0, 1 << 20);

  factory SkillDef.fromJson(Map<String, dynamic> json) => SkillDef(
    id: json['id'] as String,
    kind: SkillKind.fromKey(json['kind'] as String),
    grade: Grade.fromKey(json['grade'] as String? ?? 'common'),
    name: LocalizedText.fromJson(
      Map<String, dynamic>.from(json['name'] as Map),
    ),
    effect: json['effect'] as String,
    base: (json['base'] as num).toDouble(),
    perLevel: (json['perLevel'] as num?)?.toDouble() ?? 0,
    cooldown: Duration(seconds: (json['cooldown'] as num?)?.toInt() ?? 0),
    duration: Duration(seconds: (json['duration'] as num?)?.toInt() ?? 0),
    timing: {
      if (json['timing'] is Map)
        for (final e in (json['timing'] as Map).entries)
          e.key as String: (e.value as num).toDouble(),
    },
  );
}

/// 패시브 효과 키 — 데이터 검사(`data_test`)가 이 목록으로 오타를 잡는다.
/// 모르는 키는 로딩을 통과하고 **효과만 조용히 사라지기** 때문이다(종 패시브와 같은 구멍).
const Set<String> kSkillPassiveEffects = {
  'materialFind',
  'bugFind',
  'bossDamage',
  'perPetAttack',
  'killHeal',
  'revive',
};

/// 액티브 효과 키(홈 스킬 바에서 붙는다).
const Set<String> kSkillActiveEffects = {
  'materialFind',
  'attackSpeed',
  'areaDamage',
  'petPower',
  'burstDamage',
  'invulnerable',
};

/// 스킬 설정 전체.
@immutable
class SkillConfig {
  const SkillConfig({
    required this.skills,
    this.slotsByTier = const [2, 3, 4, 5],
    this.maxLevel = 10,
    this.unlockShards = 100,
    this.levelShardsBase = const {},
    this.levelShardsGrowth = 1.2,
    this.trainMinutesBase = const {},
    this.trainGrowth = 1.35,
    this.trainJellyPerMinute = 1.2,
    this.trainJellyExponent = 0.58,
    this.gradeUpRatio = 10,
    this.bossFirstKillShards = 10,
    this.bossRepeatChance = 0.1,
    this.bossRepeatShardsByTier = const [3, 4, 4, 5],
    this.eliteShardChance = 0.1,
    this.eliteShards = 1,
    this.dropGradeWeightsByTier = const [],
    this.gachaJellyCost = 30,
    this.gachaShards = 10,
    this.gachaPity = 10,
    this.gachaPityGrade = Grade.legendary,
    this.gachaGradeWeights = const {},
    this.gachaFreePerDay = 1,
    this.sweepShardsByTier = const [3, 4, 4, 5],
    this.sweepFreePerDay = 3,
    this.sweepJellyCost = 10,
    this.sweepMaxPerDay = 10,
  });

  final List<SkillDef> skills;

  /// 장착 칸 수 — 인덱스 = 처음 가 본 최고 난이도. 진행도로만 연다(젤리 판매 금지).
  final List<int> slotsByTier;

  final int maxLevel;

  /// 해금(레벨 1)에 필요한 그 스킬의 조각.
  final int unlockShards;

  /// 레벨 L → L+1 조각 = base[등급] × growth^(L-1).
  final Map<Grade, int> levelShardsBase;
  final double levelShardsGrowth;

  /// 수련 시간(분) = base[등급] × growth^(L-1).
  final Map<Grade, double> trainMinutesBase;
  final double trainGrowth;

  /// 즉시완료 젤리 = 계수 × 남은분^지수 → [roundJellyCost].
  final double trainJellyPerMinute;
  final double trainJellyExponent;

  /// 같은 등급 조각 이만큼 → 한 단계 위 등급 만능 조각 1개.
  final int gradeUpRatio;

  /// 보스 첫 처치 조각(확정).
  final int bossFirstKillShards;

  /// 첫 처치 뒤 보스를 다시 잡았을 때 조각이 나올 확률 · 난이도별 개수.
  final double bossRepeatChance;
  final List<int> bossRepeatShardsByTier;

  /// 정예 처치 조각 확률 · 개수.
  final double eliteShardChance;
  final int eliteShards;

  /// 드롭 조각의 등급 가중치 — 인덱스 = 난이도. 보스·정예 공용.
  final List<Map<Grade, double>> dropGradeWeightsByTier;

  /// 스킬 뽑기 — 젤리 가격 · 1회 조각 · 천장 횟수·등급 · 등급 가중치 · 하루 무료.
  final int gachaJellyCost;
  final int gachaShards;
  final int gachaPity;
  final Grade gachaPityGrade;
  final Map<Grade, double> gachaGradeWeights;
  final int gachaFreePerDay;

  /// 보스 소탕권 — 난이도별 확정 조각 · 하루 무료 · 추가 젤리 · 하루 합계 상한.
  final List<int> sweepShardsByTier;
  final int sweepFreePerDay;
  final int sweepJellyCost;
  final int sweepMaxPerDay;

  /// 소탕 1회 조각(난이도 [tier]).
  int sweepShardsFor(int tier) => sweepShardsByTier.isEmpty
      ? 0
      : sweepShardsByTier[tier.clamp(0, sweepShardsByTier.length - 1)];

  /// 뽑기 1회 — (스킬 id, 등급). [pityDue] 면 천장 등급 미만을 잘라낸다.
  (String, Grade)? rollGacha(math.Random rng, {required bool pityDue}) {
    var weights = Map<Grade, double>.from(gachaGradeWeights);
    if (pityDue) {
      weights = {
        for (final e in weights.entries)
          if (e.key.index >= gachaPityGrade.index) e.key: e.value,
      };
    }
    final grade = _pickGrade(rng, weights);
    if (grade == null) return null;
    final pool = [
      for (final s in skills)
        if (s.grade == grade) s,
    ];
    if (pool.isEmpty) return null;
    return (pool[rng.nextInt(pool.length)].id, grade);
  }

  /// 확률 공개용 — 등급별 확률(0~1, 천장 제외).
  Map<Grade, double> get gachaGradeOdds {
    final total = gachaGradeWeights.values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return const {};
    return {for (final e in gachaGradeWeights.entries) e.key: e.value / total};
  }

  SkillDef? byId(String id) {
    for (final s in skills) {
      if (s.id == id) return s;
    }
    return null;
  }

  Iterable<SkillDef> get actives => skills.where((s) => s.isActive);
  Iterable<SkillDef> get passives => skills.where((s) => !s.isActive);

  /// 처음 가 본 최고 난이도 [topTier] 에서 열린 장착 칸 수.
  int slotsFor(int topTier) {
    if (slotsByTier.isEmpty) return 0;
    return slotsByTier[topTier.clamp(0, slotsByTier.length - 1)];
  }

  /// 이론상 최대 칸 수(서버 상한 검사용).
  int get maxSlots => slotsByTier.fold(0, math.max);

  /// [g] 의 한 단계 위 스킬 등급(전설이면 null).
  static Grade? nextGrade(Grade g) {
    final i = kSkillGrades.indexOf(g);
    return (i < 0 || i >= kSkillGrades.length - 1) ? null : kSkillGrades[i + 1];
  }

  /// 레벨 [level] → [level]+1 에 드는 그 스킬 조각.
  int shardsForLevel(SkillDef def, int level) {
    final base = levelShardsBase[def.grade] ?? 0;
    return (base * math.pow(levelShardsGrowth, (level - 1).clamp(0, 1 << 10)))
        .round();
  }

  /// 레벨 [level] → [level]+1 수련 시간.
  Duration trainDuration(SkillDef def, int level) {
    final base = trainMinutesBase[def.grade] ?? 0;
    final minutes = base * math.pow(trainGrowth, (level - 1).clamp(0, 1 << 10));
    return Duration(seconds: (minutes * 60).round());
  }

  /// 남은 수련 시간 [remaining] 을 당기는 젤리. 끝났으면 0.
  int trainJelly(Duration remaining) {
    if (remaining <= Duration.zero) return 0;
    final minutes = remaining.inSeconds / 60;
    return roundJellyCost(
      trainJellyPerMinute * math.pow(minutes, trainJellyExponent),
    );
  }

  /// 보스 처치 조각 — 스킬 id → 개수(안 나오면 빈 맵).
  ///
  /// 첫 처치는 [bossFirstKillShards] 확정, 그 뒤는 [bossRepeatChance] 확률로
  /// [bossRepeatShardsByTier]. 모든 무작위는 주입된 [rng] 로만(§5 결정론).
  Map<String, int> rollBossShards(
    math.Random rng, {
    required int tier,
    required bool firstKill,
  }) {
    if (firstKill) return _rollSkill(rng, tier, bossFirstKillShards);
    if (rng.nextDouble() >= bossRepeatChance) return const {};
    final n = bossRepeatShardsByTier.isEmpty
        ? 0
        : bossRepeatShardsByTier[tier.clamp(
            0,
            bossRepeatShardsByTier.length - 1,
          )];
    return _rollSkill(rng, tier, n);
  }

  /// 정예 처치 조각 — [eliteShardChance] 확률로 [eliteShards].
  Map<String, int> rollEliteShards(math.Random rng, {required int tier}) {
    if (rng.nextDouble() >= eliteShardChance) return const {};
    return _rollSkill(rng, tier, eliteShards);
  }

  /// 등급(난이도별 가중치) → 그 등급 스킬 하나(균등) → [count] 개.
  Map<String, int> _rollSkill(math.Random rng, int tier, int count) {
    if (count <= 0 || dropGradeWeightsByTier.isEmpty || skills.isEmpty) {
      return const {};
    }
    final weights =
        dropGradeWeightsByTier[tier.clamp(
          0,
          dropGradeWeightsByTier.length - 1,
        )];
    final grade = _pickGrade(rng, weights);
    if (grade == null) return const {};
    final pool = [
      for (final s in skills)
        if (s.grade == grade) s,
    ];
    if (pool.isEmpty) return const {};
    return {pool[rng.nextInt(pool.length)].id: count};
  }

  static Grade? _pickGrade(math.Random rng, Map<Grade, double> weights) {
    final total = weights.values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return null;
    var pick = rng.nextDouble() * total;
    Grade? last;
    for (final e in weights.entries) {
      if (e.value <= 0) continue;
      last = e.key;
      pick -= e.value;
      if (pick <= 0) return e.key;
    }
    return last;
  }

  factory SkillConfig.fromJson(Map<String, dynamic> json) {
    Map<Grade, T> gradeMap<T extends num>(Object? raw, T Function(num) cast) =>
        {
          if (raw is Map)
            for (final e in raw.entries)
              Grade.fromKey(e.key as String): cast(e.value as num),
        };
    List<int> ints(Object? raw, List<int> fallback) =>
        raw is List ? [for (final v in raw) (v as num).toInt()] : fallback;
    return SkillConfig(
      skills: (json['skills'] as List)
          .cast<Map<String, dynamic>>()
          .map(SkillDef.fromJson)
          .toList(growable: false),
      slotsByTier: ints(json['slotsByTier'], const [2, 3, 4, 5]),
      maxLevel: (json['maxLevel'] as num?)?.toInt() ?? 10,
      unlockShards: (json['unlockShards'] as num?)?.toInt() ?? 100,
      levelShardsBase: gradeMap(json['levelShardsBase'], (n) => n.toInt()),
      levelShardsGrowth: (json['levelShardsGrowth'] as num?)?.toDouble() ?? 1.2,
      trainMinutesBase: gradeMap(json['trainMinutesBase'], (n) => n.toDouble()),
      trainGrowth: (json['trainGrowth'] as num?)?.toDouble() ?? 1.35,
      trainJellyPerMinute:
          (json['trainJellyPerMinute'] as num?)?.toDouble() ?? 1.2,
      trainJellyExponent:
          (json['trainJellyExponent'] as num?)?.toDouble() ?? 0.58,
      gradeUpRatio: (json['gradeUpRatio'] as num?)?.toInt() ?? 10,
      bossFirstKillShards: (json['bossFirstKillShards'] as num?)?.toInt() ?? 10,
      bossRepeatChance: (json['bossRepeatChance'] as num?)?.toDouble() ?? 0.1,
      bossRepeatShardsByTier: ints(json['bossRepeatShardsByTier'], const [
        3,
        4,
        4,
        5,
      ]),
      eliteShardChance: (json['eliteShardChance'] as num?)?.toDouble() ?? 0.1,
      eliteShards: (json['eliteShards'] as num?)?.toInt() ?? 1,
      dropGradeWeightsByTier: [
        for (final w in (json['dropGradeWeightsByTier'] as List? ?? const []))
          gradeMap(w, (n) => n.toDouble()),
      ],
      gachaJellyCost: (json['gachaJellyCost'] as num?)?.toInt() ?? 30,
      gachaShards: (json['gachaShards'] as num?)?.toInt() ?? 10,
      gachaPity: (json['gachaPity'] as num?)?.toInt() ?? 10,
      gachaPityGrade: Grade.fromKey(
        json['gachaPityGrade'] as String? ?? 'legendary',
      ),
      gachaGradeWeights: gradeMap(
        json['gachaGradeWeights'],
        (n) => n.toDouble(),
      ),
      gachaFreePerDay: (json['gachaFreePerDay'] as num?)?.toInt() ?? 1,
      sweepShardsByTier: ints(json['sweepShardsByTier'], const [3, 4, 4, 5]),
      sweepFreePerDay: (json['sweepFreePerDay'] as num?)?.toInt() ?? 3,
      sweepJellyCost: (json['sweepJellyCost'] as num?)?.toInt() ?? 10,
      sweepMaxPerDay: (json['sweepMaxPerDay'] as num?)?.toInt() ?? 10,
    );
  }
}

/// 장착한 패시브가 캐릭터 능력치에 더하는 값 — [applySpeciesPassives] 에 그대로 넘긴다.
/// 보통은 [applySkillPassives] 로 한 번에 얹는다(끈기는 여기 없다 — 곱이라 따로).
///
/// 종 패시브와 **같은 층(가산)**이다: 적응형 위협 기준 **밖**, 장비·도감과 같은 자리.
/// 기준에 넣으면 끼는 순간 몬스터도 세져 스킬을 고르는 의미가 사라진다(§2.8).
/// [petCount] = 장착한 펫 수(군집).
Map<UpgradeKind, double> skillPassiveStats(
  SkillConfig cfg, {
  required Map<String, int> levels,
  required List<String> equipped,
  required int petCount,
}) {
  final out = <UpgradeKind, double>{};
  void add(UpgradeKind k, double v) => out[k] = (out[k] ?? 0) + v;
  for (final (def, lv) in _equippedPassives(cfg, levels, equipped)) {
    final v = def.valueAt(lv);
    switch (def.effect) {
      case 'materialFind':
        add(UpgradeKind.materialFind, v);
      case 'bugFind':
        add(UpgradeKind.bugFind, v);
      case 'perPetAttack':
        add(UpgradeKind.attack, v * petCount);
    }
  }
  return out;
}

/// 끈기(보스 피해 패시브) — **곱**(1 + 값). 없으면 1.0.
///
/// 가산이면 안 된다: 보스 피해는 강화로 1.0 → 최대 11.0 까지 자라서, +0.15 를 더하면
/// 후반엔 +1~3% 로 묽어진다(2026-09-22 실측: 보스 관문 기여 2% — 희귀 목표 15%).
/// 화면 문구("보스 피해 +15%")도 곱으로 읽힌다.
double skillBossDamageMult(
  SkillConfig cfg, {
  required Map<String, int> levels,
  required List<String> equipped,
}) {
  var m = 1.0;
  for (final (def, lv) in _equippedPassives(cfg, levels, equipped)) {
    if (def.effect == 'bossDamage') m += def.valueAt(lv);
  }
  return m;
}

/// 장착한 스킬 패시브를 능력치에 얹는다 — 가산 몫([skillPassiveStats]) + 끈기(곱).
/// 앱(`_stats`)과 시뮬이 같은 함수를 쓴다. 적응형 위협 기준 **밖**(§2.8).
CharacterStats applySkillPassives(
  CharacterStats s,
  SkillConfig cfg, {
  required Map<String, int> levels,
  required List<String> equipped,
  required int petCount,
  double critBudget = 1.0,
}) {
  final out = applySpeciesPassives(
    s,
    skillPassiveStats(
      cfg,
      levels: levels,
      equipped: equipped,
      petCount: petCount,
    ),
    critBudget: critBudget,
  );
  final boss = skillBossDamageMult(cfg, levels: levels, equipped: equipped);
  if (boss == 1.0) return out;
  return CharacterStats(
    attack: out.attack,
    attackSpeed: out.attackSpeed,
    rewardMultiplier: out.rewardMultiplier,
    critChance: out.critChance,
    critDamage: out.critDamage,
    bossDamage: out.bossDamage * boss,
    maxHp: out.maxHp,
    defense: out.defense,
    hpRegen: out.hpRegen,
    xpMultiplier: out.xpMultiplier,
    bugFind: out.bugFind,
    materialFind: out.materialFind,
    moveSpeed: out.moveSpeed,
    boostBonus: out.boostBonus,
  );
}

/// 순간 피해 액티브(회심의 일격·포충망) 한 방 — **지금 초당 피해 × [seconds]초**.
///
/// 예전(1.0.13 개발 중)엔 `공격력 × 값` 이었다. 공속·치명타가 자랄수록 한 방의 무게가
/// 묽어져 회심의 일격(전설)이 보스 관문을 쉬움 5% → 극한 2% 밖에 못 넓혔다 — 수치로는
/// 못 고친다(극한에 맞추면 쉬움에서 140%). 초 단위면 어느 난이도에서나 같은 무게다
/// (2026-09-22 사장님 확정). 치명타는 기대값으로 들어간다. 앱·시뮬 공용.
double skillBurstDamage(
  CharacterStats s,
  double seconds, {
  bool boss = false,
}) => baselineHitPower(s, boss: boss) * s.attackSpeed * seconds;

/// 처치 회복 배율(흡즙). 없으면 1.0.
double skillKillHealMult(
  SkillConfig cfg, {
  required Map<String, int> levels,
  required List<String> equipped,
}) {
  var m = 1.0;
  for (final (def, lv) in _equippedPassives(cfg, levels, equipped)) {
    if (def.effect == 'killHeal') m += def.valueAt(lv);
  }
  return m;
}

/// 탈피(패배 시 부활) — 장착했으면 (부활 체력 비율, 쿨타임), 아니면 null.
({double hpFraction, Duration cooldown})? skillRevive(
  SkillConfig cfg, {
  required Map<String, int> levels,
  required List<String> equipped,
}) {
  for (final (def, lv) in _equippedPassives(cfg, levels, equipped)) {
    if (def.effect == 'revive') {
      return (
        hpFraction: def.valueAt(lv).clamp(0.05, 1.0).toDouble(),
        cooldown: def.cooldown,
      );
    }
  }
  return null;
}

Iterable<(SkillDef, int)> _equippedPassives(
  SkillConfig cfg,
  Map<String, int> levels,
  List<String> equipped,
) sync* {
  for (final id in equipped) {
    final def = cfg.byId(id);
    final lv = levels[id] ?? 0;
    if (def == null || def.isActive || lv <= 0) continue;
    yield (def, lv.clamp(1, cfg.maxLevel));
  }
}
