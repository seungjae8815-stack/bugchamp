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

  @override
  final DexConfig? dex = DexConfig.fromJson(
    jsonDecode(File('../app/assets/data/dex.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  @override
  final SkillConfig? skill = SkillConfig.fromJson(
    jsonDecode(File('../app/assets/data/skills.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  @override
  final FairyConfig? fairy = FairyConfig.fromJson(
    jsonDecode(File('../app/assets/data/fairies.json').readAsStringSync())
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

    test('운영 지급 뒤 들어온 진짜 결제는 성공으로 받는다(자동 환불 방지)', () {
      // 실패로 돌려주면 앱이 스토어에 완료 통보를 못 해, 승인 안 된 주문을
      // 구글이 3일 뒤 자동 환불한다 — 물건은 나갔는데 돈만 돌아간다.
      final granted = actions.grantPurchase(
        base,
        productId: 'starter_pack',
        purchaseId: 'admin:starter_pack:9-11 미지급건',
      );
      expect(granted.save!.starterBought, isTrue);

      final real = actions.grantPurchase(
        granted.save!,
        productId: 'starter_pack',
        purchaseId: 'GPA-REAL',
      );
      expect(real.isOk, isTrue);
      expect(real.extra['alreadyGranted'], isTrue);
      // 새로 주는 것은 없다 — 승인만 되게 한다.
      expect(real.save!.gold, granted.save!.gold);
      expect(real.save!.redeemedPurchases, contains('GPA-REAL'));
    });

    test('운영 지급은 두 번 나가지 않는다(계정당 1회 유지)', () {
      final granted = actions.grantPurchase(
        base,
        productId: 'starter_pack',
        purchaseId: 'admin:starter_pack:1차',
      );
      final again = actions.grantPurchase(
        granted.save!,
        productId: 'starter_pack',
        purchaseId: 'admin:starter_pack:2차',
      );
      expect(again.isOk, isFalse);
      expect(again.error, 'already_owned');
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

    test('젤리 충전은 하루 횟수까지만 — 패스·광고제거여도 같다(2026-10-02)', () {
      expect(cfg.ticketRefillDailyLimit, greaterThan(0));
      final r = actions.refillPvpTickets(
        spent.copyWith(materials: {MaterialKind.jelly: 30}),
      );
      expect(r.save!.adUseCount(kAdFeaturePvpRefill, dailyDateKey(t0)), 1);
      final maxed = spent.copyWith(
        materials: {MaterialKind.jelly: 300},
        adUseCounts: {kAdFeaturePvpRefill: cfg.ticketRefillDailyLimit},
        adUseDate: dailyDateKey(t0),
        adsRemoved: true,
      );
      final no = actions.refillPvpTickets(maxed);
      expect(no.error, 'refill_limit');
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
    /// ⚠️ 공격·체력·방어도 **재료를 쓴다**(2026-08-30). 예전엔 골드만 있으면
    /// 됐는데, 재료가 중반에 절반 넘게 남아돌아 소비처를 만들었다.
    /// 골드만 넣으면 `insufficient_material` 로 막힌다.
    test('골드·재료가 충분하면 레벨이 오르고 비용이 빠진다', () {
      final rich = SaveGame.initial(createdAt: t0).copyWith(
        gold: 1000000,
        materials: {for (final k in MaterialKind.values) k: 100000},
      );
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
      // 재료는 넉넉히 — 이 테스트가 보는 건 **골드**로 멈추는지다.
      final justOne = SaveGame.initial(createdAt: t0).copyWith(
        gold: upgradeCost(spec, 0),
        materials: {for (final k in MaterialKind.values) k: 100000},
      );
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
      var s = SaveGame.initial(createdAt: t0).copyWith(
        gold: 100000000,
        materials: {for (final k in MaterialKind.values) k: 100000},
      );
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

      // 곤충 대신 일반 재료가 더 들어온다. 한 시드만 보면 곤충 롤이 rng 를
      // 소비해 뒤따르는 재료 종류가 흔들려(+1/−1) 합이 같아질 수 있으므로
      // 여러 시드를 합쳐 비교한다.
      int mats(SaveGame s) => const [
        MaterialKind.chitin,
        MaterialKind.mineral,
        MaterialKind.sap,
      ].fold(0, (a, k) => a + s.materialCount(k));
      var plainBugs = 0, plainMats = 0, releasedMats = 0;
      for (var seed = 1; seed <= 8; seed++) {
        final plain = seeded(seed).sync(base).save!;
        final released = seeded(seed).sync(filtered).save!;
        expect(released.bugs, isEmpty);
        // ⚠️ 프리미엄 재화(젤리)는 자동 통로로 절대 새면 안 된다(§2.6).
        expect(released.materialCount(MaterialKind.jelly), 0);
        plainBugs += plain.bugs.length;
        plainMats += mats(plain);
        releasedMats += mats(released);
      }
      expect(plainBugs, greaterThan(0), reason: '기준 케이스에 곤충이 있어야 비교가 성립한다');
      expect(releasedMats, greaterThan(plainMats));
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

    test('sync 가 진행을 확정한다 — 사냥터 모드면 게이지, 아니면 스테이지', () {
      final r = actions.sync(strong(const Duration(hours: 2)));
      if (_Config().run.zoneMode) {
        // 사냥터 구조(2026-09-14): 방치 정산은 스테이지를 밀지 않고 처치 수를
        // 보스 도전 게이지에 쌓는다. 보스는 유저가 눌러야 나온다.
        expect(r.save!.stageNumber, 1);
        expect(r.save!.zoneKills, greaterThan(0));
      } else {
        expect(r.save!.stageNumber, greaterThan(1));
      }
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

    /// ⚠️ 예전엔 `sp.name.resolve('ko')` 로 하드코딩돼 있었다 — 앱을 영어로
    /// 바꿔도 **상대 이름만 한글**로 나왔다(2026-08-27 실기). 서버가 전투
    /// 로그의 이름을 굽기 때문에 앱에서 고칠 수 없는 자리였다.
    test('상대 이름을 앱이 보낸 언어로 굽는다', () {
      ({String? name}) build(String? locale) {
        final r = locale == null
            ? actions.buildWildTeam(
                withRoster(3),
                tierId: tiers.first.id,
                speciesById: {'a': testSpecies},
                petConfig: petCfg,
                rng: Random(7),
              )
            : actions.buildWildTeam(
                withRoster(3),
                tierId: tiers.first.id,
                speciesById: {'a': testSpecies},
                petConfig: petCfg,
                rng: Random(7),
                locale: locale,
              );
        return (name: r?.team.first.name);
      }

      expect(build('ko').name, '테스트벌레');
      expect(build('en').name, 'T');
      expect(build('ja').name, 'T');
      // 구버전 앱은 locale 을 안 보낸다 → 예전 동작(ko)을 유지한다.
      expect(build(null).name, '테스트벌레');
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

    /// ⚠️ 젤리는 **포텐셜 문턱**(`disassembleJellyMinPotential`) 이상에서만
    /// 나온다. 분해는 곤충이 무한히 나오는 통로라 §2.6("무한히 늘어나는
    /// 통로에는 젤리를 붙이지 않는다")에 걸린다 — 2026-08-30 에 문턱을
    /// 4성 → 5성으로 올렸다.
    test('문턱 이상 포텐셜을 분해하면 젤리를 주고 곤충이 사라진다', () {
      final top = egg(
        'e',
      ).copyWith(potential: cfg.pet.disassembleJellyMinPotential);
      final s = SaveGame.initial(createdAt: t0).copyWith(bugs: [top]);
      final r = actions.disassembleBug(s, 'e', petConfig: cfg.pet);
      expect(r.isOk, isTrue);
      expect(r.save!.bugs, isEmpty);
      expect(r.save!.materialCount(MaterialKind.jelly), greaterThan(0));
    });

    test('합성으로 올린 5성은 분해해도 젤리가 없다(획득 시점 포텐셜 기준, 2026-09-30)', () {
      final min = cfg.pet.disassembleJellyMinPotential;
      final synth = egg('e').copyWith(potential: min, synthUps: 1);
      final s = SaveGame.initial(createdAt: t0).copyWith(bugs: [synth]);
      final r = actions.disassembleBug(s, 'e', petConfig: cfg.pet);
      expect(r.isOk, isTrue);
      expect(r.save!.materialCount(MaterialKind.jelly), 0);
      // 합성 기록이 없는 옛 5성은 그대로 젤리(사장님 확정).
      final legacy = egg('e').copyWith(potential: min);
      final r2 = actions.disassembleBug(
        SaveGame.initial(createdAt: t0).copyWith(bugs: [legacy]),
        'e',
        petConfig: cfg.pet,
      );
      expect(r2.save!.materialCount(MaterialKind.jelly), greaterThan(0));
    });

    test('문턱 미만은 분해해도 젤리가 없다 — 재료만', () {
      final low = egg(
        'e',
      ).copyWith(potential: cfg.pet.disassembleJellyMinPotential - 1);
      final s = SaveGame.initial(createdAt: t0).copyWith(bugs: [low]);
      final r = actions.disassembleBug(s, 'e', petConfig: cfg.pet);
      expect(r.isOk, isTrue);
      expect(r.save!.materialCount(MaterialKind.jelly), 0);
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
    // pets.json 실값을 그대로 따라간다 — 상수를 박아 두면 밸런스를 조일
    // 때마다 이 테스트가 "기능이 깨진 것처럼" 실패한다(2026-08-31 돌파 상향).
    final capL0 = cfg.pet.levelCap(0);
    final gold0 = cfg.pet.breakthroughGoldCost(0);
    final mat0 = cfg.pet.breakthroughMatCost(0);

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

    test('무료 2배는 하루 상한까지만 — 넘으면 조용히 1배', () {
      // 서버가 안 세면 앱의 제한은 무의미하다. 실제로 매번 2배가 나갔다.
      var s = SaveGame.initial(createdAt: t0).copyWith(
        gifts: [
          for (var i = 0; i < 3; i++)
            GiftMail(
              id: 'g$i',
              expiry: t0.add(const Duration(hours: 1)),
              gold: 1000,
            ),
        ],
      );
      final cap = cfg.gift!.freeDoubleDaily;
      var expected = 0;
      for (var i = 0; i < 3; i++) {
        final r = actions.claimGift(s, 'g$i', doubled: true);
        expect(r.isOk, isTrue);
        final got = (r.save!.gold - expected);
        // 2026-09-18: 배수가 선물마다 랜덤(2~4)이라 **설정 함수로** 기대값을
        // 만든다. 숫자를 못 박으면 범위를 바꿀 때마다 테스트가 깨지고,
        // 정작 검사하려던 "상한을 넘으면 1배"는 안 보인다.
        expect(
          got,
          i < cap ? 1000 * cfg.gift!.multiplierFor('g' + i.toString()) : 1000,
        );
        expected = r.save!.gold;
        s = r.save!;
      }
      expect(s.giftDoublesUsed(dailyDateKey(t0)), cap);
    });

    test('패스 보유자는 무제한 2배이고 첫 2배 젤리는 하루 1회뿐이다', () {
      var s = SaveGame.initial(createdAt: t0).copyWith(
        passExpiresAt: t0.add(const Duration(days: 30)),
        gifts: [
          for (var i = 0; i < 3; i++)
            GiftMail(
              id: 'g$i',
              expiry: t0.add(const Duration(hours: 1)),
              gold: 1000,
            ),
        ],
      );
      for (var i = 0; i < 3; i++) {
        final r = actions.claimGift(s, 'g$i', doubled: true);
        s = r.save!;
      }
      // 배수는 선물마다 랜덤(2~4)이라 id 별로 합친다(2026-09-18).
      var want = 0;
      for (var i = 0; i < 3; i++) {
        want += 1000 * cfg.gift!.multiplierFor('g' + i.toString());
      }
      expect(s.gold, want);
      // 패스 보유자의 2배도 센다(2026-09-28) — 첫 2배 젤리를 하루 1회로 묶으려고.
      // 세도 패스는 자격 검사를 먼저 통과하므로 무제한은 그대로다(위 3회 모두 2배).
      expect(s.giftDoublesUsed(dailyDateKey(t0)), 3);
      expect(
        s.materialCount(MaterialKind.jelly),
        cfg.gift!.doubleJellyFor('g0'),
      );
    });

    test('첫 2배 젤리는 1~5 이고 1배 수령에는 붙지 않는다', () {
      expect(cfg.gift!.doubleJellyMax, greaterThan(0));
      for (var i = 0; i < 200; i++) {
        final j = cfg.gift!.doubleJellyFor('gift-$i');
        expect(j, inInclusiveRange(1, 5));
      }
      final s = SaveGame.initial(createdAt: t0).copyWith(
        gifts: [
          GiftMail(
            id: 'g1',
            expiry: t0.add(const Duration(hours: 1)),
            gold: 1000,
          ),
        ],
      );
      final single = actions.claimGift(s, 'g1').save!;
      expect(single.materialCount(MaterialKind.jelly), 0);
      final doubled = actions.claimGift(s, 'g1', doubled: true);
      expect(
        doubled.save!.materialCount(MaterialKind.jelly),
        cfg.gift!.doubleJellyFor('g1'),
      );
      expect(doubled.extra['bonusJelly'], cfg.gift!.doubleJellyFor('g1'));
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
          // 지금 세대의 앱이 올린 세이브(구세대면 스테이지를 안 믿는다).
          zoneEpoch: kZoneEpoch,
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

    /// 캠페인 끝(로드맵 마지막 스테이지)을 넘긴 값은 접는다. 그런데 접기만
    /// 하고 `clamped` 를 안 세우면 앱이 **채택하지 않는다** — 서버는 1000 으로
    /// 접었는데 앱은 계속 1078 을 들고 60초마다 다시 올리고, 화면에도 접히지
    /// 않은 값이 그대로 보인다(2026-09-01 실기에서 발견).
    test('캠페인 끝을 넘긴 스테이지를 접고, clamped 로 알린다', () {
      final last = cfg.roadmap!.finalStage;
      final client = stored().copyWith(stageNumber: last + 78);
      final r = actions.mergeSave(stored(), client.toJson());
      expect(r.isOk, isTrue);
      expect(r.save!.stageNumber, last, reason: '끝으로 접어야 한다');
      expect(
        r.extra['clamped'],
        isTrue,
        reason: 'clamped 가 없으면 앱이 접힌 값을 채택하지 않는다',
      );
    });

    group('요정(1.0.15)', () {
      final fc = cfg.fairy!;
      final kind = fc.kinds.first.id;
      final sub = fc.subWeight.keys.first;
      Fairy fy(int n, FairyGrade g, {int lv = 1}) =>
          Fairy(id: 'f$n', kind: kind, grade: g, sub: sub, level: lv);
      SaveGame withFairy(FairyState f, {int jelly = 0}) =>
          stored().copyWith(fairy: f, materials: {MaterialKind.jelly: jelly});

      test('합성은 통과한다(등급 가치 합이 늘지 않는다 — 영웅 → 전설 4마리)', () {
        final before = withFairy(
          FairyState(
            fairies: [for (var i = 1; i <= 4; i++) fy(i, FairyGrade.epic)],
            seq: 4,
          ),
        );
        final merged = mergeFairies(before.fairy, fc, [
          'f1',
          'f2',
          'f3',
          'f4',
        ], Random(1)).state!;
        final r = actions.mergeSave(
          before,
          before.copyWith(fairy: merged).toJson(),
        );
        expect(r.save!.fairy, merged);
        expect(r.extra['clamped'], isFalse);
      });

      // 재굴림(2026-10-04, 조정안 C) — 서버가 굴리고, 업로드로는 대기 결과·횟수를 못 바꾼다.
      test('재굴림: 젤리를 쓰고 대기 결과를 적는다 · 고르면 바뀐다', () {
        final before = withFairy(
          FairyState(fairies: [fy(1, FairyGrade.legendary)], seq: 1),
          jelly: 100,
        );
        final r = actions.fairyReroll(before, 'f1');
        expect(r.isOk, isTrue);
        expect(r.save!.materialCount(MaterialKind.jelly), 100 - fc.rerollJelly);
        final pending = r.save!.fairy.reroll!;
        expect(pending.fairyId, 'f1');
        expect(
          r.save!.fairy.fairyById('f1')!.baseRoll,
          0,
          reason: '고르기 전엔 그대로',
        );
        expect(actions.fairyReroll(r.save!, 'f1').error, 'reroll_pending');

        final keep = actions.fairyRerollChoose(r.save!, accept: false);
        expect(keep.save!.fairy.reroll, isNull);
        expect(keep.save!.fairy.fairyById('f1')!.baseRoll, 0);
        final take = actions.fairyRerollChoose(r.save!, accept: true);
        final f = take.save!.fairy.fairyById('f1')!;
        expect(f.baseRoll, pending.baseRoll);
        expect(f.sub, pending.sub);
        expect(f.grade, FairyGrade.legendary);
      });

      test('재굴림: 하루 횟수를 넘으면 막는다', () {
        var s = withFairy(
          FairyState(fairies: [fy(1, FairyGrade.legendary)], seq: 1),
          jelly: 10000,
        );
        for (var i = 0; i < fc.rerollDailyCap; i++) {
          s = actions.fairyReroll(s, 'f1').save!;
          s = actions.fairyRerollChoose(s, accept: false).save!;
        }
        expect(actions.fairyReroll(s, 'f1').error, 'reroll_cap');
      });

      test('재굴림: 업로드로 대기 결과를 지어내거나 횟수를 되돌리지 못한다', () {
        final before = withFairy(
          FairyState(
            fairies: [fy(1, FairyGrade.legendary)],
            seq: 1,
            rerollDay: '2026-08-15',
            rerollCount: 5,
          ),
        );
        final forged = before.fairy.copyWith(
          reroll: FairyReroll(
            fairyId: 'f1',
            sub: sub,
            baseRoll: kFairyRollMax,
            subRoll: kFairyRollMax,
          ),
          rerollCount: 0,
        );
        final r = actions.mergeSave(
          before,
          before.copyWith(fairy: forged).toJson(),
        );
        expect(r.save!.fairy.reroll, isNull);
        expect(r.save!.fairy.rerollCount, 5);
      });

      test('재굴림 칸을 모르는 1.0.15 앱 업로드 — 지키되 clamped 로 되튀지 않는다', () {
        final before = withFairy(
          FairyState(
            fairies: [fy(1, FairyGrade.legendary)],
            seq: 1,
            rerollDay: '2026-08-15',
            rerollCount: 3,
          ),
        );
        // 옛 앱은 rd/rn 을 버린 채 올린다.
        final old = before.fairy.copyWith(rerollDay: '', rerollCount: 0);
        final r = actions.mergeSave(
          before,
          before.copyWith(fairy: old).toJson(),
        );
        expect(r.save!.fairy.rerollCount, 3);
        expect(r.extra['clamped'], isFalse);
      });

      test('기기에만 있는 대기 결과(고르기 응답 유실)는 지우고 clamped 로 알린다', () {
        final before = withFairy(
          FairyState(fairies: [fy(1, FairyGrade.legendary)], seq: 1),
        );
        final stale = before.fairy.copyWith(
          reroll: FairyReroll(fairyId: 'f1', sub: sub, baseRoll: 5, subRoll: 5),
        );
        final r = actions.mergeSave(
          before,
          before.copyWith(fairy: stale).toJson(),
        );
        expect(r.save!.fairy.reroll, isNull);
        expect(r.extra['clamped'], isTrue);
      });

      // 도감 칸 [n] 개(종류×등급 → 종류×부가 순서로 진짜 키만).
      Set<String> dexOf(int n) => {
        for (final k in fc.kinds)
          for (final g in FairyGrade.values) FairyState.dexKey(k.id, g),
        for (final k in fc.kinds)
          for (final b in fc.subWeight.keys) FairyState.dexSubKey(k.id, b),
      }.take(n).toSet();

      test('도감 마일스톤 — 받은 가속기·가루·화석이 업로드 상한에 잘리지 않는다', () {
        final before = withFairy(FairyState(dex: dexOf(30)));
        var after = before;
        for (var i = 0; i < 4; i++) {
          after = claimFairyDexMilestone(after, fc)!;
        }
        expect(claimFairyDexMilestone(after, fc), isNull, reason: '45칸 전');
        final r = actions.mergeSave(before, after.toJson());
        expect(r.save!.fairy.dexClaimed, 4);
        expect(r.save!.fairy.accelerators, after.fairy.accelerators);
        expect(r.save!.fairy.dust, after.fairy.dust);
        expect(
          r.save!.materialCount(MaterialKind.fossil),
          after.materialCount(MaterialKind.fossil),
        );
      });

      test('도감 칸이 모자라면 받은 수를 인정하지 않는다', () {
        final before = withFairy(FairyState(dex: dexOf(10)));
        final forged = before.copyWith(
          fairy: before.fairy.copyWith(dexClaimed: 8),
        );
        final r = actions.mergeSave(before, forged.toJson());
        expect(r.save!.fairy.dexClaimed, 2, reason: '10칸 = 5·10 두 개만');
      });

      test('받은 수를 되돌려 같은 보상을 다시 받을 수 없다', () {
        final before = withFairy(FairyState(dex: dexOf(30), dexClaimed: 4));
        final rolled = before.copyWith(
          fairy: before.fairy.copyWith(dexClaimed: 0),
        );
        final r = actions.mergeSave(before, rolled.toJson());
        expect(r.save!.fairy.dexClaimed, 4);
      });

      test('알 없이 신화를 한 마리라도 만들어 넣으면 그 요정만 뺀다', () {
        final before = withFairy(FairyState.empty);
        final forged = FairyState(fairies: [fy(1, FairyGrade.mythic)], seq: 1);
        final r = actions.mergeSave(
          before,
          before.copyWith(fairy: forged).toJson(),
        );
        expect(r.save!.fairy.fairies, isEmpty);
        expect(r.extra['clampReasons'], contains('fairy'));
      });

      test('넘친 만큼만 자른다 — 예전부터 있던 요정과 가루·레벨업은 남는다', () {
        final before = withFairy(
          FairyState(
            fairies: [fy(1, FairyGrade.epic), fy(2, FairyGrade.common)],
            dust: 1000,
            seq: 2,
          ),
        );
        final after = before.copyWith(
          fairy: before.fairy.copyWith(
            fairies: [
              fy(1, FairyGrade.epic, lv: 5),
              fy(2, FairyGrade.common),
              fy(3, FairyGrade.mythic),
            ],
            dust: 900,
            seq: 3,
          ),
        );
        final r = actions.mergeSave(before, after.toJson());
        final ids = r.save!.fairy.fairies.map((x) => x.id);
        expect(ids, ['f1', 'f2']);
        expect(r.save!.fairy.fairyById('f1')!.level, 5);
        expect(r.save!.fairy.dust, 900);
      });

      test('모르는 종류·부가·속성석 키 · 없는 도감 칸은 걸러 낸다(세이브 부풀리기)', () {
        final before = withFairy(FairyState.empty);
        final after = before.copyWith(
          fairy: FairyState(
            fairies: [
              fy(1, FairyGrade.common),
              Fairy(id: 'f2', kind: 'nope', grade: FairyGrade.common, sub: sub),
            ],
            stones: {sub: 1, 'x1': 1, 'x2': 1},
            dex: {
              FairyState.dexKey(kind, FairyGrade.common),
              for (var i = 0; i < 500; i++) 'junk$i',
            },
            seq: 2,
          ),
        );
        final r = actions.mergeSave(before, after.toJson());
        final f = r.save!.fairy;
        expect(f.fairies.map((x) => x.id), ['f1']);
        expect(f.stones, {sub: 1});
        expect(f.dex, {FairyState.dexKey(kind, FairyGrade.common)});
      });

      test('가루를 쏟아 넣으면 상한까지만', () {
        final before = withFairy(FairyState.empty);
        final after = before.copyWith(fairy: const FairyState(dust: 1 << 40));
        final r = actions.mergeSave(before, after.toJson());
        expect(r.save!.fairy.dust, lessThan(1 << 30));
        expect(r.save!.fairy.dust, greaterThan(0));
      });

      // ── 2026-10-01 점검에서 나온 구멍 ──
      test('기존 요정의 등급·개체값을 고쳐 올리면 저장본 값으로(레벨은 오른 것 인정)', () {
        final before = withFairy(
          FairyState(fairies: [fy(1, FairyGrade.common)], seq: 1),
        );
        final forged = Fairy(
          id: 'f1',
          kind: kind,
          grade: FairyGrade.mythic,
          sub: sub,
          baseRoll: kFairyRollMax,
          subRoll: kFairyRollMax,
          level: 3,
        );
        final r = actions.mergeSave(
          before,
          before
              .copyWith(fairy: before.fairy.copyWith(fairies: [forged]))
              .toJson(),
        );
        final f = r.save!.fairy.fairyById('f1')!;
        expect(f.grade, FairyGrade.common);
        expect(f.baseRoll, 0);
        expect(f.level, 3);
        expect(r.extra['clampReasons'], contains('fairy'));
      });

      test('같은 id 를 겹쳐 올리면 하나만 남는다', () {
        final before = withFairy(
          FairyState(fairies: [fy(1, FairyGrade.common)], seq: 1),
        );
        final r = actions.mergeSave(
          before,
          before
              .copyWith(
                fairy: before.fairy.copyWith(
                  fairies: [fy(1, FairyGrade.common), fy(1, FairyGrade.common)],
                ),
              )
              .toJson(),
        );
        expect(r.save!.fairy.fairies.length, 1);
      });

      test('가루는 사라진 요정의 분해·환급만큼만 — 분해는 통과, 쏟아 넣기는 잘린다', () {
        final before = withFairy(
          FairyState(
            fairies: [
              fy(1, FairyGrade.legendary, lv: 5),
              fy(2, FairyGrade.common),
            ],
            seq: 2,
          ),
        );
        final rel = releaseFairy(before.fairy, fc, 'f1');
        final ok = actions.mergeSave(
          before,
          before.copyWith(fairy: rel.state).toJson(),
        );
        expect(ok.save!.fairy.dust, rel.state!.dust, reason: '정상 분해는 그대로');
        final forged = actions.mergeSave(
          before,
          before.copyWith(fairy: before.fairy.copyWith(dust: 100000)).toJson(),
        );
        expect(forged.save!.fairy.dust, lessThan(1000));
      });

      test('가짜 도감 칸으로 마일스톤을 부풀려도 화석은 더 나오지 않는다', () {
        final before = withFairy(
          FairyState(fairies: [fy(1, FairyGrade.common)], seq: 1),
        );
        SaveGame up(int claimed) => before.copyWith(
          fairy: before.fairy.copyWith(
            dex: {for (var i = 0; i < 100; i++) 'junk$i'},
            dexClaimed: claimed,
          ),
          materials: {
            ...before.materials,
            MaterialKind.fossil:
                before.materialCount(MaterialKind.fossil) + 1000000000,
          },
        );
        final a = actions.mergeSave(before, up(8).toJson());
        final b = actions.mergeSave(before, up(0).toJson());
        expect(
          a.save!.materialCount(MaterialKind.fossil),
          b.save!.materialCount(MaterialKind.fossil),
        );
        expect(a.save!.fairy.dexClaimed, 0);
      });

      test('보스 첫 처치 알(전설)은 새로 잡은 보스 수만큼 받는다', () {
        final before = withFairy(FairyState.empty);
        var f = FairyState.empty;
        for (final t in [3, 3]) {
          f = fairyBossDrop(f, fc, Random(t), tier: t, firstKill: true).state!;
        }
        final after = before.copyWith(fairy: f, bossDex: {'x01', 'x02'});
        final r = actions.mergeSave(before, after.toJson());
        expect(r.save!.fairy.eggs.length, 2);
        expect(r.save!.fairy.stones.values.fold<int>(0, (a, b) => a + b), 2);
      });

      test('젤리를 쓴 만큼의 뽑기 알은 받는다', () {
        final before = withFairy(FairyState.empty, jelly: 1000);
        final op = drawFairyEggs(
          before.fairy,
          fc,
          Random(1),
          times: 30,
          jellyHave: 1000,
        );
        final after = before.copyWith(
          fairy: op.state,
          materials: {MaterialKind.jelly: 1000 - op.jelly},
        );
        final r = actions.mergeSave(before, after.toJson());
        expect(r.save!.fairy.eggs.length, 30);
      });

      test('속성석을 쏟아 넣으면 개수만 저장본으로', () {
        final before = withFairy(
          FairyState(fairies: [fy(1, FairyGrade.common)], seq: 1),
        );
        final after = before.copyWith(
          fairy: before.fairy.copyWith(stones: {sub: 999}),
        );
        final r = actions.mergeSave(before, after.toJson());
        expect(r.save!.fairy.stones, isEmpty);
        expect(r.save!.fairy.fairies.length, 1);
      });

      test('레벨은 등급 상한으로 자른다', () {
        final before = withFairy(
          FairyState(fairies: [fy(1, FairyGrade.common)], seq: 1),
        );
        final after = before.copyWith(
          fairy: before.fairy.copyWith(
            fairies: [fy(1, FairyGrade.common, lv: 999)],
          ),
        );
        final r = actions.mergeSave(before, after.toJson());
        expect(
          r.save!.fairy.fairies.single.level,
          fc.maxLevelOf(FairyGrade.common),
        );
      });

      test('요정을 모르는 앱(feat 14)의 업로드는 요정을 지우지 않는다', () {
        final before = withFairy(
          FairyState(
            fairies: [fy(1, FairyGrade.legendary)],
            companionId: 'f1',
            seq: 1,
          ),
        );
        final j = before.toJson()
          ..['feat'] = 14
          ..remove('fairy');
        final r = actions.mergeSave(before, j);
        expect(r.save!.fairy, before.fairy);
      });

      test('요정을 아는 앱이 비우면 비운 것으로 본다', () {
        final before = withFairy(
          FairyState(fairies: [fy(1, FairyGrade.common)], seq: 1),
        );
        final j = before.copyWith(fairy: FairyState.empty).toJson();
        final r = actions.mergeSave(before, j);
        expect(r.save!.fairy, FairyState.empty);
      });
    });

    test('곤충 잠금을 모르는 앱(feat 15)의 업로드는 잠금을 지우지 않는다', () {
      const id = 'locked1';
      final before = stored().copyWith(
        bugs: [
          const IndividualBug(
            id: id,
            speciesId: 'kabuto',
            sizeMm: 50,
            potential: 4,
            element: Element.wood,
            temperament: Temperament.cautious,
            sex: Sex.male,
            stage: LifeStage.adult,
          ),
        ],
        lockedBugIds: {id},
      );
      final j = before.toJson()
        ..['feat'] = 15
        ..remove('lockedBugs');
      final r = actions.mergeSave(before, j);
      expect(r.save!.lockedBugIds, {id});
    });

    group('스킬(§2.8)', () {
      final sk = cfg.skill!;
      final legend = sk.skills.firstWhere((d) => d.grade == Grade.legendary);

      test('보스를 새로 잡은 만큼의 조각은 받는다', () {
        final client = stored().copyWith(
          bossDex: {'n01'},
          skillShards: {legend.id: sk.bossFirstKillShards},
        );
        final r = actions.mergeSave(stored(), client.toJson());
        expect(r.save!.skillShards[legend.id], sk.bossFirstKillShards);
        expect(r.extra['clamped'], isFalse);
      });

      test('세이브 편집으로 조각을 쏟아 넣으면 저장본 값으로 되돌린다', () {
        final client = stored().copyWith(
          skillShards: {legend.id: 99999},
          skillGradeShards: {'legendary': 99999},
        );
        final r = actions.mergeSave(stored(), client.toJson());
        expect(r.save!.skillShards, isEmpty);
        expect(r.save!.skillGradeShards, isEmpty);
        expect(r.extra['clamped'], isTrue);
        // 운영 요약이 "무엇이 잘렸나"를 보여 줄 수 있게 사유를 싣는다.
        expect(r.extra['clampReasons'], contains('skill'));
      });

      test('젤리를 써서 뽑은 조각은 받는다(10연 = 조각 100)', () {
        final st = stored().copyWith(materials: {MaterialKind.jelly: 1000});
        final client = st.copyWith(
          materials: {MaterialKind.jelly: 1000 - sk.gachaJellyCost * 10},
          skillShards: {legend.id: sk.gachaShards * 10},
          skillGachaPity: 3,
        );
        final r = actions.mergeSave(st, client.toJson());
        expect(r.save!.skillShards[legend.id], sk.gachaShards * 10);
        expect(r.extra['clamped'], isFalse);
      });

      test('조각 없이 레벨만 올린 편집은 저장본 레벨로 되돌린다', () {
        final client = stored().copyWith(
          skillLevels: {for (final d in sk.skills) d.id: sk.maxLevel},
        );
        final r = actions.mergeSave(stored(), client.toJson());
        expect(r.save!.skillLevels, isEmpty);
        expect(r.extra['clamped'], isTrue);
      });

      test('조각을 써서 올린 레벨(해금 · 수련 완료)은 받는다', () {
        final st = stored().copyWith(
          skillLevels: {legend.id: 1},
          skillShards: {legend.id: 60},
        );
        final need = sk.shardsForLevel(legend, 1);
        final client = st.copyWith(
          skillLevels: {legend.id: 2},
          skillShards: {legend.id: 60 - need},
        );
        final r = actions.mergeSave(st, client.toJson());
        expect(r.save!.skillLevels[legend.id], 2);
        expect(r.extra['clamped'], isFalse);
      });

      test('수련 중이던 스킬이 끝나 오른 한 레벨은 선불이라 받는다', () {
        final st = stored().copyWith(
          skillLevels: {legend.id: 3},
          skillTrainingId: legend.id,
          skillTrainingEndsAt: t0,
        );
        final client = stored().copyWith(skillLevels: {legend.id: 4});
        final r = actions.mergeSave(st, client.toJson());
        expect(r.save!.skillLevels[legend.id], 4);
        expect(r.save!.skillTrainingId, isNull);
      });

      test('스킬 필드를 모르는 앱의 업로드는 조각·수련을 지우지 못한다', () {
        final st = stored().copyWith(
          skillLevels: {legend.id: 2},
          skillShards: {legend.id: 7},
          skillGradeShards: {'epic': 15},
          skillTrainingId: legend.id,
          skillTrainingEndsAt: t0,
        );
        final old = st.toJson()
          ..remove('skillShards')
          ..remove('skillGradeShards')
          ..remove('skillTrainingId')
          ..remove('skillTrainingEndsAt');
        final r = actions.mergeSave(st, old);
        expect(r.save!.skillShards, {legend.id: 7});
        expect(r.save!.skillGradeShards, {'epic': 15});
        expect(r.save!.skillTrainingId, legend.id);
        expect(r.save!.skillLevels[legend.id], 2);
      });

      test('만렙 초과 · 미보유 장착 · 열린 칸 초과를 접는다', () {
        final ids = sk.skills.map((d) => d.id).toList();
        // 이미 정당하게 가진 레벨이다(저장본) — 조각 없이 올린 위조가 아니라 규칙 접기만 본다.
        final st = stored().copyWith(
          skillLevels: {ids[0]: sk.maxLevel, ids[1]: 1, ids[2]: 1},
        );
        final client = st.copyWith(
          skillLevels: {ids[0]: 99, ids[1]: 1, ids[2]: 1},
          equippedSkills: [ids[5], ids[0], ids[1], ids[2]],
        );
        final r = actions.mergeSave(st, client.toJson());
        expect(r.save!.skillLevels[ids[0]], sk.maxLevel);
        expect(r.save!.equippedSkills, [ids[0], ids[1]]);
        expect(r.extra['clamped'], isTrue);
      });
    });

    test('끝 이하의 스테이지는 접지도, clamped 를 세우지도 않는다', () {
      final client = stored().copyWith(stageNumber: 500);
      final r = actions.mergeSave(stored(), client.toJson());
      expect(r.save!.stageNumber, 500);
      expect(r.extra['clamped'], isFalse);
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
    // 2026-09-15: 보상은 그 사냥터 N시간치(chapterClearGold)고 난이도마다 따로다.
    // 극한 뒷 사냥터는 수억이라 인정하지 않으면 잘린다.
    // 마지막 챕터는 빼고 고른다 — 그걸 깨면 스테이지가 캠페인 끝을 넘어 따로
    // 접히고(clamped) 이 테스트가 보려는 것과 섞인다.
    RoadmapChapter bigChapter() => cfg.roadmap!.chapters
        .take(cfg.roadmap!.chapters.length - 1)
        .reduce(
          (a, b) =>
              chapterClearGold(cfg.run, a, 3) >= chapterClearGold(cfg.run, b, 3)
              ? a
              : b,
        );

    test('큰 챕터 보상은 정당하게 통과한다(잘리지 않는다)', () {
      final big = bigChapter();
      final reward = chapterClearGold(cfg.run, big, 3);
      expect(reward, greaterThan(1000000), reason: '상식 상한보다 커야 의미가 있다');
      final before = stored(gold: 1000).copyWith(difficultyTier: 3);
      final after = before.copyWith(
        gold: 1000 + reward,
        stageNumber: big.endStage + 1,
        clearedChapters: {chapterClearKey(big.id, 3)},
      );
      final r = actions.mergeSave(before, after.toJson());
      expect(r.extra['clamped'], isFalse);
      expect(r.save!.gold, 1000 + reward);
    });

    test('다른 난이도의 챕터 키로는 봐주지 않는다', () {
      final big = bigChapter();
      final reward = chapterClearGold(cfg.run, big, 3);
      final before = stored(gold: 1000); // 쉬움
      final cheat = before.copyWith(
        gold: 1000 + reward,
        stageNumber: big.endStage + 1,
        clearedChapters: {chapterClearKey(big.id, 3)}, // 극한 키
      );
      final r = actions.mergeSave(before, cheat.toJson());
      expect(r.extra['clamped'], isTrue);
    });

    // 난이도는 기기 권위라 위조할 수 있다. 저장본이 가 본 최고 난이도에서 한
    // 계단까지만 믿는다 — 쉬움 저장본이 극한으로 뛰어 극한 보상을 받지 못하게.
    test('저장본보다 두 계단 이상 높은 난이도의 챕터 보상은 봐주지 않는다', () {
      final big = bigChapter();
      final reward = chapterClearGold(cfg.run, big, 3);
      final before = stored(gold: 1000); // 쉬움
      final cheat = before.copyWith(
        difficultyTier: 3,
        maxTierReached: 3,
        gold: 1000 + reward,
        stageNumber: big.endStage + 1,
        clearedChapters: {chapterClearKey(big.id, 3)},
      );
      final r = actions.mergeSave(before, cheat.toJson());
      expect(r.extra['clamped'], isTrue);
    });

    // 가 본 난이도로 내려가 있으면 앱은 클리어 보상을 주지 않는다.
    test('아래 난이도로 내려가 있으면 챕터 보상을 봐주지 않는다', () {
      final big = bigChapter();
      final reward = chapterClearGold(cfg.run, big, 2);
      final before = stored(
        gold: 1000,
      ).copyWith(difficultyTier: 2, maxTierReached: 3);
      final cheat = before.copyWith(
        gold: 1000 + reward,
        stageNumber: big.endStage + 1,
        clearedChapters: {chapterClearKey(big.id, 2)},
      );
      final r = actions.mergeSave(before, cheat.toJson());
      expect(r.save!.gold, lessThan(1000 + reward));
    });

    // 줄어들 수 없는 기록 — 이 필드를 모르는 구버전 앱이 키 없이 올려도 지워지지 않는다.
    test('구버전 앱 업로드가 최고 난이도·보스 수집 기록을 지우지 않는다', () {
      final before = stored().copyWith(
        difficultyTier: 1,
        maxTierReached: 2,
        bossDex: {'e03', 'n01'},
      );
      final old = before.toJson()
        ..remove('maxTierReached')
        ..remove('bossDex');
      final r = actions.mergeSave(before, old);
      expect(r.save!.maxTierReached, 2);
      expect(r.save!.bossDex, {'e03', 'n01'});
      // 새 앱이 더 모았으면 합쳐진다.
      final more = before.copyWith(bossDex: {'e03', 'h02'}).toJson();
      expect(actions.mergeSave(before, more).save!.bossDex, {
        'e03',
        'n01',
        'h02',
      });
    });

    // 도감 보스 마일스톤 화석(마지막 2,000)은 오프라인 정산 상한보다 클 수 있다.
    test('보스 수집 마일스톤 화석은 몰아 받아도 잘리지 않는다', () {
      final dex = cfg.dex!;
      final all = <String>{
        for (var t = 0; t < kBossDexTiers; t++)
          for (var z = 1; z <= cfg.run.zonesPerTier; z++)
            cfg.run.bossArtId(t, z),
      };
      final before = stored().copyWith(bossDex: all);
      final fossil = dex.bossMilestones.fold<int>(0, (a, m) => a + m.fossil);
      final after = before.copyWith(
        materials: {MaterialKind.fossil: fossil},
        claimedDex: {for (final m in dex.bossMilestones) m.id},
      );
      final r = actions.mergeSave(before, after.toJson());
      expect(r.extra['clamped'], isFalse);
      expect(r.save!.materialCount(MaterialKind.fossil), fossil);
      // 모은 보스가 없으면 봐주지 않는다.
      final cheat = stored().copyWith(
        materials: {MaterialKind.fossil: fossil},
        claimedDex: {for (final m in dex.bossMilestones) m.id},
      );
      expect(
        actions.mergeSave(stored(), cheat.toJson()).extra['clamped'],
        isTrue,
      );
    });

    // 2026-09-28 운영 알림(7e79fb55 — 쉬움 사냥터 1 · Lv21): 발견·정복 마일스톤은 **정액 골드**
    // (15종 발견 40만)라 신규 유저의 60초 상한(≈20만)을 넘어 정당한 보상이 잘렸다.
    test('도감 발견·정복 마일스톤 골드는 신규 유저가 몰아 받아도 잘리지 않는다', () {
      final dex = cfg.dex!;
      final species = [for (var i = 0; i < 20; i++) 'sp$i'];
      final before = stored(gold: 1000).copyWith(
        dex: {
          for (final id in species)
            id: DexEntry(maxLevel: dex.conquerLevel, raisedToAdult: true),
        },
      );
      final ms = [...dex.discoverMilestones, ...dex.conquerMilestones];
      final gold = ms.fold<int>(0, (a, m) => a + m.gold);
      final after = before.copyWith(
        gold: before.gold + gold,
        claimedDex: {for (final m in ms) m.id},
      );
      final r = actions.mergeSave(before, after.toJson());
      expect(r.extra['clamped'], isFalse);
      expect(r.save!.gold, before.gold + gold);
      // 도감을 채우지 않았으면 봐주지 않는다(받았다고 적기만 한 조작).
      final cheat = stored(
        gold: 1000,
      ).copyWith(gold: 1000 + gold, claimedDex: {for (final m in ms) m.id});
      expect(
        actions.mergeSave(stored(gold: 1000), cheat.toJson()).extra['clamped'],
        isTrue,
      );
    });

    // B안: 가 본 난이도로 다시 올라간 직후 첫 업로드 — 저장본(쉬움)으로 봉투를
    // 재면 극한 수입이 100배라 잘린다.
    test('아래 난이도에서 극한으로 돌아온 직후 60초 수입이 잘리지 않는다', () {
      final finalStart = cfg.run.zoneStartStage(cfg.run.zonesPerTier);
      final before = stored(gold: 1000).copyWith(
        difficultyTier: 0,
        maxTierReached: 3,
        stageNumber: finalStart,
        bestStage: finalStart,
        lastSeen: t0.subtract(const Duration(seconds: 60)),
        // 극한 사냥터 11 에 있는 계정답게 강화를 갖춘다(봉투는 강화만 반영한다).
        upgradeLevels: {for (final k in UpgradeKind.values) k: 200},
      );
      // 극한 사냥터 11 의 60초 수입(처치당 골드 × 초당 1마리) — 봉투 안이어야 한다.
      final perKill = rewardGold(cfg.run, finalStart - 1, 1.0, tier: 3);
      final after = before.copyWith(
        difficultyTier: 3,
        gold: 1000 + perKill * 60,
      );
      final r = actions.mergeSave(before, after.toJson());
      expect(r.extra['clamped'], isFalse, reason: '극한 봉투로 재야 한다');
    });

    // 보스를 깨고 곧장 아래 사냥터로 내려간 채 올라오면 지금 스테이지는 낮다.
    test('보스를 깨고 아래 사냥터로 내려가도 챕터 보상은 인정된다', () {
      final big = bigChapter();
      final reward = chapterClearGold(cfg.run, big, 3);
      final before = stored(gold: 1000).copyWith(difficultyTier: 3);
      final after = before.copyWith(
        gold: 1000 + reward,
        stageNumber: cfg.run.zoneStartStage(1),
        bestStage: big.endStage + 1,
        clearedChapters: {chapterClearKey(big.id, 3)},
      );
      final r = actions.mergeSave(before, after.toJson());
      expect(r.extra['clamped'], isFalse);
    });

    // 전환기: 구버전 앱(평문 키·옛 정액)의 챕터 보상이 잘리지 않는다.
    test('구버전 앱의 평문 챕터 키와 옛 정액 보상을 인정한다', () {
      final ch = cfg.roadmap!.chapters.firstWhere((c) => c.id == 'w9');
      final before = stored(gold: 1000).copyWith(difficultyTier: 2);
      final old =
          before
              .copyWith(
                gold: 1000 + ch.rewardGold,
                stageNumber: ch.endStage + 1,
                clearedChapters: {ch.id},
              )
              .toJson()
            ..remove('maxTierReached');
      final r = actions.mergeSave(before, old);
      expect(r.extra['clamped'], isFalse);
      expect(r.save!.gold, 1000 + ch.rewardGold);
    });

    test('클리어하지 않은 챕터를 claim 해도 보상만큼 봐주지 않는다', () {
      final big = bigChapter();
      final reward = chapterClearGold(cfg.run, big, 3);
      final before = stored(gold: 1000).copyWith(difficultyTier: 3);
      // 스테이지는 그대로인데 챕터만 클리어했다고 우긴다.
      final cheat = before.copyWith(
        gold: 1000 + reward,
        clearedChapters: {chapterClearKey(big.id, 3)},
      );
      final r = actions.mergeSave(before, cheat.toJson());
      expect(r.extra['clamped'], isTrue);
      expect(r.save!.gold, lessThan(1000 + reward));
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

  test('옛 결투 경로 점수는 새 체계로 — 이기면 +1, 지면 0(2026-09-30)', () {
    final before = SaveGame.initial(createdAt: t0).copyWith(pvpTrophies: 40);
    final won = before.copyWith(pvpTrophies: 59, seasonPeakTrophies: 59);
    final lost = before.copyWith(pvpTrophies: 28);
    expect(GameActions.legacyDuelScore(before, won).pvpTrophies, 41);
    expect(GameActions.legacyDuelScore(before, won).seasonPeakTrophies, 41);
    expect(GameActions.legacyDuelScore(before, lost).pvpTrophies, 40);
  });

  group('깜짝선물 2배 횟수 병합(2026-09-30 — 첫 2배 젤리 반복 지급)', () {
    final today = dailyDateKey(t0);
    SaveGame base() =>
        SaveGame.initial(createdAt: t0.subtract(const Duration(minutes: 1)));

    test('기기가 쓴 오늘 횟수가 서버에 남는다(서버 세이브 채택 뒤에도 첫 2배가 안 되살아난다)', () {
      final stored = base();
      final client = stored.copyWith(giftDoubleDate: today, giftDoubleCount: 1);
      final r = actions.mergeSave(stored, client.toJson());
      expect(r.save!.giftDoublesUsed(today), 1);
    });

    test('같은 날엔 0 을 올려도 줄지 않는다', () {
      final stored = base().copyWith(giftDoubleDate: today, giftDoubleCount: 2);
      final client = stored.copyWith(giftDoubleCount: 0);
      final r = actions.mergeSave(stored, client.toJson());
      expect(r.save!.giftDoublesUsed(today), 2);
    });

    test('미래 날짜로 바꿔 되살릴 수 없고, 지난 날짜로 되돌릴 수도 없다', () {
      final stored = base().copyWith(giftDoubleDate: today, giftDoubleCount: 2);
      for (final d in ['2099-01-01', '2000-01-01']) {
        final client = stored.copyWith(giftDoubleDate: d, giftDoubleCount: 0);
        final r = actions.mergeSave(stored, client.toJson());
        expect(r.save!.giftDoubleDate, today, reason: d);
        expect(r.save!.giftDoublesUsed(today), 2, reason: d);
      }
    });

    test('새 날이 되면 기기 값으로 넘어간다', () {
      final stored = base().copyWith(
        giftDoubleDate: '2026-07-19',
        giftDoubleCount: 3,
      );
      final client = stored.copyWith(giftDoubleDate: today, giftDoubleCount: 1);
      final r = actions.mergeSave(stored, client.toJson());
      expect(r.save!.giftDoublesUsed(today), 1);
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

  group('결투 시즌 순위 보상(2026-09-28)', () {
    // t0 = 2026-07-20(월) 12:00 UTC → 기본 설정(월 09:00 KST)으로 이번 시즌은 07-20.
    final a = GameActions(config: _RankConfig(), now: () => t0);
    final curStart = DateTime.utc(2026, 7, 20);
    final lastWeek = curStart.subtract(const Duration(days: 7));
    SaveGame base() => SaveGame.initial(
      createdAt: t0,
    ).copyWith(seasonStartedAt: curStart, pvpTrophies: 120);

    test('표: 1위 100 · 2위 50 · 3위 30 · 4~10위 10 · 그 밖은 0', () {
      final cfg = _RankConfig().battle;
      expect(
        [
          for (final r in [0, 1, 2, 3, 4, 10, 11]) cfg.seasonRankJelly(r),
        ],
        [0, 100, 50, 30, 10, 10, 0],
      );
    });

    test('시즌 id 는 시즌 시작의 KST 날짜다', () {
      expect(seasonIdOf(curStart, _RankConfig().battle), '2026-07-20');
    });

    test('정산된 세이브만 이번 시즌 점수를 찍는다', () {
      final p = a.pvpScoreFor(base());
      expect(p, isNotNull);
      expect(p!.seasonId, '2026-07-20');
      expect(p.save.pvpScoreSeason, '2026-07-20');
      // 경계를 넘긴 뒤 정산 전 — 트로피가 지난 시즌 값이라 새 시즌에 넣지 않는다.
      expect(a.pvpScoreFor(base().copyWith(seasonStartedAt: lastWeek)), isNull);
    });

    test('결산은 결투를 해 본 유저만 · 마지막으로 끝난 시즌까지 한 번', () {
      expect(a.pvpLeagueDue(base()), isNull, reason: '결투 안 함');
      final ended = base().copyWith(pvpScoreSeason: '2026-07-13');
      final due = a.pvpLeagueDue(ended)!;
      expect(due.played, '2026-07-13');
      expect(due.lastEnded, '2026-07-13');
      final done = ended.copyWith(pvpRankRewardSeason: '2026-07-13');
      expect(a.pvpLeagueDue(done), isNull, reason: '이미 결산');
      // 이번 시즌만 뛰었다 — 지난 시즌은 쉰 것(점수 결산은 없다).
      final now = base().copyWith(pvpScoreSeason: '2026-07-20');
      expect(a.pvpLeagueDue(now)!.played, isNull);
    });

    test('여러 주를 쉬어도 옛 시즌 순위 젤리를 다시 주지 않는다(2026-09-30 점검)', () {
      // 07-06 시즌에 뛰고, 07-13 시즌이 끝난 뒤 결산됐다(기록 = 마지막으로 끝난 시즌 07-13).
      final stale = base().copyWith(
        pvpScoreSeason: '2026-07-06',
        pvpRankRewardSeason: '2026-07-13',
      );
      // 한 주 더 지나 07-20 시즌이 끝났다 — 쉰 주의 강등만 있고 07-06 보상은 없다.
      final later = GameActions(
        config: _RankConfig(),
        now: () => DateTime.utc(2026, 7, 28, 1),
      );
      final due = later.pvpLeagueDue(stale)!;
      expect(due.played, isNull);
      expect(due.lastEnded, '2026-07-20');
    });

    test('정산 기간(일 09시~월 09시) — 이번 시즌을 바로 결산하고, 점수는 더 받지 않는다', () {
      // 2026-07-26(일) 10:00 KST = 01:00 UTC.
      final sunday = GameActions(
        config: _RankConfig(),
        now: () => DateTime.utc(2026, 7, 26, 1),
      );
      final played = base().copyWith(pvpScoreSeason: '2026-07-20');
      final due = sunday.pvpLeagueDue(played)!;
      expect(due.played, '2026-07-20');
      expect(due.lastEnded, '2026-07-20');
      expect(sunday.pvpScoreFor(base()), isNull, reason: '마감 뒤에는 순위가 굳는다');
      // 받은 뒤 월 09시가 지나도 다시 결산하지 않는다.
      final settled = played.copyWith(pvpRankRewardSeason: '2026-07-20');
      final monday = GameActions(
        config: _RankConfig(),
        now: () => DateTime.utc(2026, 7, 27, 1),
      );
      expect(monday.pvpLeagueDue(settled), isNull);
      // 마감 전(일 08시 KST)에는 이번 시즌을 결산하지 않는다.
      final before = GameActions(
        config: _RankConfig(),
        now: () => DateTime.utc(2026, 7, 25, 23),
      );
      expect(before.pvpLeagueDue(played)!.played, isNull);
    });

    test('리그 안 1위 — 보상 + 승급 · 순위권 밖이어도 결산 기록은 찍는다', () {
      final s = base().copyWith(pvpScoreSeason: '2026-07-13', pvpLeague: 1);
      final first = a.settlePvpLeague(
        s,
        played: '2026-07-13',
        lastEnded: '2026-07-13',
        rank: 1,
        total: 20,
        trophies: 50,
      );
      expect(first.save!.materialCount(MaterialKind.jelly), 100);
      expect(first.save!.pvpLeague, 2, reason: '상위 20% 승급');
      expect(first.save!.pvpRankRewardSeason, '2026-07-13');
      final res = first.extra['pvpLeagueResult'] as Map;
      expect(res['from'], 'silver');
      expect(res['to'], 'gold');

      final mid = a.settlePvpLeague(
        s,
        played: '2026-07-13',
        lastEnded: '2026-07-13',
        rank: 11,
        total: 20,
        trophies: 50,
      );
      expect(mid.save!.materialCount(MaterialKind.jelly), 0);
      expect(mid.save!.pvpLeague, 1, reason: '가운데는 유지');
      expect(mid.save!.pvpRankRewardSeason, '2026-07-13');

      final low = a.settlePvpLeague(
        s,
        played: '2026-07-13',
        lastEnded: '2026-07-13',
        rank: 19,
        total: 20,
        trophies: 5,
      );
      expect(low.save!.pvpLeague, 0, reason: '하위 20% 강등');

      // 트로피 0 은 순위가 있어도 보상·승급이 없다.
      final zero = a.settlePvpLeague(
        s,
        played: '2026-07-13',
        lastEnded: '2026-07-13',
        rank: 1,
        total: 20,
      );
      expect(zero.save!.materialCount(MaterialKind.jelly), 0);
      expect(zero.save!.pvpLeague, 1);
    });

    test('개편 전 세이브는 첫 업로드에서 리셋 전 트로피로 리그를 확정한다', () {
      // 지난 시즌에 800(플래티넘)을 들고 경계를 넘겼다 — 리셋 뒤 0 으로 유도하면 브론즈가 된다.
      final st = base().copyWith(
        pvpTrophies: 800,
        seasonStartedAt: DateTime.utc(2026, 7, 13),
        lastSeen: t0.subtract(const Duration(minutes: 1)),
        zoneEpoch: kZoneEpoch,
      );
      final r = a.mergeSave(st, st.toJson());
      expect(r.save!.pvpTrophies, lessThan(800), reason: '시즌 리셋은 일어났다');
      expect(r.save!.pvpLeague, 3, reason: '플래티넘을 유지');
    });

    test('지난 시즌을 쉬었으면 한 단계 강등(여러 주를 쉬어도 한 번)', () {
      final s = base().copyWith(
        pvpScoreSeason: '2026-06-29',
        pvpRankRewardSeason: '2026-06-29',
        pvpLeague: 3,
      );
      final due = a.pvpLeagueDue(s)!;
      expect(due.played, isNull);
      final r = a.settlePvpLeague(s, lastEnded: due.lastEnded);
      expect(r.save!.pvpLeague, 2);
      expect((r.extra['pvpLeagueResult'] as Map)['inactive'], isTrue);
      expect(a.pvpLeagueDue(r.save!), isNull, reason: '같은 주에 두 번 강등하지 않는다');
    });

    test('판정 기록은 서버 소유 — 앱이 지워 올려도 되살아난다', () {
      final stored = base().copyWith(
        lastSeen: t0,
        zoneEpoch: kZoneEpoch,
        pvpScoreSeason: '2026-07-13',
        pvpRankRewardSeason: '2026-07-13',
      );
      final client = stored.toJson()
        ..remove('pvpScoreSeason')
        ..remove('pvpRankRewardSeason');
      final r = a.mergeSave(stored, client);
      expect(r.save!.pvpScoreSeason, '2026-07-13');
      expect(r.save!.pvpRankRewardSeason, '2026-07-13');
    });
  });
}

class _RankConfig extends _Config {
  @override
  final BattleConfig battle = const BattleConfig(
    seasonRankRewards: [
      SeasonRankReward(maxRank: 1, jelly: 100),
      SeasonRankReward(maxRank: 2, jelly: 50),
      SeasonRankReward(maxRank: 3, jelly: 30),
      SeasonRankReward(maxRank: 10, jelly: 10),
    ],
  );
}
