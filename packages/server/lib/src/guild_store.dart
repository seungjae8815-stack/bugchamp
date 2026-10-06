import 'dart:convert';

import 'package:core_run/core_run.dart';
import 'package:http/http.dart' as http;

import 'state_store.dart' show StateStoreException;

/// 길드 한 줄(목록·상세 공용). 인원·평균 전투력은 목록 RPC 가 세어 준다.
class GuildRow {
  GuildRow({
    required this.id,
    required this.name,
    this.lang = 'ko',
    this.level = 1,
    this.exp = 0,
    this.maxMembers = 20,
    this.joinMode = GuildJoinMode.open,
    this.notice = '',
    this.leader = '',
    this.skills = const {},
    this.deputyCanAccept = true,
    this.tier = 'bronze',
    this.gr = 0,
    this.memberCount = 0,
    this.avgPower = 0,
    this.emblem,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.utc(2000);

  final String id;
  final String name;
  final String lang;
  final int level;
  final int exp;
  final int maxMembers;
  final GuildJoinMode joinMode;
  final String notice;
  final String leader;

  /// 길드 버프 스킬 레벨(스킬 id → 레벨). DB `skill_points`.
  final Map<String, int> skills;

  /// 부길드장이 가입 신청을 수락·거절할 수 있는지(길드장 스위치, 기본 켜짐). DB `deputy_can_accept`.
  final bool deputyCanAccept;

  /// 길드전 티어·등급점(5단계).
  final String tier;
  final int gr;
  final int memberCount;
  final double avgPower;

  /// 길드 문장(1~10, DB `emblem`). null = 고른 적 없음(옛 길드 · SQL 적용 전) — 앱이 id 해시로 기본 문장을 보인다.
  final int? emblem;
  final DateTime createdAt;

  bool get full => memberCount >= maxMembers;

  factory GuildRow.fromJson(Map<String, dynamic> j) => GuildRow(
    id: '${j['id']}',
    name: j['name'] as String? ?? '',
    lang: j['lang'] as String? ?? 'ko',
    level: (j['level'] as num?)?.toInt() ?? 1,
    exp: (j['exp'] as num?)?.toInt() ?? 0,
    maxMembers: (j['max_members'] as num?)?.toInt() ?? 20,
    joinMode: GuildJoinMode.fromKey(j['join_mode'] as String?),
    notice: j['notice'] as String? ?? '',
    leader: j['leader'] as String? ?? '',
    skills: {
      for (final e in ((j['skill_points'] as Map?) ?? const {}).entries)
        '${e.key}': (e.value as num).toInt(),
    },
    // 칸이 없는 옛 RPC(SQL 적용 전)면 기본값 = 켜짐.
    deputyCanAccept: j['deputy_can_accept'] as bool? ?? true,
    tier: j['tier'] as String? ?? 'bronze',
    gr: (j['gr'] as num?)?.toInt() ?? 0,
    memberCount: (j['member_count'] as num?)?.toInt() ?? 0,
    avgPower: (j['avg_power'] as num?)?.toDouble() ?? 0,
    // 칸이 없는 옛 RPC(SQL ⑧ 적용 전)면 null.
    emblem: (j['emblem'] as num?)?.toInt(),
    createdAt: DateTime.tryParse('${j['created_at']}')?.toUtc(),
  );

  GuildRow copyWith({
    int? level,
    int? exp,
    int? maxMembers,
    GuildJoinMode? joinMode,
    String? notice,
    String? leader,
    Map<String, int>? skills,
    bool? deputyCanAccept,
    String? tier,
    int? gr,
    int? emblem,
  }) => GuildRow(
    id: id,
    name: name,
    lang: lang,
    level: level ?? this.level,
    exp: exp ?? this.exp,
    maxMembers: maxMembers ?? this.maxMembers,
    joinMode: joinMode ?? this.joinMode,
    notice: notice ?? this.notice,
    leader: leader ?? this.leader,
    skills: skills ?? this.skills,
    deputyCanAccept: deputyCanAccept ?? this.deputyCanAccept,
    tier: tier ?? this.tier,
    gr: gr ?? this.gr,
    memberCount: memberCount,
    avgPower: avgPower,
    emblem: emblem ?? this.emblem,
    createdAt: createdAt,
  );

  /// 앱에 보내는 모양.
  Map<String, dynamic> toApi() => {
    'id': id,
    'name': name,
    'lang': lang,
    'level': level,
    'maxMembers': maxMembers,
    'joinMode': joinMode.key,
    'notice': notice,
    'deputyCanAccept': deputyCanAccept,
    'memberCount': memberCount,
    'avgPower': avgPower,
    'tier': tier,
    'emblem': emblem,
  };
}

/// 멤버 한 명. 닉네임·전투력·뱃지는 `profiles` 에서 붙여 온다(없으면 빈 값).
class GuildMemberRow {
  GuildMemberRow({
    required this.guildId,
    required this.userId,
    this.role = GuildRole.member,
    DateTime? joinedAt,
    DateTime? lastSeen,
    this.contribution = 0,
    this.coins = 0,
    this.donateDay = '',
    this.attendCount = 0,
    this.nickname = '',
    this.power = 0,
    this.badge = '',
  }) : joinedAt = joinedAt ?? DateTime.utc(2000),
       lastSeen = lastSeen ?? DateTime.utc(2000);

  final String guildId;
  final String userId;
  final GuildRole role;
  final DateTime joinedAt;
  final DateTime lastSeen;
  final int contribution;

  /// 길드 코인(서버 소유) — 멤버 목록 RPC 에는 싣지 않는다(남의 코인은 보이지 않는다).
  final int coins;

  /// 마지막으로 출석한 날(KST 09시 경계 키).
  final String donateDay;

  /// 이 길드에서 출석한 날 수(출석 표 35칸 — 순환, `guild_members.attend_count`).
  /// 멤버 행이 탈퇴·추방으로 지워지면 함께 사라진다 = 길드를 옮기면 처음부터.
  final int attendCount;
  final String nickname;
  final double power;
  final String badge;

  factory GuildMemberRow.fromJson(Map<String, dynamic> j) => GuildMemberRow(
    guildId: '${j['guild_id']}',
    userId: '${j['user_id']}',
    role: GuildRole.fromKey(j['role'] as String?),
    joinedAt: DateTime.tryParse('${j['joined_at']}')?.toUtc(),
    lastSeen: DateTime.tryParse('${j['last_seen']}')?.toUtc(),
    contribution: (j['contribution'] as num?)?.toInt() ?? 0,
    coins: (j['coins'] as num?)?.toInt() ?? 0,
    donateDay: j['donate_day'] as String? ?? '',
    // 칸이 없는 옛 DB(SQL ⑨ 적용 전)면 0.
    attendCount: (j['attend_count'] as num?)?.toInt() ?? 0,
    nickname: j['nickname'] as String? ?? '',
    power: (j['power'] as num?)?.toDouble() ?? 0,
    badge: j['badge'] as String? ?? '',
  );

  GuildMemberRow copyWith({
    GuildRole? role,
    DateTime? lastSeen,
    int? contribution,
    int? coins,
    String? donateDay,
    int? attendCount,
  }) => GuildMemberRow(
    guildId: guildId,
    userId: userId,
    role: role ?? this.role,
    joinedAt: joinedAt,
    lastSeen: lastSeen ?? this.lastSeen,
    contribution: contribution ?? this.contribution,
    coins: coins ?? this.coins,
    donateDay: donateDay ?? this.donateDay,
    attendCount: attendCount ?? this.attendCount,
    nickname: nickname,
    power: power,
    badge: badge,
  );

  Map<String, dynamic> toApi() => {
    'userId': userId,
    'role': role.key,
    'joinedAt': joinedAt.toIso8601String(),
    'lastSeen': lastSeen.toIso8601String(),
    'contribution': contribution,
    'nickname': nickname,
    'power': power,
    'badge': badge,
  };
}

/// 가입 신청 한 건(승인제 길드).
class GuildRequestRow {
  GuildRequestRow({
    required this.guildId,
    required this.userId,
    DateTime? createdAt,
    this.nickname = '',
    this.power = 0,
  }) : createdAt = createdAt ?? DateTime.utc(2000);

  final String guildId;
  final String userId;
  final DateTime createdAt;
  final String nickname;
  final double power;

  factory GuildRequestRow.fromJson(Map<String, dynamic> j) => GuildRequestRow(
    guildId: '${j['guild_id']}',
    userId: '${j['user_id']}',
    createdAt: DateTime.tryParse('${j['created_at']}')?.toUtc(),
    nickname: j['nickname'] as String? ?? '',
    power: (j['power'] as num?)?.toDouble() ?? 0,
  );

  Map<String, dynamic> toApi() => {
    'guildId': guildId,
    'userId': userId,
    'createdAt': createdAt.toIso8601String(),
    'nickname': nickname,
    'power': power,
  };
}

/// 멤버 넣기 결과. DB 제약(기본키·인원 트리거)이 최종 판정을 한다 —
/// 서버가 먼저 세어 봐도 동시에 들어오는 두 요청은 막지 못한다.
enum GuildInsertResult { ok, alreadyInGuild, full }

/// 상점 구매 결과(원자적 RPC).
enum GuildBuyResult { ok, limit, coins }

/// 길드 테이블 접근. 로직(권한·규칙)은 [GuildActions] 에 있고, 여기는 읽고 쓰기만 한다.
/// 운영은 [SupabaseGuildStore], 테스트는 [MemoryGuildStore].
abstract interface class GuildStore {
  Future<GuildMemberRow?> membershipOf(String userId);
  Future<GuildRow?> guild(String guildId);
  Future<List<GuildMemberRow>> members(String guildId);

  /// 추천·검색 목록 — 같은 언어 → 자리 있음 → 전투력이 가까운 순(SQL 이 정렬).
  Future<List<GuildRow>> listGuilds({
    required String userId,
    required String lang,
    String query = '',
    int limit = 20,
  });

  /// 새 길드. 이름이 겹치면(대소문자 무시) null.
  Future<GuildRow?> insertGuild({
    required String name,
    required String lang,
    required String leader,
    required int maxMembers,
    required GuildJoinMode joinMode,
    int? emblem,
  });
  Future<void> updateGuild(String guildId, Map<String, dynamic> patch);

  /// 길드 삭제 — 멤버·신청·길드 채팅이 함께 지워진다(FK cascade).
  Future<void> deleteGuild(String guildId);

  Future<GuildInsertResult> insertMember(
    String guildId,
    String userId,
    GuildRole role,
  );
  Future<void> setRole(String userId, GuildRole role);
  Future<void> deleteMember(String userId);
  Future<void> touch(String userId, DateTime now);

  Future<bool> insertRequest(String guildId, String userId);
  Future<void> deleteRequest(String guildId, String userId);
  Future<void> deleteRequestsOf(String userId);
  Future<List<GuildRequestRow>> requestsOf(String guildId);
  Future<List<String>> requestedGuildsOf(String userId);

  /// 마지막으로 **스스로** 길드를 나간 시각(재가입 제한).
  Future<DateTime?> leftAt(String userId);
  Future<void> setLeftAt(String userId, DateTime at);

  // ── 3단계: 경험치 · 코인 · 출석 · 상점 ──

  /// 길드 코인·기여도 더하기(원자적 — 동시에 두 번 받아도 값이 안 틀어지게).
  Future<void> addCoins(String userId, int coins);
  Future<void> addGuildExp(String guildId, int exp);

  /// 출석 — **유저 기준** 그날 처음이면 출석 횟수를 하나 올리고 코인(기본 [coins] + 그 일차의
  /// [bonusCoins])을 **한 번에** 더한 뒤 새 출석 횟수를 돌려준다(원자적, SQL `guild_donate_v3`).
  /// 이미 출석했으면 0. 길드를 옮겨도 같은 날엔 0 — 추방 → 다른 길드 가입으로 두 번 받던 구멍.
  /// [bonusCoins] 는 일차별 보너스 코인(인덱스 0 = 1일차, 길이 = 출석 표 칸 수).
  Future<int> donate(
    String userId,
    String day,
    int coins,
    List<int> bonusCoins,
  );

  /// 출석 되돌리기 — 큰 보상(화석·가루) 지급 저장이 실패했을 때. 출석 횟수 −1 · 코인·기여도 −[coins] ·
  /// 그날 출석 기록을 지운다(다시 누를 수 있게, SQL `guild_donate_undo`).
  Future<void> undoDonate({
    required String userId,
    required String day,
    required int coins,
  });

  /// 유저 기준 마지막 출석일(길드를 옮겨도 남는다). 없으면 ''.
  Future<String> donateDayOf(String userId);

  /// 상점 환불 — 코인을 돌려주고 이번 기간 구매 수를 하나 뺀다(지급 저장이 실패했을 때).
  Future<void> refundBuy({
    required String userId,
    required String itemId,
    required String period,
    required int cost,
  });

  /// 상점 구매 — 기간 한도·코인을 **한 번에** 확인하고 차감한다.
  Future<GuildBuyResult> buy({
    required String userId,
    required String itemId,
    required String period,
    required int limit,
    required int cost,
  });

  /// 이번 기간 구매 수(품목 → 수). [periods] = 품목 → 기간 키.
  Future<Map<String, int>> boughtCounts(
    String userId,
    Map<String, String> periods,
  );
}

/// Supabase REST 구현(service_role — RLS 우회). 테이블은 `docs/_sql_20261001_guild_*.sql`.
class SupabaseGuildStore implements GuildStore {
  SupabaseGuildStore({
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

  Future<List<Map<String, dynamic>>> _get(String q) async {
    final res = await _http.get(_rest(q), headers: _headers);
    if (res.statusCode >= 300) {
      throw StateStoreException('길드 조회 실패($q): ${res.statusCode}');
    }
    return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
  }

  Future<dynamic> _rpcRaw(String fn, Map<String, dynamic> args) async {
    final res = await _http.post(
      _rest('rpc/$fn'),
      headers: _headers,
      body: jsonEncode(args),
    );
    if (res.statusCode >= 300) {
      throw StateStoreException('길드 RPC $fn 실패: ${res.statusCode}');
    }
    return res.body.isEmpty ? null : jsonDecode(res.body);
  }

  Future<List<Map<String, dynamic>>> _rpc(
    String fn,
    Map<String, dynamic> args,
  ) async => ((await _rpcRaw(fn, args)) as List? ?? const [])
      .cast<Map<String, dynamic>>();

  Future<void> _patch(String q, Map<String, dynamic> body) async {
    final res = await _http.patch(
      _rest(q),
      headers: {..._headers, 'Prefer': 'return=minimal'},
      body: jsonEncode(body),
    );
    if (res.statusCode >= 300) {
      throw StateStoreException('길드 수정 실패($q): ${res.statusCode}');
    }
  }

  Future<void> _delete(String q) async {
    final res = await _http.delete(_rest(q), headers: _headers);
    if (res.statusCode >= 300) {
      throw StateStoreException('길드 삭제 실패($q): ${res.statusCode}');
    }
  }

  String _eq(String v) => 'eq.${Uri.encodeComponent(v)}';

  @override
  Future<GuildMemberRow?> membershipOf(String userId) async {
    final rows = await _get('guild_members?user_id=${_eq(userId)}&limit=1');
    return rows.isEmpty ? null : GuildMemberRow.fromJson(rows.first);
  }

  @override
  Future<GuildRow?> guild(String guildId) async {
    final rows = await _rpc('guild_get', {'p_guild': guildId});
    return rows.isEmpty ? null : GuildRow.fromJson(rows.first);
  }

  @override
  Future<List<GuildMemberRow>> members(String guildId) async => [
    for (final r in await _rpc('guild_member_list', {'p_guild': guildId}))
      GuildMemberRow.fromJson(r),
  ];

  @override
  Future<List<GuildRow>> listGuilds({
    required String userId,
    required String lang,
    String query = '',
    int limit = 20,
  }) async => [
    for (final r in await _rpc('guild_list', {
      'p_user': userId,
      'p_lang': lang,
      'p_query': query,
      'lim': limit,
    }))
      GuildRow.fromJson(r),
  ];

  @override
  Future<GuildRow?> insertGuild({
    required String name,
    required String lang,
    required String leader,
    required int maxMembers,
    required GuildJoinMode joinMode,
    int? emblem,
  }) async {
    final res = await _http.post(
      _rest('guilds'),
      headers: {..._headers, 'Prefer': 'return=representation'},
      body: jsonEncode([
        {
          'name': name,
          'lang': lang,
          'leader': leader,
          'max_members': maxMembers,
          'join_mode': joinMode.key,
          // 고르지 않았으면 칸을 보내지 않는다(DB 기본 null).
          'emblem': ?emblem,
        },
      ]),
    );
    if (res.statusCode == 409) return null; // 이름 중복(유니크 인덱스)
    if (res.statusCode >= 300) {
      throw StateStoreException('길드 만들기 실패: ${res.statusCode}');
    }
    final rows = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
    return GuildRow.fromJson(rows.first);
  }

  @override
  Future<void> updateGuild(String guildId, Map<String, dynamic> patch) =>
      _patch('guilds?id=${_eq(guildId)}', patch);

  @override
  Future<void> deleteGuild(String guildId) =>
      _delete('guilds?id=${_eq(guildId)}');

  @override
  Future<GuildInsertResult> insertMember(
    String guildId,
    String userId,
    GuildRole role,
  ) async {
    final res = await _http.post(
      _rest('guild_members'),
      headers: {..._headers, 'Prefer': 'return=minimal'},
      body: jsonEncode([
        {'guild_id': guildId, 'user_id': userId, 'role': role.key},
      ]),
    );
    if (res.statusCode == 409) return GuildInsertResult.alreadyInGuild;
    // 인원 트리거가 `guild_full` 로 막는다(PostgREST 는 raise 를 400 으로 준다).
    if (res.body.contains('guild_full')) return GuildInsertResult.full;
    if (res.statusCode >= 300) {
      throw StateStoreException('길드 가입 실패: ${res.statusCode}');
    }
    return GuildInsertResult.ok;
  }

  @override
  Future<void> setRole(String userId, GuildRole role) =>
      _patch('guild_members?user_id=${_eq(userId)}', {'role': role.key});

  @override
  Future<void> deleteMember(String userId) =>
      _delete('guild_members?user_id=${_eq(userId)}');

  @override
  Future<void> touch(String userId, DateTime now) => _patch(
    'guild_members?user_id=${_eq(userId)}',
    {'last_seen': now.toUtc().toIso8601String()},
  );

  @override
  Future<bool> insertRequest(String guildId, String userId) async {
    final res = await _http.post(
      _rest('guild_requests'),
      headers: {..._headers, 'Prefer': 'return=minimal'},
      body: jsonEncode([
        {'guild_id': guildId, 'user_id': userId},
      ]),
    );
    if (res.statusCode == 409) return false;
    if (res.statusCode >= 300) {
      throw StateStoreException('가입 신청 실패: ${res.statusCode}');
    }
    return true;
  }

  @override
  Future<void> deleteRequest(String guildId, String userId) =>
      _delete('guild_requests?guild_id=${_eq(guildId)}&user_id=${_eq(userId)}');

  @override
  Future<void> deleteRequestsOf(String userId) =>
      _delete('guild_requests?user_id=${_eq(userId)}');

  @override
  Future<List<GuildRequestRow>> requestsOf(String guildId) async => [
    for (final r in await _rpc('guild_request_list', {'p_guild': guildId}))
      GuildRequestRow.fromJson(r),
  ];

  @override
  Future<List<String>> requestedGuildsOf(String userId) async => [
    for (final r in await _get(
      'guild_requests?user_id=${_eq(userId)}&select=guild_id',
    ))
      '${r['guild_id']}',
  ];

  @override
  Future<DateTime?> leftAt(String userId) async {
    final rows = await _get(
      'guild_cooldowns?user_id=${_eq(userId)}&select=left_at&limit=1',
    );
    if (rows.isEmpty) return null;
    return DateTime.tryParse('${rows.first['left_at']}')?.toUtc();
  }

  @override
  Future<void> setLeftAt(String userId, DateTime at) async {
    final res = await _http.post(
      _rest('guild_cooldowns?on_conflict=user_id'),
      headers: {
        ..._headers,
        'Prefer': 'resolution=merge-duplicates,return=minimal',
      },
      body: jsonEncode([
        {'user_id': userId, 'left_at': at.toUtc().toIso8601String()},
      ]),
    );
    if (res.statusCode >= 300) {
      throw StateStoreException('재가입 제한 기록 실패: ${res.statusCode}');
    }
  }

  @override
  Future<void> addCoins(String userId, int coins) =>
      _rpcRaw('guild_add_coins', {'p_user': userId, 'p_coins': coins});

  @override
  Future<void> addGuildExp(String guildId, int exp) =>
      _rpcRaw('guild_add_exp', {'p_guild': guildId, 'p_exp': exp});

  @override
  Future<int> donate(
    String userId,
    String day,
    int coins,
    List<int> bonusCoins,
  ) async =>
      ((await _rpcRaw('guild_donate_v3', {
                'p_user': userId,
                'p_day': day,
                'p_coins': coins,
                'p_bonus': bonusCoins,
              }))
              as num?)
          ?.toInt() ??
      0;

  @override
  Future<void> undoDonate({
    required String userId,
    required String day,
    required int coins,
  }) => _rpcRaw('guild_donate_undo', {
    'p_user': userId,
    'p_day': day,
    'p_coins': coins,
  });

  @override
  Future<String> donateDayOf(String userId) async {
    final rows = await _get(
      'guild_user_daily?user_id=${_eq(userId)}&select=donate_day&limit=1',
    );
    return rows.isEmpty ? '' : '${rows.first['donate_day'] ?? ''}';
  }

  @override
  Future<void> refundBuy({
    required String userId,
    required String itemId,
    required String period,
    required int cost,
  }) => _rpcRaw('guild_shop_refund', {
    'p_user': userId,
    'p_item': itemId,
    'p_period': period,
    'p_cost': cost,
  });

  @override
  Future<GuildBuyResult> buy({
    required String userId,
    required String itemId,
    required String period,
    required int limit,
    required int cost,
  }) async {
    final r = await _rpcRaw('guild_shop_buy', {
      'p_user': userId,
      'p_item': itemId,
      'p_period': period,
      'p_limit': limit,
      'p_cost': cost,
    });
    return switch (r) {
      'ok' => GuildBuyResult.ok,
      'limit' => GuildBuyResult.limit,
      _ => GuildBuyResult.coins,
    };
  }

  @override
  Future<Map<String, int>> boughtCounts(
    String userId,
    Map<String, String> periods,
  ) async {
    final rows = await _get(
      'guild_shop_buys?user_id=${_eq(userId)}&select=item,period_key,n',
    );
    return {
      for (final r in rows)
        if (periods['${r['item']}'] == '${r['period_key']}')
          '${r['item']}': (r['n'] as num).toInt(),
    };
  }
}

/// 테스트용 메모리 구현 — DB 제약(이름 유일·한 사람 한 길드·인원 상한·cascade)을 흉내낸다.
class MemoryGuildStore implements GuildStore {
  MemoryGuildStore({DateTime Function()? clock})
    : _clock = clock ?? (() => DateTime.now().toUtc());

  final DateTime Function() _clock;
  final Map<String, GuildRow> guilds = {};
  final Map<String, GuildMemberRow> memberRows = {};
  final List<GuildRequestRow> requests = [];
  final Map<String, DateTime> cooldowns = {};

  /// (user|item) → (기간, 수).
  final Map<String, (String, int)> buys = {};

  /// 유저 기준 마지막 출석일(guild_user_daily 흉내 — 길드를 옮겨도 남는다).
  final Map<String, String> donateDays = {};

  /// 닉네임·전투력(profiles 흉내).
  final Map<String, ({String nickname, double power})> profiles = {};
  var _seq = 0;

  GuildMemberRow _withProfile(GuildMemberRow m) {
    final p = profiles[m.userId];
    return GuildMemberRow(
      guildId: m.guildId,
      userId: m.userId,
      role: m.role,
      joinedAt: m.joinedAt,
      lastSeen: m.lastSeen,
      contribution: m.contribution,
      coins: m.coins,
      donateDay: m.donateDay,
      attendCount: m.attendCount,
      nickname: p?.nickname ?? '',
      power: p?.power ?? 0,
    );
  }

  GuildRow _counted(GuildRow g) {
    final ms = memberRows.values.where((m) => m.guildId == g.id).toList();
    final avg = ms.isEmpty
        ? 0.0
        : ms
                  .map((m) => profiles[m.userId]?.power ?? 0)
                  .reduce((a, b) => a + b) /
              ms.length;
    return GuildRow(
      id: g.id,
      name: g.name,
      lang: g.lang,
      level: g.level,
      exp: g.exp,
      maxMembers: g.maxMembers,
      joinMode: g.joinMode,
      notice: g.notice,
      leader: g.leader,
      skills: g.skills,
      deputyCanAccept: g.deputyCanAccept,
      tier: g.tier,
      gr: g.gr,
      memberCount: ms.length,
      avgPower: avg,
      emblem: g.emblem,
      createdAt: g.createdAt,
    );
  }

  /// 테스트가 멤버의 마지막 접속을 되돌려 볼 때.
  void setLastSeen(String userId, DateTime at) =>
      memberRows[userId] = memberRows[userId]!.copyWith(lastSeen: at);

  @override
  Future<GuildMemberRow?> membershipOf(String userId) async =>
      memberRows[userId];

  @override
  Future<GuildRow?> guild(String guildId) async {
    final g = guilds[guildId];
    return g == null ? null : _counted(g);
  }

  @override
  Future<List<GuildMemberRow>> members(String guildId) async => [
    for (final m in memberRows.values)
      if (m.guildId == guildId) _withProfile(m),
  ];

  @override
  Future<List<GuildRow>> listGuilds({
    required String userId,
    required String lang,
    String query = '',
    int limit = 20,
  }) async {
    final q = query.trim().toLowerCase();
    final list = [
      for (final g in guilds.values)
        if (q.isEmpty || g.name.toLowerCase().contains(q)) _counted(g),
    ];
    list.sort((a, b) {
      final l = (b.lang == lang ? 1 : 0) - (a.lang == lang ? 1 : 0);
      if (l != 0) return l;
      return (a.full ? 1 : 0) - (b.full ? 1 : 0);
    });
    return list.take(limit).toList();
  }

  @override
  Future<GuildRow?> insertGuild({
    required String name,
    required String lang,
    required String leader,
    required int maxMembers,
    required GuildJoinMode joinMode,
    int? emblem,
  }) async {
    final lower = name.toLowerCase();
    if (guilds.values.any((g) => g.name.toLowerCase() == lower)) return null;
    final g = GuildRow(
      id: 'g${++_seq}',
      name: name,
      lang: lang,
      leader: leader,
      maxMembers: maxMembers,
      joinMode: joinMode,
      emblem: emblem,
      createdAt: _clock(),
    );
    guilds[g.id] = g;
    return g;
  }

  @override
  Future<void> updateGuild(String guildId, Map<String, dynamic> patch) async {
    final g = guilds[guildId];
    if (g == null) return;
    guilds[guildId] = g.copyWith(
      joinMode: patch.containsKey('join_mode')
          ? GuildJoinMode.fromKey(patch['join_mode'] as String?)
          : null,
      notice: patch['notice'] as String?,
      leader: patch['leader'] as String?,
      level: patch['level'] as int?,
      maxMembers: patch['max_members'] as int?,
      skills: patch.containsKey('skill_points')
          ? (patch['skill_points'] as Map).map(
              (k, v) => MapEntry('$k', (v as num).toInt()),
            )
          : null,
      deputyCanAccept: patch['deputy_can_accept'] as bool?,
      tier: patch['tier'] as String?,
      gr: patch['gr'] as int?,
      emblem: patch['emblem'] as int?,
    );
  }

  @override
  Future<void> deleteGuild(String guildId) async {
    guilds.remove(guildId);
    memberRows.removeWhere((_, m) => m.guildId == guildId);
    requests.removeWhere((r) => r.guildId == guildId);
  }

  @override
  Future<GuildInsertResult> insertMember(
    String guildId,
    String userId,
    GuildRole role,
  ) async {
    if (memberRows.containsKey(userId)) return GuildInsertResult.alreadyInGuild;
    final g = guilds[guildId];
    if (g == null) throw StateStoreException('no guild');
    final n = memberRows.values.where((m) => m.guildId == guildId).length;
    if (n >= g.maxMembers) return GuildInsertResult.full;
    final now = _clock();
    memberRows[userId] = GuildMemberRow(
      guildId: guildId,
      userId: userId,
      role: role,
      joinedAt: now,
      lastSeen: now,
    );
    return GuildInsertResult.ok;
  }

  @override
  Future<void> setRole(String userId, GuildRole role) async {
    final m = memberRows[userId];
    if (m != null) memberRows[userId] = m.copyWith(role: role);
  }

  @override
  Future<void> deleteMember(String userId) async => memberRows.remove(userId);

  @override
  Future<void> touch(String userId, DateTime now) async {
    if (memberRows.containsKey(userId)) setLastSeen(userId, now);
  }

  @override
  Future<bool> insertRequest(String guildId, String userId) async {
    if (requests.any((r) => r.guildId == guildId && r.userId == userId)) {
      return false;
    }
    requests.add(
      GuildRequestRow(guildId: guildId, userId: userId, createdAt: _clock()),
    );
    return true;
  }

  @override
  Future<void> deleteRequest(String guildId, String userId) async =>
      requests.removeWhere((r) => r.guildId == guildId && r.userId == userId);

  @override
  Future<void> deleteRequestsOf(String userId) async =>
      requests.removeWhere((r) => r.userId == userId);

  @override
  Future<List<GuildRequestRow>> requestsOf(String guildId) async => [
    for (final r in requests)
      if (r.guildId == guildId)
        GuildRequestRow(
          guildId: r.guildId,
          userId: r.userId,
          createdAt: r.createdAt,
          nickname: profiles[r.userId]?.nickname ?? '',
          power: profiles[r.userId]?.power ?? 0,
        ),
  ];

  @override
  Future<List<String>> requestedGuildsOf(String userId) async => [
    for (final r in requests)
      if (r.userId == userId) r.guildId,
  ];

  @override
  Future<DateTime?> leftAt(String userId) async => cooldowns[userId];

  @override
  Future<void> setLeftAt(String userId, DateTime at) async =>
      cooldowns[userId] = at;

  @override
  Future<void> addCoins(String userId, int coins) async {
    final m = memberRows[userId];
    if (m == null || coins <= 0) return;
    memberRows[userId] = m.copyWith(
      coins: m.coins + coins,
      contribution: m.contribution + coins,
    );
  }

  @override
  Future<void> addGuildExp(String guildId, int exp) async {
    final g = guilds[guildId];
    if (g != null && exp > 0) guilds[guildId] = g.copyWith(exp: g.exp + exp);
  }

  @override
  Future<int> donate(
    String userId,
    String day,
    int coins,
    List<int> bonusCoins,
  ) async {
    final m = memberRows[userId];
    if (m == null) return 0;
    if (m.donateDay == day || donateDays[userId] == day) {
      memberRows[userId] = m.copyWith(donateDay: day);
      return 0;
    }
    donateDays[userId] = day;
    final n = m.attendCount + 1;
    final cycle = bonusCoins.isEmpty ? 1 : bonusCoins.length;
    final bonus = bonusCoins.isEmpty ? 0 : bonusCoins[(n - 1) % cycle];
    final add = coins + bonus;
    memberRows[userId] = m.copyWith(
      donateDay: day,
      attendCount: n,
      coins: m.coins + add,
      contribution: m.contribution + add,
    );
    return n;
  }

  @override
  Future<void> undoDonate({
    required String userId,
    required String day,
    required int coins,
  }) async {
    if (donateDays[userId] == day) donateDays[userId] = '';
    final m = memberRows[userId];
    if (m == null) return;
    memberRows[userId] = m.copyWith(
      donateDay: m.donateDay == day ? '' : m.donateDay,
      attendCount: m.attendCount > 0 ? m.attendCount - 1 : 0,
      coins: m.coins - coins < 0 ? 0 : m.coins - coins,
      contribution: m.contribution - coins < 0 ? 0 : m.contribution - coins,
    );
  }

  @override
  Future<String> donateDayOf(String userId) async => donateDays[userId] ?? '';

  @override
  Future<void> refundBuy({
    required String userId,
    required String itemId,
    required String period,
    required int cost,
  }) async {
    final m = memberRows[userId];
    if (m != null && cost > 0) {
      memberRows[userId] = m.copyWith(coins: m.coins + cost);
    }
    final key = '$userId|$itemId';
    final prev = buys[key];
    if (prev != null && prev.$1 == period) {
      buys[key] = (period, prev.$2 > 0 ? prev.$2 - 1 : 0);
    }
  }

  @override
  Future<GuildBuyResult> buy({
    required String userId,
    required String itemId,
    required String period,
    required int limit,
    required int cost,
  }) async {
    final m = memberRows[userId];
    final key = '$userId|$itemId';
    final prev = buys[key];
    final n = prev != null && prev.$1 == period ? prev.$2 : 0;
    if (n >= limit) return GuildBuyResult.limit;
    if (m == null || m.coins < cost) return GuildBuyResult.coins;
    memberRows[userId] = m.copyWith(coins: m.coins - cost);
    buys[key] = (period, n + 1);
    return GuildBuyResult.ok;
  }

  @override
  Future<Map<String, int>> boughtCounts(
    String userId,
    Map<String, String> periods,
  ) async => {
    for (final e in buys.entries)
      if (e.key.startsWith('$userId|') &&
          periods[e.key.split('|')[1]] == e.value.$1)
        e.key.split('|')[1]: e.value.$2,
  };
}
