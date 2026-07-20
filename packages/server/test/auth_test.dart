import 'dart:convert';

import 'package:jose/jose.dart';
import 'package:server/src/auth.dart';
import 'package:test/test.dart';

final t0 = DateTime.utc(2026, 7, 20, 12, 0, 0);
const issuer = 'https://proj.supabase.co/auth/v1';

/// 테스트용 ES256 키 한 쌍. 실제 Supabase 키셋과 같은 형태(EC P-256).
final signingKey = JsonWebKey.generate('ES256');

/// 공격자가 쓰는 다른 키 — 이걸로 서명한 토큰은 거부돼야 한다.
final attackerKey = JsonWebKey.generate('ES256');

/// [key] 로 서명한 JWT 를 만든다.
///
/// ⚠️ 기본 만료는 **실제 현재 시각 기준**이다. 고정 시각(t0)으로 두면
/// 미들웨어가 실시간으로 검증하는 테스트(엔드포인트 테스트)가 그 시각을
/// 지나는 순간 갑자기 깨진다 — 실제로 그렇게 깨졌다.
/// 만료 자체를 검사하는 테스트는 claims 를 직접 넘기고 verify(now:) 를 쓴다.
String makeToken({
  JsonWebKey? key,
  Map<String, dynamic>? claims,
  String algorithm = 'ES256',
}) {
  final builder = JsonWebSignatureBuilder()
    ..jsonContent =
        claims ??
        {
          'sub': 'user-1',
          'iss': issuer,
          'exp':
              DateTime.now()
                  .add(const Duration(hours: 1))
                  .millisecondsSinceEpoch ~/
              1000,
        }
    ..addRecipient(key ?? signingKey, algorithm: algorithm);
  return builder.build().toCompactSerialization();
}

/// 서명키의 **공개키만** 담은 키스토어 — 서버가 보는 것과 같은 상태.
JsonWebKeyStore publicStore(JsonWebKey key) {
  final pub = Map<String, dynamic>.from(key.toJson())..remove('d');
  return JsonWebKeyStore()..addKey(JsonWebKey.fromJson(pub));
}

SupabaseJwtVerifier verifierFor(JsonWebKey key) => SupabaseJwtVerifier(
  jwksUri: Uri.parse('https://proj.supabase.co/auth/v1/.well-known/jwks.json'),
  expectedIssuer: issuer,
  store: publicStore(key),
);

