// 개체 등급·능력치 롤 설계 검토(docs/design_individual_grade.md) — 결투 승률로 배율·롤 폭을 고른다.
//
// 실제 곤충을 서버 편성 함수로 "다 키운" 상태로 만든 뒤(duel_build_sim 과 같은 경로),
// 등급 배율(체력·공격·방어)과 능력치 롤(±폭 · 타고난 치명·회피·회복력·밀어내기)을 곱해 **같은 종끼리** 붙인다.
// 종 능력치 재정규화·훈련 예산 변화는 아직 넣지 않았다(등급 효과만 떼어 본다).
//
// 실행: cd packages\server ; dart run tool/grade_duel_sim.dart [--n=40]
import 'dart:io';
import 'dart:math' as math;

import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';
import 'package:core_save/core_save.dart';
import 'package:server/src/actions.dart';
import 'package:server/src/game_config.dart';

Future<void> main(List<String> args) async {
  var n = 30;
  for (final a in args) {
    final m = RegExp(r'^--n=(\d+)$').firstMatch(a);
    if (m != null) n = int.parse(m.group(1)!);
  }
  final cfg = await GameConfig.load(dir: '../app/assets/data');
  final t0 = DateTime.utc(2026, 10, 1);
  final actions = GameActions(config: cfg, now: () => t0);
  final p = actions.duelParams;
  final tr = cfg.battle.training;
  final species = cfg.speciesById.values.toList()
    ..sort((a, b) => a.id.compareTo(b.id));

  DuelBug base(Species sp) {
    final b = IndividualBug(
      id: 'x',
      speciesId: sp.id,
      sizeMm: (sp.sizeMinMm + sp.sizeMaxMm) / 2,
      potential: 5,
      temperament: Temperament.steadfast,
      sex: Sex.male,
      element: Element.wood,
      stage: LifeStage.adult,
      stageSince: t0.subtract(const Duration(days: 60)),
      level: 80,
      breakthroughTier: 4,
    );
    final levels = {
      for (final s in TrainStat.values) s: trainCapOf(b, sp, s, tr),
    };
    final save = SaveGame.initial(
      createdAt: t0.subtract(const Duration(days: 90)),
    ).copyWith(bugs: [b], duelTraining: {b.id: levels});
    final v = actions.validateDuelTeam(
      save,
      [b.id],
      speciesById: cfg.speciesById,
      petConfig: cfg.pet,
      enhance: cfg.enhance,
      teamSize: 1,
    );
    if (v.error != null) throw StateError('${sp.id}: ${v.error}');
    return v.team.first;
  }

  /// [g] = 등급 배율(체력·공격·방어) · [r] = 롤(−1 최저 ~ +1 최고) · [w] = 롤 폭.
  DuelBug shaped(DuelBug d, double g, double r, double w) {
    final k = 1 + r * w;
    // 타고난 치명·회피·회복력·밀어내기(훈련 위에 더한다) — 롤 0 이 가운데.
    final t = (r + 1) / 2;
    return DuelBug(
      id: d.id,
      name: d.name,
      speciesId: d.speciesId,
      element: d.element,
      temperament: d.temperament,
      specialty: d.specialty,
      sizeMm: d.sizeMm,
      maxHp: d.maxHp * g * k,
      atk: d.atk * g * k,
      def: d.def * g * k,
      spd: d.spd * k,
      crit: d.crit + 0.04 * t,
      recovery: d.recovery + 0.06 * t,
      evade: d.evade + 0.03 * t,
      massMult: d.massMult,
      pushMult: d.pushMult * (1 + 0.1 * r),
      tech: d.tech,
      grit: d.grit,
      sizeStatMult: d.sizeStatMult,
    );
  }

  final bases = {for (final sp in species) sp.id: base(sp)};
  var seed = 1;
  double winRate(DuelBug Function(DuelBug) fa, DuelBug Function(DuelBug) fb) {
    var w = 0.0, total = 0;
    for (final d in bases.values) {
      final a = fa(d), b = fb(d);
      for (var i = 0; i < n; i++) {
        final flip = i.isOdd;
        final bout = simulateBout(
          seed: seed++,
          a: flip ? b : a,
          b: flip ? a : b,
          params: p,
        );
        final aWon = flip ? !bout.aWon : bout.aWon;
        w += bout.winner < 0 ? 0.5 : (aWon ? 1 : 0);
        total++;
      }
    }
    return w / total;
  }

  String pct(double x) => '${(x * 100).toStringAsFixed(1)}%';
  const names = ['일반', '고급', '희귀', '영웅', '전설'];
  final sets = {
    'S1 1.00·1.15·1.35·1.60·2.00': [1.0, 1.15, 1.35, 1.6, 2.0],
    'S2 1.00·1.10·1.22·1.36·1.52': [1.0, 1.1, 1.22, 1.36, 1.52],
    'S3 1.00·1.07·1.15·1.24·1.34': [1.0, 1.07, 1.15, 1.24, 1.34],
  };
  stdout.writeln('1. 등급 차이 — 같은 종·같은 훈련·가운데 롤, 위 등급의 승률(20종 평균, 종마다 $n판)');
  for (final e in sets.entries) {
    final g = e.value;
    final cells = <String>[];
    for (var i = 0; i < 4; i++) {
      cells.add(
        '${names[i + 1]}>${names[i]} '
        '${pct(winRate((d) => shaped(d, g[i + 1], 0, 0.15), (d) => shaped(d, g[i], 0, 0.15)))}',
      );
    }
    cells.add(
      '전설>일반 ${pct(winRate((d) => shaped(d, g[4], 0, 0.15), (d) => shaped(d, g[0], 0, 0.15)))}',
    );
    stdout.writeln('  ${e.key}: ${cells.join(' · ')}');
  }
  stdout.writeln('\n2. 롤 차이 — 같은 등급(전설), 좋은 롤 vs 나쁜 롤');
  for (final w in [0.10, 0.15, 0.20]) {
    final best = winRate((d) => shaped(d, 1, 1, w), (d) => shaped(d, 1, -1, w));
    final half = winRate(
      (d) => shaped(d, 1, 0.5, w),
      (d) => shaped(d, 1, -0.5, w),
    );
    stdout.writeln(
      '  폭 ±${(w * 100).round()}%: 최고 vs 최저 ${pct(best)} · 상위권(+½) vs 하위권(−½) ${pct(half)}',
    );
  }
  stdout.writeln('\n3. 교차 — 한 등급 아래 최고 롤 vs 위 등급 최저 롤(아래 쪽 승률, 롤 폭 ±15%)');
  for (final e in sets.entries) {
    final g = e.value;
    final x = winRate(
      (d) => shaped(d, g[3], 1, 0.15),
      (d) => shaped(d, g[4], -1, 0.15),
    );
    stdout.writeln('  ${e.key}: 영웅 최고 롤 vs 전설 최저 롤 → 영웅 ${pct(x)}');
  }

  // ── 4. 왕충 선발대회 도달 웨이브(카드 없이 — 상대 비교) ──
  // 기준: 롤 가운데 전설 = 지금 다 키운 5★. 아래 등급은 S2 배율 비율만큼 약하다(롤 폭 ±10%).
  if (args.contains('--event')) {
    const s2 = [1.0, 1.1, 1.22, 1.36, 1.52];
    final spec = actions.eventDuelSpec;
    final ep = actions.eventDuelParams;
    int play(DuelBug me, int roundSeed) {
      var run = const EventDuelRun();
      while (!run.over) {
        final step = eventDuelFight(
          seed: roundSeed * 31 + 7,
          run: run,
          bug: me,
          enemy: actions.eventDuelEnemyOf(roundSeed, run.wave, cfg.speciesById),
          params: ep,
          spec: spec,
        );
        run = step.run;
      }
      return run.cleared;
    }

    double avgWaves(double g, double r) {
      var sum = 0, cnt = 0;
      for (final d in bases.values) {
        for (var rs = 1; rs <= 4; rs++) {
          sum += play(shaped(d, g / s2[4], r, 0.10), rs * 9973);
          cnt++;
        }
      }
      return sum / cnt;
    }

    stdout.writeln('\n4. 대회 도달 웨이브(20종 평균 · 회차 4개 · 카드 없음) — 롤 폭 ±10%');
    for (var i = 4; i >= 0; i--) {
      final mid = avgWaves(s2[i], 0);
      final line = StringBuffer(
        '  ${names[i]}: 가운데 롤 ${mid.toStringAsFixed(1)}',
      );
      if (i == 4) {
        line.write(
          ' · 최고 롤 ${avgWaves(s2[i], 1).toStringAsFixed(1)}'
          ' · 최저 롤 ${avgWaves(s2[i], -1).toStringAsFixed(1)}',
        );
      }
      stdout.writeln(line);
    }
    final now = () {
      var sum = 0, cnt = 0;
      for (final d in bases.values) {
        for (var rs = 1; rs <= 4; rs++) {
          sum += play(d, rs * 9973);
          cnt++;
        }
      }
      return sum / cnt;
    }();
    stdout.writeln('  (참고) 지금 다 키운 5★(롤 없음): ${now.toStringAsFixed(1)}');
  }

  // ── 5. 종 능력치 재정규화 뒤 같은 등급 종 리그전 ──
  // 체력·공격·방어를 곱해 종 희귀도별 목표(일반 90 · 고급 93 · 희귀 96 · 영웅 98 · 전설 100% — 전설 종 평균 대비)에 맞춘다. 속도는 그대로.
  if (args.contains('--league')) {
    const target = {
      Grade.common: 0.90,
      Grade.uncommon: 0.93,
      Grade.rare: 0.96,
      Grade.epic: 0.98,
      Grade.legendary: 1.00,
    };
    double gm(DuelBug d) => math.pow(d.maxHp * d.atk * d.def, 1 / 3).toDouble();
    final legs = species.where((s) => s.grade == Grade.legendary).toList();
    final ref =
        legs.map((s) => gm(bases[s.id]!)).reduce((a, b) => a + b) / legs.length;
    DuelBug scaled(DuelBug d, double f) => DuelBug(
      id: d.id,
      name: d.name,
      speciesId: d.speciesId,
      element: d.element,
      temperament: d.temperament,
      specialty: d.specialty,
      sizeMm: d.sizeMm,
      maxHp: d.maxHp * f,
      atk: d.atk * f,
      def: d.def * f,
      spd: d.spd,
      crit: d.crit,
      recovery: d.recovery,
      evade: d.evade,
      massMult: d.massMult,
      pushMult: d.pushMult,
      tech: d.tech,
      grit: d.grit,
      sizeStatMult: d.sizeStatMult,
    );

    Map<String, double> league(Map<String, double> factor) {
      final pool = {
        for (final sp in species) sp.id: scaled(bases[sp.id]!, factor[sp.id]!),
      };
      final wins = {for (final s in species) s.id: 0.0};
      final games = {for (final s in species) s.id: 0};
      for (final a in species) {
        for (final b in species) {
          if (a.id.compareTo(b.id) >= 0) continue;
          for (var i = 0; i < n; i++) {
            final flip = i.isOdd;
            final A = pool[a.id]!, B = pool[b.id]!;
            final bout = simulateBout(
              seed: seed++,
              a: flip ? B : A,
              b: flip ? A : B,
              params: p,
            );
            final aWon = flip ? !bout.aWon : bout.aWon;
            final wa = bout.winner < 0 ? 0.5 : (aWon ? 1.0 : 0.0);
            wins[a.id] = wins[a.id]! + wa;
            wins[b.id] = wins[b.id]! + 1 - wa;
            games[a.id] = games[a.id]! + 1;
            games[b.id] = games[b.id]! + 1;
          }
        }
      }
      return {for (final s in species) s.id: wins[s.id]! / games[s.id]!};
    }

    // 목표 승률 — 귀한 종이 조금 유리하게(2026-10-11 사장님 확정: 일반 90 ~ 전설 100% 차등의 승률 버전).
    const goal = {
      Grade.common: 0.46,
      Grade.uncommon: 0.48,
      Grade.rare: 0.50,
      Grade.epic: 0.52,
      Grade.legendary: 0.54,
    };
    final factor = {
      for (final sp in species)
        sp.id: target[sp.grade]! * ref / gm(bases[sp.id]!),
    };
    var rates = league(factor);
    final rounds = args.contains('--fit') ? 10 : 0;
    stdout.writeln('\n5. 같은 등급 종 리그전(종마다 상대 19종 × $n판)');
    for (var r = 0; r < rounds; r++) {
      for (final sp in species) {
        // 목표보다 이기면 줄이고 지면 키운다.
        factor[sp.id] =
            factor[sp.id]! *
            math.pow(2, (goal[sp.grade]! - rates[sp.id]!) * 0.9).toDouble();
      }
      rates = league(factor);
      final dev = species
          .map((sp) => (rates[sp.id]! - goal[sp.grade]!).abs())
          .reduce(math.max);
      stdout.writeln('  조정 ${r + 1}회: 목표와 최대 차이 ${pct(dev)}');
    }
    final order = species.toList()
      ..sort((x, y) => rates[y.id]!.compareTo(rates[x.id]!));
    for (final s in order) {
      stdout.writeln(
        '  ${s.grade.name.padRight(9)} ${s.id.padRight(24)} ${pct(rates[s.id]!)}'
        ' · 체·공·방 ×${factor[s.id]!.toStringAsFixed(2)}'
        ' (전설 종 평균의 ${pct(factor[s.id]! * gm(bases[s.id]!) / ref)})'
        ' · 속도 ${bases[s.id]!.spd.toStringAsFixed(0)}',
      );
    }
  }

  // ── 6. 종 배율(species.json gradeScale) 적용 뒤 종별 대회 웨이브 — 지금(5★)과 비교 ──
  if (args.contains('--event2')) {
    final spec = actions.eventDuelSpec;
    final ep = actions.eventDuelParams;
    int play(DuelBug me, int roundSeed) {
      var run = const EventDuelRun();
      while (!run.over) {
        final step = eventDuelFight(
          seed: roundSeed * 31 + 7,
          run: run,
          bug: me,
          enemy: actions.eventDuelEnemyOf(roundSeed, run.wave, cfg.speciesById),
          params: ep,
          spec: spec,
        );
        run = step.run;
      }
      return run.cleared;
    }

    double waves(DuelBug d) {
      var sum = 0;
      for (var rs = 1; rs <= 6; rs++) {
        sum += play(d, rs * 9973);
      }
      return sum / 6;
    }

    stdout.writeln('\n6. 종별 대회 웨이브(전설 · 가운데 롤 · 카드 없음, 회차 6개) — 지금 5★ vs 개편 뒤');
    final rows = <(String, double, double)>[];
    for (final sp in species) {
      final d = bases[sp.id]!;
      rows.add((sp.id, waves(d), waves(shaped(d, sp.gradeScale, 0, 0.10))));
    }
    rows.sort((a, b) => b.$3.compareTo(a.$3));
    for (final r in rows) {
      stdout.writeln(
        '  ${r.$1.padRight(24)} 지금 ${r.$2.toStringAsFixed(1)} → 개편 ${r.$3.toStringAsFixed(1)}',
      );
    }
  }
}
