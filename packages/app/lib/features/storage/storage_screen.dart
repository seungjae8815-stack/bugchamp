import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/game_data.dart';
import '../../domain/providers.dart';
import '../../domain/save_controller.dart';
import '../../domain/save_game.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/art.dart';
import '../../ui/concept_card.dart';
import '../../ui/format.dart';
import '../../ui/labels.dart';

const _honey = Color(0xFFEBA52F);

/// 채집함: 상단 장착 3슬롯 + 아이콘 그리드(단계·티어순) + 탭 시 상세 팝업.
class StorageScreen extends ConsumerWidget {
  const StorageScreen({super.key, required this.save});

  final SaveGame save;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final data = ref.watch(gameDataProvider).requireValue;

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
          _equipStrip(context, ref, data, l, save),
          _materialsStrip(context, l, save),
          const Divider(height: 1, color: Color(0x22FFFFFF)),
          Expanded(child: _grid(context, ref, data, l, save)),
        ],
      ),
    );
  }

  // ── 정렬 ──────────────────────────────────────────────────────
  int _stageRank(LifeStage s) => switch (s) {
    LifeStage.adult => 3,
    LifeStage.pupa => 2,
    LifeStage.larva => 1,
    LifeStage.egg => 0,
  };

  /// (성충↑ 알↓) + 티어(포텐셜)↑ + 같은 종끼리 묶고 + 레벨↑ 순. 장착은 맨 앞.
  List<({IndividualBug bug, LifeStage stage, bool equipped})> _sorted(
    GameData data,
    SaveGame save,
    DateTime now,
  ) {
    final cfg = data.petConfig;
    final list = save.bugs.map((b) {
      final st = cfg == null
          ? b.stage
          : effectiveStage(b.stage, b.stageSince, now, cfg);
      return (bug: b, stage: st, equipped: save.isEquipped(b.id));
    }).toList();
    list.sort((a, b) {
      if (a.equipped != b.equipped) return a.equipped ? -1 : 1;
      final sr = _stageRank(b.stage) - _stageRank(a.stage);
      if (sr != 0) return sr;
      if (a.bug.potential != b.bug.potential) {
        return b.bug.potential - a.bug.potential;
      }
      final sp = a.bug.speciesId.compareTo(b.bug.speciesId);
      if (sp != 0) return sp;
      return b.bug.level - a.bug.level;
    });
    return list;
  }

  Widget _grid(
    BuildContext context,
    WidgetRef ref,
    GameData data,
    AppLocalizations l,
    SaveGame save,
  ) {
    if (save.bugs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            l.storageEmpty,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }
    final items = _sorted(data, save, ref.read(clockProvider).now().toUtc());
    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.82,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final it = items[i];
        return _bugCell(context, ref, data, it.bug, it.stage, it.equipped);
      },
    );
  }

  /// 아이콘 셀: 이미지 + 티어(★) + 성충 레벨 + 장착중. 등급색 테두리.
  Widget _bugCell(
    BuildContext context,
    WidgetRef ref,
    GameData data,
    IndividualBug bug,
    LifeStage stage,
    bool equipped,
  ) {
    final species = data.species(bug.speciesId);
    return GestureDetector(
      onTap: () => _showBugDetail(context, ref, data, bug.id),
      child: Container(
        decoration: _gradeFrame(species.grade, equipped: equipped),
        child: Column(
          children: [
            const SizedBox(height: 3),
            // 성충 레벨(상단)
            SizedBox(
              height: 13,
              child: stage == LifeStage.adult
                  ? Text(
                      'Lv.${bug.level}',
                      style: const TextStyle(
                        color: Color(0xCCFFFFFF),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
            ),
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: bugStageImage(
                      bug.speciesId,
                      stage,
                      size: 48,
                      fallback: bugAvatar(species, size: 44),
                    ),
                  ),
                  if (equipped)
                    Positioned(
                      top: -2,
                      left: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: _honey,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          AppLocalizations.of(context).equippedBadge,
                          style: const TextStyle(
                            color: Color(0xFF3A2600),
                            fontSize: 7.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // 티어(별)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _stars(bug.potential, 8.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stars(int n, double size) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < n; i++)
        Icon(
          Icons.star_rounded,
          size: size,
          color: const Color(0xFFFFE24A),
          shadows: const [
            Shadow(
              color: Color(0xFF7A4E00),
              blurRadius: 0.5,
              offset: Offset(0, 0.6),
            ),
            Shadow(color: Colors.black87, blurRadius: 2),
          ],
        ),
    ],
  );

  /// 등급별 선명한 대표색(테두리·글로우용).
  Color _gradeBright(Grade g) => switch (g) {
    Grade.common => const Color(0xFFB6C2CC),
    Grade.uncommon => const Color(0xFF5CD65C),
    Grade.rare => const Color(0xFF3FA9FF),
    Grade.epic => const Color(0xFFC072F0),
    Grade.legendary => const Color(0xFFFFC93C),
  };

  /// 액자형 등급 프레임. 높은 등급일수록 두꺼운 테두리 + 그라데이션 + 글로우.
  BoxDecoration _gradeFrame(Grade g, {bool equipped = false}) {
    final c = _gradeBright(g);
    final lux = g.index; // 0(일반)~4(전설)
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          c.withValues(alpha: 0.16 + lux * 0.05),
          const Color(0xE60A1206),
        ],
      ),
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: c, width: 1.4 + lux * 0.5),
      boxShadow: [
        if (lux >= 2)
          BoxShadow(
            color: c.withValues(alpha: 0.35 + lux * 0.08),
            blurRadius: 6.0 + lux * 3,
            spreadRadius: lux >= 4 ? 1.0 : 0.0,
          ),
        if (equipped)
          BoxShadow(
            color: _honey.withValues(alpha: 0.7),
            blurRadius: 10,
            spreadRadius: 1,
          ),
      ],
    );
  }

  // ── 상단 장착 슬롯 ────────────────────────────────────────────
  Widget _equipStrip(
    BuildContext context,
    WidgetRef ref,
    GameData data,
    AppLocalizations l,
    SaveGame save,
  ) {
    final cfg = data.petConfig;
    final maxEquip = cfg?.maxEquip ?? 3;
    var atkPct = '0';
    var hpPct = '0';
    if (cfg != null) {
      final now = ref.read(clockProvider).now().toUtc();
      final pets = <PetStat>[];
      for (final id in save.equippedBugIds) {
        final bug = _findBug(save, id);
        if (bug == null) continue;
        final sp = data.speciesById[bug.speciesId];
        if (sp == null) continue;
        pets.add((
          grade: sp.grade,
          sizeMult: bug.statMultiplier(sp),
          potential: bug.potential,
          enhanceTotal: bug.enhancement.total,
          stage: effectiveStage(bug.stage, bug.stageSince, now, cfg),
          level: bug.level,
        ));
      }
      final pb = computePetBonus(pets, cfg);
      atkPct = ((pb.attackMult - 1) * 100).toStringAsFixed(0);
      hpPct = ((pb.hpMult - 1) * 100).toStringAsFixed(0);
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pets, size: 15, color: _honey),
              const SizedBox(width: 5),
              Text(
                l.equipTitle,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            l.petBonus(atkPct, hpPct),
            style: const TextStyle(
              color: _honey,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < maxEquip; i++)
                Expanded(child: _equipSlot(context, ref, data, save, i)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _equipSlot(
    BuildContext context,
    WidgetRef ref,
    GameData data,
    SaveGame save,
    int index,
  ) {
    final id = index < save.equippedBugIds.length
        ? save.equippedBugIds[index]
        : null;
    final bug = id == null ? null : _findBug(save, id);
    final species = bug == null ? null : data.species(bug.speciesId);
    final cfg = data.petConfig;
    final stage = (bug == null || cfg == null)
        ? LifeStage.adult
        : effectiveStage(
            bug.stage,
            bug.stageSince,
            ref.read(clockProvider).now().toUtc(),
            cfg,
          );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: bug == null
            ? null
            : () => _showBugDetail(context, ref, data, bug.id),
        child: Container(
          height: 118,
          decoration: bug == null
              ? BoxDecoration(
                  color: const Color(0x22000000),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0x33FFFFFF)),
                )
              : _gradeFrame(species!.grade, equipped: true),
          child: bug == null
              ? const Center(
                  child: Icon(
                    Icons.add_circle_outline,
                    color: Color(0x66FFFFFF),
                    size: 26,
                  ),
                )
              : Column(
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4, right: 6),
                        child: Text(
                          'Lv.${bug.level}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: bugStageImage(
                        bug.speciesId,
                        stage,
                        size: 58,
                        fallback: bugAvatar(species!, size: 52),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _stars(bug.potential, 11),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // ── 재화 스트립(탭 → 설명) ────────────────────────────────────
  Widget _materialsStrip(
    BuildContext context,
    AppLocalizations l,
    SaveGame save,
  ) => Container(
    padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final k in MaterialKind.values)
          InkWell(
            onTap: () => _showMaterialInfo(context, l, k),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  materialImage(
                    k,
                    size: 26,
                    fallback: Icon(materialIcon(k), size: 22),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    formatCompact(save.materialCount(k)),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );

  void _showMaterialInfo(
    BuildContext context,
    AppLocalizations l,
    MaterialKind k,
  ) {
    showConceptCard(
      context,
      iconBox: Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0x22FFFFFF),
          borderRadius: BorderRadius.circular(10),
        ),
        child: materialImage(
          k,
          size: 40,
          fallback: Icon(materialIcon(k), size: 30, color: Colors.white),
        ),
      ),
      title: materialLabel(l, k),
      subtitle: materialTag(l, k),
      body: materialDesc(l, k),
      closeLabel: l.actionClose,
    );
  }

  IndividualBug? _findBug(SaveGame save, String id) {
    for (final b in save.bugs) {
      if (b.id == id) return b;
    }
    return null;
  }

  static String _mmss(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  // ── 상세 팝업 ─────────────────────────────────────────────────
  void _showBugDetail(
    BuildContext context,
    WidgetRef ref,
    GameData data,
    String bugId,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xF2141F0E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Consumer(
          builder: (ctx, r, _) {
            final l = AppLocalizations.of(ctx);
            final save = r.watch(saveControllerProvider).requireValue;
            final bug = _findBug(save, bugId);
            if (bug == null) return const SizedBox.shrink();
            final species = data.species(bug.speciesId);
            final locale = Localizations.localeOf(ctx).languageCode;
            final petCfg = data.petConfig;
            final enhCfg = data.enhanceConfig;
            final now = r.read(clockProvider).now().toUtc();
            final effStage = petCfg == null
                ? bug.stage
                : effectiveStage(bug.stage, bug.stageSince, now, petCfg);
            final equipped = save.isEquipped(bug.id);
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 헤더
                  Row(
                    children: [
                      Container(
                        width: 62,
                        height: 62,
                        padding: const EdgeInsets.all(4),
                        decoration: _gradeFrame(species.grade),
                        child: bugStageImage(
                          bug.speciesId,
                          effStage,
                          size: 54,
                          fallback: bugAvatar(species, size: 50),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              species.name.resolve(locale),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(
                                  gradeLabel(l, species.grade),
                                  style: TextStyle(
                                    color: _gradeBright(species.grade),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${stageLabel(l, effStage)}'
                                  '${effStage == LifeStage.adult ? ' Lv.${bug.level}' : ''}',
                                  style: const TextStyle(
                                    color: Color(0xCCFFFFFF),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            _stars(bug.potential, 13),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (species.desc != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      species.desc!.resolve(locale),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xB3FFFFFF),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  if (petCfg != null)
                    _petEffectCard(l, species, bug, effStage, petCfg),
                  if (petCfg != null && effStage == LifeStage.adult) ...[
                    const SizedBox(height: 6),
                    _trainRow(ctx, r, petCfg, save, bug),
                  ],
                  if (petCfg != null) ...[
                    const SizedBox(height: 6),
                    _evolveRow(ctx, r, petCfg, save, bug, effStage, now),
                    const SizedBox(height: 6),
                    _synthRow(ctx, r, petCfg, save, bug),
                  ],
                  if (enhCfg != null) ...[
                    const SizedBox(height: 6),
                    _enhanceOpenRow(context, ref, data, l, bug),
                  ],
                  const SizedBox(height: 12),
                  // 하단 액션: 장착이면 '해제' 단독, 아니면 '장착 + 분해'
                  if (equipped)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => r
                            .read(saveControllerProvider.notifier)
                            .unequipBug(bug.id),
                        icon: const Icon(Icons.link_off, size: 18),
                        label: Text(l.unequipAction),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF556070),
                        ),
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => r
                                .read(saveControllerProvider.notifier)
                                .equipBug(bug.id),
                            icon: const Icon(Icons.pets, size: 18),
                            label: Text(l.equipAction),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF2E7D32),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final ok = await r
                                .read(saveControllerProvider.notifier)
                                .disassembleBug(bug.id);
                            if (ok && ctx.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(
                                  SnackBar(content: Text(l.disassembleSnack)),
                                );
                            }
                          },
                          icon: const Icon(Icons.call_split, size: 18),
                          label: Text(l.disassembleAction),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFEF9A9A),
                            side: const BorderSide(color: Color(0x55EF9A9A)),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _sectionBox({required Widget child}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0x22000000),
      borderRadius: BorderRadius.circular(10),
    ),
    child: child,
  );

  Widget _petEffectCard(
    AppLocalizations l,
    Species sp,
    IndividualBug bug,
    LifeStage stage,
    PetConfig cfg,
  ) {
    final c = petContribution((
      grade: sp.grade,
      sizeMult: bug.statMultiplier(sp),
      potential: bug.potential,
      enhanceTotal: bug.enhancement.total,
      stage: stage,
      level: bug.level,
    ), cfg);
    return _sectionBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.petEffectTitle,
            style: const TextStyle(
              color: _honey,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l.petAtkBonus((c.attack * 100).toStringAsFixed(1)),
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          Text(
            l.petHpBonus((c.hp * 100).toStringAsFixed(1)),
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _trainRow(
    BuildContext ctx,
    WidgetRef r,
    PetConfig cfg,
    SaveGame save,
    IndividualBug bug,
  ) {
    final l = AppLocalizations.of(ctx);
    final maxed = bug.level >= cfg.maxLevel;
    final cost = cfg.trainCost(bug.level);
    final can = !maxed && save.gold >= cost;
    return _sectionBox(
      child: Row(
        children: [
          const Icon(Icons.fitness_center, color: Color(0xFF9CCC65), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${l.trainLevel}  Lv.${bug.level}/${cfg.maxLevel}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
                Text(
                  maxed ? l.trainMaxed : '💰 ${formatCompact(cost)}',
                  style: const TextStyle(
                    color: Color(0xB3FFFFFF),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: can
                ? () async {
                    final ok = await r
                        .read(saveControllerProvider.notifier)
                        .trainBug(bug.id);
                    if (ok && ctx.mounted) {
                      ScaffoldMessenger.of(ctx)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(SnackBar(content: Text(l.trainSnack)));
                    }
                  }
                : null,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEBA52F),
              foregroundColor: const Color(0xFF3A2600),
              minimumSize: const Size(0, 36),
            ),
            child: Text(l.trainAction),
          ),
        ],
      ),
    );
  }

  Widget _evolveRow(
    BuildContext ctx,
    WidgetRef r,
    PetConfig petCfg,
    SaveGame save,
    IndividualBug bug,
    LifeStage effStage,
    DateTime now,
  ) {
    final l = AppLocalizations.of(ctx);
    final jelly = save.materialCount(MaterialKind.jelly);
    final canAcc = !effStage.isFinal && jelly >= petCfg.accelerateJelly;
    final rem =
        stageRemaining(bug.stage, bug.stageSince, now, petCfg) ?? Duration.zero;
    return _sectionBox(
      child: Row(
        children: [
          const Icon(Icons.spa, color: Color(0xFF9CCC65), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.evolveTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
                Text(
                  effStage.isFinal
                      ? l.evolveMaxed
                      : (rem <= Duration.zero
                            ? l.evolveReady
                            : l.evolveNext(
                                stageLabel(l, effStage.next),
                                _mmss(rem),
                              )),
                  style: const TextStyle(
                    color: Color(0xB3FFFFFF),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          if (!effStage.isFinal)
            FilledButton.icon(
              onPressed: canAcc
                  ? () => r
                        .read(saveControllerProvider.notifier)
                        .accelerateEvolution(bug.id)
                  : null,
              icon: const Icon(Icons.bolt, size: 16),
              label: Text('${l.accelerateAction} 💎${petCfg.accelerateJelly}'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2E6DA4),
                minimumSize: const Size(0, 36),
              ),
            ),
        ],
      ),
    );
  }

  Widget _synthRow(
    BuildContext ctx,
    WidgetRef r,
    PetConfig petCfg,
    SaveGame save,
    IndividualBug bug,
  ) {
    final l = AppLocalizations.of(ctx);
    final maxed = bug.potential >= petCfg.synthMaxPotential;
    final have = save.bugs
        .where(
          (b) =>
              b.id != bug.id &&
              b.speciesId == bug.speciesId &&
              !save.isEquipped(b.id),
        )
        .length;
    final need = petCfg.synthFodder;
    final can = !maxed && have >= need;
    return _sectionBox(
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_motion, color: _honey, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.synthTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
                Text(
                  maxed ? l.synthMaxed : l.synthDesc(have, need),
                  style: const TextStyle(
                    color: Color(0xB3FFFFFF),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: can
                ? () async {
                    final ok = await r
                        .read(saveControllerProvider.notifier)
                        .synthesize(bug.id);
                    if (ok && ctx.mounted) {
                      ScaffoldMessenger.of(ctx)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(SnackBar(content: Text(l.synthSnack)));
                    }
                  }
                : null,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEBA52F),
              foregroundColor: const Color(0xFF3A2600),
              minimumSize: const Size(0, 36),
            ),
            child: Text(l.synthDo),
          ),
        ],
      ),
    );
  }

  /// 상세 팝업의 부위강화 진입 줄(탭 → 별도 시트).
  Widget _enhanceOpenRow(
    BuildContext context,
    WidgetRef ref,
    GameData data,
    AppLocalizations l,
    IndividualBug bug,
  ) => InkWell(
    onTap: () => _showEnhanceSheet(context, ref, data, bug.id),
    borderRadius: BorderRadius.circular(10),
    child: _sectionBox(
      child: Row(
        children: [
          const Icon(Icons.handyman, color: Color(0xFF9CCC65), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.enhanceTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
                Text(
                  l.enhanceCap(bug.enhancement.total, bug.maxLevel),
                  style: const TextStyle(
                    color: Color(0xB3FFFFFF),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Color(0x88FFFFFF)),
        ],
      ),
    ),
  );

  /// 부위 강화 전용 시트(4부위).
  void _showEnhanceSheet(
    BuildContext context,
    WidgetRef ref,
    GameData data,
    String bugId,
  ) {
    final enhCfg = data.enhanceConfig;
    if (enhCfg == null) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xF2141F0E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Consumer(
          builder: (ctx, r, _) {
            final l = AppLocalizations.of(ctx);
            final save = r.watch(saveControllerProvider).requireValue;
            final bug = _findBug(save, bugId);
            if (bug == null) return const SizedBox.shrink();
            final species = data.species(bug.speciesId);
            final locale = Localizations.localeOf(ctx).languageCode;
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${species.name.resolve(locale)} · ${l.enhanceTitle}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    l.enhanceCap(bug.enhancement.total, bug.maxLevel),
                    style: const TextStyle(
                      color: _honey,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final part in BugPart.values)
                    _enhanceRow(ctx, r, enhCfg, save, bug, part),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _enhanceRow(
    BuildContext ctx,
    WidgetRef r,
    EnhanceConfig cfg,
    SaveGame save,
    IndividualBug bug,
    BugPart part,
  ) {
    final l = AppLocalizations.of(ctx);
    final spec = cfg.spec(part);
    final level = bug.enhancement.levelOf(part);
    final cost = spec.costAt(level);
    final have = save.materialCount(spec.material);
    final atCap = bug.enhancement.total >= bug.maxLevel;
    final canBuy = !atCap && have >= cost;
    final pctNum = spec.effectPerLevel * 100;
    final pct = pctNum % 1 == 0
        ? pctNum.toStringAsFixed(0)
        : pctNum.toStringAsFixed(1);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0x22FFFFFF),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(partIcon(part), color: Colors.white, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${partLabel(l, part)}  Lv.$level · ${l.enhancePerLevel(pct)}',
              style: const TextStyle(color: Colors.white, fontSize: 12.5),
            ),
          ),
          if (!atCap) ...[
            materialImage(
              spec.material,
              size: 14,
              fallback: Icon(
                materialIcon(spec.material),
                size: 13,
                color: canBuy
                    ? const Color(0xFF9CCC65)
                    : const Color(0xFFEF9A9A),
              ),
            ),
            const SizedBox(width: 3),
            Text(
              formatCompact(cost),
              style: TextStyle(
                color: canBuy
                    ? const Color(0xFFC5E1A5)
                    : const Color(0xFFEF9A9A),
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 8),
          ],
          FilledButton(
            onPressed: canBuy
                ? () => r
                      .read(saveControllerProvider.notifier)
                      .enhancePart(bug.id, part)
                : null,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 32),
            ),
            child: Text(atCap ? l.enhanceMaxed : l.enhanceAction),
          ),
        ],
      ),
    );
  }
}
