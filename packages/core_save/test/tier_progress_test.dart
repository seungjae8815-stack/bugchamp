import 'dart:convert';
import 'dart:io';

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:test/test.dart';

/// 난이도 이동 규칙(2026-09-15 사장님 결정 B안) — `tier_progress.dart`.
void main() {
  final run = RunConfig.fromJson(
    jsonDecode(File('../app/assets/data/run_config.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  final finalStart = run.zoneStartStage(run.zonesPerTier);

  SaveGame grown({int tier = 0, int stage = 501, int best = 501}) =>
      SaveGame.initial(createdAt: DateTime.utc(2026, 1, 1)).copyWith(
        stageNumber: stage,
        bestStage: best,
        difficultyTier: tier,
        maxTierReached: tier,
        level: 54,
        gold: 113000000000000,
        zoneKills: 60,
        upgradeLevels: const {UpgradeKind.attack: 200},
        materials: const {MaterialKind.chitin: 5000, MaterialKind.jelly: 300},
      );

  group('처음 가는 난이도', () {
    test('성장 축 초기화 + 최고 난이도·최고 기록 갱신', () {
      final s = enterNextTierSave(grown(stage: finalStart), run);
      expect(s.difficultyTier, 1);
      expect(s.maxTierReached, 1);
      expect(s.stageNumber, 1);
      expect(s.upgradeLevels, isEmpty);
      expect(s.gold, 0);
      expect(s.level, 1);
      expect(s.materialCount(MaterialKind.chitin), 0);
      expect(s.materialCount(MaterialKind.jelly), 300, reason: '젤리는 남는다');
      // 쉬움 최종(1001)이 남으면 랭킹에 '보통 · 최종'으로 떴다.
      expect(s.bestStage, 0);
    });
  });

  group('가 본 난이도 사이 이동', () {
    // 보통(1)까지 가 봤고 보통 사냥터 5 에 있는 유저.
    SaveGame normal() => grown(tier: 1, stage: 401, best: 401);

    test('아래로 내려가면 그 난이도의 최종 사냥터 · 초기화 없음', () {
      final s = selectTierSave(normal(), run, 0);
      expect(s.difficultyTier, 0);
      expect(s.maxTierReached, 1);
      expect(s.stageNumber, finalStart);
      expect(s.upgradeLevels[UpgradeKind.attack], 200);
      expect(s.gold, 113000000000000);
      expect(s.zoneKills, 0);
      // 아래 난이도는 다 깬 곳이다.
      expect(s.highestStageInTier(run), greaterThan(finalStart));
    });

    test('다시 올라가면 거기서 점령한 사냥터로 · 초기화 없음', () {
      final down = selectTierSave(normal(), run, 0);
      final back = enterNextTierSave(
        down.copyWith(stageNumber: finalStart),
        run,
      );
      expect(back.difficultyTier, 1);
      expect(back.stageNumber, 401);
      expect(back.upgradeLevels[UpgradeKind.attack], 200);
      expect(back.gold, 113000000000000);
    });

    test('가 보지 않은 난이도는 고를 수 없다', () {
      final s = selectTierSave(normal(), run, 3);
      expect(s.difficultyTier, 1);
    });

    test('랭킹은 내려가 있어도 최고 난이도의 최고 기록', () {
      final down = selectTierSave(normal(), run, 0);
      expect(down.rankProgress, (tier: 1, stage: 401));
    });
  });

  test('maxTierReached 는 JSON 을 왕복하고, 없던 세이브는 지금 난이도로 본다', () {
    final s = grown(tier: 2);
    expect(SaveGame.fromJson(s.toJson()).maxTierReached, 2);
    final old = s.toJson()..remove('maxTierReached');
    expect(SaveGame.fromJson(old).topTier, 2);
  });
}
