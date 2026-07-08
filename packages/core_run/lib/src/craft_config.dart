import 'package:core_models/core_models.dart';
import 'package:meta/meta.dart';

import 'enums.dart';

/// 제작 레시피 1종 (JSON, §C). 재료를 소비해 버프를 발동한다.
@immutable
class CraftRecipe {
  const CraftRecipe({
    required this.id,
    required this.inputs,
    this.buff,
    this.allBuffs = false,
  });

  final String id;

  /// 소비 재료.
  final Map<MaterialKind, int> inputs;

  /// 발동할 버프(단일). allBuffs 가 true 면 무시.
  final BuffKind? buff;

  /// true 면 모든 버프를 한 번에 발동(프리미엄 올인원).
  final bool allBuffs;

  factory CraftRecipe.fromJson(Map<String, dynamic> json) => CraftRecipe(
    id: json['id'] as String,
    inputs: {
      for (final e in (json['inputs'] as Map<String, dynamic>).entries)
        MaterialKind.fromKey(e.key): (e.value as num).toInt(),
    },
    buff: json['buff'] != null
        ? BuffKind.fromKey(json['buff'] as String)
        : null,
    allBuffs: json['allBuffs'] as bool? ?? false,
  );
}

/// 제작 설정 전체 (assets/data/craft.json 에서 로드).
@immutable
class CraftConfig {
  const CraftConfig({required this.recipes});

  final List<CraftRecipe> recipes;

  factory CraftConfig.fromJson(Map<String, dynamic> json) => CraftConfig(
    recipes: (json['recipes'] as List)
        .cast<Map<String, dynamic>>()
        .map(CraftRecipe.fromJson)
        .toList(),
  );
}
