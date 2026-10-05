import 'dart:convert';

import 'package:core_run/core_run.dart' show GuildWarDayStat;
import 'package:http/http.dart' as http;

import 'state_store.dart' show StateStoreException;

/// 이번 주 대전 한 판. [guildB] 가 null 이면 가상 길드(같은 티어 평균을 따라 한다).
class GuildWarMatch {
  GuildWarMatch({
    required this.id,
    required this.week,
    required this.guildA,
    this.guildB,
    this.tierA = 'bronze',
    this.tierB = 'bronze',
    this.result,
  });

  final String id;
  final String week;
  final String guildA;
  final String? guildB;

  /// 매칭 때 티어 — 보상은 이 티어로 준다.
  final String tierA;
  final String tierB;

  /// 7일차에 한 번 적는다(null = 아직).
  final Map<String, dynamic>? result;

  bool sideA(String guildId) => guildA == guildId;

  factory GuildWarMatch.fromJson(Map<String, dynamic> j) => GuildWarMatch(
    id: '${j['id']}',
    week: '${j['week']}',
    guildA: '${j['guild_a']}',
    guildB: j['guild_b']?.toString(),
    tierA: j['tier_a'] as String? ?? 'bronze',
    tierB: j['tier_b'] as String? ?? 'bronze',
    result: (j['result'] as Map?)?.cast<String, dynamic>(),
  );
}

/// 길드전 테이블(`docs/_sql_20261001_guild_war.sql`). 규칙은 [GuildWarActions].
abstract interface class GuildWarStore {
  /// 그날 점수를 **올리기만** 한다(앱 누적값 — 같은 값을 두 번 보내도 한 번).
  /// [score] 는 그날 내 행동 전체 기준이라, **같은 날 다른 길드에서 이미 받은 몫을 빼고** 넣는다 —
  /// 같은 사람·같은 날은 길드를 옮겨도 합쳐서 [cap] 까지(2026-10-05, SQL `guild_war_set_v2`).
  Future<void> setScore(
    String week,
    String guildId,
    String userId,
    int day,
    int score,
    int cap,
  );

  /// 그날 점수에 더한다 — 서버가 확정한 결투 승리·보스 공격. 같은 날 다른 길드 몫과 합쳐 [cap] 까지.
  Future<void> addScore(
    String week,
    String guildId,
    String userId,
    int day,
    int add,
    int cap,
  );

  Future<int> myScore(String week, String userId, int day);

  /// 길드의 1~7일차 성적(인덱스 0 = 1일차) — 합 · 점수 낸 인원 · 그 합에 도달한 시각.
  Future<List<GuildWarDayStat>> dayStats(String week, String guildId);

  /// 같은 티어 길드들의 일차별 평균(가상 길드 성적 — 도달 시각은 없다).
  Future<List<GuildWarDayStat>> tierAverageStats(String week, String tier);

  /// 이번 주 대전 — 없으면 매칭해서 만든다. 고르는 순서: **[prevWeek] 주 상대가 아닌 길드**(직전 상대 회피,
  /// 다른 후보가 없으면 다시 붙는다 — 가상 길드보다 낫다) → 같은 티어 → 가까운 등급점, 아무도 없으면 가상.
  /// 인원 미달이면 null.
  Future<GuildWarMatch?> match(
    String week,
    String guildId,
    int minMembers, {
    String? prevWeek,
  });

  /// 이미 있는 대전만(만들지 않는다).
  Future<GuildWarMatch?> matchOf(String week, String guildId);

  /// 판정을 맡는다 — 결과가 아직 없고 다른 요청이 판정 중이 아니면(멈춘 지 오래면 다시) true.
  /// 결투 30판을 여러 요청이 동시에 돌리지 않게 **계산 전에** 잡는다(SQL `guild_war_resolve_lock`).
  Future<bool> tryLockResolve(String matchId);

  /// 결과를 **아직 없을 때만** 적는다. 이번 호출이 적었으면 true(등급점을 한 번만 바꾸려고).
  Future<bool> saveResult(String matchId, Map<String, dynamic> result);

  /// 그 주에 점수를 1 이상 낸 길드원.
  Future<Set<String>> scoredMembers(String week, String guildId);

  Future<bool> insertClaim(String week, String userId);
  Future<bool> claimed(String week, String userId);

  /// 수령 기록 되돌리기 — 지급(서버 세이브 저장)이 실패했을 때.
  Future<void> deleteClaim(String week, String userId);
}

class SupabaseGuildWarStore implements GuildWarStore {
  SupabaseGuildWarStore({
    required this.supabaseUrl,
    required this.serviceRoleKey,
    http.Client? client,
  }) : _http = client ?? http.Client();

