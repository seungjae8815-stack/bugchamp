import 'dart:convert';
import 'dart:io';

import 'package:app/data/game_data.dart';
import 'package:app/data/save_repository.dart';
import 'package:app/domain/providers.dart';
import 'package:app/domain/research_view.dart';
import 'package:app/domain/save_controller.dart';
import 'package:app/features/research/research_screen.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:core_models/core_models.dart';
import 'package:core_save/core_save.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repo implements SaveRepository {
  @override
  SaveLoadFailure? get lastFailure => null;

  _Repo(this._g);
  SaveGame _g;
  @override
  Future<SaveGame> load() async => _g;
  @override
  Future<void> save(SaveGame g) async => _g = g;
  @override
  Future<void> clear() async =>
      _g = SaveGame.initial(createdAt: DateTime.utc(2026));
}

Map<String, dynamic> _read(String f) =>
    jsonDecode(File('assets/data/$f').readAsStringSync())
        as Map<String, dynamic>;

GameData _data() => GameData.fromDecoded(
  species: _read('species.json'),
  traps: _read('traps.json'),
  fields: _read('fields.json'),
  spawns: _read('spawns.json'),
  runConfig: _read('run_config.json'),
  petConfig: _read('pets.json'),
  itemConfig: _read('items.json'),
  forgeConfig: _read('forge.json'),
  battleConfig: _read('battle.json'),
  researchConfig: _read('research.json'),
);

/// 연구소 화면(설계 §3) — 칸 1~3 · 시작 · 재화 부족 사유.
void main() {
  final t0 = DateTime.utc(2026, 10, 23, 3);

  SaveGame rich(SaveGame s) => s.copyWith(
    gold: 1000000000000,
    researchSamples: 100000,
    materials: {
      MaterialKind.chitin: 1000000000,
      MaterialKind.mineral: 1000000000,
      MaterialKind.sap: 1000000000,
      MaterialKind.fossil: 1000000,
    },
  );

  Future<ProviderContainer> pump(
    WidgetTester tester,
    SaveGame save, {
    Size size = const Size(412, 915),
    double scale = 1,
    String locale = 'ko',
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = ProviderContainer(
      overrides: [
        gameDataProvider.overrideWith((ref) => _data()),
        saveRepositoryProvider.overrideWithValue(_Repo(save)),
        clockProvider.overrideWithValue(FixedClock(t0)),
      ],
    );
    addTearDown(c.dispose);
    await c.read(saveControllerProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (ctx, child) => MediaQuery(
            data: MediaQuery.of(
              ctx,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const ResearchScreen(),
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    return c;
  }

  final base = SaveGame.initial(createdAt: t0).copyWith(lastSeen: t0);

  testWidgets('빈 세이브 — 칸 1 비어 있음 · 2·3 은 어려움·극한에서 열림', (tester) async {
    await pump(tester, base);
    expect(tester.takeException(), isNull);
    expect(find.text('비어 있음'), findsOneWidget);
    expect(find.text('어려움에서 열림'), findsOneWidget);
    expect(find.text('극한에서 열림'), findsOneWidget);
  });

  testWidgets('재화가 없으면 시작 버튼이 꺼지고 이유가 보인다', (tester) async {
    await pump(tester, base);
    final btn = tester.widget<FilledButton>(
      find.byKey(const Key('researchStart_jaw')),
    );
    expect(btn.onPressed, isNull);
    expect(find.text('재화가 부족해요'), findsWidgets);
  });

  testWidgets('연구를 누르면 칸에 진행이 뜨고 재화가 빠진다', (tester) async {
    final c = await pump(tester, rich(base));
    await tester.tap(find.byKey(const Key('researchStart_jaw')));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final s = c.read(saveControllerProvider).requireValue;
    expect(s.researchSlots.map((r) => r.id), ['jaw']);
    expect(s.researchSamples, lessThan(100000));
    expect(find.byKey(const Key('researchSlotBar_jaw')), findsOneWidget);
    expect(find.text('비어 있음'), findsNothing);
    // 칸이 다 찼으니 다른 연구는 시작할 수 없다.
    final other = tester.widget<FilledButton>(
      find.byKey(const Key('researchStart_incubator')),
    );
    expect(other.onPressed, isNull);
  });

  testWidgets('끝난 연구는 로드할 때 자동으로 반영된다', (tester) async {
    final c = await pump(
      tester,
      base.copyWith(
        researchSlots: [ResearchSlot(id: 'jaw', level: 1, endsAt: t0)],
      ),
    );
    final s = c.read(saveControllerProvider).requireValue;
    expect(s.researchLevels['jaw'], 1);
    expect(s.researchSlots, isEmpty);
  });

  for (final loc in ['ko', 'en', 'ja']) {
    testWidgets('작은 폰(320x568) · 큰 글씨 1.3 · $loc — 진행 중 칸까지 넘치지 않는다', (
      tester,
    ) async {
      await pump(
        tester,
        rich(base).copyWith(
          researchSlots: [
            ResearchSlot(
              id: 'jaw',
              level: 1,
              endsAt: t0.add(const Duration(hours: 30)),
            ),
          ],
        ),
        size: const Size(320, 568),
        scale: 1.3,
        locale: loc,
      );
      expect(tester.takeException(), isNull);
    });
  }

  test('가격은 가 본 최고 사냥터 기준 — 지금 스테이지를 낮추거나 아래 난이도로 내려가도 골드가 같다', () {
    final data = _data();
    final run = data.runConfig!;
    final top = rich(base).copyWith(
      maxTierReached: 1,
      difficultyTier: 1,
      bestStage: run.zoneStartStage(5) + 30,
      stageNumber: run.zoneStartStage(5),
    );
    int gold(SaveGame s) => researchPriceOf(s, data, 'jaw', t0)!.gold;
    final g = gold(top);
    expect(g, greaterThan(0));
    expect(gold(top.copyWith(stageNumber: 1)), g);
    expect(gold(top.copyWith(difficultyTier: 0, stageNumber: 1)), g);
    // 더 높은 사냥터를 가 봤으면 비싸진다(기준이 실제로 최고 기록을 따른다).
    expect(
      gold(top.copyWith(bestStage: run.zoneStartStage(8))),
      greaterThan(g),
    );
  });

  testWidgets('어려움(2칸) — 구매 버튼은 3번째 칸 하나뿐이고 값은 3번째 칸 값', (tester) async {
    await pump(tester, base.copyWith(maxTierReached: 2, difficultyTier: 2));
    expect(find.byKey(const Key('researchBuySlot')), findsOneWidget);
    final cfg = _data().researchConfig!;
    expect(
      find.descendant(
        of: find.byKey(const Key('researchBuySlot')),
        matching: find.textContaining('${cfg.slotJelly[1]}'),
      ),
      findsOneWidget,
    );
  });
}
