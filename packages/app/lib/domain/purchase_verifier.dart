import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 영수증 검증 결과.
enum VerifyResult {
  /// 진짜 구매 — 지급해도 된다.
  valid,

  /// 위조·취소·환불, 또는 다른 계정이 이미 쓴 영수증 → **지급 금지**.
  /// 재시도해도 결과가 바뀌지 않으므로 스토어에 완료 통보해 큐에서 뺀다.
  invalid,

  /// 서버에 못 닿았거나 일시적 오류 → 지급도 완료통보도 하지 말고 **다음에 재시도**.
  /// (비행기모드·서버 점검 중에 정상 구매자가 손해 보지 않게)
  unknown,
}

/// 구매 영수증을 서버에서 검증하는 계약.
///
/// 클라이언트만으로 구매를 인정하면 결제 후킹 앱이 만든 가짜 영수증으로
/// 상품을 공짜로 받을 수 있다. 진짜 구글이 발급한 영수증인지는
/// **서버(Play Developer API)** 만 판단할 수 있다.
abstract interface class PurchaseVerifier {
  /// 검증 기능이 실제로 붙어 있는지(미연결이면 false).
  bool get available;

  Future<VerifyResult> verify({
    required String productId,
    required String purchaseToken,
  });
}

/// 백엔드 미연결 — 검증할 수단이 없다.
///
/// ⚠️ [VerifyResult.unknown] 을 돌려준다. `valid` 로 두면 검증이 없는 것과
/// 같아지고, `invalid` 로 두면 오프라인 빌드에서 정상 구매가 막힌다.
class NoPurchaseVerifier implements PurchaseVerifier {
  const NoPurchaseVerifier();

  @override
  bool get available => false;

  @override
  Future<VerifyResult> verify({
    required String productId,
    required String purchaseToken,
  }) async => VerifyResult.unknown;
}

/// Supabase Edge Function `verify-purchase` 호출 구현.
class SupabasePurchaseVerifier implements PurchaseVerifier {
  const SupabasePurchaseVerifier(this._client);

  final SupabaseClient _client;

  @override
  bool get available => true;

  @override
  Future<VerifyResult> verify({
    required String productId,
    required String purchaseToken,
  }) async {
    try {
      final res = await _client.functions.invoke(
        'verify-purchase',
        body: {'productId': productId, 'purchaseToken': purchaseToken},
      );
      final data = res.data;
      if (data is Map && data['ok'] == true) return VerifyResult.valid;

      final reason = (data is Map ? data['reason'] : null)?.toString();
      // 서버가 "확정적으로 가짜"라고 한 경우만 invalid. 나머지는 재시도 여지를 남긴다.
      const fatal = {'invalid', 'owned_by_other'};
      if (reason != null && fatal.contains(reason)) {
        debugPrint('[iap] 영수증 거부: $reason ($productId)');
        return VerifyResult.invalid;
      }
      debugPrint('[iap] 영수증 판정 보류: $reason ($productId)');
      return VerifyResult.unknown;
    } catch (e) {
      // 네트워크 오류·함수 미배포 등 → 판정 불가.
      debugPrint('[iap] 영수증 검증 실패(재시도 예정): $e');
      return VerifyResult.unknown;
    }
  }
}

/// 교체 가능한 검증기. 기본은 미연결.
final purchaseVerifierProvider = Provider<PurchaseVerifier>(
  (ref) => const NoPurchaseVerifier(),
);
