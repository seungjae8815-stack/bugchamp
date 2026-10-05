import 'package:core_run/core_run.dart';

import 'abyss_progress.dart';
import 'save_game.dart';
import 'tier_progress.dart';

/// 쓰러지면 아래로(2026-10-05 사장님 확정) — **앱과 서버가 같은 함수**를 쓴다(§4).
///
/// - **일반 몬스터**에게 쓰러지면 한 칸 아래 사냥터로 내려가고, 올라갈 수 있는 한계
///   ([SaveGame.capTier]·[SaveGame.capStage])도 그 칸이 된다. 보스 도전 실패는 예전처럼 게이지만 비운다
///   (보스는 "겨우 잡히는" 체력이라 실패가 잦은 게 정상이다).
/// - 사냥터 1 이면 이전 난이도의 최종 사냥터로. 쉬움 사냥터 1 은 더 내려갈 곳이 없어 게이지만 비운다.
/// - 심연이면 한 층 아래로, 심연 1층이면 극한 최종 사냥터로 나간다.
/// - 내려간 칸에는 **보스 도전이 열린 채로** 도착한다 — 그 보스(이미 잡아 본 보스)만 다시 잡으면 원래 칸으로
///   돌아간다. 정말 약해졌으면 그 보스도 못 잡아 머물게 된다.
/// - 로드맵은 한계 위로 못 간다(안 그러면 로드맵을 눌러 바로 되돌아간다). 진행도 랭킹도 한계로 매긴다.
SaveGame fallOnDefeat(SaveGame s, RunConfig run) {
  final full = run.bossUnlockKills;
  if (s.inAbyss) {
    if (s.abyssFloor > 1) {
      return s.copyWith(
        abyssFloor: s.abyssFloor - 1,
        abyssBossBest: 0,
        zoneKills: full,
      );
    }
    final t = abyssTier(run);
    final z = run.zonesPerTier;
    return leaveAbyss(s).copyWith(
      difficultyTier: t,
      stageNumber: run.zoneStartStage(z),
      zoneKills: full,
      capTier: t,
      capStage: run.zoneStartStage(z),
    );
  }
  final zone = run.zoneOf(s.stageNumber);
  var t = s.difficultyTier;
  int z;
  if (zone > 1) {
    z = zone - 1;
  } else if (t > 0) {
    t -= 1;
    z = run.zonesPerTier;
  } else {
    return s.copyWith(zoneKills: 0);
  }
  return s.copyWith(
    difficultyTier: t,
    stageNumber: run.zoneStartStage(z),
    zoneKills: full,
    capTier: t,
    capStage: run.zoneStartStage(z),
  );
}

/// [tier] 난이도 [zone] 사냥터의 보스를 잡았다 — 한계를 그 다음 칸까지 올린다. 가 본 최고 자리에 다시
/// 닿으면 한계가 풀린다(심연 입장도 다시 열린다). 한계가 없으면 그대로.
SaveGame liftClimbCap(
  SaveGame s,
  RunConfig run, {
  required int tier,
  required int zone,
}) {
  if (s.capStage <= 0) return s;
  var nt = tier;
  var nz = zone + 1;
  if (zone >= run.zonesPerTier) {
    nt = tier + 1;
    nz = 1;
  }
  final capZone = run.zoneOf(s.capStage);
  final beyond = nt > s.capTier || (nt == s.capTier && nz > capZone);
  if (!beyond) return s;
  final top = s.topTier;
  final bestZone = run.zoneOf(s.bestStage < 1 ? 1 : s.bestStage);
  if (nt > top || (nt == top && nz >= bestZone)) {
    return s.copyWith(clearClimbCap: true);
  }
  return s.copyWith(capTier: nt, capStage: run.zoneStartStage(nz));
}
