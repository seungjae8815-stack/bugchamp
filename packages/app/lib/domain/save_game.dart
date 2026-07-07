import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';

/// 현재 세이브 스키마 버전. SaveGame.toJson 이 이 값을 기록하고,
/// 로드 시 이 값보다 낮으면 마이그레이션이 실행된다 (see data/save_migrations.dart).
const int kSaveSchemaVersion = 2;

/// 설치된 트랩 1개 (레거시 v1 채집 시스템. v2 에서는 미사용이나 세이브 호환 위해 유지).
class TrapInstallation {
  const TrapInstallation({
    required this.slotIndex,
    required this.fieldId,
    required this.trapId,
    required this.installedAt,
  });

  final int slotIndex;
  final String fieldId;
  final String trapId;
  final DateTime installedAt;

  TrapInstallation copyWith({DateTime? installedAt}) => TrapInstallation(
    slotIndex: slotIndex,
    fieldId: fieldId,
    trapId: trapId,
    installedAt: installedAt ?? this.installedAt,
  );

  factory TrapInstallation.fromJson(Map<String, dynamic> json) =>
      TrapInstallation(
        slotIndex: (json['slotIndex'] as num).toInt(),
        fieldId: json['fieldId'] as String,
        trapId: json['trapId'] as String,
        installedAt: DateTime.parse(json['installedAt'] as String).toUtc(),
      );

  Map<String, dynamic> toJson() => {
    'slotIndex': slotIndex,
    'fieldId': fieldId,
    'trapId': trapId,
    'installedAt': installedAt.toUtc().toIso8601String(),
  };
}

/// 저장 루트 (버전드 JSON 스냅샷). v2: 횡스크롤 런 진행 상태 포함.
class SaveGame {
  const SaveGame({
    required this.schemaVersion,
    required this.bugs,
    required this.materials,
    required this.installations,
    required this.unlockedFieldIds,
    required this.createdAt,
    required this.lastSeen,
    required this.gold,
    required this.xp,
    required this.level,
    required this.upgradeLevels,
    required this.stageNumber,
  });

  final int schemaVersion;

  /// 보관함(수집 개체).
  final List<IndividualBug> bugs;

  /// 재료 인벤토리.
  final Map<MaterialKind, int> materials;

  /// (레거시 v1) 설치된 트랩.
  final List<TrapInstallation> installations;

  /// 해금된 필드/지역 id.
  final Set<String> unlockedFieldIds;

  final DateTime createdAt;

  /// 마지막 활동(저장) 시각. 오프라인 정산 기준.
  final DateTime lastSeen;

  // --- v2 런 진행 ---
  /// 골드 (업그레이드 재화).
  final int gold;

  /// 현재 레벨 진행 경험치.
  final int xp;

  /// 캐릭터 레벨.
  final int level;

  /// 능력치 업그레이드 레벨.
  final Map<UpgradeKind, int> upgradeLevels;

  /// 현재 도달 스테이지 (지역1 기준 1-based).
  final int stageNumber;

  factory SaveGame.initial({DateTime? createdAt}) => SaveGame(
    schemaVersion: kSaveSchemaVersion,
    bugs: const [],
    materials: const {},
    installations: const [],
    unlockedFieldIds: const {'oak_forest'},
    createdAt: (createdAt ?? DateTime.now()).toUtc(),
    lastSeen: (createdAt ?? DateTime.now()).toUtc(),
    gold: 0,
    xp: 0,
    level: 1,
    upgradeLevels: const {},
    stageNumber: 1,
  );

  SaveGame copyWith({
    List<IndividualBug>? bugs,
    Map<MaterialKind, int>? materials,
    List<TrapInstallation>? installations,
    Set<String>? unlockedFieldIds,
    DateTime? lastSeen,
    int? gold,
    int? xp,
    int? level,
    Map<UpgradeKind, int>? upgradeLevels,
    int? stageNumber,
  }) => SaveGame(
    schemaVersion: schemaVersion,
    bugs: bugs ?? this.bugs,
    materials: materials ?? this.materials,
    installations: installations ?? this.installations,
    unlockedFieldIds: unlockedFieldIds ?? this.unlockedFieldIds,
    createdAt: createdAt,
    lastSeen: lastSeen ?? this.lastSeen,
    gold: gold ?? this.gold,
    xp: xp ?? this.xp,
    level: level ?? this.level,
    upgradeLevels: upgradeLevels ?? this.upgradeLevels,
    stageNumber: stageNumber ?? this.stageNumber,
  );

  int materialCount(MaterialKind kind) => materials[kind] ?? 0;

  int upgradeLevel(UpgradeKind kind) => upgradeLevels[kind] ?? 0;

  TrapInstallation? installationAt(int slotIndex) {
    for (final i in installations) {
      if (i.slotIndex == slotIndex) return i;
    }
    return null;
  }

  factory SaveGame.fromJson(Map<String, dynamic> json) => SaveGame(
    schemaVersion: (json['schemaVersion'] as num).toInt(),
    bugs: (json['bugs'] as List)
        .cast<Map<String, dynamic>>()
        .map(IndividualBug.fromJson)
        .toList(),
    materials: _materialsFromJson(json['materials'] as Map<String, dynamic>),
    installations: (json['installations'] as List)
        .cast<Map<String, dynamic>>()
        .map(TrapInstallation.fromJson)
        .toList(),
    unlockedFieldIds: (json['unlockedFieldIds'] as List).cast<String>().toSet(),
    createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
    lastSeen: json['lastSeen'] != null
        ? DateTime.parse(json['lastSeen'] as String).toUtc()
        : DateTime.parse(json['createdAt'] as String).toUtc(),
    gold: (json['gold'] as num).toInt(),
    xp: (json['xp'] as num).toInt(),
    level: (json['level'] as num).toInt(),
    upgradeLevels: _upgradesFromJson(
      json['upgradeLevels'] as Map<String, dynamic>,
    ),
    stageNumber: (json['stageNumber'] as num).toInt(),
  );

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'bugs': bugs.map((b) => b.toJson()).toList(),
    'materials': {for (final e in materials.entries) e.key.key: e.value},
    'installations': installations.map((i) => i.toJson()).toList(),
    'unlockedFieldIds': unlockedFieldIds.toList(),
    'createdAt': createdAt.toUtc().toIso8601String(),
    'lastSeen': lastSeen.toUtc().toIso8601String(),
    'gold': gold,
    'xp': xp,
    'level': level,
    'upgradeLevels': {
      for (final e in upgradeLevels.entries) e.key.key: e.value,
    },
    'stageNumber': stageNumber,
  };

  static Map<MaterialKind, int> _materialsFromJson(Map<String, dynamic> json) {
    return {
      for (final e in json.entries)
        MaterialKind.fromKey(e.key): (e.value as num).toInt(),
    };
  }

  static Map<UpgradeKind, int> _upgradesFromJson(Map<String, dynamic> json) {
    return {
      for (final e in json.entries)
        UpgradeKind.fromKey(e.key): (e.value as num).toInt(),
    };
  }
}
