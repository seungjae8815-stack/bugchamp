// 곤충 배틀 스타디움(결투) 밸런스 측정 — 손으로 맞추지 않는다(docs/design_duel.md §5).
//
// 실행:
//   cd packages\core_battle ; dart run tool/duel_sim.dart
//   dart run tool/duel_sim.dart --n=600          # 판 수(기본 400)
//   dart run tool/duel_sim.dart --set=gripForce=200 --set=strikeFlipBase=0.12   # 수치 쓸어보기
//
// 수치는 `packages/app/assets/data/battle.json → duel` 을 읽는다(없으면 코드 기본값).
//
// 목표(초안):
//  - 같은 전력이면 치기·집기·던지기 서로 승률 40~60%
//  - 전력 +20% ≈ 70%, +50% ≈ 90% (게이지로는 못 뒤집는다)
//  - 같은 종 사이즈 최대 vs 최소 ≈ 60%
//  - 결판(장외·뒤집기·기절·시간)이 한쪽으로 쏠리지 않게
import 'dart:convert';
import 'dart:io';

import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';

int _n = 400;

void main(List<String> args) {
  final overrides = <String, num>{};
  for (final a in args) {
    final m = RegExp(r'^--([a-z-]+)=(.+)$').firstMatch(a);
    if (m == null) continue;
    switch (m.group(1)) {
      case 'n':
        _n = int.parse(m.group(2)!);
      case 'set':
        final kv = m.group(2)!.split('=');
        overrides[kv[0]] = num.parse(kv[1]);
    }
  }
  final battle =
      jsonDecode(File('../app/assets/data/battle.json').readAsStringSync())
          as Map<String, dynamic>;
  final duelJson = Map<String, dynamic>.from(
    (battle['duel'] as Map<String, dynamic>?) ?? const {},
  )..addAll(overrides);
  final p = DuelParams.fromJson(duelJson);
  final speciesRaw = jsonDecode(
    File('../app/assets/data/species.json').readAsStringSync(),
  );
  final species = [
    for (final s
        in (speciesRaw is Map ? speciesRaw['species'] : speciesRaw) as List)
      Species.fromJson(s as Map<String, dynamic>),
  ];

  if (overrides.isNotEmpty) stdout.writeln('덮어쓴 수치: $overrides\n');

  DuelBug unit(
    Specialty spc, {
    double scale = 1,
    double size = 50,
    Temperament? tm,
    Element el = Element.wood,
    String id = 'x',
  }) => DuelBug(
    id: id,
    name: id,
    speciesId: id,
    element: el,
    temperament: tm ?? Temperament.steadfast,
    specialty: spc,
    sizeMm: size,
    maxHp: 150 * scale,
    atk: 60 * scale,
    def: 50 * scale,
    spd: 50 * scale,
  );

  // 승률 + 결판 분포. B 는 매 판 새 기질(시드로 돌림).
  ({double win, Map<DuelFinish, int> fin, double secs}) run(
    DuelBug Function(int i) mkA,
    DuelBug Function(int i) mkB, {
    double? la,
    double? lb,
  }) {
    var w = 0;
    var ticks = 0;
    final fin = {for (final f in DuelFinish.values) f: 0};
    for (var i = 0; i < _n; i++) {
      // 기질은 판 번호로 25조합을 고르게 — 한쪽에만 특정 기질이 몰리면 대칭 대전이 50% 가 안 나온다.
      final r = simulateBout(
        seed: 1000 + i * 7919,
        a: mkA(i).copyWith(temperament: Temperament.values[i % 5]),
        b: mkB(i).copyWith(temperament: Temperament.values[(i ~/ 5) % 5]),
        params: p,
        launchA: la,
        launchB: lb,
      );
      if (r.winner == 0) w++;
      fin[r.finish] = fin[r.finish]! + 1;
      ticks += r.ticks;
    }
    return (win: w / _n, fin: fin, secs: ticks / _n / p.tickHz);
  }

  String pct(double v) => '${(v * 100).toStringAsFixed(0).padLeft(3)}%';
  String finStr(Map<DuelFinish, int> f) => [
    for (final e in f.entries)
      '${_finKo[e.key]} ${(e.value * 100 / _n).toStringAsFixed(0)}%',
  ].join(' · ');

  // ── 1. 주특기 상성(같은 스탯) ─────────────────────────────────
  stdout.writeln('── 1. 주특기 상성 (같은 스탯 · 행이 A 의 승률, 목표 40~60%) ──');
  stdout.writeln('          치기   집기   던지기');
  for (final a in Specialty.values) {
    final row = StringBuffer('  ${_spcKo[a]!.padRight(4)}  ');
    for (final b in Specialty.values) {
      final r = run((_) => unit(a), (_) => unit(b));
      row.write(' ${pct(r.win)}  ');
    }
    stdout.writeln(row);
  }

  // ── 2. 결판 분포 ──────────────────────────────────────────────
  stdout.writeln('\n── 2. 결판 분포 (주특기 조합별, 같은 스탯 · 목표 평균 8~12초 · 기절 30~40%) ──');
  final allFin = {for (final f in DuelFinish.values) f: 0};
  var allSecs = 0.0, combos = 0;
  for (final a in Specialty.values) {
    for (final b in Specialty.values) {
      if (b.index < a.index) continue;
      final r = run((_) => unit(a), (_) => unit(b));
      for (final e in r.fin.entries) {
        allFin[e.key] = allFin[e.key]! + e.value;
      }
      allSecs += r.secs;
      combos++;
      stdout.writeln(
        '  ${_spcKo[a]} 대 ${_spcKo[b]}: ${finStr(r.fin)} · 평균 ${r.secs.toStringAsFixed(1)}초',
      );
    }
  }

  stdout.writeln(
    '  ── 전체: ${[for (final e in allFin.entries) '${_finKo[e.key]} ${(e.value * 100 / (_n * combos)).toStringAsFixed(0)}%'].join(' · ')} · 평균 ${(allSecs / combos).toStringAsFixed(1)}초',
  );

  // ── 3. 전력 차이 ───────────────────────────────────────────────
  stdout.writeln(
    '\n── 3. 전력 차이 (A 가 모든 스탯 ×배율, 주특기 섞음 · 목표 +20%≈70%, +50%≈90%) ──',
  );
  for (final k in [1.1, 1.2, 1.35, 1.5, 2.0]) {
    final r = run(
      (i) => unit(Specialty.values[i % 3], scale: k),
      (i) => unit(Specialty.values[(i ~/ 3) % 3]),
    );
    stdout.writeln('  ×$k : ${pct(r.win)}');
  }

  // ── 4. 사이즈 ──────────────────────────────────────────────────
  stdout.writeln('\n── 4. 같은 종 사이즈 최대 vs 최소 (스탯 배율 포함 · 목표 ≈60%) ──');
  for (final sp in species) {
    DuelBug of(double size, String id) {
      final sm = sizeToStatMultiplier(size, sp.sizeMinMm, sp.sizeMaxMm);
      final st = sp.baseStats;
      return DuelBug(
        id: id,
        name: id,
        speciesId: sp.id,
        element: Element.wood,
        temperament: Temperament.steadfast,
        specialty: sp.specialty,
        sizeMm: size,
        maxHp: st.hp * sm,
        atk: st.atk * sm,
        def: st.def * sm,
        spd: st.spd * sm,
      );
    }

    final r = run(
      (_) => of(sp.sizeMaxMm, 'big'),
      (_) => of(sp.sizeMinMm, 'small'),
    );
    stdout.writeln('  ${sp.id.padRight(24)} ${pct(r.win)}');
  }

  // ── 5. 종 순위(강화 0 · 중간 사이즈 · 리그전) ─────────────────
  stdout.writeln('\n── 5. 종 리그전 승률 (강화 0 · 중간 사이즈 — 등급 순서가 대체로 지켜지나) ──');
  DuelBug mid(Species sp) {
    final size = (sp.sizeMinMm + sp.sizeMaxMm) / 2;
    final sm = sizeToStatMultiplier(size, sp.sizeMinMm, sp.sizeMaxMm);
    final st = sp.baseStats;
    return DuelBug(
      id: sp.id,
      name: sp.id,
      speciesId: sp.id,
      element: Element.wood,
      temperament: Temperament.steadfast,
      specialty: sp.specialty,
      sizeMm: size,
      maxHp: st.hp * sm,
      atk: st.atk * sm,
      def: st.def * sm,
      spd: st.spd * sm,
    );
  }

  final saveN = _n;
  _n = (saveN / 4).ceil();
  final table = <(Species, double)>[];
  for (final a in species) {
    var sum = 0.0;
    for (final b in species) {
      if (identical(a, b)) continue;
      sum += run((_) => mid(a), (_) => mid(b)).win;
    }
    table.add((a, sum / (species.length - 1)));
  }
  _n = saveN;
  table.sort((x, y) => y.$2.compareTo(x.$2));
  for (final (sp, w) in table) {
    stdout.writeln(
      '  ${pct(w)}  ${sp.grade.key.padRight(10)} ${_spcKo[sp.specialty]!.padRight(4)} ${sp.id}',
    );
  }

  // ── 6. 게이지 ─────────────────────────────────────────────────
  stdout.writeln('\n── 6. 던지기 게이지 (같은 스탯 · 만점 대 0점 — 결과를 뒤집지 않아야) ──');
  final g = run(
    (i) => unit(Specialty.values[i % 3]),
    (i) => unit(Specialty.values[(i ~/ 3) % 3]),
    la: 1,
    lb: 0,
  );
  stdout.writeln('  만점 쪽 승률 ${pct(g.win)}');
  final g2 = run(
    (i) => unit(Specialty.values[i % 3]),
    (i) => unit(Specialty.values[(i ~/ 3) % 3], scale: 1.2),
    la: 1,
    lb: 0,
  );
  stdout.writeln('  만점이지만 전력 -20% 쪽 승률 ${pct(g2.win)} (50% 미만이어야)');

  // ── 7. 오행 상극 ───────────────────────────────────────────────
  final el = run(
    (i) => unit(Specialty.values[i % 3], el: Element.water),
    (i) => unit(Specialty.values[(i ~/ 3) % 3], el: Element.fire),
  );
  stdout.writeln('\n── 7. 오행 상극 (수 → 화, 같은 스탯) ── 상극 쪽 승률 ${pct(el.win)}');
}

const _spcKo = {
  Specialty.strike: '치기',
  Specialty.grip: '집기',
  Specialty.toss: '던지기',
};
const _finKo = {
  DuelFinish.ringOut: '장외',
  DuelFinish.flip: '뒤집기',
  DuelFinish.knockout: '기절',
  DuelFinish.timeUp: '시간',
};
