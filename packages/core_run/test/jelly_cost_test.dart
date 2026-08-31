import 'package:core_run/core_run.dart';
import 'package:test/test.dart';

/// 젤리 **소비 금액**은 5·10 단위로 떨어져야 한다(§2.6, 사장님 확정
/// 2026-08-31). 시간 비례 공식이 그대로 화면에 나오면 `13젤리`·`27젤리` 같은
/// 값이 떠서, 유저가 가격표인지 계산 결과인지 구분하지 못한다.
void main() {
  test('5 미만은 5 — 공짜처럼 보이는 1~2젤리를 없앤다', () {
    expect(roundJellyCost(0.1), 5);
    expect(roundJellyCost(1), 5);
    expect(roundJellyCost(4.9), 5);
  });

  test('0 이하는 0 — 안 걸리는 자리는 그대로 공짜', () {
    expect(roundJellyCost(0), 0);
    expect(roundJellyCost(-3), 0);
  });

  test('50 미만은 5 단위, 50 이상은 10 단위', () {
    expect(roundJellyCost(12.4), 10);
    expect(roundJellyCost(13), 15);
    expect(roundJellyCost(24.8), 25);
    expect(roundJellyCost(53), 50);
    expect(roundJellyCost(56), 60);
    expect(roundJellyCost(79.9), 80);
  });

  test('결과는 항상 5 의 배수다', () {
    for (var i = 1; i <= 2000; i++) {
      expect(roundJellyCost(i * 0.37) % 5, 0, reason: 'raw=${i * 0.37}');
    }
  });

  test('단조 증가 — 더 오래 남았는데 더 싸지지 않는다', () {
    var prev = 0;
    for (var i = 1; i <= 3000; i++) {
      final v = roundJellyCost(i * 0.5);
      expect(v, greaterThanOrEqualTo(prev));
      prev = v;
    }
  });

  /// 실제 데이터가 의도한 가격표대로 떨어지는지 — 계수·지수를 바꾸면
  /// 여기서 먼저 걸린다(사장님 확정: 전설 산란 80 · 부화 50).
  test('전설 산란 80 · 부화 50', () {
    const cfg = PetConfig(
      gradeAttackPct: {},
      gradeHpPct: {},
      stageMult: {},
      stageDurationsSec: {},
      breedingJellyPerMinute: 0.93,
      incubateJellyPerMinute: 0.93,
      instantJellyExponent: 0.58,
    );
    expect(cfg.breedingJelly(const Duration(hours: 36)), 80);
    expect(cfg.incubateJelly(const Duration(hours: 16)), 50);
    // 낮은 등급도 5 단위로.
    expect(cfg.breedingJelly(const Duration(minutes: 15)), 5);
    expect(cfg.breedingJelly(const Duration(hours: 12)), 40);
  });
}
