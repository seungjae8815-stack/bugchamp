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
    this.rerollCost,
    this.onReroll,
  });

  final EquipItem item;
  final ItemConfig config;
  final EquipItem? compare;
  final bool dense;

  /// 옵션 한 칸을 다시 굴리는 젤리 값. null 이면 버튼을 안 그린다.
  ///
  /// **부위 기본 스탯 줄에는 안 붙인다** — 그건 옵션이 아니라 그 부위의
  /// 고정 성능이라 바꿀 수 있는 값이 아니다(바꾸면 부위의 정체가 사라진다).
  final int? rerollCost;

  /// 옵션 인덱스(0-based)를 받아 재굴림을 실행한다.
  final void Function(int index)? onReroll;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final rows = <Widget>[];

    // 부위 기본 스탯 줄은 **없앴다**(2026-09-09). 부위마다 축이 고정이면
    // 같은 등급끼리는 값도 같아 아이템끼리 고를 이유가 없다 — 장비는 이제
    // 무작위 옵션 2개로만 이루어지고, 둘 다 젤리로 바꿀 수 있다.
    final ranges = {for (final r in config.optionPool) r.kind: r};
    for (var i = 0; i < item.options.length; i++) {
      final o = item.options[i];
      rows.add(
        _row(
          optionLabel(l, o.kind),
          o.value,
          // 그 등급의 최대치를 옆에 보여 준다 — 최대가 얼마인지 모르면
          // "잘 뽑았다"를 알 수 없어 계속 돌릴 이유가 안 보인다(2026-09-14).
          max: ranges[o.kind]?.maxAt(item.tier),
          perfectLabel: l.optPerfect,
          // 옵션마다 따로 굴린다 — 통째로 굴리면 마음에 드는 한 줄까지
          // 같이 날아가서 원하는 조합을 못 맞춘다(2026-09-09 확정).
          onReroll: onReroll == null ? null : () => onReroll!(i),
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }

  Widget _row(
    String label,
    double value, {
    bool bold = false,
    double? delta,
    double? max,
    String? perfectLabel,
    VoidCallback? onReroll,
  }) {
    final up = delta != null && delta > 0.01;
    final down = delta != null && delta < -0.01;
    // 최대치 대비 비율로 색을 준다. 95% 이상은 금색 + "완벽" — 여기가
    // 제련을 계속 돌리게 하는 목표 지점이다.
    final ratio = (max == null || max <= 0) ? null : value / max;
    final perfect = ratio != null && ratio >= 0.95;
    final high = ratio != null && ratio >= 0.7;
    final valueColor = bold
        ? const Color(0xFFFFD54F)
        : perfect
        ? const Color(0xFFFFD54F)
        : high
        ? const Color(0xFFA5D6A7)
        : const Color(0xFFC5E1A5);
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
          if (perfect && perfectLabel != null && !dense)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                perfectLabel,
                style: const TextStyle(
                  color: Color(0xFFFFD54F),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          Text(
            '+${value.toStringAsFixed(value >= 10 ? 0 : 1)}%',
            style: TextStyle(
              color: valueColor,
              fontSize: dense ? 10.5 : 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          // 등급 최대치. 값과 같은 줄에 흐리게 — 비교 대상이 있어야
          // "23%" 가 좋은 건지 나쁜 건지 읽힌다.
          if (max != null && max > 0)
            Text(
              '/${max.toStringAsFixed(0)}',
              style: TextStyle(
                color: const Color(0x66FFFFFF),
                fontSize: dense ? 9 : 10.5,
                fontWeight: FontWeight.w600,
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
          // 옵션 줄 오른쪽에 **새로고침 + 젤리 + 값**. 눌러 보기 전에
          // 무엇을 얼마에 바꾸는지 보여야 한다(2026-09-09 확정).
          // ⚠️ 자리를 **있든 없든 늘 잡는다**(화살표 칸과 같은 원칙).
          // 조건부로 붙이면 버튼이 있는 줄만 라벨·값이 왼쪽으로 밀려
          // 글자 정렬이 어긋난다(2026-09-09 지적).
          // ⚠️ **좁은 칸에는 인라인으로 못 넣는다.** 제련 비교창은 2열이라
          // 한 쪽이 113px 뿐이고, 값(28)+화살표(16)+버튼(46)을 빼면 라벨에
          // 49px 만 남아 "치명타 확률"이 잘린다(2026-09-10 지적).
          // 좁은 쪽은 호출부가 비교창 **아래 전용 줄**로 뺀다.
          SizedBox(
            width: (rerollCost == null || dense) ? 0 : 46,
            child: (!dense && onReroll != null && rerollCost != null)
                ? GestureDetector(
                    onTap: onReroll,
                    child: Container(
                      margin: const EdgeInsets.only(left: 2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x337E57C2),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0x887E57C2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.refresh_rounded,
                            size: 11,
                            color: Color(0xFFCE93D8),
                          ),
                          if (!dense) ...[
                            const SizedBox(width: 1),
                            materialImage(
                              MaterialKind.jelly,
                              size: 10,
                              fallback: const Icon(
                                Icons.bubble_chart,
                                size: 9,
                                color: Color(0xFFCE93D8),
                              ),
                            ),
                            Text(
                              '$rerollCost',
                              style: const TextStyle(
                                color: Color(0xFFCE93D8),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}
