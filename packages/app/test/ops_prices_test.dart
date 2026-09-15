import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 운영 알림(결제 실시간 알림·일일 리포트 매출)이 쓰는 가격표
/// `supabase/functions/_shared/ops.ts → PRICE_KRW` 가 상점 데이터(iap.json)와 같은지.
///
/// Edge Function 은 앱 데이터를 읽을 수 없어 가격을 따로 적어 두었다. 상품 가격을 바꾸고
/// 이 표를 잊으면 **매출 알림이 조용히 틀린다** — 여기서 먼저 깨지게 한다.
void main() {
  test('Edge Function 가격표 = iap.json (iOS 전용 id 포함)', () {
    final iap =
        jsonDecode(File('assets/data/iap.json').readAsStringSync())
            as Map<String, dynamic>;
    final ts = File(
      '../../supabase/functions/_shared/ops.ts',
    ).readAsStringSync();
    final table = RegExp(
      r'PRICE_KRW[^{]*\{([^}]*)\}',
    ).firstMatch(ts)!.group(1)!;
    final prices = {
      for (final m in RegExp(r'(\w+):\s*(\d+)').allMatches(table))
        m.group(1)!: int.parse(m.group(2)!),
    };
    for (final p in (iap['products'] as List).cast<Map<String, dynamic>>()) {
      final price = (p['priceKrw'] as num).toInt();
      expect(prices[p['id']], price, reason: '${p['id']} 가격이 다르다');
      final ios = p['iosId'] as String?;
      if (ios != null && ios.isNotEmpty) {
        expect(prices[ios], price, reason: '$ios(iOS) 가격이 다르다');
      }
    }
  });
}
