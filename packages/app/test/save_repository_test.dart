import 'dart:convert';
import 'dart:io';

import 'package:app/data/save_repository.dart';
import 'package:app/domain/save_game.dart';
import 'package:core_models/core_models.dart';
import 'package:hive/hive.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  late Box box;
  late HiveSaveRepository repo;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('bugchamp_hive');
    Hive.init(dir.path);
    box = await Hive.openBox('save');
    repo = HiveSaveRepository(box);
  });

  tearDown(() async {
    await Hive.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('빈 저장소 → 초기 세이브 반환', () async {
    final s = await repo.load();
    expect(s.schemaVersion, kSaveSchemaVersion);
    expect(s.bugs, isEmpty);
    expect(s.unlockedFieldIds, {'oak_forest'});
  });

  test('저장 → 로드 왕복 동일', () async {
    final original = SaveGame(
      schemaVersion: kSaveSchemaVersion,
      bugs: const [
        IndividualBug(
          id: 'b1',
          speciesId: 'rhino_japanese',
          sizeMm: 61.2,
          potential: 4,
          temperament: Temperament.aggressive,
          sex: Sex.female,
        ),
      ],
      materials: const {MaterialKind.sap: 7},
      installations: [
        TrapInstallation(
          slotIndex: 1,
          fieldId: 'oak_forest',
          trapId: 'light_trap',
          installedAt: DateTime.utc(2026, 7, 4, 9, 30),
        ),
      ],
      unlockedFieldIds: const {'oak_forest'},
      createdAt: DateTime.utc(2026, 7, 1),
      lastSeen: DateTime.utc(2026, 7, 4),
      gold: 320,
      xp: 12,
      level: 2,
      upgradeLevels: const {},
      stageNumber: 4,
      nickname: '채집가',
      buffExpiry: const {},
      missionProgress: const {},
      missionClaims: const {},
      equippedBugIds: const [],
      dailyClaims: const {},
      gifts: const [],
      clearedChapters: const {},
      incubatorCapacity: 1,
      incubating: const {},
      pvpTrophies: 0,
    );

    await repo.save(original);
    final loaded = await repo.load();
    expect(loaded.toJson(), original.toJson());
  });

  test('손상 데이터 → 초기 세이브로 폴백', () async {
    await box.put('game', 'this is not valid json {{{');
    final s = await repo.load();
    expect(s.schemaVersion, kSaveSchemaVersion);
    expect(s.bugs, isEmpty);
  });

  test('레거시 v0 JSON → 로드 시 마이그레이션되어 v1', () async {
    await box.put('game', jsonEncode({'bugs': const []})); // schemaVersion 없음
    final s = await repo.load();
    expect(s.schemaVersion, kSaveSchemaVersion);
  });

  test('clear 후 초기 세이브', () async {
    await repo.save(SaveGame.initial(createdAt: DateTime.utc(2026, 1, 1)));
    await repo.clear();
    final s = await repo.load();
    expect(s.bugs, isEmpty);
  });
}
