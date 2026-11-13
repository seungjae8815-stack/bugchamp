import 'dart:convert';
import 'dart:io';

import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:test/test.dart';

/// 심연 포자 · 심연 연구소(2026-11-12) — 앱·서버 공용 함수.
void main() {
  Map<String, dynamic> read(String f) =>
      jsonDecode(File('../app/assets/data/$f').readAsStringSync())
          as Map<String, dynamic>;
  final run = RunConfig.fromJson(read('run_config.json'));
  final rc = ResearchConfig.fromJson(read('research.json'));
  final lab = rc.abyssLab;
  final t0 = DateTime.utc(2026, 11, 16, 3);
  final base = SaveGame.initial(createdAt: t0).copyWith(
    abyssUnlocked: true,
    inAbyss: true,
    abyssWeek: '2026-11-16',
    abyssFloor: 5,
    abyssBest: 20,
    abyssWeekTop: 4,
  );

  test('심연 연구 6종이 있고 효과 키가 모두 심연 효과다', () {
    expect(lab.defs, hasLength(6));
    expect(
      {for (final d in lab.defs) d.effect},
      containsAll(<ResearchEffect>[
        ResearchEffect.abyssShortcut,
        ResearchEffect.abyssFastFloor,
        ResearchEffect.mutationTame,
        ResearchEffect.crystalBonus,
        ResearchEffect.sporeBonus,
        ResearchEffect.abyssIdleGold,
      ]),
    );
  });

  test('포자: 그 주에 처음 깬 층만 · 다시 깬 층은 없음', () {
    final first = clearAbyssFloor(base, run, lab: rc);
    expect(first.spores, lab.sporesPerFloor);
    expect(first.save.abyssSpores, lab.sporesPerFloor);
    final again = clearAbyssFloor(base.copyWith(abyssFloor: 3), run, lab: rc);
    expect(again.spores, 0);
  });

  test('포자: 10층 배수 역대 첫 도달은 덤 · 보유 상한까지', () {
    final s = base.copyWith(abyssFloor: 30, abyssBest: 29, abyssWeekTop: 29);
    final r = clearAbyssFloor(s, run, lab: rc);
    expect(r.spores, lab.sporesPerFloor + lab.sporesMilestone);
    final full = clearAbyssFloor(
      s.copyWith(abyssSpores: lab.sporeCap - 1),
      run,
      lab: rc,
    );
    expect(full.save.abyssSpores, lab.sporeCap);
  });

  test('연구: 심연이 닫혀 있으면 · 포자가 모자라면 시작 못 함', () {
    final id = lab.defs.first.id;
    expect(
      startAbyssLab(base.copyWith(abyssUnlocked: false), rc, id, t0).error,
      'abyss_locked',
    );
    expect(startAbyssLab(base, rc, id, t0).error, 'no_spores');
  });

  test('연구: 시작하면 포자를 내고 칸이 차며, 끝나면 받는다', () {
    final d = lab.defs.first;
    final cost = rc.costAt(d, 1).samples;
    final r = startAbyssLab(base.copyWith(abyssSpores: cost), rc, d.id, t0);
    expect(r.error, isNull);
    final s = r.save!;
    expect(s.abyssSpores, 0);
    expect(s.abyssLabSlot!.level, 1);
    expect(startAbyssLab(s, rc, lab.defs[1].id, t0).error, 'slot_busy');
    // 안 끝났으면 그대로.
    expect(identical(claimAbyssLab(s, t0), s), isTrue);
    final done = claimAbyssLab(s, s.abyssLabSlot!.endsAt);
    expect(done.abyssLabLevels[d.id], 1);
    expect(done.abyssLabSlot, isNull);
    // 세이브 왕복.
    final back = SaveGame.fromJson(s.toJson());
    expect(back.abyssLabSlot!.id, d.id);
    expect(back.abyssSpores, s.abyssSpores);
  });

  test('심연 지름길: 지난주 최고 층의 비율을 10층 단위로 내려 그다음 층부터', () {
    final short = lab.defs.firstWhere(
      (d) => d.effect == ResearchEffect.abyssShortcut,
    );
    final s = base.copyWith(
      abyssWeek: '2026-11-09',
      abyssWeekTop: 100,
      abyssLabLevels: {short.id: short.maxLevel},
    );
    final v = rc.effectAt(short, short.maxLevel);
    final expected = ((100 * v + 1e-9) ~/ 10) * 10 + 1;
    expect(abyssWeekStartFloor(s, '2026-11-16', rc), expected);
    // 연구가 없거나 지난주에 안 올랐으면 1층.
    expect(abyssWeekStartFloor(base, '2026-11-23', rc), 1);
    expect(
      abyssWeekStartFloor(
        s.copyWith(abyssWeek: '2026-10-01'),
        '2026-11-16',
        rc,
      ),
      1,
    );
    // 건너뛴 층의 결정도 새 주에 받는다.
    final w = applyAbyssWeek(s, '2026-11-16', run: run, lab: rc);
    expect(w.abyssFloor, expected);
    expect(w.abyssWeekTop, expected - 1);
    expect(w.abyssCrystals, greaterThanOrEqualTo(s.abyssCrystals));
  });

  test('빠른 하강: 심연 안에서만 보스 도전 처치 수가 준다', () {
    final fast = lab.defs.firstWhere(
      (d) => d.effect == ResearchEffect.abyssFastFloor,
    );
    final s = base.copyWith(abyssLabLevels: {fast.id: fast.maxLevel});
    expect(bossUnlockKillsFor(s, run, rc), lessThan(run.bossUnlockKills));
    expect(
      bossUnlockKillsFor(s.copyWith(inAbyss: false), run, rc),
      run.bossUnlockKills,
    );
  });
}
