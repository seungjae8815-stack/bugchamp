import 'dart:convert';
import 'dart:io' show stderr;

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';
import 'package:core_save/core_save.dart';

import 'actions.dart';
import 'auth.dart';
import 'game_config.dart';
import 'state_store.dart';
import 'verifier.dart';

/// 서버 설정. 전부 환경변수에서 온다 — 코드·저장소에 비밀을 두지 않는다.
class ServerConfig {
  ServerConfig({
    required this.supabaseUrl,
    required this.serviceRoleKey,
    required this.anonKey,
  });

  final String supabaseUrl;
  final String serviceRoleKey;

  /// Edge Function 호출용(공개값).
  final String anonKey;

  /// JWT 발급자 — 프로젝트 URL 로부터 유도한다.
  String get issuer => '$supabaseUrl/auth/v1';

  /// 환경변수에서 읽는다. 하나라도 없으면 예외(조용히 뜨는 것보다 낫다).
  factory ServerConfig.fromEnv(Map<String, String> env) {
    String need(String k) {
      final v = env[k];
      if (v == null || v.isEmpty) {
        throw StateError('환경변수 $k 가 없습니다');
      }
      return v;
    }

    // JWT 시크릿은 필요 없다 — 비대칭(ES256) 서명이라 공개키(JWKS)로 검증한다.
    return ServerConfig(
      supabaseUrl: need('SUPABASE_URL'),
      serviceRoleKey: need('SUPABASE_SERVICE_ROLE_KEY'),
      anonKey: need('SUPABASE_ANON_KEY'),
    );
  }
}

/// 요청 컨텍스트에 담긴 인증 사용자 키.
const _userKey = 'authedUser';

/// 인증 미들웨어 — 통과하지 못하면 401. 세부 사유는 응답에 담지 않는다
/// (공격자에게 어디까지 맞았는지 알려주지 않기 위해).
Middleware requireAuth(SupabaseJwtVerifier verifier) {
  return (Handler inner) {
    return (Request req) async {
      final result = await verifier.verifyHeader(req.headers['authorization']);
      if (!result.isOk) {
        return Response.unauthorized(
          jsonEncode({'error': 'unauthorized'}),
          headers: {'content-type': 'application/json'},
        );
      }
      return inner(req.change(context: {_userKey: result.user!}));
    };
  };
}

AuthedUser userOf(Request req) => req.context[_userKey]! as AuthedUser;

/// 원 요청의 Bearer 토큰(Edge Function 에 그대로 전달할 용도).
String _jwtOf(Request req) =>
    (req.headers['authorization'] ?? '').replaceFirst('Bearer ', '').trim();

Response _json(Map<String, dynamic> body, {int status = 200}) => Response(
  status,
  body: jsonEncode(body),
  headers: {'content-type': 'application/json'},
);

