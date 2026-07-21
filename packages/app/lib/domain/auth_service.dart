import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 계정(로그인) 계약.
///
/// 기본은 **익명 인증**(기기 임시 계정)이라 앱을 지우면 신원이 사라진다.
/// 구글 로그인을 하면 기기가 바뀌어도 같은 계정으로 이어갈 수 있다.
///
/// ⚠️ 세이브 자체는 기기(Hive)에 있으므로 **로그인해도 진행도는 그대로**다.
/// 클라우드 백업/복원은 `CloudSaveService` 가 담당한다.
abstract interface class AuthService {
  /// 구글 로그인을 쓸 수 있는 환경인지(Supabase + 웹 클라이언트 ID 주입됨).
  bool get available;

  /// 익명이 아닌 실제 계정으로 로그인돼 있는지.
  bool get isSignedIn;

  /// 표시용 계정 이름(이메일). 미로그인/익명이면 null.
  String? get accountLabel;

  /// 구글 로그인. 성공 시 true. 사용자가 취소하면 false.
  Future<bool> signInWithGoogle();

  /// Apple 로그인(iOS). Apple 4.8 대응 — 제3자 로그인이 있으면 프라이버시
  /// 로그인도 함께 제공해야 한다. 성공 시 true, 취소 시 false.
  Future<bool> signInWithApple();

  /// Apple 로그인을 쓸 수 있는 환경인지(iOS 등 지원 플랫폼).
  bool get appleAvailable;

  /// 로그아웃 → 다시 익명 계정으로 돌아간다(로컬 세이브는 유지).
  Future<void> signOut();

  /// **계정과 서버 데이터를 영구 삭제**한다. 성공 시 true.
  ///
  /// 서버 쪽은 RPC `delete_my_account()` 한 번으로 끝난다 — `profiles`·
  /// `defenders`·`saves` 가 모두 `auth.users` 에 `on delete cascade` 로 걸려
  /// 있어 인증 계정을 지우면 함께 지워진다(SQL 은 docs/backend_supabase.md §6).
  ///
  /// ⚠️ 되돌릴 수 없다. 로컬 세이브 초기화는 **호출부 책임**이다
  /// (서버 삭제가 실패했는데 로컬만 날리는 일이 없도록 분리해 둔다).
  Future<bool> deleteAccount();
}

/// 백엔드 미연결 — 로그인 불가.
class NoAuthService implements AuthService {
  const NoAuthService();

  @override
  bool get available => false;
  @override
  bool get isSignedIn => false;
  @override
  String? get accountLabel => null;
  @override
  Future<bool> signInWithGoogle() async => false;
  @override
  Future<bool> signInWithApple() async => false;
  @override
  bool get appleAvailable => false;
  @override
  Future<void> signOut() async {}

  /// 서버가 없으므로 지울 서버 데이터도 없다(로컬 초기화는 호출부가 한다).
  @override
  Future<bool> deleteAccount() async => true;
}

/// Supabase + 네이티브 구글 로그인(google_sign_in) 구현.
///
/// 흐름: 구글에서 idToken 발급 → `signInWithIdToken` 으로 Supabase 세션 교환.
/// 웹 클라이언트 ID 는 `--dart-define-from-file=supabase.env.json` 의
/// `GOOGLE_WEB_CLIENT_ID` 로 주입한다(코드/깃에 넣지 않는다).
class SupabaseAuthService implements AuthService {
  SupabaseAuthService(this._client, this._webClientId);

  final SupabaseClient _client;
  final String _webClientId;
  bool _initialized = false;

  @override
  bool get available => _webClientId.isNotEmpty;

  @override
  bool get isSignedIn {
    final u = _client.auth.currentUser;
    return u != null && u.isAnonymous != true;
  }

  @override
  String? get accountLabel {
    final u = _client.auth.currentUser;
    if (u == null || u.isAnonymous == true) return null;
    return u.email ?? u.userMetadata?['name'] as String?;
  }

  Future<void> _ensureInit() async {
    if (_initialized) return;
    await GoogleSignIn.instance.initialize(serverClientId: _webClientId);
    _initialized = true;
  }

  @override
  Future<bool> signInWithGoogle() async {
    if (!available) return false;
    try {
      await _ensureInit();
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        debugPrint('google sign-in: idToken 없음');
        return false;
      }
      await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
      return true;
    } on GoogleSignInException catch (e) {
      // 사용자가 취소한 경우도 여기로 온다 — 실패로 조용히 처리.
      debugPrint('google sign-in cancelled/failed: ${e.code}');
      return false;
    } catch (e) {
      debugPrint('google sign-in error: $e');
      return false;
    }
  }

  @override
  bool get appleAvailable => available && !kIsWeb && Platform.isIOS;

  @override
  Future<bool> signInWithApple() async {
    if (!appleAvailable) return false;
    try {
      // nonce: 원문을 SHA256 해서 Apple 에 넘기고, 원문을 Supabase 에 넘긴다.
      // Supabase 가 토큰 속 해시와 원문을 대조해 재생공격을 막는다.
      final rawNonce = _randomNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

      final cred = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );
      final idToken = cred.identityToken;
      if (idToken == null) {
        debugPrint('apple sign-in: identityToken 없음');
        return false;
      }
      await _client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );
      return true;
    } on SignInWithAppleAuthorizationException catch (e) {
      // 취소 포함 — 조용히 실패.
      debugPrint('apple sign-in cancelled/failed: ${e.code}');
      return false;
    } catch (e) {
      debugPrint('apple sign-in error: $e');
      return false;
    }
  }

  /// 암호학적으로 안전한 nonce(Apple 로그인 재생공격 방지).
  String _randomNonce([int length = 32]) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._';
    final rng = Random.secure();
    return List.generate(
      length,
      (_) => chars[rng.nextInt(chars.length)],
    ).join();
  }

  @override
  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    try {
      await _client.auth.signOut();
      // 로그아웃 후에도 랭킹/방어팀이 동작하도록 익명으로 복귀.
      await _client.auth.signInAnonymously();
    } catch (e) {
      debugPrint('sign out error: $e');
    }
  }

  @override
  Future<bool> deleteAccount() async {
    if (_client.auth.currentUser == null) return true; // 지울 계정이 없음
    try {
      // SECURITY DEFINER RPC — 클라이언트 권한으로는 auth.users 를 못 지운다.
      await _client.rpc<void>('delete_my_account');
    } catch (e) {
      debugPrint('deleteAccount RPC 실패: $e');
      return false; // 실패를 감추지 않는다 — 호출부가 로컬을 보존해야 한다.
    }
    // 서버 계정이 사라졌으니 세션을 정리하고 새 익명 계정으로 시작한다.
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    try {
      await _client.auth.signOut();
      await _client.auth.signInAnonymously();
    } catch (e) {
      // 세션 정리 실패는 삭제 성공 자체를 무르지 않는다(데이터는 이미 지워짐).
      debugPrint('deleteAccount 세션 정리 경고: $e');
    }
    return true;
  }
}

/// 교체 가능한 인증 제공자. 기본은 미연결(익명만).
final authServiceProvider = Provider<AuthService>(
  (ref) => const NoAuthService(),
);
