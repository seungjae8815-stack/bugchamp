// 결투 **실전 전투력** 맞추기(2026-10-10 사장님 확정) — 실제 곤충을 무작위로 키워 서로 싸우게 하고,
// "전투력 비 = 이길 확률 비"(Bradley–Terry: A 가 이길 확률 = Pa / (Pa + Pb))가 되도록 능력치 가중치를 찾는다.
//
// 옛 전투력(공격 + 방어 + 속도 + 체력 × 0.15)은 공격을 키운 곤충이 부풀고, 엔진이 방어를 100/(100+방어)로
// 체감시키는 것도, 회피·치명·회복력·밀어내기 힘·체급·기술·근성도 몰랐다. 자동 편성(세진 3마리)이 그래서
// 균형 있게 키운 곤충을 뺐다(실기 지적).
//
// 실행:
//   cd packages\server ; dart run tool/duel_power_fit.dart
//   dart run tool/duel_power_fit.dart --bugs=300 --opp=40 --n=4   # 곤충 수 · 곤충당 상대 수 · 짝마다 판 수
//
// 출력: 가중치(지수) · 옛/새 전투력의 예측력(따로 남겨 둔 짝의 로그 손실·정확도) · 다트 상수 한 줄.
import 'dart:io';
import 'dart:math' as math;

import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';
import 'package:core_save/core_save.dart';
import 'package:server/src/actions.dart';
import 'package:server/src/game_config.dart';

