import 'dart:async';

import 'package:app/l10n/app_localizations.dart';
import 'package:app/ui/popup_gate.dart';
import 'package:app/ui/whats_new.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// "업데이트 내용" 창(1.0.18 도입 · 1.0.21 내용) — 기기당 판마다 한 번 · 방치 보상 뒤 · 순위 앞.
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

    testWidgets('1.0.21 8줄 — 일반 알·패시브 무료 재굴림·알 펫 금지·팀 오라·수련 비용·치기·장비·뱃지', (
      tester,
    ) async {
      await tester.pumpWidget(host(const Locale('ko'), 300));
      expect(kWhatsNewVersion, '1.0.21');
      expect(find.textContaining('모두 일반 등급'), findsOneWidget);
      expect(find.textContaining('무료 재굴림 5번'), findsOneWidget);
      expect(find.textContaining('펫으로 장착할 수 없어요'), findsOneWidget);
      expect(find.textContaining('다시 찍기 1회 무료'), findsOneWidget);
      expect(find.textContaining('수련 비용'), findsOneWidget);
      expect(find.textContaining('치기 주특기'), findsOneWidget);
      expect(find.textContaining('스킬 쿨타임 감소'), findsOneWidget);
      expect(find.textContaining('금·은·동'), findsOneWidget);
      expect(
        whatsNewItems(lookupAppLocalizations(const Locale('ko'))),
        hasLength(8),
      );
      expect(tester.takeException(), isNull);
    });

    for (final lc in const ['en', 'ja']) {
      testWidgets('$lc — 좁은 화면(본문 260px)에서도 넘치지 않는다', (tester) async {
        await tester.pumpWidget(host(Locale(lc), 260));
        expect(tester.takeException(), isNull);
      });
    }
  });
}
