// 서버 골드 상식상한(mergeSave) vs 실제 열심히 플레이한 유저의 60초 수입 비교.
//
// 서버는 60초 업로드마다 `simulateIdleProgress(efficiency: 30)` 로 상한을 잡고
// 넘으면 자른다. 상한이 낮으면 **정당한 유저의 골드가 잘린다** — 방어보다
// 오탐이 나쁘다. 접속 보너스(+60%)를 얹었으니 여유가 남았는지 확인한다.
import 'dart:convert';
import 'dart:io';
import 'package:core_run/core_run.dart';

void main() {
  final dir = '../app/assets/data';
  final run = RunConfig.fromJson(
    jsonDecode(File('$dir/run_config.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  const window = 60.0; // 업로드 주기(초)
  const saveBoundEfficiency = 30.0; // actions.dart 와 동일해야 한다
  const goldSanityFloor = 200000;

  // 실제 유저 상단 케이스: 펫 최대(공격 x4) · 광폭화(DPS x1.8) · 골드러시(x2)
  // · 탭 부스트 최대(데미지 x5, 속도 x(1+4*factor)) · 접속 보너스.
  const petAtk = 4.04;
  const frenzy = 1.8;
  const goldRush = 2.0;

  print('스테이지 | 서버 상한(60초) | 실제 최대 수입 | 여유배수');
  for (final stage in [50, 100, 200, 400, 700, 1000]) {
    final levels = <UpgradeKind, int>{
      for (final k in UpgradeKind.values) k: (stage * 0.9).round(),
    };
    // 서버가 상한을 계산할 때 쓰는 스탯: 펫·버프 없음.
    final serverStats = deriveStats(
      run,
      upgradeLevels: levels,
      characterLevel: 1 + stage ~/ 5,
      bugsCollected: 50,
    );
    final bound =
        goldSanityFloor +
        simulateIdleProgress(
          config: run,
          startStage: stage,
          stats: serverStats,
          elapsed: const Duration(seconds: window ~/ 1),
          efficiency: saveBoundEfficiency,
        ).gold;

    // 실제 유저: 펫이 공격에 실리고, 적응형 체력도 그만큼 오른다.
    // 기준 1타는 `baselineHitPower`(치명타 포함) — 앱·서버와 같은 식이어야 한다.
    final hit = baselineHitPower(serverStats) * petAtk;
    final dps = hit * serverStats.attackSpeed * frenzy * run.boostMultMax;
    final speedMul = 1 + (run.boostMultMax - 1) * run.boostSpeedFactor;
    final depth = stage - 1;
    final hp = habitatMaxHp(run, depth, playerAttack: hit).toDouble();
    final perKill = hp / dps + 0.6 / speedMul;
    final goldPerKill =
        rewardGold(run, depth, goldRush) * (1 + run.onlineGoldBonus);
    final actual = window / perKill * goldPerKill;

    final ratio = actual <= 0 ? double.infinity : bound / actual;
    final mark = ratio < 1.0 ? '  ← 잘린다!' : (ratio < 2.0 ? '  ← 여유 부족' : '');
    print(
      '${stage.toString().padLeft(7)} | '
      '${bound.toStringAsFixed(0).padLeft(15)} | '
      '${actual.toStringAsFixed(0).padLeft(13)} | '
      'x${ratio.toStringAsFixed(2)}$mark',
    );
  }
}
