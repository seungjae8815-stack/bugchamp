import 'dart:convert';
import 'dart:io';

import 'package:app/data/game_data.dart';
import 'package:app/data/save_repository.dart';
import 'package:app/domain/game_server.dart';
import 'package:app/domain/guild_service.dart';
import 'package:app/domain/providers.dart';
import 'package:app/features/guild/guild_screen.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:app/domain/save_controller.dart';
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
  chatRules: _read('chat.json'),
  guildConfig: _read('guild.json'),
);

Map<String, dynamic> _guild(
  String id,
  String name, {
  String mode = 'open',
  int n = 5,
}) => {
  'id': id,
  'name': name,
  'lang': 'ko',
  'level': 1,
  'maxMembers': 20,
  'joinMode': mode,
  'notice': '매일 접속해요',
  'memberCount': n,
  'avgPower': 1.5e6,
};

/// 서버 흉내 — 길드 없음 → 가입하면 길드원 목록으로 바뀐다.
class _GuildServer implements GameServer {
  final joined = <String>[];

  Map<String, dynamic> get _me => joined.isEmpty
      ? {'guild': null, 'requested': <String>[]}
      : {
          'guild': {
            ..._guild('g1', '장수풍뎅이단', n: 6),
            'level': 3,
            'exp': 40,
            'expNeed': 115,
            'skills': {'attack': 1},
            'pointsLeft': 1,
          },
          'myCoins': coins,
          'donatedToday': donated,
          'shop': [
            {
              'id': 'fossil',
              'kind': 'fossil',
              'amount': 20,
              'cost': 30,
              'limit': 5,
              'period': 'day',
              'bought': bought,
            },
          ],
          'myRole': 'member',
          'members': [
            {
              'userId': 'u1',
              'role': 'leader',
              'nickname': '대장',
              'power': 3.2e6,
              'lastSeen': DateTime.now().toUtc().toIso8601String(),
            },
            {
              'userId': 'me',
              'role': 'member',
              'nickname': '나',
              'power': 1.1e6,
              'lastSeen': DateTime.now().toUtc().toIso8601String(),
            },
          ],
        };

  @override
  bool get available => true;

  @override
  Future<ServerResult> guildMe() async => ServerResult.ok(_me);

  @override
  Future<ServerResult> guildList({
    required String lang,
    String query = '',
  }) async => ServerResult.ok({
    'guilds': [
      _guild('g1', '장수풍뎅이단'),
      _guild('g2', '사슴벌레회', mode: 'approval'),
      _guild('g3', '만원길드', n: 20),
    ],
    'requested': <String>[],
  });

  @override
  Future<ServerResult> guildCreate({
    required String name,
    required String lang,
    required String joinMode,
  }) async {
    joined.add('new');
    return ServerResult.ok({..._me, 'jellySpent': 200});
  }

  // ── 길드전 ──
  var warClaimed = false;

  @override
  Future<ServerResult> guildWar() async => ServerResult.ok({
    'week': '2026-10-05',
    'open': true,
    'startWeek': '2026-10-05',
    'tier': 'silver',
    'gr': 130,
    'day': 7,
    'theme': 'clash',
    'cap': 0,
    'myToday': 0,
    'match': {
      'opponent': '사슴벌레회',
      'virtual': false,
      'mine': [100, 50, 0, 30, 0, 10],
      'theirs': [80, 60, 0, 0, 0, 0],
    },
    'result': {
      'points': 12,
      'theirPoints': 6,
      'won': true,
      'draw': false,
      'clash': 3,
      'theirClash': 2,
      'days': [0, 1, -1, 0, -1, 0],
      'pairs': [
        {'me': '대장', 'them': '적장', 'won': true},
      ],
    },
    'reward': {
      'won': true,
      'eligible': true,
      'coins': 150,
      'jelly': 15,
      'claimed': warClaimed,
    },
  });

