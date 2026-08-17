import 'dart:convert';
import 'dart:io';

import 'package:app/data/game_data.dart';
import 'package:app/data/save_repository.dart';
import 'package:app/domain/bug_auto_filter.dart';
import 'package:app/domain/providers.dart';
import 'package:app/domain/save_controller.dart';
import 'package:core_models/core_models.dart';
import 'package:core_save/core_save.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 자동 분해(§2.7) — 조건에 맞는 곤충을 한 번에 재료로 바꾼다.
///
/// 검사하는 것은 두 가지다.
///  1. **안전장치** — 장착·부화 중·투자한 개체(수련/돌파/강화)는 필터에 걸려도
///     사라지지 않는다. 자동 정리는 되돌릴 수 없다.
///  2. **젤리를 주지 않는다** — 손으로 하는 분해는 손이 병목이라 4성↑ 에 젤리를
///     줘도 안전하지만, 일괄 분해엔 병목이 없다. 무한히 늘어나는 통로에는
///     젤리를 붙이지 않는다(§2.6). 이건 수치가 아니라 **구조 규칙**이라
///     계수를 바꿔도 깨지면 안 된다.
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
      _species('alpha', 'common'),
      _species('beta', 'rare'),
      _species('gamma', 'legendary'),
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
  petConfig:
      jsonDecode(File('assets/data/pets.json').readAsStringSync())
          as Map<String, dynamic>,
);

