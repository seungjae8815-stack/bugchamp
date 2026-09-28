import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';

import 'gift_mail.dart';
import 'save_game.dart';

/// 깜짝선물 수령 결과. [error] 가 있으면 실패다.
///
/// 만료(`gift_expired`)일 때도 [save] 를 준다 — 선물을 목록에서 뺀 세이브라,
/// 앱은 이걸 저장해 만료 선물을 치운다(서버는 다음 sync 가 정리한다).
typedef GiftClaim = ({
  SaveGame? save,
  String? error,
  int gold,
  int mult,
  bool doubled,
  int bonusJelly,
});

/// 깜짝선물 [giftId] 수령 — **앱과 서버가 같은 함수를 쓴다**(§4).
///
/// 예전엔 같은 규칙이 앱(`SaveController.claimGift`)과 서버(`GameActions.claimGift`)에
/// 두 벌 있었다. 첫 2배 젤리를 붙이면서 한 곳으로 모았다 — 두 벌이면 "화면엔 젤리
/// 3개인데 서버는 안 줬다"가 조용히 생긴다.
///
/// 규칙:
///  - 2배 자격 = 패스 보유 **또는** 오늘 무료 2배([GiftConfig.freeDoubleDaily])가 남음.
///    자격이 없으면 거부가 아니라 **1배**로 준다(이미 뜬 보상을 못 받게 하면 불만이 크다).
///  - 배수는 선물마다 id 해시(2~4), 옛 선물에 남은 젤리만 고정 배수.
///  - **그날 첫 2배**에만 젤리 1~5([GiftConfig.doubleJellyFor]) — 패스 보유자도 하루 1회.
///    그래서 패스 보유자의 2배도 **센다**(예전엔 안 셌다). 세도 패스는 자격 검사에서
///    먼저 통과하므로 무제한은 그대로다.
GiftClaim claimGiftOn(
  SaveGame s,
  GiftConfig? cfg,
  String giftId, {
  required bool doubled,
  required DateTime now,
}) {
  final idx = s.gifts.indexWhere((g) => g.id == giftId);
  if (idx < 0) {
    return (
      save: null,
      error: 'gift_not_found',
      gold: 0,
      mult: 1,
      doubled: false,
      bonusJelly: 0,
    );
  }
  final GiftMail g = s.gifts[idx];
  final gifts = List<GiftMail>.from(s.gifts)..removeAt(idx);
  if (g.isExpired(now)) {
    return (
      save: s.copyWith(gifts: gifts),
      error: 'gift_expired',
      gold: 0,
      mult: 1,
      doubled: false,
      bonusJelly: 0,
    );
  }

  final today = dailyDateKey(now);
  final used = s.giftDoublesUsed(today);
  final cap = cfg?.freeDoubleDaily ?? 1;
  final allowed = doubled && (s.anyPassActive(now) || used < cap);
  final mult = !allowed ? 1 : (cfg?.multiplierFor(g.id) ?? 2);
  final bonusJelly = allowed && used == 0
      ? (cfg?.doubleJellyFor(g.id) ?? 0)
      : 0;

  final mats = Map<MaterialKind, int>.from(s.materials);
  for (final e in g.materials.entries) {
    final m = !allowed ? 1 : (cfg?.multiplierForMaterial(g.id, e.key) ?? mult);
    mats[e.key] = (mats[e.key] ?? 0) + e.value * m;
  }
  if (bonusJelly > 0) {
    mats[MaterialKind.jelly] = (mats[MaterialKind.jelly] ?? 0) + bonusJelly;
  }
  final gold = g.gold * mult;
  return (
    save: s.copyWith(
      gold: addCurrency(s.gold, gold),
      materials: mats,
      gifts: gifts,
      giftDoubleDate: allowed ? today : s.giftDoubleDate,
      giftDoubleCount: allowed ? used + 1 : s.giftDoubleCount,
    ),
    error: null,
    gold: gold,
    mult: mult,
    doubled: allowed,
    bonusJelly: bonusJelly,
  );
}

/// 오늘 2배로 받으면 젤리가 붙는가 — 화면이 **받기 전에** 안내하려고 쓴다.
bool giftDoubleJellyPending(SaveGame s, GiftConfig? cfg, DateTime now) =>
    (cfg?.doubleJellyMax ?? 0) > 0 && s.giftDoublesUsed(dailyDateKey(now)) == 0;
