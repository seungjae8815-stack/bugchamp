import 'package:app/features/battle/clutch_gauge.dart';
import 'package:app/features/battle/duel_arena_screen.dart';
import 'package:app/features/battle/duel_driver.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';

/// 탭 반격(훈련 v2 §4) — 앱 게이지 점수와 진행기의 멈춤·이어짐.
void main() {
  /// 1.2초 안에 [n] 번을 고르게.
  List<double> even(int n, {double span = 1.1}) => [
    for (var i = 0; i < n; i++) (i + 1) * span / (n + 1),
  ];

  group('clutchTapScore', () {
    test('안 누르면 0 · 목표만큼 고르게 누르면 1', () {
      expect(clutchTapScore(const []), 0);
      expect(clutchTapScore(even(10)), closeTo(1, 1e-9));
      expect(clutchTapScore(even(14)), closeTo(1, 1e-9), reason: '목표를 넘어도 1');
    });

    test('고른 박자 약 6번이면 문턱(0.55)을 넘고, 4번이면 못 넘는다', () {
      expect(clutchTapScore(even(6)), greaterThanOrEqualTo(0.55));
      expect(clutchTapScore(even(4)), lessThan(0.55));
    });

    test('같은 수라도 박자가 고르면 더 높다', () {
      final steady = even(8);
      final ragged = [0.05, 0.08, 0.1, 0.12, 0.6, 0.62, 1.0, 1.15];
      expect(clutchTapScore(steady), greaterThan(clutchTapScore(ragged)));
      // 박자가 엉망이어도 연타 몫의 75% 는 남는다.
      expect(clutchTapScore(ragged), greaterThanOrEqualTo(0.75 * 0.8 - 1e-9));
    });

    test('게이지가 닫힌 뒤(시간 밖)의 탭은 세지 않고, 점수는 0~1', () {
      expect(
        clutchTapScore([0.1, 0.2, 1.5, 2.0, 3.0]),
        clutchTapScore([0.1, 0.2]),
      );
      expect(clutchTapScore([-1, 0.1]), clutchTapScore([0.1]));
      for (var n = 0; n < 30; n++) {
        final s = clutchTapScore(even(n), target: 7);
        expect(s, inInclusiveRange(0.0, 1.0));
      }
      expect(clutchTapScore(even(3), seconds: 1.2, target: 0), 0);
    });
  });

  testWidgets('게이지 — 두드린 만큼 세고 시간이 끝나면 점수를 한 번 준다', (tester) async {
    final got = <double>[];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ko'),
        home: Scaffold(
          body: ClutchGauge(
            kind: DuelCrisis.knockout,
            seconds: 1.2,
            target: 10,
            chance: 1,
            chances: 2,
            threshold: 0.55,
            onDone: got.add,
          ),
        ),
      ),
    );
    expect(find.text('일어나!'), findsOneWidget);
    expect(find.text('기회 1/2'), findsOneWidget);
    for (var i = 0; i < 5; i++) {
      await tester.tapAt(const Offset(200, 300));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('5'), findsOneWidget);
    expect(got, isEmpty);
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(got, hasLength(1));
    expect(got.single, inInclusiveRange(0.0, 1.0));
    await tester.pump(const Duration(seconds: 1));
    expect(got, hasLength(1), reason: '한 번만');
  });

  group('로컬 진행기 — 위기에서 멈추고 점수로 이어 간다(서버 세션과 같은 규칙)', () {
    DuelBug bug(String id, double scale, Specialty s) => DuelBug(
      id: id,
      name: id,
      speciesId: 'none',
      element: Element.wood,
      temperament: Temperament.aggressive,
      specialty: s,
      sizeMm: 50,
      maxHp: 150 * scale,
      atk: 60 * scale,
      def: 50 * scale,
      spd: 50 * scale,
    );
    const on = DuelParams(clutchEnabled: true);

    LocalDuelDriver driver(int seed) => LocalDuelDriver(
      seed: seed,
      mine: [for (var i = 0; i < 3; i++) bug('a$i', 1, Specialty.grip)],
      foe: [for (var i = 0; i < 3; i++) bug('b$i', 1.3, Specialty.strike)],
      params: on,
      battle: const BattleConfig(),
      trophies: 0,
      rewardMult: 1,
    );

    test('멈춘 판은 판을 넘기지 않고, 점수를 넣으면 같은 판이 이어진다', () async {
      for (var seed = 1; seed < 200; seed++) {
        final d = driver(seed);
        final s = await d.next(0.6);
        final c = s!.clutch;
        if (c == null) continue;
        expect(s.done, isFalse);
        expect(s.bout.winner, -1);
        expect(await d.clutch(c.index + 1, 1), isNull, reason: '번호가 안 맞으면 거부');
        final r = await d.clutch(c.index, 1);
        expect(r, isNotNull);
        expect(
          r!.bout.frames.take(s.bout.frames.length).toList().toString(),
          s.bout.frames.toString(),
        );
        expect(
          r.bout.events.any(
            (e) =>
                e.who == 0 &&
                e.kind == DuelEventKind.clutchSave &&
                e.tick == c.tick,
          ),
          isTrue,
        );
        return;
      }
      fail('위기가 한 번도 오지 않았다');
    });

    test('꺼져 있으면(clutchEnabled false) 멈추지 않는다', () async {
      final d = LocalDuelDriver(
        seed: 5,
        mine: [for (var i = 0; i < 3; i++) bug('a$i', 1, Specialty.grip)],
        foe: [for (var i = 0; i < 3; i++) bug('b$i', 1.3, Specialty.strike)],
        params: const DuelParams(),
        battle: const BattleConfig(),
        trophies: 0,
        rewardMult: 1,
      );
      DuelStep? s;
      do {
        s = await d.next(0.6);
        expect(s?.clutch, isNull);
      } while (s != null && !s.done);
    });
  });

  testWidgets('결투장 — 위기에서 재생이 멈추고 게이지 → 점수 → 같은 판이 이어진다', (tester) async {
    DuelBug bug(String id, double scale, Specialty sp) => DuelBug(
      id: id,
      name: id,
      speciesId: 'none',
      element: Element.wood,
      temperament: Temperament.aggressive,
      specialty: sp,
      sizeMm: 50,
      maxHp: 150 * scale,
      atk: 60 * scale,
      def: 50 * scale,
      spd: 50 * scale,
    );
    const on = DuelParams(clutchEnabled: true);
    final mine = [for (var i = 0; i < 3; i++) bug('a$i', 1, Specialty.grip)];
    final foe = [for (var i = 0; i < 3; i++) bug('b$i', 1.3, Specialty.strike)];
    // 게이지 값과 상관없이 첫 판에서 멈추는 seed — 던지기 값을 0.6 으로 고정한 진행기로 찾는다.
    LocalDuelDriver make(int seed) => LocalDuelDriver(
      seed: seed,
      mine: mine,
      foe: foe,
      params: on,
      battle: const BattleConfig(),
      trophies: 0,
      rewardMult: 1,
    );
    var seed = 1;
    while ((await make(seed).next(0.6))?.clutch == null) {
      seed++;
      if (seed > 300) fail('위기 seed 없음');
    }
    final drv = _FixedLaunch(make(seed));
    DuelStep? finished;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ko'),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => DuelArenaScreen(
                      mine: mine,
                      foe: foe,
                      driver: drv,
                      params: on,
                      arena: Element.wood,
                      onFinished: (s) async => finished = s,
                    ),
                  ),
                ),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    final gauge = find.byType(ClutchGauge);
    for (var i = 0; i < 600 && gauge.evaluate().isEmpty; i++) {
      final throwBtn = find.textContaining('던지기!');
      if (throwBtn.evaluate().isNotEmpty) await tester.tap(throwBtn);
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(gauge, findsOneWidget, reason: '위기에서 게이지가 떠야 한다');
    expect(drv.clutches, 0);
    // 연타 — 게이지 아무 데나.
    for (var i = 0; i < 10; i++) {
      await tester.tap(gauge, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 50));
    }
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(drv.clutches, 1, reason: '점수를 한 번 보냈다');
    expect(drv.lastScore, greaterThan(0.5));
    // 끝까지 — 다시 위기가 오면 또 두드린다.
    for (var i = 0; i < 3000 && finished == null; i++) {
      if (gauge.evaluate().isNotEmpty) {
        await tester.tap(gauge, warnIfMissed: false);
      }
      final throwBtn = find.textContaining('던지기!');
      if (throwBtn.evaluate().isNotEmpty) await tester.tap(throwBtn);
      final skip = find.text('건너뛰기');
      if (skip.evaluate().isNotEmpty) await tester.tap(skip);
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(finished, isNotNull);
    expect(finished!.done, isTrue);
  });
}

/// 던지기 값을 0.6 으로 고정 — 위기 seed 를 미리 찾아 두려고.
class _FixedLaunch implements DuelDriver {
  _FixedLaunch(this._inner);
  final LocalDuelDriver _inner;
  int clutches = 0;
  double lastScore = -1;

  @override
  bool get interactive => true;
  @override
  String? get error => _inner.error;
  @override
  Future<DuelStep?> next(double launch) => _inner.next(0.6);
  @override
  Future<DuelStep?> clutch(int index, double score) {
    clutches++;
    lastScore = score;
    return _inner.clutch(index, score);
  }
}
