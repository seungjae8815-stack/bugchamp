import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// 등급 색 — `items.json` 의 ARGB 문자열을 그대로 쓴다(코드에 색 하드코딩 금지).
Color tierColor(ItemConfig cfg, int tier) {
  final hex = cfg.tier(tier).color;
  return Color(int.parse(hex, radix: 16));
}

/// 부위 아이콘. 아트가 붙기 전까지의 폴백이다(§6 — 애셋 없으면 아이콘).
IconData slotIcon(EquipSlot s) => switch (s) {
  EquipSlot.tool => Icons.sports_martial_arts_rounded,
  EquipSlot.hat => Icons.emoji_people_rounded,
  EquipSlot.top => Icons.checkroom_rounded,
  EquipSlot.bottom => Icons.airline_seat_legroom_normal_rounded,
  EquipSlot.shoes => Icons.directions_walk_rounded,
  EquipSlot.necklace => Icons.workspace_premium_rounded,
  EquipSlot.ring => Icons.circle_outlined,
  EquipSlot.box => Icons.inventory_2_rounded,
};

String slotLabel(AppLocalizations l, EquipSlot s) => switch (s) {
  EquipSlot.tool => l.slotTool,
  EquipSlot.hat => l.slotHat,
  EquipSlot.top => l.slotTop,
  EquipSlot.bottom => l.slotBottom,
  EquipSlot.shoes => l.slotShoes,
  EquipSlot.necklace => l.slotNecklace,
  EquipSlot.ring => l.slotRing,
  EquipSlot.box => l.slotBox,
};

String optionLabel(AppLocalizations l, ItemOptionKind k) => switch (k) {
  ItemOptionKind.attack => l.optAttack,
  ItemOptionKind.attackSpeed => l.optAttackSpeed,
  ItemOptionKind.critChance => l.optCritChance,
  ItemOptionKind.critDamage => l.optCritDamage,
  ItemOptionKind.maxHp => l.optMaxHp,
  ItemOptionKind.defense => l.optDefense,
  ItemOptionKind.gold => l.optGold,
  ItemOptionKind.material => l.optMaterial,
  ItemOptionKind.bugFind => l.optBugFind,
  ItemOptionKind.bossDamage => l.optBossDamage,
  ItemOptionKind.skillDamage => l.optSkillDamage,
  ItemOptionKind.skillCooldown => l.optSkillCooldown,
  ItemOptionKind.boost => l.optBoost,
  ItemOptionKind.offline => l.optOffline,
  ItemOptionKind.pet => l.optPet,
};

/// `[호박] 지휘봉` — 등급 접두사 + 부위 이름.
String itemName(
  ItemConfig cfg,
  AppLocalizations l,
  String locale,
  EquipItem item,
) {
  final name = cfg.nameOf(item.slot, item.tier)?.resolve(locale) ?? '';
  return '[${cfg.tier(item.tier).name.resolve(locale)}] $name';
}

/// 장비 한 개의 옵션 줄들. [compare] 를 주면 증감 화살표를 붙인다.
class ItemOptionList extends StatelessWidget {
  const ItemOptionList({
    super.key,
    required this.item,
    required this.config,
    this.compare,
    this.dense = false,
  });

  final EquipItem item;
  final ItemConfig config;
  final EquipItem? compare;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final def = config.slot(item.slot);
    final rows = <Widget>[];

    if (def != null) {
      rows.add(
        _row(
          optionLabel(l, def.baseStat),
          def.valueAt(item.tier, config.tiers),
          bold: true,
          delta: compare == null
              ? null
              : def.valueAt(item.tier, config.tiers) -
                    def.valueAt(compare!.tier, config.tiers),
        ),
      );
    }
    for (final o in item.options) {
      rows.add(_row(optionLabel(l, o.kind), o.value));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }

  Widget _row(String label, double value, {bool bold = false, double? delta}) {
    final up = delta != null && delta > 0.01;
    final down = delta != null && delta < -0.01;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: dense ? 0.5 : 1.5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: const Color(0xB3FFFFFF),
                fontSize: dense ? 10.5 : 12,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          Text(
            '+${value.toStringAsFixed(value >= 10 ? 0 : 1)}%',
            style: TextStyle(
              color: bold ? const Color(0xFFFFD54F) : const Color(0xFFC5E1A5),
              fontSize: dense ? 10.5 : 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (up)
            const Icon(Icons.arrow_drop_up, size: 16, color: Color(0xFF9CCC65)),
          if (down)
            const Icon(
              Icons.arrow_drop_down,
              size: 16,
              color: Color(0xFFEF9A9A),
            ),
        ],
      ),
    );
  }
}
