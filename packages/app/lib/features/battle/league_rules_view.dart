import 'dart:math' as math;

import 'package:core_run/core_run.dart';

/// 리그 순위표가 보여 주는 **이번 주 규칙** — 그 리그 결투 인원([total])으로 보상·승강을 계산한다.
///
/// 서버 결산(`GameActions.settlePvpLeague`)과 **같은 core 함수**(`leagueRankJelly`·`leagueZones`·
/// `leagueAfterSeason`)를 그대로 부른다(2026-10-11 경쟁 인원 보정·승급 문턱·소수 리그 합류).
/// [total] = 서버 `/pvp/league` 의 `total` — 결산과 같은 RPC(`pvp_league_rank_of`)의 리그 인원이고
/// 이번 주 점수 0 인 사람도 들어간다(보상·승급은 트로피 0 을 거른다 — [jellyFor] 도 같다).
class LeagueRulesView {
  LeagueRulesView(this.cfg, {required this.league, required this.total});

  final BattleConfig cfg;

  /// 리그 id(bronze …).
  final String league;

  /// 이번 주 이 리그 결투 인원.
  final int total;

  int get leagueIndex => cfg.leagueIndexOf(league);

  ({int promote, int demote}) get _zones => cfg.leagueZones(total);

  /// 결산 때 이 리그 전원이 아래 리그로 합류하나(맨 아래 리그는 아니다).
  bool get merges =>
      leagueIndex > 0 && total > 0 && total < cfg.leagueMergeBelowPeople;

  /// 승급 인원(합류하는 주에는 0).
  int get promote => merges ? 0 : _zones.promote;

  /// 강등 인원(합류하는 주에는 전원이 내려가므로 구간 표시는 따로 — [zoneOf]).
  int get demote => merges ? 0 : _zones.demote;

  /// [rank] 위(트로피 [trophies])가 결산에서 받을 순위 젤리 — 서버와 같은 식.
  int jellyFor(int rank, int trophies) => trophies <= 0 || rank < 1
      ? 0
      : cfg.leagueRankJelly(rank, league: league, people: total);

  /// 순위 줄의 구간 — 1 승급 · −1 강등(또는 합류) · 0 유지. 다음 주 리그를 결산 함수로 바로 잰다.
  int zoneOf(int rank, int trophies) {
    final next = cfg.leagueAfterSeason(
      leagueIndex,
      rank: rank,
      total: total,
      trophies: trophies,
    );
    return next > leagueIndex ? 1 : (next < leagueIndex ? -1 : 0);
  }

  /// 순위 보상표(받을 수 있는 순위만) — 같은 젤리가 이어지는 순위를 한 칸으로 묶는다.
  /// [fullTable] 이면 인원 보정 없는 원래 표(인원을 모를 때 · 10명 이상일 때와 같다).
  List<({int from, int to, int jelly})> rewardRanges({bool fullTable = false}) {
    final table = cfg.leagueRankRewards[league] ?? cfg.seasonRankRewards;
    final last = table.fold<int>(0, (a, r) => math.max(a, r.maxRank));
    final out = <({int from, int to, int jelly})>[];
    for (var r = 1; r <= last; r++) {
      final j = fullTable
          ? cfg.seasonRankJelly(r, league: league)
          : jellyFor(r, 1);
      if (j <= 0) continue;
      if (out.isNotEmpty && out.last.jelly == j && out.last.to == r - 1) {
        out[out.length - 1] = (from: out.last.from, to: r, jelly: j);
      } else {
        out.add((from: r, to: r, jelly: j));
      }
    }
    return out;
  }

  /// 순위표 위 안내 — 사람이 적은 리그에서만.
  LeagueFewNotice get notice {
    if (total <= 0) return LeagueFewNotice.none;
    if (total < cfg.rankRewardMinPeople || merges) {
      return merges ? LeagueFewNotice.merge : LeagueFewNotice.noReward;
    }
    if (total < fullPeople) return LeagueFewNotice.partial;
    return LeagueFewNotice.none;
  }

  /// 승급·전체 보상이 모두 열리는 인원.
  int get fullPeople =>
      math.max(cfg.leaguePromoteMinPeople, cfg.rankRewardFullPeople);
}

enum LeagueFewNotice {
  none,

  /// 10명 미만 — 승급 없음 · 보상 줄어듦.
  partial,

  /// 3명 미만(맨 아래 리그) — 순위 보상 없음.
  noReward,

  /// 3명 미만(위 리그) — 순위 보상 없음 · 결산 때 아래 리그로 합류.
  merge,
}
