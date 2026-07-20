import 'package:core_models/core_models.dart';

import 'core_battle_base.dart';

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
/// 부위 강화 계수는 `enhance.json`(core_run) 에 있지만, core_battle 은
/// core_run 을 모르므로(형제 관계) **호출부가 값을 넘긴다**.
/// 기본값은 §2.2 표와 같다.
BattleBug buildBattleBug({
  required IndividualBug bug,
  required Species species,
  required String locale,
  double hornJawPerLevel = 0.04,
  double cuticlePerLevel = 0.04,
  double wingPerLevel = 0.03,
  double buildPerLevel = 0.05,
}) {
  final sm = bug.statMultiplier(species);
  final e = bug.enhancement;
  return BattleBug(
    id: bug.id,
    name: species.name.resolve(locale),
    element: bug.element,
    temperament: bug.temperament,
    preferredStance: preferredStanceOf(species.specialty),
    maxHp:
        species.baseStats.hp *
        sm *
        (1 + e.levelOf(BugPart.build) * buildPerLevel),
    atk:
        species.baseStats.atk *
        sm *
        (1 + e.levelOf(BugPart.hornJaw) * hornJawPerLevel),
    def:
        species.baseStats.def *
        sm *
        (1 + e.levelOf(BugPart.cuticle) * cuticlePerLevel),
    spd:
        species.baseStats.spd *
        sm *
        (1 + e.levelOf(BugPart.wing) * wingPerLevel),
  );
}

/// 내 팀(A)에서 이번 전투 중 KO 된 파이터 id들.
/// 1:1 순차전이라 `aDown` 이벤트 수 = 앞에서부터 쓰러진 곤충 수.
///
/// 부상 처리에 쓰이므로 **앱과 서버가 같은 판정**을 해야 한다.
List<String> koedTeamAIds(List<BattleBug> teamA, List<BattleEvent> events) {
  final n = events.where((e) => e.aDown).length;
  return [for (var i = 0; i < n && i < teamA.length; i++) teamA[i].id];
}
