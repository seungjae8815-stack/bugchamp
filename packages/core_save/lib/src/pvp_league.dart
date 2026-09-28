import 'package:core_run/core_run.dart';

import 'save_game.dart';

/// 결투 리그 규칙 — **앱과 서버가 같은 함수**를 쓴다(2026-09-29, 리그 = 등급 하나 · 상위 20% 승급 · 하위 20% 강등).

/// 지금 리그 순번. 개편 전 세이브(`pvpLeague` = -1)는 **지금 트로피**로 옛 등급을 유도한다 —
/// 옛 규칙("끝나는 순간의 등급", 2026-08-18)과 같게. 최고 기록으로 유도하면 주중에 떨어진 유저가
/// 한때의 등급으로 보상을 받아 옛 규칙과 어긋난다.
int pvpLeagueOf(SaveGame s, BattleConfig cfg) {
  if (s.pvpLeague >= 0) return s.pvpLeague.clamp(0, cfg.leagues.length - 1);
  return cfg.leagueIndexOf(cfg.leagueFor(s.pvpTrophies).id);
}

/// 지금 리그.
League pvpLeagueNow(SaveGame s, BattleConfig cfg) =>
    cfg.leagueAt(pvpLeagueOf(s, cfg));
