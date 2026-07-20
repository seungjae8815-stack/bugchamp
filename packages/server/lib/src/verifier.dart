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

/// 구글 플레이 영수증 검증기.
///
/// 이미 배포된 Supabase Edge Function(`verify-purchase`)을 호출한다.
/// 검증 로직을 서버에 다시 구현하지 않는 이유: 두 벌이 되면 한쪽만 고쳐져
/// "Edge 는 거부하는데 서버는 통과"가 생긴다.
abstract interface class ReceiptVerifier {
  Future<VerifyVerdict> verify({
    required String productId,
    required String purchaseToken,
    required String userJwt,
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
  Future<VerifyVerdict> verify({
    required String productId,
    required String purchaseToken,
    required String userJwt,
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
        }),
      );
      final body = jsonDecode(res.body);
      if (body is Map && body['ok'] == true) return VerifyVerdict.valid;

      final reason = (body is Map ? body['reason'] : null)?.toString();
      // 확정적으로 가짜인 경우만 invalid. 나머지는 재시도 여지를 남긴다.
      const fatal = {'invalid', 'owned_by_other'};
      if (reason != null && fatal.contains(reason))
        return VerifyVerdict.invalid;
      return VerifyVerdict.unknown;
    } catch (_) {
      return VerifyVerdict.unknown;
    }
  }
}

/// 테스트·개발용 — 항상 같은 판정을 돌려준다.
class FixedVerifier implements ReceiptVerifier {
  const FixedVerifier(this.verdict);
  final VerifyVerdict verdict;

  @override
  Future<VerifyVerdict> verify({
    required String productId,
    required String purchaseToken,
    required String userJwt,
  }) async => verdict;
}
