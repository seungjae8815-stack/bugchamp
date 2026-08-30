import 'dart:math' as math;

import 'package:core_models/core_models.dart'
    show kMaxOfflineAccrual, kMaxMonsterHp;
import 'package:meta/meta.dart';

import 'character_stats.dart';
import 'enums.dart';
import 'run_config.dart';

/// v2 런의 **순수 결정론 수식**. 실시간 루프(앱)는 이 함수들만 호출한다.
///
/// [depth] = 진행 깊이(0-based). 지역1에서는 depth = stageNumber - 1.

/// 적응형 체력·타격 수 계산의 기준이 되는 **1타 데미지**(영구 전력만).
///
/// 왜 `attack` 만으로는 안 되는가: [RunConfig.hpAdaptTargetHits] 는 "몇 대에
/// 죽나"인데, 치명타는 그 타격 수를 그대로 나눠버린다. 치명타 30% × 배수 4 면
/// 실제 타격 수가 기준의 **절반**이라, 6대로 맞춰도 화면에선 2~3대다(실측).
/// 그래서 치명타 기대값을 기준에 넣는다 — 그래야 설정값이 화면과 일치한다.
///
/// ⚠️ 들어가는 것: **공격 계열 영구 전력**(공격력·치명타·보스데미지, 펫 포함).
///    빠지는 것:
///      - 공격속도 — 타격 *수*가 아니라 시간이다. 넣으면 공속 업그레이드가
///        체력을 밀어올려 아무 효과가 없어진다.
///      - 버프·탭 부스트·장비 — §6. 기준에 넣으면 켜거나 입은 보람이 사라진다.
double baselineHitPower(CharacterStats s, {bool boss = false}) {
  final crit =
      1 + s.critChance.clamp(0.0, 1.0) * math.max(0.0, s.critDamage - 1);
  final bossMul = boss ? math.max(1.0, s.bossDamage) : 1.0;
  return s.attack * crit * bossMul;
}

/// 서식지 최대 HP. 월드 경계마다 [RunConfig.worldHpMult] 점프(벽).
///
/// [playerAttack] 을 주면 **적응형 보정**이 걸린다(§7 밸런스, 2026-08).
/// 넘길 값은 [baselineHitPower] — 생 `attack` 이 아니다.
///
/// 왜 필요한가: 몬스터 체력은 스테이지당 x1.015 로 자라는데 공격 업그레이드는
/// 레벨당 x1.15 로 자란다. 한 스테이지에 레벨을 여러 개 사므로 공격이 항상
/// 앞서가고, 스테이지 100 부터는 무엇을 해도 **한 방**이 된다(실측).
/// 그래서 "기준선 대비 얼마나 세졌는지"를 체력에 일부 반영한다.
///
/// 두 가지를 일부러 지켰다:
///  1. **보정은 월드 안에서만** 건다. 월드 관문(worldHpMult)에 걸면 벽이
///     같이 뭉개져 "뚫는 맛"이 사라진다 — 관문 배율은 보정 밖에 곱한다.
///  2. 지수 [RunConfig.hpAdaptPower] < 1 이라 **강해질수록 타격 수는 줄어든다**.
///     1.0 이면 항상 같은 횟수가 되어 성장 실감이 사라진다.
/// [tier] = 난이도 회차(0=쉬움). 회차가 오르면 몬스터가 통째로 세진다
/// (`docs/design_difficulty_loop.md`). **적응형 보정 밖에 곱한다** —
/// 안쪽에 넣으면 보정이 회차 상승을 그대로 상쇄해 아무 일도 안 일어난다.
int habitatMaxHp(RunConfig c, int depth, {double? playerAttack, int tier = 0}) {
  final base = c.hpBase * math.pow(c.hpGrowth, depth);
  final gate = c.worldMult(c.worldHpMult, depth);
  if (playerAttack == null || c.hpAdaptPower <= 0 || c.hpAdaptTargetHits <= 0) {
    return (base * gate).round();
  }
  // 기준선 = 이 깊이에서 목표 타격 수로 잡으려면 필요한 공격력.
  //
  // ⚠️ 회차는 **목표 타격 수**를 늘려서 반영한다. 체력에 직접 곱하면 타격
  // 수가 그대로 배가 되어(극한에서 13,777대) 지루한 스펀지가 된다.
  final onCurve = base / c.tierTargetHits(tier);
  // ⚠️ 상한도 회차와 함께 열어야 한다. 안 그러면 목표 타격 수를 아무리
  // 올려도 **상한이 먼저 걸려** 체력이 전 회차 동일해진다(2026-08-30 실측:
  // 목표 14→504 인데 체력은 그대로였다). 회차 난이도가 통째로 무효가 된다.
  final ratio = (playerAttack / onCurve).clamp(
    c.hpAdaptMinRatio,
    c.hpAdaptMaxRatio * c.tierHits(tier),
  );
  final hp = base * math.pow(ratio, c.hpAdaptPower) * gate;
  // ⚠️ int64 포화 방어. 회차마다 보정 상한을 열어 주므로(위) 극한 회차의
  // 월드보스가 한계(9.22e18)에 **딱 닿는다**(2026-08-30 실측 여유 1.00배).
  // 넘으면 `.round()` 가 포화시켜 조용히 이상한 값이 되고, 그 체력으로
  // 나눈 타격 수·시간이 전부 틀어진다. 여유를 두고 자른다.
  return hp >= kMaxMonsterHp ? kMaxMonsterHp : hp.round();
}

