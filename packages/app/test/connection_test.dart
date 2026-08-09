import 'package:app/domain/server_sync.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => serverDisconnected.value = false);
  tearDown(() => serverDisconnected.value = false);

  group('연결 끊김 판정', () {
    test('한 번 실패로는 끊김이 아니다 — 잠깐 끊길 때마다 쫓아내면 안 된다', () {
      expect(ServerSaveUploader.failThreshold, greaterThan(1));
    });

    test('재시도 간격이 업로드 주기보다 짧다 — 저장 안 되는 줄 모르고 놀면 안 된다', () {
      expect(
        ServerSaveUploader.retryDelay,
        lessThan(ServerSaveUploader.period),
      );
    });

    test('네트워크 오류(status 0)만 끊김이다', () {
      expect(countsAsDisconnect(0), isTrue);
    });

    test('게스트의 401(no_session)은 끊김이 아니다 — 세면 로그인 안 한 유저가 못 논다', () {
      expect(countsAsDisconnect(401), isFalse);
    });

    test('서버가 응답했다면 네트워크는 멀쩡하다 — 4xx·5xx 도 끊김이 아니다', () {
      for (final s in [400, 403, 409, 413, 500, 502, 503]) {
        expect(countsAsDisconnect(s), isFalse, reason: 'status $s');
      }
    });

    test('끊김 상태는 앱 어디서나 하나로 공유된다(게임 정지 + 화면 덮기)', () {
      expect(serverDisconnected.value, isFalse);
      serverDisconnected.value = true;
      expect(serverDisconnected.value, isTrue);
    });
  });
}
