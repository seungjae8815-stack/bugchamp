import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import 'state_store.dart' show StateStoreException;

/// 이번 주 길드 보스 한 마리.
class GuildBossRow {
  GuildBossRow({
    required this.week,
    required this.guildId,
    this.tier = 'bronze',
    this.stage = 1,
    required this.hpMax,
    required this.hpLeft,
    this.basePower = 0,
    this.estPower = 0,
  });

  final String week;
  final String guildId;

  /// 만들 때의 길드 티어 — 주간 순위는 이 티어 안에서 매긴다(주중 티어가 바뀌어도 흔들리지 않게).
  final String tier;
  final int stage;
  final double hpMax;
  final double hpLeft;

  /// 그 주에 공격한 길드원 몫의 합(2026-10-05~ — 공격할 때마다 늘어난 만큼 더한다).
  final double basePower;

  /// 만들 때 추정한 전투력 합(방어팀 있는 길드원). 체력 = max(이 값, [basePower]) × 단계 배율.
  final double estPower;

  double get progress => hpMax <= 0 ? 0 : (1 - hpLeft / hpMax).clamp(0.0, 1.0);

  factory GuildBossRow.fromJson(Map<String, dynamic> j) => GuildBossRow(
    week: '${j['week']}',
    guildId: '${j['guild_id']}',
    tier: j['tier'] as String? ?? 'bronze',
    stage: (j['stage'] as num?)?.toInt() ?? 1,
    hpMax: (j['hp_max'] as num?)?.toDouble() ?? 1,
    hpLeft: (j['hp_left'] as num?)?.toDouble() ?? 1,
    basePower: (j['base_power'] as num?)?.toDouble() ?? 0,
    estPower: (j['est_power'] as num?)?.toDouble() ?? 0,
  );
}

/// 이번 주 내 공격 기록.
class GuildBossHits {
  const GuildBossHits({
    required this.guildId,
    this.damage = 0,
    this.hits = 0,
    this.dayKey = '',
    this.dayHits = 0,
    this.power = 0,
  });
  final String guildId;
  final double damage;
  final int hits;
  final String dayKey;

  /// 그날 공격 수 — **유저 기준**(길드를 옮겨도 이어진다).
  final int dayHits;

  /// [guildId] 보스 체력에 이미 넣은 내 전투력.
  final double power;

  int hitsOn(String day) => dayKey == day ? dayHits : 0;

  factory GuildBossHits.fromJson(Map<String, dynamic> j) => GuildBossHits(
    guildId: '${j['guild_id']}',
    damage: (j['damage'] as num?)?.toDouble() ?? 0,
    hits: (j['hits'] as num?)?.toInt() ?? 0,
    dayKey: j['day_key'] as String? ?? '',
    dayHits: (j['day_hits'] as num?)?.toInt() ?? 0,
    power: (j['power'] as num?)?.toDouble() ?? 0,
  );
}

/// 공격 결과(원자적 RPC).
class GuildBossHitResult {
  const GuildBossHitResult({
    required this.ok,
    this.killed = 0,
    this.stage = 1,
    this.hpMax = 1,
    this.hpLeft = 1,
    this.hpHit = 1,
  });
  final bool ok;

  /// 이번 공격 순간의 최대 체력(내 몫을 더한 뒤) — 피해 구간 상자 비율의 분모.
  final double hpHit;

  /// 이번 공격으로 쓰러뜨린 단계 수(0 또는 1).
  final int killed;
  final int stage;
  final double hpMax;
  final double hpLeft;
}

/// 길드 보스 테이블(`docs/_sql_20261001_guild_boss.sql`). 규칙은 [GuildBossActions].
abstract interface class GuildBossStore {
  Future<GuildBossRow?> boss(String week, String guildId);

  /// 없으면 만든다(동시에 둘이 만들어도 하나만 남는다).
  Future<GuildBossRow> ensure(GuildBossRow row);

  /// 공격 — 하루 횟수 확인(유저 기준)·내 몫을 체력에 더하기([power] × [hpPerPower] × 현재 단계 배율,
  /// 이미 넣은 몫보다 세졌으면 차이만)·체력 차감·처치(다음 단계)·처치 코인(그 주 공격한 전원)을
  /// **한 번에**(SQL `guild_boss_hit_v2`).
  Future<GuildBossHitResult> hit({
    required String week,
    required String guildId,
    required String userId,
    required String day,
    required double damage,
    required double power,
    required double hpPerPower,
    required int maxDaily,
    required double growth,
    required int killCoinsPerStage,
  });

  Future<GuildBossHits?> hitsOf(String week, String userId);

  /// 같은 티어 안 순위(단계 → 피해율 → 먼저 도달). 기록이 없으면 null.
  Future<int?> rankOf(String week, String guildId);

  /// 같은 티어 상위 길드(순위표).
  Future<List<Map<String, dynamic>>> top(String week, String tier, int limit);

  /// 주간 순위 보상 수령 기록(1회성).
  Future<bool> insertClaim(String week, String userId);
  Future<bool> claimed(String week, String userId);

