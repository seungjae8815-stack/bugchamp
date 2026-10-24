import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';
import 'package:test/test.dart';

DuelBug bugOf(Sex sex) => DuelBug(
  id: 'a',
  name: 'a',
  speciesId: 's',
  element: Element.wood,
  temperament: Temperament.cunning,
  specialty: Specialty.grip,
  sizeMm: 60,
  maxHp: 100,
  atk: 10,
  def: 10,
  spd: 10,
  sex: sex,
);

void main() {
  const p = DuelParams();
  test('DuelBug.sex round-trips (sx) and defaults to male', () {
    final f = DuelBug.fromJson(bugOf(Sex.female).toJson());
    expect(f.sex, Sex.female);
    expect(bugOf(Sex.female).toJson()['sx'], 'f');
    expect(bugOf(Sex.male).toJson().containsKey('sx'), isFalse);
    expect(DuelBug.fromJson(bugOf(Sex.male).toJson()).sex, Sex.male);
    expect(f.withAura(null, 0).sex, Sex.female);
    expect(f.withTraining(atkMult: 1.1).sex, Sex.female);
  });

  test('DuelBug.sex does not change mass/radius/power', () {
    final m = bugOf(Sex.male);
    final f = bugOf(Sex.female);
    expect(f.mass(p), m.mass(p));
    expect(f.radius(p), m.radius(p));
    expect(f.powerIn(p), m.powerIn(p));
  });
}
