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
    this.goalMax = 0,
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

  /// 목표 상한(0 = 무제한, 2026-10-10 사장님 확정). `goalGrowth` 가 지수라 받을수록 끝없이 커져
  /// 사냥 20번째 1,734마리 · 강화 20번째 2,850레벨이 됐다(강화는 상한이 있어 영영 못 깬다).
  final int goalMax;

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
  int goalAt(int claims) {
    final raw =
        (goalBase * math.pow(goalGrowth, claims)).round() + goalStep * claims;
    return goalMax > 0 && raw > goalMax ? goalMax : raw;
  }

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
    goalMax: (json['goalMax'] as num?)?.toInt() ?? 0,
    reward: json['reward'] as String,
    rewardMaterial: json['rewardMaterial'] != null
        ? MaterialKind.fromKey(json['rewardMaterial'] as String)
        : null,
    rewardBase: (json['rewardBase'] as num).toDouble(),
    rewardGrowth: (json['rewardGrowth'] as num?)?.toDouble() ?? 1.0,
    rewardMax: (json['rewardMax'] as num?)?.toDouble() ?? 0,
  );
}

/// 미션 교체 횟수를 적는 `missionClaims` 키(2026-10-10).
///
/// 순환 위치 = `missionClaims` 값의 **합** % 미션 수라, 이 키를 1 올리면 보상 없이 다음 미션으로 넘어간다.
/// 세이브 필드를 새로 만들지 않은 이유: 구버전 앱·서버도 같은 합으로 순환 위치를 재서 어긋나지 않고,
/// 모르는 키도 그대로 들고 올린다. 미션 id 와 겹치지 않게 `_` 로 시작한다.
const String kMissionSwapKey = '_swap';

/// 미션 설정 전체 (assets/data/missions.json 에서 로드).
@immutable
class MissionConfig {
  const MissionConfig({required this.missions, this.swapJelly = 0});

  final List<MissionDef> missions;

  /// 진행 중인 미션을 다음 미션으로 바꾸는 젤리(0 = 교체 없음). 깰 수 없는 미션은 무료.
  /// 젤리 소비라 5 단위(§2.6 가격 단위) — 젤리 미션 보상(최대 3)보다 비싸 교체로 젤리를 벌 수 없다.
  final int swapJelly;

  /// 지금 진행 중인 미션의 순번(받은 횟수 + 교체 횟수의 합 % 미션 수).
  int activeIndex(Map<String, int> claims) {
    if (missions.isEmpty) return 0;
    var total = 0;
    for (final v in claims.values) {
      total += v;
    }
    return total % missions.length;
  }

  factory MissionConfig.fromJson(Map<String, dynamic> json) => MissionConfig(
    missions: (json['missions'] as List)
        .cast<Map<String, dynamic>>()
        .map(MissionDef.fromJson)
        .toList(),
    swapJelly: (json['swapJelly'] as num?)?.toInt() ?? 0,
  );
}
