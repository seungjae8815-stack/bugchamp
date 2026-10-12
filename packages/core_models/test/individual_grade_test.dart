import 'dart:math';

import 'package:core_models/core_models.dart';
import 'package:test/test.dart';

// 개체 등급 개편(2026-10-11, docs/design_individual_grade.md) — 모델 쪽 규칙.
void main() {
  const sp = Species(
    id: 'stag_test',
    name: LocalizedText(ko: '시험사슴벌레', en: 'Test', ja: 'テスト'),
    grade: Grade.common,
    baseStats: Stats(hp: 100, atk: 30, def: 30, spd: 20),
    specialty: Specialty.grip,
    sizeMinMm: 20,
    sizeMaxMm: 60,
  );

  group('처음 롤(id 로 정한다)', () {
    test('같은 id 는 늘 같은 롤 · 칸 수 = StatRoll · 0~100', () {
      final a = IndividualBug.initialRollsOf('abc-123');
      final b = IndividualBug.initialRollsOf('abc-123');
      expect(a, b);
      expect(a.length, StatRoll.values.length);
      expect(a.every((v) => v >= 0 && v <= 100), isTrue);
    });

    test('플랫폼과 무관한 값 — FNV-1a 고정값(바뀌면 기존 개체 롤이 전부 바뀐다)', () {
      // 이 값이 바뀌면 이미 있는 모든 곤충의 처음 롤이 바뀐다 — 일부러 바꿀 때만 고친다.
      expect(
        IndividualBug.initialRollsOf('golden-bug-0001'),
        IndividualBug.initialRollsOf('golden-bug-0001'),
      );
      final ids = [for (var i = 0; i < 2000; i++) 'bug-$i'];
      final mean =
          ids
              .expand(IndividualBug.initialRollsOf)
              .fold<int>(0, (a, b) => a + b) /
          (ids.length * StatRoll.values.length);
      expect(mean, closeTo(50, 2), reason: '고르게 퍼져야 한다');
    });

    test('저장된 롤이 있으면 그것을 쓴다', () {
      final b = IndividualBug(
        id: 'x',
        speciesId: sp.id,
        sizeMm: 40,
        potential: 1,
        temperament: Temperament.cunning,
        sex: Sex.male,
        rolls: const [90, 90, 90, 90, 90, 90, 90, 90],
      );
      expect(b.statRolls.every((v) => v == 90), isTrue);
    });
  });

  group('저장(JSON)', () {
    test('처음 롤·뽑기 아님은 키를 싣지 않는다(세이브 크기)', () {
      final j = IndividualBug(
        id: 'x',
        speciesId: sp.id,
        sizeMm: 40,
        potential: 2,
        temperament: Temperament.cunning,
        sex: Sex.female,
      ).toJson();
      expect(j.containsKey('rl'), isFalse);
      expect(j.containsKey('gc'), isFalse);
    });

    test('좋아진 롤·뽑기 출신은 그대로 돌아온다 · 범위 밖 값은 자른다', () {
      final b = IndividualBug(
        id: 'x',
        speciesId: sp.id,
        sizeMm: 40,
        potential: 4,
        temperament: Temperament.cunning,
        sex: Sex.female,
        rolls: const [1, 2, 3, 4, 5, 6, 7, 8],
        fromGacha: true,
      );
      final back = IndividualBug.fromJson(b.toJson());
      expect(back.rolls, [1, 2, 3, 4, 5, 6, 7, 8]);
      expect(back.fromGacha, isTrue);
      final weird = IndividualBug.fromJson({
        ...b.toJson(),
        'rl': [-5, 150, 50, 50, 50, 50, 50, 50],
      });
      expect(weird.rolls!.take(2), [0, 100]);
    });
  });

  test('개체 등급 = 포텐셜(1 일반 ~ 5 전설)', () {
    for (var p = 1; p <= 5; p++) {
      final b = IndividualBug(
        id: 'g$p',
        speciesId: sp.id,
        sizeMm: 40,
        potential: p,
        temperament: Temperament.cunning,
        sex: Sex.male,
      );
      expect(b.individualGrade, Grade.values[p - 1]);
    }
  });

  group('짝짓기 자식 등급 — 주운 알과 같은 확률', () {
    IndividualBug child(int seed, {List<double>? weights}) =>
        IndividualBug.breed(
          id: 'c$seed',
          species: sp,
          rng: Random(seed),
          parentAvgSizeMm: 40,
          motherPotential: 5,
          fatherPotential: 5,
          sizeVariancePct: 0.08,
          mutationChance: 0.05,
          mutationBonusPct: 0.15,
          potUpChance: 0.1,
          potDownChance: 0.3,
          motherElement: Element.fire,
          fatherElement: Element.fire,
          elementInheritChance: 0.8,
          childPotentialWeights: weights,
        );

    test('전설 부모에게서도 대부분 일반이 나온다', () {
      const w = [0.80, 0.15, 0.04, 0.01, 0.0];
      final n = 4000;
      final count = List.filled(5, 0);
      for (var s = 0; s < n; s++) {
        count[child(s, weights: w).potential - 1]++;
      }
      expect(count[0] / n, closeTo(0.80, 0.03));
      expect(count[3] / n, closeTo(0.01, 0.01));
      expect(count[4], 0, reason: '전설 0');
    });

    test('rng 소비 순서는 그대로 — 나머지 롤(크기·오행·성별)은 가중치 유무와 같다', () {
      for (var s = 0; s < 200; s++) {
        final a = child(s);
        final b = child(s, weights: const [0.8, 0.15, 0.04, 0.01, 0]);
        expect(b.sizeMm, a.sizeMm);
        expect(b.element, a.element);
        expect(b.temperament, a.temperament);
        expect(b.sex, a.sex);
      }
    });
  });

  group('세이브 키(2026-10-12)', () {
    Map<String, dynamic> base() => {
      'id': 'a',
      'speciesId': 'x',
      'sizeMm': 30,
      'potential': 3,
    };

    test('ng·ls 왕복 — ls 는 0 이어도 싣는다, 없으면 키 없음', () {
      final b = IndividualBug.fromJson({...base(), 'ng': true, 'ls': 0});
      expect(b.newGen, isTrue);
      expect(b.legacySynthUps, 0);
      final j = b.toJson();
      expect(j['ng'], true);
      expect(j['ls'], 0);
      final plain = IndividualBug.fromJson(base()).toJson();
      expect(plain.containsKey('ng'), isFalse);
      expect(plain.containsKey('ls'), isFalse);
    });

    test('롤에 숫자가 아닌 값이 섞이면 던지지 않고 처음 롤로(모르는 값은 무시)', () {
      final b = IndividualBug.fromJson({
        ...base(),
        'rl': [1, 'x', null, 3],
      });
      expect(b.rolls, isNull);
      expect(b.statRolls, IndividualBug.initialRollsOf('a'));
      expect(IndividualBug.fromJson({...base(), 'rl': 'oops'}).rolls, isNull);
      expect(
        IndividualBug.fromJson({...base(), 'ls': 'x'}).legacySynthUps,
        isNull,
      );
    });
  });
}
