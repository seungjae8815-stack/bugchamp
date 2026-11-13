import 'dart:convert';
import 'dart:io';

import 'package:core_run/core_run.dart';
import 'package:test/test.dart';

/// 주말 이벤트 · 업적 데이터(2026-11-10).
void main() {
  final run = RunConfig.fromJson(
    jsonDecode(File('../app/assets/data/run_config.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  const kst = 540;
  DateTime k(int y, int m, int d, int h, [int min = 0]) =>
      DateTime.utc(y, m, d, h, min).subtract(const Duration(minutes: kst));

  group('주말 이벤트', () {
    // 2026-11-14 = 토요일.
    test('토요일 0시(KST)부터 48시간만 열린다', () {
      final w = run.weekendEvents;
      expect(w.at(k(2026, 11, 13, 23, 59), kst), isNull);
      final sat = w.at(k(2026, 11, 14, 0, 1), kst);
      expect(sat, isNotNull);
      expect(sat!.endsAt, k(2026, 11, 16, 0));
      expect(w.at(k(2026, 11, 15, 23, 59), kst)!.event.id, sat.event.id);
      expect(w.at(k(2026, 11, 16, 0), kst), isNull);
    });

    test('주마다 다른 이벤트 · 배율 키는 아는 키', () {
      final a = run.weekendEvents.at(k(2026, 11, 14, 12), kst)!.event;
      final b = run.weekendEvents.at(k(2026, 11, 21, 12), kst)!.event;
      expect(a.id, isNot(b.id));
      for (final e in run.weekendEvents.events) {
        expect(WeekendEvent.keys, containsAll(e.mult.keys), reason: e.id);
      }
    });
  });

  test('업적 — 종류는 아는 종류 · id 는 겹치지 않는다', () {
    expect(run.achievements, isNotEmpty);
    final ids = <String>{};
    for (final a in run.achievements) {
      expect(AchievementDef.kinds, contains(a.kind), reason: a.id);
      expect(ids.add(a.id), isTrue, reason: a.id);
      expect(a.title['ko'], isNotEmpty, reason: a.id);
    }
  });
}
