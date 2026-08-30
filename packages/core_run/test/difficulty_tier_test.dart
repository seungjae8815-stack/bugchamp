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
    expect(cfg.tierHitsMult, greaterThan(1.0));
    expect(cfg.tierThreatMult, greaterThan(1.0));
    expect(cfg.tierRewardMult, greaterThan(1.0));
  });

  /// ⚠️ **이게 이 설계의 핵심이다.** 적응형 체력은 이미 "몇 대에 죽나"를
  /// 목표치로 맞춘다. 거기에 배율을 곱하면 타격 수가 그대로 배가 되어
  /// 극한에서 몬스터 하나에 13,777대가 됐다(2026-08-30 실측). 지루한
  /// 스펀지지 어려운 게 아니다.
  ///
  /// 난이도는 **위험**에서 나와야 한다 — 그래야 체력·방어·회복과 장비
  /// 옵션이 실제 선택이 된다.
  test('회차가 올라도 타격 수가 폭주하지 않는다', () {
    for (final atk in [1e3, 1e6, 1e9]) {
      final easy = habitatMaxHp(cfg, 199, playerAttack: atk) / atk;
      final extreme = habitatMaxHp(cfg, 199, playerAttack: atk, tier: 3) / atk;
      // 극한이라도 쉬움의 5배를 넘지 않는다(예전 설계는 **1000배**였다).
      expect(extreme / easy, lessThan(5.0), reason: 'atk=$atk');
      expect(extreme, greaterThanOrEqualTo(easy), reason: 'atk=$atk');
    }
    // 보정이 상한(hpAdaptMaxRatio)에 닿지 않은 구간에서는 실제로 길어진다.
    // ⚠️ 닿은 구간(공격력이 아주 큰 후반)에서는 회차가 체력을 못 바꾼다 —
    // 그때 난이도는 **위협도**가 만든다(아래 테스트).
    expect(
      habitatMaxHp(cfg, 199, playerAttack: 1e3, tier: 3),
      greaterThan(habitatMaxHp(cfg, 199, playerAttack: 1e3)),
    );
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
