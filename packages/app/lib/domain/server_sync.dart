import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:core_save/core_save.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'game_server.dart';
import 'providers.dart';
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
Future<void> syncWithServer(WidgetRef ref) => syncSaveWith(
  server: ref.read(gameServerProvider),
  ctrl: ref.read(saveControllerProvider.notifier),
  localSave: () => ref.read(saveControllerProvider.future),
);

/// [syncWithServer] 의 알맹이 — `WidgetRef` 없이 테스트할 수 있게 분리했다
/// (Riverpod 3 의 WidgetRef 는 sealed 라 가짜로 만들 수 없다).
///
/// [localSave] 는 **Future 를 돌려주는 함수**다. 세이브가 아직 로딩 중일 수
/// 있어서(첫 실행) 값을 바로 요구하면 안 된다.
Future<void> syncSaveWith({
  required GameServer server,
  required SaveController ctrl,
  required Future<SaveGame> Function() localSave,
}) async {
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

  final remote = state.save;
  if (remote != null) {
    // ⚠️ **서버를 조건 없이 따르면 안 된다.**
    //
    // 예전에는 그렇게 했다. 마지막 업로드가 실패했거나(크래시·네트워크 끊김)
    // 서버 저장본이 더 오래됐으면, 앱을 켤 때마다 **그 사이 진행이 통째로
    // 사라졌다** — "돈이 줄어든다 · 스테이지가 되돌아간다 · 부화한 곤충이
    // 없어진다"가 전부 이 한 경로였다(2026-08-30 유저 제보).
    // 특히 20260830 은 실행 즉시 죽던 빌드라(R8) 크래시로 flush 를 못 하고,
    // 다음 실행에 되돌아가는 일이 반복됐다.
    //
    // 그래서 **더 진행된 쪽**을 남긴다. 판단 기준은 `lastSeen` 이 아니라
    // **진행도**다 — 시계는 기기마다 틀어질 수 있지만 스테이지·레벨은
    // 되돌아갈 이유가 없다.
    final local = await localSave();
    if (_localIsAhead(local, remote)) {
      debugPrint('[sync] 로컬이 더 진행됨 — 서버 채택을 건너뛴다');
      // 다음 주기 업로드가 서버를 따라잡게 둔다(여기서 올리면 중복 경로가 된다).
      return;
    }
    await ctrl.adoptServerSave(remote);
    return;
  }

  // 서버에 없음 → 로컬을 이관한다.
  //
  // ⚠️ `requireValue` 를 쓰면 안 된다. **완전 신규 설치**에서는 세이브가 아직
  // 로딩 중(AsyncLoading)이라 즉시 예외가 나고, 타이틀이 "불러오는 중"에서
  // 영영 멈춘다(기존 유저는 세이브가 이미 있어 이 경로를 안 밟는다).
  // 로드가 끝날 때까지 기다렸다가 이관한다.
  final local = await localSave();
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

/// 이 실패를 **연결 끊김**으로 볼 것인가.
///
/// `status == 0` 은 요청이 서버에 닿지도 못한 경우(네트워크 오류)다. 그 외에는
/// **응답을 받았다는 뜻이므로 네트워크는 멀쩡하다** — 막으면 안 된다.
/// 특히 `401 no_session` 은 **게스트라 세션이 없는 정상 상태**이고, 이걸 끊김으로
/// 세면 로그인 안 한 유저가 게임을 아예 못 한다.
bool countsAsDisconnect(int status) => status == 0;

/// 서버 연결이 끊겼는지. 화면(앱 셸)이 듣고 **게임을 멈춘 뒤 재접속을 요구**한다.
///
/// 이 게임은 오프라인 플레이를 허용하지 않는다 — 타이틀에서 네트워크가 없으면
/// 입장 자체를 막는다. 그런데 **입장 뒤에는** 감시가 없어서, 끊긴 채 계속 놀다가
/// 앱을 껐다 켜면 서버의 낡은 세이브를 채택하며 그동안의 진행이 사라졌다.
/// 들어온 뒤에도 같은 기준을 적용한다.
final serverDisconnected = ValueNotifier<bool>(false);

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

  /// 연속 실패 횟수. [_failThreshold] 를 넘으면 끊긴 것으로 본다.
  int _fails = 0;

  /// 몇 번 연속 실패해야 "끊김"인가. 한 번의 실패로 튕기면 지하철에서
  /// 잠깐 끊길 때마다 쫓겨난다 — 짧게 재시도해 보고 판단한다.
  @visibleForTesting
  static const failThreshold = 3;

  /// 실패 뒤 재시도 간격. 60초를 그대로 기다리면 유저가 3분 동안
  /// **저장되지 않는 줄 모르고** 논다.
  static const retryDelay = Duration(seconds: 10);

  Timer? _retry;

  /// 업로드 주기. 세이브 **전체**를 올리는 호출이라 짧을수록 트래픽·서버
  /// 인스턴스 시간이 그대로 늘어난다(10초였을 때 하루 8 vCPU-시간까지 갔다).
  /// 백그라운드 전환 때도 [flush] 하므로 진행도 손실 위험은 낮다.
  static const period = Duration(seconds: 60);

  void start() {
    if (!_ref.read(gameServerProvider).available) return;
    _timer?.cancel();
    _timer = Timer.periodic(period, (_) => flush());
  }

  /// 변경분이 있으면 서버에 올린다. 이미 올린 상태면 건너뛴다.
  Future<void> flush() async {
    final server = _ref.read(gameServerProvider);
    if (!server.available || _inFlight) return;
    // ⚠️ 세이브를 못 읽은 상태의 화면값은 **초기 세이브**다. 올리면 서버의
    // 멀쩡한 계정을 그걸로 덮어쓴다. 사람이 고칠 때까지 올리지 않는다.
    if (_ref.read(saveRepositoryProvider).lastFailure != null) return;
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
        // 서버가 값을 고쳤으면 채택해 화면과 맞춘다. 세 경우다 —
        //  · `clamped`: 골드·칸수를 잘랐다(치팅 의심).
        //  · `season`: 앱을 켜둔 채 주간 경계를 넘겨 **서버가 시즌을 정산**했다.
        //  · `eventReward`: 대회 회차 보상을 지급했다(회차당 1회).
        // 이때만 세이브가 실려 온다(전부 드물어 이그레스 부담이 없다).
        // ⚠️ 새 사유를 서버에 추가하면 **여기 조건도 같이** 넓혀야 한다 —
        // 안 그러면 서버는 지급했는데 앱은 채택하지 않아, 화면에 안 보이다가
        // 다음 업로드에서 낡은 값이 덮어쓴다.
        final data = res.data;
        final season = data?['season'] == true;
        final rewarded = data?['eventReward'] is Map;
        if ((data?['clamped'] == true || season || rewarded) &&
            res.save != null) {
          final ctrl = _ref.read(saveControllerProvider.notifier);
          await ctrl.adoptServerSave(res.save!);
          _lastUploaded = jsonEncode(res.save);
          // 대회 회차 보상 — 서버가 지급했다. 회차당 1회다.
          final reward = data?['eventReward'];
          if (reward is Map) {
            ctrl.pendingEventReward = EventRewardReport.fromJson(
              Map<String, dynamic>.from(reward),
            );
          }
          final report = data?['seasonReport'];
          if (season && report is Map) {
            // 전투 탭이 다음 빌드에서 "시즌 종료" 다이얼로그로 보여준다.
            ctrl.pendingSeason = SeasonReport.fromJson(
              Map<String, dynamic>.from(report),
            );
          }
        }
      } else if (res.status == 409) {
        // 서버에 저장본이 없다 → 최초 이관(부트스트랩)이 먼저.
        final boot = await server.bootstrap(json);
        if (boot.isOk) _lastUploaded = encoded;
      } else {
        debugPrint('[save] 업로드 실패(${res.status}): ${res.error}');
        _onFail(res.status);
        return;
      }
      _onOk();
    } catch (e) {
      debugPrint('[save] 업로드 예외: $e');
      _onFail(0);
    } finally {
      _inFlight = false;
    }
  }

  void _onOk() {
    _fails = 0;
    _retry?.cancel();
    _retry = null;
    serverDisconnected.value = false;
  }

  /// 실패를 끊김으로 셀지 판단한다.
  ///
  /// ⚠️ **`status == 0`(네트워크 오류)만 끊김이다.** 다른 실패는 연결 문제가
  /// 아니라 막으면 안 된다:
  ///  - `401 no_session` — **게스트는 세션이 없어 업로드가 항상 실패한다.**
  ///    이걸 세면 로그인 안 한 유저는 게임을 아예 못 한다(실제로 그랬다).
  ///  - `4xx` — 서버가 요청을 거절한 것이지 연결은 멀쩡하다.
  ///  - `5xx` — 서버 문제다. 유저 네트워크를 탓하며 가둘 일이 아니다.
  void _onFail(int status) {
    if (!countsAsDisconnect(status)) {
      // **HTTP 응답을 받았다는 건 네트워크가 살아 있다는 뜻이다.**
      // 끊김 화면이 떠 있었다면 걷어주고, 조용히 다음 주기에 다시 시도한다.
      _fails = 0;
      serverDisconnected.value = false;
      return;
    }
    _fails++;
    if (_fails >= failThreshold) {
      serverDisconnected.value = true;
      return; // 화면이 재접속을 요구한다 — 여기서 계속 두드리지 않는다.
    }
    _retry?.cancel();
    _retry = Timer(retryDelay, flush);
  }

  /// 재접속 시도(끊김 화면의 "다시 시도"). 성공하면 true.
  Future<bool> reconnect() async {
    _fails = 0;
    // 변경 감지를 무력화해 **반드시 한 번 올려본다** — 안 그러면 올릴 게
    // 없을 때 실패인지 성공인지 알 수 없다.
    _lastUploaded = null;
    await flush();
    return !serverDisconnected.value;
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _retry?.cancel();
    _retry = null;
  }
}

