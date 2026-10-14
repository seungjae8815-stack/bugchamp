import 'dart:convert';
import 'dart:io';
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
    bool newGen = true,
    int su = 0,
  }) => IndividualBug(
    id: id,
    speciesId: sp,
    sizeMm: 40,
    potential: pot,
    temperament: Temperament.cunning,
    sex: Sex.male,
    stage: stage,
    fromGacha: gacha,
    newGen: newGen,
    synthUps: su,
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

    test('물약은 소모되고 새 롤에 +3점씩 더한다', () {
      final s = save([
        b('k').copyWith(rolls: const [0, 0, 0, 0, 0, 0, 0, 0]),
      ]).copyWith(essence: {'stag_c': 5}, growthPotions: 3);
      final r = gradeUp(s, 'k', cfg, byId, Random(2), potions: 3);
      expect(r.save!.growthPotions, 0);
      expect(r.save!.bugs.first.statRolls.every((v) => v >= 9), isTrue);
    });

    test('업데이트 전 곤충 — 처음 올릴 때 옛 합성 단계를 적는다(한 번만)', () {
      final s = save([
        b('old', pot: 3, su: 2, newGen: false),
      ]).copyWith(essence: {'stag_c': 9999});
      final r1 = gradeUp(s, 'old', cfg, byId, Random(1));
      expect(r1.save!.bugs.first.legacySynthUps, 2);
      expect(r1.save!.bugs.first.synthUps, 3);
      final r2 = gradeUp(r1.save!, 'old', cfg, byId, Random(1));
      expect(r2.save!.bugs.first.legacySynthUps, 2, reason: '처음 적은 값 고정');
      // 새 곤충은 적지 않는다.
      final n = gradeUp(
        save([b('new')]).copyWith(essence: {'stag_c': 99}),
        'new',
        cfg,
        byId,
        Random(1),
      );
      expect(n.save!.bugs.first.legacySynthUps, isNull);
    });

    test('불변식 — 올리기·바꾸기를 반복해도 정수가 늘지 않는다(업데이트 전·후 곤충)', () {
      for (final sp in ['stag_c', 'longhorn_l']) {
        for (final start in [
          b('x', sp: sp, pot: 1),
          b('x', sp: sp, pot: 2, gacha: true),
          b('x', sp: sp, pot: 5, su: 4, newGen: false),
          b('x', sp: sp, pot: 2, su: 1, newGen: false),
          b('x', sp: sp, pot: 3, newGen: false),
          b('x', sp: sp, pot: 1, newGen: false),
        ]) {
          // 곤충 하나 + 정수 넉넉히 — 올리기 → 바꾸기 → 그 정수로 같은 곤충을 다시 만들 수는 없으니,
          // "올린 뒤 바꾼 정수 == 올리기 전 바꾼 정수 + 들인 정수" 로 잰다.
          var s0 = save([start]).copyWith(essence: {sp: 100000});
          while (s0.bugs.first.potential < 5) {
            final conv0 = convertToEssence(s0, ['x'], cfg, byId);
            final gainBefore = conv0.save!.essence[sp]! - s0.essence[sp]!;
            final up = gradeUp(s0, 'x', cfg, byId, Random(3));
            final cost = up.extra['cost'] as int;
            final conv1 = convertToEssence(up.save!, ['x'], cfg, byId);
            final gainAfter = conv1.save!.essence[sp]! - up.save!.essence[sp]!;
            expect(
              gainAfter,
              gainBefore + cost,
              reason:
                  '$sp ${start.potential}/${start.synthUps}/ng=${start.newGen}',
            );
            expect(
              conv1.save!.essence[sp],
              conv0.save!.essence[sp],
              reason: '올리고 바꾸나 바로 바꾸나 정수가 같다',
            );
            s0 = up.save!;
          }
        }
      }
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

    test('기록보다 이른 날짜는 거절(시계를 되돌려 하루 상한을 다시 채우지 못하게)', () {
      final s = buyPotions(rich(), 10, cfg, '2026-10-12').save!;
      expect(buyPotions(s, 1, cfg, '2026-10-11').error, 'daily_limit');
      expect(buyPotions(s, 1, cfg, '2026-10-13').isOk, isTrue);
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
    final g2 = SaveGame.fromJson(
      SaveGame.initial()
          .copyWith(
            gachaLegendPity: 7,
            potionSrvDay: '2026-10-12',
            potionSrvBought: 3,
            potionSrvDrops: 1,
          )
          .toJson(),
    );
    expect(g2.gachaLegendPity, 7);
    expect(g2.potionSrvDay, '2026-10-12');
    expect(g2.potionSrvBought, 3);
    expect(g2.potionSrvDrops, 1);
    final empty = SaveGame.initial().toJson();
    expect(empty.containsKey('gLp'), isFalse);
    expect(empty.containsKey('psD'), isFalse);
    expect(empty.containsKey('essence'), isFalse);
    expect(empty.containsKey('potions'), isFalse);
  });

  group('짝짓기 자식(켠 상태)', () {
    final raw =
        jsonDecode(File('../app/assets/data/pets.json').readAsStringSync())
            as Map<String, dynamic>;
    final pets = PetConfig.fromJson(raw);
    BreedingSlot slot(int seed) => BreedingSlot.from(
      id: 's$seed',
      mother: b('m', pot: 5).copyWith(sex: Sex.female),
      father: b('f', pot: 5),
      endsAt: DateTime.utc(2026),
      seed: seed,
    );

    test('부모가 전설이어도 자식 등급은 야생 확률 · 켜진 뒤 생긴 표식', () {
      final c = List.filled(6, 0);
      for (var i = 0; i < 4000; i++) {
        final kid = slot(i).hatch(id: 'k$i', species: common, cfg: pets);
        expect(kid.newGen, isTrue);
        expect(kid.stage, LifeStage.egg);
        c[kid.potential]++;
      }
      expect(c[5], 0, reason: '야생 전설 0');
      expect(c[1] / 4000, closeTo(0.80, 0.03));
    });

    test('꺼져 있으면 옛 규칙(부모 등급 상속) · 표식 없음', () {
      final off = PetConfig.fromJson({
        ...raw,
        'individualGrade': {
          ...(raw['individualGrade'] as Map<String, dynamic>),
          'enabled': false,
        },
      });
      final kid = slot(1).hatch(id: 'k', species: common, cfg: off);
      expect(kid.newGen, isFalse);
      expect(kid.potential, greaterThanOrEqualTo(4));
    });
  });

  group('확률 물약 하루 한도(2026-10-14) — 서버와 같은 potionDropDaily 에서 조용히 멈춘다', () {
    final t = DateTime.utc(2026, 10, 14, 3);
    final day = dailyDateKey(t);
    test('한도까지 주고 그 뒤로는 0개 · 기록은 서버가 합칠 수 있는 꼴', () {
      var s = SaveGame.initial(createdAt: t);
      final rng = _AlwaysZero();
      var total = 0;
      for (var i = 0; i < cfg.potionDropDaily + 5; i++) {
        final r = rollPotionDrop(s, cfg, rng, PotionSource.elite, now: t);
        s = r.save;
        total += r.got;
      }
      expect(total, cfg.potionDropDaily);
      expect(s.growthPotions, cfg.potionDropDaily);
      expect(potionDropsOn(s, day), cfg.potionDropDaily);
      expect(
        s.dailyClaims[kPotionDropKey],
        '$day:${cfg.potionDropDaily.toString().padLeft(2, '0')}',
      );
      // 다음 서버 날짜에는 다시 받는다.
      final next = rollPotionDrop(
        s,
        cfg,
        rng,
        PotionSource.boss,
        now: t.add(const Duration(days: 1)),
      );
      expect(next.got, 1);
    });
    test('보스 첫 처치는 한도에 세지 않는다', () {
      var s = SaveGame.initial(createdAt: t);
      final rng = _AlwaysZero();
      for (var i = 0; i < cfg.potionDropDaily; i++) {
        s = rollPotionDrop(s, cfg, rng, PotionSource.elite, now: t).save;
      }
      final first = rollPotionDrop(
        s,
        cfg,
        rng,
        PotionSource.boss,
        firstKill: true,
        now: t,
      );
      expect(first.got, cfg.potionBossFirst);
    });
  });
}

class _AlwaysZero implements Random {
  @override
  double nextDouble() => 0;
  @override
  int nextInt(int max) => 0;
  @override
  bool nextBool() => false;
}
