import 'dart:math' as math;

import 'package:core_models/core_models.dart';
import 'package:meta/meta.dart';

import 'character_stats.dart';
import 'enums.dart';

/// 확장 비용 반올림 눈금의 기본값 — `[상한, 눈금]`, 상한 0 은 그 이상 전부.
const kDefaultExpandCostRound = <List<int>>[
  [100, 5],
  [200, 10],
  [500, 25],
  [1000, 50],
  [0, 100],
];

/// `[[100,5],...]` → 눈금 목록. 형식이 깨지면 기본값(조용히 죽지 않게).
List<List<int>> _round(Object? json) {
  if (json is! List || json.isEmpty) return kDefaultExpandCostRound;
  final out = <List<int>>[];
  for (final e in json) {
    if (e is! List || e.length < 2) return kDefaultExpandCostRound;
    out.add([(e[0] as num).toInt(), (e[1] as num).toInt()]);
  }
  return out;
}

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
    this.disassembleJellyBase = 0,
    this.disassembleJellyPerPotential = 1.0,
    this.disassembleJellyMinPotential = 0,
    this.releaseMaterialByGrade = const {},
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
    this.incubateAdSkipRatio = 0.2,
    this.incubateJellyPerMinute = 0.5,
    this.instantJellyExponent = 1.0,
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
    this.breedingElementInherit = 0,
    this.variantWildChance = 0,
    this.gachaJellyCost = 0,
    this.gachaVariantChance = 0,
    this.gachaEpicPity = 0,
    this.gachaWeights = const {},
    this.gachaPotentialWeights = const {},
    this.variantBreedChance = 0,
    this.variantBreedParentChance = 0,
    this.breedingTemperamentInherit = 0,
    this.breedingTraitInherit = 0,
    this.breedingTraitNew = 0,
    this.breedingCooldownMult = 0,
    this.traitWeights = const {},
    this.traitAttackBonus = const {},
    this.traitHpBonus = const {},
    this.traitBattleScale = 0,
    this.storageSlotsMax = 100,
    this.expandCostGrowth = 1.12,
    this.expandCostRound = kDefaultExpandCostRound,
    this.storageExpandJelly = 50,
    this.storageExpandAmount = 10,
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

  /// 분해(젤리 환원) 보상 기본값 + 포텐셜 1당 젤리(§6, JSON).
  /// 보상 = [disassembleJellyBase] + [disassembleJellyPerPotential] × 포텐셜.
  final int disassembleJellyBase;
  final double disassembleJellyPerPotential;

  /// **이 포텐셜 이상**일 때만 젤리를 돌려준다(0 = 제한 없음, 구버전 동작).
  ///
  /// 왜 문턱이 필요한가: 곤충은 무한히 나오는데 분해에 상한이 없어서,
  /// 분해가 **젤리 수입의 절반**을 차지했다(하루 97개 = 전체 193개 중 50%,
  /// `tool/jelly_sim.dart` 실측). 프리미엄 재화가 파밍으로 무한히 나오면
  /// IAP 가 의미를 잃는다(§2.6).
  ///
  /// 문턱을 두면 **드문 개체를 분해할 때만** 젤리가 나와서, 수입이 줄면서도
  /// "좋은 걸 분해하는 순간"의 가치는 오히려 올라간다. 일반 개체 분해는
  /// [releaseMaterial] 로 재료를 돌려받으므로 여전히 할 이유가 있다.
  final int disassembleJellyMinPotential;

  /// 곤충 분해 시 돌려받는 젤리(포텐셜 [potential] 기준). 0 미만은 0으로 클램프.
  /// [disassembleJellyMinPotential] 미만이면 0.
  int disassembleJelly(int potential) {
    if (potential < disassembleJellyMinPotential) return 0;
    return (disassembleJellyBase + disassembleJellyPerPotential * potential)
        .round()
        .clamp(0, 1 << 30);
  }

  /// 등급 필터에 걸려 **자동 방생**된 곤충이 주는 재료 수(§2.1).
  ///
  /// ⚠️ 손으로 하는 분해(`disassembleJelly`)와 **일부러 재화를 다르게** 뒀다.
  /// 자동 방생은 방치 중에도 계속 돌아가므로 젤리(프리미엄 재화)를 주면
  /// 켜두기만 해도 젤리가 쌓여 IAP 가 무의미해진다. 그래서 일반 재료만 준다.
  final Map<Grade, int> releaseMaterialByGrade;

  /// 등급 [g] 곤충을 자동 방생했을 때 주는 재료 수(설정 없으면 0 = 보상 없음).
  int releaseMaterial(Grade g) => releaseMaterialByGrade[g] ?? 0;

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

  /// 보상형 광고 1회로 당기는 부화 시간의 **비율**(전체 부화시간 대비).
  ///
  /// 고정 분수로 하면 5분짜리 일반 알은 광고 한 번에 끝나고 80분짜리 전설만
  /// 의미가 남는다 — 비율이면 등급과 무관하게 체감이 같다. 횟수 제한은 없다.
  final double incubateAdSkipRatio;

  /// 부화 즉시완료 젤리 비용의 분당 계수(산란과 같은 방식 — 남은 시간 비례).
  final double incubateJellyPerMinute;

  /// 즉시완료 젤리 비용의 **시간 지수**. 1.0 = 분에 정비례(구버전 동작).
  ///
  /// 등급별 타이머를 가파르게 만들면(전설 산란 36시간) 정비례 비용은
  /// 수백~수천 젤리가 되어 아무도 안 쓴다 — 소비처가 아니라 장식이 된다.
  /// 1 미만이면 긴 대기일수록 **분당 단가가 싸져** 큰 건도 지를 만해진다.
  final double instantJellyExponent;

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

  // ── 짝짓기 상속(2026-08-15) ─────────────────────────────────────
  //
  // 예전엔 오행·기질이 **균등 재추첨**이라 짝짓기 자식이 야생 드롭과 구분되지
  // 않았다. 오행 상생 순서가 편성 전략의 핵심인데(§2.3) 원하는 속성을 노릴
  // 수단이 없어서, 짝짓기를 돌릴 이유 자체가 없었다.
  //
  // ⚠️ 0 으로 두면 **예전 동작(전부 랜덤)** 그대로다 — 구버전 JSON 호환.

  /// 부모에게서 오행을 물려받을 확률. 부모가 같은 오행이면 사실상 확정.
  final double breedingElementInherit;

  /// 이색(무지개·알비노) 확률 — 야생 드롭.
  final double variantWildChance;

  /// 곤충 알 뽑기(가챠, 2026-08-31) — 젤리 비용. 0 = 기능 꺼짐.
  ///
  /// §2.6 각주: 스탯을 직접 팔지 않는다는 원칙은 유지된다 — 뽑기는 게임이
  /// 이미 주는 것(드롭)을 **더 빨리** 얻는 시간 절약이고, PvP 는 서버 편성
  /// 검증·적응형 체력이 이미 완충한다.
  final int gachaJellyCost;

  /// 뽑기의 이색 확률 — 야생(1/300)보다 훨씬 높다(1/30). 뽑기의 값어치 축.
  final double gachaVariantChance;

  /// N회 뽑을 때마다 영웅+ 보장(천장). 0 = 천장 없음.
  final int gachaEpicPity;

  /// 등급 가중치(합이 1일 필요는 없다 — 비율로 쓴다).
  final Map<Grade, double> gachaWeights;

  /// 뽑기 **포텐셜** 가중치(성 → 비율). 여기가 뽑기의 존재 이유다.
  ///
  /// 야생 드롭 공식(`1 + floor(r*r*4)`)은 **5성이 수학적으로 불가능**하고
  /// 4성도 3.4% 뿐이다. 곤충 자체는 1분에 한 마리씩 나오므로 등급을 팔아 봐야
  /// 값이 안 나온다 — 야생에 없는 것(5성)을 파는 게 유일하게 성립하는 축이다.
  final Map<int, double> gachaPotentialWeights;

  /// 뽑기 포텐셜 롤. 표가 비어 있으면 0(호출부가 야생 공식으로 폴백).
  int rollGachaPotential(double roll) {
    if (gachaPotentialWeights.isEmpty) return 0;
    final total = gachaPotentialWeights.values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return 0;
    var pick = roll * total;
    for (final e in gachaPotentialWeights.entries) {
      pick -= e.value;
      if (pick <= 0) return e.key;
    }
    return gachaPotentialWeights.keys.last;
  }

  /// 이색 확률 — 짝짓기 자식(부모 중 이색 없음).
  /// 야생보다 높게 둔다 — 짝짓기가 "이색을 노리는 길"이어야 돌릴 이유가 생긴다.
  final double variantBreedChance;

  /// 이색 확률 — **부모 중 이색이 있을 때**. 이색을 얻으면 다음 목표가
  /// "이 계통을 잇는다"가 되도록 크게 높인다(Bugtopia 식 브리딩 복권).
  final double variantBreedParentChance;

  /// 부모에게서 기질을 물려받을 확률.
  final double breedingTemperamentInherit;

  /// 부모에게 혈통 특성이 있을 때 물려받을 확률.
  final double breedingTraitInherit;

  /// 부모가 **둘 다 특성이 없을 때** 새 특성이 열릴 확률(1세대 진입로).
  final double breedingTraitNew;

  /// 짝짓기 쿨다운 = 산란 시간 × 이 값. 0 이면 쿨다운 없음(구버전 동작).
  final double breedingCooldownMult;

  /// 새 특성 추첨 가중치(BugTrait.none 은 무시).
  final Map<BugTrait, double> traitWeights;

  /// 특성별 **펫 공격 기여** 가산(0.3 = +30%).
  final Map<BugTrait, double> traitAttackBonus;

  /// 특성별 **펫 체력 기여** 가산.
  final Map<BugTrait, double> traitHpBonus;

  /// 특성 보너스가 **PvP 전투 스탯**에 실리는 비율(0 = 전투에는 영향 없음).
  ///
  /// 방치 펫 기여와 전투를 **한 손잡이로 묶지 않는다** — 둘은 상한이 다르다.
  /// 전투 쪽은 부위 강화가 이미 최대 +200%(5성 만렙)라 같은 %가 다르게 느껴지고,
  /// 무엇보다 문제가 생겼을 때 **전투만 0으로 끌 수 있어야** 한다.
  ///
  /// ⚠️ 이 값을 0보다 크게 두면 특성이 트로피 랭킹에 영향을 준다. 곤충 롤이
  /// 아직 기기 권위라(§2.1) 세이브를 편집해 특성을 찍는 우회가 가능하다 —
  /// 다만 위조 가능한 다른 값(포텐셜 5 → 강화 상한 50레벨 = +200%)보다 작아
  /// **기존 구멍을 조금 넓히는 수준**이다. 서버 발급으로 전환할 때 함께 막는다.
  final double traitBattleScale;

  /// 전투용 특성 공격 보정(= 펫 계수 × [traitBattleScale]).
  double traitBattleAtk(BugTrait t) =>
      (traitAttackBonus[t] ?? 0) * traitBattleScale;

  /// 전투용 특성 체력 보정.
  double traitBattleHp(BugTrait t) => (traitHpBonus[t] ?? 0) * traitBattleScale;

  /// 채집함 확장(젤리) — 1회 확장으로 [storageExpandAmount] 칸을
  /// [storageExpandJelly] 젤리에 늘리고, [storageSlotsMax] 에서 멈춘다.
  ///
  /// 초기 칸 수는 세이브 기본값(`kDefaultStorageCapacity`)이다.
  /// **상한은 세이브 크기의 방어선이기도 하다** — 상한 100마리 ≈ 세이브 60KB.
  /// 이 값을 크게 올리면 업로드 트래픽이 그대로 따라 오른다.
  final int storageSlotsMax;

  /// 확장 1회마다 비용이 곱해지는 비율(1.0 = 정액).
  ///
  /// 정액이면 영구 소비처가 **총 390젤리에서 끝난다** — 다 사고 나면 젤리를
  /// 쓸 데가 없어서 팩이 안 팔린다(2026-08-18 분석). 계단식이면 끝이 없다.
  final double expandCostGrowth;

  /// 자릿수별 반올림 눈금 `[상한, 눈금]` 목록. 상한 0 = 그 이상 전부.
  ///
  /// 곡선(=[expandCostGrowth])은 그대로 두고 **표시되는 숫자만** 떨어지게
  /// 만든다. 50/56/63/70 은 읽는 순간 "얼마를 더 모아야 하지"가 계산되지
  /// 않는다 — 50/60/65/75 면 바로 읽힌다.
  final List<List<int>> expandCostRound;

  /// [done] 번 늘린 뒤의 다음 확장 비용. 눈금에 맞춰 **올린다**.
  ///
  /// ⚠️ 반올림이 아니라 올림이다. 반올림하면 37.6과 42.1이 둘 다 40이 되어
  /// **연달아 같은 가격**이 나온다(부화기 3→4칸과 4→5칸에서 실제로 그랬다).
  /// 올림은 곡선이 단조증가인 한 결과도 단조증가다.
  int _stepCost(int base, int done) {
    final raw = base * math.pow(expandCostGrowth, done);
    var step = 1;
    for (final tier in expandCostRound) {
      step = tier[1];
      if (tier[0] == 0 || raw < tier[0]) break;
    }
    return (raw / step).ceil() * step;
  }

  /// 부화기: 현재 [capacity] 에서 다음 칸을 늘리는 비용.
  int incubatorExpandCost(int capacity) =>
      _stepCost(incubatorExpandJelly, (capacity - 1).clamp(0, 999));

  /// 짝짓기: 현재 [capacity] 에서 다음 칸을 늘리는 비용.
  int breedingExpandCost(int capacity) =>
      _stepCost(breedingExpandJelly, (capacity - 1).clamp(0, 999));

  /// 채집함: 현재 [capacity] 에서 다음 [storageExpandAmount] 칸의 비용.
  ///
  /// 기준은 **기본 50칸**이다 — 거기서 몇 번 늘렸는지로 센다.
  int storageExpandCost(int capacity) => _stepCost(
    storageExpandJelly,
    ((capacity - 50) ~/ storageExpandAmount).clamp(0, 999),
  );
  final int storageExpandJelly;
  final int storageExpandAmount;

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

  /// 짝짓기에 쓴 **부모가 다시 짝짓기할 수 있게 되기까지**(초).
  ///
  /// 산란 시간의 배수로 잡는다 — 등급 스케일(일반 10분 ~ 전설 160분)이
  /// 그대로 따라와, 값 하나로 전 등급을 조절할 수 있다.
  ///
  /// 왜 필요한가: 부모는 짝짓기 중에도 잠기지 않는다(스냅샷 저장). 그래서
  /// **잘 뽑힌 한 쌍만 만들어 두면 같은 급 자식을 슬롯이 도는 속도만큼 계속
  /// 찍어낼 수 있었다.** 스탯이 무한히 오르는 건 아니지만(사이즈는 종 상한에서
  /// clamp, 포텐셜은 5성이 천장) **희소성이 사라진다** — 천장 개체가 소모품이 된다.
  /// 0 이면 제한 없음(구버전 동작).
  int breedingCooldown(Grade g) =>
      (breedingDuration(g) * breedingCooldownMult).round();

  /// 남은 시간 비례 브리딩 즉시완료 젤리 비용(최소 1).
  int breedingJelly(Duration remaining) =>
      _instantJelly(remaining, breedingJellyPerMinute);

  /// 남은 시간 비례 부화 즉시완료 젤리 비용(최소 1).
  int incubateJelly(Duration remaining) =>
      _instantJelly(remaining, incubateJellyPerMinute);

  /// `계수 x 남은분^지수`. 지수 1.0 이면 예전과 완전히 같다.
  int _instantJelly(Duration remaining, double coef) {
    if (remaining <= Duration.zero) return 0;
    final minutes = remaining.inSeconds / 60;
    final v = (coef * math.pow(minutes, instantJellyExponent)).ceil();
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
      disassembleJellyBase:
          (json['disassembleJellyBase'] as num?)?.toInt() ?? 0,
      disassembleJellyPerPotential:
          (json['disassembleJellyPerPotential'] as num?)?.toDouble() ?? 1.0,
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
      incubateAdSkipRatio:
          (json['incubateAdSkipRatio'] as num?)?.toDouble() ?? 0.2,
      incubateJellyPerMinute:
          (json['incubateJellyPerMinute'] as num?)?.toDouble() ?? 0.5,
      instantJellyExponent:
          (json['instantJellyExponent'] as num?)?.toDouble() ?? 1.0,
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
      breedingElementInherit:
          (json['breedingElementInherit'] as num?)?.toDouble() ?? 0,
      variantWildChance: (json['variantWildChance'] as num?)?.toDouble() ?? 0,
      gachaJellyCost: (json['gachaJellyCost'] as num?)?.toInt() ?? 0,
      gachaVariantChance: (json['gachaVariantChance'] as num?)?.toDouble() ?? 0,
      gachaEpicPity: (json['gachaEpicPity'] as num?)?.toInt() ?? 0,
      gachaPotentialWeights: {
        if (json['gachaPotentialWeights'] is Map)
          for (final e in (json['gachaPotentialWeights'] as Map).entries)
            if (int.tryParse(e.key as String) != null)
              int.parse(e.key as String): (e.value as num).toDouble(),
      },
      gachaWeights: {
        if (json['gachaWeights'] is Map)
          for (final e in (json['gachaWeights'] as Map).entries)
            // 모르는 등급 키는 조용히 버리지 않고 로딩에서 걸리게 두고 싶지만,
            // 구버전 호환이 우선이다 — data_test 가 키 유효성을 잡는다.
            if (Grade.fromKeyOrNull(e.key as String) != null)
              Grade.fromKeyOrNull(e.key as String)!: (e.value as num)
                  .toDouble(),
      },
      variantBreedChance: (json['variantBreedChance'] as num?)?.toDouble() ?? 0,
      variantBreedParentChance:
          (json['variantBreedParentChance'] as num?)?.toDouble() ?? 0,
      breedingTemperamentInherit:
          (json['breedingTemperamentInherit'] as num?)?.toDouble() ?? 0,
      breedingTraitInherit:
          (json['breedingTraitInherit'] as num?)?.toDouble() ?? 0,
      breedingTraitNew: (json['breedingTraitNew'] as num?)?.toDouble() ?? 0,
      breedingCooldownMult:
          (json['breedingCooldownMult'] as num?)?.toDouble() ?? 0,
      traitWeights: _traitMap(json['traitWeights']),
      traitAttackBonus: _traitMap(json['traitAttackBonus']),
      traitHpBonus: _traitMap(json['traitHpBonus']),
      traitBattleScale: (json['traitBattleScale'] as num?)?.toDouble() ?? 0,
      disassembleJellyMinPotential:
          (json['disassembleJellyMinPotential'] as num?)?.toInt() ?? 0,
      releaseMaterialByGrade: _gradeIntMap(json['releaseMaterialByGrade']),
      storageSlotsMax: (json['storageSlotsMax'] as num?)?.toInt() ?? 100,
      expandCostGrowth: (json['expandCostGrowth'] as num?)?.toDouble() ?? 1.12,
      expandCostRound: _round(json['expandCostRound']),
      storageExpandJelly: (json['storageExpandJelly'] as num?)?.toInt() ?? 50,
      storageExpandAmount: (json['storageExpandAmount'] as num?)?.toInt() ?? 10,
    );
  }

  /// `{"common": 3, ...}` → `{Grade.common: 3}`. 모르는 키는 버린다.
  static Map<Grade, int> _gradeIntMap(Object? raw) {
    if (raw is! Map) return const {};
    final out = <Grade, int>{};
    for (final e in raw.entries) {
      for (final g in Grade.values) {
        if (g.key != e.key) continue;
        final v = e.value;
        if (v is num) out[g] = v.toInt();
      }
    }
    return out;
  }

  /// `{"fierce": 0.3, ...}` → `{BugTrait.fierce: 0.3}`.
  /// 모르는 키는 [BugTrait.none] 으로 떨어지므로 조용히 버린다 — JSON 에
  /// 오타가 있어도 로딩이 통째로 실패하지 않아야 한다.
  static Map<BugTrait, double> _traitMap(Object? raw) {
    if (raw is! Map) return const {};
    final out = <BugTrait, double>{};
    for (final e in raw.entries) {
      final t = BugTrait.fromKey(e.key as String);
      if (t.isNone) continue;
      final v = e.value;
      if (v is num) out[t] = v.toDouble();
    }
    return out;
  }
}

