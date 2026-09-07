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
  _optionTierTests();
  _autoStrikeTests();
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
      for (final lv in [0, 1, 7, 15, 20]) {
        final w = forge.tierWeights(lv, 10);
        expect(w.reduce((a, b) => a + b), closeTo(1.0, 1e-9));
      }
    });

    test('레벨이 오르면 하위 등급은 **아예** 안 나온다', () {
      final low = forge.tierWeights(1, 10);
      final high = forge.tierWeights(forge.maxLevel, 10);
      expect(low[0], greaterThan(0.3)); // 레벨1 은 풀잎이 주력
      expect(high[0], lessThan(0.0001)); // 최고 레벨이면 풀잎은 사실상 0
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

      // 레벨 상한이 20 이므로 그 안에서 본다 — 한 칸이 약 반 등급씩 민다.
      expect(peak(1), lessThan(peak(7)));
      expect(peak(7), lessThan(peak(14)));
      expect(peak(14), lessThan(peak(20)));
    });

    test('한 번에 나오는 등급은 3~4개뿐(창이 좁다)', () {
      for (final lv in [5, 12, 19]) {
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
          // 최대치는 **그 장비 등급의** 값이다(2026-09-07 개편).
          expect(o.value, lessThanOrEqualTo(r.maxAt(it.tier) + 0.05));
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
      final j10 = forge.levelUpJelly(forge.levelUpDuration(10));
      final j18 = forge.levelUpJelly(forge.levelUpDuration(18));
      expect(j18, greaterThan(j10));
      expect(j10, greaterThan(forge.levelUpJellyMin));
      expect(forge.levelUpJelly(Duration.zero), 0);
    });

    test('등급업 골드는 10칸으로 나뉘고, 칸 × 10 이 총액을 덮는다', () {
      expect(forge.levelUpSteps, 10);
      for (final lv in [0, 5, 10, 19]) {
        final total = forge.levelUpGold(lv);
        final step = forge.levelUpStepGold(lv);
        // 올림이라 칸 합이 총액보다 조금 클 수는 있어도 모자라면 안 된다.
        expect(step * forge.levelUpSteps, greaterThanOrEqualTo(total));
        expect(step * forge.levelUpSteps, lessThan(total + forge.levelUpSteps));
      }
    });

    test('골드는 레벨마다 오른다 — 업그레이드 15종과 경쟁시키는 축이다', () {
      expect(forge.levelUpGold(10), greaterThan(forge.levelUpGold(0)));
      expect(forge.levelUpGold(19), greaterThan(forge.levelUpGold(10)));
    });

    test('최고 레벨은 20 이고 거기서 최상위 등급이 주력이 된다', () {
      expect(forge.maxLevel, 20);
      final w = forge.tierWeights(forge.maxLevel, 10);
      expect(w.last, greaterThan(0.8));
    });
  });
}

/// 자동 제련 배수(2026-09-07). 챕터가 곧 개수이고, 회차를 넘겼으면 처음부터 상한.
void _autoStrikeTests() {
  const f = ForgeConfig(autoStrikeMax: 10, autoStrikeFullFromTier: 1);

  group('자동 제련 배수', () {
    test('쉬움 회차는 챕터 수만큼 — 1챕터 1개, 10챕터 10개', () {
      expect(f.autoStrikes(difficultyTier: 0, chapter: 1), 1);
      expect(f.autoStrikes(difficultyTier: 0, chapter: 5), 5);
      expect(f.autoStrikes(difficultyTier: 0, chapter: 10), 10);
    });

    test('상한을 넘지 않는다 — 캠페인 밖(11챕터 이상)도 10개', () {
      expect(f.autoStrikes(difficultyTier: 0, chapter: 99), 10);
    });

    test('0·음수 챕터도 최소 1개다 — 0개면 자동이 영영 안 돈다', () {
      expect(f.autoStrikes(difficultyTier: 0, chapter: 0), 1);
      expect(f.autoStrikes(difficultyTier: 0, chapter: -3), 1);
    });

    test('보통 회차부터는 1챕터에서도 상한이다', () {
      // ⚠️ 이게 깨지면 회차 전환(스테이지 1 리셋)이 **손해**가 된다 —
      // 2회차 시작이 1회차 끝보다 느려져 넘어갈 이유가 사라진다.
      expect(f.autoStrikes(difficultyTier: 1, chapter: 1), 10);
      expect(f.autoStrikes(difficultyTier: 3, chapter: 1), 10);
    });

    test('회차가 올라가도 배수는 더 커지지 않는다', () {
      expect(f.autoStrikes(difficultyTier: 9, chapter: 10), 10);
    });
  });
}

