// 요정 수입 시뮬 — 무료 유저가 날짜별로 **어떤 동행 요정**을 갖게 되나(docs/design_fairy.md).
//
// 규칙은 전부 실제 함수(core_save `fairy_progress.dart`)로 굴린다 — 손으로 더하면 틀린다.
// 결과(날짜별 중앙값 동행 요정)를 `core_run/tool/balance_targets.json → accumulation.fairyByDay`
// 에 적으면(`--write`) balance_sim 이 그 곡선으로 요정을 전투력에 얹는다(펫 곡선을 실측으로 넣은 것과 같다).
//
// 실행:
//   cd packages\core_save ; dart run tool/fairy_sim.dart
//   dart run tool/fairy_sim.dart --runs=400 --elites=180 --checkins=3 --write
//
// ⚠️ 가정(결과를 읽을 때 감안):
//  - 무료 유저: 뽑기·가속기·속성석을 젤리로 사지 않는다(90일 표는 무료 기준 — §2.8).
//  - 보스 첫 처치 날짜 = balance_targets.json 의 tierDays 안에 사냥터 11개를 고르게.
//    (실제로는 뒤 사냥터가 더 오래 걸린다 — 극한 전설 알이 조금 늦게 온다.)
//  - 정예 = 하루 온라인 처치 3,000 × run_config eliteChance(6%) = 180마리(펫 곡선 실측과 같은 처치 수).
//  - 하루 --checkins 번 접속: 꺼내기 → 가장 좋은 알 넣기(속성석 있으면 원하는 부가) → 가속기 → 자동 합성 →
//    가루는 전부 동행 요정 레벨업 → 요정함이 차면 낮은 요정부터 분해.
//  - 동행 = 등급 → 레벨 → 품질이 가장 높은 요정(종류는 가리지 않는다 — 종류는 무작위라 고를 수 없다).

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';

const _days = 90;
const _report = [3, 7, 14, 21, 30, 45, 60, 75, 90];

String get _root {
  var d = Directory.current;
  while (!File('${d.path}/pubspec.yaml').existsSync() ||
      !Directory('${d.path}/packages').existsSync()) {
    d = d.parent;
  }
  return d.path;
}

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

/// 날짜별 기록 한 줄.
typedef _Snap = ({
  int grade,
  int level,
  int baseRoll,
  int subRoll,
  double main,
  int eggs,
  int dust,
  int owned,
});

