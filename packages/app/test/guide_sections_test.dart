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

/// 사냥 쪽 공략 항목(2026-10-19 — 희귀도·성장물약·사냥터·버프·스킬·도감·채집함·요정)을 실데이터로 그린다.
/// 숫자는 JSON 에서 읽으므로 데이터가 바뀌면 여기서 깨진다 — 그때는 문구가 맞는지 보고 기대값을 고친다.
GameData _data() => GameData.fromDecoded(
  species: _read('species.json'),
  traps: _read('traps.json'),
  fields: _read('fields.json'),
  spawns: _read('spawns.json'),
  runConfig: _read('run_config.json'),
  buffConfig: _read('buffs.json'),
  skillConfig: _read('skills.json'),
  fairyConfig: _read('fairies.json'),
  petConfig: _read('pets.json'),
  dexConfig: _read('dex.json'),
  battleConfig: _read('battle.json'),
);

Future<AppLocalizations> _pump(WidgetTester tester, String lang) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [gameDataProvider.overrideWith((ref) => _data())],
      child: MaterialApp(
        locale: Locale(lang),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const GuideScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return AppLocalizations.of(tester.element(find.byType(GuideScreen)));
}

Future<void> _open(WidgetTester tester, String title) async {
  final f = find.text(title);
  await tester.scrollUntilVisible(f, 120);
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('사냥 쪽 공략 항목 — 펼치면 데이터 숫자가 들어간 문장이 보인다(ko)', (tester) async {
    await _pump(tester, 'ko');
    final opened = <String>{};
    for (final (title, inside) in [
      ('개체 등급 (일반~전설)', '정수: 3 · 12 · 64 · 400'),
      ('개체 등급 (일반~전설)', '젤리 10개로 하루 10개까지'),
      ('곤충 희귀도 (일반~전설)', '일반 52% · 고급 28% · 희귀 14% · 영웅 5% · 전설 1%'),
      ('곤충 희귀도 (일반~전설)', '전설 +15.2%'),
      ('곤충 희귀도 (일반~전설)', '곤충 3마리를 재료로'),
      ('사냥터 · 보스 · 난이도 · 심연', '사냥터 10개와 최종 보스'),
      ('사냥터 · 보스 · 난이도 · 심연', '몬스터 100마리를 잡으면'),
      ('사냥터 · 보스 · 난이도 · 심연', '최대 8시간까지'),
      ('사냥터 · 보스 · 난이도 · 심연', '1위 100개'),
      ('버프', '황금 러시 — 골드 획득 ×2'),
      ('버프', '30분씩 늘어나고 최대 6시간까지'),
      ('버프', '4시간 뒤에 다시 무료로'),
      ('캐릭터 스킬', '스킬은 12가지'),
      ('캐릭터 스킬', '처음 2칸'),
      ('캐릭터 스킬', '하루 3번 무료'),
      ('곤충 도감', '수련 10레벨까지'),
      ('곤충 도감', '모두 44마리'),
      ('채집함 관리', '기본 50칸'),
      ('채집함 관리', '최대 100칸'),
      ('요정', '30m ~ 16h'),
      ('요정', '15회 안에 전설 이상'),
      ('요정', '영웅 → 전설만 4마리'),
      ('요정', '10/20/30/40/50'),
      ('요정', '기본 30칸'),
    ]) {
      if (opened.add(title)) await _open(tester, title);
      await tester.scrollUntilVisible(find.textContaining(inside), 120);
    }
    expect(tester.takeException(), isNull);
  });

  // 영어·일본어 — 자리표시를 빠뜨리면(`{x}` 가 그대로) 여기서 걸린다.
  for (final lang in const ['en', 'ja']) {
    testWidgets('사냥 쪽 공략 항목 — 자리표시가 남지 않는다($lang)', (tester) async {
      final l = await _pump(tester, lang);
      for (final title in [
        l.guidePotentialTitleGrade,
        l.guideRarityTitle,
        l.guideZoneTitle,
        l.guideBuffTitle,
        l.guideSkillTitle,
        l.guideDexTitle,
        l.guideStorageTitle,
        l.guideFairyTitle,
      ]) {
        await _open(tester, title);
      }
      expect(find.textContaining(RegExp(r'\{[a-zA-Z]+\}')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
