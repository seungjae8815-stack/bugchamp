import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/art.dart';

/// 등급 색 — `items.json` 의 ARGB 문자열을 그대로 쓴다(코드에 색 하드코딩 금지).
Color tierColor(ItemConfig cfg, int tier) {
  final hex = cfg.tier(tier).color;
  return Color(int.parse(hex, radix: 16));
}

/// 부위 아이콘. **그림도 없을 때**의 마지막 폴백이다(§6 — 애셋 없으면 아이콘).
///
/// ⚠️ 사람 모양(운동하는 사람·앉은 사람)을 쓰면 안 된다 — 장비 칸에
/// 사람이 들어가 있어 무슨 부위인지 안 읽힌다. 실제로 그래 보였다.
IconData slotIcon(EquipSlot s) => switch (s) {
  EquipSlot.tool => Icons.sports_tennis_rounded, // 라켓 ≈ 채집망
  EquipSlot.hat => Icons.school_rounded, // 챙 있는 모자
  EquipSlot.top => Icons.checkroom_rounded,
  EquipSlot.bottom => Icons.dry_cleaning_rounded,
  EquipSlot.shoes => Icons.ice_skating_rounded, // 발에 신는 것
  EquipSlot.necklace => Icons.diamond_rounded,
  EquipSlot.ring => Icons.circle_outlined,
  EquipSlot.box => Icons.inventory_2_rounded,
};

/// 빈 칸에 깔리는 **흐린 밑그림**.
///
/// 아이콘으로 무슨 부위인지 알리려니 마땅한 그림이 없다(채집도구가 사람
/// 모양으로 보였다). 대신 **가장 낮은 등급의 실제 장비 그림**을 흐리게 깔면
/// 어떤 부위인지 정확히 읽히고, 끼면 같은 자리에 선명한 그림이 들어온다.
Widget slotGhost(EquipSlot slot, {required double size, Color? tint}) {
  final id = '${slot.key}_${_tierId(0)}';
  return Opacity(
    opacity: 0.30,
    child: gameImageChain(
      ['assets/images/items/$id.webp', 'assets/images/items/$id.png'],
      size: size,
      fallback: Icon(slotIcon(slot), size: size * 0.5, color: tint),
    ),
  );
}

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

/// 장비 그림. 파일이 없으면 부위 아이콘으로 폴백한다(§6 — 애셋 없으면 아이콘).
///
/// 경로는 `items/{부위}_{등급id}.webp` 로 **JSON 의 id 와 정확히 일치**해야 한다.
/// 오타면 에러 없이 조용히 아이콘으로 떨어지므로 눈으로 확인해야 한다.
///
/// ⚠️ **그림에 색을 입히지 않는다.** 등급색은 칸 테두리가 이미 칠하고 있어서,
/// 그림까지 물들이면 재질(구리·은·호박)이 뭉개진다.
Widget itemImage(EquipItem item, {required double size, Color? tint}) {
  final id = '${item.slot.key}_${_tierId(item.tier)}';
  return gameImageChain(
    [
      'assets/images/items/$id.webp',
      // **png 도 그대로 읽는다** — 생성한 그림을 webp 로 변환하는 수고를 없앤다.
      // webp 가 더 가벼우니 출시 전에는 변환하는 게 좋지만, 작업 중에 막히지 않게.
      'assets/images/items/$id.png',
    ],
    size: size,
    fallback: Icon(slotIcon(item.slot), size: size * 0.9, color: tint),
  );
}

/// 등급 인덱스 → JSON id. 파일명이 이 값을 그대로 쓴다.
String _tierId(int tier) => const [
  'grass',
  'wood',
  'leather',
  'copper',
  'iron',
  'silver',
  'gold',
  'chitin',
  'carapace',
  'amber',
][tier.clamp(0, 9)];

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
          // 화살표 자리는 **있든 없든 늘 잡아 둔다.** 조건부로 붙이면 화살표가
          // 있는 줄만 값이 왼쪽으로 밀려 숫자 열이 삐뚤어진다.
          SizedBox(
            width: 16,
            child: up
                ? const Icon(
                    Icons.arrow_drop_up,
                    size: 16,
                    color: Color(0xFF9CCC65),
                  )
                : down
                ? const Icon(
                    Icons.arrow_drop_down,
                    size: 16,
                    color: Color(0xFFEF9A9A),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}