void main(List<String> args) {
  var runs = 300;
  var elitesPerDay = 180.0;
  var checkins = 3;
  var write = false;
  String? desiredSub = 'bossDamage';
  for (final a in args) {
    final m = RegExp(r'^--(\w+)(?:=(.*))?$').firstMatch(a);
    if (m == null) continue;
    switch (m.group(1)) {
      case 'runs':
        runs = int.parse(m.group(2)!);
      case 'elites':
        elitesPerDay = double.parse(m.group(2)!);
      case 'checkins':
        checkins = int.parse(m.group(2)!);
      case 'sub':
        desiredSub = m.group(2);
      case 'write':
        write = true;
    }
  }

  final root = _root;
  final cfg = FairyConfig.fromJson(
    _json('$root/packages/app/assets/data/fairies.json'),
  );
  final run = _json('$root/packages/app/assets/data/run_config.json');
  final targetsPath = '$root/packages/core_run/tool/balance_targets.json';
  final targets = _json(targetsPath);
  final tierDays = [
    for (final d in targets['tierDays'] as List) (d as num).toDouble(),
  ];
  final zones = (run['zonesPerTier'] as num?)?.toInt() ?? 11;

  // 보스 첫 처치 날짜(난이도, 날짜).
  final bosses = <({int tier, double day})>[];
  var start = 0.0;
  for (var t = 0; t < tierDays.length; t++) {
    for (var z = 1; z <= zones; z++) {
      bosses.add((tier: t, day: start + tierDays[t] * z / zones));
    }
    start += tierDays[t];
  }

  final snaps = <int, List<_Snap>>{for (final d in _report) d: []};
  for (var r = 0; r < runs; r++) {
    final rng = math.Random(1000 + r);
    var f = FairyState.empty;
    var eggsGot = 0;
    var dustGot = 0;
    var bossIdx = 0;
    final step = 1 / checkins;
    for (var day = 0.0; day < _days + 1e-9; day += step) {
      final now = DateTime.utc(
        2026,
      ).add(Duration(milliseconds: (day * 86400000).round()));
      // 이번 접속까지 들어온 것: 보스 첫 처치 · 정예 드롭.
      while (bossIdx < bosses.length && bosses[bossIdx].day <= day) {
        final before = f.eggs.length;
        f = fairyBossDrop(
          f,
          cfg,
          rng,
          tier: bosses[bossIdx].tier,
          firstKill: true,
        ).state!;
        eggsGot += f.eggs.length - before;
        bossIdx++;
      }
      final elites = elitesPerDay * step;
      for (var i = 0; i < elites; i++) {
        final op = fairyEliteDrop(f, cfg, rng);
        eggsGot += (op.extra['eggs'] as List).length;
        f = op.state!;
      }
      final dust0 = f.dust;
      f = _checkin(f, cfg, rng, now, desiredSub);
      dustGot += math.max(0, f.dust - dust0);

      final d = day.round();
      if ((day - d).abs() < step / 2 && snaps.containsKey(d)) {
        final c = f.companion;
        snaps[d]!.add((
          grade: c?.grade.index ?? -1,
          level: c?.level ?? 0,
          baseRoll: c?.baseRoll ?? 0,
          subRoll: c?.subRoll ?? 0,
          main: c == null ? 0 : cfg.statAt(c.grade, c.baseRoll),
          eggs: eggsGot,
          dust: dustGot,
          owned: f.fairies.length,
        ));
      }
    }
  }

  // ── 표 ──
  String gName(int g) => g < 0 ? '없음' : FairyGrade.values[g].key;
  stdout.writeln(
    '요정 수입 시뮬 · $runs회 · 정예 ${elitesPerDay.toStringAsFixed(0)}/일 · 접속 $checkins회/일',
  );
  stdout.writeln(
    '일  | 동행 등급(중앙·10%·90%)            | Lv(중앙) | 품질 | 기본치(Lv1) | 알 누적 | 가루 누적 | 보유',
  );
  final curve = <List<num>>[];
  for (final d in _report) {
    final xs = snaps[d]!;
    int pct(List<int> v, double p) {
      final s = [...v]..sort();
      return s[(p * (s.length - 1)).round()];
    }

    final grades = [for (final x in xs) x.grade];
    final g50 = pct(grades, 0.5);
    final same = xs.where((x) => x.grade == g50).toList();
    final lv = pct([for (final x in same) x.level], 0.5);
    final br = pct([for (final x in same) x.baseRoll], 0.5);
    final sr = pct([for (final x in same) x.subRoll], 0.5);
    final main = same.isEmpty
        ? 0.0
        : ([for (final x in same) x.main]..sort())[same.length ~/ 2];
    stdout.writeln(
      '${d.toString().padLeft(3)} | '
      '${gName(g50).padRight(9)} (${gName(pct(grades, 0.1))}·${gName(pct(grades, 0.9))})'
      '${''.padRight(8)}| ${lv.toString().padLeft(3)}    | '
      '${(((br + sr) / 2) / 10).round().toString().padLeft(3)}% | '
      '${(main * 100).toStringAsFixed(1).padLeft(5)}%     | '
      '${pct([for (final x in xs) x.eggs], 0.5).toString().padLeft(5)}  | '
      '${pct([for (final x in xs) x.dust], 0.5).toString().padLeft(7)}  | '
      '${pct([for (final x in xs) x.owned], 0.5)}',
    );
    curve.add([d, g50, lv, br, sr]);
  }

  if (write) {
    final acc = targets['accumulation'] as Map<String, dynamic>;
    acc['_fairyByDayComment'] =
        'core_save/tool/fairy_sim.dart 실측(무료 유저 · 정예 ${elitesPerDay.toStringAsFixed(0)}/일 · 접속 $checkins회/일 · $runs회 중앙값). '
        '[일, 동행 등급(0 일반~4 신화, -1 없음), 레벨, 기본 개체값, 부가 개체값]. balance_sim 이 이 곡선으로 요정을 얹는다.';
    acc['fairyByDay'] = [
      [0, -1, 0, 0, 0],
      ...curve,
    ];
    File(targetsPath).writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(targets)}\n',
    );
    stdout.writeln('→ $targetsPath 의 accumulation.fairyByDay 를 갱신했다.');
  }
}