/// 장착 펫이 캐릭터에 주는 최종 배율.
@immutable
class PetBonus {
  const PetBonus({
    required this.attackMult,
    required this.hpMult,
    this.passives = const {},
  });

  /// 등급·포텐셜·사이즈·강화·단계·레벨·특성에서 오는 배율(§2.7).
  final double attackMult;
  final double hpMult;

  /// **종 고유 패시브** 합산(§2.1). 능력치별 가산치.
  ///
  /// ⚠️ [attackMult]/[hpMult] 와 **적용 위치가 다르다.** 배율 둘은 적응형
  /// 몬스터 체력의 기준(§7)에 들어가는 '영구 전력'이고, 패시브는 기준 **밖**
  /// (순수 이득)이다 — 기준에 넣으면 어떤 종을 껴도 결과가 같아져서
  /// 종을 고르는 의미가 통째로 사라진다.
  final Map<UpgradeKind, double> passives;

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

  /// 혈통 특성(§2.5). 야생 개체는 [BugTrait.none].
  BugTrait trait,

  /// 종 고유 패시브(§2.1). 없으면 null.
  SpeciesPassive? passive,
});

/// 개체 + 종 → [PetStat]. **조립을 한 곳에 모은다.**
///
/// 예전엔 화면 6곳이 각자 이 레코드를 손으로 채웠다. 필드를 하나 늘릴 때마다
/// 어느 한 곳을 빠뜨리기 쉽고, 빠뜨리면 "보관함에서 본 보너스와 실제 전투력이
/// 다르다"로 나타난다(수치가 아니라 조립이 틀린 거라 추적이 어렵다).
PetStat petStatOf(
  IndividualBug bug,
  Species species,
  PetConfig cfg,
  DateTime now,
) => (
  grade: species.grade,
  sizeMult: bug.statMultiplier(species),
  potential: bug.potential,
  enhanceTotal: bug.enhancement.total,
  stage: effectiveStage(bug.stage, bug.stageSince, now, cfg),
  level: bug.level,
  trait: bug.trait,
  passive: species.passive,
);

