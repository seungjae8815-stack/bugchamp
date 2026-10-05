import 'dart:math' as math;

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';

import 'save_game.dart';
import 'skill_progress.dart';

/// 심연 진행 규칙 — **앱과 서버가 같은 함수**를 쓴다(§4, docs/design_abyss.md).

/// 이번 주 id — 결투 시즌과 같은 경계(일요일 24시 KST)라 한 화면에서 "매주 일요일 자정 정산"으로 말한다.
String abyssWeekId(DateTime now, BattleConfig battle) =>
    seasonIdOf(seasonStartAt(now, battle), battle);

/// 심연에서 고정되는 난이도(극한 = 표의 마지막).
int abyssTier(RunConfig run) =>
    run.zoneTiers.isEmpty ? 3 : run.zoneTiers.length - 1;

/// 심연에서 고정되는 스테이지(극한 최종 사냥터 시작).
int abyssStage(RunConfig run) => run.zoneStartStage(run.zonesPerTier);

/// 지금 싸우는 심연 층(심연 밖이면 0) — 몬스터·보상 함수의 `abyssFloor` 인자로 그대로 넘긴다.
int activeAbyssFloor(SaveGame s) => s.inAbyss ? s.abyssFloor : 0;

/// 주가 바뀌었으면 **1층부터**(사장님 확정 A안 — 매주 새 경쟁). 역대 최고는 그대로.
SaveGame applyAbyssWeek(SaveGame s, String week) {
  if (s.abyssWeek == week) return s;
  return s.copyWith(
    abyssWeek: week,
    abyssFloor: 1,
    abyssBossBest: 0,
    zoneKills: s.inAbyss ? 0 : s.zoneKills,
  );
}

/// 심연 층 보스에게 넣은 피해 비율([fraction] 0~1)을 기록한다 — 이번 주 막힌 층의 **최고치**만.
/// 쓰러지거나 도망쳐 보스전이 끝날 때 부른다(잡으면 층이 올라 0 부터 다시).
SaveGame recordAbyssBossDamage(SaveGame s, double fraction) {
  if (!s.inAbyss || !fraction.isFinite) return s;
  final pm = (fraction * 1000).floor().clamp(0, 999);
  return pm > s.abyssBossBest ? s.copyWith(abyssBossBest: pm) : s;
}

/// 극한 최종 보스를 처음 잡으면 심연이 열린다.
SaveGame unlockAbyss(SaveGame s) =>
    s.abyssUnlocked ? s : s.copyWith(abyssUnlocked: true);

/// 심연으로 — 난이도·스테이지를 극한 끝으로 고정하고 게이지는 비운다. 성장 축은 **그대로**.
/// 쓰러져 심연 밖으로 밀려났으면(올라갈 수 있는 한계가 있으면) 극한 최종 보스를 다시 잡아야 들어간다.
SaveGame enterAbyss(SaveGame s, RunConfig run, String week) {
  if (!s.abyssUnlocked || s.capStage > 0) return s;
  final w = applyAbyssWeek(s, week);
  return w.copyWith(
    inAbyss: true,
    difficultyTier: abyssTier(run),
    stageNumber: abyssStage(run),
    zoneKills: 0,
  );
}

/// 심연에서 나온다 — 극한 최종 사냥터에 선다. 층은 그 주 동안 남는다.
SaveGame leaveAbyss(SaveGame s) =>
    s.inAbyss ? s.copyWith(inAbyss: false, zoneKills: 0) : s;

/// 층 보스를 잡았다 → 다음 층. [milestone] = 이 층이 **처음 깬** `milestoneEvery` 배수 층.
///
/// 조각은 보스와 같은 규칙: 마일스톤이면 "첫 처치"(10개 확정), 아니면 재처치 확률.
/// ❌ 젤리는 주지 않는다 — 층은 무한히 늘어나는 통로다(§2.6). 젤리는 주간 순위로만.
({SaveGame save, bool milestone, Map<String, int> shards, int fossil})
clearAbyssFloor(
  SaveGame s,
  RunConfig run, {
  SkillConfig? skill,
  math.Random? rng,
}) {
  final cfg = run.abyss;
  final floor = s.abyssFloor;
  final milestone =
      cfg.milestoneEvery > 0 &&
      floor % cfg.milestoneEvery == 0 &&
      floor > s.abyssBest;
  var out = s.copyWith(
    abyssFloor: floor + 1,
    abyssBest: math.max(s.abyssBest, floor),
    abyssBossBest: 0,
    zoneKills: 0,
  );
  var fossil = 0;
  if (milestone && cfg.milestoneFossil > 0) {
    fossil = cfg.milestoneFossil;
    final mats = Map<MaterialKind, int>.from(out.materials);
    mats[MaterialKind.fossil] = (mats[MaterialKind.fossil] ?? 0) + fossil;
    out = out.copyWith(materials: mats);
  }
  var shards = const <String, int>{};
  if (skill != null && rng != null) {
    final g = grantBossShards(
      out,
      skill,
      rng,
      tier: abyssTier(run),
      firstKill: milestone,
    );
    out = g.save;
    shards = g.shards;
  }
  return (save: out, milestone: milestone, shards: shards, fossil: fossil);
}
