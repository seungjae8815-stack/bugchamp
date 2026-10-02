import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_models/core_models.dart' show MaterialKind;

import '../domain/save_controller.dart';
import 'jelly_short.dart';

import '../l10n/app_localizations.dart';
import 'art.dart';
import 'game_dialog.dart';

/// 젤리를 쓰는 즉시 버튼의 확인 창 — 누르자마자 프리미엄 재화가 빠지면 실수로 눌렀을 때
/// 되돌릴 길이 없다(2026-09-30 점검: 부상 즉시회복·훈련 즉시완료에 확인이 없었다).
/// 스킬 수련 즉시 완료와 같은 모양이다.
Future<bool> confirmJellySpend(
  BuildContext context, {
  required String title,
  required String body,
  required int jelly,
}) async {
  final l = AppLocalizations.of(context);
  // 젤리가 모자라면 확인 창 대신 상점 안내(2026-10-02).
  final have = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(saveControllerProvider).value?.materialCount(MaterialKind.jelly);
  if (have != null && have < jelly) {
    await showJellyShort(context);
    return false;
  }
  final ok = await showGameDialog<bool>(
    context,
    title: title,
    icon: Icons.bolt_rounded,
    content: Text(
      body,
      textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.white, fontSize: 13),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context, rootNavigator: true).pop(false),
        child: Text(l.actionCancel),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
        child: jellyPrice(cost: jelly, label: l.actionInstant),
      ),
    ],
  );
  return ok == true;
}