/// 보스 최대 HP. 월드 마지막 보스(1-100)는 [RunConfig.worldBossHpMult] 추가
/// — 다음 월드로 가는 관문 벽.
int bossMaxHp(RunConfig c, int depth, {double? playerAttack, int tier = 0}) {
  final worldFinal = c.isWorldFinal(depth + 1) ? c.worldBossHpMult : 1.0;
  // ⚠️ 서식지 체력에 **또 곱하므로** 여기서도 상한을 본다. 서식지 쪽만
  // 막으면 보스에서 넘친다(2026-08-30 실측: 9.22e18 로 포화).
  final hp =
      habitatMaxHp(c, depth, playerAttack: playerAttack, tier: tier) *
      c.bossHpMult *
      worldFinal;
  return hp >= kMaxMonsterHp ? kMaxMonsterHp : hp.round();
}

/// 파괴 보상 골드. 보스면 [c.bossRewardMult] 배. 월드마다 [c.worldGoldMult] 점프.
int rewardGold(
  RunConfig c,
  int depth,
  double rewardMultiplier, {
  bool boss = false,
  int tier = 0,
}) {
  final base =
      c.goldBase *
      math.pow(c.goldGrowth, depth) *
      c.worldMult(c.worldGoldMult, depth) *
      rewardMultiplier *
      // ⚠️ 보상도 회차와 함께 오른다. 몬스터만 세지면 회차를 넘어갈 이유가
      // 없다 — 더 오래 걸리고 덜 버는 선택지가 되기 때문이다.
      c.tierReward(tier);
  return (base * (boss ? c.bossRewardMult : 1.0)).round();
}

/// 파괴 보상 경험치. 골드와 같은 월드 점프를 따른다.
/// 깊이 [depth] 에서 처치당 재료 수량에 곱할 배율.
///
/// 골드처럼 지수 성장시켜 **재료:골드 비율이 구간마다 뒤집히지 않게** 한다.
/// `materialAmountGrowth` 가 1.0 이면 1.0 을 돌려줘 기존 동작 그대로다.
double materialAmountMult(RunConfig c, int depth) =>
    c.materialAmountGrowth <= 1.0
    ? 1.0
    : math.pow(c.materialAmountGrowth, depth).toDouble();

