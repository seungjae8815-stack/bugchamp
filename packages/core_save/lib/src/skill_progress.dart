import 'dart:math' as math;

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';

import 'save_game.dart';
import 'tier_progress.dart';

/// 캐릭터 스킬 진행 규칙(CLAUDE.md §2.8) — **조각 · 해금 · 수련 · 등급 승급 · 장착**.
///
/// 규칙이 여기 한 곳에만 있다. 솔로 루프는 기기 권위라 지금은 앱이 부르지만,
/// 뽑기처럼 서버 권위로 돌릴 때 서버가 **같은 함수**를 부른다 — 두 벌이 되면
/// "앱에선 됐는데 서버가 거부"가 조용히 생긴다.
///
/// 시간은 인자로 받고(§5 결정론), 무작위도 주입된 [math.Random] 으로만 쓴다.

/// 등급 승급 재료로 **그 등급 만능 조각**을 가리키는 소스 키.
const String kGradeShardSource = '*';

/// 스킬 액션 결과. 실패면 [save] 가 null 이고 [error] 에 사유 키.
class SkillOp {
  const SkillOp.ok(SaveGame this.save, {this.extra = const {}}) : error = null;
  const SkillOp.fail(String this.error) : save = null, extra = const {};

  final SaveGame? save;
  final String? error;
  final Map<String, Object?> extra;

  bool get isOk => save != null;
}

/// 조각을 넣는다 — 해금까지 한 번에 정리한다.
///
/// 미보유 스킬은 조각이 [SkillConfig.unlockShards] 개 모이면 **자동으로 레벨 1**.
/// "조각이 다 모였는데 버튼을 또 눌러야" 하면 모은 순간의 기쁨이 한 박자 늦는다.
/// 만렙 스킬 조각은 그대로 쌓인다 — 등급 승급 재료다.
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
  return _unlockReady(s.copyWith(skillShards: bag), cfg);
}

SaveGame _unlockReady(SaveGame s, SkillConfig cfg) {
  final bag = Map<String, int>.from(s.skillShards);
  final levels = Map<String, int>.from(s.skillLevels);
  var changed = false;
  for (final def in cfg.skills) {
    final have = bag[def.id] ?? 0;
    if ((levels[def.id] ?? 0) > 0 || have < cfg.unlockShards) continue;
    levels[def.id] = 1;
    final left = have - cfg.unlockShards;
    if (left > 0) {
      bag[def.id] = left;
    } else {
      bag.remove(def.id);
    }
    changed = true;
  }
  if (!changed) return s;
  return s.copyWith(skillShards: bag, skillLevels: levels);
}

/// 레벨 +1 수련에 드는 것. 모자란 조각은 **그 등급 만능 조각**으로 1:1 메운다.
({int shards, int gradeShards, bool enough}) skillTrainCost(
  SaveGame s,
  SkillConfig cfg,
  SkillDef def,
) {
  final lv = s.skillLevels[def.id] ?? 0;
  final need = cfg.shardsForLevel(def, lv);
  final fromOwn = math.min(need, s.skillShards[def.id] ?? 0);
  final short = need - fromOwn;
  return (
    shards: fromOwn,
    gradeShards: short,
    enough: short <= s.gradeShards(def.grade),
  );
}

/// 수련 시작 — 조각(부족분은 등급 만능)을 쓰고 타이머를 건다. 한 번에 한 스킬.
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
      skillGradeShards: _addGrade(
        s.skillGradeShards,
        def.grade,
        -cost.gradeShards,
      ),
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
  return SkillOp.ok(
    s.copyWith(
      materials: mats,
      skillLevels: {...s.skillLevels, id: lv},
      clearSkillTraining: true,
    ),
    extra: {'level': lv, 'jelly': jelly},
  );
}

/// [from] 등급에서 승급 재료로 쓸 수 있는 조각 수 — 소스별.
///
/// 소스 = 그 등급 스킬 id, 또는 [kGradeShardSource](그 등급 만능 조각).
/// ⚠️ 수련에 쓸 조각까지 태우지 않도록 **어느 소스를 쓸지는 호출부(유저)가 고른다.**
Map<String, int> gradeUpSources(SaveGame s, SkillConfig cfg, Grade from) => {
  for (final def in cfg.skills)
    if (def.grade == from && (s.skillShards[def.id] ?? 0) > 0)
      def.id: s.skillShards[def.id]!,
  if (s.gradeShards(from) > 0) kGradeShardSource: s.gradeShards(from),
};

/// 등급 승급 — [from] 등급 조각 `gradeUpRatio × times` 개를 [sources] 순서대로
/// 꺼내 한 단계 위 등급 만능 조각 [times] 개를 만든다.
SkillOp gradeUpShards(
  SaveGame s,
  SkillConfig cfg, {
  required Grade from,
  required List<String> sources,
  required int times,
}) {
  final to = SkillConfig.nextGrade(from);
  if (to == null) return const SkillOp.fail('max_grade');
  if (times <= 0 || cfg.gradeUpRatio <= 0) {
    return const SkillOp.fail('bad_amount');
  }
  final avail = gradeUpSources(s, cfg, from);
  var need = cfg.gradeUpRatio * times;
  final bag = Map<String, int>.from(s.skillShards);
  var grades = Map<String, int>.from(s.skillGradeShards);
  for (final src in sources.toSet()) {
    if (need <= 0) break;
    final take = math.min(need, avail[src] ?? 0);
    if (take <= 0) continue;
    need -= take;
    if (src == kGradeShardSource) {
      grades = _addGrade(grades, from, -take);
    } else {
      final left = (bag[src] ?? 0) - take;
      if (left > 0) {
        bag[src] = left;
      } else {
        bag.remove(src);
      }
    }
  }
  if (need > 0) return const SkillOp.fail('not_enough_shards');
  return SkillOp.ok(
    s.copyWith(
      skillShards: bag,
      skillGradeShards: _addGrade(grades, to, times),
    ),
    extra: {'grade': to.key, 'made': times},
  );
}

Map<String, int> _addGrade(Map<String, int> m, Grade g, int delta) {
  if (delta == 0) return m;
  final out = Map<String, int>.from(m);
  final v = (out[g.key] ?? 0) + delta;
  if (v > 0) {
    out[g.key] = v;
  } else {
    out.remove(g.key);
  }
  return out;
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

/// 정예 처치 조각(확률).
({SaveGame save, Map<String, int> shards}) grantEliteShards(
  SaveGame s,
  SkillConfig cfg,
  math.Random rng, {
  required int tier,
}) {
  final shards = cfg.rollEliteShards(rng, tier: tier);
  return (save: grantSkillShards(s, cfg, shards), shards: shards);
}

/// 세이브의 스킬 필드를 규칙 안으로 접는다(서버 업로드 · 앱 로드 공용).
///
/// 레벨은 만렙 이하, 장착은 **보유한 스킬만 · 중복 없이 · 열린 칸 수까지**, 조각은 양수만.
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
  Map<String, int> positive(Map<String, int> m) => {
    for (final e in m.entries)
      if (e.value > 0) e.key: e.value,
  };
  final bag = positive(s.skillShards);
  final grades = positive(s.skillGradeShards);
  final changed =
      !_sameMap(levels, s.skillLevels) ||
      !_sameList(equipped, s.equippedSkills) ||
      !_sameMap(bag, s.skillShards) ||
      !_sameMap(grades, s.skillGradeShards);
  if (!changed) return s;
  return s.copyWith(
    skillLevels: levels,
    equippedSkills: equipped,
    skillShards: bag,
    skillGradeShards: grades,
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
