import 'package:server/src/ops_monitor.dart';
import 'package:test/test.dart';

void main() {
  late DateTime now;
  late List<String> sent;
  OpsMonitor make() {
    sent = [];
    now = DateTime.utc(2026, 9, 15, 3);
    return OpsMonitor(
      send: (t) async {
        sent.add(t);
        return true;
      },
      clock: () => now,
    );
  }

  test('5xx 가 10분 안에 기준을 넘으면 한 번 알리고, 쿨타임 동안은 조용하다', () {
    final m = make();
    for (var i = 0; i < 19; i++) {
      m.recordResponse('/save', 500, Duration.zero);
    }
    expect(sent, isEmpty);
    m.recordResponse('/save', 503, Duration.zero);
    expect(sent.single, contains('서버 오류 급증'));
    expect(sent.single, contains('/save 20'));
    for (var i = 0; i < 30; i++) {
      m.recordResponse('/sync', 500, Duration.zero);
    }
    expect(sent.length, 1, reason: '쿨타임(30분) 안에는 다시 안 보낸다');
  });

  test('오류가 창(10분)에 흩어져 있으면 급증으로 보지 않는다', () {
    final m = make();
    for (var i = 0; i < 40; i++) {
      m.recordResponse('/save', 500, Duration.zero);
      now = now.add(const Duration(minutes: 1));
      if (i % 10 == 9) now = now.add(const Duration(minutes: 10));
    }
    expect(sent.where((t) => t.contains('급증')), isEmpty);
  });

  test('1시간 요약 — 잘린 업로드·위조·큰 세이브를 모아 보낸다', () {
    final m = make();
    m.recordClamp('3f2a0000-aaaa', ['gold', 'jelly']);
    m.recordClamp('3f2a0000-aaaa', ['material:chitin']);
    m.recordForged('bbbb1111', 'potential');
    m.recordSaveSize('cccc2222', 400 * 1024);
    m.recordResponse('/save', 200, Duration.zero);
    expect(sent, isEmpty, reason: '한 시간이 안 됐다');
    now = now.add(const Duration(hours: 1, minutes: 1));
    m.recordResponse('/save', 200, Duration.zero);
    final text = sent.single;
    expect(text, contains('서버 요약'));
    expect(text, contains('3f2a0000 골드·젤리·재료 ×2'));
    expect(text, contains('bbbb1111 potential'));
    expect(text, contains('cccc2222 400KB'));
  });

  test('아무 일도 없으면 요약을 보내지 않는다', () {
    final m = make();
    m.recordResponse('/save', 200, Duration.zero);
    now = now.add(const Duration(hours: 2));
    m.recordResponse('/save', 200, Duration.zero);
    expect(sent, isEmpty);
  });

  test('상한 근처 세이브는 즉시 알린다(계정마다 쿨타임)', () {
    final m = make();
    m.recordSaveSize('dddd3333', 100 * 1024);
    expect(sent, isEmpty);
    m.recordSaveSize('dddd3333', 800 * 1024);
    m.recordSaveSize('dddd3333', 810 * 1024);
    expect(sent.length, 1);
    expect(sent.single, contains('세이브가 너무 큼'));
  });
}
