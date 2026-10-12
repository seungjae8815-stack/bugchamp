import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:test/test.dart';

// 개체 등급 개편(2026-10-11, docs/design_individual_grade.md) — 계산 규칙.
void main() {
  final pets = PetConfig.fromJson(
    jsonDecode(File('../app/assets/data/pets.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  final g = pets.individualGrade;

  IndividualBug bug(
    int pot, {
    LifeStage stage = LifeStage.larva,
    bool gacha = false,
  }) => IndividualBug(
    id: 'b$pot$stage$gacha',
    speciesId: 'x',
    sizeMm: 30,
    potential: pot,
    temperament: Temperament.cunning,
    sex: Sex.male,
    stage: stage,
    fromGacha: gacha,
  );

  test('실데이터 — 확정 값(설계 표)', () {
    expect(g.statMult, [1.0, 1.1, 1.22, 1.36, 1.52]);
    expect(g.essenceCosts, [6, 6, 6, 10]);
    expect(g.wildWeights.last, 0, reason: '야생 전설 0');
    expect(g.gachaGradeWeights.last, 0.03);
    expect(g.potionMaxPerUse, 3);
    expect(g.potionJelly % 5, 0, reason: '젤리 가격은 5 단위(§2.6)');
  });

  test('정수 — 등급 누적 · 올리기 비용 · 전설 = 2,160', () {
    expect(
      [for (var p = 1; p <= 5; p++) g.cumulative(p)],
      [1, 6, 36, 216, 2160],
    );
    expect(g.upgradeCost(1), 5);
    expect(g.upgradeCost(4), 2160 - 216);
    expect(g.upgradeCost(5), 0);
  });

  test('정수로 바꾸기 — 알은 0 · 뽑기 출신은 희귀도 가치 없음', () {
    expect(g.essenceOf(bug(3, stage: LifeStage.egg), Grade.legendary), 0);
    expect(g.essenceOf(bug(1), Grade.common), 1);
    expect(g.essenceOf(bug(2), Grade.legendary), (6 * 28).round());
    expect(g.essenceOf(bug(2, gacha: true), Grade.legendary), 6);
  });

  test('올리고 바꾸기를 반복해도 정수가 늘지 않는다(올린 몫은 들인 만큼만)', () {
    for (final grade in Grade.values) {
      for (var p = 1; p < 5; p++) {
        final before = bug(p).copyWith(id: 'loop');
        final after = before.copyWith(
          potential: p + 1,
          synthUps: before.synthUps + 1,
        );
        expect(
          g.essenceOf(after, grade) - g.essenceOf(before, grade),
          g.upgradeCost(p),
          reason: '${grade.key} $p→${p + 1}',
        );
      }
    }
  });

  test('등급 배율 — 전설 = 1(지금 다 키운 5★), 아래는 비율', () {
    expect(g.statMultOf(5), 1.0);
    expect(g.statMultOf(1), closeTo(1 / 1.52, 1e-9));
  });

  test('롤 → 배율·타고난 값', () {
    expect(g.rollFactor(50), 1.0);
    expect(g.rollFactor(100), closeTo(1.1, 1e-9));
    expect(g.rollFactor(0), closeTo(0.9, 1e-9));
    expect(g.innate(StatRoll.crit, 100), closeTo(0.04, 1e-9));
    expect(g.pushFactor(50), 1.0);
  });

  test('등급 올리기 롤 — 내려가지 않고, 물약이 바닥을 올린다', () {
    final rng = Random(7);
    const old = [10, 50, 90, 0, 100, 30, 70, 60];
    for (var i = 0; i < 500; i++) {
      final up = g.rollUp(old, rng, 3);
      for (var k = 0; k < old.length; k++) {
        expect(up[k], greaterThanOrEqualTo(old[k]));
        expect(up[k], greaterThanOrEqualTo(15), reason: '물약 3개 = 바닥 15');
        expect(up[k], lessThanOrEqualTo(100));
      }
    }
    // 물약은 한 번에 최대 3개까지만 효과가 있다.
    final a = g.rollUp(const [0, 0, 0, 0, 0, 0, 0, 0], Random(1), 9);
    expect(a.every((v) => v >= 15), isTrue);
  });

  test('등급 고르기 — 야생 확률', () {
    final rng = Random(3);
    final n = 20000;
    final c = List.filled(5, 0);
    for (var i = 0; i < n; i++) {
      c[IndividualGradeConfig.pick(g.wildWeights, rng) - 1]++;
    }
    expect(c[0] / n, closeTo(0.80, 0.02));
    expect(c[4], 0);
  });

  test('설정이 없으면 꺼짐(옛 규칙)', () {
    expect(IndividualGradeConfig.fromJson(null).enabled, isFalse);
  });

  group('결투 보정(battleMods)', () {
    const sp = Species(
      id: 'x',
      name: LocalizedText(ko: 'x', en: 'x', ja: 'x'),
      grade: Grade.common,
      specialty: Specialty.grip,
      baseStats: Stats(hp: 100, atk: 30, def: 30, spd: 20),
      sizeMinMm: 20,
      sizeMaxMm: 60,
      gradeScale: 2.0,
    );
    IndividualBug mid(int pot) => IndividualBug(
      id: 'm',
      speciesId: 'x',
      sizeMm: 40,
      potential: pot,
      temperament: Temperament.cunning,
      sex: Sex.male,
      rolls: const [50, 50, 50, 50, 50, 50, 50, 50],
    );

    test('꺼져 있으면 중립 — 지금 결투와 똑같다', () {
      final m = const IndividualGradeConfig().battleMods(mid(1), sp);
      expect([m.hp, m.atk, m.def, m.spd, m.push], [1, 1, 1, 1, 1]);
      expect([m.crit, m.evade, m.recovery], [0, 0, 0]);
    });

    test('켜면 등급 배율 × 종 배율 × 롤(가운데 = 1)', () {
      final on = IndividualGradeConfig(enabled: true, innateMax: g.innateMax);
      final legend = on.battleMods(mid(5), sp);
      expect(legend.hp, closeTo(2.0, 1e-9), reason: '전설 1 × 종 2');
      final common = on.battleMods(mid(1), sp);
      expect(common.atk, closeTo(2.0 / 1.52, 1e-9));
      expect(common.spd, 1.0, reason: '속도는 등급·종 배율을 받지 않는다');
      expect(common.crit, closeTo(0.02, 1e-9), reason: '롤 50 = 최대 4% 의 절반');
    });
  });

  test('실데이터 검사 — 종 배율 · 희귀도 가치 · 타고난 능력치 키(오타는 조용히 빠진다)', () {
    final raw = jsonDecode(
      File('../app/assets/data/species.json').readAsStringSync(),
    );
    final list = (raw is List ? raw : (raw as Map)['species']) as List;
    for (final j in list) {
      final m = j as Map<String, dynamic>;
      expect(m.containsKey('gradeScale'), isTrue, reason: '${m['id']} 종 배율 없음');
      final sp = Species.fromJson(m);
      expect(sp.gradeScale, inInclusiveRange(0.5, 4.0), reason: sp.id);
    }
    for (final grade in Grade.values) {
      expect(g.essenceRarity.containsKey(grade), isTrue, reason: grade.key);
    }
    final keys = {for (final r in StatRoll.values) r.key};
    for (final k in g.innateMax.keys) {
      expect(keys.contains(k), isTrue, reason: '모르는 키 $k');
    }
    expect(g.statMult.length, 5);
    expect(g.wildWeights.length, 5);
    expect(g.gachaGradeWeights.length, 5);
  });
}
