import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:test/test.dart';

/// 훈련 v2(2026-10-08, docs/design_training_v2.md) — 포인트 배분 · 다시 찍기 · 결투석 · 이전.
void main() {
  Map<String, dynamic> read(String f) =>
      jsonDecode(File('../app/assets/data/$f').readAsStringSync())
          as Map<String, dynamic>;
  final cfg = BattleConfig.fromJson(read('battle.json')).training;
  final enhance = EnhanceConfig.fromJson(read('enhance.json'));
  final pet = PetConfig.fromJson(read('pets.json'));
  const sp = Species(
    id: 'stag_dorcus',
    name: LocalizedText(ko: '사슴벌레', en: 'Stag', ja: 'クワガタ'),
    grade: Grade.common,
    specialty: Specialty.strike,
    baseStats: Stats(hp: 100, atk: 40, def: 30, spd: 20),
    sizeMinMm: 30,
    sizeMaxMm: 75,
  );
  Species? speciesOf(String id) => id == sp.id ? sp : null;
  IndividualBug bug({
    String id = 'b1',
    Temperament t = Temperament.aggressive,
    BugTrait trait = BugTrait.none,
    int potential = 5,
    int level = 1,
    int tier = 0,
    PartLevels enhancement = PartLevels.zero,
  }) => IndividualBug(
    id: id,
    speciesId: sp.id,
    sizeMm: 50,
    potential: potential,
    temperament: t,
    sex: Sex.male,
    element: Element.fire,
    trait: trait,
    level: level,
    breakthroughTier: tier,
    enhancement: enhancement,
  );
  final t0 = DateTime.utc(2026, 10, 8);
  SaveGame rich(List<IndividualBug> bugs) =>
      SaveGame.initial(createdAt: t0).copyWith(
        bugs: bugs,
        materials: {
          MaterialKind.chitin: 1 << 30,
          MaterialKind.mineral: 1 << 30,
          MaterialKind.sap: 1 << 30,
          MaterialKind.jelly: 10000,
        },
      );

  group('포인트 예산 · 칸 상한', () {
    test('5성 · 80레벨 · 돌파 4 = 102 (30 + 16 + 56)', () {
      final b = bug(potential: 5, level: 80, tier: 4);
      expect(trainBaseBudget(b, cfg), 102);
      expect(trainBaseBudget(bug(potential: 1), cfg), 6);
      // 돌파 단계는 누적: 1단 6 · 2단 16 · 3단 32
      expect(trainBaseBudget(bug(potential: 1, tier: 3), cfg), 6 + 32);
      // 서버는 수련 레벨을 돌파 상한으로 자른다(위조 레벨 999 → 10).
      final forged = bug(potential: 1, level: 999);
      expect(trainBaseBudget(forged, cfg, levelCap: pet.levelCap(0)), 6 + 2);
    });

    test('칸 상한 = 기본 + 기질·주특기·특성(v1 보정 × 3)', () {
      final s = rich([]);
      final st = bug(t: Temperament.steadfast);
      expect(trainSlotCapOf(s, st, sp, TrainSlot.defense, cfg), 30 + 12);
      expect(trainSlotCapOf(s, st, sp, TrainSlot.evade, cfg), 20 - 6);
      // 호전적 + 치기 + 맹렬 = 공격 30 + 9 + 3 + 6
      final ag = bug(trait: BugTrait.fierce);
      expect(trainSlotCapOf(s, ag, sp, TrainSlot.attack, cfg), 48);
      expect(trainSlotCapOf(s, ag, sp, TrainSlot.mass, cfg), 10);
    });

    test('칸 상한 합 ≫ 포인트 — 다 못 찍는다(고르게 만든다)', () {
      final s = rich([]);
      final b = bug(potential: 5, level: 80, tier: 4);
      final sum = TrainSlot.values.fold<int>(
        0,
        (a, sl) => a + trainSlotCapOf(s, b, sp, sl, cfg),
      );
      expect(sum, greaterThan(2 * trainBaseBudget(b, cfg)));
    });
  });

  group('찍기', () {
    test('처음 쓰는 포인트는 재료·시간 — n번째 비용은 지금까지 낸 포인트 수로 오른다', () {
      final b = bug();
      var s = rich([b]);
      final r = allocTrainPoint(s, cfg, b, sp, TrainSlot.attack, t0, count: 2);
      expect(r.error, isNull);
      s = r.save!;
      final cost = cfg.pointCost(1, sp.grade) + cfg.pointCost(2, sp.grade);
      expect(s.materialCount(MaterialKind.chitin), (1 << 30) - cost);
      expect(s.materialCount(MaterialKind.sap), (1 << 30) - cost);
      expect(s.trainPointJob!.count, 2);
      expect(
        s.trainPointJob!.until,
        t0.add(cfg.pointTime(1) + cfg.pointTime(2)),
      );
      // 끝나기 전엔 출전 불가 · 반영 안 됨 · 다른 찍기는 busy
      expect(trainBusy(s, b.id, t0), isTrue);
      expect(trainedPointsOf(s, b.id), 0);
      expect(allocTrainPoint(s, cfg, b, sp, TrainSlot.hp, t0).error, 'busy');
      // 끝나면 반영
      s = finishTrainPointsIfDue(s, t0.add(const Duration(days: 1)));
      expect(s.trainPointJob, isNull);
      expect(s.trainPoints[b.id]!.alloc[TrainSlot.attack], 2);
      expect(s.trainPoints[b.id]!.paid, 2);
      expect(
        cfg.pointCost(3, sp.grade),
        greaterThan(cfg.pointCost(1, sp.grade)),
      );
    });

    test('젤리로 즉시 완료 — 5·10 단위', () {
      final b = bug();
      final s = allocTrainPoint(rich([b]), cfg, b, sp, TrainSlot.hp, t0).save!;
      final r = instantFinishTrainPoint(s, cfg, t0);
      expect(r.error, isNull);
      expect(r.jelly % 5, 0);
      expect(r.save!.trainPoints[b.id]!.alloc[TrainSlot.hp], 1);
    });

    test('예산·칸 상한·재료', () {
      final b = bug(potential: 1); // 예산 6
      var s = rich([b]);
      expect(
        allocTrainPoint(s, cfg, b, sp, TrainSlot.attack, t0, count: 7).error,
        'points',
      );
      // 체급 상한 10 → 11 은 maxed
      final big = bug(id: 'b2', potential: 5, level: 80, tier: 4);
      s = rich([big]);
      expect(
        allocTrainPoint(s, cfg, big, sp, TrainSlot.mass, t0, count: 11).error,
        'maxed',
      );
      final poor = SaveGame.initial(createdAt: t0).copyWith(bugs: [b]);
      expect(
        allocTrainPoint(poor, cfg, b, sp, TrainSlot.attack, t0).error,
        'materials',
      );
    });
  });

  group('다시 찍기', () {
    SaveGame trained(IndividualBug b) {
      var s = rich([b]);
      s = allocTrainPoint(s, cfg, b, sp, TrainSlot.attack, t0, count: 5).save!;
      return finishTrainPointsIfDue(s, t0.add(const Duration(days: 30)));
    }

    test('무료 + 대기(30분 + 포인트당 3분) — 대기 중 출전 불가, 끝나면 새 배분', () {
      final b = bug();
      var s = trained(b);
      final mats = s.materialCount(MaterialKind.chitin);
      final r = startTrainRespec(s, cfg, b, sp, {
        TrainSlot.hp: 3,
        TrainSlot.mass: 2,
      }, t0);
      expect(r.error, isNull);
      s = r.save!;
      expect(s.materialCount(MaterialKind.chitin), mats); // 재료 없음
      final rec = s.trainPoints[b.id]!;
      expect(rec.respecUntil, t0.add(const Duration(minutes: 30 + 3 * 5)));
      expect(rec.alloc[TrainSlot.attack], 5); // 대기 중엔 옛 배분
      expect(trainBusy(s, b.id, t0), isTrue);
      s = finishTrainPointsIfDue(s, t0.add(const Duration(hours: 1)));
      expect(s.trainPoints[b.id]!.alloc, {TrainSlot.hp: 3, TrainSlot.mass: 2});
      expect(trainBusy(s, b.id, t0.add(const Duration(hours: 1))), isFalse);
    });

    test('대기 최대 8시간 · 젤리로 당긴다', () {
      expect(cfg.respecWait(1000), const Duration(hours: 8));
      final b = bug();
      final s = startTrainRespec(trained(b), cfg, b, sp, {
        TrainSlot.hp: 5,
      }, t0).save!;
      final r = instantFinishTrainRespec(s, cfg, b.id, t0);
      expect(r.error, isNull);
      expect(r.jelly % 5, 0);
      expect(r.save!.trainPoints[b.id]!.alloc, {TrainSlot.hp: 5});
    });

    test('재료를 낸 포인트까지만 — 남긴 몫은 나중에 재료 없이 바로 찍힌다', () {
      final b = bug();
      var s = trained(b);
      expect(
        startTrainRespec(s, cfg, b, sp, {TrainSlot.hp: 6}, t0).error,
        'points',
      );
      s = instantFinishTrainRespec(
        startTrainRespec(s, cfg, b, sp, {TrainSlot.hp: 2}, t0).save!,
        cfg,
        b.id,
        t0,
      ).save!;
      final mats = s.materialCount(MaterialKind.chitin);
      final r = allocTrainPoint(s, cfg, b, sp, TrainSlot.crit, t0, count: 3);
      expect(r.error, isNull);
      expect(r.save!.trainPointJob, isNull); // 바로
      expect(r.save!.materialCount(MaterialKind.chitin), mats);
      expect(r.save!.trainPoints[b.id]!.alloc[TrainSlot.crit], 3);
    });

    test('그대로면 same · 음수 bad · 대기 중 찍기는 respec', () {
      final b = bug();
      final s = trained(b);
      expect(
        startTrainRespec(s, cfg, b, sp, {TrainSlot.attack: 5}, t0).error,
        'same',
      );
      expect(
        startTrainRespec(s, cfg, b, sp, {TrainSlot.attack: -1}, t0).error,
        'bad',
      );
      final w = startTrainRespec(s, cfg, b, sp, {TrainSlot.hp: 1}, t0).save!;
      expect(allocTrainPoint(w, cfg, b, sp, TrainSlot.hp, t0).error, 'respec');
    });
  });

  group('이전 — 옛 부위 강화·훈련 단계 → 칸(아무도 약해지지 않는다)', () {
    // 옛 결투 계산(2026-10-07 까지): 부위 강화 × 훈련소 단계 × 수련 레벨.
    ({
      double atk,
      double def,
      double hp,
      double spd,
      double evade,
      double crit,
      double recovery,
    })
    oldDuel(IndividualBug b, Map<TrainStat, int> lv) {
      final e = b.enhancement;
      double t(TrainStat s) =>
          (lv[s] ?? 0).clamp(0, trainCapOf(b, sp, s, cfg)) *
          (cfg.perLevel[s] ?? 0);
      final lvl = b.level.clamp(1, pet.levelCap(b.breakthroughTier));
      final lm = 1 + (lvl - 1) * cfg.duelLevelBonus;
      return (
        atk:
            (1 + e.levelOf(BugPart.hornJaw) * 0.04) *
            (1 + t(TrainStat.attack)) *
            lm,
        def:
            (1 + e.levelOf(BugPart.cuticle) * 0.04) *
            (1 + t(TrainStat.defense)),
        hp: (1 + e.levelOf(BugPart.build) * 0.05) * lm,
        spd: 1 + e.levelOf(BugPart.wing) * 0.03,
        evade: e.levelOf(BugPart.wing) * 0.003 + t(TrainStat.evade),
        crit: t(TrainStat.crit),
        recovery: t(TrainStat.recovery),
      );
    }

    test('무작위 400계정 — 이전 뒤 결투 스탯이 모두 같거나 크다(서버 상한 자르기 포함)', () {
      final rng = math.Random(20261008);
      for (var i = 0; i < 400; i++) {
        final potential = 1 + rng.nextInt(5);
        final tier = rng.nextInt(5);
        final level = 1 + rng.nextInt(pet.levelCap(tier));
        // 부위 강화 총합 ≤ 포텐셜 × 10 (옛 상한)
        final parts = List.filled(4, 0);
        for (var k = 0; k < potential * 10; k++) {
          if (rng.nextDouble() < 0.8) parts[rng.nextInt(4)]++;
        }
        final temp = Temperament.values[rng.nextInt(5)];
        final trait = BugTrait.values[rng.nextInt(BugTrait.values.length)];
        final b = bug(
          potential: potential,
          tier: tier,
          level: level,
          t: temp,
          trait: trait,
          enhancement: PartLevels(
            hornJaw: parts[0],
            cuticle: parts[1],
            wing: parts[2],
            build: parts[3],
          ),
        );
        final lv = {
          for (final st in TrainStat.values)
            if (rng.nextBool()) st: rng.nextInt(20),
        };
        final before = SaveGame.initial(
          createdAt: t0,
        ).copyWith(bugs: [b], duelTraining: {b.id: lv});
        final old = oldDuel(b, lv);
        final after = migrateTrainingV2(
          before,
          cfg,
          speciesOf: speciesOf,
          enhance: enhance,
        );
        // 서버 업로드 검사를 거쳐도 그대로여야 한다.
        final served = sanitizeTrainPoints(
          after,
          cfg,
          speciesOf: speciesOf,
          levelCapOf: pet.levelCap,
          enhance: enhance,
        );
        expect(identical(served, after), isTrue, reason: '정상 이전이 서버에서 잘렸다 #$i');
        final n = trainingBonusOf(
          served,
          b,
          sp,
          cfg,
          levelCap: pet.levelCap(b.breakthroughTier),
          enhance: enhance,
        );
        const eps = 1e-9;
        expect(n.atkMult, greaterThanOrEqualTo(old.atk - eps), reason: '#$i');
        expect(n.defMult, greaterThanOrEqualTo(old.def - eps), reason: '#$i');
        expect(n.hpMult, greaterThanOrEqualTo(old.hp - eps), reason: '#$i');
        // 속도 칸은 2026-10-09 밀어내기 힘 칸이 됐다 — 날개 강화는 옛 속도 칸과 **같은 포인트 수**로
        // 밀어내기 힘에 옮긴다(속도 자체는 죽은 능력치라 옮기지 않는다 · 결투 속도는 체급의 대가로만 준다).
        final wing = b.enhancement.levelOf(BugPart.wing);
        final pushPts = wing <= 0 ? 0 : (wing * 0.03 / 0.02 - 1e-9).ceil();
        expect(
          served.trainPoints[b.id]?.alloc[TrainSlot.push] ?? 0,
          pushPts,
          reason: '#$i',
        );
        expect(n.spdMult, closeTo(1, eps), reason: '#$i');
        expect(
          n.pushMult,
          closeTo(1 + pushPts * cfg.slotEffect[TrainSlot.push]!, eps),
          reason: '#$i',
        );
        expect(n.evade, greaterThanOrEqualTo(old.evade - eps), reason: '#$i');
        expect(n.crit, greaterThanOrEqualTo(old.crit - eps), reason: '#$i');
        expect(
          n.recovery,
          greaterThanOrEqualTo(old.recovery - eps),
          reason: '#$i',
        );
        // 펫 기여도 줄지 않는다.
        final oldPet =
            (1 + b.enhancement.total * cfg.legacyEnhancePetScale) *
            (1 + lv.values.fold<int>(0, (a, x) => a + x) * cfg.petScale);
        expect(
          trainPetMult(served, b.id, cfg),
          greaterThanOrEqualTo(oldPet - eps),
        );
      }
    });

    test('예산을 넘친 만큼은 보너스 포인트 · 첫 다시 찍기는 대기 없음', () {
      final b = bug(
        potential: 5,
        enhancement: const PartLevels(hornJaw: 30, cuticle: 20),
      );
      final s = migrateTrainingV2(
        rich([b]),
        cfg,
        speciesOf: speciesOf,
        enhance: enhance,
      );
      final rec = s.trainPoints[b.id]!;
      // 뿔 30 → 공격 (1.2 / 0.03) = 40 · 표피 20 → 방어 (0.8/0.03 → 27)
      expect(rec.alloc[TrainSlot.attack], 40);
      expect(rec.alloc[TrainSlot.defense], 27);
      expect(rec.paid, 67);
      expect(rec.bonus, 67 - trainBaseBudget(b, cfg));
      expect(rec.freeRespec, isTrue);
      // 공격 칸 상한(호전적 30+9+3=42)보다 작아도 옮긴 값 40 은 그대로 — 넘치면 그 칸 상한이 늘어난다.
      final r = startTrainRespec(s, cfg, b, sp, {
        TrainSlot.hp: 30,
        TrainSlot.push: 20,
      }, t0);
      expect(r.error, isNull);
      expect(r.save!.trainPoints[b.id]!.pending, isNull); // 대기 없음
      expect(r.save!.trainPoints[b.id]!.freeRespec, isFalse);
      // 두 번째부터는 대기
      final r2 = startTrainRespec(r.save!, cfg, b, sp, {TrainSlot.hp: 1}, t0);
      expect(r2.save!.trainPoints[b.id]!.pending, isNotNull);
    });

    test('멱등 — 두 번 돌려도 같다 · 진행 중이던 옛 훈련은 끝난 것으로', () {
      final b = bug(enhancement: const PartLevels(build: 4));
      final s0 = rich([b]).copyWith(
        duelTraining: {
          b.id: {TrainStat.crit: 2},
        },
        trainingJob: TrainingJob(
          bugId: b.id,
          stat: TrainStat.crit,
          level: 3,
          until: t0.add(const Duration(hours: 5)),
        ),
      );
      final once = migrateTrainingV2(
        s0,
        cfg,
        speciesOf: speciesOf,
        enhance: enhance,
      );
      expect(once.trainingJob, isNull);
      expect(once.duelTraining[b.id]![TrainStat.crit], 3);
      // 치명 3단계 × 2% = 6% → 6포인트 · 체격 4 × 5% = 20% → 5포인트
      expect(once.trainPoints[b.id]!.alloc, {
        TrainSlot.hp: 5,
        TrainSlot.crit: 6,
      });
      final twice = migrateTrainingV2(
        once,
        cfg,
        speciesOf: speciesOf,
        enhance: enhance,
      );
      expect(identical(twice, once), isTrue);
      expect(jsonEncode(twice.toJson()), jsonEncode(once.toJson()));
    });

    test('옛 투자가 없는 곤충은 기록을 만들지 않는다', () {
      final s = rich([bug()]);
      final out = migrateTrainingV2(
        s,
        cfg,
        speciesOf: speciesOf,
        enhance: enhance,
      );
      expect(identical(out, s), isTrue);
    });
  });

  group('서버 상한 자르기(위조 방어)', () {
    test('칸 99 · 보너스 999 · 재료를 낸 포인트 999 → 예산·상한으로', () {
      final b = bug(potential: 1); // 예산 6, 옛 투자 없음 → 보너스 0
      final forged = rich([b]).copyWith(
        trainPoints: {
          b.id: const BugTrain(
            alloc: {TrainSlot.attack: 99, TrainSlot.grit: 99},
            paid: 999,
            bonus: 999,
          ),
        },
      );
      final out = sanitizeTrainPoints(
        forged,
        cfg,
        speciesOf: speciesOf,
        levelCapOf: pet.levelCap,
        enhance: enhance,
      );
      final rec = out.trainPoints[b.id]!;
      expect(rec.bonus, 0);
      expect(rec.paid, 6);
      expect(rec.allocated, 6);
      // 결투 계산도 같은 상한으로 자른다(업로드를 거치지 않은 세이브라도).
      final t = trainingBonusOf(forged, b, sp, cfg, enhance: enhance);
      expect(
        t.atkMult,
        lessThanOrEqualTo(1 + 6 * cfg.slotEffect[TrainSlot.attack]! + 1e-9),
      );
    });

    test('없는 곤충 기록·대기열은 지운다', () {
      final s = rich([bug()]).copyWith(
        trainPoints: {
          'ghost': const BugTrain(alloc: {TrainSlot.hp: 1}, paid: 1),
        },
        trainPointJob: TrainPointJob(
          bugId: 'ghost',
          slot: TrainSlot.hp,
          count: 1,
          until: t0,
        ),
      );
      final out = pruneTraining(s);
      expect(out.trainPoints, isEmpty);
      expect(out.trainPointJob, isNull);
    });

    test('찍은 곤충은 합성·방생 재료에서 빠진다(pinnedBugIds)', () {
      final s = rich([bug()]).copyWith(
        trainPoints: {
          'b1': const BugTrain(alloc: {TrainSlot.hp: 1}, paid: 1),
        },
      );
      expect(s.pinnedBugIds, contains('b1'));
    });
  });

  group('결투석', () {
    test('젤리로 사기(오행 40 · 기질 60) · 부족하면 jelly', () {
      var s = rich([bug()]);
      final r = buyDuelStone(s, cfg.stones, DuelStone.element, count: 2);
      expect(r.error, isNull);
      expect(r.jelly, 80);
      s = r.save!;
      expect(s.duelStoneCount(DuelStone.element), 2);
      expect(s.materialCount(MaterialKind.jelly), 10000 - 80);
      expect(buyDuelStone(s, cfg.stones, DuelStone.temperament).jelly, 60);
      final poor = SaveGame.initial(createdAt: t0);
      expect(buyDuelStone(poor, cfg.stones, DuelStone.element).error, 'jelly');
    });

    test('쓰기 — 원하는 오행·기질로, 같으면 same, 돌이 없으면 stone', () {
      final b = bug();
      var s = rich([
        b,
      ]).copyWith(duelStones: {DuelStone.element: 1, DuelStone.temperament: 1});
      expect(useDuelStone(s, b.id, element: Element.fire).error, 'same');
      final r = useDuelStone(s, b.id, element: Element.water);
      expect(r.error, isNull);
      s = r.save!;
      expect(s.bugs.single.element, Element.water);
      expect(s.duelStoneCount(DuelStone.element), 0);
      expect(useDuelStone(s, b.id, element: Element.wood).error, 'stone');
      s = useDuelStone(s, b.id, temperament: Temperament.cunning).save!;
      expect(s.bugs.single.temperament, Temperament.cunning);
      expect(useDuelStone(s, b.id).error, 'bad');
    });

    test('드롭 — 정예·보스 재처치 확률 · 심연 10층마다 첫 도달', () {
      const always = DuelStoneConfig(
        eliteChance: {DuelStone.element: 1},
        bossRepeatChance: {DuelStone.element: 1, DuelStone.temperament: 1},
      );
      final s = rich([]);
      final e = rollDuelStones(
        s,
        always,
        math.Random(1),
        DuelStoneSource.elite,
      );
      expect(e.got, {DuelStone.element: 1});
      final bo = rollDuelStones(
        s,
        always,
        math.Random(1),
        DuelStoneSource.bossRepeat,
      );
      expect(bo.save.duelStones, {
        DuelStone.element: 1,
        DuelStone.temperament: 1,
      });
      // 실제 확률(0.2%) — 1만 번에 수십 개 수준
      var n = 0;
      final rng = math.Random(7);
      for (var i = 0; i < 10000; i++) {
        n += rollDuelStones(
          s,
          cfg.stones,
          rng,
          DuelStoneSource.elite,
        ).got.length;
      }
      expect(n, inInclusiveRange(5, 50));
      expect(grantAbyssDuelStones(s, cfg.stones, 20).got, {
        DuelStone.element: 2,
        DuelStone.temperament: 1,
      });
      expect(grantAbyssDuelStones(s, cfg.stones, 21).got, isEmpty);
    });

    test('서버 허용치 = 쓴 젤리 ÷ 가장 싼 값 + 마일스톤 × 3 + 여유', () {
      expect(
        duelStoneAllowance(cfg.stones, jellySpent: 120, abyssMilestones: 2),
        3 + 2 * 3 + kDuelStoneDropSlack,
      );
    });
  });

  test('JSON 왕복 — 배분·대기·보너스·대기열·결투석', () {
    final s = rich([bug()]).copyWith(
      trainPoints: {
        'b1': BugTrain(
          alloc: const {TrainSlot.tech: 3, TrainSlot.grit: 2},
          paid: 7,
          bonus: 4,
          pending: const {TrainSlot.mass: 5},
          respecUntil: t0,
          freeRespec: true,
        ),
      },
      trainPointJob: TrainPointJob(
        bugId: 'b1',
        slot: TrainSlot.push,
        count: 2,
        until: t0,
      ),
      duelStones: {DuelStone.element: 3},
    );
    final back = SaveGame.fromJson(
      jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>,
    );
    final r = back.trainPoints['b1']!;
    expect(r.alloc, {TrainSlot.tech: 3, TrainSlot.grit: 2});
    expect(r.paid, 7);
    expect(r.bonus, 4);
    expect(r.pending, {TrainSlot.mass: 5});
    expect(r.respecUntil, t0);
    expect(r.freeRespec, isTrue);
    expect(back.trainPointJob!.count, 2);
    expect(back.duelStoneCount(DuelStone.element), 3);
    expect(s.toJson()['feat'], kSaveFeatureLevel);
    // 훈련 v2 필드는 feat 19 부터(20 = 장비 회피 옵션, 2026-10-09).
    expect(kSaveFeatureLevel, greaterThanOrEqualTo(19));
  });

  test('옛 단계 상한(이전 환산용) — 기본 + 포텐셜 + 기질·주특기·특성', () {
    final b = bug(trait: BugTrait.fierce);
    expect(trainCapOf(b, sp, TrainStat.attack, cfg), 17);
  });

  test('옛 칸 키 speed(속도 칸)는 밀어내기 힘으로 읽는다 — 배분·대기 배분·대기열', () {
    final raw = rich([bug()]).toJson()
      ..['trainPoints'] = {
        'b1': {
          'a': {'speed': 18, 'attack': 5},
          'p': 23,
          'n': {'speed': 3},
          'u': t0.toIso8601String(),
        },
      }
      ..['trainPointJob'] = {
        'b': 'b1',
        's': 'speed',
        'n': 2,
        'u': t0.toIso8601String(),
      };
    final s = SaveGame.fromJson(
      jsonDecode(jsonEncode(raw)) as Map<String, dynamic>,
    );
    final r = s.trainPoints['b1']!;
    expect(r.alloc, {TrainSlot.push: 18, TrainSlot.attack: 5});
    expect(r.pending, {TrainSlot.push: 3});
    expect(s.trainPointJob!.slot, TrainSlot.push);
    // 다시 쓰면 새 키로 — 둘 다 적힌 세이브(고친 경우뿐)는 큰 쪽(더하면 두 번 들어간다).
    final out = jsonEncode(s.toJson());
    expect(out.contains('"push":18'), isTrue);
    expect(out.contains('"speed"'), isFalse);
    final both = BugTrain.fromJson({
      'a': {'speed': 4, 'push': 9},
    })!;
    expect(both.alloc, {TrainSlot.push: 9});
  });

  group('추천 배분(2026-10-09)', () {
    int cap30(TrainSlot sl) => sl == TrainSlot.mass ? 10 : 30;

    test('비율대로 나누고 칸 상한을 넘지 않는다 · 결정론', () {
      final w = cfg.presets['heavy']!; // 체급 10 · 체력 30 · 방어 30 · 공격 30 · 밀어내기 2
      final a = distributeTrainPoints(w, 102, capOf: cap30);
      expect(a.values.fold<int>(0, (x, y) => x + y), 102);
      expect(a[TrainSlot.mass], 10);
      expect(a[TrainSlot.hp], 30);
      expect(a[TrainSlot.defense], 30);
      expect(a[TrainSlot.attack], 30);
      expect(a[TrainSlot.push], 2);
      expect(distributeTrainPoints(w, 102, capOf: cap30), a);
      // 절반 예산 — 비율 그대로 줄어든다.
      final h = distributeTrainPoints(w, 51, capOf: cap30);
      expect(h.values.fold<int>(0, (x, y) => x + y), 51);
      expect(h[TrainSlot.hp], 15);
      expect(h[TrainSlot.mass], 5);
    });

    test('비율 칸이 모두 상한이면 남는 칸으로 · 어느 칸도 없으면 멈춘다', () {
      final a = distributeTrainPoints(
        {TrainSlot.hp: 1},
        12,
        capOf: (sl) => sl == TrainSlot.hp ? 10 : 1,
      );
      expect(a[TrainSlot.hp], 10);
      expect(a.values.fold<int>(0, (x, y) => x + y), 12);
      final none = distributeTrainPoints(
        {TrainSlot.hp: 1},
        50,
        capOf: (_) => 2,
      );
      expect(
        none.values.fold<int>(0, (x, y) => x + y),
        TrainSlot.values.length * 2,
      );
    });

    test('바닥(이미 찍은 배분)은 내리지 않고 남는 몫만 더한다 · 다음 추천 칸', () {
      final w = cfg.presets['tank']!; // 체력 30 · 방어 30 · 회복력 20 · 회피 20 · 체급 2
      final floor = {TrainSlot.attack: 6, TrainSlot.hp: 4};
      final a = distributeTrainPoints(w, 20, capOf: cap30, floor: floor);
      expect(a[TrainSlot.attack], 6);
      expect(a[TrainSlot.hp]! >= 4, isTrue);
      expect(a.values.fold<int>(0, (x, y) => x + y), 20);
      // 체력·방어 비율이 같으면 칸 순서(방어가 먼저).
      expect(nextPresetSlot(w, const {}, capOf: cap30), TrainSlot.defense);
      expect(
        nextPresetSlot(w, const {TrainSlot.defense: 30}, capOf: cap30),
        TrainSlot.hp,
      );
    });

    test('남는 포인트 채우기 — 재료 없이 한 번에 · 지금 배분은 그대로', () {
      final b = bug(potential: 5, level: 80, tier: 4);
      final s = rich([b]).copyWith(
        trainPoints: {
          b.id: const BugTrain(alloc: {TrainSlot.attack: 10}, paid: 40),
        },
      );
      final r = fillTrainFreePoints(s, cfg, b, sp, cfg.presets['tank']!, t0);
      expect(r.error, isNull);
      final rec = r.save!.trainPoints[b.id]!;
      expect(rec.alloc[TrainSlot.attack], 10);
      expect(rec.allocated, 40);
      expect(rec.paid, 40);
      expect(r.save!.materials, s.materials); // 재료는 들지 않는다
      expect(r.save!.trainPointJob, isNull);
      // 남는 포인트가 없으면 none · 다시 찍기 대기 중이면 respec.
      expect(
        fillTrainFreePoints(
          r.save!,
          cfg,
          b,
          sp,
          cfg.presets['tank']!,
          t0,
        ).error,
        'none',
      );
      final pending = s.copyWith(
        trainPoints: {
          b.id: BugTrain(
            alloc: const {TrainSlot.attack: 10},
            paid: 40,
            pending: const {TrainSlot.hp: 10},
            respecUntil: t0.add(const Duration(hours: 1)),
          ),
        },
      );
      expect(
        fillTrainFreePoints(
          pending,
          cfg,
          b,
          sp,
          cfg.presets['tank']!,
          t0,
        ).error,
        'respec',
      );
    });
  });
}
