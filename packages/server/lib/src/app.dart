import 'dart:convert';
import 'dart:math';
import 'dart:io' show Platform, stderr;

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';

import 'actions.dart';
import 'admin_page.dart';
import 'auth.dart';
import 'battle_session.dart';
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

/// 저장된 방어팀 스냅샷 → 전투 유닛.
BattleBug _defenderToBattleBug(
  Map<String, dynamic> d,
  int index,
  Map<String, Species> speciesById,
) {
  final sp = speciesById[d['sp']?.toString() ?? ''];
  return BattleBug(
    id: 'foe-$index',
    name: sp?.name.resolve('ko') ?? '상대',
    element: Element.fromKey(d['el']?.toString() ?? 'wood'),
    temperament: Temperament.fromKey(d['tm']?.toString() ?? 'steadfast'),
    preferredStance: sp == null
        ? Stance.attack
        : preferredStanceOf(sp.specialty),
    maxHp: (d['hp'] as num?)?.toDouble() ?? 100,
    atk: (d['atk'] as num?)?.toDouble() ?? 10,
    def: (d['def'] as num?)?.toDouble() ?? 10,
    spd: (d['spd'] as num?)?.toDouble() ?? 10,
  );
}

/// 상대 1마리 직렬화 — 앱이 **서버가 싸운 것과 똑같은 상대**를 그려야 한다.
/// 야생은 서버가 만들므로 앱이 따로 만들면 연출과 결과가 갈린다.
/// 상대 1마리의 표시 정보. [skin] 은 그 유저가 산 스킨 효과 키.
///
/// 스킨은 남이 봐야 사고 싶어진다(2026-08-19) — 그림에만 쓰는 값이라
/// 전투 계산에는 일절 들어가지 않는다.
Map<String, dynamic> _foeJson(BattleBug b, String speciesId, {String? skin}) =>
    {
      'id': b.id,
      'sp': speciesId,
      if (skin != null) 'skin': skin,
      'name': b.name,
      'el': b.element.key,
      'tm': b.temperament.key,
      'stance': b.preferredStance.name,
      'hp': b.maxHp,
      'atk': b.atk,
      'def': b.def,
      'spd': b.spd,
    };

/// 방어팀 행의 스킨 효과 키(`gold`/`albino`). 없으면 null.
///
/// 앱이 등록할 때 실어 보낸 값을 그대로 돌려준다 — **그림에만 쓴다.**
/// 클라가 주장하는 값이라 위조할 수 있지만 이득이 0 이라 위조할 이유가 없다.
String? _defenderSkin(Map<String, dynamic> d) => d['skin']?.toString();

