import 'dart:convert';
import 'dart:io';

import 'package:app/data/game_data.dart';
import 'package:app/data/save_repository.dart';
import 'package:app/domain/game_server.dart';
import 'package:app/domain/guild_service.dart';
import 'package:app/domain/providers.dart';
import 'package:app/features/guild/guild_art.dart';
import 'package:app/features/guild/guild_mission_tab.dart';
import 'package:app/features/guild/guild_screen.dart';
import 'package:app/features/guild/guild_war_tab.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:app/domain/save_controller.dart';
import 'package:core_models/core_models.dart';
import 'package:core_save/core_save.dart';
import 'package:flutter/material.dart' hide Element;
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

  /// 만들기 요청에 실려 온 문장.
  int? createdEmblem;

  /// 호출 수 — 숨은 화면이 서버를 부르지 않는지 본다.
  var meCalls = 0;
  var listCalls = 0;
  var missionCalls = 0;

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
            'deputyCanAccept': deputyCanAccept,
            'emblem': settingsEmblem,
          },
          'myCoins': coins,
          'donatedToday': donated,
          'attendCount': attendCount,
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
          'myRole': role,
          'members': [
            {
              'userId': 'u1',
              'role': role == 'leader' ? 'deputy' : 'leader',
              'nickname': '대장',
              'power': 3.2e6,
              'contribution': 3500,
              'lastSeen': DateTime.now().toUtc().toIso8601String(),
            },
            {
              'userId': 'me',
              'role': role,
              'nickname': '나',
              'power': 1.1e6,
              'contribution': 120,
              'lastSeen': DateTime.now().toUtc().toIso8601String(),
            },
            {
              'userId': 'u3',
              'role': 'member',
              'nickname': '막내',
              'power': 0.5e6,
              'contribution': 600,
              'lastSeen': DateTime.now().toUtc().toIso8601String(),
            },
          ],
        };

  @override
  bool get available => true;

  @override
  Future<ServerResult> guildMe() async {
    meCalls++;
    return ServerResult.ok(_me);
  }

  @override
  Future<ServerResult> guildList({
    required String lang,
    String query = '',
  }) async {
    listCalls++;
    return _list;
  }

  /// 모집 목록 흉내 — 비우기 · 실패.
  var listEmpty = false;
  var listFails = false;

  ServerResult get _list => listFails
      ? const ServerResult.fail('store_unavailable', 503)
      : listEmpty
      ? const ServerResult.ok({'guilds': [], 'requested': <String>[]})
      : ServerResult.ok({
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
    int? emblem,
  }) async {
    createdEmblem = emblem;
    joined.add('new');
    return ServerResult.ok({..._me, 'jellySpent': 500});
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
      'opponentId': 'g2',
      'opponentEmblem': 5,
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

  /// 내 직책 · 부길드장 수락 허용(직책 권한 테스트).
  var role = 'member';
  var deputyCanAccept = true;

  /// 문장 바꾸기로 받은 값(내 길드 응답에 실린다).
  int? settingsEmblem;

  @override
  Future<ServerResult> guildSettings({
    String? notice,
    String? joinMode,
    bool? deputyCanAccept,
    int? emblem,
  }) async {
    if (emblem != null) settingsEmblem = emblem;
    if (deputyCanAccept != null) this.deputyCanAccept = deputyCanAccept;
    return ServerResult.ok(_me);
  }

  var donated = false;
  var bought = 0;
  var attendCount = 0;

  @override
  Future<ServerResult> guildDonate() async {
    donated = true;
    attendCount++;
    // 실제 guild.json 표 — 7일차 큰 보상(코인 50 + 화석 10)은 서버 세이브로 온다.
    final big = attendCount == 7;
    coins += big ? 60 : 10;
    final s = SaveGame.fromJson(uploaded!);
    return ServerResult.ok({
      ..._me,
      'attend': {
        'day': attendCount,
        'coins': big ? 60 : 10,
        'fossil': big ? 10 : 0,
        'fairyDust': 0,
      },
      if (big)
        'save': s
            .copyWith(
              materials: {
                ...s.materials,
                MaterialKind.fossil: s.materialCount(MaterialKind.fossil) + 10,
              },
            )
            .toJson(),
    });
  }

  /// 길드원 정보 — u1 만 요약이 있고, 'stranger' 는 다른 길드(403).
  final memberCalls = <String>[];

  @override
  Future<ServerResult> guildMember(String userId) async {
    memberCalls.add(userId);
    if (userId == 'stranger') {
      return const ServerResult.fail('forbidden', 403);
    }
    return ServerResult.ok({
      'member': {
        'userId': userId,
        'role': 'leader',
        'nickname': '대장',
        'power': 3.2e6,
        'contribution': 3500,
        'rank': 'elite',
        'lastSeen': DateTime.now().toUtc().toIso8601String(),
      },
      if (userId == 'u1')
        'summary': {
          'nickname': '대장',
          'level': 42,
          'tier': 1,
          'stage': 301,
          'inAbyss': false,
          'abyssFloor': 0,
          'pets': [
            IndividualBug(
              id: 'p1',
              speciesId: 'stag_dorcus',
              sizeMm: 41.5,
              potential: 4,
              temperament: Temperament.aggressive,
              sex: Sex.male,
              element: Element.fire,
              stage: LifeStage.adult,
            ).toJson(),
          ],
          'team': [
            {'sp': 'stag_saw', 'element': 'water', 'power': 1234},
          ],
          'equipment': [
            const EquipItem(slot: EquipSlot.hat, tier: 3, options: []).toJson(),
          ],
          'skills': [
            {'id': 'lure_sap', 'level': 3},
          ],
        },
    });
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
        'ownerPower': 120,
        'helpers': [
          {'userId': 'u3', 'nickname': '막내', 'power': 80},
          if (helped.isNotEmpty) {'userId': 'me', 'nickname': '나', 'power': 0},
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
  Future<ServerResult> guildMissions() async {
    missionCalls++;
    return ServerResult.ok(_missions);
  }

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
  bool onGuildTab = true,
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
  // 길드 화면은 하단 길드 탭이 골라졌을 때만 안쪽을 빌드한다.
  if (onGuildTab) container.read(tabIndexProvider.notifier).set(kGuildTabIndex);
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
    // 문장을 고른 적 없는 길드도 id 해시로 기본 문장이 보인다 · 상단 배너.
    expect(find.byKey(const ValueKey('guildEmblem:g1')), findsOneWidget);
    expect(find.byKey(const ValueKey('guildNoneBanner')), findsOneWidget);
    expect(find.text('가입 신청'), findsOneWidget, reason: '승인제는 신청 버튼');
    expect(find.text('가득 참'), findsOneWidget);
    // 젤리가 모자라 만들기는 막히고 이유가 보인다.
    expect(find.text('젤리 500개가 있어야 길드를 만들 수 있어요'), findsOneWidget);

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

  testWidgets('직책 권한 — 부길드장에게는 추방·설정 버튼이 없다 · 등급 뱃지', (tester) async {
    final server = _GuildServer()
      ..joined.add('g1')
      ..role = 'deputy'
      ..deputyCanAccept = false;
    await _pump(tester, server, _seed(0));

    // 멤버 등급(기여도) — 3500 정예 · 600 일꾼 · 120 새내기(뱃지 + 내 등급 줄).
    expect(find.byKey(const ValueKey('guildRank:elite')), findsOneWidget);
    expect(find.byKey(const ValueKey('guildRank:worker')), findsOneWidget);
    expect(find.byKey(const ValueKey('guildRank:rookie')), findsWidgets);
    // 멤버 줄에 메뉴 표시가 없고, 눌러도 추방이 안 나온다.
    expect(
      find.byIcon(Icons.more_vert_rounded),
      findsOneWidget,
      reason: '앱바 메뉴만',
    );
    // 줄을 누르면 길드원 정보 시트(추방 메뉴가 아니다).
    await tester.tap(find.text('막내'));
    await tester.pumpAndSettle();
    expect(find.text('추방'), findsNothing);
    expect(server.memberCalls, ['u3']);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    // 앱바 메뉴 — 소개·가입 방식·수락 허용 스위치가 없다.
    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    expect(find.text('소개 수정'), findsNothing);
    expect(find.text('부길드장 가입 수락 허용'), findsNothing);
    expect(find.text('길드 탈퇴'), findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    // 스위치가 꺼져 있으면 신청 탭도 없다.
    expect(find.textContaining('신청 '), findsNothing);
    // 권한 도움말(i).
    await tester.tap(find.byKey(const ValueKey('guildPermsHelp')));
    await tester.pumpAndSettle();
    expect(find.text('직책별 권한'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('직책 권한 — 길드장은 멤버 메뉴에 추방 · 앱바에 수락 허용 스위치', (tester) async {
    final server = _GuildServer()
      ..joined.add('g1')
      ..role = 'leader';
    await _pump(tester, server, _seed(0));

    expect(find.byIcon(Icons.more_vert_rounded), findsNWidgets(3));
    // 줄을 누르면 정보 시트, 직책·추방은 오른쪽 ⋮ 메뉴(2026-10-05).
    await tester.tap(find.byKey(const ValueKey('guildMemberMenu:u3')));
    await tester.pumpAndSettle();
    expect(find.text('추방'), findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.textContaining('신청 '), findsOneWidget, reason: '길드장은 신청 탭');
    await tester.tap(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.more_vert_rounded),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('부길드장 가입 수락 허용'), findsOneWidget);
    // 문장 바꾸기(길드장) — 고르고 저장하면 서버로 간다 · 앱바 문장이 바뀐다.
    await tester.tap(find.byKey(const ValueKey('guildEmblemChange')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('guildEmblemPick:4')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(server.settingsEmblem, 4);
    final mine = tester.widget<GuildEmblem>(
      find.byKey(const ValueKey('guildEmblem:mine')),
    );
    expect(mine.emblem, 4);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('개설 — 서버가 치른 젤리 500을 로컬에서도 뺀다', (tester) async {
    final server = _GuildServer();
    final c = await _pump(tester, server, _seed(550));
    expect(find.textContaining('있어야 길드를'), findsNothing);
    await tester.tap(find.text('길드 만들기 · 젤리 500'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '장수풍뎅이단');
    await tester.tap(find.byKey(const ValueKey('guildEmblemPick:3')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('길드 만들기 · 젤리 500').last);
    await tester.pumpAndSettle();
    expect(server.joined, ['new']);
    expect(server.createdEmblem, 3, reason: '고른 문장이 만들기 요청에 실린다');
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
    // 레벨과 코인은 한 줄에 따로(코인 앞엔 코인 그림).
    expect(find.text('길드 Lv 3'), findsOneWidget);
    expect(find.text('코인 100'), findsOneWidget);

    // 출석 버튼 → 출석 표 → 오늘 출석하기.
    await tester.tap(find.text('출석'));
    await tester.pumpAndSettle();
    expect(find.text('출석 표'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('guildAttendNow')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(server.uploaded, isNotNull, reason: '출석 전에 최신 세이브를 올린다');
    expect(find.text('출석 완료'), findsOneWidget);
    expect(find.text('코인 110'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('상점'));
    await tester.pumpAndSettle();
    expect(find.text('화석 20개'), findsOneWidget);
    // 가격에 단위(코인)가 보인다.
    await tester.tap(find.text('코인 30'));
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
    // 대진 문장(우리·상대) — 7일 줄 아래 결과는 스크롤해야 보인다.
    expect(find.byKey(const ValueKey('guildWarEmblem:mine')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('guildWarEmblem:opponent')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('승점 12 : 6'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(GuildWarTab),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('승점 12 : 6'), findsOneWidget);
    expect(find.text('승리'), findsOneWidget);
    await tester.ensureVisible(find.text('보상 받기'));
    await tester.pumpAndSettle();
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
  testWidgets('영어 — 머리 줄(레벨·코인·출석/스킬/상점 그림 버튼)·탭 아이콘이 360폭에 들어간다', (
    tester,
  ) async {
    final server = _GuildServer()
      ..joined.add('g1')
      ..role = 'leader';
    await _pump(tester, server, _seed(0), locale: const Locale('en'));
    expect(find.byKey(const ValueKey('guildAttend')), findsOneWidget);
    expect(tester.takeException(), isNull);
    for (final tab in ['Missions', 'Boss', 'War', 'Chat']) {
      await tester.tap(find.text(tab).first);
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull, reason: tab);
    }
    expect(tester.takeException(), isNull);
  });
  testWidgets('숨은 길드 화면 — 하단 길드 탭을 열기 전엔 목록·미션을 부르지 않는다', (tester) async {
    final server = _GuildServer();
    final c = await _pump(tester, server, _seed(0), onGuildTab: false);
    expect(server.listCalls, 0);
    expect(find.text('장수풍뎅이단'), findsNothing);
    c.read(tabIndexProvider.notifier).set(kGuildTabIndex);
    await tester.pumpAndSettle();
    expect(server.listCalls, 1);
    expect(find.text('장수풍뎅이단'), findsOneWidget);
    expect(server.meCalls, 1, reason: 'build 가 방금 받았으면 탭 진입 갱신은 건너뛴다');
  });

  testWidgets('미션 탭 주기 조회 — 다른 하단 탭으로 가면 멈춘다', (tester) async {
    final server = _GuildServer()..joined.add('g1');
    final c = await _pump(tester, server, _seed(0));
    expect(server.missionCalls, 0, reason: '안 연 안쪽 탭은 빌드하지 않는다');
    await tester.tap(find.text('미션'));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    expect(server.missionCalls, 1, reason: '처음 열 때 한 번(겹쳐 부르지 않는다)');
    c.read(tabIndexProvider.notifier).set(0);
    await tester.pump();
    final before = server.missionCalls;
    await tester.pump(const Duration(seconds: 30));
    expect(server.missionCalls, before, reason: '길드 탭 밖에서는 조회하지 않는다');
  });

  test('배율 표기 — ×2 · ×1.3 · ×0.85', () {
    expect(guildMultText(2.0), '2');
    expect(guildMultText(1.3), '1.3');
    expect(guildMultText(0.85), '0.85');
    expect(guildMultText(1.3000000000000003), '1.3');
  });

  test('길드 상태가 낡았다는 오류 코드', () {
    expect(guildStateStale('not_in_guild'), isTrue);
    expect(guildStateStale('already_in_guild'), isTrue);
    expect(guildStateStale('guild_not_found'), isTrue);
    expect(guildStateStale('guild_full'), isFalse);
  });

  testWidgets('출석 표 — 35칸 · 큰 보상 칸 · 7일차 출석은 서버 세이브(화석)를 채택한다', (tester) async {
    final server = _GuildServer()
      ..joined.add('g1')
      ..attendCount = 6;
    final c = await _pump(tester, server, _seed(0));
    await tester.tap(find.byKey(const ValueKey('guildAttend')));
    await tester.pumpAndSettle();
    expect(find.text('6 / 35칸'), findsOneWidget);
    for (final d in [1, 7, 35]) {
      expect(find.byKey(ValueKey('guildAttendCell:$d')), findsOneWidget);
    }
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(6));
    await tester.tap(find.byKey(const ValueKey('guildAttendNow')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('7일차 출석!'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(7));
    expect(
      c
          .read(saveControllerProvider)
          .requireValue
          .materialCount(MaterialKind.fossil),
      10,
      reason: '큰 보상 화석은 서버가 넣은 세이브로 받는다',
    );
    expect(find.text('오늘은 출석했어요 — 내일 또 만나요'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 3));
  });

  for (final loc in const [Locale('en'), Locale('ja')]) {
    testWidgets('출석 표 — ${loc.languageCode} 360폭에서 7칸이 넘치지 않는다', (
      tester,
    ) async {
      final server = _GuildServer()
        ..joined.add('g1')
        ..attendCount = 12;
      await _pump(tester, server, _seed(0), locale: loc);
      await tester.tap(find.byKey(const ValueKey('guildAttend')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('guildAttendCell:35')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('길드원 정보 — 줄을 누르면 진행도·장착 곤충·방어팀·장비·스킬', (tester) async {
    final server = _GuildServer()..joined.add('g1');
    await _pump(tester, server, _seed(0));
    await tester.tap(find.byKey(const ValueKey('guildMember:u1')));
    await tester.pumpAndSettle();
    expect(server.memberCalls, ['u1']);
    expect(find.text('캐릭터 Lv 42'), findsOneWidget);
    expect(find.text('장착 곤충'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('guildMemberPet:stag_dorcus')),
      findsOneWidget,
    );
    expect(find.text('결투 방어팀'), findsOneWidget);
    expect(find.textContaining('보통'), findsWidgets, reason: '난이도 · 사냥터');
    await tester.drag(find.text('장착 곤충'), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('guildMemberItem:hat')), findsOneWidget);
    expect(find.text('동행 요정'), findsOneWidget);
    expect(find.text('없음'), findsWidgets, reason: '동행 요정 없음');
    expect(tester.takeException(), isNull);
  });

  testWidgets('길드원 정보 — 요약이 없으면(세이브 없음) 안내만 · 일본어 360폭', (tester) async {
    final server = _GuildServer()..joined.add('g1');
    await _pump(tester, server, _seed(0), locale: const Locale('ja'));
    await tester.tap(find.byKey(const ValueKey('guildMember:u3')));
    await tester.pumpAndSettle();
    expect(find.text('このメンバーの詳細を読み込めません'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('미션 — 함께하는 길드원(출발·전투력) · 성공 보상 · 대기 시간마다 숫자가 바뀐다', (
    tester,
  ) async {
    final server = _GuildServer()..joined.add('g1');
    await _pump(tester, server, _seed(0));
    await tester.tap(find.text('미션'));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    expect(find.text('출발자'), findsOneWidget);
    expect(find.text('막내'), findsWidgets);
    expect(find.text('전투력 80'), findsOneWidget);
    expect(find.text('전투력 120'), findsOneWidget);
    expect(find.text('성공 보상'), findsWidgets);
    // ×3.5 칸 출발 → 대기 1·10분의 보상이 다르다(배율 1.0 · 1.25).
    await tester.scrollUntilVisible(
      find.text('출발').last,
      200,
      scrollable: find
          .descendant(
            of: find.byType(GuildMissionTab),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('출발').last);
    await tester.pumpAndSettle();
    String chips(int sec) => tester
        .widgetList<Text>(
          find.descendant(
            of: find.byKey(ValueKey('guildMissionWait:$sec')),
            matching: find.byType(Text),
          ),
        )
        .map((t) => t.data)
        .join('|');
    expect(chips(60), isNot(chips(600)));
    expect(find.textContaining('달성률'), findsOneWidget);
    expect(find.textContaining('도와준 길드원'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('길드원').first);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('길드 없음 — 들어오자마자 "모집 중" 목록 · 비었으면 만들기 안내 · 실패는 다시 시도', (
    tester,
  ) async {
    final server = _GuildServer();
    await _pump(tester, server, _seed(0));
    expect(find.text('모집 중인 길드'), findsOneWidget);
    expect(server.listCalls, 1);

    final empty = _GuildServer()..listEmpty = true;
    await _pump(tester, empty, _seed(0));
    expect(find.text('모집 중인 길드가 없어요 — 직접 만들어 보세요!'), findsOneWidget);

    final down = _GuildServer()..listFails = true;
    await _pump(tester, down, _seed(0));
    expect(find.text('모집 중인 길드가 없어요 — 직접 만들어 보세요!'), findsNothing);
    expect(find.text('다시 시도'), findsOneWidget);
    down.listFails = false;
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text('장수풍뎅이단'), findsOneWidget);
  });
}
