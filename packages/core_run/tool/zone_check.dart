// 세이브 하나를 놓고 "지금 전력이 어느 사냥터에서 벽을 만나는가"를 본다.
//
// 사냥터 구조의 몬스터는 **고정 세기**라(적응형 끔), 유저마다 체감이 갈리는
// 이유가 전부 이 표에 드러난다. 시뮬(balance_sim)이 "평균 유저"를 재는 도구라면
// 이 도구는 **실제 계정 하나**를 잰다 — 문의가 들어왔을 때 쓴다.
//
// 사용: dart run tool/zone_check.dart <세이브 json> [--no-gear] [--tier=N]
//   세이브 json = Supabase saves 행(배열) 또는 data 객체 그대로.
//   --tier 를 주면 세이브의 회차 대신 그 난이도의 표로 잰다.
import 'dart:convert';
import 'dart:io';

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';

import 'power_ceiling.dart';

Map<String, dynamic> _read(String name) =>
    jsonDecode(File('../app/assets/data/$name').readAsStringSync())
        as Map<String, dynamic>;

void main(List<String> args) {
  final path = args.firstWhere((a) => !a.startsWith('--'));
  final noGear = args.contains('--no-gear');
  final raw = jsonDecode(File(path).readAsStringSync());
  final data = (raw is List ? raw[0]['data'] : raw) as Map<String, dynamic>;

  final cfg = RunConfig.fromJson(_read('run_config.json'));
  final items = ItemConfig.fromJson(_read('items.json'));
  final petCfg = PetConfig.fromJson(_read('pets.json'));
  final species = {
    for (final s in (_read('species.json')['species'] as List))
      (s as Map<String, dynamic>)['id'] as String: Species.fromJson(s),
  };
  final ceilData = CeilingData.load();
  final targets = BalanceTargets.load();

  final levels = <UpgradeKind, int>{};
  (data['upgradeLevels'] as Map?)?.forEach((k, v) {
    final kind = UpgradeKind.values.where((u) => u.key == k);
    if (kind.isNotEmpty) levels[kind.first] = (v as num).toInt();
  });
  final tierArg = args
      .map((a) => RegExp(r'^--tier=(\d+)$').firstMatch(a))
      .whereType<RegExpMatch>()
      .firstOrNull;
  final tier = tierArg != null
      ? int.parse(tierArg.group(1)!)
      : (data['difficultyTier'] as num?)?.toInt() ?? 0;
  final level = (data['level'] as num?)?.toInt() ?? 1;

  final bare = deriveStats(
    cfg,
    upgradeLevels: levels,
    characterLevel: level,
    bugsCollected: (data['bugs'] as List?)?.length ?? 0,
  );

  // ── 장착 곤충(펫) — 앱의 permanentStatsOf 와 같은 조립 ──
  final now = DateTime.now().toUtc();
  final bugs = {
    for (final b in (data['bugs'] as List? ?? const []))
      (b as Map<String, dynamic>)['id'] as String: b,
  };
  final pets = <PetStat>[];
  final inputs = <PetAttackerInput>[];
  for (final id in (data['equippedBugIds'] as List? ?? const [])) {
    final b = bugs[id];
    if (b == null) continue;
    final bug = IndividualBug.fromJson(b);
    final sp = species[bug.speciesId];
    if (sp == null) continue;
    final ps = petStatOf(bug, sp, petCfg, now);
    pets.add(ps);
    final c = petContribution(ps, petCfg);
    inputs.add((
      bugId: bug.id,
      element: bug.element,
      spd: sp.baseStats.spd,
      attack: c.attack,
      hp: c.hp,
    ));
  }
  final pb = computePetBonus(pets, petCfg);
  final split = splitAttack(
    pets: inputs,
    playerInterval: 1,
    spdReference: petCfg.attackSpdReference,
    intervalMin: petCfg.attackIntervalMin,
    intervalMax: petCfg.attackIntervalMax,
  );
  final perm = CharacterStats(
    attack: bare.attack * pb.attackMult,
    attackSpeed: bare.attackSpeed,
    rewardMultiplier: bare.rewardMultiplier,
    critChance: bare.critChance,
    critDamage: bare.critDamage,
    bossDamage: bare.bossDamage,
    maxHp: bare.maxHp * pb.hpMult,
    defense: bare.defense,
    hpRegen: bare.hpRegen,
    xpMultiplier: bare.xpMultiplier,
    bugFind: bare.bugFind,
    materialFind: bare.materialFind,
    moveSpeed: bare.moveSpeed,
    boostBonus: bare.boostBonus,
  );

  // 장비 — **상한을 먼저 적용**한다(trimItemOptions). 안 그러면 옛 세이브의
  // 상한 초과 옵션이 그대로 더해져 앱보다 세게 나온다.
  var st = perm;
  var gearNote = '장비 없음';
  var gearBonus = const <ItemOptionKind, double>{};
  final eq = (data['equippedItems'] as Map?) ?? const {};
  if (!noGear && eq.isNotEmpty) {
    final equipped = <EquipItem>[];
    for (final v in eq.values) {
      final item = EquipItem.fromJson((v as Map).cast<String, dynamic>());
      equipped.add(trimItemOptions(item, items));
    }
    gearBonus = equipmentBonus(equipped, items);
    st = applyEquipment(st, gearBonus, critBudget: cfg.critBudgetGear);
    gearNote =
        '장비 ${equipped.length}부위 · '
        '공격 +${(gearBonus[ItemOptionKind.attack] ?? 0).toStringAsFixed(0)}% · '
        '공속 +${(gearBonus[ItemOptionKind.attackSpeed] ?? 0).toStringAsFixed(0)}% · '
        '치명피해 +${(gearBonus[ItemOptionKind.critDamage] ?? 0).toStringAsFixed(0)}% · '
        '보스 +${(gearBonus[ItemOptionKind.bossDamage] ?? 0).toStringAsFixed(0)}%';
  }

  final hit = baselineHitPower(st);
  final bossHit = baselineHitPower(st, boss: true);
  // 앱에서 캐릭터 체력 = 팀 체력 × 캐릭터 몫(playerHpMult). 곤충 체력은 팀을
  // 늘리지만 그만큼 캐릭터 몫이 줄어 **캐릭터 체력은 펫이 없을 때와 같다**.
  final charHp = st.maxHp * split.playerHpMult;
  stdout.writeln(
    '회차 $tier · 레벨 $level · 한 대 ${hit.toStringAsFixed(0)} '
    '· 팀 체력 ${st.maxHp.toStringAsFixed(0)} (캐릭터 몫 ${charHp.toStringAsFixed(0)}) '
    '· 방어 ${st.defense.toStringAsFixed(0)} · 공속 ${st.attackSpeed.toStringAsFixed(2)}',
  );
  stdout.writeln(
    '곤충 ${pets.length}마리 · 공격 x${pb.attackMult.toStringAsFixed(2)} '
    '· 체력 x${pb.hpMult.toStringAsFixed(2)} · 캐릭터 몫 '
    '${(split.playerHpMult * 100).toStringAsFixed(0)}%',
  );
  stdout.writeln(gearNote);
  stdout.writeln(
    '업그레이드: ${levels.entries.map((e) => '${e.key.key}=${e.value}').join(' ')}',
  );

  final parts = (
    upgrades: levels,
    level: level,
    petAttackMult: pb.attackMult,
    petHpMult: pb.hpMult,
    gear: gearBonus,
    dexConquered: 0,
  );
  final axis = powerPctByAxis(cfg, ceilData, targets.ceiling, parts);
  stdout.writeln(
    '최고치 대비(곱 기준 · 도감 0 가정): '
    '${axis.entries.map((e) => '${e.key} ${(e.value * 100).toStringAsFixed(0)}%').join(' · ')}',
  );
  stdout.writeln('');
  stdout.writeln('사냥터 | 타격수 | 보스타격 | 한대(캐릭터 %) | 펫체력 뺀 기준이면 | 마리당 초');
  for (var z = 1; z <= cfg.zonesPerTier; z++) {
    final stage = cfg.zoneStartStage(z);
    final hp = habitatMaxHp(cfg, stage - 1, tier: tier).toDouble();
    final bhp = bossMaxHp(cfg, stage - 1, tier: tier).toDouble();
    // 앱과 **같은 인자**로 부른다 — 기준 맷집은 장비 뺀 영구 전력, 장비 몫은 따로.
    double biteWith(CharacterStats base, CharacterStats geared) {
      final threat = habitatThreat(
        cfg,
        stage - 1,
        tier: tier,
        playerToughness: toughnessOf(base),
        gearToughness: toughnessOf(geared),
      );
      return threat * cfg.enemyAtkInterval * 100 / (100 + st.defense) / charHp;
    }

    final biteNow = biteWith(perm, st);
    // 비교: 위협 기준에서 곤충 체력을 뺐다면(캐릭터 몫 기준).
    final permChar = CharacterStats(
      attack: perm.attack,
      attackSpeed: perm.attackSpeed,
      rewardMultiplier: perm.rewardMultiplier,
      critChance: perm.critChance,
      critDamage: perm.critDamage,
      bossDamage: perm.bossDamage,
      maxHp: perm.maxHp * split.playerHpMult,
      defense: perm.defense,
      hpRegen: perm.hpRegen,
      xpMultiplier: perm.xpMultiplier,
      bugFind: perm.bugFind,
      materialFind: perm.materialFind,
      moveSpeed: perm.moveSpeed,
      boostBonus: perm.boostBonus,
    );
    final stChar = CharacterStats(
      attack: st.attack,
      attackSpeed: st.attackSpeed,
      rewardMultiplier: st.rewardMultiplier,
      critChance: st.critChance,
      critDamage: st.critDamage,
      bossDamage: st.bossDamage,
      maxHp: charHp,
      defense: st.defense,
      hpRegen: st.hpRegen,
      xpMultiplier: st.xpMultiplier,
      bugFind: st.bugFind,
      materialFind: st.materialFind,
      moveSpeed: st.moveSpeed,
      boostBonus: st.boostBonus,
    );
    final biteFixed = biteWith(permChar, stChar);
    final hits = hp / hit;
    stdout.writeln(
      '${z.toString().padLeft(4)}   '
      '${hits.toStringAsFixed(1).padLeft(7)} '
      '${(bhp / bossHit).toStringAsFixed(1).padLeft(9)} '
      '${(biteNow * 100).toStringAsFixed(1).padLeft(13)}% '
      '${(biteFixed * 100).toStringAsFixed(1).padLeft(17)}% '
      '${(hits / st.attackSpeed).toStringAsFixed(2).padLeft(9)}',
    );
  }
}
