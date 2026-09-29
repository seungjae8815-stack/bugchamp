import 'dart:math' as math;

import 'package:core_models/core_models.dart';
import 'package:meta/meta.dart';

import 'jelly_cost.dart';

/// 훈련소 설정(2026-09-29 사장님 확정, `battle.json → training`).
///
/// 곤충마다 결투 능력치 5종([TrainStat])을 훈련한다. **모든 능력치를 끝까지 올릴 수 있지만
/// 끝(최대 단계)이 곤충마다 다르다** — 기본 + 포텐셜 + 기질·주특기·혈통 특성 보정.
/// 그래서 한 종류 곤충만 키우기보다 역할이 다른 곤충을 섞어 팀을 짜게 된다.
///
/// 비용 = 키틴·미네랄·수액 각각 `baseCost × costGrowth^(단계-1) × 등급 배수`(부위 강화와 같은 곡선) ·
/// 시간 = `baseSeconds × timeGrowth^(단계-1)` · 젤리 즉시 완료(분당 단가가 긴 대기일수록 싸진다).
@immutable
class TrainingConfig {
  const TrainingConfig({
    this.perLevel = const {
      TrainStat.attack: 0.015,
      TrainStat.defense: 0.015,
      TrainStat.evade: 0.01,
      TrainStat.crit: 0.01,
      TrainStat.recovery: 0.02,
    },
    this.baseCap = 6,
    this.capPerPotential = 1,
    this.temperamentMods = const {},
    this.specialtyMods = const {},
    this.traitMods = const {},
    this.baseCost = 20,
    this.costGrowth = 1.25,
    this.gradeMult = const {},
    this.baseSeconds = 900,
    this.timeGrowth = 1.6,
    this.instantJellyPerMinute = 0.5,
    this.instantJellyExponent = 0.58,
    this.resetRefund = 0.5,
    this.petScale = 0.005,
    this.duelLevelBonus = 0.005,
  });

  /// 한 단계 효과(공격·방어 = 배율 +, 회피·치명·회복력 = 확률·비율 +).
  final Map<TrainStat, double> perLevel;

  /// 최대 단계 = baseCap + capPerPotential × 포텐셜 + 기질·주특기·특성 보정.
  final int baseCap;
  final int capPerPotential;
  final Map<Temperament, Map<TrainStat, int>> temperamentMods;
  final Map<Specialty, Map<TrainStat, int>> specialtyMods;
  final Map<BugTrait, Map<TrainStat, int>> traitMods;

  final double baseCost;
  final double costGrowth;
  final Map<Grade, double> gradeMult;
  final double baseSeconds;
  final double timeGrowth;
  final double instantJellyPerMinute;
  final double instantJellyExponent;

  /// 초기화 때 돌려받는 재료 비율.
  final double resetRefund;

  /// 훈련 → 방치(펫): 훈련 단계 합계 1당 펫 기여 +petScale(부위 강화 `enhanceScale` 과 같은 자리).
  final double petScale;

  /// 수련 → 결투: 레벨 1당 체력·공격 +duelLevelBonus(돌파 티어 레벨 상한으로 자른다).
  final double duelLevelBonus;

  /// 이 곤충의 [stat] 최대 단계.
  int cap(
    TrainStat stat, {
    required int potential,
    required Temperament temperament,
    required Specialty specialty,
    BugTrait trait = BugTrait.none,
  }) {
    final c =
        baseCap +
        capPerPotential * potential +
        (temperamentMods[temperament]?[stat] ?? 0) +
        (specialtyMods[specialty]?[stat] ?? 0) +
        (traitMods[trait]?[stat] ?? 0);
    return math.max(0, c);
  }

  /// [level]단계로 올리는 재료비(키틴·미네랄·수액 **각각**).
  int costFor(int level, Grade grade) =>
      (baseCost * math.pow(costGrowth, level - 1) * (gradeMult[grade] ?? 1))
          .round();

  /// [level]단계로 올리는 훈련 시간.
  Duration timeFor(int level) => Duration(
    seconds: (baseSeconds * math.pow(timeGrowth, level - 1)).round(),
  );

  /// 남은 [remaining] 을 젤리로 즉시 끝내는 값(5·10 단위).
  int instantJelly(Duration remaining) {
    if (remaining <= Duration.zero) return 0;
    final minutes = remaining.inSeconds / 60;
    return roundJellyCost(
      instantJellyPerMinute * math.pow(minutes, instantJellyExponent),
    );
  }

  /// 단계 [levels] → 결투 보너스.
  ({double atkMult, double defMult, double evade, double crit, double recovery})
  bonuses(Map<TrainStat, int> levels) {
    double v(TrainStat s) => (levels[s] ?? 0) * (perLevel[s] ?? 0);
    return (
      atkMult: 1 + v(TrainStat.attack),
      defMult: 1 + v(TrainStat.defense),
      evade: v(TrainStat.evade),
      crit: v(TrainStat.crit),
      recovery: v(TrainStat.recovery),
    );
  }

  factory TrainingConfig.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const TrainingConfig();
    const d = TrainingConfig();
    Map<TrainStat, int> mods(Object? raw) => {
      for (final e in ((raw as Map?) ?? const {}).entries)
        if (TrainStat.fromKeyOrNull('${e.key}') != null)
          TrainStat.fromKeyOrNull('${e.key}')!: (e.value as num).toInt(),
    };
    Map<K, Map<TrainStat, int>> table<K>(Object? raw, K Function(String) key) =>
        {
          for (final e in ((raw as Map?) ?? const {}).entries)
            key('${e.key}'): mods(e.value),
        };
    final per = mods(null).map((k, v) => MapEntry(k, v.toDouble()));
    for (final e in ((j['perLevel'] as Map?) ?? const {}).entries) {
      final k = TrainStat.fromKeyOrNull('${e.key}');
      if (k != null) per[k] = (e.value as num).toDouble();
    }
    return TrainingConfig(
      perLevel: per.isEmpty ? d.perLevel : per,
      baseCap: (j['baseCap'] as num?)?.toInt() ?? d.baseCap,
      capPerPotential:
          (j['capPerPotential'] as num?)?.toInt() ?? d.capPerPotential,
      temperamentMods: table(j['temperamentMods'], Temperament.fromKey),
      specialtyMods: table(j['specialtyMods'], Specialty.fromKey),
      traitMods: table(j['traitMods'], BugTrait.fromKey),
      baseCost: (j['baseCost'] as num?)?.toDouble() ?? d.baseCost,
      costGrowth: (j['costGrowth'] as num?)?.toDouble() ?? d.costGrowth,
      gradeMult: {
        for (final e in ((j['gradeMult'] as Map?) ?? const {}).entries)
          Grade.fromKey('${e.key}'): (e.value as num).toDouble(),
      },
      baseSeconds: (j['baseSeconds'] as num?)?.toDouble() ?? d.baseSeconds,
      timeGrowth: (j['timeGrowth'] as num?)?.toDouble() ?? d.timeGrowth,
      instantJellyPerMinute:
          (j['instantJellyPerMinute'] as num?)?.toDouble() ??
          d.instantJellyPerMinute,
      instantJellyExponent:
          (j['instantJellyExponent'] as num?)?.toDouble() ??
          d.instantJellyExponent,
      resetRefund: (j['resetRefund'] as num?)?.toDouble() ?? d.resetRefund,
      petScale: (j['petScale'] as num?)?.toDouble() ?? d.petScale,
      duelLevelBonus:
          (j['duelLevelBonus'] as num?)?.toDouble() ?? d.duelLevelBonus,
    );
  }
}
