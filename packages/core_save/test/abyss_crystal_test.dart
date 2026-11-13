import 'dart:convert';
import 'dart:io';

import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:test/test.dart';

/// 심연 주간 변이 · 심연 결정 · 강화 상한 돌파 · 심연 각인(2026-11-10).
void main() {
  final run = RunConfig.fromJson(
    jsonDecode(File('../app/assets/data/run_config.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  final cfg = run.abyss;
  final base = SaveGame.initial(createdAt: DateTime.utc(2026, 11, 1)).copyWith(
    abyssUnlocked: true,
    inAbyss: true,
    abyssWeek: 'w',
    abyssFloor: 10,
  );

  group('주간 변이', () {
    test('변이 배율 키는 모두 아는 키다(오타면 조용히 안 걸린다)', () {
      expect(cfg.mutations, isNotEmpty);
      for (final m in cfg.mutations) {
        for (final k in m.mult.keys) {
          expect(AbyssMutation.keys, contains(k), reason: '${m.id}.$k');
        }
        expect(m.name['ko'], isNotEmpty, reason: m.id);
      }
    });

    test('같은 주는 늘 같고, 두 주 연속 같은 변이가 나오지 않는다', () {
      const battle = BattleConfig();
      var t = DateTime.utc(2026, 11, 2, 3);
      AbyssMutation? prev;
      for (var w = 0; w < 30; w++) {
        final m = abyssMutationAt(run, battle, t);
        expect(abyssMutationAt(run, battle, t)!.id, m!.id);
        if (prev != null) expect(m.id, isNot(prev.id));
        prev = m;
        t = t.add(const Duration(days: 7));
      }
    });

    test('방어는 맷집(100 + 방어)에 곱한다', () {
      const m = AbyssMutation(id: 't', mult: {'defense': 2});
      const s = CharacterStats(
        attack: 1,
        attackSpeed: 1,
        rewardMultiplier: 1,
        critChance: 0,
        critDamage: 1,
        bossDamage: 1,
        maxHp: 100,
        defense: 50,
        hpRegen: 0,
        xpMultiplier: 1,
        bugFind: 1,
        materialFind: 1,
        evade: 0,
        boostBonus: 0,
      );
      expect(applyAbyssMutation(s, m).defense, 200);
    });
  });

  group('결정', () {
    test('10층을 깨면 받고 · 그 주 최고 층 아래를 다시 깨면 없다', () {
      final r = clearAbyssFloor(base, run);
      expect(r.crystals, cfg.crystalsAt(10));
      expect(r.save.abyssWeekTop, 10);
      final again = clearAbyssFloor(r.save.copyWith(abyssFloor: 10), run);
      expect(again.crystals, 0);
    });

    test('주가 바뀌면 그 주 최고 층이 0 으로', () {
      final s = base.copyWith(abyssWeekTop: 40);
      expect(applyAbyssWeek(s, 'w2').abyssWeekTop, 0);
    });
  });

  group('상한 돌파', () {
    test('결정으로 한 단계 열면 살 수 있는 상한이 늘고 값 곡선은 그대로다', () {
      final s = base.copyWith(abyssCrystals: 1000);
      final up = buyUpgradeCapStep(s, run, UpgradeKind.attack)!;
      final spec0 = upgradeSpecOf(run, s, UpgradeKind.attack);
      final spec1 = upgradeSpecOf(run, up, UpgradeKind.attack);
      expect(spec1.capLevel, spec0.capLevel! + cfg.capStep);
      expect(spec1.valueAt(200), spec0.valueAt(200));
      expect(spec1.canBuyAt(spec0.capLevel!), isTrue);
      expect(up.abyssCrystals, 1000 - cfg.capStepCost(0)!);
    });

    test('넘어선 레벨도 값이 오른다', () {
      final spec = run.upgrade(UpgradeKind.attack).withCapBonus(10);
      final max = spec.maxLevel!;
      expect(spec.valueAt(max + 5), greaterThan(spec.valueAt(max)));
    });

    test('치명·회피는 열 수 없다 · 결정이 모자라면 못 연다', () {
      final rich = base.copyWith(abyssCrystals: 1000);
      expect(buyUpgradeCapStep(rich, run, UpgradeKind.crit), isNull);
      expect(buyUpgradeCapStep(rich, run, UpgradeKind.evade), isNull);
      expect(buyUpgradeCapStep(base, run, UpgradeKind.attack), isNull);
    });
  });

  group('각인', () {
    test('사면 결정이 줄고 능력치가 오른다', () {
      final s = base.copyWith(abyssCrystals: 100);
      final up = buyAbyssImprint(s, run, 'attack')!;
      expect(up.abyssImprint['attack'], 1);
      expect(up.abyssCrystals, 100 - cfg.imprintCost(0));
      const st = CharacterStats(
        attack: 100,
        attackSpeed: 1,
        rewardMultiplier: 1,
        critChance: 0,
        critDamage: 1,
        bossDamage: 1,
        maxHp: 100,
        defense: 0,
        hpRegen: 0,
        xpMultiplier: 1,
        bugFind: 1,
        materialFind: 1,
        evade: 0,
        boostBonus: 0,
      );
      expect(
        applyAbyssImprint(st, cfg, up.abyssImprint).attack,
        closeTo(100 * (1 + cfg.imprint['attack']!), 1e-9),
      );
    });

    test('세이브 왕복', () {
      final s = base.copyWith(
        abyssCrystals: 7,
        abyssWeekTop: 20,
        upgradeCapUps: {UpgradeKind.maxHp: 2},
        abyssImprint: {'defense': 3},
      );
      final back = SaveGame.fromJson(s.toJson());
      expect(back.abyssCrystals, 7);
      expect(back.abyssWeekTop, 20);
      expect(back.upgradeCapUps[UpgradeKind.maxHp], 2);
      expect(back.abyssImprint['defense'], 3);
    });
  });
}
