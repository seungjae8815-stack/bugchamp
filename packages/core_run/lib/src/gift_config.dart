import 'package:core_models/core_models.dart';

import 'dart:math';

import 'package:meta/meta.dart';

/// 깜짝 선물 등급 1개(가중 추첨 대상) (JSON, §6).
@immutable
class GiftTier {
  const GiftTier({
    required this.weight,
    this.gold = 0,
    this.jelly = 0,
    this.chitin = 0,
    this.mineral = 0,
    this.sap = 0,
  });

  final double weight;
  final int gold;
  final int jelly;
  final int chitin;
  final int mineral;
  final int sap;

  factory GiftTier.fromJson(Map<String, dynamic> json) => GiftTier(
    weight: (json['weight'] as num?)?.toDouble() ?? 1,
    gold: (json['gold'] as num?)?.toInt() ?? 0,
    jelly: (json['jelly'] as num?)?.toInt() ?? 0,
    chitin: (json['chitin'] as num?)?.toInt() ?? 0,
    mineral: (json['mineral'] as num?)?.toInt() ?? 0,
    sap: (json['sap'] as num?)?.toInt() ?? 0,
  );
}

/// 깜짝 선물 시스템 설정 (assets/data/gifts.json).
@immutable
class GiftConfig {
  const GiftConfig({
    required this.tiers,
    this.firstDelaySec = 90,
    this.intervalMinSec = 600,
    this.intervalMaxSec = 1500,
    this.expiryHours = 3,
    this.maxActive = 5,
    this.adMultiplier = 2,
    this.adMultiplierMin = 2,
    this.adMultiplierMax = 4,
    this.adMultiplierJelly = 2,
    this.freeDoubleDaily = 1,
  });

  /// 첫 선물까지 지연(초).
  final int firstDelaySec;

  /// 이후 선물 간격 범위(초).
  final int intervalMinSec;
  final int intervalMaxSec;

  /// 유통기한(시간).
  final int expiryHours;

  /// 동시에 쌓일 수 있는 최대 선물 수.
  final int maxActive;

  /// 광고 시청 시 보상 배수.
  final int adMultiplier;

  /// 무료 2배 받기의 배수 범위 — 골드·일반 재료는 선물마다 이 사이에서 뽑는다
  /// (2026-09-18 사장님 지시: 최소 2배, 최대 4배).
  final int adMultiplierMin;
  final int adMultiplierMax;

  /// **젤리만 따로 고정한다.** 깜짝선물은 접속 시간에 비례해 무한히 늘어나는
  /// 통로라(§2.6 젤리 수도꼭지) 여기서 젤리 기대값을 올리면 하루 수입이 그대로
  /// 늘어난다. 2 로 두면 `jelly_sim` 결과가 그대로 유효하다.
  final int adMultiplierJelly;

  /// 선물 [giftId] 의 배수 — **앱과 서버가 같은 값을 얻어야 한다.**
  ///
  /// 그래서 난수 발생기를 쓰지 않고 **id 를 해시**한다. 난수를 쓰면 앱이 뽑은
  /// 값과 서버가 뽑은 값이 달라 "화면엔 4배인데 3배만 들어왔다"가 된다
  /// (선물 수령은 서버 권위다). id 는 유저가 볼 수 없으니 예측도 못 한다.
  int multiplierFor(String giftId) {
    final lo = adMultiplierMin < 1 ? 1 : adMultiplierMin;
    final hi = adMultiplierMax < lo ? lo : adMultiplierMax;
    if (hi == lo) return lo;
    var h = 0x811c9dc5;
    for (final c in giftId.codeUnits) {
      h = (h ^ c) * 0x01000193 & 0x7fffffff;
    }
    return lo + h % (hi - lo + 1);
  }

  /// 재료 [kind] 에 붙는 배수. 젤리만 고정값이다.
  int multiplierForMaterial(String giftId, MaterialKind kind) =>
      kind == MaterialKind.jelly
      ? (adMultiplierJelly < 1 ? 1 : adMultiplierJelly)
      : multiplierFor(giftId);

  /// 무료 2배 수령 횟수/일. 패스 보유자는 무제한(앱이 판단).
  ///
  /// 광고가 비용이던 자리다 — 광고를 없애면서 제동이 통째로 빠졌다.
  /// **1회**(2026-08-20 사장님 결정): 무료 1회는 "2배가 있다"를 가르치는
  /// 맛보기이고, 계속 받는 건 패스의 값어치다. 늘리면 패스를 살 이유가
  /// 그만큼 얇아진다.
  final int freeDoubleDaily;

  final List<GiftTier> tiers;

  double get _totalWeight => tiers.fold(0.0, (a, t) => a + t.weight);

  /// 가중 추첨으로 등급 1개 선택.
  GiftTier rollTier(Random rng) {
    if (tiers.isEmpty) return const GiftTier(weight: 1, gold: 1000);
    final r = rng.nextDouble() * _totalWeight;
    var acc = 0.0;
    for (final t in tiers) {
      acc += t.weight;
      if (r < acc) return t;
    }
    return tiers.last;
  }

  /// 다음 선물까지 대기(초) 무작위.
  int nextIntervalSec(Random rng) {
    final span = intervalMaxSec - intervalMinSec;
    return intervalMinSec + (span > 0 ? rng.nextInt(span) : 0);
  }

  factory GiftConfig.fromJson(Map<String, dynamic> json) => GiftConfig(
    firstDelaySec: (json['firstDelaySec'] as num?)?.toInt() ?? 90,
    intervalMinSec: (json['intervalMinSec'] as num?)?.toInt() ?? 600,
    intervalMaxSec: (json['intervalMaxSec'] as num?)?.toInt() ?? 1500,
    expiryHours: (json['expiryHours'] as num?)?.toInt() ?? 3,
    maxActive: (json['maxActive'] as num?)?.toInt() ?? 5,
    adMultiplier: (json['adMultiplier'] as num?)?.toInt() ?? 2,
    adMultiplierMin:
        (json['adMultiplierMin'] as num?)?.toInt() ??
        (json['adMultiplier'] as num?)?.toInt() ??
        2,
    adMultiplierMax:
        (json['adMultiplierMax'] as num?)?.toInt() ??
        (json['adMultiplier'] as num?)?.toInt() ??
        2,
    adMultiplierJelly:
        (json['adMultiplierJelly'] as num?)?.toInt() ??
        (json['adMultiplier'] as num?)?.toInt() ??
        2,
    freeDoubleDaily: (json['freeDoubleDaily'] as num?)?.toInt() ?? 1,
    tiers: (json['tiers'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(GiftTier.fromJson)
        .toList(),
  );
}
