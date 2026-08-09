import 'package:core_models/core_models.dart';

import 'character_stats.dart';
import 'item_config.dart';

/// 장착한 장비들이 축별로 주는 **합계 보너스(%)**.
///
/// 부위의 기본 스탯과 하위 옵션이 **같은 축을 공유**한다 — 채집도구의 기본
/// 공격력과 반지에 붙은 공격력 옵션이 같은 통에 더해진다.
Map<ItemOptionKind, double> equipmentBonus(
  Iterable<EquipItem> equipped,
  ItemConfig? config,
) {
  final out = <ItemOptionKind, double>{};
  if (config == null) return out;
  for (final item in equipped) {
    final def = config.slot(item.slot);
    if (def != null) {
      out[def.baseStat] =
          (out[def.baseStat] ?? 0) + def.valueAt(item.tier, config.tiers);
    }
    for (final o in item.options) {
      out[o.kind] = (out[o.kind] ?? 0) + o.value;
    }
  }
  return out;
}

/// 장비가 늘려주는 채집함 칸(채집함 부위 전용).
int equipmentStorageSlots(Iterable<EquipItem> equipped, ItemConfig? config) {
  if (config == null) return 0;
  var sum = 0;
  for (final item in equipped) {
    sum += config.slot(item.slot)?.storageAt(item.tier) ?? 0;
  }
  return sum;
}

/// 장비 보너스를 능력치에 얹는다.
///
/// ⚠️ 이 결과는 **적응형 몬스터 체력의 기준으로 쓰지 않는다**(§6). 기준은
/// 업그레이드(러닝머신)뿐이고 장비·펫·스킬·버프는 전부 순수 이득이다.
/// 여기 넣으면 좋은 장비를 껴도 몬스터가 같이 세져 **모으는 맛이 사라진다**
/// — 전설 장비를 껴도 체감 1.7배밖에 안 됐다(실측).
CharacterStats applyEquipment(
  CharacterStats base,
  Map<ItemOptionKind, double> bonus,
) {
  if (bonus.isEmpty) return base;
  double m(ItemOptionKind k) => 1 + (bonus[k] ?? 0) / 100.0;
  double add(ItemOptionKind k) => (bonus[k] ?? 0) / 100.0;

  return CharacterStats(
    attack: base.attack * m(ItemOptionKind.attack),
    attackSpeed: base.attackSpeed * m(ItemOptionKind.attackSpeed),
    rewardMultiplier: base.rewardMultiplier * m(ItemOptionKind.gold),
    // 치명타 **확률**은 배율이 아니라 더하기다(0.05 = +5%p).
    // 배율로 넣으면 기본 확률이 0 인 유저에게 아무 일도 일어나지 않는다.
    critChance: (base.critChance + add(ItemOptionKind.critChance)).clamp(
      0.0,
      1.0,
    ),
    critDamage: base.critDamage + add(ItemOptionKind.critDamage),
    bossDamage: base.bossDamage * m(ItemOptionKind.bossDamage),
    maxHp: base.maxHp * m(ItemOptionKind.maxHp),
    defense: base.defense * m(ItemOptionKind.defense),
    hpRegen: base.hpRegen,
    xpMultiplier: base.xpMultiplier,
    bugFind: base.bugFind * m(ItemOptionKind.bugFind),
    materialFind: base.materialFind * m(ItemOptionKind.material),
    // 이동속도는 장비 축에 없다(§3.3) — 그대로 둔다.
    moveSpeed: base.moveSpeed,
    boostBonus: base.boostBonus * m(ItemOptionKind.boost),
  );
}
