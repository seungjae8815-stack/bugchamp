import 'package:app/domain/device_session.dart';
import 'package:app/domain/game_server.dart';
import 'package:app/domain/server_sync.dart';
import 'package:core_save/core_save.dart';
import 'package:flutter_test/flutter_test.dart';

/// 업로드는 늘 "다른 기기에 밀려남"으로 거절하는 서버. 첫 이관을 불렀는지 센다.
class _TakenServer extends NoGameServer {
  int bootstraps = 0;

  @override
  bool get available => true;

  @override
  Future<ServerResult> uploadSave(Map<String, dynamic> save) async =>
      const ServerResult.fail('session_taken', 409);

  @override
  Future<ServerResult> bootstrap(Map<String, dynamic> save) async {
    bootstraps++;
    return const ServerResult.fail('already_exists', 409);
  }
}

void main() {
  // 한 기기만 접속(2026-10-03, 1.0.16).
  group('한 기기만 접속', () {
    test('표식은 서버가 받아 주는 모양이다(영숫자 8~64자)', () {
      expect(
        RegExp(r'^[A-Za-z0-9_-]{8,64}$').hasMatch(DeviceSession.id),
        isTrue,
      );
    });

    test('session_taken 409 만 밀려남이다 — 저장본 없음(409)은 아니다', () {
      expect(
        isSessionTaken(const ServerResult.fail('session_taken', 409)),
        isTrue,
      );
      expect(isSessionTaken(const ServerResult.fail('no_save', 409)), isFalse);
      expect(
        isSessionTaken(const ServerResult.fail('session_taken', 500)),
        isFalse,
      );
    });

    test('밀려난 기기는 서버 액션 전 업로드가 실패하고, 첫 이관으로 오해하지 않는다', () async {
      final server = _TakenServer();
      final ok = await flushSaveBeforeServerAction(
        server,
        () => SaveGame.initial(createdAt: DateTime.utc(2026, 10, 3)),
      );
      expect(ok, isFalse);
      expect(server.bootstraps, 0);
    });
  });
}
