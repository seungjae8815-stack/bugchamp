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
//   dart run tool/duel_build_sim.dart --set=clutchEnabled=true       # 불값도 된다(탭 반격 켠 1.0.18 상태)
//   dart run tool/duel_build_sim.dart --only1 --n=200                # 1번 표(기질)만 — 판 수를 늘려 흔들림 줄이기
//   dart run tool/duel_build_sim.dart --mod=aggressive.attack=2      # training.temperamentMods 덮어쓰기
//   dart run tool/duel_build_sim.dart --per=crit=0.015               # training.perLevel 덮어쓰기
//   dart run tool/duel_build_sim.dart --tset=slots.defense.effect=0.05   # training 아래 아무 값(점 경로)
//   dart run tool/duel_build_sim.dart --aura --n=300                 # 팀 역할 오라·지휘 칸 표(1.0.21 D3)만
//   dart run tool/duel_build_sim.dart --aura --aura-base=0.02,0.03,0.04,0.05,0.06 --aura-cap=0.2
//       --tset=slots.command.effect=0.006                            # 오라 수치 덮어쓰기(한 줄로)
//   dart run tool/duel_build_sim.dart --aura=2                       # 표 번호만(쉼표로 여러 개)
//   dart run tool/duel_build_sim.dart --team-eval                    # 종 배율(gradeScale) 점검 — 3마리 경기·1:1·대회
//   dart run tool/duel_build_sim.dart --team-fit --rounds=10 --m=20000 --vm=60000
//   dart run tool/duel_build_sim.dart --team-fit --flat ...            # 1.0.22 곤충 희귀도 — 종끼리 50%
//   dart run tool/duel_build_sim.dart --rarity-fit --rm=4000           # 1.0.22 희귀도 결투 배율(전설 대 일반 65%)
//       # 종 배율을 3마리 경기 "종 출전 승률"로 다시 맞춘다(결과 표를 species.json 에 손으로 옮긴다)
//
// 보는 것:
//  1. 기질별 승률(완전 투자 · 같은 종 거울전) — 목표 45~55%.
//  2. 종별 판 길이(초) — 목표 8~14초.
//  3. 훈련 능력치별 가치(한 능력치에 8단계 vs 무훈련) — 서로 비슷해야 한다.
//  --aura: 팀 역할 오라(3마리 경기 · 훈련 v2 포인트 · 다 키운 전설 개체) — 역할 조합 리그전 · 에이스 대 지휘관 · 오라 크기.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';
import 'package:core_save/core_save.dart';
import 'package:server/src/actions.dart';
import 'package:server/src/game_config.dart';

