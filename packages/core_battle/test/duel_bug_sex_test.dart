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

  test('buildDuelBug uses male-equivalent mm and carries sex', () {
    const sp = Species(
      id: 'x',
      name: LocalizedText(ko: 'x', en: 'x', ja: 'x'),
      grade: Grade.common,
      baseStats: Stats(hp: 100, atk: 10, def: 10, spd: 10),
      specialty: Specialty.grip,
      sizeMinMm: 40,
      sizeMaxMm: 92,
      femaleSizeMinMm: 30,
      femaleSizeMaxMm: 50,
    );
    final bug = IndividualBug(
      id: 'f',
      speciesId: 'x',
      sizeMm: 40,
      potential: 1,
      temperament: Temperament.cunning,
      sex: Sex.female,
    );
    final d = buildDuelBug(bug: bug, species: sp, locale: 'ko');
    expect(d.sizeMm, closeTo(66, 0.001));
    expect(d.sex, Sex.female);
  });
}
