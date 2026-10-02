import 'package:core_battle/core_battle.dart';
import 'package:core_run/core_run.dart';

import 'guild_actions.dart' show GuildResult;
import 'guild_store.dart';
import 'guild_war_store.dart';

/// 길드전(docs/design_guild.md §4) — 점수 기록 · 매칭 · 7일차 결투 · 결과 · 보상.
///
/// cron 이 없다: 매칭은 그 주 첫 조회 때, 결과는 7일차 첫 조회 때 한 번 적는다(DB 가 `result is null`
/// 조건으로 두 번 적히지 않게 막는다 — 등급점도 한 번만 바뀐다).
class GuildWarActions {
  GuildWarActions({
    required this.guilds,
    required this.store,
    required this.config,
    required this.now,
    required this.teamOf,
    required this.duelParams,
    required this.addExp,
  });

  final GuildStore guilds;
  final GuildWarStore store;
  final GuildConfig config;
  final DateTime Function() now;

  /// 결투 방어팀(서버 편성 검증을 거친 것). 없으면 null — 7일차에 짝이 되지 않는다.
  final Future<List<DuelBug>?> Function(String userId) teamOf;
  final DuelParams duelParams;
  final Future<void> Function(String guildId, int exp) addExp;

  GuildWarConfig get c => config.war;

  static GuildResult _err(String code, [int status = 409]) =>
      (status, {'error': code});

  String _dayKey(DateTime t) =>
      guildDayKey(t, anchorHour: config.mission.dayAnchorHourKst);

  // ── 점수 ──

  /// 앱이 60초 업로드에 실어 보낸 **그날 누적 행동 수**. 그날 주제에 맞는 것만, 멤버 하루 상한으로 자른다.
  /// 결투·보스 날은 무시한다(서버가 확정 결과로 센다). 위조해도 얻는 최대치 = 하루 상한.
  Future<void> recordTally(
    String userId,
    String dayKey,
    Map<String, int> counts,
  ) async {
    final t = now().toUtc();
    final week = guildWeekKey(t);
    if (!c.openOn(week) || dayKey != _dayKey(t)) return;
    final day = guildWarDayIndex(t, guildWeekStart(t));
    final def = c.dayDef(day);
    if (def == null || !GuildWarConfig.appCounted(def.theme)) return;
    final score = c.dayScore(day, counts);
    if (score <= 0) return;
    final mine = await guilds.membershipOf(userId);
    if (mine == null) return;
    await store.setScore(week, mine.guildId, userId, day, score);
  }

  /// 서버가 확정한 행동(결투 승리·보스 공격) — 그날 주제일 때만.
  Future<void> recordServerAction(String userId, String action) async {
    final t = now().toUtc();
    final week = guildWeekKey(t);
    if (!c.openOn(week)) return;
    final day = guildWarDayIndex(t, guildWeekStart(t));
    final def = c.dayDef(day);
    if (def == null || !GuildWarConfig.actionOn(def.theme, action)) return;
    final mine = await guilds.membershipOf(userId);
    if (mine == null) return;
    await store.addScore(
      week,
      mine.guildId,
      userId,
      day,
      c.points[action] ?? 0,
      def.cap,
    );
  }

  // ── 조회 ──

