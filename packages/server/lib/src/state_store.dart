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

  void close() => _http.close();
}

class StateStoreException implements Exception {
  StateStoreException(this.message);
  final String message;
  @override
  String toString() => 'StateStoreException: $message';
}
