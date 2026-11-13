// 사냥터 사다리(2026-11-12) — "맨몸 유저가 각 사냥터 보스를 잡으려면 그 전 사냥터에서 몇 시간 사냥해야 하나".
//
// balance_sim 은 평균 유저(버프 75% · 선물·일일보상 골드 · 스킬·펫·장비)를 잰다. 그 유저는 하루 30분만 켜도 첫날 사냥터 3 에
// 간다 — 실제 신규 유저와 동떨어진다(운영 DB: 떠난 유저 강화 합 중앙값 48). 이 도구는 반대 끝을 잰다:
//   · 강화는 시뮬과 같이 **가장 싼 것부터** 한 레벨씩 산다(대성공·재료는 없다고 본다 — 초반 50레벨은 재료 0)
//   · 수입은 **켜 둔 채 사냥한 골드뿐**(접속 보너스 포함 · 버프·선물·일일보상·방치·펫·장비·스킬 없음)
//   · 보스 판정은 시뮬과 같다: 넣는 피해(min(인내 240초, 버티는 시간 ÷ 1.1)) ≥ 보스 체력
// 사냥터마다 "그 보스가 처음 잡히는 누적 골드"를 찾고, 앞 보스를 잡은 힘으로 **그 사냥터**에서 그 골드를 버는 데 걸리는 시간을 보인다.
// 그 시간이 사냥터마다 고르게 늘어야 완만하다(튀는 칸 = 벽). 도착 판정(몇 대 · 한 대 %)도 함께.
//
// 사용: dart run tool/zone_ladder.dart [--tier=0] [--level=캐릭터레벨(기본 1)] [--set=bossHp.2=값 ...] [--run-config=경로]
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:core_run/core_run.dart';

const _patience = 240.0; // balance_sim `_bossPatienceSeconds` 와 같다.

