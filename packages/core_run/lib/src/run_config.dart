import 'dart:math' as math;

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
    this.materialKind,
    this.materialBaseCost = 0,
    this.materialCostGrowth = 1.0,
    this.valueGrowth,
  });

  final UpgradeKind kind;
  final double baseCost;
  final double costGrowth;
  final double baseValue;
  final double perLevel;

  /// 이 업그레이드가 골드 외에 추가로 요구하는 재료(없으면 null).
  final MaterialKind? materialKind;
  final double materialBaseCost;
  final double materialCostGrowth;

  /// 레벨당 **곱연산** 성장률. 지정하면 [perLevel](덧셈) 대신 이걸 쓴다.
  ///
  /// 왜 필요한가: 덧셈 성장은 비용이 지수(`costGrowth`)라서 **스탯 ∝ log(골드)**
  /// 가 된다. 적 HP 는 스테이지당 `hpGrowth` 배로 지수 증가하므로, 파밍을
  /// 두 배 해도 다음 스테이지를 못 뚫는 구간(진행 벽)이 반드시 생긴다.
  /// [valueGrowth] 를 `costGrowth` 와 같은 값으로 두면 **스탯 ∝ 쓴 골드**가 되어
  /// "막히면 더 모아서 뚫는다"가 성립한다.
  ///
  /// null 이면 기존 덧셈 그대로 — JSON 에 없으면 동작이 안 바뀐다.
  final double? valueGrowth;

  /// 레벨 [level] 에서의 스탯 값.
  double valueAt(int level) => valueGrowth == null
      ? baseValue + perLevel * level
      : baseValue * math.pow(valueGrowth!, level);

  factory UpgradeSpec.fromJson(Map<String, dynamic> json) => UpgradeSpec(
    kind: UpgradeKind.fromKey(json['kind'] as String),
    baseCost: (json['baseCost'] as num).toDouble(),
    costGrowth: (json['costGrowth'] as num).toDouble(),
    baseValue: (json['baseValue'] as num).toDouble(),
    perLevel: (json['perLevel'] as num).toDouble(),
    materialKind: json['materialKind'] != null
        ? MaterialKind.fromKey(json['materialKind'] as String)
        : null,
    materialBaseCost: (json['materialBaseCost'] as num?)?.toDouble() ?? 0,
    materialCostGrowth: (json['materialCostGrowth'] as num?)?.toDouble() ?? 1.0,
    valueGrowth: (json['valueGrowth'] as num?)?.toDouble(),
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
    this.bossFlip = true,
  });

  /// 기존 필드 id 재활용 가능 (예: 'oak_forest').
  final String id;
  final LocalizedText name;
  final LocalizedText bossName;
  final List<HabitatKind> habitatKinds;

  /// 보스 스프라이트를 좌우 반전해 캐릭터(좌측)를 바라보게 할지.
  /// 원본 아트가 오른쪽을 보면 true, 이미 왼쪽을 보면 false.
  final bool bossFlip;

  factory RegionConfig.fromJson(Map<String, dynamic> json) => RegionConfig(
    id: json['id'] as String,
    name: LocalizedText.fromJson(json['name'] as Map<String, dynamic>),
    bossName: LocalizedText.fromJson(json['bossName'] as Map<String, dynamic>),
    habitatKinds: (json['habitatKinds'] as List)
        .cast<String>()
        .map(HabitatKind.fromKey)
        .toList(),
    bossFlip: json['bossFlip'] as bool? ?? true,
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
    this.offlineEfficiency = 0.3,
    this.worldSize = 0,
    this.worldHpMult = 1.0,
    this.worldGoldMult = 1.0,
    this.worldBossHpMult = 1.0,
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

  /// 오프라인 파밍 효율(실시간 대비). 온라인이 훨씬 유리하도록 <1.
  final double offlineEfficiency;

  // ── 월드(회차 아님 — "1-37" 의 1) ──────────────────────────────
  /// 한 월드의 스테이지 수. **0 이면 월드 없음**(구버전 동작 그대로).
  ///
  /// 월드 구조(2026-08 확정): 구간 내에서는 hp·gold 가 같은 속도로 늘어
  /// 순항하고, 월드 경계에서 적 HP 가 [worldHpMult] 배 점프해 **벽**이 된다.
  /// 벽은 이전 월드에서 재화를 모아 업그레이드해야 뚫린다(방치 루프의 핵).
  final int worldSize;

  /// 월드가 하나 넘어갈 때마다 적 HP(·위협도)에 곱해지는 점프.
  final double worldHpMult;

  /// 월드가 하나 넘어갈 때마다 골드·경험치 보상에 곱해지는 점프.
  /// [worldHpMult] 보다 작아야 벽이 생긴다(같으면 벽이 없다).
  final double worldGoldMult;

  /// 월드 **마지막 스테이지 보스**(1-100 의 보스)에 추가로 곱하는 HP 배.
  /// 다음 월드로 가는 관문 — 이 벽을 넘으면 월드가 바뀐다.
  final double worldBossHpMult;

  /// 스테이지가 몇 번째 월드인지(1-based). 월드 없으면 항상 1.
  int worldOf(int stageNumber) =>
      worldSize <= 0 ? 1 : (stageNumber - 1) ~/ worldSize + 1;

  /// 월드 안에서의 스테이지 번호(1-based). "1-37" 의 37.
  int stageInWorld(int stageNumber) =>
      worldSize <= 0 ? stageNumber : (stageNumber - 1) % worldSize + 1;

  /// 이 스테이지가 월드의 마지막(월드 보스)인가.
  bool isWorldFinal(int stageNumber) =>
      worldSize > 0 && stageNumber % worldSize == 0;

  /// 깊이(depth = stage-1)에 대한 월드 점프 누적 배율.
  double worldMult(double per, int depth) =>
      worldSize <= 0 ? 1.0 : math.pow(per, depth ~/ worldSize).toDouble();

  /// 첫 지역 (하위호환).
  RegionConfig get region => regions.first;

  /// 스테이지 번호(1-based)에 해당하는 지역.
  ///
  /// 지역은 **순환**한다(1-25 참나무숲 → … → 1-100 밤숲 → 2-1 다시 참나무숲).
  /// 아트 4종으로 월드 10개를 채우기 위함 — 마지막 지역에서 멈추지 않는다.
  RegionConfig regionForStage(int stageNumber) {
    final idx = ((stageNumber - 1) ~/ stagesPerRegion) % regions.length;
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
      offlineEfficiency: (json['offlineEfficiency'] as num?)?.toDouble() ?? 0.3,
      worldSize: (json['worldSize'] as num?)?.toInt() ?? 0,
      worldHpMult: (json['worldHpMult'] as num?)?.toDouble() ?? 1.0,
      worldGoldMult: (json['worldGoldMult'] as num?)?.toDouble() ?? 1.0,
      worldBossHpMult: (json['worldBossHpMult'] as num?)?.toDouble() ?? 1.0,
    );
  }
}
