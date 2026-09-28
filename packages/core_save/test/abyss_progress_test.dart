import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:test/test.dart';

void main() {
  final run = RunConfig.fromJson(
    jsonDecode(File('../app/assets/data/run_config.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  final t0 = DateTime.utc(2026, 9, 29, 3);
  const w1 = '2026-09-28';
  const w2 = '2026-10-05';
  SaveGame base() => SaveGame.initial(createdAt: t0).copyWith(
    difficultyTier: 3,
    maxTierReached: 3,
    stageNumber: abyssStage(run),
  );

  test('열리기 전에는 들어갈 수 없다', () {
    final s = enterAbyss(base(), run, w1);
    expect(s.inAbyss, isFalse);
  });

  test('들어가면 극한 끝에 고정되고 게이지가 비워진다 · 나오면 층은 그 주 동안 남는다', () {
    var s = unlockAbyss(
      base(),
    ).copyWith(zoneKills: 57, abyssFloor: 4, abyssWeek: w1);
    s = enterAbyss(s, run, w1);
    expect(s.inAbyss, isTrue);
    expect(s.difficultyTier, abyssTier(run));
    expect(s.stageNumber, abyssStage(run));
    expect(s.zoneKills, 0);
    expect(s.abyssFloor, 4);
    expect(activeAbyssFloor(s), 4);
    s = leaveAbyss(s);
    expect(activeAbyssFloor(s), 0);
    expect(s.abyssFloor, 4);
  });

  test('주가 바뀌면 1층부터(A안) — 역대 최고는 남는다', () {
    final s = unlockAbyss(
      base(),
    ).copyWith(abyssFloor: 30, abyssBest: 29, abyssWeek: w1);
    final next = applyAbyssWeek(s, w2);
    expect(next.abyssFloor, 1);
    expect(next.abyssBest, 29);
    expect(next.abyssWeek, w2);
    // 같은 주면 그대로.
    expect(identical(applyAbyssWeek(s, w1), s), isTrue);
  });

  test('층을 깨면 다음 층 · 10층마다 **처음** 깰 때만 마일스톤', () {
    var s = unlockAbyss(base()).copyWith(abyssFloor: 9, abyssWeek: w1);
    var r = clearAbyssFloor(s, run);
    expect(r.save.abyssFloor, 10);
    expect(r.milestone, isFalse);
    r = clearAbyssFloor(r.save, run);
    expect(r.save.abyssFloor, 11);
    expect(r.save.abyssBest, 10);
    expect(r.milestone, isTrue);
    expect(
      r.save.materialCount(MaterialKind.fossil),
      run.abyss.milestoneFossil,
    );
    // 다음 주에 다시 10층을 깨도 마일스톤은 한 번뿐이다.
    s = applyAbyssWeek(r.save, w2).copyWith(abyssFloor: 10);
    r = clearAbyssFloor(s, run);
    expect(r.milestone, isFalse);
  });

  test('마일스톤 층은 스킬 조각이 확정된다(보스 첫 처치와 같은 규칙)', () {
    final skill = SkillConfig.fromJson(
      jsonDecode(File('../app/assets/data/skills.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    final s = unlockAbyss(base()).copyWith(abyssFloor: 10, abyssWeek: w1);
    final r = clearAbyssFloor(s, run, skill: skill, rng: Random(1));
    expect(r.milestone, isTrue);
    expect(r.shards.values.fold<int>(0, (a, b) => a + b), greaterThan(0));
  });

  test('세이브 JSON 왕복', () {
    final s = unlockAbyss(base()).copyWith(
      inAbyss: true,
      abyssFloor: 17,
      abyssWeek: w1,
      abyssBest: 40,
      abyssScoreWeek: w1,
      abyssRewardWeek: '2026-09-21',
    );
    final back = SaveGame.fromJson(s.toJson());
    expect(back.abyssUnlocked, isTrue);
    expect(back.inAbyss, isTrue);
    expect(back.abyssFloor, 17);
    expect(back.abyssWeek, w1);
    expect(back.abyssBest, 40);
    expect(back.abyssScoreWeek, w1);
    expect(back.abyssRewardWeek, '2026-09-21');
    // 기본값은 싣지 않는다(세이브 크기).
    final plain = base().toJson();
    expect(
      plain.keys.where((k) => k.startsWith('abyss') || k == 'inAbyss'),
      isEmpty,
    );
  });

  test('벽 보스 피해 — 이번 주 막힌 층의 최고치만 · 층을 깨거나 주가 바뀌면 0', () {
    var s = unlockAbyss(
      base(),
    ).copyWith(inAbyss: true, abyssFloor: 12, abyssWeek: w1);
    s = recordAbyssBossDamage(s, 0.42);
    expect(s.abyssBossBest, 420);
    s = recordAbyssBossDamage(s, 0.3);
    expect(s.abyssBossBest, 420, reason: '낮은 기록은 덮지 않는다');
    s = recordAbyssBossDamage(s, 1.2);
    expect(s.abyssBossBest, 999, reason: '잡지 못했으면 100% 가 아니다');
    expect(clearAbyssFloor(s, run).save.abyssBossBest, 0);
    expect(applyAbyssWeek(s, w2).abyssBossBest, 0);
    // 심연 밖에서는 기록하지 않는다.
    expect(recordAbyssBossDamage(leaveAbyss(s), 0.9).abyssBossBest, 999);
  });
}
