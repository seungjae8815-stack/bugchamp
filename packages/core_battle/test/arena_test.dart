import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';
import 'package:test/test.dart';

// 경기장 오행(2026-10-16 사장님 확정, docs/design_arena_element.md).
void main() {
  const on = DuelParams(arenaSame: 0.10, arenaRestrained: 0.10);
  const off = DuelParams();

  DuelBug bug(String id, Element e) => DuelBug(
    id: id,
    name: id,
    speciesId: id,
    element: e,
    temperament: Temperament.steadfast,
    specialty: Specialty.grip,
    sizeMm: 60,
    maxHp: 150,
    atk: 60,
    def: 50,
    spd: 50,
  );

  test('배율 — 같은 오행 +10% · 경기장이 이기는 오행 −10% · 나머지 그대로 · 꺼지면 1', () {
    const arena = Element.fire;
    final weak = Element.values.firstWhere(arena.restrains);
    expect(duelArenaMult(Element.fire, arena, on), closeTo(1.10, 1e-9));
    expect(duelArenaMult(weak, arena, on), closeTo(0.90, 1e-9));
    for (final e in Element.values) {
      if (e == arena || e == weak) continue;
      expect(duelArenaMult(e, arena, on), 1.0);
    }
    expect(duelArenaMult(Element.fire, arena, off), 1.0);
    expect(duelArenaMult(Element.fire, null, on), 1.0);
  });

  test('경기장이 같은 오행 쪽을 이기게 민다 — 같은 곤충 둘 중 경기장 오행 쪽 승률이 오른다', () {
    var plain = 0, onArena = 0;
    for (var s = 0; s < 400; s++) {
      final a = bug('a', Element.fire), b = bug('b', Element.earth);
      if (simulateBout(seed: s, a: a, b: b, params: on).aWon) plain++;
      if (simulateBout(
        seed: s,
        a: a,
        b: b,
        params: on,
        arena: Element.fire,
      ).aWon) {
        onArena++;
      }
    }
    expect(onArena, greaterThan(plain));
  });

  test('경기장은 seed 로 정해진다(결정론) · 5종이 다 나온다', () {
    expect(duelArenaOf(12345), duelArenaOf(12345));
    final seen = {for (var s = 0; s < 200; s++) duelArenaOf(s)};
    expect(seen.length, Element.values.length);
  });

  test('대회 경기장 — 같은 회차·같은 웨이브면 같다(재도전해도) · 꺼지면 null', () {
    expect(eventArenaOf(777, 3, on), eventArenaOf(777, 3, on));
    expect(eventArenaOf(777, 3, off), isNull);
    expect(eventArenaOf(null, 3, on), isNull);
    final waves = {for (var w = 1; w <= 30; w++) eventArenaOf(777, w, on)};
    expect(waves.length, greaterThan(1)); // 웨이브마다 바뀐다
  });
}
