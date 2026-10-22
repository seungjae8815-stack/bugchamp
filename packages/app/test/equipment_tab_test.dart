import 'dart:convert';
import 'dart:io';

import 'package:app/data/game_data.dart';
import 'package:app/data/save_repository.dart';
import 'package:app/domain/providers.dart';
import 'package:app/domain/save_controller.dart';
import 'package:app/features/character/equipment_tab.dart';
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
  skillConfig: _read('skills.json'),
);

void main() {
  final t0 = DateTime.utc(2026, 8, 9, 12);

  Future<void> pumpTab(WidgetTester tester, Size size, double scale) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = ProviderContainer(
      overrides: [
        gameDataProvider.overrideWith((ref) => _data()),
        saveRepositoryProvider.overrideWithValue(
          _Repo(SaveGame.initial(createdAt: t0).copyWith(lastSeen: t0)),
        ),
        clockProvider.overrideWithValue(FixedClock(t0)),
      ],
    );
    addTearDown(c.dispose);
    await c.read(saveControllerProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          locale: const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (ctx, child) => MediaQuery(
            data: MediaQuery.of(
              ctx,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const EquipmentTab(),
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('작은 폰(360x640) · 큰 글씨 1.3 — 넘치지 않고 장비 칸이 150 이상(스크롤)', (
    tester,
  ) async {
    await pumpTab(tester, const Size(360, 640), 1.3);
    expect(tester.takeException(), isNull);
    final h = tester.getSize(find.byKey(const Key('equipGrid'))).height;
    expect(h, greaterThanOrEqualTo(150));
  });

  testWidgets('넉넉한 폰(412x915) — 스크롤 없이 한 화면', (tester) async {
    await pumpTab(tester, const Size(412, 915), 1.0);
    expect(tester.takeException(), isNull);
    final scroll = tester.widget<SingleChildScrollView>(
      find
          .descendant(
            of: find.byType(EquipmentTab),
            matching: find.byType(SingleChildScrollView),
          )
          .first,
    );
    expect(scroll.physics, isA<NeverScrollableScrollPhysics>());
  });
}
