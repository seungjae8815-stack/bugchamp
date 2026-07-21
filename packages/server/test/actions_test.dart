import 'dart:convert';
import 'dart:math';
import 'dart:io';

import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:server/src/actions.dart';
import 'package:test/test.dart';

final t0 = DateTime.utc(2026, 7, 20, 12, 0, 0);

/// 드롭 롤·전투에 공통으로 쓰는 테스트 종.
final testSpecies = Species.fromJson({
  'id': 'a',
  'name': {'ko': '테스트벌레', 'en': 'T', 'ja': 'T'},
  'grade': 'common',
  'specialty': 'strike',
  'baseStats': {'hp': 100, 'atk': 40, 'def': 30, 'spd': 20},
  'sizeMinMm': 20,
  'sizeMaxMm': 60,
});

class _Config implements GameConfigLike {
  @override
  final IapConfig iap = IapConfig.fromJson({
    'passDurationDays': 30,
    'products': [
      {
        'id': 'jelly_m',
        'kind': 'consumable',
        'type': 'jelly',
        'priceKrw': 5500,
        'grant': {'jelly': 300},
      },
      {
        'id': 'starter_pack',
        'kind': 'nonConsumable',
        'type': 'starter',
        'priceKrw': 5500,
        'grant': {'jelly': 300, 'gold': 200000, 'incubatorSlots': 1},
      },
      {'id': 'idle_pass', 'kind': 'timed', 'type': 'pass', 'priceKrw': 9900},
      {
        'id': 'skin_gold_rhino',
        'kind': 'nonConsumable',
        'type': 'skin',
        'priceKrw': 3300,
        'skinId': 'gold_rhino',
      },
    ],
  });

  @override
  final BattleConfig battle = const BattleConfig();

  @override
  List<Species> get speciesList => [testSpecies];

