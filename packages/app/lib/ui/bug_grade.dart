import 'package:core_models/core_models.dart';
import 'package:flutter/material.dart';

import '../data/game_data.dart';
import '../l10n/app_localizations.dart';
import 'labels.dart';

/// 개체 등급 표시 공용(2026-10-11, docs/design_individual_grade.md).
///
/// 켜져 있으면 포텐셜(1~5)을 **개체 등급 이름·색**(일반~전설)으로, 꺼져 있으면 예전처럼 ★×N 으로 보인다.
/// 꺼진 상태의 화면은 예전과 똑같아야 한다(단계적 배포) — 그래서 모든 분기를 이 파일에 모은다.

/// 개체 등급이 켜졌나(`pets.json → individualGrade.enabled`).
bool individualGradeOn(GameData data) =>
    data.petConfig?.individualGrade.enabled ?? false;

/// 포텐셜(1~5) → 개체 등급.
Grade gradeOfPotential(int potential) =>
    Grade.values[(potential - 1).clamp(0, Grade.values.length - 1)];

/// 곤충 **한 마리**를 보여 주는 자리의 등급 — 켜지면 개체 등급, 꺼지면 종 등급(예전 그대로).
/// 도감·타이머·비용·드롭 필터처럼 종을 말하는 자리는 이걸 쓰지 않고 `sp.grade` 그대로 둔다.
Grade shownGrade(GameData data, IndividualBug bug, Species sp) =>
    individualGradeOn(data) ? bug.individualGrade : sp.grade;

/// 포텐셜 표기 — 켜지면 등급 이름, 꺼지면 ★×N.
String potentialText(AppLocalizations l, int potential, bool on) =>
    on ? gradeLabel(l, gradeOfPotential(potential)) : '★' * potential;

/// 포텐셜 표기 색 — 켜지면 등급 색, 꺼지면 예전 별 색.
Color potentialColor(int potential, bool on) =>
    on ? gradeColor(gradeOfPotential(potential)) : const Color(0xFFFFC928);

/// 곤충 칸에 붙는 작은 등급 이름표(별 줄 자리에 들어간다).
Widget individualGradeTag(
  AppLocalizations l,
  int potential, {
  double fontSize = 9,
}) {
  final c = gradeColor(gradeOfPotential(potential));
  return Container(
    padding: EdgeInsets.symmetric(horizontal: fontSize * 0.45, vertical: 0.5),
    decoration: BoxDecoration(
      color: c.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(fontSize * 0.6),
      border: Border.all(color: const Color(0xAA000000), width: 0.5),
    ),
    child: Text(
      gradeLabel(l, gradeOfPotential(potential)),
      maxLines: 1,
      style: TextStyle(
        color: Colors.white,
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        height: 1.2,
        shadows: const [Shadow(color: Colors.black54, blurRadius: 2)],
      ),
    ),
  );
}
