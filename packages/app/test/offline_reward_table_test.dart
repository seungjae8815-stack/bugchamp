import 'package:app/features/play/offline_reward_table.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// 복귀 팝업 두 칸 표(2026-10-15 사장님) — 버프 없이 / 버프 있을 때.
void main() {
  final l = lookupAppLocalizations(const Locale('ko'));

  Future<void> pump(WidgetTester t, Widget w) => t.pumpWidget(
    MaterialApp(
      locale: const Locale('ko'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SizedBox(width: 320, child: w)),
    ),
  );

  test('버프 비교가 없으면 표 없음(예전 목록)', () {
    expect(
      offlineRewardTable(
        l,
        const OfflineReport(gold: 10, xp: 1, accrued: Duration(minutes: 5)),
      ),
      isNull,
    );
  });

  testWidgets('버프 없던 사람 — 왼쪽 받은 값 · 오른쪽 약 더한 값', (t) async {
    const r = OfflineReport(
      gold: 242,
      xp: 64,
      accrued: Duration(hours: 2),
      materials: {MaterialKind.chitin: 5},
      buffMissed: OfflineGain(
        gold: 169,
        xp: 45,
        materials: 5,
        fairyStones: 1,
        potions: 0.3,
      ),
    );
    await pump(t, offlineRewardTable(l, r)!);
    expect(find.text(l.offlineColNoBuffGot), findsOneWidget);
    expect(find.text(l.offlineColBuffWould), findsOneWidget);
    expect(find.text('+242'), findsOneWidget);
    expect(find.text(l.offlineApprox('+411')), findsOneWidget);
    expect(find.text(l.offlineApprox('+10')), findsOneWidget);
    // 희귀 드롭의 버프 없이 칸은 ✕ 버프 켤 때만, 1 보다 작은 기대값은 소수 한 자리.
    expect(find.text('✕ ${l.offlineRareBuffOnly}'), findsNWidgets(3));
    expect(find.text(l.offlineRareNote(8)), findsOneWidget);
    // 받지 못한 속성석도 줄이 생긴다(왼쪽 0).
    expect(find.text(l.offlineRowFairyStone), findsOneWidget);
    // 희귀 드롭 = 방치 하루(8시간) 예상 — 2시간에 속성석 1 · 물약 0.3 → 4.0 · 1.2.
    expect(find.text(l.offlineRareDaily('4.0')), findsOneWidget);
    expect(find.text(l.offlineRareDaily('1.2')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('버프 켠 사람 — 오른쪽 받은 값 · 왼쪽 뺀 값(골드는 정확)', (t) async {
    const r = OfflineReport(
      gold: 411,
      xp: 109,
      accrued: Duration(hours: 2),
      buffBonus: OfflineGain(gold: 169, xp: 45),
    );
    await pump(t, offlineRewardTable(l, r)!);
    expect(find.text(l.offlineColNoBuffWould), findsOneWidget);
    expect(find.text(l.offlineColBuffGot), findsOneWidget);
    expect(find.text('+411'), findsOneWidget);
    expect(find.text('+242'), findsOneWidget);
    // 희귀 드롭은 0 이어도 줄이 남는다(버프 없으면 0 이 보여야 한다).
    expect(find.text(l.offlineRowFairyStone), findsOneWidget);
    expect(find.text(l.offlineRowDuelStone), findsOneWidget);
    expect(find.text(l.offlineRowPotion), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
