import 'package:meta/meta.dart';

import 'enums.dart';

/// 부위 강화 레벨 (§2.2).
/// 뿔·큰턱→ATK, 표피→DEF, 날개→SPD/회피, 체격→HP.
///
/// 강화 **효과 계수**(%/Lv)는 밸런스 값이라 여기 두지 않고, 강화 적용 로직 단계에서
/// JSON 계수를 주입해 계산한다. 이 모델은 각 부위의 현재 레벨만 저장한다.
@immutable
class PartLevels {
  const PartLevels({
    this.hornJaw = 0, // 뿔·큰턱 → ATK
    this.cuticle = 0, // 표피 → DEF
    this.wing = 0, // 날개 → SPD·회피
    this.build = 0, // 체격 → HP
  });

  final int hornJaw;
  final int cuticle;
  final int wing;
  final int build;

  static const PartLevels zero = PartLevels();

  /// 전 부위 레벨 합 (강화 상한 = 포텐셜×10 과 비교하는 데 사용).
  int get total => hornJaw + cuticle + wing + build;

  /// [part] 의 현재 레벨.
  int levelOf(BugPart part) => switch (part) {
    BugPart.hornJaw => hornJaw,
    BugPart.cuticle => cuticle,
    BugPart.wing => wing,
    BugPart.build => build,
  };

  /// [part] 레벨을 [by] 만큼 올린 새 값.
  PartLevels incremented(BugPart part, [int by = 1]) => switch (part) {
    BugPart.hornJaw => copyWith(hornJaw: hornJaw + by),
    BugPart.cuticle => copyWith(cuticle: cuticle + by),
    BugPart.wing => copyWith(wing: wing + by),
    BugPart.build => copyWith(build: build + by),
  };

  PartLevels copyWith({int? hornJaw, int? cuticle, int? wing, int? build}) =>
      PartLevels(
        hornJaw: hornJaw ?? this.hornJaw,
        cuticle: cuticle ?? this.cuticle,
        wing: wing ?? this.wing,
        build: build ?? this.build,
      );

  factory PartLevels.fromJson(Map<String, dynamic> json) => PartLevels(
    hornJaw: (json['hornJaw'] as num?)?.toInt() ?? 0,
    cuticle: (json['cuticle'] as num?)?.toInt() ?? 0,
    wing: (json['wing'] as num?)?.toInt() ?? 0,
    build: (json['build'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'hornJaw': hornJaw,
    'cuticle': cuticle,
    'wing': wing,
    'build': build,
  };

  @override
  bool operator ==(Object other) =>
      other is PartLevels &&
      other.hornJaw == hornJaw &&
      other.cuticle == cuticle &&
      other.wing == wing &&
      other.build == build;

  @override
  int get hashCode => Object.hash(hornJaw, cuticle, wing, build);

  @override
  String toString() =>
      'PartLevels(hornJaw: $hornJaw, cuticle: $cuticle, wing: $wing, build: $build)';
}
