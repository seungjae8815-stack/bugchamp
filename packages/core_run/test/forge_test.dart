import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:test/test.dart';

/// 실제 게임 데이터로 돈다 — JSON 을 고치면 여기서 먼저 깨진다.
ItemConfig _items() => ItemConfig.fromJson(
  jsonDecode(File('../app/assets/data/items.json').readAsStringSync())
      as Map<String, dynamic>,
);
ForgeConfig _forge() => ForgeConfig.fromJson(
  jsonDecode(File('../app/assets/data/forge.json').readAsStringSync())
      as Map<String, dynamic>,
);
SkillConfig _skills() => SkillConfig.fromJson(
  jsonDecode(File('../app/assets/data/skills.json').readAsStringSync())
      as Map<String, dynamic>,
);

void main() {
  group('장비 데이터(items.json)', () {
    final items = _items();

    test('부위 8종 × 등급 10 = 80종, 이름이 빠짐없이 있다', () {
      expect(items.slots.length, EquipSlot.values.length);
      expect(items.tierCount, 10);
      for (final slot in EquipSlot.values) {
        final def = items.slot(slot);
        expect(def, isNotNull, reason: '$slot 정의 없음');
        expect(def!.names.length, items.tierCount, reason: '$slot 이름 개수');
      }
    });

    test('부위마다 담당 축이 다르다 — 겹치면 "뭘 먼저 맞출까"가 사라진다', () {
      final axes = {for (final s in items.slots.values) s.baseStat};
      expect(axes.length, items.slots.length);
    });

    test('등급은 한 방향으로만 세진다(배수·옵션 수가 단조 증가)', () {
      for (var i = 1; i < items.tierCount; i++) {
        expect(
          items.tier(i).statMult,
          greaterThan(items.tier(i - 1).statMult),
          reason: '등급 $i 배수',
        );
        expect(
          items.tier(i).options,
          greaterThanOrEqualTo(items.tier(i - 1).options),
        );
      }
    });

    test('옵션 풀에 이동속도가 없다 — 뽑으면 실망하는 옵션은 넣지 않는다', () {
      final kinds = {for (final o in items.optionPool) o.kind};
      // moveSpeed 자체가 enum 에 없다(설계상 제외).
      expect(
        ItemOptionKind.values.map((e) => e.key),
        isNot(contains('moveSpeed')),
      );
      expect(kinds.length, items.optionPool.length); // 중복 정의 없음
    });
  });

  group('확률 창(공방 등급업)', () {
    final forge = _forge();

    test('합이 항상 1', () {
      for (final lv in [0, 1, 7, 15, 30, 40]) {
        final w = forge.tierWeights(lv, 10);
        expect(w.reduce((a, b) => a + b), closeTo(1.0, 1e-9));
      }
    });

    test('레벨이 오르면 하위 등급은 **아예** 안 나온다', () {
      final low = forge.tierWeights(1, 10);
      final high = forge.tierWeights(25, 10);
      expect(low[0], greaterThan(0.3)); // 레벨1 은 풀잎이 주력
      expect(high[0], lessThan(0.0001)); // 레벨25 면 풀잎은 사실상 0
      expect(high[1], lessThan(0.0001));
    });

    test('창이 위로 미끄러진다 — 최빈 등급이 레벨과 함께 오른다', () {
      int peak(int lv) {
        final w = forge.tierWeights(lv, 10);
        var best = 0;
        for (var i = 1; i < w.length; i++) {
          if (w[i] > w[best]) best = i;
        }
        return best;
      }

      expect(peak(1), lessThan(peak(10)));
      expect(peak(10), lessThan(peak(20)));
      expect(peak(20), lessThan(peak(30)));
    });

    test('한 번에 나오는 등급은 3~4개뿐(창이 좁다)', () {
      for (final lv in [5, 15, 25]) {
        final live = forge.tierWeights(lv, 10).where((w) => w >= 0.01).length;
        expect(live, lessThanOrEqualTo(4), reason: '레벨 $lv');
      }
    });
  });

  group('제련(forgeOnce)', () {
    final items = _items();
    final forge = _forge();

    test('결정론 — 같은 시드는 같은 장비(헌법 §5)', () {
      EquipItem roll() => forgeOnce(
        rng: Random(42),
        items: items,
        forge: forge,
        forgeLevel: 12,
      );
      final a = roll();
      final b = roll();
      expect(a.slot, b.slot);
      expect(a.tier, b.tier);
      expect(a.options, b.options);
    });

    test('등급이 정한 개수만큼 옵션이 붙고, 중복이 없다', () {
      final rng = Random(7);
      for (var i = 0; i < 300; i++) {
        final it = forgeOnce(
          rng: rng,
          items: items,
          forge: forge,
          forgeLevel: 20,
        );
        expect(it.options.length, items.tier(it.tier).options);
        expect(
          it.options.map((o) => o.kind).toSet().length,
          it.options.length,
          reason: '옵션 중복',
        );
      }
    });

    test('옵션 값이 정의된 범위 안에 있다', () {
      final ranges = {for (final r in items.optionPool) r.kind: r};
      final rng = Random(3);
      for (var i = 0; i < 500; i++) {
        final it = forgeOnce(
          rng: rng,
          items: items,
          forge: forge,
          forgeLevel: 25,
        );
        for (final o in it.options) {
          final r = ranges[o.kind]!;
          expect(o.value, greaterThanOrEqualTo(r.min - 0.05));
          expect(o.value, lessThanOrEqualTo(r.max + 0.05));
        }
      }
    });

    test('부위는 고르게 나온다(8부위 균등)', () {
      final rng = Random(11);
      final count = <EquipSlot, int>{};
      for (var i = 0; i < 8000; i++) {
        final it = forgeOnce(
          rng: rng,
          items: items,
          forge: forge,
          forgeLevel: 10,
        );
        count[it.slot] = (count[it.slot] ?? 0) + 1;
      }
      for (final s in EquipSlot.values) {
        expect(count[s], greaterThan(800)); // 기대 1000, 여유 있게
      }
    });
  });

  group('장비 능력치 합산', () {
    final items = _items();
    const base = CharacterStats(
      attack: 100,
      attackSpeed: 1.0,
      rewardMultiplier: 1.0,
      critChance: 0.0,
      critDamage: 1.5,
      bossDamage: 1.0,
      maxHp: 100,
      defense: 10,
      hpRegen: 0,
      xpMultiplier: 1.0,
      bugFind: 1.0,
      materialFind: 1.0,
      moveSpeed: 1.0,
      boostBonus: 1.0,
    );

    test('기본 스탯과 하위 옵션이 같은 축에 더해진다', () {
      // 채집도구(기본 공격 8% × 등급1 배수 1.0) + 공격 옵션 10%
      final item = EquipItem(
        slot: EquipSlot.tool,
        tier: 0,
        options: const [ItemOption(kind: ItemOptionKind.attack, value: 10)],
      );
      final bonus = equipmentBonus([item], items);
      expect(bonus[ItemOptionKind.attack], closeTo(18.0, 1e-9));
      expect(applyEquipment(base, bonus).attack, closeTo(118.0, 1e-9));
    });

    test('치명타 확률은 배율이 아니라 더하기 — 0에 곱하면 영원히 0이다', () {
      final bonus = {ItemOptionKind.critChance: 12.0};
      expect(applyEquipment(base, bonus).critChance, closeTo(0.12, 1e-9));
    });

    test('이동속도는 장비로 변하지 않는다(축에서 제외)', () {
      final bonus = {ItemOptionKind.attack: 50.0};
      expect(applyEquipment(base, bonus).moveSpeed, base.moveSpeed);
    });

    test('채집함 부위만 칸을 늘린다', () {
      const boxItem = EquipItem(slot: EquipSlot.box, tier: 9, options: []);
      const hatItem = EquipItem(slot: EquipSlot.hat, tier: 9, options: []);
      expect(equipmentStorageSlots([boxItem], items), greaterThan(0));
      expect(equipmentStorageSlots([hatItem], items), 0);
    });

    test('빈 장비면 능력치가 그대로다', () {
      expect(applyEquipment(base, equipmentBonus([], items)).attack, 100);
    });
  });

  group('스킬 데이터(skills.json)', () {
    final skills = _skills();

    test('장착 5칸, 액티브·패시브 공용', () {
      expect(skills.equipSlots, 5);
      expect(skills.actives.length, greaterThanOrEqualTo(8));
      expect(skills.passives.length, greaterThanOrEqualTo(8));
    });

    test('액티브는 전부 쿨타임이 있다', () {
      for (final s in skills.actives) {
        expect(s.cooldown, greaterThan(Duration.zero), reason: s.id);
      }
    });

    test('자동발동 효율은 1 미만 — 직접 누를 이유를 남긴다', () {
      expect(skills.autoEfficiency, lessThan(1.0));
      expect(skills.autoEfficiency, greaterThan(0.0));
    });

    test('레벨업 비용이 오른다', () {
      final a = skills.levelUpCost(1);
      final b = skills.levelUpCost(5);
      expect(b.gold, greaterThan(a.gold));
      expect(b.material, greaterThan(a.material));
    });

    test('id 가 중복되지 않는다', () {
      final ids = {for (final s in skills.skills) s.id};
      expect(ids.length, skills.skills.length);
    });
  });

  group('화석 조각(망치) 경제', () {
    final forge = _forge();

    test('3초에 1개 → 1시간이면 1,200개를 태운다', () {
      expect(3600 / forge.hammerSeconds, closeTo(1200, 1));
    });

    test('온라인 1시간 획득 = 제련 10분치', () {
      final perHour = forge.fossilPerSecond * 3600;
      expect(perHour, closeTo(200, 1));
      expect(perHour * forge.hammerSeconds / 60, closeTo(10, 0.1));
    });

    test('오프라인 3시간 = 온라인 1시간치', () {
      final off = forge.fossilPerSecond * forge.fossilOfflineRatio * 3 * 3600;
      expect(off, closeTo(200, 3));
    });

    test('등급업 시간이 레벨마다 길어지고, 젤리 값도 따라 오른다', () {
      expect(forge.levelUpDuration(5), greaterThan(forge.levelUpDuration(1)));
      // 초반 몇 칸은 몇 시간짜리라 **최소 젤리**에 걸린다(푼돈으로 못 넘기게).
      expect(
        forge.levelUpJelly(forge.levelUpDuration(1)),
        forge.levelUpJellyMin,
      );
      // 뒤로 갈수록 실제 시간에 비례해 오른다.
      final j10 = forge.levelUpJelly(forge.levelUpDuration(10));
      final j25 = forge.levelUpJelly(forge.levelUpDuration(25));
      expect(j25, greaterThan(j10));
      expect(j10, greaterThan(forge.levelUpJellyMin));
      expect(forge.levelUpJelly(Duration.zero), 0);
    });
  });
}
