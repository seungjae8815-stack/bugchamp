import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';

/// 검증된 호출자.
@immutable
class AuthedUser {
  const AuthedUser({required this.id, required this.isAnonymous});

  /// Supabase `auth.users.id` (JWT 의 `sub`). **모든 데이터의 소유자 키.**
  final String id;

  /// 익명 계정인지(구글 로그인 전).
  final bool isAnonymous;
}

/// JWT 검증 실패 사유. 클라이언트에는 세부 사유를 돌려주지 않는다
/// (공격자에게 힌트를 주지 않기 위해) — 로그용이다.
enum AuthFailure {
  missing,
  malformed,
  badAlgorithm,
  badSignature,
  expired,
  notYetValid,
  wrongIssuer,
  noSubject,
}

class AuthResult {
  const AuthResult.ok(this.user) : failure = null;
  const AuthResult.fail(this.failure) : user = null;

  final AuthedUser? user;
  final AuthFailure? failure;

  bool get isOk => user != null;
}

/// Supabase JWT(HS256) 검증기.
///
/// Supabase 는 프로젝트별 **JWT 시크릿**으로 토큰을 HMAC-SHA256 서명한다.
/// 그 시크릿을 아는 쪽만 유효한 토큰을 만들 수 있으므로, 서명이 맞으면
/// "Supabase 가 발급한 토큰"임이 보장된다.
///
/// ⚠️ 시크릿은 **서버 환경변수로만** 주입한다. 앱이나 저장소에 두면 안 된다
/// (알고 있으면 아무 사용자로도 위장할 수 있다).
class SupabaseJwtVerifier {
  SupabaseJwtVerifier({required String jwtSecret, this.expectedIssuer})
    : _key = utf8.encode(jwtSecret);

  final List<int> _key;

  /// `https://<project>.supabase.co/auth/v1` — 지정하면 iss 도 검사한다.
  final String? expectedIssuer;

  /// `Authorization: Bearer <token>` 헤더를 검증한다.
  AuthResult verifyHeader(String? header, {DateTime? now}) {
    if (header == null || !header.startsWith('Bearer ')) {
      return const AuthResult.fail(AuthFailure.missing);
    }
    return verify(header.substring(7).trim(), now: now);
  }

  AuthResult verify(String token, {DateTime? now}) {
    final parts = token.split('.');
    if (parts.length != 3) {
      return const AuthResult.fail(AuthFailure.malformed);
    }

    final Map<String, dynamic> header;
    final Map<String, dynamic> payload;
    try {
      header = _decodeSegment(parts[0]);
      payload = _decodeSegment(parts[1]);
    } catch (_) {
      return const AuthResult.fail(AuthFailure.malformed);
    }

    // 알고리즘 고정 — `alg: none` 이나 비대칭 혼동 공격을 막는다.
    if (header['alg'] != 'HS256') {
      return const AuthResult.fail(AuthFailure.badAlgorithm);
    }

    // 서명 검증. 상수시간 비교로 타이밍 공격을 피한다.
    final signing = utf8.encode('${parts[0]}.${parts[1]}');
    final expected = Hmac(sha256, _key).convert(signing).bytes;
    final actual = _decodeBytes(parts[2]);
    if (actual == null || !_constantTimeEquals(expected, actual)) {
      return const AuthResult.fail(AuthFailure.badSignature);
    }

    final t = (now ?? DateTime.now().toUtc()).millisecondsSinceEpoch ~/ 1000;
    final exp = (payload['exp'] as num?)?.toInt();
    if (exp != null && t >= exp) {
      return const AuthResult.fail(AuthFailure.expired);
    }
    final nbf = (payload['nbf'] as num?)?.toInt();
    if (nbf != null && t < nbf) {
      return const AuthResult.fail(AuthFailure.notYetValid);
    }

    final iss = expectedIssuer;
    if (iss != null && payload['iss'] != iss) {
      return const AuthResult.fail(AuthFailure.wrongIssuer);
    }

    final sub = payload['sub'];
    if (sub is! String || sub.isEmpty) {
      return const AuthResult.fail(AuthFailure.noSubject);
    }

    // Supabase 는 익명 로그인에 is_anonymous 클레임을 준다.
    final anon = payload['is_anonymous'] == true;
    return AuthResult.ok(AuthedUser(id: sub, isAnonymous: anon));
  }

  static Map<String, dynamic> _decodeSegment(String seg) {
    final bytes = _decodeBytes(seg);
    if (bytes == null) throw const FormatException('bad base64url');
    return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  }

  static List<int>? _decodeBytes(String seg) {
    var s = seg.replaceAll('-', '+').replaceAll('_', '/');
    switch (s.length % 4) {
      case 2:
        s += '==';
      case 3:
        s += '=';
      case 1:
        return null; // 유효한 base64 가 아님
    }
    try {
      return base64.decode(s);
    } catch (_) {
      return null;
    }
  }

  /// 길이·내용 비교를 상수시간으로 — 서명 비교에서 조기 반환하면
  /// 응답 시간 차이로 서명을 한 바이트씩 맞춰갈 수 있다.
  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
