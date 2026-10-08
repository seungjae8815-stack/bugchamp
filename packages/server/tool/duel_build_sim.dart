// 결투 밸런스 — **실제 곤충**으로 잰다(훈련소·부위 강화·수련·기질 보정까지, 서버 편성 함수 그대로).
//
// core_battle/tool/duel_sim.dart 는 가상 유닛이라 종마다 다른 판 길이·훈련 상한의 기질 보정을
// 못 본다(2026-09-30 점검에서 호전적 독주 · 장수말벌 3.4초가 여기서 나왔다). core_save(훈련)와
// core_battle(엔진)을 둘 다 아는 곳이 서버라 여기 둔다.
//
// 실행:
//   cd packages\server ; dart run tool/duel_build_sim.dart
//   dart run tool/duel_build_sim.dart --n=40                         # 짝마다 판 수(기본 24)
//   dart run tool/duel_build_sim.dart --set=strikeFlipBase=0.09      # battle.json → duel 덮어쓰기
//   dart run tool/duel_build_sim.dart --mod=aggressive.attack=2      # training.temperamentMods 덮어쓰기
//   dart run tool/duel_build_sim.dart --per=crit=0.015               # training.perLevel 덮어쓰기
//
// 보는 것:
//  1. 기질별 승률(완전 투자 · 같은 종 거울전) — 목표 45~55%.
//  2. 종별 판 길이(초) — 목표 8~14초.
//  3. 훈련 능력치별 가치(한 능력치에 8단계 vs 무훈련) — 서로 비슷해야 한다.
import 'dart:convert';
import 'dart:io';

import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';
import 'package:core_save/core_save.dart';
import 'package:server/src/actions.dart';
import 'package:server/src/game_config.dart';

