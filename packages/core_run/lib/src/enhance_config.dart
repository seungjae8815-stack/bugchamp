import 'dart:math' as math;

import 'package:core_models/core_models.dart';
import 'package:meta/meta.dart';

/// 부위 강화 1종의 재료·비용 곡선·효과 계수 (JSON, §2.2·§6).
@immutable
class EnhancePartSpec {
  const EnhancePartSpec({
    required this.part,
    required this.material,
    required this.baseCost,
    required this.costGrowth,
    required this.effectPerLevel,
  });

  final BugPart part;

  /// 강화에 소비되는 재료.
  final MaterialKind material;
  final double baseCost;
  final double costGrowth;

  /// 주 효과 계수(%/Lv, 0.04 = +4%/Lv). 표시·전투 적용 공용.
  final double effectPerLevel;

  /// 레벨 [level] → [level]+1 강화에 드는 재료 수.
  int costAt(int level) =>
      (baseCost * math.pow(costGrowth, level)).round().clamp(1, 1 << 30);

  factory EnhancePartSpec.fromJson(Map<String, dynamic> json) =>
      EnhancePartSpec(
        part: BugPart.fromKey(json['part'] as String),
        material: MaterialKind.fromKey(json['material'] as String),
        baseCost: (json['baseCost'] as num).toDouble(),
        costGrowth: (json['costGrowth'] as num).toDouble(),
        effectPerLevel: (json['effectPerLevel'] as num).toDouble(),
      );
}

/// 부위 강화 설정 전체 (assets/data/enhance.json 에서 로드).
@immutable
class EnhanceConfig {
  const EnhanceConfig({required this.parts});

  final Map<BugPart, EnhancePartSpec> parts;

  EnhancePartSpec spec(BugPart part) => parts[part]!;

  factory EnhanceConfig.fromJson(Map<String, dynamic> json) {
    final list = (json['parts'] as List).cast<Map<String, dynamic>>().map(
      EnhancePartSpec.fromJson,
    );
    return EnhanceConfig(parts: {for (final s in list) s.part: s});
  }
}
