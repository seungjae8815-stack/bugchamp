import 'dart:convert';

import 'package:http/http.dart' as http;

/// 서버가 소유하는 세이브 저장소.
///
/// P1 에서는 기존 Supabase `saves` 테이블을 그대로 쓴다(이미 존재).
/// 접근은 **service_role 키**로 하므로 RLS 를 우회한다 — 즉 이 서버가
/// 유일한 쓰기 주체이고, 클라이언트는 REST 로 직접 못 쓴다(RLS 가 막음).
///
/// ⚠️ service_role 키는 **서버 환경변수로만** 주입한다.
class StateStore {
  StateStore({
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

  /// [userId] 의 세이브 JSON. 없으면 null(신규 유저).
  Future<Map<String, dynamic>?> load(String userId) async {
    final uri = Uri.parse(
      '$supabaseUrl/rest/v1/saves?id=eq.$userId&select=data&limit=1',
    );
    final res = await _http.get(uri, headers: _headers);
    if (res.statusCode != 200) {
      throw StateStoreException('load 실패: ${res.statusCode} ${res.body}');
    }
    final rows = jsonDecode(res.body) as List;
    if (rows.isEmpty) return null;
    final data = (rows.first as Map<String, dynamic>)['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is String) return jsonDecode(data) as Map<String, dynamic>;
    return null;
  }

  /// [userId] 의 세이브를 통째로 덮어쓴다.
  Future<void> save(String userId, Map<String, dynamic> data) async {
    final uri = Uri.parse('$supabaseUrl/rest/v1/saves?on_conflict=id');
    final res = await _http.post(
      uri,
      headers: {..._headers, 'Prefer': 'resolution=merge-duplicates'},
      body: jsonEncode([
        {
          'id': userId,
          'data': data,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
      ]),
    );
    if (res.statusCode >= 300) {
      throw StateStoreException('save 실패: ${res.statusCode} ${res.body}');
    }
  }

  /// [userId] 의 방어팀(곤충 3마리 스냅샷). 없으면 null.
  ///
  /// 상대 스탯을 **클라이언트가 보내게 하면 안 된다** — 약한 상대를 만들어
  /// 트로피를 쓸어담을 수 있다. 서버가 직접 읽는다.
  Future<List<Map<String, dynamic>>?> loadDefenderTeam(String userId) async {
    final uri = Uri.parse(
      '$supabaseUrl/rest/v1/defenders?id=eq.$userId&select=team&limit=1',
    );
    final res = await _http.get(uri, headers: _headers);
    if (res.statusCode != 200) {
      throw StateStoreException('defender load 실패: ${res.statusCode}');
    }
    final rows = jsonDecode(res.body) as List;
    if (rows.isEmpty) return null;
    var team = (rows.first as Map<String, dynamic>)['team'];
    if (team is String) team = jsonDecode(team);
    if (team is! List) return null;
    return [for (final t in team) t as Map<String, dynamic>];
  }

  /// 수동 전투 세션 저장(신규/갱신).
  Future<void> saveSession(
    String id,
    String userId,
    Map<String, dynamic> data,
  ) async {
    final uri = Uri.parse(
      '$supabaseUrl/rest/v1/battle_sessions?on_conflict=id',
    );
    final res = await _http.post(
      uri,
      headers: {..._headers, 'Prefer': 'resolution=merge-duplicates'},
      body: jsonEncode([
        {
          'id': id,
          'user_id': userId,
          'data': data,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
      ]),
    );
    if (res.statusCode >= 300) {
      throw StateStoreException('session save 실패: ${res.statusCode}');
    }
  }

  /// 수동 전투 세션 조회. 없으면 null.
  Future<Map<String, dynamic>?> loadSession(String id) async {
    final uri = Uri.parse(
      '$supabaseUrl/rest/v1/battle_sessions?id=eq.$id&select=user_id,data&limit=1',
    );
    final res = await _http.get(uri, headers: _headers);
    if (res.statusCode != 200) {
      throw StateStoreException('session load 실패: ${res.statusCode}');
    }
    final rows = jsonDecode(res.body) as List;
    if (rows.isEmpty) return null;
    return rows.first as Map<String, dynamic>;
  }

  // ── 공지 · 운영 우편 · 선물코드(2026-08-07) ──
  //
  // 셋 다 "서버가 유저에게 보낸다"는 같은 일이라 한 벌로 묶었다.
  // 테이블은 전부 **service_role 로만** 읽고 쓴다(RLS 는 클라 직접 접근 차단).
  // 스키마는 `docs/backend_supabase.md` §10.

  /// 진행 중인 공지(고정 먼저, 최신순).
  ///
  /// 기간 필터는 **Dart 에서** 건다 — 공지는 몇 건뿐이라 서버 필터를 복잡한
  /// PostgREST or() 문법으로 짜서 얻을 게 없다.
  Future<List<Map<String, dynamic>>> loadNotices({
    required DateTime now,
    int limit = 30,
  }) async {
    final uri = Uri.parse(
      '$supabaseUrl/rest/v1/notices'
      '?select=id,title,body,starts_at,ends_at,pinned,created_at'
      '&order=pinned.desc,created_at.desc&limit=$limit',
    );
    final res = await _http.get(uri, headers: _headers);
    if (res.statusCode != 200) {
      throw StateStoreException('notices 실패: ${res.statusCode} ${res.body}');
    }
    final rows = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
    return [
      for (final r in rows)
        if (_inWindow(r['starts_at'], r['ends_at'], now)) r,
    ];
  }

  /// [userId] 가 아직 받지 않은 우편(개인 지정 + 전체 발송).
  ///
  /// `user_id` 가 null 인 행은 **전체 유저 대상**이다 — 점검 보상처럼 한 번
  /// 써서 모두에게 보내는 용도. 수령 여부는 `mail_claims` 로 유저별로 남는다.
  Future<List<Map<String, dynamic>>> loadMail({
    required String userId,
    required DateTime now,
    int limit = 50,
  }) async {
    final uri = Uri.parse(
      '$supabaseUrl/rest/v1/user_mail'
      '?select=id,title,body,gold,jelly,chitin,mineral,sap,starts_at,ends_at,created_at'
      '&or=(user_id.is.null,user_id.eq.$userId)'
      '&order=created_at.desc&limit=$limit',
    );
    final res = await _http.get(uri, headers: _headers);
    if (res.statusCode != 200) {
      throw StateStoreException('mail 실패: ${res.statusCode} ${res.body}');
    }
    final rows = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
    final claimed = await _claimedMailIds(userId);
    return [
      for (final r in rows)
        if (!claimed.contains('${r['id']}') &&
            _inWindow(r['starts_at'], r['ends_at'], now))
          r,
    ];
  }

  Future<Set<String>> _claimedMailIds(String userId) async {
    final uri = Uri.parse(
      '$supabaseUrl/rest/v1/mail_claims?select=mail_id&user_id=eq.$userId',
    );
    final res = await _http.get(uri, headers: _headers);
    if (res.statusCode != 200) {
      throw StateStoreException('mail_claims 실패: ${res.statusCode}');
    }
    return {
      for (final r in (jsonDecode(res.body) as List).cast<Map>())
        '${r['mail_id']}',
    };
  }

  /// 우편 1통을 [userId] 앞으로 **수령 처리**한다. 이미 받았으면 false.
  ///
  /// 중복 지급 차단을 앱이나 조회 결과에 맡기지 않는다 — `mail_claims` 의
  /// 기본키(mail_id, user_id) 충돌로 **DB 가 막는다**. 연타·재시도해도 한 번만
  /// 들어간다.
  Future<bool> claimMail(String mailId, String userId) =>
      _insertOnce('mail_claims', {'mail_id': mailId, 'user_id': userId});

  /// 선물코드 1건. 없으면 null. 대소문자는 무시한다(유저가 손으로 친다).
  Future<Map<String, dynamic>?> loadGiftCode(String code) async {
    final uri = Uri.parse(
      '$supabaseUrl/rest/v1/gift_codes'
      '?select=code,gold,jelly,chitin,mineral,sap,max_uses,used_count,ends_at'
      '&code=eq.${Uri.encodeComponent(code.toUpperCase())}&limit=1',
    );
    final res = await _http.get(uri, headers: _headers);
    if (res.statusCode != 200) {
      throw StateStoreException('gift_codes 실패: ${res.statusCode}');
    }
    final rows = jsonDecode(res.body) as List;
    return rows.isEmpty ? null : rows.first as Map<String, dynamic>;
  }

  /// 코드 사용 기록. 이미 쓴 코드면 false(계정당 1회).
  Future<bool> redeemGiftCode(String code, String userId) => _insertOnce(
    'code_redemptions',
    {'code': code.toUpperCase(), 'user_id': userId},
  );

  /// 코드 총 사용 횟수 +1 (수량 제한용). 실패해도 지급은 이미 끝났으므로
  /// 예외로 흐름을 끊지 않는다 — 카운터는 통계·상한의 근사치다.
  Future<void> bumpGiftCodeUse(String code) async {
    try {
      await _http.post(
        Uri.parse('$supabaseUrl/rest/v1/rpc/bump_gift_code'),
        headers: _headers,
        body: jsonEncode({'c': code.toUpperCase()}),
      );
    } catch (_) {
      // 무시 — 중복 지급은 code_redemptions 기본키가 이미 막았다.
    }
  }

  // ── 운영 패널(/admin) ──
  //
  // 조회는 **기간 필터 없이 전부** 준다 — 운영자는 지난 공지·만료된 코드도
  // 봐야 관리가 된다(유저용 loadNotices/loadMail 과 다른 이유).

  /// 관리 패널용 전체 조회(공지·우편·코드).
  Future<Map<String, List<Map<String, dynamic>>>> adminData({
    int limit = 100,
  }) async {
    Future<List<Map<String, dynamic>>> rows(String q) async {
      final res = await _http.get(
        Uri.parse('$supabaseUrl/rest/v1/$q'),
        headers: _headers,
      );
      if (res.statusCode != 200) {
        throw StateStoreException('admin 조회 실패: ${res.statusCode} ${res.body}');
      }
      return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
    }

    return {
      'notices': await rows(
        'notices?select=*&order=created_at.desc&limit=$limit',
      ),
      'mail': await rows(
        'user_mail?select=*&order=created_at.desc&limit=$limit',
      ),
      'codes': await rows(
        'gift_codes?select=*&order=created_at.desc&limit=$limit',
      ),
      'chat': await listChat(),
    };
  }

  /// 운영자 이름으로 전체 채팅에 글을 쓴다.
  ///
  /// `is_admin = true` 는 **service_role 로만** 넣을 수 있다(RLS 가 클라이언트의
  /// true 삽입을 막는다) — 이게 없으면 누구나 닉네임을 '운영자'로 바꿔 사칭한다.
  ///
  /// ⚠️ [userId] 는 **실재하는 계정 uuid** 여야 한다. `chat_messages.user_id` 는
  /// NOT NULL + auth.users 참조이고, 무엇보다 앱의 `recent()` 가 파싱에 실패하면
  /// **목록 전체를 빈 배열로** 돌려준다 — 잘못된 값 하나가 모든 유저의 채팅창을
  /// 비워버린다.
  Future<void> insertAdminChat({
    required String userId,
    required String nickname,
    required String body,
  }) => insertRow('chat_messages', {
    'user_id': userId,
    'nickname': nickname,
    'body': body,
    'is_admin': true,
  });

  /// 최근 채팅(운영 모더레이션용). 부적절한 글을 지우려면 먼저 보여야 한다.
  Future<List<Map<String, dynamic>>> listChat({int limit = 40}) async {
    final res = await _http.get(
      Uri.parse(
        '$supabaseUrl/rest/v1/chat_messages'
        '?select=id,user_id,nickname,body,is_admin,created_at'
        '&order=created_at.desc&limit=$limit',
      ),
      headers: _headers,
    );
    if (res.statusCode != 200) {
      throw StateStoreException('chat 조회 실패: ${res.statusCode} ${res.body}');
    }
    return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
  }

  /// 행 1개 삽입(운영 등록). 실패는 예외 — 조용히 넘기면 "올렸는데 없다"가 된다.
  Future<void> insertRow(String table, Map<String, dynamic> row) async {
    final res = await _http.post(
      Uri.parse('$supabaseUrl/rest/v1/$table'),
      headers: {..._headers, 'Prefer': 'return=minimal'},
      body: jsonEncode([row]),
    );
    if (res.statusCode >= 300) {
      throw StateStoreException('$table 등록 실패: ${res.statusCode} ${res.body}');
    }
  }

  /// 운영 행 삭제. [column] 기준 1건(공지·우편은 id, 코드는 code).
  Future<void> deleteRow(String table, String column, String value) async {
    final res = await _http.delete(
      Uri.parse(
        '$supabaseUrl/rest/v1/$table?$column=eq.${Uri.encodeComponent(value)}',
      ),
      headers: _headers,
    );
    if (res.statusCode >= 300) {
      throw StateStoreException('$table 삭제 실패: ${res.statusCode}');
    }
  }

  /// 기본키 충돌을 "이미 처리됨"으로 읽는 1회성 삽입.
  Future<bool> _insertOnce(String table, Map<String, dynamic> row) async {
    final res = await _http.post(
      Uri.parse('$supabaseUrl/rest/v1/$table'),
      headers: {..._headers, 'Prefer': 'return=minimal'},
      body: jsonEncode([row]),
    );
    if (res.statusCode == 409) return false; // 기본키 중복 = 이미 받음
    if (res.statusCode >= 300) {
      throw StateStoreException('$table insert 실패: ${res.statusCode}');
    }
    return true;
  }

  /// [now] 가 게시 기간 안인지(둘 다 null 이면 항상 유효).
  static bool _inWindow(Object? startsAt, Object? endsAt, DateTime now) {
    final t = now.toUtc();
    if (startsAt is String) {
      final s = DateTime.tryParse(startsAt)?.toUtc();
      if (s != null && t.isBefore(s)) return false;
    }
    if (endsAt is String) {
      final e = DateTime.tryParse(endsAt)?.toUtc();
      if (e != null && !t.isBefore(e)) return false;
    }
    return true;
  }

  void close() => _http.close();
}

class StateStoreException implements Exception {
  StateStoreException(this.message);
  final String message;
  @override
  String toString() => 'StateStoreException: $message';
}
