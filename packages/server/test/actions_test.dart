import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:server/src/actions.dart';
import 'package:test/test.dart';

final t0 = DateTime.utc(2026, 7, 20, 12, 0, 0);

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
}
