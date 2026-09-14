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
import 'dart:math' as math;
import 'dart:io';

import 'package:core_models/core_models.dart' show ItemOptionKind, MaterialKind;
import 'package:core_run/core_run.dart';

import 'power_ceiling.dart';

/// 하루 중 실제로 앱을 켜고 노는 시간.
const _activeHoursPerDay = 2.0;

/// 하루에 오프라인 보상으로 회수하는 시간(상한 8h — kMaxOfflineAccrual).
const _offlineHoursPerDay = 8.0;

// ── 맨몸이 아닌 "실제 유저"를 재기 위한 보정 ─────────────────────────
//
// 예전 이 도구는 펫·버프·보상을 전부 빼고 "맨몸 = 가장 느린 경로"를 쟀다.
// 그런데 **아무도 맨몸으로 남지 않는다** — 시간이 지나면 펫이 자라고, 버프를
// 켜고, 일일보상·선물·미션·결투 보상이 매일 쌓인다. 그걸 빼고 맞춘 수치는
// 실제보다 항상 느슨하다(실제로 "6대로 맞췄는데 1대"가 그렇게 나왔다).
//
// 아래 값들은 **평균적인 유저**의 가정이다. 상한(전부 최대)으로 잡으면 대다수가
// 너무 어려워지고, 0으로 잡으면 지금처럼 빗나간다.

/// 골드 배율 — `goldRush` 버프(gold x2.0, 누적 상한 6h/일)를 하루 평균으로.
/// 광고를 꼬박꼬박 보는 유저는 2.0 에 가깝고, 안 보면 1.0 이다.
const _buffGoldMult = 1.5;

/// DPS 배율 — `frenzy` 버프(공격 x1.2, 공속 x1.5 = DPS x1.8)를 활동 시간 평균으로.
const _buffDpsMult = 1.4;

// ── ★ 적응형 체력 **기준 밖** 전력 (2026-08-30 추가) ──────────────────
//
// 이 도구가 오래 틀린 지점이다. 실제 앱의 사슬은 두 갈래다:
//
//   _petStats = 업그레이드 + 캐릭터레벨 + 곤충수 + 펫   ← 몬스터가 맞추는 **기준**
//   _stats    = _petStats + 장비 + 종패시브 + 도감 + 버프 ← 실제 **전투력**
//
// 몬스터 체력은 앞쪽만 보고 자란다(§7). 뒤에 붙는 것은 전부 **순수 이득**이라,
// 그 시스템이 늘어날수록 게임이 조용히 쉬워진다. 1.0.4 엔 버프뿐이었는데
// 1.0.5 에 장비·공방, 1.0.6 에 종 패시브·도감이 붙었다.
//
// ⚠️ 예전 이 도구는 **양쪽에 같은 값**을 넘겼다(`playerAttack: hit` 에 버프
// 포함). 그러면 시뮬 안에서는 버프가 스스로 상쇄돼 "빠듯하다"고 나온다 —
// 실제로는 그만큼 쉬워지는데도. 그래서 체감과 계속 어긋났다.

/// 종 고유 패시브 — 펫 3마리 장착분. 능력치가 갈리므로 공격 기여는 일부다.
const _passiveAttackMult = 1.08;

/// `--equip-scale=k` — 공방 모델이 뽑은 장비 옵션 값을 k 배로 본다(장비를 더/덜
/// 갖춘 유저). 장비 자체는 이제 공방 규칙으로 계산한다(`_Player._forgeDays`).
double _gearScale = 1.0;

/// 탭 부스트 — **활동 시간에만** 걸리는 평균 배율.
///
/// ⚠️ `boostSpeedFactor = 1.0` 이라 데미지와 공속에 **둘 다** 실린다
/// 데미지와 공격속도 **양쪽**에 실린다 — 공속 쪽 비중은 `boostSpeedFactor`(0.4).
/// 이것도 적응형 기준 **밖**이다(§7: "탭 부스트도 여기 들어오면 안 된다").
///
/// 상한은 2026-09-01 에 x5 → **x2** 로 내렸다. x5 는 실질 DPS x13 이라
/// 탭할 때와 안 할 때의 차이가 너무 컸다 — 방치 게임인데 손으로 두드리는 게
/// 정답이 된다. x2 면 실질 DPS x2.8 이다.
/// 상한을 계속 유지하려면 쉼 없이 두드려야 하므로, 보스전에서만 올리는
/// **평균**을 잡는다(기본 1.6 — 새 상한 2.0 아래라 이 값은 그대로 유효하다).
/// `--boost=1.0` 으로 끄면 "탭을 전혀 안 하는 유저"가 된다.
double _tapBoostAvg = 1.6;

/// 난이도 회차(0=쉬움). `--tier=` 로 바꾼다.
///
/// 회차가 오르면 몬스터도 보상도 함께 오른다(`tierHpMult`/`tierRewardMult`).
/// **둘이 같은 폭이면 진행 일수는 크게 안 변해야 한다** — 그게 설계 의도다.
/// 이 도구는 그게 실제로 성립하는지 재는 데 쓴다.
int _tier = 0;

/// `--tiers=N` — 회차 N 개를 **연속으로**(이월하며) 돌린다.
int _tierRuns = 1;

/// 전투 밖에서 하루에 들어오는 골드(일일보상 13,000 + 깜짝선물 약 32,000 +
/// 미션·결투 보상). **초반에 결정적**이고 후반엔 무의미해진다 —
/// 그래서 정액으로 둔다(day1 골드의 25% 수준, day25 엔 반올림 오차).
const _dailyBonusGold = 100000.0;

/// 전투 밖에서 하루에 들어오는 **재료**(3종 각각).
///
/// 일일보상 80(점심30+저녁50) + 깜짝선물 약 11회 × 평균 36 = 약 480.
/// 처치 드롭만 세면 재료가 **덜 남는 것처럼** 보인다 — 실제로는 이만큼이
/// 매일 더 들어온다(고정값이라 후반일수록 비중은 줄어든다).
const _dailyBonusMaterials = 480.0;

/// `--mat-cost-growth=` 로 모든 업그레이드의 재료비 증가율을 덮어쓴다(탐색용).
double? _matCostGrowth;

/// `--mat-base-mult=` 로 재료 기본비용을 일괄 배수한다(탐색용).
double _matBaseMult = 1.0;

/// 오행 **상극이 걸린 곤충 수**(0~3). `--pet-restrain=N`.
///
/// 곤충은 캐릭터와 따로 때리고, 지역 속성을 克하는 곤충의 타격만 배율을 받는다.
/// 배율 자체(`petRestrainMult`)는 CLI 가 아니라 **run_config.json 에서 읽는다** —
/// CLI 로도 받게 하면 JSON 과 시뮬이 갈려 "시뮬은 통과했는데 게임은 다르다"가 된다.
int _petRestrainCount = 0;

/// `--endgame-days=N` — 극한 최종 보스 뒤로 더 노는 일수.
int _endgameDays = 0;

/// 유저가 보스전을 붙잡고 있을 수 있는 최대 시간(초). 이보다 오래 걸리면 안 누른다고 본다.
const _bossPatienceSeconds = 240.0;

/// 업그레이드 구매를 다시 판단하는 간격(초). 짧을수록 정확하고 느리다.
const _sliceSeconds = 600.0;

/// 며칠까지 굴려보고 포기할지.
const _maxDays = 3650;

/// 보고서 표본 스테이지. 사냥터 모드면 main 이 사냥터 시작점으로 바꿔 놓는다.
List<int> _samples = const [10, 50, 100, 200, 400, 550, 700, 850, 1000];
List<int> _samplesEcon = const [10, 30, 50, 100, 200, 400, 700];

