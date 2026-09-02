import 'dart:io' show Platform;

import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:flutter/foundation.dart';

/// Meta(인스타·페북) 앱 설치 광고 측정.
///
/// **왜 SDK 가 필요한가**: 메타는 "이 설치가 우리 광고를 보고 일어났는가"를
/// 앱이 보내는 신호로만 안다. 없으면 캠페인이 최적화될 근거가 없어
/// 노출만 사는 꼴이 된다(§UA, 2026-09-02).
///
/// ⚠️ 여기서 보내는 것은 **전환 신호뿐**이다. 닉네임·이메일·세이브 같은
/// 개인 데이터는 보내지 않는다 — 광고 최적화에 필요 없고, 보내는 순간
/// 개인정보 처리방침과 스토어 신고서를 함께 고쳐야 한다.
class MarketingService {
  MarketingService._();

  static final MarketingService instance = MarketingService._();

  final _fb = FacebookAppEvents();
  bool _ready = false;

  bool get _supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// 앱 시작 시 1회. 실패해도 게임은 그대로 돌아야 하므로 절대 던지지 않는다.
  Future<void> init() async {
    if (!_supported || _ready) return;
    try {
      // 자동 이벤트(설치·실행)는 SDK 가 알아서 보낸다. 광고 ID 수집은 iOS 에서
      // ATT 를 거부하면 SDK 가 스스로 멈춘다 — 앱이 따로 막을 필요가 없다.
      await _fb.setAutoLogAppEventsEnabled(true);
      _ready = true;
    } catch (e) {
      debugPrint('[ua] 초기화 실패(무시): $e');
    }
  }

  /// 결제 완료. **서버 검증을 통과한 뒤에만** 부른다 — 취소·위조 영수증까지
  /// 세면 메타가 가짜 구매자를 닮은 사람에게 광고를 돌린다.
  Future<void> logPurchase({
    required double amount,
    required String currency,
    required String productId,
  }) async {
    if (!_ready || amount <= 0) return;
    try {
      await _fb.logPurchase(
        amount: amount,
        currency: currency,
        parameters: {'product': productId},
      );
    } catch (e) {
      debugPrint('[ua] 구매 이벤트 실패(무시): $e');
    }
  }

  /// 첫 관문 통과(튜토리얼 격). 설치 직후 이탈과 진짜 유저를 가르는 신호라
  /// 캠페인 초반 학습에 가장 크게 기여한다.
  Future<void> logTutorialComplete() => _log('fb_mobile_tutorial_completion');

  /// 회차 전환 — 오래 남는 유저의 표식.
  Future<void> logLevelUp(int tier) =>
      _log('fb_mobile_level_achieved', {'level': tier});

  Future<void> _log(String name, [Map<String, dynamic>? params]) async {
    if (!_ready) return;
    try {
      await _fb.logEvent(name: name, parameters: params);
    } catch (e) {
      debugPrint('[ua] 이벤트 실패(무시): $e');
    }
  }
}
