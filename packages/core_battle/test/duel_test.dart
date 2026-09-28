import 'dart:convert';

import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';
import 'package:test/test.dart';

DuelBug _bug(
  String id,
  Specialty spc, {
  double scale = 1,
  Temperament tm = Temperament.steadfast,
  Element el = Element.wood,
  double size = 50,
}) => DuelBug(
  id: id,
  name: id,
  speciesId: id,
  element: el,
  temperament: tm,
  specialty: spc,
  sizeMm: size,
  maxHp: 150 * scale,
  atk: 60 * scale,
  def: 50 * scale,
  spd: 50 * scale,
);

void main() {
  const p = DuelParams();

  group('결정론(§2.3)', () {
    test('같은 시드·같은 입력이면 궤적까지 같다', () {
      final a = _bug('a', Specialty.strike);
      final b = _bug('b', Specialty.grip);
      final r1 = simulateBout(seed: 42, a: a, b: b, params: p, launchA: 0.8);
      final r2 = simulateBout(seed: 42, a: a, b: b, params: p, launchA: 0.8);
      expect(jsonEncode(r1.toJson()), jsonEncode(r2.toJson()));
    });

    test('시드가 다르면 결과가 갈린다(무작위가 실제로 쓰인다)', () {
      final a = _bug('a', Specialty.strike, tm: Temperament.fickle);
      final b = _bug('b', Specialty.strike, tm: Temperament.fickle);
      final outs = {
        for (var s = 0; s < 40; s++)
          jsonEncode(simulateBout(seed: s, a: a, b: b, params: p).toJson()),
      };
      expect(outs.length, greaterThan(20));
    });
  });

  group('규칙', () {
    test('판은 반드시 승자가 있고 결판 방법이 기록된다', () {
      for (var s = 0; s < 60; s++) {
        final r = simulateBout(
          seed: s,
          a: _bug('a', Specialty.values[s % 3]),
          b: _bug('b', Specialty.values[(s ~/ 3) % 3]),
          params: p,
        );
        expect(r.winner, anyOf(0, 1));
        expect(r.ticks, lessThanOrEqualTo(p.maxTicks));
        expect(r.frames, isNotEmpty);
        if (r.finish != DuelFinish.timeUp) {
          // 결판 사건의 who 는 **진 쪽**이다.
          final end = r.events.last;
          expect(end.who, 1 - r.winner, reason: r.finish.key);
        }
      }
    });

    test('같은 스탯 대칭 대전은 한쪽으로 쏠리지 않는다(자리 편향 없음)', () {
      var aw = 0;
      const n = 300;
      for (var i = 0; i < n; i++) {
        final spc = Specialty.values[i % 3];
        final r = simulateBout(
          seed: 7 + i * 131,
          a: _bug('a', spc, tm: Temperament.values[i % 5]),
          b: _bug('b', spc, tm: Temperament.values[(i ~/ 5) % 5]),
          params: p,
        );
        if (r.winner == 0) aw++;
      }
      expect(aw / n, inInclusiveRange(0.4, 0.6));
    });

    test('전력이 크게 앞서면 대부분 이긴다', () {
      var aw = 0;
      const n = 200;
      for (var i = 0; i < n; i++) {
        final r = simulateBout(
          seed: 11 + i * 17,
          a: _bug('a', Specialty.values[i % 3], scale: 1.6),
          b: _bug('b', Specialty.values[(i ~/ 3) % 3]),
          params: p,
        );
        if (r.winner == 0) aw++;
      }
      expect(aw / n, greaterThan(0.8));
    });

    test('3판 2선승 — 두 판을 먼저 이기면 3판째는 없다', () {
      final strong = [
        for (var i = 0; i < 3; i++) _bug('a$i', Specialty.grip, scale: 3),
      ];
      final weak = [for (var i = 0; i < 3; i++) _bug('b$i', Specialty.grip)];
      final m = simulateDuel(seed: 5, teamA: strong, teamB: weak, params: p);
      expect(m.winner(p), 0);
      expect(m.bouts.length, 2);
    });

    test('판 시드는 판마다 다르다', () {
      expect(duelBoutSeed(9, 0), isNot(duelBoutSeed(9, 1)));
      expect(duelBoutSeed(9, 1), duelBoutSeed(9, 1));
    });
  });

  group('직렬화', () {
    test('판 결과 JSON 왕복', () {
      final r = simulateBout(
        seed: 3,
        a: _bug('a', Specialty.toss),
        b: _bug('b', Specialty.strike),
        params: p,
      );
      final back = DuelBout.fromJson(
        jsonDecode(jsonEncode(r.toJson())) as Map<String, dynamic>,
      );
      expect(back.winner, r.winner);
      expect(back.finish, r.finish);
      expect(back.frames.length, r.frames.length);
      expect(back.events.length, r.events.length);
      // 프레임 한 줄 = 곤충 둘 × 6값.
      expect(back.frames.first.length, 12);
    });

    test('곤충 JSON 왕복', () {
      final b = _bug('x', Specialty.grip, el: Element.metal, size: 77.5);
      final back = DuelBug.fromJson(
        jsonDecode(jsonEncode(b.toJson())) as Map<String, dynamic>,
      );
      expect(back.toJson(), b.toJson());
    });

    test('수치는 JSON 에서 오고, 없는 키는 코드 기본값', () {
      final q = DuelParams.fromJson({'gripForce': 123, 'bestOf': 5});
      expect(q.gripForce, 123);
      expect(q.winsNeeded, 3);
      expect(q.friction, const DuelParams().friction);
    });
  });
}
