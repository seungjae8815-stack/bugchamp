import 'package:app/data/game_data.dart';
import 'package:app/data/save_repository.dart';
import 'package:app/domain/providers.dart';
import 'package:app/domain/save_controller.dart';
import 'package:app/domain/save_game.dart';
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

/// battleConfig: {} → 기본(season days14/reset0.5/mult3, 리그 브론즈~다이아).
/// runConfig 없음 → 오프라인 정산이 시즌 판정에 끼어들지 않음.
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
  final t0 = DateTime.utc(2026, 2, 1);

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

  test('시즌 만료: 최고 등급 보상 + 트로피 소프트리셋', () async {
    // 시즌 시작 31일 전 → 만료. peak 800(platinum) → 보상 120000골드·60젤리, 리셋 400.
    final seed = SaveGame.initial(createdAt: DateTime.utc(2026, 1, 1)).copyWith(
      lastSeen: t0,
      pvpTrophies: 800,
      seasonPeakTrophies: 800,
      seasonStartedAt: DateTime.utc(2026, 1, 1),
    );
    final c = container(seed);
    await c.read(saveControllerProvider.future);

    final s = c.read(saveControllerProvider).requireValue;
    expect(s.pvpTrophies, 400); // 800 × 0.5
    expect(s.gold, 120000); // platinum 40000 × 3
    expect(s.materialCount(MaterialKind.jelly), 60); // 20 × 3
    expect(s.seasonPeakTrophies, 400);
    expect(s.seasonStartedAt, t0); // 새 시즌 시작

    final report = c.read(saveControllerProvider.notifier).pendingSeason;
    expect(report, isNotNull);
    expect(report!.peakTrophies, 800);
    expect(report.fromTrophies, 800);
    expect(report.toTrophies, 400);
  });

  test('시즌 미만료: 변화 없음', () async {
    final seed = SaveGame.initial(createdAt: DateTime.utc(2026, 1, 1)).copyWith(
      lastSeen: t0,
      pvpTrophies: 800,
      seasonPeakTrophies: 800,
      seasonStartedAt: DateTime.utc(2026, 1, 25), // 7일 전 → 미만료
    );
    final c = container(seed);
    await c.read(saveControllerProvider.future);

    final s = c.read(saveControllerProvider).requireValue;
    expect(s.pvpTrophies, 800); // 유지
    expect(c.read(saveControllerProvider.notifier).pendingSeason, isNull);
  });
}
