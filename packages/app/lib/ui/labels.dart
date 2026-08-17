import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:flutter/material.dart' hide Element;

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

String elementLabel(AppLocalizations l, Element e) => switch (e) {
  Element.fire => l.elementFire,
  Element.water => l.elementWater,
  Element.wood => l.elementWood,
  Element.metal => l.elementMetal,
  Element.earth => l.elementEarth,
};

String elementGlyph(Element e) => switch (e) {
  Element.fire => '🔥',
  Element.water => '💧',
  Element.wood => '🌿',
  Element.metal => '⚙️',
  Element.earth => '⛰️',
};

Color elementColor(Element e) => switch (e) {
  Element.fire => const Color(0xFFFF6B4A),
  Element.water => const Color(0xFF4AA8FF),
  Element.wood => const Color(0xFF6FCF6F),
  Element.metal => const Color(0xFFCBD3DA),
  Element.earth => const Color(0xFFD2A56A),
};

// ── 전투 장소(오행 1:1 매핑) ─────────────────────────────
// 木=숲 · 火=용암굴 · 土=황무지 · 金=폐허도시 · 水=심해.
// 그 장소 오행과 같은 곤충은 데미지 강화(장소 상성).
String biomeName(AppLocalizations l, Element e) => switch (e) {
  Element.wood => l.biomeForest,
  Element.fire => l.biomeVolcano,
  Element.earth => l.biomeBadlands,
  Element.metal => l.biomeCity,
  Element.water => l.biomeDeep,
};

String biomeEmoji(Element e) => switch (e) {
  Element.wood => '🌲',
  Element.fire => '🌋',
  Element.earth => '🏜️',
  Element.metal => '🏙️',
  Element.water => '🌊',
};

/// 장소 배경 이미지(`assets/images/biomes/{오행key}.webp`).
/// 파일이 없으면 [fallback] 로 폴백(보통 그라데이션만 보이게 빈 위젯).
Widget biomeBackground(Element e, {required Widget fallback}) => Image.asset(
  'assets/images/biomes/${e.key}.webp',
  fit: BoxFit.cover,
  errorBuilder: (_, _, _) => fallback,
);

/// 장소 배경 그라데이션(상단→하단). 배경 아트가 없을 때의 폴백.
List<Color> biomeColors(Element e) => switch (e) {
  Element.wood => const [Color(0xFF1E3A1E), Color(0xFF0B1A0B)],
  Element.fire => const [Color(0xFF3E1712), Color(0xFF190807)],
  Element.earth => const [Color(0xFF3A2E15), Color(0xFF19140A)],
  Element.metal => const [Color(0xFF262C34), Color(0xFF0E1218)],
  Element.water => const [Color(0xFF102A44), Color(0xFF071522)],
};

String temperamentLabel(AppLocalizations l, Temperament t) => switch (t) {
  Temperament.aggressive => l.temperamentAggressive,
  Temperament.cautious => l.temperamentCautious,
  Temperament.cunning => l.temperamentCunning,
  Temperament.steadfast => l.temperamentSteadfast,
  Temperament.fickle => l.temperamentFickle,
};

/// 혈통 특성(§2.5) 이름. 짝짓기 자식만 가진다.
String traitLabel(AppLocalizations l, BugTrait t) => switch (t) {
  BugTrait.none => '',
  BugTrait.fierce => l.traitFierce,
  BugTrait.sturdy => l.traitSturdy,
  BugTrait.vital => l.traitVital,
  BugTrait.noble => l.traitNoble,
};

/// 특성 색 — 무엇에 특화됐는지 색으로 먼저 읽히게 한다
/// (공격 계열=붉은색, 방어 계열=푸른색, 양쪽=보라).
Color traitColor(BugTrait t) => switch (t) {
  BugTrait.none => const Color(0x66FFFFFF),
  BugTrait.fierce => const Color(0xFFFF7043),
  BugTrait.sturdy => const Color(0xFF42A5F5),
  BugTrait.vital => const Color(0xFF66BB6A),
  BugTrait.noble => const Color(0xFFBA68C8),
};

String traitGlyph(BugTrait t) => switch (t) {
  BugTrait.none => '',
  BugTrait.fierce => '🔥',
  BugTrait.sturdy => '🛡',
  BugTrait.vital => '🌿',
  BugTrait.noble => '👑',
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
  MaterialKind.fossil => l.materialFossil,
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
  MaterialKind.fossil => l.materialFossilDesc,
};

/// 재화 분류 태그(일반 재료 / 프리미엄).
String materialTag(AppLocalizations l, MaterialKind k) =>
    k == MaterialKind.jelly ? l.tagPremium : l.tagCommonMaterial;

