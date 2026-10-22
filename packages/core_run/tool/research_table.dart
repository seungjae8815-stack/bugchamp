// 연구소 비용·시간 표 — "터무니없는 값이 나오지 않게"(사장님 핵심 요구, 설계 §3.6).
//
// 입력: balance_sim 이 뽑은 **하루 3시간 켜 둔 무과금 유저**의 날짜별 활동 수입.
//   cd packages\core_run
//   dart run tool/balance_sim.dart --tiers=4 --no-fairy --active-hours=3 --income --endgame-days=150 > %TEMP%\income3h.txt
//   dart run tool/research_table.dart --income=%TEMP%\income3h.txt          # 지금 research.json 을 잰다
//   dart run tool/research_table.dart --income=%TEMP%\income3h.txt --fit    # 곡선을 다시 맞춰 JSON 조각을 찍는다
//   dart run tool/research_table.dart --income=%TEMP%\income3h.txt --fit --write   # research.json 에 반영
//
// 맞추는 목표(사장님 확정 · 컨트롤러 판정):
//  - 시간: 무과금 칸 곡선(1칸 → 어려움 도착일부터 2칸 → 극한 도착일부터 3칸)을 **쉬지 않고** 돌릴 때
//    14개 × 전 레벨이 [_targetDays](180)일에 끝난다. Lv1 = [_firstSeconds](5분) · Lv10 = [_kneeSeconds](12시간).
//  - 골드·재료: 비용은 이미 "가 본 최고 사냥터의 사냥 N분치"라 분 단위로 맞춘다 — 180일 동안 하루 평균
//    180분(3시간) × 50% = 90분치. 실제 활동 수입(버프·접속 보너스 포함) 대비 비율은 따로 보고만 한다.
//  - 연구 표본: 하루 3시간 정예·보스 드롭. 시간이 병목이 되게 합계 비용 = 180일 수입의 [_sampleShare](90%).
//    Lv1 = 표본 1개로 두고 정예 드롭 확률을 맞춘다.
//  - 화석: 마지막 [_fossilLevels] 레벨에만. 합계 = 180일 활동 화석의 [_fossilShare](20%, 상한 30%).
//
// ⚠️ 근사: 칸은 쉬지 않는다(무과금이 제때 다음 레벨을 건다) · 연구 순서 = 다음 레벨이 가장 짧은 것부터 ·
//   연구 효율(연구 시간 −%)은 **시작할 때** 그때까지 찍은 레벨로 적용(앱 `researchPrice` 와 같다) ·
//   보스 표본은 시뮬이 처음 잡는 사냥터 보스만(재처치·심연 층 보스는 0 — 보수적).
//   시뮬은 지금 자리 = 가 본 최고 자리(쓰러짐 벌칙 없음)라 "N분치"를 그날 자리의 사냥 60분치로 환산한다.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:core_run/core_run.dart';

// ── 설계 값(맞추지 않고 정하는 것) ─────────────────────────────────────
const _targetDays = 180.0;
const _maxLevel = 30;
const _firstSeconds = 300.0;
const _kneeLevel = 10;
const _kneeSeconds = 12 * 3600.0;
const _goldMinutesPerDay = 90.0; // 180분 × 50%
const _sampleShare = 0.9;
const _fossilShare = 0.2;
const _fossilLevels = 10;

/// 결투 공격·방어·체력 3종은 Task 6(80% 맞추기)이 효과를 정한다 — 여기선 건드리지 않는다.
const _duelOwned = {'duelAtk', 'duelDef', 'duelHp'};

/// 다 찍었을 때 효과(사냥·육성 분야, 시간 단축 포함). 선형(growth 1) — perLevel = 최대 ÷ maxLevel.
const _effectMax = <String, double>{
  'huntAtk': 0.40,
  'huntHpDef': 0.40,
  'find': 0.30,
  'gold': 0.30,
  'bossDmg': 0.40,
  'offline': 0.30,
  'hatchTime': 0.40,
  'breedTime': 0.40,
  'trainTime': 0.40,
  'researchTime': 0.30,
  'injuryTime': 0.40,
};

