// 서버 골드 상식상한(mergeSave) vs 실제 열심히 플레이한 유저의 60초 수입 비교.
//
// 서버는 60초 업로드마다 `simulateIdleProgress(efficiency: 30)` 로 상한을 잡고
// 넘으면 자른다. 상한이 낮으면 **정당한 유저의 골드가 잘린다** — 방어보다
// 오탐이 나쁘다. 접속 보너스(+60%)를 얹었으니 여유가 남았는지 확인한다.
//
// `--guild` : 길드 버프 최대치(guild.json skills — 공격 +8%·골드 +10%)를 실제 유저 쪽에 얹는다.
//             서버 봉투에는 길드 버프가 없다(서버는 길드를 조회하지 않는다) — 여유가 2배 이상이면 흡수된다.
//             교환소 허용치(`_exchangeAllowance`)도 같이 잰다.
// `--passive-gold` : 펫 골드 패시브 최대(3마리 × pets.json passiveV2 reward) · 도감 전 종 발견 골드를 실제 유저 쪽에
//             **곱으로** 얹는다(2026-10-14 — 가산이던 시절엔 강화로 자란 골드 배율에 묽어져 거의 0 이었다).
//             서버 봉투에는 없다(서버는 펫·도감을 안 본다). 비교용으로 예전 가산일 때 배율도 함께 찍는다.
import 'dart:convert';
import 'dart:io';
import 'package:core_run/core_run.dart';

