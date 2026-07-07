import 'dart:math';

import 'package:meta/meta.dart';

import 'enums.dart';
import 'game_rules.dart';
import 'part_levels.dart';
import 'size_roll.dart';
import 'species.dart';
import 'stats.dart';

/// 채집·브리딩으로 얻은 **개체**. 종(Species) × 개체 변수 (§2.1).
///
/// 종 정보는 [speciesId] 로만 참조한다(모델은 종 테이블을 들고 있지 않음).
/// 유효 스탯 계산 등 종이 필요한 연산은 [Species] 를 인자로 받는다.
@immutable
class IndividualBug {
  const IndividualBug({
    required this.id,
    required this.speciesId,
    required this.sizeMm,
    required this.potential,
    required this.temperament,
    required this.sex,
    this.enhancement = PartLevels.zero,
  });

  /// 개체 고유 id (앱 레이어에서 생성해 주입).
  final String id;

  /// 소속 종 id.
  final String speciesId;

  /// 롤된 사이즈(mm).
  final double sizeMm;

  /// 포텐셜 성 (1~5). 강화 상한 = potential × 10.
  final int potential;

  /// 기질 (전투 AI 성향).
  final Temperament temperament;

  /// 성별.
  final Sex sex;

  /// 부위 강화 레벨.
  final PartLevels enhancement;

  /// 강화 상한 레벨 (§2.1).
  int get maxLevel => potential * kLevelsPerPotential;

  /// 이 개체의 사이즈에 대응하는 스탯 배율 (종 사이즈 범위 기준).
  double statMultiplier(Species species) =>
      sizeToStatMultiplier(sizeMm, species.sizeMinMm, species.sizeMaxMm);

  /// 사이즈 배율만 적용한 유효 기본 스탯 (강화 미적용).
  Stats baseEffectiveStats(Species species) =>
      species.baseStats.scaled(statMultiplier(species));

  /// 채집/조우 시 개체 하나를 롤한다.
  ///
  /// - 사이즈: 종 범위 내 정규분포 (§2.1)
  /// - 기질/성별: 미지정 시 균등 롤 (기질 5종 균등, 성별 50/50)
  /// - [potential]: 출현 테이블이 정하는 값이라 **필수 주입** (밸런스를 모델에 박지 않음)
  ///
  /// 결정론: 같은 [rng] 상태 + 같은 인자 → 같은 개체.
  factory IndividualBug.roll({
    required String id,
    required Species species,
    required Random rng,
    required int potential,
    Temperament? temperament,
    Sex? sex,
  }) {
    assert(
      potential >= kPotentialMin && potential <= kPotentialMax,
      'potential must be in [$kPotentialMin, $kPotentialMax], got $potential',
    );
    final size = rollSizeMm(rng, species.sizeMinMm, species.sizeMaxMm);
    final temp =
        temperament ??
        Temperament.values[rng.nextInt(Temperament.values.length)];
    final resolvedSex = sex ?? (rng.nextBool() ? Sex.male : Sex.female);
    return IndividualBug(
      id: id,
      speciesId: species.id,
      sizeMm: size,
      potential: potential,
      temperament: temp,
      sex: resolvedSex,
    );
  }

  IndividualBug copyWith({
    String? id,
    String? speciesId,
    double? sizeMm,
    int? potential,
    Temperament? temperament,
    Sex? sex,
    PartLevels? enhancement,
  }) => IndividualBug(
    id: id ?? this.id,
    speciesId: speciesId ?? this.speciesId,
    sizeMm: sizeMm ?? this.sizeMm,
    potential: potential ?? this.potential,
    temperament: temperament ?? this.temperament,
    sex: sex ?? this.sex,
    enhancement: enhancement ?? this.enhancement,
  );

  factory IndividualBug.fromJson(Map<String, dynamic> json) => IndividualBug(
    id: json['id'] as String,
    speciesId: json['speciesId'] as String,
    sizeMm: (json['sizeMm'] as num).toDouble(),
    potential: (json['potential'] as num).toInt(),
    temperament: Temperament.fromKey(json['temperament'] as String),
    sex: Sex.fromKey(json['sex'] as String),
    enhancement: json['enhancement'] == null
        ? PartLevels.zero
        : PartLevels.fromJson(json['enhancement'] as Map<String, dynamic>),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'speciesId': speciesId,
    'sizeMm': sizeMm,
    'potential': potential,
    'temperament': temperament.key,
    'sex': sex.key,
    'enhancement': enhancement.toJson(),
  };

  @override
  bool operator ==(Object other) => other is IndividualBug && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'IndividualBug($id, $speciesId, ${sizeMm.toStringAsFixed(1)}mm, '
      'P$potential, ${temperament.key}, ${sex.key})';
}
