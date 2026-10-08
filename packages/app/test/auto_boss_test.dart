import 'package:app/domain/play_prefs.dart';
import 'package:app/features/play/boss_challenge_button.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 보스 자동 도전(2026-10-08 사장님 확정) — 신규 유저가 [보스 도전] 버튼을 몰라 수만 마리를
/// 잡고도 보스를 한 번도 도전하지 않았다. 기본 켬 · 끄면 수동 · 첫 안내는 1회.
void main() {
  group('PlayPrefs', () {
    setUp(() => PlayPrefs.instance.resetForTest());

    test('처음 설치: 자동 도전 켬 · 안내 아직 안 봄', () async {
      SharedPreferences.setMockInitialValues({});
      await PlayPrefs.instance.load();
      expect(PlayPrefs.instance.loaded, isTrue);
      expect(PlayPrefs.instance.autoBoss.value, isTrue);
      expect(PlayPrefs.instance.bossIntroSeen, isFalse);
    });

    test('끄면 다시 켤 때까지 꺼져 있다(재시작 후에도)', () async {
      SharedPreferences.setMockInitialValues({});
      await PlayPrefs.instance.load();
      await PlayPrefs.instance.setAutoBoss(false);
      PlayPrefs.instance.resetForTest();
      await PlayPrefs.instance.load();
      expect(PlayPrefs.instance.autoBoss.value, isFalse);
    });

    test('첫 안내는 한 번 보면 다시 안 뜬다(재시작 후에도)', () async {
      SharedPreferences.setMockInitialValues({});
      await PlayPrefs.instance.load();
      await PlayPrefs.instance.markBossIntroSeen();
      PlayPrefs.instance.resetForTest();
      await PlayPrefs.instance.load();
      expect(PlayPrefs.instance.bossIntroSeen, isTrue);
    });
  });

  group('AutoBossCountdown', () {
    test('조건이 이어지면 정해진 시간 뒤 한 번만 도전한다', () {
      final c = AutoBossCountdown(seconds: 3);
      var fired = 0;
      for (var i = 0; i < 59; i++) {
        if (c.tick(0.05, armed: true)) fired++;
      }
      expect(fired, 0, reason: '2.95초 — 아직');
      expect(c.secondsLeft, 1);
      if (c.tick(0.05, armed: true)) fired++;
      expect(fired, 1, reason: '3초 — 도전');
      expect(c.left, isNull);
    });

    test('남은 초는 올림으로 3 → 2 → 1', () {
      final c = AutoBossCountdown(seconds: 3);
      c.tick(0.01, armed: true);
      expect(c.secondsLeft, 3);
      c.tick(1.0, armed: true);
      expect(c.secondsLeft, 2);
      c.tick(1.0, armed: true);
      expect(c.secondsLeft, 1);
    });

    test('자동 끔(armed=false)이면 절대 도전하지 않는다 — 수동', () {
      final c = AutoBossCountdown(seconds: 3);
      for (var i = 0; i < 1000; i++) {
        expect(c.tick(0.05, armed: false), isFalse);
      }
      expect(c.secondsLeft, isNull);
    });

    test('조건이 한 번 깨지면(팝업·다른 탭) 처음부터 다시 센다', () {
      final c = AutoBossCountdown(seconds: 3);
      c.tick(2.5, armed: true);
      c.tick(0.05, armed: false);
      expect(c.tick(1.0, armed: true), isFalse, reason: '다시 3초부터');
      expect(c.tick(2.0, armed: true), isTrue);
    });

    test('실패해 게이지가 비었다가 다시 차면 또 도전한다(무한 반복이 정상)', () {
      final c = AutoBossCountdown(seconds: 3);
      expect(c.tick(3.0, armed: true), isTrue);
      c.tick(0.05, armed: false); // 보스전 중 · 게이지 0
      expect(c.tick(3.0, armed: true), isTrue);
    });
  });

  group('BossChallengeButton', () {
    Widget host(Widget child) => MaterialApp(
      locale: const Locale('ko'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Center(child: child)),
    );

    testWidgets('잠김: 남은 마리 수 · 눌러도 아무 일 없음', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(BossChallengeButton(kills: 42, need: 100, onTap: () => taps++)),
      );
      expect(find.text('보스 도전까지 58마리'), findsOneWidget);
      await tester.tap(find.text('보스 도전까지 58마리'));
      expect(taps, 0);
    });

    testWidgets('게이지 참: 보스 도전 + 카운트다운 표시 · 누르면 도전', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(
          BossChallengeButton(
            kills: 100,
            need: 100,
            autoSecondsLeft: 3,
            onTap: () => taps++,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('보스 도전'), findsOneWidget);
      expect(find.text('3초 뒤 자동 도전'), findsOneWidget);
      await tester.tap(find.text('보스 도전'));
      expect(taps, 1);
    });

    testWidgets('자동 끔: 카운트다운 줄 없음', (tester) async {
      await tester.pumpWidget(
        host(BossChallengeButton(kills: 120, need: 100, onTap: () {})),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('보스 도전'), findsOneWidget);
      expect(find.byKey(const ValueKey('bossAutoCountdown')), findsNothing);
    });
  });
}
