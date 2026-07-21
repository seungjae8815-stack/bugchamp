import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// 권위 서버 호출 결과.
class ServerResult {
  const ServerResult.ok(this.data) : error = null, status = 200;
  const ServerResult.fail(this.error, this.status) : data = null;

  /// 서버가 돌려준 JSON(성공 시). `save` 키에 갱신된 세이브가 들어 있다.
  final Map<String, dynamic>? data;
  final String? error;
  final int status;

  bool get isOk => data != null;

  /// 일시적 오류라 재시도할 가치가 있는지(네트워크·5xx).
  bool get isRetryable => !isOk && (status == 0 || status >= 500);

  Map<String, dynamic>? get save => data?['save'] as Map<String, dynamic>?;
}

/// 권위 서버 계약.
///
/// **재화가 변하는 액션은 서버가 확정한다.** 클라이언트는 "무엇을 하고 싶다"만
/// 보내고 결과를 받는다. 서버가 붙어 있지 않으면 [available] 이 false 이고,
/// 호출부는 기존 로컬 경로로 폴백한다(전환 중 안전장치).
abstract interface class GameServer {
  bool get available;

  /// 내 세이브 조회.
  Future<ServerResult> fetchState();

  /// 구매 지급 — 서버가 영수증을 검증한 뒤 지급한다.
  Future<ServerResult> purchase({
    required String productId,
    required String purchaseToken,
  });

  /// PvP 전투 — 서버가 시뮬레이션하고 승패·보상을 확정한다.
  ///
  /// [opponentUserId] 는 실제 유저 상대, [tierId] 는 야생(합성) 상대.
  /// 야생은 **서버가 상대를 만들어** 응답의 `foe` 로 돌려준다 — 앱이 따로
  /// 만들면 연출과 서버 결과가 갈린다.
  Future<ServerResult> battle({
    required List<String> teamBugIds,
    String? opponentUserId,
    String? tierId,
  });

  /// 수동 전투 시작 — 세션을 열고 상대 스탯을 받는다.
  /// **시드는 응답에 없다**(있으면 상대의 수를 미리 계산할 수 있다).
  Future<ServerResult> startManualBattle({
    required List<String> teamBugIds,
    String? opponentUserId,
    String? tierId,
  });

  /// 수동 전투 한 수 — 이번 라운드 결과만 돌아온다.
  Future<ServerResult> stepManualBattle({
    required String sessionId,
    required String stance,
  });

  /// 방치 수입 정산 — 금액은 서버가 정한다.
  Future<ServerResult> sync();

  /// 업그레이드 1단계.
  Future<ServerResult> upgrade(String kindKey, {int count});

  /// 부위 강화 1단계.
  Future<ServerResult> enhance(String bugId, String partKey);

  /// 수련(성충 레벨업).
  Future<ServerResult> train(String bugId);

  /// 돌파 시작(레벨 상한 확장 — 재화 소비 + 타이머).
  Future<ServerResult> breakthrough(String bugId);

  /// 돌파 완료 수령(타이머 종료 후 또는 젤리 즉시완료).
  Future<ServerResult> completeBreakthrough(String bugId, {bool viaJelly});

  /// 짝짓기 시작 — **시드는 서버가 정한다**(클라가 고를 수 없다).
  Future<ServerResult> breed(String motherId, String fatherId);

  /// 산란 완료 수령.
  Future<ServerResult> collectBreeding(String slotId, {bool viaJelly});

  /// 부화 수령(알 → 유충).
  Future<ServerResult> collectIncubated(String bugId);

  /// 곤충 분해 → 젤리.
  Future<ServerResult> disassemble(String bugId);

  /// 미션 보상 수령(진행도·목표는 서버가 판정).
  Future<ServerResult> claimMission(String missionId);

  /// 깜짝선물 수령([doubled]=광고 배수).
  Future<ServerResult> claimGift(String giftId, {bool doubled});

  /// 일일보상 수령(UTC 날짜당 1회).
  Future<ServerResult> claimDaily(String rewardId);

  /// 로드맵 챕터 클리어 보상(스테이지 기준, 서버 확정).
  Future<ServerResult> claimRoadmap();

  /// 로컬 세이브를 서버로 **최초 1회 이관**한다.
  /// 서버에 이미 세이브가 있으면 409 와 함께 서버 것을 돌려준다.
  Future<ServerResult> bootstrap(Map<String, dynamic> save);
}

/// 서버 미설정 — 항상 사용 불가.
class NoGameServer implements GameServer {
  const NoGameServer();

  @override
  bool get available => false;
  @override
  Future<ServerResult> fetchState() async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> purchase({
    required String productId,
    required String purchaseToken,
  }) async => const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> battle({
    required List<String> teamBugIds,
    String? opponentUserId,
    String? tierId,
  }) async => const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> bootstrap(Map<String, dynamic> save) async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> sync() async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> upgrade(String kindKey, {int count = 1}) async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> enhance(String bugId, String partKey) async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> train(String bugId) async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> breakthrough(String bugId) async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> completeBreakthrough(
    String bugId, {
    bool viaJelly = false,
  }) async => const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> breed(String motherId, String fatherId) async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> collectBreeding(
    String slotId, {
    bool viaJelly = false,
  }) async => const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> collectIncubated(String bugId) async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> disassemble(String bugId) async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> claimMission(String missionId) async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> claimGift(String giftId, {bool doubled = false}) async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> claimDaily(String rewardId) async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> claimRoadmap() async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> startManualBattle({
    required List<String> teamBugIds,
    String? opponentUserId,
    String? tierId,
  }) async => const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> stepManualBattle({
    required String sessionId,
    required String stance,
  }) async => const ServerResult.fail('unavailable', 0);
}

