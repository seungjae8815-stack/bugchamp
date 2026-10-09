import 'package:core_run/core_run.dart';

import 'abyss_progress.dart';
import 'save_game.dart';
import 'tier_progress.dart';

/// 쓰러지면 아래로(2026-10-05 사장님 확정) — **앱과 서버가 같은 함수**를 쓴다(§4).
///
/// - **올라갈 수 있는 가장 높은 칸**([frontierOf])에서 **일반 몬스터**에게 쓰러지면 한 칸 아래 사냥터로 내려가고,
///   올라갈 수 있는 한계([SaveGame.capTier]·[SaveGame.capStage])도 그 칸이 된다.
/// - 그보다 **아래 칸**(로드맵으로 내려가 농사하던 칸)에서 쓰러지면 예전처럼 게이지만 비운다 — 한계를 지금 칸으로
///   덮으면 쉬움을 구경하다 쓰러진 유저가 최고 난이도로 못 돌아갔다(2026-10-05 출시 전 점검).
/// - **사냥터 1 은 난이도를 넘지 않는다**(게이지만). 난이도마다 성장이 초기화돼서 이전 난이도의 최종 사냥터가 지금
///   사냥터 1 보다 수백 배 세다(보통 1 체력 287 · 쉬움 최종 158,734) — "아래로"가 아니라 "위로"가 된다.
/// - 심연이면 한 층 아래로, 심연 1층이면 극한 최종 사냥터로 나간다(심연은 극한 최종 위에 층 배율만 얹으므로
///   극한 최종이 더 쉽다).
/// - 보스 도전 실패는 이 함수를 부르지 않는다(게이지만 — 보스는 "겨우 잡히는" 체력이라 실패가 잦은 게 정상).
/// - 내려간 칸에는 **보스 도전이 열린 채로** 도착한다 — 그 보스만 다시 잡으면 원래 칸으로 돌아간다.
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
  if (!atClimbFront(s, run) || zone <= 1) {
    return s.zoneKills == 0 ? s : s.copyWith(zoneKills: 0);
  }
  return s.copyWith(
    stageNumber: run.zoneStartStage(zone - 1),
    zoneKills: full,
    capTier: s.difficultyTier,
    capStage: run.zoneStartStage(zone - 1),
  );
}

/// 지금 칸이 **올라갈 수 있는 가장 높은 칸**([frontierOf])인가. 심연은 늘 그렇다(층을 골라 내려갈 수 없다).
///
/// 쓰러짐 벌칙([fallOnDefeat])과 보스 자동 도전(앱, 2026-10-09 사장님 확정 — 로드맵으로 일부러 내려간
/// 아래 사냥터에서는 자동으로 도전하지 않는다)이 같은 판정을 쓴다. 쓰러져 내려온 한계 칸은 앞 칸이다.
bool atClimbFront(SaveGame s, RunConfig run) {
  if (s.inAbyss) return true;
  final front = frontierOf(s, run);
  return s.difficultyTier == front.tier &&
      run.zoneOf(s.stageNumber) >= front.zone;
}

/// 지금 올라갈 수 있는 가장 높은 칸 — 한계가 있으면 한계, 없으면 가 본 최고 난이도의 최고 사냥터.
({int tier, int zone}) frontierOf(SaveGame s, RunConfig run) {
  if (s.capStage > 0) return (tier: s.capTier, zone: run.zoneOf(s.capStage));
  final top = s.topTier;
  final best = s.difficultyTier >= top
      ? (s.bestStage > s.stageNumber ? s.bestStage : s.stageNumber)
      : s.bestStage;
  return (tier: top, zone: run.zoneOf(best < 1 ? 1 : best));
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
