import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:test/test.dart';

/// 방치 정산의 버프(2026-10-14 사장님 확정) — `offline_buffs.dart`.
void main() {
  Map<String, dynamic> read(String f) =>
      jsonDecode(File('../app/assets/data/$f').readAsStringSync())
          as Map<String, dynamic>;
  final run = RunConfig.fromJson(read('run_config.json'));
  final buffs = BuffConfig.fromJson(read('buffs.json'));
  final fairy = FairyConfig.fromJson(read('fairies.json'));
  final stones = BattleConfig.fromJson(read('battle.json')).training.stones;
  final grade = PetConfig.fromJson(read('pets.json')).individualGrade;
  final species = (read('species.json')['species'] as List)
      .cast<Map<String, dynamic>>()
      .map(Species.fromJson)
      .toList();
  final t0 = DateTime.utc(2026, 10, 14, 0);
  final base = SaveGame.initial(createdAt: t0).copyWith(lastSeen: t0);
  final stats = deriveStats(
    run,
    upgradeLevels: base.upgradeLevels,
    characterLevel: base.level,
    bugsCollected: base.bugBuffCount,
  );
  OfflinePlan plan(List<BuffSpan> spans) => planOffline(
    config: run,
    base: stats,
    buffs: buffs,
    spans: spans,
    stageNumber: base.stageNumber,
    efficiency: run.offlineEfficiency,
  );
  const h8 = Duration(hours: 8);

  group('구간 나누기', () {
    test('버프가 없으면 한 토막(버프 없음)', () {
      final spans = offlineBuffSpans(base, t0, h8);
      expect(spans.length, 1);
      expect(spans.single.length, h8);
      expect(spans.single.active, isEmpty);
    });

    test('정산 중간에 끝나는 버프는 그 시각에서 잘린다', () {
      final s = base.copyWith(
        buffExpiry: {
          BuffKind.goldRush: t0.add(const Duration(hours: 2)),
          BuffKind.gatherer: t0.add(const Duration(hours: 5)),
          // 정산 전에 이미 끝난 버프는 없는 것과 같다.
          BuffKind.xpBoost: t0.subtract(const Duration(minutes: 1)),
        },
      );
      final spans = offlineBuffSpans(s, t0, h8);
      expect(spans.map((x) => x.length.inHours), [2, 3, 3]);
      expect(spans[0].active, {BuffKind.goldRush, BuffKind.gatherer});
      expect(spans[1].active, {BuffKind.gatherer});
      expect(spans[2].active, isEmpty);
    });

    test('정산 구간보다 길게 남은 버프는 끝까지 켜져 있다', () {
      final s = base.copyWith(
        buffExpiry: {BuffKind.frenzy: t0.add(const Duration(hours: 20))},
      );
      final spans = offlineBuffSpans(s, t0, h8);
      expect(spans.length, 1);
      expect(spans.single.active, {BuffKind.frenzy});
    });

    test('무한 버프 패스는 5종 전부 — 패스가 중간에 끝나면 거기서 잘린다', () {
      final on = base.copyWith(
        buffPassExpiresAt: t0.add(const Duration(days: 30)),
      );
      expect(
        offlineBuffSpans(on, t0, h8).single.active,
        BuffKind.values.toSet(),
      );
      final ends = base.copyWith(
        buffPassExpiresAt: t0.add(const Duration(hours: 3)),
      );
      final spans = offlineBuffSpans(ends, t0, h8);
      expect(spans.map((x) => x.length.inHours), [3, 5]);
      expect(spans[0].active, BuffKind.values.toSet());
      expect(spans[1].active, isEmpty);
    });
  });

  group('정산', () {
    test('골드 러시 2시간 = 골드 러시 2시간치 + 버프 없는 6시간치', () {
      final none = plan([const BuffSpan(h8, {})]);
      final s = base.copyWith(
        buffExpiry: {BuffKind.goldRush: t0.add(const Duration(hours: 2))},
      );
      final got = plan(offlineBuffSpans(s, t0, h8));
      final rush = plan([
        const BuffSpan(Duration(hours: 2), {BuffKind.goldRush}),
      ]).gold;
      final rest = plan([const BuffSpan(Duration(hours: 6), {})]).gold;
      expect(got.gold, rush + rest);
      expect(got.gold, greaterThan(none.gold));
      expect(got.accrued, h8);
      // 골드 러시는 처치 수를 안 바꾼다.
      expect(got.clears, closeTo(none.clears, 1e-6));
    });

    test('토막별 굴림 수의 합 = 전체 처치 수 내림', () {
      final s = base.copyWith(
        buffExpiry: {BuffKind.frenzy: t0.add(const Duration(minutes: 97))},
      );
      final p = plan(offlineBuffSpans(s, t0, h8));
      expect(p.rolls().fold<int>(0, (a, b) => a + b), p.clears.floor());
      final capped = p.rolls(maxRolls: 100);
      expect(capped.fold<int>(0, (a, b) => a + b), lessThanOrEqualTo(100));
    });
  });

  group('놓친 기댓값', () {
    OfflineGain expect0(OfflinePlan p, SaveGame s) => expectedOfflineGain(
      p,
      save: s,
      run: run,
      species: species,
      fairy: fairy,
      stones: stones,
      grade: grade,
      now: t0.add(h8),
    );

    test('버프 없음 → 5종 전부 켰다면: 골드·경험치·재료·곤충·희귀 드롭이 모두 늘어난다', () {
      final none = expect0(plan([const BuffSpan(h8, {})]), base);
      final full = expect0(plan([BuffSpan(h8, BuffKind.values.toSet())]), base);
      final missed = full.minus(none);
      expect(missed.gold, greaterThan(none.gold)); // 골드 ×2 · 광폭화 처치 수
      expect(missed.xp, greaterThan(0));
      expect(missed.materials, greaterThan(0));
      expect(missed.bugs, greaterThan(0));
      expect(missed.fairyStones, greaterThan(0));
      // 채집꾼(희귀 ×2)·광폭화(처치 수) — 속성석 기댓값이 두 배를 넘는다.
      // 채집꾼이 없던 사람은 방치 희귀 드롭이 0 — 전부 놓친 몫(2026-10-14 사장님 확정).
      expect(none.fairyStones, 0);
      expect(none.potions, 0);
      expect(full.fairyStones, greaterThan(0));
      expect(missed.isEmpty, isFalse);
    });

    test('무한 버프 패스면 놓친 몫이 없다', () {
      final s = base.copyWith(
        buffPassExpiresAt: t0.add(const Duration(days: 30)),
      );
      final got = expect0(plan(offlineBuffSpans(s, t0, h8)), s);
      final full = expect0(plan([BuffSpan(h8, BuffKind.values.toSet())]), s);
      expect(full.minus(got).isEmpty, isTrue);
    });

    test('곤충 기댓값은 채집함 여유분까지 · 물약은 오늘 남은 한도까지', () {
      final full = plan([BuffSpan(h8, BuffKind.values.toSet())]);
      final tight = base.copyWith(storageCapacity: base.bugs.length + 1);
      expect(expect0(full, tight).bugs, lessThanOrEqualTo(1));
      final day = dailyDateKey(t0.add(h8));
      final spent = base.copyWith(
        dailyClaims: {kPotionDropKey: '$day:${grade.potionDropDaily}'},
      );
      expect(expect0(full, spent).potions, 0);
    });
  });

  group('채집꾼 희귀 드롭 배율', () {
    test('buffs.json 채집꾼 rareDrop = 2, 다른 버프는 1', () {
      expect(rareDropMultOf({BuffKind.gatherer}, buffs), 2.0);
      expect(rareDropMultOf({BuffKind.goldRush, BuffKind.frenzy}, buffs), 1.0);
      expect(buffs.maxRareDropMult, 2.0);
    });

    test('같은 seed 에서 배율이 확률만 바꾼다(결투석 — 난수 소비 수 그대로)', () {
      const cfg = DuelStoneConfig(eliteChance: {DuelStone.element: 0.4});
      var on = 0, off = 0;
      for (var seed = 0; seed < 2000; seed++) {
        final a = rollDuelStones(
          base,
          cfg,
          Random(seed),
          DuelStoneSource.elite,
        );
        final b = rollDuelStones(
          base,
          cfg,
          Random(seed),
          DuelStoneSource.elite,
          rareMult: 2.0,
        );
        if (a.got.isNotEmpty) off++;
        if (b.got.isNotEmpty) on++;
        // 배율이 없을 때 나온 seed 는 배율이 있어도 나온다.
        if (a.got.isNotEmpty) expect(b.got.isNotEmpty, isTrue);
      }
      expect(off / 2000, closeTo(0.4, 0.05));
      expect(on / 2000, closeTo(0.8, 0.05));
    });

    test('요정 정예 속성석 · 물약도 배율을 받는다', () {
      var off = 0, on = 0, pOff = 0, pOn = 0;
      for (var seed = 0; seed < 20000; seed++) {
        final a = fairyEliteDrop(base.fairy, fairy, Random(seed));
        final b = fairyEliteDrop(
          base.fairy,
          fairy,
          Random(seed),
          stoneMult: 2.0,
        );
        if ((a.extra['stones'] as Map?)?.isNotEmpty ?? false) off++;
        if ((b.extra['stones'] as Map?)?.isNotEmpty ?? false) on++;
        final pa = rollPotionDrop(
          base,
          grade,
          Random(seed),
          PotionSource.elite,
        );
        final pb = rollPotionDrop(
          base,
          grade,
          Random(seed),
          PotionSource.elite,
          rareMult: 2.0,
        );
        pOff += pa.got;
        pOn += pb.got;
      }
      expect(on, greaterThan(off * 1.6));
      expect(pOn, greaterThan(pOff));
    });

    test('방치 정예 드롭 — 처치 × 정예 비율로 굴리고 물약은 하루 한도', () {
      final r = rollIdleRareDrops(
        base,
        rolls: 200000,
        run: run,
        fairy: fairy,
        stones: stones,
        grade: grade,
        rareMult: 2.0,
        now: t0,
        rng: Random(1),
      );
      final elites = 200000 * run.eliteChance;
      expect(
        r.fairyStones,
        closeTo(elites * fairy.drops.eliteStoneChance * 2, elites * 0.01),
      );
      expect(
        r.save.fairy.stones.values.fold<int>(0, (a, b) => a + b),
        r.fairyStones,
      );
      expect(r.duelStones.values.fold<int>(0, (a, b) => a + b), greaterThan(0));
      expect(r.potions, grade.potionDropDaily);
      expect(r.save.growthPotions, grade.potionDropDaily);
      expect(potionDropsOn(r.save, dailyDateKey(t0)), grade.potionDropDaily);
      // 정예가 없으면 아무것도 없다.
      final none = rollIdleRareDrops(
        base,
        rolls: 0,
        run: run,
        fairy: fairy,
        stones: stones,
        grade: grade,
        rareMult: 2.0,
        now: t0,
        rng: Random(1),
      );
      expect(identical(none.save, base), isTrue);
      // 채집꾼이 꺼져 있으면(배율 1) 방치 희귀 드롭은 없다(2026-10-14 사장님 확정 — 버프 켠 사람만).
      final off = rollIdleRareDrops(
        base,
        rolls: 200000,
        run: run,
        fairy: fairy,
        stones: stones,
        grade: grade,
        rareMult: 1.0,
        now: t0,
        rng: Random(1),
      );
      expect(identical(off.save, base), isTrue);
      expect(off.fairyStones + off.potions, 0);
      expect(idleRareDropsOn(1.0), isFalse);
      expect(idleRareDropsOn(2.0), isTrue);
    });
  });

  group('서버 업로드 허용치', () {
    test('60초 업로드는 작고, 8시간은 정상 기댓값보다 넉넉하다', () {
      final m = rareDropUploadAllowance(
        elapsed: const Duration(seconds: 60),
        run: run,
        fairy: fairy,
        stones: stones,
        buffs: buffs,
      );
      expect(m.fairyStones, lessThanOrEqualTo(2));
      final h = rareDropUploadAllowance(
        elapsed: h8,
        run: run,
        fairy: fairy,
        stones: stones,
        buffs: buffs,
      );
      // 정상 8시간 방치(5종 다 켬) 기댓값의 몇 배.
      final full = expectedOfflineGain(
        plan([BuffSpan(h8, BuffKind.values.toSet())]),
        save: base,
        run: run,
        species: species,
        fairy: fairy,
        stones: stones,
        grade: grade,
        now: t0,
      );
      expect(h.fairyStones, greaterThan(full.fairyStones * 5));
      expect(h.duelStones, greaterThan(full.duelStones * 5));
      // 하루를 넘는 공백은 하루치까지만.
      final long = rareDropUploadAllowance(
        elapsed: const Duration(days: 30),
        run: run,
        fairy: fairy,
        stones: stones,
        buffs: buffs,
      );
      final day = rareDropUploadAllowance(
        elapsed: const Duration(days: 1),
        run: run,
        fairy: fairy,
        stones: stones,
        buffs: buffs,
      );
      expect(long.fairyStones, day.fairyStones);
    });
  });
}
