import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

/// 크래시 수집(Firebase Crashlytics, 2026-09-15).
///
/// 앱이 꺼지는 오류를 모아 운영 봇으로 알린다(Firebase 알림 → Cloud Function → 텔레그램).
/// 예전엔 수집 도구가 없어서, 유저가 문의로 알려 주기 전엔 크래시를 알 방법이 없었다
/// (2026-08-29 R8 사고는 스토어 리뷰로 알았다).
///
/// - **릴리즈 빌드에서만 보낸다.** 개발자 빌드(profile·debug)의 오류가 섞이면 진짜 크래시가 묻힌다.
/// - **초기화 실패로 게임을 막지 않는다.** 설정이 깨져도 게임은 떠야 한다.
bool _ready = false;

Future<void> initCrashReporting() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    final c = FirebaseCrashlytics.instance;
    await c.setCrashlyticsCollectionEnabled(kReleaseMode);
    // 프레임워크 오류(빌드·레이아웃 등)와 비동기로 새는 오류를 모두 잡는다.
    FlutterError.onError = c.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      c.recordError(error, stack, fatal: true);
      return true;
    };
    _ready = true;
  } catch (e) {
    debugPrint('crash reporting init failed: $e');
  }
}

/// 크래시에 계정을 붙인다 — 문의가 오면 그 유저의 크래시를 바로 찾을 수 있게.
/// 개인정보가 아니라 **계정 uuid** 만 넣는다.
Future<void> setCrashUser(String? userId) async {
  if (!_ready || userId == null || userId.isEmpty) return;
  try {
    await FirebaseCrashlytics.instance.setUserIdentifier(userId);
  } catch (_) {
    /* 수집 보조 정보라 실패해도 무시 */
  }
}
