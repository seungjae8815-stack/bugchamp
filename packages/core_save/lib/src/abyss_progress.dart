import 'dart:math' as math;

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';

import 'save_game.dart';
import 'skill_progress.dart';

/// 심연 진행 규칙 — **앱과 서버가 같은 함수**를 쓴다(§4, docs/design_abyss.md).

/// 이번 주 id — 결투 시즌과 같은 경계(일요일 24시 KST)라 한 화면에서 "매주 일요일 자정 정산"으로 말한다.
String abyssWeekId(DateTime now, BattleConfig battle) =>
    seasonIdOf(seasonStartAt(now, battle), battle);

/// 진행도 랭킹의 심연 값 — **이번 주 지금 깬 층**(2026-10-05 사장님 확정: 약해져 내려가면 랭킹도 내려간다).
/// [week] 가 세이브의 주와 다르면(주가 바뀌었는데 아직 안 들어옴) 0. 역대 최고(`abyssBest`)가 아니다 —
/// 앱의 내 줄이 역대 최고로 그려져 서버 값(0)과 달랐다(2026-10-12 사장님 지적: 내려갔다 왔는데 26층).
int abyssRankFloorOf(SaveGame save, {String? week}) {
  if (!save.abyssUnlocked) return 0;
  if (week != null && save.abyssWeek != week) return 0;
  return math.max(0, save.abyssFloor - 1);
}

/// 심연에서 고정되는 난이도(극한 = 표의 마지막).
int abyssTier(RunConfig run) =>
    run.zoneTiers.isEmpty ? 3 : run.zoneTiers.length - 1;

/// 심연에서 고정되는 스테이지(극한 최종 사냥터 시작).
int abyssStage(RunConfig run) => run.zoneStartStage(run.zonesPerTier);

/// 지금 싸우는 심연 층(심연 밖이면 0) — 몬스터·보상 함수의 `abyssFloor` 인자로 그대로 넘긴다.
int activeAbyssFloor(SaveGame s) => s.inAbyss ? s.abyssFloor : 0;

/// 주가 바뀌었으면 **1층부터**(사장님 확정 A안 — 매주 새 경쟁). 역대 최고는 그대로.
/// 심연 연구 "심연 지름길"(2026-11-12)이 있으면 지난주 최고 층의 일부([abyssWeekStartFloor])부터 — 건너뛴 10층 배수의
/// 결정은 그 자리에서 준다(안 주면 지름길이 손해라 아무도 안 쓴다). 포자는 직접 오른 층만(건너뛴 층은 없다).
SaveGame applyAbyssWeek(
  SaveGame s,
  String week, {
  RunConfig? run,
  ResearchConfig? lab,
}) {
  if (s.abyssWeek == week) return s;
  final start = run == null ? 1 : abyssWeekStartFloor(s, week, lab);
  final bonus = abyssLabFx(s, lab).of(ResearchEffect.crystalBonus);
  var crystals = 0;
  for (var f = 1; f < start; f++) {
    crystals += abyssCrystalsFor(run!.abyss, f, bonus);
  }
  return s.copyWith(
    abyssWeek: week,
    abyssFloor: start,
    abyssBossBest: 0,
    abyssWeekTop: start - 1,
    abyssCrystals: s.abyssCrystals + crystals,
    zoneKills: s.inAbyss ? 0 : s.zoneKills,
  );
}

/// 지난주 id(주 id = 시즌 시작 날짜 `yyyy-MM-dd`).
String abyssPrevWeekId(String week) {
  final d = DateTime.tryParse(week);
  if (d == null) return '';
  final p = d.subtract(const Duration(days: 7));
  String two(int v) => v.toString().padLeft(2, '0');
  return '${p.year}-${two(p.month)}-${two(p.day)}';
}

/// 새 주 [week] 의 시작 층 — 심연 지름길(v) × 지난주 최고 층을 10층 단위로 내림 + 1. 지난주에 안 올랐거나 연구가 없으면 1.
/// 지난주 최고 층은 **세이브의 그 주 기록**(`abWt`, 서버가 자른 값)이다 — 앱·서버 같은 함수.
int abyssWeekStartFloor(SaveGame s, String week, ResearchConfig? lab) {
  final v = abyssLabFx(s, lab).of(ResearchEffect.abyssShortcut);
  if (v <= 0) return 1;
  final lastTop = s.abyssWeek == abyssPrevWeekId(week) ? s.abyssWeekTop : 0;
  final skip = ((lastTop * v + 1e-9) ~/ 10) * 10;
  return skip <= 0 ? 1 : skip + 1;
}

