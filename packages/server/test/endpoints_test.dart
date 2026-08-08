import 'dart:convert';
import 'dart:io';

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:http/http.dart' as http;
import 'package:server/src/app.dart';
import 'package:server/src/game_config.dart';
import 'package:server/src/state_store.dart';
import 'package:server/src/verifier.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'auth_test.dart' show makeToken, signingKey, verifierFor;

const _url = 'https://proj.supabase.co';
final _t = DateTime.utc(2026, 7, 20, 12);

/// Supabase REST 를 흉내내는 가짜 — saves 읽기/쓰기와 defenders 읽기를 지원.
class _Fake extends http.BaseClient {
  _Fake(
    this.saves, {
    this.defenders = const {},
    this.notices = const [],
    this.mail = const [],
    this.codes = const [],
  });

  final Map<String, Map<String, dynamic>> saves;
  final Map<String, List<Map<String, dynamic>>> defenders;

  /// 공지·우편·선물코드 테이블(운영이 SQL 로 넣는 행들).
  final List<Map<String, dynamic>> notices;
  final List<Map<String, dynamic>> mail;
  final List<Map<String, dynamic>> codes;

  /// 운영 패널이 지운 행(URL 그대로).
  final List<String> deleted = [];

  /// 이미 처리된 1회성 행 — 기본키 중복(409)을 흉내낸다.
  final Set<String> claimedMail = {};
  final Set<String> redeemedCodes = {};

  /// 마지막으로 저장된 행 — "세이브를 건드렸는가"를 확인하는 데 쓴다.
  Map<String, dynamic>? lastSaved;

  /// 수동 전투 세션 — 수와 수 사이에 살아남아야 한다.
  final Map<String, Map<String, dynamic>> sessions = {};

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    if (request.method == 'DELETE') {
      deleted.add(request.url.toString());
      return http.StreamedResponse(Stream.value(utf8.encode('')), 204);
    }
    if (request.method == 'POST') {
      final raw = await request.finalize().bytesToString();
      if (path.contains('/rpc/bump_gift_code')) {
        return http.StreamedResponse(Stream.value(utf8.encode('null')), 200);
      }
      final row = (jsonDecode(raw) as List).first as Map<String, dynamic>;
      // 1회성 삽입: 이미 있으면 409(기본키 충돌) — 서버가 이걸로 중복을 막는다.
      if (path.contains('/mail_claims')) {
        final key = '${row['mail_id']}|${row['user_id']}';
        final fresh = claimedMail.add(key);
        return http.StreamedResponse(
          Stream.value(utf8.encode('')),
          fresh ? 201 : 409,
        );
      }
      if (path.contains('/code_redemptions')) {
        final key = '${row['code']}|${row['user_id']}';
        final fresh = redeemedCodes.add(key);
        return http.StreamedResponse(
          Stream.value(utf8.encode('')),
          fresh ? 201 : 409,
        );
      }
      if (path.contains('/battle_sessions')) {
        sessions[row['id'].toString()] = row;
      } else {
        lastSaved = row;
      }
      return http.StreamedResponse(Stream.value(utf8.encode('[]')), 201);
    }
    final id = request.url.queryParameters['id']?.replaceFirst('eq.', '');
    final Object body;
    if (path.contains('/notices')) {
      body = notices;
    } else if (path.contains('/user_mail')) {
      body = mail;
    } else if (path.contains('/mail_claims')) {
      final uid = request.url.queryParameters['user_id']?.replaceFirst(
        'eq.',
        '',
      );
      body = [
        for (final k in claimedMail)
          if (k.endsWith('|$uid')) {'mail_id': k.split('|').first},
      ];
    } else if (path.contains('/gift_codes')) {
      final want = request.url.queryParameters['code']?.replaceFirst('eq.', '');
      body = [
        for (final c in codes)
          if (c['code'] == want) c,
      ];
    } else if (path.contains('/battle_sessions')) {
      final row = sessions[id];
      body = row == null ? [] : [row];
    } else if (path.contains('/defenders')) {
      final team = defenders[id];
      body = team == null
          ? []
          : [
              {'team': team},
            ];
    } else {
      final data = saves[id];
      body = data == null
          ? []
          : [
              {'data': data},
            ];
    }
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(body))),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

Map<String, dynamic> _readJson(String name) =>
    jsonDecode(File('../app/assets/data/$name').readAsStringSync())
        as Map<String, dynamic>;

/// 다른 유저의 토큰 클레임.
Map<String, dynamic> _claimsFor(String sub) => {
  'sub': sub,
  'iss': '$_url/auth/v1',
  'exp':
      DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
      1000,
};

/// 방어팀 1마리 스냅샷.
Map<String, dynamic> _defender({
  double hp = 100,
  double atk = 10,
  double def = 10,
  double spd = 10,
}) => {
  'sp': 'a',
  'el': 'fire',
  'tm': 'aggressive',
  'hp': hp,
  'atk': atk,
  'def': def,
  'spd': spd,
};

