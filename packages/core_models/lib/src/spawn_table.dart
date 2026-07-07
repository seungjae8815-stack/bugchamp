import 'package:meta/meta.dart';

import 'enums.dart';

/// 필드×트랩 조합의 출현 테이블 (§2.4). **밸런스 데이터**이므로
/// 값은 assets/data/spawns.json 에서 로드한다.

/// 시간당 재료 기대 산출량.
@immutable
class MaterialRate {
  const MaterialRate({required this.kind, required this.perHour});

  final MaterialKind kind;
  final double perHour;

  factory MaterialRate.fromJson(Map<String, dynamic> json) => MaterialRate(
    kind: MaterialKind.fromKey(json['kind'] as String),
    perHour: (json['perHour'] as num).toDouble(),
  );

  Map<String, dynamic> toJson() => {'kind': kind.key, 'perHour': perHour};
}

/// 종별 조우 가중치.
@immutable
class SpeciesWeight {
  const SpeciesWeight({required this.speciesId, required this.weight});

  final String speciesId;
  final int weight;

  factory SpeciesWeight.fromJson(Map<String, dynamic> json) => SpeciesWeight(
    speciesId: json['speciesId'] as String,
    weight: (json['weight'] as num).toInt(),
  );

  Map<String, dynamic> toJson() => {'speciesId': speciesId, 'weight': weight};
}

/// 포텐셜(1~5) 가중치.
@immutable
class PotentialWeight {
  const PotentialWeight({required this.potential, required this.weight});

  final int potential;
  final int weight;

  factory PotentialWeight.fromJson(Map<String, dynamic> json) =>
      PotentialWeight(
        potential: (json['potential'] as num).toInt(),
        weight: (json['weight'] as num).toInt(),
      );

  Map<String, dynamic> toJson() => {'potential': potential, 'weight': weight};
}

/// 한 (fieldId, trapId) 조합의 출현 정의.
@immutable
class SpawnEntry {
  const SpawnEntry({
    required this.fieldId,
    required this.trapId,
    required this.materialsPerHour,
    required this.encountersPerHour,
    required this.speciesWeights,
    required this.potentialWeights,
  });

  final String fieldId;
  final String trapId;
  final List<MaterialRate> materialsPerHour;
  final double encountersPerHour;
  final List<SpeciesWeight> speciesWeights;
  final List<PotentialWeight> potentialWeights;

  /// [defaultPotentialWeights] 는 항목에 potentialWeights 가 없을 때 사용.
  factory SpawnEntry.fromJson(
    Map<String, dynamic> json, {
    List<PotentialWeight> defaultPotentialWeights = const [],
  }) {
    final pw = json['potentialWeights'] as List?;
    return SpawnEntry(
      fieldId: json['fieldId'] as String,
      trapId: json['trapId'] as String,
      materialsPerHour: (json['materialsPerHour'] as List)
          .cast<Map<String, dynamic>>()
          .map(MaterialRate.fromJson)
          .toList(),
      encountersPerHour: (json['encountersPerHour'] as num).toDouble(),
      speciesWeights: (json['speciesWeights'] as List)
          .cast<Map<String, dynamic>>()
          .map(SpeciesWeight.fromJson)
          .toList(),
      potentialWeights: pw == null
          ? defaultPotentialWeights
          : pw
                .cast<Map<String, dynamic>>()
                .map(PotentialWeight.fromJson)
                .toList(),
    );
  }
}

/// 전체 출현 테이블. (fieldId, trapId) 로 항목을 조회한다.
@immutable
class SpawnTable {
  const SpawnTable(this.entries);

  final List<SpawnEntry> entries;

  /// 조합에 해당하는 항목. 없으면 null.
  SpawnEntry? lookup(String fieldId, String trapId) {
    for (final e in entries) {
      if (e.fieldId == fieldId && e.trapId == trapId) return e;
    }
    return null;
  }

  factory SpawnTable.fromJson(Map<String, dynamic> json) {
    final defaults =
        (json['defaultPotentialWeights'] as List?)
            ?.cast<Map<String, dynamic>>()
            .map(PotentialWeight.fromJson)
            .toList() ??
        const <PotentialWeight>[];
    final entries = (json['spawns'] as List)
        .cast<Map<String, dynamic>>()
        .map((e) => SpawnEntry.fromJson(e, defaultPotentialWeights: defaults))
        .toList();
    return SpawnTable(entries);
  }
}
