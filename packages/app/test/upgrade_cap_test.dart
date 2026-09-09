import 'dart:convert';
import 'dart:io';

import 'package:app/data/game_data.dart';
import 'package:app/data/save_repository.dart';
import 'package:app/domain/providers.dart';
import 'package:app/domain/save_controller.dart';
import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repo implements SaveRepository {
  _Repo(this._g);
  SaveGame _g;
  @override
  SaveLoadFailure? get lastFailure => null;
  @override
  Future<SaveGame> load() async => _g;
  @override
  Future<void> save(SaveGame g) async => _g = g;
  @override
  Future<void> clear() async =>
      _g = SaveGame.initial(createdAt: DateTime.utc(2026));
}

Map<String, dynamic> _read(String f) =>
    jsonDecode(File('assets/data/$f').readAsStringSync())
        as Map<String, dynamic>;

/// 실데이터로 돈다 — 상한은 JSON 에 있으므로 JSON 을 고치면 여기서 먼저 보인다.
GameData _data() => GameData.fromDecoded(
  species: _read('species.json'),
  traps: _read('traps.json'),
  fields: _read('fields.json'),
  spawns: _read('spawns.json'),
  runConfig: _read('run_config.json'),
  petConfig: _read('pets.json'),
  itemConfig: _read('items.json'),
  forgeConfig: _read('forge.json'),
  skillConfig: _read('skills.json'),
);

void main() {
  final t0 = DateTime.utc(2026, 9, 9);

  ProviderContainer make(SaveGame seed) {
    final c = ProviderContainer(
      overrides: [
        gameDataProvider.overrideWith((ref) => _data()),
        saveRepositoryProvider.overrideWithValue(_Repo(seed)),
        clockProvider.overrideWithValue(FixedClock(t0)),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('업그레이드 상한(maxLevel)', () {
    test('실데이터의 모든 업그레이드에 상한이 있다', () {
      // 상한이 없는 축은 골드만 있으면 무한히 산다 — 능력치만 뽑는 길에 끝이
      // 있어야 펫·장비를 뽑을 이유가 생긴다(2026-09-09 확정).
      final run = _data().runConfig!;
      for (final kind in run.upgrades.keys) {
        expect(
          run.upgrade(kind).maxLevel,
          isNotNull,
          reason: '${kind.key} 에 maxLevel 이 없다',
        );
      }
    });

    test('상한에 닿으면 골드가 있어도 더 못 산다 — 연타·x100 도 막힌다', () async {
      final run = _data().runConfig!;
      final cap = run.upgrade(UpgradeKind.crit).maxLevel!;
      final c = make(
        SaveGame.initial(createdAt: t0).copyWith(
          gold: 9000000000000000000,
          materials: {
            MaterialKind.chitin: 1 << 40,
            MaterialKind.mineral: 1 << 40,
            MaterialKind.sap: 1 << 40,
          },
          upgradeLevels: {UpgradeKind.crit: cap - 1},
        ),
      );
      await c.read(saveControllerProvider.future);
      final ctrl = c.read(saveControllerProvider.notifier);

      // 한 칸 남았다 → 100 을 눌러도 1 만 산다.
      expect(await ctrl.buyUpgrade(UpgradeKind.crit, count: 100), 1);
      expect(
        c
            .read(saveControllerProvider)
            .requireValue
            .upgradeLevel(UpgradeKind.crit),
        cap,
      );
      // 상한에서 또 누르면 0.
      expect(await ctrl.buyUpgrade(UpgradeKind.crit, count: 10), 0);
    });
  });
}