/// 하루 활동 수입 한 줄(balance_sim `@research-income`).
class IncomeDay {
  IncomeDay.fromJson(Map<String, dynamic> j)
    : day = (j['day'] as num).toDouble(),
      tier = (j['tier'] as num).toInt(),
      onlineGold = (j['onlineGold'] as num).toDouble(),
      onlineMats = (j['onlineMats'] as num).toDouble(),
      hourGold = (j['hourGold'] as num).toDouble(),
      hourMats = (j['hourMats'] as num).toDouble(),
      elites = (j['elites'] as num).toDouble(),
      bossKills = (j['bossKills'] as num).toDouble(),
      fossil = (j['fossil'] as num).toDouble(),
      activeHours = (j['activeHours'] as num).toDouble();

  final double day;
  final int tier;
  final double onlineGold, onlineMats, hourGold, hourMats;
  final double elites, bossKills, fossil, activeHours;
}

List<IncomeDay> parseIncome(String text) => [
  for (final line in const LineSplitter().convert(text))
    if (line.startsWith('@research-income '))
      IncomeDay.fromJson(
        jsonDecode(line.substring('@research-income '.length))
            as Map<String, dynamic>,
      ),
];

/// 일정 계산의 바탕 — research.json `fitBasis` 에 함께 적어 회귀 테스트가 같은 값으로 다시 잰다.
class FitBasis {
  FitBasis({
    required this.activeHours,
    required this.hardDay,
    required this.extremeDay,
    required this.elitesPerDay,
    required this.bossKillsPerDay,
  });

  factory FitBasis.fromIncome(List<IncomeDay> inc) {
    double firstDay(int tier) {
      for (final r in inc) {
        if (r.tier >= tier) return r.day;
      }
      return double.infinity;
    }

    // 10일 묶음 평균(테스트용 바탕을 짧게).
    List<double> per10(double Function(IncomeDay) f) {
      final out = <double>[];
      for (var b = 0; b * 10 < _targetDays; b++) {
        final rows = [
          for (final r in inc)
            if (r.day >= b * 10 && r.day < b * 10 + 10) r,
        ];
        out.add(
          rows.isEmpty
              ? (out.isEmpty ? 0 : out.last)
              : rows.map(f).reduce((a, b) => a + b) / rows.length,
        );
      }
      return out;
    }

    return FitBasis(
      activeHours: inc.first.activeHours,
      hardDay: _r1(firstDay(2)),
      extremeDay: _r1(firstDay(3)),
      elitesPerDay: [for (final v in per10((r) => r.elites)) _r1(v)],
      bossKillsPerDay: [for (final v in per10((r) => r.bossKills)) _r2(v)],
    );
  }

  factory FitBasis.fromJson(Map<String, dynamic> j) => FitBasis(
    activeHours: (j['activeHours'] as num).toDouble(),
    hardDay: (j['hardDay'] as num).toDouble(),
    extremeDay: (j['extremeDay'] as num).toDouble(),
    elitesPerDay: [for (final v in j['elitesPerDay'] as List) (v as num) * 1.0],
    bossKillsPerDay: [
      for (final v in j['bossKillsPerDay'] as List) (v as num) * 1.0,
    ],
  );

  final double activeHours;
  final double hardDay;
  final double extremeDay;
  final List<double> elitesPerDay;
  final List<double> bossKillsPerDay;

  Map<String, dynamic> toJson() => {
    '_comment':
        '연구 곡선을 맞춘 바탕(tool/research_table.dart --fit 이 적는다) — balance_sim --active-hours=3 의 어려움·극한 도착일과 10일 묶음 하루 정예·보스 처치 수. 회귀 테스트(research_curve_test)가 이 값으로 완료일을 다시 잰다.',
    'activeHours': activeHours,
    'hardDay': hardDay,
    'extremeDay': extremeDay,
    'elitesPerDay': elitesPerDay,
    'bossKillsPerDay': bossKillsPerDay,
  };

  T _at<T>(List<T> l, double day) =>
      l[(day / 10).floor().clamp(0, l.length - 1)];

  int topTierAt(double day) => day >= extremeDay
      ? 3
      : day >= hardDay
      ? 2
      : 0;

  int slotsAt(ResearchConfig c, double day) => c.slotsFor(topTierAt(day), 0);

  double samplesPerDay(ResearchConfig c, double day) =>
      _at(elitesPerDay, day) * c.eliteDropChance * c.eliteDropAmount +
      _at(bossKillsPerDay, day) * c.bossFirstDrop;
}

double _r1(double v) => (v * 10).roundToDouble() / 10;
double _r2(double v) => (v * 100).roundToDouble() / 100;

