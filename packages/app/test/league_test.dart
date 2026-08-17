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
    // 400 트로피 → bronze(1500+2) + silver(5000+5) + gold(15000+10) 수령 가능.
    // 브론즈에도 보상이 생겼다 — 시즌 보상이 리그 보상에서 파생되는데
    // 브론즈가 0 이면 브론즈에 머무는 유저는 매주 아무것도 못 받는다.
    final seed = SaveGame.initial(
      createdAt: t0,
    ).copyWith(lastSeen: t0, pvpTrophies: 400);
    final c = container(seed);
    await c.read(saveControllerProvider.future);
    final ctrl = c.read(saveControllerProvider.notifier);

    final r = await ctrl.claimLeagueRewards();
    expect(r, isNotNull);
    expect(r!.gold, 21500); // 1500 + 5000 + 15000
    expect(r.jelly, 17); // 2 + 5 + 10

    final s = c.read(saveControllerProvider).requireValue;
    expect(s.gold, 21500);
    expect(s.materialCount(MaterialKind.jelly), 17);
    expect(s.claimedLeagues, {'bronze', 'silver', 'gold'});

    // 재수령 불가(추가 트로피 없음).
    expect(await ctrl.claimLeagueRewards(), isNull);
  });

  test('브론즈에 머물러도 보상이 있다 — 매주 0원이면 안 된다', () async {
    // 예전엔 브론즈 보상이 0 이라, 브론즈에 머무는 유저는 시즌이 끝나도
    // 아무것도 못 받았다(실기 지적 2026-08-18). 시즌 보상이 리그 보상에서
    // 파생되므로 브론즈가 0 이면 **매주 0원**이 된다.
    final seed = SaveGame.initial(createdAt: t0).copyWith(
      lastSeen: t0,
      pvpTrophies: 50, // bronze
    );
    final c = container(seed);
    await c.read(saveControllerProvider.future);
    final ctrl = c.read(saveControllerProvider.notifier);

    final r = await ctrl.claimLeagueRewards();
    expect(r, isNotNull);
    expect(r!.gold, 1500);
    expect(r.jelly, 2);
    // 승급 보상은 등급마다 1회 — 두 번은 없다.
    expect(await ctrl.claimLeagueRewards(), isNull);
  });
}
