import 'package:core_run/core_run.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/ad_service.dart';
import '../domain/providers.dart';
import '../domain/save_controller.dart';
import '../l10n/app_localizations.dart';
import 'toast.dart';

/// 보상형 광고를 보여주고 **보상을 줘도 되는지** 돌려준다.
///
/// 광고가 걸린 보상은 전부 이 함수를 거친다 — 보상 지급 조건을 한 곳에 모아둬야
/// "어떤 화면에선 광고 안 보고도 받아지더라" 같은 구멍이 안 생긴다.
///
/// true 가 아닐 땐 이유에 맞는 안내를 띄우고 false 를 돌려주므로,
/// 호출부는 `if (await watchAdForReward(...)) { 지급 }` 만 하면 된다.
///
/// [feature]·[dailyLimit] 을 주면 **하루 시청 횟수 상한**을 먼저 확인한다.
/// 지금은 결투 티켓만 상한이 있다(다른 보상형 광고는 구조적 상한이 이미 있음).
/// 실제 카운트 증가는 보상을 확정하는 쪽(서버 엔드포인트 / SaveController)에서
/// 한다 — 여기서 올리면 "광고는 봤는데 지급은 실패" 때 횟수만 날아간다.
Future<bool> watchAdForReward(
  BuildContext context,
  WidgetRef ref,
  AppLocalizations l, {
  String? feature,
  int dailyLimit = 0,
}) async {
  final save = ref.read(saveControllerProvider).value;
  final now = ref.read(clockProvider).now().toUtc();

  // 안내는 화면 **가운데**로(ui/toast.dart). 하단 SnackBar 는 탭바·버튼과
  // 겹쳐 잘 안 보인다 — 2026-08-06 결정.
  void snack(String msg) {
    if (context.mounted) showCenterToast(context, msg);
  }

  // 하루 상한(서버가 세는 값과 같은 UTC 날짜 기준).
  if (save != null && feature != null && dailyLimit > 0) {
    final used = save.adUseCount(feature, dailyDateKey(now));
    if (used >= dailyLimit) {
      snack(l.adDailyLimit(dailyLimit));
      return false;
    }
  }

  // 광고 제거·패스 구매자는 광고를 **건너뛰고 즉시 보상**받는다.
  // (사장님 결정 2026-08-06) 강제 광고만 없애면 보상형 광고를 계속 봐야 해서
  // "광고 제거"를 산 의미가 없다. 대신 하루 상한은 위에서 똑같이 적용되므로
  // 결제로 판수를 더 사는 것이 아니라 **시간만** 아끼는 게 된다.
  if (save != null && save.adsHidden(now)) return true;

  final result = await ref.read(adServiceProvider).showRewarded();
  if (result == AdResult.rewarded) return true;

  final msg = switch (result) {
    AdResult.dismissed => l.adDismissed,
    AdResult.notReady => l.adNotReady,
    AdResult.failed => l.adFailed,
    AdResult.rewarded => '', // 위에서 반환됨
  };
  if (context.mounted) snack(msg);
  return false;
}
