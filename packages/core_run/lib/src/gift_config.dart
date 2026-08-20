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
    freeDoubleDaily: (json['freeDoubleDaily'] as num?)?.toInt() ?? 1,
    tiers: (json['tiers'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(GiftTier.fromJson)
        .toList(),
  );
}
