import 'dart:math' as math;

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';

import 'save_game.dart';

/// 순차 미션 규칙(2026-10-10) — 진행 중인 미션의 **실제 목표**와 **교체**.
///
/// 화면(진행도·수령 버튼)과 수령 처리가 같은 목표를 봐야 "다 채웠는데 안 받아진다"가 안 생긴다.

/// 아직 살 수 있는 강화 레벨 수(항목마다 `maxLevel − 지금 레벨`의 합). 상한 없는 항목이 있으면 사실상 무한.
int upgradeLevelsLeft(SaveGame s, RunConfig run) {
  var left = 0;
  for (final e in run.upgrades.entries) {
    final max = e.value.maxLevel;
    if (max == null) return 1 << 30;
    left += math.max(0, max - s.upgradeLevel(e.key));
  }
  return left;
}

/// 미션 [def] 의 지금 목표. 강화 미션은 **남은 강화 레벨**보다 크지 않다 — 다 키운 유저에게
/// 50레벨을 사라고 하면 영영 못 깬다(미션이 순서대로 돌아 사냥·제련까지 멈췄다, 2026-10-10 실기 지적).
/// 0 이면 깰 수 없는 미션이다([missionImpossible] — 무료 교체).
int missionGoal(SaveGame s, MissionDef def, RunConfig? run) {
  final goal = def.goalAt(s.missionClaimCount(def.id));
  if (def.type != MissionType.buyUpgrades || run == null) return goal;
  final reachable = s.missionProgressCount(def.id) + upgradeLevelsLeft(s, run);
  return math.min(goal, reachable);
}

/// 받을 수 있는지 — 목표가 0 인(깰 수 없는) 미션은 받지 못한다(아무것도 안 하고 보상을 받는 구멍).
bool missionClaimable(SaveGame s, MissionDef def, RunConfig? run) {
  final goal = missionGoal(s, def, run);
  return goal > 0 && s.missionProgressCount(def.id) >= goal;
}

/// 깰 수 없는 미션인지 — 교체가 무료다.
bool missionImpossible(SaveGame s, MissionDef def, RunConfig? run) =>
    missionGoal(s, def, run) <= 0;

/// 지금 미션을 바꾸는 젤리(깰 수 없으면 0).
int missionSwapCost(SaveGame s, MissionConfig cfg, RunConfig? run) {
  if (cfg.missions.isEmpty) return 0;
  final def = cfg.missions[cfg.activeIndex(s.missionClaims)];
  return missionImpossible(s, def, run) ? 0 : cfg.swapJelly;
}

/// 진행 중인 미션을 보상 없이 다음 미션으로 넘긴다(`missionClaims[kMissionSwapKey]` +1, 진행도 초기화).
///
/// 실패: `no_swap`(교체 꺼짐 · 미션 1개뿐) · `claimable`(다 채운 미션은 받는 게 먼저 — 실수로 보상을 버리지 않게) ·
/// `not_enough_jelly`.
({SaveGame? save, String? error, int jelly}) applyMissionSwap(
  SaveGame s,
  MissionConfig cfg,
  RunConfig? run,
) {
  if (cfg.missions.length < 2 || cfg.swapJelly <= 0) {
    return (save: null, error: 'no_swap', jelly: 0);
  }
  final def = cfg.missions[cfg.activeIndex(s.missionClaims)];
  if (missionClaimable(s, def, run)) {
    return (save: null, error: 'claimable', jelly: 0);
  }
  final jelly = missionSwapCost(s, cfg, run);
  final have = s.materialCount(MaterialKind.jelly);
  if (have < jelly)
    return (save: null, error: 'not_enough_jelly', jelly: jelly);
  final claims = Map<String, int>.from(s.missionClaims)
    ..update(kMissionSwapKey, (v) => v + 1, ifAbsent: () => 1);
  final mats = Map<MaterialKind, int>.from(s.materials);
  if (jelly > 0) mats[MaterialKind.jelly] = have - jelly;
  return (
    save: s.copyWith(
      materials: mats,
      missionClaims: claims,
      missionProgress: const {},
    ),
    error: null,
    jelly: jelly,
  );
}
