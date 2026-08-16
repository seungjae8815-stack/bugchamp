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

/// 자동 합성(§2.7) — 같은 종이 쌓인 곳을 한 번에 정리해 포텐셜을 올린다.
///
/// 곤충이 **사라지는** 동작이라 안전장치가 핵심이다: 장착·부화 중·투자한
/// 개체(수련/돌파/강화)는 절대 재료로 쓰지 않는다. 하나라도 무너지면
/// "골드 쏟은 곤충이 조용히 없어졌다"가 되고, 그건 되돌릴 수 없다.
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
    'species': [_species('alpha', 'common'), _species('beta', 'rare')],
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
  // 합성 재료 수(synthFodder)·최대 포텐셜은 실제 밸런스를 쓴다.
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

  Future<SaveController> ctrl(SaveGame seed, ProviderContainer c) async {
    await c.read(saveControllerProvider.future);
    return c.read(saveControllerProvider.notifier);
  }

  test('같은 종 4마리 → 1번 합성, 재료 3마리 소멸, 타깃 포텐셜 +1', () async {
    final seed = SaveGame.initial(createdAt: t0).copyWith(
      lastSeen: t0,
      bugs: [
        bug('a1', 'alpha'),
        bug('a2', 'alpha'),
        bug('a3', 'alpha'),
        bug('a4', 'alpha'),
      ],
    );
    final c = container(seed);
    final k = await ctrl(seed, c);
    final r = await k.autoSynthesize();

    expect(r.fused, 1);
    expect(r.used, 3);
    final s = c.read(saveControllerProvider).requireValue;
    expect(s.bugs.length, 1);
    expect(s.bugs.single.potential, 2);
  });

  test('재료가 모자라면 아무것도 하지 않는다', () async {
    final seed = SaveGame.initial(createdAt: t0).copyWith(
      lastSeen: t0,
      bugs: [bug('a1', 'alpha'), bug('a2', 'alpha'), bug('a3', 'alpha')],
    );
    final c = container(seed);
    final k = await ctrl(seed, c);
    final r = await k.autoSynthesize();

    expect(r.fused, 0);
    expect(c.read(saveControllerProvider).requireValue.bugs.length, 3);
  });

  test('장착 중인 곤충은 재료로 쓰지 않는다', () async {
    final seed = SaveGame.initial(createdAt: t0).copyWith(
      lastSeen: t0,
      bugs: [
        bug('a1', 'alpha'),
        bug('a2', 'alpha'),
        bug('a3', 'alpha'),
        bug('a4', 'alpha'),
      ],
      // 4마리 중 하나가 장착 → 재료 후보가 2마리뿐이라 합성 불가.
      equippedBugIds: ['a4'],
    );
    final c = container(seed);
    final k = await ctrl(seed, c);
    final r = await k.autoSynthesize();

    expect(r.fused, 0);
    final s = c.read(saveControllerProvider).requireValue;
    expect(s.bugs.map((b) => b.id), containsAll(['a1', 'a2', 'a3', 'a4']));
  });

  test('부화 중인 곤충도 보호된다', () async {
    final seed = SaveGame.initial(createdAt: t0).copyWith(
      lastSeen: t0,
      bugs: [
        bug('a1', 'alpha'),
        bug('a2', 'alpha'),
        bug('a3', 'alpha'),
        bug('a4', 'alpha'),
      ],
      incubating: {'a4': t0.add(const Duration(minutes: 5))},
    );
    final c = container(seed);
    final k = await ctrl(seed, c);
    expect((await k.autoSynthesize()).fused, 0);
  });

  test('투자한 곤충(수련/돌파/강화)은 재료가 되지 않는다 — 되돌릴 수 없는 손실', () async {
    final seed = SaveGame.initial(createdAt: t0).copyWith(
      lastSeen: t0,
      bugs: [
        bug('raw1', 'alpha'),
        bug('raw2', 'alpha'),
        bug('leveled', 'alpha', level: 9), // 골드를 쏟은 개체
        bug('broken', 'alpha', tier: 1), // 돌파한 개체
        bug(
          'enhanced',
          'alpha',
          enhancement: const PartLevels(hornJaw: 3),
        ), // 강화한 개체
      ],
    );
    final c = container(seed);
    final k = await ctrl(seed, c);
    final r = await k.autoSynthesize();

    // 재료로 쓸 수 있는 건 raw 2마리뿐 → 3마리가 안 되므로 합성 불가.
    expect(r.fused, 0);
    final ids = c
        .read(saveControllerProvider)
        .requireValue
        .bugs
        .map((b) => b.id);
    expect(ids, containsAll(['leveled', 'broken', 'enhanced']));
  });

  test('타깃은 가장 많이 투자된 개체 — 키우던 곤충이 올라간다', () async {
    final seed = SaveGame.initial(createdAt: t0).copyWith(
      lastSeen: t0,
      bugs: [
        bug('raw1', 'alpha'),
        bug('raw2', 'alpha'),
        bug('raw3', 'alpha'),
        bug('leveled', 'alpha', level: 12),
      ],
    );
    final c = container(seed);
    final k = await ctrl(seed, c);
    expect((await k.autoSynthesize()).fused, 1);

    final s = c.read(saveControllerProvider).requireValue;
    expect(s.bugs.single.id, 'leveled');
    expect(s.bugs.single.potential, 2);
  });

  test('종이 다르면 섞이지 않는다', () async {
    final seed = SaveGame.initial(createdAt: t0).copyWith(
      lastSeen: t0,
      bugs: [
        bug('a1', 'alpha'),
        bug('a2', 'alpha'),
        bug('b1', 'beta'),
        bug('b2', 'beta'),
      ],
    );
    final c = container(seed);
    final k = await ctrl(seed, c);
    expect((await k.autoSynthesize()).fused, 0);
    expect(c.read(saveControllerProvider).requireValue.bugs.length, 4);
  });

  test('여러 종을 한 번에 처리한다', () async {
    final seed = SaveGame.initial(createdAt: t0).copyWith(
      lastSeen: t0,
      bugs: [
        for (var i = 0; i < 4; i++) bug('a$i', 'alpha'),
        for (var i = 0; i < 4; i++) bug('b$i', 'beta'),
      ],
    );
    final c = container(seed);
    final k = await ctrl(seed, c);
    final r = await k.autoSynthesize();

    expect(r.fused, 2);
    expect(r.used, 6);
    expect(c.read(saveControllerProvider).requireValue.bugs.length, 2);
  });

  test('최대 포텐셜에 닿으면 멈춘다 — 재료를 헛되이 태우지 않는다', () async {
    // 5성 1마리 + 재료 3마리. 더 올릴 수 없으므로 아무것도 소비하지 않는다.
    final seed = SaveGame.initial(createdAt: t0).copyWith(
      lastSeen: t0,
      bugs: [
        bug('maxed', 'alpha', potential: 5),
        bug('r1', 'alpha'),
        bug('r2', 'alpha'),
        bug('r3', 'alpha'),
      ],
    );
    final c = container(seed);
    final k = await ctrl(seed, c);
    final r = await k.autoSynthesize();

    // 5성이 타깃에서 빠지면 남은 raw 3마리 중 하나가 타깃이 되는데,
    // 그러면 재료가 2마리뿐이라 합성이 성립하지 않는다.
    expect(r.fused, 0);
    expect(c.read(saveControllerProvider).requireValue.bugs.length, 4);
  });

  test('dryRun 은 세이브를 건드리지 않는다 — 확인 다이얼로그에 쓰는 값', () async {
    final seed = SaveGame.initial(createdAt: t0).copyWith(
      lastSeen: t0,
      bugs: [for (var i = 0; i < 4; i++) bug('a$i', 'alpha')],
    );
    final c = container(seed);
    final k = await ctrl(seed, c);

    final preview = await k.autoSynthesize(dryRun: true);
    expect(preview.fused, 1);
    expect(preview.used, 3);
    // 아직 아무도 사라지지 않았다.
    expect(c.read(saveControllerProvider).requireValue.bugs.length, 4);

    // 실제로 돌리면 예상과 같은 결과.
    final done = await k.autoSynthesize();
    expect(done.fused, preview.fused);
    expect(done.used, preview.used);
    expect(c.read(saveControllerProvider).requireValue.bugs.length, 1);
  });

  test('등급 필터 설정은 저장되고, 같은 값이면 다시 쓰지 않는다', () async {
    final seed = SaveGame.initial(createdAt: t0).copyWith(lastSeen: t0);
    final c = container(seed);
    final k = await ctrl(seed, c);

    await k.setBugFilterMinGrade(Grade.rare);
    expect(
      c.read(saveControllerProvider).requireValue.bugFilterMinGrade,
      Grade.rare,
    );
    // 같은 값 재설정은 no-op(불필요한 업로드 방지) — 상태가 그대로여야 한다.
    await k.setBugFilterMinGrade(Grade.rare);
    expect(
      c.read(saveControllerProvider).requireValue.bugFilterMinGrade,
      Grade.rare,
    );
  });
}