/// HTTP 구현. 인증은 **Supabase 세션 토큰**을 그대로 실어 보낸다
/// (서버가 JWKS 공개키로 검증한다).
class HttpGameServer implements GameServer {
  HttpGameServer({
    required this.baseUrl,
    required SupabaseClient client,
    http.Client? httpClient,
  }) : _client = client,
       _http = httpClient ?? http.Client();

  final String baseUrl;
  final SupabaseClient _client;
  final http.Client _http;

  @override
  bool get available => baseUrl.isNotEmpty;

  String? get _token => _client.auth.currentSession?.accessToken;

  Future<ServerResult> _send(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final token = _token;
    if (token == null) return const ServerResult.fail('no_session', 401);
    try {
      final uri = Uri.parse('$baseUrl$path');
      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };
      final res = method == 'GET'
          ? await _http.get(uri, headers: headers)
          : await _http.post(uri, headers: headers, body: jsonEncode(body));

      final decoded = res.body.isEmpty
          ? const <String, dynamic>{}
          : jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return ServerResult.ok(decoded);
      }
      return ServerResult.fail(
        decoded['error']?.toString() ?? 'http_${res.statusCode}',
        res.statusCode,
      );
    } catch (e) {
      debugPrint('[server] $method $path 실패: $e');
      // status 0 = 네트워크 오류 → 재시도 대상.
      return const ServerResult.fail('network', 0);
    }
  }

  @override
  Future<ServerResult> fetchState() => _send('GET', '/state');

  @override
  Future<ServerResult> purchase({
    required String productId,
    required String purchaseToken,
  }) => _send('POST', '/purchase', {
    'productId': productId,
    'purchaseToken': purchaseToken,
  });

  @override
  Future<ServerResult> battle({
    required List<String> teamBugIds,
    String? opponentUserId,
    String? tierId,
  }) => _send('POST', '/battle', {
    'teamBugIds': teamBugIds,
    'opponentUserId': ?opponentUserId,
    'tierId': ?tierId,
  });

  @override
  Future<ServerResult> bootstrap(Map<String, dynamic> save) =>
      _send('POST', '/state', {'save': save});

  @override
  Future<ServerResult> sync() => _send('POST', '/sync', const {});

  @override
  Future<ServerResult> upgrade(String kindKey, {int count = 1}) =>
      _send('POST', '/upgrade', {'kind': kindKey, 'count': count});

  @override
  Future<ServerResult> enhance(String bugId, String partKey) =>
      _send('POST', '/enhance', {'bugId': bugId, 'part': partKey});

  @override
  Future<ServerResult> train(String bugId) =>
      _send('POST', '/train', {'bugId': bugId});

  @override
  Future<ServerResult> breakthrough(String bugId) =>
      _send('POST', '/breakthrough', {'bugId': bugId});

  @override
  Future<ServerResult> completeBreakthrough(
    String bugId, {
    bool viaJelly = false,
  }) => _send('POST', '/breakthrough/complete', {
    'bugId': bugId,
    'viaJelly': viaJelly,
  });

  @override
  Future<ServerResult> breed(String motherId, String fatherId) =>
      _send('POST', '/breed', {'motherId': motherId, 'fatherId': fatherId});

  @override
  Future<ServerResult> collectBreeding(
    String slotId, {
    bool viaJelly = false,
  }) =>
      _send('POST', '/breed/collect', {'slotId': slotId, 'viaJelly': viaJelly});

  @override
  Future<ServerResult> collectIncubated(String bugId) =>
      _send('POST', '/incubate/collect', {'bugId': bugId});

  @override
  Future<ServerResult> disassemble(String bugId) =>
      _send('POST', '/disassemble', {'bugId': bugId});

  @override
  Future<ServerResult> claimMission(String missionId) =>
      _send('POST', '/mission/claim', {'missionId': missionId});

  @override
  Future<ServerResult> claimGift(String giftId, {bool doubled = false}) =>
      _send('POST', '/gift/claim', {'giftId': giftId, 'doubled': doubled});

  @override
  Future<ServerResult> claimDaily(String rewardId) =>
      _send('POST', '/daily/claim', {'rewardId': rewardId});

  @override
  Future<ServerResult> claimRoadmap() =>
      _send('POST', '/roadmap/claim', const {});

  @override
  Future<ServerResult> startManualBattle({
    required List<String> teamBugIds,
    String? opponentUserId,
    String? tierId,
  }) => _send('POST', '/battle/manual/start', {
    'teamBugIds': teamBugIds,
    'opponentUserId': ?opponentUserId,
    'tierId': ?tierId,
  });

  @override
  Future<ServerResult> stepManualBattle({
    required String sessionId,
    required String stance,
  }) => _send('POST', '/battle/manual/step', {
    'sessionId': sessionId,
    'stance': stance,
  });
}

/// 교체 가능한 권위 서버. 기본은 미설정(로컬 경로 유지).
final gameServerProvider = Provider<GameServer>((ref) => const NoGameServer());
