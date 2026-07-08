import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';

/// 현재 세이브 스키마 버전. SaveGame.toJson 이 이 값을 기록하고,
/// 로드 시 이 값보다 낮으면 마이그레이션이 실행된다 (see data/save_migrations.dart).
const int kSaveSchemaVersion = 6;

/// 닉네임 기본값(설정에서 변경 가능).
const String kDefaultNickname = '채집가';

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
    required this.nickname,
    required this.buffExpiry,
    required this.missionProgress,
    required this.missionClaims,
    required this.equippedBugIds,
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

  /// 플레이어 표시 이름.
  final String nickname;

  /// 활성 버프별 만료 UTC 시각. now 이후면 활성으로 취급.
  final Map<BuffKind, DateTime> buffExpiry;

  /// 미션 id별 진행 카운터(카운터형 미션. reachStage 는 stageNumber 파생이라 미저장).
  final Map<String, int> missionProgress;

  /// 미션 id별 수집(클레임) 횟수 = 현재 티어.
  final Map<String, int> missionClaims;

  /// 장착한 애완펫(곤충) id 목록 (최대 3). 캐릭터 스탯 보너스.
  final List<String> equippedBugIds;

  bool isEquipped(String bugId) => equippedBugIds.contains(bugId);

  int missionClaimCount(String id) => missionClaims[id] ?? 0;
  int missionProgressCount(String id) => missionProgress[id] ?? 0;

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
    nickname: kDefaultNickname,
    buffExpiry: const {},
    missionProgress: const {},
    missionClaims: const {},
    equippedBugIds: const [],
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
    String? nickname,
    Map<BuffKind, DateTime>? buffExpiry,
    Map<String, int>? missionProgress,
    Map<String, int>? missionClaims,
    List<String>? equippedBugIds,
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
    nickname: nickname ?? this.nickname,
    buffExpiry: buffExpiry ?? this.buffExpiry,
    missionProgress: missionProgress ?? this.missionProgress,
    missionClaims: missionClaims ?? this.missionClaims,
    equippedBugIds: equippedBugIds ?? this.equippedBugIds,
  );

  int materialCount(MaterialKind kind) => materials[kind] ?? 0;

  int upgradeLevel(UpgradeKind kind) => upgradeLevels[kind] ?? 0;

  /// [now] 기준 활성(만료 전) 버프 종류들.
  Set<BuffKind> activeBuffs(DateTime now) => {
    for (final e in buffExpiry.entries)
      if (e.value.isAfter(now)) e.key,
  };

  /// [kind] 버프의 남은 시간([now] 기준). 비활성이면 null.
  Duration? buffRemaining(BuffKind kind, DateTime now) {
    final exp = buffExpiry[kind];
    if (exp == null || !exp.isAfter(now)) return null;
    return exp.difference(now);
  }

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
    nickname: json['nickname'] as String? ?? kDefaultNickname,
    buffExpiry: _buffsFromJson(
      json['buffExpiry'] as Map<String, dynamic>? ?? const {},
    ),
    missionProgress: _intMapFromJson(
      json['missionProgress'] as Map<String, dynamic>? ?? const {},
    ),
    missionClaims: _intMapFromJson(
      json['missionClaims'] as Map<String, dynamic>? ?? const {},
    ),
    equippedBugIds:
        (json['equippedBugIds'] as List?)?.cast<String>().toList() ?? const [],
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
    'nickname': nickname,
    'buffExpiry': {
      for (final e in buffExpiry.entries)
        e.key.key: e.value.toUtc().toIso8601String(),
    },
    'missionProgress': missionProgress,
    'missionClaims': missionClaims,
    'equippedBugIds': equippedBugIds,
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

  static Map<String, int> _intMapFromJson(Map<String, dynamic> json) => {
    for (final e in json.entries) e.key: (e.value as num).toInt(),
  };

  /// 알 수 없는 버프 key 는 무시(미래 버전 호환).
  static Map<BuffKind, DateTime> _buffsFromJson(Map<String, dynamic> json) {
    final out = <BuffKind, DateTime>{};
    for (final e in json.entries) {
      final kind = BuffKind.fromKey(e.key);
      if (kind == null) continue;
      out[kind] = DateTime.parse(e.value as String).toUtc();
    }
    return out;
  }
}
