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
  _Fake(this.saves, {this.defenders = const {}});

  final Map<String, Map<String, dynamic>> saves;
  final Map<String, List<Map<String, dynamic>>> defenders;

  /// 마지막으로 저장된 행 — "세이브를 건드렸는가"를 확인하는 데 쓴다.
  Map<String, dynamic>? lastSaved;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.method == 'POST') {
      final raw = await request.finalize().bytesToString();
      lastSaved = (jsonDecode(raw) as List).first as Map<String, dynamic>;
      return http.StreamedResponse(Stream.value(utf8.encode('[]')), 201);
    }
    final id = request.url.queryParameters['id']?.replaceFirst('eq.', '');
    final Object body;
    if (request.url.path.contains('/defenders')) {
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
  final gameConfig = GameConfig(
    iap: IapConfig.fromJson(_readJson('iap.json')),
    battle: BattleConfig.fromJson(_readJson('battle.json')),
    run: RunConfig.fromJson(_readJson('run_config.json')),
    pet: PetConfig.fromJson(_readJson('pets.json')),
  );

  final species = Species.fromJson({
    'id': 'a',
    'name': {'ko': '테스트벌레', 'en': 'T', 'ja': 'T'},
    'grade': 'common',
    'specialty': 'strike',
    'baseStats': {'hp': 100, 'atk': 40, 'def': 30, 'spd': 20},
    'sizeMinMm': 20,
    'sizeMaxMm': 60,
  });

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
  }) {
    fake = _Fake({'user-1': mySave.toJson()}, defenders: defenders);
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
}
