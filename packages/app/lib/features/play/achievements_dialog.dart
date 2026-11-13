import 'package:core_save/core_save.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/providers.dart';
import '../../domain/save_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/game_dialog.dart';

/// 업적 · 칭호 창(2026-11-10) — 진행도를 보여 주고, 달성한 업적을 눌러 칭호로 단다(다시 누르면 뗀다).
Future<void> showAchievementsDialog(BuildContext context) {
  final l = AppLocalizations.of(context);
  return showGameDialog<void>(
    context,
    title: l.achievementsTitle,
    icon: Icons.emoji_events_rounded,
    content: Consumer(
      builder: (context, ref, _) {
        final save = ref.watch(saveControllerProvider).value;
        final data = ref.watch(gameDataProvider).value;
        final run = data?.runConfig;
        if (save == null || run == null) return const SizedBox.shrink();
        final lang = Localizations.localeOf(context).languageCode;
        final conquer = data?.dexConfig?.conquerLevel ?? 1;
        String pick(Map<String, String> m) =>
            m[lang] ?? m['en'] ?? m['ko'] ?? '';
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.55,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(
                l.achievementsBody,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 6),
              for (final d in run.achievements)
                () {
                  final p = achievementProgress(save, d, conquerLevel: conquer);
                  final done = p >= d.goal;
                  final on = save.title == d.id;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    onTap: done
                        ? () => ref
                              .read(saveControllerProvider.notifier)
                              .setTitle(on ? null : d.id)
                        : null,
                    leading: Icon(
                      on
                          ? Icons.workspace_premium_rounded
                          : done
                          ? Icons.emoji_events_rounded
                          : Icons.lock_outline_rounded,
                      color: done ? const Color(0xFFFFD977) : Colors.white30,
                    ),
                    title: Text(
                      '「${pick(d.title)}」',
                      style: TextStyle(
                        color: done ? Colors.white : Colors.white54,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: Text(
                      '${pick(d.desc)} · ${p.clamp(0, d.goal)}/${d.goal}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                    trailing: on
                        ? Text(
                            l.achievementsWearing,
                            style: const TextStyle(
                              color: Color(0xFFFFD977),
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                            ),
                          )
                        : null,
                  );
                }(),
            ],
          ),
        );
      },
    ),
    actions: [gameDialogButton(l.actionClose, popOnTap(context))],
  );
}
