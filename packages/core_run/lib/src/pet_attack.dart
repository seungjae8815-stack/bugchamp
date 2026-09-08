import 'package:core_models/core_models.dart';

/// 분배 입력 — 곤충 1마리. [attack] 은 `petContribution(...).attack`,
/// [spd] 는 종 기본 SPD(`Species.baseStats.spd`).
typedef PetAttackerInput = ({
  String bugId,
  Element element,
  int spd,
  double attack,

  /// `petContribution(...).hp`. 체력도 공격과 **같은 방식으로 나눈다** —
  /// 곤충이 따로 맞으려면 자기 체력 몫이 있어야 한다.
  double hp,
});

/// 분배 결과 — 곤충 1마리가 [interval] 초마다 `오늘의 한 대 x damageMult` 를 넣는다.
typedef PetAttacker = ({
  String bugId,
  Element element,
  double damageMult,
  double interval,

  /// 팀 최대체력 중 이 곤충의 몫(0~1). 플레이어 몫은 `playerHpMult` 다.
  double hpMult,
});

/// 오늘의 DPS 를 플레이어와 곤충들에게 **나눈다**(늘리지 않는다).
///
/// 펫의 공격력 배율(`computePetBonus().attackMult` = 1 + 기여합)을 지분으로
/// 재해석한 것이다. petShare = 합/(1+합), playerMult = 1 - petShare,
/// 곤충 i 의 damageMult = petShare x (a_i/합) x (interval_i/playerInterval).
///
/// 마지막 항이 **간격 보정**이다. 이게 없으면 빠른 종이 곧 더 센 종이 되어
/// 종 선택이 다시 하나로 수렴한다.
///
/// 총량이 중립이라 **§7 적응형 체력 기준을 안 건드린다**. 이 성질이 깨지면
/// `habitatMaxHp` 를 처음부터 다시 잡아야 한다.
({double playerMult, double playerHpMult, List<PetAttacker> pets}) splitAttack({
  required List<PetAttackerInput> pets,
  required double playerInterval,
  required double spdReference,
  required double intervalMin,
  required double intervalMax,
}) {
  var sum = 0.0;
  var sumHp = 0.0;
  for (final p in pets) {
    if (p.attack > 0) sum += p.attack;
    if (p.hp > 0) sumHp += p.hp;
  }
  if (sum <= 0) {
    return (playerMult: 1.0, playerHpMult: 1.0, pets: const []);
  }

  final petShare = sum / (1 + sum);
  // 체력 몫도 같은 꼴이다. 공격 지분과 **따로** 계산한다 — 맹렬(공격만)·
  // 강인(체력만) 특성이 있어서 둘이 같지 않다.
  final petHpShare = sumHp <= 0 ? 0.0 : sumHp / (1 + sumHp);
  final out = <PetAttacker>[];
  for (final p in pets) {
    // 기여가 0 인 곤충은 뺀다 — 남겨 두면 0 데미지 팝업이 뜬다.
    if (p.attack <= 0) continue;
    final spd = p.spd <= 0 ? spdReference : p.spd.toDouble();
    final interval = (playerInterval * spdReference / spd).clamp(
      intervalMin,
      intervalMax,
    );
    out.add((
      bugId: p.bugId,
      element: p.element,
      damageMult: petShare * (p.attack / sum) * (interval / playerInterval),
      interval: interval,
      hpMult: sumHp <= 0 ? 0.0 : petHpShare * (p.hp / sumHp),
    ));
  }
  return (playerMult: 1 - petShare, playerHpMult: 1 - petHpShare, pets: out);
}

/// 곤충 속성이 몬스터를 克하면 [mult], 아니면 1.0.
///
/// **1.0 미만을 돌려주지 않는다.** 어긋났다고 깎으면 "곤충이 약해졌다"가
/// 되고, 편성을 못 맞춘 유저를 벌하는 시스템이 된다.
double petRestrainMult(Element pet, Element? monster, double mult) =>
    monster != null && pet.restrains(monster) ? mult : 1.0;
