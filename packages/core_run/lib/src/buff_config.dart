import 'package:meta/meta.dart';

import 'character_stats.dart';
import 'enums.dart';

/// 버프 1종의 효과 배율 정의 (JSON). 지정 안 된 배율은 1.0(무효과).
@immutable
class BuffSpec {
  const BuffSpec({
    required this.kind,
    this.gold = 1.0,
    this.xp = 1.0,
    this.attack = 1.0,
    this.attackSpeed = 1.0,
    this.materialFind = 1.0,
    this.bugFind = 1.0,
  });

  final BuffKind kind;
  final double gold;
  final double xp;
  final double attack;
  final double attackSpeed;
  final double materialFind;
  final double bugFind;

  factory BuffSpec.fromJson(Map<String, dynamic> json) => BuffSpec(
    kind: BuffKind.fromKey(json['kind'] as String)!,
    gold: (json['gold'] as num?)?.toDouble() ?? 1.0,
    xp: (json['xp'] as num?)?.toDouble() ?? 1.0,
    attack: (json['attack'] as num?)?.toDouble() ?? 1.0,
    attackSpeed: (json['attackSpeed'] as num?)?.toDouble() ?? 1.0,
    materialFind: (json['materialFind'] as num?)?.toDouble() ?? 1.0,
    bugFind: (json['bugFind'] as num?)?.toDouble() ?? 1.0,
  );
}

/// 버프 시스템 전체 설정 (assets/data/buffs.json 에서 로드).
@immutable
class BuffConfig {
  const BuffConfig({
    required this.durationSeconds,
    required this.maxSeconds,
    required this.specs,
  });

  /// 광고 1회 시청으로 부여되는 지속시간(초).
  final int durationSeconds;

  /// 재시청 누적 시 남은 시간 상한(초). 이 이상으로는 쌓이지 않는다.
  final int maxSeconds;

  final Map<BuffKind, BuffSpec> specs;

  BuffSpec? spec(BuffKind kind) => specs[kind];

  factory BuffConfig.fromJson(Map<String, dynamic> json) {
    final list = (json['buffs'] as List).cast<Map<String, dynamic>>().map(
      BuffSpec.fromJson,
    );
    return BuffConfig(
      durationSeconds: (json['durationSeconds'] as num).toInt(),
      maxSeconds: (json['maxSeconds'] as num).toInt(),
      specs: {for (final s in list) s.kind: s},
    );
  }
}

/// 활성 버프들을 기본 능력치에 곱해 유효 능력치를 만든다.
/// 여러 버프가 같은 배율을 건드리면 곱연산으로 누적된다.
CharacterStats applyBuffs(
  CharacterStats base,
  Iterable<BuffKind> active,
  BuffConfig? config,
) {
  if (config == null) return base;
  var gold = 1.0, xp = 1.0, atk = 1.0, atkSpeed = 1.0, mat = 1.0, bug = 1.0;
  for (final k in active) {
    final s = config.spec(k);
    if (s == null) continue;
    gold *= s.gold;
    xp *= s.xp;
    atk *= s.attack;
    atkSpeed *= s.attackSpeed;
    mat *= s.materialFind;
    bug *= s.bugFind;
  }
  return CharacterStats(
    attack: base.attack * atk,
    attackSpeed: base.attackSpeed * atkSpeed,
    rewardMultiplier: base.rewardMultiplier * gold,
    critChance: base.critChance,
    critDamage: base.critDamage,
    bossDamage: base.bossDamage,
    maxHp: base.maxHp,
    defense: base.defense,
    hpRegen: base.hpRegen,
    xpMultiplier: base.xpMultiplier * xp,
    bugFind: base.bugFind * bug,
    materialFind: base.materialFind * mat,
    moveSpeed: base.moveSpeed,
    boostBonus: base.boostBonus,
  );
}
