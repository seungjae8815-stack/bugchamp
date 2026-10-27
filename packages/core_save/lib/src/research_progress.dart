import 'dart:math' as math;

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';

import 'save_game.dart';
import 'tier_progress.dart';

/// 연구소 진행 규칙(설계 `docs/superpowers/specs/2026-10-22-research-lab-design.md`) —
/// **가격 · 시작 · 완료 · 즉시 완료 · 칸 구매 · 표본 드롭**.
///
/// 규칙이 여기 한 곳에만 있다(앱·서버 공용 — 스킬 [SkillOp] 과 같은 이유).
/// 시간은 인자로, 무작위는 주입된 [math.Random] 으로만 쓴다(§5 결정론).

/// 연구 액션 결과. 실패면 [save] 가 null 이고 [error] 에 사유 키.
class ResearchOp {
  const ResearchOp.ok(SaveGame this.save, {this.extra = const {}})
    : error = null;
  const ResearchOp.fail(String this.error) : save = null, extra = const {};

  final SaveGame? save;
  final String? error;
  final Map<String, Object?> extra;

  bool get isOk => save != null;
}

/// 표본이 나오는 곳.
enum ResearchDropSource { elite, bossFirst, bossRepeat }

/// 연구 한 단계를 시작하는 값. [materialsEach] 는 일반 재료([kRegularMaterials]) **각각** 낸다.
class ResearchPrice {
  const ResearchPrice({
    required this.samples,
    required this.gold,
    required this.materialsEach,
    required this.fossil,
    required this.time,
    required this.level,
  });

  final int samples;
  final int gold;
  final int materialsEach;
  final int fossil;
  final Duration time;

  /// 이번에 올리는 레벨(현재 + 1).
  final int level;
}

/// 연구 [id] 의 다음 레벨 값. 골드·재료는 **가 본 최고 자리** 사냥 분치라 호출자가
/// [huntAtTop] 으로 계산해 준다(지금 서 있는 사냥터로 재면 내려가 싸게 사는 길이 생긴다).
/// 시간에는 연구 시간 단축 효과를 넣는다(최소 1초).
ResearchPrice researchPrice(
  SaveGame s,
  ResearchConfig cfg,
  String id, {
  required ({int gold, int materialsEach}) Function(double minutes) huntAtTop,
  // 연구 패스가 켜져 있나(2026-10-25 — 시간 −[ResearchConfig.passTimeCut]). 시작하는 순간 기준.
  bool pass = false,
}) {
  final def = cfg.byId(id)!;
  final level = (s.researchLevels[id] ?? 0) + 1;
  final cost = cfg.costAt(def, level);
  final cut = researchTimeCut(cfg, s.researchLevels, pass: pass);
  final base = cfg.timeAt(def, level);
  final ms = (base.inMilliseconds * (1 - cut)).round();
  return ResearchPrice(
    samples: cost.samples,
    gold: cost.goldMinutes > 0 ? huntAtTop(cost.goldMinutes).gold : 0,
    materialsEach: cost.materialMinutes > 0
        ? huntAtTop(cost.materialMinutes).materialsEach
        : 0,
    fossil: cost.fossil,
    time: Duration(milliseconds: math.max(1000, ms)),
    level: level,
  );
}

/// 연구 시작 — 재화를 쓰고 칸에 건다. 실패하면 세이브는 그대로.
ResearchOp startResearch(
  SaveGame s,
  ResearchConfig cfg,
  String id,
  DateTime now,
  ResearchPrice price,
) {
  final def = cfg.byId(id);
  if (def == null) return const ResearchOp.fail('unknown_research');
  final lv = s.researchLevels[id] ?? 0;
  if (lv >= def.maxLevel) return const ResearchOp.fail('max_level');
  if (price.level != lv + 1) return const ResearchOp.fail('stale_price');
  final req = def.requires;
  if (req != null && (s.researchLevels[req.id] ?? 0) < req.level) {
    return const ResearchOp.fail('locked');
  }
  if (s.researchSlots.any((r) => r.id == id)) {
    return const ResearchOp.fail('already_running');
  }
  if (s.researchSlots.length >=
      cfg.slotsFor(s.topTier, s.researchSlotsBought, abyss: s.abyssUnlocked)) {
    return const ResearchOp.fail('slots_full');
  }
  if (price.samples < 0 ||
      price.gold < 0 ||
      price.materialsEach < 0 ||
      price.fossil < 0) {
    return const ResearchOp.fail('not_enough');
  }
  if (s.researchSamples < price.samples ||
      s.gold < price.gold ||
      s.materialCount(MaterialKind.fossil) < price.fossil ||
      kRegularMaterials.any((m) => s.materialCount(m) < price.materialsEach)) {
    return const ResearchOp.fail('not_enough');
  }
  final mats = Map<MaterialKind, int>.from(s.materials);
  for (final m in kRegularMaterials) {
    mats[m] = (mats[m] ?? 0) - price.materialsEach;
  }
  if (price.fossil > 0) {
    mats[MaterialKind.fossil] = (mats[MaterialKind.fossil] ?? 0) - price.fossil;
  }
  return ResearchOp.ok(
    s.copyWith(
      gold: s.gold - price.gold,
      materials: mats,
      researchSamples: s.researchSamples - price.samples,
      researchSlots: [
        ...s.researchSlots,
        ResearchSlot(
          id: id,
          level: price.level,
          endsAt: now.toUtc().add(price.time),
        ),
      ],
    ),
  );
}

