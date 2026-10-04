import 'dart:math';

import 'package:flutter/foundation.dart';

/// 한 기기만 접속(2026-10-03, 1.0.16).
///
/// 앱을 켤 때마다 새 표식을 만들어 서버에 쥔다(`/session/claim`) — **나중에 켠 기기가 이긴다.**
/// 먼저 켜져 있던 기기의 다음 업로드는 서버가 409 `session_taken` 으로 거절하고, 그 기기는
/// 게임을 멈추고 "다른 기기에서 접속 중"을 띄운다.
///
/// 이게 없던 시절: 두 기기를 같이 켜 두면 60초 업로드가 서로를 덮어 한 기기의 진행이 다른 기기의
/// 옛 상태로 되돌아갔고, 골드가 상한에 잘려 줄었다(2026-10-03 운영 요약 `골드 ×2`).
class DeviceSession {
  DeviceSession._();

  /// 이번 실행의 표식. 실행마다 새로 만든다(같은 기기라도 껐다 켜면 새 접속).
  static final String id = _make();

  /// 서버가 이 표식을 받아들였나. 받기 전에는 업로드에 표식을 싣지 않는다 —
  /// 실으면 서버의 옛 표식과 달라 내 업로드가 거절된다.
  static bool claimed = false;

  /// 어느 계정으로 쥐었나. 게스트 → 로그인처럼 계정이 바뀌면 새 계정에서 다시 쥐어야 한다 —
  /// 안 그러면 혼자 쓰는데도 새 계정의 옛 표식과 달라 "다른 기기에서 접속 중"이 뜬다.
  static String? claimedUser;

  /// 쥔 뒤 아직 **첫 업로드가 통과하지 않았다** — 이때 "밀려남"을 받으면 경쟁이라 한 번 다시 쥔다.
  ///
  /// 서버의 `/session/claim` 과 다른 쓰기(옛 기기의 `/save`, 같은 기기의 공지 보상·결제 복구 등)는 둘 다
  /// 세이브 전체를 읽고 다시 쓴다. 쥐기 직전에 읽고 직후에 쓰면 옛 표식이 되살아나, **방금 켠 기기**가
  /// 밀려난 것처럼 보인다. 예전엔 "쥔 지 3분"으로 쟀는데, 켜자마자 백그라운드로 갔다 3분 뒤 돌아오면
  /// 구제 창이 지나 덮개가 떴다(2026-10-04 출시 전 리뷰) — 시간이 아니라 첫 업로드로 잰다.
  static bool firstUploadPending = false;

  /// 쥘 때마다 오른다 — 업로드가 나간 사이 다른 호출이 이미 다시 쥐었는지 알아보는 데 쓴다
  /// (동시에 두 업로드가 409 를 받으면 둘째가 다시 쥐지 않고 덮개를 켰다).
  static int claimEpoch = 0;

  /// 다른 기기에 밀려났다. 화면이 게임을 덮고, 업로더는 더 올리지 않는다.
  static final taken = ValueNotifier<bool>(false);

  /// 마지막으로 쥐기를 시도한 시각 — 실패하면 업로드 때마다 두드리지 않게 간격을 둔다.
  static DateTime? triedAt;

  static String _make() {
    final r = Random.secure();
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(24, (_) => chars[r.nextInt(chars.length)]).join();
  }

  /// 테스트용 — 상태를 처음으로.
  @visibleForTesting
  static void reset() {
    claimed = false;
    claimedUser = null;
    firstUploadPending = false;
    claimEpoch = 0;
    triedAt = null;
    taken.value = false;
  }
}
