import 'dart:math';

import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:test/test.dart';

/// 연구 재화 드롭 — 방치는 연구 패스 구간만, 보스 첫 처치는 확정.
void main() {
  const cfg = ResearchConfig(
    defs: [],
    slotsByTier: [1],
    slotJelly: [],
    eliteDropChance: 0.5,
    eliteDropAmount: 1,
    bossFirstDrop: 25,
    bossRepeatDrop: 2,
    bossRepeatChance: 0.1,
  );
  final t = DateTime.utc(2026, 10, 22, 12);
  const span = Duration(hours: 8);
  SaveGame base({DateTime? pass}) =>
      SaveGame.initial(createdAt: t).copyWith(researchPassExpiresAt: pass);

  int total(SaveGame s, DateTime? pass, int seeds) {
    var sum = 0;
    for (var i = 0; i < seeds; i++) {
      sum += idleResearchSamples(
        base(pass: pass),
        cfg,
        from: t,
        accrued: span,
        eliteKills: 100,
        rng: Random(i),
      );
    }
    return sum;
  }

  test('패스 없음 → 0 이고 난수를 소비하지 않는다', () {
    final rng = Random(7);
    final probe = Random(7);
    expect(
      idleResearchSamples(
        base(),
        cfg,
        from: t,
        accrued: span,
        eliteKills: 100,
        rng: rng,
      ),
      0,
    );
    expect(rng.nextInt(1 << 20), probe.nextInt(1 << 20));
  });

  test('패스가 구간 전체를 덮으면 기댓값 그대로(100 × 0.5 = 50)', () {
    final all = total(base(), t.add(const Duration(days: 1)), 200);
    expect(all / 200, closeTo(50, 0.6));
  });

  test('패스가 구간 절반에서 만료 → 절반 몫만', () {
    final half = total(base(), t.add(span ~/ 2), 200);
    expect(half / 200, closeTo(25, 0.6));
  });

  test('이미 만료된 패스 → 0', () {
    expect(total(base(), t.subtract(const Duration(hours: 1)), 20), 0);
  });

  test('같은 seed 같은 결과', () {
    int run() => idleResearchSamples(
      base(pass: t.add(span ~/ 2)),
      cfg,
      from: t,
      accrued: span,
      eliteKills: 37,
      rng: Random(3),
    );
    expect(run(), run());
  });

  test('보스 첫 처치는 확정 bossFirstDrop', () {
    expect(rollResearchDrop(cfg, Random(1), ResearchDropSource.bossFirst), 25);
  });
}
