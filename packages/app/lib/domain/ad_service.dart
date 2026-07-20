import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 보상형 광고 1회 시청 결과.
enum AdResult {
  /// 끝까지 봐서 보상 조건 충족 — **이때만 보상을 준다**.
  rewarded,

  /// 중간에 닫음 → 보상 없음.
  dismissed,

  /// 광고 로드/표시 실패(네트워크·노출 물량 없음 등).
  failed,

  /// 아직 준비된 광고가 없음.
  notReady,
}

/// 보상형 광고 서비스 계약. `PvpBackend`·`IapService` 와 같은 교체 패턴이다.
///
/// **보상은 반드시 [AdResult.rewarded] 일 때만 지급**한다. 이 규칙이 깨지면
/// "광고 보기"라고 써놓고 광고 없이 재화를 주는 셈이 되어, 사용자를 속이는
/// 동시에 프리미엄 재화가 공짜가 된다.
abstract interface class AdService {
  /// 실제 광고 SDK 에 연결된 구현이면 true(개발용 더미는 false).
  bool get isReal;

  /// 보상형 광고를 보여주고 결과를 돌려준다.
  Future<AdResult> showRewarded();

  /// 다음 광고를 미리 받아둔다(버튼을 눌렀을 때 기다리지 않게).
  void preload();

  void dispose();
}

/// 개발용 더미 — 광고 SDK 없이 즉시 보상 처리한다.
///
/// ⚠️ 릴리즈에서 이 구현이 쓰이면 광고 없이 보상이 나간다.
/// `main.dart` 가 릴리즈에서는 실제 구현으로 오버라이드한다.
class NoAdService implements AdService {
  const NoAdService();

  @override
  bool get isReal => false;

  @override
  Future<AdResult> showRewarded() async => AdResult.rewarded;

  @override
  void preload() {}

  @override
  void dispose() {}
}

/// 교체 가능한 광고 서비스. 기본은 개발용 더미.
final adServiceProvider = Provider<AdService>((ref) {
  const s = NoAdService();
  ref.onDispose(s.dispose);
  return s;
});
