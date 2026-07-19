import 'package:meta/meta.dart';

/// 스카우트 보드의 난이도 티어. 상대 파워 배율과 보상 배율을 함께 정의한다.
/// (하이리스크-하이리턴: 파워↑ 상대일수록 보상↑)
@immutable
class ScoutTier {
  const ScoutTier({
    required this.id,
    required this.powerMult,
    required this.rewardMult,
  });

  /// 티어 식별자(라벨/색 매핑용): easy / even / hard 등.
  final String id;

  /// 상대 팀 파워 배율(1.0 = 내 로스터 기준 대등).
  final double powerMult;

  /// 승리 보상(골드·트로피) 배율.
  final double rewardMult;

  factory ScoutTier.fromJson(Map<String, dynamic> json) => ScoutTier(
    id: json['id'] as String,
    powerMult: (json['powerMult'] as num).toDouble(),
    rewardMult: (json['rewardMult'] as num).toDouble(),
  );
}

/// 리그(트로피 등급). 이름은 앱 레이어에서 id로 현지화(scoutTier 와 동일 방식).
@immutable
class League {
  const League({
    required this.id,
    required this.minTrophy,
    this.rewardGold = 0,
    this.rewardJelly = 0,
  });

  /// bronze / silver / gold / platinum / diamond 등.
  final String id;

  /// 이 리그 진입 최소 트로피(오름차순 가정).
  final int minTrophy;

  /// 이 리그 최초 도달 시 1회 승급 보상.
  final int rewardGold;
  final int rewardJelly;

  bool get hasReward => rewardGold > 0 || rewardJelly > 0;

  factory League.fromJson(Map<String, dynamic> json) {
    final reward = json['reward'] as Map<String, dynamic>?;
    return League(
      id: json['id'] as String,
      minTrophy: (json['minTrophy'] as num).toInt(),
      rewardGold: (reward?['gold'] as num?)?.toInt() ?? 0,
      rewardJelly: (reward?['jelly'] as num?)?.toInt() ?? 0,
    );
  }
}

/// PvP(곤충 결투) 보상·스카우트·리그 설정 (JSON, §6). 순수 데이터 홀더 —
/// 승패 판정(BattleOutcome)은 core_battle 소관이라 여기서 참조하지 않는다.
@immutable
class BattleConfig {
  const BattleConfig({
    this.winGoldBase = 4000,
    this.winGoldPerTrophy = 30,
    this.trophyWin = 12,
    this.trophyDraw = 0,
    this.trophyLose = -8,
    this.scoutTiers = _defaultTiers,
    this.leagues = _defaultLeagues,
    this.seasonDays = 14,
    this.seasonResetFactor = 0.5,
    this.seasonRewardMult = 3.0,
    this.locationAffinityBonus = 0.2,
  });

  /// 승리 기본 골드.
  final int winGoldBase;

  /// 트로피 1점당 추가 골드(현재 트로피 점수에 비례).
  final int winGoldPerTrophy;

  /// 승/무/패 트로피 증감.
  final int trophyWin;
  final int trophyDraw;
  final int trophyLose;

  /// 스카우트 난이도 티어(보통 3개).
  final List<ScoutTier> scoutTiers;

  /// 트로피 등급(오름차순, 최소 1개).
  final List<League> leagues;

  /// 시즌 길이(일). 만료 시 트로피 소프트리셋 + 시즌 보상.
  final int seasonDays;

  /// 시즌 종료 시 트로피 유지 비율(0.5 = 절반으로 강등).
  final double seasonResetFactor;

  /// 시즌 보상 = 최고 리그 승급보상 × 이 배율.
  final double seasonRewardMult;

  /// 장소 상성: 전투 장소 오행과 같은 곤충의 데미지 강화 비율(0.2 = +20%).
  final double locationAffinityBonus;

  static const _defaultTiers = [
    ScoutTier(id: 'easy', powerMult: 0.82, rewardMult: 0.7),
    ScoutTier(id: 'even', powerMult: 1.0, rewardMult: 1.0),
    ScoutTier(id: 'hard', powerMult: 1.22, rewardMult: 1.6),
  ];

