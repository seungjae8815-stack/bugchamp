// 밸런스 시뮬레이터 — "마지막 보스까지 며칠 걸리나"를 실제 수식으로 잰다.
//
// 진행 곡선을 손으로 추정하면 항상 틀린다(HP 는 지수, 골드도 지수, 업그레이드
// 비용도 지수라 세 곡선의 교차점이 직관과 다르다). 그래서 `run_math.dart` 의
// **실제 함수**를 그대로 호출해 하루 단위로 굴린다.
//
// 실행:
//   cd packages\core_run ; dart run tool/balance_sim.dart
//   dart run tool/balance_sim.dart --habitats=20 --stages=15 --hp-growth=1.20
//
// ⚠️ 근사인 지점(결과를 읽을 때 감안할 것):
//  - 플레이어 구매 전략 = "지금 살 수 있는 것 중 가장 싼 업그레이드"를 반복.
//    실제 유저는 더 잘/못 살 수 있어 ±20% 정도는 흔들린다.
//  - 펫·버프·광고·결제 보너스는 빼고 계산한다(맨몸 기준 = 가장 느린 경로).
//  - 활동 플레이는 efficiency 1.0, 오프라인은 run_config 의 offlineEfficiency.

import 'dart:convert';
import 'dart:io';

import 'package:core_models/core_models.dart' show MaterialKind;
import 'package:core_run/core_run.dart';

/// 하루 중 실제로 앱을 켜고 노는 시간.
const _activeHoursPerDay = 2.0;

/// 하루에 오프라인 보상으로 회수하는 시간(상한 8h — kMaxOfflineAccrual).
const _offlineHoursPerDay = 8.0;

/// 업그레이드 구매를 다시 판단하는 간격(초). 짧을수록 정확하고 느리다.
const _sliceSeconds = 600.0;

/// 며칠까지 굴려보고 포기할지.
const _maxDays = 3650;

void main(List<String> args) {
  final opts = _parseArgs(args);
  final base =
      jsonDecode(File('../app/assets/data/run_config.json').readAsStringSync())
          as Map<String, dynamic>;

  // CLI 로 덮어쓸 값들 — JSON 을 고치기 전에 후보를 빠르게 재보기 위함.
  for (final e in opts.overrides.entries) {
    base[e.key] = e.value;
  }
  // --mult=1.15 : 공격 계열 스탯을 곱연산 성장으로 바꿔본다(진행 벽 해소 실험).
  if (opts.mult != null) {
    const multiplicative = {'attack', 'maxHp', 'defense'};
    for (final u in (base['upgrades'] as List).cast<Map<String, dynamic>>()) {
      if (multiplicative.contains(u['kind'])) u['valueGrowth'] = opts.mult;
    }
  }
  final config = RunConfig.fromJson(base);
  // 캠페인 끝: 월드 구조면 --worlds(기본 10)개 월드, 아니면 지역×스테이지.
  final finalStage = config.worldSize > 0
      ? config.worldSize * opts.worlds
      : config.stagesPerRegion * config.regions.length;

  stdout.writeln('── 설정 ──');
  stdout.writeln('  habitatsPerStage : ${config.habitatsPerStage}');
  stdout.writeln('  최종 스테이지     : $finalStage');
  if (config.worldSize > 0) {
    stdout.writeln(
      '  월드            : ${config.worldSize}스테이지 × ${opts.worlds}'
      ' · HP벽 ×${config.worldHpMult} · 골드 ×${config.worldGoldMult}'
      ' · 월드보스 ×${config.worldBossHpMult}',
    );
  }
  stdout.writeln('  hpGrowth         : ${config.hpGrowth}');
  stdout.writeln('  goldGrowth       : ${config.goldGrowth}');
  stdout.writeln('  offlineEfficiency: ${config.offlineEfficiency}');
  stdout.writeln(
    '  플레이어 모델     : 활동 ${_activeHoursPerDay}h/일'
    ' + 오프라인 ${_offlineHoursPerDay}h/일',
  );
  stdout.writeln('');

  // 마일스톤: 월드 구조면 월드 경계, 아니면 지역 경계.
  final marks = config.worldSize > 0
      ? [for (var i = 1; i <= opts.worlds; i++) i * config.worldSize]
      : [
          for (var i = 1; i <= config.regions.length; i++)
            i * config.stagesPerRegion,
        ];
  final sim = _Player(config, marks);
  var day = 0;

  while (day < _maxDays && sim.stage <= finalStage) {
    day++;
    sim.playDay();
    if (day <= 5 || day % 25 == 0) {
      stdout.writeln(
        'day ${day.toString().padLeft(4)} · 스테이지 ${sim.stage}'
        ' · 골드 ${_short(sim.gold)} · CP ${_short(combatPower(sim.stats))}',
      );
    }
  }

  stdout.writeln('');
  stdout.writeln('── 스테이지당 소요 시간 ──');
  stdout.writeln('  (방치 게임이 원하는 모양 = 이 값이 대체로 일정)');
  var prev = 0.0;
  var prevStage = 0;
  for (final m in _samplePoints(finalStage)) {
    final d = sim.reached[m];
    if (d == null) {
      stdout.writeln('  스테이지 ${m.toString().padLeft(4)} : 미도달');
      continue;
    }
    final perStage = (d - prev) / (m - prevStage);
    stdout.writeln(
      '  스테이지 ${m.toString().padLeft(4)} : 누적 ${_days(d).padLeft(9)}'
      ' · 이 구간 스테이지당 ${_perStage(perStage)}',
    );
    prev = d;
    prevStage = m;
  }

  stdout.writeln('');
  stdout.writeln('── 결과 ──');
  for (final m in marks) {
    final d = sim.reached[m];
    stdout.writeln(
      '  스테이지 ${m.toString().padLeft(3)} 클리어: '
      '${d == null ? "미도달" : _days(d)}',
    );
  }
  if (sim.stage > finalStage) {
    stdout.writeln(
      '  ★ 최종 보스(스테이지 $finalStage): ${_days(sim.reached[finalStage]!)}',
    );
  } else {
    stdout.writeln('  ★ $_maxDays일 안에 미도달 (스테이지 ${sim.stage}에서 정체)');
  }
}

