import 'dart:convert';
import 'dart:io';

import 'package:app/data/game_data.dart';
import 'package:app/domain/providers.dart';
import 'package:app/ui/skin_badges.dart';
import 'package:core_run/core_run.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 스킨 뱃지(2026-10-08) — 산 곤충 스킨을 이름 옆에 보이는 표식.
void main() {
  final iapJson =
      jsonDecode(File('assets/data/iap.json').readAsStringSync())
          as Map<String, dynamic>;
  final cfg = IapConfig.fromJson(iapJson);

  Map<String, dynamic> name(String s) => {'ko': s, 'en': s, 'ja': s};
  GameData data() => GameData.fromDecoded(
    species: {'species': <dynamic>[]},
    traps: {
      'traps': [
        {'id': 'sap_trap', 'name': name('S')},
      ],
    },
    fields: {
      'fields': [
        {'id': 'oak_forest', 'name': name('O'), 'unlockOrder': 0},
      ],
    },
    spawns: {
      'schemaVersion': 1,
      'defaultPotentialWeights': [
        {'potential': 1, 'weight': 1},
      ],
      'spawns': <dynamic>[],
    },
    iapConfig: iapJson,
  );

  test('publicSkins — 곤충 스킨만, iap.json 순서대로(아레나 테마 제외)', () {
    expect(publicSkins(cfg, {'arena_theme', 'albino_stag', 'gold_rhino'}), [
      'gold_rhino',
      'albino_stag',
    ]);
    expect(publicSkins(cfg, {'arena_theme'}), isEmpty);
    expect(publicSkins(null, {'gold_rhino'}), isEmpty);
  });

  test('skinsFromJson — 없거나 모양이 틀리면(구서버) 빈 목록', () {
    expect(skinsFromJson(null), isEmpty);
    expect(skinsFromJson('gold_rhino'), isEmpty);
    expect(skinsFromJson(['gold_rhino']), ['gold_rhino']);
  });

  test('skinDisplayName — 상점 상품 이름을 locale 로', () {
    expect(skinDisplayName(cfg, 'gold_rhino', 'ko'), isNotEmpty);
    expect(skinDisplayName(cfg, 'unknown', 'ko'), isNull);
  });

  Future<void> pump(WidgetTester tester, List<String> skins) =>
      tester.pumpWidget(
        ProviderScope(
          overrides: [gameDataProvider.overrideWith((ref) => data())],
          child: MaterialApp(
            home: Scaffold(body: Center(child: skinBadges(skins))),
          ),
        ),
      );

  testWidgets('스킨마다 뱃지 하나 · 길게 누르면 스킨 이름', (tester) async {
    await pump(tester, ['gold_rhino', 'albino_stag']);
    await tester.pumpAndSettle();
    expect(find.byType(Tooltip), findsNWidgets(2));
    final en = skinDisplayName(cfg, 'gold_rhino', 'en')!;
    final tip = tester.widget<Tooltip>(find.byType(Tooltip).first);
    expect(tip.message, en); // 테스트 locale 은 en
  });

  testWidgets('빈 목록이면 아무것도 그리지 않는다', (tester) async {
    await pump(tester, const []);
    expect(find.byType(SkinBadges), findsNothing);
    expect(find.byType(Tooltip), findsNothing);
  });
}
