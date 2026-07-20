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

/// battleConfig: {} → BattleConfig 기본 리그(bronze0/silver100/gold300/plat700/dia1500).
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
  battleConfig: const {},
);

void main() {
  final t0 = DateTime.utc(2026, 1, 1);

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

  test('승급 보상: 도달한 리그 보상 일괄 지급 후 재수령 없음', () async {
    // 400 트로피 → silver(5000골드+5젤리) + gold(15000골드+10젤리) 수령 가능.
    final seed = SaveGame.initial(
      createdAt: t0,
    ).copyWith(lastSeen: t0, pvpTrophies: 400);
    final c = container(seed);
    await c.read(saveControllerProvider.future);
    final ctrl = c.read(saveControllerProvider.notifier);

    final r = await ctrl.claimLeagueRewards();
    expect(r, isNotNull);
    expect(r!.gold, 20000); // 5000 + 15000
    expect(r.jelly, 15); // 5 + 10

    final s = c.read(saveControllerProvider).requireValue;
    expect(s.gold, 20000);
    expect(s.materialCount(MaterialKind.jelly), 15);
    expect(s.claimedLeagues, {'silver', 'gold'});

    // 재수령 불가(추가 트로피 없음).
    expect(await ctrl.claimLeagueRewards(), isNull);
  });

  test('보상 없는 리그(bronze)만 도달 시 수령 불가', () async {
    final seed = SaveGame.initial(createdAt: t0).copyWith(
      lastSeen: t0,
      pvpTrophies: 50, // bronze
    );
    final c = container(seed);
    await c.read(saveControllerProvider.future);
    expect(
      await c.read(saveControllerProvider.notifier).claimLeagueRewards(),
      isNull,
    );
  });
}
