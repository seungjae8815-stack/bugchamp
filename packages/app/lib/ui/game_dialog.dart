import 'package:core_models/core_models.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'art.dart';
import 'format.dart';
import 'labels.dart';

const _honey = Color(0xFFEBA52F);

/// 게임 톤(다크그린 + 허니 테두리)으로 통일된 다이얼로그. 모든 팝업은 이걸 쓴다.
Future<T?> showGameDialog<T>(
  BuildContext context, {
  required String title,
  IconData? icon,
  String? subtitle,
  required Widget content,
  List<Widget> actions = const [],
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierColor: const Color(0xB3000000),
    barrierDismissible: barrierDismissible,
    builder: (ctx) => GameDialog(
      title: title,
      icon: icon,
      subtitle: subtitle,
      actions: actions,
      child: content,
    ),
  );
}

class GameDialog extends StatelessWidget {
  const GameDialog({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.subtitle,
    this.actions = const [],
  });

  final String title;
  final IconData? icon;
  final String? subtitle;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xF21F2E13), Color(0xF20E1608)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x88EBA52F), width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66EBA52F),
              blurRadius: 20,
              spreadRadius: -6,
            ),
            BoxShadow(color: Color(0x99000000), blurRadius: 18),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0x33EBA52F),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0x88EBA52F)),
                    ),
                    child: Icon(icon, color: _honey, size: 19),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16.5,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            color: _honey,
                            fontWeight: FontWeight.w700,
                            fontSize: 11.5,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: Color(0x33EBA52F)),
            ),
            child,
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    actions[i],
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 게임 다이얼로그용 주/보조 버튼.
Widget gameDialogButton(
  String label,
  VoidCallback onPressed, {
  bool primary = true,
  Color? color,
}) {
  if (primary) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: color ?? _honey,
        foregroundColor: const Color(0xFF3A2600),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
      child: Text(label),
    );
  }
  return TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(foregroundColor: const Color(0xCCFFFFFF)),
    child: Text(label),
  );
}

/// 보상(골드 + 재료들)을 종류별로 나열하는 위젯. 팝업 본문에 넣는다.
Widget gameRewardList(
  BuildContext context, {
  int gold = 0,
  int xp = 0,
  Map<MaterialKind, int> materials = const {},
}) {
  final l = AppLocalizations.of(context);
  final rows = <Widget>[];
  if (gold > 0) {
    rows.add(_rewardRow(goldIcon(size: 26), l.curGold, formatCompact(gold)));
  }
  if (xp > 0) {
    rows.add(
      _rewardRow(
        const Text('🔷', style: TextStyle(fontSize: 20)),
        l.offlineXpLabel,
        formatCompact(xp),
      ),
    );
  }
  for (final k in MaterialKind.values) {
    final v = materials[k] ?? 0;
    if (v <= 0) continue;
    rows.add(
      _rewardRow(
        materialImage(k, size: 26, fallback: Icon(materialIcon(k), size: 22)),
        materialLabel(l, k),
        formatCompact(v),
      ),
    );
  }
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < rows.length; i++) ...[
        if (i > 0) const SizedBox(height: 8),
        rows[i],
      ],
    ],
  );
}

Widget _rewardRow(Widget icon, String name, String amount) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
  decoration: BoxDecoration(
    color: const Color(0x22000000),
    borderRadius: BorderRadius.circular(10),
    border: Border.all(color: const Color(0x1AFFFFFF)),
  ),
  child: Row(
    children: [
      SizedBox(width: 26, height: 26, child: Center(child: icon)),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
      Text(
        '+$amount',
        style: const TextStyle(
          color: _honey,
          fontWeight: FontWeight.w900,
          fontSize: 15,
        ),
      ),
    ],
  ),
);

/// 보상 획득 결과 팝업(획득한 재화 종류별 나열).
Future<void> showRewardPopup(
  BuildContext context, {
  required String title,
  String? subtitle,
  IconData icon = Icons.card_giftcard_rounded,
  int gold = 0,
  Map<MaterialKind, int> materials = const {},
}) {
  final l = AppLocalizations.of(context);
  return showGameDialog<void>(
    context,
    title: title,
    subtitle: subtitle,
    icon: icon,
    content: gameRewardList(context, gold: gold, materials: materials),
    actions: [gameDialogButton(l.actionClose, () => Navigator.pop(context))],
  );
}
