import 'dart:convert';
import 'dart:io';

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:test/test.dart';

/// 장비 교체 별 인계(2026-10-12 사장님 확정) — 같은 등급이면 이어받고, 다르면 초기화.
final _items = ItemConfig.fromJson(
  jsonDecode(File('../app/assets/data/items.json').readAsStringSync())
      as Map<String, dynamic>,
);

void main() {
  final t0 = DateTime.utc(2026, 10, 12, 9);
  final until = t0.add(const Duration(hours: 5));
  final old = EquipItem(
    slot: EquipSlot.ring,
    tier: 7,
    stars: 3,
    starExp: 120,
    starUntil: until,
    options: const [
      ItemOption(kind: ItemOptionKind.attack, value: 10, polish: 6),
    ],
  );
  const fresh = EquipItem(
    slot: EquipSlot.ring,
    tier: 7,
    options: [ItemOption(kind: ItemOptionKind.critDamage, value: 30)],
  );

  test('같은 등급 → 별·별 재료·진행 중 강화를 그대로 이어받는다', () {
    final got = carryStarsOnSwap(_items, old, fresh);
    expect(got.stars, 3);
    expect(got.starExp, 120);
    expect(got.starUntil, until);
    expect(starsCarryOver(old, fresh), isTrue);
  });

  test('정성(옵션 p)은 인계하지 않는다 — 새 장비 옵션 그대로', () {
    final got = carryStarsOnSwap(_items, old, fresh);
    expect(got.options, fresh.options);
    expect(got.options.single.polish, 0);
  });

  test('다른 등급 → 초기화(예전과 같다)', () {
    final up = fresh.copyWith(tier: 8);
    final got = carryStarsOnSwap(_items, old, up);
    expect(got.stars, 0);
    expect(got.starExp, 0);
    expect(got.starUntil, isNull);
    expect(starsCarryOver(old, up), isFalse);
  });

  test('옛 장비에 별 투자가 없으면 새 장비 그대로', () {
    final plain = old.copyWith(stars: 0, starExp: 0, clearStarUntil: true);
    expect(carryStarsOnSwap(_items, plain, fresh), fresh);
    expect(starsCarryOver(plain, fresh), isFalse);
  });

  test('세이브 — 장착 교체와 모루 맨 위 빼기를 한 번에, 옛 장비는 사라진다(두 번 쓰지 않는다)', () {
    final s = SaveGame.initial(
      createdAt: t0,
    ).copyWith(equippedItems: {EquipSlot.ring: old}, forgeStack: const [fresh]);
    final r = equipWithStarCarry(s, _items, fresh, popForgeTop: true);
    expect(r.forgeStack, isEmpty);
    final ring = r.equippedItems[EquipSlot.ring]!;
    expect(ring.stars, 3);
    expect(ring.starExp, 120);
    expect(r.equippedItems.length, 1);
    // 세이브 왕복에도 남는다.
    final back = SaveGame.fromJson(r.toJson()).equippedItems[EquipSlot.ring]!;
    expect(back.stars, 3);
    expect(back.starUntil, until);
  });
}
