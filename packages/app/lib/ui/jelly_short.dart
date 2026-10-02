import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/providers.dart';
import '../l10n/app_localizations.dart';
import 'art.dart';
import 'game_dialog.dart';

/// 젤리 부족 → **상점으로 안내**(2026-10-02 출시 점검 — 약 25곳이 토스트만 띄우고 끝나
/// 구매 의향이 가장 높은 순간을 흘려보냈다). [showCenterToast] 가 "젤리 부족" 문구를 받으면
/// 이 창으로 바꿔 띄우므로, 부족을 알리는 곳은 따로 손대지 않아도 모두 여기로 온다.
bool _open = false;

Future<void> showJellyShort(BuildContext context) async {
  if (_open) return; // 연달아 불려도 창은 하나
  final l = AppLocalizations.of(context);
  final nav = Navigator.of(context, rootNavigator: true);
  final container = ProviderScope.containerOf(context, listen: false);
  _open = true;
  try {
    final go = await showGameDialog<bool>(
      context,
      title: l.jellyShortTitle,
      iconWidget: jellyIcon(size: 34),
      content: Text(
        l.jellyShortBody,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
      ),
      actions: [
        gameDialogButton(l.actionClose, () => nav.pop(false), primary: false),
        gameDialogButton(l.jellyShortGoShop, () => nav.pop(true)),
      ],
    );
    if (go != true) return;
    // 열려 있는 창·화면을 닫고 상점 탭으로.
    nav.popUntil((r) => r.isFirst);
    container.read(tabIndexProvider.notifier).set(kShopTabIndex);
  } finally {
    _open = false;
  }
}
