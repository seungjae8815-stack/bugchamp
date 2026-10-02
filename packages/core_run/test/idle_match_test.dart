import 'dart:convert';
import 'dart:io';

import 'package:core_run/core_run.dart';
import 'package:test/test.dart';

void main() {
  final b = BattleConfig.fromJson(
    jsonDecode(File('../app/assets/data/battle.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  test('아직 안 싸운 상대 점수 — 센 상대일수록 높다(3·4·5 / 2·1)', () {
    expect(b.idleMatchPoints(1.5), 5);
    expect(b.idleMatchPoints(1.1), 4);
    expect(b.idleMatchPoints(1.0), 3);
    expect(b.idleMatchPoints(0.9), 2);
    expect(b.idleMatchPoints(0.5), 1);
  });
}
