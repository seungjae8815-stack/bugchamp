import 'dart:convert';
import 'dart:io' show stderr;

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'auth.dart';
import 'state_store.dart';

/// 서버 설정. 전부 환경변수에서 온다 — 코드·저장소에 비밀을 두지 않는다.
class ServerConfig {
  ServerConfig({
    required this.supabaseUrl,
    required this.serviceRoleKey,
    required this.jwtSecret,
  });

  final String supabaseUrl;
  final String serviceRoleKey;
  final String jwtSecret;

  /// JWT 발급자 — 프로젝트 URL 로부터 유도한다.
  String get issuer => '$supabaseUrl/auth/v1';

  /// 환경변수에서 읽는다. 하나라도 없으면 예외(조용히 뜨는 것보다 낫다).
  factory ServerConfig.fromEnv(Map<String, String> env) {
    String need(String k) {
      final v = env[k];
      if (v == null || v.isEmpty) {
        throw StateError('환경변수 $k 가 없습니다');
      }
      return v;
    }

    return ServerConfig(
      supabaseUrl: need('SUPABASE_URL'),
      serviceRoleKey: need('SUPABASE_SERVICE_ROLE_KEY'),
      jwtSecret: need('SUPABASE_JWT_SECRET'),
    );
  }
}

/// 요청 컨텍스트에 담긴 인증 사용자 키.
const _userKey = 'authedUser';

/// 인증 미들웨어 — 통과하지 못하면 401. 세부 사유는 응답에 담지 않는다
/// (공격자에게 어디까지 맞았는지 알려주지 않기 위해).
Middleware requireAuth(SupabaseJwtVerifier verifier) {
  return (Handler inner) {
    return (Request req) async {
      final result = verifier.verifyHeader(req.headers['authorization']);
      if (!result.isOk) {
        return Response.unauthorized(
          jsonEncode({'error': 'unauthorized'}),
          headers: {'content-type': 'application/json'},
        );
      }
      return inner(req.change(context: {_userKey: result.user!}));
    };
  };
}

AuthedUser userOf(Request req) => req.context[_userKey]! as AuthedUser;

Response _json(Map<String, dynamic> body, {int status = 200}) => Response(
  status,
  body: jsonEncode(body),
  headers: {'content-type': 'application/json'},
);

/// 라우터 구성.
Handler buildHandler({
  required ServerConfig config,
  required StateStore store,
}) {
  final verifier = SupabaseJwtVerifier(
    jwtSecret: config.jwtSecret,
    expectedIssuer: config.issuer,
  );

  final public = Router()
    // Cloud Run 헬스체크 — 인증 없이 접근 가능해야 한다.
    ..get('/healthz', (Request _) => Response.ok('ok'));

  final authed = Router()
    ..get('/state', (Request req) async {
      final user = userOf(req);
      try {
        final data = await store.load(user.id);
        return _json({
          'userId': user.id,
          'isAnonymous': user.isAnonymous,
          // 신규 유저면 null — P2 에서 서버가 초기 상태를 생성하도록 옮긴다.
          'save': data,
          'serverTime': DateTime.now().toUtc().toIso8601String(),
        });
      } on StateStoreException catch (e) {
        // 세부 내용은 서버 로그에만. 클라이언트에는 일반화된 메시지.
        stderr.writeln('[state] ${user.id}: $e');
        return _json({'error': 'store_unavailable'}, status: 503);
      }
    });

  final cascade = Cascade()
      .add(public.call)
      .add(
        const Pipeline()
            .addMiddleware(requireAuth(verifier))
            .addHandler(authed.call),
      );

  return const Pipeline()
      .addMiddleware(logRequests())
      .addHandler(cascade.handler);
}
