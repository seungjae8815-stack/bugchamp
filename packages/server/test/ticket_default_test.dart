import 'dart:convert';
import 'dart:io';

import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:test/test.dart';

/// 새 계정의 결투 티켓 = 상한(2026-11-09). 기본값이 상한보다 크면 성충이 없는 신규 유저에게
/// 첫 순간부터 결투 탭 "가득 참" 점이 뜬다(상한 10 → 5 때 기본값만 10 으로 남았다).
void main() {
  test('새 세이브 티켓 기본값 = battle.json tickets.max', () {
    final battle = BattleConfig.fromJson(
      jsonDecode(File('../app/assets/data/battle.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    expect(kDefaultPvpTickets, battle.ticketMax);
  });
}
