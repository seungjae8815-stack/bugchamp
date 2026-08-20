// 젤리(프리미엄 재화) 수급 감사 — "하루에 젤리가 몇 개 들어오나"를 JSON 으로 잰다.
//
// 왜 필요한가: 젤리 수도꼭지가 **여섯 군데**(일일보상·깜짝선물·미션·리그/시즌·
// 광고버프·분해)로 흩어져 있어, 하나씩 보면 다 적어 보이는데 합치면 IAP 최대
// 패키지(₩5,500 = 300젤리)를 이틀에 하나씩 공짜로 주는 상태가 된다.
// 손으로 더하면 반드시 틀리므로 실제 config 를 읽어 합산한다.
//
// 실행:
//   cd packages\core_run ; dart run tool/jelly_sim.dart
//   dart run tool/jelly_sim.dart --active=4 --ads=0
//
// ⚠️ 근사인 지점:
//  - 유저 행동(광고 시청 횟수·분해 습관)은 아래 상수로 가정한다. 상한을 재는 게
//    목적이라 "열심히 하는 유저"에 가깝게 잡았다.
//  - 리그/시즌은 주간 보상이라 7로 나눠 하루치로 환산한다.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:core_run/core_run.dart';

/// 하루 중 앱을 켜고 노는 시간(깜짝선물·분해가 이 시간에 비례한다).
double _activeHours = 2.0;

/// 광고를 얼마나 보는가(0.0 = 안 봄, 1.0 = 뜨는 대로 다 봄).
double _adRate = 1.0;

/// 처치 1회당 곤충 드롭 확률 × 곤충 감각(bugFind) 평균 배율.
/// balance_sim 의 처치 속도(스테이지 10~100 에서 시간당 약 900마리)와 함께 쓴다.
const _killsPerHour = 900.0;

/// 분해하는 비율 — 채집함이 100칸뿐이라 결국 대부분 분해하게 된다.
const _disassembleRate = 0.9;

/// 드롭 개체의 포텐셜 분포를 **직접 굴려** 얻는다.
///
/// ⚠️ 평균 포텐셜 하나로 계산하면 안 된다. 분해 젤리에 문턱
/// (`disassembleJellyMinPotential`)이 걸린 뒤로는 **분포의 꼬리**(4~5성)만
/// 젤리를 주므로, 평균(≈1.8)을 넣으면 기여가 통째로 0으로 나온다.
/// 롤 식은 `IndividualBug.roll` 호출부와 같아야 한다: `1 + floor(r1*r2*4)`.
double _avgDisassembleJelly(PetConfig pets) {
  final rng = Random(20260815); // 고정 seed — 돌릴 때마다 값이 흔들리면 못 쓴다
  var sum = 0.0;
  const n = 200000;
  for (var i = 0; i < n; i++) {
    final p = (1 + (rng.nextDouble() * rng.nextDouble() * 4).floor()).clamp(
      1,
      5,
    );
    sum += pets.disassembleJelly(p);
  }
  return sum / n;
}

/// 도달 리그(승급·시즌 보상 규모). `--league=` 로 바꾼다.
String _leagueId = 'diamond';

/// 미션 순환 티어(보상이 `rewardGrowth^claims` 로 자라므로 진행도에 따라 커진다).
/// `--mission-tier=` 로 바꾼다.
int _missionClaims = 20;

