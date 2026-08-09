import 'package:core_models/core_models.dart';
import 'package:core_save/core_save.dart';
import 'package:test/test.dart';

void main() {
  final t0 = DateTime.utc(2026, 8, 9, 12);
  SaveGame fresh() => SaveGame.initial(createdAt: t0);

  group('장비·공방·스킬 세이브 필드', () {
    test('스키마 버전은 그대로 18 — 올리면 구버전 앱이 죽는다', () {
      expect(kSaveSchemaVersion, 18);
      expect(fresh().toJson()['schemaVersion'], 18);
    });

    test('필드가 없는 **구버전 세이브**도 기본값으로 읽힌다', () {
      final old = fresh().toJson()
        ..remove('equippedItems')
        ..remove('skillLevels')
        ..remove('equippedSkills')
        ..remove('forgeLevel')
        ..remove('forgeSteps')
        ..remove('forgeUpAt')
        ..remove('autoForgeOptions')
        ..remove('autoForgeStopOnHit');
      final s = SaveGame.fromJson(old);
      expect(s.equippedItems, isEmpty);
      expect(s.skillLevels, isEmpty);
      expect(s.equippedSkills, isEmpty);
      expect(s.forgeLevel, 0);
      expect(s.forgeSteps, 0);
      expect(s.forgeUpAt, isNull);
      expect(s.autoForgeOptions, isEmpty);
      // 기본값이 true 여야 한다 — 아니면 원하는 걸 뽑고도 계속 태운다.
      expect(s.autoForgeStopOnHit, isTrue);
    });

    test('빈 값은 JSON 에 아예 싣지 않는다 — 60초마다 올리는 세이브다', () {
      final json = fresh().toJson();
      expect(json.containsKey('equippedItems'), isFalse);
      expect(json.containsKey('skillLevels'), isFalse);
      expect(json.containsKey('forgeLevel'), isFalse);
      expect(json.containsKey('autoForgeStopOnHit'), isFalse);
    });

    test('장비를 끼면 왕복(toJson→fromJson)해도 그대로다', () {
      final item = EquipItem(
        slot: EquipSlot.tool,
        tier: 7,
        options: const [
          ItemOption(kind: ItemOptionKind.critDamage, value: 62.4),
          ItemOption(kind: ItemOptionKind.bossDamage, value: 31.0),
        ],
      );
      final s = fresh().copyWith(equippedItems: {EquipSlot.tool: item});
      final back = SaveGame.fromJson(s.toJson());
      final got = back.equippedItems[EquipSlot.tool]!;
      expect(got.tier, 7);
      expect(got.options.length, 2);
      expect(got.options.first.kind, ItemOptionKind.critDamage);
      expect(got.options.first.value, 62.4);
    });

    test('부위마다 1개뿐 — 가방이 없어 세이브에 최대 8개만 남는다', () {
      var s = fresh();
      for (final slot in EquipSlot.values) {
        s = s.copyWith(
          equippedItems: {
            ...s.equippedItems,
            slot: EquipItem(slot: slot, tier: 3, options: const []),
          },
        );
      }
      // 같은 부위를 다시 끼면 **교체**된다(쌓이지 않는다).
      s = s.copyWith(
        equippedItems: {
          ...s.equippedItems,
          EquipSlot.tool: EquipItem(
            slot: EquipSlot.tool,
            tier: 9,
            options: const [],
          ),
        },
      );
      expect(s.equippedItems.length, 8);
      expect(s.equippedItems[EquipSlot.tool]!.tier, 9);
    });

    test('공방 진행(칸·완료시각)이 왕복해도 보존된다', () {
      final done = t0.add(const Duration(hours: 5));
      final s = fresh().copyWith(forgeLevel: 7, forgeSteps: 4, forgeUpAt: done);
      final back = SaveGame.fromJson(s.toJson());
      expect(back.forgeLevel, 7);
      expect(back.forgeSteps, 4);
      expect(back.forgeUpAt, done);
    });

    test('등급업이 끝나면 완료시각을 **지울 수 있다**', () {
      final s = fresh().copyWith(forgeUpAt: t0.add(const Duration(hours: 1)));
      final cleared = s.copyWith(forgeLevel: 1, clearForgeUpAt: true);
      expect(cleared.forgeUpAt, isNull);
      expect(SaveGame.fromJson(cleared.toJson()).forgeUpAt, isNull);
    });

    test('스킬 5칸과 자동 제련 설정이 왕복한다', () {
      final s = fresh().copyWith(
        skillLevels: {'crit_strike': 3, 'nocturnal': 1},
        equippedSkills: ['crit_strike', 'nocturnal'],
        autoForgeOptions: {
          ItemOptionKind.critDamage,
          ItemOptionKind.bossDamage,
        },
        autoForgeStopOnHit: false,
      );
      final back = SaveGame.fromJson(s.toJson());
      expect(back.skillLevels['crit_strike'], 3);
      expect(back.equippedSkills, ['crit_strike', 'nocturnal']);
      expect(back.autoForgeOptions, hasLength(2));
      expect(back.autoForgeStopOnHit, isFalse);
    });
  });

  group('화석 조각(제련 전용 재화)', () {
    test('재료로 저장·복원된다', () {
      final s = fresh().copyWith(materials: {MaterialKind.fossil: 1234});
      expect(
        SaveGame.fromJson(s.toJson()).materialCount(MaterialKind.fossil),
        1234,
      );
    });

    test('기존 재료와 통이 다르다 — 강화·연마와 소비처가 겹치지 않는다', () {
      final s = fresh().copyWith(
        materials: {MaterialKind.chitin: 50, MaterialKind.fossil: 10},
      );
      expect(s.materialCount(MaterialKind.chitin), 50);
      expect(s.materialCount(MaterialKind.fossil), 10);
    });
  });
}
