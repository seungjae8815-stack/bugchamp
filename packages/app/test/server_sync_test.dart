import 'package:app/domain/game_server.dart';
import 'package:app/domain/server_sync.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('fetchStateWithAuthRetry — 콜드스타트 토큰 갱신 경쟁', () {
    // 실제 지연을 기다리지 않도록 0 으로.
    const noWait = Duration.zero;

    test('첫 조회가 성공하면 재시도하지 않는다', () async {
      var calls = 0;
      final r = await fetchStateWithAuthRetry(() async {
        calls++;
        return ServerResult.ok({'save': null});
      }, delay: noWait);
      expect(r.isOk, isTrue);
      expect(calls, 1);
    });

    test('401 몇 번 뒤 토큰이 준비되면 결국 성공한다', () async {
      var calls = 0;
      final r = await fetchStateWithAuthRetry(() async {
        calls++;
        // 처음 3번은 토큰 갱신 중(401), 그 뒤 성공.
        return calls < 4
            ? const ServerResult.fail('unauthorized', 401)
            : ServerResult.ok({'save': null});
      }, delay: noWait);
      expect(r.isOk, isTrue);
      expect(calls, 4);
    });

    test('계속 401 이면 재시도를 소진하고 마지막 실패를 돌려준다', () async {
      var calls = 0;
      final r = await fetchStateWithAuthRetry(
        () async {
          calls++;
          return const ServerResult.fail('unauthorized', 401);
        },
        maxAttempts: 5,
        delay: noWait,
      );
      expect(r.isOk, isFalse);
      expect(r.status, 401);
      expect(calls, 5); // 최초 1 + 재시도 4
    });

    test('인증과 무관한 실패(404)는 재시도하지 않는다', () async {
      var calls = 0;
      final r = await fetchStateWithAuthRetry(() async {
        calls++;
        return const ServerResult.fail('not_found', 404);
      }, delay: noWait);
      expect(r.isOk, isFalse);
      expect(calls, 1); // 404 는 즉시 포기 — 토큰 문제가 아니다
    });

    test('네트워크(0)·5xx 도 재시도 대상', () async {
      var calls = 0;
      final r = await fetchStateWithAuthRetry(() async {
        calls++;
        if (calls == 1) return const ServerResult.fail('network', 0);
        if (calls == 2) return const ServerResult.fail('boom', 503);
        return ServerResult.ok({'save': null});
      }, delay: noWait);
      expect(r.isOk, isTrue);
      expect(calls, 3);
    });
  });
}
