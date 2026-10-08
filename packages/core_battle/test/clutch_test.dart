// 훈련 v2 엔진(docs/design_training_v2.md §1.2·§4) — 주특기 기술 · 탭 반격(근성) · 크기 몫 덜어내기.
import 'dart:convert';
import 'dart:math' as math;

import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';
import 'package:test/test.dart';

DuelBug _bug(
  String id,
  Specialty spc, {
  double scale = 1,
  Temperament tm = Temperament.steadfast,
  double size = 50,
}) => DuelBug(
  id: id,
  name: id,
  speciesId: id,
  element: Element.wood,
  temperament: tm,
  specialty: spc,
  sizeMm: size,
  maxHp: 150 * scale,
  atk: 60 * scale,
  def: 50 * scale,
  spd: 50 * scale,
);

const _on = DuelParams(clutchEnabled: true);

Iterable<DuelEvent> _of(DuelBout b, DuelEventKind k, [int? who]) =>
    b.events.where((e) => e.kind == k && (who == null || e.who == who));

/// 플레이어(A) 위기가 처음 오는 판의 seed 를 찾는다.
int _seedWithPlayerCrisis(DuelBug a, DuelBug b, {DuelParams p = _on}) {
  for (var s = 1; s < 500; s++) {
    final r = simulateBout(seed: s, a: a, b: b, params: p, clutchScores: []);
    if (r.pending != null) return s;
  }
  throw StateError('플레이어 위기가 나오는 seed 가 없다');
}

