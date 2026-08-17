import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';
import 'package:test/test.dart';

/// 웨이브 방어전(실물 경품 이벤트 §3-1).
///
/// 이 모드의 순위는 **서버가 계산한 값**이 그대로 상품으로 이어진다. 그래서
/// 두 가지가 반드시 지켜져야 한다.
///  1. **결정론** — 같은 seed·팀이면 항상 같은 결과. 앱이 서버 판을 재생할 수 있는 근거다.
///  2. **체력 이월** — 웨이브마다 만피로 돌아오면 "한 웨이브를 이기면 무한히 간다"가 되어
///     순위가 갈리지 않는다.
BattleBug bug(
  String id, {
  Element element = Element.wood,
  double hp = 300,
  double atk = 40,
  double def = 20,
  double spd = 20,
}) => BattleBug(
  id: id,
  name: id,
  element: element,
  temperament: Temperament.steadfast,
  preferredStance: Stance.attack,
  maxHp: hp,
  atk: atk,
  def: def,
  spd: spd,
);

void main() {
  List<BattleBug> team() => [bug('a'), bug('b'), bug('c')];

  // 약한 적 — 반드시 이긴다. 웨이브가 계속 이어지는지 보는 데 쓴다.
  List<BattleBug> weak(int w) => [bug('e$w', hp: 1, atk: 1, def: 0)];

  // 압도적인 적 — 1웨이브에서 끝난다.
  List<BattleBug> crush(int w) => [
    for (var i = 0; i < 3; i++) bug('x$w$i', hp: 99999, atk: 9999, def: 999),
  ];

  test('같은 seed·팀이면 결과가 완전히 같다 (결정론)', () {
    WaveRunResult run() => simulateWaveRun(
      seed: 12345,
      team: team(),
      enemyOf: (w) => [bug('e$w', hp: 200.0 + w * 60, atk: 20.0 + w * 6)],
      maxWave: 30,
      waveHealPct: 0.2,
    );
    final a = run();
    final b = run();
    expect(a.clearedWaves, b.clearedWaves);
    expect(a.totalRounds, b.totalRounds);
    expect(a.survivors, b.survivors);
    expect(a.hpPctAtLastWave, b.hpPctAtLastWave);
  });

  test('seed 가 다르면 대체로 결과가 갈린다 (같은 판의 반복이 아니다)', () {
    int wavesFor(int seed) => simulateWaveRun(
      seed: seed,
      team: team(),
      enemyOf: (w) => [bug('e$w', hp: 150.0 + w * 40, atk: 18.0 + w * 5)],
      maxWave: 40,
      waveHealPct: 0.15,
    ).clearedWaves;
    final results = {for (final s in [1, 2, 3, 4, 5, 6, 7, 8]) wavesFor(s)};
    expect(results.length, greaterThan(1));
  });

  test('1웨이브에서 지면 clearedWaves 는 0', () {
    final r = simulateWaveRun(
      seed: 7,
      team: team(),
      enemyOf: crush,
      maxWave: 20,
      waveHealPct: 0.2,
    );
    expect(r.clearedWaves, 0);
    expect(r.waves.length, 1);
  });

  test('maxWave 에서 멈춘다 — 상한이 없으면 집계가 끝나지 않는다', () {
    final r = simulateWaveRun(
      seed: 3,
      team: team(),
      enemyOf: weak,
      maxWave: 12,
      waveHealPct: 0.2,
    );
    expect(r.clearedWaves, 12);
    expect(r.waves.length, 12);
  });

  test('체력이 이월된다 — 회복 0 이면 만피로 돌아오지 않는다', () {
    // 매 웨이브 같은 적을 주고 회복을 끊으면, 체력이 쌓여 깎이므로 언젠가 진다.
    final r = simulateWaveRun(
      seed: 11,
      team: team(),
      enemyOf: (w) => [bug('e$w', hp: 260, atk: 30, def: 10)],
      maxWave: 100,
      waveHealPct: 0,
    );
    expect(
      r.clearedWaves,
      lessThan(100),
      reason: '체력이 이월되지 않으면 100 웨이브를 그냥 통과한다',
    );
  });

  test('회복량이 크면 더 오래 버틴다 (회복이 실제로 작동한다)', () {
    int cleared(double heal) => simulateWaveRun(
      seed: 11,
      team: team(),
      enemyOf: (w) => [bug('e$w', hp: 260, atk: 30, def: 10)],
      maxWave: 100,
      waveHealPct: heal,
    ).clearedWaves;
    expect(cleared(0.5), greaterThan(cleared(0.0)));
  });

  test('쓰러진 곤충은 되살아나지 않는다', () {
    // 첫 두 마리를 죽여 놓고 시작해도, 회복 스탠스로 부활하면 안 된다.
    final st = initBattle(
      5,
      team(),
      [bug('e', hp: 1, atk: 1)],
      initialHpA: [0, 0, 300],
    );
    var guard = 0;
    while (!st.done && guard < 200) {
      st.step();
      guard++;
    }
    expect(st.hpA[0], 0);
    expect(st.hpA[1], 0);
    // 살아 있던 셋째가 싸운다.
    expect(st.hpA[2], greaterThan(0));
  });

  test('마지막 웨이브 진입 시점의 체력을 기록한다 (전멸 시 0 이 아니다)', () {
    final r = simulateWaveRun(
      seed: 21,
      team: team(),
      enemyOf: (w) => w < 3
          ? [bug('e$w', hp: 1, atk: 1, def: 0)]
          : [bug('boss', hp: 99999, atk: 9999, def: 999)],
      maxWave: 10,
      waveHealPct: 0.2,
    );
    expect(r.clearedWaves, 2);
    expect(
      r.hpPctAtLastWave,
      greaterThan(0),
      reason: '전멸한 웨이브의 종료 체력(0)이 아니라 진입 체력을 써야 동점이 줄어든다',
    );
  });
}
