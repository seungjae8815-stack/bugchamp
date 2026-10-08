import 'dart:convert';
import 'dart:io';

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:server/src/actions.dart';
import 'package:test/test.dart';

/// 요정·스킬 결제 상품 4종(2026-10) — **실제 iap.json** 으로 서버 지급과 업로드 검사를 본다.
///
/// 지급은 서버가 하고(앱은 채택), 성장 패스 매일 몫은 기기가 준 뒤 업로드한다 — 그 업로드가
/// 요정·스킬 급증 검사에 잘리면 산 물건이 조용히 사라진다.

Map<String, dynamic> _data(String f) =>
    jsonDecode(File('../app/assets/data/$f').readAsStringSync())
        as Map<String, dynamic>;

class _Cfg implements GameConfigLike {
  @override
  final IapConfig iap = IapConfig.fromJson(_data('iap.json'));
  @override
  final BattleConfig battle = BattleConfig.fromJson(_data('battle.json'));
  @override
  final RunConfig run = RunConfig.fromJson(_data('run_config.json'));
  @override
  final PetConfig pet = PetConfig.fromJson(_data('pets.json'));
  @override
  final EnhanceConfig? enhance = EnhanceConfig.fromJson(_data('enhance.json'));
  @override
  final ForgeConfig? forge = ForgeConfig.fromJson(_data('forge.json'));
  @override
  final MissionConfig? mission = MissionConfig.fromJson(_data('missions.json'));
  @override
  final GiftConfig? gift = GiftConfig.fromJson(_data('gifts.json'));
  @override
  final DailyConfig? daily = DailyConfig.fromJson(_data('daily.json'));
  @override
  final RoadmapConfig? roadmap = RoadmapConfig.fromJson(_data('roadmap.json'));
  @override
  final DexConfig? dex = DexConfig.fromJson(_data('dex.json'));
  @override
  final EventConfig? event = EventConfig.fromJson(_data('event.json'));
  @override
  final SkillConfig? skill = SkillConfig.fromJson(_data('skills.json'));
  @override
  final FairyConfig? fairy = FairyConfig.fromJson(_data('fairies.json'));
  @override
  List<Species> get speciesList => const [];
}

