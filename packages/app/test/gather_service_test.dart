import 'package:app/data/game_data.dart';
import 'package:app/domain/gather_service.dart';
import 'package:core_save/core_save.dart';
import 'package:core_models/core_models.dart';
import 'package:flutter_test/flutter_test.dart';

// --- 인라인 GameData 픽스처 ---
Map<String, dynamic> _name(String s) => {'ko': s, 'en': s, 'ja': s};

GameData _fixtureData() => GameData.fromDecoded(
  species: {
    'species': [
      {
        'id': 'a',
        'name': _name('A'),
        'grade': 'common',
        'specialty': 'grip',
        'baseStats': {'hp': 100, 'atk': 40, 'def': 30, 'spd': 20},
        'sizeMinMm': 20,
        'sizeMaxMm': 60,
      },
      {
        'id': 'b',
        'name': _name('B'),
        'grade': 'rare',
        'specialty': 'strike',
        'baseStats': {'hp': 140, 'atk': 60, 'def': 45, 'spd': 40},
        'sizeMinMm': 30,
        'sizeMaxMm': 90,
      },
    ],
  },
  traps: {
    'traps': [
      {'id': 't', 'name': _name('T'), 'yieldMultiplier': 1.0},
    ],
  },
  fields: {
    'fields': [
      {'id': 'f', 'name': _name('F'), 'unlockOrder': 0},
    ],
  },
  spawns: {
    'schemaVersion': 1,
    'defaultPotentialWeights': [
      {'potential': 1, 'weight': 1},
    ],
    'spawns': [
      {
        'fieldId': 'f',
        'trapId': 't',
        'encountersPerHour': 3.0,
        'materialsPerHour': [
          {'kind': 'chitin', 'perHour': 2.0},
        ],
        'speciesWeights': [
          {'speciesId': 'a', 'weight': 1},
          {'speciesId': 'b', 'weight': 1},
        ],
      },
    ],
  },
);

SaveGame _unlockedSave(DateTime createdAt) =>
    SaveGame.initial(createdAt: createdAt).copyWith(unlockedFieldIds: {'f'});

List<String> _sig(List<IndividualBug> bugs) =>
    bugs.map((b) => '${b.speciesId}/${b.sizeMm}/${b.potential}').toList();

void main() {
  final t0 = DateTime.utc(2026, 1, 1, 0, 0, 0);

  GatherService makeService(FixedClock clock) {
    var c = 0;
    return GatherService(
      data: _fixtureData(),
      clock: clock,
      idFactory: () => 'bug${c++}',
    );
  }

  group('installTrap', () {
    test('슬롯에 설치되고 installedAt = 현재 시각', () {
      final clock = FixedClock(t0);
      final svc = makeService(clock);
      final save = svc.installTrap(
        _unlockedSave(t0),
        slotIndex: 0,
        fieldId: 'f',
        trapId: 't',
      );
      expect(save.installationAt(0)!.installedAt, t0);
      expect(save.installationAt(0)!.trapId, 't');
    });

    test('잘못된 슬롯/미해금 필드/없는 조합은 예외', () {
      final svc = makeService(FixedClock(t0));
      final save = _unlockedSave(t0);
      expect(
        () => svc.installTrap(save, slotIndex: 9, fieldId: 'f', trapId: 't'),
        throwsArgumentError,
      );
      expect(
        () =>
            svc.installTrap(save, slotIndex: 0, fieldId: 'locked', trapId: 't'),
        throwsArgumentError,
      );
      expect(
        () =>
            svc.installTrap(save, slotIndex: 0, fieldId: 'f', trapId: 'ghost'),
        throwsArgumentError,
      );
    });
  });

  group('collect', () {
    test('방치분을 세이브에 반영하고 타이머를 리셋', () {
      final clock = FixedClock(t0);
      final svc = makeService(clock);
      final installed = svc.installTrap(
        _unlockedSave(t0),
        slotIndex: 0,
        fieldId: 'f',
        trapId: 't',
      );

      clock.advance(const Duration(hours: 4));
      final result = svc.collect(installed, slotIndex: 0);

      // 4h × 3/h = 12 조우, 4h × 2/h = 8 chitin
      expect(result.harvest.encounters.length, 12);
      expect(result.save.bugs.length, 12);
      expect(result.save.materialCount(MaterialKind.chitin), 8);
      // 타이머 리셋
      expect(result.save.installationAt(0)!.installedAt, clock.now());
    });

    test('설치 상태 동일 → 산출 재현(리롤 불가)', () {
      final clock = FixedClock(t0);
      final svcA = makeService(clock);
      final installed = svcA.installTrap(
        _unlockedSave(t0),
        slotIndex: 0,
        fieldId: 'f',
        trapId: 't',
      );
      clock.advance(const Duration(hours: 4));

      final r1 = svcA.collect(installed, slotIndex: 0);
      // 같은 설치 상태를 다시 수령(별도 서비스, 같은 시각)
      final svcB = makeService(clock);
      final r2 = svcB.collect(installed, slotIndex: 0);

      expect(_sig(r1.harvest.encounters), _sig(r2.harvest.encounters));
    });

    test('오프라인 8h 상한: 20h 방치도 8h 산출', () {
      final clock = FixedClock(t0);
      final svc = makeService(clock);
      final installed = svc.installTrap(
        _unlockedSave(t0),
        slotIndex: 0,
        fieldId: 'f',
        trapId: 't',
      );
      clock.advance(const Duration(hours: 20));
      final result = svc.collect(installed, slotIndex: 0);
      expect(result.harvest.accrued, const Duration(hours: 8));
      expect(result.save.materialCount(MaterialKind.chitin), 16); // 2/h × 8h
    });

    test('빈 슬롯 수령은 산출 없음/세이브 불변', () {
      final svc = makeService(FixedClock(t0));
      final save = _unlockedSave(t0);
      final result = svc.collect(save, slotIndex: 2);
      expect(result.harvest.isEmpty, isTrue);
      expect(result.save.bugs, isEmpty);
    });
  });
}
