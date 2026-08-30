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

import 'package:core_models/core_models.dart' show MaterialKind;
import 'package:core_run/core_run.dart';

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

/// 장비 8부위의 **공격 배율**(옵션 attack%). 최고등급 5옵션까지 붙지만
/// 평균 유저는 등급이 섞인다 — 상한이 아니라 중간을 잡는다.
double _equipAttackMult = 1.35;

/// 장비가 주는 치명 확률·피해 가산(옵션 critChance/critDamage).
double _equipCritChance = 0.12;
double _equipCritDamage = 0.6;

/// 장비 공격 옵션이 다 붙기까지 걸리는 스테이지(공방을 돌려 갖춘다).
const _equipFullStage = 300;

/// 종 고유 패시브 — 펫 3마리 장착분. 능력치가 갈리므로 공격 기여는 일부다.
const _passiveAttackMult = 1.08;

/// 도감 영구 보너스 — 정복 20종이면 공격 +30%(`dex.json` attackPerConquer 0.015).
/// 다 채우는 데 오래 걸리므로 진행에 따라 오른다.
const _dexAttackMult = 1.30;
const _dexFullStage = 600;

/// 탭 부스트 — **활동 시간에만** 걸리는 평균 배율.
///
/// ⚠️ `boostSpeedFactor = 1.0` 이라 데미지와 공속에 **둘 다** 실린다
/// = 실질 DPS 가 배율의 **제곱**이다(x2 면 DPS x4, 상한 x5 면 x25).
/// 이것도 적응형 기준 **밖**이다(§7: "탭 부스트도 여기 들어오면 안 된다").
///
/// 상한(x5)을 유지하려면 초당 2.7회를 계속 두드려야 한다 — 아무도 2시간
/// 내내 그러지 않는다. 보스전에서만 올리는 **평균**을 잡는다.
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

/// 펫을 다 갖췄을 때의 추가 공격 배율(+150% = x2.5).
/// pets.json 의 상한(전설3 만렙 x4.04)이 아니라 **평균적인 유저**를 가정한다.
/// `--pet-bonus=` 로 덮어쓸 수 있다(펫 상한을 바꿔볼 때).
const _petMaxBonusDefault = 1.5;
double _petMaxBonus = _petMaxBonusDefault;

