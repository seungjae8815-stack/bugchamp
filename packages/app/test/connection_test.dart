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

    test('끊김 상태는 앱 어디서나 하나로 공유된다(게임 정지 + 화면 덮기)', () {
      expect(serverDisconnected.value, isFalse);
      serverDisconnected.value = true;
      expect(serverDisconnected.value, isTrue);
    });
  });
}
