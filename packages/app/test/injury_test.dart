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
    'injuryDurationsSec': {'common': 300},
    'injuryJellyPerMinute': 0.5,
  },
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

  SaveGame seededSave({int jelly = 0}) =>
      SaveGame.initial(createdAt: t0).copyWith(
        lastSeen: t0,
        bugs: const [
          IndividualBug(
            id: 'b1',
            speciesId: 'a',
            sizeMm: 40,
            potential: 3,
            temperament: Temperament.steadfast,
            sex: Sex.male,
          ),
        ],
        materials: {MaterialKind.jelly: jelly},
      );

  test('결투에서 KO된 곤충은 등급별 회복 타이머로 부상 처리된다', () async {
    final c = container(seededSave());
    await c.read(saveControllerProvider.future);
    await c
        .read(saveControllerProvider.notifier)
        .applyBattleResult(gold: 0, trophyDelta: -8, koedBugIds: ['b1']);

    final s = c.read(saveControllerProvider).requireValue;
    expect(s.isInjured('b1', t0), isTrue);
    // common 등급 회복 300초 → t0 + 300s
    expect(s.injuredUntil('b1'), t0.add(const Duration(seconds: 300)));
  });

  test('젤리 즉시회복: 남은분 비례 젤리 소비 후 부상 해제', () async {
    final c = container(seededSave(jelly: 5));
    await c.read(saveControllerProvider.future);
    final ctrl = c.read(saveControllerProvider.notifier);
    await ctrl.applyBattleResult(gold: 0, trophyDelta: -8, koedBugIds: ['b1']);

    // 남은 300초 → ceil(300/60 × 0.5) = 3 젤리
    final ok = await ctrl.healInjury('b1', viaJelly: true);
    expect(ok, isTrue);
    final s = c.read(saveControllerProvider).requireValue;
    expect(s.isInjured('b1', t0), isFalse);
    expect(s.materialCount(MaterialKind.jelly), 2); // 5 − 3
  });

  test('젤리 부족이면 즉시회복 실패(부상 유지)', () async {
    final c = container(seededSave(jelly: 1));
    await c.read(saveControllerProvider.future);
    final ctrl = c.read(saveControllerProvider.notifier);
    await ctrl.applyBattleResult(gold: 0, trophyDelta: -8, koedBugIds: ['b1']);

    final ok = await ctrl.healInjury('b1', viaJelly: true);
    expect(ok, isFalse);
    final s = c.read(saveControllerProvider).requireValue;
    expect(s.isInjured('b1', t0), isTrue);
    expect(s.materialCount(MaterialKind.jelly), 1); // 소비 없음
  });
}
