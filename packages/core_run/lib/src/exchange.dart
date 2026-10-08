import 'character_stats.dart';
import 'run_config.dart';
import 'run_math.dart';

/// 교환소 젤리 → 골드·재료(2026-10-05 사장님 확정): 교환 1회 = **이 능력치로 직접 사냥한
/// [RunConfig.exchangeGoldHours]시간치**.
///
/// 예전엔 처치 골드를 골드 배율 1.0(맨몸) × 시간당 1,500마리로 쟀다. 강화·펫·장비·도감·길드 배율과
/// 실제 처치 속도가 빠져서 "1시간치"가 평균 유저의 실제 1시간의 1/30(5일차)~1/190(70일차)이었다
/// (balance_sim 실측) — 젤리를 쓸 이유가 없는 상품이었다.
///
/// [stats] 는 버프·접속 보너스를 **뺀** 사냥 능력치다(켜고 끄는 값에 교환량이 흔들리지 않게).
/// 계산은 방치 정산([simulateIdleProgress])을 효율 1.0 으로 돌린 것 — 사냥터 몬스터를 그 자리에서
/// 잡는 시간당 처치 수 × 처치 골드라 화면 사냥과 같은 식이다.
/// ⚠️ 앱(지급)과 서버(골드·재료 상한 허용치)가 같은 함수를 쓴다. 서버는 [efficiency] 를 넉넉히 줘서
/// 강화만 아는 전력으로도 정당한 교환이 잘리지 않게 한다(60초 골드 상한과 같은 봉투).
({int gold, int materialsEach}) exchangeOutput(
  RunConfig c, {
  required CharacterStats stats,
  required int stage,
  required int trades,
  int tier = 0,
  int abyssFloor = 0,
  double efficiency = 1.0,
}) {
  if (trades <= 0) return (gold: 0, materialsEach: 0);
  final gold = _hunt(
    c,
    stats,
    stage,
    tier,
    abyssFloor,
    efficiency,
    c.exchangeGoldHours,
  ).gold;
  final kills = _hunt(
    c,
    stats,
    stage,
    tier,
    abyssFloor,
    efficiency,
    c.exchangeMaterialHours,
  ).kills;
  return (
    gold: (gold * trades).round(),
    materialsEach: (_materialsEach(c, stats, stage, kills) * trades).round(),
  );
}

/// 깜짝선물·일일보상 — 이 능력치로 **[minutes]분 직접 사냥한** 골드·재료(종류당)(2026-10-08 사장님 확정).
///
/// 예전엔 맨몸 기준 골드 표(`giftGold`)로 쟀다. 강화·펫·장비 배율이 빠져서 "선물 2.7분치"가 실제로는
/// 쉬움 초반 18초 · 쉬움 끝 2초 · 보통 이후 1초 미만이었다(balance_sim 실측) — 열어도 아무 일이 없었다.
/// 교환소([exchangeOutput])와 같은 식이다. [stats] 는 버프·접속 보너스를 뺀 사냥 능력치(`huntStatsOf`).
/// ⚠️ 앱(금액 계산)과 서버(상한)가 같은 함수를 쓴다. 서버는 [efficiency] 를 넉넉히 줘서 강화만 아는
/// 전력으로도 정당한 금액이 잘리지 않게 한다.
({int gold, int materialsEach}) huntMinutesReward(
  RunConfig c, {
  required CharacterStats stats,
  required int stage,
  required double minutes,
  int tier = 0,
  int abyssFloor = 0,
  double efficiency = 1.0,
}) {
  if (minutes <= 0) return (gold: 0, materialsEach: 0);
  final h = _hunt(c, stats, stage, tier, abyssFloor, efficiency, minutes / 60);
  return (
    gold: h.gold.round(),
    materialsEach: _materialsEach(c, stats, stage, h.kills).round(),
  );
}

/// 효율 [efficiency] 로 [hours] 시간 사냥 — 방치 정산([simulateIdleProgress])과 같은 식.
({double gold, double kills}) _hunt(
  RunConfig c,
  CharacterStats stats,
  int stage,
  int tier,
  int abyssFloor,
  double efficiency,
  double hours,
) {
  if (hours <= 0) return (gold: 0, kills: 0);
  final d = Duration(milliseconds: (hours * 3600 * 1000).round());
  final p = simulateIdleProgress(
    config: c,
    startStage: stage,
    stats: stats,
    elapsed: d,
    maxAccrual: d,
    efficiency: efficiency,
    tier: tier,
    abyssFloor: abyssFloor,
  );
  return (gold: p.gold.toDouble(), kills: p.habitatClears.toDouble());
}

/// 재료 = 처치당 기대 수량(확률 × 평균 1.5개 × 깊이 배율 × 넘친 발견 배율) — 실시간 처치와 같은 식.
/// 3종을 고루 준다(한 종만 주면 부족한 종을 노려 반복 교환하게 된다).
double _materialsEach(
  RunConfig c,
  CharacterStats stats,
  int stage,
  double kills,
) {
  final drop = materialDrop(c, stats.materialFind);
  final perKill =
      drop.chance * 1.5 * materialAmountMult(c, stage - 1) * drop.amountMult;
  return kills * perKill / 3;
}
