import 'package:app/data/game_data.dart';
import 'package:app/data/save_repository.dart';
import 'package:app/domain/providers.dart';
import 'package:app/domain/save_controller.dart';
import 'package:core_save/core_save.dart';
import 'package:core_models/core_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRepo implements SaveRepository {
  _FakeRepo(this._game);
  SaveGame _game;
  @override
  Future<SaveGame> load() async => _game;
  @override
  Future<void> save(SaveGame g) async => _game = g;
  @override
  Future<void> clear() async =>
      _game = SaveGame.initial(createdAt: DateTime.utc(2026, 1, 1));
}

Map<String, dynamic> _name(String s) => {'ko': s, 'en': s, 'ja': s};

GameData _data() => GameData.fromDecoded(
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
        'grade': 'common',
        'specialty': 'grip',
        'baseStats': {'hp': 100, 'atk': 40, 'def': 30, 'spd': 20},
        'sizeMinMm': 20,
        'sizeMaxMm': 60,
      },
    ],
  },
  traps: {
    'traps': [
      {'id': 'sap_trap', 'name': _name('S')},
    ],
  },
  fields: {
    'fields': [
      {'id': 'oak_forest', 'name': _name('O'), 'unlockOrder': 0},
    ],
  },
  spawns: {
    'schemaVersion': 1,
    'defaultPotentialWeights': [
      {'potential': 1, 'weight': 1},
    ],
    'spawns': <dynamic>[],
  },
  petConfig: {
    'gradeAttackPct': {'common': 0.05},
    'gradeHpPct': {'common': 0.05},
    'stageMult': {'egg': 0.3, 'larva': 0.5, 'pupa': 0.7, 'adult': 1.0},
    'stageDurationsSec': {'egg': 60, 'larva': 60, 'pupa': 60},
    'breedingDurationsSec': {'common': 600},
    'breedingJellyPerMinute': 0.5,
  },
);

IndividualBug _bug(String id, String species, Sex sex) => IndividualBug(
  id: id,
  speciesId: species,
  sizeMm: 40,
  potential: 3,
  temperament: Temperament.steadfast,
  sex: sex,
);

void main() {
  final t0 = DateTime.utc(2026, 1, 1);

  ProviderContainer container(List<IndividualBug> bugs, {int jelly = 0}) {
    final seed = SaveGame.initial(createdAt: t0).copyWith(
      lastSeen: t0,
      bugs: bugs,
      materials: {MaterialKind.jelly: jelly},
    );
    final c = ProviderContainer(
      overrides: [
        gameDataProvider.overrideWith((ref) => _data()),
        saveRepositoryProvider.overrideWithValue(_FakeRepo(seed)),
        clockProvider.overrideWithValue(FixedClock(t0)),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('산란 시작 → 젤리 즉시완료 → 자식(알) 획득', () async {
    final c = container([
      _bug('mom', 'a', Sex.female),
      _bug('dad', 'a', Sex.male),
    ], jelly: 10);
    await c.read(saveControllerProvider.future);
    final ctrl = c.read(saveControllerProvider.notifier);

    expect(await ctrl.startBreeding('mom', 'dad', 123), isTrue);
    var s = c.read(saveControllerProvider).requireValue;
    expect(s.breeding.length, 1);

    final slotId = s.breeding.first.id;
    // 남은 600초 → ceil(600/60 × 0.5) = 5 젤리
    expect(await ctrl.collectBreeding(slotId, viaJelly: true), isTrue);
    s = c.read(saveControllerProvider).requireValue;
    expect(s.breeding, isEmpty);
    expect(s.materialCount(MaterialKind.jelly), 5); // 10 − 5
    // 새 개체 = 알, 같은 종
    final egg = s.bugs.firstWhere((b) => b.id != 'mom' && b.id != 'dad');
    expect(egg.stage, LifeStage.egg);
    expect(egg.speciesId, 'a');
  });

  test('산란 완료 전 젤리 없이 수령 불가', () async {
    final c = container([
      _bug('mom', 'a', Sex.female),
      _bug('dad', 'a', Sex.male),
    ]);
    await c.read(saveControllerProvider.future);
    final ctrl = c.read(saveControllerProvider.notifier);
    await ctrl.startBreeding('mom', 'dad', 1);
    final slotId = c
        .read(saveControllerProvider)
        .requireValue
        .breeding
        .first
        .id;
    expect(await ctrl.collectBreeding(slotId), isFalse); // 아직 산란 중
  });

  test('잘못된 짝은 거부: 동성·다른 종·같은 개체', () async {
    final c = container([
      _bug('f1', 'a', Sex.female),
      _bug('f2', 'a', Sex.female),
      _bug('m_b', 'b', Sex.male),
    ]);
    await c.read(saveControllerProvider.future);
    final ctrl = c.read(saveControllerProvider.notifier);
    expect(await ctrl.startBreeding('f1', 'f2', 1), isFalse); // 동성
    expect(await ctrl.startBreeding('f1', 'm_b', 1), isFalse); // 다른 종
    expect(await ctrl.startBreeding('f1', 'f1', 1), isFalse); // 같은 개체
    expect(c.read(saveControllerProvider).requireValue.breeding, isEmpty);
  });
}