void main() {
  final t0 = DateTime.utc(2026, 8, 15, 12);

  IndividualBug bug(
    String id,
    String sp, {
    int potential = 1,
    int level = 1,
    int tier = 0,
    PartLevels enhancement = PartLevels.zero,
  }) => IndividualBug(
    id: id,
    speciesId: sp,
    sizeMm: 40,
    potential: potential,
    temperament: Temperament.steadfast,
    sex: Sex.male,
    stage: LifeStage.adult,
    stageSince: t0.subtract(const Duration(days: 30)),
    level: level,
    breakthroughTier: tier,
    enhancement: enhancement,
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

  Future<SaveController> ctrl(ProviderContainer c) async {
    await c.read(saveControllerProvider.future);
    return c.read(saveControllerProvider.notifier);
  }

  const all = BugAutoFilter(grades: {...Grade.values}, maxPotential: 5);

  test('필터에 맞는 등급만 사라진다', () async {
    final seed = SaveGame.initial(createdAt: t0).copyWith(
      lastSeen: t0,
      bugs: [bug('a1', 'alpha'), bug('b1', 'beta'), bug('g1', 'gamma')],
    );
    final c = container(seed);
    final k = await ctrl(c);
    final r = await k.autoRelease(
      filter: const BugAutoFilter(grades: {Grade.common}, maxPotential: 5),
    );

    expect(r.released, 1);
    final s = c.read(saveControllerProvider).requireValue;
    expect(s.bugs.map((b) => b.id), ['b1', 'g1']);
  });

  test('포텐셜 상한을 넘는 개체는 남는다 — 잘 뽑힌 것을 지키는 문턱', () async {
    final seed = SaveGame.initial(createdAt: t0).copyWith(
      lastSeen: t0,
      bugs: [
        bug('a1', 'alpha', potential: 2),
        bug('a2', 'alpha', potential: 5),
      ],
    );
    final c = container(seed);
    final k = await ctrl(c);
    final r = await k.autoRelease(
      filter: const BugAutoFilter(grades: {Grade.common}, maxPotential: 3),
    );

    expect(r.released, 1);
    expect(c.read(saveControllerProvider).requireValue.bugs.single.id, 'a2');
  });

  test('장착·부화 중·투자한 개체는 필터에 걸려도 건드리지 않는다', () async {
    final seed = SaveGame.initial(createdAt: t0).copyWith(
      lastSeen: t0,
      bugs: [
        bug('equipped', 'alpha'),
        bug('incubating', 'alpha'),
        bug('trained', 'alpha', level: 2),
        bug('broken', 'alpha', tier: 1),
        bug('enhanced', 'alpha', enhancement: const PartLevels(hornJaw: 1)),
        bug('plain', 'alpha'),
      ],
      equippedBugIds: ['equipped'],
      incubating: {'incubating': t0.add(const Duration(hours: 1))},
    );
    final c = container(seed);
    final k = await ctrl(c);
    final r = await k.autoRelease(filter: all);

    // 사라지는 건 아무것도 투자하지 않은 'plain' 하나뿐이다.
    expect(r.released, 1);
    expect(r.consumed, ['plain']);
    final s = c.read(saveControllerProvider).requireValue;
    expect(s.bugs.length, 5);
    expect(s.bugs.any((b) => b.id == 'plain'), isFalse);
  });

  test('젤리는 절대 나오지 않는다 — 5성 전설을 분해해도 재료만', () async {
    final seed = SaveGame.initial(createdAt: t0).copyWith(
      lastSeen: t0,
      bugs: [for (var i = 0; i < 20; i++) bug('g$i', 'gamma', potential: 5)],
    );
    final c = container(seed);
    final k = await ctrl(c);
    final before = c
        .read(saveControllerProvider)
        .requireValue
        .materialCount(MaterialKind.jelly);
    final r = await k.autoRelease(filter: all);

    expect(r.released, 20);
    final s = c.read(saveControllerProvider).requireValue;
    expect(
      s.materialCount(MaterialKind.jelly),
      before,
      reason: '자동으로 굴러가는 통로에 젤리를 붙이면 IAP 가 죽는다(§2.6)',
    );
    // 일반 재료는 들어와야 한다 — 분해가 아무 보상도 없으면 쓸 이유가 없다.
    final mats = [
      for (final m in kRegularMaterials) s.materialCount(m),
    ].fold(0, (a, b) => a + b);
    expect(mats, greaterThan(0));
    expect(r.materials, greaterThan(0));
  });

  test('dryRun 은 세이브를 건드리지 않는다 — 확인 다이얼로그에 쓰는 값', () async {
    final seed = SaveGame.initial(
      createdAt: t0,
    ).copyWith(lastSeen: t0, bugs: [bug('a1', 'alpha'), bug('a2', 'alpha')]);
    final c = container(seed);
    final k = await ctrl(c);
    final r = await k.autoRelease(dryRun: true, filter: all);

    expect(r.released, 2);
    expect(r.consumed.length, 2);
    expect(c.read(saveControllerProvider).requireValue.bugs.length, 2);
  });

  test('등급을 하나도 고르지 않으면 아무것도 하지 않는다', () async {
    final seed = SaveGame.initial(
      createdAt: t0,
    ).copyWith(lastSeen: t0, bugs: [bug('a1', 'alpha')]);
    final c = container(seed);
    final k = await ctrl(c);
    final r = await k.autoRelease(
      filter: const BugAutoFilter(grades: {}, maxPotential: 5),
    );

    expect(r.released, 0);
    expect(c.read(saveControllerProvider).requireValue.bugs.length, 1);
  });

  test('자동 합성도 필터를 따른다 — 대상 밖 등급은 재료로 쓰지 않는다', () async {
    final seed = SaveGame.initial(createdAt: t0).copyWith(
      lastSeen: t0,
      bugs: [
        bug('b1', 'beta'),
        bug('b2', 'beta'),
        bug('b3', 'beta'),
        bug('b4', 'beta'),
      ],
    );
    final c = container(seed);
    final k = await ctrl(c);
    // 희귀(beta)를 대상에서 빼면 재료가 없어 합성이 일어나지 않는다.
    final r = await k.autoSynthesize(
      filter: const BugAutoFilter(grades: {Grade.common}, maxPotential: 5),
    );

    expect(r.fused, 0);
    expect(c.read(saveControllerProvider).requireValue.bugs.length, 4);
  });
}
