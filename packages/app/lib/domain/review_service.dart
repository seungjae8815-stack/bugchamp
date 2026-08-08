import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';

import 'save_controller.dart';

/// App Store 앱 id(숫자). **iOS 에서 스토어 페이지를 열려면 반드시 필요**하다 —
/// 없으면 `openStoreListing` 이 조용히 아무 일도 하지 않아 버튼이 고장난 것처럼
/// 보인다.
///
/// 비밀이 아니라 앱스토어 URL 에 그대로 드러나는 공개 값이라 기본값으로 둔다
/// (플레이스토어 주소를 `update_checker.dart` 에 박아둔 것과 같은 이유).
/// CI 변수를 깜빡해도 동작하고, 필요하면 `--dart-define=APP_STORE_ID=` 로 덮는다.
/// 출처: App Store Connect → 앱 정보 → Apple ID.
const String kAppStoreId = String.fromEnvironment(
  'APP_STORE_ID',
  defaultValue: '6793452983',
);

/// 스토어 리뷰 요청.
///
/// ⚠️ **보상을 걸지 않는다.** 두 가지 이유가 있고 둘 다 타협 불가다:
///  1. **검증이 불가능하다.** 구글 In-App Review·애플 `SKStoreReviewController`
///     모두 유저가 리뷰를 썼는지, 별점이 몇 개인지 앱에 알려주지 않는다
///     (의도된 설계). "별 5개면 지급"은 만들 수가 없고, 만들 수 있는 건
///     "창을 띄웠으면 지급"뿐이라 아무나 받는다.
///  2. **정책 위반이다.** 플레이·앱스토어 모두 평점·리뷰를 대가로 보상 주는
///     것을 금지한다. 적발되면 앱이 내려간다.
///
/// 대신 좋은 순간에 조용히 한 번 물어본다 — 그게 실제로 평점을 올리는 방법이다.
Future<void> requestStoreReview(WidgetRef ref, {bool force = false}) async {
  final ctrl = ref.read(saveControllerProvider.notifier);
  final save = ref.read(saveControllerProvider).value;
  if (save == null) return;
  // 자동 요청은 계정당 1회. 설정에서 직접 누른 경우(force)는 매번 연다.
  if (!force && save.reviewAsked) return;

  try {
    final review = InAppReview.instance;
    if (!force) {
      if (await review.isAvailable()) await review.requestReview();
    } else if (Platform.isIOS && kAppStoreId.isEmpty) {
      // iOS 는 앱 id 를 알아야 스토어를 열 수 있다. 모르면 열라고 해봐야
      // **아무 일도 일어나지 않아** 버튼이 고장난 것처럼 보인다 → 시스템
      // 리뷰창으로 대신한다(앱스토어 출시 후 kAppStoreId 를 넣으면 위로 간다).
      if (await review.isAvailable()) await review.requestReview();
    } else {
      // 설정의 "리뷰 남기기" = 스토어 페이지를 직접 연다. 시스템 리뷰창은
      // 하루 호출 한도가 있어 눌러도 아무 일이 없을 수 있는데, 사용자가
      // **직접 누른** 버튼이 반응하지 않으면 고장으로 보인다.
      await review.openStoreListing(appStoreId: kAppStoreId);
    }
  } catch (e) {
    debugPrint('리뷰 요청 실패: $e');
  }
  await ctrl.markReviewAsked();
}
