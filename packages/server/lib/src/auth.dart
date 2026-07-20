import 'dart:convert';

import 'package:jose/jose.dart';
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
/// (공격자에게 어디까지 맞았는지 알려주지 않기 위해) — 로그용이다.
enum AuthFailure {
  missing,
  malformed,
  badAlgorithm,
  badSignature,
  expired,
  notYetValid,
  wrongIssuer,
  noSubject,
  keysUnavailable,
}

class AuthResult {
  const AuthResult.ok(this.user) : failure = null;
  const AuthResult.fail(this.failure) : user = null;

  final AuthedUser? user;
  final AuthFailure? failure;

  bool get isOk => user != null;
}

/// Supabase JWT 검증기 (**비대칭 ES256 / JWKS**).
///
/// Supabase 는 2025년 이후 프로젝트별 **비대칭 서명키**(ECC P-256, ES256)를 쓴다.
/// 서버는 `/auth/v1/.well-known/jwks.json` 의 **공개키**로 서명을 검증한다.
///
/// 대칭키(HS256) 방식보다 나은 점: **서버가 비밀을 들고 있지 않아도 된다.**
/// 공유 시크릿 방식이면 그 값을 아는 쪽은 누구든 임의의 사용자로 위장할 수
/// 있으므로, 서버가 유출되면 곧바로 전면 위조가 가능하다. 공개키만 두면
/// 서버가 털려도 토큰을 만들어낼 수는 없다.
///
/// ⚠️ **HS256 토큰은 받지 않는다.** 레거시 공유 시크릿이 남아 있어도
/// (이 프로젝트는 5일 전 교체됨) 그것으로 서명된 토큰을 받아주면
/// 알고리즘 다운그레이드 통로가 된다.
class SupabaseJwtVerifier {
  SupabaseJwtVerifier({
    required this.jwksUri,
    required this.expectedIssuer,
    JsonWebKeyStore? store,
  }) : _store = store ?? (JsonWebKeyStore()..addKeySetUrl(jwksUri));

  /// `https://<project>.supabase.co/auth/v1/.well-known/jwks.json`
  final Uri jwksUri;

  /// `https://<project>.supabase.co/auth/v1`
  final String expectedIssuer;

  final JsonWebKeyStore _store;

  /// 허용 알고리즘 — 여기 없는 alg 는 서명이 맞아도 거부한다.
  static const _allowedAlgorithms = {'ES256'};

  /// 프로젝트 URL 로부터 검증기를 만든다.
  factory SupabaseJwtVerifier.forProject(String supabaseUrl) {
    final base = supabaseUrl.endsWith('/')
        ? supabaseUrl.substring(0, supabaseUrl.length - 1)
        : supabaseUrl;
    return SupabaseJwtVerifier(
      jwksUri: Uri.parse('$base/auth/v1/.well-known/jwks.json'),
      expectedIssuer: '$base/auth/v1',
    );
  }

  /// `Authorization: Bearer <token>` 헤더를 검증한다.
  Future<AuthResult> verifyHeader(String? header, {DateTime? now}) async {
    if (header == null || !header.startsWith('Bearer ')) {
      return const AuthResult.fail(AuthFailure.missing);
    }
    return verify(header.substring(7).trim(), now: now);
  }

  Future<AuthResult> verify(String token, {DateTime? now}) async {
    final JsonWebSignature jws;
    try {
      jws = JsonWebSignature.fromCompactSerialization(token);
    } catch (_) {
      return const AuthResult.fail(AuthFailure.malformed);
    }

    // 알고리즘을 서명 검증 **전에** 확인한다 — alg:none 이나 HS256 다운그레이드 차단.
    final alg = jws.commonProtectedHeader.algorithm;
    if (alg == null || !_allowedAlgorithms.contains(alg)) {
      return const AuthResult.fail(AuthFailure.badAlgorithm);
    }

    final JosePayload payload;
    try {
      payload = await jws.getPayload(_store);
    } on JoseException {
      return const AuthResult.fail(AuthFailure.badSignature);
    } catch (_) {
      // JWKS 를 못 받아온 경우 등 — 서명이 틀렸다고 단정하지 않는다.
      return const AuthResult.fail(AuthFailure.keysUnavailable);
    }

    final Map<String, dynamic> claims;
    try {
      claims = jsonDecode(utf8.decode(payload.data)) as Map<String, dynamic>;
    } catch (_) {
      return const AuthResult.fail(AuthFailure.malformed);
    }

    final t = (now ?? DateTime.now().toUtc()).millisecondsSinceEpoch ~/ 1000;
    final exp = (claims['exp'] as num?)?.toInt();
    if (exp != null && t >= exp) {
      return const AuthResult.fail(AuthFailure.expired);
    }
    final nbf = (claims['nbf'] as num?)?.toInt();
    if (nbf != null && t < nbf) {
      return const AuthResult.fail(AuthFailure.notYetValid);
    }
    if (claims['iss'] != expectedIssuer) {
      return const AuthResult.fail(AuthFailure.wrongIssuer);
    }

    final sub = claims['sub'];
    if (sub is! String || sub.isEmpty) {
      return const AuthResult.fail(AuthFailure.noSubject);
    }

    // Supabase 는 익명 로그인에 is_anonymous 클레임을 준다.
    return AuthResult.ok(
      AuthedUser(id: sub, isAnonymous: claims['is_anonymous'] == true),
    );
  }
}