void main() {
  final species = Species.fromJson({
    'id': 'a',
    'name': {'ko': '테스트벌레', 'en': 'T', 'ja': 'T'},
    'grade': 'common',
    'specialty': 'strike',
    'baseStats': {'hp': 100, 'atk': 40, 'def': 30, 'spd': 20},
    'sizeMinMm': 20,
    'sizeMaxMm': 60,
  });

  final gameConfig = GameConfig(
    iap: IapConfig.fromJson(_readJson('iap.json')),
    battle: BattleConfig.fromJson(_readJson('battle.json')),
    run: RunConfig.fromJson(_readJson('run_config.json')),
    pet: PetConfig.fromJson(_readJson('pets.json')),
    mission: MissionConfig.fromJson(_readJson('missions.json')),
    gift: GiftConfig.fromJson(_readJson('gifts.json')),
    daily: DailyConfig.fromJson(_readJson('daily.json')),
    roadmap: RoadmapConfig.fromJson(_readJson('roadmap.json')),
    speciesById: {'a': species},
  );

  final mySave = SaveGame.initial(createdAt: _t).copyWith(
    bugs: [
      IndividualBug(
        id: 'mine-1',
        speciesId: 'a',
        sizeMm: 40,
        potential: 3,
        temperament: Temperament.aggressive,
        sex: Sex.male,
        element: Element.wood,
        stage: LifeStage.adult,
        stageSince: _t.subtract(const Duration(days: 30)),
      ),
    ],
  );

  late _Fake fake;

  Handler handler({
    VerifyVerdict verdict = VerifyVerdict.valid,
    Map<String, List<Map<String, dynamic>>> defenders = const {},
    bool serverHasSave = true,
    SaveGame? save,
    List<Map<String, dynamic>> notices = const [],
    List<Map<String, dynamic>> mail = const [],
    List<Map<String, dynamic>> codes = const [],
  }) {
    fake = _Fake(
      serverHasSave ? {'user-1': (save ?? mySave).toJson()} : {},
      defenders: defenders,
      notices: notices,
      mail: mail,
      codes: codes,
    );
    return buildHandler(
      config: ServerConfig(
        supabaseUrl: _url,
        serviceRoleKey: 'service-role',
        anonKey: 'anon',
      ),
      store: StateStore(
        supabaseUrl: _url,
        serviceRoleKey: 'service-role',
        client: fake,
      ),
      jwtVerifier: verifierFor(signingKey),
      gameConfig: gameConfig,
      speciesById: {'a': species},
      receiptVerifier: FixedVerifier(verdict),
      clock: () => _t,
    );
  }

  Future<Response> get(Handler h, String path, {String? token}) async => h(
    Request(
      'GET',
      Uri.parse('http://localhost$path'),
      headers: {if (token != null) 'authorization': 'Bearer $token'},
    ),
  );

  Future<Response> post(
    Handler h,
    String path,
    Object body, {
    String? token,
  }) async => h(
    Request(
      'POST',
      Uri.parse('http://localhost$path'),
      headers: {
        if (token != null) 'authorization': 'Bearer $token',
        'content-type': 'application/json',
      },
      body: jsonEncode(body),
    ),
  );

  group('구매 엔드포인트', () {
    test('인증 없이는 불가', () async {
      final res = await post(handler(), '/purchase', {
        'productId': 'jelly_m',
        'purchaseToken': 'tok',
      });
      expect(res.statusCode, 401);
    });

    test('위조 영수증은 지급되지 않고 세이브도 안 건드린다', () async {
      final h = handler(verdict: VerifyVerdict.invalid);
      final res = await post(h, '/purchase', {
        'productId': 'jelly_m',
        'purchaseToken': 'fake',
      }, token: makeToken());
      expect(res.statusCode, 402);
      expect(fake.lastSaved, isNull);
    });

    test('검증 불가면 지급 보류 — 정상 구매자가 손해 보지 않게', () async {
      final h = handler(verdict: VerifyVerdict.unknown);
      final res = await post(h, '/purchase', {
        'productId': 'jelly_m',
        'purchaseToken': 'tok',
      }, token: makeToken());
      expect(res.statusCode, 503);
      expect(fake.lastSaved, isNull);
    });

    test('정상 영수증이면 지급되고 저장된다', () async {
      final h = handler();
      final res = await post(h, '/purchase', {
        'productId': 'jelly_m',
        'purchaseToken': 'tok-1',
      }, token: makeToken());
      expect(res.statusCode, 200);
      final saved = SaveGame.fromJson(
        fake.lastSaved!['data'] as Map<String, dynamic>,
      );
      expect(saved.materialCount(MaterialKind.jelly), greaterThan(0));
      expect(saved.redeemedPurchases, contains('tok-1'));
    });

    test('없는 상품 id 로는 재화를 만들 수 없다', () async {
      final h = handler();
      final res = await post(h, '/purchase', {
        'productId': 'free_jelly_9999',
        'purchaseToken': 'tok',
      }, token: makeToken());
      expect(res.statusCode, 400);
      expect(fake.lastSaved, isNull);
    });
  });

  group('전투 엔드포인트', () {
    test('상대가 없으면 전투 불가', () async {
      final res = await post(handler(), '/battle', {
        'teamBugIds': ['mine-1'],
        'opponentUserId': 'ghost',
      }, token: makeToken());
      expect(res.statusCode, 404);
    });

    test('내 곤충이 아니면 출전 불가', () async {
      final h = handler(
        defenders: {
          'foe': [_defender()],
        },
      );
      final res = await post(h, '/battle', {
        'teamBugIds': ['someone-elses-bug'],
        'opponentUserId': 'foe',
      }, token: makeToken());
      expect(res.statusCode, 400);
      expect(fake.lastSaved, isNull);
    });

    test('전투가 성립하면 결과가 저장된다', () async {
      final h = handler(
        defenders: {
          'foe': [_defender()],
        },
      );
      final res = await post(h, '/battle', {
        'teamBugIds': ['mine-1'],
        'opponentUserId': 'foe',
      }, token: makeToken());
      expect(res.statusCode, 200);
      final body = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
      expect(body['outcome'], isNotNull);
      expect(body['seed'], isNotNull);
      expect(fake.lastSaved, isNotNull);
    });

    test('클라이언트가 보낸 상대 스탯은 무시된다 (서버가 DB 에서 읽음)', () async {
      // DB 의 상대는 압도적으로 강하다.
      final h = handler(
        defenders: {
          'foe': [_defender(hp: 99999, atk: 9999, def: 9999, spd: 9999)],
        },
      );
      // 클라가 "상대는 약해요"라고 우겨도 서버는 DB 값을 쓴다.
      final res = await post(h, '/battle', {
        'teamBugIds': ['mine-1'],
        'opponentUserId': 'foe',
        'foeTeam': [
          {'hp': 1, 'atk': 1, 'def': 1, 'spd': 1},
        ],
      }, token: makeToken());
      expect(res.statusCode, 200);
      final body = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
      expect(body['outcome'], isNot('teamA'));
    });
  });

  group('결투 티켓 엔드포인트', () {
    final noTickets = mySave.copyWith(pvpTickets: 0, ticketsAt: _t);

    test('티켓이 없으면 전투를 시작할 수 없다', () async {
      final h = handler(
        save: noTickets,
        defenders: {
          'foe': [_defender()],
        },
      );
      final res = await post(h, '/battle', {
        'teamBugIds': ['mine-1'],
        'opponentUserId': 'foe',
      }, token: makeToken());
      expect(res.statusCode, 400);
      final body = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
      expect(body['error'], 'no_tickets');
      // 거절할 때 **서버가 아는 잔량**을 함께 준다 — 앱이 화면을 즉시 맞춘다.
      expect(body['tickets'], 0);
      expect(body['ticketsAt'], isNotNull);
      expect(fake.lastSaved, isNull); // 전투도, 저장도 없었다
    });

    test('수동 전투도 시작할 때 티켓을 쓴다', () async {
      final h = handler(
        defenders: {
          'foe': [_defender()],
        },
      );
      final res = await post(h, '/battle/manual/start', {
        'teamBugIds': ['mine-1'],
        'opponentUserId': 'foe',
      }, token: makeToken());
      expect(res.statusCode, 200);
      final body = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
      expect(body['tickets'], kDefaultPvpTickets - 1);
      // 세이브에도 반영돼야 한다 — 중간에 나가도 티켓은 이미 쓴 것.
      expect(fake.lastSaved, isNotNull);
    });

    test('인증 없이는 티켓을 충전할 수 없다', () async {
      expect(
        (await post(handler(), '/pvp/ticket/ad', const {})).statusCode,
        401,
      );
      expect(
        (await post(handler(), '/pvp/ticket/refill', const {})).statusCode,
        401,
      );
    });

    test('광고 충전은 서버가 지급하고 시청 횟수를 센다', () async {
      final h = handler(save: noTickets);
      final res = await post(h, '/pvp/ticket/ad', const {}, token: makeToken());
      expect(res.statusCode, 200);
      final body = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
      expect(body['tickets'], gameConfig.battle.ticketAdGrant);
      expect(body['adUsed'], 1);
      // 응답에 세이브를 싣지 않는다(이그레스 절약).
      expect(body.containsKey('save'), isFalse);
    });

    test('젤리가 없으면 즉시 충전이 거부된다', () async {
      final h = handler(save: noTickets);
      final res = await post(
        h,
        '/pvp/ticket/refill',
        const {},
        token: makeToken(),
      );
      expect(res.statusCode, 400);
      expect(jsonDecode(await res.readAsString())['error'], 'insufficient');
    });

    test('젤리가 있으면 만땅이 되고 값이 빠진다', () async {
      final h = handler(
        save: noTickets.copyWith(materials: {MaterialKind.jelly: 50}),
      );
      final res = await post(
        h,
        '/pvp/ticket/refill',
        const {},
        token: makeToken(),
      );
      expect(res.statusCode, 200);
      final body = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
      expect(body['tickets'], gameConfig.battle.ticketMax);
      expect(body['jelly'], 50 - gameConfig.battle.ticketRefillJelly);
    });
  });

  group('세이브 부트스트랩', () {
    test('서버에 세이브가 없으면 액션이 409 로 거부된다 (빈 세이브를 만들지 않음)', () async {
      final h = handler(serverHasSave: false);
      final res = await post(h, '/purchase', {
        'productId': 'jelly_m',
        'purchaseToken': 'tok',
      }, token: makeToken());
      expect(res.statusCode, 409);
      // 🔴 여기서 빈 세이브를 만들어 저장하면 로컬 진행도가 날아간다.
      expect(fake.lastSaved, isNull);
    });

    test('최초 업로드로 로컬 세이브를 서버에 이관한다', () async {
      final h = handler(serverHasSave: false);
      final res = await post(h, '/state', {
        'save': mySave.toJson(),
      }, token: makeToken());
      expect(res.statusCode, 200);
      final body = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
      expect(body['bootstrapped'], isTrue);
      final saved = SaveGame.fromJson(
        fake.lastSaved!['data'] as Map<String, dynamic>,
      );
      expect(saved.bugs.length, 1);
      expect(saved.bugs.first.id, 'mine-1');
    });

    test('부트스트랩은 트로피·IAP 위조를 리셋한다(솔로 진행은 유지)', () async {
      final h = handler(serverHasSave: false);
      final cheat = mySave.copyWith(
        gold: 12345,
        pvpTrophies: 999999,
        starterBought: true,
      );
      final res = await post(h, '/state', {
        'save': cheat.toJson(),
      }, token: makeToken());
      expect(res.statusCode, 200);
      final saved = SaveGame.fromJson(
        fake.lastSaved!['data'] as Map<String, dynamic>,
      );
      expect(saved.gold, 12345); // 솔로 진행 유지
      expect(saved.pvpTrophies, 0); // 위조 리셋
      expect(saved.starterBought, isFalse);
    });

    test('이미 서버 세이브가 있으면 덮어쓰지 못한다 (클라가 상태를 밀어넣는 것 차단)', () async {
      final h = handler(); // 서버에 이미 세이브 있음
      final evil = SaveGame.initial(createdAt: _t).copyWith(gold: 99999999);
      final res = await post(h, '/state', {
        'save': evil.toJson(),
      }, token: makeToken());
      expect(res.statusCode, 409);
      expect(fake.lastSaved, isNull);
      // 서버 것을 돌려줘 앱이 그걸 채택하게 한다.
      final body = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
      expect(body['alreadyExists'], isTrue);
      expect((body['save'] as Map)['gold'], isNot(99999999));
    });

    test('망가진 세이브는 저장하지 않는다', () async {
      final h = handler(serverHasSave: false);
      final res = await post(h, '/state', {
        'save': {'schemaVersion': 'not-a-number'},
      }, token: makeToken());
      expect(res.statusCode, 400);
      expect(fake.lastSaved, isNull);
    });
  });

  group('수동 전투 엔드포인트', () {
    Handler withFoe() => handler(
      defenders: {
        'foe': [_defender(), _defender(), _defender()],
      },
    );

    Future<Map<String, dynamic>> start(Handler h, {String? token}) async {
      final res = await post(h, '/battle/manual/start', {
        'teamBugIds': ['mine-1'],
        'opponentUserId': 'foe',
      }, token: token ?? makeToken());
      return jsonDecode(await res.readAsString()) as Map<String, dynamic>;
    }

    test('인증 없이는 시작 불가', () async {
      final res = await post(handler(), '/battle/manual/start', {
        'teamBugIds': ['mine-1'],
        'opponentUserId': 'foe',
      });
      expect(res.statusCode, 401);
    });

    test('상대가 없으면 시작 불가', () async {
      final res = await post(handler(), '/battle/manual/start', {
        'teamBugIds': ['mine-1'],
        'opponentUserId': 'ghost',
      }, token: makeToken());
      expect(res.statusCode, 404);
    });

    test('내 곤충이 아니면 출전 불가', () async {
      final res = await post(withFoe(), '/battle/manual/start', {
        'teamBugIds': ['someone-elses-bug'],
        'opponentUserId': 'foe',
      }, token: makeToken());
      expect(res.statusCode, 400);
    });

    test('시작해도 시드는 주지 않는다 — 상대 수를 미리 계산하지 못하게', () async {
      final body = await start(withFoe());
      expect(body['sessionId'], isNotNull);
      expect(body['foe'], isNotEmpty);
      expect(body['energyA'], 1);
      // 시드가 새면 심리전이 무의미해진다.
      expect(body.containsKey('seed'), isFalse);
      expect(jsonEncode(body), isNot(contains('seed')));
    });

    test('한 수 진행하면 그 라운드 결과만 온다', () async {
      final h = withFoe();
      final sid = (await start(h))['sessionId'];
      final res = await post(h, '/battle/manual/step', {
        'sessionId': sid,
        'stance': 'attack',
      }, token: makeToken());
      expect(res.statusCode, 200);
      final body = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
      expect(body['round'], 1);
      // 연출에 필요한 이벤트가 통째로 와야 한다.
      final ev = body['event'] as Map<String, dynamic>;
      for (final k in ['aStance', 'bStance', 'aHp', 'bHp', 'healToA', 'rps']) {
        expect(ev.containsKey(k), isTrue, reason: '이벤트에 $k 가 없다');
      }
      expect(body['energyA'], isNotNull);
      // 미결착 라운드에 보상이 새면 안 된다.
      expect(body.containsKey('gold'), isFalse);
    });

    test('남의 세션은 진행시킬 수 없다', () async {
      final h = withFoe();
      final sid = (await start(h))['sessionId'];
      final res = await post(h, '/battle/manual/step', {
        'sessionId': sid,
        'stance': 'attack',
      }, token: makeToken(claims: _claimsFor('user-2')));
      expect(res.statusCode, 403);
    });

    test('없는 세션은 거부', () async {
      final res = await post(withFoe(), '/battle/manual/step', {
        'sessionId': 'nope',
        'stance': 'attack',
      }, token: makeToken());
      expect(res.statusCode, 404);
    });

    test('결착까지 진행하면 보상이 확정되고, 세션은 다시 못 돈다', () async {
      final h = withFoe();
      final sid = (await start(h))['sessionId'];

      Map<String, dynamic>? last;
      for (var i = 0; i < kMaxBattleRounds * 3 + 5; i++) {
        final res = await post(h, '/battle/manual/step', {
          'sessionId': sid,
          'stance': 'attack',
        }, token: makeToken());
        expect(res.statusCode, 200, reason: '${i + 1}수째에서 실패');
        last = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
        if (last['done'] == true) break;
      }
      expect(last, isNotNull);
      expect(last!['done'], isTrue);
      expect(last['outcome'], isNotNull);
      expect(last['gold'], isNotNull);
      expect(last['save'], isNotNull);
      expect(fake.lastSaved, isNotNull);

      // 끝난 세션을 또 돌려 보상을 두 번 받을 수 없다.
      final again = await post(h, '/battle/manual/step', {
        'sessionId': sid,
        'stance': 'attack',
      }, token: makeToken());
      expect(again.statusCode, 409);
    });
  });

  group('야생 상대', () {
    /// battle.json 의 첫 스카우트 티어 id.
    final tierId = gameConfig.battle.scoutTiers.first.id;

    test('티어 id 로만 받는다 — 임의 배율을 넣지 못하게', () async {
      final res = await post(handler(), '/battle', {
        'teamBugIds': ['mine-1'],
        'tierId': 'made-up-tier',
      }, token: makeToken());
      expect(res.statusCode, 400);
      expect(fake.lastSaved, isNull);
    });

    test('상대도 티어도 없으면 거부', () async {
      final res = await post(handler(), '/battle', {
        'teamBugIds': ['mine-1'],
      }, token: makeToken());
      expect(res.statusCode, 400);
    });

    test('야생 전투가 성립하고, 서버가 만든 상대를 돌려준다', () async {
      final res = await post(handler(), '/battle', {
        'teamBugIds': ['mine-1'],
        'tierId': tierId,
      }, token: makeToken());
      expect(res.statusCode, 200);
      final body = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
      expect(body['outcome'], isNotNull);
      expect(body['seed'], isNotNull);

      // 앱이 **서버가 싸운 그 상대**를 그리려면 종·스탯·기질이 다 필요하다.
      final foe = body['foe'] as List;
      expect(foe, hasLength(3));
      for (final f in foe.cast<Map<String, dynamic>>()) {
        for (final k in ['id', 'sp', 'el', 'tm', 'stance', 'hp', 'atk']) {
          expect(f.containsKey(k), isTrue, reason: '상대에 $k 가 없다');
        }
        expect(f['sp'], isNotEmpty, reason: '종 id 가 없으면 스프라이트를 못 그린다');
      }
    });

    test('내 곤충이 아니면 야생전도 불가', () async {
      final res = await post(handler(), '/battle', {
        'teamBugIds': ['someone-elses-bug'],
        'tierId': tierId,
      }, token: makeToken());
      expect(res.statusCode, 400);
      expect(fake.lastSaved, isNull);
    });

    test('성충이 없으면 야생 상대를 만들 수 없다', () async {
      final h = handler(serverHasSave: false);
      final res = await post(h, '/battle', {
        'teamBugIds': ['mine-1'],
        'tierId': tierId,
      }, token: makeToken());
      // 세이브가 없으면 409, 있으나 로스터가 비면 400 — 어느 쪽이든 전투는 없다.
      expect(res.statusCode, anyOf(400, 409));
      expect(fake.lastSaved, isNull);
    });

    test('수동 야생 전투도 서버가 상대를 만든다', () async {
      final h = handler();
      final res = await post(h, '/battle/manual/start', {
        'teamBugIds': ['mine-1'],
        'tierId': tierId,
      }, token: makeToken());
      expect(res.statusCode, 200);
      final body = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
      expect(body['sessionId'], isNotNull);
      expect(body['foe'], hasLength(3));
      expect((body['foe'] as List).first['sp'], isNotEmpty);
      // 여기서도 시드는 새면 안 된다.
      expect(jsonEncode(body), isNot(contains('seed')));
    });

    test('야생 티어마다 보상 배율이 다르게 적용된다', () async {
      final tiers = gameConfig.battle.scoutTiers;
      expect(tiers.length, greaterThan(1), reason: '티어가 하나뿐이면 검증 불가');

      final golds = <double>[];
      for (final t in [tiers.first, tiers.last]) {
        final res = await post(handler(), '/battle', {
          'teamBugIds': ['mine-1'],
          'tierId': t.id,
        }, token: makeToken());
        final b = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
        golds.add((b['gold'] as num).toDouble() / t.rewardMult);
      }
      // 배율을 걷어내면 같은 기준액이 나와야 한다(승패에 따라 0 일 수 있다).
      expect(
        golds.first == 0 || golds.last == 0 || golds.first == golds.last,
        isTrue,
      );
    });
  });

  group('돌파 엔드포인트', () {
    test('인증 없이는 시작 불가', () async {
      final res = await post(handler(), '/breakthrough', {'bugId': 'mine-1'});
      expect(res.statusCode, 401);
    });

    test('상한 미달이면 400 (mine-1 은 레벨 1)', () async {
      final res = await post(handler(), '/breakthrough', {
        'bugId': 'mine-1',
      }, token: makeToken());
      expect(res.statusCode, 400);
      final body = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
      expect(body['error'], 'cap_not_reached');
      expect(fake.lastSaved, isNull); // 실패 시 세이브를 건드리지 않는다
    });

    test('bugId 가 없으면 400', () async {
      final res = await post(
        handler(),
        '/breakthrough',
        {},
        token: makeToken(),
      );
      expect(res.statusCode, 400);
    });

    test('돌파 중이 아닌데 완료 요청하면 400', () async {
      final res = await post(handler(), '/breakthrough/complete', {
        'bugId': 'mine-1',
      }, token: makeToken());
      expect(res.statusCode, 400);
      final body = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
      expect(body['error'], 'not_breaking');
    });
  });

  group('보상 수령 엔드포인트', () {
    test('인증 없이는 미션 수령 불가', () async {
      final res = await post(handler(), '/mission/claim', {
        'missionId': 'hunt',
      });
      expect(res.statusCode, 401);
    });

    test('목표 미달 미션은 400 (mine 세이브는 진행도 0)', () async {
      final res = await post(handler(), '/mission/claim', {
        'missionId': 'hunt',
      }, token: makeToken());
      expect(res.statusCode, 400);
      final b = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
      expect(b['error'], 'goal_not_reached');
      expect(fake.lastSaved, isNull);
    });

    test('선물이 없으면 400', () async {
      final res = await post(handler(), '/gift/claim', {
        'giftId': 'nope',
      }, token: makeToken());
      expect(res.statusCode, 400);
    });

    test('일일보상 첫 수령은 성공하고 세이브가 바뀐다', () async {
      final res = await post(handler(), '/daily/claim', {
        'rewardId': 'lunch',
      }, token: makeToken());
      expect(res.statusCode, 200);
      final b = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
      expect(b['save'], isNotNull);
      expect(fake.lastSaved, isNotNull);
    });

    test('로드맵 수령은 스테이지 미달이면 빈 목록(200)', () async {
      final res = await post(
        handler(),
        '/roadmap/claim',
        {},
        token: makeToken(),
      );
      expect(res.statusCode, 200);
      final b = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
      expect(b['cleared'], isEmpty);
    });
  });

  group('세이브 업로드 엔드포인트(/save)', () {
    test('인증 없이는 불가', () async {
      final res = await post(handler(), '/save', {'save': mySave.toJson()});
      expect(res.statusCode, 401);
    });

    test('저장본이 없으면 409 (부트스트랩이 먼저)', () async {
      final res = await post(handler(serverHasSave: false), '/save', {
        'save': mySave.toJson(),
      }, token: makeToken());
      expect(res.statusCode, 409);
    });

    test('솔로 필드는 수용, 트로피 위조는 서버 값 유지', () async {
      final cheat = mySave.copyWith(gold: 12345, pvpTrophies: 999999);
      final res = await post(handler(), '/save', {
        'save': cheat.toJson(),
      }, token: makeToken());
      expect(res.statusCode, 200);
      final saved = SaveGame.fromJson(
        fake.lastSaved!['data'] as Map<String, dynamic>,
      );
      expect(saved.gold, 12345); // 솔로 필드 수용
      expect(saved.pvpTrophies, mySave.pvpTrophies); // 위조 무시
    });

    // ── 비용 회귀 방지(2026-07 장애) ──────────────────────────────
    // 13.6MB 세이브를 10초마다 왕복시켜 Cloud Run 요금이 폭증했다.
    // 아래 셋이 그 재발 경로를 각각 막는다.

    test('평시 응답에 세이브 전체를 싣지 않는다 — 왕복 이그레스 차단', () async {
      final res = await post(handler(), '/save', {
        'save': mySave.toJson(),
      }, token: makeToken());
      expect(res.statusCode, 200);
      final b = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
      expect(b['ok'], isTrue);
      expect(b.containsKey('save'), isFalse);
    });

    test('상한 초과 세이브는 서버가 잘라 저장하고, 클라가 채택하도록 돌려준다', () async {
      // 구버전 앱·조작된 업로드를 흉내낸다 — 클라 상한을 우회한 경우.
      final bloated = mySave.copyWith(
        bugs: [
          for (var i = 0; i < 500; i++)
            mySave.bugs.first.copyWith(id: 'bloat-$i'),
        ],
      );
      final res = await post(handler(), '/save', {
        'save': bloated.toJson(),
      }, token: makeToken());
      expect(res.statusCode, 200);

      final saved = SaveGame.fromJson(
        fake.lastSaved!['data'] as Map<String, dynamic>,
      );
      expect(saved.bugs, hasLength(kDefaultStorageCapacity));

      // clamped 여야 클라이언트가 잘린 세이브를 채택한다 — 아니면 다음 주기에
      // 다시 500마리를 올려 무한히 되풀이된다.
      final b = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
      expect(b['clamped'], isTrue);
      expect((b['save'] as Map)['bugs'], hasLength(kDefaultStorageCapacity));
    });

    test('칸 수 자체를 위조해도 설정 상한으로 잘린다', () async {
      final cheat = mySave.copyWith(storageCapacity: 999999);
      await post(handler(), '/save', {
        'save': cheat.toJson(),
      }, token: makeToken());
      final saved = SaveGame.fromJson(
        fake.lastSaved!['data'] as Map<String, dynamic>,
      );
      expect(saved.storageCapacity, gameConfig.pet.storageSlotsMax);
    });
  });

  group('공지 · 운영 우편 · 선물코드', () {
    Map<String, dynamic> mailRow({
      Object id = 1,
      int jelly = 100,
      int gold = 0,
      String? endsAt,
    }) => {
      'id': id,
      'title': '점검 보상',
      'body': '불편을 드려 죄송합니다',
      'gold': gold,
      'jelly': jelly,
      'chitin': 0,
      'mineral': 0,
      'sap': 0,
      'starts_at': null,
      'ends_at': endsAt,
      'created_at': _t.toIso8601String(),
    };

    Map<String, dynamic> codeRow(
      String code, {
      int jelly = 10,
      int gold = 0,
      int? maxUses,
      int used = 0,
      String? endsAt,
    }) => {
      'code': code,
      'gold': gold,
      'jelly': jelly,
      'chitin': 0,
      'mineral': 0,
      'sap': 0,
      'max_uses': maxUses,
      'used_count': used,
      'ends_at': endsAt,
    };

    test('인증 없이는 공지·우편·코드에 접근할 수 없다', () async {
      expect((await get(handler(), '/notices')).statusCode, 401);
      expect((await get(handler(), '/mail')).statusCode, 401);
      final r = await post(handler(), '/code/redeem', {'code': 'X'});
      expect(r.statusCode, 401);
    });

    test('기간이 지났거나 아직 시작 안 한 공지는 빠진다', () async {
      final h = handler(
        notices: [
          {'id': 1, 'title': '현재', 'body': '', 'pinned': true},
          {
            'id': 2,
            'title': '지난',
            'body': '',
            'ends_at': _t.subtract(const Duration(days: 1)).toIso8601String(),
          },
          {
            'id': 3,
            'title': '예약',
            'body': '',
            'starts_at': _t.add(const Duration(days: 1)).toIso8601String(),
          },
        ],
      );
      final res = await get(h, '/notices', token: makeToken());
      expect(res.statusCode, 200);
      final body = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
      expect((body['notices'] as List).map((e) => e['title']), ['현재']);
    });

    test('우편 수령: 재화가 지급되고 세이브가 저장된다', () async {
      final h = handler(mail: [mailRow()]);
      final res = await post(h, '/mail/claim', {'id': 1}, token: makeToken());
      expect(res.statusCode, 200);
      final b = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
      expect((b['granted'] as Map)['jelly'], 100);
      // 지급은 **서버가** 한다 — 앱이 더하면 골드 급증 상한에 걸린다.
      final saved = SaveGame.fromJson(
        fake.lastSaved!['data'] as Map<String, dynamic>,
      );
      expect(saved.materialCount(MaterialKind.jelly), 100);
    });

    test('같은 우편을 두 번 받을 수 없다', () async {
      final h = handler(mail: [mailRow()]);
      final first = await post(h, '/mail/claim', {'id': 1}, token: makeToken());
      expect(first.statusCode, 200);
      final second = await post(h, '/mail/claim', {
        'id': 1,
      }, token: makeToken());
      expect(second.statusCode, 404);
      expect(
        jsonDecode(await second.readAsString())['error'],
        'mail_not_found',
      );
    });

    test('기한이 지난 우편은 받을 수 없다', () async {
      final h = handler(
        mail: [
          mailRow(
            endsAt: _t.subtract(const Duration(days: 1)).toIso8601String(),
          ),
        ],
      );
      final res = await post(h, '/mail/claim', {'id': 1}, token: makeToken());
      expect(res.statusCode, 404);
    });

    test('선물코드: 대소문자·공백을 무시하고 지급한다', () async {
      final h = handler(
        codes: [codeRow('BUGCHAMP100', jelly: 100, gold: 50000)],
      );
      final res = await post(h, '/code/redeem', {
        'code': ' bugchamp100 ',
      }, token: makeToken());
      expect(res.statusCode, 200);
      final granted =
          (jsonDecode(await res.readAsString()) as Map)['granted'] as Map;
      expect(granted['jelly'], 100);
      expect(granted['gold'], 50000);
    });

    test('같은 코드 재사용은 거절 · 없는 코드는 404', () async {
      final h = handler(codes: [codeRow('ONCE')]);
      final first = await post(h, '/code/redeem', {
        'code': 'ONCE',
      }, token: makeToken());
      expect(first.statusCode, 200);
      final again = await post(h, '/code/redeem', {
        'code': 'ONCE',
      }, token: makeToken());
      expect(again.statusCode, 409);
      expect(
        jsonDecode(await again.readAsString())['error'],
        'code_already_used',
      );
      final nope = await post(h, '/code/redeem', {
        'code': 'NOPE',
      }, token: makeToken());
      expect(nope.statusCode, 404);
    });

    test('만료·소진된 코드는 거절된다', () async {
      final h = handler(
        codes: [
          codeRow(
            'OLD',
            endsAt: _t.subtract(const Duration(days: 1)).toIso8601String(),
          ),
          codeRow('FULL', maxUses: 5, used: 5),
        ],
      );
      final old = await post(h, '/code/redeem', {
        'code': 'OLD',
      }, token: makeToken());
      expect(old.statusCode, 410);
      final full = await post(h, '/code/redeem', {
        'code': 'FULL',
      }, token: makeToken());
      expect(full.statusCode, 409);
    });

    test('음수 보상은 무시된다 — 운영 실수로 재화를 뺏지 않는다', () async {
      final h = handler(mail: [mailRow(jelly: -50, gold: -1000)]);
      final res = await post(h, '/mail/claim', {'id': 1}, token: makeToken());
      expect(res.statusCode, 200);
      final saved = SaveGame.fromJson(
        fake.lastSaved!['data'] as Map<String, dynamic>,
      );
      expect(saved.gold, mySave.gold);
      expect(saved.materialCount(MaterialKind.jelly), 0);
    });
  });

  group('운영 관리 패널(/admin)', () {
    const key = 'test-admin-key-0123456789';

    Handler adminHandler({String? withKey = key}) {
      fake = _Fake({'user-1': mySave.toJson()});
      return buildHandler(
        config: ServerConfig(
          supabaseUrl: _url,
          serviceRoleKey: 'service-role',
          anonKey: 'anon',
        ),
        store: StateStore(
          supabaseUrl: _url,
          serviceRoleKey: 'service-role',
          client: fake,
        ),
        jwtVerifier: verifierFor(signingKey),
        gameConfig: gameConfig,
        speciesById: {'a': species},
        clock: () => _t,
        adminKey: withKey,
      );
    }

    Future<Response> adminPost(
      Handler h,
      String path,
      Object body, {
      String? k = key,
    }) async => h(
      Request(
        'POST',
        Uri.parse('http://localhost$path'),
        headers: {
          if (k != null) 'x-admin-key': k,
          'content-type': 'application/json',
        },
        body: jsonEncode(body),
      ),
    );

    test('패널 HTML 은 키 없이 열린다(로그인 폼이므로)', () async {
      final res = await get(adminHandler(), '/admin');
      expect(res.statusCode, 200);
      expect(await res.readAsString(), contains('ADMIN KEY'));
    });

    test('키가 없거나 틀리면 데이터에 못 닿는다', () async {
      final h = adminHandler();
      final noKey = await h(
        Request('GET', Uri.parse('http://localhost/admin/data')),
      );
      expect(noKey.statusCode, 401);
      final wrong = await adminPost(h, '/admin/notice', {
        'title': 'x',
      }, k: 'wrong-key-wrong-key-wrong');
      expect(wrong.statusCode, 401);
    });

    test('시크릿에 딸려온 BOM·줄바꿈이 있어도 로그인된다', () async {
      // PowerShell 로 시크릿을 만들면 값 앞뒤에 BOM·CRLF 가 붙는다.
      // 실제로 40자 키가 46바이트로 저장돼 계속 "키가 올바르지 않다"가 났다.
      final bom = String.fromCharCode(0xFEFF);
      final h = adminHandler(withKey: '$bom$key\r\n');
      final res = await adminPost(h, '/admin/notice', {'title': '공백 테스트'});
      expect(res.statusCode, 200);
      // 붙여넣기에 딸려온 공백도 통과해야 한다.
      final pasted = await adminPost(h, '/admin/notice', {
        'title': '공백 테스트2',
      }, k: '  $key ');
      expect(pasted.statusCode, 200);
    });

    test('ADMIN_KEY 가 비어 있으면 패널이 아예 잠긴다', () async {
      // 환경변수를 깜빡한 배포가 재화를 뿌릴 수 있는 문을 열어두면 안 된다.
      final h = adminHandler(withKey: '');
      final res = await adminPost(h, '/admin/mail', {
        'title': '보상',
        'jelly': 100,
      }, k: '');
      expect(res.statusCode, 401);
    });

    test('공지 등록 — 제목이 없으면 거절', () async {
      final h = adminHandler();
      expect(
        (await adminPost(h, '/admin/notice', {'body': '본문만'})).statusCode,
        400,
      );
      final ok = await adminPost(h, '/admin/notice', {
        'title': '점검 안내',
        'body': '오늘 밤 점검합니다',
        'pinned': true,
      });
      expect(ok.statusCode, 200);
      expect(fake.lastSaved!['title'], '점검 안내');
      expect(fake.lastSaved!['pinned'], true);
    });

    test('전체 발송 우편 — user_id 가 null 로 들어간다', () async {
      final h = adminHandler();
      final res = await adminPost(h, '/admin/mail', {
        'title': '점검 보상',
        'jelly': 100,
        'gold': 50000,
      });
      expect(res.statusCode, 200);
      expect(fake.lastSaved!['user_id'], isNull); // null = 전체 대상
      expect(fake.lastSaved!['jelly'], 100);
    });

    test('상한을 넘는 지급은 거절한다 — 오타 한 번으로 뿌리지 않게', () async {
      final h = adminHandler();
      final tooMuch = await adminPost(h, '/admin/mail', {
        'title': '실수',
        'jelly': 1000000,
      });
      expect(tooMuch.statusCode, 400);
      expect(
        jsonDecode(await tooMuch.readAsString())['error'],
        'jelly_too_large',
      );
      expect(fake.lastSaved, isNull); // 저장 자체가 없었다
    });

    test('음수 지급은 0으로 — 운영 실수로 재화를 뺏지 않는다', () async {
      final h = adminHandler();
      final res = await adminPost(h, '/admin/mail', {
        'title': '음수',
        'gold': -5000,
        'jelly': -1,
      });
      expect(res.statusCode, 200);
      expect(fake.lastSaved!['gold'], 0);
      expect(fake.lastSaved!['jelly'], 0);
    });

    test('선물코드 — 형식이 틀리면 거절, 맞으면 대문자로 저장', () async {
      final h = adminHandler();
      for (final bad in ['ab', '한글코드', 'has space', 'lower-case!']) {
        final res = await adminPost(h, '/admin/code', {'code': bad});
        expect(res.statusCode, 400, reason: bad);
      }
      final ok = await adminPost(h, '/admin/code', {
        'code': 'summer2026',
        'jelly': 50,
        'maxUses': 100,
      });
      expect(ok.statusCode, 200);
      expect(fake.lastSaved!['code'], 'SUMMER2026');
      expect(fake.lastSaved!['max_uses'], 100);
    });

    test('삭제 — 알 수 없는 종류는 거절', () async {
      final h = adminHandler();
      expect(
        (await adminPost(h, '/admin/delete', {
          'kind': 'saves',
          'id': 'user-1',
        })).statusCode,
        400,
      );
      expect(
        (await adminPost(h, '/admin/delete', {
          'kind': 'notice',
          'id': '1',
        })).statusCode,
        200,
      );
    });
  });

  group('요청 크기 가드', () {
    test('상한을 넘는 본문은 읽기 전에 413 — DB 까지 가지 않는다', () async {
      final huge = 'x' * (kMaxRequestBytes + 1024);
      final res = await handler()(
        Request(
          'POST',
          Uri.parse('http://localhost/save'),
          headers: {
            'authorization': 'Bearer ${makeToken()}',
            'content-type': 'application/json',
          },
          body: jsonEncode({'blob': huge}),
        ),
      );
      expect(res.statusCode, 413);
      expect(fake.lastSaved, isNull);
    });

    test('정상 크기 요청은 통과한다', () async {
      final res = await post(handler(), '/save', {
        'save': mySave.toJson(),
      }, token: makeToken());
      expect(res.statusCode, 200);
    });
  });
}
