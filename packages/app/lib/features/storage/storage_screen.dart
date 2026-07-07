import 'package:core_models/core_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/game_data.dart';
import '../../domain/providers.dart';
import '../../domain/save_game.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/art.dart';
import '../../ui/format.dart';
import '../../ui/labels.dart';

/// 보관함: 보유 개체 목록 (사이즈·포텐셜·기질·등급·주특기).
class StorageScreen extends ConsumerWidget {
  const StorageScreen({super.key, required this.save});

  final SaveGame save;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final data = ref.watch(gameDataProvider).requireValue;
    final locale = Localizations.localeOf(context).languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.storageTitle),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: Text(l.storageCount(save.bugs.length))),
          ),
        ],
      ),
      body: Column(
        children: [
          _materialsStrip(save),
          Expanded(
            child: save.bugs.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        l.storageEmpty,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: save.bugs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, i) => _BugTile(
                      bug: save.bugs[save.bugs.length - 1 - i], // 최신순
                      data: data,
                      locale: locale,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _materialsStrip(SaveGame save) => Container(
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final k in MaterialKind.values)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              materialImage(
                k,
                size: 42,
                fallback: Icon(materialIcon(k), size: 34),
              ),
              const SizedBox(height: 2),
              Text(
                formatCompact(save.materialCount(k)),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
      ],
    ),
  );
}

class _BugTile extends StatelessWidget {
  const _BugTile({required this.bug, required this.data, required this.locale});

  final IndividualBug bug;
  final GameData data;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final species = data.species(bug.speciesId);

    return Card(
      child: ListTile(
        leading: SizedBox(
          width: 46,
          height: 46,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              bugAvatar(species, size: 46),
              Positioned(
                right: -3,
                bottom: -3,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEBA52F),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(
                    l.bugPotential(bug.potential),
                    style: const TextStyle(
                      color: Color(0xFF3A2600),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        title: Text(species.name.resolve(locale)),
        subtitle: Text(
          '${l.bugSize(formatSizeMm(bug.sizeMm))} · '
          '${specialtyLabel(l, species.specialty)} · '
          '${temperamentLabel(l, bug.temperament)}',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              gradeLabel(l, species.grade),
              style: TextStyle(
                color: gradeColor(species.grade),
                fontWeight: FontWeight.bold,
              ),
            ),
            Icon(sexIcon(bug.sex), size: 18),
          ],
        ),
      ),
    );
  }
}
