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

/// 깜짝선물 골드 — **정액과 사냥터 분치 중 큰 쪽**(2026-09-18 사장님 확정).
///
/// 정액만 두면 후반에 몬스터 한 마리보다 적어져(극한 한 마리 13,759 vs 선물
/// 12,000) 선물을 열 이유가 없어진다. 그렇다고 분치만 두면 초반이 확 약해진다
/// — 정액은 **초반 부스터로 설계된 값**이다(`balance_sim` 의 `_dailyBonusGold`
/// 주석: "day1 골드의 25% 수준, day25 엔 반올림 오차"). 그래서 정액을 바닥으로
/// 깔고 후반에는 분치가 이기게 둔다.
///
/// 선물은 **만들 때** 금액이 박힌다 — 그 시점 사냥터 기준이라 나중에 난이도를
/// 옮겨도 이미 받은 선물의 금액이 흔들리지 않는다.
/// 계산은 사냥터 클리어 보상과 같은 식이다(같은 처치 속도를 쓴다).
int giftGold(
  RunConfig run,
  int stage,
  int tier,
  int fixedGold,
  double goldMinutes,
) {
  if (goldMinutes <= 0) return fixedGold;
  final perKill = rewardGold(run, stage - 1, 1.0, tier: tier);
  final scaled = (perKill * run.exchangeKillsPerHour * goldMinutes / 60)
      .round();
  return scaled > fixedGold ? scaled : fixedGold;
}
