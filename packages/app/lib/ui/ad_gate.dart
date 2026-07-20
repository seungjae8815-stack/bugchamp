import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/ad_service.dart';
import '../l10n/app_localizations.dart';

/// 보상형 광고를 보여주고 **보상을 줘도 되는지** 돌려준다.
///
/// 광고가 걸린 보상은 전부 이 함수를 거친다 — 보상 지급 조건을 한 곳에 모아둬야
/// "어떤 화면에선 광고 안 보고도 받아지더라" 같은 구멍이 안 생긴다.
///
/// true 가 아닐 땐 이유에 맞는 안내를 띄우고 false 를 돌려주므로,
/// 호출부는 `if (await watchAdForReward(...)) { 지급 }` 만 하면 된다.
Future<bool> watchAdForReward(
  BuildContext context,
  WidgetRef ref,
  AppLocalizations l,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final result = await ref.read(adServiceProvider).showRewarded();
  if (result == AdResult.rewarded) return true;

  final msg = switch (result) {
    AdResult.dismissed => l.adDismissed,
    AdResult.notReady => l.adNotReady,
    AdResult.failed => l.adFailed,
    AdResult.rewarded => '', // 위에서 반환됨
  };
  if (context.mounted) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }
  return false;
}
