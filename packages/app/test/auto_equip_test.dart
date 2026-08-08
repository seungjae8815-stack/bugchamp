import 'dart:convert';
import 'dart:io';

import 'package:app/data/game_data.dart';
import 'package:app/data/save_repository.dart';
import 'package:app/domain/providers.dart';
import 'package:app/domain/save_controller.dart';
import 'package:core_models/core_models.dart';
import 'package:core_save/core_save.dart';
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

Map<String, dynamic> _species(String id, String grade) => {
  'id': id,
  'name': _name(id),
  'grade': grade,
  'specialty': 'grip',
  'baseStats': {'hp': 100, 'atk': 40, 'def': 30, 'spd': 20},
  'sizeMinMm': 20,
  'sizeMaxMm': 60,
};

GameData _data() => GameData.fromDecoded(
  species: {
    'species': [
      _species('low', 'common'),
      _species('mid', 'rare'),
      _species('high', 'legendary'),
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
  // 펫 보너스 수식은 실제 밸런스로 검증한다(더미면 순위가 뒤집힐 수 있다).
  petConfig:
      jsonDecode(File('assets/data/pets.json').readAsStringSync())
          as Map<String, dynamic>,
);

void main() {
  final t0 = DateTime.utc(2026, 8, 8, 12);

  IndividualBug bug(String id, String sp, {int potential = 3, int level = 1}) =>
      IndividualBug(
        id: id,
        speciesId: sp,
        sizeMm: 40,
        potential: potential,
        temperament: Temperament.steadfast,
        sex: Sex.male,
        stage: LifeStage.adult,
        stageSince: t0.subtract(const Duration(days: 30)),
        level: level,
      );

  ProviderContainer container(SaveGame seed) {
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

  test('자동장착은 보너스가 큰 3마리를 고른다', () async {
    final seed = SaveGame.initial(createdAt: t0).copyWith(
      lastSeen: t0,
      bugs: [
        bug('c1', 'low'),
        bug('c2', 'low'),
        bug('r1', 'mid'),
        bug('L1', 'high'),
        bug('c3', 'low'),
      ],
    );
    final c = container(seed);
    await c.read(saveControllerProvider.future);
    expect(
      await c.read(saveControllerProvider.notifier).autoEquipBest(),
      isTrue,
    );

    final s = c.read(saveControllerProvider).requireValue;
    expect(s.equippedBugIds.length, 3);
    // 전설 > 희귀 가 반드시 포함되고, 맨 앞이 가장 센 개체다.
    expect(s.equippedBugIds.first, 'L1');
    expect(s.equippedBugIds, contains('r1'));
  });

  test('같은 종이면 레벨·포텐셜이 높은 쪽을 고른다', () async {
    final seed = SaveGame.initial(createdAt: t0).copyWith(
      lastSeen: t0,
      bugs: [
        bug('weak', 'mid', potential: 1, level: 1),
        bug('strong', 'mid', potential: 5, level: 20),
        bug('mid', 'mid', potential: 3, level: 5),
      ],
    );
    final c = container(seed);
    await c.read(saveControllerProvider.future);
    await c.read(saveControllerProvider.notifier).autoEquipBest();
    expect(
      c.read(saveControllerProvider).requireValue.equippedBugIds.first,
      'strong',
    );
  });

  test('이미 최적이면 저장하지 않는다(불필요한 업로드 방지)', () async {
    final seed = SaveGame.initial(createdAt: t0).copyWith(
      lastSeen: t0,
      bugs: [bug('L1', 'high'), bug('r1', 'mid'), bug('c1', 'low')],
    );
    final c = container(seed);
    await c.read(saveControllerProvider.future);
    final ctrl = c.read(saveControllerProvider.notifier);
    expect(await ctrl.autoEquipBest(), isTrue);
    // 두 번째 호출은 바꿀 게 없다.
    expect(await ctrl.autoEquipBest(), isFalse);
  });

  test('곤충이 없으면 아무 일도 하지 않는다', () async {
    final c = container(SaveGame.initial(createdAt: t0).copyWith(lastSeen: t0));
    await c.read(saveControllerProvider.future);
    expect(
      await c.read(saveControllerProvider.notifier).autoEquipBest(),
      isFalse,
    );
  });
}
