import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';
import 'package:flutter/material.dart' hide Element;

import '../l10n/app_localizations.dart';
import 'labels.dart';

/// 경기장 오행 한 줄(2026-10-16, `docs/design_arena_element.md`) — "불 경기장 · 불 +10% · 쇠 −10%".
/// 결투 후보 창·경기 화면·대회 웨이브가 같은 줄을 쓴다(수치는 `battle.json → duel.arenaSame·arenaRestrained`).
Widget arenaEffectLine(
  AppLocalizations l,
  Element arena,
  DuelParams p, {
  double fontSize = 12,
}) {
  final weak = Element.values.firstWhere(arena.restrains, orElse: () => arena);
  String pct(double v) => (v * 100).round().toString();
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      elementIcon(arena, size: fontSize + 4),
      const SizedBox(width: 4),
      Flexible(
        child: Text(
          l.arenaEffectLine(
            elementLabel(l, arena),
            pct(p.arenaSame),
            elementLabel(l, weak),
            pct(p.arenaRestrained),
          ),
          style: TextStyle(
            color: elementColor(arena),
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ],
  );
}
