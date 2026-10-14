import 'dart:convert';
import 'dart:io';

import 'package:core_run/core_run.dart';
import 'package:test/test.dart';

/// 2026-10-14 사장님 확정 — "더하기라 후반에 묽어지는 보너스"를 곱으로, 회복은 체력 배율을 따라간다.
///
/// 골드·경험치·조우·재료·치명 피해는 강화로 기본값 1~2 에서 수 배~수십 배까지 자란다. 가산이면 같은
/// "+35%" 가 후반에 +0.5% 로 묽어졌다(보스 피해를 곱으로 바꾼 2026-09-22 와 같은 문제).
void main() {
  // 후반 계정 근사 — 배율 칸이 크게 자라 있다.
  const late = CharacterStats(
    attack: 1000,
    attackSpeed: 2,
    rewardMultiplier: 70,
    critChance: 0.3,
    critDamage: 15,
    bossDamage: 8,
    maxHp: 10000,
    defense: 500,
    hpRegen: 50,
    xpMultiplier: 9,
    bugFind: 12,
    materialFind: 14,
    evade: 0.1,
    boostBonus: 1,
  );

  double taken(double def) => 100 / (100 + def);

  group('종 패시브(applySpeciesPassives)', () {
    test('골드·경험치·조우·재료·치명 피해는 곱 — 후반에도 +35% 는 +35%', () {
      final s = applySpeciesPassives(late, {
        UpgradeKind.reward: 0.35,
        UpgradeKind.xp: 0.35,
        UpgradeKind.bugFind: 0.35,
        UpgradeKind.materialFind: 0.35,
        UpgradeKind.critDamage: 0.35,
      });
      expect(s.rewardMultiplier / late.rewardMultiplier, closeTo(1.35, 1e-12));
      expect(s.xpMultiplier / late.xpMultiplier, closeTo(1.35, 1e-12));
      expect(s.bugFind / late.bugFind, closeTo(1.35, 1e-12));
      expect(s.materialFind / late.materialFind, closeTo(1.35, 1e-12));
      expect(s.critDamage / late.critDamage, closeTo(1.35, 1e-12));
    });

    test('같은 종 여러 마리는 더한 뒤 한 번 곱한다(합산 규칙 그대로)', () {
      final s = applySpeciesPassives(late, {UpgradeKind.reward: 0.7});
      expect(s.rewardMultiplier, closeTo(70 * 1.7, 1e-9));
    });

    test('방어는 맷집(100 + 방어)을 곱한다 — 어느 방어력에서도 받는 피해 ÷ (1 + v)', () {
      for (final d in [0.0, 4.0, 500.0, 5000.0]) {
        final nd = defenseScaled(d, 0.35);
        expect(
          taken(nd) / taken(d),
          closeTo(1 / 1.35, 1e-12),
          reason: 'def=$d',
        );
      }
      // 방어 0 에서는 예전 가산(+v×100)과 같다 — 초반 체감은 그대로.
      expect(defenseScaled(0, 0.08), closeTo(8, 1e-9));
      expect(defenseScaled(50, 0), 50);
      final s = applySpeciesPassives(late, {UpgradeKind.defense: 0.35});
      expect(taken(s.defense) / taken(late.defense), closeTo(1 / 1.35, 1e-12));
    });

    test('확률(치명확률·회피)은 그대로 %p 가산 + 예산', () {
      final s = applySpeciesPassives(late, {
        UpgradeKind.crit: 0.06,
        UpgradeKind.evade: 0.04,
      }, critBudget: 0.05);
      expect(s.critChance, closeTo(0.35, 1e-12));
      expect(s.evade, closeTo(0.14, 1e-12));
    });

    test('체력 패시브는 회복도 같이 키운다 · 회복 패시브는 그 위에 곱', () {
      final hp = applySpeciesPassives(late, {UpgradeKind.maxHp: 0.35});
      expect(hp.maxHp, closeTo(13500, 1e-9));
      expect(hp.hpRegen / hp.maxHp, closeTo(late.hpRegen / late.maxHp, 1e-12));
      final both = applySpeciesPassives(late, {
        UpgradeKind.maxHp: 0.35,
        UpgradeKind.regen: 0.2,
      });
      expect(
        both.hpRegen / both.maxHp,
        closeTo(late.hpRegen / late.maxHp * 1.2, 1e-12),
      );
    });
  });

  test('도감 — 골드는 곱 · 정복 체력은 회복도 같이', () {
    const dex = DexConfig(
      attackPerConquer: 0.015,
      hpPerConquer: 0.02,
      rewardPerDiscover: 0.01,
    );
    final s = dex.apply(late, 20, 20);
    expect(s.rewardMultiplier / late.rewardMultiplier, closeTo(1.2, 1e-12));
    expect(s.maxHp / late.maxHp, closeTo(1.4, 1e-12));
    expect(s.hpRegen / s.maxHp, closeTo(late.hpRegen / late.maxHp, 1e-12));
  });

  test('동행 요정·길드 체력도 회복 비율을 지킨다', () {
    final f = applyFairyStats(late, const {'hp': 0.3});
    expect(f.hpRegen / f.maxHp, closeTo(late.hpRegen / late.maxHp, 1e-12));
    final g = applyGuildStats(late, const {'hp': 0.1});
    expect(g.maxHp, closeTo(11000, 1e-9));
    expect(g.hpRegen / g.maxHp, closeTo(late.hpRegen / late.maxHp, 1e-12));
  });

  test('스킬 패시브(채집가의 손·곤충학자의 눈)도 곱으로 얹힌다', () {
    final cfg = SkillConfig.fromJson(
      jsonDecode(File('../app/assets/data/skills.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    String idOf(String effect) =>
        cfg.skills.firstWhere((d) => !d.isActive && d.effect == effect).id;
    final mat = idOf('materialFind');
    final bug = idOf('bugFind');
    final s = applySkillPassives(
      late,
      cfg,
      levels: {mat: 1, bug: 1},
      equipped: [mat, bug],
      petCount: 0,
    );
    final vMat = cfg.byId(mat)!.valueAt(1);
    final vBug = cfg.byId(bug)!.valueAt(1);
    expect(vMat, greaterThan(0));
    expect(s.materialFind, closeTo(late.materialFind * (1 + vMat), 1e-9));
    expect(s.bugFind, closeTo(late.bugFind * (1 + vBug), 1e-9));
  });
}