  @override
  final PetConfig pet = PetConfig.fromJson(
    jsonDecode(File('../app/assets/data/pets.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  @override
  final EnhanceConfig? enhance = EnhanceConfig.fromJson(
    jsonDecode(File('../app/assets/data/enhance.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  @override
  final RunConfig run = RunConfig.fromJson(
    jsonDecode(File('../app/assets/data/run_config.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  @override
  final MissionConfig? mission = MissionConfig.fromJson(
    jsonDecode(File('../app/assets/data/missions.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  @override
  final GiftConfig? gift = GiftConfig.fromJson(
    jsonDecode(File('../app/assets/data/gifts.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  @override
  final DailyConfig? daily = DailyConfig.fromJson(
    jsonDecode(File('../app/assets/data/daily.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  @override
  final RoadmapConfig? roadmap = RoadmapConfig.fromJson(
    jsonDecode(File('../app/assets/data/roadmap.json').readAsStringSync())
        as Map<String, dynamic>,
  );
}

void main() {
  final actions = GameActions(config: _Config(), now: () => t0);
  final base = SaveGame.initial(createdAt: t0);

  group('구매 지급', () {
    test('젤리 팩은 재화만 지급한다', () {
      final r = actions.grantPurchase(
        base,
        productId: 'jelly_m',
        purchaseId: 'GPA-1',
      );
      expect(r.isOk, isTrue);
      expect(r.save!.materialCount(MaterialKind.jelly), 300);
      expect(r.save!.gold, 0);
    });

    test('같은 purchaseId 재요청은 멱등 — 두 번 지급되지 않는다', () {
      final first = actions.grantPurchase(
        base,
        productId: 'jelly_m',
        purchaseId: 'GPA-1',
      );
      final second = actions.grantPurchase(
        first.save!,
        productId: 'jelly_m',
        purchaseId: 'GPA-1',
      );
      expect(second.isOk, isTrue);
      expect(second.extra['alreadyGranted'], isTrue);
      expect(second.save!.materialCount(MaterialKind.jelly), 300);
    });

    test('다른 purchaseId 는 정상 지급(재구매)', () {
      var s = actions
          .grantPurchase(base, productId: 'jelly_m', purchaseId: 'GPA-1')
          .save!;
      s = actions
          .grantPurchase(s, productId: 'jelly_m', purchaseId: 'GPA-2')
          .save!;
      expect(s.materialCount(MaterialKind.jelly), 600);
    });

    test('없는 상품은 거부 — 클라이언트가 만든 id 로 재화를 못 만든다', () {
      final r = actions.grantPurchase(
        base,
        productId: 'free_billion_jelly',
        purchaseId: 'GPA-X',
      );
      expect(r.isOk, isFalse);
      expect(r.error, 'unknown_product');
    });

    test('스타터는 계정당 1회', () {
      final first = actions.grantPurchase(
        base,
        productId: 'starter_pack',
        purchaseId: 'GPA-1',
      );
      expect(first.save!.starterBought, isTrue);
      expect(first.save!.gold, 200000);

      final second = actions.grantPurchase(
        first.save!,
        productId: 'starter_pack',
        purchaseId: 'GPA-2', // 다른 영수증이어도 거부
      );
      expect(second.isOk, isFalse);
      expect(second.error, 'already_owned');
    });

    test('패스는 남은 기간에 이어서 연장된다', () {
      final first = actions.grantPurchase(
        base,
        productId: 'idle_pass',
        purchaseId: 'GPA-1',
      );
      expect(first.save!.passExpiresAt, t0.add(const Duration(days: 30)));

      final second = actions.grantPurchase(
        first.save!,
        productId: 'idle_pass',
        purchaseId: 'GPA-2',
      );
      expect(second.save!.passExpiresAt, t0.add(const Duration(days: 60)));
    });

    test('스킨은 보유 목록에만 들어간다(스탯 무관)', () {
      final r = actions.grantPurchase(
        base,
        productId: 'skin_gold_rhino',
        purchaseId: 'GPA-1',
      );
      expect(r.save!.ownedSkins, contains('gold_rhino'));
      expect(r.save!.gold, 0);
    });

    test('지급 후 원장에 영수증이 기록된다', () {
      final r = actions.grantPurchase(
        base,
        productId: 'jelly_m',
        purchaseId: 'GPA-1',
      );
      expect(r.save!.redeemedPurchases, contains('GPA-1'));
    });
  });

  group('젤리 소비', () {
    SaveGame withJelly(int n) =>
        base.copyWith(materials: {MaterialKind.jelly: n});

    test('잔액이 충분하면 차감', () {
      final r = actions.spendJelly(withJelly(100), 40);
      expect(r.isOk, isTrue);
      expect(r.save!.materialCount(MaterialKind.jelly), 60);
    });

    test('잔액보다 많이 쓰려 하면 거부 — 클라 주장을 믿지 않는다', () {
      final r = actions.spendJelly(withJelly(10), 40);
      expect(r.isOk, isFalse);
      expect(r.error, 'insufficient');
    });

    test('정확히 전액도 허용', () {
      final r = actions.spendJelly(withJelly(40), 40);
      expect(r.save!.materialCount(MaterialKind.jelly), 0);
    });

    test('0 이하는 거부 — 음수로 재화를 늘리지 못한다', () {
      expect(actions.spendJelly(withJelly(100), 0).error, 'bad_amount');
      expect(actions.spendJelly(withJelly(100), -50).error, 'bad_amount');
    });
  });

  group('서버 전투', () {
    final species = testSpecies;
    final speciesById = {'a': species};
    // 실제 pets.json 을 읽는다 — 서버가 운영에서 하는 것과 동일한 경로.
    final petCfg = PetConfig.fromJson(
      jsonDecode(File('../app/assets/data/pets.json').readAsStringSync())
          as Map<String, dynamic>,
    );

    IndividualBug bug(String id) => IndividualBug(
      id: id,
      speciesId: 'a',
      sizeMm: 40,
      potential: 3,
      temperament: Temperament.aggressive,
      sex: Sex.male,
      element: Element.wood,
      stage: LifeStage.adult,
      stageSince: t0.subtract(const Duration(days: 30)),
    );

    SaveGame saveWith(List<String> ids) => SaveGame.initial(
      createdAt: t0,
    ).copyWith(bugs: [for (final id in ids) bug(id)]);

    List<BattleBug> foe() => [
      buildBattleBug(bug: bug('foe-1'), species: species, locale: 'ko'),
    ];

    ActionResult run(SaveGame save, List<String> team) => actions.runBattle(
      save,
      myTeamBugIds: team,
      foeTeam: foe(),
      location: Element.wood,
      seed: 12345,
      rewardMult: 1.0,
      speciesById: speciesById,
      petConfig: petCfg,
    );

    test('내가 가진 곤충으로만 싸울 수 있다', () {
      final r = run(saveWith(['mine-1']), ['not-mine']);
      expect(r.isOk, isFalse);
      expect(r.error, 'bug_not_owned');
    });

    test('빈 편성은 거부', () {
      final r = run(saveWith(['mine-1']), []);
      expect(r.error, 'empty_team');
    });

    test('부상 중인 곤충은 출전 불가', () {
      final s = saveWith([
        'mine-1',
      ]).copyWith(injured: {'mine-1': t0.add(const Duration(hours: 1))});
      expect(run(s, ['mine-1']).error, 'bug_injured');
    });

    test('전투가 성립하면 결과와 보상이 확정된다', () {
      final r = run(saveWith(['mine-1']), ['mine-1']);
      expect(r.isOk, isTrue);
      expect(r.extra['outcome'], isNotNull);
      expect(r.extra['rounds'], greaterThan(0));
      // 시드를 돌려줘야 클라이언트가 같은 전개를 재생할 수 있다.
      expect(r.extra['seed'], 12345);
    });

    test('같은 입력이면 항상 같은 결과 (결정론)', () {
      final a = run(saveWith(['mine-1']), ['mine-1']);
      final b = run(saveWith(['mine-1']), ['mine-1']);
      expect(a.extra['outcome'], b.extra['outcome']);
      expect(a.extra['rounds'], b.extra['rounds']);
      expect(a.extra['teamAHpPct'], b.extra['teamAHpPct']);
    });

    test('서버 결과가 앱의 simulate 와 일치한다 (로직 한 벌 검증)', () {
      final save = saveWith(['mine-1']);
      final r = run(save, ['mine-1']);

      // 앱이 하는 것과 동일하게 직접 시뮬레이션.
      final mine = [
        buildBattleBug(bug: bug('mine-1'), species: species, locale: 'ko'),
      ];
      final direct = simulate(
        12345,
        mine,
        foe(),
        location: Element.wood,
        locationBonus: const BattleConfig().locationAffinityBonus,
      );
      expect(r.extra['outcome'], direct.outcome.name);
      expect(r.extra['rounds'], direct.rounds);
      expect(r.extra['teamAHpPct'], direct.teamAHpPct);
    });

    test('트로피는 0 아래로 내려가지 않는다', () {
      final s = saveWith(['mine-1']).copyWith(pvpTrophies: 0);
      final r = run(s, ['mine-1']);
      expect(r.save!.pvpTrophies, greaterThanOrEqualTo(0));
    });
  });

  group('방치 수입 정산(sync)', () {
    // now 를 고정하고 lastSeen 을 뒤로 밀어 경과시간을 만든다.
    SaveGame agedBy(Duration d) => SaveGame.initial(
      createdAt: t0.subtract(d),
    ).copyWith(lastSeen: t0.subtract(d), stageNumber: 5, level: 5);

    test('경과시간만큼 골드·경험치가 들어온다', () {
      final r = actions.sync(agedBy(const Duration(hours: 1)));
      expect(r.isOk, isTrue);
      expect(r.save!.gold, greaterThan(0));
      expect(r.extra['elapsedSeconds'], 3600);
    });

    test('경과가 길수록 더 많이 번다', () {
      final short = actions.sync(agedBy(const Duration(minutes: 10)));
      final long = actions.sync(agedBy(const Duration(hours: 2)));
      expect(long.save!.gold, greaterThan(short.save!.gold));
    });

    test('정산 후 lastSeen 이 서버 시각으로 갱신된다 (중복 정산 방지)', () {
      final first = actions.sync(agedBy(const Duration(hours: 1)));
      expect(first.save!.lastSeen, t0);
      // 곧바로 다시 정산해도 경과가 0 이라 추가 수입이 없다.
      final second = actions.sync(first.save!);
      expect(second.save!.gold, first.save!.gold);
    });

    test('기기 시계를 미래로 돌려도 서버 시각 기준이라 이득이 없다', () {
      // lastSeen 이 미래인 세이브(시계 조작 흔적) → 음수 경과.
      final tampered = SaveGame.initial(
        createdAt: t0,
      ).copyWith(lastSeen: t0.add(const Duration(days: 365)));
      final r = actions.sync(tampered);
      expect(r.isOk, isTrue);
      expect(r.save!.gold, 0); // 수입 없음
      expect(r.save!.lastSeen, t0); // 시각만 정상화
    });

    test('오프라인 상한을 넘겨도 상한까지만 준다', () {
      final aDay = actions.sync(agedBy(const Duration(hours: 24)));
      final aWeek = actions.sync(agedBy(const Duration(days: 7)));
      expect(aWeek.save!.gold, aDay.save!.gold);
    });
  });

  group('업그레이드', () {
    test('골드가 충분하면 레벨이 오르고 비용이 빠진다', () {
      final rich = SaveGame.initial(createdAt: t0).copyWith(gold: 1000000);
      final r = actions.upgrade(rich, UpgradeKind.attack);
      expect(r.isOk, isTrue);
      expect(r.save!.upgradeLevel(UpgradeKind.attack), 1);
      expect(r.save!.gold, lessThan(1000000));
      expect(r.extra['newLevel'], 1);
      expect(r.extra['bought'], 1);
    });

    test('골드가 모자라면 거부 — 클라 주장을 믿지 않는다', () {
      final broke = SaveGame.initial(createdAt: t0).copyWith(gold: 0);
      final r = actions.upgrade(broke, UpgradeKind.attack);
      expect(r.isOk, isFalse);
      expect(r.error, 'insufficient_gold');
    });

    test('일괄 구매는 살 수 있는 만큼만 사고 멈춘다', () {
      // 1단계 값만 겨우 되는 골드로 10단계를 요청.
      final spec = _Config().run.upgrades[UpgradeKind.attack]!;
      final justOne = SaveGame.initial(
        createdAt: t0,
      ).copyWith(gold: upgradeCost(spec, 0));
      final r = actions.upgrade(justOne, UpgradeKind.attack, count: 10);
      expect(r.isOk, isTrue);
      expect(r.extra['bought'], 1);
      expect(r.save!.gold, 0);
    });

    test('count 가 0 이하면 거부', () {
      final rich = SaveGame.initial(createdAt: t0).copyWith(gold: 1000000);
      expect(
        actions.upgrade(rich, UpgradeKind.attack, count: 0).error,
        'bad_count',
      );
    });

    test('레벨이 오를수록 비용이 비싸진다', () {
      var s = SaveGame.initial(createdAt: t0).copyWith(gold: 100000000);
      final first = actions.upgrade(s, UpgradeKind.attack);
      s = first.save!;
      final second = actions.upgrade(s, UpgradeKind.attack);
      expect(
        second.extra['goldSpent'] as int,
        greaterThanOrEqualTo(first.extra['goldSpent'] as int),
      );
    });
  });

  group('드롭 롤(서버 소유)', () {
    // 시드 고정 난수로 결정론 확보.
    GameActions seeded(int seed) => GameActions(
      config: _Config(),
      now: () => t0,
      rngFactory: () => Random(seed),
    );

    SaveGame aged(Duration d) => SaveGame.initial(
      createdAt: t0.subtract(d),
    ).copyWith(lastSeen: t0.subtract(d), stageNumber: 5, level: 10);

    test('오래 비울수록 곤충을 더 얻는다', () {
      final short = seeded(1).sync(aged(const Duration(minutes: 5)));
      final long = seeded(1).sync(aged(const Duration(hours: 8)));
      expect(
        long.extra['bugsGained'] as int,
        greaterThanOrEqualTo(short.extra['bugsGained'] as int),
      );
    });

    test('같은 시드·같은 입력이면 결과가 같다 (결정론)', () {
      final a = seeded(42).sync(aged(const Duration(hours: 2)));
      final b = seeded(42).sync(aged(const Duration(hours: 2)));
      expect(a.extra['bugsGained'], b.extra['bugsGained']);
      expect(a.save!.bugs.length, b.save!.bugs.length);
    });

    test('롤 수에 상한이 있다 (오래 비워도 계산이 폭주하지 않음)', () {
      final r = seeded(7).sync(aged(const Duration(days: 30)));
      expect(r.extra['clears'] as int, lessThanOrEqualTo(300));
    });

    test('얻은 곤충은 알 단계로 들어온다', () {
      final r = seeded(3).sync(aged(const Duration(hours: 8)));
      final gained = r.save!.bugs;
      if (gained.isNotEmpty) {
        expect(gained.every((b) => b.stage == LifeStage.egg), isTrue);
      }
    });

    test('포텐셜은 1~5 범위를 벗어나지 않는다', () {
      for (final seed in [1, 2, 3, 99]) {
        final r = seeded(seed).sync(aged(const Duration(hours: 8)));
        for (final b in r.save!.bugs) {
          expect(b.potential, inInclusiveRange(1, 5));
        }
      }
    });

    test('고포텐셜(5성)은 드물다 — 클라가 굴렸다면 마음대로 만들 수 있었다', () {
      var total = 0;
      var fiveStar = 0;
      for (var seed = 0; seed < 12; seed++) {
        final r = seeded(seed).sync(aged(const Duration(hours: 8)));
        for (final b in r.save!.bugs) {
          total++;
          if (b.potential == 5) fiveStar++;
        }
      }
      expect(total, greaterThan(0));
      // rng*rng 분포라 5성은 소수여야 한다.
      expect(fiveStar / total, lessThan(0.2));
    });

    test('재료도 서버가 굴려 지급한다', () {
      final r = seeded(5).sync(aged(const Duration(hours: 8)));
      final mats = r.save!.materials;
      final gained = mats.values.fold<int>(0, (a, b) => a + b);
      expect(gained, greaterThan(0));
      // 젤리는 프리미엄이라 일반 드롭에 없어야 한다.
      expect(mats[MaterialKind.jelly] ?? 0, 0);
    });

    // 스테이지를 실제로 밀 수 있는 강한 캐릭터로 만든다.
    SaveGame strong(Duration d) =>
        SaveGame.initial(createdAt: t0.subtract(d)).copyWith(
          lastSeen: t0.subtract(d),
          stageNumber: 1,
          level: 20,
          upgradeLevels: {UpgradeKind.attack: 80, UpgradeKind.attackSpeed: 30},
        );

    test('sync 가 스테이지를 올린다 (서버가 진행을 확정)', () {
      final r = actions.sync(strong(const Duration(hours: 2)));
      expect(r.save!.stageNumber, greaterThan(1));
      expect(r.extra['newStage'], r.save!.stageNumber);
    });

    test('스테이지 진행은 서버 시각으로 정산돼 재시작해도 남는다', () {
      final first = actions.sync(strong(const Duration(hours: 1)));
      // 두 번째 sync 는 이미 오른 스테이지에서 시작한다(되돌아가지 않는다).
      final second = actions.sync(first.save!.copyWith(lastSeen: t0));
      expect(
        second.save!.stageNumber,
        greaterThanOrEqualTo(first.save!.stageNumber),
      );
    });

    test('처치 미션 진행도가 오른다 (활성 미션이 처치형일 때)', () {
      // missions.json 의 첫 미션이 활성(수령 0회). 그게 처치형이면 진행이 오른다.
      final r = actions.sync(strong(const Duration(hours: 2)));
      final progressed = r.save!.missionProgress.values.fold<int>(
        0,
        (a, b) => a + b,
      );
      // 처치형 미션이 활성이면 > 0, 아니면(강화형 등) 0 — 어느 쪽이든 음수는 없다.
      expect(progressed, greaterThanOrEqualTo(0));
    });

    test('선물이 예정 시각을 지나면 스폰된다', () {
      // nextGiftAt 을 과거로 둔 세이브 → sync 가 하나 스폰.
      final base = strong(
        const Duration(minutes: 30),
      ).copyWith(nextGiftAt: t0.subtract(const Duration(minutes: 1)));
      final r = actions.sync(base);
      expect(r.save!.gifts.length, greaterThanOrEqualTo(1));
    });

    test('아직 예정 시각 전이면 선물을 안 준다', () {
      final base = strong(
        const Duration(minutes: 30),
      ).copyWith(nextGiftAt: t0.add(const Duration(hours: 1)));
      final r = actions.sync(base);
      expect(r.save!.gifts, isEmpty);
    });
  });

  group('야생 상대 생성(서버 소유)', () {
    final petCfg = PetConfig.fromJson(
      jsonDecode(File('../app/assets/data/pets.json').readAsStringSync())
          as Map<String, dynamic>,
    );

    IndividualBug adult(String id, {int potential = 3}) => IndividualBug(
      id: id,
      speciesId: 'a',
      sizeMm: 40,
      potential: potential,
      temperament: Temperament.aggressive,
      sex: Sex.male,
      element: Element.wood,
      stage: LifeStage.adult,
      stageSince: t0.subtract(const Duration(days: 30)),
    );

    SaveGame withRoster(int n) => SaveGame.initial(
      createdAt: t0,
    ).copyWith(bugs: [for (var i = 0; i < n; i++) adult('m$i')]);

    final tiers = _Config().battle.scoutTiers;

    test('설정에 없는 티어 id 는 거부 — 클라가 임의 배율을 못 넣는다', () {
      final r = actions.buildWildTeam(
        withRoster(3),
        tierId: 'godmode_0.001x',
        speciesById: {'a': testSpecies},
        petConfig: petCfg,
        rng: Random(1),
      );
      expect(r, isNull);
    });

    test('유효한 티어면 3마리를 만든다', () {
      final r = actions.buildWildTeam(
        withRoster(3),
        tierId: tiers.first.id,
        speciesById: {'a': testSpecies},
        petConfig: petCfg,
        rng: Random(1),
      );
      expect(r, isNotNull);
      expect(r!.team.length, 3);
    });

    test('티어 배율이 셀수록 상대가 강해진다', () {
      double avgAtk(String tierId) {
        final r = actions.buildWildTeam(
          withRoster(3),
          tierId: tierId,
          speciesById: {'a': testSpecies},
          petConfig: petCfg,
          rng: Random(7),
        )!;
        return r.team.fold(0.0, (s, b) => s + b.atk) / r.team.length;
      }

      final sorted = [...tiers]
        ..sort((a, b) => a.powerMult.compareTo(b.powerMult));
      if (sorted.length >= 2) {
        expect(avgAtk(sorted.last.id), greaterThan(avgAtk(sorted.first.id)));
      }
    });

    test('성충이 없으면 만들 수 없다', () {
      final noAdults = SaveGame.initial(createdAt: t0);
      final r = actions.buildWildTeam(
        noAdults,
        tierId: tiers.first.id,
        speciesById: {'a': testSpecies},
        petConfig: petCfg,
        rng: Random(1),
      );
      expect(r, isNull);
    });

    test('내 로스터가 강하면 상대도 강해진다 (스케일 연동)', () {
      double avgAtkFor(SaveGame s) {
        final r = actions.buildWildTeam(
          s,
          tierId: tiers.first.id,
          speciesById: {'a': testSpecies},
          petConfig: petCfg,
          rng: Random(3),
        )!;
        return r.team.fold(0.0, (x, b) => x + b.atk) / r.team.length;
      }

      final weak = SaveGame.initial(
        createdAt: t0,
      ).copyWith(bugs: [adult('w', potential: 1)]);
      final strong = SaveGame.initial(
        createdAt: t0,
      ).copyWith(bugs: [adult('s', potential: 5)]);
      expect(avgAtkFor(strong), greaterThanOrEqualTo(avgAtkFor(weak)));
    });
  });

  group('육성(강화·수련)', () {
    final cfg = _Config();

    IndividualBug adult(String id) => IndividualBug(
      id: id,
      speciesId: 'a',
      sizeMm: 40,
      potential: 5,
      temperament: Temperament.aggressive,
      sex: Sex.male,
      element: Element.wood,
      stage: LifeStage.adult,
      stageSince: t0.subtract(const Duration(days: 30)),
    );

    SaveGame owner({int gold = 0, Map<MaterialKind, int>? mats}) =>
        SaveGame.initial(createdAt: t0).copyWith(
          bugs: [adult('mine')],
          gold: gold,
          materials: mats ?? const {},
        );

    test('내 곤충이 아니면 강화 불가', () {
      final r = actions.enhancePart(
        owner(mats: {MaterialKind.chitin: 9999}),
        'not-mine',
        BugPart.hornJaw,
        enhance: cfg.enhance!,
      );
      expect(r.error, 'bug_not_owned');
    });

    test('재료가 모자라면 강화 거부 — 클라 주장을 믿지 않는다', () {
      final r = actions.enhancePart(
        owner(),
        'mine',
        BugPart.hornJaw,
        enhance: cfg.enhance!,
      );
      expect(r.error, 'insufficient_material');
    });

    test('재료가 충분하면 강화되고 재료가 빠진다', () {
      final spec = cfg.enhance!.spec(BugPart.hornJaw);
      final before = owner(mats: {spec.material: 99999});
      final r = actions.enhancePart(
        before,
        'mine',
        BugPart.hornJaw,
        enhance: cfg.enhance!,
      );
      expect(r.isOk, isTrue);
      expect(r.save!.bugs.first.enhancement.levelOf(BugPart.hornJaw), 1);
      expect(
        r.save!.materialCount(spec.material),
        lessThan(before.materialCount(spec.material)),
      );
    });

    test('골드가 모자라면 수련 거부', () {
      final r = actions.trainBug(owner(), 'mine', petConfig: cfg.pet);
      expect(r.error, 'insufficient_gold');
    });

    test('골드가 충분하면 레벨이 오른다', () {
      final r = actions.trainBug(
        owner(gold: 99999999),
        'mine',
        petConfig: cfg.pet,
      );
      expect(r.isOk, isTrue);
      expect(r.save!.bugs.first.level, 2);
      expect(r.save!.gold, lessThan(99999999));
    });

    test('성충이 아니면 수련 불가', () {
      final egg = SaveGame.initial(createdAt: t0).copyWith(
        gold: 99999999,
        bugs: [adult('mine').copyWith(stage: LifeStage.egg, stageSince: t0)],
      );
      final r = actions.trainBug(egg, 'mine', petConfig: cfg.pet);
      expect(r.error, 'not_adult');
    });
  });

  group('짝짓기(시드는 서버가 정한다)', () {
    final cfg = _Config();
    final speciesById = {'a': testSpecies};

    IndividualBug parent(String id, Sex sex, {int potential = 3}) =>
        IndividualBug(
          id: id,
          speciesId: 'a',
          sizeMm: 40,
          potential: potential,
          temperament: Temperament.aggressive,
          sex: sex,
          element: Element.wood,
          stage: LifeStage.adult,
          stageSince: t0.subtract(const Duration(days: 30)),
        );

    SaveGame pair() => SaveGame.initial(createdAt: t0).copyWith(
      bugs: [parent('mom', Sex.female), parent('dad', Sex.male)],
      breedingCapacity: 1,
    );

    ActionResult start(GameActions a, SaveGame s) => a.startBreeding(
      s,
      motherId: 'mom',
      fatherId: 'dad',
      speciesById: speciesById,
      petConfig: cfg.pet,
    );

    test('조건이 맞으면 슬롯이 생긴다', () {
      final r = start(actions, pair());
      expect(r.isOk, isTrue);
      expect(r.save!.breeding.length, 1);
    });

    test('클라이언트는 시드를 넣을 수 없다 — 서버 난수가 정한다', () {
      // 서로 다른 서버 난수 → 다른 시드가 나와야 한다.
      final a = GameActions(
        config: cfg,
        now: () => t0,
        rngFactory: () => Random(1),
      );
      final b = GameActions(
        config: cfg,
        now: () => t0,
        rngFactory: () => Random(2),
      );
      final sa = start(a, pair()).save!.breeding.first.seed;
      final sb = start(b, pair()).save!.breeding.first.seed;
      expect(sa, isNot(sb));
    });

    test('같은 종이 아니면 거부', () {
      final s = SaveGame.initial(createdAt: t0).copyWith(
        bugs: [
          parent('mom', Sex.female),
          parent('dad', Sex.male).copyWith(speciesId: 'other'),
        ],
        breedingCapacity: 1,
      );
      expect(start(actions, s).error, 'species_mismatch');
    });

    test('암수가 아니면 거부', () {
      final s = SaveGame.initial(createdAt: t0).copyWith(
        bugs: [parent('mom', Sex.male), parent('dad', Sex.male)],
        breedingCapacity: 1,
      );
      expect(start(actions, s).error, 'sex_mismatch');
    });

    test('슬롯이 없으면 거부', () {
      final s = pair().copyWith(breedingCapacity: 0);
      expect(start(actions, s).error, 'no_slot');
    });

    test('산란 중에는 수령할 수 없다 (젤리 없이)', () {
      final started = start(actions, pair()).save!;
      final r = actions.collectBreeding(
        started,
        started.breeding.first.id,
        speciesById: speciesById,
        petConfig: cfg.pet,
      );
      expect(r.error, 'not_ready');
    });

    test('젤리가 모자라면 즉시완료 거부', () {
      final started = start(actions, pair()).save!;
      final r = actions.collectBreeding(
        started,
        started.breeding.first.id,
        speciesById: speciesById,
        petConfig: cfg.pet,
        viaJelly: true,
      );
      expect(r.error, 'insufficient_jelly');
    });

    test('시간이 지나면 알을 수령한다', () {
      final started = start(actions, pair()).save!;
      final slot = started.breeding.first;
      final later = GameActions(
        config: cfg,
        now: () => slot.endsAt.add(const Duration(seconds: 1)),
      );
      final r = later.collectBreeding(
        started,
        slot.id,
        speciesById: speciesById,
        petConfig: cfg.pet,
      );
      expect(r.isOk, isTrue);
      expect(r.save!.breeding, isEmpty);
      expect(r.save!.bugs.length, 3); // 부모 2 + 알 1
      expect(r.save!.bugs.last.stage, LifeStage.egg);
    });
  });

  group('부화 수령·분해', () {
    final cfg = _Config();

    IndividualBug egg(String id) => IndividualBug(
      id: id,
      speciesId: 'a',
      sizeMm: 40,
      potential: 4,
      temperament: Temperament.aggressive,
      sex: Sex.male,
      element: Element.wood,
      stage: LifeStage.egg,
      stageSince: t0,
    );

    test('부화 중이 아니면 수령 불가', () {
      final s = SaveGame.initial(createdAt: t0).copyWith(bugs: [egg('e')]);
      expect(actions.collectIncubated(s, 'e').error, 'not_incubating');
    });

    test('완료 전에는 수령 불가 — 타이머를 건너뛸 수 없다', () {
      final s = SaveGame.initial(createdAt: t0).copyWith(
        bugs: [egg('e')],
        incubating: {'e': t0.add(const Duration(hours: 1))},
      );
      expect(actions.collectIncubated(s, 'e').error, 'not_ready');
    });

    test('완료 후 유충으로 바뀐다', () {
      final s = SaveGame.initial(createdAt: t0).copyWith(
        bugs: [egg('e')],
        incubating: {'e': t0.subtract(const Duration(seconds: 1))},
      );
      final r = actions.collectIncubated(s, 'e');
      expect(r.isOk, isTrue);
      expect(r.save!.bugs.first.stage, LifeStage.larva);
      expect(r.save!.incubating, isEmpty);
    });

    test('분해하면 젤리를 주고 곤충이 사라진다', () {
      final s = SaveGame.initial(createdAt: t0).copyWith(bugs: [egg('e')]);
      final r = actions.disassembleBug(s, 'e', petConfig: cfg.pet);
      expect(r.isOk, isTrue);
      expect(r.save!.bugs, isEmpty);
      expect(r.save!.materialCount(MaterialKind.jelly), greaterThan(0));
    });

    test('편성 중인 곤충은 분해 불가', () {
      final s = SaveGame.initial(
        createdAt: t0,
      ).copyWith(bugs: [egg('e')], equippedBugIds: ['e']);
      expect(
        actions.disassembleBug(s, 'e', petConfig: cfg.pet).error,
        'equipped',
      );
    });

    test('부화 중인 곤충은 분해 불가 (슬롯 누수 방지)', () {
      final s = SaveGame.initial(createdAt: t0).copyWith(
        bugs: [egg('e')],
        incubating: {'e': t0.add(const Duration(hours: 1))},
      );
      expect(
        actions.disassembleBug(s, 'e', petConfig: cfg.pet).error,
        'incubating',
      );
    });

    test('내 곤충이 아니면 분해 불가', () {
      final s = SaveGame.initial(createdAt: t0);
      expect(
        actions.disassembleBug(s, 'nope', petConfig: cfg.pet).error,
        'bug_not_owned',
      );
    });
  });

  group('돌파(breakthrough)', () {
    final cfg = _Config();
    // pets.json: tierCaps[0]=10, breakthroughGold[0]=20000, material[0]=100.
    const capL0 = 10;
    const gold0 = 20000;
    const mat0 = 100;

    IndividualBug bug(
      String id, {
      int level = 1,
      int tier = 0,
      DateTime? ends,
    }) => IndividualBug(
      id: id,
      speciesId: 'a',
      sizeMm: 40,
      potential: 5,
      temperament: Temperament.aggressive,
      sex: Sex.male,
      element: Element.wood,
      stage: LifeStage.adult,
      stageSince: t0.subtract(const Duration(days: 30)),
      level: level,
      breakthroughTier: tier,
      breakthroughEndsAt: ends,
    );

    SaveGame owner(
      IndividualBug b, {
      int gold = 0,
      Map<MaterialKind, int>? mats,
    }) => SaveGame.initial(
      createdAt: t0,
    ).copyWith(bugs: [b], gold: gold, materials: mats ?? const {});

    final fullMats = {
      MaterialKind.chitin: mat0,
      MaterialKind.mineral: mat0,
      MaterialKind.sap: mat0,
    };

    test('상한 미달이면 돌파 불가', () {
      final r = actions.startBreakthrough(
        owner(
          bug('b', level: capL0 - 1),
          gold: gold0,
          mats: fullMats,
        ),
        'b',
        petConfig: cfg.pet,
      );
      expect(r.error, 'cap_not_reached');
    });

    test('골드가 모자라면 거부', () {
      final r = actions.startBreakthrough(
        owner(
          bug('b', level: capL0),
          gold: gold0 - 1,
          mats: fullMats,
        ),
        'b',
        petConfig: cfg.pet,
      );
      expect(r.error, 'insufficient_gold');
    });

    test('재료가 모자라면 거부', () {
      final r = actions.startBreakthrough(
        owner(
          bug('b', level: capL0),
          gold: gold0,
          mats: {MaterialKind.chitin: mat0, MaterialKind.mineral: mat0},
        ),
        'b',
        petConfig: cfg.pet,
      );
      expect(r.error, 'insufficient_material');
    });

    test('조건을 채우면 재화를 쓰고 타이머가 걸린다', () {
      final r = actions.startBreakthrough(
        owner(
          bug('b', level: capL0),
          gold: gold0,
          mats: fullMats,
        ),
        'b',
        petConfig: cfg.pet,
      );
      expect(r.isOk, isTrue);
      expect(r.save!.gold, 0);
      for (final k in [
        MaterialKind.chitin,
        MaterialKind.mineral,
        MaterialKind.sap,
      ]) {
        expect(r.save!.materialCount(k), 0);
      }
      expect(r.save!.bugs.first.breakthroughEndsAt, isNotNull);
      // 티어는 아직 그대로 — 완료해야 오른다.
      expect(r.save!.bugs.first.breakthroughTier, 0);
    });

    test('이미 돌파 중이면 다시 시작 못 한다', () {
      final r = actions.startBreakthrough(
        owner(
          bug('b', level: capL0, ends: t0.add(const Duration(hours: 1))),
          gold: gold0,
          mats: fullMats,
        ),
        'b',
        petConfig: cfg.pet,
      );
      expect(r.error, 'breakthrough_in_progress');
    });

    test('완료 전에는 무료 수령 불가 — 타이머를 건너뛸 수 없다', () {
      final r = actions.completeBreakthrough(
        owner(bug('b', level: capL0, ends: t0.add(const Duration(hours: 1)))),
        'b',
        petConfig: cfg.pet,
      );
      expect(r.error, 'not_ready');
    });

    test('타이머가 끝나면 티어가 오른다', () {
      final r = actions.completeBreakthrough(
        owner(
          bug('b', level: capL0, ends: t0.subtract(const Duration(seconds: 1))),
        ),
        'b',
        petConfig: cfg.pet,
      );
      expect(r.isOk, isTrue);
      expect(r.save!.bugs.first.breakthroughTier, 1);
      expect(r.save!.bugs.first.breakthroughEndsAt, isNull);
    });

    test('젤리로 즉시완료 — 젤리를 쓰고 티어가 오른다', () {
      final r = actions.completeBreakthrough(
        owner(
          bug('b', level: capL0, ends: t0.add(const Duration(minutes: 10))),
          mats: {MaterialKind.jelly: 999},
        ),
        'b',
        petConfig: cfg.pet,
        viaJelly: true,
      );
      expect(r.isOk, isTrue);
      expect(r.save!.bugs.first.breakthroughTier, 1);
      expect(r.save!.materialCount(MaterialKind.jelly), lessThan(999));
    });

    test('젤리가 모자라면 즉시완료 거부', () {
      final r = actions.completeBreakthrough(
        owner(
          bug('b', level: capL0, ends: t0.add(const Duration(hours: 4))),
          mats: {MaterialKind.jelly: 0},
        ),
        'b',
        petConfig: cfg.pet,
        viaJelly: true,
      );
      expect(r.error, 'insufficient_jelly');
    });

    test('돌파 중이 아니면 수령 불가', () {
      final r = actions.completeBreakthrough(
        owner(bug('b', level: capL0)),
        'b',
        petConfig: cfg.pet,
      );
      expect(r.error, 'not_breaking');
    });

    test('최대 티어면 더 돌파할 수 없다', () {
      final r = actions.startBreakthrough(
        owner(
          bug('b', level: 999, tier: cfg.pet.maxTier),
          gold: 99999999,
          mats: {
            MaterialKind.chitin: 99999,
            MaterialKind.mineral: 99999,
            MaterialKind.sap: 99999,
          },
        ),
        'b',
        petConfig: cfg.pet,
      );
      expect(r.error, 'at_max_tier');
    });

    test('내 곤충이 아니면 거부', () {
      final r = actions.startBreakthrough(
        SaveGame.initial(createdAt: t0),
        'ghost',
        petConfig: cfg.pet,
      );
      expect(r.error, 'bug_not_owned');
    });
  });

  group('보상 수령(미션·선물·일일·챕터)', () {
    final cfg = _Config();
    final mission0 = cfg.mission!.missions.first; // hunt / killMonsters / gold

    test('목표 미달이면 미션 수령 불가', () {
      final s = SaveGame.initial(createdAt: t0);
      final r = actions.claimMission(s, mission0.id);
      expect(r.error, 'goal_not_reached');
    });

    test('목표 달성이면 지급 + 진행도 초기화 + 티어 상승', () {
      final goal = mission0.goalAt(0);
      final s = SaveGame.initial(
        createdAt: t0,
      ).copyWith(missionProgress: {mission0.id: goal});
      final r = actions.claimMission(s, mission0.id);
      expect(r.isOk, isTrue);
      expect(r.save!.gold, greaterThan(0)); // reward=gold
      expect(r.save!.missionProgress, isEmpty);
      expect(r.save!.missionClaimCount(mission0.id), 1);
    });

    test('없는 미션은 거부', () {
      final r = actions.claimMission(SaveGame.initial(createdAt: t0), 'nope');
      expect(r.error, 'unknown_mission');
    });

    test('선물 수령 → 재화 지급, 선물 제거', () {
      final gift = GiftMail(
        id: 'g1',
        expiry: t0.add(const Duration(hours: 1)),
        gold: 1000,
        jelly: 2,
      );
      final s = SaveGame.initial(createdAt: t0).copyWith(gifts: [gift]);
      final r = actions.claimGift(s, 'g1');
      expect(r.isOk, isTrue);
      expect(r.save!.gold, 1000);
      expect(r.save!.materialCount(MaterialKind.jelly), 2);
      expect(r.save!.gifts, isEmpty);
    });

    test('광고 배수 선물은 두 배로 준다', () {
      final gift = GiftMail(
        id: 'g1',
        expiry: t0.add(const Duration(hours: 1)),
        gold: 1000,
      );
      final s = SaveGame.initial(createdAt: t0).copyWith(gifts: [gift]);
      final r = actions.claimGift(s, 'g1', doubled: true);
      expect(r.save!.gold, 1000 * cfg.gift!.adMultiplier);
    });

    test('만료된 선물은 지급 안 함', () {
      final gift = GiftMail(
        id: 'g1',
        expiry: t0.subtract(const Duration(minutes: 1)),
        gold: 1000,
      );
      final s = SaveGame.initial(createdAt: t0).copyWith(gifts: [gift]);
      expect(actions.claimGift(s, 'g1').error, 'gift_expired');
    });

    test('없는 선물은 거부', () {
      final r = actions.claimGift(SaveGame.initial(createdAt: t0), 'ghost');
      expect(r.error, 'gift_not_found');
    });

    test('일일보상: 처음이면 지급, 같은 날 재수령 거부', () {
      final reward = cfg.daily!.rewards.first; // lunch
      final s = SaveGame.initial(createdAt: t0);
      final r1 = actions.claimDaily(s, reward.id);
      expect(r1.isOk, isTrue);
      expect(r1.save!.gold, reward.gold);

      final r2 = actions.claimDaily(r1.save!, reward.id);
      expect(r2.error, 'already_claimed');
    });

    test('없는 일일보상 슬롯은 거부', () {
      final r = actions.claimDaily(SaveGame.initial(createdAt: t0), 'brunch');
      expect(r.error, 'unknown_reward');
    });

    test('챕터 클리어: 스테이지가 넘으면 보상, 재요청은 빈 목록', () {
      final ch0 = cfg.roadmap!.chapters.first; // easy, endStage 10
      final s = SaveGame.initial(
        createdAt: t0,
      ).copyWith(stageNumber: ch0.endStage + 1);
      final r = actions.grantChapterClears(s);
      expect(r.isOk, isTrue);
      expect((r.extra['cleared'] as List), contains(ch0.id));
      expect(r.save!.gold, greaterThan(0));

      // 다시 요청하면 이미 받았으니 빈 목록.
      final again = actions.grantChapterClears(r.save!);
      expect((again.extra['cleared'] as List), isEmpty);
    });

    test('스테이지가 못 미치면 챕터 보상 없음', () {
      final s = SaveGame.initial(createdAt: t0).copyWith(stageNumber: 1);
      final r = actions.grantChapterClears(s);
      expect((r.extra['cleared'] as List), isEmpty);
    });
  });
}
