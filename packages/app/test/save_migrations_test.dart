import 'package:app/data/save_migrations.dart';
import 'package:app/domain/save_game.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('migrateToCurrent', () {
    test('v0(스키마 미표기) → v1 로 승격 + 기본 필드 채움', () {
      final migrated = migrateToCurrent({});
      expect(migrated['schemaVersion'], kSaveSchemaVersion);
      expect(migrated['bugs'], isEmpty);
      expect(migrated['unlockedFieldIds'], ['oak_forest']);
      // 마이그레이션 결과가 SaveGame 으로 파싱 가능해야 함
      expect(() => SaveGame.fromJson(migrated), returnsNormally);
    });

    test('v0 의 기존 데이터는 보존', () {
      final migrated = migrateToCurrent({
        'bugs': [
          {
            'id': 'legacy1',
            'speciesId': 'stag_dorcus',
            'sizeMm': 30.0,
            'potential': 2,
            'temperament': 'steadfast',
            'sex': 'female',
          },
        ],
      });
      expect(migrated['schemaVersion'], kSaveSchemaVersion);
      final save = SaveGame.fromJson(migrated);
      expect(save.bugs.single.id, 'legacy1');
    });

    test('이미 현재 버전이면 그대로 통과', () {
      final current = SaveGame.initial(
        createdAt: DateTime.utc(2026, 1, 1),
      ).toJson();
      final migrated = migrateToCurrent(current);
      expect(migrated['schemaVersion'], kSaveSchemaVersion);
    });

    test('앱이 아는 버전보다 높으면 예외(다운그레이드 불가)', () {
      expect(
        () => migrateToCurrent({'schemaVersion': kSaveSchemaVersion + 99}),
        throwsStateError,
      );
    });

    test('v11(PvP) → 현재: 부상(injured) 맵이 기본값으로 채워진다', () {
      final v11 = SaveGame.initial(createdAt: DateTime.utc(2026, 1, 1)).toJson()
        ..['schemaVersion'] = 11
        ..remove('injured');
      final migrated = migrateToCurrent(v11);
      expect(migrated['schemaVersion'], kSaveSchemaVersion);
      expect(migrated['injured'], isEmpty);
      final save = SaveGame.fromJson(migrated);
      expect(save.injured, isEmpty);
    });

    test('v12(부상) → 현재: 승급보상 기록(claimedLeagues)이 기본값으로 채워진다', () {
      final v12 = SaveGame.initial(createdAt: DateTime.utc(2026, 1, 1)).toJson()
        ..['schemaVersion'] = 12
        ..remove('claimedLeagues');
      final migrated = migrateToCurrent(v12);
      expect(migrated['schemaVersion'], kSaveSchemaVersion);
      expect(migrated['claimedLeagues'], isEmpty);
      final save = SaveGame.fromJson(migrated);
      expect(save.claimedLeagues, isEmpty);
    });

    test('v13(리그) → 현재: 시즌 필드 추가 & seasonStartedAt은 로드 시 null', () {
      final v13 = SaveGame.initial(createdAt: DateTime.utc(2026, 1, 1)).toJson()
        ..['schemaVersion'] = 13
        ..remove('seasonStartedAt')
        ..remove('seasonPeakTrophies');
      final migrated = migrateToCurrent(v13);
      expect(migrated['schemaVersion'], kSaveSchemaVersion);
      expect(migrated['seasonPeakTrophies'], 0);
      final save = SaveGame.fromJson(migrated);
      expect(save.seasonStartedAt, isNull); // 로드 시 컨트롤러가 now로 초기화
      expect(save.seasonPeakTrophies, 0);
    });

    test('v14(시즌) → 현재: 브리딩 슬롯·용량이 기본값으로 채워진다', () {
      final v14 = SaveGame.initial(createdAt: DateTime.utc(2026, 1, 1)).toJson()
        ..['schemaVersion'] = 14
        ..remove('breeding')
        ..remove('breedingCapacity');
      final migrated = migrateToCurrent(v14);
      expect(migrated['schemaVersion'], kSaveSchemaVersion);
      expect(migrated['breeding'], isEmpty);
      expect(migrated['breedingCapacity'], 1);
      final save = SaveGame.fromJson(migrated);
      expect(save.breeding, isEmpty);
      expect(save.breedingCapacity, 1);
    });

    test('v15(브리딩) → 현재: 인앱결제 상태가 미구매 기본값으로 채워진다', () {
      final v15 = SaveGame.initial(createdAt: DateTime.utc(2026, 1, 1)).toJson()
        ..['schemaVersion'] = 15
        ..remove('adsRemoved')
        ..remove('starterBought')
        ..remove('ownedSkins')
        ..remove('passExpiresAt');
      final migrated = migrateToCurrent(v15);
      expect(migrated['schemaVersion'], kSaveSchemaVersion);
      final save = SaveGame.fromJson(migrated);
      expect(save.adsRemoved, isFalse);
      expect(save.starterBought, isFalse);
      expect(save.ownedSkins, isEmpty);
      expect(save.passExpiresAt, isNull);
      // 미구매 상태에선 패스 비활성 · 광고 노출.
      final now = DateTime.utc(2026, 1, 2);
      expect(save.passActive(now), isFalse);
      expect(save.adsHidden(now), isFalse);
    });

    test('v16(로컬 결제) → 현재: 구매 원장이 빈 목록으로 채워진다', () {
      final v16 = SaveGame.initial(createdAt: DateTime.utc(2026, 1, 1)).toJson()
        ..['schemaVersion'] = 16
        ..remove('redeemedPurchases');
      final migrated = migrateToCurrent(v16);
      expect(migrated['schemaVersion'], kSaveSchemaVersion);
      final save = SaveGame.fromJson(migrated);
      expect(save.redeemedPurchases, isEmpty);
      // 기존 구매 상태는 그대로 살아남아야 한다(원장 추가가 지우지 않음).
      expect(save.adsRemoved, isFalse);
    });

    test('v17(결제 원장) → 현재: 차단 목록이 빈 집합으로 채워진다', () {
      final v17 = SaveGame.initial(createdAt: DateTime.utc(2026, 1, 1)).toJson()
        ..['schemaVersion'] = 17
        ..remove('blockedUserIds');
      final migrated = migrateToCurrent(v17);
      expect(migrated['schemaVersion'], kSaveSchemaVersion);
      final save = SaveGame.fromJson(migrated);
      expect(save.blockedUserIds, isEmpty);
      expect(save.isBlocked('아무나'), isFalse);
    });

    test('차단 목록은 직렬화 왕복으로 보존된다', () {
      final s = SaveGame.initial(
        createdAt: DateTime.utc(2026, 1, 1),
      ).copyWith(blockedUserIds: {'u-1', 'u-2'});
      final back = SaveGame.fromJson(s.toJson());
      expect(back.blockedUserIds, {'u-1', 'u-2'});
      expect(back.isBlocked('u-1'), isTrue);
      expect(back.isBlocked('u-3'), isFalse);
    });

    test('구매 상태는 직렬화 왕복으로 보존된다', () {
      final expiry = DateTime.utc(2026, 3, 1);
      final bought = SaveGame.initial(createdAt: DateTime.utc(2026, 1, 1))
          .copyWith(
            adsRemoved: true,
            starterBought: true,
            ownedSkins: {'gold_rhino'},
            passExpiresAt: expiry,
          );
      final back = SaveGame.fromJson(bought.toJson());
      expect(back.adsRemoved, isTrue);
      expect(back.starterBought, isTrue);
      expect(back.ownedSkins, {'gold_rhino'});
      expect(back.passExpiresAt, expiry);
      expect(back.passActive(DateTime.utc(2026, 2, 1)), isTrue);
      expect(back.passActive(DateTime.utc(2026, 4, 1)), isFalse);
      expect(back.adsHidden(DateTime.utc(2026, 4, 1)), isTrue); // 광고제거는 영구
    });
  });
}
