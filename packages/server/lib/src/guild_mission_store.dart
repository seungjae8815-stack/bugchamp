import 'dart:convert';

import 'package:http/http.dart' as http;

import 'state_store.dart' show StateStoreException;

/// 미션을 도운 한 사람. [power] 는 **요구치 상한으로 자른 뒤의 몫**이다.
class GuildHelperRow {
  GuildHelperRow({
    required this.missionId,
    required this.userId,
    this.nickname = '',
    required this.power,
    required this.stage,
    required this.dayKey,
    required this.rewarded,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.utc(2000);

  final String missionId;
  final String userId;
  final String nickname;
  final double power;

  /// 돕던 때의 사냥터(스테이지) — 보상은 **돕는 사람 자기 사냥터** 기준.
  final int stage;
  final String dayKey;

  /// 하루 도움 보상 횟수 안에 들었는지(도운 순간 정한다).
  final bool rewarded;
  final DateTime createdAt;

  factory GuildHelperRow.fromJson(Map<String, dynamic> j) => GuildHelperRow(
    missionId: '${j['mission_id']}',
    userId: '${j['user_id']}',
    nickname: j['nickname'] as String? ?? '',
    power: (j['power'] as num?)?.toDouble() ?? 0,
    stage: (j['stage'] as num?)?.toInt() ?? 1,
    dayKey: j['day_key'] as String? ?? '',
    rewarded: j['rewarded'] == true,
    createdAt: DateTime.tryParse('${j['created_at']}')?.toUtc(),
  );

  Map<String, dynamic> toRow() => {
    'mission_id': missionId,
    'user_id': userId,
    'nickname': nickname,
    'power': power,
    'stage': stage,
    'day_key': dayKey,
    'rewarded': rewarded,
  };
}

/// 미션 한 건.
class GuildMissionRow {
  GuildMissionRow({
    this.id = '',
    required this.guildId,
    required this.owner,
    this.ownerNick = '',
    required this.dayKey,
    required this.slot,
    required this.kind,
    required this.mult,
    required this.waitSec,
    required this.needPower,
    required this.ownerPower,
    required this.ownerStage,
    required this.startedAt,
    required this.endsAt,
    this.settled = false,
    this.ratio = 0,
    this.success = false,
    this.solo = false,
    this.helperMax = 3,
    this.helpers = const [],
  });

  final String id;

  /// 길드가 없어지면 null(보상은 남는다).
  final String? guildId;
  final String owner;
  final String ownerNick;
  final String dayKey;
  final int slot;
  final String kind;
  final double mult;
  final int waitSec;
  final double needPower;
  final double ownerPower;
  final int ownerStage;
  final DateTime startedAt;
  final DateTime endsAt;
  final bool settled;
  final double ratio;
  final bool success;

  /// 혼자 출발 즉시 성공 — 대기 배율을 주지 않는다(바로 끝났는데 10분 배율을 받는 구멍).
  final bool solo;

  /// 도울 수 있는 인원 — DB 트리거가 이 값으로 자른다(JSON 과 트리거가 따로 놀지 않게 행에 적는다).
  final int helperMax;
  final List<GuildHelperRow> helpers;

  double get total =>
      ownerPower + helpers.fold<double>(0, (a, h) => a + h.power);

  factory GuildMissionRow.fromJson(Map<String, dynamic> j) => GuildMissionRow(
    id: '${j['id']}',
    guildId: j['guild_id']?.toString(),
    owner: '${j['owner']}',
    ownerNick: j['owner_nick'] as String? ?? '',
    dayKey: j['day_key'] as String? ?? '',
    slot: (j['slot'] as num?)?.toInt() ?? 0,
    kind: j['kind'] as String? ?? '',
    mult: (j['mult'] as num?)?.toDouble() ?? 1,
    waitSec: (j['wait_sec'] as num?)?.toInt() ?? 60,
    needPower: (j['need_power'] as num?)?.toDouble() ?? 0,
    ownerPower: (j['owner_power'] as num?)?.toDouble() ?? 0,
    ownerStage: (j['owner_stage'] as num?)?.toInt() ?? 1,
    startedAt:
        DateTime.tryParse('${j['started_at']}')?.toUtc() ?? DateTime.utc(2000),
    endsAt: DateTime.tryParse('${j['ends_at']}')?.toUtc() ?? DateTime.utc(2000),
    settled: j['settled'] == true,
    ratio: (j['ratio'] as num?)?.toDouble() ?? 0,
    success: j['success'] == true,
    solo: j['solo'] == true,
    helperMax: (j['helper_max'] as num?)?.toInt() ?? 3,
    helpers: [
      for (final h in (j['guild_mission_helpers'] as List? ?? const []))
        GuildHelperRow.fromJson(h as Map<String, dynamic>),
    ],
  );

  Map<String, dynamic> toRow() => {
    'guild_id': guildId,
    'owner': owner,
    'owner_nick': ownerNick,
    'day_key': dayKey,
    'slot': slot,
    'kind': kind,
    'mult': mult,
    'wait_sec': waitSec,
    'need_power': needPower,
    'owner_power': ownerPower,
    'owner_stage': ownerStage,
    'started_at': startedAt.toIso8601String(),
    'ends_at': endsAt.toIso8601String(),
    'settled': settled,
    'ratio': ratio,
    'success': success,
    'solo': solo,
    'helper_max': helperMax,
  };

  GuildMissionRow copyWith({
    String? id,
    DateTime? endsAt,
    bool? settled,
    double? ratio,
    bool? success,
    List<GuildHelperRow>? helpers,
  }) => GuildMissionRow(
    id: id ?? this.id,
    guildId: guildId,
    owner: owner,
    ownerNick: ownerNick,
    dayKey: dayKey,
    slot: slot,
    kind: kind,
    mult: mult,
    waitSec: waitSec,
    needPower: needPower,
    ownerPower: ownerPower,
    ownerStage: ownerStage,
    startedAt: startedAt,
    endsAt: endsAt ?? this.endsAt,
    settled: settled ?? this.settled,
    ratio: ratio ?? this.ratio,
    success: success ?? this.success,
    solo: solo,
    helperMax: helperMax,
    helpers: helpers ?? this.helpers,
  );
}

/// 길드 미션 테이블 접근(`docs/_sql_20261001_guild_missions.sql`). 규칙은 [GuildMissionActions].
abstract interface class GuildMissionStore {
  Future<GuildMissionRow> insertMission(GuildMissionRow m);
  Future<GuildMissionRow?> mission(String id);

  /// 길드의 미션([since] 이후 시작) — 도움 목록·오늘 결과.
  Future<List<GuildMissionRow>> guildMissions(String guildId, DateTime since);

  /// 내가 출발했거나 도운 미션([since] 이후) — 보상 받기·하루 횟수.
  Future<List<GuildMissionRow>> userMissions(String userId, DateTime since);

  /// 도움 넣기. 이미 도왔거나 자리가 찼으면(DB 트리거) false.
  Future<bool> insertHelper(GuildHelperRow h);

  /// 판정 — **아직 판정 전일 때만** 적는다. 이번 호출이 판정했으면 true(길드 경험치를 한 번만 주려고).
  Future<bool> settle(
    String id, {
    required double ratio,
    required bool success,
    DateTime? endsAt,
  });

  /// 보상 수령 기록(1회성). 이미 받았으면 false.
  Future<bool> insertClaim(String missionId, String userId);
  Future<Set<String>> claimedIds(String userId, DateTime since);

  /// 내가 출발한 [before] 이전 미션을 지운다(테이블 크기 방어 — 보상 기한이 지난 것).
  Future<void> deleteOwnedBefore(String userId, DateTime before);

  /// 길드 채팅에 도움 요청 카드(`#help:<id>`)를 넣는다. 실패해도 조용히 넘긴다(도배 트리거 등).
  Future<void> postHelpChat({
    required String guildId,
    required String userId,
    required String nickname,
    required String missionId,
  });
}

/// 채팅의 도움 요청 카드 본문 — 앱이 이 모양을 보면 말풍선 대신 "도와주기" 카드를 그린다.
String guildHelpChatBody(String missionId) => '#help:$missionId';

class SupabaseGuildMissionStore implements GuildMissionStore {
  SupabaseGuildMissionStore({
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
  String _ts(DateTime t) => Uri.encodeComponent(t.toUtc().toIso8601String());
  static const _withHelpers = 'select=*,guild_mission_helpers(*)';

  Future<List<Map<String, dynamic>>> _get(String q) async {
    final res = await _http.get(_rest(q), headers: _headers);
    if (res.statusCode >= 300) {
      throw StateStoreException('길드 미션 조회 실패: ${res.statusCode}');
    }
    return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
  }

  Future<http.Response> _post(
    String q,
    Object body, {
    String prefer = 'return=minimal',
  }) => _http.post(
    _rest(q),
    headers: {..._headers, 'Prefer': prefer},
    body: jsonEncode(body),
  );

  @override
  Future<GuildMissionRow> insertMission(GuildMissionRow m) async {
    final res = await _post('guild_missions', [
      m.toRow(),
    ], prefer: 'return=representation');
    if (res.statusCode >= 300) {
      throw StateStoreException('길드 미션 출발 실패: ${res.statusCode}');
    }
    final row = (jsonDecode(res.body) as List).first as Map<String, dynamic>;
    return GuildMissionRow.fromJson(row);
  }

  @override
  Future<GuildMissionRow?> mission(String id) async {
    final rows = await _get('guild_missions?id=${_eq(id)}&$_withHelpers');
    return rows.isEmpty ? null : GuildMissionRow.fromJson(rows.first);
  }

  @override
  Future<List<GuildMissionRow>> guildMissions(
    String guildId,
    DateTime since,
  ) async => [
    for (final r in await _get(
      'guild_missions?guild_id=${_eq(guildId)}&started_at=gte.${_ts(since)}'
      '&$_withHelpers&order=started_at.desc&limit=200',
    ))
      GuildMissionRow.fromJson(r),
  ];

  @override
  Future<List<GuildMissionRow>> userMissions(
    String userId,
    DateTime since,
  ) async {
    final owned = await _get(
      'guild_missions?owner=${_eq(userId)}&started_at=gte.${_ts(since)}'
      '&$_withHelpers&order=started_at.desc&limit=100',
    );
    final helped = await _get(
      'guild_mission_helpers?user_id=${_eq(userId)}'
      '&created_at=gte.${_ts(since)}&select=mission_id&limit=200',
    );
    final ids = {for (final h in helped) '${h['mission_id']}'};
    final extra = ids.isEmpty
        ? const <Map<String, dynamic>>[]
        : await _get('guild_missions?id=in.(${ids.join(',')})&$_withHelpers');
    return [
      for (final r in [...owned, ...extra]) GuildMissionRow.fromJson(r),
    ];
  }

  @override
  Future<bool> insertHelper(GuildHelperRow h) async {
    final res = await _post('guild_mission_helpers', [h.toRow()]);
    if (res.statusCode == 409) return false; // 이미 도왔다
    if (res.body.contains('helpers_full')) return false;
    if (res.statusCode >= 300) {
      throw StateStoreException('도와주기 실패: ${res.statusCode}');
    }
    return true;
  }

  @override
  Future<bool> settle(
    String id, {
    required double ratio,
    required bool success,
    DateTime? endsAt,
  }) async {
    final res = await _http.patch(
      _rest('guild_missions?id=${_eq(id)}&settled=eq.false'),
      headers: {..._headers, 'Prefer': 'return=representation'},
      body: jsonEncode({
        'settled': true,
        'ratio': ratio,
        'success': success,
        if (endsAt != null) 'ends_at': endsAt.toUtc().toIso8601String(),
      }),
    );
    if (res.statusCode >= 300) {
      throw StateStoreException('길드 미션 판정 실패: ${res.statusCode}');
    }
    return (jsonDecode(res.body) as List).isNotEmpty;
  }

  @override
  Future<bool> insertClaim(String missionId, String userId) async {
    final res = await _post('guild_mission_claims', [
      {'mission_id': missionId, 'user_id': userId},
    ]);
    if (res.statusCode == 409) return false;
    if (res.statusCode >= 300) {
      throw StateStoreException('미션 보상 기록 실패: ${res.statusCode}');
    }
    return true;
  }

  @override
  Future<Set<String>> claimedIds(String userId, DateTime since) async => {
    for (final r in await _get(
      'guild_mission_claims?user_id=${_eq(userId)}'
      '&claimed_at=gte.${_ts(since)}&select=mission_id',
    ))
      '${r['mission_id']}',
  };

  @override
  Future<void> deleteOwnedBefore(String userId, DateTime before) async {
    final res = await _http.delete(
      _rest('guild_missions?owner=${_eq(userId)}&started_at=lt.${_ts(before)}'),
      headers: _headers,
    );
    if (res.statusCode >= 300) {
      throw StateStoreException('지난 미션 정리 실패: ${res.statusCode}');
    }
  }

  @override
  Future<void> postHelpChat({
    required String guildId,
    required String userId,
    required String nickname,
    required String missionId,
  }) async {
    try {
      await _post('chat_messages', [
        {
          'user_id': userId,
          'nickname': nickname.isEmpty ? '?' : nickname,
          'body': guildHelpChatBody(missionId),
          'guild_id': guildId,
        },
      ]);
    } catch (_) {
      // 카드가 안 떠도 미션은 진행된다(길드 화면 목록에는 보인다).
    }
  }
}

/// 테스트용 메모리 구현.
class MemoryGuildMissionStore implements GuildMissionStore {
  final Map<String, GuildMissionRow> rows = {};
  final Set<String> claims = {};
  final List<String> chat = [];
  final int helperMax;
  var _seq = 0;

  MemoryGuildMissionStore({this.helperMax = 3});

  @override
  Future<GuildMissionRow> insertMission(GuildMissionRow m) async {
    final r = m.copyWith(id: 'm${++_seq}');
    rows[r.id] = r;
    return r;
  }

  @override
  Future<GuildMissionRow?> mission(String id) async => rows[id];

  @override
  Future<List<GuildMissionRow>> guildMissions(
    String guildId,
    DateTime since,
  ) async => [
    for (final m in rows.values)
      if (m.guildId == guildId && !m.startedAt.isBefore(since)) m,
  ];

  @override
  Future<List<GuildMissionRow>> userMissions(
    String userId,
    DateTime since,
  ) async => [
    for (final m in rows.values)
      if (!m.startedAt.isBefore(since) &&
          (m.owner == userId || m.helpers.any((h) => h.userId == userId)))
        m,
  ];

  @override
  Future<bool> insertHelper(GuildHelperRow h) async {
    final m = rows[h.missionId];
    if (m == null) return false;
    if (m.helpers.any((x) => x.userId == h.userId)) return false;
    if (m.helpers.length >= helperMax) return false;
    rows[m.id] = m.copyWith(helpers: [...m.helpers, h]);
    return true;
  }

  @override
  Future<bool> settle(
    String id, {
    required double ratio,
    required bool success,
    DateTime? endsAt,
  }) async {
    final m = rows[id];
    if (m == null || m.settled) return false;
    rows[id] = m.copyWith(
      settled: true,
      ratio: ratio,
      success: success,
      endsAt: endsAt,
    );
    return true;
  }

  @override
  Future<bool> insertClaim(String missionId, String userId) async =>
      claims.add('$missionId|$userId');

  @override
  Future<Set<String>> claimedIds(String userId, DateTime since) async => {
    for (final c in claims)
      if (c.endsWith('|$userId')) c.split('|').first,
  };

  @override
  Future<void> deleteOwnedBefore(String userId, DateTime before) async => rows
      .removeWhere((_, m) => m.owner == userId && m.startedAt.isBefore(before));

  @override
  Future<void> postHelpChat({
    required String guildId,
    required String userId,
    required String nickname,
    required String missionId,
  }) async => chat.add(guildHelpChatBody(missionId));
}
