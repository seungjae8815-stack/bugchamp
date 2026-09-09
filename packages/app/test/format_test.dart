import 'package:app/ui/format.dart';
import 'package:flutter_test/flutter_test.dart';

/// 방치형은 숫자가 끝없이 커진다. **표기 길이가 자라면 옆 칸을 밀어낸다** —
/// 버프 타이머가 `43193:14` 로 HUD 를 밀어낸 사고와 같은 종류다.
void main() {
  group('큰 수 축약', () {
    test('1000 미만은 그대로', () {
      expect(formatCompact(0), '0');
      expect(formatCompact(999), '999');
    });

    test('K·M·B·T', () {
      expect(formatCompact(1234), '1.23K');
      expect(formatCompact(1.2e6), '1.20M');
      expect(formatCompact(5.5e9), '5.50B');
      expect(formatCompact(3.1e12), '3.10T');
    });

    test('T 위로는 aa·ab·ac… 로 이어진다', () {
      expect(formatCompact(1e15), '1.00aa');
      expect(formatCompact(1e18), '1.00ab');
      expect(formatCompact(1e21), '1.00ac');
      expect(formatCompact(1e24), '1.00ad');
    });

    test('⚠️ 어떤 값이 와도 길이가 자라지 않는다', () {
      // 예전엔 `ac`(10^21)에서 표가 끝나 그 위가 `1000000ac` 처럼 자랐다.
      // 재화는 9e18 에서 잘리지만 **능력치·전투력은 상한이 없다**.
      for (var e = 3; e <= 300; e += 3) {
        final s = formatCompact(double.parse('1e$e'));
        expect(
          s.length,
          lessThanOrEqualTo(8),
          reason: '1e$e 가 "$s" (${s.length}자) 로 나왔다',
        );
      }
    });

    test('무한대·NaN 에서 죽지 않는다', () {
      expect(formatCompact(double.infinity), '∞');
      expect(formatCompact(double.nan), '0');
    });
  });
}
