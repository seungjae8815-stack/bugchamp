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
  });
}
