// 왕충 선발대회(곤충 1마리 · 결투 엔진 웨이브전) 밸런스 측정 — 손으로 맞추지 않는다.
//
// 실행:
//   cd packages\core_battle ; dart run tool/event_duel_sim.dart
//   dart run tool/event_duel_sim.dart --set=growth=1.1 --set=baseAtk=40   # event.json → duelWave 덮어쓰기
//   dart run tool/event_duel_sim.dart --focus=heft            # 그 카드가 나오면 늘 고른다(몰빵 전략)
//   dart run tool/event_duel_sim.dart --focus=heft --nocap    # 카드 누적 상한·확률 상한을 끈 채로(비교용)
//   dart run tool/event_duel_sim.dart --set=statCompress=0.3  # 대회 전용 압축 바꿔 보기(없으면 결투 값)
//   dart run tool/event_duel_sim.dart --nosize                # 사이즈 몫 덜어내기 끄기(예전 경로 비교용)
//
// 곤충 = 종 기본 능력치 × 사이즈 배율 × "키운 정도"(강화·수련·훈련을 한 배율로 뭉친 값).
// 현실적 최고치는 약 ×3.5(부위 강화 만렙 +200~250% · 수련 +40% · 훈련 +25%)라 ×1 ~ ×4 를 본다.
// 카드는 대충 좋은 쪽(공격 큰 것 > 체력 낮으면 회복 > 부활 > 공격 작은 것 …)을 고른다고 가정.
//
// 목표(초안): 갓 잡은 일반 ≈ 2~5웨이브 · 키운 전설 ≈ 30~45 · 아무도 상한(maxWave)에 안 닿는다 ·
// 같은 곤충이라도 판마다 ±몇 웨이브 흔들린다(게이지·카드·운).
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';

