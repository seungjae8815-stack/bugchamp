import 'package:meta/meta.dart';

import 'localized_text.dart';

/// 트랩 정의 (§2.4). 슬롯은 3개, 필드×트랩 조합으로 출현 테이블이 결정된다.
///
/// **밸런스 데이터**이므로 값은 assets/data/traps.json 에서 로드한다.
/// [yieldMultiplier] 같은 계수는 그 JSON 이 정한다(코드 매직넘버 아님).
@immutable
class Trap {
  const Trap({
    required this.id,
    required this.name,
    this.yieldMultiplier = 1.0,
    this.iconAsset,
  });

  /// 안정적 식별자 (예: 'sap_trap').
  final String id;

  /// 다국어 이름.
  final LocalizedText name;

  /// 채집 산출(재료/조우) 배율. 출현 테이블과 곱해져 오프라인 보상량에 반영.
  final double yieldMultiplier;

  /// 트랩 아이콘 파일명 (예: 'sap_trap.webp'). 없으면 UI 가 아이콘으로 폴백.
  final String? iconAsset;

  factory Trap.fromJson(Map<String, dynamic> json) => Trap(
    id: json['id'] as String,
    name: LocalizedText.fromJson(json['name'] as Map<String, dynamic>),
    yieldMultiplier: (json['yieldMultiplier'] as num?)?.toDouble() ?? 1.0,
    iconAsset: json['icon'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name.toJson(),
    'yieldMultiplier': yieldMultiplier,
    if (iconAsset != null) 'icon': iconAsset,
  };

  @override
  bool operator ==(Object other) => other is Trap && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Trap($id)';
}
