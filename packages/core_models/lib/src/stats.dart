import 'package:meta/meta.dart';

/// 기본 4스탯: HP / ATK / DEF / SPD (§2.1).
///
/// 종의 기준 스탯(baseStats)과 개체의 유효 스탯 모두 이 타입으로 표현한다.
@immutable
class Stats {
  const Stats({
    required this.hp,
    required this.atk,
    required this.def,
    required this.spd,
  });

  final int hp;
  final int atk;
  final int def;
  final int spd;

  static const Stats zero = Stats(hp: 0, atk: 0, def: 0, spd: 0);

  /// 배율을 곱해 반올림한 새 Stats. (사이즈 배율 등 적용에 사용)
  Stats scaled(double m) => Stats(
    hp: (hp * m).round(),
    atk: (atk * m).round(),
    def: (def * m).round(),
    spd: (spd * m).round(),
  );

  Stats operator +(Stats o) => Stats(
    hp: hp + o.hp,
    atk: atk + o.atk,
    def: def + o.def,
    spd: spd + o.spd,
  );

  Stats copyWith({int? hp, int? atk, int? def, int? spd}) => Stats(
    hp: hp ?? this.hp,
    atk: atk ?? this.atk,
    def: def ?? this.def,
    spd: spd ?? this.spd,
  );

  factory Stats.fromJson(Map<String, dynamic> json) => Stats(
    hp: (json['hp'] as num).toInt(),
    atk: (json['atk'] as num).toInt(),
    def: (json['def'] as num).toInt(),
    spd: (json['spd'] as num).toInt(),
  );

  Map<String, dynamic> toJson() => {
    'hp': hp,
    'atk': atk,
    'def': def,
    'spd': spd,
  };

  @override
  bool operator ==(Object other) =>
      other is Stats &&
      other.hp == hp &&
      other.atk == atk &&
      other.def == def &&
      other.spd == spd;

  @override
  int get hashCode => Object.hash(hp, atk, def, spd);

  @override
  String toString() => 'Stats(hp: $hp, atk: $atk, def: $def, spd: $spd)';
}
