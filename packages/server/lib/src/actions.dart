import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';

/// 액션 처리 결과.
class ActionResult {
  const ActionResult.ok(this.save, {this.extra = const {}})
    : error = null,
      status = 200;
  const ActionResult.fail(this.error, {this.status = 400})
    : save = null,
      extra = const {};

  final SaveGame? save;
  final String? error;
  final int status;
  final Map<String, dynamic> extra;

  bool get isOk => save != null;
}

/// 서버 권위 액션들.
///
/// **여기 있는 함수만이 세이브를 바꾼다.** 클라이언트는 "무엇을 하고 싶다"만
/// 보내고, 얼마를 벌었는지·이겼는지는 전부 서버가 정한다.
///
/// 앱과 **같은 `core_*` 코드**로 계산하므로 결과가 어긋나지 않는다.
class GameActions {
  GameActions({required this.config, required this.now});

  final GameConfigLike config;

  /// 서버 시각(주입 가능 — 테스트 결정론).
  final DateTime Function() now;

  /// 구매 지급. **영수증 검증은 호출 전에 끝나 있어야 한다.**
  ///
  /// [purchaseId] 로 중복 지급을 막는다 — 스토어는 같은 구매를 여러 번
  /// 전달할 수 있고, 클라이언트가 재요청할 수도 있다.
  ActionResult grantPurchase(
    SaveGame save, {
    required String productId,
    required String purchaseId,
  }) {
    final product = config.iap.byId(productId);
    if (product == null) {
      return const ActionResult.fail('unknown_product');
    }
    if (save.redeemedPurchases.contains(purchaseId)) {
      // 이미 지급됨 — 오류가 아니라 현재 상태를 그대로 돌려준다(멱등).
      return ActionResult.ok(save, extra: {'alreadyGranted': true});
    }
    if (product.type == IapType.starter && save.starterBought) {
      return const ActionResult.fail('already_owned');
    }

    final t = now().toUtc();
    final g = product.grant;
    final mats = Map<MaterialKind, int>.from(save.materials);
    void add(MaterialKind k, int n) {
      if (n > 0) mats[k] = (mats[k] ?? 0) + n;
    }

    add(MaterialKind.jelly, g.jelly);
    add(MaterialKind.chitin, g.chitin);
    add(MaterialKind.mineral, g.mineral);
    add(MaterialKind.sap, g.sap);

    DateTime? passExpiry = save.passExpiresAt;
    if (product.type == IapType.pass) {
      final base = (passExpiry != null && passExpiry.isAfter(t))
          ? passExpiry
          : t;
      passExpiry = base.add(Duration(days: config.iap.passDurationDays));
    }

    return ActionResult.ok(
      save.copyWith(
        gold: save.gold + g.gold,
        materials: mats,
        incubatorCapacity: save.incubatorCapacity + g.incubatorSlots,
        adsRemoved: save.adsRemoved || product.type == IapType.removeAds,
        starterBought: save.starterBought || product.type == IapType.starter,
        ownedSkins: product.skinId == null
            ? save.ownedSkins
            : {...save.ownedSkins, product.skinId!},
        passExpiresAt: passExpiry,
        redeemedPurchases: {...save.redeemedPurchases, purchaseId},
      ),
    );
  }

  /// 젤리 소비. 잔액이 모자라면 거부한다 — **클라이언트 말을 믿지 않는다.**
  ActionResult spendJelly(SaveGame save, int amount, {String? reason}) {
    if (amount <= 0) return const ActionResult.fail('bad_amount');
    final have = save.materialCount(MaterialKind.jelly);
    if (have < amount) return const ActionResult.fail('insufficient');
    final mats = Map<MaterialKind, int>.from(save.materials)
      ..[MaterialKind.jelly] = have - amount;
    return ActionResult.ok(save.copyWith(materials: mats));
  }
}

/// [GameActions] 가 필요로 하는 설정만 추린 인터페이스 —
/// 테스트에서 가짜 설정을 넣기 쉽게 한다.
abstract interface class GameConfigLike {
  IapConfig get iap;
  BattleConfig get battle;
}
