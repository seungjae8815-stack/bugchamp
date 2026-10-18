import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';
import 'package:flutter/material.dart' hide Element;

import '../l10n/app_localizations.dart';
import 'labels.dart';

/// 경기장 이득(같은 오행) · 불이익(경기장이 이기는 오행) 글씨 색 — 결투 후보 창 상대 곤충 표시도 같은 색.
const arenaUpColor = Color(0xFF6FCF6F);
const arenaDownColor = Color(0xFFEF6B4A);

/// 경기장 오행 한 줄(2026-10-16, `docs/design_arena_element.md`) — "[불] 불 경기장 · [불] 불 곤충 +10% · [쇠] 쇠 곤충 −10%".
/// 오행마다 앞에 아이콘을 붙이고 이득은 초록 · 불이익은 빨강으로 가른다(2026-10-17 사장님 요청).
/// 결투 후보 창·경기 화면·대회 웨이브가 같은 줄을 쓴다(수치는 `battle.json → duel.arenaSame·arenaRestrained`).
Widget arenaEffectLine(
  AppLocalizations l,
  Element arena,
  DuelParams p, {
  double fontSize = 12,
}) {
  final weak = Element.values.firstWhere(arena.restrains, orElse: () => arena);
  String pct(double v) => (v * 100).round().toString();
  TextStyle style(Color c, {FontWeight w = FontWeight.w800}) =>
      TextStyle(color: c, fontSize: fontSize, fontWeight: w);
  Widget part(Element e, String text, Color c) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      elementIcon(e, size: fontSize + 4),
      const SizedBox(width: 3),
      Text(text, style: style(c)),
    ],
  );
  final dot = Text(' · ', style: style(const Color(0x99FFFFFF)));
  return Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    runSpacing: 2,
    children: [
      part(arena, l.arenaName(elementLabel(l, arena)), elementColor(arena)),
      dot,
      part(
        arena,
        l.arenaBugUp(elementLabel(l, arena), pct(p.arenaSame)),
        arenaUpColor,
      ),
      dot,
      part(
        weak,
        l.arenaBugDown(elementLabel(l, weak), pct(p.arenaRestrained)),
        arenaDownColor,
      ),
      Text(
        ' ${l.arenaStatsNote}',
        style: style(const Color(0x99FFFFFF), w: FontWeight.w600),
      ),
    ],
  );
}
