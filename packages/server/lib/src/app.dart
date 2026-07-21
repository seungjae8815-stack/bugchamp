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
Map<String, dynamic> _foeJson(BattleBug b, String speciesId) => {
  'id': b.id,
  'sp': speciesId,
  'name': b.name,
  'el': b.element.key,
  'tm': b.temperament.key,
  'stance': b.preferredStance.name,
  'hp': b.maxHp,
  'atk': b.atk,
  'def': b.def,
  'spd': b.spd,
};

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
}) {
  final verifier =
      jwtVerifier ?? SupabaseJwtVerifier.forProject(config.supabaseUrl);

  final public = Router()
    // 헬스체크 — 인증 없이 접근 가능해야 한다.
    //
    // ⚠️ `/healthz` 를 쓰면 안 된다. Google Cloud 인프라가 그 경로를
    //    가로채서 컨테이너까지 요청이 오지 않는다(실제로 404 를 받았다).
    ..get('/health', (Request _) => Response.ok('ok'))
    // 앱 버전 안내 — **인증 없이**(앱이 시작 즉시, 로그인 전에도 확인).
    //   min    = 이 미만이면 강제 업데이트(막힘). 서버 규약이 깨질 때 올린다.
    //   latest = 이 미만이면 권장 업데이트(닫기 가능).
    // 값은 Cloud Run 환경변수로 관리 → 재배포 없이 gcloud run update 로 바꾼다.
    ..get('/version', (Request _) {
      int env(String k) => int.tryParse(Platform.environment[k] ?? '') ?? 0;
      return _json({
        'min': env('MIN_SUPPORTED_VERSION'),
        'latest': env('LATEST_VERSION'),
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
        final save = SaveGame.fromJson(sanitized);
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
        final r = actions.mergeSave(stored, migrateToCurrent(incoming));
        if (!r.isOk) return _json({'error': r.error}, status: r.status);
        await store.save(user.id, r.save!.toJson());
        return _json({'save': r.save!.toJson(), ...r.extra});
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

        final List<BattleBug> foe;
        final List<String> foeSpecies;
        final double rewardMult;
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
          rewardMult = wild.tier.rewardMult;
        }

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
        );
        await store.saveSession(sessionId, user.id, session.toJson());

        // 상대 스탯은 화면 표시에 필요하므로 준다. 시드는 주지 않는다.
        return _json({
          'sessionId': sessionId,
          'location': session.location.key,
          'energyA': 1, // 엔진 시작 기력
          'foe': [
            for (var i = 0; i < foe.length; i++)
              _foeJson(foe[i], i < foeSpecies.length ? foeSpecies[i] : ''),
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
        final double rewardMult;
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
        if (!r.isOk) return _json({'error': r.error}, status: r.status);
        await store.save(user.id, r.save!.toJson());
        return _json({
          'save': r.save!.toJson(),
          ...r.extra,
          // 야생은 서버가 만든 상대다 — 앱이 이걸로 그리고 재생해야
          // 연출이 서버 결과와 일치한다.
          'foe': [
            for (var i = 0; i < foe.length; i++)
              _foeJson(foe[i], i < foeSpecies.length ? foeSpecies[i] : ''),
          ],
        });
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