void main(List<String> args) {
  final opts = _parseArgs(args);
  final base =
      jsonDecode(File('../app/assets/data/run_config.json').readAsStringSync())
          as Map<String, dynamic>;

  // CLI 로 덮어쓸 값들 — JSON 을 고치기 전에 후보를 빠르게 재보기 위함.
  for (final e in opts.overrides.entries) {
    if (e.key == '__up') {
      for (final u in e.value as List<List<String>>) {
        for (final spec in base['upgrades'] as List) {
          if (spec['kind'] == u[0]) {
            spec[u[1]] = num.tryParse(u[2]) ?? u[2];
          }
        }
      }
      continue;
    }
    base[e.key] = e.value;
  }
  // --mult=1.15 : 공격 계열 스탯을 곱연산 성장으로 바꿔본다(진행 벽 해소 실험).
  if (opts.mult != null) {
    const multiplicative = {'attack', 'maxHp', 'defense'};
    for (final u in (base['upgrades'] as List).cast<Map<String, dynamic>>()) {
      if (multiplicative.contains(u['kind'])) u['valueGrowth'] = opts.mult;
    }
  }
  var config = RunConfig.fromJson(base);
  if (opts.fitZones != null) {
    // ── 사냥터 표 맞추기 ──
    // 사냥터 k 의 몬스터는 "사냥터 k-1 에서 의도한 일수만큼 키운 전력"으로
    // fitHits 대에 죽고, 한 대가 최대 체력의 fitBite 만큼이 되게 잡는다.
    // 골드는 사냥터마다 fitGoldStep 배. 그 표를 넣고 일반 시뮬로 검증한다.
    final days = opts.fitZones!;
    final hp = <double>[], th = <double>[], gd = <double>[], bh = <double>[];
    final fit = _Player(config, const [])..fitting = true;
    void apply() {
      base['zoneHp'] = hp;
      base['zoneThreat'] = th;
      base['zoneGold'] = gd;
      base['zoneBossHp'] = bh;
      config = RunConfig.fromJson(base);
      fit.config = config;
    }

    for (var k = 1; k <= config.zonesPerTier; k++) {
      // ── 사냥터 하나를 맞추는 순서 ──
      // ⚠️ **일반 몬스터는 도착했을 때의 전력**에, **보스는 머물고 난 뒤의
      // 전력**에 맞춘다. 2026-09-14 에 둘 다 "머문 뒤"로 맞췄다가 게임이
      // 시작부터 막혔다 — 사냥터 1 의 첫 몬스터가 신규 유저에게 381대,
      // 한 대가 체력의 346% 였다. 도착하면 잡을 수는 있어야 골드가 돌고,
      // 골드가 돌아야 강화를 사서 보스를 넘는다. **벽은 보스 하나뿐이다.**
      final entry = fit.stats;
      hp.add((baselineHitPower(entry) * opts.fitHits).roundToDouble());
      // 위협도 **도착 시점 맷집** 기준 — 한 대가 그때 체력의 fitBite 다.
      // 머무는 동안 체력·방어를 올리면 그만큼 가벼워진다(성장 실감).
      final entryTough = entry.maxHp * (100 + entry.defense) / 100;
      th.add(
        (opts.fitBite * entryTough / config.enemyAtkInterval * 100).round() /
            100,
      );
      bh.add(
        (baselineHitPower(entry, boss: true) * opts.fitHits * 4)
            .roundToDouble(),
      );
      gd.add(
        k == 1
            ? config.goldBase
            : (gd.last * opts.fitGoldStep * 100).round() / 100,
      );
      apply();
      fit.stage = config.zoneStartStage(k);
      fit.playDays(days[(k - 1).clamp(0, days.length - 1)]);

      // 보스만 "머문 뒤 전력"으로 확정 — 도착 직후엔 못 잡고, 의도한 만큼
      // 키우면 딱 넘어가는 관문이 된다.
      final st = fit.stats;
      final bossHit = baselineHitPower(st, boss: true);
      bh[k - 1] = (bossHit * opts.fitHits * 4).roundToDouble();
      apply();
      double biteOf(CharacterStats x) =>
          th[k - 1] *
          config.enemyAtkInterval *
          100 /
          (100 + x.defense) /
          x.maxHp *
          100;
      stdout.writeln(
        '  fit 사냥터 $k: 체력 ${hp[k - 1].toStringAsFixed(0)} '
        '(도착 ${opts.fitHits.toStringAsFixed(0)}대 → 떠날 때 '
        '${(hp[k - 1] / baselineHitPower(st)).toStringAsFixed(1)}대) '
        '· 보스 ${bh[k - 1].toStringAsFixed(0)} '
        '(도착 ${(bh[k - 1] / baselineHitPower(entry, boss: true)).toStringAsFixed(0)}대 '
        '→ 떠날 때 ${(bh[k - 1] / bossHit).toStringAsFixed(0)}대) '
        '· 한 대 ${biteOf(entry).toStringAsFixed(0)}% → '
        '${biteOf(st).toStringAsFixed(0)}% · 골드 ${gd[k - 1]}',
      );
    }
    stdout.writeln('');
    stdout.writeln('── run_config.json 에 넣을 표 ──');
    stdout.writeln(' "zoneHp": ${jsonEncode(hp)},');
    stdout.writeln(' "zoneBossHp": ${jsonEncode(bh)},');
    stdout.writeln(' "zoneThreat": ${jsonEncode(th)},');
    stdout.writeln(' "zoneGold": ${jsonEncode(gd)},');
    stdout.writeln('');
    // 아래 일반 시뮬은 맞춘 표로 돈다.
  }
  if (opts.fitTiers) {
    config = _fitTiers(base, config, opts);
    // 맞춘 표로 네 난이도를 이어서 검증한다.
    _tierRuns = _targets.tierDays.length;
    _tier = 0;
  }
  // 캠페인 끝: 월드 구조면 --worlds(기본 10)개 월드, 아니면 지역×스테이지.
  // 사냥터 구조(2026-09-14): 사냥터 k = 스테이지 (k-1)×worldSize+1. 마지막
  // 사냥터(최종 보스)에 닿는 것이 캠페인 끝이다. 표본도 사냥터 시작점으로.
  final finalStage = config.zoneMode
      ? config.zoneStartStage(config.zonesPerTier)
      : config.worldSize > 0
      ? config.worldSize * opts.worlds
      : config.stagesPerRegion * config.regions.length;
  if (config.zoneMode) {
    _samples = [
      for (var z = 1; z <= config.zonesPerTier; z++) config.zoneStartStage(z),
    ];
    _samplesEcon = _samples;
  }

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
  stdout.writeln(
    '  오행 상극        : 곤충 $_petRestrainCount/3 마리'
    ' · 타격 ×${config.petRestrainMult}',
  );
  stdout.writeln('  hpGrowth         : ${config.hpGrowth}');
  stdout.writeln('  goldGrowth       : ${config.goldGrowth}');
  stdout.writeln('  offlineEfficiency: ${config.offlineEfficiency}');
  stdout.writeln(
    '  플레이어 모델     : 활동 ${_activeHoursPerDay}h/일'
    ' + 오프라인 ${_offlineHoursPerDay}h/일',
  );
  stdout.writeln('');
  stdout.writeln('── 현실적 최고치(tool/balance_targets.json → ceiling) ──');
  stdout.writeln(
    '  ${describeCeiling(config, _ceilingData, _targets.ceiling)}',
  );
  stdout.writeln('');

  // 마일스톤: 월드 구조면 월드 경계, 아니면 지역 경계.
  final marks = config.zoneMode
      ? [
          for (var z = 1; z <= config.zonesPerTier; z++)
            config.zoneStartStage(z),
        ]
      : config.worldSize > 0
      ? [for (var i = 1; i <= opts.worlds; i++) i * config.worldSize]
      : [
          for (var i = 1; i <= config.regions.length; i++)
            i * config.stagesPerRegion,
        ];
  // ── 회차 이월 모드(`--tiers=N`) ──────────────────────────────────
  //
  // 회차를 **연속으로** 돌린다. `--tier=` 는 그 회차를 **맨몸으로** 재는 것이라
  // (업그레이드·재화가 0) 실제 경험과 다르다 — 실제로는 1000 을 깬 전력을
  // 그대로 들고 다음 회차 1스테이지로 간다(docs/design_difficulty_loop.md).
  // 그래서 2회차부터는 초반이 훨씬 빠르다. 캠페인 전체 일수를 알려면 이월을
  // 모델링해야 한다.
  if (_tierRuns > 1) {
    final sim = _Player(config, marks);
    var day = 0;
    var total = 0;
    stdout.writeln('── 회차 이월(업그레이드·재화를 그대로 들고 간다) ──');
    for (var t = 0; t < _tierRuns; t++) {
      _tier = t;
      // ⚠️ **프레스티지다.** 성장 축(강화·레벨·경험치)을 처음으로 되돌리고
      // 자산(재화)만 남긴다. 전력을 그대로 들고 가면 2회차부터 이틀이면
      // 끝난다 — 적응형 체력은 "그 스테이지의 기본 체력"을 기준으로 잡아서,
      // 스테이지 1 은 배율을 아무리 곱해도 한 방이 되기 때문이다(실측).
      sim.stage = 1; // careerStage 는 그대로 — 장비·도감·펫은 남는다
      sim._entryPending = true;
      if (t > 0) {
        // 게임의 enterNextTier 와 같다(2026-09-14): 강화·레벨·경험치에 더해
        // **골드·일반 재료**도 처음으로. 남기면 넘어간 즉시 강화를 되사서
        // 회차가 통째로 건너뛰어진다. 공방 레벨·장비·펫·도감은 남는다.
        sim.levels.clear();
        sim.level = 1;
        sim.xp = 0;
        sim.gold = 0;
        sim.materials.clear();
      }
      final from = day;
      if (sim._entryPending) {
        sim.logEntry();
        sim._entryPending = false;
      }
      while (day < _maxDays && sim.stage <= finalStage) {
        day++;
        sim.playDay();
      }
      total = day;
      stdout.writeln(
        '  회차 $t : ${(day - from).toString().padLeft(4)}일'
        ' (누적 $day일) · 마지막 CP ${_short(combatPower(sim.stats))}',
      );
      if (day >= _maxDays) {
        stdout.writeln('  ⚠️ $_maxDays일 상한에 걸렸다 — 더 걸린다는 뜻이다.');
        break;
      }
    }
    // `--endgame-days=N` : 극한을 깬 뒤 최종 사냥터에서 N 일 더 논다 — 공방처럼
    // 90일 계획 밖의 **후반 목표**가 언제 닿는지 본다.
    if (_endgameDays > 0) {
      stdout.writeln('  ── 극한 이후(최종 사냥터에서 계속) ──');
      var lastForge = sim.forgeLevel;
      for (var d = 1; d <= _endgameDays; d++) {
        sim.stage = config.zoneStartStage(config.zonesPerTier);
        sim.fitting = true; // 보스를 다시 넘지 않는다
        sim.playDay();
        if (sim.forgeLevel != lastForge) {
          lastForge = sim.forgeLevel;
          stdout.writeln(
            '  +$d일 : 공방 ${sim.forgeLevel}(화면 ${sim.forgeLevel + 1}등급)'
            ' · 장비 등급 ${sim.gearTier}',
          );
        }
      }
      stdout.writeln(
        '  +$_endgameDays일 끝: 공방 ${sim.forgeLevel}(화면 ${sim.forgeLevel + 1}등급)',
      );
    }
    stdout.writeln('');
    stdout.writeln('  ★ 전 회차 합계: $total일');
    _printBossLog(sim);
    _printEntryLog(sim);
    return;
  }

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
  stdout.writeln('── 타격감(일반 몬스터를 몇 대에 잡나) ──');
  stdout.writeln('  1대 = 스치기만 해도 죽는다(성장할 이유가 안 느껴짐)');
  for (final m in _samplePoints(finalStage)) {
    final h = sim.hitsToKill[m];
    stdout.writeln(
      '  스테이지 ${m.toString().padLeft(4)} : ${h == null ? '미도달' : '$h 대'}',
    );
  }

  // 월드 관문 앞뒤 — "벽이 지점에 있나, 구간에 퍼져 있나"를 본다.
  if (config.worldSize > 0) {
    stdout.writeln('');
    stdout.writeln('── 월드 관문 앞뒤 타격 수 ──');
    stdout.writeln('  (관문에서 확 뛰고 그 뒤로 완만해야 "뚫는 맛"이 난다)');
    for (var w = 1; w < opts.worlds && w <= 5; w++) {
      final last = w * config.worldSize; // x-100 (월드 보스)
      final next = last + 1; // 다음 월드 첫 칸
      final a = sim.hitsToKill[last - 1];
      final b = sim.hitsToKill[next];
      if (a == null || b == null) continue;
      stdout.writeln(
        '  월드 $w 끝(${last - 1}) $a 대  →  월드 ${w + 1} 시작($next) $b 대'
        '  (x${(b / a).toStringAsFixed(1)})',
      );
    }
  }

  stdout.writeln('');
  // ── 재료 수지 ──
  //
  // 재료가 남아돈다는 건 **골드가 병목**이라는 뜻이다. 업그레이드 골드값은
  // 레벨당 1.15~1.30 으로 폭증하는데 재료값은 1.09~1.11 이라 격차가 벌어진다.
  // ── 재료 수지 ──
  //
  // 재료가 남아돈다는 건 **골드가 병목**이라는 뜻이다. 업그레이드 골드값은
  // 레벨당 1.15~1.30 으로 폭증하는데 재료값은 1.09~1.11 이라 격차가 벌어진다.
  stdout.writeln('── 재료 수지(키틴 기준) ──');
  stdout.writeln('  스테이지 |     번 것 |    남은 것 | 미사용 | 남은골드');
  for (final m in _samplesEcon) {
    final v = sim.matAt[m];
    if (v == null) continue;
    final pct = v.earned <= 0 ? 0.0 : v.mat / v.earned * 100;
    stdout.writeln(
      '  ${m.toString().padLeft(7)}  | ${_num(v.earned).padLeft(9)} |'
      ' ${_num(v.mat).padLeft(10)} | ${pct.toStringAsFixed(0).padLeft(5)}% |'
      ' ${_num(v.gold).padLeft(8)}',
    );
  }
  stdout.writeln('');

  stdout.writeln('── 골드 수입(공방 같은 새 소비처의 규모 기준) ──');
  stdout.writeln('  날짜 |     누적 골드 |    그날 하루 수입');
  var prevCum = 0.0;
  for (final d in const [1, 3, 5, 8, 12, 16, 20, 25, 30, 35]) {
    final cum = sim.goldEarnedByDay[d];
    if (cum == null) continue;
    final perDay = cum - prevCum;
    prevCum = cum;
    stdout.writeln(
      '  ${d.toString().padLeft(4)} | ${_num(cum).padLeft(13)} |'
      ' ${_num(perDay).padLeft(17)}',
    );
  }
  stdout.writeln('');

  stdout.writeln('── 처치 속도(화석 조각이 시간당 얼마나 들어오나) ──');
  stdout.writeln('  스테이지 |  타격 |    공속 | 마리당 |  처치/시간 | 고정 드롭 시');
  for (final m in _samples) {
    final sec = sim.secPerKill[m];
    final h = sim.hitsToKill[m];
    if (sec == null || h == null) continue;
    final perHour = 3600 / sec;
    final spd = h / (sec - 0.6);
    stdout.writeln(
      '  ${m.toString().padLeft(7)}  | ${h.toString().padLeft(4)}대 |'
      ' x${spd.toStringAsFixed(1).padLeft(5)} | ${sec.toStringAsFixed(1).padLeft(5)}초 |'
      ' ${perHour.toStringAsFixed(0).padLeft(9)} |'
      ' ${(perHour * 0.2).toStringAsFixed(0).padLeft(6)}개',
    );
  }
  stdout.writeln('');

  stdout.writeln('── 보스전 생존(위협이 실제로 위협인가) ──');
  stdout.writeln('  스테이지 | 잡는 시간 | 버티는 시간 | 판정');
  for (final m in _samples) {
    final v = sim.survivalAt[m];
    if (v == null) continue;
    final verdict = v.live.isInfinite
        ? '위협 없음'
        : (v.live > v.kill * 2
              ? '여유'
              : (v.live > v.kill ? '빠듯 — 좋다' : '못 잡음(벽)'));
    stdout.writeln(
      '  ${m.toString().padLeft(7)} | ${v.kill.toStringAsFixed(1).padLeft(8)}초 |'
      ' ${(v.live.isInfinite ? "무한" : "${v.live.toStringAsFixed(0)}초").padLeft(10)} |'
      ' $verdict',
    );
  }
  stdout.writeln('');

  stdout.writeln('── 서식지 수지(한 스테이지에서 피가 닳나) ──');
  stdout.writeln('  맞은 양 · 회복한 양 모두 **최대 체력 대비 %**.');
  stdout.writeln('  회복이 크면 위협도를 올려도 안 닳아 체력·방어·회복 투자가 죽는다.');
  stdout.writeln('  스테이지 |   맞은 양 |   회복한 양 |   수지 | 판정');
  for (final m in _samples) {
    final v = sim.habitatBudget[m];
    if (v == null) continue;
    final net = v.heal - v.dmg;
    // 판정 기준은 **수지**(최대 체력 몇 개분이 남거나 모자라나)다.
    //   0 근처  = 한 스테이지를 지나도 체력이 안 줄어든다 → 방어·회복이 죽는다
    //   -0.2~-1.2 = 스테이지 하나에 체력 0.2~1.2개분이 빈다. 순항에선 버티고
    //               벽(관문 직후)에서는 죽는다 — 이게 목표다
    //   -1.5 미만 = 순항 구간에서도 반복해 죽어 진행이 막힌다
    final verdict = v.dmg <= 0
        ? '위협 없음'
        : (net > -0.05 ? '안 닳음 ← 문제' : (net >= -1.2 ? '빠듯 — 좋다' : '너무 닳음 ← 벽'));
    stdout.writeln(
      '  ${m.toString().padLeft(7)} |'
      ' ${(v.dmg * 100).toStringAsFixed(0).padLeft(7)}% |'
      ' ${(v.heal * 100).toStringAsFixed(0).padLeft(9)}% |'
      ' ${(net * 100).toStringAsFixed(0).padLeft(5)}% | $verdict',
    );
  }
  stdout.writeln('');

  stdout.writeln('── 체력 궤적(죽을 듯 말 듯인가) ──');
  stdout.writeln('  한 대 = 일반 몬스터 한 대(최대 체력 대비). 최저 = 스테이지 중 가장 낮았던 체력.');
  stdout.writeln('  목표: 순항에서 최저 20~50% 를 오가고 죽지는 않는다. 벽에서는 죽는다.');
  stdout.writeln('  스테이지 |  한 대 |  최저 |  끝 | 판정');
  // 관문(100·200·400·1000)은 벽이라 죽는 게 맞다 — 순항 구간을 따로 본다.
  for (final m in _samples) {
    final v = sim.hpTrajectory[m];
    if (v == null) continue;
    final verdict = v.dead
        ? '죽음 ← 벽'
        : (v.low > 0.6 ? '밋밋함 ← 문제' : (v.low >= 0.15 ? '아슬아슬 — 좋다' : '간신히'));
    stdout.writeln(
      '  ${m.toString().padLeft(7)} |'
      ' ${(v.hit * 100).toStringAsFixed(0).padLeft(5)}% |'
      ' ${(v.low * 100).toStringAsFixed(0).padLeft(4)}% |'
      ' ${(v.end * 100).toStringAsFixed(0).padLeft(3)}% | $verdict',
    );
  }
  stdout.writeln('');

  stdout.writeln('── 업그레이드가 막힌 이유(구간별) ──');
  stdout.writeln('  재료가 100% 면 재료만 모으는 게임, 0% 면 재료가 장식이다.');
  for (final m in _samplesEcon) {
    final b = sim.blockedAt[m];
    if (b == null) continue;
    final tot = b.gold + b.mat;
    final pct = tot == 0 ? 0.0 : b.mat / tot * 100;
    stdout.writeln(
      '  스테이지 ${m.toString().padLeft(4)} : 재료 때문 '
      '${pct.toStringAsFixed(0).padLeft(3)}%  (골드 ${b.gold} · 재료 ${b.mat})',
    );
  }
  stdout.writeln('');

  _printBossLog(sim);

  stdout.writeln('── 결과 ──');
  for (final m in marks) {
    final d = sim.reached[m];
    final label = config.zoneMode
        ? '사냥터 ${config.zoneOf(m).toString().padLeft(2)} 도달'
        : '스테이지 ${m.toString().padLeft(3)} 클리어';
    stdout.writeln('  $label: ${d == null ? "미도달" : _days(d)}');
  }
  if (sim.stage > finalStage) {
    stdout.writeln(
      '  ★ 최종 보스(스테이지 $finalStage): '
      '${_days(sim.reached[finalStage] ?? sim.elapsedDays)}',
    );
  } else {
    stdout.writeln('  ★ $_maxDays일 안에 미도달 (스테이지 ${sim.stage}에서 정체)');
  }

  // 끝났을 때 각 업그레이드가 어디까지 올랐나 — 상한(`maxLevel`)을 정할 때
  // 이 값이 기준선이다. 자연스럽게 닿는 레벨보다 낮게 두면 벽이 된다.
  stdout.writeln('');
  stdout.writeln('── 종료 시 업그레이드 레벨 (상한 있으면 /상한) ──');
  for (final kind in config.upgrades.keys) {
    final spec = config.upgrade(kind);
    final lv = sim.levels[kind] ?? 0;
    final cap = spec.maxLevel;
    stdout.writeln(
      '  ${kind.key.padRight(14)} ${lv.toString().padLeft(4)}'
      '${cap == null ? '' : ' / $cap${lv >= cap ? '  ← 상한' : ''}'}',
    );
  }
}

