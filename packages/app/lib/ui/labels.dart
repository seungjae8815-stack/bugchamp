import 'package:core_models/core_models.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// enum → 현지화 라벨 및 표시 스타일. (UI 문자열 하드코딩 금지 규칙 준수)

String gradeLabel(AppLocalizations l, Grade g) => switch (g) {
  Grade.common => l.gradeCommon,
  Grade.uncommon => l.gradeUncommon,
  Grade.rare => l.gradeRare,
  Grade.epic => l.gradeEpic,
  Grade.legendary => l.gradeLegendary,
};

Color gradeColor(Grade g) => switch (g) {
  Grade.common => const Color(0xFF78909C), // blue grey
  Grade.uncommon => const Color(0xFF43A047), // green
  Grade.rare => const Color(0xFF1E88E5), // blue
  Grade.epic => const Color(0xFF8E24AA), // purple
  Grade.legendary => const Color(0xFFF57C00), // orange
};

String specialtyLabel(AppLocalizations l, Specialty s) => switch (s) {
  Specialty.strike => l.specialtyStrike,
  Specialty.grip => l.specialtyGrip,
  Specialty.toss => l.specialtyToss,
};

String temperamentLabel(AppLocalizations l, Temperament t) => switch (t) {
  Temperament.aggressive => l.temperamentAggressive,
  Temperament.cautious => l.temperamentCautious,
  Temperament.cunning => l.temperamentCunning,
  Temperament.steadfast => l.temperamentSteadfast,
  Temperament.fickle => l.temperamentFickle,
};

String sexLabel(AppLocalizations l, Sex s) =>
    s == Sex.male ? l.sexMale : l.sexFemale;

IconData sexIcon(Sex s) => s == Sex.male ? Icons.male : Icons.female;

String materialLabel(AppLocalizations l, MaterialKind k) => switch (k) {
  MaterialKind.chitin => l.materialChitin,
  MaterialKind.mineral => l.materialMineral,
  MaterialKind.sap => l.materialSap,
  MaterialKind.jelly => l.materialJelly,
};

IconData materialIcon(MaterialKind k) => switch (k) {
  MaterialKind.chitin => Icons.shield_outlined,
  MaterialKind.mineral => Icons.diamond_outlined,
  MaterialKind.sap => Icons.water_drop_outlined,
  MaterialKind.jelly => Icons.bubble_chart_outlined,
};
