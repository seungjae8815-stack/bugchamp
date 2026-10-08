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
    this.crit = 0,
    this.recovery = 0,
    this.evade = 0,
    this.massMult = 1,
    this.tech = 0,
    this.grit = 0,
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

  /// 추가 크리티컬 확률(0~1) — 훈련소에서 올린다(설계 대기, 지금은 0).
  final double crit;

  /// 판 사이 추가 회복(최대 체력 비율) — 훈련소에서 올린다(설계 대기, 지금은 0).
  final double recovery;

  /// 회피 확률(0~1) — 부딪힘 피해를 통째로 피한다. 훈련소에서 올린다.
  final double evade;

  /// 체급 칸(훈련 v2, docs/design_training_v2.md) — 무게 배율. 실제 크기(mm)·몸 반경은 그대로.
  final double massMult;

  /// 주특기 기술 칸 — 주특기마다 다른 효과의 비율 보너스(치기 뒤집기 확률 · 집기 무는 힘 · 던지기 쿨타임).
  final double tech;

  /// 근성 칸(단계) — 탭 반격 성공 문턱·효과·횟수.
  final int grit;

  /// 훈련소 보너스를 입힌다(공격·방어 배율, 회피·치명·회복력 가산). 값은 호출자가
  /// `TrainingConfig.bonuses` 로 계산한다 — core_battle 은 core_run 을 모른다.
  DuelBug withTraining({
    double atkMult = 1,
    double defMult = 1,
    double hpMult = 1,
    double evade = 0,
    double crit = 0,
    double recovery = 0,
    double spdMult = 1,
    double massMult = 1,
    double tech = 0,
    int grit = 0,
  }) => DuelBug(
    id: id,
    name: name,
    speciesId: speciesId,
    element: element,
    temperament: temperament,
    specialty: specialty,
    sizeMm: sizeMm,
    maxHp: maxHp * hpMult,
    atk: atk * atkMult,
    def: def * defMult,
    spd: spd * spdMult,
    crit: this.crit + crit,
    recovery: this.recovery + recovery,
    evade: this.evade + evade,
    massMult: this.massMult * massMult,
    tech: this.tech + tech,
    grit: this.grit + grit,
  );

  /// 한 판 안에서만 쓰는 전투 수치로 바꾼다(전력 압축·게이지 보너스, 엔진 내부용).
  DuelBug withCombatStats({
    required double maxHp,
    required double atk,
    required double def,
    double? spd,
  }) => DuelBug(
    id: id,
    name: name,
    speciesId: speciesId,
    element: element,
    temperament: temperament,
    specialty: specialty,
    sizeMm: sizeMm,
    maxHp: maxHp,
    atk: atk,
    def: def,
    spd: spd ?? this.spd,
    crit: crit,
    recovery: recovery,
    evade: evade,
    massMult: massMult,
    tech: tech,
    grit: grit,
  );

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
    crit: crit,
    recovery: recovery,
    evade: evade,
    massMult: massMult,
    tech: tech,
    grit: grit,
  );

  /// 몸 반경.
  double radius(DuelParams p) =>
      (p.radiusBase + sizeMm * p.radiusPerMm).clamp(p.radiusMin, p.radiusMax);

  /// 무게 — 사이즈가 주되, 단단한(DEF) 곤충이 조금 더 무겁게 버틴다.
  double mass(DuelParams p) =>
      math.pow(math.max(sizeMm, 1) / p.sizeRefMm, p.massExp).toDouble() *
      (1 + p.defMassWeight * def / (def + 100)) *
      massMult;

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
    if (crit > 0) 'crit': crit,
    if (recovery > 0) 'rec': recovery,
    if (evade > 0) 'eva': evade,
    if (massMult != 1) 'mm': massMult,
    if (tech != 0) 'tech': tech,
    if (grit != 0) 'grit': grit,
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
    crit: (j['crit'] as num?)?.toDouble() ?? 0,
    recovery: (j['rec'] as num?)?.toDouble() ?? 0,
    evade: (j['eva'] as num?)?.toDouble() ?? 0,
    massMult: (j['mm'] as num?)?.toDouble() ?? 1,
    tech: (j['tech'] as num?)?.toDouble() ?? 0,
    grit: (j['grit'] as num?)?.toInt() ?? 0,
  );
}
