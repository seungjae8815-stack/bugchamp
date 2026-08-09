import 'dart:math' as math;

import 'package:core_models/core_models.dart';
import 'package:meta/meta.dart';

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

/// 스킬 1종의 정의 (assets/data/skills.json).
@immutable
class SkillDef {
  const SkillDef({
    required this.id,
    required this.kind,
    required this.name,
    required this.effect,
    required this.base,
    required this.perLevel,
    this.cooldown = Duration.zero,
    this.duration = Duration.zero,
  });

  final String id;
  final SkillKind kind;
  final LocalizedText name;

  /// 효과 종류 키(`attackSpeed`·`bossDamage`·`revive` 등). 해석은 호출부가 한다 —
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

/// 스킬 설정 전체.
@immutable
class SkillConfig {
  const SkillConfig({
    required this.skills,
    this.equipSlots = 5,
    this.autoEfficiency = 0.7,
    this.goldBase = 5000,
    this.goldGrowth = 1.35,
    this.materialBase = 20,
    this.materialGrowth = 1.25,
    this.maxLevel = 20,
  });

  final List<SkillDef> skills;

  /// 장착 칸 수(액티브·패시브 공용).
  final int equipSlots;

  /// 방치 중 자동발동 효율. 1.0 미만이라 직접 누를 이유가 남고,
  /// 안 눌러도 손해는 아니게 된다.
  final double autoEfficiency;

  final double goldBase;
  final double goldGrowth;
  final double materialBase;
  final double materialGrowth;
  final int maxLevel;

  SkillDef? byId(String id) {
    for (final s in skills) {
      if (s.id == id) return s;
    }
    return null;
  }

  Iterable<SkillDef> get actives => skills.where((s) => s.isActive);
  Iterable<SkillDef> get passives => skills.where((s) => !s.isActive);

  /// 레벨 [level] → [level]+1 강화 비용.
  ({int gold, int material}) levelUpCost(int level) => (
    gold: (goldBase * math.pow(goldGrowth, level - 1)).round(),
    material: (materialBase * math.pow(materialGrowth, level - 1)).round(),
  );

  factory SkillConfig.fromJson(Map<String, dynamic> json) {
    final lv = json['levelUp'] as Map<String, dynamic>? ?? const {};
    return SkillConfig(
      skills: (json['skills'] as List)
          .cast<Map<String, dynamic>>()
          .map(SkillDef.fromJson)
          .toList(growable: false),
      equipSlots: (json['equipSlots'] as num?)?.toInt() ?? 5,
      autoEfficiency: (json['autoEfficiency'] as num?)?.toDouble() ?? 0.7,
      goldBase: (lv['goldBase'] as num?)?.toDouble() ?? 5000,
      goldGrowth: (lv['goldGrowth'] as num?)?.toDouble() ?? 1.35,
      materialBase: (lv['materialBase'] as num?)?.toDouble() ?? 20,
      materialGrowth: (lv['materialGrowth'] as num?)?.toDouble() ?? 1.25,
      maxLevel: (lv['maxLevel'] as num?)?.toInt() ?? 20,
    );
  }
}