/// 심연 연구 효과(연구소 설정이 없으면 없음).
ResearchEffects abyssLabFx(SaveGame s, ResearchConfig? lab) =>
    lab == null || !lab.abyssLab.enabled
    ? ResearchEffects.none
    : abyssResearchEffects(lab.abyssLab, s.abyssLabLevels);

/// 층 [floor] 를 그 주에 처음 깼을 때의 결정 — 결정 정제 연구 몫([bonus])까지(내림). 앱·서버 공용.
int abyssCrystalsFor(AbyssConfig cfg, int floor, double bonus) {
  final c = cfg.crystalsAt(floor);
  return c <= 0 ? 0 : (c * (1 + bonus) + 1e-9).floor();
}

/// 보스 도전이 열리는 처치 수 — 심연 안이면 "빠른 하강" 연구만큼 줄어든다(2026-11-12). 앱 게이지·버튼 공용.
int bossUnlockKillsFor(SaveGame s, RunConfig run, ResearchConfig? lab) {
  final base = run.bossUnlockKills;
  if (!s.inAbyss) return base;
  final v = abyssLabFx(s, lab).of(ResearchEffect.abyssFastFloor);
  return math.max(1, (base * (1 - v.clamp(0.0, 0.9))).ceil());
}

/// 심연 방치 골드 배율 — "심연 휴식" 연구(심연 안에 있을 때만). 앱·서버 방치 정산 공용.
double abyssIdleGoldMult(SaveGame s, ResearchConfig? lab) =>
    s.inAbyss ? 1 + abyssLabFx(s, lab).of(ResearchEffect.abyssIdleGold) : 1;

/// 심연 연구 시작 — 전용 1칸(심연이 열려야) · 포자로 낸다. 못 하면 error.
({SaveGame? save, String? error}) startAbyssLab(
  SaveGame s,
  ResearchConfig rc,
  String id,
  DateTime now,
) {
  final lab = rc.abyssLab;
  final def = lab.byId(id);
  if (def == null) return (save: null, error: 'unknown_research');
  if (!s.abyssUnlocked) return (save: null, error: 'abyss_locked');
  if (s.abyssLabSlot != null) return (save: null, error: 'slot_busy');
  final lv = (s.abyssLabLevels[id] ?? 0) + 1;
  if (lv > def.maxLevel) return (save: null, error: 'max_level');
  final cost = rc.costAt(def, lv).samples;
  if (s.abyssSpores < cost) return (save: null, error: 'no_spores');
  return (
    save: s.copyWith(
      abyssSpores: s.abyssSpores - cost,
      abyssLabSlot: ResearchSlot(
        id: id,
        level: lv,
        endsAt: now.toUtc().add(rc.timeAt(def, lv)),
      ),
    ),
    error: null,
  );
}