Future<void> main(List<String> args) async {
  var nBugs = 300, nOpp = 40, nBout = 4;
  for (final a in args) {
    final m = RegExp(r'^--([a-z]+)=(\d+)$').firstMatch(a);
    if (m == null) continue;
    final v = int.parse(m.group(2)!);
    switch (m.group(1)) {
      case 'bugs':
        nBugs = v;
      case 'opp':
        nOpp = v;
      case 'n':
        nBout = v;
    }
  }
  final cfg = await GameConfig.load(dir: '../app/assets/data');
  final t0 = DateTime.utc(2026, 10, 10);
  final actions = GameActions(config: cfg, now: () => t0);
  final p = actions.duelParams;
  final tr = cfg.battle.training;
  final pet = cfg.pet;
  final species = cfg.speciesById.values.toList()
    ..sort((a, b) => a.id.compareTo(b.id));
  final rng = math.Random(20261010);

  // ── 1. 무작위 곤충 — 종·크기·포텐셜·수련·돌파·기질·오행, 예산을 무작위 비율로 칸에 나눠 찍는다 ──
  DuelBug make(int i) {
    final sp = species[rng.nextInt(species.length)];
    final bt = rng.nextInt(5);
    final cap = pet.levelCap(bt);
    final b = IndividualBug(
      id: 'b$i',
      speciesId: sp.id,
      sizeMm: sp.sizeMinMm + rng.nextDouble() * (sp.sizeMaxMm - sp.sizeMinMm),
      potential: 1 + rng.nextInt(5),
      temperament: Temperament.values[rng.nextInt(Temperament.values.length)],
      sex: Sex.male,
      element: Element.values[rng.nextInt(Element.values.length)],
      stage: LifeStage.adult,
      stageSince: t0.subtract(const Duration(days: 30)),
      level: 1 + rng.nextInt(cap),
      breakthroughTier: bt,
    );
    final empty = SaveGame.initial(
      createdAt: t0.subtract(const Duration(days: 90)),
    ).copyWith(bugs: [b]);
    final budget = trainBaseBudget(b, tr, levelCap: cap);
    // 키운 정도도 섞는다 — 예산을 0~100% 쓴 곤충.
    final spend = (budget * math.pow(rng.nextDouble(), 0.6)).round();
    final w = {
      for (final s in TrainSlot.values)
        s: rng.nextDouble() < 0.35 ? 0.0 : -math.log(1 - rng.nextDouble()),
    };
    final alloc = <TrainSlot, int>{};
    for (var k = 0; k < spend; k++) {
      final open = [
        for (final s in TrainSlot.values)
          if ((alloc[s] ?? 0) < trainSlotCapOf(empty, b, sp, s, tr) &&
              w[s]! > 0)
            s,
      ];
      if (open.isEmpty) break;
      final tot = open.fold(0.0, (a, s) => a + w[s]!);
      var r = rng.nextDouble() * tot;
      var pick = open.last;
      for (final s in open) {
        r -= w[s]!;
        if (r <= 0) {
          pick = s;
          break;
        }
      }
      alloc[pick] = (alloc[pick] ?? 0) + 1;
    }
    final paid = alloc.values.fold(0, (a, v) => a + v);
    final save = empty.copyWith(
      trainPoints: {b.id: BugTrain(alloc: alloc, paid: paid)},
    );
    final v = actions.validateDuelTeam(
      save,
      [b.id],
      speciesById: cfg.speciesById,
      petConfig: pet,
      enhance: cfg.enhance,
      teamSize: 1,
    );
    if (v.error != null) throw StateError('${sp.id}: ${v.error}');
    return v.team.first;
  }

  final sw = Stopwatch()..start();
  final bugs = [for (var i = 0; i < nBugs; i++) make(i)];

  // ── 2. 짝 결과 — 곤충마다 무작위 상대 nOpp 명, 짝마다 nBout 판(자리 번갈아) ──
  final pairs = <(int, int, double)>[];
  var seed = 1;
  for (var i = 0; i < nBugs; i++) {
    for (var k = 0; k < nOpp ~/ 2; k++) {
      var j = rng.nextInt(nBugs);
      if (j == i) j = (j + 1) % nBugs;
      var w = 0.0;
      for (var q = 0; q < nBout; q++) {
        final flip = q.isOdd;
        final r = simulateBout(
          seed: seed++,
          a: flip ? bugs[j] : bugs[i],
          b: flip ? bugs[i] : bugs[j],
          params: p,
        );
        if (r.winner < 0) {
          w += 0.5;
        } else if (flip ? !r.aWon : r.aWon) {
          w += 1;
        }
      }
      pairs.add((i, j, w / nBout));
    }
  }
  stdout.writeln(
    '곤충 $nBugs · 짝 ${pairs.length} · 판 ${pairs.length * nBout} · ${sw.elapsed.inSeconds}초',
  );

  // ── 3. 특징값 — 엔진이 실제로 쓰는 값(사이즈 몫 덜어낸 능력치 · 확률 상한) ──
  const names = [
    'ln 공격',
    'ln 체력',
    'ln(1+방어/100)',
    'ln 속도',
    '-ln(1-회피)',
    '치명',
    '회복력',
    'ln 크기',
    'ln 체급',
    'ln 밀어내기',
    '기술',
    '근성',
  ];
  // 앱·서버의 [DuelBug.powerIn] 과 같은 특징값 — 공식을 여기서 따로 쓰지 않는다.
  List<double> feat(DuelBug d) => d.powerFeatures(p);

  final x = [for (final b in bugs) feat(b)];
  final dim = names.length;

  // 짝을 학습 80% · 검증 20% 로 나눈다.
  final idx = List.generate(pairs.length, (i) => i)..shuffle(rng);
  final cut = (pairs.length * 0.8).round();
  final train = [for (final i in idx.take(cut)) pairs[i]];
  final test = [for (final i in idx.skip(cut)) pairs[i]];

  double sig(double z) => 1 / (1 + math.exp(-z));

  // 로지스틱 회귀(짝 차이) — 뉴턴법, 약한 L2.
  List<double> fit(List<double> Function(int) f, int d) {
    final w = List<double>.filled(d, 0);
    for (var it = 0; it < 40; it++) {
      final g = List<double>.filled(d, 0);
      final h = List.generate(d, (_) => List<double>.filled(d, 0));
      for (final (i, j, y) in train) {
        final fi = f(i), fj = f(j);
        final dx = [for (var k = 0; k < d; k++) fi[k] - fj[k]];
        var z = 0.0;
        for (var k = 0; k < d; k++) {
          z += w[k] * dx[k];
        }
        final pr = sig(z);
        for (var k = 0; k < d; k++) {
          g[k] += (y - pr) * dx[k];
          for (var l = 0; l < d; l++) {
            h[k][l] += pr * (1 - pr) * dx[k] * dx[l];
          }
        }
      }
      for (var k = 0; k < d; k++) {
        g[k] -= 1e-3 * w[k];
        h[k][k] += 1e-3;
      }
      final step = _solve(h, g);
      var mx = 0.0;
      for (var k = 0; k < d; k++) {
        w[k] += step[k];
        mx = math.max(mx, step[k].abs());
      }
      if (mx < 1e-7) break;
    }
    return w;
  }

  ({double loss, double acc}) eval(double Function(int) score) {
    var loss = 0.0, acc = 0.0;
    for (final (i, j, y) in test) {
      final pr = sig(score(i) - score(j)).clamp(1e-6, 1 - 1e-6);
      loss -= y * math.log(pr) + (1 - y) * math.log(1 - pr);
      if ((pr - 0.5) * (y - 0.5) > 0 || y == 0.5) acc += 1;
    }
    return (loss: loss / test.length, acc: acc / test.length);
  }

  // 옛 전투력 — ln(옛 값) 하나에 계수 하나(가장 유리하게 맞춰 준다).
  final oldLn = [for (final b in bugs) math.log(_oldPower(b))];
  final wOld = fit((i) => [oldLn[i]], 1);
  final eOld = eval((i) => wOld[0] * oldLn[i]);

  final w = fit((i) => x[i], dim);
  double score(int i) {
    var z = 0.0;
    for (var k = 0; k < dim; k++) {
      z += w[k] * x[i][k];
    }
    return z;
  }

  final eNew = eval(score);
  stdout.writeln('\n가중치(전투력 = C × Π 특징^가중치 · 선형 특징은 exp(가중치 × 값))');
  for (var k = 0; k < dim; k++) {
    stdout.writeln('  ${names[k].padRight(16)} ${w[k].toStringAsFixed(4)}');
  }
  stdout.writeln('\n검증 짝 ${test.length} — 로그 손실(낮을수록 좋다) · 승패 맞힘');
  stdout.writeln(
    '  옛 전투력  ${eOld.loss.toStringAsFixed(4)} · ${(eOld.acc * 100).toStringAsFixed(1)}%'
    '  (옛 값 ^${wOld[0].toStringAsFixed(2)} 이 BT 와 가장 맞다)',
  );
  stdout.writeln(
    '  새 전투력  ${eNew.loss.toStringAsFixed(4)} · ${(eNew.acc * 100).toStringAsFixed(1)}%',
  );
  // 같은 집단에서 옛 전투력 중앙값과 새 전투력 중앙값이 같아지는 상수.
  final oldSorted = [for (final b in bugs) _oldPower(b)]..sort();
  final newSorted = [for (var i = 0; i < nBugs; i++) math.exp(score(i))]
    ..sort();
  final c = oldSorted[nBugs ~/ 2] / newSorted[nBugs ~/ 2];
  stdout.writeln(
    '\n중앙값 맞춤 상수 C = ${c.toStringAsExponential(4)}'
    ' (옛 중앙 ${oldSorted[nBugs ~/ 2].round()} · 새 최소~최대 ${(newSorted.first * c).round()}~${(newSorted.last * c).round()}'
    ' · 옛 ${oldSorted.first.round()}~${oldSorted.last.round()})',
  );
  stdout.writeln(
    '\nbattle.json → duel: "powerWeights": [${w.map((v) => v.toStringAsFixed(4)).join(', ')}], '
    '"powerScale": ${c.toStringAsPrecision(5)}',
  );
  // 지금 데이터의 가중치와 비교(다시 맞출 필요가 있는지).
  final cur = [for (var i = 0; i < nBugs; i++) bugs[i].powerIn(p)];
  final eCur = eval((i) => math.log(cur[i]));
  stdout.writeln(
    '지금 battle.json 가중치  ${eCur.loss.toStringAsFixed(4)} · ${(eCur.acc * 100).toStringAsFixed(1)}%',
  );
}