/// 하루 = 활동 + 오프라인 시간. 소수 일수를 사람이 읽는 표기로.
String _days(double d) {
  if (d < 1) return '${(d * 24).toStringAsFixed(1)}시간';
  return '${d.toStringAsFixed(1)}일';
}

/// 스테이지 1개당 소요(일 단위 → 분/시간/일).
String _perStage(double d) {
  final min = d * 24 * 60;
  if (min < 1) return '${(min * 60).toStringAsFixed(0)}초';
  if (min < 90) return '${min.toStringAsFixed(1)}분';
  if (min < 60 * 48) return '${(min / 60).toStringAsFixed(1)}시간';
  return '${(min / 60 / 24).toStringAsFixed(1)}일';
}

/// 곡선 모양을 보기 위한 표본 스테이지들(로그 간격 + 균등 간격 혼합).
List<int> _samplePoints(int finalStage) {
  final out = <int>{};
  for (final f in [0.01, 0.05, 0.1, 0.2, 0.4, 0.6, 0.8, 1.0]) {
    final v = (finalStage * f).round();
    if (v > 0) out.add(v);
  }
  final list = out.toList()..sort();
  return list;
}

/// 업그레이드를 사 가며 스테이지를 미는 가상 플레이어.
class _Player {
  _Player(this.config, this.marks);

  final RunConfig config;

  /// 도달 시각을 기록할 스테이지들.
  final List<int> marks;

  /// 스테이지 → 도달 시점(소수 일수).
  final Map<int, double> reached = {};

  /// 지금까지 흘린 시뮬레이션 시간(일). 하루 = 활동 + 오프라인.
  double elapsedDays = 0;

  int stage = 1;

  /// 직전 슬라이스의 스테이지 — 그 사이 구간을 클리어로 기록한다.
  int prevStage = 1;
  double gold = 0;
  int level = 1;
  int xp = 0;
  final Map<UpgradeKind, int> levels = {};
  final Map<MaterialKind, double> materials = {};

  CharacterStats get stats => deriveStats(
    config,
    upgradeLevels: levels,
    characterLevel: level,
    // 채집함 상한 = 곤충 버프 상한과 같다(§2.1). 상한까지 모았다고 본다.
    bugsCollected: 50,
  );

  void playDay() {
    _run(_activeHoursPerDay * 3600, 1.0);
    _run(_offlineHoursPerDay * 3600, config.offlineEfficiency);
  }

