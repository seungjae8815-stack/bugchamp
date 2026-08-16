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

  group('짝짓기 상속 — 오행·기질·혈통 특성 (§2.5)', () {
    IndividualBug breed(
      Random rng, {
      Element? momEl,
      Element? dadEl,
      Temperament? momTemp,
      Temperament? dadTemp,
      BugTrait momTrait = BugTrait.none,
      BugTrait dadTrait = BugTrait.none,
      double elIn = 0,
      double tempIn = 0,
      double traitIn = 0,
      double traitNew = 0,
      Map<BugTrait, double> weights = const {},
    }) => IndividualBug.breed(
      id: 'egg',
      species: _species,
      rng: rng,
      parentAvgSizeMm: 50,
      motherPotential: 3,
      fatherPotential: 3,
      sizeVariancePct: 0.08,
      mutationChance: 0,
      mutationBonusPct: 0.15,
      potUpChance: 0.1,
      potDownChance: 0.3,
      motherElement: momEl,
      fatherElement: dadEl,
      motherTemperament: momTemp,
      fatherTemperament: dadTemp,
      motherTrait: momTrait,
      fatherTrait: dadTrait,
      elementInheritChance: elIn,
      temperamentInheritChance: tempIn,
      traitInheritChance: traitIn,
      traitNewChance: traitNew,
      traitWeights: weights,
    );

    test('부모가 같은 오행이면 자식도 그 오행 — 계통 육성의 근거', () {
      // 확률 1.0 이면 어느 부모를 고르든 결과가 같다.
      final rng = Random(3);
      for (var i = 0; i < 200; i++) {
        final e = breed(
          rng,
          momEl: Element.fire,
          dadEl: Element.fire,
          elIn: 1.0,
        );
        expect(e.element, Element.fire);
      }
    });

    test('부모 오행이 다르면 둘 중 하나 — 제3의 값이 나오지 않는다', () {
      final rng = Random(5);
      for (var i = 0; i < 300; i++) {
        final e = breed(
          rng,
          momEl: Element.water,
          dadEl: Element.metal,
          elIn: 1.0,
        );
        expect(e.element, anyOf(Element.water, Element.metal));
      }
    });

    test('기질도 같은 규칙으로 상속된다', () {
      final rng = Random(11);
      for (var i = 0; i < 200; i++) {
        final e = breed(
          rng,
          momTemp: Temperament.cunning,
          dadTemp: Temperament.cunning,
          tempIn: 1.0,
        );
        expect(e.temperament, Temperament.cunning);
      }
    });

    test('상속 확률 0(= 구버전 JSON)이면 예전처럼 랜덤 — 한 값에 고정되지 않는다', () {
      final rng = Random(13);
      final seen = <Element>{};
      for (var i = 0; i < 300; i++) {
        seen.add(breed(rng, momEl: Element.fire, dadEl: Element.fire).element);
      }
      expect(seen.length, greaterThan(1));
    });

    test('부모 값이 없으면(구버전 슬롯) 상속을 건너뛰고 랜덤 — 수령이 깨지지 않는다', () {
      final rng = Random(17);
      final seen = <Element>{};
      for (var i = 0; i < 300; i++) {
        seen.add(breed(rng, elIn: 1.0).element); // 부모 오행 null
      }
      expect(seen.length, greaterThan(1));
    });

    test('부모가 같은 특성이면 자식도 그 특성(확률 1.0)', () {
      final rng = Random(19);
      for (var i = 0; i < 200; i++) {
        final e = breed(
          rng,
          momTrait: BugTrait.noble,
          dadTrait: BugTrait.noble,
          traitIn: 1.0,
        );
        expect(e.trait, BugTrait.noble);
      }
    });

    test('부모 한쪽만 특성이 있으면 그 특성이거나 없음 — 다른 특성은 안 나온다', () {
      final rng = Random(23);
      for (var i = 0; i < 300; i++) {
        final e = breed(rng, momTrait: BugTrait.fierce, traitIn: 0.5);
        expect(e.trait, anyOf(BugTrait.fierce, BugTrait.none));
      }
    });

    test('부모가 둘 다 특성이 없으면 신규 특성 확률로만 열린다(1세대 진입로)', () {
      final rng = Random(29);
      // 신규 확률 0 → 절대 안 열린다.
      for (var i = 0; i < 200; i++) {
        expect(
          breed(rng, traitNew: 0, weights: {BugTrait.vital: 1}).trait,
          BugTrait.none,
        );
      }
      // 신규 확률 1 + 가중치 1종 → 그 특성으로 확정.
      for (var i = 0; i < 200; i++) {
        expect(
          breed(rng, traitNew: 1.0, weights: {BugTrait.vital: 1}).trait,
          BugTrait.vital,
        );
      }
    });

    test('가중치가 비어 있으면 특성이 열리지 않는다(JSON 미설정 안전)', () {
      final rng = Random(31);
      expect(breed(rng, traitNew: 1.0).trait, BugTrait.none);
    });

    test('야생 롤은 항상 특성 없음 — 특성은 짝짓기의 표식이다', () {
      final rng = Random(37);
      for (var i = 0; i < 200; i++) {
        final b = IndividualBug.roll(
          id: 'w$i',
          species: _species,
          rng: rng,
          potential: 3,
        );
        expect(b.trait, BugTrait.none);
      }
    });

    test('결정론: 같은 seed+인자 → 같은 오행·기질·특성', () {
      IndividualBug make() => breed(
        Random(101),
        momEl: Element.wood,
        dadEl: Element.earth,
        momTemp: Temperament.fickle,
        dadTemp: Temperament.steadfast,
        momTrait: BugTrait.fierce,
        dadTrait: BugTrait.sturdy,
        elIn: 0.8,
        tempIn: 0.65,
        traitIn: 0.55,
        traitNew: 0.2,
        weights: {BugTrait.vital: 1, BugTrait.noble: 1},
      );
      final a = make();
      final b = make();
      expect(a.element, b.element);
      expect(a.temperament, b.temperament);
      expect(a.trait, b.trait);
      expect(a.sizeMm, b.sizeMm);
    });

    test('특성은 JSON 왕복에서 보존되고, 없으면 키를 싣지 않는다(세이브 크기)', () {
      final withTrait = breed(
        Random(3),
        momTrait: BugTrait.noble,
        dadTrait: BugTrait.noble,
        traitIn: 1.0,
      );
      expect(withTrait.toJson()['trait'], 'noble');
      expect(IndividualBug.fromJson(withTrait.toJson()).trait, BugTrait.noble);

      final plain = breed(Random(3));
      expect(plain.toJson().containsKey('trait'), isFalse);
      expect(IndividualBug.fromJson(plain.toJson()).trait, BugTrait.none);
    });

    test('모르는 특성 키는 none 으로 떨어진다 — 구버전 앱이 세이브를 읽어야 한다', () {
      final json = breed(Random(3)).toJson()..['trait'] = 'from_the_future';
      expect(IndividualBug.fromJson(json).trait, BugTrait.none);
    });
  });
}
