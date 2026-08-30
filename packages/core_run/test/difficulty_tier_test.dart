import 'dart:convert';
import 'dart:io';

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:test/test.dart';

/// 난이도 회차(`docs/design_difficulty_loop.md`).
///
/// 스테이지 1000 을 깨면 스테이지만 1 로 돌아가고 회차가 오른다.
/// 세 문제가 한 뿌리라 함께 풀린다 — 스테이지 무한(1708 유저 실재) ·
/// 후반 무의미(1200→1800 이 0.3일) · 골드 int64 오버플로.
void main() {
  final cfg = RunConfig.fromJson(
    jsonDecode(File('../app/assets/data/run_config.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  test('회차 기능이 켜져 있다', () {
    expect(cfg.tierHitsMult, greaterThan(1.0));
    expect(cfg.tierThreatMult, greaterThan(1.0));
    expect(cfg.tierRewardMult, greaterThan(1.0));
  });

  /// ⚠️ **회차는 실제로 어려워져야 한다.**
  ///
  /// 처음엔 목표 타격 수만 올렸는데 `hpAdaptMaxRatio`(3000)가 **먼저 걸려**
  /// 체력이 전 회차 동일했다 — 목표를 14→504 로 올려도 아무 일이 없었다
  /// (2026-08-30 실측). 보정 상한도 회차와 함께 열어야 작동한다.
  test('회차가 오르면 몬스터가 실제로 세진다', () {
    for (final atk in [1e3, 1e6, 1e9]) {
      final easy = habitatMaxHp(cfg, 199, playerAttack: atk);
      final extreme = habitatMaxHp(cfg, 199, playerAttack: atk, tier: 3);
      expect(extreme, greaterThan(easy), reason: 'atk=$atk');
    }
  });

  /// ⚠️ 그렇다고 무한정 세지면 안 된다. int64 를 넘으면 `.round()` 가 조용히
  /// 포화시키고, 그 체력으로 나눈 타격 수·소요 시간이 전부 틀어진다.
  test('체력은 int64 상한 안에서 멈춘다', () {
    final hp = bossMaxHp(cfg, 999, playerAttack: double.maxFinite, tier: 3);
    expect(hp, greaterThan(0), reason: '음수면 이미 넘친 것이다');
    expect(hp, lessThanOrEqualTo(kMaxMonsterHp));
    // 곱셈이 한 번 더 일어나도 넘치지 않을 여유가 있어야 한다.
    expect(kMaxMonsterHp, lessThan(9223372036854775807 ~/ 2));
  });

  test('난이도는 위협도(맞는 아픔)로 온다', () {
    final easy = habitatThreat(cfg, 199, playerToughness: 1e6);
    final extreme = habitatThreat(cfg, 199, playerToughness: 1e6, tier: 3);
    expect(extreme / easy, closeTo(cfg.tierThreat(3), 0.01));
    expect(cfg.tierThreat(3), greaterThan(5.0), reason: '확실히 위험해야 한다');
  });

  test('보상도 회차와 함께 오른다', () {
    final easy = rewardGold(cfg, 200, 1.0);
    final extreme = rewardGold(cfg, 200, 1.0, tier: 3);
    expect(
      extreme / easy,
      closeTo(cfg.tierReward(3), cfg.tierReward(3) * 0.005),
    );
  });

  test('회차 0(쉬움)은 아무것도 바꾸지 않는다 — 구버전과 같다', () {
    expect(cfg.tierThreat(0), 1.0);
    expect(cfg.tierReward(0), 1.0);
    expect(cfg.tierTargetHits(0), cfg.hpAdaptTargetHits);
    expect(habitatMaxHp(cfg, 100, tier: 0), habitatMaxHp(cfg, 100));
  });

  /// 마지막 회차까지 가도 골드가 int64 안에 있어야 한다 — 그러라고 회차로
  /// 끊은 것이다(2026-08-30 오버플로 사고).
  test('마지막 회차의 마지막 스테이지 보상도 상한 안이다', () {
    final g = rewardGold(cfg, 999, 1.0, boss: true, tier: 3);
    expect(g, greaterThan(0), reason: '음수면 이미 넘친 것이다');
    expect(g, lessThan(9223372036854775807 ~/ 1000));
  });
}
