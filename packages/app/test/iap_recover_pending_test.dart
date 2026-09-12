// 보류된 결제가 **스스로** 되살아나는지 검사한다.
//
// 안드로이드는 미완료 구매를 앱 시작 시 자동으로 다시 주지 않는다 —
// restorePurchases() 를 불러야 큐가 다시 흐른다. 이 사실을 모르고
// "다음 실행에 다시 온다"고 믿었다가, 검증이 보류된 실결제가 지급도
// 승인도 되지 않은 채 멈춰 72시간 뒤 자동 환불될 뻔했다(2026-09-11).
import 'dart:async';

import 'package:app/domain/store_iap_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// 스토어 호출만 세는 가짜 스토어.
class _FakeStore implements InAppPurchase {
  final _controller = StreamController<List<PurchaseDetails>>.broadcast();
  int restoreCalls = 0;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _controller.stream;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {
    restoreCalls++;
  }

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) async =>
      ProductDetailsResponse(
        productDetails: const [],
        notFoundIDs: ids.toList(),
      );

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeStore store;
  late ProviderContainer container;
  late StoreIapService service;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    store = _FakeStore();
    container = ProviderContainer();
    service = StoreIapService(container.read(_refProvider), store: store);
  });

  tearDown(() {
    service.dispose();
    container.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  test('앱 시작 시 보류 결제를 스스로 다시 흘린다', () async {
    await service.recoverPending();
    expect(store.restoreCalls, 1);
  });

  test('복귀마다 스토어를 두드리지는 않는다(최소 간격)', () async {
    await service.recoverPending();
    await service.recoverPending();
    expect(store.restoreCalls, 1);
  });

  test('iOS 는 결제 큐가 스스로 다시 주므로 복원을 부르지 않는다', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await service.recoverPending();
    expect(store.restoreCalls, 0);
  });
}

/// StoreIapService 가 요구하는 Ref 를 꺼내기 위한 자리표시 프로바이더.
final _refProvider = Provider<Ref>((ref) => ref);
