import 'dart:convert';
import 'dart:io';

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

  test('치명 피해·재생·경험치는 곱(종 패시브·요정과 같은 해석, 설계 §10)', () {
    final r = applyResearchStats(
      _s,
      _fx({
        ResearchEffect.huntCritDmg: 0.4,
        ResearchEffect.huntRegen: 0.4,
        ResearchEffect.huntExp: 0.3,
      }),
    );
    expect(r.critDamage, closeTo(1.5 * 1.4, 1e-9));
    expect(r.hpRegen, closeTo(0.01 * 1.4, 1e-12));
    expect(r.xpMultiplier, closeTo(1.2 * 1.3, 1e-9));
    expect(r.attack, 100);
    expect(r.critChance, 0.1);
    expect(r.maxHp, 1000);
  });

  test('재생은 체력 배율과 함께 곱한다(회복 = 최대 체력 비율)', () {
    final r = applyResearchStats(
      _s,
      _fx({ResearchEffect.huntHpDef: 0.2, ResearchEffect.huntRegen: 0.5}),
    );
    expect(r.hpRegen, closeTo(0.01 * 1.2 * 1.5, 1e-12));
  });

  test('회피는 %p 가산 — 연구 몫은 예산(evadeBudgetResearch)에서 잘린다', () {
    final r = applyResearchStats(_s, _fx({ResearchEffect.huntEvade: 0.2}));
    expect(r.evade, closeTo(0.05 + 0.2, 1e-9));
    // 예산보다 작게 주면 그 예산까지만.
    final cut = applyResearchStats(
      _s,
      _fx({ResearchEffect.huntEvade: 0.2}),
      evadeBudget: 0.1,
    );
    expect(cut.evade, closeTo(0.05 + 0.1, 1e-9));
    // 효과 합 자체도 연구 몫 상한(0.2)에서 잘린다(연구 2개가 겹쳐도).
    final over = applyResearchStats(_s, _fx({ResearchEffect.huntEvade: 0.5}));
    expect(over.evade, closeTo(0.05 + kResearchEvadeMax, 1e-9));
  });

  test('실데이터: 회피 연구 몫 0.2 · 전체 상한 0.6 — 다 모아도 상한을 넘지 않는다', () {
    final cfg = RunConfig.fromJson(
      jsonDecode(File('../app/assets/data/run_config.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    expect(cfg.evadeBudgetResearch, closeTo(0.2, 1e-9));
    expect(cfg.evadeMax, closeTo(0.6, 1e-9));
    const full = CharacterStats(
      attack: 1,
      attackSpeed: 1,
      rewardMultiplier: 1,
      critChance: 0,
      critDamage: 1,
      bossDamage: 1,
      maxHp: 1,
      defense: 0,
      hpRegen: 0,
      xpMultiplier: 1,
      bugFind: 1,
      materialFind: 1,
      // 강화 + 장비 + 그 외 예산을 다 채운 상태.
      evade: 0.4,
      boostBonus: 0,
    );
    final r = applyResearchStats(
      full,
      _fx({ResearchEffect.huntEvade: 0.9}),
      evadeBudget: cfg.evadeBudgetResearch,
    );
    expect(r.evade, closeTo(0.6, 1e-9));
    expect(evadeChance(cfg, r), closeTo(0.6, 1e-9));
    // 더 얹어도(예산 밖 출처가 넘쳐도) 최종 상한에서 멈춘다.
    expect(
      evadeChance(
        cfg,
        applyResearchStats(r, _fx({ResearchEffect.huntEvade: 0.2})),
      ),
      closeTo(0.6, 1e-9),
    );
  });

  test('스킬 쿨타임 — 연구 0 이면 장비 몫만, 연구 몫 ≤ 0.2 · 합 ≤ 0.5', () {
    final c = RunConfig.fromJson(
      jsonDecode(File('../app/assets/data/run_config.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    expect(c.skillCooldownBudgetResearch, closeTo(0.2, 1e-9));
    expect(skillCooldownMult(c, gearCut: 0, research: ResearchEffects.none), 1);
    expect(
      skillCooldownMult(c, gearCut: 0.12, research: ResearchEffects.none),
      closeTo(0.88, 1e-12),
    );
    expect(
      skillCooldownMult(
        c,
        gearCut: 0,
        research: _fx({ResearchEffect.skillCooldown: 0.15}),
      ),
      closeTo(0.85, 1e-12),
    );
    // 장비 최대 + 연구 넘침 → 장비 0.3 + 연구 0.2 = 0.5.
    expect(
      skillCooldownMult(
        c,
        gearCut: 0.9,
        research: _fx({ResearchEffect.skillCooldown: 0.9}),
      ),
      closeTo(0.5, 1e-12),
    );
    expect(
      researchSkillCooldownCut(
        _fx({ResearchEffect.skillCooldown: 0.9}),
        budget: 0.1,
      ),
      closeTo(0.1, 1e-12),
    );
  });

  test('결투 효과(치명·근성)는 사냥 능력치에 안 붙는다', () {
    final r = applyResearchStats(
      _s,
      _fx({ResearchEffect.duelCrit: 0.05, ResearchEffect.duelGrit: 0.05}),
    );
    _same(r, _s);
  });
}