/// 펫이 위 배율에 도달하는 스테이지(그 전까지는 선형으로 오른다).
const _petFullStage = 600.0;

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
      if (t > 0) {
        sim.levels.clear();
        sim.level = 1;
        sim.xp = 0;
      }
      final from = day;
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
    stdout.writeln('');
    stdout.writeln('  ★ 전 회차 합계: $total일');
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
  for (final m in const [10, 30, 50, 100, 200, 400, 700]) {
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
  for (final m in const [10, 50, 100, 200, 400, 700, 1000]) {
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
  for (final m in const [10, 50, 100, 200, 400, 700, 1000]) {
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
  for (final m in const [10, 50, 100, 200, 400, 700, 1000]) {
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

  stdout.writeln('── 업그레이드가 막힌 이유(구간별) ──');
  stdout.writeln('  재료가 100% 면 재료만 모으는 게임, 0% 면 재료가 장식이다.');
  for (final m in const [10, 30, 50, 100, 200, 400, 700]) {
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

  final RunConfig config;

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

  /// 진행도에 따른 **펫 공격 배율**.
  ///
  /// 예전엔 펫을 통째로 빼고 계산했다("맨몸 = 가장 느린 경로"). 그런데 실제
  /// 유저는 펫을 키우고, 그 배율이 공격에 곱해진다 — 빼고 재면 "체력을 올렸는데
  /// 한 방에 죽는다"를 못 본다(실제로 그렇게 틀렸다).
  ///
  /// 모델: 초반엔 낮은 등급·저레벨(≈+5%), 진행할수록 좋은 펫을 갖춰
  /// [_petMaxBonus] 까지 오른다. 최대치(전설3 만렙)가 아니라 **평균적인 유저**를
  /// 가정한다 — 상한을 기준으로 맞추면 대다수가 너무 어려워진다.
  double get petAttackMult =>
      1 + _petMaxBonus * math.min(1.0, careerStage / _petFullStage);

  /// 기준 밖 전력이 진행에 따라 붙는 배율(장비·종패시브·도감).
  double get _outsideBaselineAttack {
    final equip =
        1 +
        (_equipAttackMult - 1) * math.min(1.0, careerStage / _equipFullStage);
    final dex =
        1 + (_dexAttackMult - 1) * math.min(1.0, careerStage / _dexFullStage);
    return equip * _passiveAttackMult * dex;
  }

  /// **적응형 체력이 맞추는 기준**(앱의 `_petStats`).
  /// 장비·종패시브·도감·버프는 **들어가지 않는다** — 그게 이 게임의 설계다(§7).
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

  /// 실제로 몬스터를 때리는 능력치(앱의 `_stats`).
  CharacterStats get stats {
    final s = _baseStats;
    return CharacterStats(
      attack:
          s.attack *
          petAttackMult *
          _buffDpsMult *
          _outsideBaselineAttack *
          _tapBoostAvg,
      // 부스트는 공속에도 실린다 — 얼마나 실리는지는 `boostSpeedFactor` 다.
      // 1.0 이면 DPS 가 배율의 **제곱**(x2 → x4), 0.5 면 완만해진다(x2 → x2.8).
      attackSpeed:
          s.attackSpeed * (1 + (_tapBoostAvg - 1) * config.boostSpeedFactor),
      rewardMultiplier: s.rewardMultiplier,
      critChance:
          (s.critChance +
                  _equipCritChance * math.min(1.0, stage / _equipFullStage))
              .clamp(0.0, 1.0),
      critDamage:
          s.critDamage +
          _equipCritDamage * math.min(1.0, stage / _equipFullStage),
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
              habitatThreat(config, s - 1, boss: true, playerToughness: tough) *
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
              habitatThreat(config, s - 1, playerToughness: tough) *
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
              habitatThreat(config, s - 1, boss: true, playerToughness: tough) *
              100 /
              (100 + st.defense) *
              1.4; // 보스 한 대는 1.4배(앱과 동일)
          final n = config.habitatsPerStage;
          final dmg = inc * fight * n + bossInc * bossFight;
          final heal =
              (st.hpRegen * fight + st.hpRegen * 2 * walk) * n +
              st.maxHp * config.killHealPct * n +
              st.hpRegen * bossFight +
              st.maxHp * config.bossKillHealPct;
          final max = st.maxHp <= 0 ? 1.0 : st.maxHp;
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
      for (final m in const [10, 30, 50, 100, 200, 400, 700]) {
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
      if (stage > careerStage) careerStage = stage;
      final earned =
          prog.gold *
          _buffGoldMult *
          (_online ? 1 + config.onlineGoldBonus : 1.0);
      gold += earned;
      _goldEarned += earned;
      goldEarnedByDay[elapsedDays.floor()] = _goldEarned;
      _gainXp(prog.xp);
      // 재료: 처치당 materialDropChance 확률로 평균 1.5개, 3종에 고르게.
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
    'mat-amt-growth': 'materialAmountGrowth',
    // 적응형 손잡이 — "몇 대에 죽나"를 JSON 고치기 전에 쓸어보기 위한 것.
    'hits': 'hpAdaptTargetHits',
    'hp-adapt-power': 'hpAdaptPower',
    'hp-adapt-max': 'hpAdaptMaxRatio',
    'threat-pct': 'threatAdaptTargetPct',
    'boost-speed': 'boostSpeedFactor',
    // 회복 축 — 처치 회복(킬 속도에 좌우)과 상시 회복(시간 비례)의 비중.
    'kill-heal': 'killHealPct',
    'boss-kill-heal': 'bossKillHealPct',
  };
  final out = <String, dynamic>{};
  double? mult;
  var worlds = 10;
  for (final a in args) {
    // 장비 옵션 **평균**을 배율로 조절한다(분포를 바꿀 때 난이도 영향을 잰다).
    final es = RegExp(r'^--equip-scale=(.+)$').firstMatch(a);
    if (es != null) {
      final k = double.parse(es.group(1)!);
      _equipAttackMult = 1 + (_equipAttackMult - 1) * k;
      _equipCritChance *= k;
      _equipCritDamage *= k;
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
    final tb = RegExp(r'^--boost=(.+)$').firstMatch(a);
    if (tb != null) {
      _tapBoostAvg = double.parse(tb.group(1)!);
      continue;
    }
    final pb = RegExp(r'^--pet-bonus=(.+)$').firstMatch(a);
    if (pb != null) {
      _petMaxBonus = double.parse(pb.group(1)!);
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
  return _Opts(out, mult, worlds);
}
