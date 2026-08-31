import 'dart:math';

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:test/test.dart';

/// 야생 드롭의 등급 희소성(§2.1, 2026-08-31).
///
/// ⚠️ 이 테스트가 지키는 것: **희소성이 종 개수 비율로 되돌아가지 않는다.**
/// 가중치가 없던 시절엔 종 20개를 균등하게 뽑아 전설(2종)이 드롭의 10% 였고,
/// 활동 중 13분에 한 마리씩 전설이 나왔다.
void main() {
  Species sp(String id, Grade g) => Species(
    id: id,
    name: LocalizedText(ko: id, en: id, ja: id),
    grade: g,
    specialty: Specialty.strike,
    baseStats: const Stats(hp: 10, atk: 10, def: 10, spd: 10),
    sizeMinMm: 10,
    sizeMaxMm: 20,
  );

  // 실제 데이터와 같은 구성(일반6 고급5 희귀4 영웅3 전설2).
  final all = <Species>[
    for (var i = 0; i < 6; i++) sp('c$i', Grade.common),
    for (var i = 0; i < 5; i++) sp('u$i', Grade.uncommon),
    for (var i = 0; i < 4; i++) sp('r$i', Grade.rare),
    for (var i = 0; i < 3; i++) sp('e$i', Grade.epic),
    for (var i = 0; i < 2; i++) sp('l$i', Grade.legendary),
  ];

  Map<Grade, int> tally(Map<Grade, double> w, {int n = 40000, int seed = 5}) {
    final rng = Random(seed);
    final out = <Grade, int>{};
    for (var i = 0; i < n; i++) {
      final s = pickDropSpecies(rng, all, weights: w);
      out[s!.grade] = (out[s.grade] ?? 0) + 1;
    }
    return out;
  }

  test('가중치가 없으면 종 개수 비율 — 전설이 10%(예전 동작)', () {
    final t = tally(const {});
    expect(t[Grade.legendary]! / 40000, closeTo(0.10, 0.01));
  });

  test('가중치를 주면 전설이 1% 로 내려간다', () {
    final t = tally(const {
      Grade.common: 52,
      Grade.uncommon: 28,
      Grade.rare: 14,
      Grade.epic: 5,
      Grade.legendary: 1,
    });
    expect(t[Grade.legendary]! / 40000, closeTo(0.01, 0.004));
    expect(t[Grade.common]! / 40000, closeTo(0.52, 0.02));
    // 희귀+ 비율은 천장(rarePityKills) 계산의 근거다 — 바뀌면 천장도 다시 잰다.
    final rarePlus =
        (t[Grade.rare] ?? 0) + (t[Grade.epic] ?? 0) + (t[Grade.legendary] ?? 0);
    expect(rarePlus / 40000, closeTo(0.20, 0.02));
  });

  test('minGrade(천장)를 주면 희귀 미만은 절대 안 나온다', () {
    final rng = Random(11);
    for (var i = 0; i < 2000; i++) {
      final s = pickDropSpecies(
        rng,
        all,
        weights: const {Grade.common: 99, Grade.legendary: 1},
        minGrade: Grade.rare,
      );
      expect(s!.grade.index, greaterThanOrEqualTo(Grade.rare.index));
    }
  });

  test('풀에 없는 등급에 가중치가 걸려도 빈손이 되지 않는다', () {
    final rng = Random(3);
    final onlyCommon = [sp('c', Grade.common)];
    final s = pickDropSpecies(
      rng,
      onlyCommon,
      weights: const {Grade.legendary: 100},
    );
    expect(s, isNotNull);
    expect(s!.grade, Grade.common);
  });

  /// 즉시완료 젤리 — 등급 타이머를 가파르게 만들면서 지수를 안 넣으면
  /// 전설 산란이 1,000젤리를 넘겨 **소비처가 아니라 장식**이 된다.
  group('즉시완료 젤리 곡선', () {
    const cfg = PetConfig(
      gradeAttackPct: {},
      gradeHpPct: {},
      stageMult: {},
      stageDurationsSec: {},
      breedingJellyPerMinute: 1.0,
      incubateJellyPerMinute: 1.0,
      instantJellyExponent: 0.58,
    );

    test('긴 대기일수록 분당 단가가 싸진다', () {
      final short = cfg.breedingJelly(const Duration(minutes: 15));
      final long = cfg.breedingJelly(const Duration(hours: 36));
      expect(short, lessThan(10));
      // 시간은 144배인데 값은 20배 안쪽이어야 지를 만하다.
      expect(long, lessThan(short * 20));
      expect(long, greaterThan(short)); // 그래도 단조 증가
    });

    test('지수 1.0 이면 예전(분 정비례)과 같다', () {
      const old = PetConfig(
        gradeAttackPct: {},
        gradeHpPct: {},
        stageMult: {},
        stageDurationsSec: {},
        breedingJellyPerMinute: 0.5,
      );
      expect(old.breedingJelly(const Duration(minutes: 60)), 30);
    });

    test('남은 시간이 없으면 0, 아주 짧아도 최소 5(§2.6 가격 단위)', () {
      expect(cfg.breedingJelly(Duration.zero), 0);
      expect(cfg.incubateJelly(const Duration(seconds: 1)), 5);
    });
  });
}