  final String supabaseUrl;
  final String serviceRoleKey;
  final http.Client _http;

  Map<String, String> get _headers => {
    'apikey': serviceRoleKey,
    'Authorization': 'Bearer $serviceRoleKey',
    'Content-Type': 'application/json',
  };

  Uri _rest(String q) => Uri.parse('$supabaseUrl/rest/v1/$q');
  String _eq(String v) => 'eq.${Uri.encodeComponent(v)}';

  Future<List<Map<String, dynamic>>> _get(String q) async {
    final res = await _http.get(_rest(q), headers: _headers);
    if (res.statusCode >= 300) {
      throw StateStoreException('길드전 조회 실패: ${res.statusCode}');
    }
    return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
  }

  Future<dynamic> _rpc(String fn, Map<String, dynamic> args) async {
    final res = await _http.post(
      _rest('rpc/$fn'),
      headers: _headers,
      body: jsonEncode(args),
    );
    if (res.statusCode >= 300) {
      throw StateStoreException('길드전 RPC $fn 실패: ${res.statusCode}');
    }
    return res.body.isEmpty ? null : jsonDecode(res.body);
  }

  List<GuildWarDayStat> _days(dynamic rows) {
    final out = List.filled(7, const GuildWarDayStat());
    for (final r in (rows as List? ?? const [])) {
      final m = (r as Map).cast<String, dynamic>();
      final d = (m['day'] as num).toInt();
      if (d < 1 || d > 7) continue;
      out[d - 1] = GuildWarDayStat(
        total: (m['total'] as num?)?.round() ?? 0,
        members: (m['members'] as num?)?.round() ?? 0,
        reachedAt: m['last_at'] == null
            ? null
            : DateTime.tryParse('${m['last_at']}')?.toUtc(),
      );
    }
    return out;
  }

  @override
  Future<void> setScore(
    String week,
    String guildId,
    String userId,
    int day,
    int score,
    int cap,
  ) => _rpc('guild_war_set_v2', {
    'p_week': week,
    'p_guild': guildId,
    'p_user': userId,
    'p_day': day,
    'p_score': score,
    'p_cap': cap,
  });

  @override
  Future<void> addScore(
    String week,
    String guildId,
    String userId,
    int day,
    int add,
    int cap,
  ) => _rpc('guild_war_add_v2', {
    'p_week': week,
    'p_guild': guildId,
    'p_user': userId,
    'p_day': day,
    'p_add': add,
    'p_cap': cap,
  });

  @override
  Future<int> myScore(String week, String userId, int day) async {
    final rows = await _get(
      'guild_war_scores?week=${_eq(week)}&user_id=${_eq(userId)}'
      '&day=eq.$day&select=score',
    );
    return rows.fold<int>(0, (a, r) => a + (r['score'] as num).toInt());
  }

  @override
  Future<List<GuildWarDayStat>> dayStats(String week, String guildId) async =>
      _days(
        await _rpc('guild_war_day_stats', {'p_week': week, 'p_guild': guildId}),
      );

  @override
  Future<List<GuildWarDayStat>> tierAverageStats(
    String week,
    String tier,
  ) async => _days(
    await _rpc('guild_war_tier_avg_stats', {'p_week': week, 'p_tier': tier}),
  );

  @override
  Future<GuildWarMatch?> match(
    String week,
    String guildId,
    int minMembers, {
    String? prevWeek,
  }) async {
    final r = await _rpc('guild_war_match', {
      'p_week': week,
      'p_guild': guildId,
      'p_min': minMembers,
      'p_prev': ?prevWeek,
    });
    if (r is! Map) return null;
    return GuildWarMatch.fromJson(r.cast<String, dynamic>());
  }

  @override
  Future<GuildWarMatch?> matchOf(String week, String guildId) async {
    final g = Uri.encodeComponent(guildId);
    final rows = await _get(
      'guild_war_matches?week=${_eq(week)}'
      '&or=(guild_a.eq.$g,guild_b.eq.$g)&limit=1',
    );
    return rows.isEmpty ? null : GuildWarMatch.fromJson(rows.first);
  }

  @override
  Future<bool> tryLockResolve(String matchId) async =>
      (await _rpc('guild_war_resolve_lock', {'p_match': matchId})) == true;

