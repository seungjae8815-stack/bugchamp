import 'package:app/features/battle/duel_arena_screen.dart';
import 'package:app/features/battle/duel_driver.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';

DuelBug _bug(String id, Specialty s, double scale) => DuelBug(
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

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('ko'),
  home: Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => child)),
          child: const Text('go'),
        ),
      ),
    ),
  ),
);

void main() {
  const p = DuelParams();
  final mine = [for (var i = 0; i < 3; i++) _bug('a$i', Specialty.grip, 2)];
  final foe = [for (var i = 0; i < 3; i++) _bug('b$i', Specialty.strike, 1)];

  testWidgets('빠른 결투 — 판을 끝까지 재생하고 결과 팝업을 띄운 뒤 닫힌다', (tester) async {
    final match = simulateDuel(seed: 3, teamA: mine, teamB: foe, params: p);
    DuelStep? finished;
    await tester.pumpWidget(
      _wrap(
        DuelArenaScreen(
          mine: mine,
          foe: foe,
          driver: PrebakedDuelDriver(
            bouts: match.bouts,
            gold: 1234,
            trophyDelta: 12,
          ),
          params: p,
          arena: Element.wood,
          onFinished: (s) async => finished = s,
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    // 판마다 떨어지기 + 재생(최대 30초) + 판 결과 — 넉넉히 흘린다.
    for (var i = 0; i < 1200 && finished == null; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(finished, isNotNull);
    expect(finished!.done, isTrue);
    expect(finished!.winsA + finished!.winsB, match.bouts.length);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('${match.winsA} : ${match.winsB}'), findsWidgets);
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(find.byType(DuelArenaScreen), findsNothing);
  });

  testWidgets('직접 던지기 — 게이지 버튼으로 판을 던지고 건너뛰기로 넘긴다', (tester) async {
    DuelStep? finished;
    await tester.pumpWidget(
      _wrap(
        DuelArenaScreen(
          mine: mine,
          foe: foe,
          driver: LocalDuelDriver(
            seed: 9,
            mine: mine,
            foe: foe,
            params: p,
            battle: const BattleConfig(),
            trophies: 100,
            rewardMult: 1,
          ),
          params: p,
          arena: Element.fire,
          onFinished: (s) async => finished = s,
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    // 화면은 0.25초가 넘는 틈을 건너뛴다(앱이 멈췄다 돌아온 경우) — 0.1초씩 흘린다.
    var throws = 0;
    for (var i = 0; i < 1500 && finished == null; i++) {
      final throwBtn = find.textContaining('던지기!');
      if (throwBtn.evaluate().isNotEmpty) {
        await tester.tap(throwBtn);
        throws++;
      }
      final skip = find.text('건너뛰기');
      if (skip.evaluate().isNotEmpty) await tester.tap(skip);
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(throws, inInclusiveRange(3, 5), reason: '승자 연속 — 3~5판');
    expect(finished, isNotNull);
    expect(finished!.done, isTrue);
  });
}
