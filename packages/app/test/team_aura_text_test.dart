import 'package:app/features/battle/training_screen.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:core_models/core_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// 팀 오라 한 줄(1.0.21) — 상한에 닿은 능력치에만 "(최대)"(2026-10-15 에뮬에서 상한까지 못 키워 테스트로 확인).
void main() {
  final l = lookupAppLocalizations(const Locale('ko'));

  test('상한에 닿은 능력치만 (최대)', () {
    final text = duelTeamAuraText(l, {
      DuelRole.attack: 0.2,
      DuelRole.hp: 0.08,
    }, capPerStat: 0.2);
    expect(text, contains('${l.trainAttack} +20%${l.duelTeamAuraMaxed}'));
    expect(text, isNot(contains('+8%${l.duelTeamAuraMaxed}')));
  });

  test('상한을 모르면 (최대)를 붙이지 않는다', () {
    final text = duelTeamAuraText(l, {DuelRole.attack: 0.2});
    expect(text, isNot(contains(l.duelTeamAuraMaxed)));
  });

  test('아무도 오라가 없으면 없음 문구', () {
    expect(duelTeamAuraText(l, const {}), l.duelTeamAuraNone);
  });
}
