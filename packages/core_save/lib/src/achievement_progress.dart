import 'dart:math' as math;

import 'package:core_run/core_run.dart';

import 'save_game.dart';

/// 업적 · 칭호(2026-11-10) — 세이브에서 바로 계산한다. 앱 화면·칭호 고르기·서버 업로드 검사가 같은 함수.

/// [d] 의 지금 진행 값. [conquerLevel] = 도감 정복 기준 수련 레벨(`dex.json → conquerLevel`).
int achievementProgress(
  SaveGame s,
  AchievementDef d, {
  int conquerLevel = 1,
}) => switch (d.kind) {
  'dexDiscover' => s.dex.length,
  'dexConquer' => s.dexConqueredWith(conquerLevel),
  'dexVariant' => s.dex.values.where((e) => e.variantFound).length,
  'bosses' => s.bossDex.length,
  'tier' => s.maxTierReached,
  'abyss' => s.abyssBest,
  'league' => math.max(0, s.pvpLeague),
  'level' => s.level,
  'forge' => s.forgeLevel,
  // 왕중왕전 — 최고 성적을 "64 ÷ 순위"로(우승 64 · 준우승 32 · 4강 16 · 8강 8 · 16강 4 · 32강 2).
  'kotk' => s.kotkBest <= 0 ? 0 : 64 ~/ s.kotkBest,
  'specimens' => s.retiredBugs.length,
  _ => 0,
};

bool achievementDone(SaveGame s, AchievementDef d, {int conquerLevel = 1}) =>
    achievementProgress(s, d, conquerLevel: conquerLevel) >= d.goal;

/// [id] 업적의 칭호를 단다(null 이면 뗀다). 달성하지 않은 업적이면 null(못 단다).
SaveGame? setAchievementTitle(
  SaveGame s,
  RunConfig run,
  String? id, {
  int conquerLevel = 1,
}) {
  if (id == null) return s.copyWith(clearTitle: true);
  for (final d in run.achievements) {
    if (d.id == id) {
      return achievementDone(s, d, conquerLevel: conquerLevel)
          ? s.copyWith(title: id)
          : null;
    }
  }
  return null;
}

/// 단 칭호가 규칙 안인가(없는 업적·미달성이면 false) — 서버 업로드 검사.
bool titleValid(SaveGame s, RunConfig run, {int conquerLevel = 1}) {
  final id = s.title;
  if (id == null) return true;
  for (final d in run.achievements) {
    if (d.id == id) return achievementDone(s, d, conquerLevel: conquerLevel);
  }
  return false;
}
