import 'dart:math';

import 'package:core_models/core_models.dart';
import 'package:test/test.dart';

void main() {
  group('rollSizeMm — 범위', () {
    test('모든 롤 결과가 [min,max] 범위 내', () {
      final rng = Random(1);
      const min = 30.0, max = 75.0;
      for (var i = 0; i < 20000; i++) {
        final s = rollSizeMm(rng, min, max);
        expect(s, inInclusiveRange(min, max));
      }
    });

    test('퇴화 범위(min>=max)는 min 반환', () {
      final rng = Random(1);
      expect(rollSizeMm(rng, 50, 50), 50);
      expect(rollSizeMm(rng, 60, 40), 60);
    });
  });

  group('rollSizeMm — 결정론', () {
    test('같은 seed 는 같은 시퀀스를 재현', () {
      final a = Random(42);
      final b = Random(42);
      for (var i = 0; i < 500; i++) {
        expect(rollSizeMm(a, 10, 90), rollSizeMm(b, 10, 90));
      }
    });

    test('다른 seed 는 (거의 항상) 다른 값', () {
      final a = rollSizeMm(Random(1), 10, 90);
      final b = rollSizeMm(Random(2), 10, 90);
      expect(a, isNot(equals(b)));
    });
  });

  group('rollSizeMm — 정규분포 형태', () {
    // 결정론적 seed 이므로 통계 검증도 재현 가능하게 통과한다.
    const min = 30.0, max = 75.0;
    const n = 50000;
    final mean = (min + max) / 2; // 52.5
    final sigma = (max - min) / 6; // 7.5

    late List<double> samples;

    setUp(() {
      final rng = Random(12345);
      samples = List.generate(n, (_) => rollSizeMm(rng, min, max));
    });

    test('표본 평균 ≈ 중앙값', () {
      final m = samples.reduce((a, b) => a + b) / n;
      expect(m, closeTo(mean, 0.5)); // ±0.5mm
    });

    test('표본 표준편차 ≈ 범위/6', () {
      final m = samples.reduce((a, b) => a + b) / n;
      final variance =
          samples.map((x) => (x - m) * (x - m)).reduce((a, b) => a + b) / n;
      final sd = sqrt(variance);
      expect(sd, closeTo(sigma, 0.6)); // clamp 로 살짝 작아질 수 있어 여유
    });

    test('±1σ 이내 비율 ≈ 0.68 (종 모양)', () {
      final within = samples.where((x) => (x - mean).abs() <= sigma).length / n;
      expect(within, closeTo(0.68, 0.03));
    });

    test('중앙 근처가 꼬리보다 조밀 (단봉형)', () {
      // 중앙 ±0.5σ 밀도 > 바깥쪽 [1σ,1.5σ] 밀도
      int band(double lo, double hi) => samples
          .where((x) => (x - mean).abs() >= lo && (x - mean).abs() < hi)
          .length;
      final center = band(0, 0.5 * sigma);
      final outer = band(1.0 * sigma, 1.5 * sigma);
      expect(center, greaterThan(outer));
    });
  });

  group('sizeToStatMultiplier — 매핑', () {
    const min = 30.0, max = 75.0;

    test('경계: min→0.85, max→1.20', () {
      expect(
        sizeToStatMultiplier(min, min, max),
        closeTo(kStatMultiplierMin, 1e-9),
      );
      expect(
        sizeToStatMultiplier(max, min, max),
        closeTo(kStatMultiplierMax, 1e-9),
      );
    });

    test('중앙값 → 배율 중앙', () {
      final mid = (min + max) / 2;
      final expected = (kStatMultiplierMin + kStatMultiplierMax) / 2;
      expect(sizeToStatMultiplier(mid, min, max), closeTo(expected, 1e-9));
    });

    test('범위 밖 사이즈는 clamp', () {
      expect(
        sizeToStatMultiplier(0, min, max),
        closeTo(kStatMultiplierMin, 1e-9),
      );
      expect(
        sizeToStatMultiplier(999, min, max),
        closeTo(kStatMultiplierMax, 1e-9),
      );
    });

    test('단조 증가', () {
      expect(
        sizeToStatMultiplier(40, min, max),
        lessThan(sizeToStatMultiplier(60, min, max)),
      );
    });
  });
}
