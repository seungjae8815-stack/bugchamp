import 'roadmap_config.dart';
import 'run_config.dart';
import 'run_math.dart';

/// 사냥터(챕터) 클리어 보상 — **앱 지급과 서버 허용치가 같은 함수**를 쓴다.
///
/// 2026-09-15: 옛 스테이지 구조의 정액(2만~8억)은 난이도별 표와 규모가 맞지
/// 않았다 — 쉬움 처치 골드가 12~1,395 인데 사냥터 10 클리어가 4억이라 몇십만
/// 마리분이 한 번에 들어왔다. 이제 **그 사냥터에서 [RunConfig.chapterClearHours]
/// 시간 사냥한 골드**다(처치 수는 교환소와 같은 [RunConfig.exchangeKillsPerHour]).
/// 표와 늘 같은 규모라 표를 다시 뽑아도 어긋나지 않는다.
///
/// [RunConfig.chapterClearHours] 가 0 이면 예전 정액([RoadmapChapter.rewardGold]).
int chapterClearGold(RunConfig run, RoadmapChapter ch, int tier) {
  if (run.chapterClearHours <= 0) return ch.rewardGold;
  final perKill = rewardGold(run, ch.startStage - 1, 1.0, tier: tier);
  return (perKill * run.exchangeKillsPerHour * run.chapterClearHours).round();
}

/// 클리어 기록 키 — **난이도마다 따로** 받는다.
///
/// 회차를 넘기면 사냥터를 처음부터 다시 깨고, 보상도 그 난이도 규모라 다시
/// 받는 게 맞다. 쉬움(0)은 예전 키(`w3`) 그대로라 기존 기록이 유효하다.
String chapterClearKey(String chapterId, int tier) =>
    tier <= 0 ? chapterId : '$chapterId@$tier';

/// 키에서 난이도를 읽는다(`w3@2` → 2, `w3` → 0).
int chapterClearKeyTier(String key) {
  final i = key.lastIndexOf('@');
  if (i < 0) return 0;
  return int.tryParse(key.substring(i + 1)) ?? 0;
}
