import 'dart:convert';
import 'dart:io';

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:test/test.dart';

/// 훈련소(2026-09-29) — 곤충마다 결투 능력치. 최대 단계가 기질·주특기·특성·포텐셜로 갈린다.
void main() {
  final cfg = BattleConfig.fromJson(
    jsonDecode(File('../app/assets/data/battle.json').readAsStringSync())
        as Map<String, dynamic>,
  ).training;
  const sp = Species(
    id: 'stag_dorcus',
    name: LocalizedText(ko: '사슴벌레', en: 'Stag', ja: 'クワガタ'),
    grade: Grade.common,
    specialty: Specialty.strike,
    baseStats: Stats(hp: 100, atk: 40, def: 30, spd: 20),
    sizeMinMm: 30,
    sizeMaxMm: 75,
  );
  IndividualBug bug({
    Temperament t = Temperament.aggressive,
    BugTrait trait = BugTrait.none,
    int potential = 5,
  }) => IndividualBug(
    id: 'b1',
    speciesId: sp.id,
    sizeMm: 50,
    potential: potential,
    temperament: t,
    sex: Sex.male,
    element: Element.fire,
    trait: trait,
  );
  final t0 = DateTime.utc(2026, 10, 1);
  SaveGame rich(IndividualBug b) => SaveGame.initial(createdAt: t0).copyWith(
    bugs: [b],
    materials: {
      MaterialKind.chitin: 1 << 20,
      MaterialKind.mineral: 1 << 20,
      MaterialKind.sap: 1 << 20,
      MaterialKind.jelly: 1000,
    },
  );

  test('최대 단계 — 기본 + 포텐셜 + 기질·주특기·특성', () {
    // 5성 · 호전적(공격+3) · 치기(공격+1) · 맹렬(공격+2) = 6+5+3+1+2
    final b = bug(trait: BugTrait.fierce);
    expect(trainCapOf(b, sp, TrainStat.attack, cfg), 17);
    // 호전적은 방어 −2 → 6+5−2 = 9
    expect(trainCapOf(b, sp, TrainStat.defense, cfg), 9);
    // 1성 우직: 방어 6+1+3 = 10 · 회피 6+1−2 = 5
    final s = bug(t: Temperament.steadfast, potential: 1);
    expect(trainCapOf(s, sp, TrainStat.defense, cfg), 10);
    expect(trainCapOf(s, sp, TrainStat.evade, cfg), 5);
  });

  test('시작 → 재료 차감·타이머 → 끝나면 단계 오름 · 한 칸만', () {
    final b = bug();
    final r = startTraining(rich(b), cfg, b, sp, TrainStat.attack, t0);
    expect(r.error, isNull);
    final s1 = r.save!;
    expect(
      s1.materialCount(MaterialKind.chitin),
      (1 << 20) - cfg.costFor(1, sp.grade),
    );
    expect(s1.trainingJob!.level, 1);
    expect(
      startTraining(s1, cfg, b, sp, TrainStat.crit, t0).error,
      'busy',
      reason: '훈련소는 한 칸',
    );
    expect(trainLevelsOf(finishTrainingIfDue(s1, t0), b.id), isEmpty);
    final done = finishTrainingIfDue(s1, t0.add(cfg.timeFor(1)));
    expect(trainLevelsOf(done, b.id)[TrainStat.attack], 1);
    expect(done.trainingJob, isNull);
    expect(done.pinnedBugIds, contains(b.id), reason: '훈련한 곤충은 합성·방생에서 빠진다');
  });

  test('젤리 즉시 완료 · 재료 부족 · 최대 단계', () {
    final b = bug(t: Temperament.steadfast, potential: 1);
    final s1 = startTraining(rich(b), cfg, b, sp, TrainStat.evade, t0).save!;
    final i = instantFinishTraining(s1, cfg, t0);
    expect(i.error, isNull);
    expect(i.jelly % 5, 0, reason: '젤리 가격은 5 단위');
    expect(trainLevelsOf(i.save!, b.id)[TrainStat.evade], 1);
    final poor = SaveGame.initial(createdAt: t0).copyWith(bugs: [b]);
    expect(
      startTraining(poor, cfg, b, sp, TrainStat.evade, t0).error,
      'materials',
    );
    final maxed = rich(b).copyWith(
      duelTraining: {
        b.id: {TrainStat.evade: trainCapOf(b, sp, TrainStat.evade, cfg)},
      },
    );
    expect(
      startTraining(maxed, cfg, b, sp, TrainStat.evade, t0).error,
      'maxed',
    );
  });

  test('결투 보너스는 최대 단계로 자른다(위조 방어) · 초기화는 절반 환불', () {
    final b = bug(t: Temperament.cautious, potential: 1); // 공격 cap 6+1−2+1 = 6
    final forged = rich(b).copyWith(
      duelTraining: {
        b.id: {TrainStat.attack: 99},
      },
    );
    final bonus = trainingBonusOf(forged, b, sp, cfg);
    expect(
      bonus.atkMult,
      closeTo(1 + 6 * cfg.perLevel[TrainStat.attack]!, 1e-9),
    );
    final r = resetTraining(forged, cfg, b, sp);
    expect(r.error, isNull);
    expect(trainLevelsOf(r.save!, b.id), isEmpty);
  });

  test('세이브 왕복', () {
    final b = bug();
    final s1 = startTraining(rich(b), cfg, b, sp, TrainStat.crit, t0).save!
        .copyWith(
          duelTraining: {
            b.id: {TrainStat.attack: 3},
          },
        );
    final back = SaveGame.fromJson(s1.toJson());
    expect(trainLevelsOf(back, b.id)[TrainStat.attack], 3);
    expect(back.trainingJob!.stat, TrainStat.crit);
    expect(back.trainingJob!.until, s1.trainingJob!.until);
  });

  test('교차 반영 — 훈련은 펫 기여에, 수련 레벨은 결투에(상한으로 자른다)', () {
    final b = bug().copyWith(level: 30);
    final s = rich(b).copyWith(
      duelTraining: {
        b.id: {TrainStat.attack: 4, TrainStat.defense: 6},
      },
    );
    expect(trainPetMult(s, b.id, cfg), closeTo(1 + 10 * cfg.petScale, 1e-9));
    final full = trainingBonusOf(s, b, sp, cfg, levelCap: 80);
    final lm = 1 + 29 * cfg.duelLevelBonus;
    expect(full.hpMult, closeTo(lm, 1e-9));
    expect(
      full.atkMult,
      closeTo((1 + 4 * cfg.perLevel[TrainStat.attack]!) * lm, 1e-9),
    );
    // 돌파 티어 상한이 10이면 레벨 30 으로 적어도 10 으로 친다(위조 방어).
    final capped = trainingBonusOf(s, b, sp, cfg, levelCap: 10);
    expect(capped.hpMult, closeTo(1 + 9 * cfg.duelLevelBonus, 1e-9));
  });
}
