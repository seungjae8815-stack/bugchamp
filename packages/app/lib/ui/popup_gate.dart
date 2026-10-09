import 'dart:async';

import 'package:flutter/foundation.dart';

/// 앱을 켤 때 뜨는 팝업들의 순서 잡기.
///
/// 방치 보상 팝업(홈 화면)과 순위 팝업(앱 셸)이 같은 첫 프레임에서 따로 출발해, 순위 조회가 끝나는 순간
/// 방치 보상 팝업 **위에** 순위 팝업이 겹쳐 떴다(2026-10-09 점검). 먼저 떠야 하는 팝업이 [hold] 로 자리를
/// 잡고 닫힐 때 [release] 하면, 뒤에 뜰 팝업은 [whenIdle] 을 기다렸다가 띄운다.
class StartupPopupGate {
  StartupPopupGate._();

  static final ValueNotifier<int> _held = ValueNotifier(0);

  /// 지금 앞선 팝업이 떠 있거나 뜰 예정인가.
  static bool get busy => _held.value > 0;

  /// 앞선 팝업이 뜰 예정이다(띄우기 전에, 같은 프레임 안에서 부른다).
  static void hold() => _held.value++;

  /// 앞선 팝업이 닫혔다. [hold] 와 짝을 맞춘다(못 띄우고 끝난 경우에도).
  static void release() {
    if (_held.value > 0) _held.value--;
  }

  /// 앞선 팝업이 모두 닫힐 때까지 기다린다(이미 비어 있으면 바로).
  static Future<void> whenIdle() {
    if (!busy) return Future.value();
    final done = Completer<void>();
    void check() {
      if (busy || done.isCompleted) return;
      _held.removeListener(check);
      done.complete();
    }

    _held.addListener(check);
    return done.future;
  }

  /// 테스트용 — 상태를 비운다.
  @visibleForTesting
  static void reset() => _held.value = 0;
}
