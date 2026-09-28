import 'dart:math' as math;

import 'package:core_models/core_models.dart';
import 'package:meta/meta.dart';

import '../core_battle_base.dart';
import 'duel_params.dart';

/// 결투(곤충 배틀 스타디움)에 나서는 곤충 한 마리.
///
/// 스탯(HP/ATK/DEF/SPD)은 옛 엔진과 **같은 계산**(`buildBattleBug`)에서 온다 — 부위 강화·특성·이색이
/// 두 전투에서 같은 값이어야 한다. 여기에 물리에 필요한 **사이즈·주특기**를 더한다.
@immutable
class DuelBug {
  const DuelBug({
    required this.id,
    required this.name,
    required this.speciesId,
    required this.element,
    required this.temperament,
    required this.specialty,
    required this.sizeMm,
    required this.maxHp,
    required this.atk,
    required this.def,
    required this.spd,
  });

  final String id;
  final String name;
  final String speciesId;
  final Element element;
  final Temperament temperament;
  final Specialty specialty;

  /// 개체 사이즈(mm) — **무게·몸 반경**이 된다.
  final double sizeMm;
  final double maxHp;
  final double atk;
  final double def;
  final double spd;

  /// 옛 엔진 유닛에 사이즈·주특기를 붙인다.
  factory DuelBug.fromBattleBug(
    BattleBug b, {
    required String speciesId,
    required double sizeMm,
    required Specialty specialty,
  }) => DuelBug(
    id: b.id,
    name: b.name,
    speciesId: speciesId,
    element: b.element,
    temperament: b.temperament,
    specialty: specialty,
    sizeMm: sizeMm,
    maxHp: b.maxHp,
    atk: b.atk,
    def: b.def,
    spd: b.spd,
  );

  DuelBug copyWith({
    Temperament? temperament,
    Element? element,
    double? sizeMm,
  }) => DuelBug(
    id: id,
    name: name,
    speciesId: speciesId,
    element: element ?? this.element,
    temperament: temperament ?? this.temperament,
    specialty: specialty,
    sizeMm: sizeMm ?? this.sizeMm,
    maxHp: maxHp,
    atk: atk,
    def: def,
    spd: spd,
  );

  /// 몸 반경.
  double radius(DuelParams p) =>
      (p.radiusBase + sizeMm * p.radiusPerMm).clamp(p.radiusMin, p.radiusMax);

  /// 무게 — 사이즈가 주되, 단단한(DEF) 곤충이 조금 더 무겁게 버틴다.
  double mass(DuelParams p) =>
      math.pow(math.max(sizeMm, 1) / p.sizeRefMm, p.massExp).toDouble() *
      (1 + p.defMassWeight * def / (def + 100));

  /// 평소 최고 속도.
  double maxSpeed(DuelParams p) =>
      math.min(p.speedCap, p.speedBase + spd * p.speedPerSpd);

  /// 스카우트·야생 상대 규모를 맞추는 대략적 전력(표시·매칭용, 판정에는 안 쓴다).
  double get power => maxHp * 0.15 + atk + def + spd;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'sp': speciesId,
    'el': element.key,
    'tm': temperament.key,
    'spc': specialty.key,
    'size': sizeMm,
    'hp': maxHp,
    'atk': atk,
    'def': def,
    'spd': spd,
  };

  factory DuelBug.fromJson(Map<String, dynamic> j) => DuelBug(
    id: '${j['id']}',
    name: '${j['name'] ?? ''}',
    speciesId: '${j['sp'] ?? ''}',
    element: Element.fromKey('${j['el']}'),
    temperament: Temperament.fromKey('${j['tm']}'),
    specialty: Specialty.fromKey('${j['spc']}'),
    sizeMm: (j['size'] as num).toDouble(),
    maxHp: (j['hp'] as num).toDouble(),
    atk: (j['atk'] as num).toDouble(),
    def: (j['def'] as num).toDouble(),
    spd: (j['spd'] as num).toDouble(),
  );
}
