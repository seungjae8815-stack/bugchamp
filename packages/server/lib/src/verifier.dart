import 'dart:convert';

import 'package:http/http.dart' as http;

/// 영수증 검증 결과. 앱 쪽 `VerifyResult` 와 같은 3분기다.
enum VerifyVerdict {
  /// 진짜 구매 — 지급해도 된다.
  valid,

  /// 위조·취소·재사용 — 지급 금지. 재시도해도 결과가 같다.
  invalid,

  /// 판정 불가(네트워크·함수 미배포 등) — **지급하지 않고 나중에 재시도**.
  unknown,
}

/// 판정 + 중복 지급을 막을 **거래 고유 키**(2026-11-09). 검증 함수가 iOS 면 `ios:<transaction_id>` 를 준다 —
/// iOS 영수증 문자열은 갱신될 때마다 바뀌어, 문자열로 막으면 같은 거래를 새 영수증으로 다시 내 또 받을 수 있었다.
/// null 이면(안드로이드·옛 함수) 호출부가 영수증 문자열을 그대로 쓴다.
typedef VerifyOutcome = ({VerifyVerdict verdict, String? purchaseKey});

/// 구글 플레이 영수증 검증기.
///
/// 이미 배포된 Supabase Edge Function(`verify-purchase`)을 호출한다.
/// 검증 로직을 서버에 다시 구현하지 않는 이유: 두 벌이 되면 한쪽만 고쳐져
/// "Edge 는 거부하는데 서버는 통과"가 생긴다.
abstract interface class ReceiptVerifier {
  Future<VerifyOutcome> verify({
    required String productId,
    required String purchaseToken,
    required String userJwt,
    String? transactionId,
  });
}

class EdgeFunctionVerifier implements ReceiptVerifier {
  EdgeFunctionVerifier({
    required this.supabaseUrl,
    required this.anonKey,
    http.Client? client,
  }) : _http = client ?? http.Client();

  final String supabaseUrl;
  final String anonKey;
  final http.Client _http;

  @override
  Future<VerifyOutcome> verify({
    required String productId,
    required String purchaseToken,
    required String userJwt,
    String? transactionId,
  }) async {
    try {
      final res = await _http.post(
        Uri.parse('$supabaseUrl/functions/v1/verify-purchase'),
        headers: {
          'apikey': anonKey,
          // 사용자 JWT 를 그대로 전달 — 함수가 소유자를 판단해야 하므로.
          'Authorization': 'Bearer $userJwt',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'productId': productId,
          'purchaseToken': purchaseToken,
          // iOS 거래 id(1.0.28 앱부터) — 함수가 그 거래를 정확히 골라 거래 키를 돌려준다.
          if (transactionId != null && transactionId.isNotEmpty)
            'transactionId': transactionId,
        }),
      );
      final body = jsonDecode(res.body);
      if (body is Map && body['ok'] == true) {
        final key = body['purchaseKey'];
        return (
          verdict: VerifyVerdict.valid,
          purchaseKey: key is String && key.isNotEmpty ? key : null,
        );
      }

      final reason = (body is Map ? body['reason'] : null)?.toString();
      // 확정적으로 가짜인 경우만 invalid. 나머지는 재시도 여지를 남긴다.
      const fatal = {'invalid', 'owned_by_other'};
      if (reason != null && fatal.contains(reason)) {
        return (verdict: VerifyVerdict.invalid, purchaseKey: null);
      }
      return (verdict: VerifyVerdict.unknown, purchaseKey: null);
    } catch (_) {
      return (verdict: VerifyVerdict.unknown, purchaseKey: null);
    }
  }
}

/// 테스트·개발용 — 항상 같은 판정을 돌려준다.
class FixedVerifier implements ReceiptVerifier {
  const FixedVerifier(this.verdict, {this.purchaseKey});
  final VerifyVerdict verdict;
  final String? purchaseKey;

  @override
  Future<VerifyOutcome> verify({
    required String productId,
    required String purchaseToken,
    required String userJwt,
    String? transactionId,
  }) async => (verdict: verdict, purchaseKey: purchaseKey);
}
