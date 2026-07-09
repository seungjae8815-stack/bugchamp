import 'package:core_models/core_models.dart';
import 'package:meta/meta.dart';

/// 일일 보상 1개(편지함) — 특정 시각(로컬)부터 그날 1회 수령 (JSON, §6).
@immutable
class DailyReward {
  const DailyReward({
    required this.id,
    required this.hour,
    this.gold = 0,
    this.jelly = 0,
    this.chitin = 0,
    this.mineral = 0,
    this.sap = 0,
  });

  /// 슬롯 식별자 (예: 'lunch','dinner').
  final String id;

  /// 이 시각(로컬 24h) 이후부터 수령 가능.
  final int hour;

  final int gold;
  final int jelly;
  final int chitin;
  final int mineral;
  final int sap;

  /// 재료 보상 맵(0 제외).
  Map<MaterialKind, int> get materials => {
    if (chitin > 0) MaterialKind.chitin: chitin,
    if (mineral > 0) MaterialKind.mineral: mineral,
    if (sap > 0) MaterialKind.sap: sap,
    if (jelly > 0) MaterialKind.jelly: jelly,
  };

  factory DailyReward.fromJson(Map<String, dynamic> json) => DailyReward(
    id: json['id'] as String,
    hour: (json['hour'] as num).toInt(),
    gold: (json['gold'] as num?)?.toInt() ?? 0,
    jelly: (json['jelly'] as num?)?.toInt() ?? 0,
    chitin: (json['chitin'] as num?)?.toInt() ?? 0,
    mineral: (json['mineral'] as num?)?.toInt() ?? 0,
    sap: (json['sap'] as num?)?.toInt() ?? 0,
  );
}

/// 일일 보상 설정 전체 (assets/data/daily.json 에서 로드).
@immutable
class DailyConfig {
  const DailyConfig({required this.rewards});

  final List<DailyReward> rewards;

  factory DailyConfig.fromJson(Map<String, dynamic> json) => DailyConfig(
    rewards: (json['rewards'] as List)
        .cast<Map<String, dynamic>>()
        .map(DailyReward.fromJson)
        .toList(),
  );
}

/// 로컬 날짜 키 'yyyy-MM-dd' (일일 리셋 판정용).
String dailyDateKey(DateTime localNow) =>
    '${localNow.year.toString().padLeft(4, '0')}-'
    '${localNow.month.toString().padLeft(2, '0')}-'
    '${localNow.day.toString().padLeft(2, '0')}';