  @override
  Future<bool> saveResult(String matchId, Map<String, dynamic> result) async {
    final res = await _http.patch(
      _rest('guild_war_matches?id=${_eq(matchId)}&result=is.null'),
      headers: {..._headers, 'Prefer': 'return=representation'},
      body: jsonEncode({'result': result}),
    );
    if (res.statusCode >= 300) {
      throw StateStoreException('길드전 결과 기록 실패: ${res.statusCode}');
    }
    return (jsonDecode(res.body) as List).isNotEmpty;
  }

  @override
  Future<Set<String>> scoredMembers(String week, String guildId) async => {
    for (final r in await _get(
      'guild_war_scores?week=${_eq(week)}&guild_id=${_eq(guildId)}'
      '&score=gt.0&select=user_id',
    ))
      '${r['user_id']}',
  };

  @override
  Future<bool> insertClaim(String week, String userId) async {
    final res = await _http.post(
      _rest('guild_war_claims'),
      headers: {..._headers, 'Prefer': 'return=minimal'},
      body: jsonEncode([
        {'week': week, 'user_id': userId},
      ]),
    );
    if (res.statusCode == 409) return false;
    if (res.statusCode >= 300) {
      throw StateStoreException('길드전 보상 기록 실패: ${res.statusCode}');
    }
    return true;
  }

  @override
  Future<bool> claimed(String week, String userId) async => (await _get(
    'guild_war_claims?week=${_eq(week)}&user_id=${_eq(userId)}&limit=1',
  )).isNotEmpty;

  @override
  Future<void> deleteClaim(String week, String userId) async {
    final res = await _http.delete(
      _rest('guild_war_claims?week=${_eq(week)}&user_id=${_eq(userId)}'),
      headers: _headers,
    );
    if (res.statusCode >= 300) {
      throw StateStoreException('길드전 보상 되돌리기 실패: ${res.statusCode}');
    }
  }
}

/// 테스트용 메모리 구현. [membersOf]·[guildOf] 로 인원·티어·등급점을 본다.
class MemoryGuildWarStore implements GuildWarStore {
  MemoryGuildWarStore({
    required this.membersOf,
    required this.guildOf,
    DateTime Function()? clock,
  }) : _clock = clock ?? (() => DateTime.now().toUtc());

  final int Function(String guildId) membersOf;
  final ({String tier, int gr})? Function(String guildId) guildOf;
  final DateTime Function() _clock;

  /// (week|guild|user|day) → 점수.
  final Map<String, int> scores = {};

  /// (week|guild|user|day) → 점수가 마지막으로 오른 시각.
  final Map<String, DateTime> touched = {};

  /// 판정 중 표시(경기 id).
  final Set<String> resolving = {};

  /// 같은 사람·같은 날, [guildId] 밖에서 받은 점수 합.
  int _other(String week, String guildId, String userId, int day) => scores
      .entries
      .where((e) {
        final p = e.key.split('|');
        return p[0] == week &&
            p[1] != guildId &&
            p[2] == userId &&
            p[3] == '$day';
      })
      .fold<int>(0, (a, e) => a + e.value);

  void _put(String k, int v) {
    if ((scores[k] ?? 0) >= v) return;
    scores[k] = v;
    touched[k] = _clock();
  }

  final List<GuildWarMatch> matches = [];
  final Set<String> claims = {};
  var _seq = 0;

  @override
  Future<void> setScore(
    String week,
    String guildId,
    String userId,
    int day,
    int score,
    int cap,
  ) async {
    final allowed =
        score.clamp(0, cap < 0 ? 0 : cap) - _other(week, guildId, userId, day);
    if (allowed <= 0) return;
    _put('$week|$guildId|$userId|$day', allowed);
  }

  @override
  Future<void> addScore(
    String week,
    String guildId,
    String userId,
    int day,
    int add,
    int cap,
  ) async {
    final room = cap - _other(week, guildId, userId, day);
    if (room <= 0 || add <= 0) return;
    final k = '$week|$guildId|$userId|$day';
    _put(k, ((scores[k] ?? 0) + add).clamp(0, room));
  }

  @override
  Future<int> myScore(String week, String userId, int day) async => scores
      .entries
      .where((e) {
        final p = e.key.split('|');
        return p[0] == week && p[2] == userId && p[3] == '$day';
      })
      .fold<int>(0, (a, e) => a + e.value);

  @override
  Future<List<GuildWarDayStat>> dayStats(String week, String guildId) async {
    final total = List.filled(7, 0);
    final members = List.filled(7, 0);
    final at = List<DateTime?>.filled(7, null);
    for (final e in scores.entries) {
      final p = e.key.split('|');
      if (p[0] != week || p[1] != guildId) continue;
      final i = int.parse(p[3]) - 1;
      total[i] += e.value;
      if (e.value <= 0) continue;
      members[i]++;
      final t = touched[e.key];
      if (t != null && (at[i] == null || t.isAfter(at[i]!))) at[i] = t;
    }
    return [
      for (var i = 0; i < 7; i++)
        GuildWarDayStat(total: total[i], members: members[i], reachedAt: at[i]),
    ];
  }

