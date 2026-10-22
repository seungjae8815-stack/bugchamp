import 'package:app/features/character/equip_widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('장비 옵션 값 — 0.1 단위로 오른 것이 화면에 보인다(68.0 → 68.3)', () {
    expect(fmtOptPct(68), '68');
    expect(fmtOptPct(68.3), '68.3');
    // 반올림하면 "69/69" 로 보여 최대처럼 읽히던 값.
    expect(fmtOptPct(68.6), '68.6');
    expect(fmtOptPct(3.45), '3.5');
    expect(fmtOptPct(69.0000001), '69');
  });
}