  static const _defaultLeagues = [
    League(id: 'bronze', minTrophy: 0),
    League(id: 'silver', minTrophy: 100, rewardGold: 5000, rewardJelly: 5),
    League(id: 'gold', minTrophy: 300, rewardGold: 15000, rewardJelly: 10),
    League(id: 'platinum', minTrophy: 700, rewardGold: 40000, rewardJelly: 20),
    League(id: 'diamond', minTrophy: 1500, rewardGold: 100000, rewardJelly: 40),
  ];

  /// 승리 골드 = (기본 + 트로피×계수) × 보상배율.
  int winGold(int trophies, double rewardMult) =>
      ((winGoldBase + trophies * winGoldPerTrophy) * rewardMult).round();

  /// 승리 트로피 = 기본 × 보상배율(최소 1).
  int trophyOnWin(double rewardMult) {
    final v = (trophyWin * rewardMult).round();
    return v < 1 ? 1 : v;
  }

  /// [trophies] 로 도달한 현재 리그(오름차순 가정, 최소 첫 리그).
  League leagueFor(int trophies) {
    var cur = leagues.first;
    for (final lg in leagues) {
      if (trophies >= lg.minTrophy) cur = lg;
    }
    return cur;
  }

  /// [cur] 바로 위 리그(최고 등급이면 null).
  League? nextLeagueAfter(League cur) {
    final i = leagues.indexOf(cur);
    return (i >= 0 && i + 1 < leagues.length) ? leagues[i + 1] : null;
  }

  /// 현재 리그→다음 리그 진행도 0~1(최고 등급이면 1.0).
  double leagueProgress(int trophies) {
    final cur = leagueFor(trophies);
    final next = nextLeagueAfter(cur);
    if (next == null) return 1.0;
    final span = next.minTrophy - cur.minTrophy;
    if (span <= 0) return 1.0;
    return ((trophies - cur.minTrophy) / span).clamp(0.0, 1.0);
  }

  /// 도달했지만 아직 승급 보상을 안 받은 리그들.
  List<League> claimableLeagues(int trophies, Set<String> claimed) => [
    for (final lg in leagues)
      if (lg.hasReward && trophies >= lg.minTrophy && !claimed.contains(lg.id))
        lg,
  ];

  /// 시즌 종료 보상 = 최고 트로피 도달 리그의 승급보상 × 시즌 배율.
  ({int gold, int jelly}) seasonReward(int peakTrophies) {
    final lg = leagueFor(peakTrophies);
    return (
      gold: (lg.rewardGold * seasonRewardMult).round(),
      jelly: (lg.rewardJelly * seasonRewardMult).round(),
    );
  }

  /// 시즌 종료 후 남는 트로피(소프트 리셋).
  int seasonResetTrophies(int trophies) =>
      (trophies * seasonResetFactor).floor();

  factory BattleConfig.fromJson(Map<String, dynamic> json) {
    final scout = json['scout'] as Map<String, dynamic>?;
    final tiers = scout?['tiers'] as List?;
    final season = json['season'] as Map<String, dynamic>?;
    return BattleConfig(
      winGoldBase: (json['winGoldBase'] as num?)?.toInt() ?? 4000,
      winGoldPerTrophy: (json['winGoldPerTrophy'] as num?)?.toInt() ?? 30,
      trophyWin: (json['trophyWin'] as num?)?.toInt() ?? 12,
      trophyDraw: (json['trophyDraw'] as num?)?.toInt() ?? 0,
      trophyLose: (json['trophyLose'] as num?)?.toInt() ?? -8,
      scoutTiers: tiers == null
          ? _defaultTiers
          : [
              for (final t in tiers)
                ScoutTier.fromJson(t as Map<String, dynamic>),
            ],
      leagues: (json['leagues'] as List?) == null
          ? _defaultLeagues
          : [
              for (final lg in (json['leagues'] as List))
                League.fromJson(lg as Map<String, dynamic>),
            ],
      seasonDays: (season?['days'] as num?)?.toInt() ?? 14,
      seasonResetFactor: (season?['resetFactor'] as num?)?.toDouble() ?? 0.5,
      seasonRewardMult: (season?['rewardMult'] as num?)?.toDouble() ?? 3.0,
      locationAffinityBonus:
          (json['locationAffinityBonus'] as num?)?.toDouble() ?? 0.2,
    );
  }
}
