import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/providers.dart';
import '../../domain/save_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/format.dart';
import '../../ui/game_dialog.dart';
import '../../ui/toast.dart';
import 'equip_widgets.dart';
import 'forge_screen.dart';

const _honey = Color(0xFFFFD54F);

/// 캐릭터 탭 — **내 전력을 조립하는 곳**.
///
/// 장비 8부위 · 펫 3마리 · 스킬 5칸이 한 화면에 모인다. 채집함은 "곤충 목록"
/// 으로 역할이 갈린다 — 예전엔 채집함 상단에 펫 슬롯이 얹혀 있어 목록과
/// 전력 조립이 섞여 있었다.
class CharacterScreen extends ConsumerWidget {
  const CharacterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final save = ref.watch(saveControllerProvider).requireValue;
    final data = ref.watch(gameDataProvider).value;
    final items = data?.itemConfig;

    return Scaffold(
      appBar: AppBar(title: Text(l.navCharacter)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 24),
        children: [
          _PowerHeader(save: save),
          const SizedBox(height: 10),
          if (items != null) ...[
            _section(l.charEquipment),
            _EquipGrid(save: save, config: items),
            const SizedBox(height: 8),
            _ForgeEntry(save: save),
          ],
          const SizedBox(height: 14),
          _section(l.charSkills),
          _SkillPanel(save: save),
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 6, top: 2),
    child: Text(
      title,
      style: const TextStyle(
        color: _honey,
        fontWeight: FontWeight.w900,
        fontSize: 14,
      ),
    ),
  );
}

class _PowerHeader extends ConsumerWidget {
  const _PowerHeader({required this.save});
  final SaveGame save;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final data = ref.watch(gameDataProvider).value;
    final run = data?.runConfig;
    var power = 0.0;
    if (run != null) {
      final base = deriveStats(
        run,
        upgradeLevels: save.upgradeLevels,
        characterLevel: save.level,
        bugsCollected: save.bugs.length,
      );
      final withGear = applyEquipment(
        base,
        equipmentBonus(save.equippedItems.values, data?.itemConfig),
      );
      power = withGear.attack * withGear.attackSpeed;
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0x66121A10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: Column(
        children: [
          Text(
            l.charPower,
            style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 11.5),
          ),
          Text(
            formatCompact(power),
            style: const TextStyle(
              color: _honey,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

/// 장비 8칸 — 부위마다 **낀 것 1개**. 가방이 없다.
class _EquipGrid extends ConsumerWidget {
  const _EquipGrid({required this.save, required this.config});
  final SaveGame save;
  final ItemConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      childAspectRatio: 0.78,
      children: [
        for (final slot in EquipSlot.values)
          _EquipCell(
            slot: slot,
            item: save.equippedItems[slot],
            config: config,
          ),
      ],
    );
  }
}

class _EquipCell extends ConsumerWidget {
  const _EquipCell({
    required this.slot,
    required this.item,
    required this.config,
  });

  final EquipSlot slot;
  final EquipItem? item;
  final ItemConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final color = item == null
        ? const Color(0x33FFFFFF)
        : tierColor(config, item!.tier);
    return InkWell(
      onTap: item == null ? null : () => _showDetail(context, ref, locale),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0x55121A10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color, width: item == null ? 1 : 1.8),
        ),
        padding: const EdgeInsets.all(5),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(slotIcon(slot), size: 22, color: color),
            const SizedBox(height: 4),
            Text(
              slotLabel(l, slot),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0x99FFFFFF),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
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

  void _showDetail(BuildContext context, WidgetRef ref, String locale) {
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

/// 공방 진입 — 캐릭터 탭 하단의 모루.
class _ForgeEntry extends ConsumerWidget {
  const _ForgeEntry({required this.save});
  final SaveGame save;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final fossil = save.materialCount(MaterialKind.fossil);
    return InkWell(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const ForgeScreen())),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4A3420), Color(0xFF2A1D12)],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x55FFD54F)),
        ),
        child: Row(
          children: [
            const Icon(Icons.hardware_rounded, color: _honey, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.forgeTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    l.forgeLevel(save.forgeLevel + 1),
                    style: const TextStyle(
                      color: Color(0x99FFFFFF),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              formatCompact(fossil),
              style: const TextStyle(
                color: _honey,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: Color(0x99FFFFFF)),
          ],
        ),
      ),
    );
  }
}

/// 스킬 — **액티브·패시브 공용 5칸**. 나누면 선택이 사라진다.
class _SkillPanel extends ConsumerWidget {
  const _SkillPanel({required this.save});
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
        for (final s in cfg.skills) _skillRow(context, l, locale, ctrl, cfg, s),
      ],
    );
  }

  Widget _skillRow(
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
            _miniButton(equipped ? l.skillEquipped : l.charEquipment, () async {
              final before = save.equippedSkills.length;
              await ctrl.toggleSkill(def.id);
              if (!context.mounted) return;
              // 칸이 가득 차 무시됐으면 이유를 알려준다 — 눌렀는데 아무 일도
              // 없으면 고장으로 보인다.
              if (!equipped && before >= cfg.equipSlots) {
                showCenterToast(context, l.skillSlotsFull);
              }
            }, on: equipped),
          const SizedBox(width: 6),
          _miniButton(
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

  Widget _miniButton(
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
