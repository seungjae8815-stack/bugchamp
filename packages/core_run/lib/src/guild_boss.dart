import 'dart:math' as math;

import 'package:meta/meta.dart';

import 'battle_config.dart' show SeasonRankReward;

/// 길드 보스(docs/design_guild.md §3, 2026-10-01 4단계) — 주 1마리, 체력은 길드가 공유·이월.
///
/// - 피해는 **서버가** 계산한다. 입력 = 결투 방어팀 전투력(서버 `validateDuelTeam` 이 이미 검증 —
///   설계 A안). 홈 전투력(기기 권위)을 쓰면 누구나 1위다. 방어팀이 없으면 공격할 수 없다.
/// - 체력 = 방어팀이 있는 길드원 전투력 합 × [hitsPerMember] (모두가 그만큼 치면 1단계가 쓰러진다)
///   × [stageGrowth]^(단계−1). 길드 규모 차이를 체력이 흡수한다.
/// - 개인 보상 = 공격마다 코인 + **피해 구간 상자**(약한 유저도 첫 상자는 받는다). 처치하면 그 주에
///   공격한 길드원 **모두** 코인. 젤리는 **주간 순위**(같은 티어 길드끼리)로만 — 유한 통로(§2.6).
/// ⚠️ 요정·스킬·장비·길드 버프는 싣지 않는다(결투와 같은 선 — 뽑기가 순위를 정하지 않게).
@immutable
class GuildBossConfig {
  const GuildBossConfig({
    this.attacksPerDay = 2,
    this.hitsPerMember = 4,
    this.stageGrowth = 1.6,
    this.variance = 0.15,
    this.attackCoins = 10,
    this.chestShares = const [0.02, 0.05, 0.10],
    this.chestCoins = const [5, 10, 20],
    this.killCoinsPerStage = 20,
    this.killExp = 20,
    this.attackExp = 1,
    this.rankRewards = const [],
  });

  final int attacksPerDay;
  final double hitsPerMember;
  final double stageGrowth;

  /// 피해 흔들림(±).
  final double variance;
  final int attackCoins;

  /// 피해 구간 상자 — 한 번에 보스 최대 체력의 이 비율 이상을 넣으면 해당 상자 코인(가장 높은 한 칸).
  final List<double> chestShares;
  final List<int> chestCoins;
  final int killCoinsPerStage;
  final int killExp;
  final int attackExp;

  /// 주간 순위(같은 티어) 보상 — 그 주에 공격한 길드원 한 명당 젤리.
  final List<SeasonRankReward> rankRewards;

  factory GuildBossConfig.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const GuildBossConfig();
    const d = GuildBossConfig();
    List<double> dl(String k, List<double> v) => j[k] is List
        ? [for (final x in j[k] as List) (x as num).toDouble()]
        : v;
    List<int> il(String k, List<int> v) =>
        j[k] is List ? [for (final x in j[k] as List) (x as num).toInt()] : v;
    return GuildBossConfig(
      attacksPerDay: (j['attacksPerDay'] as num?)?.toInt() ?? d.attacksPerDay,
      hitsPerMember:
          (j['hitsPerMember'] as num?)?.toDouble() ?? d.hitsPerMember,
      stageGrowth: (j['stageGrowth'] as num?)?.toDouble() ?? d.stageGrowth,
      variance: (j['variance'] as num?)?.toDouble() ?? d.variance,
      attackCoins: (j['attackCoins'] as num?)?.toInt() ?? d.attackCoins,
      chestShares: dl('chestShares', d.chestShares),
      chestCoins: il('chestCoins', d.chestCoins),
      killCoinsPerStage:
          (j['killCoinsPerStage'] as num?)?.toInt() ?? d.killCoinsPerStage,
      killExp: (j['killExp'] as num?)?.toInt() ?? d.killExp,
      attackExp: (j['attackExp'] as num?)?.toInt() ?? d.attackExp,
      rankRewards: [
        for (final r in (j['rankRewards'] as List? ?? const []))
          SeasonRankReward.fromJson(r as Map<String, dynamic>),
      ],
    );
  }

  /// [stage] 단계 최대 체력 — [teamPowerSum] = 방어팀이 있는 길드원 전투력 합.
  double hpFor(double teamPowerSum, int stage) =>
      math.max(1.0, teamPowerSum) *
      hitsPerMember *
      math.pow(stageGrowth, stage - 1);

  /// 한 번 공격 피해 — 방어팀 전투력 × (1 ± variance). [roll] 은 0~1 (서버 난수).
  double damage(double teamPower, double roll) =>
      math.max(0.0, teamPower) * (1 + variance * (roll * 2 - 1));

  /// 피해 구간 상자 코인(가장 높은 칸 하나). [share] = 피해 / 보스 최대 체력.
  int chestFor(double share) {
    var out = 0;
    for (var i = 0; i < chestShares.length && i < chestCoins.length; i++) {
      if (share >= chestShares[i]) out = chestCoins[i];
    }
    return out;
  }

  int rankJelly(int rank) {
    if (rank < 1) return 0;
    for (final r in rankRewards) {
      if (rank <= r.maxRank) return r.jelly;
    }
    return 0;
  }
}
