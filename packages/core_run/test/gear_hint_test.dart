import 'dart:convert';
import 'dart:io';

import 'package:core_run/core_run.dart';
import 'package:test/test.dart';

RunConfig _real() => RunConfig.fromJson(
  jsonDecode(File('../app/assets/data/run_config.json').readAsStringSync())
      as Map<String, dynamic>,
);

/// 관문 앞 장비 안내(2026-09-09). 안내는 **벽을 만들지 않는다** — 왜 막히는지
/// 말할 뿐이다. 다만 숫자가 시뮬의 가정과 갈리면 거짓말이 된다.
void main() {
  group('장비 권장치', () {
    test('0 에서 시작해 완성 시점에 완성치가 된다', () {
      final c = _real();
      expect(c.gearHintAt(0), closeTo(1.0, 1e-9));
      expect(c.gearHintAt(c.gearHintFullStage), closeTo(c.gearHintMult, 1e-9));
      // 그 뒤로는 더 오르지 않는다 — 권장은 상한이 아니라 목표다.
      expect(
        c.gearHintAt(c.gearHintFullStage * 3),
        closeTo(c.gearHintMult, 1e-9),
      );
    });

    test('중간은 선형으로 오른다', () {
      final c = _real();
      final half = c.gearHintAt(c.gearHintFullStage ~/ 2);
      expect(half, closeTo(1 + (c.gearHintMult - 1) / 2, 1e-6));
    });

    test('⚠️ 실데이터가 balance_sim 의 평균 유저 장비 가정과 같다', () {
      // 시뮬이 "장비 x1.70 을 900 스테이지에 갖춘 유저"로 22일을 재고 있다.
      // 안내가 그보다 약한 값을 권하면 그대로 따라간 유저가 벽에 막힌다.
      final c = _real();
      expect(c.gearHintMult, 1.70);
      expect(c.gearHintFullStage, 900);
    });
  });
}
