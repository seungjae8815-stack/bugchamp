import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:app/data/game_data.dart';
import 'package:app/data/save_repository.dart';
import 'package:app/domain/providers.dart';
import 'package:app/domain/save_controller.dart';
import 'package:app/features/character/fairy_panel.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:core_models/core_models.dart';
import 'package:core_save/core_save.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
  Future<void> clear() async =>
      _g = SaveGame.initial(createdAt: DateTime.utc(2026));
}

Map<String, dynamic> _read(String f) =>
    jsonDecode(File('assets/data/$f').readAsStringSync())
        as Map<String, dynamic>;

/// 실제 게임 데이터로 돈다 — fairies.json 을 고치면 여기서 먼저 깨진다.
GameData _data() => GameData.fromDecoded(
  species: _read('species.json'),
  traps: _read('traps.json'),
  fields: _read('fields.json'),
  spawns: _read('spawns.json'),
  runConfig: _read('run_config.json'),
  petConfig: _read('pets.json'),
  fairyConfig: _read('fairies.json'),
);

final _t0 = DateTime.utc(2026, 10, 1, 12);

SaveGame _seed({int jelly = 1000, FairyState fairy = FairyState.empty}) =>
    SaveGame.initial(
      createdAt: _t0,
    ).copyWith(materials: {MaterialKind.jelly: jelly}, fairy: fairy);