/// 펫 1마리가 기여하는 공격/체력 배율(장착 효과 표시·합산 공용).
({double attack, double hp}) petContribution(PetStat p, PetConfig cfg) {
  final scale =
      (1 + p.potential * cfg.potentialScale) *
      p.sizeMult *
      (1 + p.enhanceTotal * cfg.enhanceScale) *
      (cfg.stageMult[p.stage] ?? 1.0) *
      (1 + (p.level - 1) * cfg.levelBonus);
  // 혈통 특성은 **곱이 아니라 축별 가산**이다 — 맹렬은 공격만, 강인은 체력만
  // 올려야 "무엇을 노리고 교배했는지"가 수치로 보인다. scale 에 곱해버리면
  // 두 축이 같이 올라 특성끼리 구분이 사라진다.
  final tAtk = 1 + (cfg.traitAttackBonus[p.trait] ?? 0);
  final tHp = 1 + (cfg.traitHpBonus[p.trait] ?? 0);
  return (
    attack: (cfg.gradeAttackPct[p.grade] ?? 0) * scale * tAtk,
    hp: (cfg.gradeHpPct[p.grade] ?? 0) * scale * tHp,
  );
}

/// 장착 펫들의 총 보너스 배율(공격/체력).
PetBonus computePetBonus(Iterable<PetStat> pets, PetConfig cfg) {
  var atk = 0.0;
  var hp = 0.0;
  // 종 패시브는 **합산**한다. 같은 종을 둘 끼면 두 배 — 특화 편성이 성립해야
  // "이 종을 모은다"가 전략이 된다.
  final passives = <UpgradeKind, double>{};
  for (final p in pets) {
    final c = petContribution(p, cfg);
    atk += c.attack;
    hp += c.hp;
    final sp = p.passive;
    if (sp == null) continue;
    final kind = UpgradeKind.fromKeyOrNull(sp.statKey);
    // 모르는 키는 조용히 버린다 — JSON 오타로 게임이 죽으면 안 된다.
    // (오타 자체는 `data_test` 의 패시브 키 유효성 검사가 잡는다.)
    if (kind == null) continue;
    passives[kind] = (passives[kind] ?? 0) + sp.value;
  }
  return PetBonus(attackMult: 1 + atk, hpMult: 1 + hp, passives: passives);
}

