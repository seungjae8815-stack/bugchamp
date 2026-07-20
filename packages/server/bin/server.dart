import 'dart:io';

import 'package:server/src/app.dart';
import 'package:server/src/game_config.dart';
import 'package:server/src/state_store.dart';
import 'package:server/src/verifier.dart';
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

  // 밸런스 JSON 로드 — 없으면 쓰기 엔드포인트가 등록되지 않으므로 즉시 실패시킨다
  // (조용히 읽기 전용으로 뜨면 클라이언트가 404 를 받고 원인을 못 찾는다).
  final GameConfig gameConfig;
  try {
    gameConfig = await GameConfig.load();
  } catch (e) {
    stderr.writeln('게임 데이터 로드 실패: $e');
    exitCode = 78; // EX_CONFIG
    return;
  }

  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final server = await io.serve(
    buildHandler(
      config: config,
      store: store,
      gameConfig: gameConfig,
      speciesById: gameConfig.speciesById,
      receiptVerifier: EdgeFunctionVerifier(
        supabaseUrl: config.supabaseUrl,
        anonKey: config.anonKey,
      ),
    ),
    InternetAddress.anyIPv4,
    port,
  );
  stdout.writeln('bugchamp server listening on :${server.port}');
}