/// 지금 즉시 서버에 올린다(60초 주기 업로드를 기다리지 않는다).
///
/// **다음 실행에서 서버 세이브에 덮이면 안 되는 변경** 직후에 부른다.
/// 실제 사고: 닉네임을 정하고 60초 안에 앱을 끄면, 서버에는 이관 시점의
/// (닉네임 없는) 세이브가 남아 있다. 다음 실행에 [syncWithServer] 가 그걸
/// 채택하면서 닉네임이 사라지고 입력창이 매번 다시 떴다.
Future<void> pushSaveNow(WidgetRef ref) => ServerSaveUploader(ref).flush();

/// 서버가 **세이브를 고쳐서 돌려주는 액션 직전에** 최신 로컬 세이브를 올린다.
/// 성공했을 때만 true.
///
/// 이걸 건너뛰면 이렇게 된다: 서버에는 최대 60초 낡은 세이브가 있는데, 서버가
/// 그 위에 보상을 얹어 돌려주고 앱이 그걸 채택한다 → **최근 1분의 진행(골드·
/// 곤충·업그레이드)이 통째로 사라진다.** 그래서 실패하면 호출부는 액션 자체를
/// 진행하지 않는다(다음 주기 업로드가 따라잡은 뒤 다시 시도하면 된다).
///
/// 전투·우편수령·코드사용이 같은 함수를 쓴다 — 한 곳이라도 빠지면 그 경로에서만
/// 진행도가 사라지는, 재현하기 어려운 버그가 된다.
Future<bool> flushSaveBeforeServerAction(
  GameServer server,
  SaveGame? save,
) async {
  if (!server.available) return true; // 서버 미연결이면 로컬 경로로 진행
  if (save == null) return false;
  final json = save.toJson();
  final res = await server.uploadSave(json);
  if (res.isOk) return true;
  // 저장본이 없다 = 최초 이관이 먼저.
  if (res.status == 409) return (await server.bootstrap(json)).isOk;
  return false;
}

