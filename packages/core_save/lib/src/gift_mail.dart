import 'package:core_models/core_models.dart';

/// 온라인 중 지급되는 깜짝 선물(편지함). 만료(기본 3h)되면 사라진다.
/// 광고 시청 시 배수 보상. 저장되는 상태 모델.
class GiftMail {
  const GiftMail({
    required this.id,
    required this.expiry,
    this.gold = 0,
    this.jelly = 0,
    this.chitin = 0,
    this.mineral = 0,
    this.sap = 0,
    this.minutes = 0,
  });

  final String id;

  /// 만료 UTC 시각.
  final DateTime expiry;

  final int gold;
  final int jelly;
  final int chitin;
  final int mineral;
  final int sap;

  /// 사냥 몇 분치로 만든 선물인가(화면 표시용 "사냥 N분치", 2026-10-08). 0 = 예전 선물(표시 안 함).
  /// 금액은 만들 때 박힌다 — 이 값으로 다시 계산하지 않는다.
  final double minutes;

  bool isExpired(DateTime nowUtc) => !nowUtc.isBefore(expiry);

  /// 금액만 바꾼 사본 — 서버가 상한으로 자를 때 쓴다.
  GiftMail capped({
    required int gold,
    required int chitin,
    required int mineral,
    required int sap,
  }) => GiftMail(
    id: id,
    expiry: expiry,
    gold: gold,
    jelly: jelly,
    chitin: chitin,
    mineral: mineral,
    sap: sap,
    minutes: minutes,
  );

  Map<MaterialKind, int> get materials => {
    if (chitin > 0) MaterialKind.chitin: chitin,
    if (mineral > 0) MaterialKind.mineral: mineral,
    if (sap > 0) MaterialKind.sap: sap,
    if (jelly > 0) MaterialKind.jelly: jelly,
  };

  factory GiftMail.fromJson(Map<String, dynamic> json) => GiftMail(
    id: json['id'] as String,
    expiry: DateTime.parse(json['expiry'] as String).toUtc(),
    gold: (json['gold'] as num?)?.toInt() ?? 0,
    jelly: (json['jelly'] as num?)?.toInt() ?? 0,
    chitin: (json['chitin'] as num?)?.toInt() ?? 0,
    mineral: (json['mineral'] as num?)?.toInt() ?? 0,
    sap: (json['sap'] as num?)?.toInt() ?? 0,
    minutes: (json['min'] as num?)?.toDouble() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'expiry': expiry.toUtc().toIso8601String(),
    'gold': gold,
    'jelly': jelly,
    'chitin': chitin,
    'mineral': mineral,
    'sap': sap,
    if (minutes > 0) 'min': minutes,
  };
}
