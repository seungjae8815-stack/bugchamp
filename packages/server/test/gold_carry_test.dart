import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:server/src/actions.dart';
import 'package:server/src/game_config.dart';
import 'package:test/test.dart';

/// 골드 허용치 이월(2026-10-13) — 앱 복귀 때 연결 확인 업로드(방치 보상 전)가 먼저 닿고, 몇 초 뒤 방치 보상
/// 골드가 실린 업로드가 "0초 만에 번 돈"으로 잘리던 것(운영 요약 f17b46e0 · 31e577e1, 1.0.20).
void main() {
  late GameConfig cfg;
  var now = DateTime.utc(2026, 10, 13, 9);
  late GameActions actions;

  setUpAll(() async {
    cfg = await GameConfig.load(dir: '../app/assets/data');
    actions = GameActions(config: cfg, now: () => now);
  });

  SaveGame stored(DateTime t, Duration away) {
    final stage = cfg.run.zoneStartStage(3);
    return SaveGame.initial(createdAt: t).copyWith(
      lastSeen: t.subtract(away),
      zoneEpoch: kZoneEpoch,
      difficultyTier: 1,
      maxTierReached: 1,
      stageNumber: stage,
      bestStage: stage,
      upgradeLevels: {for (final k in UpgradeKind.values) k: 100},
      gold: 1000,
    );
  }

  List reasons(ActionResult r) => r.extra['clampReasons'] as List? ?? const [];

  test('3시간 쉬고 복귀 — 연결 확인 업로드 뒤 3초 만의 방치 보상 골드가 잘리지 않는다', () {
    final t0 = DateTime.utc(2026, 10, 13, 9);
    now = t0;
    final s = stored(t0, const Duration(hours: 3));
    // ① 복귀 직후 연결 확인 — 방치 보상 전 세이브(골드 그대로).
    final a = actions.mergeSave(s, s.toJson());
    expect(reasons(a), isEmpty);
    final afterA = a.save!;
    expect(afterA.goldCarry, greaterThan(0), reason: '다 쓰지 않은 방치 몫을 넘긴다');

    // ② 3초 뒤 방치 보상이 실린 업로드 — 넘긴 몫의 90%.
    now = t0.add(const Duration(seconds: 3));
    final reward = (afterA.goldCarry * 0.9).floor();
    final b = actions.mergeSave(
      afterA,
      afterA.copyWith(gold: afterA.gold + reward).toJson(),
    );
    expect(reasons(b), isNot(contains('gold')));
    expect(b.save!.gold, afterA.gold + reward);

    // ③ 이월을 다 쓴 뒤 또 같은 골드를 올리면 잘린다 — 허용치를 두 번 받지 못한다.
    now = t0.add(const Duration(seconds: 6));
    final afterB = b.save!;
    final c = actions.mergeSave(
      afterB,
      afterB.copyWith(gold: afterB.gold + reward).toJson(),
    );
    expect(reasons(c), contains('gold'));
  });

  test('이월이 없으면(바로 전 업로드가 짧은 간격) 같은 골드는 잘린다', () {
    final t0 = DateTime.utc(2026, 10, 13, 10);
    now = t0;
    final probe = actions.mergeSave(
      stored(t0, const Duration(hours: 3)),
      stored(t0, const Duration(hours: 3)).toJson(),
    );
    final reward = (probe.save!.goldCarry * 0.9).floor();

    final s = stored(t0, const Duration(seconds: 3));
    final r = actions.mergeSave(s, s.copyWith(gold: s.gold + reward).toJson());
    expect(reasons(r), contains('gold'));
  });

  test('이월은 5분 뒤 사라진다', () {
    final t0 = DateTime.utc(2026, 10, 13, 11);
    now = t0;
    final s = stored(t0, const Duration(hours: 3));
    final a = actions.mergeSave(s, s.toJson()).save!;
    final reward = (a.goldCarry * 0.9).floor();
    // 5분을 넘긴 뒤 — 60초마다 올라온 업로드가 사이에 있었다고 본다.
    now = t0.add(const Duration(minutes: 6));
    final late = a.copyWith(lastSeen: now.subtract(const Duration(seconds: 3)));
    final r = actions.mergeSave(
      late,
      late.copyWith(gold: late.gold + reward).toJson(),
    );
    expect(reasons(r), contains('gold'));
  });

  test('3분 간격 업로드가 이어져도 이월은 쌓이지 않는다(한 공백 몫까지)', () {
    final t0 = DateTime.utc(2026, 10, 13, 13);
    now = t0;
    var s = stored(t0, const Duration(minutes: 3));
    s = actions.mergeSave(s, s.toJson()).save!;
    final first = s.goldCarry;
    expect(first, greaterThan(0));
    // 골드 없이 3분마다 10번 — 옛 이월을 더하던 시절엔 기한이 계속 늘며 10배로 쌓였다.
    for (var i = 1; i <= 10; i++) {
      now = t0.add(Duration(minutes: 3 * i));
      s = actions.mergeSave(s, s.toJson()).save!;
    }
    expect(s.goldCarry, lessThanOrEqualTo((first * 1.5).ceil()));
  });

  test('기기가 이월 필드를 올려도 서버 값이 이긴다', () {
    final t0 = DateTime.utc(2026, 10, 13, 12);
    now = t0;
    final s = stored(t0, const Duration(seconds: 60));
    final forged = s.toJson()
      ..['gC'] = 999999999999
      ..['gCU'] = t0.add(const Duration(days: 1)).toIso8601String()
      ..['gold'] = s.gold + 999999999;
    final r = actions.mergeSave(s, forged);
    expect(reasons(r), contains('gold'));
  });
}
