import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';

import 'save_game.dart';

/// 장비 교체 때 별 인계(2026-10-12 사장님 확정) — 같은 부위에서 **같은 등급** 장비로 바꾸면 새 장비가
/// 별(`stars`)·모은 별 재료(`starExp`)·진행 중 별 강화(`starUntil`)를 그대로 이어받는다. 옛 장비는 사라지므로
/// (가방이 없다) 두 번 쓰일 일이 없다. 등급이 다르면 예전처럼 초기화(`inheritStars` — `starInheritRatio` 0).
/// 정성(옵션 `p`)·다듬기 기록은 옵션에 붙은 것이라 인계하지 않는다(새 장비의 옵션 그대로).
///
/// 새 장비가 원래 별을 더 많이 갖고 있으면(보통은 모루에서 막 나온 0성) 새 장비 그대로.
EquipItem carryStarsOnSwap(ItemConfig items, EquipItem? from, EquipItem to) {
  if (from == null) return to;
  if (from.slot != to.slot || from.tier != to.tier) {
    return inheritStars(items, from, to);
  }
  if (!starsCarryOver(from, to)) return to;
  return to.copyWith(
    stars: from.stars.clamp(0, items.starMax),
    starExp: from.starExp,
    starUntil: from.starUntil,
    clearStarUntil: from.starUntil == null,
  );
}

/// [from] 을 [to] 로 바꿀 때 별이 이어지는가(같은 부위 · 같은 등급 · 옛 장비에 별 투자가 있고 새 장비보다 많다).
/// 확인 창 문구(이어받아요 / 사라져요)가 이 값으로 갈린다.
bool starsCarryOver(EquipItem from, EquipItem to) =>
    from.slot == to.slot &&
    from.tier == to.tier &&
    (from.stars > 0 || from.starExp > 0 || from.starUntil != null) &&
    from.stars >= to.stars;

/// [item] 을 그 부위에 낀 세이브(옛 장비는 사라진다). [popForgeTop] 이면 모루 맨 위([item])를 같은 저장에서 뺀다 —
/// 두 번 나눠 저장하면 그 사이 앱이 꺼질 때 장착과 모루에 같은 장비가 하나씩 남았다(2026-10-10).
SaveGame equipWithStarCarry(
  SaveGame s,
  ItemConfig items,
  EquipItem item, {
  bool popForgeTop = false,
}) => s.copyWith(
  equippedItems: {
    ...s.equippedItems,
    item.slot: carryStarsOnSwap(items, s.equippedItems[item.slot], item),
  },
  forgeStack: popForgeTop && s.forgeStack.isNotEmpty
      ? s.forgeStack.sublist(0, s.forgeStack.length - 1)
      : null,
);
