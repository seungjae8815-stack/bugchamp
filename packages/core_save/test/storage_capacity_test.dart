import 'package:core_save/core_save.dart';
import 'package:test/test.dart';

/// 채집함 상한(§2.1) — 세이브가 무한히 커지는 것을 막는 유일한 방어선이라
/// 마이그레이션 정리·상한 강제·보호 규칙을 모두 고정해 둔다.
///
/// 2026-07 장애: 상한이 없어 곤충 3만 마리(세이브 13.6MB)가 쌓였고, 10초마다
/// 그 세이브를 통째로 업로드해 서버 인스턴스 시간과 DB 가 모두 타임아웃했다.
void main() {
  Map<String, dynamic> bug(
    String id, {
    int level = 1,
    int tier = 0,
    int potential = 1,
    double size = 30.0,
  }) => {
    'id': id,
    'speciesId': 'stag_dorcus',
    'sizeMm': size,
    'potential': potential,
    'temperament': 'steadfast',
    'sex': 'female',
    'level': level,
    'breakthroughTier': tier,
  };

  /// 상한 도입 전에 저장된 세이브 원형(곤충이 무제한 쌓인 상태).
  Map<String, dynamic> legacy({
    required List<Map<String, dynamic>> bugs,
    List<String> equipped = const [],
    Map<String, dynamic> incubating = const {},
  }) => {
    'schemaVersion': kSaveSchemaVersion,
    'bugs': bugs,
    'materials': <String, dynamic>{},
    'installations': <dynamic>[],
    'unlockedFieldIds': ['oak_forest'],
    'createdAt': '2026-01-01T00:00:00.000Z',
    'lastSeen': '2026-01-01T00:00:00.000Z',
    'gold': 0,
    'xp': 0,
    'level': 1,
    'upgradeLevels': <String, dynamic>{},
    'stageNumber': 1,
    'equippedBugIds': equipped,
    'incubating': incubating,
  };

  /// 세이브를 로드해 앱과 같은 정리 단계를 태운다(SaveController.build 상당).
  SaveGame load(Map<String, dynamic> raw) =>
      SaveGame.fromJson(migrateToCurrent(raw)).trimmedToStorage();

  group('레거시 세이브 정리(trimmedToStorage)', () {
    test('상한 이하면 곤충을 그대로 둔다', () {
      final save = load(
        legacy(bugs: [for (var i = 0; i < 10; i++) bug('b$i')]),
      );
      expect(save.bugs, hasLength(10));
      expect(save.storageCapacity, kDefaultStorageCapacity);
    });

    test('상한 초과분을 잘라낸다 — 이게 13.6MB 세이브를 정상 크기로 되돌린다', () {
      final save = load(
        legacy(bugs: [for (var i = 0; i < 3000; i++) bug('b$i')]),
      );
      expect(save.bugs, hasLength(kDefaultStorageCapacity));
    });

    test('스키마 버전을 올리지 않는다 — 구버전 앱이 서버 세이브를 계속 읽어야 한다', () {
      // 버전을 올리면 서버가 새 버전 세이브를 저장하는 순간, 스토어에 배포된
      // 구버전 앱이 migrateToCurrent 에서 "다운그레이드 불가"로 죽는다.
      final withCap = load(
        legacy(bugs: [for (var i = 0; i < 300; i++) bug('b$i')]),
      ).toJson();
      expect(withCap['schemaVersion'], 18);
      // 구버전 앱이 모르는 필드가 섞여도 파싱은 그대로 된다(무시).
      expect(() => SaveGame.fromJson(withCap), returnsNormally);
      // 반대로 storageCapacity 가 없는(구버전이 올린) 세이브도 기본값으로 읽힌다.
      final withoutCap = Map<String, dynamic>.from(withCap)
        ..remove('storageCapacity');
      expect(
        SaveGame.fromJson(withoutCap).storageCapacity,
        kDefaultStorageCapacity,
      );
    });

    test('투자한 개체(수련레벨 > 돌파 > 포텐셜 > 사이즈)를 먼저 남긴다', () {
      final save = load(
        legacy(
          bugs: [
            for (var i = 0; i < 200; i++) bug('junk$i'),
            bug('trained', level: 30),
            bug('breakthrough', tier: 3),
            bug('potent', potential: 5),
            bug('big', size: 99.0),
          ],
        ),
      );
      final ids = save.bugs.map((b) => b.id).toSet();
      expect(ids, containsAll(['trained', 'breakthrough', 'potent', 'big']));
    });

    test('장착·부화 중인 곤충은 스탯이 낮아도 잘리지 않는다', () {
      final save = load(
        legacy(
          bugs: [
            bug('equipped'),
            bug('incubating'),
            // 나머지는 전부 더 좋은 개체 — 보호가 없으면 이 둘이 먼저 잘린다.
            for (var i = 0; i < 500; i++) bug('rich$i', level: 50),
          ],
          equipped: ['equipped'],
          incubating: {'incubating': '2026-01-02T00:00:00.000Z'},
        ),
      );
      final ids = save.bugs.map((b) => b.id).toSet();
      expect(ids, contains('equipped'));
      expect(ids, contains('incubating'));
      expect(save.bugs, hasLength(kDefaultStorageCapacity));
      // 장착 참조가 살아 있어야 한다 — 끊기면 펫 보너스가 사라진다.
      expect(save.equippedBugIds.every(ids.contains), isTrue);
    });

    test('정리 후에도 원래 보관 순서를 유지한다', () {
      final save = load(
        legacy(
          bugs: [for (var i = 0; i < 300; i++) bug('b$i', potential: i % 5)],
        ),
      );
      expect(save.bugs, hasLength(kDefaultStorageCapacity)); // 실제로 잘렸는지
      final kept = save.bugs.map((b) => b.id).toList();
      final sorted = [...kept]
        ..sort(
          (a, b) =>
              int.parse(a.substring(1)).compareTo(int.parse(b.substring(1))),
        );
      expect(kept, sorted);
    });

    test('같은 입력이면 같은 결과 — 정리는 결정론적이다', () {
      final raw = legacy(bugs: [for (var i = 0; i < 400; i++) bug('b$i')]);
      final a = load(raw).bugs.map((b) => b.id).toList();
      final b = load(raw).bugs.map((b) => b.id).toList();
      expect(a, hasLength(kDefaultStorageCapacity));
      expect(a, orderedEquals(b));
    });
  });

  group('SaveGame 채집함 헬퍼', () {
    SaveGame withBugs(int n, {int? capacity}) {
      final base = SaveGame.fromJson(
        migrateToCurrent(
          legacy(bugs: [for (var i = 0; i < 10; i++) bug('b$i')]),
        ),
      );
      return base.copyWith(
        bugs: [for (var i = 0; i < n; i++) base.bugs.first.copyWith(id: 'x$i')],
        storageCapacity: capacity,
      );
    }

    test('storageFull / storageFree', () {
      expect(withBugs(10, capacity: 50).storageFull, isFalse);
      expect(withBugs(10, capacity: 50).storageFree, 40);
      expect(withBugs(50, capacity: 50).storageFull, isTrue);
      expect(withBugs(50, capacity: 50).storageFree, 0);
      // 상한을 낮춘 직후 등 초과 상태여도 음수가 나오지 않아야 한다.
      expect(withBugs(80, capacity: 50).storageFree, 0);
    });

    test('trimmedToStorage 는 상한 이하로 자르고, 이하면 그대로 둔다', () {
      expect(withBugs(80, capacity: 50).trimmedToStorage().bugs, hasLength(50));
      final small = withBugs(10, capacity: 50);
      expect(identical(small.trimmedToStorage(), small), isTrue);
    });

    test('보호 대상이 상한보다 많으면 보호분만 남긴다(상한을 낮췄을 때)', () {
      final base = withBugs(10, capacity: 2);
      final pinned = base.copyWith(equippedBugIds: ['x0', 'x1', 'x2', 'x3']);
      final trimmed = pinned.trimmedToStorage();
      expect(
        trimmed.bugs.map((b) => b.id),
        unorderedEquals(['x0', 'x1', 'x2', 'x3']),
      );
    });
  });
}
