import 'character_stats.dart';
import 'pet_config.dart' show defenseScaled;
import 'research_config.dart';

/// 연구소 **사냥 분야**를 사냥 능력치에 얹는다(설계 §3.8 — 앱 `huntStatsUncapped`·시뮬이 같은 함수).
///
/// 전부 **곱**(1 + v)이다 — 종 패시브(`applySpeciesPassives`)와 같은 해석(§2.1 곱 원칙):
/// - 공격·골드·곤충/재료 찾기·보스 피해 = × (1 + v).
/// - 체력·방어(단단한 껍질) = 체력 × (1 + v) · 방어는 맷집 `(100 + 방어) × (1 + v)`([defenseScaled]) —
///   받는 피해가 정확히 ÷ (1 + v). 회복은 최대 체력 비율이라 체력 배율을 함께 탄다.
///
/// ⚠️ **적응형 몬스터 기준(`permanentStatsOf`) 밖**에서 부른다 — 기준에 넣으면 연구할수록 몬스터도
/// 같이 세져 연구한 의미가 사라진다(장비·종 패시브와 같은 층).
/// 여기서는 처음 6종(공격·체력방어·찾기·골드·보스·방치)만 다룬다 — 방치 효율은 [researchOfflineEfficiency].
CharacterStats applyResearchStats(CharacterStats s, ResearchEffects e) {
  double v(ResearchEffect k) => e.of(k);
  final atk = v(ResearchEffect.huntAtk);
  final hpDef = v(ResearchEffect.huntHpDef);
  final gold = v(ResearchEffect.gold);
  final find = v(ResearchEffect.find);
  final boss = v(ResearchEffect.bossDmg);
  if (atk == 0 && hpDef == 0 && gold == 0 && find == 0 && boss == 0) return s;
  return CharacterStats(
    attack: s.attack * (1 + atk),
    attackSpeed: s.attackSpeed,
    rewardMultiplier: s.rewardMultiplier * (1 + gold),
    critChance: s.critChance,
    critDamage: s.critDamage,
    bossDamage: s.bossDamage * (1 + boss),
    maxHp: s.maxHp * (1 + hpDef),
    defense: defenseScaled(s.defense, hpDef),
    hpRegen: s.hpRegen * (1 + hpDef),
    xpMultiplier: s.xpMultiplier,
    bugFind: s.bugFind * (1 + find),
    materialFind: s.materialFind * (1 + find),
    evade: s.evade,
    boostBonus: s.boostBonus,
  );
}

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