void main() {
  final verifier = verifierFor(signingKey);

  group('정상 토큰', () {
    test('유효한 ES256 토큰은 통과하고 sub 를 돌려준다', () async {
      final r = await verifier.verify(makeToken(), now: t0);
      expect(r.isOk, isTrue);
      expect(r.user!.id, 'user-1');
      expect(r.user!.isAnonymous, isFalse);
    });

    test('is_anonymous 클레임을 읽는다', () async {
      final r = await verifier.verify(
        makeToken(
          claims: {
            'sub': 'anon-1',
            'iss': issuer,
            'is_anonymous': true,
            'exp':
                t0.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
          },
        ),
        now: t0,
      );
      expect(r.isOk, isTrue);
      expect(r.user!.isAnonymous, isTrue);
    });

    test('Bearer 헤더 형태도 처리한다', () async {
      final r = await verifier.verifyHeader('Bearer ${makeToken()}', now: t0);
      expect(r.isOk, isTrue);
    });
  });

  group('위조 차단', () {
    test('다른 키로 서명한 토큰은 거부', () async {
      final r = await verifier.verify(makeToken(key: attackerKey), now: t0);
      expect(r.isOk, isFalse);
      expect(r.failure, AuthFailure.badSignature);
    });

    test('페이로드를 바꿔치기하면 거부 (다른 사람으로 위장 시도)', () async {
      final parts = makeToken().split('.');
      final evil = base64Url
          .encode(
            utf8.encode(
              jsonEncode({
                'sub': 'admin',
                'iss': issuer,
                'exp':
                    t0.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
                    1000,
              }),
            ),
          )
          .replaceAll('=', '');
      final r = await verifier.verify('${parts[0]}.$evil.${parts[2]}', now: t0);
      expect(r.failure, AuthFailure.badSignature);
    });

    test('alg: none 공격 거부', () async {
      final h = base64Url
          .encode(utf8.encode(jsonEncode({'alg': 'none', 'typ': 'JWT'})))
          .replaceAll('=', '');
      final p = base64Url
          .encode(utf8.encode(jsonEncode({'sub': 'admin', 'exp': 9999999999})))
          .replaceAll('=', '');
      final r = await verifier.verify('$h.$p.', now: t0);
      expect(r.failure, AuthFailure.badAlgorithm);
    });

    test('HS256 다운그레이드 거부 (레거시 공유 시크릿 통로 차단)', () async {
      // 레거시 시크릿을 손에 넣은 공격자가 HS256 으로 서명해도 받으면 안 된다.
      final hs = JsonWebKey.fromJson({
        'kty': 'oct',
        'k': base64Url
            .encode(utf8.encode('leaked-legacy-secret'))
            .replaceAll('=', ''),
      });
      final token = makeToken(key: hs, algorithm: 'HS256');
      final r = await verifier.verify(token, now: t0);
      expect(r.failure, AuthFailure.badAlgorithm);
    });
  });

  group('시간·발급자 검사', () {
    test('만료된 토큰 거부', () async {
      final r = await verifier.verify(
        makeToken(
          claims: {
            'sub': 'user-1',
            'iss': issuer,
            'exp':
                t0
                    .subtract(const Duration(seconds: 1))
                    .millisecondsSinceEpoch ~/
                1000,
          },
        ),
        now: t0,
      );
      expect(r.failure, AuthFailure.expired);
    });

    test('만료 직전은 통과', () async {
      final r = await verifier.verify(
        makeToken(
          claims: {
            'sub': 'user-1',
            'iss': issuer,
            'exp':
                t0.add(const Duration(seconds: 1)).millisecondsSinceEpoch ~/
                1000,
          },
        ),
        now: t0,
      );
      expect(r.isOk, isTrue);
    });

    test('nbf 이전은 거부', () async {
      final r = await verifier.verify(
        makeToken(
          claims: {
            'sub': 'user-1',
            'iss': issuer,
            'nbf':
                t0.add(const Duration(minutes: 5)).millisecondsSinceEpoch ~/
                1000,
            'exp':
                t0.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
          },
        ),
        now: t0,
      );
      expect(r.failure, AuthFailure.notYetValid);
    });

    test('다른 프로젝트가 발급한 토큰 거부', () async {
      final r = await verifier.verify(
        makeToken(
          claims: {
            'sub': 'user-1',
            'iss': 'https://other.supabase.co/auth/v1',
            'exp':
                t0.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
          },
        ),
        now: t0,
      );
      expect(r.failure, AuthFailure.wrongIssuer);
    });
  });

  group('형식 오류', () {
    test('헤더 없음 / Bearer 아님', () async {
      expect((await verifier.verifyHeader(null)).failure, AuthFailure.missing);
      expect(
        (await verifier.verifyHeader('Basic abc')).failure,
        AuthFailure.missing,
      );
    });

    test('JWT 형태가 아니면 거부', () async {
      expect((await verifier.verify('a.b')).failure, AuthFailure.malformed);
      expect((await verifier.verify('!!!')).failure, AuthFailure.malformed);
    });

    test('sub 가 없으면 거부', () async {
      final r = await verifier.verify(
        makeToken(
          claims: {
            'iss': issuer,
            'exp':
                t0.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
          },
        ),
        now: t0,
      );
      expect(r.failure, AuthFailure.noSubject);
    });
  });

  group('프로젝트 URL 로부터 구성', () {
    test('JWKS·발급자 주소를 올바로 만든다', () {
      final v = SupabaseJwtVerifier.forProject('https://abc.supabase.co');
      expect(
        v.jwksUri.toString(),
        'https://abc.supabase.co/auth/v1/.well-known/jwks.json',
      );
      expect(v.expectedIssuer, 'https://abc.supabase.co/auth/v1');
    });

    test('끝의 슬래시를 정리한다', () {
      final v = SupabaseJwtVerifier.forProject('https://abc.supabase.co/');
      expect(v.expectedIssuer, 'https://abc.supabase.co/auth/v1');
    });
  });
}
