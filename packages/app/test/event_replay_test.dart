import 'dart:convert';
import 'dart:io';

import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:flutter_test/flutter_test.dart';

/// 이벤트 재생(앱) — **서버가 확정한 판을 앱이 똑같이 그릴 수 있는가**.
///
/// 앱은 점수를 계산하지 않는다. 그러나 연출을 위해 같은 판을 다시 돌리므로,
/// 서버와 **같은 입력**(event.json + seed + 팀)에서 **같은 흐름**이 나와야 한다.
/// 이게 깨지면 "화면에선 8웨이브까지 갔는데 기록은 6웨이브"가 된다.
void main() {
  final cfg = EventConfig.fromJson(
    jsonDecode(File('assets/data/event.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  Species species(String id, Grade grade) => Species(
    id: id,
    name: const LocalizedText(ko: '테스트', en: 'test', ja: 'テスト'),
    grade: grade,
    specialty: Specialty.strike,
    baseStats: const Stats(hp: 100, atk: 40, def: 30, spd: 20),
    sizeMinMm: 20,
    sizeMaxMm: 60,
  );

  IndividualBug bug(String id, Element el) => IndividualBug(
    id: id,
    speciesId: 'test',
    sizeMm: 40,
    potential: 3,
    temperament: Temperament.steadfast,
    sex: Sex.male,
    element: el,
    stage: LifeStage.adult,
    stageSince: DateTime.utc(2026, 1, 1),
  );

  List<BattleBug> team(Grade grade) {
    final sp = species('test', grade);
    const els = [Element.wood, Element.fire, Element.earth];
    return [
      for (var i = 0; i < 3; i++)
        () {
          final n = cfg.normalized(grade);
          return buildEventBug(
            bug: bug('b$i', els[i]),
            species: sp,
            locale: 'ko',
            hp: n.hp,
            atk: n.atk,
            def: n.def,
            spd: n.spd,
          );
        }(),
    ];
  }

  WaveEnemySpec spec() => WaveEnemySpec(
    baseHp: cfg.enemyBaseHp,
    baseAtk: cfg.enemyBaseAtk,
    baseDef: cfg.enemyBaseDef,
    baseSpd: cfg.enemyBaseSpd,
    growth: cfg.enemyGrowth,
    count: cfg.enemyCount,
  );

  WaveRunResult run(int seed, Grade grade) => simulateWaveRun(
    seed: seed,
    team: team(grade),
    enemyOf: (w) => eventWaveEnemies(seed, w, spec()),
    maxWave: cfg.maxWave,
    waveHealPct: cfg.waveHealPct,
  );

  test('event.json 이 로드되고 계수가 살아 있다', () {
    expect(cfg.maxWave, greaterThan(0));
    expect(cfg.enemyGrowth, greaterThan(1.0));
    expect(cfg.ticketMax, greaterThan(0));
    expect(cfg.fatigueHours, greaterThan(0));
    // 정규화가 등급 격차를 실제로 압축하는지 — 종 기본 스탯을 그대로 쓰면
    // 전설이 일반의 2~3배라 "전설 보유자가 이긴다"가 된다.
    final common = cfg.normalized(Grade.common);
    final legend = cfg.normalized(Grade.legendary);
    expect(legend.atk / common.atk, lessThan(1.35));
  });

  test('같은 seed·팀이면 판이 완전히 같다 — 서버 결과를 재생할 수 있는 근거', () {
    final seed = EventConfig.roundSeedOf('2026-W34');
    final a = run(seed, Grade.common);
    final b = run(seed, Grade.common);
    expect(a.clearedWaves, b.clearedWaves);
    expect(a.totalRounds, b.totalRounds);
    expect(a.hpPctAtLastWave, b.hpPctAtLastWave);
  });

  test('회차 키가 같으면 seed 도 같다 — 같은 회차엔 모두 같은 웨이브를 만난다', () {
    expect(
      EventConfig.roundSeedOf('2026-W34'),
      EventConfig.roundSeedOf('2026-W34'),
    );
    expect(
      EventConfig.roundSeedOf('2026-W34'),
      isNot(EventConfig.roundSeedOf('2026-W35')),
    );
  });

  test('실제 계수로 도전하면 상한에 닿지 않는다 — 닿으면 동점이 쏟아진다', () {
    final seed = EventConfig.roundSeedOf('2026-W34');
    final legend = run(seed, Grade.legendary);
    expect(legend.clearedWaves, greaterThan(0));
    expect(legend.clearedWaves, lessThan(cfg.maxWave));
  });

  test('점수는 도달 웨이브가 지배한다 — 잔여 체력으로 웨이브를 뒤집지 못한다', () {
    final low = cfg.score(
      clearedWaves: 9,
      hpPct: 1.0,
      survivors: 3,
      totalRounds: 0,
    );
    final high = cfg.score(
      clearedWaves: 10,
      hpPct: 0.0,
      survivors: 0,
      totalRounds: 400,
    );
    expect(high, greaterThan(low));
  });
}