/// 밸런스 목표·최고치 정의(tool/balance_targets.json) — 게임 수치가 아니라 판정 기준.
final _targets = BalanceTargets.load();
final _ceilingData = CeilingData.load();

/// ── 난이도 4개 표 맞추기(`--fit-tiers`) ──
///
/// 난이도 t 마다:
///  1. 일정: tierDays[t] 일을 사냥터 11개에 **뒤로 갈수록 조금씩 길게** 나눈다.
///  2. 골드 규모(사냥터 1 의 처치당 골드)를 **이분 탐색**한다 — 그 난이도가 끝날 때
///     **강화 채움**이 finalBossPowerPct[t] 에 닿게. 채움 평균으로 맞추면 이월되는
///     장비·펫·도감이 넘쳐 강화를 거의 안 사도 목표를 넘는다(2026-09-15 첫 시도:
///     보통부터 골드 0 · 강화 26%). 강화는 회차마다 초기화되는 유일한 축이라
///     "이번 회차에서 키웠다"의 잣대가 된다. 채움 평균은 결과로 보고한다.
///  3. 사냥터마다 기존 fit 규칙: 일반 몬스터·위협은 **도착 전력**, 보스는 **머문 뒤 전력**.
///  4. 강화·레벨·골드·재료를 초기화하고 다음 난이도로(장비·펫·도감·공방은 이월).
RunConfig _fitTiers(Map<String, dynamic> base, RunConfig config, _Opts opts) {
  // `--fit-days=` 가 있으면 표를 뽑을 때만 그 일정을 쓴다. 이어서 돌리면 회차
  // 사이 이월 때문에 일정이 어긋나므로, 목표 일수가 나오게 한 번 보정할 때 쓴다.
  final days = opts.fitDays ?? _targets.tierDays;
  final goals = _targets.finalBossPowerPct;
  final adapt = [
    for (final v in (_targets.raw['tierThreatAdaptMult'] as List? ?? const []))
      (v as num).toDouble(),
  ];
  final tables = <Map<String, dynamic>>[];
  var player = _Player(config, const [])..fitting = true;

  RunConfig withTables(List<Map<String, dynamic>> t) {
    base['zoneTiers'] = t;
    return RunConfig.fromJson(base);
  }

  for (var t = 0; t < days.length; t++) {
    _tier = t;
    if (t > 0) {
      player
        ..stage = 1
        ..levels.clear()
        ..level = 1
        ..xp = 0
        ..gold = 0
        ..materials.clear();
    }
    final n = config.zonesPerTier;
    final weights = [for (var k = 0; k < n; k++) 1 + 0.1 * k];
    final wSum = weights.fold(0.0, (a, v) => a + v);
    final zoneDays = [for (final w in weights) days[t] * w / wSum];

    ({double fill, Map<String, dynamic> table, _Player end}) run(double g1) {
      final p = player.copy();
      final hp = <double>[], th = <double>[], gd = <double>[], bh = <double>[];
      Map<String, dynamic> table() => {
        'hp': hp,
        'bossHp': bh,
        'threat': th,
        'gold': gd,
        if (t < adapt.length) 'threatAdaptMult': adapt[t],
      };
      for (var k = 1; k <= n; k++) {
        final entry = p.stats;
        // 난이도의 **첫 사냥터**는 강화가 막 초기화된 직후라 가장 약하다 —
        // 여기서 죽으면 회차를 넘긴 벌을 받는 셈이다. 몬스터를 절반 대수로,
        // 한 대를 조금 작게(2026-09-15 시뮬: 첫 사냥터만 죽었다).
        final first = k == 1;
        final hitsK = first ? opts.fitHits * 0.5 : opts.fitHits;
        final biteK = first ? opts.fitBite * 0.6 : opts.fitBite;
        hp.add((baselineHitPower(entry) * hitsK).roundToDouble());
        final tough = entry.maxHp * (100 + entry.defense) / 100;
        th.add((biteK * tough / config.enemyAtkInterval * 100).round() / 100);
        gd.add(
          (g1 * math.pow(opts.fitGoldStep, k - 1) * 100).roundToDouble() / 100,
        );
        bh.add(
          (baselineHitPower(entry, boss: true) * opts.fitHits * 4)
              .roundToDouble(),
        );
        p.config = withTables([...tables, table()]);
        p._ceilPetsCache = null;
        p.stage = config.zoneStartStage(k);
        p.playDays(zoneDays[k - 1]);
        // 보스 = **머문 뒤 전력으로 버틸 수 있는 시간 안에 겨우 잡히는** 체력.
        // 위협이 적응형이라 버티는 시간은 전력과 무관하게 거의 일정하다 —
        // 그래서 체력을 그 시간에 맞추면 전력이 조금만 모자라도 못 잡는
        // **확실한 관문**이 된다(타격 수로 잡으면 20초 만에 뚫려 일정이 무너졌다).
        bh[k - 1] = p.bossHpAtLimit(opts.fitBossMargin).roundToDouble();
        p.gold += p.zoneClearGold(k); // 보스를 깨면 받는 클리어 보상
      }
      return (fill: p._upgradeFill, table: table(), end: p);
    }

    // 로그 공간 이분 탐색. 골드를 아무리 줘도 못 닿거나(강화·장비가 꽉 차도
    // 펫·도감 곡선이 모자람) 아무리 줄여도 넘으면 끝값을 쓰고 알린다.
    var lo = math.log(1e-3), hi = math.log(1e9);
    var best = run(math.exp(hi));
    if (best.fill < goals[t]) {
      stdout.writeln(
        '  ⚠️ 난이도 $t: 골드를 최대로 줘도 강화 채움 '
        '${(best.fill * 100).toStringAsFixed(1)}% < 목표 '
        '${(goals[t] * 100).toStringAsFixed(0)}% — 펫·도감 곡선이나 목표를 봐야 한다',
      );
    } else {
      for (var i = 0; i < 18; i++) {
        final mid = (lo + hi) / 2;
        final r = run(math.exp(mid));
        if (r.fill < goals[t]) {
          lo = mid;
        } else {
          hi = mid;
          best = r;
        }
      }
    }
    tables.add(best.table);
    player = best.end;
    final g = best.table['gold'] as List<double>;
    stdout.writeln(
      '  fit 난이도 $t: ${days[t].toStringAsFixed(0)}일 · 채움 '
      '${(best.fill * 100).toStringAsFixed(1)}%(강화) · 평균 '
      '${(player.fillAverage * 100).toStringAsFixed(1)}% (목표 '
      '${(goals[t] * 100).toStringAsFixed(0)}%) · 골드 ${_short(g.first)}→'
      '${_short(g.last)} · 공방 ${player.forgeLevel} · 장비등급 ${player.gearTier}'
      ' · 채움 ${player._fillByAxis.values.map((v) => (v * 100).toStringAsFixed(0)).join('·')}',
    );
  }

  stdout.writeln('');
  stdout.writeln('── run_config.json 에 넣을 표(zoneTiers) ──');
  stdout.writeln(' "zoneTiers": ${jsonEncode(tables)},');
  stdout.writeln('');
  return withTables(tables);
}