/// 라우터 구성.
Handler buildHandler({
  required ServerConfig config,
  required StateStore store,

  /// 테스트에서 가짜 키셋을 주입하기 위한 훅. 운영에서는 null.
  SupabaseJwtVerifier? jwtVerifier,

  /// 게임 데이터·액션. 없으면 쓰기 엔드포인트가 노출되지 않는다(읽기 전용).
  GameConfig? gameConfig,
  Map<String, Species>? speciesById,
  ReceiptVerifier? receiptVerifier,
  DateTime Function()? clock,
}) {
  final verifier =
      jwtVerifier ?? SupabaseJwtVerifier.forProject(config.supabaseUrl);

  final public = Router()
    // Cloud Run 헬스체크 — 인증 없이 접근 가능해야 한다.
    ..get('/healthz', (Request _) => Response.ok('ok'));

  final authed = Router()
    ..get('/state', (Request req) async {
      final user = userOf(req);
      try {
        final data = await store.load(user.id);
        return _json({
          'userId': user.id,
          'isAnonymous': user.isAnonymous,
          // 신규 유저면 null — P2 에서 서버가 초기 상태를 생성하도록 옮긴다.
          'save': data,
          'serverTime': DateTime.now().toUtc().toIso8601String(),
        });
      } on StateStoreException catch (e) {
        // 세부 내용은 서버 로그에만. 클라이언트에는 일반화된 메시지.
        stderr.writeln('[state] ${user.id}: $e');
        return _json({'error': 'store_unavailable'}, status: 503);
      }
    });

  // 쓰기 액션 — 게임 설정이 주입된 경우에만 노출한다.
  if (gameConfig != null && speciesById != null) {
    // 클로저 안에서 널 승격이 유지되도록 지역 변수로 고정한다.
    final cfg = gameConfig;
    final species = speciesById;
    final actions = GameActions(
      config: cfg,
      now: clock ?? () => DateTime.now().toUtc(),
    );
    final verifier =
        receiptVerifier ?? const FixedVerifier(VerifyVerdict.unknown);

    Future<SaveGame?> loadSave(String uid) async {
      final raw = await store.load(uid);
      if (raw == null) return null;
      return SaveGame.fromJson(migrateToCurrent(raw));
    }

    authed.post('/purchase', (Request req) async {
      final user = userOf(req);
      final Map<String, dynamic> body;
      try {
        body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      } catch (_) {
        return _json({'error': 'bad_request'}, status: 400);
      }
      final productId = body['productId']?.toString() ?? '';
      final token = body['purchaseToken']?.toString() ?? '';
      if (productId.isEmpty || token.isEmpty) {
        return _json({'error': 'bad_request'}, status: 400);
      }

      // 1) 영수증부터 검증 — 통과 못 하면 세이브를 건드리지 않는다.
      final verdict = await verifier.verify(
        productId: productId,
        purchaseToken: token,
        userJwt: _jwtOf(req),
      );
      if (verdict == VerifyVerdict.invalid) {
        return _json({'error': 'invalid_receipt'}, status: 402);
      }
      if (verdict == VerifyVerdict.unknown) {
        // 판정 불가 — 지급하지 않고 클라이언트가 재시도하게 둔다.
        return _json({'error': 'verification_unavailable'}, status: 503);
      }

      try {
        final save = await loadSave(user.id);
        if (save == null) return _json({'error': 'no_save'}, status: 409);
        // 영수증 토큰 자체를 지급 식별자로 쓴다 — 재요청해도 멱등.
        final r = actions.grantPurchase(
          save,
          productId: productId,
          purchaseId: token,
        );
        if (!r.isOk) return _json({'error': r.error}, status: r.status);
        await store.save(user.id, r.save!.toJson());
        return _json({'save': r.save!.toJson(), ...r.extra});
      } on StateStoreException catch (e) {
        stderr.writeln('[purchase] ${user.id}: $e');
        return _json({'error': 'store_unavailable'}, status: 503);
      }
    });

    authed.post('/battle', (Request req) async {
      final user = userOf(req);
      final Map<String, dynamic> body;
      try {
        body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      } catch (_) {
        return _json({'error': 'bad_request'}, status: 400);
      }
      final teamIds = [
        for (final id in (body['teamBugIds'] as List? ?? const []))
          id.toString(),
      ];
      final opponentId = body['opponentUserId']?.toString() ?? '';
      if (teamIds.isEmpty || opponentId.isEmpty) {
        return _json({'error': 'bad_request'}, status: 400);
      }

      try {
        final save = await loadSave(user.id);
        if (save == null) return _json({'error': 'no_save'}, status: 409);

        // 상대 팀은 **서버가 직접 읽는다** — 클라가 보낸 스탯을 쓰면
        // 약한 상대를 만들어 트로피를 쓸어담을 수 있다.
        final rows = await store.loadDefenderTeam(opponentId);
        if (rows == null || rows.isEmpty) {
          return _json({'error': 'opponent_not_found'}, status: 404);
        }
        final foe = <BattleBug>[];
        for (var i = 0; i < rows.length; i++) {
          final d = rows[i];
          final sp = species[d['sp']?.toString() ?? ''];
          foe.add(
            BattleBug(
              id: 'foe-$i',
              name: sp?.name.resolve('ko') ?? '상대',
              element: Element.fromKey(d['el']?.toString() ?? 'wood'),
              temperament: Temperament.fromKey(
                d['tm']?.toString() ?? 'steadfast',
              ),
              preferredStance: sp == null
                  ? Stance.attack
                  : preferredStanceOf(sp.specialty),
              maxHp: (d['hp'] as num?)?.toDouble() ?? 100,
              atk: (d['atk'] as num?)?.toDouble() ?? 10,
              def: (d['def'] as num?)?.toDouble() ?? 10,
              spd: (d['spd'] as num?)?.toDouble() ?? 10,
            ),
          );
        }

        // 시드는 **서버가 정한다** — 클라가 유리한 시드를 고르지 못하게.
        final seed = DateTime.now().microsecondsSinceEpoch & 0x7fffffff;
        final r = actions.runBattle(
          save,
          myTeamBugIds: teamIds,
          foeTeam: foe,
          location: foe.first.element,
          seed: seed,
          rewardMult: 1.0,
          speciesById: species,
          petConfig: cfg.pet,
        );
        if (!r.isOk) return _json({'error': r.error}, status: r.status);
        await store.save(user.id, r.save!.toJson());
        return _json({'save': r.save!.toJson(), ...r.extra});
      } on StateStoreException catch (e) {
        stderr.writeln('[battle] ${user.id}: $e');
        return _json({'error': 'store_unavailable'}, status: 503);
      }
    });
  }

  final cascade = Cascade()
      .add(public.call)
      .add(
        const Pipeline()
            .addMiddleware(requireAuth(verifier))
            .addHandler(authed.call),
      );

  return const Pipeline()
      .addMiddleware(logRequests())
      .addHandler(cascade.handler);
}
