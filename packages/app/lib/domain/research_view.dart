import 'dart:math' as math;

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';

import '../data/game_data.dart';
import 'combat_power.dart';

/// 연구소 화면·빨간 점·컨트롤러가 함께 쓰는 값(설계 `docs/superpowers/specs/2026-10-22-research-lab-design.md` §3.6).
///
/// 규칙(가격·시작 조건)은 core_save `research_progress.dart` 에 있고, 여기서는 앱이 쥔 값(사냥 능력치·시각)을
/// 이어 붙이기만 한다 — 화면이 보여 주는 값과 실제로 빠지는 값이 갈리지 않게 한 곳에서 계산한다.

/// 비용 기준 스테이지 = **가 본 가장 높은 사냥터의 첫 스테이지**(지금 서 있는 곳이 아니다 — 쉬운 곳으로
/// 내려가 싸게 사는 길을 막는다). 최고 난이도 안의 최고 기록([SaveGame.bestStage])에서 사냥터를 잡고,
/// 최종 사냥터에서 자른다(심연 층 배율은 넣지 않는다 — 설계 §8).
int researchHuntStage(SaveGame s, RunConfig run) {
  final best = s.difficultyTier >= s.topTier
      ? math.max(s.bestStage, s.stageNumber)
      : s.bestStage;
  final zone = run.zoneOf(math.max(best, 1)).clamp(1, run.zonesPerTier);
  return run.zoneStartStage(zone);
}

/// 연구 [id] 의 다음 레벨 값. 사냥 설정·연구 설정이 없거나 다 찍은 연구면 null.
ResearchPrice? researchPriceOf(
  SaveGame s,
  GameData data,
  String id,
  DateTime now, {
  Map<String, double> guildBonus = const {},
  CharacterStats? stats,
}) {
  final cfg = data.researchConfig;
  final run = data.runConfig;
  final def = cfg?.byId(id);
  if (cfg == null || run == null || def == null) return null;
  if ((s.researchLevels[id] ?? 0) >= def.maxLevel) return null;
  final st = stats ?? huntStatsOf(s, data, now, guildBonus: guildBonus);
  final stage = researchHuntStage(s, run);
  return researchPrice(
    s,
    cfg,
    id,
    huntAtTop: (m) {
      final r = huntMinutesReward(
        run,
        stats: st,
        stage: stage,
        minutes: m,
        tier: s.topTier,
      );
      return (gold: r.gold, materialsEach: r.materialsEach);
    },
    pass: s.researchPassActive(now),
  );
}

/// 지금 시작할 수 있는 연구가 하나라도 있나(빈 칸 · 선행 충족 · 재화 충분 · 진행 중 아님).
/// 사냥 능력치는 한 번만 계산한다(빨간 점이 세이브가 바뀔 때마다 부른다).
bool anyResearchStartable(
  SaveGame s,
  GameData data,
  DateTime now, {
  Map<String, double> guildBonus = const {},
}) {
  final cfg = data.researchConfig;
  if (cfg == null || data.runConfig == null) return false;
  if (s.researchSlots.length >=
      cfg.slotsFor(
        s.topTier,
        s.researchSlotsBought,
        abyss: s.abyssUnlocked,
      )) {
    return false;
  }
  CharacterStats? stats;
  for (final def in cfg.defs) {
    final lv = s.researchLevels[def.id] ?? 0;
    if (lv >= def.maxLevel) continue;
    final req = def.requires;
    if (req != null && (s.researchLevels[req.id] ?? 0) < req.level) continue;
    if (s.researchSlots.any((r) => r.id == def.id)) continue;
    // 사냥 분치가 필요 없는 표본·화석부터 본다 — 모자라면 능력치 계산 없이 넘긴다.
    final cost = cfg.costAt(def, lv + 1);
    if (s.researchSamples < cost.samples ||
        s.materialCount(MaterialKind.fossil) < cost.fossil) {
      continue;
    }
    stats ??= huntStatsOf(s, data, now, guildBonus: guildBonus);
    final price = researchPriceOf(s, data, def.id, now, stats: stats);
    if (price != null && startResearch(s, cfg, def.id, now, price).isOk) {
      return true;
    }
  }
  return false;
}

/// 칸 [index](0부터)가 진행도로 열리는 난이도 — 진행도로 안 열리면 null.
int? researchSlotOpensAtTier(ResearchConfig cfg, int index) {
  for (var t = 0; t < cfg.slotsByTier.length; t++) {
    if (cfg.slotsByTier[t] > index) return t;
  }
  return null;
}