IconData materialIcon(MaterialKind k) => switch (k) {
  MaterialKind.chitin => Icons.shield_outlined,
  MaterialKind.mineral => Icons.diamond_outlined,
  MaterialKind.sap => Icons.water_drop_outlined,
  MaterialKind.jelly => Icons.bubble_chart_outlined,
  MaterialKind.fossil => Icons.hardware_outlined,
};

/// 능력치(업그레이드) 이름. 강화 패널·도감의 종 패시브가 **같은 이름**을
/// 써야 "이 패시브가 무슨 능력치를 올리는지"가 바로 연결된다.
String upgradeLabel(AppLocalizations l, UpgradeKind k) => switch (k) {
  UpgradeKind.attack => l.upAttack,
  UpgradeKind.attackSpeed => l.upAttackSpeed,
  UpgradeKind.crit => l.upCrit,
  UpgradeKind.critDamage => l.upCritDamage,
  UpgradeKind.bossDamage => l.upBossDamage,
  UpgradeKind.maxHp => l.upMaxHp,
  UpgradeKind.defense => l.upDefense,
  UpgradeKind.regen => l.upRegen,
  UpgradeKind.reward => l.upReward,
  UpgradeKind.xp => l.upXp,
  UpgradeKind.bugFind => l.upBugFind,
  UpgradeKind.materialFind => l.upMaterialFind,
  UpgradeKind.moveSpeed => l.upMoveSpeed,
  UpgradeKind.boost => l.upBoost,
  UpgradeKind.bugBuff => l.upBugBuff,
};

/// 종 패시브(§2.1) 한 줄 — "투지 +25%" 처럼 읽히게 만든다.
///
/// 치명타 확률만 **%p** 다(0.04 = +4%p). 배율 스탯과 같은 '%' 로 쓰면
/// "치명타 +4%" 가 상대 증가로 읽혀 실제보다 작아 보인다.
String passiveText(AppLocalizations l, SpeciesPassive p) {
  final kind = UpgradeKind.fromKeyOrNull(p.statKey);
  if (kind == null) return '';
  final pct = (p.value * 100);
  final num = pct == pct.roundToDouble()
      ? pct.toStringAsFixed(0)
      : pct.toStringAsFixed(1);
  final unit = kind == UpgradeKind.crit ? '%p' : '%';
  return '${upgradeLabel(l, kind)} +$num$unit';
}

/// 타이머 남은 시간 라벨(1시간↑ "N시간 M분" / 1분↑ "N분" / 그 미만 "N초").
///
/// 부화기·돌파·부상·짝짓기·공방이 전부 같은 모양으로 보여야 한다 —
/// 화면마다 제 나름대로 포맷하면 같은 "3분"이 어디선 "180초"로 뜬다.
String remainLabel(AppLocalizations l, Duration d) {
  final s = d.inSeconds <= 0 ? 0 : d.inSeconds;
  if (s >= 3600) return l.durationHm(s ~/ 3600, (s % 3600) ~/ 60);
  if (s >= 60) return l.durationM(s ~/ 60);
  return l.durationS(s);
}

/// 이벤트 강화 카드의 이름·설명. 카드 id 는 `event.json → cards.list` 의 것.
///
/// 모르는 id 면 빈 문자열이 아니라 id 를 그대로 보여준다 — JSON 에 카드를
/// 추가하고 ARB 를 깜빡했을 때 화면이 비어 보이는 대신 눈에 띄게 만든다.
(String, String) cardText(AppLocalizations l, String id) => switch (id) {
  'heal_s' => (l.cardHeal_s, l.cardHeal_sDesc),
  'heal_l' => (l.cardHeal_l, l.cardHeal_lDesc),
  'atk_s' => (l.cardAtk_s, l.cardAtk_sDesc),
  'atk_l' => (l.cardAtk_l, l.cardAtk_lDesc),
  'def_s' => (l.cardDef_s, l.cardDef_sDesc),
  'hp_s' => (l.cardHp_s, l.cardHp_sDesc),
  'revive' => (l.cardRevive, l.cardReviveDesc),
  'skip' => (l.cardSkip, l.cardSkipDesc),
  _ => (id, ''),
};

/// 카드 아이콘 폴백 글리프(애셋이 없을 때).
String cardGlyph(String kind) => switch (kind) {
  'heal' => '💚',
  'atk' => '⚔️',
  'def' => '🛡️',
  'maxHp' => '❤️',
  'revive' => '✨',
  'skip' => '🌀',
  _ => '🃏',
};
