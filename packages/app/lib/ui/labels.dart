import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
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

String missionLabel(AppLocalizations l, MissionType t) => switch (t) {
  MissionType.killMonsters => l.missionKillMonsters,
  MissionType.killBosses => l.missionKillBosses,
  MissionType.buyUpgrades => l.missionBuyUpgrades,
  MissionType.reachStage => l.missionReachStage,
};

IconData missionIcon(MissionType t) => switch (t) {
  MissionType.killMonsters => Icons.pest_control,
  MissionType.killBosses => Icons.local_fire_department,
  MissionType.buyUpgrades => Icons.upgrade,
  MissionType.reachStage => Icons.flag_rounded,
};

String buffLabel(AppLocalizations l, BuffKind k) => switch (k) {
  BuffKind.goldRush => l.buffGoldRush,
  BuffKind.xpBoost => l.buffXpBoost,
  BuffKind.frenzy => l.buffFrenzy,
  BuffKind.gatherer => l.buffGatherer,
  BuffKind.luckyWind => l.buffLuckyWind,
};

String buffDesc(AppLocalizations l, BuffKind k) => switch (k) {
  BuffKind.goldRush => l.buffGoldRushDesc,
  BuffKind.xpBoost => l.buffXpBoostDesc,
  BuffKind.frenzy => l.buffFrenzyDesc,
  BuffKind.gatherer => l.buffGathererDesc,
  BuffKind.luckyWind => l.buffLuckyWindDesc,
};

/// 버프 이모지 글리프(아트 애셋 없을 때 폴백).
String buffGlyph(BuffKind k) => switch (k) {
  BuffKind.goldRush => '💰',
  BuffKind.xpBoost => '📖',
  BuffKind.frenzy => '⚔️',
  BuffKind.gatherer => '🧪',
  BuffKind.luckyWind => '🍀',
};

String partLabel(AppLocalizations l, BugPart p) => switch (p) {
  BugPart.hornJaw => l.partHornJaw,
  BugPart.cuticle => l.partCuticle,
  BugPart.wing => l.partWing,
  BugPart.build => l.partBuild,
};

IconData partIcon(BugPart p) => switch (p) {
  BugPart.hornJaw => Icons.bolt, // ATK
  BugPart.cuticle => Icons.shield, // DEF
  BugPart.wing => Icons.air, // SPD·회피
  BugPart.build => Icons.favorite, // HP
};

Color buffColor(BuffKind k) => switch (k) {
  BuffKind.goldRush => const Color(0xFFE0A32E),
  BuffKind.xpBoost => const Color(0xFF3E7D4F),
  BuffKind.frenzy => const Color(0xFFB5432E),
  BuffKind.gatherer => const Color(0xFF2E6DA4),
  BuffKind.luckyWind => const Color(0xFF7E57C2),
};

IconData sexIcon(Sex s) => s == Sex.male ? Icons.male : Icons.female;

String materialLabel(AppLocalizations l, MaterialKind k) => switch (k) {
  MaterialKind.chitin => l.materialChitin,
  MaterialKind.mineral => l.materialMineral,
  MaterialKind.sap => l.materialSap,
  MaterialKind.jelly => l.materialJelly,
};

String stageLabel(AppLocalizations l, LifeStage s) => switch (s) {
  LifeStage.egg => l.stageEgg,
  LifeStage.larva => l.stageLarva,
  LifeStage.pupa => l.stagePupa,
  LifeStage.adult => l.stageAdult,
};

String materialDesc(AppLocalizations l, MaterialKind k) => switch (k) {
  MaterialKind.chitin => l.materialChitinDesc,
  MaterialKind.mineral => l.materialMineralDesc,
  MaterialKind.sap => l.materialSapDesc,
  MaterialKind.jelly => l.materialJellyDesc,
};

/// 재화 분류 태그(일반 재료 / 프리미엄).
String materialTag(AppLocalizations l, MaterialKind k) =>
    k == MaterialKind.jelly ? l.tagPremium : l.tagCommonMaterial;

IconData materialIcon(MaterialKind k) => switch (k) {
  MaterialKind.chitin => Icons.shield_outlined,
  MaterialKind.mineral => Icons.diamond_outlined,
  MaterialKind.sap => Icons.water_drop_outlined,
  MaterialKind.jelly => Icons.bubble_chart_outlined,
};