/// 한 레벨을 시작한 기록.
class LevelStart {
  LevelStart(this.id, this.level, this.day, this.seconds);
  final String id;
  final int level;
  final double day;
  final double seconds;
}

class ScheduleResult {
  double completionDay = double.infinity;
  double slotDays = 0;
  double idleSlotDays = 0;
  double sampleWaitSlotDays = 0;
  double samplesSpent = 0;
  double samplesEarned = 0;
  final starts = <LevelStart>[];

  /// 정수 날짜별 시작 때 낸 골드 분 · 재료 분 · 화석 · 표본.
  final goldMin = <int, double>{};
  final matMin = <int, double>{};
  final fossil = <int, double>{};
  final samples = <int, double>{};
}

/// 무과금이 칸을 쉬지 않고 돌릴 때의 일정. [ignoreSamples] 면 표본을 무한으로 본다(시간 맞추기용).
ScheduleResult scheduleResearch(
  ResearchConfig c,
  FitBasis basis, {
  bool ignoreSamples = false,
  double horizonDays = 1000,
}) {
  final r = ScheduleResult();
  final levels = {for (final d in c.defs) d.id: 0};
  final running = <({String id, double end})>[];
  var bank = 0.0;
  var t = 0.0;
  const waitStep = 1 / 96; // 15분

  bool done() =>
      running.isEmpty && c.defs.every((d) => levels[d.id]! >= d.maxLevel);

  while (!done() && t < horizonDays) {
    // 끝난 연구를 거둔다.
    running.removeWhere((e) {
      if (e.end <= t + 1e-9) {
        levels[e.id] = levels[e.id]! + 1;
        return true;
      }
      return false;
    });
    if (done()) break;
    // 빈 칸에 다음 레벨이 가장 짧은 것부터 건다.
    final slots = basis.slotsAt(c, t);
    final cut = researchEffects(c, levels).of(ResearchEffect.researchTime);
    final cands =
        [
          for (final d in c.defs)
            if (levels[d.id]! < d.maxLevel &&
                !running.any((e) => e.id == d.id) &&
                (d.requires == null ||
                    levels[d.requires!.id]! >= d.requires!.level))
              d,
        ]..sort(
          (a, b) => c
              .timeAt(a, levels[a.id]! + 1)
              .compareTo(c.timeAt(b, levels[b.id]! + 1)),
        );
    var blockedBySamples = 0;
    for (final d in cands) {
      if (running.length >= slots) break;
      final lv = levels[d.id]! + 1;
      final cost = c.costAt(d, lv);
      if (!ignoreSamples && bank + 1e-9 < cost.samples) {
        blockedBySamples++;
        continue;
      }
      if (!ignoreSamples) bank -= cost.samples;
      final sec = math.max(
        1.0,
        c.timeAt(d, lv).inMilliseconds * (1 - cut) / 1000,
      );
      running.add((id: d.id, end: t + sec / 86400));
      r.starts.add(LevelStart(d.id, lv, t, sec));
      final day = t.floor();
      r.goldMin[day] = (r.goldMin[day] ?? 0) + cost.goldMinutes;
      r.matMin[day] = (r.matMin[day] ?? 0) + cost.materialMinutes;
      r.fossil[day] = (r.fossil[day] ?? 0) + cost.fossil;
      r.samples[day] = (r.samples[day] ?? 0) + cost.samples;
      r.samplesSpent += cost.samples;
    }
    // 다음 사건: 가장 빨리 끝나는 연구 · 칸이 늘어나는 날 · (표본을 기다리면) 15분 뒤.
    var next = running.isEmpty
        ? double.infinity
        : running.map((e) => e.end).reduce(math.min);
    for (final edge in [basis.hardDay, basis.extremeDay]) {
      if (edge > t + 1e-9) next = math.min(next, edge);
    }
    final free = math.max(0, slots - running.length);
    final waiting = math.min(free, blockedBySamples);
    if (waiting > 0) next = math.min(next, t + waitStep);
    if (next == double.infinity) next = t + waitStep;
    final dt = next - t;
    r.slotDays += slots * dt;
    r.sampleWaitSlotDays += waiting * dt;
    r.idleSlotDays += (free - waiting) * dt;
    final earn = basis.samplesPerDay(c, t) * dt;
    bank += earn;
    r.samplesEarned += earn;
    t = next;
  }
  r.completionDay = done() ? t : double.infinity;
  return r;
}

// ── 곡선 맞추기 ───────────────────────────────────────────────────────

