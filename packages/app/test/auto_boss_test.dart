import 'package:app/domain/play_prefs.dart';
import 'package:app/features/play/boss_challenge_button.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:core_run/core_run.dart';
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

    test('일일보상 자동 열기 기록은 재시작 후에도 남는다', () async {
      SharedPreferences.setMockInitialValues({});
      await PlayPrefs.instance.load();
      await PlayPrefs.instance.markDailyAutoShown('2026-11-09:lunch');
      PlayPrefs.instance.resetForTest();
      await PlayPrefs.instance.load();
      expect(PlayPrefs.instance.dailyAutoShown, '2026-11-09:lunch');
    });
  });

  // 곤충 상세 "성장·능력치 자세히"(2026-11-09) — 쉬움 사냥터 3 전엔 접힘, 그 뒤·기존 유저는 펼침.
  test('bugDetailMoreDefault: 쉬움 사냥터 1·2 접힘 · 3 이상·보통 이상 펼침', () {
    expect(bugDetailMoreDefault(topTier: 0, bestStage: 1), isFalse);
    expect(bugDetailMoreDefault(topTier: 0, bestStage: 200), isFalse);
    expect(bugDetailMoreDefault(topTier: 0, bestStage: 201), isTrue);
    expect(bugDetailMoreDefault(topTier: 1, bestStage: 1), isTrue);
  });

  test('상세 펼침 선택은 재시작 후에도 남는다(고른 적 없으면 null)', () async {
    SharedPreferences.setMockInitialValues({});
    PlayPrefs.instance.resetForTest();
    await PlayPrefs.instance.load();
    expect(PlayPrefs.instance.bugDetailMore.value, isNull);
    await PlayPrefs.instance.setBugDetailMore(true);
    PlayPrefs.instance.resetForTest();
    await PlayPrefs.instance.load();
    expect(PlayPrefs.instance.bugDetailMore.value, isTrue);
  });

  // 일일보상 창 자동 열기(2026-11-09) — 쉬움 사냥터 1 유저 73% 가 일일보상을 한 번도 안 받았다.
  group('dailyAutoOpenKey', () {
    const daily = DailyConfig(
      rewards: [
        DailyReward(id: 'lunch', hour: 12),
        DailyReward(id: 'dinner', hour: 18),
      ],
    );

    test('열린 시간대가 없으면 띄우지 않는다', () {
      expect(
        dailyAutoOpenKey(daily, {}, DateTime(2026, 11, 9, 9), null),
        isNull,
      );
    });

    test('안 받은 점심이 열려 있으면 띄우고, 한 번 띄운 뒤엔 다시 안 띄운다', () {
      final now = DateTime(2026, 11, 9, 13);
      final key = dailyAutoOpenKey(daily, {}, now, null);
      expect(key, '2026-11-09:lunch');
      expect(dailyAutoOpenKey(daily, {}, now, key), isNull);
    });

    test('받은 시간대는 띄우지 않는다 · 어제 받은 기록은 오늘을 막지 않는다', () {
      final now = DateTime(2026, 11, 9, 13);
      expect(
        dailyAutoOpenKey(daily, {'lunch': '2026-11-09'}, now, null),
        isNull,
      );
      expect(
        dailyAutoOpenKey(daily, {'lunch': '2026-11-08'}, now, null),
        '2026-11-09:lunch',
      );
    });

    test('점심 창을 닫고 안 받아도 저녁이 열리면 한 번 더 띄운다', () {
      final now = DateTime(2026, 11, 9, 19);
      expect(
        dailyAutoOpenKey(daily, {}, now, '2026-11-09:lunch'),
        '2026-11-09:dinner',
      );
      expect(dailyAutoOpenKey(daily, {}, now, '2026-11-09:dinner'), isNull);
    });

    test('저녁 창에서 저녁만 받고 닫으면 점심이 남아도 다시 안 띄운다(같은 시간대 한 번)', () {
      final now = DateTime(2026, 11, 9, 19);
      expect(
        dailyAutoOpenKey(
          daily,
          {'dinner': '2026-11-09'},
          now,
          '2026-11-09:dinner',
        ),
        isNull,
      );
      // 그날 처음이면(띄운 적 없음) 점심만 남아도 띄운다 — 열쇠는 지금 시간대(저녁).
      expect(
        dailyAutoOpenKey(daily, {'dinner': '2026-11-09'}, now, null),
        '2026-11-09:dinner',
      );
      expect(
        dailyAutoOpenKey(
          daily,
          {'lunch': '2026-11-09', 'dinner': '2026-11-09'},
          now,
          null,
        ),
        isNull,
      );
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

  group('AutoBossFailGuard — 같은 사냥터 자동 도전 2연패면 멈춤(2026-10-09)', () {
    test('자동 도전이 두 번 연달아 지면 그 사냥터만 멈춘다', () {
      final g = AutoBossFailGuard();
      g.enter('0:1');
      expect(g.recordAutoFail('0:1'), isFalse, reason: '한 번은 그대로 자동');
      expect(g.pausedAt('0:1'), isFalse);
      expect(g.recordAutoFail('0:1'), isTrue, reason: '두 번째 — 멈춘다');
      expect(g.pausedAt('0:1'), isTrue);
      expect(g.pausedAt('0:2'), isFalse, reason: '다른 사냥터는 상관없다');
    });

    test('보스를 잡으면(직접·자동) 다시 자동', () {
      final g = AutoBossFailGuard()
        ..recordAutoFail('0:1')
        ..recordAutoFail('0:1');
      expect(g.pausedAt('0:1'), isTrue);
      g.recordWin();
      expect(g.pausedAt('0:1'), isFalse);
      expect(g.fails, 0);
    });

    test('다른 사냥터로 가면 기록이 비워진다 — 돌아와도 처음부터', () {
      final g = AutoBossFailGuard()
        ..recordAutoFail('1:4')
        ..recordAutoFail('1:4');
      g.enter('1:3'); // 쓰러져 한 칸 아래로
      expect(g.fails, 0);
      g.enter('1:4');
      expect(g.pausedAt('1:4'), isFalse);
    });

    test('같은 사냥터를 계속 알려도(매 프레임) 기록은 유지된다', () {
      final g = AutoBossFailGuard()..recordAutoFail('abyss:7');
      for (var i = 0; i < 100; i++) {
        g.enter('abyss:7');
      }
      expect(g.recordAutoFail('abyss:7'), isTrue);
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

    testWidgets('자동 멈춤: 카운트다운 대신 "자동 멈춤" · 누르면 직접 도전', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(
          BossChallengeButton(
            kills: 100,
            need: 100,
            autoPaused: true,
            onTap: () => taps++,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('자동 멈춤'), findsOneWidget);
      expect(find.byKey(const ValueKey('bossAutoCountdown')), findsNothing);
      await tester.tap(find.text('보스 도전'));
      expect(taps, 1);
    });

    testWidgets('폭은 최대 110 — 긴 영어 문구도 미션 패널 쪽으로 넘치지 않는다', (tester) async {
      Widget en(Widget child) => MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: Center(child: child)),
      );
      for (final b in [
        BossChallengeButton(kills: 3, need: 100, onTap: () {}),
        BossChallengeButton(
          kills: 100,
          need: 100,
          autoSecondsLeft: 3,
          onTap: () {},
        ),
        BossChallengeButton(
          kills: 100,
          need: 100,
          autoPaused: true,
          onTap: () {},
        ),
      ]) {
        await tester.pumpWidget(en(b));
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(find.byType(BossChallengeButton)).width,
          lessThanOrEqualTo(BossChallengeButton.maxWidth),
        );
      }
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
