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

    // **한 화면에 담는다.** 스크롤을 넣으면 기기마다 잘리는 위치가 달라서
    // "내 폰에서만 공방이 안 보인다"가 된다. 대신 남는 높이를 장비 칸에
    // 몰아주고, 씬 높이는 화면에 비례시킨다 — 작은 폰은 알아서 낮아진다.
    return Scaffold(
      appBar: AppBar(title: Text(l.navCharacter)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: LayoutBuilder(
            builder: (context, c) => Column(
              children: [
                _tabs(l),
                const SizedBox(height: 8),
                SizedBox(
                  height: (c.maxHeight * 0.19).clamp(84.0, 132.0),
                  child: CharacterScene(save: save),
                ),
                const SizedBox(height: 8),
                // 펫·스킬은 아직 다듬는 중이다. 반쯤 된 걸 보여 주느니
                // **준비 중이라고 말한다** — 눌러도 아무 일이 없으면
                // 고장으로 읽힌다. 다시 켤 땐 이 분기만 되돌리면 된다.
                //
                // ⚠️ 장비·공방은 **능력치 탭에만** 붙인다. 준비 중 안내 밑에
                // 장비칸이 그대로 있으면 "펫인데 왜 장비가 있지"가 된다.
                if (_panel != _Panel.stats)
                  Expanded(
                    child: _SoonPanel(
                      label: _panel == _Panel.pets
                          ? l.charTabPets
                          : l.charTabSkills,
                    ),
                  )
                else ...[
                  _StatsPanel(save: save),
                  const SizedBox(height: 8),
                  if (items != null) ...[
                    // 남는 높이를 전부 장비 칸이 가져간다 — 칸 모양은 자기가
                    // 받은 높이로 정한다(작은 폰에선 납작해질 뿐 안 잘린다).
                    Expanded(
                      child: _EquipGrid(save: save, config: items),
                    ),
                    const SizedBox(height: 6),
                    // 장비 **바로 밑** — 가운데 제련, 좌우에 공방 등급·필터/자동.
                    const ForgeBar(),
                  ] else
                    const Spacer(),
                ],
              ],
            ),
          ),
        ),
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

    // 8줄을 세로로 세우면 화면의 3분의 1을 먹는다 — **두 줄씩 좌우로** 접어
    // 넣어 높이를 절반으로 줄인다. 캐릭터 탭이 한 화면에 들어와야 한다.
    final rows = <(String, String)>[
      (l.statAttack, formatCompact(s.attack)),
      (l.statAttackSpeed, '×${s.attackSpeed.toStringAsFixed(2)}'),
      (
        l.statCrit,
        '${(s.critChance * 100).toStringAsFixed(1)}%·'
            '×${s.critDamage.toStringAsFixed(2)}',
      ),
      (l.statHp, formatCompact(s.maxHp)),
      (l.statDefense, formatCompact(s.defense)),
      (l.statGoldGain, '×${s.rewardMultiplier.toStringAsFixed(2)}'),
      (l.statMaterialGain, '×${s.materialFind.toStringAsFixed(2)}'),
      (l.statBugFind, '×${s.bugFind.toStringAsFixed(2)}'),
    ];
    final half = (rows.length + 1) ~/ 2;

    return _box(
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: [for (final r in rows.take(half)) _row(r.$1, r.$2)],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              children: [for (final r in rows.skip(half)) _row(r.$1, r.$2)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(
          child: Text(
            k,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 11.5),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          v,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _honey,
            fontWeight: FontWeight.w900,
            fontSize: 11.5,
          ),
        ),
      ],
    ),
  );
}

