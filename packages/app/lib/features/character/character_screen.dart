import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/game_data.dart';
import '../../domain/providers.dart';
import '../../domain/save_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/format.dart';
import '../../ui/game_dialog.dart';
import '../../ui/labels.dart';
import '../../ui/toast.dart';
import 'character_scene.dart';
import 'equip_widgets.dart';
import 'forge_panel.dart';

const _honey = Color(0xFFFFD54F);

/// 상단 3버튼이 무엇을 보여줄지.
enum _Panel { stats, pets, skills }

/// 캐릭터 탭 — **내 전력을 조립하는 곳**.
///
/// 위 → 아래: [능력치][펫][스킬] 버튼 · 메인 캐릭터와 곁에 선 곤충들 ·
/// 고른 패널 · 장비 8칸 · **제련/자동** · **공방 등급**.
class CharacterScreen extends ConsumerStatefulWidget {
  const CharacterScreen({super.key});

  @override
  ConsumerState<CharacterScreen> createState() => _CharacterScreenState();
}

class _CharacterScreenState extends ConsumerState<CharacterScreen> {
  _Panel _panel = _Panel.stats;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final save = ref.watch(saveControllerProvider).requireValue;
    final items = ref.watch(gameDataProvider).value?.itemConfig;

    return Scaffold(
      appBar: AppBar(title: Text(l.navCharacter)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 24),
        children: [
          _tabs(l),
          const SizedBox(height: 10),
          CharacterScene(save: save),
          const SizedBox(height: 10),
          switch (_panel) {
            _Panel.stats => _StatsPanel(save: save),
            _Panel.pets => _PetsPanel(save: save),
            _Panel.skills => _SkillsPanel(save: save),
          },
          const SizedBox(height: 12),
          if (items != null) ...[
            _EquipGrid(save: save, config: items),
            const SizedBox(height: 10),
            // 장비 **바로 밑** — 가운데 제련, 옆에 자동. 그 밑에 공방 등급.
            const ForgeBar(),
          ],
        ],
      ),
    );
  }

  Widget _tabs(AppLocalizations l) => Row(
    children: [
      _tab(l.charTabStats, Icons.person_rounded, _Panel.stats),
      const SizedBox(width: 6),
      _tab(l.charTabPets, Icons.pets_rounded, _Panel.pets),
      const SizedBox(width: 6),
      _tab(l.charTabSkills, Icons.auto_awesome_rounded, _Panel.skills),
    ],
  );

  Widget _tab(String text, IconData icon, _Panel p) {
    final on = _panel == p;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _panel = p),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: on ? const Color(0x33FFD54F) : const Color(0x33121A10),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: on ? _honey : const Color(0x22FFFFFF),
              width: on ? 1.6 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: on ? _honey : Colors.white70),
              const SizedBox(width: 5),
              Text(
                text,
                style: TextStyle(
                  color: on ? _honey : Colors.white70,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 능력치 — 장비까지 반영된 **지금 값**.
class _StatsPanel extends ConsumerWidget {
  const _StatsPanel({required this.save});
  final SaveGame save;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final data = ref.watch(gameDataProvider).value;
    final run = data?.runConfig;
    if (run == null) return const SizedBox.shrink();

    final s = applyEquipment(
      deriveStats(
        run,
        upgradeLevels: save.upgradeLevels,
        characterLevel: save.level,
        bugsCollected: save.bugs.length,
      ),
      equipmentBonus(save.equippedItems.values, data?.itemConfig),
    );

    return _box(
      Column(
        children: [
          _row(l.statAttack, formatCompact(s.attack)),
          _row(l.statAttackSpeed, '×${s.attackSpeed.toStringAsFixed(2)}'),
          _row(
            l.statCrit,
            '${(s.critChance * 100).toStringAsFixed(1)}% · '
            '×${s.critDamage.toStringAsFixed(2)}',
          ),
          _row(l.statHp, formatCompact(s.maxHp)),
          _row(l.statDefense, formatCompact(s.defense)),
          _row(l.statGoldGain, '×${s.rewardMultiplier.toStringAsFixed(2)}'),
          _row(l.statMaterialGain, '×${s.materialFind.toStringAsFixed(2)}'),
          _row(l.statBugFind, '×${s.bugFind.toStringAsFixed(2)}'),
        ],
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          child: Text(
            k,
            style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 12.5),
          ),
        ),
        Text(
          v,
          style: const TextStyle(
            color: _honey,
            fontWeight: FontWeight.w900,
            fontSize: 12.5,
          ),
        ),
      ],
    ),
  );
}

