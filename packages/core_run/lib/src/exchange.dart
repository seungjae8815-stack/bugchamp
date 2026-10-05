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
  ({double gold, double kills}) hunt(double hours) {
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
    return (gold: p.gold.toDouble(), kills: p.habitatClears);
  }

  final gold = hunt(c.exchangeGoldHours).gold * trades;
  // 재료 = 처치당 기대 수량(확률 × 평균 1.5개 × 깊이 배율 × 넘친 발견 배율) — 실시간 처치와 같은 식.
  // 3종을 고루 준다(한 종만 주면 부족한 종을 노려 반복 교환하게 된다).
  final drop = materialDrop(c, stats.materialFind);
  final perKill =
      drop.chance * 1.5 * materialAmountMult(c, stage - 1) * drop.amountMult;
  final mats = hunt(c.exchangeMaterialHours).kills * perKill * trades / 3;
  return (gold: gold.round(), materialsEach: mats.round());
}
