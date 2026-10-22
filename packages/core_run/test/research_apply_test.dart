import 'package:core_run/core_run.dart';
import 'package:test/test.dart';

const _s = CharacterStats(
  attack: 100,
  attackSpeed: 1.5,
  rewardMultiplier: 2,
  critChance: 0.1,
  critDamage: 1.5,
  bossDamage: 3,
  maxHp: 1000,
  defense: 50,
  hpRegen: 0.01,
  xpMultiplier: 1.2,
  bugFind: 1.1,
  materialFind: 1.3,
  evade: 0.05,
  boostBonus: 0,
);

ResearchEffects _fx(Map<ResearchEffect, double> v) {
  final c = ResearchConfig(
    defs: [
      for (final e in v.entries)
        ResearchDef(
          id: e.key.key,
          branch: ResearchBranch.hunt,
          effect: e.key,
          maxLevel: 1,
          perLevel: e.value,
        ),
    ],
  );
  return researchEffects(c, {for (final e in v.keys) e.key: 1});
}

void _same(CharacterStats a, CharacterStats b) {
  expect(a.attack, closeTo(b.attack, 1e-9));
  expect(a.attackSpeed, closeTo(b.attackSpeed, 1e-9));
  expect(a.rewardMultiplier, closeTo(b.rewardMultiplier, 1e-9));
  expect(a.critChance, closeTo(b.critChance, 1e-9));
  expect(a.critDamage, closeTo(b.critDamage, 1e-9));
  expect(a.bossDamage, closeTo(b.bossDamage, 1e-9));
  expect(a.maxHp, closeTo(b.maxHp, 1e-9));
  expect(a.defense, closeTo(b.defense, 1e-9));
  expect(a.hpRegen, closeTo(b.hpRegen, 1e-12));
  expect(a.xpMultiplier, closeTo(b.xpMultiplier, 1e-9));
  expect(a.bugFind, closeTo(b.bugFind, 1e-9));
  expect(a.materialFind, closeTo(b.materialFind, 1e-9));
  expect(a.evade, closeTo(b.evade, 1e-9));
}

void main() {
  test('연구가 없으면 능력치 그대로', () {
    _same(applyResearchStats(_s, ResearchEffects.none), _s);
    _same(applyResearchIdleStats(_s, ResearchEffects.none), _s);
  });

  test('공격 0.3 → 공격 ×1.3, 다른 능력치는 그대로', () {
    final r = applyResearchStats(_s, _fx({ResearchEffect.huntAtk: 0.3}));
    expect(r.attack, closeTo(130, 1e-9));
    expect(r.maxHp, 1000);
    expect(r.rewardMultiplier, 2);
  });

  test('체력·방어 — 체력 곱 · 맷집 (100+방어)×(1+v) · 회복도 체력 배율을 탄다', () {
    final r = applyResearchStats(_s, _fx({ResearchEffect.huntHpDef: 0.2}));
    expect(r.maxHp, closeTo(1200, 1e-9));
    // 받는 피해 = 위협 × 100 / (100 + 방어) 가 정확히 ÷1.2.
    expect(100 + r.defense, closeTo((100 + 50) * 1.2, 1e-9));
    expect(r.defense, closeTo(defenseScaled(50, 0.2), 1e-9));
    expect(r.hpRegen, closeTo(0.01 * 1.2, 1e-12));
  });

  test('골드·찾기·보스 피해는 곱', () {
    final r = applyResearchStats(
      _s,
      _fx({
        ResearchEffect.gold: 0.1,
        ResearchEffect.find: 0.2,
        ResearchEffect.bossDmg: 0.4,
      }),
    );
    expect(r.rewardMultiplier, closeTo(2.2, 1e-9));
    expect(r.bugFind, closeTo(1.1 * 1.2, 1e-9));
    expect(r.materialFind, closeTo(1.3 * 1.2, 1e-9));
    expect(r.bossDamage, closeTo(3 * 1.4, 1e-9));
    expect(r.attack, 100);
  });

  test('방치 정산용은 골드·찾기만 — 공격·체력·보스 피해는 안 붙는다(펫·장비처럼 방치 밖)', () {
    final r = applyResearchIdleStats(
      _s,
      _fx({
        ResearchEffect.huntAtk: 0.3,
        ResearchEffect.huntHpDef: 0.3,
        ResearchEffect.bossDmg: 0.3,
        ResearchEffect.gold: 0.1,
        ResearchEffect.find: 0.2,
      }),
    );
    expect(r.attack, 100);
    expect(r.maxHp, 1000);
    expect(r.bossDamage, 3);
    expect(r.rewardMultiplier, closeTo(2.2, 1e-9));
    expect(r.bugFind, closeTo(1.32, 1e-9));
  });

  test('방치 효율 = 기본 효율 × (1 + 방치 효율 연구)', () {
    expect(
      researchOfflineEfficiency(0.3, _fx({ResearchEffect.offline: 0.25})),
      closeTo(0.375, 1e-12),
    );
    expect(researchOfflineEfficiency(0.3, ResearchEffects.none), 0.3);
  });

  test('나중에 붙는 사냥 효과(치명 피해 등)는 여기서 입히지 않는다', () {
    final r = applyResearchStats(_s, _fx({ResearchEffect.huntCritDmg: 0.4}));
    _same(r, _s);
  });
}
