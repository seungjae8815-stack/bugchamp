import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:core_run/core_run.dart';
import 'package:test/test.dart';

/// 장비 옵션 뽑기 분포.
///
/// 균등분포였을 때 문제: 치명피해 1~80 에서 56 이상이 **30%** 로 나왔다.
/// "잘 뽑았다"가 흔하고 상위 5% 가 평균의 1.88배뿐이라, **평균 장비로 충분해서
/// 아무도 더 안 돌렸다**(2026-08-30). 계속 돌릴 이유는 평균과 최선의 **격차**에서
/// 나온다 — 그래서 분포를 아래로 몰고, 평균도 함께 내린다.
void main() {
  final items = ItemConfig.fromJson(
    jsonDecode(File('../app/assets/data/items.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  final forge = ForgeConfig.fromJson(
    jsonDecode(File('../app/assets/data/forge.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  test('곡선이 균등(1.0)이 아니다 — 균등이면 이 시스템의 의미가 없다', () {
    expect(items.optionCurve, greaterThan(1.0));
  });

  /// 실제 롤을 굴려 분포를 확인한다. **시드 고정** — 돌릴 때마다 값이
  /// 흔들리면 회귀 테스트로 못 쓴다.
  test('높은 롤이 귀하다 — 상위 5%가 평균의 2.5배를 넘는다', () {
    final rng = Random(20260830);
    final vals = <double>[];
    for (var i = 0; i < 20000; i++) {
      final item = forgeOnce(
        rng: rng,
        items: items,
        forge: forge,
        forgeLevel: items.tierCount - 1,
      );
      for (final o in item.options) {
        final r = items.optionPool.firstWhere((p) => p.kind == o.kind);
        // 범위가 옵션마다 달라 **범위 대비 비율**로 비교한다.
        vals.add((o.value - r.min) / (r.max - r.min));
      }
    }
    vals.sort();
    final mean = vals.reduce((a, b) => a + b) / vals.length;
    final top5 = vals[(vals.length * 0.95).floor()];
    expect(mean, lessThan(0.40), reason: '균등이면 0.5 근처다');
    expect(top5 / mean, greaterThan(2.5), reason: '상위 롤이 평균보다 확실히 좋아야 계속 돌린다');
  });

  test('값은 항상 범위 안이다', () {
    final rng = Random(7);
    for (var i = 0; i < 2000; i++) {
      final item = forgeOnce(
        rng: rng,
        items: items,
        forge: forge,
        forgeLevel: rng.nextInt(items.tierCount),
      );
      for (final o in item.options) {
        final r = items.optionPool.firstWhere((p) => p.kind == o.kind);
        expect(o.value, inInclusiveRange(r.min.toDouble(), r.max.toDouble()));
      }
    }
  });
}
