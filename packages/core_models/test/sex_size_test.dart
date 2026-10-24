import 'dart:math';

import 'package:core_models/core_models.dart';
import 'package:test/test.dart';

// 암컷 범위가 있는 종: 수컷 40~92, 암컷 30~50.
const _stag = Species(
  id: 'stag_x',
  name: LocalizedText(ko: '사슴', en: 'Stag', ja: 'クワガタ'),
  grade: Grade.common,
  specialty: Specialty.grip,
  baseStats: Stats(hp: 100, atk: 40, def: 30, spd: 20),
  sizeMinMm: 40,
  sizeMaxMm: 92,
  femaleSizeMinMm: 30,
  femaleSizeMaxMm: 50,
);

// 암컷 범위가 없는 종: 22~38.
const _chafer = Species(
  id: 'chafer_x',
  name: LocalizedText(ko: '꽃무지', en: 'Chafer', ja: 'ハナムグリ'),
  grade: Grade.common,
  specialty: Specialty.strike,
  baseStats: Stats(hp: 100, atk: 40, def: 30, spd: 20),
  sizeMinMm: 22,
  sizeMaxMm: 38,
);

IndividualBug _bug(Species s, {required Sex sex, required double mm}) =>
    IndividualBug(
      id: 'b',
      speciesId: s.id,
      sizeMm: mm,
      potential: 3,
      temperament: Temperament.values.first,
      sex: sex,
      element: Element.values.first,
    );

void main() {
  test('sizeRangeFor: 암컷 범위가 있으면 암컷, 없으면 수컷', () {
    expect(_stag.sizeRangeFor(Sex.female), (min: 30.0, max: 50.0));
    expect(_stag.sizeRangeFor(Sex.male), (min: 40.0, max: 92.0));
    expect(_chafer.sizeRangeFor(Sex.female), (min: 22.0, max: 38.0));
  });

  test('fromJson: 암컷 범위는 둘 다 있어야 유효', () {
    Map<String, dynamic> j(Map<String, dynamic> extra) => {
      ..._stag.toJson(),
      ...extra,
    };
    final both = Species.fromJson(j({}));
    expect(both.femaleSizeMinMm, 30);
    expect(both.femaleSizeMaxMm, 50);
    final onlyMin = Species.fromJson(
      {..._stag.toJson()}..remove('femaleSizeMaxMm'),
    );
    expect(onlyMin.femaleSizeMinMm, isNull);
    expect(onlyMin.femaleSizeMaxMm, isNull);
    expect(_chafer.toJson().containsKey('femaleSizeMinMm'), isFalse);
  });

  test('sizeFracOf·sizeForFrac·maleEquivalentMm: 같은 위치는 수컷 환산이 같다', () {
    final f = _bug(_stag, sex: Sex.female, mm: 40);
    final m = _bug(_stag, sex: Sex.male, mm: 66);
    expect(_stag.sizeFracOf(f), closeTo(0.5, 1e-9));
    expect(_stag.maleEquivalentMm(f), closeTo(66, 1e-9));
    expect(_stag.maleEquivalentMm(m), closeTo(66, 1e-9));
    expect(_stag.remapFromMale(92, Sex.female), closeTo(50, 1e-9));
    expect(_stag.remapFromMale(92, Sex.male), 92);
    expect(_stag.sizeForFrac(Sex.female, 2), 50); // clamp
  });

  test('퇴화 범위(max ≤ min)면 위치 0.5', () {
    const flat = Species(
      id: 'flat',
      name: LocalizedText(ko: 'a', en: 'a', ja: 'a'),
      grade: Grade.common,
      specialty: Specialty.grip,
      baseStats: Stats(hp: 1, atk: 1, def: 1, spd: 1),
      sizeMinMm: 30,
      sizeMaxMm: 30,
    );
    expect(flat.sizeFracOf(_bug(flat, sex: Sex.male, mm: 30)), 0.5);
  });

  test('roll: 암컷은 암컷 범위 안, 같은 seed 의 수컷 결과는 바뀌지 않는다', () {
    final base = rollSizeMm(Random(7), 40, 92);
    final m = IndividualBug.roll(
      id: 'm',
      species: _stag,
      rng: Random(7),
      potential: 3,
      sex: Sex.male,
    );
    expect(m.sizeMm, base);
    final f = IndividualBug.roll(
      id: 'f',
      species: _stag,
      rng: Random(7),
      potential: 3,
      sex: Sex.female,
    );
    expect(f.sizeMm, closeTo(_stag.remapFromMale(base, Sex.female), 1e-9));
    expect(f.sizeMm, inInclusiveRange(30, 50));
  });

  test('breed: 암컷 자식은 암컷 최대를 넘지 않고, 수컷 자식은 수컷 범위', () {
    var females = 0;
    var males = 0;
    for (var seed = 0; seed < 100; seed++) {
      final c = IndividualBug.breed(
        id: 'c$seed',
        species: _stag,
        rng: Random(seed),
        parentAvgSizeMm: 90,
        motherPotential: 3,
        fatherPotential: 3,
        sizeVariancePct: 0,
        mutationChance: 0,
        mutationBonusPct: 0,
        potUpChance: 0,
        potDownChance: 0,
      );
      if (c.sex == Sex.female) {
        females++;
        expect(c.sizeMm, lessThanOrEqualTo(50.001));
        expect(c.sizeMm, greaterThanOrEqualTo(29.999));
      } else {
        males++;
        expect(c.sizeMm, lessThanOrEqualTo(92.001));
      }
    }
    expect(females, greaterThan(0));
    expect(males, greaterThan(0));
  });

  test('statMultiplier·integrityError 는 성별 범위를 쓴다', () {
    expect(
      _bug(_stag, sex: Sex.female, mm: 30).statMultiplier(_stag),
      closeTo(kStatMultiplierMin, 1e-9),
    );
    String? err(IndividualBug b) =>
        b.integrityError(_stag, levelCap: 50, maxBreakthroughTier: 4);
    expect(err(_bug(_stag, sex: Sex.female, mm: 55)), 'size_out_of_range');
    expect(err(_bug(_stag, sex: Sex.male, mm: 55)), isNull);
  });

  test('암컷 범위 없는 종: 모든 함수가 수컷 범위로 떨어진다', () {
    final f = _bug(_chafer, sex: Sex.female, mm: 30);
    expect(_chafer.sizeFracOf(f), closeTo(0.5, 1e-9));
    expect(_chafer.remapFromMale(30, Sex.female), 30);
  });
}
