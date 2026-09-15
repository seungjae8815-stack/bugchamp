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

    test('만렙 스킬로 들어온 조각은 만능 조각(등급 환산값)으로 바뀐다', () {
      final maxed = fresh().copyWith(skillLevels: {legend.id: cfg.maxLevel});
      final s = grantSkillShards(maxed, cfg, {legend.id: 4});
      expect(s.skillShards[legend.id], isNull);
      expect(s.skillAnyShards, 4 * cfg.anyValueOf(Grade.legendary));
    });
  });

  group('수련', () {
    SaveGame owned({int lv = 1, int shards = 0, int any = 0, int jelly = 0}) =>
        fresh().copyWith(
          skillLevels: {common.id: lv},
          skillShards: shards > 0 ? {common.id: shards} : const {},
          skillAnyShards: any,
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

    test('조각이 모자라면 만능으로 메운다 — 모자란 1개당 그 등급 환산값', () {
      final need = cfg.shardsForLevel(common, 1);
      final value = cfg.anyValueOf(common.grade);
      final short = startSkillTraining(
        owned(shards: need - 2, any: 2 * value - 1),
        cfg,
        common.id,
        _t,
      );
      expect(short.error, 'not_enough_shards');
      final ok = startSkillTraining(
        owned(shards: need - 2, any: 2 * value),
        cfg,
        common.id,
        _t,
      );
      expect(ok.isOk, isTrue);
      expect(ok.save!.skillAnyShards, 0);
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

    test('만렙에 닿으면 남은 그 스킬 조각이 만능으로 바뀐다', () {
      final need = cfg.shardsForLevel(common, cfg.maxLevel - 1);
      final s = startSkillTraining(
        owned(lv: cfg.maxLevel - 1, shards: need + 5),
        cfg,
        common.id,
        _t,
      ).save!;
      final done = completeSkillTraining(s, cfg, s.skillTrainingEndsAt!).save!;
      expect(done.skillLevels[common.id], cfg.maxLevel);
      expect(done.skillShards[common.id], isNull);
      expect(done.skillAnyShards, 5 * cfg.anyValueOf(common.grade));
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

  group('보스 조각', () {
    test('같은 시드면 같은 조각 · 해금까지 이어진다', () {
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
      expect(a.shards, isNotEmpty);
      expect(a.save.skillShards, b.save.skillShards);
    });
  });

  group('규칙 강제(업로드·로드)', () {
    test('만렙 초과 · 미보유 장착 · 칸 초과 · 중복 · 음수를 접는다', () {
      final ids = cfg.skills.map((d) => d.id).toList();
      final bad = fresh().copyWith(
        skillLevels: {ids[0]: 999, ids[1]: 1, ids[2]: 1, ids[3]: 0},
        equippedSkills: [ids[0], ids[0], ids[3], ids[1], ids[2]],
        skillShards: {ids[0]: -4, ids[1]: 3},
        skillAnyShards: -10,
      );
      final s = enforceSkillRules(bad, cfg);
      expect(s.skillLevels[ids[0]], cfg.maxLevel);
      expect(s.skillLevels.containsKey(ids[3]), isFalse);
      expect(s.equippedSkills, [ids[0], ids[1]]); // 쉬움 = 2칸
      expect(s.skillShards, {ids[1]: 3});
      expect(s.skillAnyShards, 0);
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
        skillAnyShards: 12,
        skillTrainingId: common.id,
        skillTrainingEndsAt: _t,
      );
      final back = SaveGame.fromJson(
        jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>,
      );
      expect(back.skillShards, {common.id: 7});
      expect(back.skillAnyShards, 12);
      expect(back.skillTrainingId, common.id);
      expect(back.skillTrainingEndsAt, _t);

      final empty = fresh().toJson();
      // skillAnyShards 는 표식이라 0 이어도 싣는다(서버가 구버전 업로드를 알아본다).
      expect(empty['skillAnyShards'], 0);
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
