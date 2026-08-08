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

Map<String, dynamic> _readJson(String rel) =>
    jsonDecode(File(rel).readAsStringSync()) as Map<String, dynamic>;

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
  // 방치 수식은 실제 밸런스 값으로 검증한다(더미 값이면 의미가 없다).
  runConfig: _readJson('assets/data/run_config.json'),
);

void main() {
  final t0 = DateTime.utc(2026, 8, 8, 12);

  test('백그라운드에 있던 시간도 방치 보상으로 정산된다', () async {
    // 이 테스트가 잡는 버그: 예전엔 앱 **시작 때만** 정산해서, 앱을 내려놨다가
    // 다시 열면 그 시간이 통째로 사라졌다.
    final clock = FixedClock(t0);
    final seed = SaveGame.initial(
      createdAt: t0,
    ).copyWith(lastSeen: t0, stageNumber: 30, level: 5);
    final c = ProviderContainer(
      overrides: [
        gameDataProvider.overrideWith((ref) => _data()),
        saveRepositoryProvider.overrideWithValue(_FakeRepo(seed)),
        clockProvider.overrideWithValue(clock),
      ],
    );
    addTearDown(c.dispose);

    await c.read(saveControllerProvider.future);
    final ctrl = c.read(saveControllerProvider.notifier);
    final goldAtStart = c.read(saveControllerProvider).requireValue.gold;

    // 2시간 백그라운드 → 복귀.
    clock.advance(const Duration(hours: 2));
    expect(await ctrl.settleOffline(), isTrue);

    final after = c.read(saveControllerProvider).requireValue;
    expect(after.gold, greaterThan(goldAtStart));
    expect(ctrl.pendingOffline, isNotNull);
    expect(ctrl.pendingOffline!.accrued, const Duration(hours: 2));
  });

  test('잠깐 다녀온 정도(1분 이하)는 정산하지 않는다', () async {
    final clock = FixedClock(t0);
    final c = ProviderContainer(
      overrides: [
        gameDataProvider.overrideWith((ref) => _data()),
        saveRepositoryProvider.overrideWithValue(
          _FakeRepo(SaveGame.initial(createdAt: t0).copyWith(lastSeen: t0)),
        ),
        clockProvider.overrideWithValue(clock),
      ],
    );
    addTearDown(c.dispose);
    await c.read(saveControllerProvider.future);
    final ctrl = c.read(saveControllerProvider.notifier);

    clock.advance(const Duration(seconds: 30));
    expect(await ctrl.settleOffline(), isFalse);
    expect(ctrl.pendingOffline, isNull);
  });

  test('연달아 복귀해도 같은 시간을 두 번 주지 않는다', () async {
    // `_commit` 이 lastSeen 을 지금으로 찍으므로 경과가 리셋돼야 한다.
    final clock = FixedClock(t0);
    final c = ProviderContainer(
      overrides: [
        gameDataProvider.overrideWith((ref) => _data()),
        saveRepositoryProvider.overrideWithValue(
          _FakeRepo(
            SaveGame.initial(
              createdAt: t0,
            ).copyWith(lastSeen: t0, stageNumber: 30),
          ),
        ),
        clockProvider.overrideWithValue(clock),
      ],
    );
    addTearDown(c.dispose);
    await c.read(saveControllerProvider.future);
    final ctrl = c.read(saveControllerProvider.notifier);

    clock.advance(const Duration(hours: 1));
    expect(await ctrl.settleOffline(), isTrue);
    final goldOnce = c.read(saveControllerProvider).requireValue.gold;

    // 시간을 더 보내지 않고 바로 다시 복귀 → 추가 지급이 없어야 한다.
    expect(await ctrl.settleOffline(), isFalse);
    expect(c.read(saveControllerProvider).requireValue.gold, goldOnce);
  });
}
