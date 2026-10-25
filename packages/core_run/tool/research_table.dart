// 연구소 비용·시간 표 — "터무니없는 값이 나오지 않게"(사장님 핵심 요구, 설계 §3.6).
//
// 입력: balance_sim 이 뽑은 **하루 3시간 켜 둔 무과금 유저**의 날짜별 활동 수입.
//   cd packages\core_run
//   dart run tool/balance_sim.dart --tiers=4 --no-fairy --active-hours=3 --income --endgame-days=150 > %TEMP%\income3h.txt
//   dart run tool/research_table.dart --income=%TEMP%\income3h.txt          # 지금 research.json 을 잰다
//   dart run tool/research_table.dart --income=%TEMP%\income3h.txt --fit    # 곡선을 다시 맞춰 JSON 조각을 찍는다
//   dart run tool/research_table.dart --income=%TEMP%\income3h.txt --fit --write   # research.json 에 반영
//   dart run tool/research_table.dart --income=%TEMP%\income3h.txt --fit --level-cap=0   # 한 레벨 상한(기본 1,210분) 없이
//
// 맞추는 목표(사장님 확정 · 컨트롤러 판정):
//  - 시간: 무과금 칸 곡선(1칸 → 어려움 도착일부터 2칸 → 극한 도착일부터 3칸)을 **쉬지 않고** 돌릴 때
//    29개 × 전 레벨이 [_targetDays](180)일에 끝난다. Lv1 = [_firstSeconds](5분) · Lv10 = [_kneeSeconds](12시간).
//  - 골드·재료: JSON 단위는 "가 본 최고 사냥터의 사냥 N분치"지만, 크기는 그날 **실제 활동 수입**
//    (처치 + 선물·일일보상·미션, 방치 제외)의 180일 평균 50% 로 맞춘다(골드·재료 따로, 사장님 확정).
//    한 레벨 상한(--level-cap, 기본 1,210분 ≈ 하루 실제 수입의 1/3 — 회귀 테스트와 같다, 사장님 A안)에 걸리면 상한까지만 올리고 필요한 상한을 찍는다.
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

/// 연구마다 레벨 수 — `--levels=` 로 바꿔 본다.
int _maxLevel = 30;
const _firstSeconds = 300.0;
const _kneeLevel = 10;
const _kneeSeconds = 12 * 3600.0;

/// 연구 골드·재료 = 그날 **실제로 지갑에 들어온** 활동 수입(처치 + 선물·일일보상·미션 등 전투 밖)의 50%
/// (사장님 확정 2026-10-22 — 사냥 분치의 50% 가 아니다). 방치(오프라인) 정산은 뺀다(설계 §8).
const _incomeShare = 0.5;
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
  // §10 추가 — 회피·스킬 쿨타임은 연구 몫 상한(0.2)과 같게. 결투 치명 0.05 · 근성 0.02(6b 결투 맞추기 —
  // duel_build_sim --research-max: 근성 0.05 면 다 찍은 쪽 3마리 95.6% 로 사장님 기준(95% 미만)을 넘었다 → 0.02 에서 88.7%).
  'huntCritDmg': 0.40,
  'huntRegen': 0.40,
  'huntEvade': 0.20,
  'huntExp': 0.30,
  'skillCooldown': 0.20,
  'forgeTime': 0.40,
  'starTime': 0.40,
  'polishCost': 0.30,
  'traitChance': 0.50,
  'potionChance': 0.30,
  'salvageMat': 0.30,
  'exchangeGain': 0.20,
  'giftGold': 0.20,
  'duelCrit': 0.05,
  'duelGrit': 0.02,
};

