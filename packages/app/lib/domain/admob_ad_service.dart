import 'dart:async';
import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_service.dart';

/// AdMob 보상형 광고 구현.
///
/// 광고 단위 ID 는 빌드 인자로 주입한다(계정마다 다르므로 코드에 박지 않는다):
///   --dart-define=ADMOB_REWARDED_ANDROID=ca-app-pub-xxx/yyy
/// 주입이 없으면 **구글 공식 테스트 단위**를 쓴다 — 개발 중에 실광고를 눌러
/// 계정이 정지되는 사고를 막기 위해서다.
class AdMobAdService implements AdService {
  AdMobAdService();

  /// 구글이 공개한 테스트 전용 보상형 광고 단위. 실계정 정책 위반이 아니다.
  static const _testRewardedAndroid = 'ca-app-pub-3940256099942544/5224354917';
  static const _testRewardedIos = 'ca-app-pub-3940256099942544/1712485313';

  static const _rewardedAndroid = String.fromEnvironment(
    'ADMOB_REWARDED_ANDROID',
  );
  static const _rewardedIos = String.fromEnvironment('ADMOB_REWARDED_IOS');

  /// 실제 광고 단위가 주입됐는지(테스트 단위로 도는 중인지 판별용).
  static bool get usingTestUnits =>
      Platform.isIOS ? _rewardedIos.isEmpty : _rewardedAndroid.isEmpty;

  static String get _unitId {
    if (Platform.isIOS) {
      return _rewardedIos.isEmpty ? _testRewardedIos : _rewardedIos;
    }
    return _rewardedAndroid.isEmpty ? _testRewardedAndroid : _rewardedAndroid;
  }

  RewardedAd? _ad;
  bool _loading = false;
  bool _initialized = false;

  @override
  bool get isReal => true;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    // iOS: 광고 IDFA 를 쓰기 전에 App Tracking Transparency 권한을 묻는다.
    // 이 프롬프트가 없으면 심사에서 거절될 수 있다(5.1.2). 거부해도 광고는
    // 나가되(비맞춤), 요청 자체는 반드시 해야 한다.
    await _requestTrackingIfNeeded();
    await MobileAds.instance.initialize();
    preload();
  }

  Future<void> _requestTrackingIfNeeded() async {
    if (kIsWeb || !Platform.isIOS) return;
    try {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
    } catch (e) {
      debugPrint('ATT 요청 실패(무시): $e');
    }
  }

  @override
  void preload() {
    if (_ad != null || _loading) return;
    _loading = true;
    RewardedAd.load(
      adUnitId: _unitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _loading = false;
        },
        onAdFailedToLoad: (err) {
          debugPrint('[ads] 로드 실패: ${err.code} ${err.message}');
          _ad = null;
          _loading = false;
        },
      ),
    );
  }

  @override
  Future<AdResult> showRewarded() async {
    await init();

    // 버튼을 눌렀는데 아직 준비가 안 됐으면 잠깐 기다려 준다.
    if (_ad == null) {
      preload();
      final ok = await _waitForAd(const Duration(seconds: 6));
      if (!ok) return AdResult.notReady;
    }

    final ad = _ad;
    if (ad == null) return AdResult.notReady;
    _ad = null; // 광고 1개는 1회용

    final done = Completer<AdResult>();
    var earned = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        preload(); // 다음 광고 미리 받아두기
        if (!done.isCompleted) {
          done.complete(earned ? AdResult.rewarded : AdResult.dismissed);
        }
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        debugPrint('[ads] 표시 실패: ${err.message}');
        ad.dispose();
        preload();
        if (!done.isCompleted) done.complete(AdResult.failed);
      },
    );

    try {
      await ad.show(
        // 여기서만 보상 자격이 확정된다. 콜백이 안 오면 보상도 없다.
        onUserEarnedReward: (_, _) => earned = true,
      );
    } catch (e) {
      debugPrint('[ads] show 예외: $e');
      if (!done.isCompleted) done.complete(AdResult.failed);
    }

    return done.future;
  }

  /// 로드가 끝날 때까지 [limit] 까지만 기다린다.
  Future<bool> _waitForAd(Duration limit) async {
    const tick = Duration(milliseconds: 200);
    var waited = Duration.zero;
    while (_ad == null && waited < limit) {
      await Future<void>.delayed(tick);
      waited += tick;
      if (!_loading && _ad == null) return false; // 로드가 실패로 끝남
    }
    return _ad != null;
  }

  @override
  void dispose() {
    _ad?.dispose();
    _ad = null;
  }
}