  @override
  Future<List<GuildWarDayStat>> tierAverageStats(
    String week,
    String tier,
  ) async {
    final guilds = {
      for (final k in scores.keys)
        if (k.startsWith('$week|')) k.split('|')[1],
    }.where((g) => guildOf(g)?.tier == tier).toList();
    if (guilds.isEmpty) return List.filled(7, const GuildWarDayStat());
    final total = List.filled(7, 0);
    final members = List.filled(7, 0);
    for (final g in guilds) {
      final t = await dayStats(week, g);
      for (var i = 0; i < 7; i++) {
        total[i] += t[i].total;
        members[i] += t[i].members;
      }
    }
    return [
      for (var i = 0; i < 7; i++)
        GuildWarDayStat(
          total: (total[i] / guilds.length).round(),
          members: (members[i] / guilds.length).round(),
        ),
    ];
  }

  @override
  Future<GuildWarMatch?> match(
    String week,
    String guildId,
    int minMembers, {
    String? prevWeek,
  }) async {
    final have = await matchOf(week, guildId);
    if (have != null) return have;
    if (membersOf(guildId) < minMembers) return null;
    final me = guildOf(guildId);
    final last = prevWeek == null ? null : await matchOf(prevWeek, guildId);
    final prevOpp = last == null
        ? null
        : (last.guildA == guildId ? last.guildB : last.guildA);
    final busy = {
      for (final m in matches)
        if (m.week == week) ...[m.guildA, ?m.guildB],
    };
    final candidates =
        [
          for (final g in _allGuilds())
            if (g != guildId && !busy.contains(g) && membersOf(g) >= minMembers)
              g,
        ]..sort((a, b) {
          final pa = a == prevOpp ? 1 : 0;
          final pb = b == prevOpp ? 1 : 0;
          if (pa != pb) return pa - pb;
          final ta = guildOf(a)?.tier == me?.tier ? 0 : 1;
          final tb = guildOf(b)?.tier == me?.tier ? 0 : 1;
          if (ta != tb) return ta - tb;
          return ((guildOf(a)?.gr ?? 0) - (me?.gr ?? 0)).abs().compareTo(
            ((guildOf(b)?.gr ?? 0) - (me?.gr ?? 0)).abs(),
          );
        });
    final opp = candidates.firstOrNull;
    final m = GuildWarMatch(
      id: 'w${++_seq}',
      week: week,
      guildA: guildId,
      guildB: opp,
      tierA: me?.tier ?? 'bronze',
      tierB: opp == null
          ? (me?.tier ?? 'bronze')
          : (guildOf(opp)?.tier ?? 'bronze'),
    );
    matches.add(m);
    return m;
  }

  /// 테스트가 등록한 길드 목록(매칭 후보).
  final List<String> knownGuilds = [];
  List<String> _allGuilds() => knownGuilds;

  @override
  Future<GuildWarMatch?> matchOf(String week, String guildId) async => matches
      .where(
        (m) => m.week == week && (m.guildA == guildId || m.guildB == guildId),
      )
      .firstOrNull;

  @override
  Future<bool> tryLockResolve(String matchId) async {
    final m = matches.where((m) => m.id == matchId).firstOrNull;
    if (m == null || m.result != null) return false;
    return resolving.add(matchId);
  }

  @override
  Future<bool> saveResult(String matchId, Map<String, dynamic> result) async {
    final i = matches.indexWhere((m) => m.id == matchId);
    if (i < 0 || matches[i].result != null) return false;
    final m = matches[i];
    matches[i] = GuildWarMatch(
      id: m.id,
      week: m.week,
      guildA: m.guildA,
      guildB: m.guildB,
      tierA: m.tierA,
      tierB: m.tierB,
      result: result,
    );
    return true;
  }

  @override
  Future<Set<String>> scoredMembers(String week, String guildId) async => {
    for (final e in scores.entries)
      if (e.key.startsWith('$week|$guildId|') && e.value > 0)
        e.key.split('|')[2],
  };

  @override
  Future<bool> insertClaim(String week, String userId) async =>
      claims.add('$week|$userId');

  @override
  Future<bool> claimed(String week, String userId) async =>
      claims.contains('$week|$userId');

  @override
  Future<void> deleteClaim(String week, String userId) async =>
      claims.remove('$week|$userId');
}