ProviderContainer _make(SaveGame seed, {DateTime? now}) {
  final c = ProviderContainer(
    overrides: [
      gameDataProvider.overrideWith((ref) => _data()),
      saveRepositoryProvider.overrideWithValue(_Repo(seed)),
      clockProvider.overrideWithValue(FixedClock(now ?? _t0)),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('컨트롤러 흐름(젤리 차감 · 저장)', () {
    test('교환소 젤리 → 가루는 하루 상한까지(다음 날 다시 열린다)', () async {
      final c = _make(_seed());
      await c.read(saveControllerProvider.future);
      final ctrl = c.read(saveControllerProvider.notifier);
      final cap = c
          .read(gameDataProvider)
          .requireValue
          .fairyConfig!
          .exchangeDustDailyCap;
      expect(cap, greaterThan(0));
      expect(ctrl.exchangeDustLeftToday(), cap);
      // 한도만큼 바꾼다(묶음 = 젤리 10).
      expect(await ctrl.tradeJellyForDust(trades: cap ~/ 10), isTrue);
      final s = c.read(saveControllerProvider).requireValue;
      expect(s.fairy.dust, cap);
      expect(s.materialCount(MaterialKind.jelly), 1000 - cap);
      expect(ctrl.exchangeDustLeftToday(), 0);
      expect(ctrl.exchangeDust(trades: 1), isNull);
      expect(await ctrl.tradeJellyForDust(trades: 1), isFalse);

      final next = _make(s, now: _t0.add(const Duration(days: 1)));
      await next.read(saveControllerProvider.future);
      expect(
        next.read(saveControllerProvider.notifier).exchangeDustLeftToday(),
        cap,
      );
    });

    test('뽑기 → 둥지 → 가속기 → 꺼내기', () async {
      final c = _make(_seed());
      await c.read(saveControllerProvider.future);
      final ctrl = c.read(saveControllerProvider.notifier);
      final cfg = c.read(gameDataProvider).requireValue.fairyConfig!;

      final draw = await ctrl.fairyDraw(1, rng: Random(1));
      expect(draw.isOk, isTrue);
      var s = c.read(saveControllerProvider).requireValue;
      expect(s.materialCount(MaterialKind.jelly), 1000 - cfg.gachaJelly);
      expect(s.fairy.eggs.length, 1);

      final put = await ctrl.fairyPlaceEgg(
        s.fairy.eggs.single.id,
        rng: Random(2),
      );
      expect(put.isOk, isTrue);
      s = c.read(saveControllerProvider).requireValue;
      expect(s.fairy.nest, isNotNull);

      // 가장 큰 가속기를 사서 쓰면 끝난다(전설 알 16시간보다 짧을 수 있어 반복).
      final big = cfg.accelerators.last;
      while (_t0.isBefore(s.fairy.nest!.endsAt)) {
        final b = await ctrl.fairyBuyAccelerator(big.id);
        expect(b.isOk, isTrue);
        final u = await ctrl.fairyUseAccelerator(big.id);
        expect(u.isOk, isTrue);
        s = c.read(saveControllerProvider).requireValue;
      }
      final got = await ctrl.fairyCollectNest();
      expect(got.extra['fairy'], isA<Fairy>());
      s = c.read(saveControllerProvider).requireValue;
      expect(s.fairy.fairies.length, 1);
      expect(s.fairy.nest, isNull);
    });

    test('보스 첫 처치 = 요정 알 확정 · 다시 잡으면 없음(무료 경로)', () async {
      final seed = _seed().copyWith(
        lastSeen: _t0,
        zoneEpoch: kZoneEpoch,
        difficultyTier: 3,
        maxTierReached: 3,
      );
      final c = _make(seed);
      await c.read(saveControllerProvider.future);
      final ctrl = c.read(saveControllerProvider.notifier);
      final cfg = c.read(gameDataProvider).requireValue.fairyConfig!;
      await ctrl.advanceZone(rng: Random(1));
      var s = c.read(saveControllerProvider).requireValue;
      expect(s.fairy.eggs.single.grade, cfg.drops.bossFirstEggGrade(3));
      expect(ctrl.lastBossFairyEggs, [cfg.drops.bossFirstEggGrade(3)]);

      // 같은 보스를 다시 잡으면(사냥터 1로 되돌려서) 알이 없다.
      await ctrl.adoptServerSave(s.copyWith(stageNumber: 1).toJson());
      await ctrl.advanceZone(rng: Random(2));
      s = c.read(saveControllerProvider).requireValue;
      expect(s.fairy.eggs.length, 1);
      expect(ctrl.lastBossFairyEggs, isEmpty);
    });

    test('젤리가 모자라면 실패하고 아무것도 안 바뀐다', () async {
      final c = _make(_seed(jelly: 0));
      await c.read(saveControllerProvider.future);
      final r = await c.read(saveControllerProvider.notifier).fairyDraw(1);
      expect(r.error, 'not_enough_jelly');
      expect(c.read(saveControllerProvider).requireValue.fairy.eggs, isEmpty);
    });

    test('동행·레벨업·분해', () async {
      final c = _make(
        _seed(
          fairy: const FairyState(
            fairies: [
              Fairy(id: 'f1', kind: 'ignis', grade: FairyGrade.rare, sub: 'hp'),
              Fairy(
                id: 'f2',
                kind: 'undine',
                grade: FairyGrade.common,
                sub: 'attack',
              ),
            ],
            dust: 1000,
            seq: 2,
          ),
        ),
      );
      await c.read(saveControllerProvider.future);
      final ctrl = c.read(saveControllerProvider.notifier);
      expect((await ctrl.fairySetCompanion('f1')).isOk, isTrue);
      expect((await ctrl.fairyLevelUp('f1')).isOk, isTrue);
      expect((await ctrl.fairyRelease('f1')).error, 'companion');
      expect((await ctrl.fairyRelease('f2')).isOk, isTrue);
      final s = c.read(saveControllerProvider).requireValue.fairy;
      expect(s.companion?.level, 2);
      expect(s.fairies.map((x) => x.id), ['f1']);
    });
  });

  group('요정 탭 화면', () {
    Future<void> pump(WidgetTester tester, SaveGame seed) async {
      // 폰 크기(360×740) — 넓은 기본 창에선 안 보이는 넘침을 잡는다.
      tester.view.physicalSize = const Size(1080, 2220);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final c = _make(seed);
      await tester.runAsync(() => c.read(saveControllerProvider.future));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: const MaterialApp(
            locale: Locale('ko'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: FairyPanel()),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('빈 요정함', (tester) async {
      await pump(tester, _seed());
      expect(find.text('요정함 0/30'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('빈 둥지 — 알·속성석을 골라 넣는다', (tester) async {
      await pump(
        tester,
        _seed(
          fairy: const FairyState(
            eggs: [
              FairyEgg(id: 'e1', grade: FairyGrade.rare),
              FairyEgg(id: 'e2', grade: FairyGrade.legendary),
            ],
            stones: {'bossDamage': 1},
            seq: 2,
          ),
        ),
      );
      // 위 버튼은 짧은 문구(2026-10-09 — 긴 이름을 줄여 맞추면 6~8px 였다).
      await tester.tap(find.text('둥지').first);
      await tester.pumpAndSettle(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      // 속성석은 한 줄에 하나(이름 + 효과) — 목록을 끌어 내려 고른다.
      final stone = find.text('보스 피해 속성석');
      await tester.dragUntilVisible(
        stone,
        find.byType(ListView).last,
        const Offset(0, -60),
      );
      await tester.pumpAndSettle();
      await tester.tap(stone);
      await tester.pump();
      expect(find.text('×1'), findsOneWidget);
      await tester.tap(find.text('둥지에 넣기'));
      await tester.pumpAndSettle(const Duration(milliseconds: 300));
      expect(find.textContaining('남음'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('요정·알·둥지가 있어도 그려지고 팝업이 열린다', (tester) async {
      final fairy = FairyState(
        fairies: [
          for (final (i, k) in ['ignis', 'undine', 'asteria'].indexed)
            Fairy(
              id: 'f$i',
              kind: k,
              grade: FairyGrade.values[i + 2],
              sub: 'bossDamage',
              baseRoll: 800,
              subRoll: 300,
              level: 3,
            ),
        ],
        eggs: const [FairyEgg(id: 'e1', grade: FairyGrade.epic)],
        nest: FairyNest(
          eggId: 'e9',
          grade: FairyGrade.rare,
          kind: 'voltea',
          sub: 'hp',
          baseRoll: 1,
          subRoll: 1,
          endsAt: _t0.add(const Duration(hours: 1)),
        ),
        companionId: 'f0',
        dust: 500,
        dex: const {'ignis:epic', 'ignis+bossDamage'},
        seq: 10,
      );
      await pump(tester, _seed(fairy: fairy));
      expect(find.text('이그니스'), findsWidgets);
      expect(tester.takeException(), isNull);

      // 둥지
      // 위 버튼은 짧은 문구(2026-10-09 — 긴 이름을 줄여 맞추면 6~8px 였다).
      await tester.tap(find.text('둥지').first);
      await tester.pumpAndSettle(const Duration(milliseconds: 300));
      expect(find.textContaining('남음'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('닫기').last);
      await tester.pumpAndSettle(const Duration(milliseconds: 300));

      // 요정 상세 → 합성(재료 없음)
      // 칸 위쪽 = "등급 · Lv.N".
      await tester.tap(find.text('영웅 · Lv.3').last); // 동행 중인 f0(에픽) 칸
      await tester.pumpAndSettle(const Duration(milliseconds: 300));
      expect(find.text('동행 해제'), findsOneWidget);
      // 동행 요정은 합성 창 대신 이유를 알린다.
      await tester.tap(find.text('합성').last);
      await tester.pump();
      expect(find.text('착용 중인 요정은 합성할 수 없어요'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('닫기').last);
      await tester.pumpAndSettle(const Duration(milliseconds: 300));

      // 뽑기 · 도감
      for (final title in ['뽑기', '도감']) {
        await tester.tap(find.text(title).first);
        await tester.pumpAndSettle(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull, reason: title);
        await tester.tap(find.text('닫기').last);
        await tester.pumpAndSettle(const Duration(milliseconds: 300));
      }
    });
  });
}
