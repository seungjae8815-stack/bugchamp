import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/providers.dart';
import '../../domain/save_controller.dart';
import '../../domain/save_game.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/art.dart';
import '../../ui/format.dart';
import '../../ui/labels.dart';

/// 상점(제작) 탭: 재료를 소비해 버프 물약을 제작한다 (§C).
class CraftScreen extends ConsumerWidget {
  const CraftScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final data = ref.watch(gameDataProvider).requireValue;
    final save = ref.watch(saveControllerProvider).requireValue;
    final cfg = data.craftConfig;

    return Scaffold(
      appBar: AppBar(title: Text(l.craftTitle)),
      body: cfg == null
          ? Center(child: Text(l.comingSoon))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: cfg.recipes.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) =>
                  _RecipeCard(recipe: cfg.recipes[i], save: save),
            ),
    );
  }
}

class _RecipeCard extends ConsumerWidget {
  const _RecipeCard({required this.recipe, required this.save});

  final CraftRecipe recipe;
  final SaveGame save;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final buff = recipe.buff;
    final name = recipe.allBuffs
        ? l.craftAllPotion
        : l.craftPotion(buffLabel(l, buff!));
    final color = recipe.allBuffs ? const Color(0xFF4FC3F7) : buffColor(buff!);
    final glyph = recipe.allBuffs ? '💎' : buffGlyph(buff!);

    var affordable = true;
    for (final e in recipe.inputs.entries) {
      if (save.materialCount(e.key) < e.value) affordable = false;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(glyph, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 10,
                    runSpacing: 2,
                    children: [
                      for (final e in recipe.inputs.entries)
                        _cost(e.key, e.value, save.materialCount(e.key)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: affordable
                  ? () async {
                      final ok = await ref
                          .read(saveControllerProvider.notifier)
                          .craft(recipe);
                      if (ok && context.mounted) {
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            SnackBar(content: Text(l.craftedSnack(name))),
                          );
                      }
                    }
                  : null,
              child: Text(l.craftMake),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cost(MaterialKind kind, int need, int have) {
    final ok = have >= need;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        materialImage(
          kind,
          size: 15,
          fallback: Icon(
            materialIcon(kind),
            size: 14,
            color: ok ? const Color(0xFF9CCC65) : const Color(0xFFEF9A9A),
          ),
        ),
        const SizedBox(width: 3),
        Text(
          formatCompact(need),
          style: TextStyle(
            color: ok ? const Color(0xFF9CCC65) : const Color(0xFFEF9A9A),
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
