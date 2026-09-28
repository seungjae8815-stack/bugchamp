import 'dart:math' as math;

import 'package:meta/meta.dart';

import 'battle_config.dart' show SeasonRankReward;

/// 심연 — 극한 이후 무한 층 + 주간 최고 층 순위(docs/design_abyss.md, 2026-09-28 사장님 확정).
///
/// 심연에 있는 동안 난이도는 극한, 스테이지는 극한 최종 사냥터로 고정된다 — 표에서 나오는
/// 몬스터·골드 기준값이 이미 "극한 끝"이다. 층은 그 위에 **배율만** 곱한다(`abyssScale`).
/// 스테이지를 늘리는 방식이 아닌 이유: 재료 수량이 `1.008^(스테이지)` 라 스테이지 축을 늘리면
/// 지수로 폭주한다. 수치는 `run_config.json → abyss`.
@immutable
class AbyssConfig {
  const AbyssConfig({
    this.hpGrowth = 1.06,
    this.threatGrowth = 1.05,
    this.goldGrowth = 1.05,
    this.milestoneEvery = 10,
    this.milestoneShards = 10,
    this.milestoneFossil = 100,
    this.minSecondsPerFloor = 90,
    this.rankRewards = const [],
  });

  /// 층마다 몬스터·보스 체력 배율.
  final double hpGrowth;

  /// 층마다 표 위협 배율(적응형 위협과 큰 쪽이 쓰인다).
  final double threatGrowth;

  /// 층마다 골드 배율. **체력보다 느리게** — 어딘가에서 벽에 닿아야 순위가 갈린다.
  final double goldGrowth;

  /// 이 층수마다 **처음 도달**하면 조각·화석 일시금(역대 최고 층 기준이라 주간 리셋에도 한 번뿐).
  final int milestoneEvery;
  final int milestoneShards;
  final int milestoneFossil;

  /// 층 하나를 깨는 데 걸릴 수 있는 **최소 시간**(초) — 서버가 업로드마다 층 증가 상한을 건다.
  /// 몬스터 100마리 + 보스라 정상 플레이로는 이보다 빠를 수 없다(심연은 기기 권위라
  /// 세이브를 고쳐 999층을 적는 위조를 여기서 막는다).
  final double minSecondsPerFloor;

  /// 주간 최고 층 순위 보상(젤리) — 결투 시즌 순위와 같은 구조.
  final List<SeasonRankReward> rankRewards;

  /// [floor] 층의 배율(1층 = 1). 0 이하는 심연 밖.
  double scale(double growth, int floor) =>
      floor <= 1 ? 1.0 : math.pow(growth, floor - 1).toDouble();

  int rankJelly(int rank) {
    if (rank < 1) return 0;
    for (final r in rankRewards) {
      if (rank <= r.maxRank) return r.jelly;
    }
    return 0;
  }

  factory AbyssConfig.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const AbyssConfig();
    const d = AbyssConfig();
    double n(String k, double v) => (j[k] as num?)?.toDouble() ?? v;
    int i(String k, int v) => (j[k] as num?)?.toInt() ?? v;
    return AbyssConfig(
      hpGrowth: n('hpGrowth', d.hpGrowth),
      threatGrowth: n('threatGrowth', d.threatGrowth),
      goldGrowth: n('goldGrowth', d.goldGrowth),
      milestoneEvery: i('milestoneEvery', d.milestoneEvery),
      milestoneShards: i('milestoneShards', d.milestoneShards),
      milestoneFossil: i('milestoneFossil', d.milestoneFossil),
      minSecondsPerFloor: n('minSecondsPerFloor', d.minSecondsPerFloor),
      rankRewards: [
        for (final r in (j['rankRewards'] as List? ?? const []))
          SeasonRankReward.fromJson(r as Map<String, dynamic>),
      ],
    );
  }
}