/// 로컬 세이브가 서버 저장본보다 **더 진행됐는가**.
///
/// 시계(`lastSeen`)로 판단하지 않는다 — 기기 시간대가 틀어지면 멀쩡한 진행이
/// 묻힌다. 되돌아갈 이유가 없는 값들만 본다.
///
/// 하나라도 로컬이 앞서고 뒤처지는 게 없으면 로컬이 앞선 것으로 본다.
/// 애매하면(서로 엇갈리면) **서버를 따른다** — 서버가 진실이라는 기본 원칙은
/// 유지하고, 명백한 되돌림만 막는 게 목적이다.
bool _localIsAhead(SaveGame local, Map<String, dynamic> remoteJson) {
  final SaveGame remote;
  try {
    remote = SaveGame.fromJson(migrateToCurrent(remoteJson));
  } catch (_) {
    // 서버 것을 못 읽으면 로컬을 지킨다.
    return true;
  }
  var ahead = false;
  bool cmp(num l, num r) {
    if (l > r) ahead = true;
    return l < r; // 뒤처지는 항목이 하나라도 있으면 애매한 것
  }

  final behind = [
    cmp(local.stageNumber, remote.stageNumber),
    cmp(local.level, remote.level),
    cmp(local.bugs.length, remote.bugs.length),
    cmp(
      local.upgradeLevels.values.fold<int>(0, (a, b) => a + b),
      remote.upgradeLevels.values.fold<int>(0, (a, b) => a + b),
    ),
  ].any((x) => x);
  return ahead && !behind;
}
