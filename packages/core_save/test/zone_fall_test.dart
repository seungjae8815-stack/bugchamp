import 'dart:convert';
import 'dart:io';

import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:test/test.dart';

/// 쓰러지면 아래로(2026-10-05 사장님 확정) — `zone_fall.dart`.
void main() {
  final run = RunConfig.fromJson(
    jsonDecode(File('../app/assets/data/run_config.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  int z(int zone) => run.zoneStartStage(zone);
  final last = run.zonesPerTier;
  final full = run.bossUnlockKills;

  SaveGame at({int tier = 1, int zone = 6, int top = 1, int bestZone = 6}) =>
      SaveGame.initial(createdAt: DateTime.utc(2026, 1, 1)).copyWith(
        difficultyTier: tier,
        maxTierReached: top,
        stageNumber: z(zone),
        bestStage: z(bestZone),
        zoneKills: 37,
      );

  group('쓰러짐', () {
    test('한 칸 아래 사냥터 · 보스 도전 열림 · 한계도 그 칸', () {
      final s = fallOnDefeat(at(), run);
      expect(s.difficultyTier, 1);
      expect(s.stageNumber, z(5));
      expect(s.zoneKills, full);
      expect((s.capTier, s.capStage), (1, z(5)));
      expect(s.bestStage, z(6), reason: '역대 기록은 건드리지 않는다');
      expect(s.maxTierReached, 1);
    });

    test('사냥터 1 은 난이도를 넘지 않는다(이전 난이도 최종이 더 세다) — 게이지만', () {
      final s = fallOnDefeat(at(tier: 2, zone: 1, top: 2, bestZone: 1), run);
      expect(s.difficultyTier, 2);
      expect(s.stageNumber, z(1));
      expect(s.zoneKills, 0);
      expect(s.capStage, 0);
    });

    test('가 본 최고보다 아래 칸에서 쓰러지면 게이지만(한계를 걸지 않는다)', () {
      // 보통 사냥터 6 까지 간 유저가 쉬움 최종을 구경하다 쓰러짐.
      final low = fallOnDefeat(
        at(tier: 0, zone: last, top: 1, bestZone: 6),
        run,
      );
      expect(low.difficultyTier, 0);
      expect(low.stageNumber, z(last));
      expect(low.capStage, 0);
      expect(selectTierSave(low, run, 1).difficultyTier, 1, reason: '돌아갈 수 있다');
      // 같은 난이도 아래 칸도 마찬가지.
      final same = fallOnDefeat(at(zone: 3, bestZone: 8), run);
      expect(same.stageNumber, z(3));
      expect(same.capStage, 0);
    });

    test('한계 칸에서 또 쓰러지면 한 칸 더 내려간다', () {
      final once = fallOnDefeat(at(), run);
      final twice = fallOnDefeat(once.copyWith(zoneKills: 0), run);
      expect(twice.stageNumber, z(4));
      expect(twice.capStage, z(4));
    });

    test('쉬움 사냥터 1 은 게이지만 비운다', () {
      final s = fallOnDefeat(at(tier: 0, zone: 1, top: 0, bestZone: 1), run);
      expect(s.stageNumber, z(1));
      expect(s.zoneKills, 0);
      expect(s.capStage, 0);
    });

    test('심연 N층 → N-1층(벽 보스 기록 비움)', () {
      final s = fallOnDefeat(
        at(tier: 3, zone: last, top: 3, bestZone: last).copyWith(
          abyssUnlocked: true,
          inAbyss: true,
          abyssFloor: 9,
          abyssBossBest: 400,
        ),
        run,
      );
      expect(s.inAbyss, isTrue);
      expect(s.abyssFloor, 8);
      expect(s.abyssBossBest, 0);
      expect(s.zoneKills, full);
    });

    test('심연 1층 → 극한 최종 사냥터 · 다시 들어가려면 최종 보스부터', () {
      final s = fallOnDefeat(
        at(
          tier: 3,
          zone: last,
          top: 3,
          bestZone: last,
        ).copyWith(abyssUnlocked: true, inAbyss: true, abyssFloor: 1),
        run,
      );
      expect(s.inAbyss, isFalse);
      expect(s.stageNumber, z(last));
      expect((s.capTier, s.capStage), (3, z(last)));
      expect(
        enterAbyss(s, run, 'w').inAbyss,
        isFalse,
        reason: '한계가 있으면 못 들어간다',
      );
      final back = liftClimbCap(s, run, tier: 3, zone: last);
      expect(back.capStage, 0);
      expect(enterAbyss(back, run, 'w').inAbyss, isTrue);
    });
  });

  group('한계', () {
    test('로드맵은 한계 위로 못 간다 · 랭킹도 한계', () {
      final s = fallOnDefeat(at(tier: 2, zone: 4, top: 2, bestZone: 4), run);
      expect(s.highestStageInTier(run), z(3));
      expect(s.rankProgress, (tier: 2, stage: z(3)));
      // 아래 난이도로는 가고, 한계 난이도로 돌아오면 한계 칸에 선다.
      final down = selectTierSave(s, run, 1);
      expect(down.difficultyTier, 1);
      expect(selectTierSave(down, run, 2).stageNumber, z(3));
    });

    test('보스를 잡으면 한 칸씩 오르고, 가 본 최고 자리에 닿으면 풀린다', () {
      var s = fallOnDefeat(fallOnDefeat(at(bestZone: 6), run), run);
      expect(s.capStage, z(4));
      s = liftClimbCap(s, run, tier: 1, zone: 4);
      expect(s.capStage, z(5));
      expect(s.rankProgress, (tier: 1, stage: z(5)));
      s = liftClimbCap(s, run, tier: 1, zone: 5);
      expect(s.capStage, 0, reason: '사냥터 6(가 본 최고)에 닿았다');
    });

    test('한계 아래 보스를 다시 잡아도 한계는 그대로', () {
      final s = fallOnDefeat(at(), run);
      expect(liftClimbCap(s, run, tier: 1, zone: 2).capStage, z(5));
    });

    // 보스 자동 도전(앱, 2026-10-09)이 같은 판정을 쓴다 — 앞 칸에서만 자동.
    test('앞 칸 판정: 가 본 최고 칸·한계 칸·심연은 앞 칸, 로드맵으로 내려간 칸은 아니다', () {
      expect(atClimbFront(at(), run), isTrue, reason: '가 본 최고 사냥터');
      expect(atClimbFront(at(zone: 3, bestZone: 8), run), isFalse);
      expect(
        atClimbFront(at(tier: 0, zone: last, top: 1, bestZone: 6), run),
        isFalse,
        reason: '아래 난이도',
      );
      final fell = fallOnDefeat(at(), run);
      expect(atClimbFront(fell, run), isTrue, reason: '쓰러져 내려온 한계 칸');
      expect(
        atClimbFront(fell.copyWith(stageNumber: z(2)), run),
        isFalse,
        reason: '한계보다 아래',
      );
      final abyss = at(
        tier: 3,
        zone: last,
        top: 3,
        bestZone: last,
      ).copyWith(abyssUnlocked: true);
      expect(atClimbFront(enterAbyss(abyss, run, 'w'), run), isTrue);
    });

    test('세이브 왕복', () {
      final s = fallOnDefeat(at(), run);
      final back = SaveGame.fromJson(s.toJson());
      expect((back.capTier, back.capStage), (1, z(5)));
      expect(SaveGame.fromJson(at().toJson()).capStage, 0);
      expect(at().toJson().containsKey('capS'), isFalse);
    });
  });
}