  Future<GuildResult> view(String userId) async {
    final mine = await guilds.membershipOf(userId);
    if (mine == null) return _err('not_in_guild');
    final g = await guilds.guild(mine.guildId);
    if (g == null) return _err('not_in_guild');
    final t = now().toUtc();
    final week = guildWeekKey(t);
    final start = guildWeekStart(t);
    final base = <String, dynamic>{
      'week': week,
      'open': c.openOn(week),
      'startWeek': c.startWeek,
      'tier': c.tierOf(g.gr).id,
      'gr': g.gr,
      'now': t.toIso8601String(),
      'endsAt': start.add(const Duration(days: 7)).toIso8601String(),
      'lastWeek': await _rewardInfo(userId, mine, t, current: false),
    };
    if (!c.openOn(week)) return (200, base);
    final day = guildWarDayIndex(t, start);
    final m = await store.match(
      week,
      g.id,
      c.minMembers,
      // 직전 상대 회피(2026-10-01 사장님 요청) — 같은 상대와 2주 연속 붙지 않게.
      prevWeek: guildWeekKey(t.subtract(const Duration(days: 7))),
    );
    if (m == null) {
      return (
        200,
        {...base, 'day': day, 'match': null, 'minMembers': c.minMembers},
      );
    }
    final result = day >= 7 ? await _resolve(m) : m.result;
    final a = m.sideA(g.id);
    final oppId = a ? m.guildB : m.guildA;
    final opp = oppId == null ? null : await guilds.guild(oppId);
    final mineTotals = await store.dayTotals(week, g.id);
    final oppTotals = oppId == null
        ? await store.tierAverage(week, a ? m.tierA : m.tierB)
        : await store.dayTotals(week, oppId);
    final def = c.dayDef(day);
    return (
      200,
      {
        ...base,
        'day': day,
        'theme': def?.theme,
        'cap': def?.cap ?? 0,
        'myToday': await store.myScore(week, userId, day),
        'match': {
          'opponent': opp?.name,
          'virtual': oppId == null,
          'mine': mineTotals.take(6).toList(),
          'theirs': oppTotals.take(6).toList(),
        },
        if (result != null) 'result': _relative(result, a),
        'reward': result == null
            ? null
            : await _rewardInfo(userId, mine, t, current: true),
      },
    );
  }

  /// 결과를 "내 길드 기준"으로 뒤집는다(A/B → 우리/상대).
  Map<String, dynamic> _relative(Map<String, dynamic> r, bool a) {
    int w(int x) => x < 0 ? -1 : (a ? x : 1 - x);
    return {
      'points': a ? r['pointsA'] : r['pointsB'],
      'theirPoints': a ? r['pointsB'] : r['pointsA'],
      'won': w((r['winner'] as num).toInt()) == 0,
      'draw': (r['winner'] as num).toInt() < 0,
      'clash': a ? r['clashA'] : r['clashB'],
      'theirClash': a ? r['clashB'] : r['clashA'],
      'days': [
        for (final d in (r['dayWinners'] as List)) w((d as num).toInt()),
      ],
      'pairs': [
        for (final p in (r['pairs'] as List? ?? const []))
          {
            'me': (p as Map)[a ? 'a' : 'b'],
            'them': p[a ? 'b' : 'a'],
            'won': a ? p['winA'] == true : p['winA'] == false,
          },
      ],
    };
  }

  // ── 7일차 · 결과 ──

  /// 7일차 대결을 돌리고 결과를 적는다(이미 있으면 그대로).
  Future<Map<String, dynamic>?> _resolve(GuildWarMatch m) async {
    if (m.result != null) return m.result;
    final dayA = await store.dayTotals(m.week, m.guildA);
    final dayB = m.guildB == null
        ? await store.tierAverage(m.week, m.tierA)
        : await store.dayTotals(m.week, m.guildB!);

    // 멤버를 방어팀 전투력 순으로 1:1. 인원이 다르면 남는 쪽은 부전승 없음(인원 늘리기 경쟁 방지).
    Future<List<({String nick, List<DuelBug> team, double power})>> side(
      String? gid,
    ) async {
      if (gid == null) return const [];
      final out = <({String nick, List<DuelBug> team, double power})>[];
      for (final mem in await guilds.members(gid)) {
        final team = await teamOf(mem.userId);
        if (team == null || team.isEmpty) continue;
        final p = team.fold<double>(
          0,
          (a, x) => a + x.atk + x.def + x.spd + x.maxHp * 0.15,
        );
        out.add((nick: mem.nickname, team: team, power: p));
      }
      out.sort((x, y) => y.power.compareTo(x.power));
      return out;
    }

    final sa = await side(m.guildA);
    final sb = await side(m.guildB);
    var clashA = 0, clashB = 0;
    final pairs = <Map<String, dynamic>>[];
    final seed0 = fnv1a32('war|${m.id}');
    if (m.guildB == null) {
      // 가상 길드 — 한 판씩 동전(seed 고정 — 다시 조회해도 같다).
      for (var i = 0; i < sa.length; i++) {
        final winA = (fnv1a32('$seed0|$i') & 1) == 0;
        winA ? clashA++ : clashB++;
        pairs.add({'a': sa[i].nick, 'b': null, 'winA': winA});
      }
    } else {
      final n = sa.length < sb.length ? sa.length : sb.length;
      for (var i = 0; i < n; i++) {
        final duel = simulateDuel(
          seed: fnv1a32('$seed0|$i'),
          teamA: sa[i].team,
          teamB: sb[i].team,
          params: duelParams,
        );
        final winA = duel.winsA > duel.winsB;
        winA ? clashA++ : clashB++;
        pairs.add({'a': sa[i].nick, 'b': sb[i].nick, 'winA': winA});
      }
    }
    final o = guildWarOutcome(
      c,
      dayA: dayA.take(6).toList(),
      dayB: dayB.take(6).toList(),
      clashA: clashA,
      clashB: clashB,
    );
    final result = {
      'dayA': dayA.take(6).toList(),
      'dayB': dayB.take(6).toList(),
      'clashA': clashA,
      'clashB': clashB,
      'pointsA': o.pointsA,
      'pointsB': o.pointsB,
      'winner': o.winner,
      'dayWinners': o.dayWinners,
      'pairs': pairs,
    };
    if (await store.saveResult(m.id, result)) {
      await _applyGr(
        m.guildA,
        o.winner == 0 ? c.grWin : (o.winner == 1 ? c.grLose : 0),
      );
      if (m.guildB != null) {
        await _applyGr(
          m.guildB!,
          o.winner == 1 ? c.grWin : (o.winner == 0 ? c.grLose : 0),
        );
      }
      return result;
    }
    // 다른 요청이 먼저 적었다 — 그걸 쓴다.
    return (await store.matchOf(m.week, m.guildA))?.result ?? result;
  }

