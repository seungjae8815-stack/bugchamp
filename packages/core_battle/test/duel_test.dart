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

    test('승자 연속 — 상대 세 마리를 모두 쓰러뜨려야 끝, 이긴 곤충이 계속 나간다', () {
      final strong = [
        for (var i = 0; i < 3; i++) _bug('a$i', Specialty.grip, scale: 3),
      ];
      final weak = [for (var i = 0; i < 3; i++) _bug('b$i', Specialty.grip)];
      final m = simulateDuel(seed: 5, teamA: strong, teamB: weak, params: p);
      expect(m.winner(p), 0);
      expect(m.bouts.length, 3, reason: '첫 곤충이 세 판을 다 이긴다');
      expect(m.winsA, 3);
      // 두 번째 판부터 A 는 **남은 체력**으로 들어온다(가득이 아니다).
      final st = duelNextState(m.bouts.take(1).toList(), strong, weak, p);
      expect(st.ia, 0);
      expect(st.ib, 1);
      expect(st.hpB, 1.0);
      expect(
        st.hpA,
        closeTo(duelCarryHp(m.bouts.first.hpPctA, strong.first, p), 1e-9),
      );
    });

    test('판 사이 회복 — 기본 회복 + 회복력, 가득을 넘지 않는다', () {
      final b = _bug('a', Specialty.grip);
      expect(duelCarryHp(0.4, b, p), closeTo(0.4 + p.carryHealBase, 1e-9));
      final tough = DuelBug.fromJson({...b.toJson(), 'rec': 0.3});
      expect(
        duelCarryHp(0.4, tough, p),
        closeTo(0.4 + p.carryHealBase + 0.3, 1e-9),
      );
      expect(duelCarryHp(0.99, tough, p), 1.0);
    });

    test('크리티컬·약점 공격은 사건으로 남는다(화면 표시용)', () {
      var crit = 0, weak = 0;
      for (var s = 1; s <= 40; s++) {
        final r = simulateBout(
          seed: s,
          a: _bug('a', Specialty.strike),
          b: _bug('b', Specialty.grip),
          params: p,
        );
        crit += r.events.where((e) => e.kind == DuelEventKind.crit).length;
        weak += r.events.where((e) => e.kind == DuelEventKind.weak).length;
      }
      expect(crit, greaterThan(0));
      expect(weak, greaterThanOrEqualTo(0));
    });

    test('판 시작 체력 — 덜 찬 체력으로 들어오면 그만큼 약하다', () {
      var lowWins = 0;
      for (var s = 1; s <= 40; s++) {
        final r = simulateBout(
          seed: s,
          a: _bug('a', Specialty.grip),
          b: _bug('b', Specialty.grip),
          params: p,
          hpA: 0.3,
        );
        if (r.winner == 0) lowWins++;
      }
      expect(lowWins / 40, lessThan(0.5));
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
      expect(q.winsNeeded, 5, reason: '승자 연속 — 팀 크기만큼 쓰러뜨려야 이긴다');
      expect(q.maxBouts, 9);
      expect(q.friction, const DuelParams().friction);
    });
  });
  group('약한 쪽의 여지(A·B·C, 2026-09-29)', () {
    double winRate(DuelParams q, {double scaleA = 1, double? la, double? lb}) {
      var w = 0;
      for (var i = 0; i < 200; i++) {
        final r = simulateBout(
          seed: 900 + i * 31,
          a: _bug(
            'a',
            Specialty.values[i % 3],
            scale: scaleA,
            tm: Temperament.values[i % 5],
          ),
          b: _bug(
            'b',
            Specialty.values[(i ~/ 3) % 3],
            tm: Temperament.values[(i ~/ 5) % 5],
          ),
          params: q,
          launchA: la,
          launchB: lb,
        );
        if (r.winner == 0) w++;
      }
      return w / 200;
    }

    test('전력 압축을 켜면 센 쪽 승률이 내려간다', () {
      final off = winRate(const DuelParams(), scaleA: 1.2);
      final on = winRate(const DuelParams(statCompress: 0.5), scaleA: 1.2);
      expect(on, lessThan(off));
      expect(on, greaterThan(0.5)); // 그래도 센 쪽이 이긴다
    });

    test('게이지 공격 보너스 — 자동값 아래는 효과 없음, 만점은 이득', () {
      const q = DuelParams(launchPowerMax: 0.3);
      final auto = winRate(q, la: q.launchAuto, lb: q.launchAuto);
      final low = winRate(q, la: 0, lb: q.launchAuto);
      final perfect = winRate(q, la: 1, lb: q.launchAuto);
      expect(perfect, greaterThan(auto));
      // 게이지 0 은 첫 돌진 속도만 약간 느리다(공격 벌칙 없음).
      expect(low, greaterThan(auto - 0.15));
    });

    test('기본값(1·0·1·1)이면 예전 엔진과 같은 결과', () {
      final a = _bug('a', Specialty.strike, scale: 1.3);
      final b = _bug('b', Specialty.toss);
      const q = DuelParams(
        statCompress: 1,
        launchPowerMax: 0,
        leverageStatExp: 1,
        leverageMassExp: 1,
      );
      final r1 = simulateBout(seed: 7, a: a, b: b, params: q);
      final r2 = simulateBout(seed: 7, a: a, b: b, params: const DuelParams());
      expect(jsonEncode(r1.toJson()), jsonEncode(r2.toJson()));
    });
  });

  group('흡혈 — 회복력이 판 안에서도 쓰인다(2026-09-30)', () {
    test('lifestealMult 0 이면 회복력이 있어도 판 결과가 예전과 같다', () {
      final a = _bug('a', Specialty.strike).withTraining(recovery: 0.3);
      final b = _bug('b', Specialty.strike);
      final plain = _bug('a', Specialty.strike);
      const off = DuelParams(lifestealMult: 0);
      for (var s = 0; s < 5; s++) {
        final r1 = simulateBout(seed: s, a: a, b: b, params: off);
        final r2 = simulateBout(seed: s, a: plain, b: b, params: off);
        expect(r1.hpPctA, r2.hpPctA);
        expect(r1.winner, r2.winner);
      }
    });

    test('흡혈이 켜지면 회복력 있는 쪽이 더 많은 체력으로 끝난다(평균)', () {
      final a = _bug('a', Specialty.strike).withTraining(recovery: 0.3);
      final plain = _bug('a', Specialty.strike);
      final b = _bug('b', Specialty.strike, scale: 0.8);
      const on = DuelParams(lifestealMult: 1);
      var withLs = 0.0, without = 0.0;
      for (var s = 0; s < 30; s++) {
        withLs += simulateBout(seed: s, a: a, b: b, params: on).hpPctA;
        without += simulateBout(seed: s, a: plain, b: b, params: on).hpPctA;
      }
      expect(withLs, greaterThan(without));
    });
  });

  group('밀어내기 힘(2026-10-09 속도 칸 자리)', () {
    test('1 이면 예전 엔진과 같은 판 · JSON 왕복(pm)', () {
      final a = _bug('a', Specialty.strike);
      final b = _bug('b', Specialty.grip);
      for (var s = 0; s < 5; s++) {
        final r1 = simulateBout(seed: s, a: a.withTraining(), b: b, params: p);
        final r2 = simulateBout(seed: s, a: a, b: b, params: p);
        expect(jsonEncode(r1.toJson()), jsonEncode(r2.toJson()));
      }
      final pushed = a.withTraining(pushMult: 1.4);
      expect(pushed.pushMult, 1.4);
      final back = DuelBug.fromJson(
        jsonDecode(jsonEncode(pushed.toJson())) as Map<String, dynamic>,
      );
      expect(back.pushMult, 1.4);
      expect(a.toJson().containsKey('pm'), isFalse); // 기본값은 키 생략
      // 한 판 안 수치·크기를 바꿔도 밀어내기 힘은 그대로 따라간다.
      expect(pushed.copyWith(sizeMm: 70).pushMult, 1.4);
      expect(pushed.withCombatStats(maxHp: 1, atk: 1, def: 1).pushMult, 1.4);
    });

    test('같은 스탯 거울전에서 밀어내기 힘이 큰 쪽이 더 이긴다(주특기 섞음)', () {
      var w = 0;
      const n = 240;
      for (var i = 0; i < n; i++) {
        final spc = Specialty.values[i % 3];
        final flip = i.isOdd;
        final strong = _bug('s', spc).withTraining(pushMult: 1.5);
        final plain = _bug('p', spc);
        final r = simulateBout(
          seed: 4000 + i,
          a: flip ? plain : strong,
          b: flip ? strong : plain,
          params: p,
        );
        if (r.winner == (flip ? 1 : 0)) w++;
      }
      expect(w / n, greaterThan(0.55));
    });
  });
}