  /// 수령 기록 되돌리기 — 지급(서버 세이브 저장)이 실패했을 때.
  Future<void> deleteClaim(String week, String userId);
}

class SupabaseGuildBossStore implements GuildBossStore {
  SupabaseGuildBossStore({
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
      throw StateStoreException('길드 보스 조회 실패: ${res.statusCode}');
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
      throw StateStoreException('길드 보스 RPC $fn 실패: ${res.statusCode}');
    }
    return res.body.isEmpty ? null : jsonDecode(res.body);
  }

  @override
  Future<GuildBossRow?> boss(String week, String guildId) async {
    final rows = await _get(
      'guild_boss?week=${_eq(week)}&guild_id=${_eq(guildId)}&limit=1',
    );
    return rows.isEmpty ? null : GuildBossRow.fromJson(rows.first);
  }

  @override
  Future<GuildBossRow> ensure(GuildBossRow row) async {
    final res = await _http.post(
      _rest('guild_boss?on_conflict=week,guild_id'),
      headers: {
        ..._headers,
        'Prefer': 'resolution=ignore-duplicates,return=minimal',
      },
      body: jsonEncode([
        {
          'week': row.week,
          'guild_id': row.guildId,
          'tier': row.tier,
          'stage': row.stage,
          'hp_max': row.hpMax,
          'hp_left': row.hpLeft,
          'base_power': row.basePower,
          'est_power': row.estPower,
        },
      ]),
    );
    if (res.statusCode >= 300) {
      throw StateStoreException('길드 보스 만들기 실패: ${res.statusCode}');
    }
    return (await boss(row.week, row.guildId)) ?? row;
  }

  @override
  Future<GuildBossHitResult> hit({
    required String week,
    required String guildId,
    required String userId,
    required String day,
    required double damage,
    required double power,
    required double hpPerPower,
    required int maxDaily,
    required double growth,
    required int killCoinsPerStage,
  }) async {
    final r = await _rpc('guild_boss_hit_v2', {
      'p_week': week,
      'p_guild': guildId,
      'p_user': userId,
      'p_day': day,
      'p_damage': damage,
      'p_power': power,
      'p_hpm': hpPerPower,
      'p_max_daily': maxDaily,
      'p_growth': growth,
      'p_kill_coins': killCoinsPerStage,
    });
    final j = (r as Map).cast<String, dynamic>();
    return GuildBossHitResult(
      ok: j['ok'] == true,
      killed: (j['killed'] as num?)?.toInt() ?? 0,
      stage: (j['stage'] as num?)?.toInt() ?? 1,
      hpMax: (j['hp_max'] as num?)?.toDouble() ?? 1,
      hpLeft: (j['hp_left'] as num?)?.toDouble() ?? 1,
      hpHit: (j['hp_hit'] as num?)?.toDouble() ?? 1,
    );
  }

  @override
  Future<GuildBossHits?> hitsOf(String week, String userId) async {
    final rows = await _get(
      'guild_boss_hits?week=${_eq(week)}&user_id=${_eq(userId)}&limit=1',
    );
    return rows.isEmpty ? null : GuildBossHits.fromJson(rows.first);
  }

  @override
  Future<int?> rankOf(String week, String guildId) async {
    final r = await _rpc('guild_boss_rank', {
      'p_week': week,
      'p_guild': guildId,
    });
    return (r as num?)?.toInt();
  }

  @override
  Future<List<Map<String, dynamic>>> top(
    String week,
    String tier,
    int limit,
  ) async =>
      ((await _rpc('guild_boss_top', {
                'p_week': week,
                'p_tier': tier,
                'lim': limit,
              }))
              as List)
          .cast<Map<String, dynamic>>();

  @override
  Future<bool> claimed(String week, String userId) async => (await _get(
    'guild_boss_claims?week=${_eq(week)}&user_id=${_eq(userId)}&limit=1',
  )).isNotEmpty;

  @override
  Future<bool> insertClaim(String week, String userId) async {
    final res = await _http.post(
      _rest('guild_boss_claims'),
      headers: {..._headers, 'Prefer': 'return=minimal'},
      body: jsonEncode([
        {'week': week, 'user_id': userId},
      ]),
    );
    if (res.statusCode == 409) return false;
    if (res.statusCode >= 300) {
      throw StateStoreException('보스 보상 기록 실패: ${res.statusCode}');
    }
    return true;
  }

  @override
  Future<void> deleteClaim(String week, String userId) async {
    final res = await _http.delete(
      _rest('guild_boss_claims?week=${_eq(week)}&user_id=${_eq(userId)}'),
      headers: _headers,
    );
    if (res.statusCode >= 300) {
      throw StateStoreException('보스 보상 되돌리기 실패: ${res.statusCode}');
    }
  }
}

/// 테스트용 메모리 구현. 처치 코인은 [onKillCoins] 로 넘긴다(길드 저장소 쪽 코인).
class MemoryGuildBossStore implements GuildBossStore {
  MemoryGuildBossStore({this.onKillCoins, this.guildName});