Future<void> main(List<String> args) async {
  var n = 24;
  final duelOver = <String, num>{};
  final modOver = <String, num>{};
  final perOver = <String, num>{};
  for (final a in args) {
    final m = RegExp(r'^--([a-z-]+)=(.+)$').firstMatch(a);
    if (m == null) continue;
    final v = m.group(2)!;
    switch (m.group(1)) {
      case 'n':
        n = int.parse(v);
      case 'set':
        final kv = v.split('=');
        duelOver[kv[0]] = num.parse(kv[1]);
      case 'mod':
        final kv = v.split('=');
        modOver[kv[0]] = num.parse(kv[1]);
      case 'per':
        final kv = v.split('=');
        perOver[kv[0]] = num.parse(kv[1]);
    }
  }

  // 덮어쓰기는 데이터 폴더 사본에 적어 GameConfig 가 그대로 읽게 한다.
  var dir = '../app/assets/data';
  if (duelOver.isNotEmpty || modOver.isNotEmpty || perOver.isNotEmpty) {
    final tmp = Directory.systemTemp.createTempSync('duel_build_sim');
    for (final f in Directory(dir).listSync().whereType<File>()) {
      f.copySync('${tmp.path}/${f.uri.pathSegments.last}');
    }
    final bf = File('${tmp.path}/battle.json');
    final b = jsonDecode(bf.readAsStringSync()) as Map<String, dynamic>;
    final duel = b['duel'] as Map<String, dynamic>;
    duelOver.forEach((k, v) => duel[k] = v);
    final mods =
        (b['training'] as Map<String, dynamic>)['temperamentMods']
            as Map<String, dynamic>;
    modOver.forEach((k, v) {
      final parts = k.split('.');
      final t = mods.putIfAbsent(parts[0], () => <String, dynamic>{}) as Map;
      t[parts[1]] = v;
    });
    final per =
        (b['training'] as Map<String, dynamic>)['perLevel']
            as Map<String, dynamic>;
    perOver.forEach((k, v) => per[k] = v);
    bf.writeAsStringSync(jsonEncode(b));
    dir = tmp.path;
    stdout.writeln('덮어쓴 값: $duelOver $modOver $perOver\n');
  }

  final cfg = await GameConfig.load(dir: dir);
  final t0 = DateTime.utc(2026, 10, 1);
  final actions = GameActions(config: cfg, now: () => t0);
  final p = actions.duelParams;
  final tr = cfg.battle.training;
  final species = cfg.speciesById.values.toList()
    ..sort((a, b) => a.id.compareTo(b.id));

  IndividualBug bugOf(Species sp, Temperament t, {String id = 'x'}) =>
      IndividualBug(
        id: id,
        speciesId: sp.id,
        sizeMm: (sp.sizeMinMm + sp.sizeMaxMm) / 2,
        potential: 5,
        temperament: t,
        sex: Sex.male,
        element: Element.wood,
        stage: LifeStage.adult,
        stageSince: t0.subtract(const Duration(days: 60)),
        enhancement: const PartLevels(
          hornJaw: 13,
          cuticle: 13,
          wing: 12,
          build: 12,
        ),
        level: 80,
        breakthroughTier: 4,
      );

  /// [train] 이 null 이면 모든 능력치를 최대 단계로.
  DuelBug build(IndividualBug b, Species sp, {Map<TrainStat, int>? train}) {
    final levels =
        train ??
        {for (final s in TrainStat.values) s: trainCapOf(b, sp, s, tr)};
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

  var seed = 1;
  ({double aWin, double secs}) duel(DuelBug a, DuelBug b) {
    var w = 0.0, secs = 0.0;
    for (var i = 0; i < n; i++) {
      // 자리(A/B)를 번갈아 — 자리 이점이 한쪽에 몰리지 않게.
      final flip = i.isOdd;
      final bout = simulateBout(
        seed: seed++,
        a: flip ? b : a,
        b: flip ? a : b,
        params: p,
      );
      final aWon = flip ? !bout.aWon : bout.aWon;
      if (bout.winner < 0) {
        w += 0.5;
      } else if (aWon) {
        w += 1;
      }
      secs += bout.ticks / p.tickHz;
    }
    return (aWin: w / n, secs: secs / n);
  }

  // ── 1. 기질별 승률 ──
  stdout.writeln('1. 기질별 승률 — 완전 투자 · 같은 종 거울전(모든 종 평균) · 목표 45~55%');
  final temps = Temperament.values;
  final win = {for (final t in temps) t: 0.0};
  final cnt = {for (final t in temps) t: 0};
  final secsBySp = <String, double>{};
  final finishBySp = <String, Map<String, int>>{};
  for (final sp in species) {
    final built = {for (final t in temps) t: build(bugOf(sp, t), sp)};
    var spSecs = 0.0, spN = 0;
    for (var i = 0; i < temps.length; i++) {
      for (var j = i + 1; j < temps.length; j++) {
        final r = duel(built[temps[i]]!, built[temps[j]]!);
        win[temps[i]] = win[temps[i]]! + r.aWin;
        win[temps[j]] = win[temps[j]]! + (1 - r.aWin);
        cnt[temps[i]] = cnt[temps[i]]! + 1;
        cnt[temps[j]] = cnt[temps[j]]! + 1;
        spSecs += r.secs;
        spN++;
      }
    }
    secsBySp[sp.id] = spSecs / spN;
    // 결판 종류(거울전 기준).
    final fin = <String, int>{};
    for (var k = 0; k < n; k++) {
      final bout = simulateBout(
        seed: seed++,
        a: built[Temperament.fickle]!,
        b: built[Temperament.steadfast]!,
        params: p,
      );
      fin[bout.finish.name] = (fin[bout.finish.name] ?? 0) + 1;
    }
    finishBySp[sp.id] = fin;
  }
  for (final t in temps) {
    stdout.writeln(
      '  ${t.name.padRight(12)} ${(win[t]! / cnt[t]! * 100).toStringAsFixed(1)}%',
    );
  }

  // ── 2. 종별 판 길이 — 모든 종을 상대로(실제 경기 모양) ──
  final crossBySp = <String, double>{};
  final fickle = {
    for (final sp in species) sp.id: build(bugOf(sp, Temperament.fickle), sp),
  };
  for (final sp in species) {
    var sum = 0.0;
    for (final op in species) {
      sum += duel(fickle[sp.id]!, fickle[op.id]!).secs;
    }
    crossBySp[sp.id] = sum / species.length;
  }
  stdout.writeln('\n2. 종별 판 길이(초) — 모든 종 상대 평균 / 거울전 · 목표 8~14초 · 결판(거울전)');
  for (final sp in species) {
    final s = crossBySp[sp.id]!;
    final mark = s < 8 || s > 14 ? ' ←' : '';
    stdout.writeln(
      '  ${'${sp.grade.key} ${sp.id}'.padRight(28)} ${sp.specialty.name.padRight(7)}'
      ' ${s.toStringAsFixed(1).padLeft(5)}초 / ${secsBySp[sp.id]!.toStringAsFixed(1).padLeft(4)}'
      '  ${finishBySp[sp.id]}$mark',
    );
  }
  final all = crossBySp.values.toList()..sort();
  stdout.writeln(
    '  최소 ${all.first.toStringAsFixed(1)} · 중앙 ${all[all.length ~/ 2].toStringAsFixed(1)} · 최대 ${all.last.toStringAsFixed(1)}초',
  );

  // ── 3. 훈련 능력치별 가치 ──
  stdout.writeln('\n3. 훈련 능력치별 가치 — 한 능력치 8단계 vs 무훈련(같은 곤충) 승률');
  for (final s in TrainStat.values) {
    var w = 0.0;
    for (final sp in species) {
      final base = bugOf(sp, Temperament.fickle);
      final a = build(base, sp, train: {s: 8});
      final b = build(base, sp, train: const {});
      w += duel(a, b).aWin;
    }
    stdout.writeln(
      '  ${s.name.padRight(10)} ${(w / species.length * 100).toStringAsFixed(1)}%',
    );
  }

  // ── 4. 같은 종 크기 — 최대 vs 최소(완전 투자 · 서버 편성 경로 = 사이즈 몫 덜어내기 포함) ──
  // 크기는 결투에서 무게로만(2026-10-08 사장님 확정) — 목표 60~70%(core_battle duel_sim 4번 표와 같은 질문).
  stdout.writeln('\n4. 같은 종 크기 — 최대 vs 최소 승률(실제 경로) · 목표 60~70%');
  final sizeWins = <double>[];
  for (final sp in species) {
    IndividualBug sized(double mm, String id) => IndividualBug.fromJson(
      bugOf(sp, Temperament.fickle, id: id).toJson(),
    ).copyWith(sizeMm: mm);
    final big = build(sized(sp.sizeMaxMm, 'big'), sp);
    final small = build(sized(sp.sizeMinMm, 'small'), sp);
    final r = duel(big, small).aWin;
    sizeWins.add(r);
    stdout.writeln(
      '  ${'${sp.grade.key} ${sp.id}'.padRight(28)} ${(r * 100).toStringAsFixed(0).padLeft(4)}%',
    );
  }
  sizeWins.sort();
  final avg = sizeWins.reduce((a, b) => a + b) / sizeWins.length;
  stdout.writeln(
    '  평균 ${(avg * 100).toStringAsFixed(1)}% · 최소 ${(sizeWins.first * 100).toStringAsFixed(0)}% · 최대 ${(sizeWins.last * 100).toStringAsFixed(0)}%',
  );
}