  Future<void> _applyGr(String guildId, int delta) async {
    final g = await guilds.guild(guildId);
    if (g == null) return;
    final gr = (g.gr + delta).clamp(0, 1 << 30);
    await guilds.updateGuild(guildId, {'gr': gr, 'tier': c.tierOf(gr).id});
    await addExp(guildId, 50);
  }

  // ── 보상 ──

  /// [current] 면 이번 주(7일차에 결과가 나온 뒤), 아니면 지난주.
  Future<Map<String, dynamic>?> _rewardInfo(
    String userId,
    GuildMemberRow mine,
    DateTime t, {
    required bool current,
  }) async {
    final ref = current ? t : t.subtract(const Duration(days: 7));
    final week = guildWeekKey(ref);
    final m = await store.matchOf(week, mine.guildId);
    if (m == null || m.result == null) return null;
    final start = guildWeekStart(ref);
    // 자격: 그 주 월 09시 **전에** 가입 + 그 주 점수 1 이상(보상 사냥 방지).
    final eligible =
        !mine.joinedAt.isAfter(start) &&
        (await store.scoredMembers(week, mine.guildId)).contains(userId);
    final a = m.sideA(mine.guildId);
    final winner = (m.result!['winner'] as num).toInt();
    final won = winner < 0 || (a ? winner == 0 : winner == 1);
    final tier = c.tierById(a ? m.tierA : m.tierB) ?? c.tierOf(0);
    final share = won ? 1.0 : c.loseShare;
    return {
      'week': week,
      'won': won,
      'eligible': eligible,
      'coins': (tier.coins * share).round(),
      'jelly': (tier.jelly * share).round(),
      'claimed': await store.claimed(week, userId),
    };
  }

  /// 받을 수 있는 대전 보상(이번 주 결과 → 없으면 지난주). 코인은 여기서 넣고 젤리 양을 돌려준다.
  Future<(int, Map<String, dynamic>, int)> claim(String userId) async {
    final mine = await guilds.membershipOf(userId);
    if (mine == null)
      return (409, <String, dynamic>{'error': 'not_in_guild'}, 0);
    final t = now().toUtc();
    for (final current in [true, false]) {
      final r = await _rewardInfo(userId, mine, t, current: current);
      if (r == null || r['eligible'] != true || r['claimed'] == true) continue;
      if (!await store.insertClaim(r['week'] as String, userId)) continue;
      await guilds.addCoins(userId, r['coins'] as int);
      return (
        200,
        <String, dynamic>{'coins': r['coins'], 'won': r['won']},
        r['jelly'] as int,
      );
    }
    return (409, <String, dynamic>{'error': 'nothing_to_claim'}, 0);
  }
}
