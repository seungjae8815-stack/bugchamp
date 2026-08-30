import 'dart:convert';
import 'dart:io';

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
    expect(cfg.tierHpMult, greaterThan(1.0));
    expect(cfg.tierRewardMult, greaterThan(1.0));
  });

  /// ⚠️ 몬스터만 세지면 회차를 넘어갈 이유가 없다 — 더 오래 걸리고 덜 번다.
  /// 보상만 세지면 넘어가는 게 공짜가 된다.
  test('몬스터와 보상이 같은 폭으로 오른다', () {
    expect(cfg.tierRewardMult, cfg.tierHpMult);
    for (final t in [1, 2, 3]) {
      expect(cfg.tierReward(t), closeTo(cfg.tierHp(t), 1e-6));
    }
  });

  test('회차 0(쉬움)은 아무것도 바꾸지 않는다 — 구버전과 같다', () {
    expect(cfg.tierHp(0), 1.0);
    expect(cfg.tierReward(0), 1.0);
    expect(habitatMaxHp(cfg, 100, tier: 0), habitatMaxHp(cfg, 100));
  });

  test('회차가 오르면 몬스터 체력이 오른다', () {
    final easy = habitatMaxHp(cfg, 100, playerAttack: 1000);
    final normal = habitatMaxHp(cfg, 100, playerAttack: 1000, tier: 1);
    expect(normal, greaterThan(easy));
    expect(normal / easy, closeTo(cfg.tierHpMult, 0.01));
  });

  /// ⚠️ 회차 배율은 **적응형 보정 밖**에 곱해야 한다. 안쪽에 넣으면 보정이
  /// 회차 상승을 그대로 상쇄해 아무 일도 일어나지 않는다.
  test('적응형 보정이 회차 상승을 상쇄하지 않는다', () {
    for (final atk in [100.0, 1e6, 1e12]) {
      final easy = habitatMaxHp(cfg, 300, playerAttack: atk);
      final hard = habitatMaxHp(cfg, 300, playerAttack: atk, tier: 2);
      expect(hard / easy, closeTo(cfg.tierHp(2), 0.01), reason: 'atk=$atk');
    }
  });

  test('보상도 회차와 함께 오른다', () {
    final easy = rewardGold(cfg, 200, 1.0);
    final extreme = rewardGold(cfg, 200, 1.0, tier: 3);
    // 정수 반올림 때문에 비율이 소수점에서 흔들린다 — 0.5% 안이면 같다고 본다.
    expect(
      extreme / easy,
      closeTo(cfg.tierReward(3), cfg.tierReward(3) * 0.005),
    );
  });

  /// 마지막 회차까지 가도 골드가 int64 안에 있어야 한다 — 그러라고 회차로
  /// 끊은 것이다(2026-08-30 오버플로 사고).
  test('마지막 회차의 마지막 스테이지 보상도 상한 안이다', () {
    final g = rewardGold(cfg, 999, 1.0, boss: true, tier: 3);
    expect(g, greaterThan(0), reason: '음수면 이미 넘친 것이다');
    expect(g, lessThan(9223372036854775807 ~/ 1000));
  });
}
