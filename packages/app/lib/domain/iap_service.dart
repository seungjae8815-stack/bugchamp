import 'package:core_run/core_run.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'save_controller.dart';

/// 구매 1건의 결과. 스토어 결제는 취소·보류가 흔해서 성공/실패 2값으론 부족하다.
enum PurchaseOutcome {
  /// 결제 완료 + 지급까지 끝남.
  success,

  /// 사용자가 결제창을 닫음(에러 아님 — 조용히 넘어간다).
  canceled,

  /// 결제가 접수됐지만 아직 확정 전(예: 보호자 승인 대기).
  /// 확정되면 스트림으로 들어와 자동 지급된다.
  pending,

  /// 결제 실패(네트워크·결제수단 등).
  failed,

  /// 이 기기에서 스토어 결제를 쓸 수 없음(플레이 서비스 없음 등).
  unavailable,

  /// 스토어에 해당 상품이 등록되지 않음(콘솔 등록 누락 또는 id 불일치).
  notInStore,
}

/// 인앱결제 서비스 계약. `PvpBackend` 와 같은 "인터페이스 + 구현 교체" 패턴이다.
///
/// 개발 중엔 [LocalIapService](스토어 없이 즉시 지급)로 상점을 굴리고,
/// 스토어 상품 등록이 끝나면 [StoreIapService] 로 [iapServiceProvider] 를
/// 오버라이드한다. 지급 로직은 양쪽 모두 `SaveController.applyPurchase`
/// 하나만 쓴다(중복 구현 방지).
abstract interface class IapService {
  /// 실제 스토어에 연결된 구현이면 true(개발용 로컬은 false).
  bool get isStore;

  /// 스토어가 알려준 **현지 통화 가격** (상품 id → "₩5,500" 같은 표시 문자열).
  ///
  /// 스토어가 붙은 뒤에는 이 값을 보여줘야 한다 — 나라마다 가격이 다르고,
  /// `iap.json` 의 원화 값은 어디까지나 기획용 참고치다.
  Map<String, String> get storePrices;

  /// [product] 결제 시작 → 결착되면 결과 반환. 성공이면 지급까지 끝난 상태.
  Future<PurchaseOutcome> buy(IapProduct product);

  /// 비소모성(광고제거·스킨·스타터) 구매 복원. 스토어 심사 필수 항목.
  Future<void> restore();

  /// 스트림 구독 해제 등 정리.
  void dispose();
}

/// 개발용 구현 — 결제 없이 즉시 지급한다.
///
/// ⚠️ 릴리즈에서 이 구현이 쓰이면 상품을 공짜로 주는 셈이므로,
/// 스토어 연동 후 반드시 [iapServiceProvider] 를 실제 구현으로 오버라이드할 것.
class LocalIapService implements IapService {
  const LocalIapService(this._ref);

  final Ref _ref;

  @override
  bool get isStore => false;

  /// 로컬은 스토어 가격이 없다 — UI 가 `iap.json` 의 원화로 폴백한다.
  @override
  Map<String, String> get storePrices => const {};

  @override
  Future<PurchaseOutcome> buy(IapProduct product) async {
    final ok = await _ref
        .read(saveControllerProvider.notifier)
        .applyPurchase(product);
    return ok ? PurchaseOutcome.success : PurchaseOutcome.failed;
  }

  /// 로컬은 스토어 이력이 없어 복원할 것이 없다.
  @override
  Future<void> restore() async {}

  @override
  void dispose() {}
}

/// 교체 가능한 결제 서비스 제공자. 기본은 개발용 로컬.
/// 스토어 빌드는 `main.dart` 에서 [StoreIapService] 로 오버라이드한다.
final iapServiceProvider = Provider<IapService>((ref) {
  final s = LocalIapService(ref);
  ref.onDispose(s.dispose);
  return s;
});
