import 'dart:math';

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:test/test.dart';

// 개체 등급 개편(2026-10-11, docs/design_individual_grade.md) — 정수·등급 올리기·물약.
void main() {
  const cfg = IndividualGradeConfig(
    enabled: true,
    essenceRarity: {Grade.common: 1, Grade.legendary: 28},
  );
  const common = Species(
    id: 'stag_c',
    name: LocalizedText(ko: '일반종', en: 'c', ja: 'c'),
    grade: Grade.common,
    specialty: Specialty.grip,
    baseStats: Stats(hp: 100, atk: 30, def: 30, spd: 20),
    sizeMinMm: 20,
    sizeMaxMm: 60,
  );
  const legend = Species(
    id: 'longhorn_l',
    name: LocalizedText(ko: '전설종', en: 'l', ja: 'l'),
    grade: Grade.legendary,
    specialty: Specialty.grip,
    baseStats: Stats(hp: 200, atk: 90, def: 80, spd: 50),
    sizeMinMm: 60,
    sizeMaxMm: 120,
  );
  final byId = {common.id: common, legend.id: legend};

  IndividualBug b(
    String id, {
    String sp = 'stag_c',
    int pot = 1,
    LifeStage stage = LifeStage.adult,
    bool gacha = false,
  }) => IndividualBug(
    id: id,
    speciesId: sp,
    sizeMm: 40,
    potential: pot,
    temperament: Temperament.cunning,
    sex: Sex.male,
    stage: stage,
    fromGacha: gacha,
  );

  SaveGame save(List<IndividualBug> bugs) =>
      SaveGame.initial().copyWith(bugs: bugs);

  group('정수로 바꾸기', () {
    test('애벌레·성충만 — 알은 남는다 · 등급 누적 × 종 희귀도', () {
      final s = save([
        b('egg', stage: LifeStage.egg),
        b('lv', stage: LifeStage.larva),
        b('ad2', pot: 2),
        b('leg', sp: 'longhorn_l'),
        b('gacha', sp: 'longhorn_l', gacha: true),
      ]);
      final r = convertToEssence(
        s,
        ['egg', 'lv', 'ad2', 'leg', 'gacha'],
        cfg,
        byId,
      );
      expect(r.isOk, isTrue);
      expect(r.save!.bugs.map((x) => x.id), ['egg']);
      expect(r.save!.essence['stag_c'], 1 + 6);
      expect(r.save!.essence['longhorn_l'], 28 + 1, reason: '뽑기 출신은 희귀도 가치 없음');
      expect(r.extra['skippedEggs'], 1);
    });

    test('보호 곤충(잠금)은 바꾸지 않는다', () {
      final s = save([b('a'), b('locked')]).copyWith(lockedBugIds: {'locked'});
      final r = convertToEssence(s, ['a', 'locked'], cfg, byId);
      expect(r.save!.bugs.map((x) => x.id), ['locked']);
      expect(r.extra['skippedPinned'], 1);
    });

    test('알만 고르면 실패 — 사유 egg', () {
      final r = convertToEssence(
        save([b('e', stage: LifeStage.egg)]),
        ['e'],
        cfg,
        byId,
      );
      expect(r.error, 'egg');
    });
  });

  group('등급 올리기', () {
    test('정수 소모 · 포텐셜+1 · 합성 단계+1(태생 등급 유지) · 롤은 내려가지 않는다', () {
      final s = save([b('k')]).copyWith(essence: {'stag_c': 7});
      final before = s.bugs.first.statRolls;
      final r = gradeUp(s, 'k', cfg, byId, Random(1));
      expect(r.isOk, isTrue);
      final up = r.save!.bugs.first;
      expect(up.potential, 2);
      expect(up.bornPotential, 1, reason: '분해 젤리는 태생 등급으로');
      expect(r.save!.essence['stag_c'], 2);
      for (var i = 0; i < before.length; i++) {
        expect(up.statRolls[i], greaterThanOrEqualTo(before[i]));
      }
    });

    test('정수 부족 · 알 · 전설 · 물약 부족은 실패', () {
      expect(
        gradeUp(save([b('k')]), 'k', cfg, byId, Random(1)).error,
        'no_essence',
      );
      expect(
        gradeUp(
          save([
            b('e', stage: LifeStage.egg),
          ]).copyWith(essence: {'stag_c': 99}),
          'e',
          cfg,
          byId,
          Random(1),
        ).error,
        'egg',
      );
      expect(
        gradeUp(
          save([b('m', pot: 5)]).copyWith(essence: {'stag_c': 9999}),
          'm',
          cfg,
          byId,
          Random(1),
        ).error,
        'max',
      );
      expect(
        gradeUp(
          save([b('k')]).copyWith(essence: {'stag_c': 99}),
          'k',
          cfg,
          byId,
          Random(1),
          potions: 2,
        ).error,
        'no_potion',
      );
    });

    test('물약은 소모되고 롤 바닥을 올린다', () {
      final s = save([
        b('k').copyWith(rolls: const [0, 0, 0, 0, 0, 0, 0, 0]),
      ]).copyWith(essence: {'stag_c': 5}, growthPotions: 3);
      final r = gradeUp(s, 'k', cfg, byId, Random(2), potions: 3);
      expect(r.save!.growthPotions, 0);
      expect(r.save!.bugs.first.statRolls.every((v) => v >= 15), isTrue);
    });
  });

  group('성장물약 구매', () {
    SaveGame rich() =>
        SaveGame.initial().copyWith(materials: {MaterialKind.jelly: 500});

    test('젤리 10개에 1개 · 하루 10개까지 · 날이 바뀌면 다시', () {
      var s = rich();
      final r1 = buyPotions(s, 7, cfg, '2026-10-12');
      expect(r1.save!.growthPotions, 7);
      expect(r1.save!.materialCount(MaterialKind.jelly), 430);
      s = r1.save!;
      expect(buyPotions(s, 4, cfg, '2026-10-12').error, 'daily_limit');
      expect(buyPotions(s, 3, cfg, '2026-10-12').isOk, isTrue);
      expect(buyPotions(s, 10, cfg, '2026-10-13').isOk, isTrue);
    });

    test('젤리 부족은 실패', () {
      expect(buyPotions(SaveGame.initial(), 1, cfg, 'd').error, 'no_jelly');
    });
  });

  test('세이브 저장 — 정수·물약·구매 기록이 돌아온다, 비면 키 없음', () {
    final s = SaveGame.initial().copyWith(
      essence: {'stag_c': 12},
      growthPotions: 4,
      potionBuyDay: '2026-10-12',
      potionBuyCount: 2,
    );
    final back = SaveGame.fromJson(s.toJson());
    expect(back.essence, {'stag_c': 12});
    expect(back.growthPotions, 4);
    expect(back.potionBuyDay, '2026-10-12');
    expect(back.potionBuyCount, 2);
    final empty = SaveGame.initial().toJson();
    expect(empty.containsKey('essence'), isFalse);
    expect(empty.containsKey('potions'), isFalse);
  });
}
