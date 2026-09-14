import 'package:core_run/core_run.dart';

import 'save_game.dart';

/// 도감 보스 수집(2026-09-15) — **잡아 본 사냥터 보스**의 아트 id 집합.
///
/// [SaveGame.bossDex] 에 더해 **클리어 보상 기록**(`clearedChapters`)도 읽는다.
/// 보스 수집이 생기기 전에 깬 사냥터가 빈칸으로 남으면 "잡았는데 왜 없지"가
/// 된다. 기록 키는 난이도마다 따로다(`w3` = 쉬움, `w3@2` = 어려움).
Set<String> collectedBosses(SaveGame s, RunConfig run, RoadmapConfig? roadmap) {
  final out = <String>{...s.bossDex};
  final chapters = roadmap?.chapters ?? const <RoadmapChapter>[];
  if (!run.zoneMode || chapters.isEmpty) return out;
  for (var tier = 0; tier < kBossDexTiers; tier++) {
    for (final ch in chapters) {
      if (!s.clearedChapters.contains(chapterClearKey(ch.id, tier))) continue;
      final zone = run.zoneOf(ch.startStage);
      if (zone < 1 || zone > run.zonesPerTier) continue;
      out.add(run.bossArtId(tier, zone));
    }
  }
  return out;
}

/// 도감에 싣는 난이도 수(쉬움·보통·어려움·극한).
const int kBossDexTiers = 4;

/// 도감 보스 칸 전체 — 난이도 순, 그 안에서 사냥터 순.
List<({int tier, int zone, String id})> bossDexSlots(RunConfig run) => [
  for (var tier = 0; tier < kBossDexTiers; tier++)
    for (var zone = 1; zone <= run.zonesPerTier; zone++)
      (tier: tier, zone: zone, id: run.bossArtId(tier, zone)),
];
