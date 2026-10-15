import 'package:app/features/play/buff_wait_dialog.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// 무료 버프 대기 화면(2026-10-15 사장님 확정 60초) — 끝까지 기다리면 done, 취소·젤리는 그 결과.
void main() {
  Future<BuffWaitResult?> run(
    WidgetTester t,
    Future<void> Function(AppLocalizations l) act,
  ) async {
    BuffWaitResult? result;
    await t.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
              onPressed: () async => result = await showBuffWait(
                ctx,
                icon: const Icon(Icons.star),
                buffName: '황금 러시',
                seconds: 60,
                jellyCost: 5,
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('go'));
    await t.pump();
    await act(lookupAppLocalizations(const Locale('ko')));
    await t.pumpAndSettle();
    return result;
  }

  testWidgets('60초를 다 기다리면 done', (t) async {
    final r = await run(t, (l) async {
      expect(find.text(l.buffWaitTitle('황금 러시')), findsOneWidget);
      expect(find.text('1:00'), findsOneWidget);
      await t.pump(const Duration(seconds: 30));
      expect(find.text('0:30'), findsOneWidget);
      await t.pump(const Duration(seconds: 31));
    });
    expect(r, BuffWaitResult.done);
    expect(t.takeException(), isNull);
  });

  testWidgets('취소를 누르면 cancel', (t) async {
    final r = await run(t, (l) async {
      await t.pump(const Duration(seconds: 10));
      await t.ensureVisible(find.text(l.actionCancel));
      await t.tap(find.text(l.actionCancel));
    });
    expect(r, BuffWaitResult.cancel);
  });

  testWidgets('젤리로 바로 켜기를 누르면 jelly', (t) async {
    final r = await run(t, (l) async {
      await t.ensureVisible(find.text(l.buffWaitJelly(5)));
      await t.tap(find.text(l.buffWaitJelly(5)));
    });
    expect(r, BuffWaitResult.jelly);
  });

  testWidgets('위에 다른 창이 떠 있는 동안은 멈추고, 닫히면 이어서 done', (t) async {
    final r = await run(t, (l) async {
      await t.pump(const Duration(seconds: 10));
      final nav = t.state<NavigatorState>(find.byType(Navigator).first);
      nav.push(
        DialogRoute<bool>(
          context: nav.context,
          builder: (_) => const Text('over'),
        ),
      );
      await t.pump();
      await t.pump(const Duration(seconds: 70));
      expect(find.text('over'), findsOneWidget);
      nav.pop();
      await t.pump();
      await t.pump(const Duration(seconds: 51));
    });
    expect(r, BuffWaitResult.done);
    expect(t.takeException(), isNull);
  });
}
