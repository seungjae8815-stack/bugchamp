import 'dart:math' as math;

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';

import 'save_game.dart';
import 'tier_progress.dart';

/// 캐릭터 스킬 진행 규칙(CLAUDE.md §2.8) — **조각 · 해금 · 수련 · 장착**.
///
/// 규칙이 여기 한 곳에만 있다. 솔로 루프는 기기 권위라 지금은 앱이 부르지만,
/// 뽑기처럼 서버 권위로 돌릴 때 서버가 **같은 함수**를 부른다 — 두 벌이 되면
/// "앱에선 됐는데 서버가 거부"가 조용히 생긴다.
///
/// 시간은 인자로 받고(§5 결정론), 무작위도 주입된 [math.Random] 으로만 쓴다.

/// 스킬 액션 결과. 실패면 [save] 가 null 이고 [error] 에 사유 키.
class SkillOp {
  const SkillOp.ok(SaveGame this.save, {this.extra = const {}}) : error = null;
  const SkillOp.fail(String this.error) : save = null, extra = const {};

  final SaveGame? save;
  final String? error;
  final Map<String, Object?> extra;

  bool get isOk => save != null;
}

/// 조각을 넣는다 — 해금·만능 환산까지 한 번에 정리한다.
///
/// - 미보유 스킬은 조각이 [SkillConfig.unlockShards] 개 모이면 **자동으로 레벨 1**.
///   "조각이 다 모였는데 버튼을 또 눌러야" 하면 모은 순간의 기쁨이 한 박자 늦는다.
/// - 만렙 스킬로 들어온 조각은 **만능 조각**으로 바뀐다(등급 환산값만큼) —
///   중복이 쓰레기가 되지 않게.
SaveGame grantSkillShards(
  SaveGame s,
  SkillConfig cfg,
  Map<String, int> shards,
) {
  if (shards.isEmpty) return s;
  final bag = Map<String, int>.from(s.skillShards);
  for (final e in shards.entries) {
    if (e.value <= 0 || cfg.byId(e.key) == null) continue;
    bag[e.key] = (bag[e.key] ?? 0) + e.value;
  }
  return _settle(s.copyWith(skillShards: bag), cfg);
}

/// 해금 조건을 채운 스킬을 올리고, 만렙 스킬의 조각을 만능으로 바꾼다.
SaveGame _settle(SaveGame s, SkillConfig cfg) {
  final bag = Map<String, int>.from(s.skillShards);
  final levels = Map<String, int>.from(s.skillLevels);
  var any = s.skillAnyShards;
  for (final def in cfg.skills) {
    var have = bag[def.id] ?? 0;
    final lv = levels[def.id] ?? 0;
    if (lv <= 0 && have >= cfg.unlockShards) {
      have -= cfg.unlockShards;
      levels[def.id] = 1;
    }
    // 수련 중인 스킬은 아직 만렙이 아니다 — 끝날 때 다시 정리한다.
    if ((levels[def.id] ?? 0) >= cfg.maxLevel && have > 0) {
      any += have * cfg.anyValueOf(def.grade);
      have = 0;
    }
    if (have > 0) {
      bag[def.id] = have;
    } else {
      bag.remove(def.id);
    }
  }
  return s.copyWith(skillShards: bag, skillLevels: levels, skillAnyShards: any);
}

/// 레벨 [SaveGame.skillLevels] → +1 수련에 드는 것. 모자란 조각은 만능으로 메운다.
({int shards, int any, bool enough}) skillTrainCost(
  SaveGame s,
  SkillConfig cfg,
  SkillDef def,
) {
  final lv = s.skillLevels[def.id] ?? 0;
  final need = cfg.shardsForLevel(def, lv);
  final have = s.skillShards[def.id] ?? 0;
  final fromOwn = math.min(need, have);
  final short = need - fromOwn;
  final any = short * cfg.anyValueOf(def.grade);
  return (shards: fromOwn, any: any, enough: any <= s.skillAnyShards);
}

/// 수련 시작 — 조각(부족분은 만능)을 쓰고 타이머를 건다. 한 번에 한 스킬.
SkillOp startSkillTraining(
  SaveGame s,
  SkillConfig cfg,
  String id,
  DateTime now,
) {
  final def = cfg.byId(id);
  if (def == null) return const SkillOp.fail('unknown_skill');
  final lv = s.skillLevels[id] ?? 0;
  if (lv <= 0) return const SkillOp.fail('not_owned');
  if (lv >= cfg.maxLevel) return const SkillOp.fail('max_level');
  if (s.skillTrainingId != null) return const SkillOp.fail('training_busy');
  final cost = skillTrainCost(s, cfg, def);
  if (!cost.enough) return const SkillOp.fail('not_enough_shards');

  final bag = Map<String, int>.from(s.skillShards);
  final left = (bag[id] ?? 0) - cost.shards;
  if (left > 0) {
    bag[id] = left;
  } else {
    bag.remove(id);
  }
  final endsAt = now.toUtc().add(cfg.trainDuration(def, lv));
  return SkillOp.ok(
    s.copyWith(
      skillShards: bag,
      skillAnyShards: s.skillAnyShards - cost.any,
      skillTrainingId: id,
      skillTrainingEndsAt: endsAt,
    ),
    extra: {'endsAt': endsAt.toIso8601String(), 'level': lv + 1},
  );
}