/// 펫 — 지금 받고 있는 보너스. 편성은 아직 채집함에서 한다(이동은 별도 단계).
class _PetsPanel extends ConsumerWidget {
  const _PetsPanel({required this.save});
  final SaveGame save;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final data = ref.watch(gameDataProvider).value;
    final cfg = data?.petConfig;
    var atk = '0';
    var hp = '0';
    if (cfg != null) {
      final now = ref.read(clockProvider).now().toUtc();
      final pets = <PetStat>[];
      for (final id in save.equippedBugIds) {
        IndividualBug? bug;
        for (final b in save.bugs) {
          if (b.id == id) {
            bug = b;
            break;
          }
        }
        final sp = bug == null ? null : data?.speciesById[bug.speciesId];
        if (bug == null || sp == null) continue;
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
      atk = ((pb.attackMult - 1) * 100).toStringAsFixed(0);
      hp = ((pb.hpMult - 1) * 100).toStringAsFixed(0);
    }
    return _box(
      Column(
        children: [
          Text(
            l.petBonus(atk, hp),
            style: const TextStyle(
              color: _honey,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l.charPetHint,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

/// 스킬 — 액티브·패시브 **공용 5칸**.
class _SkillsPanel extends ConsumerWidget {
  const _SkillsPanel({required this.save});
  final SaveGame save;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final cfg = ref.watch(gameDataProvider).value?.skillConfig;
    if (cfg == null) return const SizedBox.shrink();
    final locale = Localizations.localeOf(context).languageCode;
    final ctrl = ref.read(saveControllerProvider.notifier);

    return Column(
      children: [
        for (final def in cfg.skills) _row(context, l, locale, ctrl, cfg, def),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    AppLocalizations l,
    String locale,
    SaveController ctrl,
    SkillConfig cfg,
    SkillDef def,
  ) {
    final lv = save.skillLevels[def.id] ?? 0;
    final equipped = save.equippedSkills.contains(def.id);
    final owned = lv > 0;
    final cost = cfg.levelUpCost(lv + 1);
    final canLevel =
        lv < cfg.maxLevel &&
        save.gold >= cost.gold &&
        save.materialCount(MaterialKind.chitin) >= cost.material;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x55121A10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: equipped ? _honey : const Color(0x22FFFFFF),
          width: equipped ? 1.6 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            def.isActive ? Icons.bolt_rounded : Icons.auto_awesome_rounded,
            size: 18,
            color: def.isActive ? const Color(0xFF4FC3F7) : _honey,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  def.name.resolve(locale),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                Text(
                  owned ? 'Lv.$lv' : l.skillLearn,
                  style: const TextStyle(
                    color: Color(0x99FFFFFF),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (owned)
            _mini(equipped ? l.skillEquipped : l.charEquipment, () async {
              final wasFull = save.equippedSkills.length >= cfg.equipSlots;
              await ctrl.toggleSkill(def.id);
              // 칸이 차서 무시됐으면 이유를 알려준다 — 눌렀는데 아무 일도
              // 없으면 고장으로 보인다.
              if (!equipped && wasFull && context.mounted) {
                showCenterToast(context, l.skillSlotsFull);
              }
            }, on: equipped),
          const SizedBox(width: 6),
          _mini(
            owned ? '+' : l.skillLearn,
            canLevel
                ? () => ctrl.levelUpSkill(def.id)
                : () => showCenterToast(context, l.notEnoughGold),
            on: false,
            dim: !canLevel,
          ),
        ],
      ),
    );
  }

  Widget _mini(
    String text,
    VoidCallback onTap, {
    required bool on,
    bool dim = false,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: on ? const Color(0x33FFD54F) : const Color(0x22FFFFFF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: on ? _honey : const Color(0x33FFFFFF)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: dim ? const Color(0x66FFFFFF) : Colors.white,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );
}

/// 장비 8칸 — 부위마다 **낀 것 1개**. 가방이 없다.
class _EquipGrid extends StatelessWidget {
  const _EquipGrid({required this.save, required this.config});
  final SaveGame save;
  final ItemConfig config;

  @override
  Widget build(BuildContext context) => GridView.count(
    crossAxisCount: 4,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: 6,
    crossAxisSpacing: 6,
    childAspectRatio: 0.82,
    children: [
      for (final slot in EquipSlot.values)
        _EquipCell(slot: slot, item: save.equippedItems[slot], config: config),
    ],
  );
}

class _EquipCell extends StatelessWidget {
  const _EquipCell({
    required this.slot,
    required this.item,
    required this.config,
  });

  final EquipSlot slot;
  final EquipItem? item;
  final ItemConfig config;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final color = item == null
        ? const Color(0x33FFFFFF)
        : tierColor(config, item!.tier);
    return InkWell(
      onTap: item == null ? null : () => _detail(context, locale),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0x55121A10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color, width: item == null ? 1 : 1.8),
        ),
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (item == null)
              Icon(slotIcon(slot), size: 21, color: color)
            else
              itemImage(item!, size: 26, tint: color),
            const SizedBox(height: 3),
            Text(
              slotLabel(l, slot),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0x99FFFFFF),
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              item == null
                  ? l.charEmptySlot
                  : config.tier(item!.tier).name.resolve(locale),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: item == null ? const Color(0x66FFFFFF) : color,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _detail(BuildContext context, String locale) {
    final l = AppLocalizations.of(context);
    showGameDialog<void>(
      context,
      title: itemName(config, l, locale, item!),
      icon: slotIcon(slot),
      content: ItemOptionList(item: item!, config: config),
      actions: [gameDialogButton(l.actionClose, () => Navigator.pop(context))],
    );
  }
}

Widget _box(Widget child) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  decoration: BoxDecoration(
    color: const Color(0x55121A10),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: const Color(0x22FFFFFF)),
  ),
  child: child,
);
