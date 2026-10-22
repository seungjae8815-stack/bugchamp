import 'package:app/domain/providers.dart';
import 'package:app/features/app_shell.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:app/ui/red_dot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 하단 탭 2쪽(⇄ 전환) — 홈은 양쪽 맨 앞, 다른 쪽에 빨간 점이 있으면 ⇄ 에 점.
Widget _bar(
  ProviderContainer c, {
  Set<int> dots = const {},
  Locale locale = const Locale('ko'),
  double width = 400,
  double textScale = 1,
}) => UncontrolledProviderScope(
  container: c,
  child: MaterialApp(
    locale: locale,
    builder: (ctx, child) => MediaQuery(
      data: MediaQuery.of(
        ctx,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        width: width,
        child: Scaffold(
          body: const SizedBox.shrink(),
          bottomNavigationBar: GameNavBar(dots: dots),
        ),
      ),
    ),
  ),
);

Finder _switchDot() => find.descendant(
  of: find.byKey(const Key('navSwitch')),
  matching: find.byType(RedDot),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('처음은 1쪽 — 홈·채집함·결투·길드·상점 + 전환', (tester) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await tester.pumpWidget(_bar(c));
    await tester.pump();
    for (final t in ['홈', '채집함', '전투', '길드', '상점', '전환']) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expect(find.text('장비'), findsNothing);
  });

  testWidgets('⇄ 누르면 2쪽 — 홈·장비·스킬·요정·연구소, 고른 쪽을 기억', (tester) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await tester.pumpWidget(_bar(c));
    await tester.pump();
    await tester.tap(find.byKey(const Key('navSwitch')));
    await tester.pump();
    for (final t in ['홈', '장비', '스킬', '요정', '연구소', '전환']) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expect(find.text('상점'), findsNothing);
    expect(c.read(navPageProvider), 1);
    final p = await SharedPreferences.getInstance();
    expect(p.getInt('nav.page'), 1);

    await tester.tap(find.text('스킬'));
    await tester.pump();
    expect(c.read(tabIndexProvider), kSkillTabIndex);
  });

  testWidgets('기억한 쪽으로 시작한다', (tester) async {
    SharedPreferences.setMockInitialValues({'nav.page': 1});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await tester.pumpWidget(_bar(c));
    await tester.pumpAndSettle();
    expect(find.text('연구소'), findsOneWidget);
  });

  testWidgets('2쪽에서 상점으로 가면 1쪽으로 바뀐다', (tester) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await tester.pumpWidget(_bar(c));
    await tester.pump();
    c.read(tabIndexProvider.notifier).set(kResearchTabIndex);
    await tester.pump();
    expect(c.read(navPageProvider), 1);
    c.read(tabIndexProvider.notifier).set(kShopTabIndex);
    await tester.pump();
    expect(c.read(navPageProvider), 0);
    expect(find.text('상점'), findsOneWidget);
    // 홈은 양쪽에 있어 쪽을 바꾸지 않는다.
    c.read(navPageProvider.notifier).set(1);
    c.read(tabIndexProvider.notifier).set(0);
    await tester.pump();
    expect(c.read(navPageProvider), 1);
  });

  testWidgets('다른 쪽 탭에 빨간 점이 있으면 ⇄ 에 점', (tester) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await tester.pumpWidget(_bar(c, dots: {kSkillTabIndex}));
    await tester.pump();
    expect(_switchDot(), findsOneWidget);
    // 2쪽으로 오면 스킬 탭 자체에 점이 있고 ⇄ 에는 없다.
    await tester.tap(find.byKey(const Key('navSwitch')));
    await tester.pump();
    expect(_switchDot(), findsNothing);

    // 같은 쪽 점만 있으면 ⇄ 에는 점이 없다 · 홈 점은 양쪽에 있으니 세지 않는다.
    await tester.pumpWidget(_bar(c, dots: {0, kEquipTabIndex}));
    await tester.pump();
    expect(_switchDot(), findsNothing);
  });

  testWidgets('nav_fits_260px_ja', (tester) async {
    for (final page in [0, 1]) {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(navPageProvider.notifier).set(page);
      await tester.pumpWidget(
        _bar(c, locale: const Locale('ja'), width: 260, dots: {0, 1, 5, 8}),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'page $page');
    }
  });

  testWidgets('nav_label_320px_ja — 큰 글씨 1.3 에서도 라벨이 9px 아래로 안 줄어든다', (
    tester,
  ) async {
    for (final page in [0, 1]) {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(navPageProvider.notifier).set(page);
      await tester.pumpWidget(
        _bar(c, locale: const Locale('ja'), width: 320, textScale: 1.3),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      final labels = find.descendant(
        of: find.byType(GameNavBar),
        matching: find.byType(Text),
      );
      expect(labels, findsNWidgets(6));
      for (final e in labels.evaluate()) {
        final text = tester.widget<Text>(find.byWidget(e.widget));
        final own = tester.getSize(find.byWidget(e.widget)).width;
        final box = tester
            .getSize(
              find
                  .ancestor(
                    of: find.byWidget(e.widget),
                    matching: find.byType(FittedBox),
                  )
                  .first,
            )
            .width;
        final scaled =
            text.style!.fontSize! *
            (box / own).clamp(0.0, 1.0) *
            MediaQuery.textScalerOf(e).scale(1);
        expect(scaled, greaterThanOrEqualTo(9), reason: '${text.data} p$page');
      }
    }
  });
}
