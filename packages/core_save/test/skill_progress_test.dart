import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:test/test.dart';

/// 실제 게임 데이터(skills.json)로 돈다 — 수치를 바꾸면 규칙이 여기서 먼저 깨진다.
SkillConfig _cfg() => SkillConfig.fromJson(
  jsonDecode(File('../app/assets/data/skills.json').readAsStringSync())
      as Map<String, dynamic>,
);

final _t = DateTime.utc(2026, 9, 15, 12);

void main() {
  final cfg = _cfg();
  final common = cfg.skills.firstWhere(
    (s) => s.grade == Grade.common && !s.isActive,
  );
  final legend = cfg.skills.firstWhere((s) => s.grade == Grade.legendary);
  SaveGame fresh() => SaveGame.initial(createdAt: _t);

  group('조각 · 해금', () {
    test('해금 조각이 모이면 자동으로 레벨 1 · 남는 조각은 그대로', () {
      var s = grantSkillShards(fresh(), cfg, {common.id: cfg.unlockShards - 1});
      expect(s.skillLevels[common.id], isNull);
      expect(s.skillShards[common.id], cfg.unlockShards - 1);

      s = grantSkillShards(s, cfg, {common.id: 3});
      expect(s.skillLevels[common.id], 1);
      expect(s.skillShards[common.id], 2);
    });

    test('모르는 스킬 id · 0 이하 조각은 무시', () {
      final s = grantSkillShards(fresh(), cfg, {'nope': 99, common.id: -5});
      expect(s.skillShards, isEmpty);
      expect(s.skillLevels, isEmpty);
    });

    test('만렙 스킬 조각은 그대로 쌓인다 — 등급 승급 재료', () {
      final maxed = fresh().copyWith(skillLevels: {legend.id: cfg.maxLevel});
      final s = grantSkillShards(maxed, cfg, {legend.id: 4});
      expect(s.skillShards[legend.id], 4);
    });
  });

  group('수련', () {
    SaveGame owned({int lv = 1, int shards = 0, int wild = 0, int jelly = 0}) =>
        fresh().copyWith(
          skillLevels: {common.id: lv},
          skillShards: shards > 0 ? {common.id: shards} : const {},
          skillGradeShards: wild > 0 ? {common.grade.key: wild} : const {},
          materials: {MaterialKind.jelly: jelly},
        );

    test('조각을 쓰고 타이머를 건다 · 한 번에 한 스킬', () {
      final need = cfg.shardsForLevel(common, 1);
      final op = startSkillTraining(
        owned(shards: need + 1),
        cfg,
        common.id,
        _t,
      );
      expect(op.isOk, isTrue);
      final s = op.save!;
      expect(s.skillShards[common.id], 1);
      expect(s.skillTrainingId, common.id);
      expect(s.skillTrainingEndsAt, _t.add(cfg.trainDuration(common, 1)));

      final other = cfg.skills.firstWhere((d) => d.id != common.id);
      final busy = startSkillTraining(
        s.copyWith(skillLevels: {...s.skillLevels, other.id: 1}),
        cfg,
        other.id,
        _t,
      );
      expect(busy.error, 'training_busy');
    });

    test('조각이 모자라면 그 등급 만능 조각으로 1:1 메운다', () {
      final need = cfg.shardsForLevel(common, 1);
      final short = startSkillTraining(
        owned(shards: need - 2, wild: 1),
        cfg,
        common.id,
        _t,
      );
      expect(short.error, 'not_enough_shards');
      final ok = startSkillTraining(
        owned(shards: need - 2, wild: 2),
        cfg,
        common.id,
        _t,
      );
      expect(ok.isOk, isTrue);
      expect(ok.save!.gradeShards(common.grade), 0);
      expect(ok.save!.skillShards[common.id], isNull);
    });

    test('미보유·만렙은 수련할 수 없다', () {
      expect(
        startSkillTraining(fresh(), cfg, common.id, _t).error,
        'not_owned',
      );
      expect(
        startSkillTraining(
          owned(lv: cfg.maxLevel, shards: 999),
          cfg,
          common.id,
          _t,
        ).error,
        'max_level',
      );
    });

    test('타이머 전엔 못 받고, 끝나면 레벨 +1', () {
      final need = cfg.shardsForLevel(common, 1);
      final s = startSkillTraining(
        owned(shards: need),
        cfg,
        common.id,
        _t,
      ).save!;
      expect(completeSkillTraining(s, cfg, _t).error, 'not_ready');
      final done = completeSkillTraining(s, cfg, s.skillTrainingEndsAt!).save!;
      expect(done.skillLevels[common.id], 2);
      expect(done.skillTrainingId, isNull);
      expect(done.skillTrainingEndsAt, isNull);
    });

    test('젤리 즉시완료 — 남은 시간 비례 · 젤리가 모자라면 거절', () {
      final need = cfg.shardsForLevel(common, 1);
      final started = startSkillTraining(
        owned(shards: need),
        cfg,
        common.id,
        _t,
      ).save!;
      final price = cfg.trainJelly(started.skillTrainingEndsAt!.difference(_t));
      expect(price, greaterThan(0));
      expect(
        completeSkillTraining(started, cfg, _t, viaJelly: true).error,
        'not_enough_jelly',
      );
      final rich = started.copyWith(materials: {MaterialKind.jelly: price});
      final op = completeSkillTraining(rich, cfg, _t, viaJelly: true);
      expect(op.isOk, isTrue);
      expect(op.save!.materialCount(MaterialKind.jelly), 0);
      expect(op.save!.skillLevels[common.id], 2);
    });
  });

  group('등급 승급', () {
    final commons = cfg.skills.where((d) => d.grade == Grade.common).toList();
    final ratio = cfg.gradeUpRatio;

    test('같은 등급 조각 N개 → 위 등급 만능 1개 · 고른 소스 순서대로 꺼낸다', () {
      final s = fresh().copyWith(
        skillShards: {commons[0].id: ratio + 3, commons[1].id: ratio},
      );
      final op = gradeUpShards(
        s,
        cfg,
        from: Grade.common,
        sources: [commons[0].id, commons[1].id],
        times: 2,
      );
      expect(op.isOk, isTrue);
      final out = op.save!;
      expect(out.gradeShards(Grade.rare), 2);
      expect(out.skillShards[commons[0].id], isNull);
      expect(out.skillShards[commons[1].id], 3);
    });

    test('고르지 않은 스킬 조각은 건드리지 않는다 · 모자라면 거절', () {
      final s = fresh().copyWith(
        skillShards: {commons[0].id: ratio - 1, commons[1].id: 999},
      );
      final op = gradeUpShards(
        s,
        cfg,
        from: Grade.common,
        sources: [commons[0].id],
        times: 1,
      );
      expect(op.error, 'not_enough_shards');
    });

    test('만능 조각도 재료가 된다 — 희귀 만능 N개 → 영웅 만능', () {
      final s = fresh().copyWith(skillGradeShards: {Grade.rare.key: ratio});
      final op = gradeUpShards(
        s,
        cfg,
        from: Grade.rare,
        sources: const [kGradeShardSource],
        times: 1,
      );
      expect(op.save!.gradeShards(Grade.rare), 0);
      expect(op.save!.gradeShards(Grade.epic), 1);
    });

    test('전설은 더 올릴 곳이 없다', () {
      expect(
        gradeUpShards(
          fresh(),
          cfg,
          from: Grade.legendary,
          sources: const [],
          times: 1,
        ).error,
        'max_grade',
      );
    });
  });

  group('장착', () {
    test('칸은 처음 가 본 최고 난이도로 열린다', () {
      final ids = cfg.skills.take(5).map((d) => d.id).toList();
      var s = fresh().copyWith(skillLevels: {for (final id in ids) id: 1});
      for (final id in ids) {
        final op = toggleSkillEquip(s, cfg, id);
        if (op.isOk) s = op.save!;
      }
      expect(s.equippedSkills.length, cfg.slotsFor(0));
      expect(toggleSkillEquip(s, cfg, ids.last).error, 'slots_full');

      final hard = s.copyWith(maxTierReached: 3);
      expect(toggleSkillEquip(hard, cfg, ids.last).isOk, isTrue);
    });

    test('미보유는 장착 불가 · 다시 누르면 해제', () {
      expect(toggleSkillEquip(fresh(), cfg, common.id).error, 'not_owned');
      final s = fresh().copyWith(skillLevels: {common.id: 1});
      final on = toggleSkillEquip(s, cfg, common.id).save!;
      expect(on.equippedSkills, [common.id]);
      final off = toggleSkillEquip(on, cfg, common.id).save!;
      expect(off.equippedSkills, isEmpty);
    });
  });

  group('보스·정예 조각', () {
    test('같은 시드면 같은 조각 · 첫 처치는 확정', () {
      final a = grantBossShards(
        fresh(),
        cfg,
        Random(3),
        tier: 1,
        firstKill: true,
      );
      final b = grantBossShards(
        fresh(),
        cfg,
        Random(3),
        tier: 1,
        firstKill: true,
      );
      expect(a.shards, b.shards);
      expect(a.shards.values.single, cfg.bossFirstKillShards);
      expect(a.save.skillShards, b.save.skillShards);
    });

    test('정예 조각은 확률 — 나오면 세이브에 들어간다', () {
      var hits = 0;
      for (var i = 0; i < 500; i++) {
        final r = grantEliteShards(fresh(), cfg, Random(i), tier: 0);
        if (r.shards.isEmpty) continue;
        hits++;
        expect(r.save.skillShards, r.shards);
      }
      expect(hits, greaterThan(0));
      expect(hits, lessThan(500));
    });
  });

  group('뽑기', () {
    const day = '2026-09-15';
    SaveGame rich([int jelly = 1000]) =>
        fresh().copyWith(materials: {MaterialKind.jelly: jelly});

    test('젤리를 쓰고 조각이 들어온다 · 10연은 10배', () {
      final op = drawSkills(rich(), cfg, Random(1), dayKey: day, times: 10);
      expect(op.isOk, isTrue);
      final s = op.save!;
      expect(
        s.materialCount(MaterialKind.jelly),
        1000 - cfg.gachaJellyCost * 10,
      );
      final draws = op.extra['draws'] as List<SkillDraw>;
      expect(draws.length, 10);
      final got =
          s.skillShards.values.fold(0, (a, b) => a + b) +
          s.skillLevels.length * cfg.unlockShards;
      expect(got, cfg.gachaShards * 10);
    });

    test('천장 — 10회 안에 천장 등급이 반드시 나온다', () {
      for (var seed = 0; seed < 50; seed++) {
        final op = drawSkills(
          rich(),
          cfg,
          Random(seed),
          dayKey: day,
          times: cfg.gachaPity,
        );
        final draws = op.extra['draws'] as List<SkillDraw>;
        expect(
          draws.any((d) => d.grade.index >= cfg.gachaPityGrade.index),
          isTrue,
          reason: 'seed $seed',
        );
      }
    });

    test('천장 카운터는 천장 등급이 나올 때만 되감긴다', () {
      final s = rich().copyWith(skillGachaPity: cfg.gachaPity - 1);
      final op = drawSkills(s, cfg, Random(0), dayKey: day, times: 1);
      expect(
        (op.extra['draws'] as List<SkillDraw>).single.grade,
        greaterThanOrEqualTo(cfg.gachaPityGrade),
      );
      expect(op.save!.skillGachaPity, 0);
    });

    test('하루 무료 — 젤리 없이 1회 · 날짜가 바뀌면 다시', () {
      final op = drawSkills(
        fresh(),
        cfg,
        Random(0),
        dayKey: day,
        times: 1,
        free: true,
      );
      expect(op.isOk, isTrue);
      expect(
        drawSkills(
          op.save!,
          cfg,
          Random(1),
          dayKey: day,
          times: 1,
          free: true,
        ).error,
        'no_free',
      );
      expect(
        drawSkills(
          op.save!,
          cfg,
          Random(1),
          dayKey: '2026-09-16',
          times: 1,
          free: true,
        ).isOk,
        isTrue,
      );
      expect(
        drawSkills(fresh(), cfg, Random(0), dayKey: day, times: 1).error,
        'not_enough_jelly',
      );
    });
  });

  group('소탕', () {
    const day = '2026-09-15';
    final run = RunConfig.fromJson(
      jsonDecode(File('../app/assets/data/run_config.json').readAsStringSync())
          as Map<String, dynamic>,
    );

    test('보스를 잡아 본 적 없으면 못 한다', () {
      expect(
        sweepBoss(fresh(), cfg, run, Random(0), dayKey: day).error,
        'no_boss',
      );
    });

    test('가장 높은 난이도 기준 확정 조각 · 무료 뒤엔 젤리 · 하루 상한', () {
      var s = fresh().copyWith(
        bossDex: {run.bossArtId(0, 1), run.bossArtId(2, 3)},
        materials: {MaterialKind.jelly: 10000},
      );
      expect(bestSweepTier(s, run), 2);
      for (var i = 0; i < cfg.sweepMaxPerDay; i++) {
        final op = sweepBoss(s, cfg, run, Random(i), dayKey: day);
        expect(op.isOk, isTrue, reason: 'sweep $i');
        final shards = op.extra['shards'] as Map<String, int>;
        expect(shards.values.single, cfg.sweepShardsFor(2));
        expect(
          op.extra['jelly'],
          i < cfg.sweepFreePerDay ? 0 : cfg.sweepJellyCost,
        );
        s = op.save!;
      }
      expect(
        sweepBoss(s, cfg, run, Random(99), dayKey: day).error,
        'sweep_limit',
      );
      expect(
        sweepBoss(s, cfg, run, Random(99), dayKey: '2026-09-16').isOk,
        isTrue,
      );
    });
  });

  group('뽑기·소탕 세이브', () {
    test('천장·하루 기록 왕복 · 기본값은 싣지 않는다', () {
      final s = fresh().copyWith(
        skillGachaPity: 7,
        skillDayKey: '2026-09-15',
        skillFreeDrawsUsed: 1,
        skillSweepsUsed: 4,
      );
      final back = SaveGame.fromJson(
        jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>,
      );
      expect(back.skillGachaPity, 7);
      expect(back.skillDayKey, '2026-09-15');
      expect(back.skillFreeDrawsUsed, 1);
      expect(back.skillSweepsUsed, 4);
      // 자동발동은 기본 켜짐 — 끈 것만 싣는다.
      expect(fresh().skillAutoCast, isTrue);
      expect(fresh().toJson().containsKey('skillAutoCast'), isFalse);
      final off = SaveGame.fromJson(
        jsonDecode(jsonEncode(fresh().copyWith(skillAutoCast: false).toJson()))
            as Map<String, dynamic>,
      );
      expect(off.skillAutoCast, isFalse);
      final empty = fresh().toJson();
      for (final k in [
        'skillGachaPity',
        'skillDayKey',
        'skillFreeDrawsUsed',
        'skillSweepsUsed',
      ]) {
        expect(empty.containsKey(k), isFalse, reason: k);
      }
    });
  });

  group('규칙 강제(업로드·로드)', () {
    test('만렙 초과 · 미보유 장착 · 칸 초과 · 중복 · 음수를 접는다', () {
      final ids = cfg.skills.map((d) => d.id).toList();
      final bad = fresh().copyWith(
        skillLevels: {ids[0]: 999, ids[1]: 1, ids[2]: 1, ids[3]: 0},
        equippedSkills: [ids[0], ids[0], ids[3], ids[1], ids[2]],
        skillShards: {ids[0]: -4, ids[1]: 3},
        skillGradeShards: {'rare': -10, 'epic': 2},
      );
      final s = enforceSkillRules(bad, cfg);
      expect(s.skillLevels[ids[0]], cfg.maxLevel);
      expect(s.skillLevels.containsKey(ids[3]), isFalse);
      expect(s.equippedSkills, [ids[0], ids[1]]); // 쉬움 = 2칸
      expect(s.skillShards, {ids[1]: 3});
      expect(s.skillGradeShards, {'epic': 2});
    });

    test('규칙 안이면 같은 객체를 돌려준다(불필요한 커밋 방지)', () {
      final ok = fresh().copyWith(
        skillLevels: {common.id: 2},
        equippedSkills: [common.id],
      );
      expect(identical(enforceSkillRules(ok, cfg), ok), isTrue);
    });
  });

  group('세이브 호환', () {
    test('왕복 · 빈 값은 싣지 않는다 · 반쪽 수련은 수련 없음으로', () {
      final s = fresh().copyWith(
        skillShards: {common.id: 7},
        skillGradeShards: {'legendary': 12},
        skillTrainingId: common.id,
        skillTrainingEndsAt: _t,
      );
      final back = SaveGame.fromJson(
        jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>,
      );
      expect(back.skillShards, {common.id: 7});
      expect(back.gradeShards(Grade.legendary), 12);
      expect(back.skillTrainingId, common.id);
      expect(back.skillTrainingEndsAt, _t);

      final empty = fresh().toJson();
      // skillGradeShards 는 표식이라 비어 있어도 싣는다(서버가 구버전 업로드를 알아본다).
      expect(empty['skillGradeShards'], isEmpty);
      for (final k in [
        'skillShards',
        'skillTrainingId',
        'skillTrainingEndsAt',
      ]) {
        expect(empty.containsKey(k), isFalse, reason: k);
      }

      final half = fresh().toJson()..['skillTrainingId'] = common.id;
      final parsed = SaveGame.fromJson(half);
      expect(parsed.skillTrainingId, isNull);
      expect(parsed.skillTrainingEndsAt, isNull);
    });
  });
}
