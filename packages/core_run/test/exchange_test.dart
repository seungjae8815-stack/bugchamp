import 'dart:convert';
import 'dart:io';

import 'package:core_run/core_run.dart';
import 'package:test/test.dart';

/// 교환소(2026-10-05) — 교환 1회 = 이 능력치로 직접 사냥한 1시간치.
/// 예전엔 골드 배율 1.0(맨몸)으로 재서 실제 1시간의 1/30~1/190 이었다.
void main() {
  final run = RunConfig.fromJson(
    jsonDecode(File('../app/assets/data/run_config.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  final base = deriveStats(
    run,
    upgradeLevels: {for (final k in UpgradeKind.values) k: 100},
    characterLevel: 40,
    bugsCollected: 30,
  );
  CharacterStats scaled({double reward = 1, double find = 1}) => CharacterStats(
    attack: base.attack,
    attackSpeed: base.attackSpeed,
    rewardMultiplier: base.rewardMultiplier * reward,
    critChance: base.critChance,
    critDamage: base.critDamage,
    bossDamage: base.bossDamage,
    maxHp: base.maxHp,
    defense: base.defense,
    hpRegen: base.hpRegen,
    xpMultiplier: base.xpMultiplier,
    bugFind: base.bugFind,
    materialFind: base.materialFind * find,
    moveSpeed: base.moveSpeed,
    boostBonus: base.boostBonus,
  );
  final stage = run.zoneStartStage(6);

  test('교환 1회 골드 = 같은 능력치로 1시간 사냥한 골드', () {
    final hunt = simulateIdleProgress(
      config: run,
      startStage: stage,
      stats: base,
      elapsed: const Duration(hours: 1),
      efficiency: 1.0,
      tier: 1,
    ).gold;
    final out = exchangeOutput(
      run,
      stats: base,
      stage: stage,
      trades: 1,
      tier: 1,
    );
    expect(out.gold, closeTo(hunt * run.exchangeGoldHours, hunt * 0.01));
    expect(out.materialsEach, greaterThan(0));
  });

  test('골드 배율·재료 발견이 교환량에 실린다(예전엔 빠졌다)', () {
    final a = exchangeOutput(run, stats: base, stage: stage, trades: 1);
    final b = exchangeOutput(
      run,
      stats: scaled(reward: 3, find: 2),
      stage: stage,
      trades: 1,
    );
    expect(b.gold / a.gold, closeTo(3, 0.05));
    expect(b.materialsEach, greaterThan(a.materialsEach));
  });

  test('횟수에 비례하고 0회는 0', () {
    final one = exchangeOutput(run, stats: base, stage: stage, trades: 1);
    final five = exchangeOutput(run, stats: base, stage: stage, trades: 5);
    expect(five.gold, closeTo(one.gold * 5, 5));
    expect(exchangeOutput(run, stats: base, stage: stage, trades: 0).gold, 0);
  });

  test('난이도가 오르면 교환량도 오른다(쉬움 골드로 떨어지지 않는다)', () {
    final easy = exchangeOutput(run, stats: base, stage: stage, trades: 1);
    final hard = exchangeOutput(
      run,
      stats: base,
      stage: stage,
      trades: 1,
      tier: 2,
    );
    expect(hard.gold, greaterThan(easy.gold));
  });

  // 깜짝선물·일일보상(2026-10-08) — 사냥 N분치. 교환소와 같은 식이라 교환 시간만큼 = 교환 1회.
  test('사냥 (교환 시간)분치 = 교환 1회(같은 식)', () {
    expect(run.exchangeGoldHours, run.exchangeMaterialHours);
    final ex = exchangeOutput(run, stats: base, stage: stage, trades: 1);
    final h = huntMinutesReward(
      run,
      stats: base,
      stage: stage,
      minutes: run.exchangeGoldHours * 60,
    );
    expect(h.gold, closeTo(ex.gold, ex.gold * 0.001 + 1));
    expect(
      h.materialsEach,
      closeTo(ex.materialsEach, ex.materialsEach * 0.001 + 1),
    );
  });

  test('사냥 분치는 분에 비례하고 골드 배율을 따른다', () {
    final m10 = huntMinutesReward(run, stats: base, stage: stage, minutes: 10);
    final m20 = huntMinutesReward(run, stats: base, stage: stage, minutes: 20);
    expect(m20.gold / m10.gold, closeTo(2, 0.05));
    final rich = huntMinutesReward(
      run,
      stats: scaled(reward: 3),
      stage: stage,
      minutes: 10,
    );
    expect(rich.gold / m10.gold, closeTo(3, 0.05));
    expect(
      huntMinutesReward(run, stats: base, stage: stage, minutes: 0).gold,
      0,
    );
  });
}
