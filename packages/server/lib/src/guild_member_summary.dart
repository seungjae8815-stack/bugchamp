import 'package:core_save/core_save.dart';

/// 길드원 정보 시트에 보낼 **세이브 요약**(2026-10-05) — `/guild/member/<id>`.
///
/// ⚠️ 세이브를 통째로 보내지 않는다 — 크기(곤충 50~100마리)·개인정보(차단 목록·구매 기록 등).
/// 화면에 그리는 것만 고른다: 진행도·레벨·장착 곤충 3칸·장비 8부위·동행 요정·장착 스킬.
/// 곤충·장비·요정은 각 모델의 `toJson` 그대로(앱이 같은 모델·같은 그림 위젯으로 그린다).
/// 결투 방어팀은 서버가 편성 검증을 거쳐 계산한 값을 [team] 으로 받는다(`/pvp/profile` 과 같은 모양).
Map<String, dynamic> guildMemberSummary(
  SaveGame s, {
  List<Map<String, dynamic>> team = const [],
}) {
  final byId = {for (final b in s.bugs) b.id: b};
  return {
    'nickname': s.nickname,
    'level': s.level,
    'tier': s.difficultyTier,
    'stage': s.stageNumber,
    'inAbyss': s.inAbyss,
    'abyssFloor': s.abyssFloor,
    'pets': [
      for (final id in s.equippedBugIds)
        if (byId[id] != null) byId[id]!.toJson(),
    ],
    'team': team,
    'equipment': [for (final e in s.equippedItems.values) e.toJson()],
    'fairy': ?s.fairy.companion?.toJson(),
    'skills': [
      for (final id in s.equippedSkills)
        {'id': id, 'level': s.skillLevels[id] ?? 0},
    ],
  };
}
