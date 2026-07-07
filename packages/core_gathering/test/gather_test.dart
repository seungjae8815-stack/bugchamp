import 'dart:math';

import 'package:core_gathering/core_gathering.dart';
import 'package:core_models/core_models.dart';
import 'package:test/test.dart';

// --- 픽스처 ---
const _speciesA = Species(
  id: 'a',
  name: LocalizedText(ko: 'A', en: 'A', ja: 'A'),
  grade: Grade.common,
  specialty: Specialty.grip,
  baseStats: Stats(hp: 100, atk: 40, def: 30, spd: 20),
  sizeMinMm: 20,
  sizeMaxMm: 60,
);
const _speciesB = Species(
  id: 'b',
  name: LocalizedText(ko: 'B', en: 'B', ja: 'B'),
  grade: Grade.rare,
  specialty: Specialty.strike,
  baseStats: Stats(hp: 140, atk: 60, def: 45, spd: 40),
  sizeMinMm: 30,
  sizeMaxMm: 90,
);

const _speciesById = {'a': _speciesA, 'b': _speciesB};
Species _resolve(String id) => _speciesById[id]!;

final _entry = SpawnEntry(
  fieldId: 'f',
  trapId: 't',
  encountersPerHour: 1.0,
  materialsPerHour: const [
    MaterialRate(kind: MaterialKind.chitin, perHour: 2.0),
    MaterialRate(kind: MaterialKind.sap, perHour: 1.0),
  ],
  speciesWeights: const [
    SpeciesWeight(speciesId: 'a', weight: 60),
    SpeciesWeight(speciesId: 'b', weight: 40),
  ],
  potentialWeights: const [
    PotentialWeight(potential: 1, weight: 50),
    PotentialWeight(potential: 2, weight: 30),
    PotentialWeight(potential: 3, weight: 15),
    PotentialWeight(potential: 4, weight: 4),
    PotentialWeight(potential: 5, weight: 1),
  ],
);

final _install = DateTime.utc(2026, 1, 1, 0, 0, 0);

GatherYield _run({
  required int seed,
  required Duration elapsed,
  double mult = 1.0,
  Duration maxAccrual = kMaxOfflineAccrual,
}) {
  var c = 0;
  final trap = Trap(
    id: 't',
    name: const LocalizedText(ko: 't', en: 't', ja: 't'),
    yieldMultiplier: mult,
  );
  return accrue(
    installedAt: _install,
    now: _install.add(elapsed),
    entry: _entry,
    trap: trap,
    rng: Random(seed),
    resolveSpecies: _resolve,
    idFactory: () => 'b${c++}',
    maxAccrual: maxAccrual,
  );
}

int _mat(GatherYield y, MaterialKind k) =>
    y.materials.firstWhere((m) => m.kind == k).amount;

List<Map<String, dynamic>> _encJson(GatherYield y) =>
    y.encounters.map((e) => e.toJson()).toList();

void main() {
  group('경과시간 비례', () {
    test('시간이 2배면 재료·조우도 2배 (선형)', () {
      final r2 = _run(seed: 1, elapsed: const Duration(hours: 2));
      final r4 = _run(seed: 1, elapsed: const Duration(hours: 4));

      expect(_mat(r2, MaterialKind.chitin), 4); // 2.0 * 2h
      expect(_mat(r4, MaterialKind.chitin), 8); // 2.0 * 4h
      expect(_mat(r2, MaterialKind.sap), 2);
      expect(_mat(r4, MaterialKind.sap), 4);
      expect(r2.encounters.length, 2);
      expect(r4.encounters.length, 4);
    });

    test('경과 0 이면 산출 없음', () {
      final y = _run(seed: 1, elapsed: Duration.zero);
      expect(y.isEmpty, isTrue);
      expect(y.accrued, Duration.zero);
    });
  });

  group('오프라인 상한(8h) clamp', () {
    test('8h 와 100h 산출이 동일하고 accrued=8h', () {
      final r8 = _run(seed: 9, elapsed: const Duration(hours: 8));
      final r100 = _run(seed: 9, elapsed: const Duration(hours: 100));

      expect(r8.accrued, const Duration(hours: 8));
      expect(r100.accrued, const Duration(hours: 8));
      expect(_mat(r100, MaterialKind.chitin), _mat(r8, MaterialKind.chitin));
      expect(_mat(r8, MaterialKind.chitin), 16); // 2.0 * 8h
      expect(_encJson(r100), _encJson(r8));
    });

    test('maxAccrual 파라미터 override 반영', () {
      final y = _run(
        seed: 2,
        elapsed: const Duration(hours: 5),
        maxAccrual: const Duration(hours: 2),
      );
      expect(y.accrued, const Duration(hours: 2));
      expect(_mat(y, MaterialKind.chitin), 4); // 2h 로 clamp
    });
  });

  group('시드 결정론', () {
    test('같은 seed + 같은 입력 → 완전 동일', () {
      final a = _run(seed: 7, elapsed: const Duration(hours: 6));
      final b = _run(seed: 7, elapsed: const Duration(hours: 6));
      expect(_encJson(a), _encJson(b));
      expect(_mat(a, MaterialKind.chitin), _mat(b, MaterialKind.chitin));
    });

    test('다른 seed → 조우 개체가 달라짐', () {
      final a = _run(seed: 7, elapsed: const Duration(hours: 6));
      final c = _run(seed: 8, elapsed: const Duration(hours: 6));
      expect(
        c.encounters.map((e) => e.sizeMm).toList(),
        isNot(equals(a.encounters.map((e) => e.sizeMm).toList())),
      );
    });
  });

  group('트랩 배율 반영', () {
    test('yieldMultiplier 가 크면 산출이 더 많음', () {
      final base = _run(seed: 3, elapsed: const Duration(hours: 5), mult: 1.0);
      final boosted = _run(
        seed: 3,
        elapsed: const Duration(hours: 5),
        mult: 1.2,
      );
      expect(
        _mat(boosted, MaterialKind.chitin),
        greaterThan(_mat(base, MaterialKind.chitin)),
      ); // 12 > 10
      expect(
        boosted.encounters.length,
        greaterThan(base.encounters.length),
      ); // 6 > 5
    });
  });

  group('조우 개체 유효성', () {
    test('종/포텐셜/사이즈가 표·범위 내', () {
      final y = _run(seed: 123, elapsed: const Duration(hours: 8));
      expect(y.encounters, isNotEmpty);
      const validIds = {'a', 'b'};
      const validPots = {1, 2, 3, 4, 5};
      for (final e in y.encounters) {
        expect(validIds.contains(e.speciesId), isTrue);
        expect(validPots.contains(e.potential), isTrue);
        final sp = _resolve(e.speciesId);
        expect(e.sizeMm, inInclusiveRange(sp.sizeMinMm, sp.sizeMaxMm));
      }
    });
  });

  group('기기시간 조작 방어', () {
    test('now < installedAt (시계 역행) → 산출 없음', () {
      var c = 0;
      final y = accrue(
        installedAt: _install,
        now: _install.subtract(const Duration(hours: 3)),
        entry: _entry,
        trap: const Trap(
          id: 't',
          name: LocalizedText(ko: 't', en: 't', ja: 't'),
        ),
        rng: Random(1),
        resolveSpecies: _resolve,
        idFactory: () => 'x${c++}',
      );
      expect(y.isEmpty, isTrue);
      expect(y.accrued, Duration.zero);
    });
  });
}
