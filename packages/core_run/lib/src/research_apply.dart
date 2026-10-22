import 'dart:math' as math;

import 'character_stats.dart';
import 'pet_config.dart' show defenseScaled;
import 'research_config.dart';
import 'run_config.dart';

/// 연구소 **사냥 분야**를 사냥 능력치에 얹는다(설계 §3.8 — 앱 `huntStatsUncapped`·시뮬이 같은 함수).
///
/// 전부 **곱**(1 + v)이다 — 종 패시브(`applySpeciesPassives`)와 같은 해석(§2.1 곱 원칙):
/// - 공격·골드·곤충/재료 찾기·보스 피해 = × (1 + v).
/// - 체력·방어(단단한 껍질) = 체력 × (1 + v) · 방어는 맷집 `(100 + 방어) × (1 + v)`([defenseScaled]) —
///   받는 피해가 정확히 ÷ (1 + v). 회복은 최대 체력 비율이라 체력 배율을 함께 탄다.
///
/// ⚠️ **적응형 몬스터 기준(`permanentStatsOf`) 밖**에서 부른다 — 기준에 넣으면 연구할수록 몬스터도
/// 같이 세져 연구한 의미가 사라진다(장비·종 패시브와 같은 층).
/// - 치명 피해·재생·경험치(설계 §10) = × (1 + v) — 종 패시브·요정 치명 피해와 같은 곱(§2.1).
///   재생은 체력 배율과 함께 곱한다(회복 = 최대 체력 비율).
/// - 회피(날쌘 발)만 **%p 가산** — 확률이라 치명확률·종 패시브 회피와 같다. 연구 몫은 [evadeBudget]
///   (`RunConfig.evadeBudgetResearch`)에서 자르고, 최종 상한(`evadeMax`)은 [evadeChance] 가 씌운다.
/// 방치 효율은 [researchOfflineEfficiency] · 스킬 쿨타임은 [skillCooldownMult](능력치가 아니라 시간 축).
CharacterStats applyResearchStats(
  CharacterStats s,
  ResearchEffects e, {

  /// 연구가 더할 수 있는 회피의 상한(예산, RunConfig.evadeBudgetResearch).
  double evadeBudget = kResearchEvadeMax,
}) {
  double v(ResearchEffect k) => e.of(k);
  final atk = v(ResearchEffect.huntAtk);
  final hpDef = v(ResearchEffect.huntHpDef);
  final gold = v(ResearchEffect.gold);
  final find = v(ResearchEffect.find);
  final boss = v(ResearchEffect.bossDmg);
  final critDmg = v(ResearchEffect.huntCritDmg);
  final regen = v(ResearchEffect.huntRegen);
  final xp = v(ResearchEffect.huntExp);
  final evade = math.min(v(ResearchEffect.huntEvade), evadeBudget);
  if (atk == 0 &&
      hpDef == 0 &&
      gold == 0 &&
      find == 0 &&
      boss == 0 &&
      critDmg == 0 &&
      regen == 0 &&
      xp == 0 &&
      evade <= 0) {
    return s;
  }
  return CharacterStats(
    attack: s.attack * (1 + atk),
    attackSpeed: s.attackSpeed,
    rewardMultiplier: s.rewardMultiplier * (1 + gold),
    critChance: s.critChance,
    critDamage: s.critDamage * (1 + critDmg),
    bossDamage: s.bossDamage * (1 + boss),
    maxHp: s.maxHp * (1 + hpDef),
    defense: defenseScaled(s.defense, hpDef),
    hpRegen: s.hpRegen * (1 + hpDef) * (1 + regen),
    xpMultiplier: s.xpMultiplier * (1 + xp),
    bugFind: s.bugFind * (1 + find),
    materialFind: s.materialFind * (1 + find),
    evade: s.evade + math.max(0.0, evade),
    boostBonus: s.boostBonus,
  );
}

/// 연구소 "스킬 숙련"의 쿨타임 감소 몫 — 0 ~ [budget](`RunConfig.skillCooldownBudgetResearch`).
double researchSkillCooldownCut(
  ResearchEffects e, {
  double budget = kResearchSkillCooldownMax,
}) => e.of(ResearchEffect.skillCooldown).clamp(0.0, budget).toDouble();

/// 스킬·탈피 쿨타임에 곱하는 값 = 1 − (장비 몫 + 연구 몫) — 앱 사냥 화면·스킬 화면·시뮬 공용.
///
/// [gearCut] 은 `equipmentSkillCooldownCut` 결과(장비 예산 전이어도 여기서 `skillCooldownBudgetGear` 로 다시 자른다).
/// 두 몫은 **따로** 자른다(장비 30% + 연구 20% = 최대 50%, 2026-10-22 사장님 확정) — 한 출처가 남의 자리를 먹지 않게.
double skillCooldownMult(
  RunConfig c, {
  required double gearCut,
  required ResearchEffects research,
}) =>
    1 -
    gearCut.clamp(0.0, c.skillCooldownBudgetGear) -
    researchSkillCooldownCut(research, budget: c.skillCooldownBudgetResearch);

/// 방치(오프라인) 정산용 — **골드·찾기만** 곱한다(앱 `_applyOffline` · 서버 `sync` 공용).
///
/// 방치 정산은 강화만 아는 맨몸 능력치(`deriveStats`)로 잰다 — 펫·장비·스킬도 안 들어간다.
/// 공격·체력을 여기 넣으면 연구만 방치 처치 속도를 올리는 셈이라 넣지 않고,
/// "벌이"인 골드·곤충/재료 찾기만 온라인과 같은 배율로 붙인다.
CharacterStats applyResearchIdleStats(CharacterStats s, ResearchEffects e) {
  final gold = e.of(ResearchEffect.gold);
  final find = e.of(ResearchEffect.find);
  if (gold == 0 && find == 0) return s;
  return CharacterStats(
    attack: s.attack,
    attackSpeed: s.attackSpeed,
    rewardMultiplier: s.rewardMultiplier * (1 + gold),
    critChance: s.critChance,
    critDamage: s.critDamage,
    bossDamage: s.bossDamage,
    maxHp: s.maxHp,
    defense: s.defense,
    hpRegen: s.hpRegen,
    xpMultiplier: s.xpMultiplier,
    bugFind: s.bugFind * (1 + find),
    materialFind: s.materialFind * (1 + find),
    evade: s.evade,
    boostBonus: s.boostBonus,
  );
}

/// 방치 효율 = [base](run_config `offlineEfficiency`) × (1 + 방치 효율 연구) — 곤충학자 패스 골드 배율과도 곱(설계 §8).
double researchOfflineEfficiency(double base, ResearchEffects e) =>
    base * (1 + e.of(ResearchEffect.offline));

/// 연구소 **시간 단축**(설계 §3.7) — `seconds × (1 − v)` 올림, 최소 1초. v=0 이면 그대로(앱·서버 공용).
/// 스킨 단축 결과에 **곱**한다(스킨 먼저, 연구 나중).
int researchScaledSeconds(int seconds, ResearchEffects e, ResearchEffect kind) {
  final v = e.of(kind);
  if (v <= 0 || seconds <= 0) return seconds;
  final scaled = (seconds * (1 - v)).ceil();
  return scaled < 1 ? 1 : scaled;
}