/// 하루 활동 수입 한 줄(balance_sim `@research-income`).
class IncomeDay {
  IncomeDay.fromJson(Map<String, dynamic> j)
    : day = (j['day'] as num).toDouble(),
      tier = (j['tier'] as num).toInt(),
      onlineGold = (j['onlineGold'] as num).toDouble(),
      onlineMats = (j['onlineMats'] as num).toDouble(),
      offBattleGold = (j['offBattleGold'] as num?)?.toDouble() ?? 0,
      offBattleMats = (j['offBattleMats'] as num?)?.toDouble() ?? 0,
      toUpgrades = (j['toUpgrades'] as num?)?.toDouble() ?? 0,
      hourGold = (j['hourGold'] as num).toDouble(),
      hourMats = (j['hourMats'] as num).toDouble(),
      elites = (j['elites'] as num).toDouble(),
      bossKills = (j['bossKills'] as num).toDouble(),
      fossil = (j['fossil'] as num).toDouble(),
      activeHours = (j['activeHours'] as num).toDouble();

  final double day;
  final int tier;
  final double onlineGold, onlineMats, hourGold, hourMats;

  /// 선물·일일보상·미션 등 전투 밖 골드 · 재료(종류당) · 그날 강화에 쓸 수 있게 들어온 골드 전부(방치 포함).
  final double offBattleGold, offBattleMats, toUpgrades;

  /// 하루 활동 실제 수입(처치 + 전투 밖) — 골드 · 재료(종류당).
  double get actualGold => onlineGold + offBattleGold;
  double get actualMats => onlineMats + offBattleMats;
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

  /// 하루 표본 수입. [idleFactor] = 연구 패스가 방치 중 더하는 정예 몫(방치 시간 × 방치 효율 ÷ 활동 시간, [_PassFit]).
  double samplesPerDay(ResearchConfig c, double day, {double idleFactor = 0}) =>
      _at(elitesPerDay, day) *
          (1 + idleFactor) *
          c.eliteDropChance *
          c.eliteDropAmount +
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

  /// 정수 날짜별 번 표본 · 표본이 없어 논 칸·일(2026-10-25 — 초반에 남고 후반에 모자라는지 보려고).
  final earned = <int, double>{};
  final sampleWait = <int, double>{};
  final slotTime = <int, double>{};
}

/// 무과금이 칸을 쉬지 않고 돌릴 때의 일정. [ignoreSamples] 면 표본을 무한으로 본다(시간 맞추기용).
ScheduleResult scheduleResearch(
  ResearchConfig c,
  FitBasis basis, {
  bool ignoreSamples = false,
  double horizonDays = 1000,
  // 연구 패스(2026-10-25 사장님 — 패스면 표본이 딱 맞고, 없으면 칸이 논다): 방치 표본 몫 · 연구 시간 단축.
  double idleFactor = 0,
  double passCut = 0,
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
    final cut = math.min(
      0.5,
      researchEffects(c, levels).of(ResearchEffect.researchTime) + passCut,
    );
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
    final dk = t.floor();
    r.sampleWait[dk] = (r.sampleWait[dk] ?? 0) + waiting * dt;
    r.slotTime[dk] = (r.slotTime[dk] ?? 0) + slots * dt;
    r.idleSlotDays += (free - waiting) * dt;
    final earn = basis.samplesPerDay(c, t, idleFactor: idleFactor) * dt;
    bank += earn;
    r.samplesEarned += earn;
    r.earned[t.floor()] = (r.earned[t.floor()] ?? 0) + earn;
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
  required double matFirst,
  required double fossilFirst,
  double? eliteChance,
}) {
  final out = jsonDecode(jsonEncode(raw)) as Map<String, dynamic>;
  out['_comment'] =
      '연구소(설계 docs/superpowers/specs/2026-10-22-research-lab-design.md). 시간·비용 곡선 · eliteDropChance · 사냥·육성·장비·경제 effect · fitBasis 는 '
      'tool/research_table.dart --fit --write 가 뽑는다 — 손으로 한 칸씩 고치지 않는다(하루 3시간 켜 둔 무과금 · 골드·재료 = 3시간 켜 둔 날 실제 수입의 50% 목표, 한 레벨 상한 사냥 1,210분치 · 약 180일 · 사장님 A안). bossFirstDrop 25 는 사장님 확정값. '
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
      'materialMinutesFirst': matFirst,
      'fossilFrom': _maxLevel - _fossilLevels + 1,
      'fossilFirst': fossilFirst,
      'growth': cg,
      'decay': cd,
    };
  }
  return out;
}