  @override
  Future<ServerResult> guildWarClaim() async {
    warClaimed = true;
    final s = SaveGame.fromJson(uploaded!);
    return ServerResult.ok({
      'save': s
          .copyWith(
            materials: {
              ...s.materials,
              MaterialKind.jelly: s.materialCount(MaterialKind.jelly) + 15,
            },
          )
          .toJson(),
      'jelly': 15,
      'coins': 150,
    });
  }

  // ── 보스 ──
  var bossLeft = 2;
  Map<String, dynamic> get _boss => {
    'stage': 2,
    'hpMax': 800,
    'hpLeft': bossLeft == 2 ? 800 : 700,
    'attacksLeft': bossLeft,
    'myDamage': bossLeft == 2 ? 0 : 100,
    'rank': 1,
    'top': [
      {'rank': 1, 'name': '장수풍뎅이단', 'stage': 2, 'progress': 0.125},
    ],
    'hasTeam': true,
    'lastWeek': {'rank': 3, 'jelly': 10, 'claimed': false},
    'endsAt': DateTime.now()
        .toUtc()
        .add(const Duration(days: 3))
        .toIso8601String(),
  };

  @override
  Future<ServerResult> guildBoss() async => ServerResult.ok(_boss);

  @override
  Future<ServerResult> guildBossAttack() async {
    bossLeft--;
    return ServerResult.ok({
      ..._boss,
      'hit': {'damage': 100, 'coins': 15, 'chest': 5, 'killed': 0},
    });
  }

  // ── 3단계 ──
  var coins = 100;
  var donated = false;
  var bought = 0;

  @override
  Future<ServerResult> guildDonate() async {
    donated = true;
    coins += 10;
    return ServerResult.ok(_me);
  }

  @override
  Future<ServerResult> guildShopBuy(String itemId) async {
    coins -= 30;
    bought++;
    final s = SaveGame.fromJson(uploaded!);
    return ServerResult.ok({
      ..._me,
      'save': s
          .copyWith(
            materials: {
              ...s.materials,
              MaterialKind.fossil: s.materialCount(MaterialKind.fossil) + 20,
            },
          )
          .toJson(),
      'granted': {'fossil': 20},
    });
  }

  // ── 미션 ──
  final helped = <String>[];
  var claimed = false;
  Map<String, dynamic>? uploaded;

  Map<String, dynamic> get _missions => {
    'now': DateTime.now().toUtc().toIso8601String(),
    'nextDayAt': DateTime.now()
        .toUtc()
        .add(const Duration(hours: 5))
        .toIso8601String(),
    'board': [
      for (final (i, m) in [0.8, 1.3, 1.8, 2.5, 3.5].indexed)
        {'slot': i, 'kind': 'forest', 'mult': m},
    ],
    'startsLeft': 3,
    'helpRewardsLeft': 5,
    'active': [
      {
        'id': 'm1',
        'ownerNick': '대장',
        'mine': false,
        'kind': 'cave',
        'mult': 3.5,
        'need': 350,
        'total': helped.isEmpty ? 100 : 200,
        'endsAt': DateTime.now()
            .toUtc()
            .add(const Duration(minutes: 3))
            .toIso8601String(),
        'helpers': [
          if (helped.isNotEmpty) {'userId': 'me', 'nickname': '나'},
        ],
        'helped': helped.isNotEmpty,
        'helperMax': 3,
      },
    ],
    'recent': const [],
    'claimable': claimed
        ? {'missions': 0}
        : {
            'missions': 1,
            'chitin': 40,
            'mineral': 40,
            'sap': 40,
            'fossil': 4,
            'coins': 8,
          },
  };

  @override
  Future<ServerResult> guildMissions() async => ServerResult.ok(_missions);

  @override
  Future<ServerResult> guildMissionHelp(
    String missionId, {
    required double power,
  }) async {
    helped.add(missionId);
    return ServerResult.ok(_missions);
  }

