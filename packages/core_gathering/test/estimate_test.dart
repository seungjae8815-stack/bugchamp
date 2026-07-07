import 'dart:math';

import 'package:core_gathering/core_gathering.dart';
import 'package:core_models/core_models.dart';
import 'package:test/test.dart';

const _species = Species(
  id: 'a',
  name: LocalizedText(ko: 'A', en: 'A', ja: 'A'),
  grade: Grade.common,
  specialty: Specialty.grip,
  baseStats: Stats(hp: 100, atk: 40, def: 30, spd: 20),
  sizeMinMm: 20,
  sizeMaxMm: 60,
);

final _entry = SpawnEntry(
  fieldId: 'f',
  trapId: 't',
  encountersPerHour: 1.0,
  materialsPerHour: const [
    MaterialRate(kind: MaterialKind.chitin, perHour: 2.0),
    MaterialRate(kind: MaterialKind.sap, perHour: 1.0),
  ],
  speciesWeights: const [SpeciesWeight(speciesId: 'a', weight: 1)],
  potentialWeights: const [PotentialWeight(potential: 1, weight: 1)],
);

const _trap = Trap(
  id: 't',
  name: LocalizedText(ko: 't', en: 't', ja: 't'),
);

final _install = DateTime.utc(2026, 1, 1);

void main() {
  test('estimate 개수가 실제 accrue 개수와 일치', () {
    for (final h in [0, 1, 3, 8, 20]) {
      final now = _install.add(Duration(hours: h));
      final est = estimateYield(
        installedAt: _install,
        now: now,
        entry: _entry,
        trap: _trap,
      );
      var c = 0;
      final actual = accrue(
        installedAt: _install,
        now: now,
        entry: _entry,
        trap: _trap,
        rng: Random(1),
        resolveSpecies: (_) => _species,
        idFactory: () => 'b${c++}',
      );
      final actualMaterials = actual.materials.fold<int>(
        0,
        (a, m) => a + m.amount,
      );
      expect(est.materialCount, actualMaterials, reason: '${h}h materials');
      expect(
        est.encounterCount,
        actual.encounters.length,
        reason: '${h}h bugs',
      );
    }
  });

  test('경과 0 / 음수는 hasYield=false', () {
    expect(
      estimateYield(
        installedAt: _install,
        now: _install,
        entry: _entry,
        trap: _trap,
      ).hasYield,
      isFalse,
    );
    expect(
      estimateYield(
        installedAt: _install,
        now: _install.subtract(const Duration(hours: 1)),
        entry: _entry,
        trap: _trap,
      ).hasYield,
      isFalse,
    );
  });

  test('8h 상한 반영', () {
    final est = estimateYield(
      installedAt: _install,
      now: _install.add(const Duration(hours: 50)),
      entry: _entry,
      trap: _trap,
    );
    expect(est.accrued, const Duration(hours: 8));
    expect(est.materialCount, (2.0 + 1.0).toInt() * 8); // 3/h * 8h = 24
    expect(est.encounterCount, 8);
  });
}
