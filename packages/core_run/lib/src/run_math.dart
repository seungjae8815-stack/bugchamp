import 'dart:math' as math;

import 'package:core_models/core_models.dart' show kMaxOfflineAccrual;

import 'character_stats.dart';
import 'enums.dart';
import 'run_config.dart';

/// v2 런의 **순수 결정론 수식**. 실시간 루프(앱)는 이 함수들만 호출한다.
///
/// [depth] = 진행 깊이(0-based). 지역1에서는 depth = stageNumber - 1.

/// 서식지 최대 HP.
int habitatMaxHp(RunConfig c, int depth) =>
    (c.hpBase * math.pow(c.hpGrowth, depth)).round();

/// 보스 최대 HP.
int bossMaxHp(RunConfig c, int depth) =>
    (habitatMaxHp(c, depth) * c.bossHpMult).round();

/// 파괴 보상 골드. 보스면 [c.bossRewardMult] 배.
int rewardGold(
  RunConfig c,
  int depth,
  double rewardMultiplier, {
  bool boss = false,
}) {
  final base = c.goldBase * math.pow(c.goldGrowth, depth) * rewardMultiplier;
  return (base * (boss ? c.bossRewardMult : 1.0)).round();
}

/// 파괴 보상 경험치.
int rewardXp(RunConfig c, int depth, {bool boss = false}) {
  final base = c.xpBase * math.pow(c.xpGrowth, depth);
  return (base * (boss ? c.bossRewardMult : 1.0)).round();
}

/// 업그레이드 [level] → 다음 레벨 구매 비용(골드).
int upgradeCost(UpgradeSpec spec, int level) =>
    (spec.baseCost * math.pow(spec.costGrowth, level)).round();

/// [level] 부터 [count] 레벨 연속 구매 총비용(배치 구매 ×10/×100 용).
int bulkUpgradeCost(UpgradeSpec spec, int level, int count) {
  var total = 0;
  for (var i = 0; i < count; i++) {
    total += upgradeCost(spec, level + i);
  }
  return total;
}

/// 업그레이드 [level] → 다음 레벨 구매에 드는 재료 비용(재료 미요구면 0).
int upgradeMaterialCost(UpgradeSpec spec, int level) {
  if (spec.materialKind == null) return 0;
  return (spec.materialBaseCost * math.pow(spec.materialCostGrowth, level))
      .round();
}

/// [level] 부터 [count] 레벨 연속 구매의 재료 총비용.
int bulkUpgradeMaterialCost(UpgradeSpec spec, int level, int count) {
  var total = 0;
  for (var i = 0; i < count; i++) {
    total += upgradeMaterialCost(spec, level + i);
  }
  return total;
}

/// 캐릭터 레벨 [level] → [level]+1 로 가는 데 필요한 경험치.
int xpForNextLevel(int level) => (25 * math.pow(1.45, level - 1)).round();

/// 서식지 곤충의 반격 위협도(초당 피해). 보스면 [c.bossThreatMult] 배.
double habitatThreat(RunConfig c, int depth, {bool boss = false}) {
  final base = c.threatBase * math.pow(c.threatGrowth, depth);
  return base * (boss ? c.bossThreatMult : 1.0);
}

