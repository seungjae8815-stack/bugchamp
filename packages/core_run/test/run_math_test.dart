import 'package:core_run/core_run.dart';
import 'package:test/test.dart';

RunConfig _config() => RunConfig.fromJson({
  'hpBase': 20.0,
  'hpGrowth': 1.2,
  'bossHpMult': 5.0,
  'goldBase': 10.0,
  'goldGrowth': 1.1,
  'xpBase': 4.0,
  'xpGrowth': 1.1,
  'bossRewardMult': 8.0,
  'habitatsPerStage': 5,
  'bugDropChance': 0.1,
  'materialDropChance': 0.5,
  'region': {
    'id': 'oak_forest',
    'name': {'ko': '숲', 'en': 'Forest', 'ja': '森'},
    'bossName': {'ko': '보스', 'en': 'Boss', 'ja': 'ボス'},
    'habitatKinds': ['tree', 'rock', 'flower'],
  },
  'upgrades': [
    {
      'kind': 'attack',
      'baseCost': 15.0,
      'costGrowth': 1.15,
      'baseValue': 6.0,
      'perLevel': 4.0,
    },
    {
      'kind': 'attackSpeed',
      'baseCost': 30.0,
      'costGrowth': 1.2,
      'baseValue': 1.0,
      'perLevel': 0.06,
    },
    {
      'kind': 'reward',
      'baseCost': 45.0,
      'costGrowth': 1.25,
      'baseValue': 1.0,
      'perLevel': 0.08,
    },
  ],
});