  @override
  Future<ServerResult> uploadSave(Map<String, dynamic> save) async {
    uploaded = save;
    return const ServerResult.ok({});
  }

  @override
  Future<ServerResult> guildMissionClaim() async {
    claimed = true;
    final s = SaveGame.fromJson(uploaded!);
    return ServerResult.ok({
      'save': s
          .copyWith(
            materials: {
              ...s.materials,
              MaterialKind.fossil: s.materialCount(MaterialKind.fossil) + 4,
            },
          )
          .toJson(),
      'granted': {
        'chitin': 40,
        'mineral': 40,
        'sap': 40,
        'fossil': 4,
        'coins': 8,
        'eggs': 0,
      },
      'missions': 1,
    });
  }

  @override
  Future<ServerResult> guildJoin(String guildId) async {
    joined.add(guildId);
    return ServerResult.ok(_me);
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

SaveGame _seed(int jelly) => SaveGame.initial(
  createdAt: DateTime.utc(2026, 10),
).copyWith(materials: {MaterialKind.jelly: jelly});

Future<ProviderContainer> _pump(
  WidgetTester tester,
  _GuildServer server,
  SaveGame seed, {
  Locale locale = const Locale('ko'),
}) async {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      gameServerProvider.overrideWithValue(server),
      gameDataProvider.overrideWith((ref) => _data()),
      saveRepositoryProvider.overrideWithValue(_Repo(seed)),
    ],
  );
  addTearDown(container.dispose);
  // 실제 앱은 세이브를 읽은 뒤에 홈(길드 아이콘)에 들어온다.
  await tester.runAsync(() => container.read(saveControllerProvider.future));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: GuildScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('길드 없음 → 목록 · 가입 → 길드원 탭', (tester) async {
    final server = _GuildServer();
    await _pump(tester, server, _seed(0));

    expect(find.text('장수풍뎅이단'), findsOneWidget);
    expect(find.text('가입 신청'), findsOneWidget, reason: '승인제는 신청 버튼');
    expect(find.text('가득 참'), findsOneWidget);
    // 젤리가 모자라 만들기는 막히고 이유가 보인다.
    expect(find.text('젤리 200개가 있어야 길드를 만들 수 있어요'), findsOneWidget);

    await tester.tap(find.text('가입').first);
    await tester.pumpAndSettle();
    expect(server.joined, ['g1']);
    expect(find.text('대장'), findsOneWidget);
    expect(find.text('길드원'), findsWidgets);
    // 멤버는 가입 신청 탭이 없다.
    expect(find.textContaining('가입 신청'), findsNothing);
    expect(tester.takeException(), isNull);
    // "길드에 들어왔어요!" 안내가 사라질 때까지.
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('개설 — 서버가 치른 젤리 200을 로컬에서도 뺀다', (tester) async {
    final server = _GuildServer();
    final c = await _pump(tester, server, _seed(250));
    expect(find.textContaining('있어야 길드를'), findsNothing);
    await tester.tap(find.text('길드 만들기 · 젤리 200'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '장수풍뎅이단');
    await tester.tap(find.text('길드 만들기 · 젤리 200').last);
    await tester.pumpAndSettle();
    expect(server.joined, ['new']);
    expect(
      c
          .read(saveControllerProvider)
          .requireValue
          .materialCount(MaterialKind.jelly),
      50,
    );
    expect(find.text('대장'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('미션 탭 — 게시판 · 도와주기 · 보상 받기(서버 세이브 채택)', (tester) async {
    final server = _GuildServer()..joined.add('g1');
    final c = await _pump(tester, server, _seed(0));
    await tester.tap(find.text('미션'));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));

    expect(find.text('오늘의 게시판'), findsOneWidget);
    expect(find.text('대장 님의 미션'), findsOneWidget);
    expect(find.textContaining('28%'), findsOneWidget);

    await tester.tap(find.text('도와주기'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(server.helped, ['m1']);
    expect(find.text('도움 완료'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));

    await tester.tap(find.text('보상 받기'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(server.uploaded, isNotNull, reason: '받기 전에 최신 세이브를 먼저 올린다');
    expect(
      c
          .read(saveControllerProvider)
          .requireValue
          .materialCount(MaterialKind.fossil),
      4,
    );
    expect(find.text('길드 코인 +8'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // 탭을 떠나면 주기 조회를 멈춘다(타이머가 남지 않는다).
    await tester.tap(find.text('받기').last);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('길드원').first);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('3단계 — 출석 · 상점 구매(서버 세이브 채택)', (tester) async {
    final server = _GuildServer()..joined.add('g1');
    final c = await _pump(tester, server, _seed(0));
    expect(find.text('길드 Lv 3 · 코인 100'), findsOneWidget);

    await tester.tap(find.text('출석'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('출석 완료'), findsOneWidget);
    expect(find.text('길드 Lv 3 · 코인 110'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));

    await tester.tap(find.text('상점'));
    await tester.pumpAndSettle();
    expect(find.text('화석 20개'), findsOneWidget);
    await tester.tap(find.text('30'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(server.uploaded, isNotNull, reason: '사기 전에 최신 세이브를 올린다');
    expect(
      c
          .read(saveControllerProvider)
          .requireValue
          .materialCount(MaterialKind.fossil),
      20,
    );
    expect(find.text('오늘 1/5'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('보스 탭 — 공격하면 피해·코인이 보이고 남은 횟수가 준다', (tester) async {
    final server = _GuildServer()..joined.add('g1');
    await _pump(tester, server, _seed(0));
    await tester.tap(find.text('보스'));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    expect(find.text('길드 보스 · 2단계'), findsOneWidget);
    expect(find.text('지난주 3위 — 젤리 10개'), findsOneWidget);
    await tester.tap(find.text('공격하기 (오늘 2회 남음)'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('공격하기 (오늘 1회 남음)'), findsOneWidget);
    expect(find.textContaining('피해 100'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('길드전 탭 — 7일차 결과 · 보상 받기(서버 세이브 채택)', (tester) async {
    final server = _GuildServer()..joined.add('g1');
    final c = await _pump(tester, server, _seed(0));
    await tester.tap(find.text('길드전'));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    expect(find.text('vs 사슴벌레회'), findsOneWidget);
    expect(find.text('승점 12 : 6'), findsOneWidget);
    expect(find.text('승리'), findsOneWidget);
    await tester.tap(find.text('보상 받기'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      c
          .read(saveControllerProvider)
          .requireValue
          .materialCount(MaterialKind.jelly),
      15,
    );
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 3));
  });

  test('길드전 활동 집계 — 하루가 바뀌면 0부터 · 보낸 뒤엔 바뀐 게 없으면 안 싣는다', () {
    GuildWarTally.reset();
    final d1 = DateTime.utc(2026, 10, 5, 3);
    expect(GuildWarTally.payload(d1), isNull);
    GuildWarTally.add('synth', d1);
    GuildWarTally.add('synth', d1);
    expect(GuildWarTally.payload(d1)!['counts'], {'synth': 2});
    GuildWarTally.sent();
    expect(GuildWarTally.payload(d1), isNull);
    final d2 = d1.add(const Duration(days: 1));
    GuildWarTally.add('elite', d2);
    expect(GuildWarTally.payload(d2)!['counts'], {'elite': 1});
    GuildWarTally.reset();
  });

  testWidgets('일본어 — 길드 화면 탭을 돌아도 넘치지 않는다(360폭)', (tester) async {
    final server = _GuildServer()..joined.add('g1');
    await _pump(tester, server, _seed(0), locale: const Locale('ja'));
    expect(find.text('メンバー'), findsWidgets);
    for (final tab in ['ミッション', 'ボス', 'ギルド戦', 'チャット']) {
      await tester.tap(find.text(tab).first);
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull, reason: tab);
    }
  });
}