/// 끝난 심연 연구를 받는다(안 끝났으면 그대로).
SaveGame claimAbyssLab(SaveGame s, DateTime now) {
  final slot = s.abyssLabSlot;
  if (slot == null || slot.endsAt.isAfter(now.toUtc())) return s;
  return s.copyWith(
    abyssLabLevels: {...s.abyssLabLevels, slot.id: slot.level},
    clearAbyssLabSlot: true,
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
SaveGame enterAbyss(
  SaveGame s,
  RunConfig run,
  String week, {
  ResearchConfig? lab,
}) {
  if (!s.abyssUnlocked || s.capStage > 0) return s;
  final w = applyAbyssWeek(s, week, run: run, lab: lab);
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
({
  SaveGame save,
  bool milestone,
  Map<String, int> shards,
  int fossil,
  int crystals,
  int spores,
})
clearAbyssFloor(
  SaveGame s,
  RunConfig run, {
  SkillConfig? skill,
  math.Random? rng,
  // 심연 연구소(2026-11-12) — 포자 드롭·결정 정제·포자 감각.
  ResearchConfig? lab,
}) {
  final cfg = run.abyss;
  final floor = s.abyssFloor;
  final milestone =
      cfg.milestoneEvery > 0 &&
      floor % cfg.milestoneEvery == 0 &&
      floor > s.abyssBest;
  // 심연 결정(2026-11-10) — 역대 최고가 아니라 **그 주에** 처음 깬 10층 배수마다(매주 다시 번다).
  // 그 주 최고 층 아래는 다시 깨도 없다(쓰러져 내려갔다 같은 층을 깨는 반복 차단).
  final fx = abyssLabFx(s, lab);
  final crystals = floor > s.abyssWeekTop
      ? abyssCrystalsFor(cfg, floor, fx.of(ResearchEffect.crystalBonus))
      : 0;
  // 심연 포자 — 그 주에 처음 깬 층 + 10층 배수 역대 첫 도달(결정과 같은 "그 주 최고 층" 규칙). 보유 상한까지.
  final abLab = lab?.abyssLab;
  var spores = 0;
  if (abLab != null && abLab.enabled) {
    if (floor > s.abyssWeekTop) {
      spores += abLab.sporesForFloor(
        floor,
        sporeBonus: fx.of(ResearchEffect.sporeBonus),
      );
    }
    if (milestone) spores += abLab.sporesMilestone;
    spores = math.max(0, math.min(spores, abLab.sporeCap - s.abyssSpores));
  }
  var out = s.copyWith(
    abyssSpores: s.abyssSpores + spores,
    abyssFloor: floor + 1,
    abyssBest: math.max(s.abyssBest, floor),
    abyssBossBest: 0,
    zoneKills: 0,
    abyssCrystals: s.abyssCrystals + crystals,
    abyssWeekTop: math.max(s.abyssWeekTop, floor),
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
  return (
    save: out,
    milestone: milestone,
    shards: shards,
    fossil: fossil,
    crystals: crystals,
    spores: spores,
  );
}

/// 이 세이브의 강화 [kind] 곡선 — 심연 결정으로 연 상한 돌파([SaveGame.upgradeCapUps])를 얹는다.
/// 강화를 사거나 살 수 있는지 보는 곳(앱 구매·화면·미션)은 `run.upgrade(kind)` 대신 이걸 쓴다.
UpgradeSpec upgradeSpecOf(RunConfig run, SaveGame s, UpgradeKind kind) {
  final spec = run.upgrade(kind);
  final steps = s.upgradeCapUps[kind] ?? 0;
  if (steps <= 0 || !run.abyss.capBreakable(kind)) return spec;
  return spec.withCapBonus(steps * run.abyss.capStep);
}

/// 강화 [kind] 의 상한 돌파 다음 단계 비용(못 열면 null — 대상 아님·다 엶·상한 없는 줄).
int? upgradeCapStepCost(RunConfig run, SaveGame s, UpgradeKind kind) {
  if (!run.abyss.capBreakable(kind) || run.upgrade(kind).maxLevel == null) {
    return null;
  }
  return run.abyss.capStepCost(s.upgradeCapUps[kind] ?? 0);
}

/// 심연 결정으로 강화 [kind] 의 상한을 한 단계 연다. 못 열면 null(대상 아님·다 엶·결정 부족).
SaveGame? buyUpgradeCapStep(SaveGame s, RunConfig run, UpgradeKind kind) {
  final cost = upgradeCapStepCost(run, s, kind);
  if (cost == null || s.abyssCrystals < cost) return null;
  return s.copyWith(
    abyssCrystals: s.abyssCrystals - cost,
    upgradeCapUps: {...s.upgradeCapUps, kind: (s.upgradeCapUps[kind] ?? 0) + 1},
  );
}

/// 심연 결정으로 각인 [key] 를 한 레벨 올린다(2026-11-10). 못 올리면 null(없는 키·결정 부족).
SaveGame? buyAbyssImprint(SaveGame s, RunConfig run, String key) {
  final cfg = run.abyss;
  if (!cfg.imprintOn || !cfg.imprint.containsKey(key)) return null;
  final lv = s.abyssImprint[key] ?? 0;
  final cost = cfg.imprintCost(lv);
  if (s.abyssCrystals < cost) return null;
  return s.copyWith(
    abyssCrystals: s.abyssCrystals - cost,
    abyssImprint: {...s.abyssImprint, key: lv + 1},
  );
}

/// 이번 주 심연 변이(2026-11-10) — 모든 유저에게 같다(두 주 연속 같지 않다 — [AbyssConfig.mutationFor]).
AbyssMutation? abyssMutationAt(
  RunConfig run,
  BattleConfig battle,
  DateTime now,
) => run.abyss.mutationFor(abyssWeekId(now, battle));
