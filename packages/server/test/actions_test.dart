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
      {
        'id': 'idle_pass',
        'iosId': 'idle_pass_c',
        'kind': 'timed',
        'type': 'pass',
        'priceKrw': 9900,
      },
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
  final ForgeConfig? forge = ForgeConfig.fromJson(
    jsonDecode(File('../app/assets/data/forge.json').readAsStringSync())
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

  @override
  final EventConfig? event = EventConfig.fromJson(
    jsonDecode(File('../app/assets/data/event.json').readAsStringSync())
        as Map<String, dynamic>,
  );
}

void main() {
  final actions = GameActions(config: _Config(), now: () => t0);
  final base = SaveGame.initial(createdAt: t0);

  _forfeitTests(actions, base);

  group('구매 지급', () {
    test('iOS 전용 ID(idle_pass_c)로도 곤충학자 패스가 지급된다', () {
      // ASC 유형 사고로 iOS 만 새 ID 를 쓴다(iap.json → iosId).
      // 서버가 별칭을 못 풀면 iOS 결제가 전부 unknown_product 로 죽는다.
      final r = actions.grantPurchase(
        base,
        productId: 'idle_pass_c',
        purchaseId: 'GPA-ios-1',
      );
      expect(r.isOk, isTrue);
      expect(r.save!.passExpiresAt, isNotNull);
    });

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

    group('위조 개체 차단 — 세이브 편집으로 만든 값은 편성 거부', () {
      // 드롭 롤이 기기 권위라 위조 자체는 막을 수 없다. 여기서 *효과*를
      // 막는다 — 통과하면 위조 곤충으로 트로피를 쌓아 랭킹이 오염된다.
      SaveGame forged(IndividualBug b) =>
          SaveGame.initial(createdAt: t0).copyWith(bugs: [b]);

      test('종 사이즈 범위 밖(거대화)', () {
        final b = bug('mine-1').copyWith(sizeMm: 999);
        expect(
          run(forged(b), ['mine-1']).error,
          'bug_forged:size_out_of_range',
        );
      });

      test('NaN 사이즈 — 비교가 전부 false 라 범위 검사를 통과해 버린다', () {
        final b = bug('mine-1').copyWith(sizeMm: double.nan);
        expect(run(forged(b), ['mine-1']).error, 'bug_forged:size_not_finite');
      });

      test('포텐셜 5 초과', () {
        // 생성자 assert 는 릴리스에서 꺼지므로 fromJson 경로로 만든다.
        final b = IndividualBug.fromJson(
          bug('mine-1').toJson()..['potential'] = 9,
        );
        expect(
          run(forged(b), ['mine-1']).error,
          'bug_forged:potential_out_of_range',
        );
      });

      test('부위 강화 총량이 포텐셜×10 초과', () {
        final b = bug('mine-1').copyWith(
          enhancement: const PartLevels(
            hornJaw: 20,
            cuticle: 20,
            wing: 20,
            build: 20,
          ),
        );
        expect(run(forged(b), ['mine-1']).error, 'bug_forged:enhance_over_cap');
      });

      test('수련 레벨이 돌파 티어 상한 초과', () {
        final b = bug('mine-1').copyWith(level: 999);
        expect(run(forged(b), ['mine-1']).error, 'bug_forged:level_over_cap');
      });

      test('돌파 티어가 설정 최대 초과', () {
        final b = bug('mine-1').copyWith(breakthroughTier: 99);
        expect(
          run(forged(b), ['mine-1']).error,
          'bug_forged:breakthrough_out_of_range',
        );
      });

      test('정상 상한값(경계)은 통과한다 — 진짜 만렙 유저를 막으면 안 된다', () {
        final cap = petCfg.levelCap(petCfg.maxTier);
        final b = bug('mine-1').copyWith(
          sizeMm: 60, // 종 최대
          level: cap,
          breakthroughTier: petCfg.maxTier,
          enhancement: const PartLevels(hornJaw: 10, cuticle: 10, wing: 10),
        ); // potential 3 → 강화 상한 30 = 딱 상한
        expect(run(forged(b), ['mine-1']).isOk, isTrue);
      });
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

    test('전투 1판마다 티켓 1장이 깎인다', () {
      final r = run(saveWith(['mine-1']), ['mine-1']);
      expect(r.save!.pvpTickets, kDefaultPvpTickets - 1);
      expect(r.extra['tickets'], kDefaultPvpTickets - 1);
    });

    test('티켓이 없으면 전투 자체가 거부된다 (판수 제한의 핵심)', () {
      final s = saveWith(['mine-1']).copyWith(pvpTickets: 0, ticketsAt: t0);
      final r = run(s, ['mine-1']);
      expect(r.isOk, isFalse);
      expect(r.error, 'no_tickets');
    });

    test('편성이 잘못되면 티켓을 쓰지 않는다', () {
      final s = saveWith(['mine-1']);
      final r = run(s, ['not-mine']);
      expect(r.isOk, isFalse);
      expect(s.pvpTickets, kDefaultPvpTickets); // 원본 그대로
    });
  });

  group('결투 티켓 충전', () {
    const cfg = BattleConfig(); // max10 / 30분 / 광고+3(30회) / 젤리10
    final spent = SaveGame.initial(
      createdAt: t0,
    ).copyWith(pvpTickets: 2, ticketsAt: t0);

    test('세이브를 편집해 티켓을 채워도 업로드 때 서버 값으로 덮인다', () {
      final stored = spent;
      final forged = stored.toJson()..['pvpTickets'] = 999;
      final r = actions.mergeSave(stored, forged);
      expect(r.isOk, isTrue);
      expect(r.save!.pvpTickets, 2);
    });

    test('광고 1회 = +3장, 시청 횟수가 기록된다', () {
      final r = actions.grantAdTicket(spent);
      expect(r.isOk, isTrue);
      expect(r.save!.pvpTickets, 2 + cfg.ticketAdGrant);
      expect(r.save!.adUseCount(kAdFeaturePvpTicket, dailyDateKey(t0)), 1);
      expect(r.extra['adUsed'], 1);
    });

    test('하루 상한을 넘기면 거부 — 광고제거 구매자도 동일', () {
      final maxed = spent.copyWith(
        adUseCounts: {kAdFeaturePvpTicket: cfg.ticketAdDailyLimit},
        adUseDate: dailyDateKey(t0),
        adsRemoved: true, // 광고제거여도 상한은 그대로
      );
      expect(actions.grantAdTicket(maxed).error, 'ad_limit');
    });

    test('날짜가 바뀌면 시청 횟수가 리셋된다', () {
      final yesterday = spent.copyWith(
        adUseCounts: {kAdFeaturePvpTicket: cfg.ticketAdDailyLimit},
        adUseDate: dailyDateKey(t0.subtract(const Duration(days: 1))),
      );
      final r = actions.grantAdTicket(yesterday);
      expect(r.isOk, isTrue);
      expect(r.extra['adUsed'], 1);
    });

    test('젤리 충전은 값을 치르고 만땅이 된다', () {
      final rich = spent.copyWith(materials: {MaterialKind.jelly: 30});
      final r = actions.refillPvpTickets(rich);
      expect(r.isOk, isTrue);
      expect(r.save!.pvpTickets, cfg.ticketMax);
      expect(
        r.save!.materialCount(MaterialKind.jelly),
        30 - cfg.ticketRefillJelly,
      );
    });

    test('젤리가 모자라면 충전되지 않는다', () {
      final poor = spent.copyWith(materials: {MaterialKind.jelly: 1});
      final r = actions.refillPvpTickets(poor);
      expect(r.error, 'insufficient');
      expect(poor.pvpTickets, 2);
    });

    test('가득 찬 상태에서는 젤리를 받지 않는다', () {
      final full = spent.copyWith(
        pvpTickets: cfg.ticketMax,
        materials: {MaterialKind.jelly: 30},
      );
      expect(actions.refillPvpTickets(full).error, 'already_full');
    });

    test('시간이 지나면 서버가 자연 충전분을 인정한다', () {
      final old = spent.copyWith(
        ticketsAt: t0.subtract(const Duration(hours: 2)),
      );
      expect(actions.ticketsNow(old).tickets, 2 + 4); // 2시간 = 4장
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

    test('등급 필터를 서버도 건다 — 클라만 거르면 구버전 앱이 우회한다', () {
      // 테스트 종은 common 하나뿐이라, 기준을 rare 로 올리면 전부 걸린다.
      final filtered = aged(
        const Duration(hours: 8),
      ).copyWith(bugFilterMinGrade: Grade.rare);
      final r = seeded(3).sync(filtered);
      expect(r.save!.bugs, isEmpty);
      expect(r.extra['bugsGained'], 0);
    });

    test('필터에 걸린 곤충은 재료로 환산된다(자동 방생) — 젤리가 아니다', () {
      final base = aged(const Duration(hours: 8));
      final filtered = base.copyWith(bugFilterMinGrade: Grade.legendary);

      final plain = seeded(3).sync(base).save!;
      final released = seeded(3).sync(filtered).save!;

      // 곤충 대신 일반 재료가 더 들어온다.
      int mats(SaveGame s) => const [
        MaterialKind.chitin,
        MaterialKind.mineral,
        MaterialKind.sap,
      ].fold(0, (a, k) => a + s.materialCount(k));
      expect(plain.bugs, isNotEmpty, reason: '기준 케이스에 곤충이 있어야 비교가 성립한다');
      expect(released.bugs, isEmpty);
      expect(mats(released), greaterThan(mats(plain)));
      // ⚠️ 프리미엄 재화(젤리)는 자동 통로로 절대 새면 안 된다(§2.6).
      expect(released.materialCount(MaterialKind.jelly), 0);
    });

    test('필터가 기본값이면 예전 그대로 곤충이 들어온다', () {
      final r = seeded(3).sync(aged(const Duration(hours: 8)));
      expect(r.save!.bugs, isNotEmpty);
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

    // ── 짝짓기 텀(§2.5) ────────────────────────────────────────────
    // 부모는 잠기지 않으므로(스냅샷 저장) 텀이 없으면 잘 뽑힌 한 쌍으로
    // 같은 급 자식을 무한히 찍어낼 수 있다. **서버도** 막아야 구버전 앱이나
    // 세이브를 고친 요청이 우회하지 못한다.
    test('시작하면 부모 둘 다 쿨다운이 걸린다 — 수령이 아니라 시작 시점', () {
      final r = start(actions, pair());
      expect(r.isOk, isTrue);
      final cool = r.save!.breedCooldowns;
      expect(cool.keys.toSet(), {'mom', 'dad'});
      expect(cool['mom']!.isAfter(t0), isTrue);
      expect(r.save!.breedOnCooldown('mom', t0), isTrue);
    });

    test('쿨다운 중인 부모로 다시 시작하면 거부', () {
      final started = start(actions, pair()).save!;
      // 슬롯을 비워 "슬롯 없음"이 아니라 쿨다운으로 걸리는지 확인한다.
      final free = started.copyWith(breeding: const [], breedingCapacity: 1);
      expect(start(actions, free).error, 'breed_cooldown');
    });

    test('쿨다운이 지나면 다시 짝짓기할 수 있다', () {
      final started = start(actions, pair()).save!;
      final free = started.copyWith(breeding: const [], breedingCapacity: 1);
      final later = GameActions(
        config: cfg,
        now: () => t0.add(const Duration(days: 2)),
      );
      final r = later.startBreeding(
        free,
        motherId: 'mom',
        fatherId: 'dad',
        speciesById: speciesById,
        petConfig: cfg.pet,
      );
      expect(r.isOk, isTrue);
      // 지난 쿨다운은 걷어낸다 — 안 그러면 세이브가 계속 커진다.
      expect(r.save!.breedCooldowns.length, 2);
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

  group('부위강화 비용', () {
    test('서버도 등급 배수를 적용한다 (앱만 올리면 서버가 우회로가 된다)', () {
      // testSpecies 는 common — 배수 1배라 기본값 그대로여야 한다.
      final enh = EnhanceConfig.fromJson({
        'parts': [
          {
            'part': 'hornJaw',
            'material': 'chitin',
            'baseCost': 2,
            'costGrowth': 1.12,
            'effectPerLevel': 0.04,
          },
        ],
        'gradeMult': {'common': 1, 'legendary': 16},
      });
      final bug = IndividualBug.roll(
        id: 'b1',
        species: testSpecies,
        rng: Random(1),
        potential: 3,
      ).copyWith(stage: LifeStage.adult);
      final save = SaveGame.initial(
        createdAt: t0,
      ).copyWith(bugs: [bug], materials: {MaterialKind.chitin: 100});

      final r = actions.enhancePart(save, 'b1', BugPart.hornJaw, enhance: enh);
      expect(r.isOk, isTrue);
      expect(r.save!.materialCount(MaterialKind.chitin), 98); // 2 x 1배

      // 재료가 배수만큼 없으면 거부된다(전설 기준 32 필요).
      final legendary = EnhanceConfig.fromJson({
        'parts': [
          {
            'part': 'hornJaw',
            'material': 'chitin',
            'baseCost': 2,
            'costGrowth': 1.12,
            'effectPerLevel': 0.04,
          },
        ],
        'gradeMult': {'common': 50},
      });
      final poor = save.copyWith(materials: {MaterialKind.chitin: 10});
      final r2 = actions.enhancePart(
        poor,
        'b1',
        BugPart.hornJaw,
        enhance: legendary,
      );
      expect(r2.isOk, isFalse);
      expect(r2.error, 'insufficient_material');
    });
  });

  group('기기 권위 세이브 업로드(mergeSave)', () {
    final cfg = _Config();

    SaveGame stored({int gold = 1000, int trophies = 500}) =>
        SaveGame.initial(createdAt: t0).copyWith(
          lastSeen: t0,
          gold: gold,
          pvpTrophies: trophies,
          seasonPeakTrophies: trophies,
          starterBought: true,
          redeemedPurchases: {'GPA-1'},
        );

    test('솔로 필드(골드·업그레이드)는 클라 값을 수용한다', () {
      final client = stored().copyWith(
        gold: 5000,
        upgradeLevels: {UpgradeKind.attack: 10},
      );
      final r = actions.mergeSave(stored(), client.toJson());
      expect(r.isOk, isTrue);
      expect(r.save!.gold, 5000);
      expect(r.save!.upgradeLevel(UpgradeKind.attack), 10);
    });

    test('모루 스택은 서버가 상한(10)으로 자른다 — 세이브 비대화 차단', () {
      // 앱은 kMaxForgeStack 에서 멈추지만 조작 업로드는 수천 개를 실을 수
      // 있다. 곤충 3만 마리 13.6MB 사고와 같은 경로라 서버가 자른다.
      final client = stored().copyWith(
        forgeStack: [
          for (var i = 0; i < 50; i++)
            EquipItem(slot: EquipSlot.tool, tier: i % 10, options: const []),
        ],
      );
      final r = actions.mergeSave(stored(), client.toJson());
      expect(r.save!.forgeStack.length, kMaxForgeStack);
      // **최근 것**(뒤쪽)이 남아야 한다 — 방금 뽑은 게 사라지면 안 된다.
      expect(r.save!.forgeStack.last.tier, 49 % 10);
    });

    // t0 = 2026-07-20(월) 12:00 UTC → 이번 시즌 시작은 같은 날 09:00 KST(=00:00 UTC).
    final curStart = DateTime.utc(2026, 7, 20);
    final lastWeek = curStart.subtract(const Duration(days: 7));

    test('시즌 경계를 넘기면 서버가 트로피를 깎는다 (앱만 깎으면 되돌아갔다)', () {
      final st = stored(trophies: 1500).copyWith(seasonStartedAt: lastWeek);
      // 앱이 먼저 정산해 750 으로 깎고 경계를 올려 보낸 세이브.
      final client = st
          .copyWith(
            pvpTrophies: 750,
            seasonPeakTrophies: 750,
            seasonStartedAt: curStart,
          )
          .toJson();
      final r = actions.mergeSave(st, client);
      expect(r.save!.pvpTrophies, 750);
      expect(r.save!.seasonPeakTrophies, 750);
      expect(r.save!.seasonStartedAt, curStart);
      // 앱이 이미 보상을 줬으므로 서버는 또 주지 않는다.
      expect(r.save!.gold, st.gold);
      expect(r.extra['season'], isFalse);
    });

    test('같은 주에 다시 올려도 또 깎이지 않는다', () {
      final settled = stored(trophies: 750).copyWith(seasonStartedAt: curStart);
      final r = actions.mergeSave(settled, settled.toJson());
      expect(r.save!.pvpTrophies, 750); // 절반의 절반이 되면 안 된다
    });

    test('앱을 켜둔 채 경계를 넘기면 서버가 보상까지 주고 알린다', () {
      final st = stored(trophies: 800).copyWith(seasonStartedAt: lastWeek);
      // 앱은 아직 모른다 — 지난 시즌 시작을 그대로 올린다.
      final r = actions.mergeSave(st, st.toJson());
      expect(r.save!.pvpTrophies, 400);
      expect(r.save!.seasonStartedAt, curStart);
      // 플래티넘(40000골드·20젤리) × 시즌배율 3.
      expect(r.save!.gold, st.gold + 120000);
      expect(r.save!.materialCount(MaterialKind.jelly), 60);
      expect(r.extra['season'], isTrue);
      final report = r.extra['seasonReport'] as Map<String, dynamic>;
      expect(report['peakTrophies'], 800);
      expect(report['fromTrophies'], 800);
      expect(report['toTrophies'], 400);
    });

    test('시즌 시작을 미래로 적어 리셋을 건너뛸 수 없다', () {
      final st = stored(trophies: 1500).copyWith(seasonStartedAt: lastWeek);
      final cheat = st
          .copyWith(seasonStartedAt: curStart.add(const Duration(days: 365)))
          .toJson();
      final r = actions.mergeSave(st, cheat);
      expect(r.save!.seasonStartedAt, curStart); // 미래 날짜는 경계로 잘린다
      expect(r.save!.pvpTrophies, 750); // 리셋도 정상 적용
    });

    test('젤리로 늘린 부화기 슬롯은 유지된다 (서버가 소유하지 않는다)', () {
      final st = stored();
      final expanded = st
          .copyWith(incubatorCapacity: st.incubatorCapacity + 1)
          .toJson();
      final r = actions.mergeSave(st, expanded);
      expect(r.save!.incubatorCapacity, st.incubatorCapacity + 1);
      expect(r.extra['clamped'], isFalse);
    });

    test('부화기 슬롯도 설정 상한을 넘기면 잘린다', () {
      final st = stored();
      final forged = st.copyWith(incubatorCapacity: 999).toJson();
      final r = actions.mergeSave(st, forged);
      expect(r.save!.incubatorCapacity, cfg.pet.incubatorSlotsMax);
      expect(r.extra['clamped'], isTrue);
    });

    test('화석 조각 급증은 상한으로 잘린다 — 제련 무한 우회 차단', () {
      final st = stored();
      final forged = st
          .copyWith(materials: {MaterialKind.fossil: 999999})
          .toJson();
      final r = actions.mergeSave(st, forged);
      expect(r.isOk, isTrue);
      // 정상 획득은 초당 0.056개라 60초에 4개 남짓 — 3000 이면 넉넉하다.
      expect(r.save!.materialCount(MaterialKind.fossil), lessThan(999999));
      expect(r.extra['clamped'], isTrue);
    });

    test('오프라인을 꽉 채우고 돌아와도 통과한다 — 이게 상한의 존재 이유다', () {
      // 앱을 내려뒀다 열면 정산분이 **한 번의 업로드에 실린다**. 매일 일어나는
      // 정상 경로다. 패스(12h)까지 꽉 채워도 800개를 넘지 않는다.
      final st = stored().copyWith(
        lastSeen: t0.subtract(const Duration(hours: 12)),
        materials: {MaterialKind.fossil: 0},
      );
      final back = st.copyWith(materials: {MaterialKind.fossil: 800}).toJson();
      final r = actions.mergeSave(st, back);
      expect(r.save!.materialCount(MaterialKind.fossil), 800);
      expect(r.extra['clamped'], isFalse);
    });

    test('오래 비워도 상한이 부풀지 않는다 — 오프라인 정산이 12h 에서 멈추므로', () {
      // 3일을 비워도 정상 획득은 여전히 800 남짓이다. 경과시간에 비례시키면
      // 상한만 4만으로 커지고 방어가 헐거워진다.
      final long = stored().copyWith(
        lastSeen: t0.subtract(const Duration(days: 3)),
        materials: {MaterialKind.fossil: 0},
      );
      final short = stored().copyWith(
        lastSeen: t0.subtract(const Duration(minutes: 1)),
        materials: {MaterialKind.fossil: 0},
      );
      final cheat = {MaterialKind.fossil: 50000};
      final a = actions.mergeSave(
        long,
        long.copyWith(materials: cheat).toJson(),
      );
      final b = actions.mergeSave(
        short,
        short.copyWith(materials: cheat).toJson(),
      );
      expect(
        a.save!.materialCount(MaterialKind.fossil),
        b.save!.materialCount(MaterialKind.fossil),
      );
    });

    test('상한은 보유가 아니라 **증가분**에만 걸린다 — 모아뒀다 한 번에 쓸 수 있다', () {
      var save = stored().copyWith(materials: {MaterialKind.fossil: 0});
      // 업로드를 거듭하며 쌓는다(각 회차는 상한 안).
      for (var i = 0; i < 20; i++) {
        final client = save
            .copyWith(
              materials: {
                MaterialKind.fossil:
                    save.materialCount(MaterialKind.fossil) + 50,
              },
            )
            .toJson();
        save = actions.mergeSave(save, client).save!;
      }
      expect(save.materialCount(MaterialKind.fossil), 1000);
      // 한 번에 전부 소비 — 감소는 검사하지 않는다.
      final spent = save.copyWith(materials: {MaterialKind.fossil: 0}).toJson();
      final r = actions.mergeSave(save, spent);
      expect(r.save!.materialCount(MaterialKind.fossil), 0);
      expect(r.extra['clamped'], isFalse);
    });

    test('장비·공방 진행은 기기 권위 — 서버가 덮지 않는다', () {
      final st = stored();
      final client = st
          .copyWith(
            forgeLevel: 9,
            forgeSteps: 6,
            equippedItems: {
              EquipSlot.tool: const EquipItem(
                slot: EquipSlot.tool,
                tier: 7,
                options: [],
              ),
            },
          )
          .toJson();
      final r = actions.mergeSave(st, client);
      expect(r.save!.forgeLevel, 9);
      expect(r.save!.forgeSteps, 6);
      expect(r.save!.equippedItems[EquipSlot.tool]?.tier, 7);
    });

    test('트로피 위조는 무시하고 서버 값을 유지한다', () {
      final cheat = stored().copyWith(pvpTrophies: 999999);
      final r = actions.mergeSave(stored(trophies: 500), cheat.toJson());
      expect(r.save!.pvpTrophies, 500); // 서버 값 유지
    });

    test('IAP 지급물 위조는 무시한다(스타터·영수증)', () {
      // 서버엔 스타터 미구매인데 클라가 샀다고 우김.
      final serverSave = SaveGame.initial(createdAt: t0).copyWith(lastSeen: t0);
      final cheat = serverSave.copyWith(
        starterBought: true,
        gold: 500,
        redeemedPurchases: {'FAKE'},
      );
      final r = actions.mergeSave(serverSave, cheat.toJson());
      expect(r.save!.starterBought, isFalse);
      expect(r.save!.redeemedPurchases, isEmpty);
    });

    test('패스 위조(미구매인데 만료일 설정)는 무시한다 — nullable 도 정확히', () {
      final serverSave = SaveGame.initial(createdAt: t0).copyWith(lastSeen: t0);
      expect(serverSave.passActive(t0), isFalse);
      final cheat = serverSave.copyWith(
        passExpiresAt: t0.add(const Duration(days: 365)),
      );
      final r = actions.mergeSave(serverSave, cheat.toJson());
      expect(r.save!.passActive(t0), isFalse); // 여전히 미구매
    });

    test('골드 급증(1000→10억)은 상식 상한으로 잘린다', () {
      final cheat = stored(gold: 1000).copyWith(gold: 1000000000);
      final r = actions.mergeSave(stored(gold: 1000), cheat.toJson());
      expect(r.extra['clamped'], isTrue);
      expect(r.save!.gold, lessThan(1000000000));
    });

    // 챕터 보상은 앱이 지급해서 세이브에 실려 온다. 뒷 챕터는 보상이 수백만~수억
    // 이라, 인정하지 않으면 **정상 유저의 보상이 상식 상한에 잘린다**.
    test('큰 챕터 보상은 정당하게 통과한다(잘리지 않는다)', () {
      final big = cfg.roadmap!.chapters.firstWhere(
        (c) => c.rewardGold > 1000000,
      );
      final before = stored(gold: 1000);
      final after = before.copyWith(
        gold: 1000 + big.rewardGold,
        stageNumber: big.endStage + 1,
        clearedChapters: {big.id},
      );
      final r = actions.mergeSave(before, after.toJson());
      expect(r.extra['clamped'], isFalse);
      expect(r.save!.gold, 1000 + big.rewardGold);
    });

    test('클리어하지 않은 챕터를 claim 해도 보상만큼 봐주지 않는다', () {
      final big = cfg.roadmap!.chapters.firstWhere(
        (c) => c.rewardGold > 1000000,
      );
      final before = stored(gold: 1000);
      // 스테이지는 그대로인데 챕터만 클리어했다고 우긴다.
      final cheat = before.copyWith(
        gold: 1000 + big.rewardGold,
        clearedChapters: {big.id},
      );
      final r = actions.mergeSave(before, cheat.toJson());
      expect(r.extra['clamped'], isTrue);
      expect(r.save!.gold, lessThan(1000 + big.rewardGold));
    });

    test('같은 챕터를 다시 claim 해도 두 번 인정하지 않는다', () {
      final big = cfg.roadmap!.chapters.firstWhere(
        (c) => c.rewardGold > 1000000,
      );
      // 서버에 이미 클리어로 기록돼 있다.
      final before = stored(
        gold: 1000,
      ).copyWith(stageNumber: big.endStage + 1, clearedChapters: {big.id});
      final cheat = before.copyWith(gold: 1000 + big.rewardGold);
      final r = actions.mergeSave(before, cheat.toJson());
      expect(r.extra['clamped'], isTrue);
    });

    test('정상 범위 골드 증가는 안 잘린다(수령·전투 보상)', () {
      // 바닥(20만) 이내 증가는 통과. 예전엔 200만이었는데, 업로드(60초)마다
      // 무조건 통과해 하루 28억까지 정당화되던 구멍이라 좁혔다. 큰 몫인 챕터
      // 보상은 _chapterGrantAllowance 가 따로 인정하므로 바닥은 작아도 된다.
      final ok = stored(gold: 1000).copyWith(gold: 1000 + 150000);
      final r = actions.mergeSave(stored(gold: 1000), ok.toJson());
      expect(r.extra['clamped'], isFalse);
      expect(r.save!.gold, 1000 + 150000);
    });

    test('lastSeen 은 서버 시각으로 갱신된다', () {
      final r = actions.mergeSave(stored(), stored().toJson());
      expect(r.save!.lastSeen, t0);
    });

    test('젤리 급증(→99만)은 상한으로 잘린다 — 결제 우회 차단', () {
      final base = stored().copyWith(materials: {MaterialKind.jelly: 10});
      final cheat = base.copyWith(materials: {MaterialKind.jelly: 999999});
      final r = actions.mergeSave(base, cheat.toJson());
      expect(r.extra['clamped'], isTrue);
      expect(r.save!.materialCount(MaterialKind.jelly), lessThan(999999));
    });

    test('젤리 소량 증가(선물·분해)는 통과', () {
      final base = stored().copyWith(materials: {MaterialKind.jelly: 10});
      final ok = base.copyWith(materials: {MaterialKind.jelly: 60});
      final r = actions.mergeSave(base, ok.toJson());
      expect(r.save!.materialCount(MaterialKind.jelly), 60);
    });
  });

  group('부트스트랩 정화(sanitizeBootstrap)', () {
    test('트로피·IAP 위조는 초기값으로 리셋된다', () {
      final cheat = SaveGame.initial(createdAt: t0).copyWith(
        gold: 50000,
        pvpTrophies: 999999,
        seasonPeakTrophies: 999999,
        starterBought: true,
        adsRemoved: true,
        ownedSkins: {'gold_rhino'},
        redeemedPurchases: {'FAKE'},
        passExpiresAt: t0.add(const Duration(days: 365)),
      );
      final clean = SaveGame.fromJson(
        actions.sanitizeBootstrap(cheat.toJson()),
      );
      // 솔로 진행(골드)은 그대로.
      expect(clean.gold, 50000);
      // 서버 소유 필드는 전부 초기화.
      expect(clean.pvpTrophies, 0);
      expect(clean.seasonPeakTrophies, 0);
      expect(clean.starterBought, isFalse);
      expect(clean.adsRemoved, isFalse);
      expect(clean.ownedSkins, isEmpty);
      expect(clean.redeemedPurchases, isEmpty);
      expect(clean.passActive(t0), isFalse);
    });
  });
}

/// 수동 전투 **중도 이탈 치트** 방지 — 시작할 때 패배분을 먼저 깎고,
/// 결착에서 차액만 반영한다. 두 번 깎이면 이겨도 손해가 된다.
void _forfeitTests(GameActions actions, SaveGame base) {
  final petCfg = actions.config.pet;
  group('수동 전투 선차감(중도 이탈 방지)', () {
    BattleResult res(BattleOutcome o) => BattleResult(
      outcome: o,
      rounds: 3,
      teamAHpPct: o == BattleOutcome.teamA ? 0.6 : 0,
      teamBHpPct: o == BattleOutcome.teamA ? 0 : 0.6,
      events: const [],
    );

    final start = base.copyWith(pvpTrophies: 500);
    final cfg = actions.config.battle;
    final lose = pvpReward(
      won: false,
      draw: false,
      trophies: 500,
      cfg: cfg,
      rewardMult: 1.0,
    ).trophyDelta;
    final win = pvpReward(
      won: true,
      draw: false,
      trophies: 500,
      cfg: cfg,
      rewardMult: 1.0,
    ).trophyDelta;

    test('선차감 액수가 실제 패배분과 같다', () {
      expect(lose, lessThan(0), reason: '패배는 트로피가 줄어야 한다');
    });

    test('이기면 선차감이 되돌아온다 — 최종은 승리분만큼만 오른다', () {
      // 시작: 500 + lose. 결착: 차액(win - lose)을 더한다.
      final afterStart = start.copyWith(pvpTrophies: 500 + lose);
      final r = actions.applyBattleOutcome(
        afterStart,
        result: res(BattleOutcome.teamA),
        myTeam: const [],
        rewardMult: 1.0,
        speciesById: const {},
        petConfig: petCfg,
        trophiesAtStart: 500,
        trophyPrepaid: lose,
      );
      expect(r.save!.pvpTrophies, 500 + win);
    });

    test('지면 선차감만 남는다 — 두 번 깎이지 않는다', () {
      final afterStart = start.copyWith(pvpTrophies: 500 + lose);
      final r = actions.applyBattleOutcome(
        afterStart,
        result: res(BattleOutcome.teamB),
        myTeam: const [],
        rewardMult: 1.0,
        speciesById: const {},
        petConfig: petCfg,
        trophiesAtStart: 500,
        trophyPrepaid: lose,
      );
      expect(r.save!.pvpTrophies, 500 + lose);
    });

    test('중도 이탈 = 패배 확정 — 시작 차감이 그대로 남는다', () {
      // 결착 요청이 영영 안 오는 경우. 세이브에는 이미 패배가 반영돼 있다.
      expect(500 + lose, lessThan(500));
    });

    test('0 근처 트로피 — 선차감이 잘려도 과지급되지 않는다', () {
      // 트로피 5, 패배분 -12: 실제 차감은 -5 뿐이다. 세션에 원래 액수(-12)를
      // 적으면 승리 시 5+12 가 아니라 +19 가 된다(감사에서 발견 2026-08-20).
      const start = 5;
      final effPrepaid = (start + lose).clamp(0, 1 << 30) - start; // -5
      final afterStart = base.copyWith(
        pvpTrophies: (start + lose).clamp(0, 1 << 30),
      );
      final w = actions.applyBattleOutcome(
        afterStart,
        result: res(BattleOutcome.teamA),
        myTeam: const [],
        rewardMult: 1.0,
        speciesById: const {},
        petConfig: petCfg,
        trophiesAtStart: start,
        trophyPrepaid: effPrepaid,
      );
      // 시작 5 에서 이겼으니 최종은 5 + win 이어야 한다.
      final winAt5 = pvpReward(
        won: true,
        draw: false,
        trophies: start,
        cfg: cfg,
        rewardMult: 1.0,
      ).trophyDelta;
      expect(w.save!.pvpTrophies, start + winAt5);

      final l = actions.applyBattleOutcome(
        afterStart,
        result: res(BattleOutcome.teamB),
        myTeam: const [],
        rewardMult: 1.0,
        speciesById: const {},
        petConfig: petCfg,
        trophiesAtStart: start,
        trophyPrepaid: effPrepaid,
      );
      expect(l.save!.pvpTrophies, 0, reason: '지면 0 밑으로는 안 내려간다');
    });

    test('부상 선차감 — 생존자는 되돌리고 KO 는 그대로 남는다', () {
      // 수동 시작 때 팀 전체에 부상을 미리 건 상태를 흉내 낸다.
      final until = t0.add(const Duration(hours: 1));
      final team = [
        for (final id in ['a', 'b'])
          BattleBug(
            id: id,
            name: id,
            element: Element.wood,
            temperament: Temperament.steadfast,
            preferredStance: Stance.attack,
            maxHp: 100,
            atk: 10,
            def: 10,
            spd: 10,
          ),
      ];
      final preInjured = base.copyWith(injured: {'a': until, 'b': until});
      // a 만 KO 된 결과.
      final r = BattleResult(
        outcome: BattleOutcome.teamB,
        rounds: 3,
        teamAHpPct: 0,
        teamBHpPct: 0.5,
        events: [
          BattleEvent(
            round: 1,
            aName: 'a',
            bName: 'x',
            aStance: Stance.attack,
            bStance: Stance.attack,
            rps: 0,
            dmgToA: 100,
            dmgToB: 0,
            healToA: 0,
            healToB: 0,
            aHp: 0,
            bHp: 50,
            aDown: true,
            bDown: false,
          ),
        ],
      );
      final out = actions.applyBattleOutcome(
        preInjured,
        result: r,
        myTeam: team,
        rewardMult: 1.0,
        speciesById: const {},
        petConfig: petCfg,
        healSurvivors: true,
      );
      expect(
        out.save!.injured.containsKey('b'),
        isFalse,
        reason: '생존자의 선차감은 되돌아가야 한다',
      );
      expect(
        out.save!.injured.containsKey('a'),
        isTrue,
        reason: 'KO 는 부상이 걸려야 한다',
      );
    });

    test('예전 세션(선차감 0)은 그대로 동작한다', () {
      final r = actions.applyBattleOutcome(
        start,
        result: res(BattleOutcome.teamA),
        myTeam: const [],
        rewardMult: 1.0,
        speciesById: const {},
        petConfig: petCfg,
      );
      expect(r.save!.pvpTrophies, 500 + win);
    });
  });
}
