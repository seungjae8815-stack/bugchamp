import 'dart:convert';
import 'dart:io';

import 'package:app/data/game_data.dart';
import 'package:app/domain/providers.dart';
import 'package:app/features/guide/guide_screen.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _read(String f) =>
    jsonDecode(File('assets/data/$f').readAsStringSync())
        as Map<String, dynamic>;

/// 실제 게임 데이터로 공략집을 그린다 — 숫자를 JSON 에서 읽으므로 데이터가 바뀌어도 여기서 깨진다.
GameData _data() => GameData.fromDecoded(
  species: _read('species.json'),
  traps: _read('traps.json'),
  fields: _read('fields.json'),
  spawns: _read('spawns.json'),
  runConfig: _read('run_config.json'),
  petConfig: _read('pets.json'),
  battleConfig: _read('battle.json'),
);

void main() {
  testWidgets('공략집 — 모든 항목을 펼쳐도 깨지지 않고 숫자는 데이터에서 온다', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [gameDataProvider.overrideWith((ref) => _data())],
        child: const MaterialApp(
          locale: Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: GuideScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // 오행은 처음부터 펼쳐져 있다 — 상극 배율(battle.json duel.restrainMult 1.3).
    expect(find.textContaining('1.3배'), findsOneWidget);

    // 펼친 뒤 그 항목의 내용이 보이는지 — 목록은 화면 밖을 그리지 않으므로 하나씩 확인한다.
    for (final (title, inside) in [
      ('기질 (싸움 성향)', '훈련 상한: 공격 +3 · 방어 -2 · 치명 +1'),
      ('혈통 특성 (짝짓기 전용)', '맹렬'),
      ('이색 개체', '1/300'),
    ]) {
      final f = find.text(title);
      await tester.scrollUntilVisible(f, 120);
      await tester.tap(f);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.textContaining(inside), 120);
    }
    expect(tester.takeException(), isNull);
  });
}
