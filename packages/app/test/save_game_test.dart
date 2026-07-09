import 'package:app/domain/save_game.dart';
import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:flutter_test/flutter_test.dart';

SaveGame _sampleSave() => SaveGame(
  schemaVersion: kSaveSchemaVersion,
  bugs: const [
    IndividualBug(
      id: 'x1',
      speciesId: 'stag_dorcus',
      sizeMm: 42.5,
      potential: 3,
      temperament: Temperament.cunning,
      sex: Sex.male,
      enhancement: PartLevels(hornJaw: 2, wing: 1),
    ),
  ],
  materials: const {MaterialKind.chitin: 5, MaterialKind.jelly: 2},
  installations: [
    TrapInstallation(
      slotIndex: 0,
      fieldId: 'oak_forest',
      trapId: 'sap_trap',
      installedAt: DateTime.utc(2026, 7, 1, 12),
    ),
  ],
  unlockedFieldIds: const {'oak_forest', 'valley_stream'},
  createdAt: DateTime.utc(2026, 6, 30),
  lastSeen: DateTime.utc(2026, 7, 5),
  gold: 1250,
  xp: 40,
  level: 5,
  upgradeLevels: const {UpgradeKind.attack: 8, UpgradeKind.reward: 3},
  stageNumber: 12,
  nickname: '테스트챔프',
  buffExpiry: {BuffKind.goldRush: DateTime.utc(2026, 7, 5, 13)},
  missionProgress: const {'hunt': 12},
  missionClaims: const {'hunt': 2},
  equippedBugIds: const ['x1'],
  dailyClaims: const {'lunch': '2026-07-05'},
  gifts: const [],
  clearedChapters: const {'easy'},
  incubatorCapacity: 2,
  incubating: const {},
  pvpTrophies: 30,
);

void main() {
  group('SaveGame.initial', () {
    test('현재 스키마 버전 + 시작 필드만 해금 + 빈 상태', () {
      final s = SaveGame.initial(createdAt: DateTime.utc(2026, 1, 1));
      expect(s.schemaVersion, kSaveSchemaVersion);
      expect(s.bugs, isEmpty);
      expect(s.materials, isEmpty);
      expect(s.installations, isEmpty);
      expect(s.unlockedFieldIds, {'oak_forest'});
      expect(s.gold, 0);
      expect(s.level, 1);
      expect(s.stageNumber, 1);
      expect(s.upgradeLevels, isEmpty);
    });
  });

  group('직렬화 왕복', () {
    test('toJson → fromJson 이 완전 동일', () {
      final s = _sampleSave();
      final restored = SaveGame.fromJson(s.toJson());
      expect(restored.toJson(), s.toJson());
    });

    test('개체/재료/설치/해금 필드 보존', () {
      final restored = SaveGame.fromJson(_sampleSave().toJson());
      expect(restored.bugs.single.id, 'x1');
      expect(restored.bugs.single.enhancement.hornJaw, 2);
      expect(restored.materialCount(MaterialKind.chitin), 5);
      expect(restored.installationAt(0)!.trapId, 'sap_trap');
      expect(restored.unlockedFieldIds, {'oak_forest', 'valley_stream'});
      expect(restored.gold, 1250);
      expect(restored.level, 5);
      expect(restored.stageNumber, 12);
      expect(restored.upgradeLevel(UpgradeKind.attack), 8);
    });
  });

  group('헬퍼', () {
    test('materialCount 는 없는 재료에 0', () {
      expect(_sampleSave().materialCount(MaterialKind.mineral), 0);
    });

    test('installationAt 은 빈 슬롯에 null', () {
      expect(_sampleSave().installationAt(2), isNull);
    });
  });
}
