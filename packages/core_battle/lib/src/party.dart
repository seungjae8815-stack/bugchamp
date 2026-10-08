import 'package:core_models/core_models.dart';

import 'core_battle_base.dart';
import 'duel/duel_bug.dart';

/// 주특기 → 선호 스탠스 매핑 (§2.3).
Stance preferredStanceOf(Specialty s) => switch (s) {
  Specialty.strike => Stance.attack,
  Specialty.grip => Stance.defend,
  Specialty.toss => Stance.heal,
};

/// 보유 개체([bug])를 전투 유닛으로 변환한다.
///
/// **앱과 서버가 반드시 같은 결과를 내야 한다.** 한쪽만 달라지면
/// "클라에선 이겼는데 서버는 졌다고 함"이 발생하므로 이 함수 하나로 통일한다.
///
/// 훈련 v2(2026-10-08, docs/design_training_v2.md): 부위 강화는 **훈련 포인트로 흡수**됐다 — 이 함수는
/// 곤충의 `enhancement` 를 더 이상 읽지 않는다(이전된 곤충이 두 번 세지지 않게). 대신 호출부가 훈련 배분에서
/// 계산한 배율([trainAtkMult]·[trainDefMult]·[trainHpMult]·[trainSpdMult], core_save `trainingBonusOf`)을 넘긴다.
/// core_battle 은 core_run·core_save 를 모르므로(형제 관계) 값으로 받는다. 기본 1 = 훈련 없음.
/// [traitAtkBonus] / [traitHpBonus] 는 **혈통 특성**(§2.5)의 전투 보정이다
/// (0.35 = +35%). 계수는 `pets.json → traitAttackBonus/traitHpBonus` ×
/// `traitBattleScale` 이며, core_battle 은 core_run 을 모르므로 호출부가 넘긴다.
/// 0 이면 특성이 전투에 영향을 주지 않는다(구버전 동작).
/// [variantAtkBonus] / [variantHpBonus] 는 **이색**(§2.1)의 전투 보정이다.
/// 계수는 `pets.json → variantAttackBonus/variantHpBonus × variantBattleScale`.
/// ⚠️ 이색은 위조를 막을 수 없으므로(기기 권위 롤) 문제가 생기면
/// `variantBattleScale` 을 0 으로 내려 **전투만** 끌 수 있어야 한다.
BattleBug buildBattleBug({
  required IndividualBug bug,
  required Species species,
  required String locale,
  double trainAtkMult = 1,
  double trainDefMult = 1,
  double trainHpMult = 1,
  double trainSpdMult = 1,
  double traitAtkBonus = 0,
  double traitHpBonus = 0,
  double variantAtkBonus = 0,
  double variantHpBonus = 0,
}) {
  final sm = bug.statMultiplier(species);
  // 특성은 **훈련 배율과 곱해진다** — 훈련이 이미 크게 올려서
  // 덧셈으로 붙이면 후반에 체감이 사라진다. 짝짓기 세대를 쌓은 보람이
  // 후반에도 남아야 계통 육성이 죽은 시스템이 되지 않는다.
  return BattleBug(
    id: bug.id,
    name: species.name.resolve(locale),
    element: bug.element,
    temperament: bug.temperament,
    preferredStance: preferredStanceOf(species.specialty),
    maxHp:
        species.baseStats.hp *
        sm *
        trainHpMult *
        (1 + traitHpBonus) *
        (1 + variantHpBonus),
    atk:
        species.baseStats.atk *
        sm *
        trainAtkMult *
        (1 + traitAtkBonus) *
        (1 + variantAtkBonus),
    def: species.baseStats.def * sm * trainDefMult,
    spd: species.baseStats.spd * sm * trainSpdMult,
  );
}

/// 보유 개체를 **결투(곤충 배틀 스타디움)** 유닛으로 — 스탯은 [buildBattleBug] 와 같은 계산에
/// 사이즈·주특기를 더한다. 앱·서버가 이 함수 하나로 만든다(§4: 두 벌 금지).
DuelBug buildDuelBug({
  required IndividualBug bug,
  required Species species,
  required String locale,
  double trainAtkMult = 1,
  double trainDefMult = 1,
  double trainHpMult = 1,
  double trainSpdMult = 1,
  double traitAtkBonus = 0,
  double traitHpBonus = 0,
  double variantAtkBonus = 0,
  double variantHpBonus = 0,
}) => DuelBug.fromBattleBug(
  buildBattleBug(
    bug: bug,
    species: species,
    locale: locale,
    trainAtkMult: trainAtkMult,
    trainDefMult: trainDefMult,
    trainHpMult: trainHpMult,
    trainSpdMult: trainSpdMult,
    traitAtkBonus: traitAtkBonus,
    traitHpBonus: traitHpBonus,
    variantAtkBonus: variantAtkBonus,
    variantHpBonus: variantHpBonus,
  ),
  speciesId: species.id,
  sizeMm: bug.sizeMm,
  specialty: species.specialty,
);

/// 내 팀(A)에서 이번 전투 중 KO 된 파이터 id들.
/// 1:1 순차전이라 `aDown` 이벤트 수 = 앞에서부터 쓰러진 곤충 수.
///
/// 부상 처리에 쓰이므로 **앱과 서버가 같은 판정**을 해야 한다.
List<String> koedTeamAIds(List<BattleBug> teamA, List<BattleEvent> events) {
  final n = events.where((e) => e.aDown).length;
  return [for (var i = 0; i < n && i < teamA.length; i++) teamA[i].id];
}

/// 이벤트(웨이브 방어전) 규격으로 변환한다 — **개체 스탯을 쓰지 않는다.**
///
/// 반영하는 것: 종의 주특기(→선호 스탠스)·오행·기질. 스탯은 호출부가 넘긴
/// 정규화 값([hp]/[atk]/[def]/[spd])을 그대로 쓴다.
///
/// 왜 버리는가: 수련·돌파·부위 강화·포텐셜·사이즈는 **전부 위조 가능한 축**
/// (곤충 롤이 기기 권위 §2.1)이자 **오래 한 사람만 유리한 축**이다. 순위가
/// 실물 상품으로 이어지는 모드에서는 둘 다 곤란하다 — 버리면 한 번에 풀린다.
///
/// `buildBattleBug` 와 마찬가지로 **앱과 서버가 같은 함수**를 써야 한다.
BattleBug buildEventBug({
  required IndividualBug bug,
  required Species species,
  required String locale,
  required double hp,
  required double atk,
  required double def,
  required double spd,
}) => BattleBug(
  id: bug.id,
  name: species.name.resolve(locale),
  element: bug.element,
  temperament: bug.temperament,
  preferredStance: preferredStanceOf(species.specialty),
  maxHp: hp,
  atk: atk,
  def: def,
  spd: spd,
);