/// 사냥터 도착 직후 — 일반 몬스터 20마리를 버티나. 벽은 보스뿐이어야 한다.
void _printEntryLog(_Player sim) {
  if (sim.entryLog.isEmpty) return;
  stdout.writeln('── 사냥터 도착 직후(일반 몬스터 20마리) ──');
  stdout.writeln('  목표: 몇 대 4~12 · 한 대 8~20% · 최저 15% 이상 · 죽지 않는다');
  stdout.writeln('  회차·사냥터 |  몇 대 | 한 대 |  최저 | 판정');
  for (final e in sim.entryLog) {
    final verdict = e.dead
        ? '죽음 ← 문제'
        : (e.low < 0.15 ? '간신히' : (e.low > 0.7 ? '밋밋함' : '좋다'));
    stdout.writeln(
      '  ${e.tier}·${e.zone.toString().padLeft(2)}       |'
      ' ${e.hits.toStringAsFixed(1).padLeft(6)} |'
      ' ${(e.bite * 100).toStringAsFixed(0).padLeft(3)}% |'
      ' ${(e.low * 100).toStringAsFixed(0).padLeft(4)}% | $verdict',
    );
  }
  stdout.writeln('');
}

/// 보스를 깬 날과 그때 전력이 최고치의 몇 %였나. 최종 보스 줄에 목표를 붙인다.
void _printBossLog(_Player sim) {
  if (sim.bossLog.isEmpty) return;
  final days = _targets.tierDays;
  final goal = _targets.finalBossPowerPct;
  stdout.writeln('');
  stdout.writeln('── 보스 격파(최고치 대비 전투력) ──');
  stdout.writeln(
    '  회차·사냥터 | 날짜(누적) | 전투력 % | 채움 평균 | 채움(강화·펫·장비·도감) | 곱 기준 축별',
  );
  for (final b in sim.bossLog) {
    final isFinal = b.zone == sim.config.zonesPerTier;
    final axis = b.axis.entries
        .map((e) => (e.value * 100).toStringAsFixed(0))
        .join('·');
    final target = isFinal && b.tier < goal.length
        ? '  ← 목표 ${(goal[b.tier] * 100).toStringAsFixed(0)}% · '
              '${days[b.tier].toStringAsFixed(0)}일'
        : '';
    stdout.writeln(
      '  ${b.tier}·${b.zone.toString().padLeft(2)}${isFinal ? '★' : ' '}     |'
      ' ${b.day.toStringAsFixed(1).padLeft(10)} |'
      ' ${(b.pct * 100).toStringAsFixed(1).padLeft(9)}% |'
      ' ${(b.fill.values.fold(0.0, (a, v) => a + math.min(1.0, v)) / b.fill.length * 100).toStringAsFixed(0).padLeft(7)}% |'
      ' ${b.fill.values.map((v) => (v * 100).toStringAsFixed(0)).join('·').padRight(22)} |'
      ' 공방 ${b.forge.toString().padLeft(2)}·장비등급 ${b.gearTier} | $axis$target',
    );
  }
  stdout.writeln('');
}