void main(List<String> args) {
  final tier =
      int.tryParse(
        args
                .map((a) => RegExp(r'^--tier=(\d+)$').firstMatch(a)?.group(1))
                .whereType<String>()
                .firstOrNull ??
            '0',
      ) ??
      0;
  final path =
      args
          .map((a) => RegExp(r'^--run-config=(.+)$').firstMatch(a)?.group(1))
          .whereType<String>()
          .firstOrNull ??
      '../app/assets/data/run_config.json';
  final charLevel =
      int.tryParse(
        args
                .map((a) => RegExp(r'^--level=(\d+)$').firstMatch(a)?.group(1))
                .whereType<String>()
                .firstOrNull ??
            '1',
      ) ??
      1;
  final json =
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  // --set=bossHp.2=1200000 : 이 난이도 표의 칸을 바꿔 본다(사냥터 번호는 1부터). 여러 번 줄 수 있다.
  for (final a in args) {
    final m = RegExp(r'^--set=(\w+)\.(\d+)=([\d.]+)$').firstMatch(a);
    if (m == null) continue;
    final row = ((json['zoneTiers'] as List)[tier] as Map)[m.group(1)] as List;
    row[int.parse(m.group(2)!) - 1] = num.parse(m.group(3)!);
  }
  final cfg = RunConfig.fromJson(json);

  CharacterStats statsOf(Map<UpgradeKind, int> lv) => deriveStats(
    cfg,
    upgradeLevels: lv,
    characterLevel: charLevel,
    bugsCollected: 0,
  );

  bool beatable(CharacterStats st, int zone) {
    final depth = cfg.zoneStartStage(zone) - 1;
    final hp = bossMaxHp(cfg, depth, tier: tier).toDouble();
    final inc =
        habitatThreat(
          cfg,
          depth,
          boss: true,
          playerToughness: toughnessOf(st),
          gearToughness: toughnessOf(st),
          tier: tier,
        ) *
        100 /
        (100 + st.defense) *
        (1 - evadeChance(cfg, st));
    final net = inc - st.hpRegen;
    final live = net <= 0 ? double.infinity : st.maxHp / net;
    final sec = math.min(_patience, live / 1.1);
    return baselineHitPower(st, boss: true) * st.attackSpeed * sec >= hp;
  }

  // 사냥터 [zone] 에서 켜 두고 사냥할 때 시간당 골드(접속 보너스 포함).
  double goldPerHour(CharacterStats st, int zone) {
    final depth = cfg.zoneStartStage(zone) - 1;
    final hp = habitatMaxHp(cfg, depth, tier: tier).toDouble();
    final secPerKill =
        hp / baselineHitPower(st) / st.attackSpeed + cfg.walkSeconds;
    final g =
        rewardGold(cfg, depth, st.rewardMultiplier, tier: tier) *
        (1 + cfg.onlineGoldBonus);
    return g / secPerKill * 3600;
  }

  ({double hits, double bite}) arrival(CharacterStats st, int zone) {
    final depth = cfg.zoneStartStage(zone) - 1;
    final hp = habitatMaxHp(cfg, depth, tier: tier).toDouble();
    final threat = habitatThreat(
      cfg,
      depth,
      playerToughness: toughnessOf(st),
      gearToughness: toughnessOf(st),
      tier: tier,
    );
    return (
      hits: hp / baselineHitPower(st),
      bite: threat * cfg.enemyAtkInterval * 100 / (100 + st.defense) / st.maxHp,
    );
  }

  final lv = <UpgradeKind, int>{};
  var spent = 0.0;
  final zones = cfg.zonesPerTier + 1;
  final need = <int, ({double gold, int total, CharacterStats st})>{};
  var zone = 1;
  // 사냥터마다 머문 시간 — 강화를 하나 살 때마다 **그 순간의 사냥 속도**로 그 값을 버는 시간을 더한다.
  final hoursIn = <int, double>{};
  for (var guard = 0; guard < 200000 && zone <= zones; guard++) {
    var st = statsOf(lv);
    while (zone <= zones && beatable(st, zone)) {
      need[zone] = (
        gold: spent,
        total: lv.values.fold(0, (a, b) => a + b),
        st: st,
      );
      zone++;
    }
    if (zone > zones) break;
    UpgradeKind? best;
    var bestCost = double.infinity;
    for (final e in cfg.upgrades.entries) {
      final l = lv[e.key] ?? 0;
      if (!e.value.canBuyAt(l)) continue;
      final c = upgradeCost(e.value, l).toDouble();
      if (c < bestCost) {
        bestCost = c;
        best = e.key;
      }
    }
    if (best == null) break;
    hoursIn[zone] = (hoursIn[zone] ?? 0) + bestCost / goldPerHour(st, zone);
    spent += bestCost;
    lv[best] = (lv[best] ?? 0) + 1;
  }

  String s(num v) => v >= 1e9
      ? '${(v / 1e9).toStringAsFixed(1)}B'
      : v >= 1e6
      ? '${(v / 1e6).toStringAsFixed(1)}M'
      : v >= 1e3
      ? '${(v / 1e3).toStringAsFixed(1)}K'
      : v.toStringAsFixed(0);
  stdout.writeln('난이도 $tier · 맨몸(강화만, 싼 것부터) · 수입 = 켜 둔 사냥 골드만(버프·선물·방치 없음)');
  stdout.writeln('보스 | 강화합 | 누적 골드 | 그 사냥터 사냥 시간 | 도착 몇 대 · 한 대 | 처음 잡을 때 보스전');
  for (var z = 1; z <= zones; z++) {
    final n = need[z];
    if (n == null) {
      stdout.writeln('${z.toString().padLeft(3)}  | 못 잡음(강화 상한)');
      continue;
    }
    final prev = z == 1 ? null : need[z - 1];
    final hours = hoursIn[z] ?? 0;
    // 이 사냥터에 도착한 직후(앞 보스를 막 잡은 전력)의 일반 몬스터.
    final a = arrival(prev?.st ?? statsOf(const {}), z);
    // 처음 잡힐 때 보스전 길이(초) — 인내 240초에 가까우면 "물렁한 보스"(오래 때려야 한다).
    final fight =
        bossMaxHp(cfg, cfg.zoneStartStage(z) - 1, tier: tier) /
        (baselineHitPower(n.st, boss: true) * n.st.attackSpeed);
    stdout.writeln(
      '${z.toString().padLeft(3)}  | ${n.total.toString().padLeft(5)} | ${s(n.gold).padLeft(8)} | '
      '${hours.toStringAsFixed(1).padLeft(7)}시간 | ${a.hits.toStringAsFixed(1).padLeft(5)}대 · ${(a.bite * 100).toStringAsFixed(0)}%'
      ' | ${fight.toStringAsFixed(0).padLeft(4)}초',
    );
  }
}
