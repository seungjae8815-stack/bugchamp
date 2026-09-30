import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'art.dart';

/// 요정 그림·문구 공용(docs/design_fairy.md). 홈(동행 표시)과 요정 탭이 같은 것을 쓴다.

const _dir = 'assets/images/fairies';

/// 등급 빛 색 — 요정 그림은 등급마다 따로 그리지 않고 이 빛으로 가른다(design_fairy.md §2).
Color fairyGradeColor(FairyGrade g) => switch (g) {
  FairyGrade.common => const Color(0xFFCFD8DC),
  FairyGrade.rare => const Color(0xFF64B5F6),
  FairyGrade.epic => const Color(0xFFBA68C8),
  FairyGrade.legendary => const Color(0xFFFFB74D),
  FairyGrade.mythic => const Color(0xFFFF6F91),
};

String fairyGradeLabel(AppLocalizations l, FairyGrade g) => switch (g) {
  FairyGrade.common => l.fairyGradeCommon,
  FairyGrade.rare => l.fairyGradeRare,
  FairyGrade.epic => l.fairyGradeEpic,
  FairyGrade.legendary => l.fairyGradeLegendary,
  FairyGrade.mythic => l.fairyGradeMythic,
};

/// 능력치 키(fairies.json) → 화면 이름. 모르는 키는 키 그대로.
String fairyStatLabel(AppLocalizations l, String key) => switch (key) {
  'attack' => l.fairyStatAttack,
  'hp' => l.fairyStatHp,
  'defense' => l.fairyStatDefense,
  'attackSpeed' => l.fairyStatAttackSpeed,
  'critDamage' => l.fairyStatCritDamage,
  'bossDamage' => l.fairyStatBossDamage,
  'petShare' => l.fairyStatPetShare,
  _ => key,
};

/// 능력치 값(0.083) → `+8.3%`. 방어는 받는 피해 감소라 `−`.
String fairyStatValue(String key, double v) {
  final p = (v * 100).toStringAsFixed(v * 100 >= 10 ? 0 : 1);
  return key == 'defense' ? '−$p%' : '+$p%';
}

String _pct(double v) => (v * 100).toStringAsFixed(0);

String _sec(Duration d) {
  final s = d.inMilliseconds / 1000;
  return s == s.roundToDouble() ? '${s.round()}' : s.toStringAsFixed(1);
}

/// 스킬 설명 한 줄 — [value] 는 `FairyConfig.skillValue`(등급·레벨 반영).
String fairySkillText(AppLocalizations l, FairySkillDef sk, double value) =>
    switch (sk.effect) {
      'burstDamage' => l.fairySkillBurst(value.toStringAsFixed(1)),
      'bossBurst' => l.fairySkillBossBurst(value.toStringAsFixed(1)),
      'heal' => l.fairySkillHeal(_pct(value)),
      'damageReduce' => l.fairySkillGuard(
        _sec(sk.duration),
        _pct(value.clamp(0.0, 0.8)),
      ),
      'attackSpeed' => l.fairySkillHaste(_sec(sk.duration), _pct(value)),
      'petPower' => l.fairySkillPet(_sec(sk.duration), _pct(value)),
      'critStrikes' => l.fairySkillCrits('${value.round().clamp(1, 20)}'),
      'lastStand' => l.fairySkillStand(_pct(value.clamp(0.05, 1.0))),
      _ => sk.effect,
    };

/// 요정 그림(날갯짓 1). 그림이 없으면 🧚.
Widget fairyPortrait(String kind, {required double size}) => gameImageChain(
  ['$_dir/fairy_${kind}_1.webp'],
  size: size,
  fallback: Text('🧚', style: TextStyle(fontSize: size * 0.55)),
);

/// 등급 빛을 깐 요정 그림 — 요정함·동행 칸·도감이 같은 모양을 쓴다.
Widget fairyGlow(Fairy f, {required double size}) {
  final c = fairyGradeColor(f.grade);
  return Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: [c.withValues(alpha: 0.5), c.withValues(alpha: 0)],
      ),
    ),
    child: fairyPortrait(f.kind, size: size * 0.9),
  );
}

/// 요정 알 그림 — 등급 색으로 물들인다(알은 한 장만 그렸다).
Widget fairyEggImage(FairyGrade g, {required double size}) {
  final c = fairyGradeColor(g);
  return Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: [c.withValues(alpha: 0.45), c.withValues(alpha: 0)],
      ),
    ),
    child: gameImageChain(
      ['$_dir/fairy_egg.webp'],
      size: size * 0.8,
      fallback: Text('🥚', style: TextStyle(fontSize: size * 0.5)),
    ),
  );
}

/// 속성석 그림(부가 능력치 키마다 하나).
Widget fairyStoneImage(String sub, {required double size}) => gameImageChain(
  ['$_dir/stone_$sub.webp'],
  size: size,
  fallback: Text('💎', style: TextStyle(fontSize: size * 0.7)),
);

/// 가속기 그림(가속기 id 마다 하나).
Widget fairyAccelImage(String id, {required double size}) => gameImageChain(
  ['$_dir/$id.webp'],
  size: size,
  fallback: Text('⏳', style: TextStyle(fontSize: size * 0.7)),
);

/// 요정 가루 그림.
Widget fairyDustImage({required double size}) => gameImageChain(
  ['$_dir/fairy_dust.webp'],
  size: size,
  fallback: Text('✨', style: TextStyle(fontSize: size * 0.7)),
);

/// 둥지 그림.
Widget fairyNestImage({required double size}) => gameImageChain(
  ['$_dir/fairy_nest.webp'],
  size: size,
  fallback: Text('🪺', style: TextStyle(fontSize: size * 0.6)),
);
