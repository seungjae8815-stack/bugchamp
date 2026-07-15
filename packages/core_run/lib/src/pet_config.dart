import 'dart:math' as math;

import 'package:core_models/core_models.dart';
import 'package:meta/meta.dart';

/// 애완펫(장착 곤충) 보너스·진화·합성·수련 설정 (JSON, §6).
@immutable
class PetConfig {
  const PetConfig({
    required this.gradeAttackPct,
    required this.gradeHpPct,
    required this.stageMult,
    required this.stageDurationsSec,
    this.potentialScale = 0.06,
    this.enhanceScale = 0.005,
    this.maxEquip = 3,
    this.accelerateJelly = 2,
    this.synthFodder = 3,
    this.synthMaxPotential = 5,
    this.maxLevel = 30,
    this.levelBonus = 0.06,
    this.trainBaseCost = 200,
    this.trainCostGrowth = 1.18,
    this.trainJellyCost = 3,
    this.trainJellyLevels = 5,
    this.tierCaps = const [10, 20, 35, 55, 80],
    this.breakthroughDurationsSec = const [600, 1800, 5400, 14400],
    this.breakthroughGold = const [20000, 60000, 200000, 600000],
    this.breakthroughMaterial = const [100, 250, 600, 1500],
    this.breakthroughJellyPerMinute = 0.5,
    this.incubatorSlotsInitial = 1,
    this.incubatorSlotsMax = 3,
    this.incubatorExpandJelly = 30,
    this.incubateDurationsSec = const {},
    this.injuryDurationsSec = const {},
    this.injuryJellyPerMinute = 0.5,
    this.breedingDurationsSec = const {},
    this.breedingJellyPerMinute = 0.5,
    this.breedingSlotsInitial = 1,
    this.breedingSlotsMax = 3,
    this.breedingExpandJelly = 40,
    this.breedingSizeVariancePct = 0.08,
    this.breedingMutationChance = 0.05,
    this.breedingMutationBonusPct = 0.15,
    this.breedingPotUpChance = 0.10,
    this.breedingPotDownChance = 0.30,
  });

  /// 등급별 공격력 기여(0.05 = +5%).
  final Map<Grade, double> gradeAttackPct;

  /// 등급별 체력 기여.
  final Map<Grade, double> gradeHpPct;

  /// 생애주기 단계별 보너스 배율(알<유충<번데기<성충).
  final Map<LifeStage, double> stageMult;

  /// 단계별 다음 단계까지 걸리는 시간(초). 성충은 없음.
  final Map<LifeStage, int> stageDurationsSec;

  /// 포텐셜 1당 기여 증폭.
  final double potentialScale;

  /// 강화 레벨 합 1당 기여 증폭.
  final double enhanceScale;

  /// 최대 장착 수.
  final int maxEquip;

  /// 진화 1단계 촉진에 드는 젤리.
  final int accelerateJelly;

  /// 합성으로 포텐셜 +1 하는 데 필요한 재료 곤충 수.
  final int synthFodder;

  /// 합성으로 올릴 수 있는 최대 포텐셜.
  final int synthMaxPotential;

  /// 성충 수련 최대 레벨.
  final int maxLevel;

  /// 레벨 1당 그 펫 기여의 증폭(0.06 = 레벨당 +6%p).
  final double levelBonus;

  /// 수련(레벨업) 골드 비용 곡선.
  final double trainBaseCost;
  final double trainCostGrowth;

  /// 젤리 즉시 수련(레거시): [trainJellyCost] 젤리로 한 번에 [trainJellyLevels] 레벨.
  final int trainJellyCost;
  final int trainJellyLevels;

  /// 돌파 티어별 레벨 상한(누적 절대값). 예: [10,20,35,55,80].
  final List<int> tierCaps;

  /// 티어 i→i+1 돌파에 걸리는 시간(초).
  final List<int> breakthroughDurationsSec;

  /// 티어 i→i+1 돌파 골드 비용.
  final List<int> breakthroughGold;

