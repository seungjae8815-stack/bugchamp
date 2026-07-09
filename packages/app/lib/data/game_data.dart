import 'dart:convert';

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:flutter/services.dart' show rootBundle;

/// assets/data/*.json 을 로드해 만든 **불변 게임 정적 데이터** 테이블.
/// 런타임 밸런스 데이터의 단일 진입점.
class GameData {
  const GameData({
    required this.speciesById,
    required this.trapById,
    required this.fields,
    required this.spawnTable,
    this.runConfig,
    this.buffConfig,
    this.enhanceConfig,
    this.craftConfig,
    this.missionConfig,
    this.petConfig,
    this.dailyConfig,
    this.giftConfig,
    this.roadmapConfig,
  });

  final Map<String, Species> speciesById;
  final Map<String, Trap> trapById;
  final List<Field> fields;
  final SpawnTable spawnTable;

  /// v2 런 밸런스 설정 (에셋 로드 시 채워짐. 일부 테스트에선 null).
  final RunConfig? runConfig;

  /// 광고 버프 설정 (에셋 로드 시 채워짐. 일부 테스트에선 null).
  final BuffConfig? buffConfig;

  /// 부위 강화 설정 (에셋 로드 시 채워짐. 일부 테스트에선 null).
  final EnhanceConfig? enhanceConfig;

  /// 제작 설정 (에셋 로드 시 채워짐. 일부 테스트에선 null).
  final CraftConfig? craftConfig;

  /// 미션 설정 (에셋 로드 시 채워짐. 일부 테스트에선 null).
  final MissionConfig? missionConfig;

  /// 애완펫 보너스 설정 (에셋 로드 시 채워짐. 일부 테스트에선 null).
  final PetConfig? petConfig;

  /// 일일 보상 설정 (에셋 로드 시 채워짐. 일부 테스트에선 null).
  final DailyConfig? dailyConfig;

  /// 깜짝 선물 설정 (에셋 로드 시 채워짐. 일부 테스트에선 null).
  final GiftConfig? giftConfig;

  /// 로드맵(난이도 챕터) 설정 (에셋 로드 시 채워짐. 일부 테스트에선 null).
  final RoadmapConfig? roadmapConfig;

  /// speciesId → Species (accrue 의 resolveSpecies 로 그대로 넘길 수 있음).
  Species species(String id) {
    final s = speciesById[id];
    if (s == null) throw StateError('Unknown speciesId: $id');
    return s;
  }

  Trap trap(String id) {
    final t = trapById[id];
    if (t == null) throw StateError('Unknown trapId: $id');
    return t;
  }

  List<Species> get allSpecies => speciesById.values.toList();

  /// 디코드된 JSON 맵들로부터 구성 (테스트/런타임 공용).
  factory GameData.fromDecoded({
    required Map<String, dynamic> species,
    required Map<String, dynamic> traps,
    required Map<String, dynamic> fields,
    required Map<String, dynamic> spawns,
    Map<String, dynamic>? runConfig,
    Map<String, dynamic>? buffConfig,
    Map<String, dynamic>? enhanceConfig,
    Map<String, dynamic>? craftConfig,
    Map<String, dynamic>? missionConfig,
    Map<String, dynamic>? petConfig,
    Map<String, dynamic>? dailyConfig,
    Map<String, dynamic>? giftConfig,
    Map<String, dynamic>? roadmapConfig,
  }) {
    final speciesList = (species['species'] as List)
        .cast<Map<String, dynamic>>()
        .map(Species.fromJson);
    final trapList = (traps['traps'] as List).cast<Map<String, dynamic>>().map(
      Trap.fromJson,
    );
    final fieldList =
        (fields['fields'] as List)
            .cast<Map<String, dynamic>>()
            .map(Field.fromJson)
            .toList()
          ..sort((a, b) => a.unlockOrder.compareTo(b.unlockOrder));
    return GameData(
      speciesById: {for (final s in speciesList) s.id: s},
      trapById: {for (final t in trapList) t.id: t},
      fields: fieldList,
      spawnTable: SpawnTable.fromJson(spawns),
      runConfig: runConfig == null ? null : RunConfig.fromJson(runConfig),
      buffConfig: buffConfig == null ? null : BuffConfig.fromJson(buffConfig),
      enhanceConfig: enhanceConfig == null
          ? null
          : EnhanceConfig.fromJson(enhanceConfig),
      craftConfig: craftConfig == null
          ? null
          : CraftConfig.fromJson(craftConfig),
      missionConfig: missionConfig == null
          ? null
          : MissionConfig.fromJson(missionConfig),
      petConfig: petConfig == null ? null : PetConfig.fromJson(petConfig),
      dailyConfig: dailyConfig == null
          ? null
          : DailyConfig.fromJson(dailyConfig),
      giftConfig: giftConfig == null ? null : GiftConfig.fromJson(giftConfig),
      roadmapConfig: roadmapConfig == null
          ? null
          : RoadmapConfig.fromJson(roadmapConfig),
    );
  }

  /// Flutter 에셋 번들에서 로드 (런타임).
  static Future<GameData> loadFromBundle() async {
    Future<Map<String, dynamic>> read(String name) async =>
        jsonDecode(await rootBundle.loadString('assets/data/$name'))
            as Map<String, dynamic>;
    final results = await Future.wait([
      read('species.json'),
      read('traps.json'),
      read('fields.json'),
      read('spawns.json'),
      read('run_config.json'),
      read('buffs.json'),
      read('enhance.json'),
      read('craft.json'),
      read('missions.json'),
      read('pets.json'),
      read('daily.json'),
      read('gifts.json'),
      read('roadmap.json'),
    ]);
    return GameData.fromDecoded(
      species: results[0],
      traps: results[1],
      fields: results[2],
      spawns: results[3],
      runConfig: results[4],
      buffConfig: results[5],
      enhanceConfig: results[6],
      craftConfig: results[7],
      missionConfig: results[8],
      petConfig: results[9],
      dailyConfig: results[10],
      giftConfig: results[11],
      roadmapConfig: results[12],
    );
  }
}
