import 'dart:async';

import 'package:core_run/core_run.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'iap_service.dart';
import 'providers.dart';
import 'save_controller.dart';

/// 실제 스토어(구글 플레이 / 앱스토어) 결제 구현.
///
/// 결제는 **비동기 스트림**이다: `buy()` 는 결제창을 띄우기만 하고, 실제 결과는
/// [InAppPurchase.purchaseStream] 으로 나중에 온다. 앱을 껐다 켜도 미완료 구매가
/// 다시 흘러오므로, 지급은 항상 스트림 한 곳에서만 처리한다.
///
/// UI 가 `await buy()` 로 결과를 받을 수 있게, 상품별 [Completer] 를 걸어두고
/// 스트림이 결착될 때 완료시킨다.
///
/// ⚠️ **영수증 서버 검증은 아직 없다.** 루팅 기기에서 결제를 위조할 수 있으므로,
/// 실제 매출이 발생하기 전에 서버 검증(구글 Play Developer API)을 붙여야 한다.
/// 자세한 내용은 `docs/monetization.md` §6.
class StoreIapService implements IapService {
  StoreIapService(this._ref, {InAppPurchase? store})
    : _store = store ?? InAppPurchase.instance;

  final Ref _ref;
  final InAppPurchase _store;

  StreamSubscription<List<PurchaseDetails>>? _sub;

  /// 진행 중인 구매의 결과를 UI 로 돌려주기 위한 대기표(상품 id → 완료자).
  final _pending = <String, Completer<PurchaseOutcome>>{};

  /// 스토어에서 조회한 상품 상세(현지 가격 표시용). 상품 id → 상세.
  final _details = <String, ProductDetails>{};

  bool _available = false;

  @override
  bool get isStore => true;

  /// 스토어 연결 + 구매 스트림 구독. 앱 시작 시 1회.
  ///
  /// 구독을 **가장 먼저** 시작해야 앱이 꺼져 있는 동안 완료된 결제
  /// (결제창에서 앱이 죽은 경우 등)를 놓치지 않는다.
  Future<void> init() async {
    _sub ??= _store.purchaseStream.listen(
      _onPurchases,
      onError: (Object e) => debugPrint('[iap] purchaseStream error: $e'),
    );
    _available = await _store.isAvailable();
    if (!_available) {
      debugPrint('[iap] 스토어를 사용할 수 없음(미지원 기기이거나 플레이 서비스 없음)');
      return;
    }
    await _loadDetails();
  }

  /// `iap.json` 의 상품 id 로 스토어 상세를 조회한다.
  /// 스토어에 등록되지 않은 id 는 `notFoundIDs` 로 돌아온다 — 그 상품은 구매 불가.
  Future<void> _loadDetails() async {
    final cfg = _ref.read(gameDataProvider).value?.iapConfig;
    if (cfg == null || cfg.products.isEmpty) return;
    final ids = cfg.products.map((p) => p.id).toSet();
    final res = await _store.queryProductDetails(ids);
    for (final d in res.productDetails) {
      _details[d.id] = d;
    }
    if (res.notFoundIDs.isNotEmpty) {
      // 스토어 콘솔에 상품이 아직 없거나 id 가 다르면 여기 찍힌다.
      debugPrint('[iap] 스토어에 없는 상품 id: ${res.notFoundIDs.join(", ")}');
    }
    if (res.error != null) debugPrint('[iap] 상품 조회 오류: ${res.error}');
  }

  @override
  Map<String, String> get storePrices => {
    for (final e in _details.entries) e.key: e.value.price,
  };

