import 'package:core_models/core_models.dart';
import 'package:meta/meta.dart';

import 'enums.dart';

/// 능력치 업그레이드 1종의 곡선 정의 (JSON).
@immutable
class UpgradeSpec {
  const UpgradeSpec({
    required this.kind,
    required this.baseCost,
    required this.costGrowth,
    required this.baseValue,
    required this.perLevel,
  });

  final UpgradeKind kind;
  final double baseCost;
  final double costGrowth;
  final double baseValue;
  final double perLevel;

  /// 레벨 [level] 에서의 스탯 값.
  double valueAt(int level) => baseValue + perLevel * level;

  factory UpgradeSpec.fromJson(Map<String, dynamic> json) => UpgradeSpec(
    kind: UpgradeKind.fromKey(json['kind'] as String),
    baseCost: (json['baseCost'] as num).toDouble(),
    costGrowth: (json['costGrowth'] as num).toDouble(),
    baseValue: (json['baseValue'] as num).toDouble(),
    perLevel: (json['perLevel'] as num).toDouble(),
  );
}

/// 지역(테마) 정의.
@immutable
class RegionConfig {
  const RegionConfig({
    required this.id,
    required this.name,
    required this.bossName,
    required this.habitatKinds,
  });

  /// 기존 필드 id 재활용 가능 (예: 'oak_forest').
  final String id;
  final LocalizedText name;
  final LocalizedText bossName;
  final List<HabitatKind> habitatKinds;

  factory RegionConfig.fromJson(Map<String, dynamic> json) => RegionConfig(
    id: json['id'] as String,
    name: LocalizedText.fromJson(json['name'] as Map<String, dynamic>),
    bossName: LocalizedText.fromJson(json['bossName'] as Map<String, dynamic>),
    habitatKinds: (json['habitatKinds'] as List)
        .cast<String>()
        .map(HabitatKind.fromKey)
        .toList(),
  );
}

/// 런 밸런스 설정 전체 (assets/data/run_config.json 에서 로드).
@immutable
class RunConfig {
  const RunConfig({
    required this.hpBase,
    required this.hpGrowth,
    required this.bossHpMult,
    required this.goldBase,
    required this.goldGrowth,
    required this.xpBase,
    required this.xpGrowth,
    required this.bossRewardMult,
    required this.habitatsPerStage,
    required this.bugDropChance,
    required this.materialDropChance,
    required this.regions,
    required this.upgrades,
    this.stagesPerRegion = 10,
    this.threatBase = 3.0,
    this.threatGrowth = 1.12,
    this.bossThreatMult = 4.0,
  });

  final double hpBase;
  final double hpGrowth;
  final double bossHpMult;
  final double goldBase;
  final double goldGrowth;
  final double xpBase;
  final double xpGrowth;
  final double bossRewardMult;
  final int habitatsPerStage;
  final double bugDropChance;
  final double materialDropChance;
  final List<RegionConfig> regions;
  final Map<UpgradeKind, UpgradeSpec> upgrades;

  /// 지역 1개당 스테이지 수 (넘어가면 다음 지역).
  final int stagesPerRegion;

  /// 서식지의 곤충 반격 위협도(초당 피해) 스케일링.
  final double threatBase;
  final double threatGrowth;
  final double bossThreatMult;

  /// 첫 지역 (하위호환).
  RegionConfig get region => regions.first;

  /// 스테이지 번호(1-based)에 해당하는 지역.
  RegionConfig regionForStage(int stageNumber) {
    final idx = ((stageNumber - 1) ~/ stagesPerRegion).clamp(
      0,
      regions.length - 1,
    );
    return regions[idx];
  }

  UpgradeSpec upgrade(UpgradeKind kind) => upgrades[kind]!;

  factory RunConfig.fromJson(Map<String, dynamic> json) {
    final upgradeList = (json['upgrades'] as List)
        .cast<Map<String, dynamic>>()
        .map(UpgradeSpec.fromJson);
    return RunConfig(
      hpBase: (json['hpBase'] as num).toDouble(),
      hpGrowth: (json['hpGrowth'] as num).toDouble(),
      bossHpMult: (json['bossHpMult'] as num).toDouble(),
      goldBase: (json['goldBase'] as num).toDouble(),
      goldGrowth: (json['goldGrowth'] as num).toDouble(),
      xpBase: (json['xpBase'] as num).toDouble(),
      xpGrowth: (json['xpGrowth'] as num).toDouble(),
      bossRewardMult: (json['bossRewardMult'] as num).toDouble(),
      habitatsPerStage: (json['habitatsPerStage'] as num).toInt(),
      bugDropChance: (json['bugDropChance'] as num).toDouble(),
      materialDropChance: (json['materialDropChance'] as num).toDouble(),
      regions: json['regions'] != null
          ? (json['regions'] as List)
                .cast<Map<String, dynamic>>()
                .map(RegionConfig.fromJson)
                .toList()
          : [RegionConfig.fromJson(json['region'] as Map<String, dynamic>)],
      stagesPerRegion: (json['stagesPerRegion'] as num?)?.toInt() ?? 10,
      upgrades: {for (final u in upgradeList) u.kind: u},
      threatBase: (json['threatBase'] as num?)?.toDouble() ?? 3.0,
      threatGrowth: (json['threatGrowth'] as num?)?.toDouble() ?? 1.12,
      bossThreatMult: (json['bossThreatMult'] as num?)?.toDouble() ?? 4.0,
    );
  }
}
