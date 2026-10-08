import 'package:core_battle/core_battle.dart';
import 'package:flutter/material.dart' hide Element;

import '../../data/game_data.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/art.dart';
import '../../ui/format.dart';
import '../../ui/game_dialog.dart';
import '../../ui/labels.dart';
import '../../ui/skins.dart';

/// 결투 곤충 한 마리의 능력치 창 — 순위표 프로필에서 곤충을 누를 때(2026-09-29).
/// 서버가 그 사람의 세이브로 계산한 값(훈련·수련 반영)을 그대로 보여 준다.
///
/// [confirm] 을 주면 `취소 · confirm` 버튼이 붙고, confirm 을 누르면 true 를 돌려준다
/// (왕충 선발대회 출전 곤충 고르기).
///
/// [skin] 은 그림의 이색·스킨(상대는 [foeBugView], 내 곤충은 [bugView]),
/// [variant] 면 등급 옆에 이색 칩을 단다.
Future<bool?> showDuelBugInfo(
  BuildContext context,
  GameData? data,
  DuelBug d, {
  String? confirm,
  SkinView? skin,
  bool variant = false,
}) {
  final l = AppLocalizations.of(context);
  final locale = Localizations.localeOf(context).languageCode;
  String name = d.name;
  Color? gradeC;
  String? grade;
  try {
    final sp = data?.species(d.speciesId);
    if (sp != null) {
      name = sp.name.resolve(locale);
      grade = gradeLabel(l, sp.grade);
      gradeC = gradeColor(sp.grade);
    }
  } catch (_) {}
  Widget row(String k, String v, {Color? c, Widget? lead}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(
            k,
            style: const TextStyle(color: Color(0xAAFFFFFF), fontSize: 12),
          ),
        ),
        if (lead != null) ...[lead, const SizedBox(width: 4)],
        Expanded(
          child: Text(
            v,
            style: TextStyle(
              color: c ?? Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    ),
  );
  String pct(double v) => '${(v * 100).toStringAsFixed(1)}%';
  return showGameDialog<bool>(
    context,
    title: name,
    iconWidget: bugPoseImage(
      d.speciesId,
      BugPose.idle,
      size: 60,
      skin: skin,
      fallback: const Icon(Icons.bug_report, color: Colors.white54),
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (grade != null || variant)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Wrap(
              spacing: 4,
              children: [
                if (grade != null) duelInfoChip(grade, gradeC!),
                if (variant) duelInfoChip(l.dexVariant, kVariantChipColor),
              ],
            ),
          ),
        row(
          l.statCombatPower,
          formatCompact(d.power.round()),
          c: const Color(0xFFEBD24A),
        ),
        row(l.statHp, formatCompact(d.maxHp.round())),
        row(l.bugInfoAtk, formatCompact(d.atk.round())),
        row(l.bugInfoDef, formatCompact(d.def.round())),
        row(l.bugInfoSpd, formatCompact(d.spd.round())),
        row(
          l.bugInfoElement,
          elementLabel(l, d.element),
          c: elementColor(d.element),
          lead: elementIcon(d.element, size: 14),
        ),
        row(l.bugInfoSpecialty, specialtyLabel(l, d.specialty)),
        row(
          l.bugInfoTemperament,
          temperamentLabel(l, d.temperament),
          lead: temperamentIcon(d.temperament, size: 14),
        ),
        row(l.bugInfoSize, l.bugSize(d.sizeMm.toStringAsFixed(1))),
        if (d.evade > 0) row(l.trainEvade, pct(d.evade)),
        if (d.crit > 0) row(l.trainCrit, '+${pct(d.crit)}'),
        if (d.recovery > 0) row(l.trainRecovery, '+${pct(d.recovery)}'),
      ],
    ),
    actions: confirm == null
        ? [gameDialogButton(l.actionClose, () => Navigator.pop(context))]
        : [
            gameDialogButton(
              l.actionCancel,
              () => Navigator.pop(context, false),
              primary: false,
            ),
            gameDialogButton(confirm, () => Navigator.pop(context, true)),
          ],
  );
}

/// 이색 칩 색(채집함·훈련소 이색 칩과 같은 금색).
const Color kVariantChipColor = Color(0xFFE0A020);

/// 능력치 창의 작은 칩(등급·이색).
Widget duelInfoChip(String text, Color c) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
  decoration: BoxDecoration(
    color: c.withValues(alpha: 0.22),
    borderRadius: BorderRadius.circular(6),
  ),
  child: Text(
    text,
    style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w900),
  ),
);
