import 'dart:convert';
import 'dart:io';

import 'package:core_run/core_run.dart';
import 'package:test/test.dart';

/// 회차가 오프라인 정산에 빠지면 어떻게 되는가:
/// 처치 수는 회차-0 체력으로 재서 3^회차 배 부풀고, 골드 단가에만 회차 배율이
/// 실려 **오프라인 골드가 회차당 3배 과지급**된다. 온라인(실시간 루프)은
/// 회차를 아는데 오프라인만 모르면, 껐다 켜는 게 이득인 게임이 된다.
void main() {
  late RunConfig config;
  setUpAll(() {
    final raw = File('../app/assets/data/run_config.json').readAsStringSync();
    config = RunConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  });

  CharacterStats stats() => deriveStats(
    config,
    upgradeLevels: const {UpgradeKind.attack: 40, UpgradeKind.maxHp: 30},
    characterLevel: 40,
    bugsCollected: 50,
  );

  test('회차 1 오프라인 골드가 회차 0 의 3배로 튀지 않는다', () {
    OfflineReport at(int tier) => computeOfflineReward(
      config: config,
      stageNumber: 500,
      stats: stats(),
      elapsed: const Duration(hours: 4),
      tier: tier,
    );
    final g0 = at(0).gold;
    final g1 = at(1).gold;
    // 처치 수(÷3)와 단가(×3)가 상쇄돼 같은 자릿수여야 한다. 과지급 버그가
    // 재발하면 g1 ≈ 3 × g0 으로 벌어진다.
    expect(g1, lessThan(g0 * 2), reason: '회차 배율이 한쪽에만 실렸다');
    expect(g1, greaterThan(g0 ~/ 2), reason: '회차 배율이 반대쪽에만 실렸다');
  });

  test('서버 정산이 캠페인 끝을 넘겨 전진하지 않는다', () {
    final prog = simulateIdleProgress(
      config: config,
      startStage: 998,
      stats: stats(),
      elapsed: const Duration(hours: 8),
      efficiency: 30, // 서버 봉투처럼 후하게 — 전진 여지를 최대로
      finalStage: 1000,
    );
    expect(prog.newStage, lessThanOrEqualTo(1000));
    // 끝에 멈춰도 파밍은 계속돼야 한다(보상 0 이면 상한이 벌이 된다).
    expect(prog.gold, greaterThan(0));
  });

  /// 끝에 눌러앉아 파밍하는 게 회차를 넘기는 것보다 이득이면, 회차 시스템은
  /// 아무도 쓰지 않는다. 온라인·방치 **양쪽 모두** 깎여야 한다 — 한쪽만
  /// 깎으면 "켜 두면 손해"가 되어 눌러앉기가 오히려 최적이 된다.
  test('끝에 눌러앉으면 방치 보상이 깎인다', () {
    OfflineReport at({int? finalStage}) => computeOfflineReward(
      config: config,
      // 이 스탯으로 실제 클리어가 되는 깊이라야 0 이 아닌 값이 나온다.
      stageNumber: 300,
      stats: stats(),
      elapsed: const Duration(hours: 4),
      finalStage: finalStage,
    );
    final normal = at().gold;
    expect(normal, greaterThan(0), reason: '테스트 전제: 이 구간은 클리어된다');
    final parked = at(finalStage: 300).gold;
    expect(parked, lessThan(normal ~/ 2), reason: '눌러앉기 페널티가 안 걸렸다');
    expect(at(finalStage: 300).xp, lessThan(at().xp));
  });

  test('끝 직전 스테이지는 깎이지 않는다', () {
    final before = computeOfflineReward(
      config: config,
      stageNumber: 299,
      stats: stats(),
      elapsed: const Duration(hours: 4),
      finalStage: 300,
    ).gold;
    final noCap = computeOfflineReward(
      config: config,
      stageNumber: 299,
      stats: stats(),
      elapsed: const Duration(hours: 4),
    ).gold;
    expect(before, noCap, reason: '정상 진행 구간까지 깎으면 안 된다');
  });
}