/// 시간 증가율 [g]·감쇠 [d] 일 때 Lv [level] 의 초.
double _secondsAt(double g, double d, int level) {
  var m = _firstSeconds;
  for (var i = 1; i < level; i++) {
    m *= 1 + (g - 1) * math.pow(d, i - 1);
  }
  return m;
}

/// 감쇠 [d] 에서 Lv[_kneeLevel] = [_kneeSeconds] 가 되는 증가율.
double _growthForKnee(double d) {
  var lo = 1.0001, hi = 20.0;
  for (var i = 0; i < 80; i++) {
    final mid = (lo + hi) / 2;
    if (_secondsAt(mid, d, _kneeLevel) < _kneeSeconds) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return (lo + hi) / 2;
}

double _round(double v, int digits) {
  final p = math.pow(10, digits);
  return (v * p).roundToDouble() / p;
}

/// research.json 원본에 곡선을 덮어쓴 새 JSON.
Map<String, dynamic> _withCurves(
  Map<String, dynamic> raw, {
  required double tg,
  required double td,
  required double cg,
  required double cd,
  required double goldFirst,
  required double fossilFirst,
  double? eliteChance,
}) {
  final out = jsonDecode(jsonEncode(raw)) as Map<String, dynamic>;
  out['_comment'] =
      '연구소(설계 docs/superpowers/specs/2026-10-22-research-lab-design.md). 시간·비용 곡선 · eliteDropChance · bossFirstDrop · 사냥·육성 effect · fitBasis 는 '
      'tool/research_table.dart --fit --write 가 뽑는다 — 손으로 한 칸씩 고치지 않는다(하루 3시간 켜 둔 무과금 · 골드·재료 = 3시간 사냥분치의 50% · 약 180일). '
      '시간·비용: Lv1 = first, 한 단계 오를 때마다 × (1 + (growth−1)·decay^(i−1)). kind = ResearchEffect 키. 결투 공격·방어·체력 effect 는 결투 80% 맞추기가 정한다.';
  if (eliteChance != null) out['eliteDropChance'] = eliteChance;
  for (final e in out['research'] as List) {
    final m = e as Map<String, dynamic>;
    m['maxLevel'] = _maxLevel;
    final kind = m['kind'] as String;
    if (!_duelOwned.contains(kind)) {
      m['effect'] = {
        'perLevel': _round(_effectMax[kind]! / _maxLevel, 6),
        'growth': 1.0,
      };
    }
    m['time'] = {'firstSeconds': _firstSeconds, 'growth': tg, 'decay': td};
    m['cost'] = {
      'samplesFirst': 1,
      'goldMinutesFirst': goldFirst,
      'materialMinutesFirst': goldFirst,
      'fossilFrom': _maxLevel - _fossilLevels + 1,
      'fossilFirst': fossilFirst,
      'growth': cg,
      'decay': cd,
    };
  }
  return out;
}

ResearchConfig _cfg(Map<String, dynamic> raw) => ResearchConfig.fromJson(raw);

/// 10일 묶음마다 하루 골드 분(연구가 쓴) — 고르게 쓰는지 본다.
List<double> _blocks(ScheduleResult s, Map<int, double> m) => [
  for (var b = 0; b * 10 < _targetDays; b++)
    [
          for (var d = b * 10; d < b * 10 + 10; d++) m[d] ?? 0,
        ].reduce((a, b) => a + b) /
        10,
];

Map<String, dynamic> _fit(
  Map<String, dynamic> raw,
  List<IncomeDay> inc,
  FitBasis basis,
) {
  var elites = 0.0, bosses = 0.0;
  final fossilIncome = inc
      .where((r) => r.day < _targetDays)
      .fold<double>(0, (a, r) => a + r.fossil);
  for (final r in inc.where((r) => r.day < _targetDays)) {
    elites += r.elites;
    bosses += r.bossKills;
  }
  final amount = _cfg(raw).eliteDropAmount;

  // 감쇠 td · 비용 모양 α · 보스 첫 처치 표본 drop 이 정해지면 나머지는 모두 따라 나온다:
  //   시간 증가율 = Lv10 이 12시간이 되는 값 · 비용 증가율 = 1 + α(시간 증가율 − 1)(같은 감쇠)
  //   골드 Lv1 = 180일 합계가 하루 90분 · 화석 첫 값 = 180일 활동 화석의 20% · 정예 확률 = 표본 합계 ÷ 90%.
  Map<String, dynamic> build(double td, double alpha, int drop) {
    final tg = _round(_growthForKnee(td), 4);
    final cg = _round(1 + alpha * (tg - 1), 4);
    final unit = _cfg(
      _withCurves(
        raw,
        tg: tg,
        td: td,
        cg: cg,
        cd: td,
        goldFirst: 1,
        fossilFirst: 1,
      ),
    );
    var goldSum = 0.0, fossilShape = 0.0, sampleSum = 0.0;
    for (final d in unit.defs) {
      for (var l = 1; l <= d.maxLevel; l++) {
        final k = unit.costAt(d, l);
        goldSum += k.goldMinutes;
        sampleSum += k.samples;
        if (l >= d.fossilFrom) {
          // 반올림 전 화석 모양(fossilFrom 레벨 = 1).
          fossilShape +=
              k.goldMinutes / unit.costAt(d, d.fossilFrom).goldMinutes;
        }
      }
    }
    final chance = _round(
      (sampleSum / _sampleShare - bosses * drop) / (elites * amount),
      4,
    );
    return _withCurves(
      raw,
      tg: tg,
      td: td,
      cg: cg,
      cd: td,
      goldFirst: _round(_goldMinutesPerDay * _targetDays / goldSum, 4),
      fossilFirst: _round(fossilIncome * _fossilShare / fossilShape, 1),
      eliteChance: chance,
    )..['bossFirstDrop'] = drop;
  }

  ScheduleResult run(Map<String, dynamic> j, {bool ignoreSamples = false}) =>
      scheduleResearch(_cfg(j), basis, ignoreSamples: ignoreSamples);

  /// 완료일이 [_targetDays] 가 되는 감쇠(클수록 후반이 길어 늦게 끝난다).
  double fitDecay(double alpha, int drop, {required bool ignoreSamples}) {
    var lo = 0.5, hi = 0.999;
    for (var i = 0; i < 30; i++) {
      final mid = (lo + hi) / 2;
      final done = run(
        build(mid, alpha, drop),
        ignoreSamples: ignoreSamples,
      ).completionDay;
      if (done < _targetDays) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return _round((lo + hi) / 2, 4);
  }

  // 1) 시간 — 표본을 무한으로 두고 감쇠를 먼저 잡는다.
  var drop = _cfg(raw).bossFirstDrop;
  final td0 = fitDecay(0.6, drop, ignoreSamples: true);

  // 2) 비용 모양 α — 10일 묶음 하루 골드 지출이 가장 고르게(변동계수 최소).
  var best = (alpha: 1.0, cv: double.infinity);
  for (var a = 0.40; a <= 1.0001; a += 0.02) {
    final s = run(build(td0, a, drop), ignoreSamples: true);
    final b = _blocks(s, s.goldMin);
    final mean = b.reduce((x, y) => x + y) / b.length;
    final sd = math.sqrt(
      b.map((x) => (x - mean) * (x - mean)).reduce((x, y) => x + y) / b.length,
    );
    if (sd / mean < best.cv) best = (alpha: _round(a, 2), cv: sd / mean);
  }

  // 3) 표본 — 정예 드롭은 사냥이 빨라지는 후반에 늘어 초반이 모자란다. 초반에 몰린 보스 첫 처치
  //    몫을 키워 메운다: 표본을 기다리며 노는 칸이 1% 미만이 되는 가장 작은 값.
  for (final d in const [5, 10, 15, 20, 25, 30, 40, 50]) {
    drop = d;
    final s = run(build(td0, best.alpha, d));
    if (s.sampleWaitSlotDays / s.slotDays < 0.01) break;
  }

  // 4) 표본까지 넣고 감쇠를 다시 잡는다.
  final td = fitDecay(best.alpha, drop, ignoreSamples: false);
  final out = build(td, best.alpha, drop);
  final first = (out['research'] as List).first as Map<String, dynamic>;
  stdout.writeln(
    '  시간: Lv1 ${_firstSeconds ~/ 60}분 · Lv$_kneeLevel ${_kneeSeconds ~/ 3600}시간 · 증가율 ${first['time']['growth']} · 감쇠 $td (표본 무한 $td0)',
  );
  stdout.writeln(
    '  골드·재료: 증가율 ${first['cost']['growth']}(α ${best.alpha}, 10일 묶음 변동 ${(best.cv * 100).toStringAsFixed(0)}%) · Lv1 ${first['cost']['goldMinutesFirst']}분',
  );
  stdout.writeln(
    '  표본: 정예 드롭 확률 ${out['eliteDropChance']} · 보스 첫 처치 $drop (180일 정예 ${elites.toStringAsFixed(0)} · 보스 ${bosses.toStringAsFixed(0)})',
  );
  return out..['fitBasis'] = basis.toJson();
}

// ── 보고 ──────────────────────────────────────────────────────────────

String _dur(double sec) {
  if (sec < 3600) return '${(sec / 60).toStringAsFixed(0)}분';
  if (sec < 86400) return '${(sec / 3600).toStringAsFixed(1)}시간';
  return '${(sec / 86400).toStringAsFixed(2)}일';
}

void _report(ResearchConfig c, List<IncomeDay> inc, FitBasis basis) {
  stdout.writeln('── 연구별 레벨 표(시간은 연구 효율 0% 기준) ──');
  var topJelly = 0, jellyAll = 0;
  var maxGold = 0.0;
  for (final d in c.defs) {
    stdout.writeln(
      '  ${d.id} (${d.effect.key}, Lv1 ${(c.effectAt(d, 1) * 100).toStringAsFixed(2)}% → Lv${d.maxLevel} ${(c.effectAt(d, d.maxLevel) * 100).toStringAsFixed(1)}%)',
    );
    stdout.writeln('    Lv |     시간 | 골드 분 | 재료 분 | 표본 |  화석 | 젤리');
    for (var l = 1; l <= d.maxLevel; l++) {
      final k = c.costAt(d, l);
      final t = c.timeAt(d, l);
      final j = c.instantJelly(t);
      jellyAll += j;
      topJelly = math.max(topJelly, j);
      maxGold = math.max(maxGold, math.max(k.goldMinutes, k.materialMinutes));
      if (l <= 3 || l % 5 == 0 || l == d.maxLevel) {
        stdout.writeln(
          '    ${l.toString().padLeft(2)} | ${_dur(t.inSeconds.toDouble()).padLeft(8)} |'
          ' ${k.goldMinutes.toStringAsFixed(1).padLeft(7)} | ${k.materialMinutes.toStringAsFixed(1).padLeft(7)} |'
          ' ${k.samples.toString().padLeft(4)} | ${k.fossil.toString().padLeft(5)} | ${j.toString().padLeft(4)}',
        );
      }
    }
  }
  final s = scheduleResearch(c, basis);
  final s180 = inc.where((r) => r.day < _targetDays).toList();
  var gSum = 0.0, mSum = 0.0, fSum = 0.0;
  for (final v in s.goldMin.values) {
    gSum += v;
  }
  for (final v in s.matMin.values) {
    mSum += v;
  }
  for (final v in s.fossil.values) {
    fSum += v;
  }
  // 실제 활동 수입 대비(그날 자리 사냥 60분치로 환산 · 버프·접속 보너스 포함 처치 골드).
  var rg = 0.0, rm = 0.0, n = 0;
  for (final r in s180) {
    final dd = r.day.round();
    final g = (s.goldMin[dd] ?? 0) * r.hourGold / 60;
    final m = (s.matMin[dd] ?? 0) * r.hourMats / 60;
    if (r.onlineGold > 0) rg += g / r.onlineGold;
    if (r.onlineMats > 0) rm += m / r.onlineMats;
    n++;
  }
  final fossilIncome = s180.fold<double>(0, (a, r) => a + r.fossil);
  stdout.writeln('');
  stdout.writeln('── 무과금 일정(칸을 쉬지 않음) ──');
  stdout.writeln(
    '  칸: 1칸 → ${basis.hardDay.toStringAsFixed(0)}일 2칸 → ${basis.extremeDay.toStringAsFixed(0)}일 3칸 (하루 ${basis.activeHours}h 켜 둔 유저)',
  );
  stdout.writeln('  ★ 전체 완료: ${s.completionDay.toStringAsFixed(1)}일');
  stdout.writeln(
    '  칸 시간 ${s.slotDays.toStringAsFixed(0)}칸·일 중 표본 대기 ${(s.sampleWaitSlotDays / s.slotDays * 100).toStringAsFixed(1)}% · 할 연구가 없어 논 칸 ${(s.idleSlotDays / s.slotDays * 100).toStringAsFixed(1)}%',
  );
  stdout.writeln(
    '  골드: 하루 평균 ${(gSum / _targetDays).toStringAsFixed(1)}분치(목표 ${_goldMinutesPerDay.toStringAsFixed(0)} = 3시간 사냥분치의 ${(gSum / _targetDays / 180 * 100).toStringAsFixed(0)}%) · 재료 ${(mSum / _targetDays).toStringAsFixed(1)}분치',
  );
  stdout.writeln(
    '  실제 활동 수입(버프·접속 보너스 포함) 대비 하루 평균: 골드 ${(rg / n * 100).toStringAsFixed(1)}% · 재료 ${(rm / n * 100).toStringAsFixed(1)}%',
  );
  stdout.writeln(
    '  표본: 쓴 ${s.samplesSpent.toStringAsFixed(0)} / 번 ${s.samplesEarned.toStringAsFixed(0)} = ${(s.samplesSpent / s.samplesEarned * 100).toStringAsFixed(0)}% (하루 ${basis.samplesPerDay(c, 0).toStringAsFixed(1)} → ${basis.samplesPerDay(c, 170).toStringAsFixed(1)})',
  );
  stdout.writeln(
    '  화석: 합계 ${fSum.toStringAsFixed(0)} = 180일 활동 화석 ${fossilIncome.toStringAsFixed(0)} 의 ${(fSum / fossilIncome * 100).toStringAsFixed(0)}%',
  );
  stdout.writeln(
    '  젤리 즉시완료: 한 레벨 최대 $topJelly · 전부 즉시완료 합계 $jellyAll · 한 레벨 골드/재료 최대 ${maxGold.toStringAsFixed(0)}분',
  );
  stdout.writeln('  10일 묶음 하루 골드 분(연구 지출):');
  final b = _blocks(s, s.goldMin);
  stdout.writeln(
    '    ${[for (var i = 0; i < b.length; i++) '${i * 10}~:${b[i].toStringAsFixed(0)}'].join(' ')}',
  );
  stdout.writeln('  레벨 시작일(첫 연구):');
  final d0 = c.defs.first;
  stdout.writeln(
    '    ${[for (final st in s.starts)
      if (st.id == d0.id && (st.level % 5 == 0 || st.level == 1)) 'Lv${st.level} ${st.day.toStringAsFixed(1)}일'].join(' · ')}',
  );
}