void main() {
  // 2026-10-07(수) 12:00 UTC = KST 21:00 수요일 — 이번 주 = 2026-10-05(월) 시작.
  final t0 = DateTime.utc(2026, 10, 7, 12);
  var clock = t0;
  final cfg = _Cfg();
  final actions = GameActions(config: cfg, now: () => clock);
  final base = SaveGame.initial(
    createdAt: t0,
  ).copyWith(lastSeen: t0, zoneEpoch: kZoneEpoch);

  setUp(() => clock = t0);

  int items(
    FairyState f,
    Map<String, int> Function(FairyState) pick,
    String k,
  ) => pick(f)[k] ?? 0;

  group('요정 입문 패키지', () {
    test('영웅 알 1 · 희귀 알 3 · 8시간 가속기 3 · 속성석 3 · 가루 300', () {
      final r = actions.grantPurchase(
        base,
        productId: 'fairy_starter',
        purchaseId: 'GPA-F1',
      );
      expect(r.isOk, isTrue);
      final f = r.save!.fairy;
      expect(f.eggs.where((e) => e.grade == FairyGrade.epic).length, 1);
      expect(f.eggs.where((e) => e.grade == FairyGrade.rare).length, 3);
      expect(items(f, (s) => s.accelerators, 'acc8h'), 3);
      expect(items(f, (s) => s.stones, 'attack'), 1);
      expect(items(f, (s) => s.stones, 'critDamage'), 1);
      expect(items(f, (s) => s.stones, 'bossDamage'), 1);
      expect(f.dust, 300);
      expect(r.save!.boughtOnce, contains('fairy_starter'));
      expect(r.save!.materialCount(MaterialKind.jelly), 0, reason: '젤리 없음');
    });

    test('산 알은 자동 분해 설정이 켜져 있어도 가루가 되지 않는다', () {
      final s = base.copyWith(
        fairy: base.fairy.copyWith(autoReleaseUpTo: FairyGrade.rare),
      );
      final r = actions.grantPurchase(
        s,
        productId: 'fairy_starter',
        purchaseId: 'GPA-F1',
      );
      expect(r.save!.fairy.eggs.length, 4);
      expect(r.save!.fairy.dust, 300);
    });

    test('두 번째 영수증은 already_owned · 같은 영수증은 멱등', () {
      final first = actions.grantPurchase(
        base,
        productId: 'fairy_starter',
        purchaseId: 'GPA-F1',
      );
      final again = actions.grantPurchase(
        first.save!,
        productId: 'fairy_starter',
        purchaseId: 'GPA-F1',
      );
      expect(again.extra['alreadyGranted'], isTrue);
      expect(again.save!.fairy.eggs.length, 4);
      final second = actions.grantPurchase(
        first.save!,
        productId: 'fairy_starter',
        purchaseId: 'GPA-F2',
      );
      expect(second.error, 'already_owned');
    });
  });

  group('스킬 입문 패키지', () {
    test('희귀 만능 100 · 영웅 만능 30 · 계정당 1회', () {
      final r = actions.grantPurchase(
        base,
        productId: 'skill_starter',
        purchaseId: 'GPA-S1',
      );
      expect(r.save!.skillGradeShards, {'rare': 100, 'epic': 30});
      expect(r.save!.boughtOnce, {'skill_starter'});
      final second = actions.grantPurchase(
        r.save!,
        productId: 'skill_starter',
        purchaseId: 'GPA-S2',
      );
      expect(second.error, 'already_owned');
      // 다른 1회 상품은 따로 센다.
      final fairy = actions.grantPurchase(
        r.save!,
        productId: 'fairy_starter',
        purchaseId: 'GPA-F1',
      );
      expect(fairy.isOk, isTrue);
      expect(fairy.save!.boughtOnce, {'skill_starter', 'fairy_starter'});
    });
  });

  group('주간 묶음', () {
    test('2시간 가속기 3 · 속성석 2 · 희귀 만능 20 · 이번 주가 적힌다', () {
      final r = actions.grantPurchase(
        base,
        productId: 'weekly_bundle',
        purchaseId: 'GPA-W1',
      );
      final s = r.save!;
      expect(items(s.fairy, (f) => f.accelerators, 'acc2h'), 3);
      expect(items(s.fairy, (f) => f.stones, 'hp'), 1);
      expect(items(s.fairy, (f) => f.stones, 'attack'), 1);
      expect(s.skillGradeShards['rare'], 20);
      expect(s.weeklyBought['weekly_bundle'], '2026-10-05');
      final p = cfg.iap.byId('weekly_bundle')!;
      expect(
        iapPurchaseBlock(s, p, battle: cfg.battle, now: t0),
        IapBlock.thisWeek,
      );
      // 다음 주 월 09시(KST) = 일 24:00 UTC 부터 다시 살 수 있다.
      final next = iapNextWeekAt(t0, cfg.battle);
      expect(next, DateTime.utc(2026, 10, 12, 0));
      expect(
        iapPurchaseBlock(
          s,
          p,
          battle: cfg.battle,
          now: next.subtract(const Duration(seconds: 1)),
        ),
        IapBlock.thisWeek,
      );
      expect(
        iapPurchaseBlock(s, p, battle: cfg.battle, now: next),
        IapBlock.none,
      );
    });

    test('같은 주 두 번째 영수증도 지급한다(결제 끝난 영수증 거절 = 자동 환불 사고)', () {
      final first = actions.grantPurchase(
        base,
        productId: 'weekly_bundle',
        purchaseId: 'GPA-W1',
      );
      final second = actions.grantPurchase(
        first.save!,
        productId: 'weekly_bundle',
        purchaseId: 'GPA-W2',
      );
      expect(second.isOk, isTrue);
      expect(second.save!.skillGradeShards['rare'], 40);
      // 같은 영수증 재전달은 한 번만.
      final dup = actions.grantPurchase(
        second.save!,
        productId: 'weekly_bundle',
        purchaseId: 'GPA-W2',
      );
      expect(dup.save!.skillGradeShards['rare'], 40);
    });
  });

  group('성장 패스', () {
    test('30일 · 남은 기간에 이어 붙인다 · 결제만으로는 물건이 없다', () {
      final first = actions.grantPurchase(
        base,
        productId: 'growth_pass',
        purchaseId: 'GPA-G1',
      );
      expect(first.save!.growthPassExpiresAt, t0.add(const Duration(days: 30)));
      expect(first.save!.fairy.dust, 0);
      clock = t0.add(const Duration(days: 10));
      final second = actions.grantPurchase(
        first.save!,
        productId: 'growth_pass',
        purchaseId: 'GPA-G2',
      );
      expect(
        second.save!.growthPassExpiresAt,
        t0.add(const Duration(days: 60)),
      );
      // 만료 뒤 사면 지금부터 30일.
      clock = t0.add(const Duration(days: 90));
      final third = actions.grantPurchase(
        second.save!,
        productId: 'growth_pass',
        purchaseId: 'GPA-G3',
      );
      expect(
        third.save!.growthPassExpiresAt,
        clock.add(const Duration(days: 30)),
      );
    });

    test('매일 몫(기기 지급)이 업로드 검사에 잘리지 않는다', () {
      final stored = actions
          .grantPurchase(base, productId: 'growth_pass', purchaseId: 'GPA-G1')
          .save!;
      final claimed = claimGrowthPassDaily(
        stored,
        cfg.iap,
        now: t0,
        today: '2026-10-07',
        fairy: cfg.fairy,
      )!;
      expect(claimed.fairy.dust, 20);
      expect(claimed.skillGradeShards['rare'], 2);
      expect(claimed.fairy.accelerators['acc30m'], 1);
      // 같은 날 두 번은 없다.
      expect(
        claimGrowthPassDaily(
          claimed,
          cfg.iap,
          now: t0,
          today: '2026-10-07',
          fairy: cfg.fairy,
        ),
        isNull,
      );

      clock = t0.add(const Duration(minutes: 1));
      final r = actions.mergeSave(
        stored,
        claimed.copyWith(lastSeen: clock).toJson(),
      );
      expect(r.isOk, isTrue);
      expect(r.save!.fairy.dust, 20);
      expect(r.save!.fairy.accelerators['acc30m'], 1);
      expect(r.save!.skillGradeShards['rare'], 2);
      expect(r.save!.growthPassExpiresAt, stored.growthPassExpiresAt);

      // 대조군 — 검사가 실제로 돌고 있는가(가루를 여유 넘게 올리면 잘린다).
      final forged = actions.mergeSave(
        stored,
        claimed
            .copyWith(
              lastSeen: clock,
              fairy: claimed.fairy.copyWith(dust: 5000),
            )
            .toJson(),
      );
      expect(forged.save!.fairy.dust, lessThan(5000));
    });

    test('업로드가 서버 소유 결제 기록을 지우거나 만들지 못한다', () {
      var stored = actions
          .grantPurchase(base, productId: 'growth_pass', purchaseId: 'GPA-G1')
          .save!;
      stored = actions
          .grantPurchase(stored, productId: 'skill_starter', purchaseId: 'S1')
          .save!;
      stored = actions
          .grantPurchase(stored, productId: 'weekly_bundle', purchaseId: 'W1')
          .save!;
      // 구버전 앱 = 새 키를 모르고 빼고 올린다.
      final oldApp = stored.toJson()
        ..remove('boughtOnce')
        ..remove('growthPassExpiresAt')
        ..remove('weeklyBought');
      final r = actions.mergeSave(stored, oldApp);
      expect(r.save!.boughtOnce, {'skill_starter'});
      expect(r.save!.growthPassExpiresAt, stored.growthPassExpiresAt);
      expect(r.save!.weeklyBought, stored.weeklyBought);

      // 위조 — 패스를 만들고 1회 기록을 지운다.
      final forged = base.copyWith(
        growthPassExpiresAt: t0.add(const Duration(days: 999)),
      );
      final r2 = actions.mergeSave(base, forged.toJson());
      expect(r2.save!.growthPassExpiresAt, isNull);
    });

    test('하루 몫은 업로드 검사 여유보다 한참 작다(가루 500 · 아이템 10)', () {
      final d = cfg.iap.growthPassDaily;
      expect(d.jelly, 0, reason: '매일 도는 통로에 젤리 금지(§2.6)');
      expect(d.fairyDust, lessThan(500 ~/ 5));
      final n =
          d.fairyAccelerators.values.fold(0, (a, b) => a + b) +
          d.fairyStones.values.fold(0, (a, b) => a + b);
      expect(n, lessThan(10 ~/ 2));
    });
  });

  test('새 상품 4종은 젤리를 주지 않는다(jelly_sim 장부 밖)', () {
    for (final id in [
      'fairy_starter',
      'skill_starter',
      'growth_pass',
      'weekly_bundle',
    ]) {
      final p = cfg.iap.byId(id);
      expect(p, isNotNull, reason: id);
      expect(p!.grant.jelly, 0, reason: id);
    }
  });

  test('상품의 요정 키는 fairies.json 에 있는 키다(오타면 조용히 사라진다)', () {
    final f = cfg.fairy!;
    final accels = {for (final a in f.accelerators) a.id};
    final grades = {for (final g in FairyGrade.values) g.key};
    final skillGrades = {for (final g in Grade.values) g.key};
    for (final g in [
      for (final p in cfg.iap.products) p.grant,
      cfg.iap.growthPassDaily,
    ]) {
      expect(accels.containsAll(g.fairyAccelerators.keys), isTrue);
      expect(f.subWeight.keys.toSet().containsAll(g.fairyStones.keys), isTrue);
      expect(grades.containsAll(g.fairyEggs.keys), isTrue);
      expect(skillGrades.containsAll(g.skillGradeShards.keys), isTrue);
    }
  });
}
