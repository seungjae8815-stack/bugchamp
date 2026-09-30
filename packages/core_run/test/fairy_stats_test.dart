import 'package:core_run/core_run.dart';
import 'package:test/test.dart';

/// 요정 능력치가 방치 런 능력치에 얹히는 방식(docs/design_fairy.md §1.1).
void main() {
  const base = CharacterStats(
    attack: 100,
    attackSpeed: 1,
    rewardMultiplier: 1,
    critChance: 0.2,
    critDamage: 2,
    bossDamage: 3,
    maxHp: 1000,
    defense: 50,
    hpRegen: 5,
    xpMultiplier: 1,
    bugFind: 0,
    materialFind: 0,
    moveSpeed: 1,
    boostBonus: 1,
  );

  test('없으면 그대로', () {
    expect(identical(applyFairyStats(base, const {}), base), isTrue);
  });

  test('공격·체력·공속은 비율 · 치명 피해는 가산 · 보스 피해는 곱', () {
    final s = applyFairyStats(base, const {
      'attack': 0.1,
      'hp': 0.2,
      'attackSpeed': 0.05,
      'critDamage': 0.3,
      'bossDamage': 0.1,
    });
    expect(s.attack, closeTo(110, 1e-9));
    expect(s.maxHp, closeTo(1200, 1e-9));
    expect(s.attackSpeed, closeTo(1.05, 1e-9));
    expect(s.critDamage, closeTo(2.3, 1e-9));
    expect(s.bossDamage, closeTo(3.3, 1e-9));
    // 요정이 건드리지 않는 능력치는 그대로.
    expect(s.critChance, base.critChance);
    expect(s.hpRegen, base.hpRegen);
  });

  test('방어 v = 어느 방어력에서도 받는 피해 정확히 −v', () {
    double taken(double def) => 100 / (100 + def);
    for (final d in [0.0, 50.0, 800.0]) {
      final nd = fairyDefenseFor(d, 0.1);
      expect(taken(nd) / taken(d), closeTo(0.9, 1e-12), reason: 'def=$d');
    }
    expect(fairyDefenseFor(50, 0), 50);
    // 80% 에서 자른다(무적 방지).
    expect(taken(fairyDefenseFor(0, 5)) / taken(0), closeTo(0.2, 1e-12));
  });

  test('곤충 몫은 곤충 피해 배율로', () {
    expect(fairyPetMult(const {}), 1);
    expect(fairyPetMult(const {'petShare': 0.15}), closeTo(1.15, 1e-12));
  });

  group('스킬 발동 판정', () {
    test('싸우는 중이 아니면 안 쓴다', () {
      expect(
        fairySkillShouldCast(
          'burstDamage',
          inCombat: false,
          boss: false,
          hpRatio: 1,
        ),
        isFalse,
      );
    });

    test('회복은 체력이 낮을 때만', () {
      bool heal(double r) =>
          fairySkillShouldCast('heal', inCombat: true, boss: false, hpRatio: r);
      expect(heal(0.9), isFalse);
      expect(heal(0.5), isTrue);
    });

    test('보스 일격은 보스전에서만', () {
      expect(
        fairySkillShouldCast(
          'bossBurst',
          inCombat: true,
          boss: false,
          hpRatio: 1,
        ),
        isFalse,
      );
      expect(
        fairySkillShouldCast(
          'bossBurst',
          inCombat: true,
          boss: true,
          hpRatio: 1,
        ),
        isTrue,
      );
    });

    test('버티기는 스스로 쓰지 않는다(죽는 순간 터진다)', () {
      expect(
        fairySkillShouldCast(
          'lastStand',
          inCombat: true,
          boss: true,
          hpRatio: 0.01,
        ),
        isFalse,
      );
    });

    test('나머지는 싸우는 중이면 쿨마다', () {
      for (final e in [
        'burstDamage',
        'damageReduce',
        'attackSpeed',
        'critWindow',
        'petPower',
      ]) {
        expect(
          fairySkillShouldCast(e, inCombat: true, boss: false, hpRatio: 1),
          isTrue,
          reason: e,
        );
      }
    });
  });
}
