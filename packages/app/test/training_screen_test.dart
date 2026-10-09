import 'dart:convert';
import 'dart:io';

import 'package:app/data/game_data.dart';
import 'package:app/data/save_repository.dart';
import 'package:app/domain/providers.dart';
import 'package:app/domain/save_controller.dart';
import 'package:app/features/battle/training_screen.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:core_models/core_models.dart';
import 'package:core_save/core_save.dart';
import 'package:flutter/material.dart' hide Element;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 훈련 v2 화면(훈련소) — 포인트 표시 · [+] 찍기 · 다시 찍기 · 결투석.
class _Repo implements SaveRepository {
  _Repo(this._g);
  SaveGame _g;
  @override
  SaveLoadFailure? get lastFailure => null;
  @override
  Future<SaveGame> load() async => _g;
  @override
  Future<void> save(SaveGame g) async => _g = g;
  @override
  Future<void> clear() async {}
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
  enhanceConfig: _read('enhance.json'),
  battleConfig: _read('battle.json'),
);

const _bug = IndividualBug(
  id: 'b1',
  speciesId: 'stag_dorcus',
  sizeMm: 40,
  potential: 3, // 예산 18
  temperament: Temperament.aggressive,
  sex: Sex.male,
  element: Element.wood,
);

SaveGame _seed({BugTrain? train, Map<DuelStone, int> stones = const {}}) =>
    SaveGame.initial(createdAt: DateTime.utc(2026, 10)).copyWith(
      bugs: const [_bug],
      materials: {
        MaterialKind.chitin: 1000000,
        MaterialKind.mineral: 1000000,
        MaterialKind.sap: 1000000,
      },
      trainPoints: train == null ? null : {'b1': train},
      duelStones: stones,
    );

Future<ProviderContainer> _pump(WidgetTester tester, SaveGame seed) async {
  tester.view.physicalSize = const Size(400, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      gameDataProvider.overrideWith((ref) => _data()),
      saveRepositoryProvider.overrideWithValue(_Repo(seed)),
    ],
  );
  addTearDown(container.dispose);
  await tester.runAsync(() => container.read(saveControllerProvider.future));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        locale: Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TrainingScreen(initialBugId: 'b1'),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

String _value(WidgetTester tester, TrainSlot sl) => tester
    .widget<Text>(find.byKey(ValueKey('trainSlot:${sl.key}:value')))
    .data!;