  /// 티어 i→i+1 돌파 재료 비용(키틴/미네랄/수액 각각).
  final List<int> breakthroughMaterial;

  /// 즉시완료 젤리 = 남은분 × 이 값(비례, 최소 1).
  final double breakthroughJellyPerMinute;

  /// 부화기 초기/최대 슬롯 수, 슬롯 확장 젤리 비용.
  final int incubatorSlotsInitial;
  final int incubatorSlotsMax;
  final int incubatorExpandJelly;

  /// 등급별 알→유충 부화 시간(초).
  final Map<Grade, int> incubateDurationsSec;

  /// 등급별 KO 후 부상 회복 시간(초). 높은 등급일수록 회복이 오래 걸린다.
  final Map<Grade, int> injuryDurationsSec;

  /// 부상 즉시회복 젤리 = 남은분 × 이 값(비례, 최소 1).
  final double injuryJellyPerMinute;

  /// 브리딩(§2.5) 설정.
  final Map<Grade, int> breedingDurationsSec; // 등급별 임신(산란) 시간
  final double breedingJellyPerMinute; // 즉시완료 젤리 비례계수
  final int breedingSlotsInitial;
  final int breedingSlotsMax;
  final int breedingExpandJelly;
  final double breedingSizeVariancePct; // 부모평균 대비 사이즈 변이
  final double breedingMutationChance; // 돌연변이 확률
  final double breedingMutationBonusPct; // 돌연변이 사이즈 보너스
  final double breedingPotUpChance; // 포텐셜 상승 확률
  final double breedingPotDownChance; // 포텐셜 하락 확률(나머지=유지)

  /// 돌파 최대 티어(마지막 인덱스).
  int get maxTier => tierCaps.length - 1;

  /// 티어의 레벨 상한.
  int levelCap(int tier) => tierCaps[tier.clamp(0, maxTier)];

  int _atOrLast(List<int> xs, int i) =>
      xs.isEmpty ? 0 : xs[i.clamp(0, xs.length - 1)];

  int breakthroughDuration(int tier) =>
      _atOrLast(breakthroughDurationsSec, tier);
  int breakthroughGoldCost(int tier) => _atOrLast(breakthroughGold, tier);
  int breakthroughMatCost(int tier) => _atOrLast(breakthroughMaterial, tier);

  /// 남은 시간 비례 즉시완료 젤리 비용.
  int breakthroughJelly(Duration remaining) {
    if (remaining <= Duration.zero) return 0;
    final v = (remaining.inSeconds / 60 * breakthroughJellyPerMinute).ceil();
    return v < 1 ? 1 : v;
  }

  int incubateDuration(Grade g) => incubateDurationsSec[g] ?? 300;

  /// 등급별 부상 회복 시간(초). 미설정이면 10분.
  int injuryDuration(Grade g) => injuryDurationsSec[g] ?? 600;

  /// 남은 시간 비례 부상 즉시회복 젤리 비용(최소 1).
  int injuryJelly(Duration remaining) {
    if (remaining <= Duration.zero) return 0;
    final v = (remaining.inSeconds / 60 * injuryJellyPerMinute).ceil();
    return v < 1 ? 1 : v;
  }

  /// 등급별 산란(임신) 시간(초). 미설정이면 20분.
  int breedingDuration(Grade g) => breedingDurationsSec[g] ?? 1200;

  /// 남은 시간 비례 브리딩 즉시완료 젤리 비용(최소 1).
  int breedingJelly(Duration remaining) {
    if (remaining <= Duration.zero) return 0;
    final v = (remaining.inSeconds / 60 * breedingJellyPerMinute).ceil();
    return v < 1 ? 1 : v;
  }

  /// [level] → [level]+1 수련 비용(골드).
  int trainCost(int level) =>
      (trainBaseCost * math.pow(trainCostGrowth, level - 1)).round();