  final Future<void> Function(String userId, int coins)? onKillCoins;
  final String Function(String guildId)? guildName;
  final Map<String, GuildBossRow> rows = {};
  final Map<String, GuildBossHits> hits = {};
  final Set<String> claims = {};
  final Map<String, int> order = {};
  var _seq = 0;

  String _k(String a, String b) => '$a|$b';

  @override
  Future<GuildBossRow?> boss(String week, String guildId) async =>
      rows[_k(week, guildId)];

  @override
  Future<GuildBossRow> ensure(GuildBossRow row) async =>
      rows.putIfAbsent(_k(row.week, row.guildId), () => row);

  @override
  Future<GuildBossHitResult> hit({
    required String week,
    required String guildId,
    required String userId,
    required String day,
    required double damage,
    required double power,
    required double hpPerPower,
    required int maxDaily,
    required double growth,
    required int killCoinsPerStage,
  }) async {
    var b = rows[_k(week, guildId)];
    if (b == null) return const GuildBossHitResult(ok: false);
    final h = hits[_k(week, userId)];
    // 하루 공격 수는 유저 기준(길드를 옮겨도 이어진다) — SQL guild_boss_hit_v2 와 같은 규칙.
    final today = h?.hitsOn(day) ?? 0;
    if (today >= maxDaily) return const GuildBossHitResult(ok: false);
    final same = h != null && h.guildId == guildId;
    final counted = same ? h.power : 0.0;
    final delta = math.max(0.0, power - counted);
    if (delta > 0) {
      final base = b.basePower + delta;
      final want =
          math.max(b.estPower, base) *
          hpPerPower *
          math.pow(growth, math.max(0, b.stage - 1));
      final grow = math.max(0.0, want - b.hpMax);
      b = GuildBossRow(
        week: week,
        guildId: guildId,
        tier: b.tier,
        stage: b.stage,
        hpMax: b.hpMax + grow,
        hpLeft: b.hpLeft + grow,
        basePower: base,
        estPower: b.estPower,
      );
    }
    hits[_k(week, userId)] = GuildBossHits(
      guildId: guildId,
      damage: (same ? h.damage : 0) + damage,
      hits: (same ? h.hits : 0) + 1,
      dayKey: day,
      dayHits: today + 1,
      power: math.max(counted, power),
    );
    final hpHit = b.hpMax;
    var left = b.hpLeft - damage;
    var stage = b.stage;
    var max = b.hpMax;
    var killed = 0;
    if (left <= 0) {
      killed = 1;
      for (final e in hits.entries) {
        if (e.key.startsWith('$week|') && e.value.guildId == guildId) {
          await onKillCoins?.call(
            e.key.split('|')[1],
            killCoinsPerStage * stage,
          );
        }
      }
      stage++;
      max = max * growth;
      left = max;
    }
    rows[_k(week, guildId)] = GuildBossRow(
      week: week,
      guildId: guildId,
      tier: b.tier,
      stage: stage,
      hpMax: max,
      hpLeft: left,
      basePower: b.basePower,
      estPower: b.estPower,
    );
    order[_k(week, guildId)] = ++_seq;
    return GuildBossHitResult(
      ok: true,
      killed: killed,
      stage: stage,
      hpMax: max,
      hpLeft: left,
      hpHit: hpHit,
    );
  }

  @override
  Future<GuildBossHits?> hitsOf(String week, String userId) async =>
      hits[_k(week, userId)];

  List<GuildBossRow> _ranked(String week, String tier) {
    final list = [
      for (final b in rows.values)
        if (b.week == week &&
            b.tier == tier &&
            (b.stage > 1 || b.hpLeft < b.hpMax))
          b,
    ];
    list.sort((a, b) {
      final s = b.stage.compareTo(a.stage);
      if (s != 0) return s;
      final p = b.progress.compareTo(a.progress);
      if (p != 0) return p;
      return (order[_k(week, a.guildId)] ?? 0).compareTo(
        order[_k(week, b.guildId)] ?? 0,
      );
    });
    return list;
  }

  @override
  Future<int?> rankOf(String week, String guildId) async {
    final b = rows[_k(week, guildId)];
    if (b == null) return null;
    final i = _ranked(week, b.tier).indexWhere((x) => x.guildId == guildId);
    return i < 0 ? null : i + 1;
  }

  @override
  Future<List<Map<String, dynamic>>> top(
    String week,
    String tier,
    int limit,
  ) async => [
    for (final (i, b) in _ranked(week, tier).take(limit).indexed)
      {
        'rank': i + 1,
        'guild_id': b.guildId,
        'name': guildName?.call(b.guildId) ?? '',
        'stage': b.stage,
        'progress': b.progress,
      },
  ];

  @override
  Future<bool> insertClaim(String week, String userId) async =>
      claims.add(_k(week, userId));

  @override
  Future<bool> claimed(String week, String userId) async =>
      claims.contains(_k(week, userId));

  @override
  Future<void> deleteClaim(String week, String userId) async =>
      claims.remove(_k(week, userId));
}
