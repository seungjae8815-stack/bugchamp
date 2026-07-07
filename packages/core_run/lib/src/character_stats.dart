import 'package:meta/meta.dart';

/// 업그레이드/레벨/곤충버프로부터 파생된 캐릭터 유효 능력치.
@immutable
class CharacterStats {
  const CharacterStats({
    required this.attack,
    required this.attackSpeed,
    required this.rewardMultiplier,
    required this.critChance,
    required this.critDamage,
    required this.bossDamage,
    required this.maxHp,
    required this.defense,
    required this.hpRegen,
    required this.xpMultiplier,
    required this.bugFind,
    required this.materialFind,
    required this.moveSpeed,
    required this.boostBonus,
  });

  /// 타격당 데미지.
  final double attack;

  /// 초당 공격 횟수.
  final double attackSpeed;

  /// 골드 획득 배율(곤충 버프 포함).
  final double rewardMultiplier;

  /// 치명타 확률 (0~1).
  final double critChance;

  /// 치명타 데미지 배수.
  final double critDamage;

  /// 보스 추가 데미지 배수.
  final double bossDamage;

  /// 최대 체력.
  final double maxHp;

  /// 방어력 (받는 피해 경감).
  final double defense;

  /// 초당 체력 재생.
  final double hpRegen;

  /// 경험치 획득 배율.
  final double xpMultiplier;

  /// 곤충 조우율 배율.
  final double bugFind;

  /// 재료 획득 배율.
  final double materialFind;

  /// 이동속도 배율(걷기 시간 단축).
  final double moveSpeed;

  /// 탭 부스트 강화 배율.
  final double boostBonus;

  /// 한 번의 공격 간격.
  Duration get attackInterval =>
      Duration(microseconds: (1000000 / attackSpeed).round());

  @override
  String toString() =>
      'CharacterStats(atk: ${attack.toStringAsFixed(1)}, '
      'as: ${attackSpeed.toStringAsFixed(2)}/s, hp: ${maxHp.toStringAsFixed(0)}, '
      'def: ${defense.toStringAsFixed(0)})';
}
