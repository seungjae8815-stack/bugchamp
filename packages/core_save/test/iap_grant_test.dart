import 'dart:convert';
import 'dart:io';

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:test/test.dart';

Map<String, dynamic> _data(String f) =>
    jsonDecode(File('../app/assets/data/$f').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  final iap = IapConfig.fromJson(_data('iap.json'));
  final fairy = FairyConfig.fromJson(_data('fairies.json'));
  const battle = BattleConfig();
  final t0 = DateTime.utc(2026, 10, 7, 12);
  final base = SaveGame.initial(createdAt: t0);

  SaveGame grant(SaveGame s, String id, {String? pid, DateTime? at}) =>
      applyIapGrant(
        s,
        iap.byId(id)!,
        iap,
        battle: battle,
        now: at ?? t0,
        fairy: fairy,
        purchaseId: pid,
      );

  group('세이브 왕복', () {
    test('결제 기록 3칸이 JSON 을 오가도 같다', () {
      var s = grant(base, 'fairy_starter', pid: 'A');
      s = grant(s, 'growth_pass', pid: 'B');
      s = grant(s, 'weekly_bundle', pid: 'C');
      final back = SaveGame.fromJson(jsonDecode(jsonEncode(s.toJson())));
      expect(back.boughtOnce, {'fairy_starter'});
      expect(back.growthPassExpiresAt, s.growthPassExpiresAt);
      expect(back.weeklyBought, {'weekly_bundle': '2026-10-05'});
    });

    test('기본값이면 키를 생략한다(세이브 크기)', () {
      final j = base.toJson();
      expect(j.containsKey('boughtOnce'), isFalse);
      expect(j.containsKey('growthPassExpiresAt'), isFalse);
      expect(j.containsKey('weeklyBought'), isFalse);
    });

    test('모양이 틀린 값은 던지지 않고 버린다', () {
      final j = base.toJson()
        ..['boughtOnce'] = ['ok', 3]
        ..['growthPassExpiresAt'] = 'not-a-date'
        ..['weeklyBought'] = {'w': 7, 'x': '2026-10-05'};
      final s = SaveGame.fromJson(j);
      expect(s.boughtOnce, {'ok'});
      expect(s.growthPassExpiresAt, isNull);
      expect(s.weeklyBought, {'x': '2026-10-05'});
    });
  });

  group('지급 규칙', () {
    test('산 알도 여유 칸까지 차면 넘친 알은 가루 — 높은 등급이 먼저 들어간다', () {
      final full = base.copyWith(
        fairy: base.fairy.copyWith(
          eggs: [
            for (var i = 0; i < fairy.boxCap + fairy.boxPurchaseSlack - 1; i++)
              FairyEgg(id: 'x$i', grade: FairyGrade.common),
          ],
          seq: 100,
        ),
      );
      final s = grant(full, 'fairy_starter');
      final kept = s.fairy.eggs.where((e) => !e.id.startsWith('x')).toList();
      expect(kept.single.grade, FairyGrade.epic);
      expect(s.fairy.dust, 300 + 3 * (fairy.releaseDust[FairyGrade.rare] ?? 0));
    });

    test('기존 상품(스타터·패스)이 지급된다', () {
      final s = grant(base, 'starter_pack', pid: 'P1');
      expect(s.starterBought, isTrue);
      // 2026-10-08 구성 변경: 젤리 400 · 부화기 +1 · 2시간 가속기 3(골드·재료 뺌).
      expect(s.materialCount(MaterialKind.jelly), 400);
      expect(s.gold, base.gold);
      expect(s.fairy.accelerators['acc2h'], 3);
      expect(s.incubatorCapacity, base.incubatorCapacity + 1);
      expect(s.redeemedPurchases, {'P1'});
      final p = grant(grant(base, 'idle_pass'), 'idle_pass');
      expect(p.passExpiresAt, t0.add(const Duration(days: 60)));
      final b = grant(base, 'buff_pass');
      expect(b.buffPassExpiresAt, t0.add(const Duration(days: 30)));
    });

    test('1회 상품 차단', () {
      final p = iap.byId('skill_starter')!;
      expect(iapIsOncePerAccount(p), isTrue);
      expect(iapPurchaseBlock(base, p, battle: battle, now: t0), IapBlock.none);
      final s = grant(base, 'skill_starter');
      expect(iapPurchaseBlock(s, p, battle: battle, now: t0), IapBlock.owned);
      expect(iapIsOncePerAccount(iap.byId('weekly_bundle')!), isFalse);
    });
  });

  group('성장 패스 매일 몫', () {
    test('패스가 있을 때 하루 한 번 · 밀린 날을 몰아주지 않는다 · 만료 뒤 없음', () {
      expect(
        claimGrowthPassDaily(
          base,
          iap,
          now: t0,
          today: '2026-10-07',
          fairy: fairy,
        ),
        isNull,
        reason: '패스 없음',
      );
      final s = grant(base, 'growth_pass');
      final d1 = claimGrowthPassDaily(
        s,
        iap,
        now: t0,
        today: '2026-10-07',
        fairy: fairy,
      )!;
      expect(d1.dailyClaims[kGrowthPassDailyKey], '2026-10-07');
      // 사흘 뒤 켜도 한 번분.
      final d4 = claimGrowthPassDaily(
        d1,
        iap,
        now: t0.add(const Duration(days: 3)),
        today: '2026-10-10',
        fairy: fairy,
      )!;
      expect(d4.fairy.dust, 2 * iap.growthPassDaily.fairyDust);
      expect(
        claimGrowthPassDaily(
          d4,
          iap,
          now: t0.add(const Duration(days: 31)),
          today: '2026-11-07',
          fairy: fairy,
        ),
        isNull,
        reason: '만료',
      );
    });
  });

  group('스킨 구매 덤(2026-10-08)', () {
    final species = {
      for (final j in (_data('species.json')['species'] as List))
        (j as Map<String, dynamic>)['id'] as String: Species.fromJson(j),
    };
    SaveGame buy(SaveGame s, String id, String pid) => applyIapGrant(
      s,
      iap.byId(id)!,
      iap,
      battle: battle,
      now: t0,
      fairy: fairy,
      purchaseId: pid,
      speciesOf: (x) => species[x],
    );

    test('젤리 100 + 그 계열 대표종 4성 알(이색 없음) · 같은 영수증이면 같은 알', () {
      final a = buy(base, 'skin_gold_rhino', 'R1');
      expect(a.materialCount(MaterialKind.jelly), 100);
      final egg = a.bugs.single;
      expect(egg.speciesId, 'rhino_japanese');
      expect(egg.potential, 4);
      expect(egg.stage, LifeStage.egg);
      expect(egg.variant, BugVariant.none);
      expect(buy(base, 'skin_gold_rhino', 'R1').bugs.single.sizeMm, egg.sizeMm);
      expect(
        buy(base, 'skin_albino_stag', 'A1').bugs.single.speciesId,
        'stag_miyama',
      );
    });

    test('채집함이 가득 차면 사기 전에 막는다', () {
      final full = base.copyWith(
        bugs: [
          for (var i = 0; i < base.storageCapacity; i++)
            buy(base, 'skin_gold_rhino', 'F$i').bugs.single,
        ],
      );
      expect(
        iapPurchaseBlock(
          full,
          iap.byId('skin_gold_rhino')!,
          battle: battle,
          now: t0,
        ),
        IapBlock.storageFull,
      );
      expect(
        iapPurchaseBlock(
          base,
          iap.byId('skin_gold_rhino')!,
          battle: battle,
          now: t0,
        ),
        IapBlock.none,
      );
    });

    test('스킨 편의 보너스 — 재료 +30% · 부화 −25% · 짝짓기 −25%', () {
      const owned = {'gold_rhino'};
      expect(iap.skinnedReleaseMaterial(100, owned, 'rhino_japanese'), 130);
      expect(iap.skinnedIncubateSeconds(1000, owned, 'rhino_japanese'), 750);
      expect(iap.skinnedBreedSeconds(1000, owned, 'rhino_japanese'), 750);
      expect(iap.skinnedBreedSeconds(1000, owned, 'stag_giant'), 1000);
    });
  });
}
