import 'dart:convert';

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
  Future<void> setScore(
    String week,
    String guildId,
    String userId,
    int day,
    int score,
  );

  /// 그날 점수에 더한다(상한까지) — 서버가 확정한 결투 승리·보스 공격.
  Future<void> addScore(
    String week,
    String guildId,
    String userId,
    int day,
    int add,
    int cap,
  );

  Future<int> myScore(String week, String userId, int day);

  /// 길드의 1~7일차 합(인덱스 0 = 1일차).
  Future<List<int>> dayTotals(String week, String guildId);

  /// 같은 티어 길드들의 일차별 평균 합(가상 길드 점수).
  Future<List<int>> tierAverage(String week, String tier);

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

  /// 결과를 **아직 없을 때만** 적는다. 이번 호출이 적었으면 true(등급점을 한 번만 바꾸려고).
  Future<bool> saveResult(String matchId, Map<String, dynamic> result);

  /// 그 주에 점수를 1 이상 낸 길드원.
  Future<Set<String>> scoredMembers(String week, String guildId);

  Future<bool> insertClaim(String week, String userId);
  Future<bool> claimed(String week, String userId);
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

  List<int> _days(dynamic rows) {
    final out = List.filled(7, 0);
    for (final r in (rows as List? ?? const [])) {
      final m = (r as Map).cast<String, dynamic>();
      final d = (m['day'] as num).toInt();
      if (d >= 1 && d <= 7) out[d - 1] = (m['total'] as num).round();
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
  ) => _rpc('guild_war_set', {
    'p_week': week,
    'p_guild': guildId,
    'p_user': userId,
    'p_day': day,
    'p_score': score,
  });

  @override
  Future<void> addScore(
    String week,
    String guildId,
    String userId,
    int day,
    int add,
    int cap,
  ) => _rpc('guild_war_add', {
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
  Future<List<int>> dayTotals(String week, String guildId) async => _days(
    await _rpc('guild_war_totals', {'p_week': week, 'p_guild': guildId}),
  );

  @override
  Future<List<int>> tierAverage(String week, String tier) async =>
      _days(await _rpc('guild_war_tier_avg', {'p_week': week, 'p_tier': tier}));

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
}

/// 테스트용 메모리 구현. [membersOf]·[guildOf] 로 인원·티어·등급점을 본다.
class MemoryGuildWarStore implements GuildWarStore {
  MemoryGuildWarStore({required this.membersOf, required this.guildOf});

  final int Function(String guildId) membersOf;
  final ({String tier, int gr})? Function(String guildId) guildOf;

  /// (week|guild|user|day) → 점수.
  final Map<String, int> scores = {};
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
  ) async {
    final k = '$week|$guildId|$userId|$day';
    if ((scores[k] ?? 0) < score) scores[k] = score;
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
    final k = '$week|$guildId|$userId|$day';
    scores[k] = ((scores[k] ?? 0) + add).clamp(0, cap);
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
  Future<List<int>> dayTotals(String week, String guildId) async {
    final out = List.filled(7, 0);
    for (final e in scores.entries) {
      final p = e.key.split('|');
      if (p[0] == week && p[1] == guildId) {
        out[int.parse(p[3]) - 1] += e.value;
      }
    }
    return out;
  }

  @override
  Future<List<int>> tierAverage(String week, String tier) async {
    final guilds = {
      for (final k in scores.keys)
        if (k.startsWith('$week|')) k.split('|')[1],
    }.where((g) => guildOf(g)?.tier == tier).toList();
    final out = List.filled(7, 0);
    if (guilds.isEmpty) return out;
    for (final g in guilds) {
      final t = await dayTotals(week, g);
      for (var i = 0; i < 7; i++) {
        out[i] += t[i];
      }
    }
    return [for (final v in out) (v / guilds.length).round()];
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
}
