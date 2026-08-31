import 'package:core_models/core_models.dart';
import 'package:core_save/core_save.dart';
import 'package:test/test.dart';

/// 재화 int64 오버플로 방어.
///
/// ⚠️ Dart 의 int 는 64비트이고 **넘치면 조용히 음수로 감싼다** — 예외도 안 난다.
/// `9223372036854775807 + 1 == -9223372036854775808`.
/// 실제로 "게임 내 돈이 마이너스가 됐다"는 제보가 나왔다(2026-08-30).
///
/// 경로: 방치 정산이 double 로 계산해 `.round()` 하면 **포화**(최대값으로 잘림)
/// 되는데, 그렇게 최대값 근처가 된 골드에 **다음 보상을 더하는 순간** 감싼다.
void main() {
  final t0 = DateTime.utc(2026, 8, 30);

  test('int64 는 조용히 감싼다 — 이 테스트가 지키는 전제', () {
    const max = 9223372036854775807;
    expect(max + 1, isNegative, reason: '예외 없이 음수가 된다');
  });

  test('clampCurrency 는 음수·초과·NaN 을 막는다', () {
    expect(clampCurrency(-1), 0);
    expect(clampCurrency(-9223372036854775808), 0);
    expect(clampCurrency(double.nan), 0);
    expect(clampCurrency(1e30), kMaxCurrency);
    expect(clampCurrency(1234), 1234);
  });

  /// 이미 감싸서 음수가 된 세이브를 읽었을 때 **스스로 회복**해야 한다.
  /// 그대로 두면 화면에 마이너스가 뜨고, 거기서 또 더하면 계속 음수다.
  test('음수 골드 세이브를 읽으면 0 으로 되돌아온다', () {
    final json = SaveGame.initial(createdAt: t0).toJson()
      ..['gold'] = -8946744073709551616
      ..['xp'] = -5;
    final s = SaveGame.fromJson(json);
    expect(s.gold, 0);
    expect(s.xp, 0);
  });

  /// ⚠️ `clampCurrency(a + b)` 는 **틀렸다** — int 덧셈이 먼저 감싼다.
  /// 이 게임은 스테이지 1708 유저가 9.289e18 까지 모았다(자연 누적).
  test('addCurrency 는 더하는 순간의 오버플로도 막는다', () {
    // 상한 근처 + 큰 보상 → int 로 더했으면 음수가 됐을 조합.
    expect(addCurrency(kMaxCurrency, 5e18), kMaxCurrency);
    expect(addCurrency(9000000000000000000, 9000000000000000000), kMaxCurrency);
    // 평범한 덧셈은 그대로.
    expect(addCurrency(1000, 234), 1234);
    // 음수 보상(차감)도 0 아래로 안 내려간다.
    expect(addCurrency(100, -500), 0);
  });

  /// 낮게 잡으면 후반 유저의 자산을 통째로 깎고 업그레이드를 막는다 —
  /// 오버플로를 막으려다 진행을 막는 셈이다.
  test('상한은 후반 유저의 실제 자산을 담을 만큼 크다', () {
    expect(kMaxCurrency, greaterThan(9000000000000000000 ~/ 2));
    expect(kMaxCurrency, lessThan(9223372036854775807));
  });

  test('상한을 넘는 세이브는 상한으로 잘린다', () {
    final json = SaveGame.initial(createdAt: t0).toJson()
      ..['gold'] = 9223372036854775807;
    expect(SaveGame.fromJson(json).gold, kMaxCurrency);
  });
}
