import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:test/test.dart';

/// 장비 v2(2026-10-10 사장님 확정, docs/design_equipment_v2.md) — 다듬기·환생 별. 실제 데이터로 돈다.
ItemConfig _items() => ItemConfig.fromJson(
  jsonDecode(File('../app/assets/data/items.json').readAsStringSync())
      as Map<String, dynamic>,
);
ForgeConfig _forge() => ForgeConfig.fromJson(
  jsonDecode(File('../app/assets/data/forge.json').readAsStringSync())
      as Map<String, dynamic>,
);

const _amber = 9;

EquipItem _item({
  EquipSlot slot = EquipSlot.tool,
  int tier = _amber,
  int stars = 0,
  int starExp = 0,
  List<ItemOption>? options,
}) => EquipItem(
  slot: slot,
  tier: tier,
  stars: stars,
  starExp: starExp,
  options:
      options ??
      const [
        ItemOption(kind: ItemOptionKind.attack, value: 5),
        ItemOption(kind: ItemOptionKind.critDamage, value: 10),
      ],
);

void main() {
  final items = _items();
  final forge = _forge();

  group('저장 키', () {
    test('기본값이면 키를 안 적고, 있으면 적고 읽는다(구버전 tryFromJson 도 읽는다)', () {
      expect(_item().toJson().containsKey('st'), isFalse);
      expect(_item().toJson().containsKey('sx'), isFalse);
      expect(
        (_item().toJson()['o'] as List).first as Map,
        isNot(contains('p')),
      );
      final it = _item(
        stars: 3,
        starExp: 2,
        options: const [
          ItemOption(kind: ItemOptionKind.attack, value: 5, polish: 4),
        ],
      );
      final back = EquipItem.tryFromJson(jsonDecode(jsonEncode(it.toJson())))!;
      expect(back.stars, 3);
      expect(back.starExp, 2);
      expect(back.options.first.polish, 4);
    });
  });

  group('다듬기', () {
    test('비용 — 화석 = 20 × (등급+1) · 젤리 15, 종류 지정은 ×3(젤리는 5 단위)', () {
      expect(forge.polishCost(_amber, pickKind: false), (
        fossils: 200,
        jelly: 15,
      ));
      expect(forge.polishCost(0, pickKind: false), (fossils: 20, jelly: 15));
      expect(forge.polishCost(_amber, pickKind: true), (
        fossils: 600,
        jelly: 45,
      ));
      expect(forge.polishCost(_amber, pickKind: true).jelly % 5, 0);
    });

    test('정성 +1 · 이전 값은 그대로(고르기 전) · 새 후보도 같은 정성', () {
      final r = polishOptionAt(
        rng: Random(1),
        items: items,
        item: _item(),
        index: 0,
      )!;
      expect(r.kept.options[0].value, 5);
      expect(r.kept.options[0].polish, 1);
      expect(r.candidate.polish, 1);
      expect(r.kept.options[1], _item().options[1]); // 다른 줄은 안 건드린다
    });

    test('종류 지정 — 그 종류로만 · 다른 줄에 있는 종류는 거절(null)', () {
      for (var seed = 0; seed < 30; seed++) {
        final r = polishOptionAt(
          rng: Random(seed),
          items: items,
          item: _item(),
          index: 0,
          kind: ItemOptionKind.bossDamage,
        )!;
        expect(r.candidate.kind, ItemOptionKind.bossDamage);
      }
      expect(
        polishOptionAt(
          rng: Random(1),
          items: items,
          item: _item(),
          index: 0,
          kind: ItemOptionKind.critDamage,
        ),
        isNull,
      );
    });

    test('무작위 종류는 다른 줄과 겹치지 않는다', () {
      for (var seed = 0; seed < 200; seed++) {
        final r = polishOptionAt(
          rng: Random(seed),
          items: items,
          item: _item(),
          index: 0,
        )!;
        expect(r.candidate.kind, isNot(ItemOptionKind.critDamage));
      }
    });

    test('정성이 쌓이면 바닥이 오른다 — 정성 10 이면 최대의 40% 아래로는 안 나온다', () {
      final maxed = _item(
        options: const [
          ItemOption(kind: ItemOptionKind.attack, value: 5, polish: 9),
          ItemOption(kind: ItemOptionKind.critDamage, value: 10),
        ],
      );
      final range = items.optionPool.firstWhere(
        (r) => r.kind == ItemOptionKind.bossDamage,
      );
      final lo =
          range.min +
          items.polishMaxStacks *
              items.polishFloorPerStack *
              (range.maxAt(_amber) - range.min);
      for (var seed = 0; seed < 200; seed++) {
        final r = polishOptionAt(
          rng: Random(seed),
          items: items,
          item: maxed,
          index: 0,
          kind: ItemOptionKind.bossDamage,
        )!;
        expect(r.candidate.polish, items.polishMaxStacks);
        expect(r.candidate.value, greaterThanOrEqualTo(lo - 0.05));
        expect(r.candidate.value, lessThanOrEqualTo(range.maxAt(_amber)));
      }
    });

    test('새 값 고르기는 그 줄만 바꾸고 별은 그대로', () {
      final it = _item(stars: 2);
      const cand = ItemOption(
        kind: ItemOptionKind.bossDamage,
        value: 30,
        polish: 1,
      );
      final out = applyPolish(it, 0, cand);
      expect(out.options[0], cand);
      expect(out.options[1], it.options[1]);
      expect(out.stars, 2);
    });

    test('옛 재굴림·옵션 채우기도 별을 지운다면 안 된다', () {
      final it = _item(stars: 4, starExp: 1);
      final r = rerollOptionAt(
        rng: Random(3),
        items: items,
        item: it,
        index: 0,
      );
      expect(r.stars, 4);
      expect(r.starExp, 1);
    });
  });

  group('환생 별', () {
    test('같은 부위 · 등급 ≥ 장착 −1 만 재료 · 만렙이면 안 된다', () {
      final t = _item();
      expect(canFeedStar(items, t, _item(tier: _amber)), isTrue);
      expect(canFeedStar(items, t, _item(tier: _amber - 1)), isTrue);
      expect(canFeedStar(items, t, _item(tier: _amber - 2)), isFalse);
      expect(canFeedStar(items, t, _item(slot: EquipSlot.ring)), isFalse);
      expect(canFeedStar(items, _item(stars: items.starMax), t), isFalse);
    });

    test('재료 1·2·3·4·5개마다 별 +1 — 5성까지 15개', () {
      var t = _item();
      var fed = 0;
      while (t.stars < items.starMax) {
        t = feedStar(items, t);
        fed++;
      }
      expect(fed, items.starNeed.fold(0, (a, b) => a + b));
      expect(fed, 15);
      expect(feedStar(items, t), t); // 만렙이면 그대로
    });

    test('효과 배율 — 별당 +4% · 회피는 빠진다', () {
      expect(items.starMult(5, ItemOptionKind.attack), closeTo(1.2, 1e-9));
      expect(items.starMult(5, ItemOptionKind.evade), 1);
      expect(items.starMult(0, ItemOptionKind.attack), 1);
      final bonus = equipmentBonus([
        _item(
          stars: 5,
          options: const [
            ItemOption(kind: ItemOptionKind.attack, value: 10),
            ItemOption(kind: ItemOptionKind.evade, value: 3),
          ],
        ),
      ], items);
      expect(bonus[ItemOptionKind.attack], closeTo(12, 1e-9));
      expect(bonus[ItemOptionKind.evade], closeTo(3, 1e-9));
    });

    test('바꿀 때 별 절반(내림)을 이어받는다 · 새 장비 별이 더 많으면 그대로', () {
      final old = _item(stars: 5);
      expect(inheritStars(items, old, _item(tier: _amber)).stars, 2);
      expect(inheritStars(items, old, _item(stars: 3)).stars, 3);
      expect(inheritStars(items, null, _item()).stars, 0);
    });

    test('상한 정리 — 세이브를 고쳐 99성·정성 99 를 적어도 상한으로', () {
      final cheat = _item(
        stars: 99,
        starExp: 99,
        options: const [
          ItemOption(kind: ItemOptionKind.attack, value: 5, polish: 99),
          ItemOption(kind: ItemOptionKind.critDamage, value: 10),
        ],
      );
      final t = trimItemOptions(cheat, items);
      expect(t.stars, items.starMax);
      expect(t.starExp, 0);
      expect(t.options[0].polish, items.polishMaxStacks);
      expect(t.options[0].value, 5);
    });
  });
}