/// 한 번 접속해서 하는 일(무료 유저 · 사람이 할 법한 순서).
FairyState _checkin(
  FairyState f,
  FairyConfig cfg,
  math.Random rng,
  DateTime now,
  String? desiredSub,
) {
  // 1) 다 깼으면 꺼낸다.
  final got = collectFairyNest(f, now: now);
  if (got.isOk) f = got.state!;
  // 2) 비었으면 가장 좋은 알을 넣는다(원하는 부가 속성석이 있으면 같이).
  if (f.nest == null && f.eggs.isNotEmpty) {
    final egg = ([
      ...f.eggs,
    ]..sort((a, b) => b.grade.index - a.grade.index)).first;
    final stone = desiredSub != null && (f.stones[desiredSub] ?? 0) > 0
        ? desiredSub
        : null;
    final op = placeFairyEgg(
      f,
      cfg,
      rng,
      eggId: egg.id,
      now: now,
      stoneSub: stone,
    );
    if (op.isOk) f = op.state!;
  }
  // 3) 가속기(무료로 얻은 것)를 다 쓴다. 다 깨면 한 번 더 꺼내고 넣는다.
  for (var guard = 0; guard < 50 && f.nest != null; guard++) {
    final have = [
      for (final a in cfg.accelerators)
        if ((f.accelerators[a.id] ?? 0) > 0) a.id,
    ];
    if (have.isEmpty) break;
    final u = useFairyAccelerator(f, cfg, accelId: have.first, now: now);
    if (!u.isOk) break;
    f = u.state!;
    final c = collectFairyNest(f, now: now);
    if (c.isOk) {
      f = c.state!;
      if (f.eggs.isNotEmpty) {
        final egg = ([
          ...f.eggs,
        ]..sort((a, b) => b.grade.index - a.grade.index)).first;
        final p = placeFairyEgg(f, cfg, rng, eggId: egg.id, now: now);
        if (p.isOk) f = p.state!;
      }
    }
  }
  // 4) 자동 합성.
  f = autoMergeFairies(f, cfg, rng).state!;
  // 5) 동행 = 가장 좋은 요정.
  if (f.fairies.isNotEmpty) {
    final best = ([...f.fairies]..sort(_better)).first;
    f = setFairyCompanion(f, best.id).state!;
  }
  // 6) 요정함이 차면(알이 넘치지 않게 5칸 여유) 낮은 요정부터 분해 — 동행은 빼고.
  while (f.boxUsed > cfg.boxCap - 5) {
    final cands = [
      for (final x in f.fairies)
        if (x.id != f.companionId) x,
    ]..sort((a, b) => _better(b, a));
    if (cands.isEmpty) break;
    f = releaseFairy(f, cfg, cands.first.id).state!;
  }
  // 7) 가루는 전부 동행 레벨업.
  final c = f.companion;
  if (c != null) {
    while (true) {
      final op = levelUpFairy(f, cfg, c.id);
      if (!op.isOk) break;
      f = op.state!;
    }
  }
  return f;
}

/// 정렬 — 좋은 것이 앞(등급 → 레벨 → 품질).
int _better(Fairy a, Fairy b) {
  final g = b.grade.index.compareTo(a.grade.index);
  if (g != 0) return g;
  final l = b.level.compareTo(a.level);
  if (l != 0) return l;
  return b.quality.compareTo(a.quality);
}
