/// 세이브 스키마 마이그레이션 파이프라인.
///
/// 저장은 **버전드 JSON**이다. 로드 시 `schemaVersion` 이 [kSaveSchemaVersion] 보다
/// 낮으면, 순차 변환 함수(vN → vN+1)를 체인으로 적용해 현재 버전으로 끌어올린 뒤
/// `SaveGame.fromJson` 으로 파싱한다. 새 스키마가 생기면:
///   1) [kSaveSchemaVersion] (domain/save_game.dart) 을 올리고
///   2) `_migrations[이전버전]` 에 변환 함수를 추가한다.
library;

import '../domain/save_game.dart' show kSaveSchemaVersion;

typedef _JsonMap = Map<String, dynamic>;

/// 원시 JSON 맵을 현재 스키마 버전으로 끌어올린다.
/// `schemaVersion` 이 없으면 v0(레거시/미표기)로 간주한다.
Map<String, dynamic> migrateToCurrent(Map<String, dynamic> raw) {
  var data = Map<String, dynamic>.from(raw);
  var version = (data['schemaVersion'] as num?)?.toInt() ?? 0;

  if (version > kSaveSchemaVersion) {
    throw StateError(
      '세이브 버전($version)이 앱이 아는 버전($kSaveSchemaVersion)보다 높음 — 다운그레이드 불가',
    );
  }

  while (version < kSaveSchemaVersion) {
    final migrate = _migrations[version];
    if (migrate == null) {
      throw StateError('v$version → v${version + 1} 마이그레이션이 없음');
    }
    data = migrate(data);
    final next = (data['schemaVersion'] as num).toInt();
    assert(next > version, '마이그레이션이 schemaVersion 을 증가시켜야 함');
    version = next;
  }
  return data;
}

/// vN → vN+1 변환 함수 테이블.
const Map<int, _JsonMap Function(_JsonMap)> _migrations = {
  0: _v0ToV1,
  1: _v1ToV2,
  2: _v2ToV3,
  3: _v3ToV4,
  4: _v4ToV5,
  5: _v5ToV6,
  6: _v6ToV7,
  7: _v7ToV8,
  8: _v8ToV9,
  9: _v9ToV10,
  10: _v10ToV11,
  11: _v11ToV12,
  12: _v12ToV13,
  13: _v13ToV14,
  14: _v14ToV15,
};

/// v0(스키마 미표기 레거시) → v1: 누락 필드를 기본값으로 채우고 버전을 승격.
_JsonMap _v0ToV1(_JsonMap old) => {
  ...old,
  'schemaVersion': 1,
  'bugs': old['bugs'] ?? const [],
  'materials': old['materials'] ?? const <String, dynamic>{},
  'installations': old['installations'] ?? const [],
  'unlockedFieldIds': old['unlockedFieldIds'] ?? const ['oak_forest'],
  'createdAt':
      old['createdAt'] ??
      DateTime.fromMillisecondsSinceEpoch(0).toIso8601String(),
};

/// v1(트랩 채집) → v2(횡스크롤 런): 런 진행 필드를 기본값으로 추가.
_JsonMap _v1ToV2(_JsonMap old) => {
  ...old,
  'schemaVersion': 2,
  'gold': old['gold'] ?? 0,
  'xp': old['xp'] ?? 0,
  'level': old['level'] ?? 1,
  'upgradeLevels': old['upgradeLevels'] ?? const <String, dynamic>{},
  'stageNumber': old['stageNumber'] ?? 1,
};

/// v2 → v3(닉네임·광고 버프): 닉네임/버프 필드를 기본값으로 추가.
_JsonMap _v2ToV3(_JsonMap old) => {
  ...old,
  'schemaVersion': 3,
  'nickname': old['nickname'] ?? '채집가',
  'buffExpiry': old['buffExpiry'] ?? const <String, dynamic>{},
};

