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

  /// [level] → [level]+1 수련 비용(골드). 최대치면 0.
  int trainCost(int level) => level >= maxLevel
      ? 0
      : (trainBaseCost * math.pow(trainCostGrowth, level - 1)).round();

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
