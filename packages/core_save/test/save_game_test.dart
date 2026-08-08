import 'package:core_save/core_save.dart';
import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:test/test.dart';

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
  injured: const {},
  claimedLeagues: const {'bronze'},
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

  group('결투 티켓 필드(호환 필드 — 스키마 버전 안 올림)', () {
    test('티켓 필드가 없는 예전 세이브는 만땅으로 읽힌다', () {
      final old = _sampleSave().toJson()
        ..remove('pvpTickets')
        ..remove('ticketsAt')
        ..remove('adUseCounts')
        ..remove('adUseDate');
      final restored = SaveGame.fromJson(old);
      expect(restored.pvpTickets, kDefaultPvpTickets);
      expect(restored.ticketsAt, isNull);
      expect(restored.adUseCounts, isEmpty);
    });

    test('티켓 상태가 왕복 저장된다', () {
      final at = DateTime.utc(2026, 8, 6, 3);
      final save = _sampleSave().copyWith(
        pvpTickets: 4,
        ticketsAt: at,
        adUseCounts: {kAdFeaturePvpTicket: 7},
        adUseDate: '2026-08-06',
      );
      final restored = SaveGame.fromJson(save.toJson());
      expect(restored.pvpTickets, 4);
      expect(restored.ticketsAt, at);
      expect(restored.adUseCount(kAdFeaturePvpTicket, '2026-08-06'), 7);
      // 날짜가 다르면 0 — 자정을 넘기면 자동 리셋된다.
      expect(restored.adUseCount(kAdFeaturePvpTicket, '2026-08-07'), 0);
    });

    test('새 필드가 붙어도 스키마 버전은 그대로(구버전 앱이 읽을 수 있게)', () {
      expect(_sampleSave().toJson()['schemaVersion'], kSaveSchemaVersion);
      expect(kSaveSchemaVersion, 18);
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
