import 'package:app/data/game_data.dart';
import 'package:app/data/save_repository.dart';
import 'package:app/domain/providers.dart';
import 'package:core_save/core_save.dart';
import 'package:app/main.dart';
import 'package:core_models/core_models.dart';
import 'package:flutter/material.dart';
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

GameData _fixtureData() => GameData.fromDecoded(
  species: {
    'species': [
      {
        'id': 'a',
        'name': _name('Test Bug'),
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
      {'id': 'sap_trap', 'name': _name('Sap Trap')},
    ],
  },
  fields: {
    'fields': [
      {'id': 'oak_forest', 'name': _name('Oak Forest'), 'unlockOrder': 0},
    ],
  },
  spawns: {
    'schemaVersion': 1,
    'defaultPotentialWeights': [
      {'potential': 1, 'weight': 1},
    ],
    'spawns': [
      {
        'fieldId': 'oak_forest',
        'trapId': 'sap_trap',
        'encountersPerHour': 1.0,
        'materialsPerHour': [
          {'kind': 'chitin', 'perHour': 2.0},
        ],
        'speciesWeights': [
          {'speciesId': 'a', 'weight': 1},
        ],
      },
    ],
  },
  runConfig: {
    'hpBase': 5,
    'hpGrowth': 1.0,
    'bossHpMult': 2.0,
    'goldBase': 10,
    'goldGrowth': 1.0,
    'xpBase': 4,
    'xpGrowth': 1.0,
    'bossRewardMult': 4.0,
    'habitatsPerStage': 3,
    'bugDropChance': 0.2,
    'materialDropChance': 0.3,
    'region': {
      'id': 'oak_forest',
      'name': _name('Oak Forest'),
      'bossName': _name('Boss'),
      'habitatKinds': ['tree', 'rock'],
    },
    'upgrades': [
      {
        'kind': 'attack',
        'baseCost': 10,
        'costGrowth': 1.1,
        'baseValue': 20,
        'perLevel': 5,
      },
      {
        'kind': 'attackSpeed',
        'baseCost': 10,
        'costGrowth': 1.1,
        'baseValue': 2.0,
        'perLevel': 0.1,
      },
      {
        'kind': 'reward',
        'baseCost': 10,
        'costGrowth': 1.1,
        'baseValue': 1.0,
        'perLevel': 0.05,
      },
    ],
  },
);

Widget _wrap(SaveRepository repo) => ProviderScope(
  overrides: [
    gameDataProvider.overrideWith((ref) => _fixtureData()),
    saveRepositoryProvider.overrideWithValue(repo),
    // 초기 세이브(lastSeen 2026-01-01)와 30초 차 → 오프라인 보상 미발동
    clockProvider.overrideWithValue(
      FixedClock(DateTime.utc(2026, 1, 1, 0, 0, 30)),
    ),
  ],
  child: const BugChampApp(),
);

Future<void> _advance(WidgetTester tester, double seconds) async {
  for (var t = 0.0; t < seconds; t += 0.05) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('부팅 → 3탭(홈/강화/도감) + 골드 HUD', (tester) async {
    final repo = _FakeRepo(
      SaveGame.initial(createdAt: DateTime.utc(2026, 1, 1)),
    );
    await tester.pumpWidget(_wrap(repo));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    expect(find.text('Home'), findsWidgets);
    expect(find.text('Storage'), findsWidgets);
    expect(find.text('Shop'), findsWidgets);
    expect(
      tester.widget<Text>(find.byKey(const Key('goldHud'))).data,
      '0',
    ); // 골드 HUD 초기값
  });

  testWidgets('자동 타격 루프가 골드를 벌어들인다', (tester) async {
    final repo = _FakeRepo(
      SaveGame.initial(createdAt: DateTime.utc(2026, 1, 1)),
    );
    await tester.pumpWidget(_wrap(repo));
    await tester.pump();
    await _advance(tester, 3.0);

    // 서식지가 여러 번 파괴되어 골드가 0을 벗어남
    expect(
      tester.widget<Text>(find.byKey(const Key('goldHud'))).data,
      isNot('0'),
    );
  });
}