ResearchConfig _cfg(Map<String, dynamic> raw) => ResearchConfig.fromJson(raw);

/// 연구 패스로 맞추기(2026-10-25 사장님) — research.json `pass`: `timeCut`(연구 시간 단축) · `fitIdleHours`(맞출 때 가정하는
/// 하루 방치 시간) · `fitSampleShare`(표본 합계 = **패스 유저** 180일 수입의 이 비율 — 1 에 가까울수록 아슬아슬).
/// 방치 효율은 run_config `offlineEfficiency`. 패스 블록이 없으면 예전처럼 무과금 기준(_sampleShare).
class _PassFit {
  const _PassFit({this.timeCut = 0, this.idleFactor = 0, this.share = _sampleShare});
  final double timeCut;
  final double idleFactor;
  final double share;
  bool get on => idleFactor > 0 || timeCut > 0;

  factory _PassFit.of(Map<String, dynamic> raw, double activeHours) {
    final p = raw['pass'];
    if (p is! Map) return const _PassFit();
    final run =
        jsonDecode(File('../app/assets/data/run_config.json').readAsStringSync())
            as Map<String, dynamic>;
    final eff = (run['offlineEfficiency'] as num?)?.toDouble() ?? 0.3;
    final idleH = (p['fitIdleHours'] as num?)?.toDouble() ?? 0;
    return _PassFit(
      timeCut: (p['timeCut'] as num?)?.toDouble() ?? 0,
      idleFactor: idleH * eff / activeHours,
      share: (p['fitSampleShare'] as num?)?.toDouble() ?? _sampleShare,
    );
  }
}

/// 10일 묶음마다 하루 골드 분(연구가 쓴) — 고르게 쓰는지 본다.
List<double> _blocks(ScheduleResult s, Map<int, double> m) => [
  for (var b = 0; b * 10 < _targetDays; b++)
    [
          for (var d = b * 10; d < b * 10 + 10; d++) m[d] ?? 0,
        ].reduce((a, b) => a + b) /
        10,
];

double _mean(List<double> v) => v.reduce((a, b) => a + b) / v.length;

/// 180일 날짜별 비율 — 연구 골드(그날 자리 사냥 60분치로 환산) ÷ 활동 실제 수입, 재료도 같이,
/// 그리고 연구 골드 ÷ 그날 강화에 쓸 수 있던 골드 전부(방치 포함) = "강화 골드가 줄어든 몫".
({List<double> gold, List<double> mats, List<double> upgrades}) _ratios(
  ScheduleResult s,
  List<IncomeDay> inc,
) {
  final g = <double>[], m = <double>[], u = <double>[];
  for (final r in inc.where((r) => r.day.round() < _targetDays)) {
    final dd = r.day.round();
    final gold = (s.goldMin[dd] ?? 0) * r.hourGold / 60;
    final mats = (s.matMin[dd] ?? 0) * r.hourMats / 60;
    g.add(r.actualGold > 0 ? gold / r.actualGold : 0);
    m.add(r.actualMats > 0 ? mats / r.actualMats : 0);
    u.add(r.toUpgrades > 0 ? gold / r.toUpgrades : 0);
  }
  return (gold: g, mats: m, upgrades: u);
}

/// 날짜별 값을 10일 묶음 평균으로.
List<double> _ratioBlocks(List<double> v) => [
  for (var b = 0; b * 10 < v.length; b++)
    _mean(v.sublist(b * 10, math.min(v.length, b * 10 + 10))),
];

