// 이벤트 웨이브 방어전 밸런스 시뮬 (docs/event_ranking_prize.md).
//
// 순위가 그대로 실물 상품이 되므로, "어떤 편성이 몇 웨이브까지 가는가"를 눈으로
// 보고 계수를 정해야 한다. 손으로 더하면 반드시 틀린다 — 오행 상극(x1.5)과
// 상생 시너지(연결당 +10%)가 곱으로 얽혀 있어서다.
//
//   dart run tool/event_sim.dart
//   dart run tool/event_sim.dart --growth=1.13 --hp=100
//
// 보는 것:
//  1. 편성별 도달 웨이브 — 무작정 센 팀이 아니라 **오행을 맞춘 팀**이 위여야 한다.
//  2. 등급 격차 — 전설 팀이 일반 팀을 압도하면 신규가 참여할 이유가 사라진다.
//  3. 상한(maxWave) 도달자가 나오는지 — 나오면 동점이 쏟아져 순위를 못 매긴다.
import 'dart:convert';
import 'dart:io';

import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';

void main(List<String> args) {
  final overrides = <String, double>{};
  for (final a in args) {
    final m = RegExp(r'^--(\w+)=([\d.]+)$').firstMatch(a);
    if (m != null) overrides[m.group(1)!] = double.parse(m.group(2)!);
  }

  final raw =
      jsonDecode(File('../app/assets/data/event.json').readAsStringSync())
          as Map<String, dynamic>;
  var cfg = EventConfig.fromJson(raw);
  if (overrides.isNotEmpty) {
    cfg = EventConfig(
      fatigueHours: cfg.fatigueHours,
      normBaseHp: overrides['normHp'] ?? cfg.normBaseHp,
      normBaseAtk: overrides['normAtk'] ?? cfg.normBaseAtk,
      normBaseDef: cfg.normBaseDef,
      normBaseSpd: cfg.normBaseSpd,
      gradeBonus: cfg.gradeBonus,
      maxWave: (overrides['maxWave'] ?? cfg.maxWave).toInt(),
      waveHealPct: overrides['heal'] ?? cfg.waveHealPct,
      enemyCount: cfg.enemyCount,
      enemyBaseHp: overrides['hp'] ?? cfg.enemyBaseHp,
      enemyBaseAtk: overrides['atk'] ?? cfg.enemyBaseAtk,
      enemyBaseDef: cfg.enemyBaseDef,
      enemyBaseSpd: cfg.enemyBaseSpd,
      enemyGrowth: overrides['growth'] ?? cfg.enemyGrowth,
      wavePoint: cfg.wavePoint,
      hpPoint: cfg.hpPoint,
      survivorPoint: cfg.survivorPoint,
      speedBase: cfg.speedBase,
    );
  }

  final spec = WaveEnemySpec(
    baseHp: cfg.enemyBaseHp,
    baseAtk: cfg.enemyBaseAtk,
    baseDef: cfg.enemyBaseDef,
    baseSpd: cfg.enemyBaseSpd,
    growth: cfg.enemyGrowth,
    count: cfg.enemyCount,
  );

  BattleBug mk(String id, Grade grade, Element el, Stance stance) {
    final s = cfg.normalized(grade);
    return BattleBug(
      id: id,
      name: '$id(${el.name})',
      element: el,
      temperament: Temperament.steadfast,
      preferredStance: stance,
      maxHp: s.hp,
      atk: s.atk,
      def: s.def,
      spd: s.spd,
    );
  }

  // 편성 예시. **상생 순서**(목→화→토→금→수→목)를 맞춘 팀이 위여야 한다.
  final teams = <String, List<BattleBug>>{
    '일반·상생순서(목화토)': [
      mk('a', Grade.common, Element.wood, Stance.attack),
      mk('b', Grade.common, Element.fire, Stance.defend),
      mk('c', Grade.common, Element.earth, Stance.heal),
    ],
    '일반·한속성몰빵(목목목)': [
      mk('a', Grade.common, Element.wood, Stance.attack),
      mk('b', Grade.common, Element.wood, Stance.attack),
      mk('c', Grade.common, Element.wood, Stance.attack),
    ],
    '일반·순서엉망(토화목)': [
      mk('a', Grade.common, Element.earth, Stance.attack),
      mk('b', Grade.common, Element.fire, Stance.defend),
      mk('c', Grade.common, Element.wood, Stance.heal),
    ],
    '전설·상생순서': [
      mk('a', Grade.legendary, Element.wood, Stance.attack),
      mk('b', Grade.legendary, Element.fire, Stance.defend),
      mk('c', Grade.legendary, Element.earth, Stance.heal),
    ],
    '전설·몰빵': [
      mk('a', Grade.legendary, Element.metal, Stance.attack),
      mk('b', Grade.legendary, Element.metal, Stance.attack),
      mk('c', Grade.legendary, Element.metal, Stance.attack),
    ],
    '혼합(희귀+일반)·상생': [
      mk('a', Grade.rare, Element.water, Stance.attack),
      mk('b', Grade.common, Element.wood, Stance.defend),
      mk('c', Grade.rare, Element.fire, Stance.heal),
    ],
  };

  stdout.writeln('── 설정 ──');
  stdout.writeln(
    '  적: hp ${spec.baseHp} · atk ${spec.baseAtk} · 성장 x${spec.growth}/웨이브 · ${spec.count}마리',
  );
  stdout.writeln(
    '  아군 정규화: hp ${cfg.normBaseHp} · atk ${cfg.normBaseAtk} '
    '(전설 +${((cfg.gradeMult(Grade.legendary) - 1) * 100).round()}%)',
  );
  stdout.writeln(
    '  회복 ${(cfg.waveHealPct * 100).round()}%/웨이브 · 상한 ${cfg.maxWave}웨이브',
  );
  stdout.writeln('');

  // 회차마다 웨이브가 달라지므로 여러 회차를 돌려 평균을 본다.
  const rounds = ['2026-W34', '2026-W36', '2026-W38', '2026-W40', '2026-W42'];
  stdout.writeln('── 편성별 도달 웨이브(회차 5개) ──');
  stdout.writeln('  같은 등급이면 **오행을 맞춘 팀이 위**여야 설계가 맞다.');
  stdout.writeln('  편성                        평균   최소~최대   점수(평균)');

  for (final e in teams.entries) {
    final waves = <int>[];
    final scores = <int>[];
    var timeout = 0, wipe = 0;
    for (final r in rounds) {
      final seed = EventConfig.roundSeedOf(r);
      final run = simulateWaveRun(
        seed: seed,
        team: e.value,
        enemyOf: (w) => eventWaveEnemies(seed, w, spec),
        maxWave: cfg.maxWave,
        waveHealPct: cfg.waveHealPct,
      );
      waves.add(run.clearedWaves);
      final last = run.waves.isEmpty ? null : run.waves.last;
      if (last != null) {
        if (last.rounds >= kMaxEventRounds) {
          timeout++;
        } else {
          wipe++;
        }
      }
      scores.add(
        cfg.score(
          clearedWaves: run.clearedWaves,
          hpPct: run.hpPctAtLastWave,
          survivors: run.survivors,
          totalRounds: run.totalRounds,
        ),
      );
    }
    final avg = waves.reduce((a, b) => a + b) / waves.length;
    final sAvg = scores.reduce((a, b) => a + b) ~/ scores.length;
    final lo = waves.reduce((a, b) => a < b ? a : b);
    final hi = waves.reduce((a, b) => a > b ? a : b);
    stdout.writeln(
      '  ${e.key.padRight(26)} ${avg.toStringAsFixed(1).padLeft(5)}   '
      '${'$lo~$hi'.padLeft(7)}   ${sAvg.toString().padLeft(10)}',
    );
    stdout.writeln('     끝난 이유: 전멸 $wipe · 판정패 $timeout');
    if (hi >= cfg.maxWave) {
      stdout.writeln('     ⚠️ 상한 도달 — 동점이 쏟아져 순위를 못 매긴다');
    }
  }

  stdout.writeln('');
  stdout.writeln('── 선봉 오행 선택이 값어치가 있는가 ──');
  stdout.writeln('  편성                        고정    상극선봉    차이');
  for (final e in teams.entries) {
    var dumb = 0.0, smart = 0.0;
    for (final r in rounds) {
      final seed = EventConfig.roundSeedOf(r);
      dumb += _runWithLead(cfg, seed, e.value, spec, smartLead: false);
      smart += _runWithLead(cfg, seed, e.value, spec, smartLead: true);
    }
    dumb /= rounds.length;
    smart /= rounds.length;
    final pct = dumb <= 0 ? 0.0 : (smart - dumb) / dumb * 100;
    stdout.writeln(
      '  ${e.key.padRight(26)} ${dumb.toStringAsFixed(1).padLeft(5)}   '
      '${smart.toStringAsFixed(1).padLeft(7)}   '
      '${'${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(0)}%'.padLeft(6)}',
    );
  }
}