/// 수련 완료. [viaJelly] 면 남은 시간만큼 젤리로 즉시(돌파와 같은 구조),
/// 아니면 타이머가 끝난 뒤에만.
SkillOp completeSkillTraining(
  SaveGame s,
  SkillConfig cfg,
  DateTime now, {
  bool viaJelly = false,
}) {
  final id = s.skillTrainingId;
  final endsAt = s.skillTrainingEndsAt;
  if (id == null || endsAt == null) return const SkillOp.fail('no_training');
  final remaining = endsAt.difference(now.toUtc());
  var mats = s.materials;
  var jelly = 0;
  if (remaining > Duration.zero) {
    if (!viaJelly) return const SkillOp.fail('not_ready');
    jelly = cfg.trainJelly(remaining);
    final have = s.materialCount(MaterialKind.jelly);
    if (have < jelly) return const SkillOp.fail('not_enough_jelly');
    mats = Map<MaterialKind, int>.from(s.materials)
      ..[MaterialKind.jelly] = have - jelly;
  }
  final lv = ((s.skillLevels[id] ?? 0) + 1).clamp(1, cfg.maxLevel);
  final next = s.copyWith(
    materials: mats,
    skillLevels: {...s.skillLevels, id: lv},
    clearSkillTraining: true,
  );
  // 만렙에 닿았으면 남은 그 스킬 조각을 만능으로.
  return SkillOp.ok(_settle(next, cfg), extra: {'level': lv, 'jelly': jelly});
}

/// 장착/해제. 칸은 처음 가 본 최고 난이도로 열린다.
SkillOp toggleSkillEquip(SaveGame s, SkillConfig cfg, String id) {
  final next = [...s.equippedSkills];
  if (next.remove(id)) return SkillOp.ok(s.copyWith(equippedSkills: next));
  if (cfg.byId(id) == null) return const SkillOp.fail('unknown_skill');
  if ((s.skillLevels[id] ?? 0) <= 0) return const SkillOp.fail('not_owned');
  if (next.length >= cfg.slotsFor(s.topTier)) {
    return const SkillOp.fail('slots_full');
  }
  next.add(id);
  return SkillOp.ok(s.copyWith(equippedSkills: next));
}

/// 사냥터 보스 처치 조각. [firstKill] = 그 난이도에서 이 보스를 처음 잡았나.
({SaveGame save, Map<String, int> shards}) grantBossShards(
  SaveGame s,
  SkillConfig cfg,
  math.Random rng, {
  required int tier,
  required bool firstKill,
}) {
  final shards = cfg.rollBossShards(rng, tier: tier, firstKill: firstKill);
  return (save: grantSkillShards(s, cfg, shards), shards: shards);
}

/// 올라온 세이브의 스킬 필드를 규칙 안으로 접는다(서버 업로드 · 앱 로드 공용).
///
/// 레벨은 만렙 이하, 장착은 **보유한 스킬만 · 중복 없이 · 열린 칸 수까지**.
/// 조각 **증가량** 상한은 저장본과 비교해야 해서 서버 `mergeSave` 가 따로 본다.
SaveGame enforceSkillRules(SaveGame s, SkillConfig cfg) {
  final levels = <String, int>{
    for (final e in s.skillLevels.entries)
      if (e.value > 0) e.key: e.value.clamp(1, cfg.maxLevel),
  };
  final slots = cfg.slotsFor(s.topTier);
  final equipped = <String>[];
  for (final id in s.equippedSkills) {
    if (equipped.length >= slots) break;
    if ((levels[id] ?? 0) <= 0 || equipped.contains(id)) continue;
    equipped.add(id);
  }
  final bag = {
    for (final e in s.skillShards.entries)
      if (e.value > 0) e.key: e.value,
  };
  final changed =
      !_sameMap(levels, s.skillLevels) ||
      !_sameList(equipped, s.equippedSkills) ||
      !_sameMap(bag, s.skillShards) ||
      s.skillAnyShards < 0;
  if (!changed) return s;
  return s.copyWith(
    skillLevels: levels,
    equippedSkills: equipped,
    skillShards: bag,
    skillAnyShards: math.max(0, s.skillAnyShards),
  );
}

bool _sameMap(Map<String, int> a, Map<String, int> b) =>
    a.length == b.length && a.entries.every((e) => b[e.key] == e.value);

bool _sameList(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
