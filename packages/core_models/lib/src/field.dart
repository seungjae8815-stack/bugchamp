import 'package:meta/meta.dart';

import 'localized_text.dart';

/// 채집 필드 정의 (§2.4). 필드×트랩 조합으로 출현 테이블이 결정된다.
///
/// **밸런스 데이터**이므로 값은 assets/data/fields.json 에서 로드한다.
/// 실제 출현표(어떤 종/재료가 얼마 확률로 나오는지)는 별도 spawn table JSON 에 둔다.
@immutable
class Field {
  const Field({
    required this.id,
    required this.name,
    this.unlockOrder = 0,
    this.backgroundAsset,
  });

  /// 안정적 식별자 (예: 'oak_forest').
  final String id;

  /// 다국어 이름.
  final LocalizedText name;

  /// 진행상 해금 순서(0=시작 필드). 정렬/해금 조건에 사용.
  final int unlockOrder;

  /// 필드 배경 이미지 파일명 (예: 'oak_forest.webp'). 없으면 UI 가 그라데이션 씬으로 폴백.
  final String? backgroundAsset;

  factory Field.fromJson(Map<String, dynamic> json) => Field(
    id: json['id'] as String,
    name: LocalizedText.fromJson(json['name'] as Map<String, dynamic>),
    unlockOrder: (json['unlockOrder'] as num?)?.toInt() ?? 0,
    backgroundAsset: json['bg'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name.toJson(),
    'unlockOrder': unlockOrder,
    if (backgroundAsset != null) 'bg': backgroundAsset,
  };

  @override
  bool operator ==(Object other) => other is Field && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Field($id)';
}
