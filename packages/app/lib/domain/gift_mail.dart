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
  });

  final String id;

  /// 만료 UTC 시각.
  final DateTime expiry;

  final int gold;
  final int jelly;
  final int chitin;
  final int mineral;
  final int sap;

  bool isExpired(DateTime nowUtc) => !nowUtc.isBefore(expiry);

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
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'expiry': expiry.toUtc().toIso8601String(),
    'gold': gold,
    'jelly': jelly,
    'chitin': chitin,
    'mineral': mineral,
    'sap': sap,
  };
}
