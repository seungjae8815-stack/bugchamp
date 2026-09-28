import 'dart:convert';
import 'dart:io';

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:test/test.dart';

void main() {
  final run = RunConfig.fromJson(
    jsonDecode(File('../app/assets/data/run_config.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  const tier = 3;
  final depth = run.zoneStartStage(run.zonesPerTier) - 1; // 극한 최종 사냥터

  group('심연 층 배율', () {
    test('1층은 극한 최종 사냥터 그대로', () {
      expect(
        habitatMaxHp(run, depth, tier: tier, abyssFloor: 1),
        habitatMaxHp(run, depth, tier: tier),
      );
      expect(
        rewardGold(run, depth, 1.0, tier: tier, abyssFloor: 1),
        rewardGold(run, depth, 1.0, tier: tier),
      );
    });

    test('층이 오르면 체력·보스·골드·표 위협이 오른다', () {
      int hp(int f) => habitatMaxHp(run, depth, tier: tier, abyssFloor: f);
      int boss(int f) => bossMaxHp(run, depth, tier: tier, abyssFloor: f);
      int gold(int f) => rewardGold(run, depth, 1.0, tier: tier, abyssFloor: f);
      double threat(int f) =>
          habitatThreat(run, depth, tier: tier, abyssFloor: f);
      for (final f in [2, 10, 50]) {
        expect(hp(f), greaterThan(hp(f - 1)), reason: 'hp $f');
        expect(boss(f), greaterThan(boss(f - 1)), reason: 'boss $f');
        expect(gold(f), greaterThan(gold(f - 1)), reason: 'gold $f');
        expect(threat(f), greaterThan(threat(f - 1)), reason: 'threat $f');
      }
    });

    test('골드는 체력보다 느리게 자란다(어딘가에서 벽 — 순위가 갈린다)', () {
      expect(run.abyss.goldGrowth, lessThan(run.abyss.hpGrowth));
    });

    test('숫자가 넘치지 않는다 — 깊은 층에서도 상한에서 멈춘다', () {
      for (final f in [100, 300, 1000, 5000]) {
        final hp = bossMaxHp(run, depth, tier: tier, abyssFloor: f);
        expect(hp, greaterThan(0), reason: 'floor $f');
        expect(hp, lessThanOrEqualTo(kMaxMonsterHp), reason: 'floor $f');
        final g = rewardGold(run, depth, 1.0, tier: tier, abyssFloor: f);
        expect(g, greaterThan(0));
        expect(g, lessThanOrEqualTo(kMaxCurrency));
      }
    });

    test('방치 정산도 층을 탄다(같은 시간이면 깊은 층일수록 처치가 적다)', () {
      final stats = deriveStats(
        run,
        upgradeLevels: {for (final k in UpgradeKind.values) k: 300},
        characterLevel: 100,
        bugsCollected: 50,
      );
      double clears(int f) => estimateClears(
        config: run,
        stageNumber: depth + 1,
        stats: stats,
        elapsed: const Duration(hours: 1),
        tier: tier,
        abyssFloor: f,
      );
      expect(clears(40), lessThan(clears(1)));
    });

    test('주간 순위 보상은 10위까지', () {
      expect(run.abyss.rankJelly(1), greaterThan(run.abyss.rankJelly(2)));
      expect(run.abyss.rankJelly(10), greaterThan(0));
      expect(run.abyss.rankJelly(11), 0);
    });
  });
}
