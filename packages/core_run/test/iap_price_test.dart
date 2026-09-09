import 'dart:convert';
import 'dart:io';

import 'package:core_run/core_run.dart';
import 'package:test/test.dart';

Map<String, dynamic> _iapJson() =>
    jsonDecode(File('../app/assets/data/iap.json').readAsStringSync())
        as Map<String, dynamic>;

/// 젤리 팩과 패스의 **가격 사다리**를 지킨다.
///
/// 2026-09-09: 패스 일일 30젤리는 ₩11.0/젤리로 **어떤 팩보다도 쌌다**.
/// 젤리를 원하는 사람은 무조건 패스를 사므로 팩 6종이 진열만 되고,
/// 매출 상한이 1인당 월 ₩9,900 에 묶였다(jelly_sim 실측).
void main() {
  group('IAP 가격 사다리', () {
    final json = _iapJson();
    final iap = IapConfig.fromJson(json);
    final products = (json['products'] as List).cast<Map<String, dynamic>>();

    double passPerJelly() {
      final pass = products.firstWhere((p) => p['id'] == 'idle_pass');
      final total = iap.passDailyJelly * iap.passDurationDays;
      return (pass['priceKrw'] as num) / total;
    }

    Iterable<double> packPerJelly() sync* {
      for (final p in products) {
        final grant = p['grant'] as Map<String, dynamic>?;
        final jelly = (grant?['jelly'] as num?)?.toInt() ?? 0;
        if (p['type'] != 'jelly' || jelly <= 0) continue;
        yield (p['priceKrw'] as num) / jelly;
      }
    }

    test('⚠️ 패스가 최저가 젤리 팩보다 싸면 안 된다', () {
      final cheapestPack = packPerJelly().reduce((a, b) => a < b ? a : b);
      expect(
        passPerJelly(),
        greaterThan(cheapestPack),
        reason:
            '패스 ₩${passPerJelly().toStringAsFixed(1)}/젤리 vs '
            '최저팩 ₩${cheapestPack.toStringAsFixed(1)}/젤리 — 팩이 안 팔린다',
      );
    });

    test('큰 팩일수록 싸다 — 사다리가 뒤집히면 큰 팩을 살 이유가 없다', () {
      final packs = products.where((p) => p['type'] == 'jelly').toList()
        ..sort(
          (a, b) => (a['priceKrw'] as num).compareTo(b['priceKrw'] as num),
        );
      var prev = double.infinity;
      for (final p in packs) {
        final unit =
            (p['priceKrw'] as num) / ((p['grant'] as Map)['jelly'] as num);
        expect(unit, lessThanOrEqualTo(prev + 1e-9), reason: '${p['id']}');
        prev = unit;
      }
    });
  });
}
