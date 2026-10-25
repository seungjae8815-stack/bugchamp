import 'dart:convert';
import 'dart:io';

import 'package:app/domain/pass_expiry.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:flutter_test/flutter_test.dart';

/// 패스 만료 안내(2026-10-25) — 단계·남은 날·알림 시각.
void main() {
  final cfg = IapConfig.fromJson(
    jsonDecode(File('assets/data/iap.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  final now = DateTime.utc(2026, 10, 25, 12);

  test('단계: 3일 넘게 남음 = 없음 · 3일 이하 = soon · 하루 이하 = today · 끝남 = 없음', () {
    expect(passExpiryStage(now.add(const Duration(days: 4)), now), isNull);
    expect(
      passExpiryStage(now.add(const Duration(days: 3)), now),
      PassExpiryStage.soon,
    );
    expect(
      passExpiryStage(now.add(const Duration(hours: 20)), now),
      PassExpiryStage.today,
    );
    expect(
      passExpiryStage(now.subtract(const Duration(hours: 1)), now),
      isNull,
    );
  });

  test('남은 날은 올림(마지막 날이 0일로 보이지 않게)', () {
    expect(passDaysLeft(now.add(const Duration(hours: 1)), now), 1);
    expect(passDaysLeft(now.add(const Duration(hours: 49)), now), 3);
  });

  test('보유 패스 — 켜진 패스만, 올인원은 따로 세지 않는다 · 알림은 3일 전·12시간 전 중 미래만', () {
    final s = SaveGame.initial(createdAt: now).copyWith(
      researchPassExpiresAt: now.add(const Duration(days: 2)),
      buffPassExpiresAt: now.subtract(const Duration(days: 1)), // 이미 끝남
    );
    final passes = activePasses(s, cfg, now);
    expect(passes.map((p) => p.product.id), ['research_pass']);
    final times = passExpiryNotifyTimes(passes, now);
    // 3일 전은 이미 지났고, 12시간 전만 남는다.
    expect(times, [now.add(const Duration(days: 2, hours: -12))]);
  });
}
