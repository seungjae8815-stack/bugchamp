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
  _forgeSinkTests();
  _critCapTests();
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

    test('⚠️ 부위 기본 스탯은 더 이상 안 실린다 — 옵션만 더해진다', () {
      // 2026-09-09: 부위마다 축이 고정이면 같은 등급끼리는 값도 같아
      // **아이템끼리 고를 이유가 없다**. 장비는 무작위 옵션 2 개로만 이룬다.
      final item = EquipItem(
        slot: EquipSlot.tool,
        tier: 0,
        options: const [ItemOption(kind: ItemOptionKind.attack, value: 10)],
      );
      final bonus = equipmentBonus([item], items);
      expect(bonus[ItemOptionKind.attack], closeTo(10.0, 1e-9));
      expect(applyEquipment(base, bonus).attack, closeTo(110.0, 1e-9));
    });

    test('같은 축 옵션은 부위가 달라도 합산된다', () {
      const a = EquipItem(
        slot: EquipSlot.tool,
        tier: 0,
        options: [ItemOption(kind: ItemOptionKind.attack, value: 10)],
      );
      const b = EquipItem(
        slot: EquipSlot.ring,
        tier: 0,
        options: [ItemOption(kind: ItemOptionKind.attack, value: 7)],
      );
      expect(
        equipmentBonus([a, b], items)[ItemOptionKind.attack],
        closeTo(17.0, 1e-9),
      );
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

    test('12종 · 등급 4단계에 고르게 · 칸은 진행도로 2 → 5', () {
      expect(skills.skills.length, 12);
      for (final g in kSkillGrades) {
        expect(
          skills.skills.where((s) => s.grade == g).length,
          3,
          reason: g.key,
        );
      }
      expect(skills.skills.any((s) => s.grade == Grade.uncommon), isFalse);
      expect(skills.slotsFor(0), 2);
      expect(skills.slotsFor(3), 5);
      expect(skills.slotsFor(99), 5); // 넘어도 마지막 값
      expect(skills.maxSlots, 5);
    });

    test('액티브는 전부 쿨타임이 있다', () {
      for (final s in skills.actives) {
        expect(s.cooldown, greaterThan(Duration.zero), reason: s.id);
      }
    });

    test('효과 키에 오타가 없다 — 모르는 키는 효과만 조용히 사라진다', () {
      for (final s in skills.skills) {
        final known = s.isActive ? kSkillActiveEffects : kSkillPassiveEffects;
        expect(known, contains(s.effect), reason: s.id);
      }
    });

    test('등급마다 조각·수련 값이 있다(없으면 0 조각으로 공짜 레벨업)', () {
      for (final g in kSkillGrades) {
        expect(skills.levelShardsBase[g], greaterThan(0), reason: g.key);
        expect(skills.trainMinutesBase[g], greaterThan(0), reason: g.key);
      }
      expect(skills.unlockShards, 100);
      expect(skills.gradeUpRatio, greaterThan(1));
      expect(SkillConfig.nextGrade(Grade.common), Grade.rare);
      expect(SkillConfig.nextGrade(Grade.epic), Grade.legendary);
      expect(SkillConfig.nextGrade(Grade.legendary), isNull);
    });

    test('레벨이 오를수록 조각·수련 시간이 늘고, 높은 등급일수록 수련이 길다', () {
      final common = skills.skills.firstWhere((s) => s.grade == Grade.common);
      final legend = skills.skills.firstWhere(
        (s) => s.grade == Grade.legendary,
      );
      expect(
        skills.shardsForLevel(common, 5),
        greaterThan(skills.shardsForLevel(common, 1)),
      );
      expect(
        skills.trainDuration(common, 5),
        greaterThan(skills.trainDuration(common, 1)),
      );
      expect(
        skills.trainDuration(legend, 1),
        greaterThan(skills.trainDuration(common, 1)),
      );
    });

    test('수련 즉시완료 젤리는 5·10 단위(§2.6 가격 단위)', () {
      final legend = skills.skills.firstWhere(
        (s) => s.grade == Grade.legendary,
      );
      for (var lv = 1; lv < skills.maxLevel; lv++) {
        final j = skills.trainJelly(skills.trainDuration(legend, lv));
        expect(j % 5, 0, reason: 'Lv$lv $j');
        expect(j, greaterThan(0));
      }
      expect(skills.trainJelly(Duration.zero), 0);
    });

    test('드롭 등급 표가 난이도 4개 · 어려운 난이도일수록 전설이 잦다', () {
      expect(skills.dropGradeWeightsByTier.length, 4);
      expect(skills.bossRepeatShardsByTier.length, 4);
      double legendShare(Map<Grade, double> w) =>
          (w[Grade.legendary] ?? 0) / w.values.fold(0.0, (a, b) => a + b);
      for (var t = 1; t < 4; t++) {
        expect(
          legendShare(skills.dropGradeWeightsByTier[t]),
          greaterThan(legendShare(skills.dropGradeWeightsByTier[t - 1])),
        );
      }
    });

    test('보스 첫 처치는 확정 · 재처치·정예는 확률 · 한 번에 한 스킬', () {
      int total(Map<String, int> m) => m.values.fold(0, (a, b) => a + b);
      final a = skills.rollBossShards(Random(7), tier: 2, firstKill: true);
      expect(a, skills.rollBossShards(Random(7), tier: 2, firstKill: true));
      expect(a.length, 1);
      expect(total(a), skills.bossFirstKillShards);
      expect(skills.byId(a.keys.single), isNotNull);

      var repeatHits = 0, eliteHits = 0;
      const n = 4000;
      for (var i = 0; i < n; i++) {
        final r = skills.rollBossShards(Random(i), tier: 3, firstKill: false);
        if (r.isNotEmpty) {
          repeatHits++;
          expect(total(r), skills.bossRepeatShardsByTier[3]);
        }
        final e = skills.rollEliteShards(Random(i + n), tier: 0);
        if (e.isNotEmpty) {
          eliteHits++;
          expect(total(e), skills.eliteShards);
        }
      }
      expect(repeatHits / n, closeTo(skills.bossRepeatChance, 0.02));
      expect(eliteHits / n, closeTo(skills.eliteShardChance, 0.02));
    });

    test('뽑기 등급 확률은 어느 난이도의 드롭보다도 좋다 — 돈 내고 나빠지면 안 된다', () {
      double share(Map<Grade, double> w, Set<Grade> gs) {
        final total = w.values.fold(0.0, (a, b) => a + b);
        return [for (final g in gs) w[g] ?? 0].fold(0.0, (a, b) => a + b) /
            total;
      }

      const top = {Grade.legendary};
      const high = {Grade.epic, Grade.legendary};
      for (final w in skills.dropGradeWeightsByTier) {
        expect(
          share(skills.gachaGradeWeights, top),
          greaterThanOrEqualTo(share(w, top)),
        );
        expect(
          share(skills.gachaGradeWeights, high),
          greaterThanOrEqualTo(share(w, high)),
        );
      }
      final odds = skills.gachaGradeOdds;
      expect(odds.values.fold(0.0, (a, b) => a + b), closeTo(1, 1e-9));
    });

    test('액티브 타이밍 보너스 — 일격은 보스 체력 기준 · 방벽은 물기 직전 반사', () {
      final strike = skills.skills.firstWhere((d) => d.effect == 'burstDamage');
      expect(strike.timingValue('bossHpBelow'), inExclusiveRange(0, 1));
      expect(strike.timingValue('mult'), greaterThan(1));
      final guard = skills.skills.firstWhere((d) => d.effect == 'invulnerable');
      expect(guard.timingValue('window'), greaterThan(0));
      expect(guard.timingValue('reflectAttackMult'), greaterThan(0));
      expect(guard.timingValue('cooldownRefund'), inInclusiveRange(0, 1));
      // 지속형 액티브는 지속시간이 있어야 켜진다.
      for (final d in skills.actives) {
        if (const {
          'attackSpeed',
          'materialFind',
          'petPower',
          'invulnerable',
        }.contains(d.effect)) {
          expect(d.duration, greaterThan(Duration.zero), reason: d.id);
        }
      }
    });

    test('뽑기 천장 — 천장 회차면 천장 등급 이상만', () {
      for (var i = 0; i < 300; i++) {
        final r = skills.rollGacha(Random(i), pityDue: true)!;
        expect(r.$2.index, greaterThanOrEqualTo(skills.gachaPityGrade.index));
      }
      expect(skills.sweepShardsFor(3), skills.sweepShardsByTier.last);
    });

    test('패시브 — 장착한 것만 · 군집은 펫 수에 비례 · 흡즙·탈피', () {
      final levels = {'tenacity': 1, 'swarm': 2, 'sap_drink': 1, 'molting': 1};
      final none = skillPassiveStats(
        skills,
        levels: levels,
        equipped: const [],
        petCount: 3,
      );
      expect(none, isEmpty);
      final on = skillPassiveStats(
        skills,
        levels: levels,
        equipped: const ['tenacity', 'swarm'],
        petCount: 3,
      );
      expect(on[UpgradeKind.bossDamage], closeTo(0.15, 1e-9));
      expect(on[UpgradeKind.attack], closeTo((0.06 + 0.01) * 3, 1e-9));
      expect(
        skillKillHealMult(
          skills,
          levels: levels,
          equipped: const ['sap_drink'],
        ),
        closeTo(1.2, 1e-9),
      );
      expect(skillRevive(skills, levels: levels, equipped: const []), isNull);
      expect(
        skillRevive(
          skills,
          levels: levels,
          equipped: const ['molting'],
        )!.hpFraction,
        closeTo(0.35, 1e-9),
      );
    });

    test('순간 피해 = 지금 초당 피해 × 값(초) — 공속·치명이 자라도 묽어지지 않는다', () {
      CharacterStats st({required double speed, required double crit}) =>
          CharacterStats(
            attack: 100,
            attackSpeed: speed,
            rewardMultiplier: 1,
            critChance: crit,
            critDamage: 3,
            bossDamage: 2,
            maxHp: 1000,
            defense: 0,
            hpRegen: 0,
            xpMultiplier: 1,
            bugFind: 1,
            materialFind: 1,
            moveSpeed: 1,
            boostBonus: 0,
          );
      final slow = st(speed: 2, crit: 0);
      // 100 × 2타/초 × 4초 = 800. 보스면 보스 피해 ×2.
      expect(skillBurstDamage(slow, 4), closeTo(800, 1e-9));
      expect(skillBurstDamage(slow, 4, boss: true), closeTo(1600, 1e-9));
      // 공속·치명이 올라도 "초당 피해 대비 몇 초"는 그대로다.
      final fast = st(speed: 8, crit: 0.5);
      final dps = baselineHitPower(fast) * fast.attackSpeed;
      expect(skillBurstDamage(fast, 4) / dps, closeTo(4, 1e-9));
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
      for (final lv in [0, 5, 10, forge.maxLevel - 1]) {
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

    /// 2026-09-15: 최대 레벨 19(화면 20등급). 16등급까지는 최상위(호박)가 귀하고
    /// (90일 계획 안), 17~20등급은 극한 이후의 목표라 거기서 주력이 된다.
    test('최고 레벨(화면 20등급)에서 최상위 등급이 주력이 된다', () {
      expect(forge.maxLevel, 19);
      expect(forge.tierWeights(forge.maxLevel, 10).last, greaterThan(0.5));
      expect(
        forge.tierWeights(15, 10).last,
        lessThan(0.3),
        reason: '90일 계획 안(공방 15)에서 흔하면 극한에서 장비가 넘친다',
      );
    });

    test('가파른 구간은 lateSpan 만큼만 — 그 뒤는 endGoldGrowth', () {
      final f = forge.levelUpLateFrom;
      double step(int lv) => forge.levelUpGold(lv) / forge.levelUpGold(lv - 1);
      expect(step(f + 1), closeTo(forge.levelUpLateGoldGrowth, 0.01));
      expect(
        step(f + forge.levelUpLateSpan + 1),
        closeTo(forge.levelUpEndGoldGrowth, 0.01),
      );
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

  group('고른 배수(2026-09-08)', () {
    int eff(int chosen, {int chapter = 5, int tier = 0}) => f.effectiveStrikes(
      difficultyTier: tier,
      chapter: chapter,
      chosen: chosen,
    );

    test('0 이면 해금 상한 그대로 — 고른 적 없는 유저의 체감이 안 바뀐다', () {
      expect(eff(0), 5);
      expect(eff(0, chapter: 2), 2);
      expect(eff(0, chapter: 1, tier: 1), 10);
    });

    test('상한 안에서 고르면 그 값 — 적게도 고를 수 있다', () {
      expect(eff(1), 1);
      expect(eff(3), 3);
      expect(eff(5), 5);
    });

    test('상한을 넘겨 고르면 상한으로 잘린다 — 세이브를 고쳐도 챕터를 못 건너뛴다', () {
      expect(eff(9, chapter: 5), 5);
      expect(eff(999, chapter: 5), 5);
      expect(eff(999, chapter: 1, tier: 1), 10);
    });

    test('음수도 상한으로 — 0개면 자동이 영영 안 돈다', () {
      expect(eff(-4), 5);
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

    test('최대치 안의 값은 깎지 않는다 — 가만있는데 약해지면 안 된다', () {
      final hi = cfg.optionPool
          .firstWhere((r) => r.kind == ItemOptionKind.attack)
          .maxAt(0);
      final opt = ItemOption(kind: ItemOptionKind.attack, value: hi);
      final out = trimItemOptions(
        EquipItem(slot: EquipSlot.tool, tier: 0, options: [opt]),
        cfg,
      );
      expect(out.options.single.value, hi);
    });

    test('최대치가 **내려갔으면** 그 최대치로 맞춘다(2026-09-14 치명확률 예산제)', () {
      // 옛 값을 두면 화면에 "67/15" 가 찍히고 실제 효과는 예산에서 잘려
      // 숫자와 효과가 갈린다.
      final hi = cfg.optionPool
          .firstWhere((r) => r.kind == ItemOptionKind.critChance)
          .maxAt(9);
      final out = trimItemOptions(
        EquipItem(
          slot: EquipSlot.tool,
          tier: 9,
          options: [
            ItemOption(kind: ItemOptionKind.critChance, value: hi + 50),
          ],
        ),
        cfg,
      );
      expect(out.options.single.value, hi);
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

/// 치명확률 상한(2026-09-07) — 100%면 손맛이 죽는다.
void _critCapTests() {
  const base = CharacterStats(
    attack: 100,
    attackSpeed: 1,
    rewardMultiplier: 1,
    critChance: 1.0,
    critDamage: 3.0,
    bossDamage: 1,
    maxHp: 100,
    defense: 0,
    hpRegen: 0,
    xpMultiplier: 1,
    bugFind: 1,
    materialFind: 1,
    moveSpeed: 1,
    boostBonus: 1,
  );

  double dpsMult(CharacterStats s) => 1 + s.critChance * (s.critDamage - 1);

  group('치명확률 상한', () {
    test('상한 아래면 아무것도 바뀌지 않는다', () {
      final s = capCritChance(base, 1.0);
      expect(identical(s, base), isTrue);
    });

    test('상한을 넘으면 확률은 상한까지, 넘친 만큼은 치명피해로', () {
      final s = capCritChance(base, 0.85);
      expect(s.critChance, 0.85);
      expect(s.critDamage, greaterThan(base.critDamage));
    });

    test('⚠️ 변환은 전력 중립이다 — 깨지면 상한을 만지는 순간 난이도가 움직인다', () {
      for (final raw in [0.9, 0.95, 1.0]) {
        for (final cd in [1.5, 2.0, 3.0, 5.0]) {
          final src = CharacterStats(
            attack: base.attack,
            attackSpeed: 1,
            rewardMultiplier: 1,
            critChance: raw,
            critDamage: cd,
            bossDamage: 1,
            maxHp: 100,
            defense: 0,
            hpRegen: 0,
            xpMultiplier: 1,
            bugFind: 1,
            materialFind: 1,
            moveSpeed: 1,
            boostBonus: 1,
          );
          final out = capCritChance(src, 0.85);
          expect(
            dpsMult(out),
            closeTo(dpsMult(src), 1e-9),
            reason: 'raw=$raw cd=$cd',
          );
          // 적응형 몬스터 체력 기준도 같이 안 움직여야 한다(§7).
          expect(
            baselineHitPower(out),
            closeTo(baselineHitPower(src), 1e-6),
            reason: 'raw=$raw cd=$cd 기준이 움직였다',
          );
        }
      }
    });

    test('상한 뒤 투자도 값어치가 있다 — 더 넣을수록 치명피해가 커진다', () {
      CharacterStats at(double raw) => CharacterStats(
        attack: 100,
        attackSpeed: 1,
        rewardMultiplier: 1,
        critChance: raw,
        critDamage: 3.0,
        bossDamage: 1,
        maxHp: 100,
        defense: 0,
        hpRegen: 0,
        xpMultiplier: 1,
        bugFind: 1,
        materialFind: 1,
        moveSpeed: 1,
        boostBonus: 1,
      );
      final a = capCritChance(at(0.90), 0.85);
      final b = capCritChance(at(1.00), 0.85);
      expect(b.critDamage, greaterThan(a.critDamage));
    });

    test('실데이터: 출처별 예산이 상한을 정확히 채운다(2026-09-14 예산제)', () {
      // 예전엔 상한 0.85 + 넘침을 치명피해로 돌리는 방식이었다. 이제 상한
      // 100% 를 강화·장비·그 외가 예산으로 나눠 가지므로, 세 예산의 합이
      // 상한이어야 한다 — 합이 작으면 절대 100% 에 못 닿고, 크면 한 출처가
      // 남의 자리를 먹는다.
      final cfg = RunConfig.fromJson(
        jsonDecode(
              File('../app/assets/data/run_config.json').readAsStringSync(),
            )
            as Map<String, dynamic>,
      );
      final sum =
          cfg.critBudgetUpgrade + cfg.critBudgetGear + cfg.critBudgetOther;
      expect(sum, closeTo(cfg.critChanceMax, 1e-9));
      expect(cfg.critBudgetUpgrade, lessThan(1.0));
      expect(cfg.critBudgetGear, lessThan(1.0));
      expect(cfg.critBudgetOther, lessThan(1.0));
      // 강화 상한 레벨을 다 찍으면 정확히 강화 예산이 된다.
      final crit = cfg.upgrades[UpgradeKind.crit]!;
      expect(
        crit.valueAt(crit.maxLevel!),
        closeTo(cfg.critBudgetUpgrade, 1e-9),
      );
    });
  });
}

/// 제련 젤리 소비처(2026-09-09). 제련은 유저가 가장 오래 붙잡는 **무한 루프**인데
/// 젤리 통로가 하나도 없었다 — 확장(유한 1,660젤리)만으로는 살 게 금방 떨어진다.
void _forgeSinkTests() {
  // 실데이터로 돈다 — 등급별 최대치가 JSON 에 있으므로 JSON 을 고치면 여기서 보인다.
  final items = ItemConfig.fromJson(
    jsonDecode(File('../app/assets/data/items.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  final top = items.tierCount - 1;

  group('옵션 재굴림', () {
    test('부위와 등급은 그대로다 — 등급을 사면 물건을 사는 것이라 §2.6 위반', () {
      final item = EquipItem(
        slot: EquipSlot.tool,
        tier: top,
        options: const [ItemOption(kind: ItemOptionKind.attack, value: 3.0)],
      );
      for (var seed = 0; seed < 50; seed++) {
        final out = rerollOptions(rng: Random(seed), items: items, item: item);
        expect(out.slot, item.slot);
        expect(out.tier, item.tier);
      }
    });

    test('옵션 개수는 그 등급의 규칙을 따른다', () {
      for (final tier in [0, top]) {
        final out = rerollOptions(
          rng: Random(7),
          items: items,
          item: EquipItem(slot: EquipSlot.ring, tier: tier, options: const []),
        );
        expect(out.options.length, items.tier(tier).options);
      }
    });

    test('옵션 값이 그 등급 최대치를 안 넘는다', () {
      for (var seed = 0; seed < 200; seed++) {
        final out = rerollOptions(
          rng: Random(seed),
          items: items,
          item: EquipItem(slot: EquipSlot.tool, tier: top, options: const []),
        );
        for (final o in out.options) {
          final r = items.optionPool.firstWhere((x) => x.kind == o.kind);
          expect(o.value, lessThanOrEqualTo(r.maxAt(top).toDouble() + 1e-9));
          expect(o.value, greaterThanOrEqualTo(r.min - 1e-9));
        }
      }
    });

    test('굴릴 때마다 달라진다 — 같은 결과만 나오면 살 이유가 없다', () {
      final item = EquipItem(
        slot: EquipSlot.tool,
        tier: top,
        options: const [],
      );
      final seen = <String>{};
      for (var seed = 0; seed < 30; seed++) {
        final out = rerollOptions(rng: Random(seed), items: items, item: item);
        seen.add(out.options.map((o) => '${o.kind}:${o.value}').join(','));
      }
      expect(seen.length, greaterThan(5));
    });
  });

  group('옵션 한 칸만 재굴림', () {
    EquipItem two() => EquipItem(
      slot: EquipSlot.tool,
      tier: top,
      options: const [
        ItemOption(kind: ItemOptionKind.attack, value: 5.0),
        ItemOption(kind: ItemOptionKind.maxHp, value: 3.0),
      ],
    );

    test('지목한 칸만 바뀌고 나머지는 그대로다', () {
      // 통째로 굴리면 마음에 드는 한 줄까지 날아가 조합을 못 맞춘다.
      final item = two();
      for (var seed = 0; seed < 40; seed++) {
        final out = rerollOptionAt(
          rng: Random(seed),
          items: items,
          item: item,
          index: 0,
        );
        expect(out.options[1].kind, item.options[1].kind);
        expect(out.options[1].value, item.options[1].value);
        expect(out.options.length, 2);
      }
    });

    test('⚠️ 나머지 칸과 종류가 겹치지 않는다', () {
      // 공격력 두 줄은 합산이라 한 줄과 다를 바가 없고, 그 장비의 축이
      // 하나로 줄어든다.
      final item = two();
      for (var seed = 0; seed < 200; seed++) {
        final out = rerollOptionAt(
          rng: Random(seed),
          items: items,
          item: item,
          index: 0,
        );
        expect(out.options[0].kind, isNot(out.options[1].kind));
      }
    });

    test('등급·부위는 그대로다 — 등급을 사면 §2.6 위반', () {
      final item = two();
      final out = rerollOptionAt(
        rng: Random(3),
        items: items,
        item: item,
        index: 1,
      );
      expect(out.tier, item.tier);
      expect(out.slot, item.slot);
    });

    test('굴릴 때마다 달라진다', () {
      final item = two();
      final seen = <String>{};
      for (var seed = 0; seed < 40; seed++) {
        final out = rerollOptionAt(
          rng: Random(seed),
          items: items,
          item: item,
          index: 0,
        );
        seen.add('${out.options[0].kind}:${out.options[0].value}');
      }
      expect(seen.length, greaterThan(5));
    });

    test('범위 밖 인덱스는 원본을 그대로 돌려준다 — 젤리만 쓰고 끝나면 안 된다', () {
      final item = two();
      expect(
        rerollOptionAt(rng: Random(1), items: items, item: item, index: 5),
        item,
      );
      expect(
        rerollOptionAt(rng: Random(1), items: items, item: item, index: -1),
        item,
      );
    });
  });

  group('옛 장비 옵션 채우기', () {
    test('모자란 칸을 그 등급 개수만큼 채운다', () {
      // 2026-09-09 에 기본 스탯을 없애고 모두 2 옵션으로 바꿨다. 옛 1 옵션
      // 장비를 그대로 두면 **가만히 있던 유저가 손해**를 본다.
      final one = EquipItem(
        slot: EquipSlot.tool,
        tier: top,
        options: const [ItemOption(kind: ItemOptionKind.attack, value: 5.0)],
      );
      final out = fillMissingOptions(rng: Random(1), items: items, item: one);
      expect(out.options.length, items.tier(top).options);
    });

    test('⚠️ 이미 있던 옵션은 안 건드린다 — 값이 바뀌면 그것도 손해다', () {
      const kept = ItemOption(kind: ItemOptionKind.attack, value: 5.0);
      final one = EquipItem(
        slot: EquipSlot.tool,
        tier: top,
        options: const [kept],
      );
      for (var seed = 0; seed < 30; seed++) {
        final out = fillMissingOptions(
          rng: Random(seed),
          items: items,
          item: one,
        );
        expect(out.options.first.kind, kept.kind);
        expect(out.options.first.value, kept.value);
      }
    });

    test('채운 것이 기존과 겹치지 않는다', () {
      final one = EquipItem(
        slot: EquipSlot.tool,
        tier: top,
        options: const [ItemOption(kind: ItemOptionKind.attack, value: 5.0)],
      );
      for (var seed = 0; seed < 60; seed++) {
        final out = fillMissingOptions(
          rng: Random(seed),
          items: items,
          item: one,
        );
        expect(out.options[0].kind, isNot(out.options[1].kind));
      }
    });

    test('이미 다 찼으면 그대로 돌려준다', () {
      final full = EquipItem(
        slot: EquipSlot.tool,
        tier: top,
        options: const [
          ItemOption(kind: ItemOptionKind.attack, value: 5.0),
          ItemOption(kind: ItemOptionKind.maxHp, value: 3.0),
        ],
      );
      expect(
        identical(
          fillMissingOptions(rng: Random(1), items: items, item: full),
          full,
        ),
        isTrue,
      );
    });

    test('실데이터: 모든 등급이 옵션 2 개다', () {
      // 부위 기본 스탯이 사라졌으므로 1 옵션 등급이 남아 있으면 그 등급만
      // 유독 약해진다.
      for (var t = 0; t < items.tierCount; t++) {
        expect(items.tier(t).options, 2, reason: '등급 $t');
      }
    });
  });

  group('모루 칸 확장', () {
    const f = ForgeConfig(stackExpandJelly: 100, stackExpandStep: 2);

    test('살수록 비싸진다 — 정액이면 다 사고 나서 젤리 쓸 데가 없어진다(§2.6)', () {
      var prev = 0;
      for (var i = 0; i < 5; i++) {
        final c = f.stackExpandCost(i);
        expect(c, greaterThan(prev));
        prev = c;
      }
    });

    test('첫 값은 설정 그대로', () {
      expect(f.stackExpandCost(0), 100);
    });

    test('젤리 값은 5 단위로 떨어진다(§2.6 가격 단위)', () {
      for (var i = 0; i < 8; i++) {
        expect(f.stackExpandCost(i) % 5, 0);
      }
    });
  });
}