void main() {
  final a = _bug('a', Specialty.strike, tm: Temperament.aggressive);
  final b = _bug('b', Specialty.grip, tm: Temperament.cunning);

  group('주특기 기술(tech)', () {
    double winRate(Specialty s, double tech, {int n = 300}) {
      var w = 0;
      for (var i = 0; i < n; i++) {
        final r = simulateBout(
          seed: 100 + i * 7919,
          a: _bug(
            'a',
            s,
            tm: Temperament.values[i % 5],
          ).withTraining(tech: tech),
          b: _bug('b', s, tm: Temperament.values[(i ~/ 5) % 5]),
          params: const DuelParams(),
        );
        if (r.aWon) w++;
      }
      return w / n;
    }

    test('세 주특기 모두 기술이 있으면 같은 주특기 거울전을 더 이긴다', () {
      for (final s in Specialty.values) {
        expect(winRate(s, 0.3), greaterThan(0.55), reason: '$s');
      }
    });

    test('치기 기술 = 뒤집기가 늘어난다', () {
      var plain = 0, teched = 0;
      for (var i = 0; i < 300; i++) {
        DuelBout go(double t) => simulateBout(
          seed: 9 + i * 31,
          a: _bug('a', Specialty.strike).withTraining(tech: t),
          b: _bug('b', Specialty.strike),
          params: const DuelParams(),
        );
        if (go(0).finish == DuelFinish.flip) plain++;
        if (go(0.3).finish == DuelFinish.flip) teched++;
      }
      expect(teched, greaterThan(plain));
    });

    test('던지기 기술 = 쿨타임이 짧아져 더 자주 던진다', () {
      var plain = 0, teched = 0;
      for (var i = 0; i < 100; i++) {
        DuelBout go(double t) => simulateBout(
          seed: 5 + i * 13,
          a: _bug('a', Specialty.toss).withTraining(tech: t),
          b: _bug('b', Specialty.toss),
          params: const DuelParams(),
        );
        plain += _of(go(0), DuelEventKind.toss, 0).length;
        teched += _of(go(0.3), DuelEventKind.toss, 0).length;
      }
      expect(teched, greaterThan(plain));
    });

    test('기술은 techMax 에서 잘린다(위조 세이브가 큰 값을 적어 와도)', () {
      for (final s in Specialty.values) {
        final capped = simulateBout(
          seed: 77,
          a: _bug('a', s).withTraining(tech: 0.3),
          b: _bug('b', s),
          params: const DuelParams(),
        );
        final forged = simulateBout(
          seed: 77,
          a: _bug('a', s).withTraining(tech: 9),
          b: _bug('b', s),
          params: const DuelParams(),
        );
        expect(jsonEncode(forged.toJson()), jsonEncode(capped.toJson()));
      }
    });
  });

  group('탭 반격 — 위기에서 멈추고 같은 입력이면 같은 판', () {
    test('점수가 떨어지면 멈추고 자리를 돌려준다', () {
      final s = _seedWithPlayerCrisis(a, b);
      final r = simulateBout(
        seed: s,
        a: a,
        b: b,
        params: _on,
        clutchScores: [],
      );
      final pc = r.pending!;
      expect(r.winner, -1);
      expect(r.done, isFalse);
      expect(pc.index, 0);
      expect(r.events.last.kind, DuelEventKind.clutch);
      expect(r.events.last.who, 0);
      expect(r.events.last.tick, pc.tick);
      expect(r.events.last.value, pc.kind.index);
      // JSON 왕복.
      final back = DuelBout.fromJson(
        jsonDecode(jsonEncode(r.toJson())) as Map<String, dynamic>,
      );
      expect(back.pending!.kind, pc.kind);
      expect(back.pending!.tick, pc.tick);
    });

    test('같은 seed + 같은 점수면 완전히 같은 판(서버가 상태 없이 재계산)', () {
      final s = _seedWithPlayerCrisis(a, b);
      for (final scores in [
        <double>[],
        [0.9],
        [0.1],
      ]) {
        final r1 = simulateBout(
          seed: s,
          a: a,
          b: b,
          params: _on,
          clutchScores: scores,
        );
        final r2 = simulateBout(
          seed: s,
          a: a,
          b: b,
          params: _on,
          clutchScores: List.of(scores),
        );
        expect(jsonEncode(r1.toJson()), jsonEncode(r2.toJson()));
      }
    });

    test('멈춘 판의 궤적·사건은 점수를 넣고 다시 계산한 판의 앞부분과 같다', () {
      final s = _seedWithPlayerCrisis(a, b);
      final stop = simulateBout(
        seed: s,
        a: a,
        b: b,
        params: _on,
        clutchScores: [],
      );
      for (final score in [0.0, 1.0]) {
        final full = simulateBout(
          seed: s,
          a: a,
          b: b,
          params: _on,
          clutchScores: [score],
        );
        expect(full.frames.length, greaterThanOrEqualTo(stop.frames.length));
        expect(
          jsonEncode(full.frames.sublist(0, stop.frames.length)),
          jsonEncode(stop.frames),
        );
        expect(
          jsonEncode([
            for (final e in full.events.take(stop.events.length)) e.toJson(),
          ]),
          jsonEncode([for (final e in stop.events) e.toJson()]),
        );
        // 다음 사건이 그 위기의 결과다.
        final next = full.events[stop.events.length];
        expect(next.who, 0);
        expect(
          next.kind,
          score >= 0.55 ? DuelEventKind.clutchSave : DuelEventKind.clutchFail,
        );
      }
    });

    test('점수를 하나씩 늘려 가면 끝까지 간다(위기마다 멈춤)', () {
      var hits = 0;
      for (var s = 1; s < 60; s++) {
        final scores = <double>[];
        DuelBout r;
        var guard = 0;
        do {
          r = simulateBout(
            seed: s,
            a: a,
            b: b,
            params: _on,
            clutchScores: scores,
          );
          if (r.pending != null) {
            expect(r.pending!.index, scores.length);
            scores.add(1.0);
            hits++;
          }
        } while (r.pending != null && ++guard < 5);
        expect(r.done, isTrue);
        expect(r.playerClutches, scores.length);
      }
      expect(hits, greaterThan(0));
    });
  });

  group('탭 반격 — 횟수·문턱', () {
    test('한 판에 곤충마다 1번(근성 5 이상이면 2번)', () {
      var sawTwo = false;
      for (var s = 1; s < 200; s++) {
        for (final grit in [0, 5]) {
          final r = simulateBout(
            seed: s,
            a: a.withTraining(grit: grit),
            b: b.withTraining(grit: grit),
            params: _on,
            clutchScores: List.filled(5, 1.0),
          );
          final mine = _of(r, DuelEventKind.clutch, 0).length;
          final theirs = _of(r, DuelEventKind.clutch, 1).length;
          final cap = grit >= 5 ? 2 : 1;
          expect(mine, lessThanOrEqualTo(cap));
          expect(theirs, lessThanOrEqualTo(cap));
          if (grit >= 5 && mine == 2) sawTwo = true;
        }
      }
      expect(sawTwo, isTrue);
    });

    test('문턱 = 0.55 − 근성 × 0.02', () {
      final s = _seedWithPlayerCrisis(a, b);
      DuelEventKind outcome(int grit, double score) {
        final r = simulateBout(
          seed: s,
          a: a.withTraining(grit: grit),
          b: b,
          params: _on,
          clutchScores: [score],
        );
        return r.events
            .firstWhere(
              (e) =>
                  e.who == 0 &&
                  (e.kind == DuelEventKind.clutchSave ||
                      e.kind == DuelEventKind.clutchFail),
            )
            .kind;
      }

      expect(outcome(0, 0.549), DuelEventKind.clutchFail);
      expect(outcome(0, 0.55), DuelEventKind.clutchSave);
      expect(outcome(5, 0.449), DuelEventKind.clutchFail);
      expect(outcome(5, 0.451), DuelEventKind.clutchSave);
    });

    test('근성은 clutchGritMax 에서 잘린다', () {
      final s = _seedWithPlayerCrisis(a, b);
      final capped = simulateBout(
        seed: s,
        a: a.withTraining(grit: 10),
        b: b,
        params: _on,
      );
      final forged = simulateBout(
        seed: s,
        a: a.withTraining(grit: 99),
        b: b,
        params: _on,
      );
      expect(jsonEncode(forged.toJson()), jsonEncode(capped.toJson()));
    });

    test('깨우기 성공 = 체력 10% + 근성 × 1% 로 일어난다', () {
      var checked = 0;
      for (var s = 1; s < 400 && checked < 3; s++) {
        final r = simulateBout(
          seed: s,
          a: _bug('a', Specialty.toss),
          b: _bug('b', Specialty.toss),
          params: _on,
          clutchScores: List.filled(3, 1.0),
        );
        final crisis = r.events.where(
          (e) =>
              e.kind == DuelEventKind.clutch &&
              e.who == 0 &&
              e.value == DuelCrisis.knockout.index,
        );
        if (crisis.isEmpty) continue;
        final t = crisis.first.tick;
        // 위기 틱 뒤 첫 프레임의 A 체력(천분율) — 일어났으니 0 보다 크고 대략 10% 근처.
        final fi = (t ~/ _on.frameEvery) + 1;
        if (fi >= r.frames.length) continue;
        final hp = r.frames[fi][4];
        expect(hp, greaterThan(0));
        expect(hp, lessThanOrEqualTo(110));
        checked++;
      }
      expect(checked, greaterThan(0));
    });
  });

  group('탭 반격 — 상대 자동 점수 · 결정론', () {
    test('상대 점수는 판 seed 전용 난수(0.5 + 근성 × 0.02 ± 0.15)', () {
      var checked = 0;
      for (var s = 1; s < 300 && checked < 5; s++) {
        final r = simulateBout(
          seed: s,
          a: a,
          b: b.withTraining(grit: 3),
          params: _on,
          clutchScores: List.filled(3, 0.0),
        );
        final first = _of(r, DuelEventKind.clutch, 1);
        if (first.isEmpty) continue;
        final res = r.events.firstWhere(
          (e) =>
              e.who == 1 &&
              (e.kind == DuelEventKind.clutchSave ||
                  e.kind == DuelEventKind.clutchFail),
        );
        final want =
            0.5 +
            3 * 0.02 +
            (math.Random(duelClutchSeed(s, 1)).nextDouble() * 2 - 1) * 0.15;
        expect(res.value, (want * 1000).round());
        expect(
          res.kind,
          want >= 0.55 - 3 * 0.02
              ? DuelEventKind.clutchSave
              : DuelEventKind.clutchFail,
        );
        checked++;
      }
      expect(checked, greaterThan(0));
    });

    test('점수 null 이면 A 도 자동 점수 — 같은 seed 면 같은 판', () {
      for (var s = 1; s < 30; s++) {
        final r1 = simulateBout(seed: s, a: a, b: b, params: _on);
        final r2 = simulateBout(seed: s, a: a, b: b, params: _on);
        expect(r1.done, isTrue);
        expect(jsonEncode(r1.toJson()), jsonEncode(r2.toJson()));
      }
    });

    test('위기 처리는 물리 난수를 쓰지 않는다 — 모든 위기가 실패하면 예전 엔진과 같은 판', () {
      // 자동 점수가 늘 문턱 아래(base −1)면 위기는 전부 실패한다.
      const allFail = DuelParams(clutchEnabled: true, clutchAutoBase: -1);
      for (var s = 1; s < 120; s++) {
        final old = simulateBout(
          seed: s,
          a: _bug('a', Specialty.values[s % 3]),
          b: _bug('b', Specialty.values[(s ~/ 3) % 3]),
          params: const DuelParams(),
        );
        final now = simulateBout(
          seed: s,
          a: _bug('a', Specialty.values[s % 3]),
          b: _bug('b', Specialty.values[(s ~/ 3) % 3]),
          params: allFail,
        );
        expect(now.winner, old.winner);
        expect(now.finish, old.finish);
        expect(now.ticks, old.ticks);
        expect(jsonEncode(now.frames), jsonEncode(old.frames));
        final noClutch = [
          for (final e in now.events)
            if (e.kind != DuelEventKind.clutch &&
                e.kind != DuelEventKind.clutchFail)
              e.toJson(),
        ];
        expect(
          jsonEncode(noClutch),
          jsonEncode([for (final e in old.events) e.toJson()]),
        );
      }
    });

    test('clutchEnabled 가 꺼져 있으면 점수 목록을 줘도 위기가 없다', () {
      final r = simulateBout(
        seed: 3,
        a: a,
        b: b,
        params: const DuelParams(),
        clutchScores: [],
      );
      expect(r.done, isTrue);
      expect(_of(r, DuelEventKind.clutch), isEmpty);
    });
  });

  group('탭 반격 — 경기(승자 연속)', () {
    final teamA = [
      _bug('a0', Specialty.strike, tm: Temperament.aggressive),
      _bug('a1', Specialty.grip),
      _bug('a2', Specialty.toss, tm: Temperament.cunning),
    ];
    final teamB = [
      _bug('b0', Specialty.grip, tm: Temperament.cautious),
      _bug('b1', Specialty.toss),
      _bug('b2', Specialty.strike, tm: Temperament.fickle),
    ];

    test('대기 중 위기가 몇 번째 판·몇 번째 점수인지 위로 올라온다', () {
      for (var seed = 1; seed < 20; seed++) {
        final scores = <double>[];
        DuelMatch m;
        var guard = 0;
        do {
          m = simulateDuel(
            seed: seed,
            teamA: teamA,
            teamB: teamB,
            params: _on,
            clutchScores: scores,
          );
          final pc = m.pending;
          if (pc != null) {
            expect(pc.index, scores.length);
            expect(pc.bout, m.bouts.length - 1);
            expect(m.bouts.last.pending, isNotNull);
            expect(m.winner(_on), isNull);
            scores.add(scores.length.isEven ? 1.0 : 0.0);
          }
        } while (m.pending != null && ++guard < 20);
        expect(m.pending, isNull);
        expect(m.winner(_on), isNotNull);
        expect(
          m.bouts.fold<int>(0, (n, b) => n + b.playerClutches),
          scores.length,
        );
        // 같은 입력이면 같은 경기.
        final again = simulateDuel(
          seed: seed,
          teamA: teamA,
          teamB: teamB,
          params: _on,
          clutchScores: List.of(scores),
        );
        expect(
          jsonEncode([for (final b in again.bouts) b.toJson()]),
          jsonEncode([for (final b in m.bouts) b.toJson()]),
        );
      }
    });

    test('멈춘 판은 다음 판 대진·체력 계산에서 빠진다', () {
      for (var seed = 1; seed < 40; seed++) {
        final m = simulateDuel(
          seed: seed,
          teamA: teamA,
          teamB: teamB,
          params: _on,
          clutchScores: [],
        );
        if (m.pending == null) continue;
        final done = m.bouts.sublist(0, m.bouts.length - 1);
        final st1 = duelNextState(m.bouts, teamA, teamB, _on);
        final st2 = duelNextState(done, teamA, teamB, _on);
        expect(st1, st2);
        return;
      }
      fail('멈추는 경기가 없다');
    });
  });

  group('탭 반격 — 대회(왕충 선발대회)', () {
    const spec = EventDuelSpec();
    final mine = _bug('me', Specialty.strike, scale: 1.5);

    test('내 곤충 위기에서 멈추면 진행 상태는 그대로 — 점수를 넣으면 이어진다', () {
      var paused = 0;
      var run = const EventDuelRun();
      for (var guard = 0; guard < 60 && !run.over; guard++) {
        final enemy = eventDuelEnemy(
          roundSeed: 11,
          wave: run.wave,
          spec: spec,
          speciesId: 'e',
          specialty: Specialty.values[run.wave % 3],
        );
        final scores = <double>[];
        EventDuelStep step;
        do {
          step = eventDuelFight(
            seed: 4242,
            run: run,
            bug: mine,
            enemy: enemy,
            params: _on,
            spec: spec,
            clutchScores: scores,
          );
          if (step.bout.pending != null) {
            expect(identical(step.run, run), isTrue);
            expect(step.won, isFalse);
            scores.add(0.8);
            paused++;
          }
        } while (step.bout.pending != null);
        // 같은 점수로 다시 부르면 같은 결과(서버 재계산).
        final again = eventDuelFight(
          seed: 4242,
          run: run,
          bug: mine,
          enemy: enemy,
          params: _on,
          spec: spec,
          clutchScores: List.of(scores),
        );
        expect(jsonEncode(again.run.toJson()), jsonEncode(step.run.toJson()));
        run = step.run;
      }
      expect(paused, greaterThan(0));
      expect(run.cleared, greaterThan(0));
    });
  });

  test('새 키를 battle.json 에서 읽는다(없으면 예전 동작)', () {
    final q = DuelParams.fromJson({
      'clutchEnabled': true,
      'clutchThreshold': 0.6,
      'clutchUses': 2,
      'techMax': 0.2,
      'techTossScale': 0.5,
      'sizeStatExp': 0,
      'massSpeedExp': 0.5,
      'gripLevOffset': 0.4,
    });
    expect(q.clutchEnabled, isTrue);
    expect(q.clutchThreshold, 0.6);
    expect(q.clutchUses, 2);
    expect(q.techMax, 0.2);
    expect(q.techTossScale, 0.5);
    expect(q.sizeStatExp, 0);
    expect(q.massSpeedExp, 0.5);
    expect(q.gripLevOffset, 0.4);
    const d = DuelParams();
    expect(d.clutchEnabled, isFalse);
    expect(d.sizeStatExp, 1);
    expect(d.massSpeedExp, 0);
    expect(d.gripLevOffset, 0.6);
    expect(d.tossLevMin, 0.35);
  });

  group('크기 몫 덜어내기(sizeStatExp)', () {
    test('sizeStatMult 가 1 이면(모름) 아무 영향이 없다', () {
      const q = DuelParams(sizeStatExp: 0);
      final r1 = simulateBout(seed: 5, a: a, b: b, params: q);
      final r2 = simulateBout(seed: 5, a: a, b: b, params: const DuelParams());
      expect(jsonEncode(r1.toJson()), jsonEncode(r2.toJson()));
    });

    test('sizeStatExp 0 이면 구워진 크기 배율이 결투 스탯에서 빠진다', () {
      // 같은 곤충 둘 — 한쪽은 스탯에 ×1.2 가 구워져 있다. 덜어내면 거울전과 같은 판.
      final big = DuelBug(
        id: 'a',
        name: 'a',
        speciesId: 'a',
        element: Element.wood,
        temperament: Temperament.steadfast,
        specialty: Specialty.strike,
        sizeMm: 50,
        maxHp: 150 * 1.2,
        atk: 60 * 1.2,
        def: 50 * 1.2,
        spd: 50 * 1.2,
        sizeStatMult: 1.2,
      );
      final plain = _bug('a', Specialty.strike);
      const q = DuelParams(sizeStatExp: 0);
      final r1 = simulateBout(seed: 8, a: big, b: b, params: q);
      final r2 = simulateBout(seed: 8, a: plain, b: b, params: q);
      expect(r1.winner, r2.winner);
      expect(r1.ticks, r2.ticks);
      expect(DuelBug.fromJson(big.toJson()).sizeStatMult, closeTo(1.2, 1e-9));
    });
  });
}
