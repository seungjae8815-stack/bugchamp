import 'dart:math' as math;

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
  const CraftConfig({required this.recipes, this.inputGrowth = 1.0});

  final List<CraftRecipe> recipes;

  /// 재료비의 스테이지당 성장률(1.0 = 고정, 기존 동작).
  ///
  /// 제작은 소모품이라 **유일한 무한 재료 소비처**다. 고정값이면 재료 수입이
  /// 커지는 후반엔 물약이 공짜가 되고 재료가 다시 쌓인다. 수입과 같은 속도로
  /// 올려서 "한 번에 몇 개 만들 수 있나"를 전 구간 일정하게 유지한다.
  final double inputGrowth;

  /// [stage] 에서 [recipe] 한 번에 드는 재료(젤리는 성장에서 제외 — 프리미엄
  /// 재화라 스테이지에 따라 비싸지면 결제 가치가 흔들린다).
  Map<MaterialKind, int> inputsAt(CraftRecipe recipe, int stage) {
    if (inputGrowth <= 1.0) return recipe.inputs;
    final mult = math.pow(inputGrowth, (stage - 1).clamp(0, 1 << 20));
    return {
      for (final e in recipe.inputs.entries)
        e.key: e.key == MaterialKind.jelly
            ? e.value
            : (e.value * mult).round().clamp(1, 1 << 30),
    };
  }

  factory CraftConfig.fromJson(Map<String, dynamic> json) => CraftConfig(
    inputGrowth: (json['inputGrowth'] as num?)?.toDouble() ?? 1.0,
    recipes: (json['recipes'] as List)
        .cast<Map<String, dynamic>>()
        .map(CraftRecipe.fromJson)
        .toList(),
  );
}
