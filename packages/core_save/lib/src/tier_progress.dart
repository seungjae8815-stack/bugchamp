import 'dart:math' as math;

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';

import 'save_game.dart';

/// 난이도(회차) 이동 규칙 — 2026-09-15 사장님 결정(B안).
///
/// - 가 본 가장 높은 난이도([SaveGame.maxTierReached])까지는 **자유롭게 오간다.**
///   오가도 성장 축(강화·레벨·골드·일반 재료)은 그대로다. 아래 난이도는 벌이가
///   적고 클리어 보상도 최고 난이도에서만 나와서, 내려가 모으는 이득이 없다.
/// - 성장 축 초기화는 **처음 가는 난이도**에 들어설 때만 한다 — 이게 없으면
///   회차가 이틀 만에 끝난다(2026-09-14).
/// - [SaveGame.bestStage] 는 **최고 난이도 안의** 최고 스테이지다. 난이도를 넘길
///   때 초기화한다 — 안 그러면 보통으로 넘어가도 쉬움 최종(1001)이 남아 랭킹에
///   "보통 · 최종 사냥터"로 뜨고 로드맵이 전부 점령으로 보였다.
///
/// 앱 컨트롤러가 이 함수를 그대로 쓴다(Riverpod·Hive 를 모르는 순수 변환이라
/// 테스트가 규칙을 직접 본다).
extension TierProgress on SaveGame {
  /// 가 본 가장 높은 난이도.
  int get topTier => math.max(maxTierReached, difficultyTier);

  /// 지금 난이도에서 **점령한 가장 높은 스테이지**. 최고 난이도보다 아래면 그
  /// 난이도는 다 깬 것이다(최종 보스를 넘어 올라갔으므로).
  int highestStageInTier(RunConfig run) => difficultyTier < topTier
      ? run.zoneStartStage(run.zonesPerTier) + run.worldSize
      : math.max(bestStage, stageNumber);

  /// 랭킹에 싣는 진행도 — (최고 난이도, 그 난이도의 최고 스테이지).
  ({int tier, int stage}) get rankProgress => (
    tier: topTier,
    stage: difficultyTier >= topTier
        ? math.max(math.max(bestStage, stageNumber), 1)
        : math.max(bestStage, 1),
  );
}

/// 최종 보스를 깨고 다음 난이도로.
SaveGame enterNextTierSave(SaveGame s, RunConfig run) {
  final next = s.difficultyTier + 1;
  if (next > s.topTier) {
    return s.copyWith(
      stageNumber: 1,
      difficultyTier: next,
      maxTierReached: next,
      bestStage: 0,
      // 성장 축을 처음으로 — 이게 없으면 회차가 이틀 만에 끝난다.
      upgradeLevels: const {},
      level: 1,
      xp: 0,
      gold: 0,
      zoneKills: 0,
      // 일반 재료(키틴·미네랄·수액)는 강화 2차 비용이라 골드와 한 세트다.
      // 젤리·화석은 남긴다.
      materials: {
        for (final e in s.materials.entries)
          if (!kRegularMaterials.contains(e.key)) e.key: e.value,
      },
    );
  }
  // 이미 가 본 난이도로 다시 올라간다 — 초기화 없음.
  return selectTierSave(s, run, next);
}

/// 로드맵에서 난이도를 고른다. [tier] 는 0 ~ [TierProgress.topTier].
///
/// 최고 난이도로 돌아가면 거기서 점령한 최고 사냥터로, 그보다 아래면 그 난이도의
/// 최종 사냥터로 간다(다 깬 난이도라 사냥터는 로드맵에서 다시 고르면 된다).
SaveGame selectTierSave(SaveGame s, RunConfig run, int tier) {
  final top = s.topTier;
  final t = tier.clamp(0, top);
  if (t == s.difficultyTier) return s;
  final stage = t == top
      ? run.zoneStartStage(run.zoneOf(math.max(s.bestStage, 1)))
      : run.zoneStartStage(run.zonesPerTier);
  return s.copyWith(
    difficultyTier: t,
    maxTierReached: top,
    stageNumber: stage,
    zoneKills: 0,
  );
}