/// v3 → v4(미션): 미션 진행/수집 필드를 기본값으로 추가.
_JsonMap _v3ToV4(_JsonMap old) => {
  ...old,
  'schemaVersion': 4,
  'missionProgress': old['missionProgress'] ?? const <String, dynamic>{},
  'missionClaims': old['missionClaims'] ?? const <String, dynamic>{},
};

/// v4 → v5(미션 순차화): 이전 버전에서 누적된 미션 진행/티어를 초기화해
/// 순차 미션이 처음부터 새로 시작되게 한다.
_JsonMap _v4ToV5(_JsonMap old) => {
  ...old,
  'schemaVersion': 5,
  'missionProgress': const <String, dynamic>{},
  'missionClaims': const <String, dynamic>{},
};

/// v5 → v6(애완펫 장착): 장착 목록 필드를 기본값으로 추가.
_JsonMap _v5ToV6(_JsonMap old) => {
  ...old,
  'schemaVersion': 6,
  'equippedBugIds': old['equippedBugIds'] ?? const <String>[],
};

/// v6 → v7(일일보상): 수령 기록 필드를 기본값으로 추가.
_JsonMap _v6ToV7(_JsonMap old) => {
  ...old,
  'schemaVersion': 7,
  'dailyClaims': old['dailyClaims'] ?? const <String, dynamic>{},
};

/// v7 → v8(깜짝 선물): 선물 목록 필드를 기본값으로 추가.
_JsonMap _v7ToV8(_JsonMap old) => {
  ...old,
  'schemaVersion': 8,
  'gifts': old['gifts'] ?? const <dynamic>[],
};

/// v8 → v9(챕터 클리어 보상): 클리어 기록 필드를 기본값으로 추가.
_JsonMap _v8ToV9(_JsonMap old) => {
  ...old,
  'schemaVersion': 9,
  'clearedChapters': old['clearedChapters'] ?? const <dynamic>[],
};

/// v9 → v10(부화기): 슬롯/진행 필드를 기본값으로 추가.
_JsonMap _v9ToV10(_JsonMap old) => {
  ...old,
  'schemaVersion': 10,
  'incubatorCapacity': old['incubatorCapacity'] ?? 1,
  'incubating': old['incubating'] ?? const <String, dynamic>{},
};

/// v10 → v11(PvP): 트로피 필드를 기본값으로 추가.
_JsonMap _v10ToV11(_JsonMap old) => {
  ...old,
  'schemaVersion': 11,
  'pvpTrophies': old['pvpTrophies'] ?? 0,
};

/// v11 → v12(부상/회복): KO 회복 타이머 맵을 기본값으로 추가.
_JsonMap _v11ToV12(_JsonMap old) => {
  ...old,
  'schemaVersion': 12,
  'injured': old['injured'] ?? const <String, dynamic>{},
};

/// v12 → v13(리그/티어): 승급 보상 수령 기록을 기본값으로 추가.
_JsonMap _v12ToV13(_JsonMap old) => {
  ...old,
  'schemaVersion': 13,
  'claimedLeagues': old['claimedLeagues'] ?? const <dynamic>[],
};

/// v13 → v14(시즌): 시즌 최고 트로피 필드 추가. `seasonStartedAt` 은 미표기 →
/// 로드 시 now 로 초기화(마이그레이션에서 시간을 만들지 않는다).
_JsonMap _v13ToV14(_JsonMap old) => {
  ...old,
  'schemaVersion': 14,
  'seasonPeakTrophies': old['seasonPeakTrophies'] ?? 0,
};

/// v14 → v15(브리딩): 산란 슬롯·용량 필드를 기본값으로 추가.
_JsonMap _v14ToV15(_JsonMap old) => {
  ...old,
  'schemaVersion': 15,
  'breeding': old['breeding'] ?? const <dynamic>[],
  'breedingCapacity': old['breedingCapacity'] ?? 1,
};