  factory PetConfig.fromJson(Map<String, dynamic> json) {
    Map<Grade, double> grades(String key) => {
      for (final e in (json[key] as Map<String, dynamic>).entries)
        Grade.fromKey(e.key): (e.value as num).toDouble(),
    };
    return PetConfig(
      gradeAttackPct: grades('gradeAttackPct'),
      gradeHpPct: grades('gradeHpPct'),
      stageMult: {
        for (final e in (json['stageMult'] as Map<String, dynamic>).entries)
          LifeStage.fromKey(e.key): (e.value as num).toDouble(),
      },
      stageDurationsSec: {
        for (final e
            in (json['stageDurationsSec'] as Map<String, dynamic>).entries)
          LifeStage.fromKey(e.key): (e.value as num).toInt(),
      },
      potentialScale: (json['potentialScale'] as num?)?.toDouble() ?? 0.06,
      enhanceScale: (json['enhanceScale'] as num?)?.toDouble() ?? 0.005,
      maxEquip: (json['maxEquip'] as num?)?.toInt() ?? 3,
      accelerateJelly: (json['accelerateJelly'] as num?)?.toInt() ?? 2,
      synthFodder: (json['synthFodder'] as num?)?.toInt() ?? 3,
      synthMaxPotential: (json['synthMaxPotential'] as num?)?.toInt() ?? 5,
      maxLevel: (json['maxLevel'] as num?)?.toInt() ?? 30,
      levelBonus: (json['levelBonus'] as num?)?.toDouble() ?? 0.06,
      trainBaseCost: (json['trainBaseCost'] as num?)?.toDouble() ?? 200,
      trainCostGrowth: (json['trainCostGrowth'] as num?)?.toDouble() ?? 1.18,
      trainJellyCost: (json['trainJellyCost'] as num?)?.toInt() ?? 3,
      trainJellyLevels: (json['trainJellyLevels'] as num?)?.toInt() ?? 5,
      tierCaps:
          (json['tierCaps'] as List?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [10, 20, 35, 55, 80],
      breakthroughDurationsSec:
          (json['breakthroughDurationsSec'] as List?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [600, 1800, 5400, 14400],
      breakthroughGold:
          (json['breakthroughGold'] as List?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [20000, 60000, 200000, 600000],
      breakthroughMaterial:
          (json['breakthroughMaterial'] as List?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [100, 250, 600, 1500],
      breakthroughJellyPerMinute:
          (json['breakthroughJellyPerMinute'] as num?)?.toDouble() ?? 0.5,
      incubatorSlotsInitial:
          (json['incubatorSlotsInitial'] as num?)?.toInt() ?? 1,
      incubatorSlotsMax: (json['incubatorSlotsMax'] as num?)?.toInt() ?? 3,
      incubatorExpandJelly:
          (json['incubatorExpandJelly'] as num?)?.toInt() ?? 30,
      incubateDurationsSec: {
        for (final e
            in ((json['incubateDurationsSec'] as Map<String, dynamic>?) ??
                    const {})
                .entries)
          Grade.fromKey(e.key): (e.value as num).toInt(),
      },
      injuryDurationsSec: {
        for (final e
            in ((json['injuryDurationsSec'] as Map<String, dynamic>?) ??
                    const {})
                .entries)
          Grade.fromKey(e.key): (e.value as num).toInt(),
      },
      injuryJellyPerMinute:
          (json['injuryJellyPerMinute'] as num?)?.toDouble() ?? 0.5,
      breedingDurationsSec: {
        for (final e
            in ((json['breedingDurationsSec'] as Map<String, dynamic>?) ??
                    const {})
                .entries)
          Grade.fromKey(e.key): (e.value as num).toInt(),
      },
      breedingJellyPerMinute:
          (json['breedingJellyPerMinute'] as num?)?.toDouble() ?? 0.5,
      breedingSlotsInitial:
          (json['breedingSlotsInitial'] as num?)?.toInt() ?? 1,
      breedingSlotsMax: (json['breedingSlotsMax'] as num?)?.toInt() ?? 3,
      breedingExpandJelly: (json['breedingExpandJelly'] as num?)?.toInt() ?? 40,
      breedingSizeVariancePct:
          (json['breedingSizeVariancePct'] as num?)?.toDouble() ?? 0.08,
      breedingMutationChance:
          (json['breedingMutationChance'] as num?)?.toDouble() ?? 0.05,
      breedingMutationBonusPct:
          (json['breedingMutationBonusPct'] as num?)?.toDouble() ?? 0.15,
      breedingPotUpChance:
          (json['breedingPotUpChance'] as num?)?.toDouble() ?? 0.10,
      breedingPotDownChance:
          (json['breedingPotDownChance'] as num?)?.toDouble() ?? 0.30,
    );
  }
}

/// 장착 펫이 캐릭터에 주는 최종 배율.
@immutable
class PetBonus {
  const PetBonus({required this.attackMult, required this.hpMult});
  final double attackMult;
  final double hpMult;
  static const none = PetBonus(attackMult: 1, hpMult: 1);
}

/// 펫 1마리의 보너스 계산 입력(앱에서 종·개체를 해석해 넘긴다).
typedef PetStat = ({
  Grade grade,
  double sizeMult,
  int potential,
  int enhanceTotal,
  LifeStage stage,
  int level,
});

/// 펫 1마리가 기여하는 공격/체력 배율(장착 효과 표시·합산 공용).
({double attack, double hp}) petContribution(PetStat p, PetConfig cfg) {
  final scale =
      (1 + p.potential * cfg.potentialScale) *
      p.sizeMult *
      (1 + p.enhanceTotal * cfg.enhanceScale) *
      (cfg.stageMult[p.stage] ?? 1.0) *
      (1 + (p.level - 1) * cfg.levelBonus);
  return (
    attack: (cfg.gradeAttackPct[p.grade] ?? 0) * scale,
    hp: (cfg.gradeHpPct[p.grade] ?? 0) * scale,
  );
}

/// 장착 펫들의 총 보너스 배율(공격/체력).
PetBonus computePetBonus(Iterable<PetStat> pets, PetConfig cfg) {
  var atk = 0.0;
  var hp = 0.0;
  for (final p in pets) {
    final c = petContribution(p, cfg);
    atk += c.attack;
    hp += c.hp;
  }
  return PetBonus(attackMult: 1 + atk, hpMult: 1 + hp);
}

/// 저장된 단계·시각으로부터 [now] 기준 **실제 도달 단계**를 계산(경과분 자동 진화).
LifeStage effectiveStage(
  LifeStage stored,
  DateTime? since,
  DateTime now,
  PetConfig cfg,
) {
  // 알은 자동 진화하지 않는다(부화기로만 유충이 됨).
  if (stored == LifeStage.egg) return LifeStage.egg;
  var st = stored;
  var t = since ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  var guard = 0;
  while (!st.isFinal && guard < 8) {
    final dur = cfg.stageDurationsSec[st] ?? 0;
    final adv = t.add(Duration(seconds: dur));
    if (now.isBefore(adv)) break;
    st = st.next;
    t = adv;
    guard++;
  }
  return st;
}

/// 현재 **실제 단계**에서 다음 단계까지 남은 시간(성충이면 null, 이미 도달했으면 0).
Duration? stageRemaining(
  LifeStage stored,
  DateTime? since,
  DateTime now,
  PetConfig cfg,
) {
  if (stored == LifeStage.egg) return null; // 알은 부화기 수동
  var st = stored;
  var t = since ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  var guard = 0;
  while (!st.isFinal && guard < 8) {
    final adv = t.add(Duration(seconds: cfg.stageDurationsSec[st] ?? 0));
    if (now.isBefore(adv)) return adv.difference(now);
    st = st.next;
    t = adv;
    guard++;
  }
  return st.isFinal ? null : Duration.zero;
}