Map<String, dynamic> _fit(
  Map<String, dynamic> raw,
  List<IncomeDay> inc,
  FitBasis basis, {
  double levelCap = 1210,
}) {
  var elites = 0.0, bosses = 0.0;
  final fossilIncome = inc
      .where((r) => r.day < _targetDays)
      .fold<double>(0, (a, r) => a + r.fossil);
  for (final r in inc.where((r) => r.day < _targetDays)) {
    elites += r.elites;
    bosses += r.bossKills;
  }
  final amount = _cfg(raw).eliteDropAmount;
  final pf = _PassFit.of(raw, basis.activeHours);

  // 감쇠 td · 비용 모양 α · 보스 첫 처치 표본 drop 이 정해지면 나머지는 모두 따라 나온다:
  //   시간 증가율 = Lv10 이 12시간이 되는 값 · 비용 증가율 = 1 + α(시간 증가율 − 1)(같은 감쇠)
  //   골드·재료 Lv1 = 180일 평균 실제 수입 비율 50%(각각 따로) · 화석 첫 값 = 180일 활동 화석의 20% · 정예 확률 = 표본 합계 ÷ 90%.
  Map<String, dynamic> build(
    double td,
    double alpha,
    int drop, {
    double goldFirst = 1,
    double matFirst = 1,
  }) {
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
        matFirst: 1,
        fossilFirst: 1,
      ),
    );
    var fossilShape = 0.0, sampleSum = 0.0;
    for (final d in unit.defs) {
      for (var l = 1; l <= d.maxLevel; l++) {
        final k = unit.costAt(d, l);
        sampleSum += k.samples;
        if (l >= d.fossilFrom) {
          // 반올림 전 화석 모양(fossilFrom 레벨 = 1).
          fossilShape +=
              k.goldMinutes / unit.costAt(d, d.fossilFrom).goldMinutes;
        }
      }
    }
    final chance = _round(
      (sampleSum / pf.share - bosses * drop) /
          (elites * (1 + pf.idleFactor) * amount),
      4,
    );
    return _withCurves(
      raw,
      tg: tg,
      td: td,
      cg: cg,
      cd: td,
      goldFirst: goldFirst,
      matFirst: matFirst,
      fossilFirst: _round(fossilIncome * _fossilShare / fossilShape, 1),
      eliteChance: chance,
    )..['bossFirstDrop'] = drop;
  }

  ScheduleResult run(Map<String, dynamic> j, {bool ignoreSamples = false}) =>
      scheduleResearch(
        _cfg(j),
        basis,
        ignoreSamples: ignoreSamples,
        idleFactor: pf.idleFactor,
        passCut: pf.timeCut,
      );

  /// 완료일이 [_targetDays] 가 되는 감쇠(클수록 후반이 길어 늦게 끝난다).
  double fitDecay(double alpha, int drop, {required bool ignoreSamples}) {
    var lo = 0.2, hi = 0.999;
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
  final drop = _cfg(raw).bossFirstDrop;
  final td0 = fitDecay(0.6, drop, ignoreSamples: true);

  // 2) 비용 모양 α — 10일 묶음 "골드 ÷ 실제 수입" 비율이 가장 고르게(변동계수 최소).
  var best = (alpha: 1.0, cv: double.infinity);
  for (var a = 0.30; a <= 1.2001; a += 0.02) {
    final s = run(build(td0, a, drop), ignoreSamples: true);
    final b = _ratioBlocks(_ratios(s, inc).gold);
    final mean = b.reduce((x, y) => x + y) / b.length;
    final sd = math.sqrt(
      b.map((x) => (x - mean) * (x - mean)).reduce((x, y) => x + y) / b.length,
    );
    if (sd / mean < best.cv) best = (alpha: _round(a, 2), cv: sd / mean);
  }

  // 3) 표본 — 보스 첫 처치 몫은 사장님 확정값(research.json bossFirstDrop, 설계 §10 — 25 확정)을 그대로 두고
  //    정예 드롭 확률만 맞춘다(build). 초반엔 정예가 적어 보스 몫이 표본 대기를 메운다.

  // 4) 표본까지 넣고 감쇠를 다시 잡는다.
  final td = fitDecay(best.alpha, drop, ignoreSamples: false);

  // 5) 크기 — 비율은 Lv1 값에 정비례하므로 1분일 때의 180일 평균 비율로 나눈다(골드·재료 따로).
  //    한 레벨 상한([levelCap] 분, 회귀 테스트와 같은 값)을 넘으면 상한까지만 — 비율은 그만큼 낮아지고,
  //    50% 에 필요한 상한을 함께 찍는다(상한을 바꿀지는 사장님 결정).
  final unitCfg = build(td, best.alpha, drop);
  final unitRatio = _ratios(run(unitCfg), inc);
  var unitMax = 0.0;
  final uc = _cfg(unitCfg);
  for (final d in uc.defs) {
    unitMax = math.max(unitMax, uc.costAt(d, d.maxLevel).goldMinutes);
  }
  var gf = _incomeShare / _mean(unitRatio.gold);
  var mf = _incomeShare / _mean(unitRatio.mats);
  stdout.writeln(
    '  50% 에 필요한 한 레벨 최대: 골드 ${(gf * unitMax).toStringAsFixed(0)}분 · 재료 ${(mf * unitMax).toStringAsFixed(0)}분 (상한 ${levelCap > 0 ? levelCap.toStringAsFixed(0) : '없음'})',
  );
  if (levelCap > 0) {
    gf = math.min(gf, levelCap / unitMax * 0.999);
    mf = math.min(mf, levelCap / unitMax * 0.999);
  }
  final out = build(
    td,
    best.alpha,
    drop,
    goldFirst: _round(gf, 4),
    matFirst: _round(mf, 4),
  );
  final first = (out['research'] as List).first as Map<String, dynamic>;
  stdout.writeln(
    '  시간: Lv1 ${_firstSeconds ~/ 60}분 · Lv$_kneeLevel ${_kneeSeconds ~/ 3600}시간 · 증가율 ${first['time']['growth']} · 감쇠 $td (표본 무한 $td0)',
  );
  stdout.writeln(
    '  골드·재료: 증가율 ${first['cost']['growth']}(α ${best.alpha}, 10일 묶음 비율 변동 ${(best.cv * 100).toStringAsFixed(0)}%) · Lv1 골드 ${first['cost']['goldMinutesFirst']}분 · 재료 ${first['cost']['materialMinutesFirst']}분',
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

void _report(
  ResearchConfig c,
  List<IncomeDay> inc,
  FitBasis basis, {
  _PassFit pf = const _PassFit(),
}) {
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
  // 비용 비율은 **설계 경로**(패스가 있으면 패스 유저)로 잰다 — 맞추기와 같은 일정.
  final s = scheduleResearch(
    c,
    basis,
    idleFactor: pf.idleFactor,
    passCut: pf.timeCut,
  );
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
  final ratio = _ratios(s, inc);
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
    '  사냥 분치: 하루 평균 골드 ${(gSum / _targetDays).toStringAsFixed(1)}분 · 재료 ${(mSum / _targetDays).toStringAsFixed(1)}분 (3시간 = 180분)',
  );
  stdout.writeln(
    '  ★ 실제 활동 수입(처치 + 선물·일일보상·미션, 방치 제외) 대비 180일 평균: 골드 ${(_mean(ratio.gold) * 100).toStringAsFixed(1)}% · 재료 ${(_mean(ratio.mats) * 100).toStringAsFixed(1)}% (목표 ${(_incomeShare * 100).toStringAsFixed(0)}%)',
  );
  stdout.writeln(
    '  ★ 강화에 쓸 골드(방치 포함 그날 들어온 골드 전부)가 줄어든 몫: 180일 평균 ${(_mean(ratio.upgrades) * 100).toStringAsFixed(1)}%',
  );
  String blocks(List<double> v) => [
    for (final (i, x) in _ratioBlocks(v).indexed)
      '${i * 10}~:${(x * 100).toStringAsFixed(0)}',
  ].join(' ');
  stdout.writeln('  10일 묶음 골드 ÷ 실제 수입(%): ${blocks(ratio.gold)}');
  stdout.writeln('  10일 묶음 재료 ÷ 실제 수입(%): ${blocks(ratio.mats)}');
  stdout.writeln('  10일 묶음 강화 골드 감소(%): ${blocks(ratio.upgrades)}');
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
  var levelCap = 1210.0;
  var jsonPath = '../app/assets/data/research.json';
  for (final a in args) {
    if (a.startsWith('--income=')) incomePath = a.substring(9);
    if (a == '--fit') fit = true;
    if (a == '--write') write = true;
    if (a.startsWith('--level-cap=')) levelCap = double.parse(a.substring(12));
    if (a.startsWith('--levels=')) _maxLevel = int.parse(a.substring(9));
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
    raw = _fit(raw, inc, basis, levelCap: levelCap);
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
  final pf = _PassFit.of(raw, basis.activeHours);
  _report(_cfg(raw), inc, basis, pf: pf);
  if (pf.on) _passCompare(_cfg(raw), basis, pf);
}

/// 패스 있음 / 없음 비교(2026-10-25) — 같은 연구 표로 완료일과 "표본이 없어 칸이 논 시간".
void _passCompare(ResearchConfig c, FitBasis basis, _PassFit pf) {
  stdout.writeln('');
  stdout.writeln('── 연구 패스 있음 / 없음 (하루 ${basis.activeHours}h 켜 둠) ──');
  void blocks(ScheduleResult r) {
    final rows = <String>[];
    for (var b = 0; b * 20 < 300; b++) {
      double sum(Map<int, double> m) => [
        for (var d = b * 20; d < b * 20 + 20; d++) m[d] ?? 0,
      ].fold(0.0, (a, x) => a + x);
      final slot = sum(r.slotTime);
      if (slot <= 0) break;
      rows.add(
        '${b * 20}~: 번 ${(sum(r.earned) / 20).toStringAsFixed(0)}/일 · 쓴 ${(sum(r.samples) / 20).toStringAsFixed(0)}/일 · 논 칸 ${(sum(r.sampleWait) / slot * 100).toStringAsFixed(0)}%',
      );
    }
    for (final x in rows) {
      stdout.writeln('      $x');
    }
  }

  void line(String name, ScheduleResult r) => stdout.writeln(
    '  $name: 완료 ${r.completionDay.isFinite ? '${r.completionDay.toStringAsFixed(0)}일' : '1000일 넘음'} · '
    '표본이 없어 논 칸 ${(r.sampleWaitSlotDays / r.slotDays * 100).toStringAsFixed(0)}% · '
    '표본 쓴/번 ${(r.samplesSpent / r.samplesEarned * 100).toStringAsFixed(0)}%',
  );
  final withPass = scheduleResearch(
    c,
    basis,
    idleFactor: pf.idleFactor,
    passCut: pf.timeCut,
  );
  line(
    '패스(방치 표본 · 시간 −${(pf.timeCut * 100).toStringAsFixed(0)}%)',
    withPass,
  );
  blocks(withPass);
  final noPass = scheduleResearch(c, basis);
  line('패스 없음', noPass);
  blocks(noPass);
  // 패스 없이 더 오래 켜 두면 — 활동 시간에 비례해 정예가 는다고 본다(추정).
  for (final h in [4.0, 5.0, 6.0]) {
    line(
      '패스 없음 · ${h.toStringAsFixed(0)}h 켜 둠(추정)',
      scheduleResearch(c, basis, idleFactor: h / basis.activeHours - 1),
    );
  }
}