/// 종 패시브 가산치를 능력치에 실제로 얹는다.
///
/// **적응형 몬스터 체력(§7)의 기준 밖에서 호출해야 한다** — 장비·버프와 같은
/// 층이다. 기준 안에 넣으면 어떤 종을 껴도 몬스터가 같이 세져서 종을 고르는
/// 의미가 사라진다(= 종 패시브를 넣은 이유 자체가 무너진다).
///
/// 곱연산이 아니라 **가산**인 이유: 이미 업그레이드가 곱연산(valueGrowth)이라
/// 후반엔 +22% 를 곱해도 티가 안 난다. `bossDamage` 처럼 기본값이 1.0 인
/// 배율 스탯에 0.22 를 더하면 1.0 → 1.22 로 정확히 22% 가 된다.
CharacterStats applySpeciesPassives(
  CharacterStats s,
  Map<UpgradeKind, double> passives,
) {
  if (passives.isEmpty) return s;
  double v(UpgradeKind k) => passives[k] ?? 0;
  return CharacterStats(
    // 공격·체력은 **비율**로 얹는다(절대값을 더하면 초반엔 과하고 후반엔 무의미).
    attack: s.attack * (1 + v(UpgradeKind.attack)),
    maxHp: s.maxHp * (1 + v(UpgradeKind.maxHp)),
    attackSpeed: s.attackSpeed * (1 + v(UpgradeKind.attackSpeed)),
    moveSpeed: s.moveSpeed * (1 + v(UpgradeKind.moveSpeed)),
    // 아래는 원래 배율·확률·계수라 그대로 더한다.
    rewardMultiplier: s.rewardMultiplier + v(UpgradeKind.reward),
    critChance: (s.critChance + v(UpgradeKind.crit)).clamp(0.0, 0.95),
    critDamage: s.critDamage + v(UpgradeKind.critDamage),
    bossDamage: s.bossDamage + v(UpgradeKind.bossDamage),
    defense: s.defense + v(UpgradeKind.defense) * 100,
    hpRegen: s.hpRegen * (1 + v(UpgradeKind.regen)),
    xpMultiplier: s.xpMultiplier + v(UpgradeKind.xp),
    bugFind: s.bugFind + v(UpgradeKind.bugFind),
    materialFind: s.materialFind + v(UpgradeKind.materialFind),
    boostBonus: s.boostBonus + v(UpgradeKind.boost),
  );
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