  /// [seconds] 동안 진행하되, 중간중간 업그레이드를 산다(dps 가 오르면 진행도 빨라짐).
  void _run(double seconds, double efficiency) {
    var left = seconds;
    while (left > 0) {
      final slice = left < _sliceSeconds ? left : _sliceSeconds;
      left -= slice;
      final prog = simulateIdleProgress(
        config: config,
        startStage: stage,
        stats: stats,
        elapsed: Duration(milliseconds: (slice * 1000).round()),
        maxAccrual: const Duration(days: 1), // 상한은 호출부가 이미 반영
        efficiency: efficiency,
      );
      elapsedDays += slice / 3600 / (_activeHoursPerDay + _offlineHoursPerDay);
      // 모든 스테이지의 클리어 시각을 남긴다 — 곡선 모양(스테이지당 소요)을 보기 위해.
      for (var s = prevStage; s < stage; s++) {
        reached.putIfAbsent(s, () => elapsedDays);
      }
      prevStage = stage;
      stage = prog.newStage;
      gold += prog.gold;
      _gainXp(prog.xp);
      // 재료: 처치당 materialDropChance 확률로 평균 1.5개, 3종에 고르게.
      final mats =
          prog.habitatClears *
          config.materialDropChance *
          stats.materialFind *
          1.5;
      for (final k in const [
        MaterialKind.chitin,
        MaterialKind.mineral,
        MaterialKind.sap,
      ]) {
        materials[k] = (materials[k] ?? 0) + mats / 3;
      }
      _buyUpgrades();
    }
  }

  void _gainXp(int amount) {
    xp += amount;
    while (xp >= xpForNextLevel(level)) {
      xp -= xpForNextLevel(level);
      level++;
    }
  }

  /// 살 수 있는 것 중 **가장 싼** 업그레이드를 계속 산다(고르게 성장하는 플레이어).
  void _buyUpgrades() {
    for (var guard = 0; guard < 10000; guard++) {
      UpgradeKind? best;
      var bestCost = double.infinity;
      for (final kind in config.upgrades.keys) {
        final spec = config.upgrade(kind);
        final lv = levels[kind] ?? 0;
        final cost = upgradeCost(spec, lv).toDouble();
        if (cost > gold || cost >= bestCost) continue;
        final mk = spec.materialKind;
        if (mk != null &&
            upgradeMaterialCost(spec, lv) > (materials[mk] ?? 0)) {
          continue;
        }
        best = kind;
        bestCost = cost;
      }
      if (best == null) return;
      final spec = config.upgrade(best);
      final lv = levels[best] ?? 0;
      gold -= bestCost;
      final mk = spec.materialKind;
      if (mk != null) {
        materials[mk] = (materials[mk] ?? 0) - upgradeMaterialCost(spec, lv);
      }
      levels[best] = lv + 1;
    }
  }
}

String _short(num v) {
  if (v >= 1e12) return '${(v / 1e12).toStringAsFixed(1)}T';
  if (v >= 1e9) return '${(v / 1e9).toStringAsFixed(1)}B';
  if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
  if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(1)}K';
  return v.toStringAsFixed(0);
}

class _Opts {
  const _Opts(this.overrides, this.mult, this.worlds);
  final Map<String, dynamic> overrides;

  /// 공격·체력 스탯의 레벨당 곱연산 성장률(null 이면 현행 덧셈).
  final double? mult;

  /// 캠페인 월드 수(worldSize > 0 일 때).
  final int worlds;
}

/// `--habitats=20 --stages=15 --hp-growth=1.2 --gold-growth=1.14`
_Opts _parseArgs(List<String> args) {
  const map = {
    'habitats': 'habitatsPerStage',
    'stages': 'stagesPerRegion',
    'hp-growth': 'hpGrowth',
    'gold-growth': 'goldGrowth',
    'boss-hp': 'bossHpMult',
    'boss-reward': 'bossRewardMult',
    'xp-growth': 'xpGrowth',
    'gold-base': 'goldBase',
    'hp-base': 'hpBase',
    'world-size': 'worldSize',
    'world-hp': 'worldHpMult',
    'world-gold': 'worldGoldMult',
    'world-boss': 'worldBossHpMult',
  };
  final out = <String, dynamic>{};
  double? mult;
  var worlds = 10;
  for (final a in args) {
    final m = RegExp(r'^--([a-z-]+)=(.+)$').firstMatch(a);
    if (m == null) continue;
    if (m.group(1) == 'mult') {
      mult = double.parse(m.group(2)!);
      continue;
    }
    if (m.group(1) == 'worlds') {
      worlds = int.parse(m.group(2)!);
      continue;
    }
    final key = map[m.group(1)];
    if (key == null) {
      stderr.writeln('알 수 없는 옵션: ${m.group(1)}');
      continue;
    }
    out[key] = num.parse(m.group(2)!);
  }
  return _Opts(out, mult, worlds);
}
