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
    bool newGen = true,
    int su = 0,
  }) => IndividualBug(
    id: 'b$pot$stage$gacha',
    speciesId: 'x',
    sizeMm: 30,
    potential: pot,
    temperament: Temperament.cunning,
    sex: Sex.male,
    stage: stage,
    fromGacha: gacha,
    newGen: newGen,
    synthUps: su,
  );

  /// 앱·서버 `gradeUp` 과 같은 필드 변화(core_save) — 업데이트 전 곤충은 처음 올릴 때 옛 합성 단계를 적는다.
  IndividualBug up(IndividualBug b) => b.copyWith(
    potential: b.potential + 1,
    synthUps: b.synthUps + 1,
    legacySynthUps: !b.newGen && b.legacySynthUps == null ? b.synthUps : null,
  );

  test('실데이터 — 확정 값(설계 표)', () {
    expect(g.statMult, [1.0, 1.1, 1.22, 1.36, 1.52]);
    // 2026-10-14(1.0.21): 야생·짝짓기 100% 일반 + 올리기 4·4·5·6(무료 전설 약 4주 유지).
    expect(g.essenceCosts, [4, 4, 5, 6]);
    expect(g.wildWeights, [1.0, 0.0, 0.0, 0.0, 0.0], reason: '야생은 일반만');
    expect(g.gachaGradeWeights.last, 0.03);
    expect(g.potionMaxPerUse, 3);
    expect(g.potionJelly % 5, 0, reason: '젤리 가격은 5 단위(§2.6)');
  });

  test('정수 — 등급 누적 · 올리기 비용 · 전설 = 480', () {
    expect(
      [for (var p = 1; p <= 5; p++) g.cumulative(p)],
      [1, 4, 16, 80, 480],
    );
    expect(g.upgradeCost(1), 3);
    expect(g.upgradeCost(4), 480 - 80);
    expect(g.upgradeCost(5), 0);
  });

  test('정수로 바꾸기 — 알은 0 · 뽑기 출신은 희귀도 가치 없음', () {
    expect(g.essenceOf(bug(3, stage: LifeStage.egg), Grade.legendary), 0);
    expect(g.essenceOf(bug(1), Grade.common), 1);
    expect(g.essenceOf(bug(2), Grade.legendary), (4 * 28).round());
    expect(g.essenceOf(bug(2, gacha: true), Grade.legendary), 4);
  });

  test('올리고 바꾸기를 반복해도 정수가 늘지 않는다(올린 몫은 들인 만큼만)', () {
    for (final grade in Grade.values) {
      for (final ng in [true, false]) {
        for (final gacha in [true, false]) {
          // 태생 등급 × 옛 합성 단계(업데이트 전 곤충만 의미)마다 전설까지 올려 본다.
          for (var born = 1; born <= 5; born++) {
            for (var su = 0; born + su <= 5; su++) {
              if (ng && su > 0) continue; // 켜진 뒤 생긴 곤충은 옛 합성이 없다
              var b = bug(born + su, gacha: gacha, newGen: ng, su: su);
              while (b.potential < 5) {
                final a = up(b);
                expect(
                  g.essenceOf(a, grade) - g.essenceOf(b, grade),
                  g.upgradeCost(b.potential),
                  reason:
                      '${grade.key} ng=$ng gc=$gacha born=$born su=$su '
                      '${b.potential}→${a.potential}',
                );
                b = a;
              }
            }
          }
        }
      }
    }
  });

  test('업데이트 전 곤충 — 들인 마릿수만큼(희귀도 × (태생 기본 + 3 × 옛 합성 단계))', () {
    // 옛 합성 5★(태생 1·합성 4) = 13 × r.
    expect(g.essenceOf(bug(5, newGen: false, su: 4), Grade.common), 13);
    expect(g.essenceOf(bug(5, newGen: false, su: 4), Grade.legendary), 13 * 28);
    // 옛 태생 5★ 전설 종 = 6 × 28 = 168(새 규칙이면 2,160 × 28 = 60,480 이었다).
    expect(g.essenceOf(bug(5, newGen: false), Grade.legendary), 168);
    expect(g.essenceOf(bug(1, newGen: false), Grade.rare), 3);
    expect(g.essenceOf(bug(2, newGen: false), Grade.common), 3);
    // 옛 합성 5★ 를 새로 올린 적 없이 그대로 바꾸면 위 값 — 올린 뒤엔 들인 정수가 그대로 더해진다.
    final legacy = bug(3, newGen: false, su: 1);
    final once = up(legacy);
    expect(once.legacySynthUps, 1);
    expect(
      g.essenceOf(once, Grade.epic) - g.essenceOf(legacy, Grade.epic),
      g.upgradeCost(3),
    );
    // 옛 합성 단계를 늘려 적으면(위조) 정수는 커질 수 있다 — 서버가 `ls` 를 저장본 합성 단계로 묶는다.
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

  test('등급 올리기 롤 — 내려가지 않고, 물약 1개 = 새 롤 +3점(100 상한)', () {
    expect(g.potionRollBonus, 3);
    final rng = Random(7);
    const old = [10, 50, 90, 0, 100, 30, 70, 60];
    for (var i = 0; i < 500; i++) {
      final up = g.rollUp(old, rng, 3);
      for (var k = 0; k < old.length; k++) {
        expect(up[k], greaterThanOrEqualTo(old[k]));
        expect(up[k], greaterThanOrEqualTo(9), reason: '물약 3개 = +9');
        expect(up[k], lessThanOrEqualTo(100));
      }
    }
    // 물약은 한 번에 최대 3개까지만 효과가 있다 — 9개를 넣어도 +9 와 같은 결과.
    final a = g.rollUp(const [0, 0, 0, 0, 0, 0, 0, 0], Random(1), 9);
    final b = g.rollUp(const [0, 0, 0, 0, 0, 0, 0, 0], Random(1), 3);
    expect(a, b);
    expect(a.every((v) => v >= 9), isTrue);
  });

  test('물약 분포 — 일반에서 전설까지 4번, 매번 3개면 평균 약 97점(없으면 약 84점)', () {
    double mean(int potions) {
      final rng = Random(11);
      var sum = 0.0, n = 0;
      for (var i = 0; i < 4000; i++) {
        var r = IndividualBug.initialRollsOf('bug$i');
        for (var k = 0; k < 4; k++) {
          r = g.rollUp(r, rng, potions);
        }
        for (final v in r) {
          sum += v;
          n++;
        }
      }
      return sum / n;
    }

    // 사장님 확정(2026-10-12): 큰 쪽에 물약 점수를 더한다 — 매번 3개면 평균 약 97점, 없으면 약 84점.
    expect(mean(0), closeTo(84, 1.5));
    expect(mean(3), closeTo(97, 1.5));
  });

  group('뽑기 천장', () {
    test('전설 천장 50 — 49번 전설 없이 뽑았으면 50번째는 전설', () {
      expect(g.gachaLegendPity, 50);
      expect(g.legendPityDue(48), isFalse);
      expect(g.legendPityDue(49), isTrue);
      for (final r in [0.0, 0.5, 0.999]) {
        expect(g.gachaPotential(r, legendPity: true), 5);
      }
    });

    test('영웅 이상 천장 — 영웅·전설만', () {
      for (var i = 0; i < 100; i++) {
        expect(
          g.gachaPotential(i / 100, epicPity: true),
          greaterThanOrEqualTo(4),
        );
      }
    });

    test('평소 — 희귀 이상(설정 확률)', () {
      final rng = Random(5);
      final c = List.filled(6, 0);
      for (var i = 0; i < 20000; i++) {
        c[g.gachaPotential(rng.nextDouble())]++;
      }
      expect(c[1] + c[2], 0);
      expect(c[5] / 20000, closeTo(0.03, 0.006));
    });

    test('두 천장을 함께 돌리면 50번 안에 전설이 반드시 하나 나온다', () {
      final rng = Random(9);
      var epic = 0, legend = 0, worst = 0, since = 0;
      for (var i = 0; i < 20000; i++) {
        final p = g.gachaPotential(
          rng.nextDouble(),
          epicPity: epic >= 10 - 1,
          legendPity: g.legendPityDue(legend),
        );
        epic = p >= g.gachaPityMinPotential ? 0 : epic + 1;
        legend = p >= 5 ? 0 : legend + 1;
        since = p >= 5 ? 0 : since + 1;
        if (since > worst) worst = since;
      }
      expect(worst, lessThan(50));
    });
  });

  test('등급 고르기 — 야생 확률', () {
    final rng = Random(3);
    final n = 20000;
    final c = List.filled(5, 0);
    for (var i = 0; i < n; i++) {
      c[IndividualGradeConfig.pick(g.wildWeights, rng) - 1]++;
    }
    expect(c[0], n, reason: '야생은 100% 일반(2026-10-14)');
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