/// 끝난 칸 하나를 받는다(2026-10-26 사장님 확정 — 앱은 끝난 칸에 "연구 완료" 버튼을 띄우고 눌러야 레벨이 오른다.
/// 예전엔 저장할 때마다 [claimResearch] 로 바로 반영해 칸이 말없이 사라졌다). 실패: `not_running` · `not_done`.
ResearchOp claimResearchSlot(
  SaveGame s,
  ResearchConfig cfg,
  String id,
  DateTime now,
) {
  final slot = s.researchSlots.where((r) => r.id == id).firstOrNull;
  if (slot == null) return const ResearchOp.fail('not_running');
  if (now.isBefore(slot.endsAt)) return const ResearchOp.fail('not_done');
  return ResearchOp.ok(
    s.copyWith(
      researchLevels: {
        ...s.researchLevels,
        id: math.max(s.researchLevels[id] ?? 0, slot.level),
      },
      researchSlots: [
        for (final r in s.researchSlots)
          if (r.id != id) r,
      ],
    ),
    extra: {'level': slot.level},
  );
}

/// 끝난 칸을 모두 레벨에 반영하고 비운다. 끝난 칸이 없으면 그대로.
/// 앱은 더 이상 자동으로 부르지 않는다([claimResearchSlot]) — 서버 결투가 "끝났지만 아직 안 받은 칸"까지 셀 때만 쓴다.
SaveGame claimResearch(SaveGame s, ResearchConfig cfg, DateTime now) {
  final done = [
    for (final r in s.researchSlots)
      if (!now.isBefore(r.endsAt)) r,
  ];
  if (done.isEmpty) return s;
  final levels = Map<String, int>.from(s.researchLevels);
  for (final r in done) {
    levels[r.id] = math.max(levels[r.id] ?? 0, r.level);
  }
  return s.copyWith(
    researchLevels: levels,
    researchSlots: [
      for (final r in s.researchSlots)
        if (now.isBefore(r.endsAt)) r,
    ],
  );
}

/// 남은 시간을 젤리로 끝낸다 — 레벨을 바로 반영하고 칸을 비운다.
ResearchOp finishResearchNow(
  SaveGame s,
  ResearchConfig cfg,
  String id,
  DateTime now,
) {
  final slot = s.researchSlots.where((r) => r.id == id).firstOrNull;
  if (slot == null) return const ResearchOp.fail('not_running');
  final cost = cfg.instantJelly(slot.endsAt.difference(now));
  if (s.materialCount(MaterialKind.jelly) < cost) {
    return const ResearchOp.fail('not_enough_jelly');
  }
  final mats = Map<MaterialKind, int>.from(s.materials);
  mats[MaterialKind.jelly] = (mats[MaterialKind.jelly] ?? 0) - cost;
  return ResearchOp.ok(
    s.copyWith(
      materials: mats,
      researchLevels: {
        ...s.researchLevels,
        id: math.max(s.researchLevels[id] ?? 0, slot.level),
      },
      researchSlots: [
        for (final r in s.researchSlots)
          if (r.id != id) r,
      ],
    ),
    extra: {'jelly': cost},
  );
}

/// 연구 칸을 젤리로 산다 — **언제나 다음 칸 하나**가 열린다(2026-10-23 확정).
/// 지금 열린 칸이 n 개면 값은 `slotJelly[n − 1]`(2번째 칸 = [0] · 3번째 칸 = [1]), 산 칸 수는 n 이 된다
/// (`slotsFor = max(진행도 칸, 1 + 산 칸)` 이 n + 1 이 되게). 진행도로 이미 2칸인 어려움 유저가 사면 바로 3칸 —
/// 예전(`slotJelly[산 수]`, 산 수 + 1)은 어려움에서 첫 구매가 칸을 늘리지 않았다.
ResearchOp buyResearchSlot(SaveGame s, ResearchConfig cfg) {
  final n = cfg.slotsFor(
    s.topTier,
    s.researchSlotsBought,
    abyss: s.abyssUnlocked,
  );
  if (n >= ResearchConfig.maxSlots || n - 1 >= cfg.slotJelly.length) {
    return const ResearchOp.fail('max_slots');
  }
  final price = cfg.slotJelly[n - 1];
  if (s.materialCount(MaterialKind.jelly) < price) {
    return const ResearchOp.fail('not_enough_jelly');
  }
  final mats = Map<MaterialKind, int>.from(s.materials);
  mats[MaterialKind.jelly] = (mats[MaterialKind.jelly] ?? 0) - price;
  return ResearchOp.ok(
    s.copyWith(materials: mats, researchSlotsBought: n),
    extra: {'jelly': price},
  );
}

/// 지금 칸을 하나 더 사는 값 — 더 살 수 없으면 null(화면 가격표와 [buyResearchSlot] 이 같은 값).
int? researchSlotPrice(SaveGame s, ResearchConfig cfg) {
  final n = cfg.slotsFor(
    s.topTier,
    s.researchSlotsBought,
    abyss: s.abyssUnlocked,
  );
  if (n >= ResearchConfig.maxSlots || n - 1 >= cfg.slotJelly.length) {
    return null;
  }
  return cfg.slotJelly[n - 1];
}

/// 표본을 [n] 개 넣는다.
SaveGame grantResearchSamples(SaveGame s, int n) =>
    n <= 0 ? s : s.copyWith(researchSamples: s.researchSamples + n);

/// 표본 드롭 한 번 — 나온 개수(0 이면 꽝). 정예·보스 재처치는 확률, 보스 첫 처치는 확정.
int rollResearchDrop(
  ResearchConfig cfg,
  math.Random rng,
  ResearchDropSource src,
) => switch (src) {
  ResearchDropSource.elite =>
    rng.nextDouble() < cfg.eliteDropChance ? cfg.eliteDropAmount : 0,
  ResearchDropSource.bossFirst => cfg.bossFirstDrop,
  ResearchDropSource.bossRepeat =>
    rng.nextDouble() < cfg.bossRepeatChance ? cfg.bossRepeatDrop : 0,
};