/// 하루 = 활동 + 오프라인 시간. 소수 일수를 사람이 읽는 표기로.
/// 큰 수를 읽기 쉽게(1234567 → 1.2M).
String _num(double v) {
  if (v >= 1e9) return '${(v / 1e9).toStringAsFixed(1)}B';
  if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
  if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(1)}K';
  return v.toStringAsFixed(0);
}

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

  /// 사냥터 표를 맞추는 동안 사냥터마다 새 표를 넣으므로 바꿀 수 있어야 한다.
  RunConfig config;

  /// 표를 맞추는 중 — 보스를 잡을 수 있어도 자동으로 안 넘어간다(일정대로 머문다).
  bool fitting = false;

  /// [days] 일만큼(소수 가능) 논다. 활동·오프라인 비율은 [playDay] 와 같다.
  void playDays(double days) {
    var left = days;
    while (left > 0) {
      final d = left < 1 ? left : 1.0;
      left -= d;
      gold += _dailyBonusGold * d;
      _goldEarned += _dailyBonusGold * d;
      _online = true;
      _run(_activeHoursPerDay * 3600 * d, 1.0);
      _online = false;
      _run(_offlineHoursPerDay * 3600 * d, config.offlineEfficiency);
      _forgeDays(d);
    }
  }

  /// 도달 시각을 기록할 스테이지들.
  final List<int> marks;

  /// 스테이지 → 도달 시점(소수 일수).
  final Map<int, double> reached = {};

  /// 스테이지 → 그 시점에 **일반 몬스터를 몇 대 때려야 죽었는지**.
  ///
  /// 방치 게임의 '타격감'은 이 값이 결정한다. 1이면 스치기만 해도 죽어서
  /// 성장할 이유가 안 느껴지고, 너무 크면 진행이 답답하다.
  final Map<int, int> hitsToKill = {};

  /// 스테이지별 생존 지표 — (보스 잡는 시간, 버티는 시간).
  final Map<int, ({double kill, double live})> survivalAt = {};

  /// 스테이지별 **서식지 수지** — 한 스테이지를 지나는 동안 맞은 양과 회복한 양
  /// (최대 체력 대비 비율). 보스가 아니라 **일반 몬스터 구간**을 잰다.
  ///
  /// 여기가 균형의 핵심이다: 회복이 피격보다 크면 위협도를 아무리 올려도
  /// 체력이 안 닳아 체력·방어·회복 업그레이드가 통째로 죽는다. 반대로 너무
  /// 크면 순항 구간에서도 계속 죽는다. 목표는 **순항에선 안 죽고 벽에서는
  /// 죽는다** — 즉 피격이 회복보다 조금 크다.
  final Map<int, ({double dmg, double heal})> habitatBudget = {};

  /// 스테이지별 **체력 궤적** — 한 스테이지를 마리 단위로 따라가며
  /// (맞고 → 잡고 회복) 체력이 어디까지 내려갔다가 어디서 끝나는지.
  /// 수지(합계)는 같아도 궤적은 다르다: 천천히 미끄러지는 것과
  /// 30~60% 를 오르내리는 것은 같은 수지에서 전혀 다른 게임이다.
  ///   hit   = 일반 몬스터 한 대(최대 체력 대비)
  ///   low   = 스테이지 중 가장 낮았던 체력
  ///   end   = 보스까지 끝낸 뒤 체력
  ///   dead  = 도중에 0 에 닿았나
  final Map<int, ({double hit, double low, double end, bool dead})>
  hpTrajectory = {};

  /// 날짜별 누적 골드 획득 — 공방 같은 새 소비처의 규모를 정할 때 쓴다.
  final Map<int, double> goldEarnedByDay = {};
  double _goldEarned = 0;

  /// 그 스테이지에서 **한 마리를 잡는 데 걸리는 초**(공속·걷기 포함).
  /// 화석 조각처럼 "처치당 지급"하는 재화가 시간당 얼마나 들어오는지의 기준.
  final Map<int, double> secPerKill = {};

  /// 지금까지 흘린 시뮬레이션 시간(일). 하루 = 활동 + 오프라인.
  double elapsedDays = 0;

  int stage = 1;

  /// 지금이 활동(접속) 구간인지 — 접속 보너스 적용 여부.
  bool _online = false;

  /// 직전 슬라이스의 스테이지 — 그 사이 구간을 클리어로 기록한다.
  int prevStage = 1;
  double gold = 0;
  int level = 1;

  /// **여태 가장 멀리 간 스테이지**(회차를 넘어가도 안 줄어든다).
  ///
  /// ⚠️ 장비·도감·펫은 프레스티지에서 **남는 자산**이다. 그런데 이 모델은
  /// 그것들을 `stage` 에 비례해 붙이고 있어서, 회차가 스테이지를 1 로
  /// 되돌리면 **장비를 잃은 것처럼** 계산됐다(2026-08-30). 남는 것은 남는
  /// 진행도를 기준으로 세야 한다.
  int careerStage = 1;
  int xp = 0;
  final Map<UpgradeKind, int> levels = {};
  final Map<MaterialKind, double> materials = {};

  /// 지금까지 **번** 재료 누계(남은 양과 비교해 미사용 비율을 본다).
  final Map<MaterialKind, double> earnedMaterials = {};

  /// 업그레이드를 못 산 이유 집계 — **체감**은 재고가 아니라 "뭐가 막았나"다.
  /// 재고 스냅샷은 방금 지른 직후냐 아니냐로 크게 튀어 지표로 못 쓴다.
  final Map<int, ({int gold, int mat})> blockedAt = {};
  int _blockGold = 0;
  int _blockMat = 0;

  /// 스테이지 체크포인트에서의 (남은 재료, 남은 골드) — 어디서 남아도는지 본다.
  final Map<int, ({double mat, double gold, double earned})> matAt = {};

  /// 보스를 깬 기록 — (회차, 사냥터, 날짜, 최고치 대비 %, 축별 %, 강화 채움).
  final List<
    ({
      int tier,
      int zone,
      double day,
      double pct,
      Map<String, double> axis,
      double upgradeFill,
      Map<String, double> fill,
      int forge,
      int gearTier,
    })
  >
  bossLog = [];

  /// 항목별 **채움률**(0~1) — 곱하지 않고 각 항목이 최고치까지 얼마나 왔나.
  ///   강화 = 레벨 합 / maxLevel 합
  ///   펫   = (펫 공격 배율 - 1) / (최고치 배율 - 1)
  ///   장비 = 장비만 뗀 전투력 이득 / 최고치 장비의 이득 (넘으면 100% 초과)
  ///   도감 = 정복 종 / 전 종
  Map<String, double> get _fillByAxis {
    final top = ceilingParts(
      config,
      _ceilingData,
      _targets.ceiling,
      level: level,
    );
    final me = powerParts;
    double gearGain(Map<ItemOptionKind, double> gear) {
      final base = (
        upgrades: top.upgrades,
        level: top.level,
        petAttackMult: top.petAttackMult,
        petHpMult: top.petHpMult,
        gear: const <ItemOptionKind, double>{},
        dexConquered: top.dexConquered,
      );
      final withGear = (
        upgrades: top.upgrades,
        level: top.level,
        petAttackMult: top.petAttackMult,
        petHpMult: top.petHpMult,
        gear: gear,
        dexConquered: top.dexConquered,
      );
      return combatPower(composeStats(config, _ceilingData, withGear)) /
              combatPower(composeStats(config, _ceilingData, base)) -
          1;
    }

    final topGear = gearGain(top.gear);
    return {
      '강화': _upgradeFill,
      '펫': _petFill,
      '장비': topGear <= 0 ? 0 : gearGain(me.gear) / topGear,
      '도감': me.dexConquered / _ceilingData.speciesCount,
    };
  }

  /// 강화 레벨 합 / maxLevel 합 — "강화를 얼마나 채웠나"(참고용).
  double get _upgradeFill {
    var have = 0, cap = 0;
    for (final e in config.upgrades.entries) {
      final m = e.value.maxLevel;
      if (m == null) continue;
      cap += m;
      have += math.min(m, levels[e.key] ?? 0);
    }
    return cap == 0 ? 0 : have / cap;
  }

  /// 최고치와 **같은 조립**으로 넣을 이 유저의 재료(power_ceiling.dart).
  /// 버프·탭 부스트·종 패시브는 뺀다 — 최고치에도 없다.
  PowerParts get powerParts => (
    upgrades: Map.of(levels),
    level: level,
    petAttackMult: petAttackMult,
    petHpMult: 1 + (_ceilPets.petHpMult - 1) * _petFill,
    gear: gear,
    dexConquered: dexConquered,
  );

  // ── 펫·도감: 날짜별 가정 곡선(balance_targets.json → accumulation) ──
  // ⚠️ 가정이다 — 브리딩 타이머·훈련 골드·돌파로 실제로 닿는지 따로 검증한다.
  PowerParts get _ceilPets => _ceilPetsCache ??= ceilingParts(
    config,
    _ceilingData,
    _targets.ceiling,
    level: 1,
  );
  PowerParts? _ceilPetsCache;

  double get _petFill => _targets.curveAt('petFillByDay', elapsedDays);

  /// 펫 공격 배율 — 최고치 배율까지 채움만큼.
  double get petAttackMult => 1 + (_ceilPets.petAttackMult - 1) * _petFill;

  int get dexConquered =>
      (_ceilingData.speciesCount *
              _targets.curveAt('dexFillByDay', elapsedDays))
          .round();

  // ── 장비: 공방 규칙으로 계산 ──
  //
  // 처치 골드의 일부로 공방을 올리고(골드 + 타이머), 그 레벨의 등급 확률로
  // 하루 화석만큼 뽑아 부위마다 **가장 좋은 것**을 낀다. 옵션 값은 같은 등급을
  // N 번 뽑았을 때의 최고 백분위(N/(N+1))로 본다.
  int forgeLevel = 0;
  double forgeFund = 0;

  /// 진행 중인 공방 등급업이 끝나는 날(없으면 null).
  double? forgeUpUntil;

  /// 부위 하나당 등급별 "쓸 만한 장비" 누적 개수.
  final List<double> gearDraws = List.filled(_ceilingData.items.tierCount, 0.0);

  /// 지금 끼고 있는 장비의 옵션 합(%).
  Map<ItemOptionKind, double> gear = const {};

  /// 가장 좋은 장비 등급(-1 = 없음).
  int gearTier = -1;

  void _forgeDays(double days) {
    final forge = _ceilingData.forge;
    final items = _ceilingData.items;
    final end = elapsedDays;
    var t = end - days;
    while (forgeLevel < forge.maxLevel) {
      final until = forgeUpUntil;
      if (until != null) {
        if (until > end) break;
        t = math.max(t, until);
        forgeLevel++;
        forgeUpUntil = null;
        continue;
      }
      final cost = forge.levelUpGold(forgeLevel).toDouble();
      if (forgeFund < cost) break;
      forgeFund -= cost;
      forgeUpUntil = t + forge.levelUpDuration(forgeLevel).inSeconds / 86400;
    }

    final acc = _targets.accumulation;
    final fossils =
        (forge.fossilPerSecond * 3600 * _activeHoursPerDay +
            forge.fossilPerSecond *
                forge.fossilOfflineRatio *
                3600 *
                _offlineHoursPerDay) *
        days;
    final w = forge.tierWeights(forgeLevel, items.tierCount);
    final perSlot =
        fossils /
        items.slots.length *
        (acc['forgeUsefulOptionChance'] as num).toDouble();
    for (var i = 0; i < w.length; i++) {
      gearDraws[i] += perSlot * w[i];
    }
    var top = -1;
    for (var i = 0; i < gearDraws.length; i++) {
      if (gearDraws[i] >= 1) top = i;
    }
    gearTier = top;
    if (top < 0) {
      gear = const {};
      return;
    }
    final n = gearDraws[top];
    final roll = math.pow(n / (n + 1), items.optionCurve).toDouble();
    final build =
        (_targets.ceiling['gear'] as Map<String, dynamic>)['build']
            as Map<String, dynamic>;
    final out = <ItemOptionKind, double>{};
    for (final e in build.entries) {
      final kind = ItemOptionKind.fromKey(e.key);
      final r = items.optionPool.firstWhere((x) => x.kind == kind);
      out[kind] =
          (r.min + (r.maxAt(top) - r.min) * roll) *
          (e.value as num).toDouble() *
          _gearScale;
    }
    gear = out;
  }

  /// 오행 상극 — **§7 기준 밖**. 곤충 지분 중 상극이 걸린 몫만큼만 늘어난다.
  /// ⚠️ `baselineStats` 에는 절대 넣지 마라(시뮬 안에서 스스로 상쇄된다).
  double get _restrainMult {
    final petShare = petAttackMult <= 1
        ? 0.0
        : (petAttackMult - 1) / petAttackMult;
    final restrained = petShare * (_petRestrainCount.clamp(0, 3) / 3.0);
    return 1 + restrained * (config.petRestrainMult - 1);
  }

  /// **적응형 기준**(앱의 `_petStats`) — 강화 + 레벨 + 펫 공격.
  ///
  /// 체력은 **캐릭터 몫**만 둔다. 앱에서 곤충 체력은 팀 체력을 늘리지만 그만큼
  /// 캐릭터 몫(`playerHpMult`)이 줄어 캐릭터 체력은 그대로다 — 한 대는
  /// 캐릭터가 받는다.
  CharacterStats get baselineStats {
    final s = _baseStats;
    return CharacterStats(
      attack: s.attack * petAttackMult,
      attackSpeed: s.attackSpeed,
      rewardMultiplier: s.rewardMultiplier,
      critChance: s.critChance,
      critDamage: s.critDamage,
      bossDamage: s.bossDamage,
      maxHp: s.maxHp,
      defense: s.defense,
      hpRegen: s.hpRegen,
      xpMultiplier: s.xpMultiplier,
      bugFind: s.bugFind,
      materialFind: s.materialFind,
      moveSpeed: s.moveSpeed,
      boostBonus: s.boostBonus,
    );
  }

  /// 실제로 몬스터를 때리는 능력치(앱의 `_stats`) — 앱과 같은 순서:
  /// 기준 → 장비 → (종 패시브) → 도감 → 버프·탭 → 치명확률 상한.
  CharacterStats get stats {
    final b = baselineStats;
    var s = CharacterStats(
      attack:
          b.attack *
          _passiveAttackMult *
          _restrainMult *
          _buffDpsMult *
          _tapBoostAvg,
      // 부스트는 공속에도 실린다 — 얼마나 실리는지는 `boostSpeedFactor` 다.
      attackSpeed:
          b.attackSpeed * (1 + (_tapBoostAvg - 1) * config.boostSpeedFactor),
      rewardMultiplier: b.rewardMultiplier,
      critChance: b.critChance,
      critDamage: b.critDamage,
      bossDamage: b.bossDamage,
      maxHp: b.maxHp,
      defense: b.defense,
      hpRegen: b.hpRegen,
      xpMultiplier: b.xpMultiplier,
      bugFind: b.bugFind,
      materialFind: b.materialFind,
      moveSpeed: b.moveSpeed,
      boostBonus: b.boostBonus,
    );
    // ⚠️ 장비의 체력·방어를 **반드시** 태운다(applyEquipment 가 한다). 빼면
    // 시뮬이 "피가 닳는다"고 하는데 실기는 안 닳는다.
    s = applyEquipment(s, gear, critBudget: config.critBudgetGear);
    s = _ceilingData.dex.apply(s, dexConquered, dexConquered);
    return capCritChance(s, config.critChanceMax);
  }

  CharacterStats get _baseStats => deriveStats(
    config,
    upgradeLevels: levels,
    characterLevel: level,
    // 채집함 상한 = 곤충 버프 상한과 같다(§2.1). 상한까지 모았다고 본다.
    bugsCollected: 50,
  );

  void playDay() {
    // 전투 밖 보상(일일·선물·미션·결투)은 하루 한 번 정액으로 넣는다.
    gold += _dailyBonusGold;
    _goldEarned += _dailyBonusGold;
    for (final k in const [
      MaterialKind.chitin,
      MaterialKind.mineral,
      MaterialKind.sap,
    ]) {
      materials[k] = (materials[k] ?? 0) + _dailyBonusMaterials;
      earnedMaterials[k] = (earnedMaterials[k] ?? 0) + _dailyBonusMaterials;
    }
    // 접속 보너스는 **활동 구간에만** — 켜두는 쪽이 이득이어야 한다.
    _online = true;
    _run(_activeHoursPerDay * 3600, 1.0);
    _online = false;
    _run(_offlineHoursPerDay * 3600, config.offlineEfficiency);
    _forgeDays(1);
  }

  /// 회차 시작 직후 도착 기록을 남겨야 하는가(초기화가 끝난 뒤에 잰다).
  bool _entryPending = false;

  /// 사냥터에 **도착했을 때** 일반 몬스터 사냥이 버틸 만한가.
  /// (회차, 사냥터, 몇 대에 잡나, 한 대(최대 체력 %), 20마리 중 최저 체력, 죽었나)
  final List<
    ({int tier, int zone, double hits, double bite, double low, bool dead})
  >
  entryLog = [];

  void logEntry() {
    final st = stats;
    final z = config.zoneOf(stage);
    final hp = habitatMaxHp(
      config,
      stage - 1,
      playerAttack: baselineHitPower(baselineStats),
      tier: _tier,
    ).toDouble();
    final hit = baselineHitPower(st);
    final dps = hit * st.attackSpeed;
    final fight = dps <= 0 ? 999.0 : hp / dps;
    final walk = 0.6 / (st.moveSpeed <= 0 ? 1.0 : st.moveSpeed);
    final inc =
        habitatThreat(
          config,
          stage - 1,
          playerToughness: toughnessOf(_baseStats),
          gearToughness: toughnessOf(st),
          tier: _tier,
        ) *
        100 /
        (100 + st.defense);
    final max = st.maxHp <= 0 ? 1.0 : st.maxHp;
    // 앱과 같은 리듬: 달라붙고 첫 물기(1배) → 간격마다 따라 물기(followMult)
    // → 처치 회복. 걷는 동안은 walkThreatMult 로 게이지가 찬다.
    final iv = config.enemyAtkInterval;
    final delay = config.enemyFirstBiteDelay;
    var cur = max, low = max, acc = 0.0;
    var dead = false;
    for (var i = 0; i < config.habitatsPerStage && !dead; i++) {
      // 걷기
      var t = 0.0;
      while (t < walk && !dead) {
        final step = math.min(0.25, walk - t);
        cur = math.min(max, cur + st.hpRegen * 2 * step);
        acc += step * config.walkThreatMult;
        if (acc >= iv) {
          acc -= iv;
          cur -= inc * iv * config.enemyFollowBiteMult;
        }
        t += step;
      }
      // 싸움
      var bitten = delay <= 0;
      t = 0;
      while (t < fight && !dead) {
        final step = math.min(0.25, fight - t);
        cur = math.min(max, cur + st.hpRegen * step);
        acc += step;
        if (!bitten && t + step >= delay) {
          bitten = true;
          acc = 0;
          cur -= inc * iv;
        } else if (acc >= iv) {
          acc -= iv;
          cur -= inc * iv * config.enemyFollowBiteMult;
        }
        if (cur < low) low = cur;
        if (cur <= 0) dead = true;
        t += step;
      }
      if (!bitten && !dead) cur -= inc * iv; // 죽으면서 무는 한 대
      if (cur < low) low = cur;
      if (cur <= 0) dead = true;
      if (!dead) cur += killHealAmount(config, hp: cur, maxHp: max);
    }
    entryLog.add((
      tier: _tier,
      zone: z,
      hits: hit <= 0 ? 0 : hp / hit,
      bite: inc * iv / max,
      low: math.max(0.0, low) / max,
      dead: dead,
    ));
  }

  /// 사냥터 [zone] 클리어 보상(앱 `chapterClearGold` 와 같은 식 — 로드맵 없이 사냥터로 잰다).
  double zoneClearGold(int zone) {
    if (config.chapterClearHours <= 0) return 0;
    return rewardGold(
          config,
          config.zoneStartStage(zone) - 1,
          1.0,
          tier: _tier,
        ) *
        config.exchangeKillsPerHour *
        config.chapterClearHours;
  }

  /// 표를 맞출 때 같은 출발점에서 여러 번 굴려 보려고 상태를 복제한다.
  /// 기록(도달·타격 수 등)은 복제하지 않는다 — 판정에 쓰지 않는다.
  _Player copy() {
    final c = _Player(config, marks)
      ..fitting = fitting
      ..stage = stage
      ..prevStage = prevStage
      ..gold = gold
      ..level = level
      ..careerStage = careerStage
      ..xp = xp
      ..elapsedDays = elapsedDays
      ..forgeLevel = forgeLevel
      ..forgeFund = forgeFund
      ..forgeUpUntil = forgeUpUntil
      ..gear = Map.of(gear)
      ..gearTier = gearTier
      .._zoneKills = _zoneKills
      .._goldEarned = _goldEarned;
    c.levels.addAll(levels);
    c.materials.addAll(materials);
    c.earnedMaterials.addAll(earnedMaterials);
    for (var i = 0; i < gearDraws.length; i++) {
      c.gearDraws[i] = gearDraws[i];
    }
    return c;
  }

  /// 채움 평균(각 항목 100% 에서 자른다).
  double get fillAverage {
    final f = _fillByAxis;
    return f.values.fold(0.0, (a, v) => a + math.min(1.0, v)) / f.length;
  }

  /// 사냥터 모드의 보스 도전 게이지(처치 수).
  double _zoneKills = 0;

  /// 지금 전력으로 [_bossBeatable] 을 **딱 통과하는** 보스 체력 × [margin].
  double bossHpAtLimit(double margin) {
    final st = stats;
    final dps = baselineHitPower(st, boss: true) * st.attackSpeed;
    final inc =
        habitatThreat(
          config,
          stage - 1,
          boss: true,
          playerToughness: toughnessOf(_baseStats),
          gearToughness: toughnessOf(st),
          tier: _tier,
        ) *
        100 /
        (100 + st.defense);
    final net = inc - st.hpRegen;
    final live = net <= 0 ? double.infinity : st.maxHp / net;
    final limit = math.min(_bossPatienceSeconds, live / 1.1);
    return dps * limit * margin;
  }

  /// 지금 전력으로 [stage] 의 보스를 잡을 수 있나 — 죽이는 시간 < 버티는 시간.
  /// 앱의 도전 판단(유저가 누른다)을 시뮬이 대신한다. 너무 오래 걸리면(120초)
  /// 유저도 안 누른다고 본다.
  bool _bossBeatable(int stage) {
    final st = stats;
    final bossHit = baselineHitPower(st, boss: true);
    final baseBoss = baselineHitPower(baselineStats, boss: true);
    final hp = bossMaxHp(
      config,
      stage - 1,
      playerAttack: baseBoss,
      tier: _tier,
    ).toDouble();
    final dps = bossHit * st.attackSpeed;
    if (dps <= 0) return false;
    final kill = hp / dps;
    if (kill > _bossPatienceSeconds) return false;
    final inc =
        habitatThreat(
          config,
          stage - 1,
          boss: true,
          playerToughness: toughnessOf(_baseStats),
          gearToughness: toughnessOf(st),
          tier: _tier,
        ) *
        100 /
        (100 + st.defense);
    final net = inc - st.hpRegen;
    final live = net <= 0 ? double.infinity : st.maxHp / net;
    return live > kill * 1.1;
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
        // ⚠️ **진행을 결정하는 건 이 호출이다.** 여기 회차를 안 넘기면
        // 통계만 회차를 반영하고 실제 속도는 그대로여서, 배율을 아무리
        // 바꿔도 결과가 안 변한다(2026-08-30 에 실제로 그랬다).
        tier: _tier,
      );
      elapsedDays += slice / 3600 / (_activeHoursPerDay + _offlineHoursPerDay);
      for (final m in _samplesEcon) {
        if (prevStage < m && stage >= m) {
          blockedAt[m] = (gold: _blockGold, mat: _blockMat);
          _blockGold = 0;
          _blockMat = 0;
          matAt[m] = (
            mat: materials[MaterialKind.chitin] ?? 0,
            gold: gold,
            earned: earnedMaterials[MaterialKind.chitin] ?? 0,
          );
        }
      }
      prevStage = stage;
      stage = prog.newStage;
      // ── 사냥터 모드: 게이지가 차고 보스를 잡을 수 있으면 다음 사냥터 ──
      // 방치 정산(simulateIdleProgress)은 사냥터 안에서 스테이지를 밀지 않는다.
      // "잡을 수 있다" = 보스를 죽이는 시간이 버티는 시간보다 짧다(앱의 도전
      // 버튼을 누르는 판단을 시뮬이 대신한다). 최종 보스를 깨면 worldSize 만큼
      // 더 밀어 캠페인 끝을 표시한다.
      if (config.zoneMode && !fitting) {
        _zoneKills += prog.habitatClears;
        if (_zoneKills >= config.bossUnlockKills && _bossBeatable(stage)) {
          final z = config.zoneOf(stage);
          if (z <= config.zonesPerTier) {
            bossLog.add((
              tier: _tier,
              zone: z,
              day: elapsedDays,
              pct: powerPct(config, _ceilingData, _targets.ceiling, powerParts),
              axis: powerPctByAxis(
                config,
                _ceilingData,
                _targets.ceiling,
                powerParts,
              ),
              upgradeFill: _upgradeFill,
              fill: _fillByAxis,
              forge: forgeLevel,
              gearTier: gearTier,
            ));
          }
          // 사냥터 클리어 보상 — 앱과 같은 규모(chapterClearGold: 그 사냥터
          // chapterClearHours 시간치). 빼고 재면 초반이 시뮬보다 빠르다.
          gold += zoneClearGold(z);
          stage = config.isFinalZone(z)
              ? stage + config.worldSize
              : config.zoneStartStage(z + 1);
          _zoneKills = 0;
          if (!config.isFinalZone(z)) logEntry();
        }
      }
      if (stage > careerStage) careerStage = stage;
      // ⚠️ 기록은 **stage 를 갱신한 뒤**에 한다. 갱신 전에 하면 직전 슬라이스의
      // 구간을 적는 셈이라, 하루의 마지막 슬라이스에서 넘은 스테이지는 다음
      // 날에나 기록된다 — 최종 보스를 넘고도 "미도달"로 찍히던 원인(2026-09-09).
      // 모든 스테이지의 클리어 시각을 남긴다 — 곡선 모양(스테이지당 소요)을 보기 위해.
      for (var s = prevStage; s < stage; s++) {
        reached.putIfAbsent(s, () => elapsedDays);
        // 그 스테이지를 지날 때 **실제 스탯으로** 몇 대에 죽었는지.
        hitsToKill.putIfAbsent(s, () {
          // ⚠️ **두 값을 갈라 쓴다.** 몬스터 체력은 기준(장비·버프 제외)으로
          // 자라고, 실제로 때리는 건 그 전부가 실린 값이다. 예전에는 양쪽에
          // 같은 값을 넘겨 버프·장비가 시뮬 안에서 스스로 상쇄됐다.
          final base = baselineHitPower(baselineStats);
          final hit = baselineHitPower(stats);
          final hp = habitatMaxHp(
            config,
            s - 1,
            playerAttack: base,
            tier: _tier,
          );
          return (hp / (hit <= 0 ? 1.0 : hit)).ceil();
        });
        survivalAt.putIfAbsent(s, () {
          final st = stats; // 장비·패시브·도감·버프 포함한 실제 전투 능력치
          final bossHit = baselineHitPower(st, boss: true);
          final baseBoss = baselineHitPower(baselineStats, boss: true);
          final hp = bossMaxHp(
            config,
            s - 1,
            playerAttack: baseBoss,
            tier: _tier,
          ).toDouble();
          final dps = bossHit * st.attackSpeed;
          // 위협 기준은 **영구 전력**(버프 제외) — 앱과 같은 규칙.
          final tough = toughnessOf(_baseStats);
          final inc =
              habitatThreat(
                config,
                s - 1,
                boss: true,
                playerToughness: tough,
                gearToughness: toughnessOf(st),
                tier: _tier,
              ) *
              100 /
              (100 + st.defense);
          final net = inc - st.hpRegen;
          return (
            kill: dps <= 0 ? 0.0 : hp / dps,
            live: net <= 0 ? double.infinity : st.maxHp / net,
          );
        });
        // 서식지 한 스테이지(일반 몬스터 N마리 + 보스)의 피격/회복 수지.
        // 앱과 같은 규칙으로 잰다: 걷는 동안은 **무피해 + 회복 2배**,
        // 처치 회복은 마리마다 최대 체력의 killHealPct.
        habitatBudget.putIfAbsent(s, () {
          final st = stats;
          final hit = baselineHitPower(st);
          final hp = habitatMaxHp(
            config,
            s - 1,
            playerAttack: baselineHitPower(baselineStats),
            tier: _tier,
          );
          final dps = hit * st.attackSpeed;
          final fight = dps <= 0 ? 0.0 : hp / dps;
          final walk = 0.6 / (st.moveSpeed <= 0 ? 1.0 : st.moveSpeed);
          final tough = toughnessOf(_baseStats);
          final inc =
              habitatThreat(
                config,
                s - 1,
                playerToughness: tough,
                gearToughness: toughnessOf(st),
                tier: _tier,
              ) *
              100 /
              (100 + st.defense);
          final bossHit = baselineHitPower(st, boss: true);
          final bossHp = bossMaxHp(
            config,
            s - 1,
            playerAttack: baselineHitPower(baselineStats, boss: true),
          );
          final bossDps = bossHit * st.attackSpeed;
          final bossFight = bossDps <= 0 ? 0.0 : bossHp / bossDps;
          final bossInc =
              habitatThreat(
                config,
                s - 1,
                boss: true,
                playerToughness: tough,
                gearToughness: toughnessOf(st),
                tier: _tier,
              ) *
              100 /
              (100 + st.defense) *
              1.4; // 보스 한 대는 1.4배(앱과 동일)
          final n = config.habitatsPerStage;
          // 이동 중에도 위협이 붙는다(§walkThreatMult). 예전엔 이동이 완전
          // 공짜여서, 몹이 서너 대에 죽는 구간에서 판의 절반이 안전지대였다.
          final dmg =
              inc * (fight + walk * config.walkThreatMult) * n +
              bossInc * bossFight;
          final heal =
              (st.hpRegen * fight + st.hpRegen * 2 * walk) * n +
              st.maxHp * config.killHealPct * n +
              st.hpRegen * bossFight +
              st.maxHp * config.bossKillHealPct;
          final max = st.maxHp <= 0 ? 1.0 : st.maxHp;
          // ── 체력 궤적 ── (앱의 게이지 규칙 그대로: 간격마다 한 대, 게이지
          // 이월, 처치 회복은 killHealAmount)
          hpTrajectory.putIfAbsent(s, () {
            var hp = max;
            var low = max;
            var acc = 0.0;
            var dead = false;
            void tick(
              double sec,
              double incPerSec,
              double interval,
              double mult,
              double regenMul, {
              // 달라붙고 enemyFirstBiteDelay 뒤 반드시 한 대(앱과 같은 규칙).
              // 그 뒤 게이지는 0 부터 — 안 그러면 두 대가 겹친다.
              bool engage = false,
            }) {
              final delay = config.enemyFirstBiteDelay;
              var bitten = !(engage && delay > 0);
              void bite({bool first = false}) {
                final follow = (first || delay <= 0)
                    ? 1.0
                    : config.enemyFollowBiteMult;
                hp -= incPerSec * interval * mult * follow;
                if (hp < low) low = hp;
                if (hp <= 0) dead = true;
              }

              // 회복은 구간에 고르게, 피격은 게이지가 찰 때마다 한 대.
              var t = 0.0;
              while (t < sec && !dead) {
                final step = math.min(0.25, sec - t);
                hp = math.min(max, hp + st.hpRegen * regenMul * step);
                acc += step;
                if (!bitten && t + step >= delay) {
                  bitten = true;
                  acc = 0;
                  bite(first: true);
                } else if (acc >= interval) {
                  acc -= interval;
                  bite();
                }
                t += step;
              }
              // 죽으면서 무는 한 대 — 첫 물기 전에 죽어도 마리당 한 대는 들어간다.
              if (!bitten && !dead) bite(first: true);
            }

            final iv = config.enemyAtkInterval;
            for (var i = 0; i < n && !dead; i++) {
              tick(walk, inc * config.walkThreatMult, iv, 1.0, 2.0);
              tick(fight, inc, iv, 1.0, 1.0, engage: true);
              if (!dead) {
                hp += killHealAmount(config, hp: hp, maxHp: max);
              }
            }
            if (!dead) {
              tick(
                bossFight,
                bossInc / 1.4,
                config.bossAtkInterval,
                config.bossHitMult,
                1.0,
                engage: true,
              );
              if (!dead) {
                hp += killHealAmount(config, hp: hp, maxHp: max, boss: true);
              }
            }
            // 디버그: SIM_DEBUG_STAGE=850 처럼 주면 그 스테이지의 궤적 입력을 찍는다.
            if (Platform.environment['SIM_DEBUG_STAGE'] == '$s') {
              stderr.writeln(
                '[궤적 $s] fight=${fight.toStringAsFixed(2)}s walk=${walk.toStringAsFixed(2)}s '
                'bite=${(inc * iv / max * 100).toStringAsFixed(1)}% '
                'bossFight=${bossFight.toStringAsFixed(1)}s bossBite=${(bossInc / 1.4 * config.bossAtkInterval * config.bossHitMult / max * 100).toStringAsFixed(1)}% '
                'regen/s=${(st.hpRegen / max * 100).toStringAsFixed(2)}% hits=${hitsToKill[s]}',
              );
            }
            return (
              hit: inc * iv / max,
              low: math.max(0.0, low) / max,
              end: math.max(0.0, hp) / max,
              dead: dead,
            );
          });
          return (dmg: dmg / max, heal: heal / max);
        });
        secPerKill.putIfAbsent(s, () {
          final st = stats;
          final hit = baselineHitPower(st);
          final hp = habitatMaxHp(
            config,
            s - 1,
            playerAttack: baselineHitPower(baselineStats),
            tier: _tier,
          );
          final dps = hit * st.attackSpeed;
          return (dps <= 0 ? 0.0 : hp / dps) + 0.6; // 0.6 = 걷는 시간
        });
      }
      final earned =
          prog.gold *
          _buffGoldMult *
          (_online ? 1 + config.onlineGoldBonus : 1.0);
      // 공방이 최대가 아니면 처치 골드의 일부를 공방 등급업에 넣는다.
      final toForge = forgeLevel < _ceilingData.forge.maxLevel
          ? earned * (_targets.accumulation['forgeGoldShare'] as num).toDouble()
          : 0.0;
      forgeFund += toForge;
      gold += earned - toForge;
      _goldEarned += earned;
      goldEarnedByDay[elapsedDays.floor()] = _goldEarned;
      _gainXp(prog.xp);
      // 재료: 처치당 materialDropChance 확률로 평균 1.5개, 3종에 고르게.
      // `chance × find` 를 그대로 곱하는 게 맞다 — 게임은 확률을 1 에서 자르고
      // 넘친 배율을 수량으로 돌리므로(`materialDrop`) 기대값이 정확히 이 값이다.
      // (그 규칙이 들어오기 전엔 확률만 잘려서, 이 시뮬이 재료를 최대 9배
      // 과대계상하고 있었다 — 2026-09-09.)
      //
      // ⚠️ **접속 중에만** 떨어진다. 오프라인 정산(`computeOfflineReward`)은
      // 골드·경험치만 준다 — 여기서 오프라인까지 세면 재료 수입을 40% 넘게
      // 과다 계상한다(실제로 그렇게 재서 "재료가 빠듯하다"는 결론이 나왔다).
      final mats = _online
          ? prog.habitatClears *
                config.materialDropChance *
                stats.materialFind *
                1.5 *
                materialAmountMult(config, prevStage - 1)
          : 0.0;
      for (final k in const [
        MaterialKind.chitin,
        MaterialKind.mineral,
        MaterialKind.sap,
      ]) {
        materials[k] = (materials[k] ?? 0) + mats / 3;
        earnedMaterials[k] = (earnedMaterials[k] ?? 0) + mats / 3;
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

  /// 재료비 — `--mat-cost-growth=` 가 있으면 그 증가율로 계산한다(탐색용).
  double _matCost(UpgradeSpec spec, int lv) {
    final g = _matCostGrowth ?? spec.materialCostGrowth;
    return (spec.materialBaseCost * _matBaseMult * math.pow(g, lv))
        .ceilToDouble();
  }

  /// 살 수 있는 것 중 **가장 싼** 업그레이드를 계속 산다(고르게 성장하는 플레이어).
  void _buyUpgrades() {
    for (var guard = 0; guard < 10000; guard++) {
      UpgradeKind? best;
      var bestCost = double.infinity;
      var goldBlocked = false;
      var matBlocked = false;
      for (final kind in config.upgrades.keys) {
        final spec = config.upgrade(kind);
        final lv = levels[kind] ?? 0;
        // 상한(`maxLevel`)에 닿은 축은 더 안 산다 — 게임과 같은 규칙.
        if (!spec.canBuyAt(lv)) continue;
        final cost = upgradeCost(spec, lv).toDouble();
        final mk = spec.materialKind;
        final matShort =
            mk != null && _matCost(spec, lv) > (materials[mk] ?? 0);
        if (cost > gold) {
          // 골드가 모자란다 — 재료까지 모자라면 그건 재료 탓이 아니다.
          if (!matShort) goldBlocked = true;
          continue;
        }
        if (matShort) {
          // 골드는 있는데 재료가 없어서 못 산다 = **재료가 병목**.
          matBlocked = true;
          continue;
        }
        if (cost >= bestCost) continue;
        best = kind;
        bestCost = cost;
      }
      if (best == null) {
        if (matBlocked) {
          _blockMat++;
        } else if (goldBlocked) {
          _blockGold++;
        }
        return;
      }
      final spec = config.upgrade(best);
      final lv = levels[best] ?? 0;
      gold -= bestCost;
      final mk = spec.materialKind;
      if (mk != null) {
        materials[mk] = (materials[mk] ?? 0) - _matCost(spec, lv);
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
  const _Opts(
    this.overrides,
    this.mult,
    this.worlds, {
    this.fitZones,
    this.fitHits = 8,
    this.fitBite = 0.12,
    this.fitGoldStep = 1.6,
    this.fitTiers = false,
    this.fitBossMargin = 0.95,
    this.fitDays,
  });
  final Map<String, dynamic> overrides;

  /// `--fit-zones=0.1,0.3,…` : 사냥터마다 머무를 **의도한 일수**. 주면 사냥터
  /// 표(zoneHp·zoneThreat·zoneGold)를 그 일정에 맞춰 뽑고 검증까지 돌린다.
  final List<double>? fitZones;
  final double fitHits;
  final double fitBite;
  final double fitGoldStep;

  /// `--fit-tiers` : 네 난이도의 표(zoneTiers)를 balance_targets.json 의 일정·
  /// 채움 목표에 맞춰 뽑고, 그 표로 이어서 검증한다.
  final bool fitTiers;

  /// 보스 체력 = 머문 뒤 전력의 한계 × 이 값. 1 에 가까울수록 일정 끝에 딱 뚫린다.
  final double fitBossMargin;

  /// `--fit-days=14,21,33,24` : 표를 뽑을 때 쓸 난이도별 일정(없으면 목표 일수).
  final List<double>? fitDays;

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
    'mat-amt-growth': 'materialAmountGrowth',
    // 적응형 손잡이 — "몇 대에 죽나"를 JSON 고치기 전에 쓸어보기 위한 것.
    'hits': 'hpAdaptTargetHits',
    'hp-adapt-power': 'hpAdaptPower',
    'hp-adapt-max': 'hpAdaptMaxRatio',
    'threat-pct': 'threatAdaptTargetPct',
    'boost-speed': 'boostSpeedFactor',
    // 회복 축 — 처치 회복(킬 속도에 좌우)과 상시 회복(시간 비례)의 비중.
    'walk-threat': 'walkThreatMult',
    'kill-heal': 'killHealPct',
    'boss-kill-heal': 'bossKillHealPct',
  };
  final out = <String, dynamic>{};
  double? mult;
  var worlds = 10;
  List<double>? fitZones;
  var fitHits = 8.0, fitBite = 0.12, fitGoldStep = 1.6;
  var fitTiers = false;
  var fitBossMargin = 0.95;
  List<double>? fitDays;
  for (final a in args) {
    final fz = RegExp(r'^--fit-zones=(.+)$').firstMatch(a);
    if (fz != null) {
      fitZones = fz.group(1)!.split(',').map(double.parse).toList();
      continue;
    }
    final fdy = RegExp(r'^--fit-days=(.+)$').firstMatch(a);
    if (fdy != null) {
      fitDays = fdy.group(1)!.split(',').map(double.parse).toList();
      continue;
    }
    final fbm = RegExp(r'^--fit-boss-margin=(.+)$').firstMatch(a);
    if (fbm != null) {
      fitBossMargin = double.parse(fbm.group(1)!);
      continue;
    }
    if (a == '--fit-tiers') {
      fitTiers = true;
      continue;
    }
    final fh = RegExp(r'^--fit-hits=(.+)$').firstMatch(a);
    if (fh != null) {
      fitHits = double.parse(fh.group(1)!);
      continue;
    }
    final fb = RegExp(r'^--fit-bite=(.+)$').firstMatch(a);
    if (fb != null) {
      fitBite = double.parse(fb.group(1)!);
      continue;
    }
    final fg = RegExp(r'^--fit-gold-step=(.+)$').firstMatch(a);
    if (fg != null) {
      fitGoldStep = double.parse(fg.group(1)!);
      continue;
    }
    // `--set=키=값` : run_config 의 최상위 값을 아무거나 덮어쓴다(사냥터 계단 탐색용).
    final st = RegExp(r'^--set=([A-Za-z]+)=(.+)$').firstMatch(a);
    if (st != null) {
      final v = st.group(2)!;
      out[st.group(1)!] =
          num.tryParse(v) ??
          (v == 'true'
              ? true
              : v == 'false'
              ? false
              : v);
      continue;
    }
    // `--up=종류.필드=값` : 업그레이드 스펙 한 칸을 덮어쓴다(예 --up=attack.perLevel=6).
    final up = RegExp(r'^--up=([A-Za-z]+)\.([A-Za-z]+)=(.+)$').firstMatch(a);
    if (up != null) {
      final list = (out['__up'] ??= <List<String>>[]) as List<List<String>>;
      list.add([up.group(1)!, up.group(2)!, up.group(3)!]);
      continue;
    }
    // 장비 옵션 값을 배율로 조절한다(장비를 더/덜 갖춘 유저).
    final es = RegExp(r'^--equip-scale=(.+)$').firstMatch(a);
    if (es != null) {
      _gearScale = double.parse(es.group(1)!);
      continue;
    }
    final egd = RegExp(r'^--endgame-days=(.+)$').firstMatch(a);
    if (egd != null) {
      _endgameDays = int.parse(egd.group(1)!);
      continue;
    }
    final trs = RegExp(r'^--tiers=(.+)$').firstMatch(a);
    if (trs != null) {
      _tierRuns = int.parse(trs.group(1)!);
      continue;
    }
    final tr = RegExp(r'^--tier=(.+)$').firstMatch(a);
    if (tr != null) {
      _tier = int.parse(tr.group(1)!);
      continue;
    }
    final prc = RegExp(r'^--pet-restrain=(.+)$').firstMatch(a);
    if (prc != null) {
      _petRestrainCount = int.parse(prc.group(1)!);
      continue;
    }
    final tb = RegExp(r'^--boost=(.+)$').firstMatch(a);
    if (tb != null) {
      _tapBoostAvg = double.parse(tb.group(1)!);
      continue;
    }
    final mb = RegExp(r'^--mat-base-mult=(.+)$').firstMatch(a);
    if (mb != null) {
      _matBaseMult = double.parse(mb.group(1)!);
      continue;
    }
    final mc = RegExp(r'^--mat-cost-growth=(.+)$').firstMatch(a);
    if (mc != null) {
      _matCostGrowth = double.parse(mc.group(1)!);
      continue;
    }
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
  return _Opts(
    out,
    mult,
    worlds,
    fitZones: fitZones,
    fitHits: fitHits,
    fitBite: fitBite,
    fitGoldStep: fitGoldStep,
    fitTiers: fitTiers,
    fitBossMargin: fitBossMargin,
    fitDays: fitDays,
  );
}
