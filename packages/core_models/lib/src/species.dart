import 'package:meta/meta.dart';

import 'enums.dart';
import 'localized_text.dart';
import 'stats.dart';

/// 종 고유 패시브 (§2.1) — **그 종을 애완펫으로 장착했을 때** 캐릭터 능력치에 붙는다.
///
/// 왜 필요한가: 20종이 등급·기본스탯·주특기 말고는 구분이 없어서, 플레이어의
/// 목표가 "장수풍뎅이를 갖고 싶다"가 아니라 "전설을 갖고 싶다"가 됐다.
/// 종 20개가 사실상 **등급 5개**로 압축돼 있던 셈이다.
///
/// [statKey] 는 `UpgradeKind.key`(예: 'bossDamage')다. **문자열인 이유**:
/// `UpgradeKind` 는 core_run 에 있고 core_models 는 그걸 모른다(의존 방향).
/// 오타는 로딩이 아니라 테스트(`species.json 패시브 키 유효성`)에서 잡는다.
@immutable
class SpeciesPassive {
  const SpeciesPassive({required this.statKey, required this.value});

  /// 붙일 능력치(`UpgradeKind.key`).
  final String statKey;

  /// 가산치. 배율 스탯이면 0.15 = +15%, 확률 스탯이면 0.05 = +5%p.
  final double value;

  factory SpeciesPassive.fromJson(Map<String, dynamic> json) => SpeciesPassive(
    statKey: json['stat'] as String,
    value: (json['value'] as num).toDouble(),
  );

  Map<String, dynamic> toJson() => {'stat': statKey, 'value': value};
}

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
    this.desc,
    this.passive,
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

  /// 다국어 종 설명(도감/상세 팝업용). 없으면 null.
  final LocalizedText? desc;

  /// 종 고유 패시브. 장착 시 캐릭터 능력치에 붙는다. 없으면 null.
  final SpeciesPassive? passive;

  factory Species.fromJson(Map<String, dynamic> json) => Species(
    id: json['id'] as String,
    name: LocalizedText.fromJson(json['name'] as Map<String, dynamic>),
    grade: Grade.fromKey(json['grade'] as String),
    specialty: Specialty.fromKey(json['specialty'] as String),
    baseStats: Stats.fromJson(json['baseStats'] as Map<String, dynamic>),
    sizeMinMm: (json['sizeMinMm'] as num).toDouble(),
    sizeMaxMm: (json['sizeMaxMm'] as num).toDouble(),
    imageAsset: json['image'] as String?,
    desc: json['desc'] == null
        ? null
        : LocalizedText.fromJson(json['desc'] as Map<String, dynamic>),
    passive: json['passive'] == null
        ? null
        : SpeciesPassive.fromJson(json['passive'] as Map<String, dynamic>),
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
    if (desc != null) 'desc': desc!.toJson(),
    if (passive != null) 'passive': passive!.toJson(),
  };

  @override
  bool operator ==(Object other) => other is Species && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Species($id, ${grade.key}, ${specialty.key})';
}
