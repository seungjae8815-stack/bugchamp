import 'dart:math';

import 'package:core_models/core_models.dart';
import 'package:test/test.dart';

const _species = Species(
  id: 'stag_beetle_common',
  name: LocalizedText(ko: '넓적사슴벌레', en: 'Flat Stag Beetle', ja: 'ヒラタクワガタ'),
  grade: Grade.common,
  specialty: Specialty.grip,
  baseStats: Stats(hp: 100, atk: 40, def: 30, spd: 20),
  sizeMinMm: 30,
  sizeMaxMm: 75,
);

void main() {
  group('IndividualBug.roll', () {
    test('사이즈는 종 범위 내, 배율은 0.85~1.20', () {
      final rng = Random(7);
      for (var i = 0; i < 2000; i++) {
        final bug = IndividualBug.roll(
          id: 'b$i',
          species: _species,
          rng: rng,
          potential: 3,
        );
        expect(
          bug.sizeMm,
          inInclusiveRange(_species.sizeMinMm, _species.sizeMaxMm),
        );
        expect(
          bug.statMultiplier(_species),
          inInclusiveRange(kStatMultiplierMin, kStatMultiplierMax),
        );
        expect(bug.speciesId, _species.id);
      }
    });

    test('결정론: 같은 seed → 동일 개체', () {
      IndividualBug make(int seed) => IndividualBug.roll(
        id: 'x',
        species: _species,
        rng: Random(seed),
        potential: 4,
      );
      final a = make(999);
      final b = make(999);
      expect(a.sizeMm, b.sizeMm);
      expect(a.temperament, b.temperament);
      expect(a.sex, b.sex);
      expect(a.toJson(), b.toJson());
    });

    test('maxLevel = 포텐셜 × 10', () {
      for (var p = kPotentialMin; p <= kPotentialMax; p++) {
        final bug = IndividualBug.roll(
          id: 'p$p',
          species: _species,
          rng: Random(p),
          potential: p,
        );
        expect(bug.maxLevel, p * kLevelsPerPotential);
      }
    });

    test('기질/성별 명시 주입 시 그대로 사용', () {
      final bug = IndividualBug.roll(
        id: 'fixed',
        species: _species,
        rng: Random(1),
        potential: 2,
        temperament: Temperament.cunning,
        sex: Sex.female,
      );
      expect(bug.temperament, Temperament.cunning);
      expect(bug.sex, Sex.female);
    });
  });

  group('유효 스탯', () {
    test('최소 사이즈 개체는 base×0.85, 최대 사이즈는 base×1.20 (반올림)', () {
      final minBug = IndividualBug.roll(
        id: 'min',
        species: _species,
        rng: Random(1),
        potential: 1,
      ).copyWith(sizeMm: _species.sizeMinMm);
      final maxBug = minBug.copyWith(sizeMm: _species.sizeMaxMm);

      expect(
        minBug.baseEffectiveStats(_species),
        _species.baseStats.scaled(kStatMultiplierMin),
      );
      expect(
        maxBug.baseEffectiveStats(_species),
        _species.baseStats.scaled(kStatMultiplierMax),
      );

      // 구체 수치: hp 100 → 85 / 120
      expect(minBug.baseEffectiveStats(_species).hp, 85);
      expect(maxBug.baseEffectiveStats(_species).hp, 120);
    });
  });

  group('직렬화', () {
    test('toJson → fromJson 왕복 동일', () {
      final bug = IndividualBug.roll(
        id: 'rt',
        species: _species,
        rng: Random(5),
        potential: 5,
      ).copyWith(enhancement: const PartLevels(hornJaw: 2, wing: 1));
      final restored = IndividualBug.fromJson(bug.toJson());
      expect(restored.id, bug.id);
      expect(restored.sizeMm, bug.sizeMm);
      expect(restored.potential, bug.potential);
      expect(restored.temperament, bug.temperament);
      expect(restored.sex, bug.sex);
      expect(restored.enhancement, bug.enhancement);
    });
  });

  group('IndividualBug.breed', () {
    IndividualBug breed(
      Random rng, {
      int mom = 3,
      int dad = 3,
      double up = 0.10,
      double down = 0.30,
      double mut = 0.0,
    }) => IndividualBug.breed(
      id: 'egg',
      species: _species,
      rng: rng,
      parentAvgSizeMm: 50,
      motherPotential: mom,
      fatherPotential: dad,
      sizeVariancePct: 0.08,
      mutationChance: mut,
      mutationBonusPct: 0.15,
      potUpChance: up,
      potDownChance: down,
    );

    test('자식은 알 단계 · 사이즈 종범위 내 · 포텐셜 1~5', () {
      final rng = Random(1);
      for (var i = 0; i < 500; i++) {
        final e = breed(rng);
        expect(e.stage, LifeStage.egg);
        expect(
          e.sizeMm,
          inInclusiveRange(_species.sizeMinMm, _species.sizeMaxMm),
        );
        expect(e.potential, inInclusiveRange(1, 5));
      }
    });

    test('결정론: 같은 seed+인자 → 같은 자식', () {
      final a = breed(Random(42));
      final b = breed(Random(42));
      expect(a.sizeMm, b.sizeMm);
      expect(a.potential, b.potential);
      expect(a.element, b.element);
      expect(a.sex, b.sex);
      expect(a.temperament, b.temperament);
    });

    test('포텐셜 상속: 높은 부모 기준 상승/하락/유지(+clamp)', () {
      // 상승(+1), 5 clamp
      expect(breed(Random(1), mom: 2, dad: 4, up: 1.0, down: 0.0).potential, 5);
      expect(breed(Random(1), mom: 5, dad: 5, up: 1.0, down: 0.0).potential, 5);
      // 하락(−1), 1 clamp
      expect(breed(Random(1), mom: 2, dad: 3, up: 0.0, down: 1.0).potential, 2);
      expect(breed(Random(1), mom: 1, dad: 1, up: 0.0, down: 1.0).potential, 1);
      // 유지
      expect(breed(Random(1), mom: 2, dad: 4, up: 0.0, down: 0.0).potential, 4);
    });
  });
}
