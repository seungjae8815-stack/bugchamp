import 'dart:math' as math;

import 'package:core_models/core_models.dart';
import 'package:meta/meta.dart';

import 'enums.dart';
import 'jelly_cost.dart';

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
    this.unlockShards = 10,
    this.levelShardsBase = const {},
    this.levelShardsGrowth = 1.3,
    this.trainMinutesBase = const {},
    this.trainGrowth = 1.35,
    this.trainJellyPerMinute = 1.2,
    this.trainJellyExponent = 0.58,
    this.anyShardValue = const {},
    this.bossFirstKillRolls = 3,
    this.bossRepeatRolls = 1,
    this.shardsPerRoll = const {},
    this.bossGradeWeightsByTier = const [],
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

  /// 만능 조각 환산값(등급별). 만렙 스킬 조각 1개 → 만능 value 개,
  /// 만능으로 조각 1개를 메울 때 value 개.
  final Map<Grade, int> anyShardValue;

  final int bossFirstKillRolls;
  final int bossRepeatRolls;

  /// 한 번 뽑을 때 나오는 조각 수(등급별).
  final Map<Grade, int> shardsPerRoll;

  /// 보스 조각 등급 가중치 — 인덱스 = 난이도.
  final List<Map<Grade, double>> bossGradeWeightsByTier;

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

  int anyValueOf(Grade g) => anyShardValue[g] ?? 1;

  /// 보스 한 마리를 잡았을 때 나오는 조각 — 스킬 id → 개수.
  ///
  /// 모든 무작위는 주입된 [rng] 로만(§5 결정론). 등급 → 그 등급 스킬 하나 →
  /// [shardsPerRoll] 개를 [bossFirstKillRolls]/[bossRepeatRolls] 번 반복한다.
  Map<String, int> rollBossShards(
    math.Random rng, {
    required int tier,
    required bool firstKill,
  }) {
    final out = <String, int>{};
    if (bossGradeWeightsByTier.isEmpty || skills.isEmpty) return out;
    final weights =
        bossGradeWeightsByTier[tier.clamp(
          0,
          bossGradeWeightsByTier.length - 1,
        )];
    final rolls = firstKill ? bossFirstKillRolls : bossRepeatRolls;
    for (var i = 0; i < rolls; i++) {
      final grade = _pickGrade(rng, weights);
      if (grade == null) continue;
      final pool = [
        for (final s in skills)
          if (s.grade == grade) s,
      ];
      if (pool.isEmpty) continue;
      final def = pool[rng.nextInt(pool.length)];
      final n = shardsPerRoll[grade] ?? 0;
      if (n <= 0) continue;
      out[def.id] = (out[def.id] ?? 0) + n;
    }
    return out;
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
    return SkillConfig(
      skills: (json['skills'] as List)
          .cast<Map<String, dynamic>>()
          .map(SkillDef.fromJson)
          .toList(growable: false),
      slotsByTier: [
        for (final v in (json['slotsByTier'] as List? ?? const [2, 3, 4, 5]))
          (v as num).toInt(),
      ],
      maxLevel: (json['maxLevel'] as num?)?.toInt() ?? 10,
      unlockShards: (json['unlockShards'] as num?)?.toInt() ?? 10,
      levelShardsBase: gradeMap(json['levelShardsBase'], (n) => n.toInt()),
      levelShardsGrowth: (json['levelShardsGrowth'] as num?)?.toDouble() ?? 1.3,
      trainMinutesBase: gradeMap(json['trainMinutesBase'], (n) => n.toDouble()),
      trainGrowth: (json['trainGrowth'] as num?)?.toDouble() ?? 1.35,
      trainJellyPerMinute:
          (json['trainJellyPerMinute'] as num?)?.toDouble() ?? 1.2,
      trainJellyExponent:
          (json['trainJellyExponent'] as num?)?.toDouble() ?? 0.58,
      anyShardValue: gradeMap(json['anyShardValue'], (n) => n.toInt()),
      bossFirstKillRolls: (json['bossFirstKillRolls'] as num?)?.toInt() ?? 3,
      bossRepeatRolls: (json['bossRepeatRolls'] as num?)?.toInt() ?? 1,
      shardsPerRoll: gradeMap(json['shardsPerRoll'], (n) => n.toInt()),
      bossGradeWeightsByTier: [
        for (final w in (json['bossGradeWeightsByTier'] as List? ?? const []))
          gradeMap(w, (n) => n.toDouble()),
      ],
    );
  }
}

/// 장착한 패시브가 캐릭터 능력치에 더하는 값 — [applySpeciesPassives] 에 그대로 넘긴다.
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
      case 'bossDamage':
        add(UpgradeKind.bossDamage, v);
      case 'perPetAttack':
        add(UpgradeKind.attack, v * petCount);
    }
  }
  return out;
}

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
