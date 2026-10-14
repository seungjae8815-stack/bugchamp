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