/// 옛 전투력(2026-10-10 전) — 비교용.
double _oldPower(DuelBug b) => b.maxHp * 0.15 + b.atk + b.def + b.spd;

/// 가우스 소거(작은 대칭 행렬).
List<double> _solve(List<List<double>> a0, List<double> b0) {
  final n = b0.length;
  final a = [
    for (final r in a0) [...r],
  ];
  final b = [...b0];
  for (var c = 0; c < n; c++) {
    var piv = c;
    for (var r = c + 1; r < n; r++) {
      if (a[r][c].abs() > a[piv][c].abs()) piv = r;
    }
    final tr = a[c];
    a[c] = a[piv];
    a[piv] = tr;
    final tb = b[c];
    b[c] = b[piv];
    b[piv] = tb;
    if (a[c][c].abs() < 1e-12) continue;
    for (var r = c + 1; r < n; r++) {
      final f = a[r][c] / a[c][c];
      for (var k = c; k < n; k++) {
        a[r][k] -= f * a[c][k];
      }
      b[r] -= f * b[c];
    }
  }
  final x = List<double>.filled(n, 0);
  for (var c = n - 1; c >= 0; c--) {
    var s = b[c];
    for (var k = c + 1; k < n; k++) {
      s -= a[c][k] * x[k];
    }
    x[c] = a[c][c].abs() < 1e-12 ? 0 : s / a[c][c];
  }
  return x;
}
