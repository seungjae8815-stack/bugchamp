import 'package:core_run/core_run.dart';
import 'package:test/test.dart';

Map<String, dynamic> _baseJson() => {
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
};

RunConfig _config() => RunConfig.fromJson(_baseJson());

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

  group('simulateIdleProgress — 스테이지 진행', () {
    // 강한 캐릭터(빠르게 스테이지를 민다)와 약한 캐릭터(거의 못 민다).
    final strong = deriveStats(
      c,
      upgradeLevels: {UpgradeKind.attack: 60, UpgradeKind.attackSpeed: 30},
      characterLevel: 20,
      bugsCollected: 10,
    );
    final weak = deriveStats(
      c,
      upgradeLevels: {},
      characterLevel: 1,
      bugsCollected: 0,
    );

    test('경과 0 이면 진행 없음, 스테이지 유지', () {
      final r = simulateIdleProgress(
        config: c,
        startStage: 7,
        stats: strong,
        elapsed: Duration.zero,
      );
      expect(r.isEmpty, isTrue);
      expect(r.newStage, 7);
    });

    test('dps 가 0 이면 스테이지만 유지', () {
      final noDmg = deriveStats(
        c,
        upgradeLevels: {UpgradeKind.attack: 0},
        characterLevel: 1,
        bugsCollected: 0,
      );
      // attack 은 0 이 아니어도, 인위적으로 0 dps 를 만들 순 없으니
      // 최소 진행만 확인(약캐는 오래 걸려도 결국 조금은 민다).
      final r = simulateIdleProgress(
        config: c,
        startStage: 1,
        stats: noDmg,
        elapsed: const Duration(seconds: 1),
      );
      expect(r.newStage, greaterThanOrEqualTo(1));
    });

    test('시간이 길수록 스테이지가 오른다', () {
      final short = simulateIdleProgress(
        config: c,
        startStage: 1,
        stats: strong,
        elapsed: const Duration(minutes: 5),
      );
      final long = simulateIdleProgress(
        config: c,
        startStage: 1,
        stats: strong,
        elapsed: const Duration(hours: 2),
      );
      expect(long.newStage, greaterThan(short.newStage));
      expect(long.gold, greaterThan(short.gold));
    });

    test('스테이지를 넘기면 보스도 잡힌다(bossClears)', () {
      final r = simulateIdleProgress(
        config: c,
        startStage: 1,
        stats: strong,
        elapsed: const Duration(hours: 1),
      );
      expect(r.newStage, greaterThan(1));
      // 스테이지를 N칸 올렸으면 보스도 N마리 잡은 것.
      expect(r.bossClears, r.newStage - 1);
      expect(r.habitatClears, greaterThan(0));
    });

    test('8h 상한: 100h 나 8h 나 진행이 같다', () {
      final r8 = simulateIdleProgress(
        config: c,
        startStage: 1,
        stats: strong,
        elapsed: const Duration(hours: 8),
      );
      final r100 = simulateIdleProgress(
        config: c,
        startStage: 1,
        stats: strong,
        elapsed: const Duration(hours: 100),
      );
      expect(r100.newStage, r8.newStage);
      expect(r100.gold, r8.gold);
    });

    test('약캐는 보스를 못 넘겨 스테이지가 거의 안 오른다', () {
      final strongR = simulateIdleProgress(
        config: c,
        startStage: 1,
        stats: strong,
        elapsed: const Duration(minutes: 30),
      );
      final weakR = simulateIdleProgress(
        config: c,
        startStage: 1,
        stats: weak,
        elapsed: const Duration(minutes: 30),
      );
      expect(weakR.newStage, lessThan(strongR.newStage));
    });

    test('결정론: 같은 입력이면 같은 결과', () {
      IdleProgress run() => simulateIdleProgress(
        config: c,
        startStage: 3,
        stats: strong,
        elapsed: const Duration(minutes: 45),
      );
      final a = run(), b = run();
      expect(a.newStage, b.newStage);
      expect(a.gold, b.gold);
      expect(a.bossClears, b.bossClears);
    });

    test('도달 스테이지는 시작 이상이고, accrued 는 상한을 넘지 않는다', () {
      final r = simulateIdleProgress(
        config: c,
        startStage: 5,
        stats: strong,
        elapsed: const Duration(hours: 100),
        maxAccrual: const Duration(hours: 8),
      );
      expect(r.newStage, greaterThanOrEqualTo(5));
      expect(r.accrued, const Duration(hours: 8));
    });

    test('전투력을 넘어선 고스테이지는 진행이 거의 멈춘다(과확장 페널티)', () {
      // HP 성장이 골드 성장보다 빠르므로, 전투력에 비해 너무 높은
      // 스테이지에서는 같은 시간에 스테이지가 거의 안 오른다.
      final reachable = simulateIdleProgress(
        config: c,
        startStage: 1,
        stats: strong,
        elapsed: const Duration(minutes: 10),
      );
      final tooHigh = simulateIdleProgress(
        config: c,
        startStage: 80,
        stats: strong,
        elapsed: const Duration(minutes: 10),
      );
      expect(tooHigh.newStage - 80, lessThan(reachable.newStage - 1));
    });
  });

  group('적응형 체력(§7)', () {
    // 공격은 업그레이드 레벨당 x1.15, 체력은 스테이지당 x1.0088 로 자라
    // 공격이 항상 이긴다 → 스테이지 100부터 한 방이 됐다. 그래서 "기준선 대비
    // 얼마나 세졌나"를 체력에 일부 반영한다.
    const c = RunConfig(
      hpBase: 100,
      hpGrowth: 1.01,
      hpAdaptTargetHits: 6,
      hpAdaptPower: 0.85,
      hpAdaptMinRatio: 0.6,
      hpAdaptMaxRatio: 500,
      bossHpMult: 5,
      goldBase: 1,
      goldGrowth: 1.01,
      xpBase: 1,
      xpGrowth: 1.01,
      bossRewardMult: 2,
      habitatsPerStage: 20,
      bugDropChance: 0.1,
      materialDropChance: 0.5,
      threatBase: 1,
      threatGrowth: 1.01,
      bossThreatMult: 2,
      stagesPerRegion: 25,
      regions: [],
      upgrades: {},
      worldSize: 100,
      worldHpMult: 8,
      worldGoldMult: 2,
      worldBossHpMult: 3,
    );

    test('공격력을 안 주면 기존 동작 그대로', () {
      expect(habitatMaxHp(c, 0), (100 * 1.0).round());
      expect(habitatMaxHp(c, 10), habitatMaxHp(c, 10, playerAttack: null));
    });

    test('세질수록 체력도 오르지만 **타격 수는 줄어든다**', () {
      // 성장 실감이 사라지면 안 된다 — 지수가 1 미만인 이유.
      int hits(double atk) =>
          (habitatMaxHp(c, 50, playerAttack: atk) / atk).ceil();
      final weak = hits(20);
      final strong = hits(2000);
      expect(strong, lessThan(weak));
      expect(strong, greaterThan(1)); // 그래도 한 방은 아니다
    });

    test('월드 관문은 보정 밖에 곱해진다 — 벽이 뭉개지면 안 된다', () {
      const atk = 500.0;
      final endOfWorld1 = habitatMaxHp(c, 99, playerAttack: atk);
      final startOfWorld2 = habitatMaxHp(c, 100, playerAttack: atk);
      // 관문에서 worldHpMult(8배)에 가까운 점프가 남아 있어야 한다.
      expect(startOfWorld2 / endOfWorld1, greaterThan(6.0));
    });

    test('약한 플레이어를 더 괴롭히지 않는다(하한 클램프)', () {
      // 기준선보다 훨씬 약해도 체력이 무한히 내려가진 않지만, 최소한
      // 기준 체력보다 커지지는 않는다.
      final base = habitatMaxHp(c, 30);
      expect(habitatMaxHp(c, 30, playerAttack: 1), lessThan(base));
    });
  });

  group('재료 수량 성장(materialAmountMult)', () {
    test('성장률 1.0 이면 항상 1배 — 기존 세이브·서버 동작 그대로', () {
      final c = RunConfig.fromJson({
        ..._baseJson(),
        'materialAmountGrowth': 1.0,
      });
      expect(materialAmountMult(c, 0), 1.0);
      expect(materialAmountMult(c, 500), 1.0);
    });

    test('설정하면 깊이에 따라 지수로 자란다', () {
      final c = RunConfig.fromJson({
        ..._baseJson(),
        'materialAmountGrowth': 1.01,
      });
      expect(materialAmountMult(c, 0), 1.0);
      expect(materialAmountMult(c, 100), closeTo(2.70, 0.01)); // 1.01^100
      // 골드만 지수로 크고 재료가 고정이면 중반엔 재료가 쌓이기만 하고
      // 후반엔 반대로 재료가 병목이 된다 — 그래서 같이 자라야 한다.
      expect(
        materialAmountMult(c, 300),
        greaterThan(materialAmountMult(c, 200)),
      );
    });

    test('키가 없으면 1.0 (구버전 JSON 호환)', () {
      final c = RunConfig.fromJson(_baseJson());
      expect(c.materialAmountGrowth, 1.0);
      expect(materialAmountMult(c, 300), 1.0);
    });
  });

  group('적응형 위협 — 몬스터가 실제로 아파야 한다', () {
    final c = RunConfig.fromJson({
      ..._baseJson(),
      'threatBase': 2.0,
      'threatGrowth': 1.025,
      'bossThreatMult': 3.0,
      'threatAdaptTargetPct': 0.015,
    });

    test('기준을 안 주면 기존 동작(고정 곡선) 그대로다', () {
      final a = habitatThreat(c, 100);
      expect(a, greaterThan(0));
      expect(habitatThreat(c, 100, playerToughness: null), a);
    });

    test('한 대가 가져가는 체력 비율이 **깊이와 무관하게 일정**하다', () {
      // 방어 전력이 지수로 커지는 동안 위협이 고정이면 한 대가 0.0006% 가 된다
      // (실측). 그러면 체력·방어·회복 투자가 전부 죽는다.
      double pct(int depth, double maxHp) {
        final t = habitatThreat(
          c,
          depth,
          playerToughness: maxHp, // 방어 0 가정 → toughness = maxHp
        );
        return t / maxHp;
      }

      expect(pct(10, 1e3), closeTo(pct(900, 1e40), 1e-9));
    });

    test('보스는 훨씬 아프다', () {
      final n = habitatThreat(c, 100, playerToughness: 1e6);
      final b = habitatThreat(c, 100, boss: true, playerToughness: 1e6);
      expect(b / n, closeTo(3.0, 1e-9));
    });

    test('초반에는 곡선 절대값이 바닥을 잡아준다(전력이 미미할 때)', () {
      // 전력이 0에 가까우면 비례식이 0 이 되어 아예 안 아프게 된다.
      expect(habitatThreat(c, 0, playerToughness: 0), greaterThan(0));
    });

    test('회복은 이 식에 없다 — 올린 만큼 그대로 버틴다', () {
      // toughness 는 체력×방어만 본다. 회복이 위협을 키우지 않아야
      // "회복력 투자"가 순수 이득이 된다.
      const s1 = CharacterStats(
        attack: 1,
        attackSpeed: 1,
        rewardMultiplier: 1,
        critChance: 0,
        critDamage: 1,
        bossDamage: 1,
        maxHp: 1000,
        defense: 100,
        hpRegen: 0,
        xpMultiplier: 1,
        bugFind: 1,
        materialFind: 1,
        moveSpeed: 1,
        boostBonus: 1,
      );
      final s2 = CharacterStats(
        attack: s1.attack,
        attackSpeed: s1.attackSpeed,
        rewardMultiplier: s1.rewardMultiplier,
        critChance: s1.critChance,
        critDamage: s1.critDamage,
        bossDamage: s1.bossDamage,
        maxHp: s1.maxHp,
        defense: s1.defense,
        hpRegen: 999, // 회복만 다르다
        xpMultiplier: s1.xpMultiplier,
        bugFind: s1.bugFind,
        materialFind: s1.materialFind,
        moveSpeed: s1.moveSpeed,
        boostBonus: s1.boostBonus,
      );
      expect(toughnessOf(s2), toughnessOf(s1));
    });
  });
}