/// 업그레이드 레벨 + 캐릭터 레벨 + 곤충 수로부터 유효 능력치 파생.
/// 설정에 없는 업그레이드는 **중립값**으로 대체(부분 설정 안전).
CharacterStats deriveStats(
  RunConfig c, {
  required Map<UpgradeKind, int> upgradeLevels,
  required int characterLevel,
  required int bugsCollected,
}) {
  double v(UpgradeKind k, double neutral) {
    final spec = c.upgrades[k];
    if (spec == null) return neutral;
    return spec.valueAt(upgradeLevels[k] ?? 0);
  }

  final levelScale = 1 + 0.03 * (characterLevel - 1);
  final bugBuffAmp = v(UpgradeKind.bugBuff, 1.0);
  final bugBuff = 1 + 0.01 * bugBuffAmp * math.min(bugsCollected, 50);

  return CharacterStats(
    attack: v(UpgradeKind.attack, 5.0) * levelScale,
    attackSpeed: v(UpgradeKind.attackSpeed, 1.0),
    rewardMultiplier: v(UpgradeKind.reward, 1.0) * bugBuff,
    critChance: v(UpgradeKind.crit, 0.0).clamp(0.0, 0.9),
    critDamage: v(UpgradeKind.critDamage, 2.0),
    bossDamage: v(UpgradeKind.bossDamage, 1.0),
    maxHp: v(UpgradeKind.maxHp, 100.0) * levelScale,
    defense: v(UpgradeKind.defense, 0.0),
    hpRegen: v(UpgradeKind.regen, 0.0),
    xpMultiplier: v(UpgradeKind.xp, 1.0),
    bugFind: v(UpgradeKind.bugFind, 1.0),
    materialFind: v(UpgradeKind.materialFind, 1.0),
    moveSpeed: v(UpgradeKind.moveSpeed, 1.0),
    boostBonus: v(UpgradeKind.boost, 1.0),
  );
}

/// 전투력(CP): 능력치를 하나의 지표로 집계한 **표시용** 값.
/// 밸런스 계산에 쓰이지 않는 순수 표시 지표라 코드 공식으로 둔다.
/// 공격 성능(DPS 근사) + 생존력(유효 체력)을 가중 합산한다.
int combatPower(CharacterStats s) {
  final dps =
      s.attack *
      s.attackSpeed *
      (1 + s.critChance * (s.critDamage - 1)) *
      s.bossDamage;
  final effectiveHp = s.maxHp * (1 + s.defense / 100);
  return (dps * 6 + effectiveHp * 0.4).round();
}

/// (스테이지, 서식지 인덱스)에 대응하는 서식지 종류 (결정론, 해당 지역 기준).
HabitatKind habitatKindAt(RunConfig c, int stageNumber, int habitatIndex) {
  final kinds = c.regionForStage(stageNumber).habitatKinds;
  final idx = (stageNumber * 7 + habitatIndex * 3) % kinds.length;
  return kinds[idx];
}

/// 오프라인 정산 결과.
class OfflineReport {
  const OfflineReport({
    required this.gold,
    required this.xp,
    required this.accrued,
  });

  final int gold;
  final int xp;
  final Duration accrued;

  bool get isEmpty => gold <= 0 && xp <= 0;

  static const OfflineReport empty = OfflineReport(
    gold: 0,
    xp: 0,
    accrued: Duration.zero,
  );
}

/// 오프라인 동안의 골드/경험치 추정 (현재 스테이지·능력치 기준 파밍 속도 × 시간).
/// 상한 [maxAccrual](기본 8h), 효율 [efficiency](실시간 대비).
OfflineReport computeOfflineReward({
  required RunConfig config,
  required int stageNumber,
  required CharacterStats stats,
  required Duration elapsed,
  Duration maxAccrual = kMaxOfflineAccrual,
  double efficiency = 0.5,
}) {
  if (elapsed <= Duration.zero) return OfflineReport.empty;
  final capped = elapsed > maxAccrual ? maxAccrual : elapsed;
  final secs = capped.inMilliseconds / 1000.0;
  final depth = stageNumber - 1;

  final dps = stats.attack * stats.attackSpeed;
  if (dps <= 0) return OfflineReport.empty;
  final hp = habitatMaxHp(config, depth).toDouble();
  final timePerClear = hp / dps + 0.6; // + 이동시간 근사
  final clearsPerSec = timePerClear > 0 ? 1 / timePerClear : 0.0;

  final goldPer = rewardGold(config, depth, stats.rewardMultiplier);
  final xpPer = (rewardXp(config, depth) * stats.xpMultiplier).round();

  final gold = (clearsPerSec * secs * goldPer * efficiency).round();
  final xp = (clearsPerSec * secs * xpPer * efficiency).round();
  return OfflineReport(gold: gold, xp: xp, accrued: capped);
}
