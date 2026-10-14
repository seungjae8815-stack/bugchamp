import 'dart:convert';
import 'dart:io';

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:test/test.dart';

/// 장비·요정 치명 피해 = **곱**(2026-10-14 사장님 확정).
///
/// 강화 치명 피해가 2.0 → 18.5 까지 자라서 가산이면 후반에 묽어졌다(펫 패시브·도감과 같은 이유).
/// 같은 숫자를 곱하면 ×2.3 이 되므로 효과 눈금을 함께 줄였다 — 장비는 저장 값·범위를 그대로 두고
/// `effectScale`(0.1)로 읽고, 요정은 비중(fairies.json)을 낮췄다. 맞춘 점 = 강화 치명 피해 10(중반).
void main() {
  Map<String, dynamic> load(String f) =>
      jsonDecode(File('../app/assets/data/$f').readAsStringSync())
          as Map<String, dynamic>;
  final items = ItemConfig.fromJson(load('items.json'));
  final fairies = FairyConfig.fromJson(load('fairies.json'));

  CharacterStats stats({double critDamage = 10}) => CharacterStats(
    attack: 100,
    attackSpeed: 1,
    rewardMultiplier: 1,
    critChance: 0.3,
    critDamage: critDamage,
    bossDamage: 1,
    maxHp: 1000,
    defense: 0,
    hpRegen: 1,
    xpMultiplier: 1,
    bugFind: 1,
    materialFind: 1,
    evade: 0,
    boostBonus: 0,
  );

  final amber = items.tierCount - 1;
  EquipItem gear(double critRaw, {int stars = 0}) => EquipItem(
    slot: EquipSlot.ring,
    tier: amber,
    stars: stars,
    options: [
      ItemOption(kind: ItemOptionKind.critDamage, value: critRaw),
      const ItemOption(kind: ItemOptionKind.attack, value: 20),
    ],
  );

  test('장비 치명 피해는 곱 — 강화 치명 피해가 커질수록 같이 커진다', () {
    for (final cd in [2.0, 10.0, 18.5]) {
      final s = applyEquipment(stats(critDamage: cd), const {
        ItemOptionKind.critDamage: 7,
      });
      expect(s.critDamage, closeTo(cd * 1.07, 1e-9), reason: 'cd=$cd');
    }
  });

  test('효과 눈금 — 치명 피해만 0.1, 나머지 옵션은 저장 값 그대로', () {
    expect(items.effectScaleOf(ItemOptionKind.critDamage), 0.1);
    for (final r in items.optionPool) {
      if (r.kind == ItemOptionKind.critDamage) continue;
      expect(r.effectScale, 1.0, reason: r.kind.key);
    }
    final bonus = equipmentBonus([gear(70)], items);
    expect(bonus[ItemOptionKind.critDamage], closeTo(7, 1e-9));
    expect(bonus[ItemOptionKind.attack], closeTo(20, 1e-9));
    // 환생 별 효과 배율과 함께 곱해진다(5성 = +20%).
    final starred = equipmentBonus([gear(70, stars: 5)], items);
    expect(
      starred[ItemOptionKind.critDamage],
      closeTo(7 * items.starMult(5, ItemOptionKind.critDamage), 1e-9),
    );
  });

  test('맞춘 점 — 강화 치명 피해 10 에서 예전 가산과 같고, 후반엔 덜 묽어진다', () {
    // 호박 최대 70: 예전 = cd + 0.70, 지금 = cd × (1 + 70 × 0.1 / 100).
    double now(double cd) => applyEquipment(
      stats(critDamage: cd),
      equipmentBonus([gear(70)], items),
    ).critDamage;
    expect(now(10), closeTo(10 + 0.70, 1e-9));
    expect(now(18.5), greaterThan(18.5 + 0.70)); // 후반: 묽어지지 않는다
    expect(now(18.5), lessThan(18.5 * 1.1)); // 폭주하지 않는다(같은 숫자를 곱하면 ×1.7)
  });

  test('기존 장비는 저장 값이 그대로 — 범위를 안 줄여서 잘리지 않는다', () {
    final top = items.optionPool
        .firstWhere((r) => r.kind == ItemOptionKind.critDamage)
        .maxAt(amber);
    final item = gear(top);
    final trimmed = trimItemOptions(item, items);
    expect(
      trimmed.options
          .firstWhere((o) => o.kind == ItemOptionKind.critDamage)
          .value,
      top,
    );
    // 중간 값도 그대로(범위를 줄였다면 새 최대치로 잘려 모두 최대가 됐다).
    final mid = trimItemOptions(gear(top / 2), items);
    expect(
      mid.options.firstWhere((o) => o.kind == ItemOptionKind.critDamage).value,
      top / 2,
    );
  });

  test('요정 치명 피해는 곱 · 비중은 강화 치명 피해 10 기준으로 ÷10', () {
    final s = applyFairyStats(stats(critDamage: 10), const {'critDamage': 0.1});
    expect(s.critDamage, closeTo(11, 1e-9));
    // 볼테아 신화 50레벨 최고 개체값: 예전 비중 4 → 가산 약 +1.01, 지금 0.4 → ×1.10(강화 10 에서 같은 값).
    const f = Fairy(
      id: 't',
      kind: 'voltea',
      grade: FairyGrade.mythic,
      sub: 'hp',
      level: 50,
      baseRoll: kFairyRollMax,
      subRoll: 0,
    );
    final v = fairies.mainBonus(f)['critDamage']!;
    expect(v, closeTo(0.101, 0.002));
    expect(10 * (1 + v), closeTo(10 + v * 10, 1e-9));
    expect(fairies.subWeight['critDamage'], closeTo(0.15, 1e-12));
  });
}
