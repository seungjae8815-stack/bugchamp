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

  /// 난이도별 표(2026-09-15)가 들어온 뒤로 적응형 위협의 회차 배율은
  /// **표의 threatAdaptMult** 다. 예전 곱셈(2.0^회차 = 극한 x8)은 한 대가
  /// 체력의 96% 라 극한을 아무도 못 깼다(balance_sim 실측 미완주).
  test('난이도는 위협도(맞는 아픔)로 온다 — 오를수록 아프되 한 방은 아니다', () {
    // 표의 절대값보다 적응형 몫이 커지도록 맷집을 크게 준다.
    final easy = habitatThreat(cfg, 199, playerToughness: 1e12);
    final extreme = habitatThreat(cfg, 199, playerToughness: 1e12, tier: 3);
    final m0 = cfg.zoneTier(0)?.threatAdaptMult ?? cfg.tierThreat(0);
    final m3 = cfg.zoneTier(3)?.threatAdaptMult ?? cfg.tierThreat(3);
    expect(extreme / easy, closeTo(m3 / m0, 0.01));
    expect(m3, greaterThan(m0), reason: '어려운 회차가 더 아파야 한다');
    // 한 대 = 맷집 × pct × 간격 × 배율 — 극한에서도 체력의 절반을 넘지 않는다.
    expect(
      cfg.threatAdaptTargetPct * cfg.enemyAtkInterval * m3,
      lessThan(0.5),
      reason: '극한 한 대가 체력의 절반을 넘으면 두 대에 죽는다',
    );
  });

  /// 난이도별 표에서는 배율이 아니라 **표 자체**가 오른다 — 같은 사냥터라도
  /// 어려운 회차가 더 번다(안 그러면 넘어갈 이유가 없다).
  test('보상도 회차와 함께 오른다', () {
    for (var z = 1; z <= cfg.zonesPerTier; z++) {
      final depth = cfg.zoneStartStage(z) - 1;
      var prev = rewardGold(cfg, depth, 1000.0);
      for (var t = 1; t < 4; t++) {
        final g = rewardGold(cfg, depth, 1000.0, tier: t);
        expect(g, greaterThan(prev), reason: '사냥터 $z 회차 $t');
        prev = g;
      }
    }
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
