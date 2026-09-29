import 'package:core_battle/core_battle.dart';
import 'package:flutter/material.dart' hide Element;

import '../../data/game_data.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/art.dart';
import '../../ui/format.dart';
import '../../ui/game_dialog.dart';
import '../../ui/labels.dart';

/// 결투 곤충 한 마리의 능력치 창 — 순위표 프로필에서 곤충을 누를 때(2026-09-29).
/// 서버가 그 사람의 세이브로 계산한 값(훈련·수련 반영)을 그대로 보여 준다.
Future<void> showDuelBugInfo(BuildContext context, GameData? data, DuelBug d) {
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
  return showGameDialog<void>(
    context,
    title: name,
    iconWidget: bugPoseImage(
      d.speciesId,
      BugPose.idle,
      size: 60,
      fallback: const Icon(Icons.bug_report, color: Colors.white54),
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (grade != null)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: gradeC!.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              grade,
              style: TextStyle(
                color: gradeC,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
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
    actions: [gameDialogButton(l.actionClose, () => Navigator.pop(context))],
  );
}
