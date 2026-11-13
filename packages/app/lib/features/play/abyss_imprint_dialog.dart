import 'package:core_run/core_run.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/providers.dart';
import '../../domain/save_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/game_dialog.dart';
import '../../ui/labels.dart';
import '../../ui/toast.dart';

/// 심연 각인 창(2026-11-10) — 심연 결정으로 영구 능력치를 올린다. 산 만큼 바로 다시 그린다.
Future<void> showAbyssImprintDialog(BuildContext context) {
  final l = AppLocalizations.of(context);
  return showGameDialog<void>(
    context,
    title: l.abyssImprintTitle,
    icon: Icons.auto_awesome,
    content: Consumer(
      builder: (context, ref, _) {
        final save = ref.watch(saveControllerProvider).value;
        final run = ref.watch(gameDataProvider).value?.runConfig;
        if (save == null || run == null) return const SizedBox.shrink();
        final cfg = run.abyss;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l.abyssImprintBody,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 12.5),
            ),
            const SizedBox(height: 8),
            Text(
              l.abyssCrystalsHave('${save.abyssCrystals}'),
              style: const TextStyle(
                color: Color(0xFFD1C4E9),
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            for (final e in cfg.imprint.entries)
              _row(context, ref, l, cfg, e.key, e.value, save.abyssCrystals, {
                ...save.abyssImprint,
              }),
          ],
        );
      },
    ),
    actions: [gameDialogButton(l.actionClose, popOnTap(context))],
  );
}

Widget _row(
  BuildContext context,
  WidgetRef ref,
  AppLocalizations l,
  AbyssConfig cfg,
  String key,
  double per,
  int crystals,
  Map<String, int> levels,
) {
  final lv = levels[key] ?? 0;
  final cost = cfg.imprintCost(lv);
  final kind = UpgradeKind.fromKeyOrNull(key);
  final ok = crystals >= cost;
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          child: Text(
            '${kind == null ? key : upgradeLabel(l, kind)} · '
            '${l.abyssImprintLevel('$lv', (per * lv * 100).toStringAsFixed(0))}',
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
        TextButton(
          onPressed: () async {
            if (!ok) {
              showCenterToast(context, l.upgradeCapNeed('$crystals', '$cost'));
              return;
            }
            await ref
                .read(saveControllerProvider.notifier)
                .buyAbyssImprintNow(key);
          },
          child: Text(
            '💠$cost',
            style: TextStyle(
              color: ok ? const Color(0xFFD1C4E9) : Colors.white38,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    ),
  );
}