/// 세션 id — 추측 불가능해야 한다(남의 세션을 찍어보지 못하게).
String _newSessionId() {
  final r = Random.secure();
  return List<int>.generate(
    16,
    (_) => r.nextInt(256),
  ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

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

  /// 운영 패널 키. 생략하면 환경변수 `ADMIN_KEY`(운영), 비어 있으면 패널 잠김.
  String? adminKey,

  /// 운영자 채팅을 보낼 계정 uuid. 생략하면 환경변수 `ADMIN_CHAT_USER_ID`.
  String? adminChatUserId,
}) {
  final verifier =
      jwtVerifier ?? SupabaseJwtVerifier.forProject(config.supabaseUrl);

  final public = Router()
    // 헬스체크 — 인증 없이 접근 가능해야 한다.
    //
    // ⚠️ `/healthz` 를 쓰면 안 된다. Google Cloud 인프라가 그 경로를
    //    가로채서 컨테이너까지 요청이 오지 않는다(실제로 404 를 받았다).
    ..get('/health', (Request _) => Response.ok('ok'))
    // 운영 관리 패널(HTML). 여기서는 **키를 요구하지 않는다** — 로그인 폼일
    // 뿐이고, 데이터에 닿는 /admin/* 요청이 키를 검사한다.
    ..get(
      '/admin',
      (Request _) => Response.ok(
        adminHtml,
        headers: {'content-type': 'text/html; charset=utf-8'},
      ),
    )
    // 앱 버전 안내 — **인증 없이**(앱이 시작 즉시, 로그인 전에도 확인).
    //   min    = 이 미만이면 강제 업데이트(막힘). 서버 규약이 깨질 때 올린다.
    //   latest = 이 미만이면 권장 업데이트(닫기 가능).
    // 값은 Cloud Run 환경변수로 관리 → 재배포 없이 gcloud run update 로 바꾼다.
    ..get('/version', (Request req) {
      int env(String k) => int.tryParse(Platform.environment[k] ?? '') ?? 0;
      // 스토어 심사 통과 시점이 플랫폼마다 다르다. 한쪽만 출시됐는데 양쪽에
      // 업데이트를 권하면 아직 못 받는 쪽은 **없는 업데이트**를 안내받는다.
      // 앱이 `?platform=ios|android` 를 보내면 그쪽 값을 쓰고, 없거나 값이
      // 설정되지 않았으면 공용 값으로 떨어진다(구버전 앱 호환).
      final p = req.url.queryParameters['platform']?.toUpperCase();
      int forPlatform(String base) {
        if (p == 'IOS' || p == 'ANDROID') {
          final v = env('${base}_$p');
          if (v > 0) return v;
        }
        return env(base);
      }

      return _json({
        'min': forPlatform('MIN_SUPPORTED_VERSION'),
        'latest': forPlatform('LATEST_VERSION'),
        // 점검 모드 — 앱이 "점검 중" 화면을 띄우고 입장을 막는다. 재배포 없이
        // `gcloud run services update --update-env-vars MAINTENANCE=1` 로 켜고
        // `MAINTENANCE=0`(또는 제거)으로 끈다.
        'maintenance': Platform.environment['MAINTENANCE'] == '1',
      });
    });

  final authed = Router()
    ..get('/state', (Request req) async {
      final user = userOf(req);
      try {
        final data = await store.load(user.id);
        return _json({
          'userId': user.id,
          'isAnonymous': user.isAnonymous,
          // 신규 유저면 null — 클라이언트가 최초 1회 업로드하거나,
          // 쓰기 액션이 들어올 때 서버가 만든다(loadOrCreate).
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

    /// 서버 세이브를 읽는다. 없으면 null.
    ///
    /// ⚠️ **없다고 해서 빈 세이브를 만들면 안 된다.** 로컬에 진행도가 있는
    /// 유저가 그 빈 세이브를 채택하면 게임이 통째로 날아간다.
    /// 서버 세이브 생성은 오직 `POST /state`(부트스트랩) 한 곳에서만 한다.
    Future<SaveGame?> loadSave(String uid) async {
      final raw = await store.load(uid);
      if (raw == null) return null;
      return SaveGame.fromJson(migrateToCurrent(raw));
    }

    /// 최초 1회 세이브 업로드(로컬 → 서버 이관).
    ///
    /// **이미 서버 세이브가 있으면 거부한다(409).** 허용하면 클라이언트가
    /// 아무 상태나 밀어넣을 수 있어 서버 권위가 무너진다. 그때는 서버 것을
    /// 돌려주고 앱이 그걸 채택하게 한다.
    authed.post('/state', (Request req) async {
      final user = userOf(req);
      try {
        final existing = await store.load(user.id);
        if (existing != null) {
          return _json({'save': existing, 'alreadyExists': true}, status: 409);
        }
        final body = jsonDecode(await req.readAsString());
        if (body is! Map<String, dynamic>) {
          return _json({'error': 'bad_request'}, status: 400);
        }
        final incoming = body['save'];
        if (incoming is! Map<String, dynamic>) {
          return _json({'error': 'bad_request'}, status: 400);
        }
        // 보호 필드(트로피·IAP)를 초기값으로 리셋 후 파싱 — 부트스트랩으로
        // 랭킹·결제 상태를 위조하지 못하게(솔로 진행은 그대로).
        final sanitized = actions.sanitizeBootstrap(migrateToCurrent(incoming));
        // 부트스트랩은 mergeSave 를 거치지 않으므로 채집함 상한을 여기서도
        // 강제한다 — 안 그러면 비대한 세이브를 새 계정으로 올려 되살릴 수 있다.
        final save = actions.enforceStorage(SaveGame.fromJson(sanitized));
        await store.save(user.id, save.toJson());
        return _json({'save': save.toJson(), 'bootstrapped': true});
      } on StateStoreException catch (e) {
        stderr.writeln('[bootstrap] ${user.id}: $e');
        return _json({'error': 'store_unavailable'}, status: 503);
      } catch (e) {
        stderr.writeln('[bootstrap] ${user.id} 파싱 실패: $e');
        return _json({'error': 'bad_save'}, status: 400);
      }
    });

    /// 기기 권위 세이브 업로드(주기 저장).
    ///
    /// 솔로 루프(업그레이드·재화·육성·방치·수령)는 기기가 확정하고 몇 초마다
    /// 여기로 올린다. 서버는 **트로피·IAP 지급물을 자기 값으로 덮고**(위조 차단),
    /// 골드 급증을 상식 상한으로 자른 뒤 저장한다. PvP·결제는 별도 액션이 확정.
    ///
    /// 저장본이 없으면 409 — 최초 이관은 `POST /state`(부트스트랩)가 먼저다.
    authed.post('/save', (Request req) async {
      final user = userOf(req);
      final Map<String, dynamic> body;
      try {
        body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      } catch (_) {
        return _json({'error': 'bad_request'}, status: 400);
      }
      final incoming = body['save'];
      if (incoming is! Map<String, dynamic>) {
        return _json({'error': 'bad_request'}, status: 400);
      }
      try {
        final stored = await loadSave(user.id);
        if (stored == null) return _json({'error': 'no_save'}, status: 409);
        var r = actions.mergeSave(stored, migrateToCurrent(incoming));
        if (!r.isOk) return _json({'error': r.error}, status: r.status);

        // 끝난 회차의 대회 보상을 여기서 지급한다. **`/event` 가 아니다** —
        // 그쪽은 대회가 닫히면 404 라 끝난 뒤엔 호출되지 않는다.
        // 순위 조회(RPC)는 **받을 게 있는 사람만** 타므로 회차당 1인 1회다.
        final dueRound = actions.eventRewardDueRound(r.save!);
        if (dueRound != null) {
          final placed = await store.eventRankOf(dueRound, user.id);
          final granted = actions.grantEventReward(
            r.save!,
            dueRound,
            placed?.rank,
          );
          if (granted.isOk) {
            r = ActionResult.ok(
              granted.save,
              extra: {...r.extra, ...granted.extra},
            );
            // 대표 뱃지를 순위표(profiles)에 싣는다. 실패해도 보상 지급은
            // 되돌리지 않는다 — 뱃지는 표시용이고 재화가 더 중요하다.
            final badge = (granted.extra['eventReward'] as Map?)?['badge'];
            if (badge is String && badge.isNotEmpty) {
              try {
                await store.setBadge(user.id, badge);
              } on StateStoreException catch (e) {
                stderr.writeln('[save] badge 저장 실패 ${user.id}: $e');
              }
            }
          }
        }

        await store.save(user.id, r.save!.toJson());
        // ⚠️ 세이브 전체를 되돌려주지 않는다. 이 엔드포인트는 주기 업로드라
        // 호출이 잦은데, 응답까지 세이브 통째면 왕복마다 세이브 크기 × 2 의
        // 이그레스가 나간다(과거 14MB 응답 × 수천 회 = 요금 대부분).
        // 클라이언트는 `clamped`·`season` 일 때만 서버 값을 채택하므로
        // 그때만 실어준다. 시즌 정산은 **주 1회**라 이그레스에 영향이 없다.
        // 대회 보상도 세이브를 바꾸므로 함께 채택시킨다(회차당 1회라
        // 이그레스에 영향이 없다 — 시즌 정산과 같은 이유).
        final adopt =
            r.extra['clamped'] == true ||
            r.extra['season'] == true ||
            r.extra['eventReward'] != null;
        return _json({
          'ok': true,
          ...r.extra,
          if (adopt) 'save': r.save!.toJson(),
        });
      } on StateStoreException catch (e) {
        stderr.writeln('[save] ${user.id}: $e');
        return _json({'error': 'store_unavailable'}, status: 503);
      }
    });

    /// 방치 수입 정산. 클라이언트는 "정산해줘"만 보내고 금액은 서버가 정한다.
    authed.post('/sync', (Request req) async {
      final user = userOf(req);
      try {
        final save = await loadSave(user.id);
        if (save == null) return _json({'error': 'no_save'}, status: 409);
        final r = actions.sync(save);
        if (!r.isOk) return _json({'error': r.error}, status: r.status);
        await store.save(user.id, r.save!.toJson());
        return _json({'save': r.save!.toJson(), ...r.extra});
      } on StateStoreException catch (e) {
        stderr.writeln('[sync] ${user.id}: $e');
        return _json({'error': 'store_unavailable'}, status: 503);
      }
    });

    /// 업그레이드 1단계. 비용·잔액 판정은 서버가 한다.
    authed.post('/upgrade', (Request req) async {
      final user = userOf(req);
      final Map<String, dynamic> body;
      try {
        body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      } catch (_) {
        return _json({'error': 'bad_request'}, status: 400);
      }
      final kindKey = body['kind']?.toString() ?? '';
      final kind = UpgradeKind.values
          .where((k) => k.key == kindKey)
          .firstOrNull;
      if (kind == null) return _json({'error': 'unknown_upgrade'}, status: 400);

      try {
        final save = await loadSave(user.id);
        if (save == null) return _json({'error': 'no_save'}, status: 409);
        final count = (body['count'] as num?)?.toInt() ?? 1;
        final r = actions.upgrade(save, kind, count: count);
        if (!r.isOk) return _json({'error': r.error}, status: r.status);
        await store.save(user.id, r.save!.toJson());
        return _json({'save': r.save!.toJson(), ...r.extra});
      } on StateStoreException catch (e) {
        stderr.writeln('[upgrade] ${user.id}: $e');
        return _json({'error': 'store_unavailable'}, status: 503);
      }
    });

    /// 부위 강화 — 재료 비용·상한을 서버가 판정.
    authed.post('/enhance', (Request req) async {
      final user = userOf(req);
      final enh = cfg.enhance;
      if (enh == null) return _json({'error': 'not_configured'}, status: 503);
      final Map<String, dynamic> body;
      try {
        body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      } catch (_) {
        return _json({'error': 'bad_request'}, status: 400);
      }
      final bugId = body['bugId']?.toString() ?? '';
      final part = BugPart.values
          .where((p) => p.key == (body['part']?.toString() ?? ''))
          .firstOrNull;
      if (bugId.isEmpty || part == null) {
        return _json({'error': 'bad_request'}, status: 400);
      }
      try {
        final save = await loadSave(user.id);
        if (save == null) return _json({'error': 'no_save'}, status: 409);
        final r = actions.enhancePart(save, bugId, part, enhance: enh);
        if (!r.isOk) return _json({'error': r.error}, status: r.status);
        await store.save(user.id, r.save!.toJson());
        return _json({'save': r.save!.toJson(), ...r.extra});
      } on StateStoreException catch (e) {
        stderr.writeln('[enhance] ${user.id}: $e');
        return _json({'error': 'store_unavailable'}, status: 503);
      }
    });

    /// 수련(성충 레벨업) — 골드 비용·상한을 서버가 판정.
    authed.post('/train', (Request req) async {
      final user = userOf(req);
      final Map<String, dynamic> body;
      try {
        body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      } catch (_) {
        return _json({'error': 'bad_request'}, status: 400);
      }
      final bugId = body['bugId']?.toString() ?? '';
      if (bugId.isEmpty) return _json({'error': 'bad_request'}, status: 400);
      try {
        final save = await loadSave(user.id);
        if (save == null) return _json({'error': 'no_save'}, status: 409);
        final r = actions.trainBug(save, bugId, petConfig: cfg.pet);
        if (!r.isOk) return _json({'error': r.error}, status: r.status);
        await store.save(user.id, r.save!.toJson());
        return _json({'save': r.save!.toJson(), ...r.extra});
      } on StateStoreException catch (e) {
        stderr.writeln('[train] ${user.id}: $e');
        return _json({'error': 'store_unavailable'}, status: 503);
      }
    });

    /// 돌파 시작 — 레벨 상한을 올린다(재화 소비 + 타이머). 스탯에 직결돼 PvP 영향.
    authed.post('/breakthrough', (Request req) async {
      final user = userOf(req);
      final Map<String, dynamic> body;
      try {
        body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      } catch (_) {
        return _json({'error': 'bad_request'}, status: 400);
      }
      final bugId = body['bugId']?.toString() ?? '';
      if (bugId.isEmpty) return _json({'error': 'bad_request'}, status: 400);
      try {
        final save = await loadSave(user.id);
        if (save == null) return _json({'error': 'no_save'}, status: 409);
        final r = actions.startBreakthrough(save, bugId, petConfig: cfg.pet);
        if (!r.isOk) return _json({'error': r.error}, status: r.status);
        await store.save(user.id, r.save!.toJson());
        return _json({'save': r.save!.toJson(), ...r.extra});
      } on StateStoreException catch (e) {
        stderr.writeln('[breakthrough] ${user.id}: $e');
        return _json({'error': 'store_unavailable'}, status: 503);
      }
    });

    /// 돌파 완료 수령 — 타이머 종료 후, 또는 젤리 즉시완료. 건너뛰기를 서버가 막는다.
    authed.post('/breakthrough/complete', (Request req) async {
      final user = userOf(req);
      final Map<String, dynamic> body;
      try {
        body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      } catch (_) {
        return _json({'error': 'bad_request'}, status: 400);
      }
      final bugId = body['bugId']?.toString() ?? '';
      if (bugId.isEmpty) return _json({'error': 'bad_request'}, status: 400);
      final viaJelly = body['viaJelly'] == true;
      try {
        final save = await loadSave(user.id);
        if (save == null) return _json({'error': 'no_save'}, status: 409);
        final r = actions.completeBreakthrough(
          save,
          bugId,
          petConfig: cfg.pet,
          viaJelly: viaJelly,
        );
        if (!r.isOk) return _json({'error': r.error}, status: r.status);
        await store.save(user.id, r.save!.toJson());
        return _json({'save': r.save!.toJson(), ...r.extra});
      } on StateStoreException catch (e) {
        stderr.writeln('[breakthrough/complete] ${user.id}: $e');
        return _json({'error': 'store_unavailable'}, status: 503);
      }
    });

    /// 미션 보상 수령 — 진행도를 서버가 소유하므로 목표 달성 여부도 서버가 본다.
    authed.post('/mission/claim', (Request req) async {
      final user = userOf(req);
      final Map<String, dynamic> body;
      try {
        body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      } catch (_) {
        return _json({'error': 'bad_request'}, status: 400);
      }
      final id = body['missionId']?.toString() ?? '';
      if (id.isEmpty) return _json({'error': 'bad_request'}, status: 400);
      try {
        final save = await loadSave(user.id);
        if (save == null) return _json({'error': 'no_save'}, status: 409);
        final r = actions.claimMission(save, id);
        if (!r.isOk) return _json({'error': r.error}, status: r.status);
        await store.save(user.id, r.save!.toJson());
        return _json({'save': r.save!.toJson(), ...r.extra});
      } on StateStoreException catch (e) {
        stderr.writeln('[mission/claim] ${user.id}: $e');
        return _json({'error': 'store_unavailable'}, status: 503);
      }
    });

    /// 깜짝선물 수령 — 선물 존재·만료를 서버가 확인한다.
    authed.post('/gift/claim', (Request req) async {
      final user = userOf(req);
      final Map<String, dynamic> body;
      try {
        body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      } catch (_) {
        return _json({'error': 'bad_request'}, status: 400);
      }
      final id = body['giftId']?.toString() ?? '';
      if (id.isEmpty) return _json({'error': 'bad_request'}, status: 400);
      final doubled = body['doubled'] == true;
      try {
        final save = await loadSave(user.id);
        if (save == null) return _json({'error': 'no_save'}, status: 409);
        final r = actions.claimGift(save, id, doubled: doubled);
        if (!r.isOk) return _json({'error': r.error}, status: r.status);
        await store.save(user.id, r.save!.toJson());
        return _json({'save': r.save!.toJson(), ...r.extra});
      } on StateStoreException catch (e) {
        stderr.writeln('[gift/claim] ${user.id}: $e');
        return _json({'error': 'store_unavailable'}, status: 503);
      }
    });

    /// 일일보상 수령 — UTC 날짜당 슬롯 1회(시간 게이트는 UI).
    authed.post('/daily/claim', (Request req) async {
      final user = userOf(req);
      final Map<String, dynamic> body;
      try {
        body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      } catch (_) {
        return _json({'error': 'bad_request'}, status: 400);
      }
      final id = body['rewardId']?.toString() ?? '';
      if (id.isEmpty) return _json({'error': 'bad_request'}, status: 400);
      try {
        final save = await loadSave(user.id);
        if (save == null) return _json({'error': 'no_save'}, status: 409);
        final r = actions.claimDaily(save, id);
        if (!r.isOk) return _json({'error': r.error}, status: r.status);
        await store.save(user.id, r.save!.toJson());
        return _json({'save': r.save!.toJson(), ...r.extra});
      } on StateStoreException catch (e) {
        stderr.writeln('[daily/claim] ${user.id}: $e');
        return _json({'error': 'store_unavailable'}, status: 503);
      }
    });

    /// 로드맵 챕터 클리어 보상 — 스테이지가 서버 소유라 클리어도 서버가 확정.
    authed.post('/roadmap/claim', (Request req) async {
      final user = userOf(req);
      try {
        final save = await loadSave(user.id);
        if (save == null) return _json({'error': 'no_save'}, status: 409);
        final r = actions.grantChapterClears(save);
        if (!r.isOk) return _json({'error': r.error}, status: r.status);
        await store.save(user.id, r.save!.toJson());
        return _json({'save': r.save!.toJson(), ...r.extra});
      } on StateStoreException catch (e) {
        stderr.writeln('[roadmap/claim] ${user.id}: $e');
        return _json({'error': 'store_unavailable'}, status: 503);
      }
    });

    /// 짝짓기 시작 — 조건 검사와 **자식 롤 시드 생성**을 서버가 한다.
    // ── 실물 경품 랭킹 이벤트 ────────────────────────────────────
    //
    // docs/event_ranking_prize.md. 순위가 그대로 실물 상품이 되므로 **앱이
    // 점수를 올리는 경로는 없다.** 서버가 참가권을 깎고 웨이브를 돌려 확정한다.

    /// 이벤트 현황 — 회차·참가권·내 최고 기록.
    authed.get('/event', (Request req) async {
      final user = userOf(req);
      final ev = cfg.event;
      // 기간 밖이면 닫힌 것으로 본다 — 앱은 이 응답을 보고 배너·화면을 감춘다.
      if (ev == null || !actions.eventOpen) {
        return _json({'error': 'event_closed'}, status: 404);
      }
      try {
        final save = await loadSave(user.id);
        if (save == null) return _json({'error': 'no_save'}, status: 409);
        final roundId = actions.eventRoundId();
        final t = actions.eventTicketsNow(save);
        return _json({
          'roundId': roundId,
          'tickets': t.tickets,
          'ticketMax': ev.ticketMax,
          'fatigueHours': ev.fatigueHours,
          'bestWave': save.eventRoundId == roundId ? save.eventBestWave : 0,
          'bestScore': save.eventBestScoreIn(roundId),
          // 익명 계정은 도전은 되지만 **순위에 오르지 않는다**(다계정이 무료·무제한).
          'rankEligible': !user.isAnonymous,
          if (ev.startsAt != null) 'startsAt': ev.startsAt!.toIso8601String(),
          if (ev.endsAt != null) 'endsAt': ev.endsAt!.toIso8601String(),
        });
      } on StateStoreException catch (e) {
        stderr.writeln('[event] ${user.id}: $e');
        return _json({'error': 'store_unavailable'}, status: 503);
      }
    });

    /// 이벤트 순위 — 상위 N + 내 순위(목록 안에 있으면 `isMe`).
    authed.get('/event/leaderboard', (Request req) async {
      final user = userOf(req);
      if (cfg.event == null)
        return _json({'error': 'event_closed'}, status: 404);
      final roundId = actions.eventRoundId();
      try {
        final rows = await store.eventTop(roundId, 100);
        return _json({
          'roundId': roundId,
          'entries': [
            for (final r in rows)
              {
                'rank': r['rank'],
                'nickname': r['nickname'],
                'score': r['score'],
                'wave': r['wave'],
                'badge': r['badge'] ?? '',
                'isMe': r['user_id'] == user.id,
              },
          ],
        });
      } on StateStoreException catch (e) {
        stderr.writeln('[event/leaderboard] ${user.id}: $e');
        return _json({'error': 'store_unavailable'}, status: 503);
      }
    });

    /// **이벤트 도전 시작** — 참가권을 깎고 1웨이브를 치른다.
    ///
    /// 판을 통째로 돌리지 않고 세션으로 쪼개는 이유는 웨이브마다 **카드를
    /// 고르게** 하기 위해서다(로그라이크). 진행 상태는 서버가 들고 있고,
    /// 앱에는 세션 id 만 준다 — 앱이 상태를 들고 있으면 고쳐 보낼 수 있다.
    authed.post('/event/start', (Request req) async {
      final user = userOf(req);
      final Map<String, dynamic> body;
      try {
        body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      } catch (_) {
        return _json({'error': 'bad_request'}, status: 400);
      }
      final ids = (body['teamIds'] as List?)?.map((e) => '$e').toList();
      if (ids == null || ids.length != 3) {
        return _json({'error': 'bad_request'}, status: 400);
      }
      try {
        final save = await loadSave(user.id);
        if (save == null) return _json({'error': 'no_save'}, status: 409);
        final r = actions.eventStart(save, teamIds: ids, speciesById: species);
        if (!r.isOk) return _json({'error': r.error}, status: r.status);
        await store.save(user.id, r.save!.toJson());

        final sessionId = _newSessionId();
        await store.saveSession(sessionId, user.id, {
          'kind': 'event',
          ...(r.extra['session'] as Map<String, dynamic>),
        });

        final out = Map<String, dynamic>.from(r.extra)..remove('session');
        // 판이 1웨이브에서 끝났으면 점수를 바로 기록한다.
        var recorded = false;
        if (r.extra['done'] == true &&
            !user.isAnonymous &&
            r.extra['isBest'] == true) {
          recorded = await _submitEventScore(
            store,
            user.id,
            r.save!,
            r.extra,
            ids,
          );
        }
        return _json({
          'save': r.save!.toJson(),
          ...out,
          'sessionId': sessionId,
          'rankEligible': !user.isAnonymous,
          'recorded': recorded,
        });
      } on StateStoreException catch (e) {
        stderr.writeln('[event/start] ${user.id}: $e');
        return _json({'error': 'store_unavailable'}, status: 503);
      }
    });

    /// **카드 선택 → 다음 웨이브.** 판이 끝나면 점수를 확정·기록한다.
    authed.post('/event/pick', (Request req) async {
      final user = userOf(req);
      final Map<String, dynamic> body;
      try {
        body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      } catch (_) {
        return _json({'error': 'bad_request'}, status: 400);
      }
      final sessionId = body['sessionId']?.toString() ?? '';
      final cardId = body['cardId']?.toString() ?? '';
      if (sessionId.isEmpty || cardId.isEmpty) {
        return _json({'error': 'bad_request'}, status: 400);
      }
      try {
        final row = await store.loadSession(sessionId);
        if (row == null) return _json({'error': 'no_session'}, status: 404);
        // 남의 세션을 진행시키지 못하게 한다.
        if (row['user_id'] != user.id) {
          return _json({'error': 'forbidden'}, status: 403);
        }
        final data = (row['data'] as Map).cast<String, dynamic>();
        if (data['kind'] != 'event') {
          return _json({'error': 'no_session'}, status: 404);
        }
        final save = await loadSave(user.id);
        if (save == null) return _json({'error': 'no_save'}, status: 409);

        final r = actions.eventPick(
          save,
          session: data,
          cardId: cardId,
          speciesById: species,
          leadBugId: body['leadBugId']?.toString(),
        );
        if (!r.isOk) return _json({'error': r.error}, status: r.status);

        final next = (r.extra['session'] as Map<String, dynamic>);
        await store.saveSession(sessionId, user.id, {'kind': 'event', ...next});
        if (r.save != save) await store.save(user.id, r.save!.toJson());

        var recorded = false;
        if (r.extra['done'] == true &&
            !user.isAnonymous &&
            r.extra['isBest'] == true) {
          recorded = await _submitEventScore(
            store,
            user.id,
            r.save!,
            r.extra,
            (data['teamIds'] as List).map((e) => '$e').toList(),
          );
        }

        final out = Map<String, dynamic>.from(r.extra)..remove('session');
        // 선봉 교체로 **순서가 바뀌었을 수 있다.** 앱이 모르면 재생이 옛 순서로
        // 그려져 "바꿨는데 안 나온다"가 된다(세션 전체는 주지 않는다 — 앱이
        // 들고 있으면 고쳐 보낼 수 있다).
        out['teamIds'] = next['teamIds'];
        return _json({
          'save': r.save!.toJson(),
          ...out,
          'sessionId': sessionId,
          'rankEligible': !user.isAnonymous,
          'recorded': recorded,
        });
      } on StateStoreException catch (e) {
        stderr.writeln('[event/pick] ${user.id}: $e');
        return _json({'error': 'store_unavailable'}, status: 503);
      }
    });

    /// 이벤트 도전 1회.
    authed.post('/event/challenge', (Request req) async {
      final user = userOf(req);
      final Map<String, dynamic> body;
      try {
        body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      } catch (_) {
        return _json({'error': 'bad_request'}, status: 400);
      }
      final ids = (body['teamIds'] as List?)?.map((e) => '$e').toList();
      if (ids == null || ids.length != 3) {
        return _json({'error': 'bad_request'}, status: 400);
      }
      try {
        final save = await loadSave(user.id);
        if (save == null) return _json({'error': 'no_save'}, status: 409);
        final r = actions.eventChallenge(
          save,
          teamIds: ids,
          speciesById: species,
        );
        if (!r.isOk) return _json({'error': r.error}, status: r.status);
        await store.save(user.id, r.save!.toJson());

        // 순위 기록은 **로그인 계정만**. 익명은 다계정을 막을 수 없어서
        // 실물 경품 대상이 될 수 없다(기획 §4).
        var recorded = false;
        if (!user.isAnonymous && r.extra['isBest'] == true) {
          try {
            await store.submitEventScore(
              roundId: '${r.extra['roundId']}',
              userId: user.id,
              nickname: r.save!.nickname,
              score: r.extra['score'] as int,
              wave: r.extra['wave'] as int,
              team: {'ids': ids},
            );
            recorded = true;
          } catch (e) {
            // 기록 실패로 판을 무르지 않는다 — 참가권은 이미 나갔다.
            // 다음 도전에서 최고 기록이면 다시 올라간다.
            stderr.writeln('[event/submit] ${user.id}: $e');
          }
        }
        return _json({
          'save': r.save!.toJson(),
          ...r.extra,
          'rankEligible': !user.isAnonymous,
          'recorded': recorded,
        });
      } on StateStoreException catch (e) {
        stderr.writeln('[event/challenge] ${user.id}: $e');
        return _json({'error': 'store_unavailable'}, status: 503);
      }
    });

    /// 광고 시청 → 참가권 1장(하루 상한은 event.json).
    authed.post('/event/ad-ticket', (Request req) async {
      final user = userOf(req);
      try {
        final save = await loadSave(user.id);
        if (save == null) return _json({'error': 'no_save'}, status: 409);
        final r = actions.grantEventAdTicket(save);
        if (!r.isOk) return _json({'error': r.error}, status: r.status);
        await store.save(user.id, r.save!.toJson());
        return _json({'save': r.save!.toJson(), ...r.extra});
      } on StateStoreException catch (e) {
        stderr.writeln('[event/ad-ticket] ${user.id}: $e');
        return _json({'error': 'store_unavailable'}, status: 503);
      }
    });

    authed.post('/breed', (Request req) async {
      final user = userOf(req);
      final Map<String, dynamic> body;
      try {
        body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      } catch (_) {
        return _json({'error': 'bad_request'}, status: 400);
      }
      final motherId = body['motherId']?.toString() ?? '';
      final fatherId = body['fatherId']?.toString() ?? '';
      if (motherId.isEmpty || fatherId.isEmpty) {
        return _json({'error': 'bad_request'}, status: 400);
      }
      try {
        final save = await loadSave(user.id);
        if (save == null) return _json({'error': 'no_save'}, status: 409);
        final r = actions.startBreeding(
          save,
          motherId: motherId,
          fatherId: fatherId,
          speciesById: species,
          petConfig: cfg.pet,
        );
        if (!r.isOk) return _json({'error': r.error}, status: r.status);
        await store.save(user.id, r.save!.toJson());
        return _json({'save': r.save!.toJson(), ...r.extra});
      } on StateStoreException catch (e) {
        stderr.writeln('[breed] ${user.id}: $e');
        return _json({'error': 'store_unavailable'}, status: 503);
      }
    });

    /// 산란 완료 수령 — 자식 롤은 슬롯에 박힌 서버 시드로 굴린다.
    authed.post('/breed/collect', (Request req) async {
      final user = userOf(req);
      final Map<String, dynamic> body;
      try {
        body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      } catch (_) {
        return _json({'error': 'bad_request'}, status: 400);
      }
      final slotId = body['slotId']?.toString() ?? '';
      if (slotId.isEmpty) return _json({'error': 'bad_request'}, status: 400);
      try {
        final save = await loadSave(user.id);
        if (save == null) return _json({'error': 'no_save'}, status: 409);
        final r = actions.collectBreeding(
          save,
          slotId,
          speciesById: species,
          petConfig: cfg.pet,
          viaJelly: body['viaJelly'] == true,
        );
        if (!r.isOk) return _json({'error': r.error}, status: r.status);
        await store.save(user.id, r.save!.toJson());
        return _json({'save': r.save!.toJson(), ...r.extra});
      } on StateStoreException catch (e) {
        stderr.writeln('[breed/collect] ${user.id}: $e');
        return _json({'error': 'store_unavailable'}, status: 503);
      }
    });

    /// 수동 전투 시작 — 세션을 만들고 **시드는 서버에만 둔다**.
    ///
    /// 시드를 클라이언트가 알면 상대의 매 라운드 수를 미리 계산해
    /// 최적해를 고를 수 있다(심리전이 무의미해진다). 그래서 응답에 넣지 않는다.
    authed.post('/battle/manual/start', (Request req) async {
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
      final tierId = body['tierId']?.toString() ?? '';
      if (teamIds.isEmpty || (opponentId.isEmpty && tierId.isEmpty)) {
        return _json({'error': 'bad_request'}, status: 400);
      }

      try {
        final save = await loadSave(user.id);
        if (save == null) return _json({'error': 'no_save'}, status: 409);

        final built = actions.validateTeam(
          save,
          teamIds,
          speciesById: species,
          petConfig: cfg.pet,
          enhance: cfg.enhance,
        );
        if (built.error != null) {
          return _json({'error': built.error}, status: 400);
        }

        // 수동 전투도 티켓 1장 — **시작할 때** 깎는다(중간 이탈로 무한 판수를
        // 돌리지 못하게). 자동 전투는 actions.runBattle 안에서 함께 처리된다.
        // 실제 저장은 세션 생성에 성공한 뒤에(아래) — 세션도 못 열었는데
        // 티켓만 사라지는 일이 없게.
        final ticketed = actions.consumePvpTicket(save);
        if (!ticketed.isOk) {
          return _json(
            _ticketError(actions, save, ticketed.error),
            status: ticketed.status,
          );
        }

        final List<BattleBug> foe;
        final List<String> foeSpecies;
        // 상대가 산 스킨(그림용). 야생은 전부 null.
        final List<String?> foeSkins;
        final double rewardMult;
        // ⚠️ 자기 자신과는 싸울 수 없다. 앱이 걸러 주지만 서버도 막는다 —
        // 내 방어팀은 내 전력과 똑같아 승률 조작에 쓰기 딱 좋다.
        if (opponentId == user.id) {
          return _json({'error': 'self_opponent'}, status: 400);
        }
        if (opponentId.isNotEmpty) {
          final rows = await store.loadDefenderTeam(opponentId);
          if (rows == null || rows.isEmpty) {
            return _json({'error': 'opponent_not_found'}, status: 404);
          }
          foe = [
            for (var i = 0; i < rows.length; i++)
              _defenderToBattleBug(rows[i], i, species),
          ];
          foeSpecies = [for (final d in rows) d['sp']?.toString() ?? ''];
          foeSkins = [for (final d in rows) _defenderSkin(d)];
          rewardMult = 1.0;
        } else {
          final wild = actions.buildWildTeam(
            save,
            tierId: tierId,
            speciesById: species,
            petConfig: cfg.pet,
          );
          if (wild == null) {
            return _json({'error': 'cannot_build_wild'}, status: 400);
          }
          foe = wild.team;
          foeSpecies = wild.speciesIds;
          foeSkins = List<String?>.filled(wild.team.length, null);
          rewardMult = wild.tier.rewardMult;
        }

        // ⚠️ **시작할 때 먼저 지고 들어간다.** 수동 전투는 결착까지 시간이
        // 걸려서, 지고 있으면 앱을 강제 종료해 트로피를 지키는 치트가 가능했다
        // (티켓만 날아가고 점수는 그대로 — 2026-08-19 지적). 이기면 결착에서
        // 차액으로 되돌려준다. 중간에 사라지면 패배가 그대로 남는다.
        final startSave = ticketed.save!;
        final prepaid = pvpReward(
          won: false,
          draw: false,
          trophies: startSave.pvpTrophies,
          cfg: cfg.battle,
          rewardMult: rewardMult,
        ).trophyDelta;
        // ⚠️ **부상도 선차감한다.** 트로피만 미리 깎으면 곤충은 멀쩡히
        // 빠져나간다 — 지고 있을 때 이탈하면 KO 대가(회복 타이머)를 통째로
        // 피할 수 있었다(감사 후 보완 2026-08-20). 결착에서 살아남은 곤충은
        // 되돌려준다. 시작 검증이 진짜 부상을 거부하므로 여기서 걸리는 건
        // 전부 이 선차감분이다.
        final tNow = DateTime.now().toUtc();
        final preInjured = Map<String, DateTime>.from(startSave.injured);
        for (final b in built.team) {
          final bug = startSave.bugs.where((x) => x.id == b.id).firstOrNull;
          final sp = bug == null ? null : species[bug.speciesId];
          if (sp == null) continue;
          preInjured[b.id] = tNow.add(
            Duration(seconds: cfg.pet.injuryDuration(sp.grade)),
          );
        }

        final prepaidSave = startSave.copyWith(
          pvpTrophies: (startSave.pvpTrophies + prepaid).clamp(0, 1 << 30),
          injured: preInjured,
        );
        // ⚠️ 세션에는 **실제로 깎인 만큼**을 적는다. 트로피가 12 미만이면
        // 차감이 0 에서 잘리는데, 결착에서 원래 액수(-12)를 되돌려주면
        // 그 차이만큼 공짜 트로피가 된다(0 근처 유저가 이길수록 이득 — 감사에서
        // 발견 2026-08-20).
        final effPrepaid = prepaidSave.pvpTrophies - startSave.pvpTrophies;

        final sessionId = _newSessionId();
        final session = BattleSession(
          id: sessionId,
          userId: user.id,
          seed: DateTime.now().microsecondsSinceEpoch & 0x7fffffff,
          myTeamBugIds: teamIds,
          foe: foe,
          location: foe.first.element,
          rewardMult: rewardMult,
          stances: const [],
          finished: false,
          trophiesAtStart: startSave.pvpTrophies,
          trophyPrepaid: effPrepaid,
        );
        await store.saveSession(sessionId, user.id, session.toJson());
        await store.save(user.id, prepaidSave.toJson());

        // 상대 스탯은 화면 표시에 필요하므로 준다. 시드는 주지 않는다.
        // 세이브는 싣지 않는다(이그레스 비용) — 바뀐 티켓 값만 돌려준다.
        return _json({
          'sessionId': sessionId,
          'location': session.location.key,
          'energyA': 1, // 엔진 시작 기력
          ...ticketed.extra,
          'foe': [
            for (var i = 0; i < foe.length; i++)
              _foeJson(
                foe[i],
                i < foeSpecies.length ? foeSpecies[i] : '',
                skin: i < foeSkins.length ? foeSkins[i] : null,
              ),
          ],
        });
      } on StateStoreException catch (e) {
        stderr.writeln('[manual/start] ${user.id}: $e');
        return _json({'error': 'store_unavailable'}, status: 503);
      }
    });

    /// 수동 전투 한 수 진행. 서버가 처음부터 재생해 **이번 라운드 결과만** 준다.
    authed.post('/battle/manual/step', (Request req) async {
      final user = userOf(req);
      final Map<String, dynamic> body;
      try {
        body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      } catch (_) {
        return _json({'error': 'bad_request'}, status: 400);
      }
      final sessionId = body['sessionId']?.toString() ?? '';
      final stance = Stance.values
          .where((s) => s.name == (body['stance']?.toString() ?? ''))
          .firstOrNull;
      if (sessionId.isEmpty || stance == null) {
        return _json({'error': 'bad_request'}, status: 400);
      }

      try {
        final row = await store.loadSession(sessionId);
        if (row == null) return _json({'error': 'no_session'}, status: 404);
        // 남의 세션을 진행시킬 수 없다.
        if (row['user_id']?.toString() != user.id) {
          return _json({'error': 'forbidden'}, status: 403);
        }
        var session = BattleSession.fromJson(
          sessionId,
          user.id,
          row['data'] as Map<String, dynamic>,
        );
        // 끝난 세션을 다시 돌려 보상을 두 번 받지 못하게.
        if (session.finished) {
          return _json({'error': 'already_finished'}, status: 409);
        }

        final save = await loadSave(user.id);
        if (save == null) return _json({'error': 'no_save'}, status: 409);
        final built = actions.validateTeam(
          save,
          session.myTeamBugIds,
          speciesById: species,
          petConfig: cfg.pet,
          enhance: cfg.enhance,
          // 시작 때 선차감한 부상에 자기가 걸리면 안 된다(위 선차감 주석).
          allowInjured: true,
        );
        if (built.error != null) {
          return _json({'error': built.error}, status: 400);
        }

        session = session.copyWith(stances: [...session.stances, stance]);
        final st = replay(
          session,
          built.team,
          locationBonus: cfg.battle.locationAffinityBonus,
        );

        final out = <String, dynamic>{
          'round': st.round,
          'done': st.done,
          'hpA': st.hpA,
          'hpB': st.hpB,
          // 다음 수의 버튼 활성 판정용(기력 0 이면 공격만 가능).
          'energyA': st.a < st.enA.length ? st.enA[st.a] : 0,
        };
        if (st.events.isNotEmpty) {
          final ev = st.events.last;
          // 앱 연출이 로컬 엔진과 같으려면 이벤트를 통째로 줘야 한다.
          out['event'] = {
            'round': ev.round,
            'aName': ev.aName,
            'bName': ev.bName,
            'aStance': ev.aStance.name,
            'bStance': ev.bStance.name,
            'rps': ev.rps,
            'dmgToA': ev.dmgToA,
            'dmgToB': ev.dmgToB,
            'healToA': ev.healToA,
            'healToB': ev.healToB,
            'aHp': ev.aHp,
            'bHp': ev.bHp,
            'aDown': ev.aDown,
            'bDown': ev.bDown,
          };
        }

        if (!st.done) {
          await store.saveSession(sessionId, user.id, session.toJson());
          return _json(out);
        }

        // 결착 — 보상을 서버가 확정하고 세션을 닫는다.
        final applied = actions.applyBattleOutcome(
          save,
          result: st.toResult(),
          myTeam: built.team,
          rewardMult: session.rewardMult,
          speciesById: species,
          petConfig: cfg.pet,
          // 시작할 때 패배분을 미리 깎았다 — 차액만 반영한다.
          trophiesAtStart: session.trophiesAtStart == 0
              ? null
              : session.trophiesAtStart,
          trophyPrepaid: session.trophyPrepaid,
          healSurvivors: true,
        );
        await store.saveSession(
          sessionId,
          user.id,
          session.copyWith(finished: true).toJson(),
        );
        final r = st.toResult();
        out['teamAHpPct'] = r.teamAHpPct;
        out['teamBHpPct'] = r.teamBHpPct;
        out['rounds'] = r.rounds;
        if (!applied.isOk) return _json(out);
        await store.save(user.id, applied.save!.toJson());
        return _json({
          ...out,
          ...applied.extra,
          'save': applied.save!.toJson(),
        });
      } on StateStoreException catch (e) {
        stderr.writeln('[manual/step] ${user.id}: $e');
        return _json({'error': 'store_unavailable'}, status: 503);
      }
    });

    /// 부화 수령(알 → 유충) — 타이머 완료를 서버가 확인한다.
    authed.post('/incubate/collect', (Request req) async {
      final user = userOf(req);
      final Map<String, dynamic> body;
      try {
        body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      } catch (_) {
        return _json({'error': 'bad_request'}, status: 400);
      }
      final bugId = body['bugId']?.toString() ?? '';
      if (bugId.isEmpty) return _json({'error': 'bad_request'}, status: 400);
      try {
        final save = await loadSave(user.id);
        if (save == null) return _json({'error': 'no_save'}, status: 409);
        final r = actions.collectIncubated(save, bugId);
        if (!r.isOk) return _json({'error': r.error}, status: r.status);
        await store.save(user.id, r.save!.toJson());
        return _json({'save': r.save!.toJson(), ...r.extra});
      } on StateStoreException catch (e) {
        stderr.writeln('[incubate/collect] ${user.id}: $e');
        return _json({'error': 'store_unavailable'}, status: 503);
      }
    });

    /// 곤충 분해 → 젤리. 지급량은 서버가 pets.json 에서 정한다.
    authed.post('/disassemble', (Request req) async {
      final user = userOf(req);
      final Map<String, dynamic> body;
      try {
        body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      } catch (_) {
        return _json({'error': 'bad_request'}, status: 400);
      }
      final bugId = body['bugId']?.toString() ?? '';
      if (bugId.isEmpty) return _json({'error': 'bad_request'}, status: 400);
      try {
        final save = await loadSave(user.id);
        if (save == null) return _json({'error': 'no_save'}, status: 409);
        final r = actions.disassembleBug(save, bugId, petConfig: cfg.pet);
        if (!r.isOk) return _json({'error': r.error}, status: r.status);
        await store.save(user.id, r.save!.toJson());
        return _json({'save': r.save!.toJson(), ...r.extra});
      } on StateStoreException catch (e) {
        stderr.writeln('[disassemble] ${user.id}: $e');
        return _json({'error': 'store_unavailable'}, status: 503);
      }
    });

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
      // 야생(합성) 상대는 티어 id 만 받는다 — 배율은 서버가 config 에서 고른다.
      final tierId = body['tierId']?.toString() ?? '';
      if (teamIds.isEmpty || (opponentId.isEmpty && tierId.isEmpty)) {
        return _json({'error': 'bad_request'}, status: 400);
      }

      try {
        final save = await loadSave(user.id);
        if (save == null) return _json({'error': 'no_save'}, status: 409);

        final List<BattleBug> foe;
        final List<String> foeSpecies;
        // 상대가 산 스킨(그림용). 야생은 전부 null.
        final List<String?> foeSkins;
        final double rewardMult;
        // ⚠️ 자기 자신과는 싸울 수 없다(수동 전투와 같은 규칙).
        if (opponentId == user.id) {
          return _json({'error': 'self_opponent'}, status: 400);
        }
        if (opponentId.isNotEmpty) {
          // 실 유저 상대 — 방어팀을 서버가 DB 에서 직접 읽는다.
          final rows = await store.loadDefenderTeam(opponentId);
          if (rows == null || rows.isEmpty) {
            return _json({'error': 'opponent_not_found'}, status: 404);
          }
          foe = [
            for (var i = 0; i < rows.length; i++)
              _defenderToBattleBug(rows[i], i, species),
          ];
          foeSpecies = [for (final d in rows) d['sp']?.toString() ?? ''];
          foeSkins = [for (final d in rows) _defenderSkin(d)];
          rewardMult = 1.0;
        } else {
          // 야생 상대 — 서버가 내 로스터 기준으로 만든다.
          final wild = actions.buildWildTeam(
            save,
            tierId: tierId,
            speciesById: species,
            petConfig: cfg.pet,
          );
          if (wild == null) {
            return _json({'error': 'cannot_build_wild'}, status: 400);
          }
          foe = wild.team;
          foeSpecies = wild.speciesIds;
          foeSkins = List<String?>.filled(wild.team.length, null);
          rewardMult = wild.tier.rewardMult;
        }

        // 시드는 **서버가 정한다** — 클라가 유리한 시드를 고르지 못하게.
        final seed = DateTime.now().microsecondsSinceEpoch & 0x7fffffff;
        final r = actions.runBattle(
          save,
          myTeamBugIds: teamIds,
          foeTeam: foe,
          location: foe.first.element,
          seed: seed,
          rewardMult: rewardMult,
          speciesById: species,
          petConfig: cfg.pet,
        );
        if (!r.isOk) {
          return _json(_ticketError(actions, save, r.error), status: r.status);
        }
        await store.save(user.id, r.save!.toJson());
        return _json({
          'save': r.save!.toJson(),
          ...r.extra,
          // 야생은 서버가 만든 상대다 — 앱이 이걸로 그리고 재생해야
          // 연출이 서버 결과와 일치한다.
          'foe': [
            for (var i = 0; i < foe.length; i++)
              _foeJson(
                foe[i],
                i < foeSpecies.length ? foeSpecies[i] : '',
                skin: i < foeSkins.length ? foeSkins[i] : null,
              ),
          ],
        });
      } on StateStoreException catch (e) {
        stderr.writeln('[battle] ${user.id}: $e');
        return _json({'error': 'store_unavailable'}, status: 503);
      }
    });

    /// 결투 티켓 충전 — 광고(`/pvp/ticket/ad`) · 젤리(`/pvp/ticket/refill`).
    ///
    /// 티켓은 서버 소유라 앱이 로컬로 늘려봐야 업로드 때 덮인다. 그래서 충전은
    /// 반드시 여기를 거친다. 응답에 **세이브를 싣지 않는다** — 바뀌는 건 티켓
    /// 몇 바이트인데 세이브를 왕복시키면 이그레스 요금만 는다(2026-07 사고).
    Future<Response> ticketAction(
      Request req,
      String tag,
      ActionResult Function(SaveGame) run,
    ) async {
      final user = userOf(req);
      try {
        final save = await loadSave(user.id);
        if (save == null) return _json({'error': 'no_save'}, status: 409);
        final r = run(save);
        if (!r.isOk) return _json({'error': r.error}, status: r.status);
        await store.save(user.id, r.save!.toJson());
        return _json(r.extra);
      } on StateStoreException catch (e) {
        stderr.writeln('[$tag] ${user.id}: $e');
        return _json({'error': 'store_unavailable'}, status: 503);
      }
    }

    // ── 공지 · 운영 우편 · 선물코드 ──
    //
    // 셋 다 "서버가 유저에게 보낸다"는 하나의 일이다. 지급은 반드시 서버가
    // 하고 앱은 결과 세이브를 채택한다(구매와 같은 방식) — 앱이 스스로 더하면
    // 다음 업로드에서 골드 급증 상한에 걸려 정당한 보상이 잘린다.

    /// 진행 중인 공지 목록. 보상이 아니라 읽을거리라 세이브를 건드리지 않는다.
    authed.get('/notices', (Request req) async {
      try {
        final rows = await store.loadNotices(now: actions.now().toUtc());
        return _json({'notices': rows});
      } on StateStoreException catch (e) {
        stderr.writeln('[notices] $e');
        return _json({'error': 'store_unavailable'}, status: 503);
      }
    });

    /// 내가 아직 안 받은 우편(개인 + 전체 발송).
    authed.get('/mail', (Request req) async {
      final user = userOf(req);
      try {
        final rows = await store.loadMail(
          userId: user.id,
          now: actions.now().toUtc(),
        );
        return _json({'mail': rows});
      } on StateStoreException catch (e) {
        stderr.writeln('[mail] ${user.id}: $e');
        return _json({'error': 'store_unavailable'}, status: 503);
      }
    });

    /// 우편 수령 → 재화 지급. 중복 수령은 `mail_claims` 기본키가 막는다.
    authed.post('/mail/claim', (Request req) async {
      final user = userOf(req);
      final Map<String, dynamic> body;
      try {
        body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      } catch (_) {
        return _json({'error': 'bad_request'}, status: 400);
      }
      final mailId = body['id']?.toString() ?? '';
      if (mailId.isEmpty) return _json({'error': 'bad_request'}, status: 400);

      try {
        final save = await loadSave(user.id);
        if (save == null) return _json({'error': 'no_save'}, status: 409);
        final now = actions.now().toUtc();
        final rows = await store.loadMail(userId: user.id, now: now);
        final row = rows.cast<Map<String, dynamic>?>().firstWhere(
          (r) => '${r!['id']}' == mailId,
          orElse: () => null,
        );
        // 목록에 없다 = 남의 우편이거나, 기간이 지났거나, 이미 받았다.
        if (row == null) return _json({'error': 'mail_not_found'}, status: 404);

        // **먼저 수령을 확정**하고 지급한다. 순서가 반대면 지급 후 기록에
        // 실패했을 때 같은 우편을 계속 받을 수 있다.
        if (!await store.claimMail(mailId, user.id)) {
          return _json({'error': 'already_claimed'}, status: 409);
        }
        final r = actions.grantRewardRow(save, row);
        if (!r.isOk) return _json({'error': r.error}, status: r.status);
        await store.save(user.id, r.save!.toJson());
        return _json({'save': r.save!.toJson(), ...r.extra});
      } on StateStoreException catch (e) {
        stderr.writeln('[mail/claim] ${user.id}: $e');
        return _json({'error': 'store_unavailable'}, status: 503);
      }
    });

    /// 선물코드 사용 → 재화 지급(계정당 1회).
    authed.post('/code/redeem', (Request req) async {
      final user = userOf(req);
      final Map<String, dynamic> body;
      try {
        body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      } catch (_) {
        return _json({'error': 'bad_request'}, status: 400);
      }
      final code = (body['code']?.toString() ?? '').trim().toUpperCase();
      if (code.isEmpty || code.length > 32) {
        return _json({'error': 'bad_code'}, status: 400);
      }

      try {
        final save = await loadSave(user.id);
        if (save == null) return _json({'error': 'no_save'}, status: 409);
        final row = await store.loadGiftCode(code);
        if (row == null) return _json({'error': 'bad_code'}, status: 404);

        final ends = row['ends_at'];
        if (ends is String) {
          final e = DateTime.tryParse(ends)?.toUtc();
          if (e != null && !actions.now().toUtc().isBefore(e)) {
            return _json({'error': 'code_expired'}, status: 410);
          }
        }
        final maxUses = (row['max_uses'] as num?)?.toInt();
        final used = (row['used_count'] as num?)?.toInt() ?? 0;
        if (maxUses != null && used >= maxUses) {
          return _json({'error': 'code_exhausted'}, status: 409);
        }

        // 계정당 1회 — DB 기본키 충돌로 막는다(연타·재시도 안전).
        if (!await store.redeemGiftCode(code, user.id)) {
          return _json({'error': 'code_already_used'}, status: 409);
        }
        final r = actions.grantRewardRow(save, row);
        if (!r.isOk) return _json({'error': r.error}, status: r.status);
        await store.save(user.id, r.save!.toJson());
        await store.bumpGiftCodeUse(code);
        return _json({'save': r.save!.toJson(), ...r.extra});
      } on StateStoreException catch (e) {
        stderr.writeln('[code/redeem] ${user.id}: $e');
        return _json({'error': 'store_unavailable'}, status: 503);
      }
    });

    // ── 운영 관리 패널 API (/admin/*) ──
    //
    // 인증은 **Supabase JWT 가 아니라 관리자 키**다(운영자는 게임 계정이
    // 아닐 수 있다). 그래서 authed 라우터가 아닌 public 에 달고 키를 직접 본다.
    //
    // ⚠️ `ADMIN_KEY` 가 없으면 **엔드포인트를 아예 열지 않는다.** 기본값을 두면
    // 환경변수를 깜빡한 배포가 전 유저에게 재화를 뿌릴 수 있는 문을 연 채로 뜬다.
    // ⚠️ **양끝 공백·BOM 을 반드시 걷어낸다.** PowerShell 로 시크릿을 만들면
    // (`$key | gcloud secrets create ... --data-file=-`) 값 끝에 CRLF 가, 앞에
    // BOM 이 붙는다. 실제로 40자 키가 46바이트로 저장돼 로그인이 계속 실패했다.
    // Dart 의 trim() 은 U+FEFF(BOM)까지 제거한다.
    final key = (adminKey ?? Platform.environment['ADMIN_KEY'] ?? '').trim();

    /// 관리자 키 검사. 길이·내용이 모두 같을 때만 통과(시간차를 줄여 비교).
    bool adminOk(Request req) {
      if (key.isEmpty) return false;
      // 붙여넣기에 딸려온 공백도 걷어낸다(사람이 손으로 옮기는 값이다).
      final given = (req.headers['x-admin-key'] ?? '').trim();
      if (given.length != key.length) return false;
      var diff = 0;
      for (var i = 0; i < key.length; i++) {
        diff |= given.codeUnitAt(i) ^ key.codeUnitAt(i);
      }
      return diff == 0;
    }

    /// 운영 지급의 **1건당 상한**. 오타 한 번으로 전 유저에게 젤리 100만이
    /// 나가는 사고를 코드로 막는다(UI 검증만으로는 못 막는다).
    const adminMaxGold = 10000000;
    const adminMaxJelly = 10000;
    const adminMaxMaterial = 100000;

    /// 지급 필드 정규화 + 상한 검사.
    ///
    /// 상한을 넘으면 **잘라서 보내지 않고 거절**한다. 조용히 잘라 보내면
    /// 운영자는 100만을 보냈다고 믿는데 실제로는 1만이 나가 있다.
    /// 음수는 0으로 만든다(운영 실수로 재화를 뺏는 일은 없어야 한다).
    (Map<String, int>, String?) rewardFields(Map<String, dynamic> b) {
      int n(String k) {
        final v = b[k];
        final i = (v is num) ? v.toInt() : 0;
        return i < 0 ? 0 : i;
      }

      final out = {
        'gold': n('gold'),
        'jelly': n('jelly'),
        'chitin': n('chitin'),
        'mineral': n('mineral'),
        'sap': n('sap'),
      };
      if (out['gold']! > adminMaxGold) return (out, 'gold_too_large');
      if (out['jelly']! > adminMaxJelly) return (out, 'jelly_too_large');
      for (final k in ['chitin', 'mineral', 'sap']) {
        if (out[k]! > adminMaxMaterial) return (out, 'material_too_large');
      }
      return (out, null);
    }

    /// 본문 파싱 + 키 검사를 한 번에. 통과하면 본문을, 아니면 응답을 돌려준다.
    Future<(Map<String, dynamic>?, Response?)> adminBody(Request req) async {
      if (!adminOk(req)) {
        return (null, _json({'error': 'unauthorized'}, status: 401));
      }
      try {
        final raw = await req.readAsString();
        final b = raw.isEmpty
            ? <String, dynamic>{}
            : jsonDecode(raw) as Map<String, dynamic>;
        return (b, null);
      } catch (_) {
        return (null, _json({'error': 'bad_request'}, status: 400));
      }
    }

    String? clean(Object? v, int max) {
      final s = v?.toString().trim() ?? '';
      if (s.isEmpty) return null;
      return s.length > max ? s.substring(0, max) : s;
    }

    public.get('/admin/data', (Request req) async {
      if (!adminOk(req)) return _json({'error': 'unauthorized'}, status: 401);
      try {
        return _json(await store.adminData());
      } on StateStoreException catch (e) {
        stderr.writeln('[admin/data] $e');
        return _json({'error': 'store_unavailable'}, status: 503);
      }
    });

    public.post('/admin/notice', (Request req) async {
      final (b, err) = await adminBody(req);
      if (err != null) return err;
      final title = clean(b!['title'], 100);
      if (title == null) return _json({'error': 'title_required'}, status: 400);
      try {
        await store.insertRow('notices', {
          'title': title,
          'body': clean(b['body'], 1000) ?? '',
          'pinned': b['pinned'] == true,
          if (b['endsAt'] != null) 'ends_at': b['endsAt'],
        });
        return _json({'ok': true});
      } on StateStoreException catch (e) {
        stderr.writeln('[admin/notice] $e');
        return _json({'error': 'store_unavailable'}, status: 503);
      }
    });

    public.post('/admin/mail', (Request req) async {
      final (b, err) = await adminBody(req);
      if (err != null) return err;
      final title = clean(b!['title'], 100);
      if (title == null) return _json({'error': 'title_required'}, status: 400);
      final (reward, tooBig) = rewardFields(b);
      if (tooBig != null) return _json({'error': tooBig}, status: 400);
      try {
        await store.insertRow('user_mail', {
          // null = 전체 유저 대상(점검 보상 등).
          'user_id': clean(b['userId'], 64),
          'title': title,
          'body': clean(b['body'], 1000) ?? '',
          ...reward,
          if (b['endsAt'] != null) 'ends_at': b['endsAt'],
        });
        return _json({'ok': true});
      } on StateStoreException catch (e) {
        stderr.writeln('[admin/mail] $e');
        return _json({'error': 'store_unavailable'}, status: 503);
      }
    });

    /// 이벤트 참가권 지급(테스트·운영용).
    ///
    /// ⚠️ 참가권은 **서버 소유 필드**라 앱이 세이브를 고쳐 늘릴 수 없다 —
    /// 그래서 개발자 모드도 이 경로로 받아야 한다. 아무나 부르면 순위가 무너지므로
    /// **운영 키(`x-admin-key`)** 로만 연다. 상한도 둔다(오타 한 번으로 참가권
    /// 수천 장이 나가면 그 회차 순위는 그대로 무효다).
    public.post('/admin/event-ticket', (Request req) async {
      final (b, err) = await adminBody(req);
      if (err != null) return err;
      final userId = clean(b!['userId'], 64);
      if (userId == null) return _json({'error': 'user_required'}, status: 400);
      final want = (b['amount'] is num) ? (b['amount'] as num).toInt() : 1;
      if (want < 1 || want > 20) {
        return _json({'error': 'amount_out_of_range'}, status: 400);
      }
      final ev = cfg.event;
      if (ev == null) return _json({'error': 'event_closed'}, status: 404);
      try {
        final raw = await store.load(userId);
        if (raw == null) return _json({'error': 'no_save'}, status: 404);
        final save = SaveGame.fromJson(migrateToCurrent(raw));
        final now = actions.eventTicketsNow(save);
        // 상한을 넘겨서 주지 않는다 — 상한이 곧 하루 판수 제한이다.
        final next = (now.tickets + want).clamp(0, ev.ticketMax);
        final out = save.copyWith(eventTickets: next, eventTicketsAt: now.at);
        await store.save(userId, out.toJson());
        return _json({'ok': true, 'tickets': next, 'max': ev.ticketMax});
      } on StateStoreException catch (e) {
        stderr.writeln('[admin/event-ticket] $e');
        return _json({'error': 'store_unavailable'}, status: 503);
      }
    });

    public.post('/admin/code', (Request req) async {
      final (b, err) = await adminBody(req);
      if (err != null) return err;
      final code = clean(b!['code'], 32)?.toUpperCase();
      // 코드는 손으로 입력한다 — 헷갈릴 여지가 없게 영문 대문자·숫자만 받는다.
      if (code == null || !RegExp(r'^[A-Z0-9]{4,32}$').hasMatch(code)) {
        return _json({'error': 'bad_code_format'}, status: 400);
      }
      final (reward, tooBig) = rewardFields(b);
      if (tooBig != null) return _json({'error': tooBig}, status: 400);
      final maxUses = (b['maxUses'] as num?)?.toInt();
      try {
        await store.insertRow('gift_codes', {
          'code': code,
          ...reward,
          if (maxUses != null && maxUses > 0) 'max_uses': maxUses,
          if (b['endsAt'] != null) 'ends_at': b['endsAt'],
        });
        return _json({'ok': true});
      } on StateStoreException catch (e) {
        stderr.writeln('[admin/code] $e');
        // 같은 코드가 이미 있으면 여기로 온다(기본키 충돌).
        return _json({'error': 'insert_failed'}, status: 409);
      }
    });

    /// 운영자 이름으로 전체 채팅에 글쓰기.
    ///
    /// 보내는 계정은 `ADMIN_CHAT_USER_ID`(실재하는 uuid). 앱의 채팅 목록은
    /// 파싱에 한 줄만 실패해도 **전체가 빈 목록**이 되므로, 존재하지 않는
    /// id 로 쓰면 모든 유저의 채팅창이 비어버린다 — 그래서 설정을 강제한다.
    final chatUserId =
        (adminChatUserId ?? Platform.environment['ADMIN_CHAT_USER_ID'] ?? '')
            .trim();

    public.post('/admin/chat', (Request req) async {
      final (b, err) = await adminBody(req);
      if (err != null) return err;
      // 요청이 잘못된 것과 서버 설정이 빠진 것은 구분해서 알린다.
      final body = clean(b!['body'], 100); // 테이블 제약과 같은 100자
      if (body == null) return _json({'error': 'body_required'}, status: 400);
      if (chatUserId.isEmpty) {
        return _json({'error': 'admin_chat_user_id_missing'}, status: 503);
      }
      final nickname = clean(b['nickname'], 20) ?? '운영자';
      try {
        await store.insertAdminChat(
          userId: chatUserId,
          nickname: nickname,
          body: body,
        );
        return _json({'ok': true});
      } on StateStoreException catch (e) {
        stderr.writeln('[admin/chat] $e');
        return _json({'error': 'store_unavailable'}, status: 503);
      }
    });

    public.post('/admin/delete', (Request req) async {
      final (b, err) = await adminBody(req);
      if (err != null) return err;
      final id = clean(b!['id'], 64);
      final target = switch (b['kind']?.toString()) {
        'notice' => ('notices', 'id'),
        'mail' => ('user_mail', 'id'),
        'code' => ('gift_codes', 'code'),
        // 채팅 모더레이션 — 유저는 본인 글만 지울 수 있어(RLS), 부적절한 글을
        // 내리려면 서버가 대신 지워야 한다(UGC 정책 요구사항).
        'chat' => ('chat_messages', 'id'),
        _ => null,
      };
      if (target == null || id == null) {
        return _json({'error': 'bad_request'}, status: 400);
      }
      try {
        await store.deleteRow(target.$1, target.$2, id);
        return _json({'ok': true});
      } on StateStoreException catch (e) {
        stderr.writeln('[admin/delete] $e');
        return _json({'error': 'store_unavailable'}, status: 503);
      }
    });

    authed.post(
      '/pvp/ticket/ad',
      (Request req) => ticketAction(req, 'ticket/ad', actions.grantAdTicket),
    );

    authed.post(
      '/pvp/ticket/refill',
      (Request req) =>
          ticketAction(req, 'ticket/refill', actions.refillPvpTickets),
    );
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
      .addMiddleware(limitBodySize())
      .addHandler(cascade.handler);
}

/// 액션 실패 응답 본문. 티켓 부족이면 **서버가 아는 잔량·충전시각을 함께** 준다.
///
/// 앱이 로컬로만 세던 잔량이 서버와 어긋났을 때(재설치·구버전 세이브),
/// 그냥 "실패"라고만 하면 사용자는 화면에 티켓이 남아 보이는데 못 싸운다.
/// 정확한 값을 함께 주면 앱이 즉시 맞춰 그린다.
Map<String, dynamic> _ticketError(
  GameActions actions,
  SaveGame save,
  String? error,
) {
  if (error != 'no_tickets') return {'error': error};
  final t = actions.ticketsNow(save);
  return {
    'error': error,
    'tickets': t.tickets,
    'ticketsAt': t.at.toIso8601String(),
  };
}

/// 정상 세이브의 몇 배까지 허용할지 — 이 위는 사고로 본다.
///
/// 채집함 100마리 세이브가 60KB 수준이라 1MB 는 20배 가까운 여유다.
/// 그런데도 넘는 요청은 읽어서 파싱할 가치가 없다. 2026-07 에 13.6MB 짜리
/// 세이브가 10초마다 올라와 인스턴스 시간·DB 를 모두 태웠다 — 그때
/// 이 가드가 있었다면 첫 요청에서 413 으로 끝났다.
const int kMaxRequestBytes = 1 * 1024 * 1024;

/// 과대 요청을 **읽기 전에** 413 으로 끊는 미들웨어.
///
/// `Content-Length` 가 있으면 그걸로 즉시 거절한다. 없으면(청크 전송)
/// 본문을 그대로 흘리되 누적 바이트가 상한을 넘는 순간 스트림을 끊는다.
Middleware limitBodySize({int maxBytes = kMaxRequestBytes}) {
  return (Handler inner) {
    return (Request req) async {
      final declared = req.contentLength;
      if (declared != null && declared > maxBytes) {
        stderr.writeln('[limit] ${req.requestedUri.path}: $declared bytes 거절');
        return _json({'error': 'payload_too_large'}, status: 413);
      }
      if (declared != null) return inner(req);

      var seen = 0;
      final guarded = req.read().map((chunk) {
        seen += chunk.length;
        if (seen > maxBytes) {
          throw StateError('요청 본문이 상한($maxBytes bytes)을 넘었습니다');
        }
        return chunk;
      });
      try {
        return await inner(req.change(body: guarded));
      } on StateError catch (e) {
        stderr.writeln('[limit] ${req.requestedUri.path}: $e');
        return _json({'error': 'payload_too_large'}, status: 413);
      }
    };
  };
}

/// 이벤트 점수 기록. 실패해도 판을 무르지 않는다 — 참가권은 이미 나갔고,
/// 다음 도전에서 최고 기록이면 다시 올라간다.
Future<bool> _submitEventScore(
  StateStore store,
  String userId,
  SaveGame save,
  Map<String, dynamic> extra,
  List<String> teamIds,
) async {
  try {
    await store.submitEventScore(
      roundId: '${save.eventRoundId}',
      userId: userId,
      nickname: save.nickname,
      score: (extra['score'] as num).toInt(),
      wave: (extra['cleared'] as num).toInt(),
      team: {'ids': teamIds},
    );
    return true;
  } catch (e) {
    stderr.writeln('[event/submit] $userId: $e');
    return false;
  }
}
