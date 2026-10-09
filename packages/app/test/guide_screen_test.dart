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
    // 오행은 처음부터 펼쳐져 있다 — 상극 배율(battle.json duel.restrainMult 1.2, 2026-10-09 1.3 → 1.2).
    expect(find.textContaining('1.2배'), findsOneWidget);

    // 펼친 뒤 그 항목의 내용이 보이는지 — 목록은 화면 밖을 그리지 않으므로 하나씩 확인한다.
    // 훈련은 v2(포인트·칸) 기준 — 칸 상한 보정은 battle.json training.slotTemperamentMods(옛 v1 의 3배).
    final opened = <String>{};
    for (final (title, inside) in [
      ('기질 (싸움 성향)', '훈련 칸 상한: 공격 +9 · 방어 -6 · 치명 +3'),
      ('포텐셜 (1~5성)', '별 1개당 6점'),
      ('혈통 특성 (짝짓기 전용)', '맹렬'),
      ('이색 개체', '1/300'),
      ('훈련소', '돌파 단계마다 6/10/16/24점'),
      ('훈련소', '공격 — +5% · 상한 30'),
      ('훈련소', '밀어내기 힘 — 미는 힘 +2.5% · 상한 20'),
      ('훈련소', '근성 — 탭 반격 문턱 −0.009 · 깨우기 체력 +0.5% · 탭 힘 +5% · 상한 10'),
      ('훈련소', '추천 배분'),
      ('훈련소', '30분 + 포인트당 3분(최대 8시간)'),
      ('탭 반격 (근성)', '문턱 0.55'),
    ]) {
      // 같은 항목을 두 번 누르면 접힌다 — 이미 펼쳐 둔 항목은 다시 누르지 않는다.
      if (opened.add(title)) {
        final f = find.text(title);
        await tester.scrollUntilVisible(f, 120);
        // 끝에 걸쳐 멈추면 탭이 화면 밖을 누른다 — 한 번 더 화면 안으로 끌어온다.
        await tester.ensureVisible(f);
        await tester.pumpAndSettle();
        await tester.tap(f);
        await tester.pumpAndSettle();
      }
      await tester.scrollUntilVisible(find.textContaining(inside), 120);
    }
    expect(tester.takeException(), isNull);
  });
}
