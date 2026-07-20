import 'dart:convert';
import 'dart:io';

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';

import 'actions.dart';

/// 서버가 쓰는 밸런스 설정.
///
/// **앱과 같은 JSON 파일을 읽는다** (`packages/app/assets/data/`).
/// 밸런스는 §6 규칙상 JSON 이 유일한 원본이므로, 서버가 별도 사본을 두면
/// 곧바로 어긋난다 — 앱은 지급한다는데 서버는 거부하는 상황이 된다.
///
/// Docker 이미지는 이 디렉터리를 그대로 복사해 넣는다(Dockerfile 참조).
class GameConfig implements GameConfigLike {
  GameConfig({
    required this.iap,
    required this.battle,
    required this.run,
    required this.pet,
    this.speciesById = const {},
  });

  @override
  final IapConfig iap;
  @override
  final BattleConfig battle;
  @override
  final RunConfig run;
  final PetConfig pet;

  /// 종 정보 — 전투 유닛 변환·부상 시간 계산에 필요하다.
  final Map<String, Species> speciesById;

  @override
  List<Species> get speciesList => speciesById.values.toList();

  /// 기본 경로 — 리포지토리 구조 기준. 환경변수 `GAME_DATA_DIR` 로 덮어쓴다.
  static const defaultDir = 'packages/app/assets/data';

  static Future<GameConfig> load({String? dir}) async {
    final base = dir ?? Platform.environment['GAME_DATA_DIR'] ?? defaultDir;

    Future<Map<String, dynamic>> read(String name) async {
      final file = File('$base/$name');
      if (!file.existsSync()) {
        throw StateError('게임 데이터 파일이 없습니다: ${file.path}');
      }
      return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    }

    final speciesJson = await read('species.json');
    final speciesList = (speciesJson['species'] as List)
        .cast<Map<String, dynamic>>()
        .map(Species.fromJson);

    return GameConfig(
      speciesById: {for (final s in speciesList) s.id: s},
      iap: IapConfig.fromJson(await read('iap.json')),
      battle: BattleConfig.fromJson(await read('battle.json')),
      run: RunConfig.fromJson(await read('run_config.json')),
      pet: PetConfig.fromJson(await read('pets.json')),
    );
  }
}