  @override
  Future<PurchaseOutcome> buy(IapProduct product) async {
    if (!_available) return PurchaseOutcome.unavailable;

    // 상세를 아직 못 받았으면 한 번 더 시도(네트워크 지연·늦은 상품 등록 대비).
    if (!_details.containsKey(product.id)) await _loadDetails();
    final details = _details[product.id];
    if (details == null) return PurchaseOutcome.notInStore;

    // 같은 상품을 두 번 누르면 앞선 대기표를 그대로 쓴다.
    final existing = _pending[product.id];
    if (existing != null) return existing.future;

    final completer = Completer<PurchaseOutcome>();
    _pending[product.id] = completer;

    final param = PurchaseParam(productDetails: details);
    try {
      // 소모성(젤리)은 consume 해야 다시 살 수 있다. 나머지는 비소모성.
      final started = product.kind == IapKind.consumable
          ? await _store.buyConsumable(purchaseParam: param)
          : await _store.buyNonConsumable(purchaseParam: param);
      if (!started) {
        _pending.remove(product.id);
        return PurchaseOutcome.failed;
      }
    } catch (e) {
      debugPrint('[iap] buy 실패: $e');
      _pending.remove(product.id);
      return PurchaseOutcome.failed;
    }

    // 결제창이 떠 있는 동안 무한정 매달리지 않게 상한을 둔다.
    // (시간이 지나 결제가 완료돼도 지급은 스트림에서 정상 처리된다.)
    return completer.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () {
        _pending.remove(product.id);
        return PurchaseOutcome.pending;
      },
    );
  }

  @override
  Future<void> restore() async {
    if (!_available) return;
    // 복원된 구매도 스트림으로 흘러와 _onPurchases 에서 지급된다.
    await _store.restorePurchases();
  }

  /// 구매 스트림 처리 — **지급은 오직 여기서만** 일어난다.
  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      switch (p.status) {
        case PurchaseStatus.pending:
          // 결제 진행 중(예: 부모 승인 대기). 아직 지급하지 않는다.
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final granted = await _grant(p);
          // 지급에 실패했으면 완료 통보하지 않는다 — 그래야 스토어가 다시 전달해
          // 다음 기회에 지급할 수 있다(돈만 받고 물건 안 주는 상황 방지).
          if (granted && p.pendingCompletePurchase) {
            await _store.completePurchase(p);
          }
          _finish(
            p.productID,
            granted ? PurchaseOutcome.success : PurchaseOutcome.failed,
          );

        case PurchaseStatus.canceled:
          if (p.pendingCompletePurchase) await _store.completePurchase(p);
          _finish(p.productID, PurchaseOutcome.canceled);

        case PurchaseStatus.error:
          debugPrint('[iap] 구매 오류: ${p.error}');
          if (p.pendingCompletePurchase) await _store.completePurchase(p);
          _finish(p.productID, PurchaseOutcome.failed);
      }
    }
  }

  /// 구매 1건을 세이브에 반영. 중복 지급은 `purchaseId` 로 막는다.
  Future<bool> _grant(PurchaseDetails p) async {
    final cfg = _ref.read(gameDataProvider).value?.iapConfig;
    final product = cfg?.byId(p.productID);
    if (product == null) {
      // iap.json 에 없는 상품이 스토어에서 왔다 — 지급할 근거가 없다.
      debugPrint('[iap] 알 수 없는 상품: ${p.productID}');
      return false;
    }
    try {
      return await _ref
          .read(saveControllerProvider.notifier)
          .applyPurchase(product, purchaseId: p.purchaseID ?? p.productID);
    } catch (e) {
      debugPrint('[iap] 지급 실패: $e');
      return false;
    }
  }

  void _finish(String productId, PurchaseOutcome outcome) {
    final c = _pending.remove(productId);
    if (c != null && !c.isCompleted) c.complete(outcome);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}

/// 스토어 연결 + 상품 조회를 1회 수행하고 **현지 가격표**를 돌려준다.
///
/// 상점 화면이 이걸 watch 하면, 조회가 끝나는 순간 가격이 원화 참고값에서
/// 스토어 실제 가격으로 바뀐다. 로컬 구현이면 빈 맵(원화 폴백).
final storePricesProvider = FutureProvider<Map<String, String>>((ref) async {
  final svc = ref.watch(iapServiceProvider);
  if (svc is StoreIapService) await svc.init();
  return svc.storePrices;
});
