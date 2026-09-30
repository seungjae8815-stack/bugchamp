import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';

import '../../data/game_data.dart';

/// 개체 → 전투 유닛(부위 강화·혈통 특성·이색). 서버 `GameActions._buildTeam` 과 **같은 값**이어야
/// 승패가 안 갈린다.
BattleBug battleBugFor(IndividualBug bug, GameData data, String locale) {
  final enh = data.enhanceConfig;
  final pet = data.petConfig;
  double per(BugPart p, double d) => enh?.spec(p).effectPerLevel ?? d;
  return buildBattleBug(
    bug: bug,
    species: data.species(bug.speciesId),
    locale: locale,
    hornJawPerLevel: per(BugPart.hornJaw, 0.04),
    cuticlePerLevel: per(BugPart.cuticle, 0.04),
    wingPerLevel: per(BugPart.wing, 0.03),
    buildPerLevel: per(BugPart.build, 0.05),
    // 혈통 특성(§2.5)은 전투에도 실린다. 배율은 `traitBattleScale` —
    // 서버(`GameActions._buildTeam`)와 **같은 값**이어야 승패가 안 갈린다.
    traitAtkBonus: pet?.traitBattleAtk(bug.trait) ?? 0,
    variantAtkBonus: pet?.variantBattleAtk(bug.variant) ?? 0,
    variantHpBonus: pet?.variantBattleHp(bug.variant) ?? 0,
    traitHpBonus: pet?.traitBattleHp(bug.trait) ?? 0,
  );
}

/// 개체 → 결투 유닛(결투·왕충 선발대회 공용). 서버 `validateDuelTeam` 과 **같은 계산**이다 —
/// 훈련소(최대 단계로 자름)·수련 레벨·날개 회피까지.
DuelBug duelBugFor(
  IndividualBug bug,
  GameData data,
  SaveGame save,
  String locale,
) {
  final sp = data.species(bug.speciesId);
  final t = trainingBonusOf(
    save,
    bug,
    sp,
    (data.battleConfig ?? const BattleConfig()).training,
    levelCap: data.petConfig?.levelCap(bug.breakthroughTier),
  );
  return DuelBug.fromBattleBug(
    battleBugFor(bug, data, locale),
    speciesId: bug.speciesId,
    sizeMm: bug.sizeMm,
    specialty: sp.specialty,
  ).withTraining(
    atkMult: t.atkMult,
    defMult: t.defMult,
    hpMult: t.hpMult,
    // 날개 강화 회피(+0.3%p/Lv, 서버와 같은 계산) + 훈련소 회피.
    evade:
        t.evade +
        bug.enhancement.levelOf(BugPart.wing) *
            (data.enhanceConfig?.spec(BugPart.wing).evadePerLevel ?? 0),
    crit: t.crit,
    recovery: t.recovery,
  );
}
