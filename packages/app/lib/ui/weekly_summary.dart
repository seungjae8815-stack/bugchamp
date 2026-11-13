import 'dart:async';
import 'dart:math' as math;

import 'package:core_save/core_save.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/providers.dart';
import '../domain/save_controller.dart';
import '../l10n/app_localizations.dart';
import 'game_dialog.dart';
import 'popup_gate.dart';

/// 주간 요약(2026-11-12 사장님 확정) — 새 결투 주(월 09시)의 첫 실행에 지난주 기록 한 장.
///
/// 기기 설정(SharedPreferences)에 센다 — 진행·보상과 무관한 안내라 세이브에 넣지 않는다(세이브 크기·서버 검사 밖).
/// 기기를 바꾸면 그 주 기록은 처음부터다(괜찮다 — 자랑거리일 뿐).
class WeeklyStats {
  static const _week = 'wk.id';
  static const _levels = 'wk.levels';
  static const _lucky = 'wk.lucky';
  static const _awaken = 'wk.awaken';
  static const _abyss = 'wk.abyss';

  /// 강화를 샀다 — 오른 레벨·대성공·각성 수를 더한다.
  static Future<void> addUpgrade({
    int levels = 0,
    int lucky = 0,
    int awaken = 0,
  }) async {
    try {
      final p = await SharedPreferences.getInstance();
      for (final (key, n) in [
        (_levels, levels),
        (_lucky, lucky),
        (_awaken, awaken),
      ]) {
        if (n > 0) await p.setInt(key, (p.getInt(key) ?? 0) + n);
      }
    } catch (_) {}
  }

  /// 이번 주 심연 층을 본 순간(앱이 뒤로 갈 때) — 가장 높은 값만 남긴다.
  static Future<void> noteAbyss(int floor) async {
    if (floor <= 0) return;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt(_abyss, math.max(p.getInt(_abyss) ?? 0, floor));
    } catch (_) {}
  }
}

/// 앱 시작 시 1회 — 지난번에 센 주와 지금 주가 다르면 그 기록을 보여 주고 새로 센다.
/// 순서는 업데이트 내용 팝업과 같은 문([StartupPopupGate])을 쓴다.
Future<void> showWeeklySummaryOnStart(
  BuildContext context,
  WidgetRef ref,
) async {
  StartupPopupGate.hold();
  try {
    final SharedPreferences p;
    try {
      p = await SharedPreferences.getInstance();
    } catch (_) {
      return;
    }
    final battle = ref.read(gameDataProvider).value?.battleConfig;
    if (battle == null) return;
    final week = abyssWeekId(ref.read(clockProvider).now().toUtc(), battle);
    final last = p.getString(WeeklyStats._week);
    if (last == week) return;
    final levels = p.getInt(WeeklyStats._levels) ?? 0;
    final lucky = p.getInt(WeeklyStats._lucky) ?? 0;
    final awaken = p.getInt(WeeklyStats._awaken) ?? 0;
    final abyss = p.getInt(WeeklyStats._abyss) ?? 0;
    // 새 주로 넘긴다 — 닫는 방식과 무관하게 다시 뜨지 않게 먼저.
    await p.setString(WeeklyStats._week, week);
    for (final k in [
      WeeklyStats._levels,
      WeeklyStats._lucky,
      WeeklyStats._awaken,
      WeeklyStats._abyss,
    ]) {
      await p.remove(k);
    }
    // 처음 세기 시작한 기기(지난 기록 없음)·아무것도 안 한 주는 띄우지 않는다.
    if (last == null || levels + lucky + awaken + abyss == 0) return;
    if (!context.mounted) return;
    try {
      await ref.read(saveControllerProvider.future);
    } catch (_) {
      return;
    }
    final waited = StartupPopupGate.busyBeyond(1);
    await StartupPopupGate.whenIdle(own: 1);
    if (waited) await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!context.mounted) return;
    final l = AppLocalizations.of(context);
    final nav = Navigator.of(context);
    final lines = [
      if (levels > 0) (Icons.trending_up_rounded, l.weeklyLevels('$levels')),
      if (lucky > 0) (Icons.auto_awesome_rounded, l.weeklyLucky('$lucky')),
      if (awaken > 0) (Icons.bolt_rounded, l.weeklyAwaken('$awaken')),
      if (abyss > 0) (Icons.layers_rounded, l.weeklyAbyss('$abyss')),
    ];
    await showGameDialog<void>(
      context,
      title: l.weeklyTitle,
      subtitle: l.weeklySubtitle,
      icon: Icons.event_note_rounded,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (icon, text) in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(icon, color: const Color(0xFFFFD977), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      actions: [
        gameDialogButton(l.whatsNewOk, () {
          if (nav.mounted && nav.canPop()) nav.pop();
        }),
      ],
    );
  } finally {
    StartupPopupGate.release();
  }
}
