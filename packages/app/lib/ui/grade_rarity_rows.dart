import 'package:core_models/core_models.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'bug_grade.dart';
import 'game_dialog.dart';
import 'labels.dart';

/// 등급별 선명한 글자색(어두운 배경 위).
Color gradeBrightColor(Grade g) => switch (g) {
  Grade.common => const Color(0xFFB6C2CC),
  Grade.uncommon => const Color(0xFF5CD65C),
  Grade.rare => const Color(0xFF3FA9FF),
  Grade.epic => const Color(0xFFC072F0),
  Grade.legendary => const Color(0xFFFFC93C),
};

/// 곤충 이름 줄 — "장수하늘소 알 Lv.1"(2026-10-15 사장님). 성충은 단계 이름을 붙이지 않는다.
String bugTitleLine(
  AppLocalizations l,
  Species species,
  LifeStage stage,
  int level,
  String locale,
) {
  final name = species.name.resolve(locale);
  final withStage = stage == LifeStage.adult
      ? name
      : '$name ${stageLabel(l, stage, species)}';
  return '$withStage Lv.$level';
}

/// "등급 고급 (!)" · "희귀도 전설 (!)" 두 줄(2026-10-15 사장님) — 채집함 곤충 상세 · 결투 상대 곤충 창 공용.
/// 느낌표를 누르면 무엇인지 한 줄로 알려 준다.
class GradeRarityRows extends StatelessWidget {
  const GradeRarityRows({
    super.key,
    this.grade,
    required this.rarity,
    this.fontSize = 12.5,
  });

  /// 개체 등급(곤충마다 · 정수로 올림). null = 모름(옛 서버가 보낸 상대 곤충) — 희귀도 줄만.
  final Grade? grade;

  /// 종 희귀도(종마다 정해짐).
  final Grade rarity;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (grade case final g?) ...[
          _row(
            context,
            l.bugGradeLabel,
            gradeLabel(l, g),
            gradeBrightColor(g),
            l.bugGradeHelp,
          ),
          const SizedBox(height: 2),
        ],
        _row(
          context,
          l.bugRarityLabel,
          gradeLabel(l, rarity),
          gradeBrightColor(rarity),
          l.bugRarityHelp,
          lead: rarityGem(rarity, size: fontSize),
        ),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    String value,
    Color color,
    String help, {
    Widget? lead,
  }) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (lead != null) ...[lead, const SizedBox(width: 3)],
      Text(
        label,
        style: TextStyle(color: const Color(0xB3FFFFFF), fontSize: fontSize),
      ),
      const SizedBox(width: 5),
      Text(
        value,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
        ),
      ),
      InkWell(
        onTap: () => showGameDialog<void>(
          context,
          title: label,
          icon: Icons.info_outline_rounded,
          content: Text(
            help,
            style: const TextStyle(
              color: Color(0xDDFFFFFF),
              fontSize: 13,
              height: 1.45,
            ),
          ),
          actions: [
            gameDialogButton(
              AppLocalizations.of(context).actionClose,
              () => Navigator.pop(context),
            ),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          child: Icon(
            Icons.error_outline_rounded,
            size: fontSize + 3,
            color: const Color(0xFFEBA52F),
          ),
        ),
      ),
    ],
  );
}
