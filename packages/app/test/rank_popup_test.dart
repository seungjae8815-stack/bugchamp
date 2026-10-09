import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app/ui/popup_gate.dart';
import 'package:app/ui/rank_popup.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:flutter_test/flutter_test.dart';

/// 앱 시작 순위 팝업(2026-10-09 점검) — 신규 유저 제외 · 방치 보상 팝업 뒤에 뜨기.
void main() {
  final run = RunConfig.fromJson(
    jsonDecode(File('assets/data/run_config.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  final fresh = SaveGame.initial(createdAt: DateTime.utc(2026, 1, 1));

  group('신규 유저(쉬움 사냥터 1 · 보스 0)에게는 띄우지 않는다', () {
    test('막 시작한 세이브는 신규', () {
      expect(isNewPlayerForRank(fresh, run, 0), isTrue);
    });

    test('보스를 한 마리라도 잡았으면 신규가 아니다', () {
      expect(isNewPlayerForRank(fresh, run, 1), isFalse);
    });

    test('사냥터 2 이상이면 신규가 아니다', () {
      final s = fresh.copyWith(bestStage: run.zoneStartStage(2));
      expect(isNewPlayerForRank(s, run, 0), isFalse);
    });

    test('보통 이상을 가 봤으면 신규가 아니다', () {
      final s = fresh.copyWith(maxTierReached: 1);
      expect(isNewPlayerForRank(s, run, 0), isFalse);
    });
  });

  group('StartupPopupGate — 앞 팝업이 닫힌 뒤에', () {
    setUp(StartupPopupGate.reset);

    test('비어 있으면 바로 끝난다', () async {
      var done = false;
      unawaited(StartupPopupGate.whenIdle().then((_) => done = true));
      await Future<void>.delayed(Duration.zero);
      expect(done, isTrue);
    });

    test('잡혀 있으면 놓을 때까지 기다린다(두 개면 둘 다)', () async {
      StartupPopupGate.hold();
      StartupPopupGate.hold();
      var done = false;
      unawaited(StartupPopupGate.whenIdle().then((_) => done = true));
      await Future<void>.delayed(Duration.zero);
      expect(done, isFalse);
      StartupPopupGate.release();
      await Future<void>.delayed(Duration.zero);
      expect(done, isFalse);
      StartupPopupGate.release();
      await Future<void>.delayed(Duration.zero);
      expect(done, isTrue);
      // 짝이 안 맞는 release 는 음수로 내려가지 않는다.
      StartupPopupGate.release();
      expect(StartupPopupGate.busy, isFalse);
    });
  });
}
