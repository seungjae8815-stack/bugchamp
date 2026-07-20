import 'dart:async';

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

  final state = await server.fetchState();
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

/// 서버 권위 모드에서 방치 수입을 주기적으로 정산한다.
///
/// 15초 주기 + 앱이 백그라운드로 갈 때. 금액은 서버가 정하므로
/// 클라이언트는 "정산해줘"만 보낸다.
///
/// 실패해도 조용히 넘어간다 — 다음 주기에 다시 시도하면 되고,
/// 경과시간 기준이라 **놓친 구간이 사라지지 않는다**(중복 정산도 없다).
class ServerSyncTimer {
  ServerSyncTimer(this._ref);

  final WidgetRef _ref;
  Timer? _timer;

  static const period = Duration(seconds: 15);

  void start() {
    if (!_ref.read(gameServerProvider).available) return;
    _timer?.cancel();
    _timer = Timer.periodic(period, (_) => syncNow());
  }

  Future<void> syncNow() async {
    final server = _ref.read(gameServerProvider);
    if (!server.available) return;
    final res = await server.sync();
    if (res.isOk && res.save != null) {
      await _ref
          .read(saveControllerProvider.notifier)
          .adoptServerSave(res.save!);
    } else {
      debugPrint('[sync] 정산 실패(다음 주기 재시도): ${res.error}');
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
