import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:server/src/app.dart';
import 'package:server/src/state_store.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'auth_test.dart' show makeToken, attackerKey, signingKey, verifierFor;

/// Supabase REST 를 흉내내는 가짜 클라이언트 — 네트워크 없이 라우팅을 검증한다.
class _FakeHttp extends http.BaseClient {
  _FakeHttp(this.rows);

  /// userId → 세이브 JSON
  final Map<String, Map<String, dynamic>> rows;
  int loadCount = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    loadCount++;
    final id = request.url.queryParameters['id']?.replaceFirst('eq.', '');
    final data = rows[id];
    final body = jsonEncode(
      data == null
          ? []
          : [
              {'data': data},
            ],
    );
    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

void main() {
  const url = 'https://proj.supabase.co';

  Handler handlerWith(Map<String, Map<String, dynamic>> rows) {
    final config = ServerConfig(
      supabaseUrl: url,
      serviceRoleKey: 'service-role',
    );
    final store = StateStore(
      supabaseUrl: url,
      serviceRoleKey: 'service-role',
      client: _FakeHttp(rows),
    );
    return buildHandler(
      config: config,
      store: store,
      jwtVerifier: verifierFor(signingKey),
    );
  }

  Future<Response> get(Handler h, String path, {String? token}) async => h(
    Request(
      'GET',
      Uri.parse('http://localhost$path'),
      headers: {if (token != null) 'authorization': 'Bearer $token'},
    ),
  );

  test('헬스체크는 인증 없이 통과한다 (Cloud Run 이 부른다)', () async {
    final res = await get(handlerWith({}), '/healthz');
    expect(res.statusCode, 200);
  });

  test('토큰 없이 /state 는 401', () async {
    final res = await get(handlerWith({}), '/state');
    expect(res.statusCode, 401);
  });

  test('위조 토큰으로 /state 는 401', () async {
    final res = await get(
      handlerWith({}),
      '/state',
      token: makeToken(key: attackerKey),
    );
    expect(res.statusCode, 401);
  });

  test('401 응답은 실패 사유를 흘리지 않는다', () async {
    final res = await get(
      handlerWith({}),
      '/state',
      token: makeToken(key: attackerKey),
    );
    final body = jsonDecode(await res.readAsString()) as Map;
    expect(body['error'], 'unauthorized');
    // badSignature / expired 같은 내부 사유가 노출되면 안 된다.
    expect(body.values.join(), isNot(contains('ignature')));
  });

  test('유효한 토큰이면 본인 세이브를 돌려준다', () async {
    final h = handlerWith({
      'user-1': {'gold': 123, 'schemaVersion': 18},
    });
    final res = await get(h, '/state', token: makeToken());
    expect(res.statusCode, 200);
    final body = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
    expect(body['userId'], 'user-1');
    expect((body['save'] as Map)['gold'], 123);
    expect(body['serverTime'], isNotEmpty);
  });

  test('다른 사람 세이브는 넘어오지 않는다 (조회 키는 토큰의 sub)', () async {
    final h = handlerWith({
      'user-1': {'gold': 1},
      'victim': {'gold': 999999},
    });
    // user-1 토큰으로 요청 → victim 데이터가 섞여 나오면 안 된다.
    final res = await get(h, '/state', token: makeToken());
    final body = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
    expect((body['save'] as Map)['gold'], 1);
  });

  test('신규 유저는 save 가 null 이다', () async {
    final res = await get(handlerWith({}), '/state', token: makeToken());
    expect(res.statusCode, 200);
    final body = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
    expect(body['save'], isNull);
  });
}
