import 'dart:async';

import 'package:app/l10n/app_localizations.dart';
import 'package:app/ui/popup_gate.dart';
import 'package:app/ui/whats_new.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// "업데이트 내용" 창(1.0.18 도입 · 1.0.20 내용) — 기기당 판마다 한 번 · 방치 보상 뒤 · 순위 앞.
void main() {
  group('막 시작한 세이브에는 띄우지 않는다', () {
    final now = DateTime.utc(2026, 10, 9, 12);
    test('방금 만든 세이브 = 새로 시작', () {
      expect(
        isFreshSave(now.subtract(const Duration(minutes: 2)), now),
        isTrue,
      );
    });
    test('며칠 전 세이브 = 기존 유저', () {
      expect(isFreshSave(now.subtract(const Duration(days: 3)), now), isFalse);
    });
  });

  group('시작 팝업 순서 — 방치 보상 → 업데이트 내용 → 순위', () {
    setUp(StartupPopupGate.reset);

    test('가운데 팝업은 자기 자리만 남으면 뜨고, 순위는 둘 다 닫혀야 뜬다', () async {
      StartupPopupGate.hold(); // 방치 보상(홈 화면 initState)
      StartupPopupGate.hold(); // 업데이트 내용(앱 셸 첫 프레임)
      var whatsNew = false, rank = false;
      unawaited(StartupPopupGate.whenIdle(own: 1).then((_) => whatsNew = true));
      unawaited(StartupPopupGate.whenIdle().then((_) => rank = true));
      await Future<void>.delayed(Duration.zero);
      expect(whatsNew, isFalse, reason: '방치 보상이 떠 있다');
      expect(StartupPopupGate.busyBeyond(1), isTrue);
      StartupPopupGate.release(); // 방치 보상 닫힘
      await Future<void>.delayed(Duration.zero);
      expect(whatsNew, isTrue);
      expect(rank, isFalse, reason: '업데이트 내용이 아직 떠 있다');
      expect(StartupPopupGate.busyBeyond(1), isFalse);
      StartupPopupGate.release(); // 업데이트 내용 닫힘
      await Future<void>.delayed(Duration.zero);
      expect(rank, isTrue);
    });

    test('앞 팝업이 없으면 바로', () async {
      StartupPopupGate.hold();
      var done = false;
      unawaited(StartupPopupGate.whenIdle(own: 1).then((_) => done = true));
      await Future<void>.delayed(Duration.zero);
      expect(done, isTrue);
    });
  });

  group('본문', () {
    Widget host(Locale locale, double width) => MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: SingleChildScrollView(
              child: Builder(
                builder: (context) => WhatsNewBody(
                  items: whatsNewItems(AppLocalizations.of(context)),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    testWidgets('1.0.20 9줄 — 개체 등급·물약·펫·뽑기 천장·초월 시간·별 인계·전투력·리그·약충', (
      tester,
    ) async {
      await tester.pumpWidget(host(const Locale('ko'), 300));
      expect(kWhatsNewVersion, '1.0.20');
      expect(find.textContaining('등급(일반~전설)'), findsOneWidget);
      expect(find.textContaining('성장물약'), findsOneWidget);
      expect(find.textContaining('펫 효과'), findsOneWidget);
      expect(find.textContaining('50회 안에 전설'), findsOneWidget);
      expect(find.textContaining('공방 초월'), findsOneWidget);
      expect(find.textContaining('별을 그대로'), findsOneWidget);
      expect(find.textContaining('결투 전투력'), findsOneWidget);
      expect(find.textContaining('리그 순위표'), findsOneWidget);
      expect(find.textContaining('약충'), findsOneWidget);
      expect(find.byType(Icon), findsNWidgets(9));
    });

    for (final lc in const ['en', 'ja']) {
      testWidgets('$lc — 좁은 화면(본문 260px)에서도 넘치지 않는다', (tester) async {
        await tester.pumpWidget(host(Locale(lc), 260));
        expect(tester.takeException(), isNull);
      });
    }
  });
}
