import 'dart:convert';

import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';
import 'package:test/test.dart';

DuelBug _me({double scale = 1, double recovery = 0}) => DuelBug(
  id: 'me',
  name: 'me',
  speciesId: 'me',
  element: Element.wood,
  temperament: Temperament.steadfast,
  specialty: Specialty.grip,
  sizeMm: 60,
  maxHp: 150 * scale,
  atk: 60 * scale,
  def: 50 * scale,
  spd: 50 * scale,
).withTraining(recovery: recovery);

DuelBug _enemy(int wave, EventDuelSpec spec) => eventDuelEnemy(
  roundSeed: 20261005,
  wave: wave,
  spec: spec,
  speciesId: 'e',
  specialty: Specialty.values[wave % 3],
);

/// 끝날 때까지(카드 없이) 돌린다.
EventDuelRun _runOut(DuelBug me, EventDuelSpec spec, {int seed = 7}) {
  var run = const EventDuelRun();
  const p = DuelParams();
  while (!run.over) {
    run = eventDuelFight(
      seed: seed,
      run: run,
      bug: me,
      enemy: _enemy(run.wave, spec),
      params: p,
      spec: spec,
    ).run;
  }
  return run;
}

void main() {
  const spec = EventDuelSpec(maxWave: 60);

  test('결정론 — 같은 시드·곤충이면 같은 판', () {
    final a = _runOut(_me(), spec);
    final b = _runOut(_me(), spec);
    expect(jsonEncode(a.toJson()), jsonEncode(b.toJson()));
  });

  test('같은 회차·웨이브면 적이 같다(모두 같은 웨이브를 만난다)', () {
    expect(
      jsonEncode(_enemy(5, spec).toJson()),
      jsonEncode(_enemy(5, spec).toJson()),
    );
    expect(_enemy(6, spec).maxHp, greaterThan(_enemy(5, spec).maxHp));
  });

  test('잘 키운 곤충이 더 멀리 간다', () {
    var weak = 0, strong = 0;
    for (var s = 0; s < 20; s++) {
      weak += _runOut(_me(), spec, seed: s).cleared;
      strong += _runOut(_me(scale: 2), spec, seed: s).cleared;
    }
    expect(strong, greaterThan(weak));
  });

  test('지면 끝 — 체력 0 · over', () {
    final r = _runOut(_me(), spec);
    expect(r.over, isTrue);
    expect(r.hpPct, 0);
    expect(r.cleared, lessThan(spec.maxWave));
  });

  test('카드 — 부활은 지면 같은 웨이브를 그 체력으로 다시', () {
    final run = const EventDuelRun(
      wave: 40,
      hpPct: 0.1,
    ).applyCard('revive', 0.5, spec);
    final step = eventDuelFight(
      seed: 1,
      run: run,
      bug: _me(),
      enemy: _enemy(40, spec),
      params: const DuelParams(),
      spec: spec,
    );
    expect(step.won, isFalse);
    expect(step.run.over, isFalse);
    expect(step.run.wave, 40);
    expect(step.run.hpPct, 0.5);
    expect(step.run.revives, 0);
  });

  test('카드 — 건너뛰기·회복·강화', () {
    var r = const EventDuelRun(wave: 3, cleared: 2, hpPct: 0.4);
    r = r.applyCard('skip', 1, spec);
    expect((r.wave, r.cleared), (4, 3));
    r = r.applyCard('heal', 0.7, spec);
    expect(r.hpPct, 1.0);
    r = r.applyCard('atk', 0.12, spec).applyCard('unknown', 9, spec);
    expect(r.dress(_me()).atk, closeTo(60 * 1.12, 1e-9));
  });

  test('회복력(훈련소)은 웨이브 사이 회복에 더해진다', () {
    final base = eventDuelFight(
      seed: 3,
      run: const EventDuelRun(hpPct: 0.5),
      bug: _me(scale: 3),
      enemy: _enemy(1, spec),
      params: const DuelParams(),
      spec: spec,
    );
    final rec = eventDuelFight(
      seed: 3,
      run: const EventDuelRun(hpPct: 0.5),
      bug: _me(scale: 3, recovery: 0.1),
      enemy: _enemy(1, spec),
      params: const DuelParams(),
      spec: spec,
    );
    expect(base.won && rec.won, isTrue);
    expect(rec.run.hpPct, greaterThanOrEqualTo(base.run.hpPct));
  });

  test('세션 저장 왕복', () {
    const r = EventDuelRun(wave: 9, cleared: 8, hpPct: 0.3, revives: 1);
    expect(
      jsonEncode(EventDuelRun.fromJson(r.toJson()).toJson()),
      jsonEncode(r.toJson()),
    );
  });

  test('카드 2차 — A 결투 능력치', () {
    var r = const EventDuelRun()
        .applyCard('evade', 0.08, spec)
        .applyCard('crit', 0.1, spec)
        .applyCard('size', 0.4, spec);
    final me = r.dress(_me());
    expect(me.evade, closeTo(0.08, 1e-9));
    expect(me.crit, closeTo(0.1, 1e-9));
    expect(me.sizeMm, closeTo(60 * 1.4, 1e-9));
    r = r.applyCard('recover', 0.1, spec);
    expect(r.recoveryOf(_me(recovery: 0.05)), closeTo(0.15, 1e-9));
  });

  test('카드 2차 — B 대가가 있는 카드', () {
    final berserk = const EventDuelRun().applyCard('berserk', 0.35, spec);
    final b = berserk.dress(_me());
    expect(b.atk, closeTo(60 * 1.35, 1e-9));
    expect(b.def, closeTo(50 * (1 - 0.21), 1e-9));
    final iron = const EventDuelRun().applyCard('ironhide', 0.4, spec);
    final ib = iron.dress(_me());
    expect(ib.def, closeTo(50 * 1.4, 1e-9));
    expect(ib.spd, closeTo(50 * 0.84, 1e-9));
    // 광폭화를 겹쳐도 방어는 30% 아래로 안 떨어진다.
    var many = const EventDuelRun();
    for (var i = 0; i < 6; i++) {
      many = many.applyCard('berserk', 0.35, spec);
    }
    expect(many.dress(_me()).def, closeTo(50 * 0.3, 1e-9));
  });

  test('배수진 — 체력 50% 미만으로 들어갈 때만 공격 +', () {
    final full = const EventDuelRun().applyCard('lastStand', 0.4, spec);
    expect(full.dress(_me()).atk, closeTo(60, 1e-9));
    final low = const EventDuelRun(
      hpPct: 0.3,
    ).applyCard('lastStand', 0.4, spec);
    expect(low.dress(_me()).atk, closeTo(60 * 1.4, 1e-9));
  });

  test('새 카드 필드도 세션 저장 왕복', () {
    final r = const EventDuelRun()
        .applyCard('evade', 0.08, spec)
        .applyCard('ironhide', 0.4, spec)
        .applyCard('lastStand', 0.4, spec);
    expect(
      jsonEncode(EventDuelRun.fromJson(r.toJson()).toJson()),
      jsonEncode(r.toJson()),
    );
  });

  group('카드 누적 상한(2026-09-30 점검 — 무게·날렵함 무한 누적)', () {
    const spec = EventDuelSpec();
    test('같은 카드를 계속 골라도 상한을 넘지 않는다', () {
      var run = const EventDuelRun();
      for (var i = 0; i < 20; i++) {
        run = run
            .applyCard('size', 0.4, spec)
            .applyCard('evade', 0.08, spec)
            .applyCard('crit', 0.1, spec);
      }
      expect(run.size, spec.cardCaps['size']);
      expect(run.evade, spec.cardCaps['evade']);
      expect(run.crit, spec.cardCaps['crit']);
    });
    test('상한이 없는 카드는 그대로 쌓인다', () {
      var run = const EventDuelRun();
      for (var i = 0; i < 3; i++) {
        run = run.applyCard('atk', 0.1, spec);
      }
      expect(run.atk, closeTo(0.3, 1e-9));
    });
    test('JSON 의 cardCaps 를 읽는다', () {
      final s = EventDuelSpec.fromJson({
        'cardCaps': {'size': 0.4},
      });
      expect(s.cardCaps, {'size': 0.4});
      expect(
        const EventDuelRun().applyCard('size', 1.0, s).size,
        closeTo(0.4, 1e-9),
      );
    });
  });

  test('회피·치명 확률은 엔진 상한으로 잘린다 — 회피 100% 면역이 없다', () {
    const p = DuelParams();
    expect(p.evadeMax, lessThan(1));
    expect(p.critMax, lessThan(1));
    // 회피 5.0 인 곤충도 부딪힘 피해를 언젠가는 받는다(면역이 아니다).
    final tank = _me(scale: 3).withTraining(evade: 5.0);
    const spec2 = EventDuelSpec();
    var hurt = false;
    for (var s = 0; s < 20 && !hurt; s++) {
      final step = eventDuelFight(
        seed: s,
        run: const EventDuelRun(),
        bug: tank,
        enemy: _enemy(30, spec2),
        params: p,
        spec: spec2,
        launch: 0.6,
      );
      if (step.run.hpPct < 1.0) hurt = true;
    }
    expect(hurt, isTrue);
  });
}
