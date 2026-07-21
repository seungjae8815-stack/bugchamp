import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'game_server.dart';
import 'save_controller.dart';

/// 앱 시작 시 서버와 세이브를 맞춘다.
///
/// 서버 권위 모델에서는 **서버에 세이브가 있어야** 구매·전투가 동작한다.
/// 그런데 기존 유저는 진행도가 기기에만 있으므로, 최초 1회 올려줘야 한다.
///
/// 규칙:
/// - 서버에 세이브가 **있으면** → 그걸 채택한다(서버가 진실).
/// - **없으면** → 로컬 것을 올린다(진행도 이관).
///
/// ⚠️ 순서를 뒤집으면 안 된다. 서버가 빈 세이브를 만들고 앱이 그걸 채택하면
/// 기존 진행도가 통째로 날아간다.
Future<void> syncWithServer(WidgetRef ref) async {
  final server = ref.read(gameServerProvider);
  if (!server.available) return;

  // 앱을 갓 켜면 **저장된 세션 토큰이 만료**돼 있을 수 있다. Supabase 가
  // 백그라운드로 토큰을 갱신하는 동안 첫 조회가 401 을 맞는다(콜드스타트 경쟁).
  // 인증이 준비될 시간을 주고 몇 번 재시도한다 — 여기서 포기하면 이번 실행 내내
  // 서버 세이브를 채택하지 못해, 다른 기기에서 더 진행한 상태가 묻힌다.
  final state = await fetchStateWithAuthRetry(server.fetchState);
  if (!state.isOk) {
    debugPrint('[sync] 서버 상태 조회 실패: ${state.error}');
    return; // 로컬 유지 — 연결이 없다고 진행도를 건드리지 않는다.
  }

  final ctrl = ref.read(saveControllerProvider.notifier);
  final remote = state.save;
  if (remote != null) {
    await ctrl.adoptServerSave(remote);
    return;
  }

  // 서버에 없음 → 로컬을 이관한다.
  final local = ref.read(saveControllerProvider).requireValue;
  final res = await server.bootstrap(local.toJson());
  if (res.isOk) {
    debugPrint('[sync] 로컬 세이브를 서버로 이관했다');
  } else if (res.save != null) {
    // 그사이 다른 기기가 먼저 올렸다 → 서버 것을 따른다.
    await ctrl.adoptServerSave(res.save!);
  } else {
    debugPrint('[sync] 이관 실패: ${res.error}');
  }
}

/// 인증이 아직 준비 안 됐거나 일시적 오류라 재시도할 가치가 있는지.
///
/// 401 은 보통 "저장된 토큰이 만료됐고 갱신이 진행 중"이라는 뜻이라
/// 여기서만 재시도 대상으로 본다(다른 경로에서는 401 을 재시도하지 않는다).
bool _authNotReady(ServerResult r) =>
    r.status == 401 || r.status == 0 || r.status >= 500;

/// 상태 조회를 하되, 인증이 아직 준비 안 됐으면(콜드스타트 토큰 갱신 중)
/// 준비될 때까지 짧게 재시도한다. 성공하거나 재시도가 소진되면 반환.
///
/// 진짜 실패(잘못된 토큰 등)면 재시도를 다 쓰고 마지막 실패를 그대로 돌려준다
/// — 호출부는 지금처럼 로컬을 유지한다.
@visibleForTesting
Future<ServerResult> fetchStateWithAuthRetry(
  Future<ServerResult> Function() fetch, {
  int maxAttempts = 7,
  Duration delay = const Duration(milliseconds: 700),
}) async {
  var state = await fetch();
  for (var i = 1; i < maxAttempts && !state.isOk && _authNotReady(state); i++) {
    await Future<void>.delayed(delay);
    state = await fetch();
  }
  return state;
}

/// 기기 권위 세이브를 **주기적으로 서버에 올린다**(저장·백업).
///
/// 솔로 루프는 기기가 즉시 처리하고, 이 업로더가 변경분이 있을 때만
/// 몇 초마다 `/save` 로 올린다 — 서버는 보호필드(트로피·IAP)·골드상한만
/// 손대고 저장한다. 앱이 백그라운드로 갈 때도 [flush] 한다(놓친 진행 방지).
///
/// 변경이 없으면 올리지 않아 **호출 수를 억제**한다(AFK 중엔 사실상 0).
class ServerSaveUploader {
  ServerSaveUploader(this._ref);

  final WidgetRef _ref;
  Timer? _timer;

  /// 마지막으로 올린 세이브의 직렬화(변경 감지용).
  String? _lastUploaded;
  bool _inFlight = false;

  static const period = Duration(seconds: 10);

  void start() {
    if (!_ref.read(gameServerProvider).available) return;
    _timer?.cancel();
    _timer = Timer.periodic(period, (_) => flush());
  }

  /// 변경분이 있으면 서버에 올린다. 이미 올린 상태면 건너뛴다.
  Future<void> flush() async {
    final server = _ref.read(gameServerProvider);
    if (!server.available || _inFlight) return;
    final save = _ref.read(saveControllerProvider).value;
    if (save == null) return;

    final json = save.toJson();
    final encoded = jsonEncode(json);
    if (encoded == _lastUploaded) return; // 변경 없음 → 호출 안 함

    _inFlight = true;
    try {
      final res = await server.uploadSave(json);
      if (res.isOk) {
        _lastUploaded = encoded;
        // 서버가 골드를 잘랐으면(치팅 의심) 그 값을 채택해 화면과 맞춘다.
        if (res.data?['clamped'] == true && res.save != null) {
          await _ref
              .read(saveControllerProvider.notifier)
              .adoptServerSave(res.save!);
          _lastUploaded = jsonEncode(res.save);
        }
      } else if (res.status == 409) {
        // 서버에 저장본이 없다 → 최초 이관(부트스트랩)이 먼저.
        final boot = await server.bootstrap(json);
        if (boot.isOk) _lastUploaded = encoded;
      } else {
        debugPrint('[save] 업로드 실패(다음 주기 재시도): ${res.error}');
      }
    } finally {
      _inFlight = false;
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
