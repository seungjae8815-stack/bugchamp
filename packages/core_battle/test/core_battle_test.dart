import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';
import 'package:test/test.dart';

BattleBug _bug(
  String id,
  Element el,
  Temperament t, {
  Stance pref = Stance.attack,
  double hp = 100,
  double atk = 30,
  double def = 30,
  double spd = 20,
}) => BattleBug(
  id: id,
  name: id,
  element: el,
  temperament: t,
  preferredStance: pref,
  maxHp: hp,
  atk: atk,
  def: def,
  spd: spd,
);

List<BattleBug> _teamA() => [
  _bug('a1', Element.wood, Temperament.aggressive),
  _bug('a2', Element.fire, Temperament.cautious, pref: Stance.defend),
  _bug('a3', Element.earth, Temperament.cunning, pref: Stance.heal),
];

List<BattleBug> _teamB() => [
  _bug('b1', Element.metal, Temperament.steadfast),
  _bug('b2', Element.water, Temperament.fickle),
  _bug('b3', Element.fire, Temperament.aggressive),
];

void main() {
  group('오행 상성', () {
    test('상극/상생 사이클', () {
      expect(Element.water.restrains(Element.fire), isTrue);
      expect(Element.fire.restrains(Element.metal), isTrue);
      expect(Element.metal.restrains(Element.wood), isTrue);
      expect(Element.wood.restrains(Element.earth), isTrue);
      expect(Element.earth.restrains(Element.water), isTrue);
      expect(Element.fire.restrains(Element.water), isFalse);

      expect(Element.wood.generates(Element.fire), isTrue);
      expect(Element.fire.generates(Element.earth), isTrue);
      expect(Element.water.generates(Element.wood), isTrue);
    });

    test('상생 배치가 팀 배율을 올린다', () {
      // 木→火→土 : 2연결
      final synced = [
        _bug('x', Element.wood, Temperament.fickle),
        _bug('y', Element.fire, Temperament.fickle),
        _bug('z', Element.earth, Temperament.fickle),
      ];
      final none = [
        _bug('x', Element.wood, Temperament.fickle),
        _bug('y', Element.water, Temperament.fickle),
        _bug('z', Element.metal, Temperament.fickle),
      ];
      expect(teamSynergy(synced), greaterThan(teamSynergy(none)));
    });
  });

  group('simulate 결정론', () {
    test('같은 seed·팀 → 완전 동일', () {
      final r1 = simulate(12345, _teamA(), _teamB());
      final r2 = simulate(12345, _teamA(), _teamB());
      expect(r1.outcome, r2.outcome);
      expect(r1.rounds, r2.rounds);
      expect(r1.events.length, r2.events.length);
      for (var i = 0; i < r1.events.length; i++) {
        expect(r1.events[i].aStance, r2.events[i].aStance);
        expect(r1.events[i].bStance, r2.events[i].bStance);
        expect(r1.events[i].aHp, r2.events[i].aHp);
        expect(r1.events[i].bHp, r2.events[i].bHp);
      }
    });

    test('다른 seed → 전개가 달라진다', () {
      final a = simulate(1, _teamA(), _teamB());
      final b = simulate(2, _teamA(), _teamB());
      expect(
        a.rounds != b.rounds ||
            a.outcome != b.outcome ||
            a.events.first.aStance != b.events.first.aStance,
        isTrue,
      );
    });
  });

  group('규칙', () {
    test('압도적으로 강한 공격팀이 이긴다', () {
      final strong = [
        for (var i = 0; i < 3; i++)
          _bug(
            's$i',
            Element.values[i],
            Temperament.aggressive,
            atk: 200,
            hp: 300,
          ),
      ];
      final weak = [
        for (var i = 0; i < 3; i++)
          _bug('w$i', Element.values[i], Temperament.fickle, atk: 5, hp: 30),
      ];
      var wins = 0;
      for (var seed = 0; seed < 20; seed++) {
        if (simulate(seed, strong, weak).outcome == BattleOutcome.teamA) {
          wins++;
        }
      }
      expect(wins, greaterThan(17));
    });

    test('HP% 0~1, 라운드 최대 20', () {
      final r = simulate(7, _teamA(), _teamB());
      expect(r.teamAHpPct, inInclusiveRange(0.0, 1.0));
      expect(r.teamBHpPct, inInclusiveRange(0.0, 1.0));
      expect(r.rounds, lessThanOrEqualTo(kMaxBattleRounds));
    });

    test('수동 step: A 스탠스 주입이 반영된다', () {
      final st = initBattle(3, _teamA(), _teamB());
      st.step(playerAStance: Stance.attack);
      expect(st.events.first.aStance, Stance.attack);
    });
  });
}