void main(List<String> args) {
  String? incomePath;
  var fit = false, write = false;
  var jsonPath = '../app/assets/data/research.json';
  for (final a in args) {
    if (a.startsWith('--income=')) incomePath = a.substring(9);
    if (a == '--fit') fit = true;
    if (a == '--write') write = true;
    if (a.startsWith('--json=')) jsonPath = a.substring(7);
  }
  if (incomePath == null) {
    stderr.writeln('--income=<balance_sim --income 출력 파일> 이 필요합니다');
    exit(2);
  }
  final inc = parseIncome(File(incomePath).readAsStringSync());
  if (inc.isEmpty) {
    stderr.writeln(
      '@research-income 줄이 없습니다 — balance_sim 을 --income 으로 돌렸나요?',
    );
    exit(2);
  }
  if (inc.last.day + 1 < _targetDays) {
    stderr.writeln(
      '수입이 ${inc.last.day + 1}일치뿐입니다 — --endgame-days 로 $_targetDays일 이상을 뽑으세요',
    );
    exit(2);
  }
  var raw =
      jsonDecode(File(jsonPath).readAsStringSync()) as Map<String, dynamic>;
  final basis = FitBasis.fromIncome(inc);
  if (fit) {
    stdout.writeln('── 맞추기 ──');
    raw = _fit(raw, inc, basis);
    final frag = {
      'eliteDropChance': raw['eliteDropChance'],
      'bossFirstDrop': raw['bossFirstDrop'],
      'fitBasis': raw['fitBasis'],
      'research(모두)': {
        'maxLevel': _maxLevel,
        'time': (raw['research'] as List).first['time'],
        'cost': (raw['research'] as List).first['cost'],
      },
      'effect(사냥·육성·회복, perLevel)': {
        for (final e in raw['research'] as List)
          if (!_duelOwned.contains(e['kind'])) e['id']: e['effect']['perLevel'],
      },
    };
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(frag));
    stdout.writeln('');
    if (write) {
      File(jsonPath).writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(raw)}\n',
      );
      stdout.writeln('→ $jsonPath 에 반영했습니다');
    }
  }
  _report(_cfg(raw), inc, basis);
}