/// 옵션 개편(2026-09-07) — 등급별 최대치 · 2개 상한 · 죽은 축 제거.
void _optionTierTests() {
  final cfg = ItemConfig.fromJson(
    jsonDecode(File('../app/assets/data/items.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  group('옵션 등급별 최대치', () {
    test('모든 축이 등급 표를 갖는다 — 하나라도 없으면 그 축만 평평해진다', () {
      for (final r in cfg.optionPool) {
        expect(
          r.maxByTier.length,
          cfg.tierCount,
          reason: '${r.kind.key} 의 maxByTier 가 등급 수와 다르다',
        );
      }
    });

    test('등급이 오르면 최대치도 오른다(같은 값은 허용, 내려가면 안 된다)', () {
      for (final r in cfg.optionPool) {
        for (var t = 1; t < cfg.tierCount; t++) {
          expect(
            r.maxAt(t),
            greaterThanOrEqualTo(r.maxAt(t - 1)),
            reason: '${r.kind.key} 가 $t 등급에서 내려간다',
          );
        }
      }
    });

    test('최상위가 최하위보다 확실히 세다 — 여기가 모으는 이유다', () {
      for (final r in cfg.optionPool) {
        expect(
          r.maxAt(cfg.tierCount - 1),
          greaterThan(r.maxAt(0)),
          reason: '${r.kind.key} 는 등급을 올려도 이득이 없다',
        );
      }
    });

    test('옵션은 최대 2개다', () {
      for (var t = 0; t < cfg.tierCount; t++) {
        expect(cfg.tier(t).options, lessThanOrEqualTo(2));
        expect(cfg.tier(t).options, greaterThanOrEqualTo(1));
      }
    });

    test('효과가 구현되지 않은 축은 풀에 없다 — 2칸 중 하나가 꽝이 된다', () {
      // ⚠️ 나중에 구현하면 그때 풀에 되돌린다(equipment_stats 에 반영 후).
      const dead = {'skillDamage', 'skillCooldown', 'offline', 'pet'};
      for (final r in cfg.optionPool) {
        expect(dead.contains(r.kind.key), isFalse, reason: '${r.kind.key}');
      }
    });

    test('제련 결과가 그 등급 최대치를 넘지 않는다', () {
      final forge = ForgeConfig.fromJson(
        jsonDecode(File('../app/assets/data/forge.json').readAsStringSync())
            as Map<String, dynamic>,
      );
      final byKind = {for (final r in cfg.optionPool) r.kind: r};
      final rng = Random(1234);
      for (var i = 0; i < 3000; i++) {
        final item = forgeOnce(
          rng: rng,
          items: cfg,
          forge: forge,
          forgeLevel: rng.nextInt(forge.maxLevel + 1),
        );
        expect(item.options.length, lessThanOrEqualTo(2));
        for (final o in item.options) {
          expect(o.value, lessThanOrEqualTo(byKind[o.kind]!.maxAt(item.tier)));
        }
      }
    });
  });

  group('기존 장비 정리(trimItemOptions)', () {
    test('죽은 축은 버리고 2개까지만 남긴다', () {
      final item = EquipItem(
        slot: EquipSlot.tool,
        tier: 9,
        options: const [
          ItemOption(kind: ItemOptionKind.pet, value: 25),
          ItemOption(kind: ItemOptionKind.attack, value: 15),
          ItemOption(kind: ItemOptionKind.critDamage, value: 80),
          ItemOption(kind: ItemOptionKind.maxHp, value: 2),
        ],
      );
      final out = trimItemOptions(item, cfg);
      expect(out.options.length, 2);
      expect(
        out.options.map((o) => o.kind),
        isNot(contains(ItemOptionKind.pet)),
      );
      // 최대치 대비 비율로 고른다 — 날값이면 치명피해(80)가 항상 이기고
      // 공격(15)은 영영 안 남는다. 공격 15/30=0.50 vs 치명피해 80/150=0.53.
      expect(out.options.map((o) => o.kind), contains(ItemOptionKind.attack));
      expect(
        out.options.map((o) => o.kind),
        isNot(contains(ItemOptionKind.maxHp)),
      );
    });

    test('값은 깎지 않는다 — 가만있는데 약해지면 안 된다', () {
      const opt = ItemOption(kind: ItemOptionKind.attack, value: 15);
      final out = trimItemOptions(
        const EquipItem(slot: EquipSlot.tool, tier: 0, options: [opt]),
        cfg,
      );
      expect(out.options.single.value, 15);
    });

    test('이미 규칙에 맞으면 같은 객체를 돌려준다(매 저장마다 도는 자리다)', () {
      const item = EquipItem(
        slot: EquipSlot.tool,
        tier: 9,
        options: [ItemOption(kind: ItemOptionKind.attack, value: 5)],
      );
      expect(identical(trimItemOptions(item, cfg), item), isTrue);
    });
  });
}