int rewardXp(RunConfig c, int depth, {bool boss = false}) {
  final base =
      c.xpBase *
      math.pow(c.xpGrowth, depth) *
      c.worldMult(c.worldGoldMult, depth);
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
/// 적 HP 와 같은 월드 점프를 따른다(플레이어 체력 업그레이드도 곱연산이므로).
double habitatThreat(
  RunConfig c,
  int depth, {
  bool boss = false,
  double? playerToughness,
  int tier = 0,
}) {
  final base =
      c.threatBase *
      math.pow(c.threatGrowth, depth) *
      c.worldMult(c.worldHpMult, depth);
  // 회차가 오르면 **맞는 게 아프다** — 여기가 난이도의 본체다. 체력을
  // 부풀리면 타격 수만 늘어 지루해지지만, 공격이 세지면 체력·방어·회복과
  // 장비 옵션이 실제 선택이 된다(docs/design_difficulty_loop.md).
  final bossMult = (boss ? c.bossThreatMult : 1.0) * c.tierThreat(tier);
  if (playerToughness == null || c.threatAdaptTargetPct <= 0) {
    return base * bossMult;
  }
  // 몬스터 공격을 **내 방어 전력에 비례**시킨다. 한 대가 늘 체력의 일정
  // 비율을 가져가므로, 깊이와 무관하게 "맞으면 아프다"가 유지된다.
  //
  // ⚠️ 지수를 1 이 아닌 값으로 두면 못 쓴다. 방어 축은 **제곱으로** 작동해서
  // (체력으로 한 번, 방어력 나눗셈으로 또 한 번) 지수를 0.1 만 바꿔도 결과가
  // 수십~수만 배로 흔들린다(1.6 → 0%, 1.8 → 265%). 튜닝 손잡이로 쓸 수 없다.
  //
  // 대신 **기준에서 무엇을 빼느냐**로 투자 보람을 만든다(§6 과 같은 원칙):
  //   기준에 넣는 것   업그레이드·펫의 체력·방어 → 곡선을 따라가는 유지비
  //   기준 밖(순수 이득) 회복 · 장비(옷·바지) · 방어 스킬 · 버프
  // 회복은 애초에 이 식에 없으므로 올린 만큼 그대로 버틴다.
  final threat = playerToughness * c.threatAdaptTargetPct;
  // 초반(전력이 미미할 때)에는 곡선 절대값이 더 크면 그쪽을 쓴다.
  return math.max(base, threat) * bossMult;
}

double toughnessOf(CharacterStats s) => s.maxHp * (1 + s.defense / 100);

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
///
/// double 인 이유: 곱연산 성장(valueGrowth)에서는 후반 스탯이 int64 를 넘는다
/// — `.round()` 는 9.2e18 에서 조용히 포화해 CP 가 멈춘 것처럼 보였다.
double combatPower(CharacterStats s) {
  final dps =
      s.attack *
      s.attackSpeed *
      (1 + s.critChance * (s.critDamage - 1)) *
      s.bossDamage;
  final effectiveHp = s.maxHp * (1 + s.defense / 100);
  return dps * 6 + effectiveHp * 0.4;
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

/// 방치 진행 결과 — 골드/경험치뿐 아니라 **스테이지 진행**과 처치 수를 함께 낸다.
///
/// 서버가 권위를 가질 때 스테이지가 서버에만 남으면 재시작마다 진행이
/// 사라지므로(로컬 스크롤러는 연출), 방치 정산이 스테이지도 올려야 한다.
@immutable
class IdleProgress {
  const IdleProgress({
    required this.newStage,
    required this.gold,
    required this.xp,
    required this.habitatClears,
    required this.bossClears,
    required this.accrued,
  });

  /// 정산 후 도달 스테이지(시작 스테이지 이상).
  final int newStage;
  final int gold;
  final int xp;

  /// 처치한 서식지 수(소수) — 드롭 롤·`killMonsters` 미션 근거.
  final double habitatClears;

  /// 처치한 보스 수 — `killBosses` 미션 근거.
  final int bossClears;
  final Duration accrued;

  bool get isEmpty => gold <= 0 && xp <= 0 && bossClears == 0;

  /// 진행 없이 스테이지만 유지하는 결과(예산 0·dps 0 인 경우).
  IdleProgress copyStage(int stage) => IdleProgress(
    newStage: stage,
    gold: 0,
    xp: 0,
    habitatClears: 0,
    bossClears: 0,
    accrued: Duration.zero,
  );

  static const IdleProgress empty = IdleProgress(
    newStage: 1,
    gold: 0,
    xp: 0,
    habitatClears: 0,
    bossClears: 0,
    accrued: Duration.zero,
  );
}

/// 경과시간 동안의 방치 진행을 **스테이지가 오르며** 시뮬레이션한다.
///
/// 한 스테이지 = 서식지 [RunConfig.habitatsPerStage] 개 + 보스 1.
/// 스테이지를 다 밀면 다음 스테이지로 넘어가고, 그러면 적 HP 가 커져
/// (`hpGrowth`) 처치가 느려진다 — 그래서 무한히 오르지 않고 전투력에 수렴한다.
///
/// [maxStageAdvance] 는 안전장치(dps 가 비정상으로 크면 루프가 길어질 수 있다).
/// 서버·앱이 **같은 함수**를 써야 "서버가 준 스테이지"와 앱 연출이 어긋나지 않는다.
IdleProgress simulateIdleProgress({
  required RunConfig config,
  required int startStage,
  required CharacterStats stats,
  required Duration elapsed,
  Duration maxAccrual = kMaxOfflineAccrual,
  double efficiency = 0.5,
  int maxStageAdvance = 500,
  int tier = 0,
  int? finalStage,
}) {
  if (elapsed <= Duration.zero) {
    return IdleProgress.empty.copyStage(startStage);
  }
  // 1타 데미지는 화면과 같은 기준(치명타 포함)을 쓴다 — 여기서 치명타를 빼면
  // 체력에는 반영되고 화력에는 안 실려 방치 수입이 이중으로 깎인다.
  final hit = baselineHitPower(stats);
  final bossHit = baselineHitPower(stats, boss: true);
  final dps = hit * stats.attackSpeed;
  if (dps <= 0) return IdleProgress.empty.copyStage(startStage);

  final capped = elapsed > maxAccrual ? maxAccrual : elapsed;
  var budget = capped.inMilliseconds / 1000.0;
  final eff = efficiency <= 0 ? 1.0 : efficiency;
  final bossDps = bossHit * stats.attackSpeed;

  var stage = startStage;
  var gold = 0.0;
  var xp = 0.0;
  var habitatClears = 0.0;
  var bossClears = 0;
  var advanced = 0;

  while (budget > 0 && advanced < maxStageAdvance) {
    final depth = stage - 1;
    final habHp = habitatMaxHp(
      config,
      depth,
      playerAttack: hit,
      tier: tier,
    ).toDouble();
    final bossHp = bossMaxHp(
      config,
      depth,
      playerAttack: bossHit,
      tier: tier,
    ).toDouble();
    // 효율을 시간에 반영: 실제로 한 번 처치하는 데 드는 예산(초).
    final habTime = (habHp / dps + 0.6) / eff;
    final bossTime = (bossHp / bossDps + 0.6) / eff;
    final stageTime = config.habitatsPerStage * habTime + bossTime;

    final goldHab = rewardGold(
      config,
      depth,
      stats.rewardMultiplier,
      tier: tier,
    );
    final xpHab = rewardXp(config, depth);

    if (budget >= stageTime) {
      // 스테이지 전체(서식지들 + 보스)를 밀고 다음 스테이지로.
      gold +=
          config.habitatsPerStage * goldHab +
          rewardGold(
            config,
            depth,
            stats.rewardMultiplier,
            boss: true,
            tier: tier,
          );
      xp +=
          config.habitatsPerStage * xpHab + rewardXp(config, depth, boss: true);
      habitatClears += config.habitatsPerStage;
      bossClears += 1;
      budget -= stageTime;
      stage += 1;
      advanced += 1;
    } else {
      // 남은 예산으로 서식지만(보스 못 잡으면 스테이지는 안 넘어간다).
      final n = budget / habTime;
      final cleared = n > config.habitatsPerStage
          ? config.habitatsPerStage.toDouble()
          : n;
      gold += cleared * goldHab;
      xp += cleared * xpHab;
      habitatClears += cleared;
      budget = 0;
    }
  }

  return IdleProgress(
    newStage: stage,
    gold: gold.round(),
    xp: (xp * stats.xpMultiplier).round(),
    habitatClears: habitatClears,
    bossClears: bossClears,
    accrued: capped,
  );
}

/// 오프라인 동안의 골드/경험치 추정 (현재 스테이지·능력치 기준 파밍 속도 × 시간).
/// 상한 [maxAccrual](기본 8h), 효율 [efficiency](실시간 대비).
/// 경과시간 동안 처치했을 서식지 수(효율 반영). 소수 단위다.
///
/// 방치 수입·드롭을 **같은 근거**로 계산하기 위해 분리했다.
/// 서버가 드롭을 굴릴 때도 이 값을 쓴다 — 공식이 두 벌이 되면
/// "골드는 맞는데 곤충 수가 다른" 상황이 생긴다.
double estimateClears({
  required RunConfig config,
  required int stageNumber,
  required CharacterStats stats,
  required Duration elapsed,
  Duration maxAccrual = kMaxOfflineAccrual,
  double efficiency = 0.5,
}) {
  if (elapsed <= Duration.zero) return 0;
  final capped = elapsed > maxAccrual ? maxAccrual : elapsed;
  final secs = capped.inMilliseconds / 1000.0;
  final hit = baselineHitPower(stats);
  final dps = hit * stats.attackSpeed;
  if (dps <= 0) return 0;
  final hp = habitatMaxHp(
    config,
    stageNumber - 1,
    playerAttack: hit,
  ).toDouble();
  final timePerClear = hp / dps + 0.6; // + 이동시간 근사
  if (timePerClear <= 0) return 0;
  return secs / timePerClear * efficiency;
}

OfflineReport computeOfflineReward({
  required RunConfig config,
  required int stageNumber,
  required CharacterStats stats,
  required Duration elapsed,
  Duration maxAccrual = kMaxOfflineAccrual,
  double efficiency = 0.5,
  int tier = 0,
}) {
  if (elapsed <= Duration.zero) return OfflineReport.empty;
  final capped = elapsed > maxAccrual ? maxAccrual : elapsed;
  final clears = estimateClears(
    config: config,
    stageNumber: stageNumber,
    stats: stats,
    elapsed: elapsed,
    maxAccrual: maxAccrual,
    efficiency: efficiency,
  );
  if (clears <= 0) return OfflineReport.empty;

  final depth = stageNumber - 1;
  final goldPer = rewardGold(config, depth, stats.rewardMultiplier, tier: tier);
  final xpPer = (rewardXp(config, depth) * stats.xpMultiplier).round();

  return OfflineReport(
    gold: (clears * goldPer).round(),
    xp: (clears * xpPer).round(),
    accrued: capped,
  );
}
