import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';

/// 결정론적 전투 데모: 같은 seed → 항상 같은 결과.
void main() {
  BattleBug bug(String id, Element el, Temperament t) => BattleBug(
    id: id,
    name: id,
    element: el,
    temperament: t,
    preferredStance: Stance.attack,
    maxHp: 100,
    atk: 30,
    def: 30,
    spd: 20,
  );

  final teamA = [
    bug('a1', Element.wood, Temperament.aggressive),
    bug('a2', Element.fire, Temperament.cautious),
    bug('a3', Element.earth, Temperament.cunning),
  ];
  final teamB = [
    bug('b1', Element.metal, Temperament.steadfast),
    bug('b2', Element.water, Temperament.fickle),
    bug('b3', Element.fire, Temperament.aggressive),
  ];

  final result = simulate(42, teamA, teamB);
  print('outcome: ${result.outcome}, rounds: ${result.rounds}');
}
