import 'package:core_models/core_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 자동 합성·자동 분해가 **무엇을 건드릴지** 고르는 조건.
///
/// 자동 정리는 되돌릴 수 없다 — 조건 없이 "전부"를 돌리면 남겨야 할 개체가
/// 조용히 사라진다. 그래서 대상은 항상 이 필터를 통과한 것만으로 좁히고,
/// 실행 전에 예상 결과를 보여준다(§2.7 자동 합성 원칙).
///
/// ⚠️ 이 필터와 **무관하게 항상 보호되는 것**(컨트롤러 쪽 안전장치):
/// 장착 중 · 부화 중 · 투자한 개체(수련 2↑ · 돌파 1↑ · 부위 강화 1↑).
class BugAutoFilter {
  const BugAutoFilter({required this.grades, required this.maxPotential});

  /// 대상 등급(체크된 것만 건드린다).
  final Set<Grade> grades;

  /// 포텐셜이 이 값 **이하**인 개체만 대상. 잘 뽑힌 개체를 지키는 문턱이다.
  final int maxPotential;

  /// 기본값 = **일반·고급, 3성 이하**. 안전한 쪽으로 시작한다 —
  /// 처음 눌렀을 때 전설이 사라지면 그게 곧 클레임이다.
  static const safe = BugAutoFilter(
    grades: {Grade.common, Grade.uncommon},
    maxPotential: 3,
  );

  bool accepts(Grade grade, int potential) =>
      grades.contains(grade) && potential <= maxPotential;

  BugAutoFilter copyWith({Set<Grade>? grades, int? maxPotential}) =>
      BugAutoFilter(
        grades: grades ?? this.grades,
        maxPotential: maxPotential ?? this.maxPotential,
      );

  BugAutoFilter toggled(Grade g) {
    final next = Set<Grade>.from(grades);
    if (!next.remove(g)) next.add(g);
    return copyWith(grades: next);
  }
}

/// 앱을 켜 둔 동안 유지되는 필터(세이브에는 넣지 않는다 — 화면 설정이다).
/// 매번 기본값으로 되돌아가면 같은 조건을 반복해 고르게 된다.
class BugAutoFilterNotifier extends Notifier<BugAutoFilter> {
  @override
  BugAutoFilter build() => BugAutoFilter.safe;

  void set(BugAutoFilter next) => state = next;
}

typedef BugAutoFilterProvider =
    NotifierProvider<BugAutoFilterNotifier, BugAutoFilter>;

final autoSynthFilterProvider = BugAutoFilterProvider(
  BugAutoFilterNotifier.new,
);

final autoReleaseFilterProvider = BugAutoFilterProvider(
  BugAutoFilterNotifier.new,
);
