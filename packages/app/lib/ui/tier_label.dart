import 'package:core_run/core_run.dart';

import '../l10n/app_localizations.dart';

/// 난이도 회차 이름 — 쉬움 / 보통 / 어려움 / 극한.
///
/// 회차는 세이브의 `difficultyTier`(0=쉬움)다. 정의를 넘어서면 마지막 이름을
/// 쓴다 — 회차를 늘릴 때 문구가 없어서 화면이 비는 일이 없어야 한다.
String tierName(AppLocalizations l, int tier) => switch (tier) {
  <= 0 => l.tierEasy,
  1 => l.tierNormal,
  2 => l.tierHard,
  _ => l.tierExtreme,
};

/// 회차 개수(쉬움~극한). 마지막 회차를 깨면 더 갈 곳이 없다.
const int kTierCount = 4;

/// 진행도 표기 — `보통 5-32` 처럼 **난이도 + 월드-월드내스테이지**.
///
/// 숫자만 보여주면(`432`) 어느 구간인지 아무도 모른다(2026-08-30 지적).
/// 순위표에서 특히 그렇다 — 서로의 위치를 비교하려면 난이도가 앞에 있어야 한다.
///
/// 월드 번호는 로드맵 챕터 순서(w1 → 1)이고, 챕터가 100스테이지 단위라
/// `stage - startStage + 1` 이 월드 안에서의 위치가 된다.
/// 로드맵을 못 읽었으면 **숫자를 그대로** 돌려준다 — 표기 때문에 화면이
/// 비어 보이면 안 된다.
String progressLabel(
  AppLocalizations l,
  RoadmapConfig? roadmap,
  int tier,
  int stage,
) {
  final pos = roadmap?.stageLabel(stage);
  if (pos == null) return '${tierName(l, tier)} $stage';
  return '${tierName(l, tier)} ${pos.world}-${pos.inWorld}';
}
