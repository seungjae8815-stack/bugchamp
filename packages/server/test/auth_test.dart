import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:server/src/auth.dart';
import 'package:test/test.dart';

const _secret = 'super-secret-for-tests-only';
final _t0 = DateTime.utc(2026, 7, 20, 12, 0, 0);

String _b64(Object o) =>
    base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');

/// 테스트용 토큰 생성. [secret] 을 바꾸면 위조 토큰이 된다.
String makeToken({
  Map<String, dynamic>? header,
  Map<String, dynamic>? payload,
  String secret = _secret,
  bool corruptSignature = false,
}) {
  final h = _b64(header ?? {'alg': 'HS256', 'typ': 'JWT'});
  final p = _b64(
    payload ??
        {
          'sub': 'user-1',
          'iss': 'https://proj.supabase.co/auth/v1',
          'exp':
              _t0.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
        },
  );
  final sig = Hmac(sha256, utf8.encode(secret)).convert(utf8.encode('$h.$p'));
  var s = base64Url.encode(sig.bytes).replaceAll('=', '');
  if (corruptSignature) {
    s = s.replaceRange(0, 1, s[0] == 'A' ? 'B' : 'A');
  }
  return '$h.$p.$s';
}

void main() {
  final verifier = SupabaseJwtVerifier(
    jwtSecret: _secret,
    expectedIssuer: 'https://proj.supabase.co/auth/v1',
  );

  group('정상 토큰', () {
    test('유효한 토큰은 통과하고 sub 를 돌려준다', () {
      final r = verifier.verify(makeToken(), now: _t0);
      expect(r.isOk, isTrue);
      expect(r.user!.id, 'user-1');
      expect(r.user!.isAnonymous, isFalse);
    });

    test('is_anonymous 클레임을 읽는다', () {
      final r = verifier.verify(
        makeToken(
          payload: {
            'sub': 'anon-1',
            'iss': 'https://proj.supabase.co/auth/v1',
            'is_anonymous': true,
            'exp':
                _t0.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
                1000,
          },
        ),
        now: _t0,
      );
      expect(r.isOk, isTrue);
      expect(r.user!.isAnonymous, isTrue);
    });

    test('Bearer 헤더 형태도 처리한다', () {
      final r = verifier.verifyHeader('Bearer ${makeToken()}', now: _t0);
      expect(r.isOk, isTrue);
    });
  });

  group('위조 차단', () {
    test('다른 시크릿으로 서명한 토큰은 거부', () {
      final r = verifier.verify(makeToken(secret: 'wrong-secret'), now: _t0);
      expect(r.isOk, isFalse);
      expect(r.failure, AuthFailure.badSignature);
    });

    test('서명을 한 글자만 바꿔도 거부', () {
      final r = verifier.verify(makeToken(corruptSignature: true), now: _t0);
      expect(r.failure, AuthFailure.badSignature);
    });

    test('페이로드를 바꿔치기하면 거부 (다른 사람으로 위장 시도)', () {
      final good = makeToken();
      final parts = good.split('.');
      // sub 만 admin 으로 바꾸고 서명은 그대로 → 서명 불일치여야 한다.
      final evil = _b64({
        'sub': 'admin',
        'iss': 'https://proj.supabase.co/auth/v1',
        'exp': _t0.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
      });
      final r = verifier.verify('${parts[0]}.$evil.${parts[2]}', now: _t0);
      expect(r.failure, AuthFailure.badSignature);
    });

    test('alg: none 공격 거부', () {
      final h = _b64({'alg': 'none', 'typ': 'JWT'});
      final p = _b64({'sub': 'admin', 'exp': 9999999999});
      final r = verifier.verify('$h.$p.', now: _t0);
      expect(r.failure, AuthFailure.badAlgorithm);
    });

    test('다른 알고리즘(RS256) 주장도 거부', () {
      final r = verifier.verify(
        makeToken(header: {'alg': 'RS256', 'typ': 'JWT'}),
        now: _t0,
      );
      expect(r.failure, AuthFailure.badAlgorithm);
    });
  });

  group('시간·발급자 검사', () {
    test('만료된 토큰 거부', () {
      final r = verifier.verify(
        makeToken(
          payload: {
            'sub': 'user-1',
            'iss': 'https://proj.supabase.co/auth/v1',
            'exp':
                _t0
                    .subtract(const Duration(seconds: 1))
                    .millisecondsSinceEpoch ~/
                1000,
          },
        ),
        now: _t0,
      );
      expect(r.failure, AuthFailure.expired);
    });

    test('만료 직전은 통과', () {
      final r = verifier.verify(
        makeToken(
          payload: {
            'sub': 'user-1',
            'iss': 'https://proj.supabase.co/auth/v1',
            'exp':
                _t0.add(const Duration(seconds: 1)).millisecondsSinceEpoch ~/
                1000,
          },
        ),
        now: _t0,
      );
      expect(r.isOk, isTrue);
    });

    test('nbf 이전은 거부', () {
      final r = verifier.verify(
        makeToken(
          payload: {
            'sub': 'user-1',
            'iss': 'https://proj.supabase.co/auth/v1',
            'nbf':
                _t0.add(const Duration(minutes: 5)).millisecondsSinceEpoch ~/
                1000,
            'exp':
                _t0.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
                1000,
          },
        ),
        now: _t0,
      );
      expect(r.failure, AuthFailure.notYetValid);
    });

    test('다른 프로젝트가 발급한 토큰 거부', () {
      final r = verifier.verify(
        makeToken(
          payload: {
            'sub': 'user-1',
            'iss': 'https://other.supabase.co/auth/v1',
            'exp':
                _t0.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
                1000,
          },
        ),
        now: _t0,
      );
      expect(r.failure, AuthFailure.wrongIssuer);
    });
  });

  group('형식 오류', () {
    test('헤더 없음 / Bearer 아님', () {
      expect(verifier.verifyHeader(null).failure, AuthFailure.missing);
      expect(verifier.verifyHeader('Basic abc').failure, AuthFailure.missing);
    });

    test('점 개수가 다르면 거부', () {
      expect(verifier.verify('a.b').failure, AuthFailure.malformed);
      expect(verifier.verify('a.b.c.d').failure, AuthFailure.malformed);
    });

    test('base64 가 깨졌으면 거부', () {
      expect(verifier.verify('!!!.???.***').failure, AuthFailure.malformed);
    });

    test('sub 가 없으면 거부', () {
      final r = verifier.verify(
        makeToken(
          payload: {
            'iss': 'https://proj.supabase.co/auth/v1',
            'exp':
                _t0.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
                1000,
          },
        ),
        now: _t0,
      );
      expect(r.failure, AuthFailure.noSubject);
    });
  });
}