Future<void> _tap(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

/// 토스트·소리 타이머가 남지 않게 흘려보낸다.
Future<void> _drain(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('포인트 표시 · [+] 는 재료를 내고 훈련소 1칸을 쓴다', (tester) async {
    final c = await _pump(tester, _seed());
    expect(find.text('포인트 0 / 18'), findsOneWidget);
    expect(find.text('남은 포인트 18'), findsOneWidget);
    // 칸 10종이 다 보인다.
    for (final sl in TrainSlot.values) {
      expect(find.byKey(ValueKey('trainSlot:${sl.key}:plus')), findsOneWidget);
    }
    // 주특기 기술은 이 곤충 주특기(집기) 설명.
    expect(find.textContaining('집기: 무는 힘'), findsOneWidget);
    // 근성은 탭 반격 설명.
    expect(find.textContaining('탭 반격'), findsOneWidget);
    // 결투석 보유 수.
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('duelStone:element:count')))
          .data,
      '0개',
    );

    final before = c
        .read(saveControllerProvider)
        .requireValue
        .materialCount(MaterialKind.chitin);
    await _tap(tester, const ValueKey('trainSlot:attack:plus'));
    final s = c.read(saveControllerProvider).requireValue;
    expect(s.trainPointJob?.slot, TrainSlot.attack);
    expect(s.materialCount(MaterialKind.chitin), lessThan(before));
    expect(find.text('공격 +1 찍는 중'), findsOneWidget);
    // 찍는 중이라 출전 불가 안내.
    expect(find.textContaining('결투·대회에 나갈 수 없어요'), findsOneWidget);
    // 진행 중인 포인트도 사용으로 센다.
    expect(find.text('포인트 1 / 18'), findsOneWidget);

    // 훈련소가 차 있으면 다른 칸은 시작하지 않는다.
    await _tap(tester, const ValueKey('trainSlot:defense:plus'));
    expect(
      c.read(saveControllerProvider).requireValue.trainPointJob?.slot,
      TrainSlot.attack,
    );
    expect(tester.takeException(), isNull);
    await _drain(tester);
  });

  testWidgets('재료를 낸 포인트가 남아 있으면 [+] 는 바로 무료로 찍힌다', (tester) async {
    final c = await _pump(
      tester,
      _seed(train: const BugTrain(alloc: {TrainSlot.attack: 2}, paid: 4)),
    );
    expect(find.text('포인트 2 / 18'), findsOneWidget);
    expect(find.textContaining('재료를 이미 낸 포인트 2개'), findsOneWidget);
    await _tap(tester, const ValueKey('trainSlot:defense:plus'));
    final s = c.read(saveControllerProvider).requireValue;
    expect(s.trainPointJob, isNull);
    expect(s.trainPoints['b1']!.alloc[TrainSlot.defense], 1);
    expect(find.text('포인트 3 / 18'), findsOneWidget);
    expect(_value(tester, TrainSlot.defense), startsWith('1 /'));
    expect(tester.takeException(), isNull);
    await _drain(tester);
  });

  testWidgets('다시 찍기 — 첫 1회는 대기 없이 · 다음은 대기 · 취소', (tester) async {
    final c = await _pump(
      tester,
      _seed(
        train: const BugTrain(
          alloc: {TrainSlot.attack: 4},
          paid: 4,
          freeRespec: true,
        ),
      ),
    );
    expect(find.text('첫 1회 무료 · 대기 없음'), findsOneWidget);
    await _tap(tester, const ValueKey('trainRespecBtn'));
    expect(find.text('새 배분 — 남은 포인트 0'), findsOneWidget);
    // 남은 포인트가 0 이면 [+] 는 막힌다.
    await _tap(tester, const ValueKey('trainSlot:hp:plus'));
    expect(_value(tester, TrainSlot.hp), startsWith('0 /'));
    await _tap(tester, const ValueKey('trainSlot:attack:minus'));
    await _tap(tester, const ValueKey('trainSlot:attack:minus'));
    expect(find.text('새 배분 — 남은 포인트 2'), findsOneWidget);
    // 편집 미리보기 — 요약 카드 제목이 바뀐다.
    expect(find.text('편집 중 — 바꾸면 이렇게 돼요'), findsOneWidget);
    await _tap(tester, const ValueKey('trainSlot:hp:plus'));
    await _tap(tester, const ValueKey('trainSlot:hp:plus'));
    await _tap(tester, const ValueKey('trainRespecApply'));
    // 확인 팝업.
    expect(find.textContaining('기다림 없이 무료'), findsOneWidget);
    await tester.tap(find.text('이대로 바꾸기').last);
    await tester.pumpAndSettle();
    var rec = c.read(saveControllerProvider).requireValue.trainPoints['b1']!;
    expect(rec.alloc, {TrainSlot.attack: 2, TrainSlot.hp: 2});
    expect(rec.pending, isNull);
    expect(rec.freeRespec, isFalse);
    expect(_value(tester, TrainSlot.hp), startsWith('2 /'));

    // 두 번째는 대기가 생긴다.
    await _tap(tester, const ValueKey('trainRespecBtn'));
    await _tap(tester, const ValueKey('trainSlot:hp:minus'));
    await _tap(tester, const ValueKey('trainSlot:defense:plus'));
    await _tap(tester, const ValueKey('trainRespecApply'));
    expect(find.textContaining('기다려야 하고'), findsOneWidget);
    await tester.tap(find.text('이대로 바꾸기').last);
    await tester.pumpAndSettle();
    rec = c.read(saveControllerProvider).requireValue.trainPoints['b1']!;
    expect(rec.pending, {
      TrainSlot.attack: 2,
      TrainSlot.hp: 1,
      TrainSlot.defense: 1,
    });
    expect(find.byKey(const ValueKey('trainRespecPending')), findsOneWidget);
    expect(find.textContaining('결투·대회에 나갈 수 없어요'), findsOneWidget);

    // 대기 취소 → 배분 그대로.
    await _tap(tester, const ValueKey('trainRespecCancel'));
    await tester.tap(find.text('대기 취소').last);
    await tester.pumpAndSettle();
    rec = c.read(saveControllerProvider).requireValue.trainPoints['b1']!;
    expect(rec.pending, isNull);
    expect(rec.alloc, {TrainSlot.attack: 2, TrainSlot.hp: 2});
    expect(tester.takeException(), isNull);
    await _drain(tester);
  });

  testWidgets('추천 배분 — 다음 추천 칸 · 남는 포인트를 한 번에 채운다', (tester) async {
    final c = await _pump(
      tester,
      _seed(train: const BugTrain(alloc: {TrainSlot.attack: 2}, paid: 6)),
    );
    // 집기 종(사슴벌레)의 기본 추천은 균형(★).
    expect(find.text('균형 ★'), findsOneWidget);
    expect(find.byKey(const ValueKey('trainPresetNext')), findsOneWidget);
    await _tap(tester, const ValueKey('trainPresetFill'));
    final rec = c.read(saveControllerProvider).requireValue.trainPoints['b1']!;
    expect(rec.allocated, 6);
    expect(rec.paid, 6);
    expect(rec.alloc[TrainSlot.attack], greaterThanOrEqualTo(2));
    expect(c.read(saveControllerProvider).requireValue.trainPointJob, isNull);
    // 다 채우면 채우기 버튼은 사라진다.
    expect(find.byKey(const ValueKey('trainPresetFill')), findsNothing);
    expect(tester.takeException(), isNull);
    await _drain(tester);
  });

  testWidgets('추천 배분 — 이 배분으로 다시 찍기 · 편집 중 칩을 누르면 그 배분으로 바뀐다', (tester) async {
    final c = await _pump(
      tester,
      _seed(
        train: const BugTrain(
          alloc: {TrainSlot.grit: 6},
          paid: 6,
          freeRespec: true,
        ),
      ),
    );
    await _tap(tester, const ValueKey('trainPresetRespec'));
    expect(find.text('새 배분 — 남은 포인트 0'), findsOneWidget);
    // 편집 중 체급형을 누르면 편집 배분이 체급형 비율로 바뀐다(체급 · 체력 · 방어 · 공격 · 밀어내기 힘).
    await _tap(tester, const ValueKey('trainPreset:heavy'));
    expect(_value(tester, TrainSlot.grit), startsWith('0 /'));
    await _tap(tester, const ValueKey('trainRespecApply'));
    await tester.tap(find.text('이대로 바꾸기').last);
    await tester.pumpAndSettle();
    final rec = c.read(saveControllerProvider).requireValue.trainPoints['b1']!;
    expect(rec.allocated, 6);
    const heavy = {
      TrainSlot.mass,
      TrainSlot.hp,
      TrainSlot.defense,
      TrainSlot.attack,
      TrainSlot.push,
    };
    expect(
      rec.alloc.keys.every(heavy.contains),
      isTrue,
      reason: '${rec.alloc}',
    );
    expect(tester.takeException(), isNull);
    await _drain(tester);
  });

  testWidgets('결투석 — 오행 고르기 → 확인하면 바뀐다', (tester) async {
    final c = await _pump(tester, _seed(stones: {DuelStone.element: 1}));
    await _tap(tester, const ValueKey('duelStone:element:use'));
    expect(find.text('바꿀 오행을 고르세요'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('stonePick:fire')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('오행 바꾸기').last);
    await tester.pumpAndSettle();
    final s = c.read(saveControllerProvider).requireValue;
    expect(s.bugs.firstWhere((b) => b.id == 'b1').element, Element.fire);
    expect(s.duelStoneCount(DuelStone.element), 0);
    expect(tester.takeException(), isNull);
    await _drain(tester);
  });
}
