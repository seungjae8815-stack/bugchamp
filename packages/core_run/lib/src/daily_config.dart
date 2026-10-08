import 'package:core_models/core_models.dart';
import 'package:meta/meta.dart';

/// 일일 보상 1개(편지함) — 특정 시각(로컬)부터 그날 1회 수령 (JSON, §6).
@immutable
class DailyReward {
  const DailyReward({
    required this.id,
    required this.hour,
    this.gold = 0,
    this.huntMinutes = 0,
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

  /// 이 유저가 지금 자리에서 **몇 분 직접 사냥한 만큼**을 주는가(2026-10-08, `huntMinutesReward`).
  /// 골드·재료 모두 정액([gold]·[chitin] 등)과 **큰 쪽**이다 — 정액은 첫날 바닥값으로 남는다.
  /// 정액만 두면 쉬움 3일차부터 0.1분치도 안 됐다(balance_sim 실측).
  final double huntMinutes;

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
    huntMinutes: (json['huntMinutes'] as num?)?.toDouble() ?? 0,
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

/// "한 번 더 받기"(추가 1배) 수령 기록 키 — `dailyClaims` 에 슬롯과 나란히 적는다(2026-10-08).
/// 구버전 앱은 모르는 키라 건너뛴다.
String dailyBonusKey(String rewardId) => '$rewardId#2';

/// 로컬 날짜 키 'yyyy-MM-dd' (일일 리셋 판정용).
String dailyDateKey(DateTime localNow) =>
    '${localNow.year.toString().padLeft(4, '0')}-'
    '${localNow.month.toString().padLeft(2, '0')}-'
    '${localNow.day.toString().padLeft(2, '0')}';