void main(List<String> args) {
  final over = <String, num>{};
  var n = 40;
  var gauge = 0.8;
  String? focus;
  var noCap = false;
  var noSize = false;
  for (final a in args) {
    if (a == '--nocap') noCap = true;
    if (a == '--nosize') noSize = true;
    final m = RegExp(r'^--([a-z-]+)=(.+)$').firstMatch(a);
    if (m == null) continue;
    switch (m.group(1)) {
      case 'n':
        n = int.parse(m.group(2)!);
      case 'gauge':
        gauge = double.parse(m.group(2)!);
      case 'focus':
        focus = m.group(2);
      case 'set':
        final kv = m.group(2)!.split('=');
        over[kv[0]] = num.parse(kv[1]);
    }
  }
  Map<String, dynamic> read(String f) =>
      jsonDecode(File('../app/assets/data/$f').readAsStringSync())
          as Map<String, dynamic>;
  final ev = read('event.json');
  final spec = EventDuelSpec.fromJson({
    ...?(ev['duelWave'] as Map<String, dynamic>?),
    ...over,
    if (noCap) 'cardCaps': <String, num>{},
  });
  // 서버·앱과 같은 함수 — 대회 전용 압축(duelWave.statCompress)이 결투 값을 덮어쓴다.
  final p = eventDuelParamsOf({
    ...?(read('battle.json')['duel'] as Map<String, dynamic>?),
    if (noCap) 'evadeMax': 99,
    if (noCap) 'critMax': 99,
  }, spec);
  stdout.writeln(
    '전력 압축 ${p.statCompress} · 사이즈 스탯 지수 ${p.sizeStatExp}${noSize ? ' (덜어내기 끔)' : ''}',
  );
  final cards = [
    for (final c in ((ev['cards'] as Map)['list'] as List))
      (
        id: '${c['id']}',
        kind: '${c['kind']}',
        value: (c['value'] as num).toDouble(),
        weight: (c['weight'] as num).toInt(),
      ),
  ];
  final speciesRaw = read('species.json');
  final species = [
    for (final s in speciesRaw['species'] as List)
      Species.fromJson(s as Map<String, dynamic>),
  ];
  final ids = [for (final s in species) s.id]..sort();
  final byId = {for (final s in species) s.id: s};
  if (over.isNotEmpty) stdout.writeln('덮어쓴 수치: $over\n');
  if (focus != null) stdout.writeln('몰빵 카드: $focus${noCap ? ' · 상한 끔' : ''}');
  stdout.writeln(
    '적 1웨이브 hp ${spec.baseHp} atk ${spec.baseAtk} def ${spec.baseDef} spd ${spec.baseSpd} · 성장 ×${spec.growth}/웨이브 · 회복 ${spec.healPct} · 게이지 $gauge\n',
  );

  final pref = [
    ?focus,
    'atk_l',
    'berserk',
    'revive',
    'atk_s',
    'last_stand',
    'vital',
    'agile',
    'hp_s',
    'breath',
    'ironhide',
    'def_s',
    'heft',
    'heal_l',
    'heal_s',
    'skip',
  ];
  List<({String id, String kind, double value, int weight})> draw(
    int seed,
    int wave,
  ) {
    final rng = math.Random(seed * 7717 + wave * 131);
    final pool = [...cards];
    final out = <({String id, String kind, double value, int weight})>[];
    while (out.length < 3 && pool.isNotEmpty) {
      final total = pool.fold<int>(0, (s, c) => s + c.weight);
      var r = rng.nextInt(total);
      for (final c in pool) {
        r -= c.weight;
        if (r < 0) {
          out.add(c);
          pool.remove(c);
          break;
        }
      }
    }
    return out;
  }

  int play(DuelBug me, int roundSeed, int seed) {
    var run = const EventDuelRun();
    while (!run.over) {
      final sp = byId[eventWaveSpeciesId(roundSeed, run.wave, 0, ids)]!;
      final step = eventDuelFight(
        seed: seed,
        run: run,
        bug: me,
        enemy: eventDuelEnemy(
          roundSeed: roundSeed,
          wave: run.wave,
          spec: spec,
          speciesId: sp.id,
          specialty: sp.specialty,
        ),
        params: p,
        spec: spec,
        launch: gauge,
      );
      run = step.run;
      if (step.won && !run.over) {
        final offer = draw(roundSeed, run.cleared);
        final low = run.hpPct < 0.45;
        final pick =
            low &&
                offer.any((c) => c.kind == 'heal') &&
                !offer.any((c) => c.id == focus)
            ? offer.firstWhere((c) => c.kind == 'heal')
            : (offer..sort(
                    (a, b) => pref.indexOf(a.id).compareTo(pref.indexOf(b.id)),
                  ))
                  .first;
        run = run.applyCard(pick.kind, pick.value, spec);
      }
    }
    return run.cleared;
  }

  DuelBug bugOf(Species sp, double scale) {
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
      maxHp: st.hp * sm * scale,
      atk: st.atk * sm * scale,
      def: st.def * sm * scale,
      spd: st.spd * sm * math.sqrt(scale),
      // 서버 validateDuelTeam 과 같이 — 스탯에 구워진 사이즈 배율을 엔진이 덜어낸다.
      sizeStatMult: noSize ? 1 : sm,
    );
  }

  const scales = [1.0, 1.5, 2.0, 3.0, 4.0];
  stdout.writeln('도달 웨이브 평균(최소~최대) — 행 = 종, 열 = 키운 정도');
  stdout.writeln(
    '${''.padRight(26)}${[for (final s in scales) '×$s'.padLeft(14)].join()}',
  );
  var hitCap = 0;
  for (final g in Grade.values) {
    for (final sp in species.where((s) => s.grade == g).take(2)) {
      final row = StringBuffer('${g.key} ${sp.id}'.padRight(26));
      for (final k in scales) {
        final me = bugOf(sp, k);
        final got = [
          for (var i = 0; i < n; i++) play(me, 20261005 + i % 4, 1000 + i * 37),
        ];
        hitCap += got.where((w) => w >= spec.maxWave).length;
        final avg = got.reduce((a, b) => a + b) / got.length;
        final lo = got.reduce(math.min), hi = got.reduce(math.max);
        row.write('${avg.toStringAsFixed(1)}($lo~$hi)'.padLeft(14));
      }
      stdout.writeln(row);
    }
  }
  stdout.writeln('\n상한(${spec.maxWave}) 도달 판 수: $hitCap');
}