void main(List<String> args) {
  final dir = '../app/assets/data';
  final withGuild = args.contains('--guild');
  final guild = GuildConfig.fromJson(
    jsonDecode(File('$dir/guild.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  final gb = withGuild
      ? guildBonus(guild.skills, {for (final d in guild.skills) d.id: d.max})
      : const <String, double>{};
  final guildAtk = 1.0 + (gb['attack'] ?? 0);
  final guildGold = 1.0 + (gb['gold'] ?? 0);
  if (withGuild) {
    print('길드 버프 최대: 공격 x$guildAtk · 골드 x$guildGold (실제 유저 쪽에만)');
  }
  // 펫 골드 패시브(3마리 합) · 도감 발견 골드 — 곱(지금 규칙)과 가산(예전 규칙)의 추가분.
  final withPassiveGold = args.contains('--passive-gold');
  var passiveAdd = 0.0;
  if (withPassiveGold) {
    final pets =
        jsonDecode(File('$dir/pets.json').readAsStringSync())
            as Map<String, dynamic>;
    final v2 = pets['passiveV2'] as Map<String, dynamic>? ?? const {};
    final kinds = v2['kinds'] as Map<String, dynamic>? ?? const {};
    final petGold = 3 * ((kinds['reward'] as num?)?.toDouble() ?? 0);
    final dex =
        jsonDecode(File('$dir/dex.json').readAsStringSync())
            as Map<String, dynamic>;
    final species =
        (jsonDecode(File('$dir/species.json').readAsStringSync())
                as Map<String, dynamic>)['species']
            as List;
    final dexGold =
        ((dex['rewardPerDiscover'] as num?)?.toDouble() ?? 0) * species.length;
    _passiveGoldMul = (1 + petGold) * (1 + dexGold);
    passiveAdd = petGold + dexGold;
    print(
      '골드 패시브 최대: 펫 +${(petGold * 100).round()}% · 도감 +${(dexGold * 100).round()}% '
      '→ 곱 x${_passiveGoldMul.toStringAsFixed(2)} (예전 가산이면 골드 배율에 +${passiveAdd.toStringAsFixed(2)})',
    );
  }
  // 예전 가산 규칙이었다면 이 골드 배율에서 몇 배였나(비교용).
  double addGain(double reward) =>
      reward <= 0 ? 1.0 : (reward + passiveAdd) / reward;
  final run = RunConfig.fromJson(
    jsonDecode(File('$dir/run_config.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  const window = 60.0; // 업로드 주기(초)
  const saveBoundEfficiency = 30.0; // actions.dart 와 동일해야 한다
  const goldSanityFloor = 200000;
  const saveBoundAttackMult = 100.0; // actions.dart 와 동일해야 한다

  // 실제 유저 상단 케이스: 펫 최대(공격 x4) · 광폭화(DPS x1.8) · 골드러시(x2)
  // · 탭 부스트 최대(데미지 x5, 속도 x(1+4*factor)) · 접속 보너스.
  const petAtk = 4.04;
  const frenzy = 1.8;
  const goldRush = 2.0;

  print('스테이지 | 서버 상한(60초) | 실제 최대 수입 | 여유배수');
  for (final stage in [50, 100, 200, 400, 700, 1000]) {
    final levels = <UpgradeKind, int>{
      for (final k in UpgradeKind.values) k: (stage * 0.9).round(),
    };
    // 서버가 상한을 계산할 때 쓰는 스탯: 펫·버프 없음.
    final serverStats = deriveStats(
      run,
      upgradeLevels: levels,
      characterLevel: 1 + stage ~/ 5,
      bugsCollected: 50,
    );
    final bound =
        goldSanityFloor +
        simulateIdleProgress(
          config: run,
          startStage: stage,
          stats: _boosted(serverStats, saveBoundAttackMult),
          elapsed: const Duration(seconds: window ~/ 1),
          efficiency: saveBoundEfficiency,
        ).gold;

    // 실제 유저: 펫이 공격에 실리고, 적응형 체력도 그만큼 오른다.
    // 기준 1타는 `baselineHitPower`(치명타 포함) — 앱·서버와 같은 식이어야 한다.
    final hit = baselineHitPower(serverStats) * petAtk * guildAtk;
    final dps = hit * serverStats.attackSpeed * frenzy * run.boostMultMax;
    final speedMul = 1 + (run.boostMultMax - 1) * run.boostSpeedFactor;
    final depth = stage - 1;
    final hp = habitatMaxHp(run, depth, playerAttack: hit).toDouble();
    final perKill = hp / dps + 0.6 / speedMul;
    final goldPerKill =
        rewardGold(run, depth, goldRush) *
        (1 + run.onlineGoldBonus) *
        guildGold *
        _passiveGoldMul;
    final actual = window / perKill * goldPerKill;

    final ratio = actual <= 0 ? double.infinity : bound / actual;
    final mark = ratio < 1.0 ? '  ← 잘린다!' : (ratio < 2.0 ? '  ← 여유 부족' : '');
    print(
      '${stage.toString().padLeft(7)} | '
      '${bound.toStringAsFixed(0).padLeft(15)} | '
      '${actual.toStringAsFixed(0).padLeft(13)} | '
      'x${ratio.toStringAsFixed(2)}$mark'
      '${_oldCol(ratio, addGain(serverStats.rewardMultiplier))}',
    );
  }

  // ── 난이도별 표(zoneTiers, 2026-09-15) ──
  // 표의 골드가 난이도마다 크게 달라서, 위 스테이지 표만으로는 극한의 정당한
  // 수입이 잘리는지 알 수 없다. 강화는 난이도 목표 채움만큼, 펫·장비는 최고치
  // 근처(공격 x4 · DPS x3 가정)로 잡는다 — 상한을 넘기기 가장 쉬운 유저다.
  print('');
  print('난이도·사냥터 | 서버 상한(60초) | 실제 최대 수입 | 여유배수');
  const fill = [0.5, 0.65, 0.75, 0.85];
  for (var tier = 0; tier < run.zoneTiers.length; tier++) {
    for (final zone in [1, 6, run.zonesPerTier]) {
      final stage = run.zoneStartStage(zone);
      final levels = <UpgradeKind, int>{
        for (final e in run.upgrades.entries)
          e.key: ((e.value.maxLevel ?? 100) * fill[tier]).round(),
      };
      final serverStats = deriveStats(
        run,
        upgradeLevels: levels,
        characterLevel: 30,
        bugsCollected: 50,
      );
      final bound =
          goldSanityFloor +
          simulateIdleProgress(
            config: run,
            startStage: stage,
            stats: _boosted(serverStats, saveBoundAttackMult),
            elapsed: const Duration(seconds: window ~/ 1),
            efficiency: saveBoundEfficiency,
            tier: tier,
          ).gold;
      const gearDps = 3.0;
      final hit = baselineHitPower(serverStats) * petAtk * guildAtk;
      final dps =
          hit * serverStats.attackSpeed * frenzy * run.boostMultMax * gearDps;
      final speedMul = 1 + (run.boostMultMax - 1) * run.boostSpeedFactor;
      final hp = habitatMaxHp(run, stage - 1, tier: tier).toDouble();
      final perKill = hp / dps + 0.6 / speedMul;
      final goldPerKill =
          rewardGold(
            run,
            stage - 1,
            goldRush * serverStats.rewardMultiplier,
            tier: tier,
          ) *
          (1 + run.onlineGoldBonus) *
          guildGold *
          _passiveGoldMul;
      final actual = window / perKill * goldPerKill;
      final ratio = actual <= 0 ? double.infinity : bound / actual;
      final mark = ratio < 1.0 ? '  ← 잘린다!' : (ratio < 2.0 ? '  ← 여유 부족' : '');
      print(
        '      $tier·${zone.toString().padLeft(2)} | '
        '${bound.toStringAsFixed(0).padLeft(15)} | '
        '${actual.toStringAsFixed(0).padLeft(13)} | '
        'x${ratio.toStringAsFixed(2)}$mark'
        '${_oldCol(ratio, addGain(serverStats.rewardMultiplier))}',
      );
    }
  }

  // ── 교환소(젤리 → 골드) 1회 — 서버 허용치(actions.dart `_exchangeAllowance`) vs 앱 지급 ──
  // 앱은 펫·장비·길드 버프가 실린 사냥 능력치(huntStatsOf)로 효율 1 의 1시간치를 준다.
  // 서버는 강화만 반영한 능력치에 공격 x100 · 효율 30 으로 잰다.
  print('');
  print('교환 1회 골드 | 서버 허용치 | 앱 지급(펫·장비·길드) | 여유배수');
  for (var tier = 0; tier < run.zoneTiers.length; tier++) {
    for (final zone in [1, 6, run.zonesPerTier]) {
      final stage = run.zoneStartStage(zone);
      final levels = <UpgradeKind, int>{
        for (final e in run.upgrades.entries)
          e.key: ((e.value.maxLevel ?? 100) * fill[tier]).round(),
      };
      final serverStats = deriveStats(
        run,
        upgradeLevels: levels,
        characterLevel: 30,
        bugsCollected: 50,
      );
      final server = exchangeOutput(
        run,
        stats: _boosted(serverStats, saveBoundAttackMult),
        stage: stage,
        trades: 1,
        tier: tier,
        efficiency: saveBoundEfficiency,
      ).gold;
      final app = exchangeOutput(
        run,
        stats: _scaled(
          serverStats,
          atk: petAtk * 3.0 * guildAtk, // 펫 x4 · 장비 x3 · 길드
          reward: guildGold * _passiveGoldMul,
        ),
        stage: stage,
        trades: 1,
        tier: tier,
      ).gold;
      final ratio = app <= 0 ? double.infinity : server / app;
      final mark = ratio < 1.0 ? '  ← 잘린다!' : (ratio < 2.0 ? '  ← 여유 부족' : '');
      print(
        '      $tier·${zone.toString().padLeft(2)} | '
        '${server.toString().padLeft(15)} | '
        '${app.toString().padLeft(13)} | '
        'x${ratio.toStringAsFixed(2)}$mark'
        '${_oldCol(ratio, addGain(serverStats.rewardMultiplier))}',
      );
    }
  }
}

/// `--passive-gold` 의 골드 곱(펫 골드 패시브 3마리 × 도감 발견). 없으면 1.
var _passiveGoldMul = 1.0;

/// `--passive-gold` 일 때 예전 가산 규칙의 여유배수를 옆에 붙인다(지금 여유 × 곱 ÷ 가산 배율).
String _oldCol(double ratio, double addGain) => _passiveGoldMul == 1.0
    ? ''
    : '  (예전 가산 x${(ratio * _passiveGoldMul / addGain).toStringAsFixed(2)})';

/// 공격·보상 배율만 바꾼 능력치(앱 쪽 펫·장비·길드 버프 근사).
CharacterStats _scaled(
  CharacterStats s, {
  required double atk,
  required double reward,
}) => CharacterStats(
  attack: s.attack * atk,
  attackSpeed: s.attackSpeed,
  rewardMultiplier: s.rewardMultiplier * reward,
  critChance: s.critChance,
  critDamage: s.critDamage,
  bossDamage: s.bossDamage,
  maxHp: s.maxHp,
  defense: s.defense,
  hpRegen: s.hpRegen,
  xpMultiplier: s.xpMultiplier,
  bugFind: s.bugFind,
  materialFind: s.materialFind,
  evade: s.evade,
  boostBonus: s.boostBonus,
);

/// 서버가 상한을 잴 때처럼 공격만 [mult] 배로 준 능력치(actions.dart).
CharacterStats _boosted(CharacterStats s, double mult) => CharacterStats(
  attack: s.attack * mult,
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
  evade: s.evade,
  boostBonus: s.boostBonus,
);
