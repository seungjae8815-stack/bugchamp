import 'dart:math' as math;

import 'package:core_models/core_models.dart';
import 'package:meta/meta.dart';

/// 미션 1종 정의 (JSON). 완료 시 클릭 수집 → 보상. 반복(티어)형.
@immutable
class MissionDef {
  const MissionDef({
    required this.id,
    required this.type,
    required this.goalBase,
    required this.reward,
    required this.rewardBase,
    this.goalGrowth = 1.0,
    this.goalStep = 0,
    this.rewardGrowth = 1.0,
    this.rewardMax = 0,
    this.rewardMaterial,
  });

  final String id;
  final MissionType type;

  /// 1티어(claims=0) 목표치.
  final double goalBase;

  /// 티어마다 목표 배율(대부분 미션). reachStage 는 goalStep 사용.
  final double goalGrowth;

  /// reachStage 마일스톤 증가폭(티어당).
  final int goalStep;

  /// 보상 종류: 'gold' | 'material' | 'jelly'.
  final String reward;

  /// reward=='material' 일 때 재료 종류.
  final MaterialKind? rewardMaterial;

  final double rewardBase;
  final double rewardGrowth;

  /// 보상 상한(0 = 무제한). **젤리 보상 미션에는 반드시 둔다.**
  ///
  /// `rewardBase × rewardGrowth^claims` 는 지수라 티어가 쌓이면 끝없이 커진다.
  /// 목표치(`goalGrowth`)도 같이 커지긴 하지만, 프리미엄 재화(§2.6)에
  /// 무한 성장 곡선을 붙이면 후반 유저에게 젤리가 무제한으로 흘러간다.
  final double rewardMax;

  /// [claims] 티어의 목표치.
  int goalAt(int claims) =>
      (goalBase * math.pow(goalGrowth, claims)).round() + goalStep * claims;

  /// [claims] 티어의 보상량.
  int rewardAt(int claims) {
    final raw = rewardBase * math.pow(rewardGrowth, claims);
    final capped = rewardMax > 0 && raw > rewardMax ? rewardMax : raw;
    return capped.round().clamp(1, 1 << 30);
  }

  factory MissionDef.fromJson(Map<String, dynamic> json) => MissionDef(
    id: json['id'] as String,
    type: MissionType.fromKey(json['type'] as String)!,
    goalBase: (json['goalBase'] as num).toDouble(),
    goalGrowth: (json['goalGrowth'] as num?)?.toDouble() ?? 1.0,
    goalStep: (json['goalStep'] as num?)?.toInt() ?? 0,
    reward: json['reward'] as String,
    rewardMaterial: json['rewardMaterial'] != null
        ? MaterialKind.fromKey(json['rewardMaterial'] as String)
        : null,
    rewardBase: (json['rewardBase'] as num).toDouble(),
    rewardGrowth: (json['rewardGrowth'] as num?)?.toDouble() ?? 1.0,
    rewardMax: (json['rewardMax'] as num?)?.toDouble() ?? 0,
  );
}

/// 미션 설정 전체 (assets/data/missions.json 에서 로드).
@immutable
class MissionConfig {
  const MissionConfig({required this.missions});

  final List<MissionDef> missions;

  factory MissionConfig.fromJson(Map<String, dynamic> json) => MissionConfig(
    missions: (json['missions'] as List)
        .cast<Map<String, dynamic>>()
        .map(MissionDef.fromJson)
        .toList(),
  );
}
