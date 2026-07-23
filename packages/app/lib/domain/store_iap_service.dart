import 'dart:async';

import 'package:core_run/core_run.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'game_server.dart';
import 'iap_service.dart';
import 'providers.dart';
import 'purchase_verifier.dart';
import 'save_controller.dart';

/// 임시 진단 — 마지막 구매 처리의 내부 경로(검증기 연결·영수증 길이·결과).
/// 상점 스낵바에 함께 표시해 iOS 미지급 원인을 눈으로 확인한다. 원인 파악 후 제거.
String iapLastDiag = '';

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
          // 지급 전에 **서버에서 영수증을 검증**한다. 클라이언트만 믿으면
          // 결제 후킹 앱이 만든 가짜 영수증으로 상품이 나간다.
          switch (await _verify(p)) {
            case VerifyResult.invalid:
              // 위조·취소·재사용 — 지급하지 않는다. 재시도해도 결과가 같으므로
              // 완료 통보해 큐에서 뺀다(무한 재전달 방지).
              if (p.pendingCompletePurchase) await _store.completePurchase(p);
              _finish(p.productID, PurchaseOutcome.failed);

            case VerifyResult.unknown:
              // 판정 불가(네트워크·서버 점검). 지급도 완료통보도 하지 않는다 →
              // 다음 실행에 스토어가 다시 전달해 재시도된다.
              // 정상 구매자가 오프라인이라는 이유로 손해 보지 않게 하는 쪽을 택한다.
              _finish(p.productID, PurchaseOutcome.pending);

            case VerifyResult.valid:
              final granted = await _grant(p);
              iapLastDiag += ' grant=$granted';
              // 지급에 실패했으면 완료 통보하지 않는다 — 그래야 스토어가 다시 전달해
              // 다음 기회에 지급할 수 있다(돈만 받고 물건 안 주는 상황 방지).
              if (granted && p.pendingCompletePurchase) {
                await _store.completePurchase(p);
              }
              _finish(
                p.productID,
                granted ? PurchaseOutcome.success : PurchaseOutcome.failed,
              );
          }

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

  /// 영수증 서버 검증.
  ///
  /// 검증기가 없을 때: **개발 빌드는 통과**(백엔드 없이 상점을 돌려보려고),
  /// **릴리즈 빌드는 보류**(unknown). 릴리즈에서 통과시키면, 검증기 없이
  /// 빌드된 출시본이 **위조 영수증을 무검증 지급**하는 구멍이 된다.
  Future<VerifyResult> _verify(PurchaseDetails p) async {
    final verifier = _ref.read(purchaseVerifierProvider);
    final tokLen = p.verificationData.serverVerificationData.length;
    final srv = _ref.read(gameServerProvider).available;
    iapLastDiag = 'chk avail=${verifier.available} tok=$tokLen srv=$srv';
    if (!verifier.available) {
      iapLastDiag += ' →미연결';
      if (kReleaseMode) {
        debugPrint('[iap] ⚠️ 릴리즈인데 검증기 미연결 — 지급 보류');
        return VerifyResult.unknown; // 릴리즈는 검증 없이 지급하지 않는다
      }
      debugPrint('[iap] 검증기 미연결(개발 빌드) — 통과');
      return VerifyResult.valid;
    }
    final token = p.verificationData.serverVerificationData;
    if (token.isEmpty) {
      iapLastDiag += ' →영수증빈값';
      return VerifyResult.unknown;
    }
    final r = await verifier.verify(productId: p.productID, purchaseToken: token);
    iapLastDiag += ' →$r';
    return r;
  }

  /// 구매 1건을 반영한다.
  ///
  /// **권위 서버가 붙어 있으면 서버가 지급한다** — 클라이언트가 자기 세이브에
  /// 재화를 쓰면 앱을 개조해 결제 없이 넣을 수 있기 때문이다.
  /// 서버가 없으면(전환 중·오프라인 빌드) 기존 로컬 경로로 폴백한다.
  Future<bool> _grantViaServer(PurchaseDetails p) async {
    final server = _ref.read(gameServerProvider);
    if (!server.available) return false; // 로컬 경로로
    final token = p.verificationData.serverVerificationData;
    if (token.isEmpty) return false;

    // 지급 전 최신 로컬 세이브를 올린다 — 안 그러면 서버가 **낡은 세이브**에
    // 지급하고 그걸 adopt 해, 최근 기기 진행(방금 번 골드·잡은 곤충)이 사라진다.
    final save = _ref.read(saveControllerProvider).value;
    if (save != null) {
      final up = await server.uploadSave(save.toJson());
      if (up.status == 409) await server.bootstrap(save.toJson());
    }

    final res = await server.purchase(
      productId: p.productID,
      purchaseToken: token,
    );
    if (res.isOk && res.save != null) {
      await _ref
          .read(saveControllerProvider.notifier)
          .adoptServerSave(res.save!);
      return true;
    }
    debugPrint('[iap] 서버 지급 실패: ${res.error} (${res.status})');
    return false;
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
    // 권위 서버가 있으면 서버가 지급한다(영수증 검증도 서버가 다시 한다).
    final server = _ref.read(gameServerProvider);
    if (server.available) return _grantViaServer(p);

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
