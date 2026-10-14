import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';
import 'package:test/test.dart';

/// 치기 약함 수정(2026-10-14) · 대회 전용 종 배율 — battle.json `strikeStaggerSeconds`·`strikeHitDamage`,
/// event.json `duelWave.speciesScale`.
DuelBug _bug(
  String id,
  Specialty sp, {
  double tech = 0,
  String species = 'x',
}) => DuelBug(
  id: id,
  name: id,
  speciesId: species,
  element: Element.wood,
  temperament: Temperament.fickle,
  specialty: sp,
  sizeMm: 50,
  maxHp: 600,
  atk: 200,
  def: 120,
  spd: 45,
  tech: tech,
);

String _sig(DuelBout b) => '${b.winner}/${b.finish}/${b.ticks}/${b.hpPctA}';

void main() {
  test('치기 기술 0 이면 옛 치기 그대로 — 새 수치를 켜도 판이 같다', () {
    const off = DuelParams(strikeStaggerSeconds: 0, strikeHitDamage: 0);
    const on = DuelParams(strikeStaggerSeconds: 3.3, strikeHitDamage: 3.3);
    for (var seed = 1; seed <= 30; seed++) {
      final a = _bug('a', Specialty.strike);
      final b = _bug('b', Specialty.grip, tech: 0.3);
      expect(
        _sig(simulateBout(seed: seed, a: a, b: b, params: on)),
        _sig(simulateBout(seed: seed, a: a, b: b, params: off)),
        reason: 'seed $seed',
      );
    }
  });

  test('치기 기술이 있으면 새 수치가 집기 상대 승률을 올린다', () {
    const off = DuelParams(strikeStaggerSeconds: 0, strikeHitDamage: 0);
    const on = DuelParams(strikeStaggerSeconds: 3.3, strikeHitDamage: 3.3);
    var wOff = 0, wOn = 0;
    for (var seed = 1; seed <= 300; seed++) {
      final a = _bug('a', Specialty.strike, tech: 0.3);
      final b = _bug('b', Specialty.grip, tech: 0.3);
      if (simulateBout(seed: seed, a: a, b: b, params: off).aWon) wOff++;
      if (simulateBout(seed: seed, a: a, b: b, params: on).aWon) wOn++;
    }
    expect(wOn, greaterThan(wOff));
  });

  test('코드 기본값 = battle.json 값(3.3)', () {
    const d = DuelParams();
    expect(d.strikeStaggerSeconds, 3.3);
    expect(d.strikeHitDamage, 3.3);
    final j = DuelParams.fromJson({
      'strikeStaggerSeconds': 0,
      'strikeHitDamage': 1.5,
    });
    expect(j.strikeStaggerSeconds, 0);
    expect(j.strikeHitDamage, 1.5);
  });

  group('대회 전용 종 배율(duelWave.speciesScale)', () {
    test('읽기 · 없는 종은 1', () {
      final spec = EventDuelSpec.fromJson({
        'speciesScale': {'hornet_giant': 0.67, 'bad': 'x'},
      });
      expect(spec.speciesScaleOf('hornet_giant'), 0.67);
      expect(spec.speciesScaleOf('stag_saw'), 1);
      expect(spec.speciesScaleOf('bad'), 1);
      expect(const EventDuelSpec().speciesScale, isEmpty);
    });

    test('eventDuelFight 가 체력·공격·방어에 곱한다 — 미리 곱한 곤충과 같은 판', () {
      const p = DuelParams();
      final enemy = _bug('e', Specialty.grip);
      final me = _bug('m', Specialty.strike, species: 'hornet_giant');
      final scaled = me.withTraining(
        hpMult: 0.67,
        atkMult: 0.67,
        defMult: 0.67,
      );
      final withScale = EventDuelSpec.fromJson({
        'speciesScale': {'hornet_giant': 0.67},
      });
      const plain = EventDuelSpec();
      for (var seed = 1; seed <= 10; seed++) {
        final x = eventDuelFight(
          seed: seed,
          run: const EventDuelRun(),
          bug: me,
          enemy: enemy,
          params: p,
          spec: withScale,
        );
        final y = eventDuelFight(
          seed: seed,
          run: const EventDuelRun(),
          bug: scaled,
          enemy: enemy,
          params: p,
          spec: plain,
        );
        expect(_sig(x.bout), _sig(y.bout), reason: 'seed $seed');
      }
    });
  });
}