/// 오행이 **실제로 보상되는지** 재는 실험(2026-09-02).
///
/// 웨이브 색은 `(seed + wave) % 5` 로 한 칸씩 돈다 — 어떤 팀이든 5웨이브면
/// 다섯 색을 한 번씩 만난다. 그래서 **어떤 색을 들고 오느냐**는 구조적으로
/// 상쇄된다. 남는 유일한 오행 선택은 **웨이브마다 선봉을 누구로 두느냐**다.
/// 이 함수는 그 선택의 값어치를 잰다: 매 웨이브 상극을 아는 곤충을 앞에
/// 세우는 플레이 vs 그냥 두는 플레이.
int _runWithLead(
  EventConfig cfg,
  int seed,
  List<BattleBug> team,
  WaveEnemySpec spec, {
  required bool smartLead,
}) {
  var order = [...team];
  var hp = [for (final u in order) u.maxHp];
  var cleared = 0;
  for (var w = 1; w <= cfg.maxWave; w++) {
    final foes = eventWaveEnemies(seed, w, spec);
    if (smartLead && foes.isNotEmpty) {
      // 이번 웨이브 색을 克하는 살아 있는 곤충을 앞으로.
      final foeEl = foes.first.element;
      for (var i = 1; i < order.length; i++) {
        if (hp[i] > 0 && order[i].element.restrains(foeEl)) {
          order.insert(0, order.removeAt(i));
          hp.insert(0, hp.removeAt(i));
          break;
        }
      }
    }
    final st = initBattle(
      seed + w * 7919,
      order,
      foes,
      initialHpA: hp,
      maxRounds: kMaxEventRounds,
    );
    var guard = 0;
    while (!st.done && guard++ < kMaxEventRounds * 2) {
      st.step();
    }
    if (st.toResult().outcome != BattleOutcome.teamA) break;
    cleared = w;
    hp = [...st.hpA];
    for (var i = 0; i < hp.length; i++) {
      if (hp[i] > 0) {
        final m = order[i].maxHp;
        final v = hp[i] + m * cfg.waveHealPct;
        hp[i] = v > m ? m : v;
      }
    }
  }
  return cleared;
}