/// 펫 — 지금 받고 있는 보너스. 편성은 아직 채집함에서 한다(이동은 별도 단계).
// 준비 중이라 지금은 안 쓴다. **지우지 않는다** — 다시 켤 때 그대로 붙인다.
// ignore: unused_element
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
// 준비 중이라 지금은 안 쓴다. **지우지 않는다** — 다시 켤 때 그대로 붙인다.
// ignore: unused_element
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

    // 스킬은 몇 개가 될지 모른다 — **높이를 묶어 두고 안에서 굴린다**.
    // 안 묶으면 스킬이 늘어날 때마다 캐릭터 탭이 한 화면을 넘긴다.
    return SizedBox(
      height: 168,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          for (final def in cfg.skills)
            _row(context, l, locale, ctrl, cfg, def),
        ],
      ),
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

  static const _cols = 4;
  static const _gap = 5.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      // 받은 높이에 **두 줄이 딱 맞게** 칸 비율을 역산한다. 고정 비율로 두면
      // 세로가 짧은 폰에서 넘치고 긴 폰에서는 아래가 텅 빈다.
      final w = (c.maxWidth - _gap * (_cols - 1)) / _cols;
      final h = (c.maxHeight - _gap) / 2;
      return GridView.count(
        crossAxisCount: _cols,
        shrinkWrap: true,
        // 계산이 빗나가도 넘치는 대신 스크롤된다 — 안전판.
        physics: const ClampingScrollPhysics(),
        mainAxisSpacing: _gap,
        crossAxisSpacing: _gap,
        childAspectRatio: h <= 0 ? 1.3 : (w / h).clamp(0.7, 2.6),
        children: [
          for (final slot in EquipSlot.values)
            _EquipCell(
              slot: slot,
              item: save.equippedItems[slot],
              config: config,
            ),
        ],
      );
    },
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
    // 그림이 **칸을 꽉 채운다**. 예전엔 26px 그림 아래에 부위·등급 글씨를
    // 쌓아서 정작 아이템이 제일 작았다 — 뭘 꼈는지 한눈에 안 들어왔다.
    // 글씨는 아래에 겹쳐 얹고, 등급은 테두리 색이 이미 말해 준다.
    return InkWell(
      onTap: item == null ? null : () => _detail(context, locale),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          // 등급을 **바탕색**으로도 알린다. 테두리 선만으로는 격자에서
          // 한눈에 안 들어온다 — 색 면적이 있어야 훑어보다 눈에 걸린다.
          // 그림이 죽지 않게 아주 옅게, 아래로 갈수록 어둡게.
          gradient: item == null
              ? null
              : LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    color.withValues(alpha: 0.34),
                    color.withValues(alpha: 0.10),
                  ],
                ),
          color: item == null ? const Color(0x55121A10) : null,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color, width: item == null ? 1 : 1.8),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (item == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(3, 3, 3, 12),
                child: LayoutBuilder(
                  builder: (context, c) => Center(
                    child: slotGhost(
                      slot,
                      size: c.biggest.shortestSide,
                      tint: color,
                    ),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(3),
                child: LayoutBuilder(
                  builder: (context, c) => Center(
                    child: itemImage(
                      item!,
                      size: c.biggest.shortestSide,
                      tint: color,
                    ),
                  ),
                ),
              ),
            // 낀 칸에는 **글씨를 안 넣는다.** 등급은 테두리·바탕색이 이미
            // 말하고 있어서, 이름까지 얹으면 그림 자리만 깎아먹는다.
            // 빈 칸만 어느 부위인지 알려 준다.
            if (item == null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  color: const Color(0xAA0D1408),
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Text(
                    slotLabel(l, slot),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0x88FFFFFF),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
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
      iconWidget: itemImage(item!, size: 40),
      content: ItemOptionList(item: item!, config: config),
      actions: [gameDialogButton(l.actionClose, () => Navigator.pop(context))],
    );
  }
}

/// 아직 안 연 탭 — **준비 중**이라고 분명히 말한다.
///
/// 빈 화면이나 반쯤 된 화면을 보여 주면 고장으로 읽힌다.
class _SoonPanel extends StatelessWidget {
  const _SoonPanel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _box(
      SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.construction_rounded,
              color: Color(0x99FFD54F),
              size: 26,
            ),
            const SizedBox(height: 6),
            Text(
              '$label · ${l.comingSoon}',
              style: const TextStyle(
                color: Color(0xCCFFFFFF),
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
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
