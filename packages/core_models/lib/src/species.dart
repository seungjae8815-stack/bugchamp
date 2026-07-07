import 'package:meta/meta.dart';

import 'enums.dart';
import 'localized_text.dart';
import 'stats.dart';

/// 종(Species) 정의. **밸런스 데이터**이므로 실제 값은 assets/data/species.json 에서 로드한다.
/// 이 클래스는 그 JSON 한 항목을 담는 불변 모델이다 (§2.1).
@immutable
class Species {
  const Species({
    required this.id,
    required this.name,
    required this.grade,
    required this.specialty,
    required this.baseStats,
    required this.sizeMinMm,
    required this.sizeMaxMm,
    this.imageAsset,
  });

  /// 안정적 식별자 (예: 'stag_beetle_common').
  final String id;

  /// 다국어 종 이름.
  final LocalizedText name;

  /// 등급 (일반~전설).
  final Grade grade;

  /// 주특기 (치기/집기/던지기).
  final Specialty specialty;

  /// 기준 스탯 (사이즈 배율 1.0 기준).
  final Stats baseStats;

  /// 사이즈 범위(mm).
  final double sizeMinMm;
  final double sizeMaxMm;

  /// 종 일러스트 파일명 (예: 'stag_dorcus.webp'). 없으면 UI 가 플레이스홀더로 폴백.
  final String? imageAsset;

  factory Species.fromJson(Map<String, dynamic> json) => Species(
    id: json['id'] as String,
    name: LocalizedText.fromJson(json['name'] as Map<String, dynamic>),
    grade: Grade.fromKey(json['grade'] as String),
    specialty: Specialty.fromKey(json['specialty'] as String),
    baseStats: Stats.fromJson(json['baseStats'] as Map<String, dynamic>),
    sizeMinMm: (json['sizeMinMm'] as num).toDouble(),
    sizeMaxMm: (json['sizeMaxMm'] as num).toDouble(),
    imageAsset: json['image'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name.toJson(),
    'grade': grade.key,
    'specialty': specialty.key,
    'baseStats': baseStats.toJson(),
    'sizeMinMm': sizeMinMm,
    'sizeMaxMm': sizeMaxMm,
    if (imageAsset != null) 'image': imageAsset,
  };

  @override
  bool operator ==(Object other) => other is Species && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Species($id, ${grade.key}, ${specialty.key})';
}
