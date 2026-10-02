import 'dart:convert';
import 'dart:io';

import 'package:core_run/core_run.dart';
import 'package:test/test.dart';

void main() {
  final cfg = FairyConfig.fromJson(
    jsonDecode(File('../app/assets/data/fairies.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  test('요정 도감 마일스톤 — 늘어나는 칸 수 · 전체 칸 이하 · 젤리 없음 · 가속기 id 가 진짜', () {
    final ms = cfg.dexMilestones;
    expect(ms, isNotEmpty);
    final cells = cfg.kinds.length * (5 + cfg.subWeight.length);
    final accels = {for (final a in cfg.accelerators) a.id};
    for (var i = 0; i < ms.length; i++) {
      if (i > 0) expect(ms[i].count, greaterThan(ms[i - 1].count));
      expect(ms[i].count, lessThanOrEqualTo(cells));
      for (final id in ms[i].accelerators.keys) {
        expect(accels, contains(id), reason: id);
      }
    }
    final raw =
        jsonDecode(File('../app/assets/data/fairies.json').readAsStringSync())
            as Map<String, dynamic>;
    for (final m in raw['dexMilestones'] as List) {
      expect((m as Map).containsKey('jelly'), isFalse, reason: '젤리 금지');
    }
  });
}
