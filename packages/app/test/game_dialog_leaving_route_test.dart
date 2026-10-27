import 'dart:async';

import 'package:app/ui/game_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 치워지는 화면에서 띄운 팝업(2026-10-27 1.0.26 크래시 두 건 — `_showOfflineReward` · `_showSoftUpdate`).
///
/// 앱 복귀 때 앱 셸이 타이틀로 되돌리는(`pushAndRemoveUntil`) 동안 사냥 화면은 새 화면 애니메이션이 끝날 때까지
/// 아직 mounted 라 방치 보상 팝업이 **새 타이틀 위에** 떴다. 그 뒤 사냥 화면이 내려가고 "닫기"가 사라진 화면의
/// context 로 `Navigator.pop` 을 불러 `navigator!` 에서 죽었다.
void main() {
  testWidgets('치워지는 화면의 context 로는 팝업을 띄우지 않는다 — 새 화면 위에 주인 없는 팝업이 남지 않게', (
    tester,
  ) async {
    late BuildContext oldCtx;
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: nav,
        home: Builder(
          builder: (ctx) {
            oldCtx = ctx;
            return const Scaffold(body: Text('old'));
          },
        ),
      ),
    );
    // 타이틀로 되돌리기 — 옛 화면은 애니메이션 동안 남아 있다.
    unawaited(
      nav.currentState!.pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('title')),
        ),
        (_) => false,
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(oldCtx.mounted, isTrue, reason: '아직 내려가지 않은 순간을 재현해야 한다');

    final shown = showGameDialog<bool>(
      oldCtx,
      title: 'offline',
      content: const Text('reward'),
      actions: [gameDialogButton('close', () => Navigator.pop(oldCtx))],
    );
    await tester.pumpAndSettle();
    expect(find.text('title'), findsOneWidget);
    expect(find.text('close'), findsNothing, reason: '주인 없는 팝업이 떴다');
    expect(await shown, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('보통 화면에서는 그대로 뜬다', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) {
            ctx = c;
            return const Scaffold(body: Text('home'));
          },
        ),
      ),
    );
    unawaited(
      showGameDialog<void>(
        ctx,
        title: 'hi',
        content: const Text('body'),
        actions: [gameDialogButton('close', () => Navigator.pop(ctx))],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('close'), findsOneWidget);
    await tester.tap(find.text('close'));
    await tester.pumpAndSettle();
    expect(find.text('close'), findsNothing);
  });
}
