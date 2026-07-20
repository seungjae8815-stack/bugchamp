import 'package:core_run/core_run.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'save_controller.dart';

/// 인앱결제 서비스 계약. `PvpBackend` 와 같은 "인터페이스 + 구현 교체" 패턴이다.
///
/// 개발 중엔 [LocalIapService](스토어 없이 즉시 지급)로 상점을 굴리고,
/// 스토어 상품 등록이 끝나면 `StoreIapService`(in_app_purchase)로
/// [iapServiceProvider] 를 오버라이드한다. 지급 로직은 양쪽 모두
/// `SaveController.applyPurchase` 하나만 쓴다(중복 구현 방지).
abstract interface class IapService {
  /// 실제 스토어에 연결된 구현이면 true(개발용 로컬은 false).
  bool get isStore;

  /// [product] 구매 → 성공 시 지급까지 완료하고 true.
  Future<bool> buy(IapProduct product);

  /// 비소모성(광고제거·스킨·스타터) 구매 복원. 스토어 심사 필수 항목.
  Future<void> restore();
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

  @override
  Future<bool> buy(IapProduct product) =>
      _ref.read(saveControllerProvider.notifier).applyPurchase(product);

  /// 로컬은 스토어 이력이 없어 복원할 것이 없다.
  @override
  Future<void> restore() async {}
}

/// 교체 가능한 결제 서비스 제공자. 기본은 개발용 로컬.
final iapServiceProvider = Provider<IapService>((ref) => LocalIapService(ref));
