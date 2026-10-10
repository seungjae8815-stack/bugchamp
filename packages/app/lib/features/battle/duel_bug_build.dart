import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';

import '../../data/game_data.dart';

/// 훈련 v2 보너스(배분을 예산·칸 상한으로 자름 · 수련 레벨 보너스 포함). 서버 `validateTeam` 과 같은 계산.
({
  double atkMult,
  double defMult,
  double hpMult,
  double spdMult,
  double evade,
  double crit,
  double recovery,
  double massMult,
  double pushMult,
  double tech,
  int grit,
})
_trainOf(IndividualBug bug, GameData data, SaveGame save) => trainingBonusOf(
  save,
  bug,
  data.species(bug.speciesId),
  (data.battleConfig ?? const BattleConfig()).training,
  levelCap: data.petConfig?.levelCap(bug.breakthroughTier),
  enhance: data.enhanceConfig,
);

/// 개체 → 전투 유닛(훈련 v2 배분·혈통 특성·이색). 서버 `GameActions.validateTeam` 과 **같은 값**이어야
/// 승패가 안 갈린다. 부위 강화는 훈련 포인트로 이전돼 더 이상 따로 붙지 않는다.
BattleBug battleBugFor(
  IndividualBug bug,
  GameData data,
  SaveGame save,
  String locale,
) {
  final pet = data.petConfig;
  final t = _trainOf(bug, data, save);
  return buildBattleBug(
    bug: bug,
    species: data.species(bug.speciesId),
    locale: locale,
    trainAtkMult: t.atkMult,
    trainDefMult: t.defMult,
    trainHpMult: t.hpMult,
    trainSpdMult: t.spdMult,
    // 혈통 특성(§2.5)은 전투에도 실린다. 배율은 `traitBattleScale` —
    // 서버(`GameActions.validateTeam`)와 **같은 값**이어야 승패가 안 갈린다.
    traitAtkBonus: pet?.traitBattleAtk(bug.trait) ?? 0,
    variantAtkBonus: pet?.variantBattleAtk(bug.variant) ?? 0,
    variantHpBonus: pet?.variantBattleHp(bug.variant) ?? 0,
    traitHpBonus: pet?.traitBattleHp(bug.trait) ?? 0,
  );
}

/// 결투 수치(`battle.json → duel`) — 재생·실전 전투력이 같은 값을 본다. 설정 객체가 같으면 다시 만들지 않는다.
DuelParams duelParamsOf(GameData? data) {
  final cfg = data?.battleConfig;
  if (cfg == null) return const DuelParams();
  if (!identical(cfg, _paramsCfg) || _params == null) {
    _paramsCfg = cfg;
    _params = DuelParams.fromJson(cfg.duelJson);
  }
  return _params!;
}

BattleConfig? _paramsCfg;
DuelParams? _params;

/// 곤충 한 마리 **실전 전투력**(서버 `_duelPower` 와 같은 [DuelBug.powerIn], 2026-10-10).
double duelPowerOf(DuelBug d, GameData? data) => d.powerIn(duelParamsOf(data));

/// 개체 → 결투 유닛(결투·왕충 선발대회 공용). 서버 `validateDuelTeam` 과 **같은 계산**이다 —
/// 훈련 v2 배분(예산·칸 상한으로 자름)·수련 레벨·체급·밀어내기 힘·주특기 기술·근성까지.
DuelBug duelBugFor(
  IndividualBug bug,
  GameData data,
  SaveGame save,
  String locale,
) {
  final sp = data.species(bug.speciesId);
  final t = _trainOf(bug, data, save);
  return DuelBug.fromBattleBug(
    battleBugFor(bug, data, save, locale),
    speciesId: bug.speciesId,
    sizeMm: bug.sizeMm,
    specialty: sp.specialty,
    // 크기는 결투에서 무게로만(2026-10-08 사장님 확정) — 엔진이 스탯에 구워진 사이즈 배율을 덜어낸다.
    // 서버 `validateDuelTeam` 과 같은 값이어야 재생·체험이 서버 판과 같다.
    sizeStatMult: bug.statMultiplier(sp),
  ).withTraining(
    evade: t.evade,
    crit: t.crit,
    recovery: t.recovery,
    massMult: t.massMult,
    pushMult: t.pushMult,
    tech: t.tech,
    grit: t.grit,
  );
}
