// 사냥 강화 15종 — **+10 레벨을 샀을 때 무엇이 얼마나 좋아지나**(2026-10-10 실기 지적: 근성·맷집·회복력을
// 올려도 차이가 안 난다).
//
// 실행:  cd packages\core_run ; dart run tool/upgrade_value.dart
//
// 모든 강화를 같은 레벨 L 에 두고(상한에서 자름) 한 종만 +10 했을 때의 변화를 잰다.
// 받는 피해는 앱과 같은 식: 위협 = max(표, 맷집 × threatAdaptTargetPct), 받는 피해 = 위협 × 100/(100+방어),
// 맷집 = 최대 체력 × (1+방어/100)(강화·펫 = 기준). 표보다 강하면(적응형 쪽) 한 대 = 최대 체력의 일정 비율.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';

void main() {
  final run = RunConfig.fromJson(
    jsonDecode(File('../app/assets/data/run_config.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  final bite = run.threatAdaptTargetPct * run.enemyAtkInterval;

  CharacterStats at(Map<UpgradeKind, int> lv) => deriveStats(
    run,
    upgradeLevels: lv,
    characterLevel: 60,
    bugsCollected: 50,
  );

  double crit(CharacterStats s) =>
      1 + s.critChance.clamp(0.0, 1.0) * math.max(0.0, s.critDamage - 1);
  double dps(CharacterStats s) => s.attack * s.attackSpeed * crit(s);

  // 적응형 쪽에서의 한 대(최대 체력 대비) — 강화 체력·방어가 기준이라 상쇄된다.
  double biteAdaptive(CharacterStats s) {
    final tough = toughnessOf(s);
    final incoming = tough * run.threatAdaptTargetPct * 100 / (100 + s.defense);
    return incoming * run.enemyAtkInterval / s.maxHp;
  }

  // 표 쪽(사냥터 도착 직후 등 내가 표보다 약할 때) — 고정 위협이면 체력·방어가 그대로 듣는다.
  double biteFixed(CharacterStats s, double fixedThreat) =>
      fixedThreat * 100 / (100 + s.defense) * run.enemyAtkInterval / s.maxHp;

  String pct(double x) =>
      '${x >= 0 ? '+' : ''}${(x * 100).toStringAsFixed(1)}%'.padLeft(8);

  for (final level in [30, 80, 150]) {
    final base = {
      for (final e in run.upgrades.entries)
        e.key: math.min(level, e.value.maxLevel ?? level),
    };
    final s0 = at(base);
    // 표 위협 = 지금 맷집에서 한 대 12% 가 되는 값(도착 시점 가정) — 여기서 체력·방어를 올리면 얼마나 줄어드나.
    final fixedThreat = toughnessOf(s0) * run.threatAdaptTargetPct;
    stdout.writeln(
      '\n── 모든 강화 레벨 $level · 한 종만 +10 레벨 ── (한 대 = 적응형 ${(biteAdaptive(s0) * 100).toStringAsFixed(1)}% / 기준 ${(bite * 100).toStringAsFixed(0)}%)',
    );
    stdout.writeln(
      '  강화            주는 효과(+10)                              비용(공격 +10 대비)',
    );
    final atkCost = _cost(run, UpgradeKind.attack, base);
    for (final k in run.upgrades.keys) {
      final spec = run.upgrades[k]!;
      final cur = base[k]!;
      if (spec.maxLevel != null && cur >= spec.maxLevel!) {
        stdout.writeln('  ${k.key.padRight(14)}  (만렙)');
        continue;
      }
      final up = {...base, k: math.min(cur + 10, spec.maxLevel ?? cur + 10)};
      final s1 = at(up);
      final effect = switch (k) {
        UpgradeKind.attack ||
        UpgradeKind.attackSpeed ||
        UpgradeKind.crit ||
        UpgradeKind.critDamage => '사냥 피해 ${pct(dps(s1) / dps(s0) - 1)}',
        UpgradeKind.bossDamage =>
          '보스 피해 ${pct(s1.bossDamage / s0.bossDamage - 1)}',
        UpgradeKind.maxHp || UpgradeKind.defense =>
          '한 대(적응형) ${pct(biteAdaptive(s1) / biteAdaptive(s0) - 1)} · (표 쪽) ${pct(biteFixed(s1, fixedThreat) / biteFixed(s0, fixedThreat) - 1)}',
        UpgradeKind.regen =>
          '초당 회복 ${(s0.hpRegen / s0.maxHp * 100).toStringAsFixed(2)}% → ${(s1.hpRegen / s1.maxHp * 100).toStringAsFixed(2)}% (받는 피해 초당 ${(run.threatAdaptTargetPct * 100).toStringAsFixed(1)}%)',
        UpgradeKind.reward =>
          '골드 ${pct(s1.rewardMultiplier / s0.rewardMultiplier - 1)}',
        UpgradeKind.xp => '경험치 ${pct(s1.xpMultiplier / s0.xpMultiplier - 1)}',
        UpgradeKind.bugFind => '곤충 ${pct(s1.bugFind / s0.bugFind - 1)}',
        UpgradeKind.materialFind =>
          '재료 ${pct(s1.materialFind / s0.materialFind - 1)}',
        UpgradeKind.evade =>
          '회피 ${(s0.evade * 100).toStringAsFixed(1)}% → ${(s1.evade * 100).toStringAsFixed(1)}% (맞는 횟수 ${pct((1 - s1.evade) / (1 - s0.evade) - 1)})',
        UpgradeKind.boost => '탭 부스트 ${pct(s1.boostBonus / s0.boostBonus - 1)}',
        UpgradeKind.bugBuff =>
          '곤충 수 보너스(보상) ${pct(s1.rewardMultiplier / s0.rewardMultiplier - 1)}',
        _ => '',
      };
      final c = _cost(run, k, base) / atkCost;
      stdout.writeln(
        '  ${k.key.padRight(14)}  ${effect.padRight(46)}  ×${c.toStringAsFixed(c < 10 ? 1 : 0)}',
      );
    }
  }
}

/// [k] 를 지금 레벨에서 +10 하는 골드.
double _cost(RunConfig run, UpgradeKind k, Map<UpgradeKind, int> lv) {
  final spec = run.upgrades[k]!;
  var sum = 0.0;
  for (var i = 0; i < 10; i++) {
    final l = lv[k]! + i;
    if (spec.maxLevel != null && l >= spec.maxLevel!) break;
    sum += upgradeCost(spec, l).toDouble();
  }
  return sum;
}
