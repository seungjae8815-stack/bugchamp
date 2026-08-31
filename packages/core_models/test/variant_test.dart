import 'dart:math';

import 'package:core_models/core_models.dart';
import 'package:test/test.dart';

/// 이색 개체(§2.1) — 순수 외형 변이. 여기서 지키는 것 셋:
/// ① 확률 0 이면 절대 안 나온다(기존 세이브·기존 롤과 완전 동일).
/// ② 확률 1 이면 반드시 나온다.
/// ③ **이색 롤이 기존 롤 결과를 바꾸지 않는다** — rng 소비를 맨 뒤에 붙였는지.
///    바꾸면 같은 seed 의 브리딩 슬롯 결과가 통째로 달라진다(§2.5 경고).
void main() {
  final species = Species(
    id: 'test_bug',
    name: const LocalizedText(ko: '시험벌레', en: 'Test Bug', ja: 'テスト虫'),
    grade: Grade.common,
    specialty: Specialty.strike,
    baseStats: const Stats(hp: 10, atk: 10, def: 10, spd: 10),
    sizeMinMm: 10,
    sizeMaxMm: 20,
  );

  test('확률 0 → 이색 없음, 확률 1 → 반드시 이색', () {
    final a = IndividualBug.roll(
      id: 'a',
      species: species,
      rng: Random(7),
      potential: 3,
    );
    expect(a.variant, BugVariant.none);
    final b = IndividualBug.roll(
      id: 'b',
      species: species,
      rng: Random(7),
      potential: 3,
      variantChance: 1,
    );
    expect(b.variant, isNot(BugVariant.none));
  });

  test('이색 롤이 기존 롤 결과를 바꾸지 않는다(맨 뒤 소비)', () {
    IndividualBug at(double chance) => IndividualBug.roll(
      id: 'x',
      species: species,
      rng: Random(42),
      potential: 2,
      variantChance: chance,
    );
    final off = at(0);
    final on = at(1);
    expect(on.sizeMm, off.sizeMm);
    expect(on.temperament, off.temperament);
    expect(on.sex, off.sex);
    expect(on.element, off.element);
  });

  test('브리딩도 같은 규칙 — 이색 확률이 기존 자식을 바꾸지 않는다', () {
    IndividualBug at(double chance) => IndividualBug.breed(
      id: 'c',
      species: species,
      rng: Random(99),
      parentAvgSizeMm: 15,
      motherPotential: 3,
      fatherPotential: 3,
      sizeVariancePct: 0.05,
      mutationChance: 0.05,
      mutationBonusPct: 0.1,
      potUpChance: 0.1,
      potDownChance: 0.3,
      variantChance: chance,
    );
    final off = at(0);
    final on = at(1);
    expect(on.sizeMm, off.sizeMm);
    expect(on.potential, off.potential);
    expect(on.element, off.element);
    expect(on.temperament, off.temperament);
    expect(on.sex, off.sex);
    expect(off.variant, BugVariant.none);
    expect(on.variant, isNot(BugVariant.none));
  });

  test('json 왕복 — 이색 아닌 개체는 키를 싣지 않는다(세이브 크기)', () {
    final plain = IndividualBug.roll(
      id: 'p',
      species: species,
      rng: Random(1),
      potential: 1,
    );
    expect(plain.toJson().containsKey('variant'), isFalse);
    final v = plain.copyWith(variant: BugVariant.rainbow);
    final back = IndividualBug.fromJson(v.toJson());
    expect(back.variant, BugVariant.rainbow);
    // 구버전 호환 — 모르는 키는 none 으로.
    final j = v.toJson()..['variant'] = 'future_variant';
    expect(IndividualBug.fromJson(j).variant, BugVariant.none);
  });

  test('한정 종 — 기간 밖이면 드롭 풀에서 빠진다', () {
    final limited = Species.fromJson({
      ...species.toJson(),
      'id': 'limited_bug',
      'from': '2026-09-01T00:00:00Z',
      'until': '2026-09-08T00:00:00Z',
    });
    expect(limited.availableAt(DateTime.utc(2026, 8, 31)), isFalse);
    expect(limited.availableAt(DateTime.utc(2026, 9, 3)), isTrue);
    expect(limited.availableAt(DateTime.utc(2026, 9, 8)), isFalse);
    // 상시 종은 언제나.
    expect(species.availableAt(DateTime.utc(2030)), isTrue);
  });
}