Future<void> main(List<String> args) async {
  var n = 24;
  final only1 = args.contains('--only1');
  final duelOver = <String, Object>{};
  final modOver = <String, num>{};
  final perOver = <String, num>{};
  final trainOver = <String, num>{};
  final auraOver = <String, Object>{};
  for (final a in args) {
    final m = RegExp(r'^--([a-z-]+)=(.+)$').firstMatch(a);
    if (m == null) continue;
    final v = m.group(2)!;
    switch (m.group(1)) {
      case 'n':
        n = int.parse(v);
      case 'set':
        final kv = v.split('=');
        duelOver[kv[0]] = kv[1] == 'true' || kv[1] == 'false'
            ? kv[1] == 'true'
            : num.parse(kv[1]);
      case 'mod':
        final kv = v.split('=');
        modOver[kv[0]] = num.parse(kv[1]);
      case 'per':
        final kv = v.split('=');
        perOver[kv[0]] = num.parse(kv[1]);
      case 'tset':
        final kv = v.split('=');
        trainOver[kv[0]] = num.parse(kv[1]);
      case 'aura-base':
        auraOver['baseByGrade'] = [for (final x in v.split(',')) num.parse(x)];
      case 'aura-cap':
        auraOver['capPerStat'] = num.parse(v);
    }
  }

  // 덮어쓰기는 데이터 폴더 사본에 적어 GameConfig 가 그대로 읽게 한다.
  var dir = '../app/assets/data';
  if (duelOver.isNotEmpty ||
      auraOver.isNotEmpty ||
      modOver.isNotEmpty ||
      perOver.isNotEmpty ||
      trainOver.isNotEmpty) {
    final tmp = Directory.systemTemp.createTempSync('duel_build_sim');
    for (final f in Directory(dir).listSync().whereType<File>()) {
      f.copySync('${tmp.path}/${f.uri.pathSegments.last}');
    }
    final bf = File('${tmp.path}/battle.json');
    final b = jsonDecode(bf.readAsStringSync()) as Map<String, dynamic>;
    final duel = b['duel'] as Map<String, dynamic>;
    duelOver.forEach((k, v) => duel[k] = v);
    if (auraOver.isNotEmpty) {
      duel['teamAura'] = {
        ...((duel['teamAura'] as Map?) ?? const {}),
        ...auraOver,
      };
    }
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
    trainOver.forEach((path, v) {
      final parts = path.split('.');
      var cur = b['training'] as Map<String, dynamic>;
      for (var i = 0; i < parts.length - 1; i++) {
        cur =
            cur.putIfAbsent(parts[i], () => <String, dynamic>{})
                as Map<String, dynamic>;
      }
      cur[parts.last] = v;
    });
    bf.writeAsStringSync(jsonEncode(b));
    dir = tmp.path;
    stdout.writeln('덮어쓴 값: $duelOver $auraOver $modOver $perOver $trainOver\n');
  }

  final cfg = await GameConfig.load(dir: dir);
  final t0 = DateTime.utc(2026, 10, 1);
  final actions = GameActions(config: cfg, now: () => t0);
  final p = actions.duelParams;
  final tr = cfg.battle.training;
  final species = cfg.speciesById.values.toList()
    ..sort((a, b) => a.id.compareTo(b.id));

  if (args.any((a) => a == '--aura' || a.startsWith('--aura='))) {
    // --aura=2 처럼 표 번호를 주면 그 표만(쉼표로 여러 개).
    final only = [
      for (final a in args)
        if (a.startsWith('--aura='))
          for (final x in a.substring(7).split(',')) int.parse(x),
    ];
    _auraTables(
      actions,
      cfg,
      species,
      t0,
      n,
      only.isEmpty ? {1, 2, 3} : only.toSet(),
    );
    return;
  }

  if (args.any(
    (a) =>
        a == '--team-fit' ||
        a == '--team-eval' ||
        a == '--event-fit' ||
        a == '--rarity-fit',
  )) {
    _teamFit(actions, cfg, species, t0, args);
    return;
  }

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
  if (only1) return;

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

// ── 팀 역할 오라(1.0.21 D3, docs/design_growth_1021.md §3) ─────────────────────
//
// 3마리 승자 연속 경기(simulateDuel) · 훈련 v2 포인트(다 키운 전설 개체: 포텐셜 5 · 80레벨 · 돌파 4 = 102점) ·
// 서버 편성 함수(validateDuelTeam — 오라까지 입힌다). 오라를 끈 같은 경기도 함께 재서 오라 몫만 본다.
//
// 1. 역할 조합 리그전(공격 3 · 방어 3 · 체력 3 · 섞기 · 2+1) — 종은 그 역할 안에서 무작위, 목표 45~55%.
// 2. 에이스(추천 배분 'balanced' 102점) 대 지휘관(같은 종·순서, 공격 칸 10점을 지휘 칸으로) — 목표 45~55%.
// 3. 같은 팀 오라 있음 대 없음(오라 크기의 체감).
void _auraTables(
  GameActions actions,
  GameConfig cfg,
  List<Species> species,
  DateTime t0,
  int n,
  Set<int> tables,
) {
  final p = actions.duelParams;
  final tr = cfg.battle.training;
  final aura = cfg.battle.teamAura;
  final rng = math.Random(20261014);
  // 지휘 칸 상한이 10 인 기질(교활 0) — 양쪽 같은 기질이라 기질 몫은 지운다.
  const temp = Temperament.cunning;
  final ace = tr.presets['balanced'] ?? const {TrainSlot.attack: 1};
  stdout.writeln(
    '팀 오라: 켜짐 ${aura.enabled} · 등급 기본 ${aura.baseByGrade} · 능력치 상한 ${aura.capPerStat}'
    ' · 지휘 1점 ${tr.slotEffect[TrainSlot.command]} · 지휘 칸 상한(교활) '
    '${tr.slotCap(TrainSlot.command, temperament: temp, specialty: Specialty.strike)}\n',
  );

  final cache = <String, List<DuelBug>>{};
  var uid = 0;

  /// [team] = (종, 지휘 점수). 나머지 포인트는 추천 배분으로.
  List<DuelBug> build(List<(Species, int)> team, {required bool withAura}) {
    final key = '${team.map((e) => '${e.$1.id}:${e.$2}').join(',')}|$withAura';
    return cache.putIfAbsent(key, () {
      final bugs = <IndividualBug>[];
      final rec = <String, BugTrain>{};
      for (final (sp, cmd) in team) {
        final b = IndividualBug(
          id: 'b${uid++}',
          speciesId: sp.id,
          sizeMm: (sp.sizeMinMm + sp.sizeMaxMm) / 2,
          potential: 5,
          temperament: temp,
          sex: Sex.male,
          element: Element.wood,
          stage: LifeStage.adult,
          stageSince: t0.subtract(const Duration(days: 60)),
          level: 80,
          breakthroughTier: 4,
        );
        final budget = trainBaseBudget(b, tr, levelCap: cfg.pet.levelCap(4));
        int capOf(TrainSlot sl) => tr.slotCap(
          sl,
          temperament: b.temperament,
          specialty: sp.specialty,
          trait: b.trait,
        );
        // 지휘관 = 에이스 배분에서 공격 칸 [cmd]점을 지휘 칸으로 옮긴 것(공격 1점 ≈ 지휘 1점 비교).
        // 비율로 깎으면 근성(10 = 반격 2번 문턱)·기술이 1점씩 빠져 지휘와 무관하게 크게 약해진다.
        final alloc = Map<TrainSlot, int>.from(
          distributeTrainPoints(ace, budget, capOf: capOf),
        );
        if (cmd > 0) {
          final moved = cmd.clamp(0, alloc[TrainSlot.attack] ?? 0);
          alloc[TrainSlot.attack] = (alloc[TrainSlot.attack] ?? 0) - moved;
          alloc[TrainSlot.command] = moved;
        }
        bugs.add(b);
        rec[b.id] = BugTrain(alloc: alloc, paid: budget);
      }
      final save = SaveGame.initial(
        createdAt: t0.subtract(const Duration(days: 90)),
      ).copyWith(bugs: bugs, trainPoints: rec);
      if (withAura) {
        final v = actions.validateDuelTeam(
          save,
          [for (final b in bugs) b.id],
          speciesById: cfg.speciesById,
          petConfig: cfg.pet,
          enhance: cfg.enhance,
        );
        if (v.error != null) throw StateError('team: ${v.error}');
        return v.team;
      }
      // 오라 없는 같은 팀 — 한 마리씩(대회 경로 = 오라를 입히지 않는다) 만든다.
      return [
        for (final b in bugs)
          actions
              .validateDuelTeam(
                save,
                [b.id],
                speciesById: cfg.speciesById,
                petConfig: cfg.pet,
                enhance: cfg.enhance,
                teamSize: 1,
              )
              .team
              .first
              .withAura(null, 0),
      ];
    });
  }

  var seed = 1;
  double match(List<DuelBug> a, List<DuelBug> b) {
    // 자리(A/B)를 번갈아.
    final flip = (seed & 1) == 1;
    final m = simulateDuel(
      seed: seed++,
      teamA: flip ? b : a,
      teamB: flip ? a : b,
      params: p,
    );
    final w = m.winner(p);
    if (w == null) return 0.5;
    final aWon = flip ? w == 1 : w == 0;
    return aWon ? 1 : 0;
  }

  String pct(double v) => '${(v * 100).toStringAsFixed(1)}%';
  final byRole = {
    for (final r in DuelRole.values)
      r: [
        for (final sp in species)
          if (sp.duelRole == r) sp,
      ],
  };
  Species pick(DuelRole r) => byRole[r]![rng.nextInt(byRole[r]!.length)];

  // ── 1. 역할 조합 리그전 ──
  if (tables.contains(1)) {
    const comps = <String, List<DuelRole>>{
      'A3': [DuelRole.attack, DuelRole.attack, DuelRole.attack],
      'D3': [DuelRole.defense, DuelRole.defense, DuelRole.defense],
      'H3': [DuelRole.hp, DuelRole.hp, DuelRole.hp],
      'ADH': [DuelRole.attack, DuelRole.defense, DuelRole.hp],
      'AAH': [DuelRole.attack, DuelRole.attack, DuelRole.hp],
      'DDA': [DuelRole.defense, DuelRole.defense, DuelRole.attack],
    };
    stdout.writeln(
      '1. 역할 조합 리그전 — 행 팀 승률 · 오라 켬(끔) · 경기 $n번씩 · 목표 45~55% (A=공격형 D=방어형 H=체력형)',
    );
    final names = comps.keys.toList();
    final total = {for (final k in names) k: 0.0};
    final totalOff = {for (final k in names) k: 0.0};
    final head = StringBuffer('  ${''.padRight(5)}');
    for (final k in names) {
      head.write(k.padLeft(15));
    }
    stdout.writeln(head);
    for (final x in names) {
      final row = StringBuffer('  ${x.padRight(5)}');
      for (final y in names) {
        if (x == y) {
          row.write('-'.padLeft(15));
          continue;
        }
        var on = 0.0, off = 0.0;
        for (var i = 0; i < n; i++) {
          final ta = [for (final r in comps[x]!) (pick(r), 0)]..shuffle(rng);
          final tb = [for (final r in comps[y]!) (pick(r), 0)]..shuffle(rng);
          on += match(build(ta, withAura: true), build(tb, withAura: true));
          off += match(build(ta, withAura: false), build(tb, withAura: false));
        }
        total[x] = total[x]! + on / n;
        totalOff[x] = totalOff[x]! + off / n;
        row.write('${pct(on / n)}(${pct(off / n)})'.padLeft(15));
      }
      stdout.writeln(row);
    }
    stdout.writeln('  평균(다른 조합 전부 상대):');
    for (final k in names) {
      final m = names.length - 1;
      stdout.writeln(
        '    ${k.padRight(5)} 켬 ${pct(total[k]! / m)} · 끔 ${pct(totalOff[k]! / m)}'
        ' · 오라 몫 ${((total[k]! - totalOff[k]!) / m * 100).toStringAsFixed(1)}%p',
      );
    }
  }
  // ── 2. 에이스 대 지휘관 ──
  if (tables.contains(2)) {
    stdout.writeln(
      '\n2. 지휘관 팀 승률 — 같은 종·순서 거울전 · 에이스 = 추천 배분 102점 · 지휘관 = 그중 공격 10점 → 지휘 10점 · 목표 45~55%',
    );
    for (final (label, roles) in <(String, List<DuelRole>?)>[
      ('무작위 종', null),
      ('ADH', [DuelRole.attack, DuelRole.defense, DuelRole.hp]),
      ('A3', [DuelRole.attack, DuelRole.attack, DuelRole.attack]),
      ('D3', [DuelRole.defense, DuelRole.defense, DuelRole.defense]),
      ('H3', [DuelRole.hp, DuelRole.hp, DuelRole.hp]),
    ]) {
      final out = StringBuffer('  ${label.padRight(10)}');
      for (final cmdCount in [1, 2, 3]) {
        var w = 0.0;
        for (var i = 0; i < n; i++) {
          final sps = roles == null
              ? [
                  for (var k = 0; k < 3; k++)
                    species[rng.nextInt(species.length)],
                ]
              : ([for (final r in roles) pick(r)]..shuffle(rng));
          final who = ([0, 1, 2]..shuffle(rng)).take(cmdCount).toSet();
          final a = build([
            for (var k = 0; k < 3; k++) (sps[k], who.contains(k) ? 10 : 0),
          ], withAura: true);
          final b = build([for (final sp in sps) (sp, 0)], withAura: true);
          w += match(a, b);
        }
        out.write('  지휘관 $cmdCount마리 ${pct(w / n)}');
      }
      stdout.writeln(out);
    }
  }
  // ── 3. 오라 크기 체감 ──
  if (tables.contains(3)) {
    stdout.writeln('\n3. 같은 팀 오라 있음 대 없음(무작위 종 · 지휘 0) — 오라가 경기를 얼마나 바꾸나');
    var w3 = 0.0;
    for (var i = 0; i < n; i++) {
      final sps = [
        for (var k = 0; k < 3; k++) (species[rng.nextInt(species.length)], 0),
      ];
      w3 += match(build(sps, withAura: true), build(sps, withAura: false));
    }
    stdout.writeln('  오라 있는 팀 ${pct(w3 / n)}');
  }
}

// ── 종 배율(species.json → gradeScale) 3마리 경기 맞추기(2026-10-14 사장님 확정) ─────────────────
//
// 예전 배율은 1:1 리그전(grade_duel_sim --league --fit)으로 맞췄는데, 실제 결투는 3마리 승자 연속 + 팀 오라라
// 방어형 3마리 ≈ 61% · 체력형 3마리 ≈ 43% 로 갈렸다. 여기서는 **무작위 3마리 팀**(종·기질·순서 무작위, 같은 종 중복 허용)
// 끼리 붙여 종마다 "그 종이 낀 팀의 승률(출전 승률)"을 재고, 종 희귀도 목표(일반 46 · 고급 48 · 희귀 50 · 영웅 52 ·
// 전설 54% — 1:1 때 사장님 확정 차등을 그대로)에 맞춰 체력·공격·방어 배율만 곱으로 고친다(속도 제외 — 예전과 같다).
//
// 곤충 = 다 키운 전설 개체(포텐셜 5 · 80레벨 · 돌파 4 · 102점 추천 배분 'balanced') · 롤 50 고정(id 롤 잡음 제거) ·
// 오행 같음(상극 없음) · 오라 켬. 배율은 결투 능력치에 마지막으로 곱해지는 값이라(battleMods) 만든 곤충의
// 체력·공격·방어에 비율을 곱하는 것과 같다 — 반복마다 곤충을 다시 만들지 않는다.
// 정규화: 전설 종 배율 평균 = 지금 값(1.00) — 대회 최상위 눈금을 지킨다.
void _teamFit(
  GameActions actions,
  GameConfig cfg,
  List<Species> species,
  DateTime t0,
  List<String> args,
) {
  int opt(String k, int d) {
    for (final a in args) {
      if (a.startsWith('--$k=')) return int.parse(a.substring(k.length + 3));
    }
    return d;
  }

  double optD(String k, double d) {
    for (final a in args) {
      if (a.startsWith('--$k=')) return double.parse(a.substring(k.length + 3));
    }
    return d;
  }

  final fit = args.contains('--team-fit');
  final rounds = opt('rounds', 8);
  final m = opt('m', 20000);
  final vm = opt('vm', 40000);
  final cn = opt('cn', 600);
  final n1 = opt('n1', 200);
  final evSeeds = opt('ev', 4);
  final gain = optD('gain', 2.0);
  final flat = args.contains('--flat');
  // 배율 범위(--min=0.5 --max=3.5) — 한 종이 혼자 튀지 않게(그 종은 목표에 못 닿을 수 있다).
  final lo = optD('min', 0.01), hi = optD('max', 100.0);
  // --temp=cunning 처럼 주면 3마리 경기의 기질을 그것 하나로(--aura 표는 교활 고정이다).
  final fixT = [
    for (final a in args)
      if (a.startsWith('--temp=')) Temperament.values.byName(a.substring(7)),
  ].firstOrNull;

  final p = actions.duelParams;
  final tr = cfg.battle.training;
  final aura = cfg.battle.teamAura;
  final ace = tr.presets['balanced'] ?? const {TrainSlot.attack: 1};
  final temps = Temperament.values;
  const goalByGrade = {
    Grade.common: 0.46,
    Grade.uncommon: 0.48,
    Grade.rare: 0.50,
    Grade.epic: 0.52,
    Grade.legendary: 0.54,
  };
  double goal(Species s) => flat ? 0.5 : goalByGrade[s.grade]!;

  // 종 × 기질 기본 곤충(지금 배율 s0 로 만들어진 값).
  final base = <String, Map<Temperament, DuelBug>>{};
  for (final sp in species) {
    base[sp.id] = {};
    for (final t in temps) {
      final b = IndividualBug(
        id: 'f_${sp.id}_${t.name}',
        speciesId: sp.id,
        sizeMm: (sp.sizeMinMm + sp.sizeMaxMm) / 2,
        potential: 5,
        temperament: t,
        sex: Sex.male,
        element: Element.wood,
        stage: LifeStage.adult,
        stageSince: t0.subtract(const Duration(days: 60)),
        level: 80,
        breakthroughTier: 4,
        rolls: List.filled(StatRoll.values.length, 50),
      );
      final budget = trainBaseBudget(b, tr, levelCap: cfg.pet.levelCap(4));
      int capOf(TrainSlot sl) => tr.slotCap(
        sl,
        temperament: t,
        specialty: sp.specialty,
        trait: b.trait,
      );
      // 기본 = 모든 종 균형 배분(--aura 표와 같은 기준 · 종을 가로지르는 리그전에서 가장 강한 배분).
      // --star = 주특기별 ★ 배분(presetFor — 던지기 = 체급형. 다른 종 상대로는 약하다, 2026-10-14 측정).
      final preset = !args.contains('--star')
          ? ace
          : (tr.presets[tr.presetIdFor(sp.specialty)] ?? ace);
      final alloc = distributeTrainPoints(preset, budget, capOf: capOf);
      final save =
          SaveGame.initial(
            createdAt: t0.subtract(const Duration(days: 90)),
          ).copyWith(
            bugs: [b],
            trainPoints: {b.id: BugTrain(alloc: alloc, paid: budget)},
          );
      final v = actions.validateDuelTeam(
        save,
        [b.id],
        speciesById: cfg.speciesById,
        petConfig: cfg.pet,
        enhance: cfg.enhance,
        teamSize: 1,
      );
      if (v.error != null) throw StateError('${sp.id}: ${v.error}');
      base[sp.id]![t] = v.team.first;
    }
  }
  final s0 = {for (final sp in species) sp.id: sp.gradeScale};

  DuelBug scaled(DuelBug d, double f, String id) => DuelBug(
    id: id,
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
    auraRole: d.auraRole,
    aura: d.aura,
  );

  /// [scale] = 종 배율(절대값). 곤충은 s0 로 만들어졌으니 비율을 곱한다.
  List<DuelBug> team(
    List<(Species, Temperament)> picks,
    Map<String, double> scale,
    String side,
  ) {
    final t = [
      for (var i = 0; i < picks.length; i++)
        scaled(
          base[picks[i].$1.id]![picks[i].$2]!,
          scale[picks[i].$1.id]! / s0[picks[i].$1.id]!,
          '$side$i',
        ),
    ];
    return aura.enabled ? applyTeamAura(t, capPerStat: aura.capPerStat) : t;
  }

  double play(List<DuelBug> a, List<DuelBug> b, int seed) {
    final flip = seed.isOdd;
    final r = simulateDuel(
      seed: seed,
      teamA: flip ? b : a,
      teamB: flip ? a : b,
      params: p,
    );
    final w = r.winner(p);
    if (w == null) return 0.5;
    return (flip ? w == 1 : w == 0) ? 1 : 0;
  }

  String pct(double v) => '${(v * 100).toStringAsFixed(1)}%';

  /// 종 출전 승률 — 무작위 3마리 대 3마리 [games]경기. [rngSeed] 가 같으면 같은 팀·같은 판(반복 비교용).
  Map<String, double> presence(
    Map<String, double> scale,
    int games,
    int rngSeed,
  ) {
    final rng = math.Random(rngSeed);
    final w = {for (final s in species) s.id: 0.0};
    final c = {for (final s in species) s.id: 0};
    (Species, Temperament) pick() => (
      species[rng.nextInt(species.length)],
      fixT ?? temps[rng.nextInt(temps.length)],
    );
    for (var i = 0; i < games; i++) {
      final a = [pick(), pick(), pick()];
      final b = [pick(), pick(), pick()];
      final r = play(
        team(a, scale, 'a'),
        team(b, scale, 'b'),
        rngSeed * 7919 + i,
      );
      for (final x in a) {
        w[x.$1.id] = w[x.$1.id]! + r;
        c[x.$1.id] = c[x.$1.id]! + 1;
      }
      for (final x in b) {
        w[x.$1.id] = w[x.$1.id]! + 1 - r;
        c[x.$1.id] = c[x.$1.id]! + 1;
      }
    }
    return {for (final s in species) s.id: w[s.id]! / c[s.id]!};
  }

  /// 역할 조합 리그전(무작위 종·기질) — 조합마다 다른 조합 전부 상대 평균.
  Map<String, double> comps(Map<String, double> scale, int games) {
    const roleOf = {
      'A': DuelRole.attack,
      'D': DuelRole.defense,
      'H': DuelRole.hp,
    };
    const names = [
      'AAA',
      'DDD',
      'HHH',
      'ADH',
      'AAD',
      'AAH',
      'DDA',
      'DDH',
      'HHA',
      'HHD',
    ];
    final byRole = {
      for (final r in DuelRole.values)
        r: [
          for (final s in species)
            if (s.duelRole == r) s,
        ],
    };
    final rng = math.Random(4242);
    List<(Species, Temperament)> draw(String c) => [
      for (final ch in c.split(''))
        (
          byRole[roleOf[ch]]![rng.nextInt(byRole[roleOf[ch]]!.length)],
          fixT ?? temps[rng.nextInt(temps.length)],
        ),
    ]..shuffle(rng);
    final tot = {for (final k in names) k: 0.0};
    var seed = 900000000;
    for (var i = 0; i < names.length; i++) {
      for (var j = i + 1; j < names.length; j++) {
        var w = 0.0;
        for (var g = 0; g < games; g++) {
          w += play(
            team(draw(names[i]), scale, 'a'),
            team(draw(names[j]), scale, 'b'),
            seed++,
          );
        }
        tot[names[i]] = tot[names[i]]! + w / games;
        tot[names[j]] = tot[names[j]]! + 1 - w / games;
      }
    }
    return {for (final k in names) k: tot[k]! / (names.length - 1)};
  }

  /// 1:1 리그전(20종 서로 · 기질은 판마다 돌아가며) — 예전 배율을 맞춘 질문(목표 43~58%).
  Map<String, double> league(Map<String, double> scale) {
    final w = {for (final s in species) s.id: 0.0};
    final c = {for (final s in species) s.id: 0};
    var seed = 500000000;
    for (var i = 0; i < species.length; i++) {
      for (var j = i + 1; j < species.length; j++) {
        final x = species[i], y = species[j];
        for (var g = 0; g < n1; g++) {
          final a = scaled(
            base[x.id]![temps[g % 5]]!,
            scale[x.id]! / s0[x.id]!,
            'a',
          );
          final b = scaled(
            base[y.id]![temps[(g ~/ 5) % 5]]!,
            scale[y.id]! / s0[y.id]!,
            'b',
          );
          final flip = g.isOdd;
          final bout = simulateBout(
            seed: seed++,
            a: flip ? b : a,
            b: flip ? a : b,
            params: p,
          );
          final aWon = flip ? !bout.aWon : bout.aWon;
          final r = bout.winner < 0 ? 0.5 : (aWon ? 1.0 : 0.0);
          w[x.id] = w[x.id]! + r;
          w[y.id] = w[y.id]! + 1 - r;
          c[x.id] = c[x.id]! + 1;
          c[y.id] = c[y.id]! + 1;
        }
      }
    }
    return {for (final s in species) s.id: w[s.id]! / c[s.id]!};
  }

  /// 대회(곤충 1마리 웨이브전 · 카드 없음 · 오라 없음) 평균 도달 웨이브 — 기질 5 × 회차 [evSeeds].
  Map<String, double> eventWaves(
    Map<String, double> scale, {
    Map<String, double>? ev,
  }) {
    final spec = ev == null
        ? actions.eventDuelSpec
        : actions.eventDuelSpec.withSpeciesScale(ev);
    final ep = actions.eventDuelParams;
    final out = <String, double>{};
    for (final sp in species) {
      var sum = 0, cnt = 0;
      for (final t in temps) {
        final me = scaled(
          base[sp.id]![t]!,
          scale[sp.id]! / s0[sp.id]!,
          'me',
        ).withAura(null, 0);
        for (var rs = 1; rs <= evSeeds; rs++) {
          final roundSeed = rs * 9973;
          var run = const EventDuelRun();
          while (!run.over) {
            run = eventDuelFight(
              seed: roundSeed * 31 + 7,
              run: run,
              bug: me,
              enemy: actions.eventDuelEnemyOf(
                roundSeed,
                run.wave,
                cfg.speciesById,
              ),
              params: ep,
              spec: spec,
              roundSeed: roundSeed,
            ).run;
          }
          sum += run.cleared;
          cnt++;
        }
      }
      out[sp.id] = sum / cnt;
    }
    return out;
  }

  String row(Species s) =>
      '${s.grade.key.padRight(10)} ${(s.duelRole?.name ?? '-').padRight(8)} ${s.id.padRight(24)}';

  void report(String title, Map<String, double> scale) {
    stdout.writeln('\n=== $title ===');
    final pr = presence(scale, vm, 31337);
    stdout.writeln(
      '· 종 출전 승률(무작위 3마리 팀 $vm경기 · 목표 43~57%, 희귀도 목표 ${flat ? '50' : '46~54'}%)',
    );
    final order = species.toList()
      ..sort((a, b) => pr[b.id]!.compareTo(pr[a.id]!));
    for (final s in order) {
      stdout.writeln(
        '  ${row(s)} ${pct(pr[s.id]!).padLeft(6)} (목표 ${pct(goal(s))}) · 배율 ${scale[s.id]!.toStringAsFixed(2)}',
      );
    }
    final pv = pr.values.toList()..sort();
    stdout.writeln('  범위 ${pct(pv.first)} ~ ${pct(pv.last)}');
    final cm = comps(scale, cn);
    stdout.writeln('· 역할 조합 평균 승률(다른 9조합 상대 · 쌍마다 $cn경기 · 목표 45~55%)');
    stdout.writeln(
      '  ${cm.entries.map((e) => '${e.key} ${pct(e.value)}').join(' · ')}',
    );
    final lg = league(scale);
    final lo = species.toList()..sort((a, b) => lg[b.id]!.compareTo(lg[a.id]!));
    stdout.writeln('· 1:1 리그전(20종 · 쌍마다 $n1판 · 목표 43~58%)');
    for (final s in lo) {
      stdout.writeln('  ${row(s)} ${pct(lg[s.id]!)}');
    }
  }

  var scale = Map<String, double>.from(s0);
  if (args.contains('--rarity-fit')) {
    // 곤충 희귀도 결투 배율(1.0.22, pets.json → bugRarity.duelMult, 2026-10-16 사장님 확정 "전설 대 일반 65%").
    // 같은 종·같은 기질·같은 훈련의 3마리 팀끼리(거울) 한쪽만 체력·공격·방어 ×f — 승률이 목표가 되는 f 를 찾는다.
    // 희귀도 사이는 고르게(곱으로 4등분): [1, f^¼, f^½, f^¾, f].
    final goalR = optD('rarity-goal', 0.65);
    final games = opt('rm', 4000);
    final rng0 = math.Random(2026);
    (Species, Temperament) pick() => (
      species[rng0.nextInt(species.length)],
      fixT ?? temps[rng0.nextInt(temps.length)],
    );
    final picks = [
      for (var i = 0; i < games; i++) [pick(), pick(), pick()],
    ];
    double rate(double f) {
      final up = {for (final sp in species) sp.id: scale[sp.id]! * f};
      var w = 0.0;
      for (var i = 0; i < games; i++) {
        w += play(
          team(picks[i], up, 'a'),
          team(picks[i], scale, 'b'),
          7001 + i,
        );
      }
      return w / games;
    }

    var lo = 1.0, hi = 3.0;
    for (var it = 0; it < 14; it++) {
      final mid = (lo + hi) / 2;
      if (rate(mid) < goalR) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final f = (lo + hi) / 2;
    final steps = [for (var i = 0; i <= 4; i++) math.pow(f, i / 4).toDouble()];
    stdout.writeln(
      '희귀도 결투 배율: 전설 대 일반 ${pct(goalR)} → ×${f.toStringAsFixed(3)} '
      '(3마리 거울 팀 $games경기)',
    );
    stdout.writeln(
      '  duelMult = [${steps.map((v) => v.toStringAsFixed(3)).join(', ')}]',
    );
    for (var i = 1; i <= 4; i++) {
      stdout.writeln(
        '  ${Grade.values[i].key} 대 일반 ${pct(rate(steps[i]))} · 한 칸 위 ${pct(rate(steps[1]))}',
      );
    }
    return;
  }
  if (args.contains('--event-fit')) {
    // 대회 전용 종 배율(event.json → duelWave.speciesScale) — 종별 도달 웨이브를 전체 평균 둘레로 모은다
    // (희귀도 기울기: 일반 −6% · 고급 −3% · 희귀 0 · 영웅 +3% · 전설 +6%). 종 배율(gradeScale)은 지금 데이터 그대로.
    // --flat(1.0.22 곤충 희귀도) — 종에는 희귀도가 없으니 기울기 없이 모든 종을 같은 웨이브로.
    final tilt = flat
        ? {for (final g in Grade.values) g: 1.0}
        : const {
            Grade.common: 0.94,
            Grade.uncommon: 0.97,
            Grade.rare: 1.00,
            Grade.epic: 1.03,
            Grade.legendary: 1.06,
          };
    final ev0 = {
      for (final sp in species)
        sp.id: actions.eventDuelSpec.speciesScaleOf(sp.id),
    };
    final w0 = eventWaves(scale, ev: {for (final sp in species) sp.id: 1.0});
    // --event-mean=18.5 처럼 주면 그 평균에 맞춘다(기본 = 배율 없는 지금 평균). 2026-10-14 는 2회차 실제 상태
    // (옛 종 배율·옛 치기) 평균 18.5 로 맞췄다 — 이번 수정으로 대회 전체 난이도가 움직이지 않게.
    final mean = optD(
      'event-mean',
      w0.values.reduce((a, b) => a + b) / w0.length,
    );
    final norm =
        species.map((sp) => tilt[sp.grade]!).reduce((a, b) => a + b) /
        species.length;
    double target(Species sp) => mean * tilt[sp.grade]! / norm;
    // 웨이브 1개 ≈ 전력 × growth^(1/압축) — 차이를 배율로 옮기는 이득.
    final g = actions.eventDuelSpec.growth;
    final c =
        actions.eventDuelSpec.statCompress ?? actions.duelParams.statCompress;
    final k = math.log(g) / c;
    var ev = {for (final sp in species) sp.id: 1.0};
    stdout.writeln(
      '대회 맞추기: 평균 ${mean.toStringAsFixed(1)}웨이브(배율 없음) · 웨이브 1개 ≈ 배율 ×${math.exp(k).toStringAsFixed(3)}',
    );
    for (var r = 0; r < rounds; r++) {
      final w = eventWaves(scale, ev: ev);
      final dev = species
          .map((sp) => (w[sp.id]! - target(sp)).abs())
          .reduce(math.max);
      stdout.writeln('  ${r + 1}회 전: 목표와 최대 차이 ${dev.toStringAsFixed(1)}웨이브');
      ev = {
        for (final sp in species)
          sp.id:
              ev[sp.id]! *
              math.exp(0.8 * math.pow(0.85, r) * k * (target(sp) - w[sp.id]!)),
      };
    }
    ev = {for (final sp in species) sp.id: (ev[sp.id]! * 100).round() / 100};
    final w1 = eventWaves(scale, ev: ev);
    final wNow = eventWaves(scale, ev: ev0);
    stdout.writeln(
      '\n대회 도달 웨이브(카드 없음 · 기질 5 × 회차 $evSeeds) — 배율 없음 → 새 배율(목표)',
    );
    for (final sp in species) {
      stdout.writeln(
        '  ${row(sp)} ${w0[sp.id]!.toStringAsFixed(1).padLeft(5)} → ${w1[sp.id]!.toStringAsFixed(1).padLeft(5)}'
        ' (목표 ${target(sp).toStringAsFixed(1)}) · 배율 ${ev[sp.id]!.toStringAsFixed(2)}',
      );
    }
    String spread(Map<String, double> w) {
      final v = w.values.toList()..sort();
      final m = v.reduce((a, b) => a + b) / v.length;
      final sd = math.sqrt(
        v.map((x) => (x - m) * (x - m)).reduce((a, b) => a + b) / v.length,
      );
      return '${v.first.toStringAsFixed(1)}~${v.last.toStringAsFixed(1)} · 평균 ${m.toStringAsFixed(1)} · 표준편차 ${sd.toStringAsFixed(1)}';
    }

    stdout.writeln('  배율 없음 ${spread(w0)}');
    stdout.writeln('  데이터 지금 값 ${spread(wNow)}');
    stdout.writeln('  새 배율 ${spread(w1)}');
    stdout.writeln(
      '  json: ${species.map((sp) => '"${sp.id}": ${ev[sp.id]!.toStringAsFixed(2)}').join(', ')}',
    );
    return;
  }
  if (!fit) {
    report('지금 배율', scale);
    final ev = eventWaves(scale);
    stdout.writeln('· 대회 도달 웨이브(카드 없음 · 기질 5 × 회차 $evSeeds)');
    for (final s in species) {
      stdout.writeln('  ${row(s)} ${ev[s.id]!.toStringAsFixed(1)}');
    }
    return;
  }

  final legs = species.where((s) => s.grade == Grade.legendary).toList();
  final legMean =
      legs.map((s) => s0[s.id]!).reduce((a, b) => a + b) / legs.length;
  stdout.writeln(
    '맞추기: $rounds회 × $m경기(같은 팀·판 반복) · 이득 $gain · 전설 종 평균 ${legMean.toStringAsFixed(2)} 유지',
  );
  for (var r = 0; r < rounds; r++) {
    final pr = presence(scale, m, 271828);
    final dev = species
        .map((s) => (pr[s.id]! - goal(s)).abs())
        .reduce(math.max);
    stdout.writeln('  ${r + 1}회 전: 목표와 최대 차이 ${pct(dev)}');
    final step = gain * math.pow(0.85, r);
    for (final s in species) {
      scale[s.id] = scale[s.id]! * math.exp(step * (goal(s) - pr[s.id]!));
    }
    final lm =
        legs.map((s) => scale[s.id]!).reduce((a, b) => a + b) / legs.length;
    scale = {
      for (final s in species)
        s.id: (scale[s.id]! * legMean / lm).clamp(lo, hi).toDouble(),
    };
  }
  // 두 자리로(데이터에 그대로 옮길 값).
  scale = {for (final s in species) s.id: (scale[s.id]! * 100).round() / 100};

  stdout.writeln('\n새 배율(지금 → 새):');
  for (final s in species) {
    stdout.writeln(
      '  ${row(s)} ${s0[s.id]!.toStringAsFixed(2)} → ${scale[s.id]!.toStringAsFixed(2)}',
    );
  }
  stdout.writeln(
    '  json: ${species.map((s) => '"${s.id}": ${scale[s.id]!.toStringAsFixed(2)}').join(', ')}',
  );
  if (args.contains('--no-report')) return;
  report('새 배율', scale);
  final e0 = eventWaves(s0), e1 = eventWaves(scale);
  stdout.writeln('· 대회 도달 웨이브(카드 없음 · 기질 5 × 회차 $evSeeds) 지금 → 새');
  for (final s in species) {
    stdout.writeln(
      '  ${row(s)} ${e0[s.id]!.toStringAsFixed(1)} → ${e1[s.id]!.toStringAsFixed(1)}',
    );
  }
}