void main() {
  final c = _config();

  group('HP 스케일링', () {
    test('depth 0 = hpBase, 깊어질수록 증가', () {
      expect(habitatMaxHp(c, 0), 20);
      expect(habitatMaxHp(c, 1), 24); // 20*1.2
      expect(habitatMaxHp(c, 5), greaterThan(habitatMaxHp(c, 4)));
    });

    test('보스 HP = 서식지 × bossHpMult', () {
      expect(bossMaxHp(c, 0), (20 * 5.0).round());
    });
  });

  group('보상', () {
    test('골드는 깊이·보상배율에 비례, 보스는 배수', () {
      expect(rewardGold(c, 0, 1.0), 10);
      expect(rewardGold(c, 0, 2.0), 20);
      expect(rewardGold(c, 0, 1.0, boss: true), 80); // 10 * 8
      expect(
        rewardGold(c, 3, 1.0, boss: true),
        greaterThan(rewardGold(c, 3, 1.0)),
      );
    });

    test('경험치도 보스 배수', () {
      expect(rewardXp(c, 0), 4);
      expect(rewardXp(c, 0, boss: true), 32); // 4*8
    });
  });

  group('업그레이드', () {
    test('비용은 레벨에 지수 증가', () {
      final spec = c.upgrade(UpgradeKind.attack);
      expect(upgradeCost(spec, 0), 15);
      expect(upgradeCost(spec, 5), greaterThan(upgradeCost(spec, 4)));
    });

    test('스탯 값은 레벨에 선형', () {
      final spec = c.upgrade(UpgradeKind.attack);
      expect(spec.valueAt(0), 6);
      expect(spec.valueAt(3), 6 + 4 * 3);
    });

    test('배치 비용 = 개별 비용 합', () {
      final spec = c.upgrade(UpgradeKind.attack);
      expect(
        bulkUpgradeCost(spec, 0, 3),
        upgradeCost(spec, 0) + upgradeCost(spec, 1) + upgradeCost(spec, 2),
      );
      expect(bulkUpgradeCost(spec, 5, 1), upgradeCost(spec, 5));
    });
  });

  group('deriveStats', () {
    test('업그레이드 레벨이 공격력을 올림', () {
      final s0 = deriveStats(
        c,
        upgradeLevels: {},
        characterLevel: 1,
        bugsCollected: 0,
      );
      final s1 = deriveStats(
        c,
        upgradeLevels: {UpgradeKind.attack: 5},
        characterLevel: 1,
        bugsCollected: 0,
      );
      expect(s1.attack, greaterThan(s0.attack));
      expect(s0.attack, 6); // baseValue, lv1 캐릭터
    });

    test('곤충 수집이 보상배율 버프', () {
      final s0 = deriveStats(
        c,
        upgradeLevels: {},
        characterLevel: 1,
        bugsCollected: 0,
      );
      final s1 = deriveStats(
        c,
        upgradeLevels: {},
        characterLevel: 1,
        bugsCollected: 20,
      );
      expect(s1.rewardMultiplier, greaterThan(s0.rewardMultiplier));
    });

    test('attackInterval = 1/attackSpeed', () {
      final s = deriveStats(
        c,
        upgradeLevels: {},
        characterLevel: 1,
        bugsCollected: 0,
      );
      expect(s.attackSpeed, 1.0);
      expect(s.attackInterval, const Duration(seconds: 1));
    });
  });

  group('computeOfflineReward', () {
    final stats = deriveStats(
      c,
      upgradeLevels: {},
      characterLevel: 1,
      bugsCollected: 0,
    );

    test('경과 0 이면 보상 없음', () {
      expect(
        computeOfflineReward(
          config: c,
          stageNumber: 1,
          stats: stats,
          elapsed: Duration.zero,
        ).isEmpty,
        isTrue,
      );
    });

    test('경과가 길수록 보상 증가, 8h 상한', () {
      final r1 = computeOfflineReward(
        config: c,
        stageNumber: 1,
        stats: stats,
        elapsed: const Duration(hours: 1),
      );
      final r4 = computeOfflineReward(
        config: c,
        stageNumber: 1,
        stats: stats,
        elapsed: const Duration(hours: 4),
      );
      final r100 = computeOfflineReward(
        config: c,
        stageNumber: 1,
        stats: stats,
        elapsed: const Duration(hours: 100),
      );
      expect(r4.gold, greaterThan(r1.gold));
      expect(r100.accrued, const Duration(hours: 8));
    });
  });

  group('regionForStage', () {
    test('스테이지에 따라 지역 전환 (단일 지역이면 항상 동일)', () {
      expect(c.regionForStage(1).id, c.regions.first.id);
      expect(c.regionForStage(999).id, c.regions.last.id);
    });
  });

  group('habitatThreat (적 반격)', () {
    test('기본값 적용 + 보스/깊이에 따라 증가', () {
      expect(habitatThreat(c, 0), c.threatBase);
      expect(habitatThreat(c, 0, boss: true), greaterThan(habitatThreat(c, 0)));
      expect(habitatThreat(c, 4), greaterThan(habitatThreat(c, 0)));
    });
  });

  group('deriveStats 중립값', () {
    test('미설정 스탯은 중립값으로 채워짐', () {
      final s = deriveStats(
        c,
        upgradeLevels: {},
        characterLevel: 1,
        bugsCollected: 0,
      );
      expect(s.maxHp, 100);
      expect(s.defense, 0);
      expect(s.critChance, 0);
      expect(s.critDamage, 2.0);
      expect(s.bossDamage, 1.0);
      expect(s.moveSpeed, 1.0);
    });
  });

  group('habitatKindAt', () {
    test('결정론적이고 범위 내', () {
      for (var st = 1; st <= 10; st++) {
        for (var h = 0; h < 5; h++) {
          final k = habitatKindAt(c, st, h);
          expect(c.region.habitatKinds.contains(k), isTrue);
          expect(habitatKindAt(c, st, h), k); // 재현
        }
      }
    });
  });

  group('xpForNextLevel', () {
    test('레벨이 오를수록 필요 경험치 증가', () {
      expect(xpForNextLevel(1), 25);
      expect(xpForNextLevel(3), greaterThan(xpForNextLevel(2)));
    });
  });
}
