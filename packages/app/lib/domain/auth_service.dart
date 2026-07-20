import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
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

  /// 로그아웃 → 다시 익명 계정으로 돌아간다(로컬 세이브는 유지).
  Future<void> signOut();
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
  Future<void> signOut() async {}
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
}

/// 교체 가능한 인증 제공자. 기본은 미연결(익명만).
final authServiceProvider = Provider<AuthService>(
  (ref) => const NoAuthService(),
);
