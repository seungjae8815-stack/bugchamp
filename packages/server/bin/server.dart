import 'dart:io';

import 'package:server/src/app.dart';
import 'package:server/src/state_store.dart';
import 'package:shelf/shelf_io.dart' as io;

/// Bug Champ 권위 서버 진입점.
///
/// 실행에 필요한 환경변수:
///   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
/// (JWT 시크릿은 불필요 — 비대칭 서명이라 공개키 JWKS 로 검증한다)
/// Cloud Run 은 PORT 를 주입한다(없으면 8080).
Future<void> main() async {
  final ServerConfig config;
  try {
    config = ServerConfig.fromEnv(Platform.environment);
  } on StateError catch (e) {
    stderr.writeln('설정 오류: ${e.message}');
    exitCode = 78; // EX_CONFIG
    return;
  }

  final store = StateStore(
    supabaseUrl: config.supabaseUrl,
    serviceRoleKey: config.serviceRoleKey,
  );

  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final server = await io.serve(
    buildHandler(config: config, store: store),
    InternetAddress.anyIPv4,
    port,
  );
  stdout.writeln('bugchamp server listening on :${server.port}');
}