void main(List<String> args) {
  for (final a in args) {
    final m = RegExp(r'^--([a-z-]+)=(.+)$').firstMatch(a);
    if (m == null) continue;
    switch (m.group(1)) {
      case 'active':
        _activeHours = double.parse(m.group(2)!);
      case 'ads':
        _adRate = double.parse(m.group(2)!);
      case 'league':
        _leagueId = m.group(2)!;
      case 'mission-tier':
        _missionClaims = int.parse(m.group(2)!);
    }
  }

  Map<String, dynamic> load(String name) =>
      jsonDecode(File('../app/assets/data/$name').readAsStringSync())
          as Map<String, dynamic>;

  final daily = DailyConfig.fromJson(load('daily.json'));
  final gifts = GiftConfig.fromJson(load('gifts.json'));
  final missions = MissionConfig.fromJson(load('missions.json'));
  final battle = BattleConfig.fromJson(load('battle.json'));
  final pets = PetConfig.fromJson(load('pets.json'));
  final buffs = BuffConfig.fromJson(load('buffs.json'));
  final iap = IapConfig.fromJson(load('iap.json'));

  final rows = <({String name, double perDay, String note})>[];

  // ── 1. 일일보상 — 고정. 하루 한 번씩.
  final dailyJelly = daily.rewards.fold<int>(0, (a, r) => a + r.jelly);
  rows.add((
    name: '일일보상',
    perDay: dailyJelly.toDouble(),
    note: '${daily.rewards.length}회 고정',
  ));

  // ── 2. 깜짝선물 — 접속 중 평균 간격마다 1개, 가중 평균 젤리.
  final totalWeight = gifts.tiers.fold<double>(0, (a, t) => a + t.weight);
  final avgGiftJelly = totalWeight <= 0
      ? 0.0
      : gifts.tiers.fold<double>(0, (a, t) => a + t.weight * t.jelly) /
            totalWeight;
  final avgIntervalSec = (gifts.intervalMinSec + gifts.intervalMaxSec) / 2;
  final giftsPerDay = _activeHours * 3600 / avgIntervalSec;
  // 무료 2배는 하루 [freeDoubleDaily] 회뿐이다(2026-08-20 — 1회).
  // 예전처럼 전량 ×2 로 세면 무과금 수입이 두 배 가까이 과대계상된다.
  // 무제한 2배는 패스 몫이라 아래 "패스 보유자" 줄에서 따로 본다.
  final freeDoubles = gifts.freeDoubleDaily.toDouble().clamp(0, giftsPerDay);
  rows.add((
    name: '깜짝선물',
    perDay: (giftsPerDay + freeDoubles) * avgGiftJelly,
    note:
        '${giftsPerDay.toStringAsFixed(1)}개/일 × 평균 '
        '${avgGiftJelly.toStringAsFixed(2)} + 무료 2배 '
        '${freeDoubles.toStringAsFixed(0)}회',
  ));

  // ── 3. 미션 — 젤리 보상 미션의 현재 티어값. 하루 몇 번 도느냐는 진행도에
  //      따라 다르지만, 보수적으로 하루 1회전으로 잡는다.
  var missionJelly = 0.0;
  for (final d in missions.missions) {
    if (d.reward != 'jelly') continue;
    missionJelly += d.rewardAt(_missionClaims);
  }
  rows.add((
    name: '미션',
    perDay: missionJelly,
    note: '$_missionClaims티어 · 1회전/일 가정',
  ));

  // ── 4. 리그 승급 + 시즌 종료 — 주간이라 7로 나눈다.
  // 승급 보상은 **한 번씩만** 받는다(도달 리그까지 누적). 시즌 종료는 매주.
  var promo = 0;
  var reached = false;
  for (final lg in battle.leagues) {
    promo += lg.rewardJelly;
    if (lg.id == _leagueId) {
      reached = true;
      break;
    }
  }
  if (!reached) {
    stderr.writeln('알 수 없는 리그: $_leagueId');
    exit(2);
  }
  final seasonEnd =
      (battle.leagues.firstWhere((l) => l.id == _leagueId).rewardJelly *
              battle.seasonRewardMult)
          .round();
  // ⚠️ 승급 보상은 **계정당 한 번**이다(`claimedLeagues` 는 시즌 리셋에서
  // 초기화되지 않는다). 하루치로 나눠 상시 수입에 넣으면 과대계상된다 —
  // 반복되는 건 시즌 종료 보상뿐이다.
  rows.add((
    name: '시즌 종료',
    perDay: seasonEnd / 7,
    note: '$_leagueId $seasonEnd젤리 (주간 → ÷7) · 승급 $promo 는 1회성이라 제외',
  ));

  // ── 5. 광고 버프 — 버프 1회당 젤리 1개(코드 상수). 누적 상한까지 볼 수 있다.
  final buffAdsPerDay = buffs.durationSeconds <= 0
      ? 0.0
      : buffs.maxSeconds / buffs.durationSeconds;
  rows.add((
    name: '광고 버프',
    perDay: buffAdsPerDay * _adRate * buffs.adJelly,
    note:
        '${buffAdsPerDay.toStringAsFixed(0)}회/일(누적상한) × '
        '${buffs.adJelly}젤리 × 시청률 $_adRate',
  ));

  // ── 6. 분해 — **곤충은 무한히 나온다.** 여기가 가장 큰 수도꼭지가 되기 쉽다.
  final bugsPerDay = _activeHours * _killsPerHour * 0.03;
  final perBug = _avgDisassembleJelly(pets);
  rows.add((
    name: '분해',
    perDay: bugsPerDay * _disassembleRate * perBug,
    note:
        '${bugsPerDay.toStringAsFixed(0)}마리/일 × 분해율 $_disassembleRate '
        '× ${perBug.toStringAsFixed(2)}젤리(포텐셜 분포 실측, '
        '문턱 ${pets.disassembleJellyMinPotential}성)',
  ));

  final total = rows.fold<double>(0, (a, r) => a + r.perDay);

  stdout.writeln('── 가정 ──');
  stdout.writeln('  활동 ${_activeHours}h/일 · 광고 시청률 $_adRate · 리그 $_leagueId');
  stdout.writeln('');
  stdout.writeln('── 젤리 수급(하루) ──');
  stdout.writeln('  ${'출처'.padRight(10)} | ${'젤리/일'.padLeft(8)} | 비중 | 근거');
  rows.sort((a, b) => b.perDay.compareTo(a.perDay));
  for (final r in rows) {
    final pct = total <= 0 ? 0.0 : r.perDay / total * 100;
    stdout.writeln(
      '  ${r.name.padRight(10)} | ${r.perDay.toStringAsFixed(1).padLeft(8)} |'
      ' ${pct.toStringAsFixed(0).padLeft(3)}% | ${r.note}',
    );
  }
  stdout.writeln(
    '  ${'합계'.padRight(10)} | ${total.toStringAsFixed(1).padLeft(8)} |',
  );
  stdout.writeln('');

  // ── IAP 대비 — 공짜로 주는 젤리가 최대 패키지 몇 개어치인가.
  stdout.writeln('  ※ 승급 보상 $promo젤리는 **계정당 1회**라 위 합계에 없다(첫 도달 시 일시금).');
  stdout.writeln('');

  // ── 패스 보유자 — **여기가 오래 비어 있었다.**
  //
  // 시뮬이 무과금만 재고 있어서, 패스가 매일 주는 젤리가 어느 장부에도
  // 안 잡혔다. §2.6 이 "손으로 더하면 반드시 틀린다"고 경고한 자리에 도구
  // 자체가 빠져 있던 셈이다(2026-08-18 발견).
  final passJelly = iap.passDailyJelly.toDouble();
  final passTotal = total + passJelly;
  stdout.writeln('── 패스 보유자 ──');
  stdout.writeln(
    '  무과금 ${total.toStringAsFixed(1)} + 패스 일일 ${passJelly.toStringAsFixed(0)}'
    ' = ${passTotal.toStringAsFixed(1)} 젤리/일',
  );
  final passProd = iap.products.where((p) => p.type == IapType.pass);
  for (final p in passProd) {
    final per = iap.passDurationDays * iap.passDailyJelly;
    if (per <= 0) continue;
    stdout.writeln(
      '  ${p.id}: ₩${p.priceKrw} / ${iap.passDurationDays}일 = $per젤리'
      ' → ₩${(p.priceKrw / per).toStringAsFixed(1)}/젤리',
    );
  }
  stdout.writeln('');

  stdout.writeln('── IAP 대비(이게 핵심 지표) ──');
  // 젤리 팩의 **단가**가 패스보다 비싸면 아무도 팩을 안 산다 — 매출 상한이
  // 패스 가격에 묶인다. 그래서 단가를 나란히 찍는다.
  double? cheapestPack;
  for (final p in iap.products) {
    final j = p.grant.jelly;
    if (j <= 0) continue;
    final unit = p.priceKrw / j;
    if (p.type == IapType.jelly) {
      cheapestPack = (cheapestPack == null || unit < cheapestPack)
          ? unit
          : cheapestPack;
    }
    final days = total <= 0 ? double.infinity : j / total;
    stdout.writeln(
      '  ${p.id.padRight(16)} ₩${p.priceKrw.toString().padLeft(6)} = '
      '${j.toString().padLeft(5)}젤리 → ₩${unit.toStringAsFixed(1)}/젤리'
      ' · 공짜로 모으는 데 ${days.toStringAsFixed(1)}일',
    );
  }
  final passUnit = iap.passDurationDays * iap.passDailyJelly > 0
      ? (passProd.isEmpty
            ? null
            : passProd.first.priceKrw /
                  (iap.passDurationDays * iap.passDailyJelly))
      : null;
  if (cheapestPack != null && passUnit != null) {
    final verdict = passUnit < cheapestPack
        ? '⚠️ 패스가 더 싸다 → 젤리 팩이 안 팔린다(매출 상한이 패스에 묶임)'
        : 'OK — 팩이 패스보다 싸거나 비슷하다';
    stdout.writeln('');
    stdout.writeln(
      '  최저가 팩 ₩${cheapestPack.toStringAsFixed(1)}/젤리 vs '
      '패스 ₩${passUnit.toStringAsFixed(1)}/젤리 → $verdict',
    );
  }
  stdout.writeln('');

  // ── 소비처 — 하루 수입이 주요 소비처를 몇 개나 덮는가.
  stdout.writeln('── 하루 수입으로 살 수 있는 것 ──');
  void sink(String name, int cost) {
    if (cost <= 0) return;
    stdout.writeln(
      '  ${name.padRight(20)} ${cost.toString().padLeft(4)}젤리 → '
      '하루에 ${(total / cost).toStringAsFixed(1)}개',
    );
  }

  sink('부화기 확장 1회', pets.incubatorExpandJelly);
  sink('짝짓기 슬롯 확장 1회', pets.breedingExpandJelly);
  sink('채집함 +10칸', pets.storageExpandJelly);
  sink('결투 티켓 만땅', battle.ticketRefillJelly);
  stdout.writeln('');

  // ── 영구 소비처 = **한 번 사면 끝나는 것**들의 총합.
  //
  // 소모성(즉시완료·티켓 리필·물약)은 끝이 없어서 "며칠이면 다 산다"를 말할 수
  // 없다. 무과금 유저가 **편의 기능을 전부 열기까지** 걸리는 시간이 이 지표다.
  //
  // 채집함 시작 칸 수(50)는 core_save 의 `kDefaultStorageCapacity` 다.
  // core_run 은 core_save 를 모르므로(의존 방향이 반대) 여기서는 값을 적는다.
  const startStorage = 50;
  final incubatorBuys = pets.incubatorSlotsMax - pets.incubatorSlotsInitial;
  final breedingBuys = pets.breedingSlotsMax - pets.breedingSlotsInitial;
  final storageBuys =
      ((pets.storageSlotsMax - startStorage) / pets.storageExpandAmount).ceil();
  // ⚠️ **정액으로 곱하면 안 된다.** 확장은 살수록 비싸진다(expandCostGrowth).
  // 정액으로 세던 시절엔 총액을 1530 으로 보고했는데 실제는 7003 이었다 —
  // 도구가 실제보다 4.6배 싸게 보고하고 있었다(2026-08-18).
  var incubatorCost = 0;
  for (var c = pets.incubatorSlotsInitial; c < pets.incubatorSlotsMax; c++) {
    incubatorCost += pets.incubatorExpandCost(c);
  }
  var breedingCost = 0;
  for (var c = pets.breedingSlotsInitial; c < pets.breedingSlotsMax; c++) {
    breedingCost += pets.breedingExpandCost(c);
  }
  var storageCost = 0;
  for (
    var cap = startStorage;
    cap < pets.storageSlotsMax;
    cap += pets.storageExpandAmount
  ) {
    storageCost += pets.storageExpandCost(cap);
  }
  final permanent = incubatorCost + breedingCost + storageCost;

  stdout.writeln('── 영구 소비처(한 번 사면 끝) ──');
  stdout.writeln(
    '  부화기 슬롯 ${pets.incubatorSlotsInitial}→${pets.incubatorSlotsMax}'
    ' : $incubatorBuys회 = $incubatorCost젤리',
  );
  stdout.writeln(
    '  짝짓기 슬롯 ${pets.breedingSlotsInitial}→${pets.breedingSlotsMax}'
    ' : $breedingBuys회 = $breedingCost젤리',
  );
  stdout.writeln(
    '  채집함 $startStorage→${pets.storageSlotsMax}칸'
    ' : $storageBuys회 = $storageCost젤리 (살수록 비싸짐)',
  );
  stdout.writeln(
    '  합계 $permanent젤리 → 무과금으로 '
    '${total <= 0 ? '∞' : (permanent / total).toStringAsFixed(1)}일',
  );
  stdout.writeln('');
  stdout.writeln('  ※ 소모성(즉시완료·티켓 리필·진화촉진·물약)은 끝이 없어서 여기 안 넣는다.');
}
