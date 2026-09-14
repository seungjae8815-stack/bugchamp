// "현실적 최고치" 전투력과, 그 대비 지금 전력이 몇 % 인가.
//
// balance_sim(평균 유저)과 zone_check(계정 하나)가 **같은 정의**로 잰다.
// 정의는 tool/balance_targets.json → ceiling 에 있다(2026-09-15 사장님 확정).
//
// ⚠️ 비교할 두 값은 **같은 순서·같은 함수**로 조립해야 한다 — 한쪽만 버프나
// 종 패시브가 실리면 %가 통째로 어긋난다. 그래서 [composeStats] 하나를 둘 다 쓴다.
// 들어가는 것: 강화 + 레벨 + 곤충 수 + 펫 + 장비 + 도감 (+ 치명확률 상한).
// 빠지는 것: 버프 · 탭 부스트 · 종 패시브(일시적이거나 편성에 따라 갈린다).
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';

const _dataDir = '../app/assets/data';

Map<String, dynamic> _readData(String name) =>
    jsonDecode(File('$_dataDir/$name').readAsStringSync())
        as Map<String, dynamic>;

/// balance_targets.json.
class BalanceTargets {
  BalanceTargets._(this.raw);

  factory BalanceTargets.load() => BalanceTargets._(
    jsonDecode(File('tool/balance_targets.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  final Map<String, dynamic> raw;

  List<double> get tierDays => [
    for (final v in raw['tierDays'] as List) (v as num).toDouble(),
  ];

  List<double> get finalBossPowerPct => [
    for (final v in raw['finalBossPowerPct'] as List) (v as num).toDouble(),
  ];

  Map<String, dynamic> get ceiling => raw['ceiling'] as Map<String, dynamic>;

  Map<String, dynamic> get accumulation =>
      raw['accumulation'] as Map<String, dynamic>;

  /// [key] 곡선을 [day] 에서 선형 보간한다(끝을 넘으면 끝값).
  double curveAt(String key, double day) {
    final pts = [
      for (final p in accumulation[key] as List)
        ((p as List)[0] as num).toDouble(),
    ];
    final vals = [
      for (final p in accumulation[key] as List)
        ((p as List)[1] as num).toDouble(),
    ];
    if (day <= pts.first) return vals.first;
    for (var i = 1; i < pts.length; i++) {
      if (day <= pts[i]) {
        final t = (day - pts[i - 1]) / (pts[i] - pts[i - 1]);
        return vals[i - 1] + (vals[i] - vals[i - 1]) * t;
      }
    }
    return vals.last;
  }
}

/// 게임 데이터 묶음(시뮬이 필요한 것만).
class CeilingData {
  CeilingData._({
    required this.pet,
    required this.items,
    required this.dex,
    required this.speciesCount,
    required this.forge,
  });

  factory CeilingData.load() => CeilingData._(
    pet: PetConfig.fromJson(_readData('pets.json')),
    items: ItemConfig.fromJson(_readData('items.json')),
    dex: DexConfig.fromJson(_readData('dex.json')),
    speciesCount: (_readData('species.json')['species'] as List).length,
    forge: ForgeConfig.fromJson(_readData('forge.json')),
  );

  final PetConfig pet;
  final ItemConfig items;
  final DexConfig dex;
  final int speciesCount;
  final ForgeConfig forge;
}

/// 전력의 재료. 유저든 최고치든 이 모양으로 넣는다.
typedef PowerParts = ({
  Map<UpgradeKind, int> upgrades,
  int level,
  double petAttackMult,
  double petHpMult,
  Map<ItemOptionKind, double> gear,
  int dexConquered,
});

/// 앱의 `_stats` 와 같은 순서로 쌓는다(버프·종 패시브 제외).
CharacterStats composeStats(RunConfig run, CeilingData data, PowerParts p) {
  final base = deriveStats(
    run,
    upgradeLevels: p.upgrades,
    characterLevel: p.level,
    bugsCollected: 50,
  );
  var s = CharacterStats(
    attack: base.attack * p.petAttackMult,
    attackSpeed: base.attackSpeed,
    rewardMultiplier: base.rewardMultiplier,
    critChance: base.critChance,
    critDamage: base.critDamage,
    bossDamage: base.bossDamage,
    maxHp: base.maxHp * p.petHpMult,
    defense: base.defense,
    hpRegen: base.hpRegen,
    xpMultiplier: base.xpMultiplier,
    bugFind: base.bugFind,
    materialFind: base.materialFind,
    moveSpeed: base.moveSpeed,
    boostBonus: base.boostBonus,
  );
  s = applyEquipment(s, p.gear, critBudget: run.critBudgetGear);
  s = data.dex.apply(s, p.dexConquered, p.dexConquered);
  return capCritChance(s, run.critChanceMax);
}

/// 보스를 잡는 힘(치명·보스피해·공속 포함 DPS). 표를 맞출 때 쓴다.
double bossDps(CharacterStats s) =>
    baselineHitPower(s, boss: true) * s.attackSpeed;

/// 현실적 최고치의 재료 — [level] 은 유저의 지금 레벨(레벨은 %에서 뺀다).
PowerParts ceilingParts(
  RunConfig run,
  CeilingData data,
  Map<String, dynamic> spec, {
  required int level,
}) {
  final pets = spec['pets'] as Map<String, dynamic>;
  final potential = (pets['potential'] as num).toInt();
  final one = (
    grade: Grade.fromKey(pets['grade'] as String),
    sizeMult: (pets['sizeMult'] as num).toDouble(),
    potential: potential,
    enhanceTotal:
        potential *
        (pets['enhancePerPotential'] as num).toInt() *
        (pets['parts'] as num).toInt(),
    stage: LifeStage.adult,
    level: data.pet.tierCaps.isEmpty ? 1 : data.pet.tierCaps.last,
    trait: BugTrait.values.firstWhere((t) => t.key == pets['trait']),
    variant: BugVariant.values.firstWhere((v) => v.key == pets['variant']),
    passive: null,
  );
  final bonus = computePetBonus(
    List.filled((pets['count'] as num).toInt(), one),
    data.pet,
  );

  final gearSpec = spec['gear'] as Map<String, dynamic>;
  final tierIdx = data.items.tiers.indexWhere((t) => t.id == gearSpec['tier']);
  if (tierIdx < 0) {
    throw StateError('ceiling.gear.tier 오타: ${gearSpec['tier']}');
  }
  // 롤 백분위 q 의 값 = min + (max-min) × q^k (r 이 균등이라 백분위가 곧 r).
  final roll = math.pow(
    (gearSpec['rollPercentile'] as num).toDouble(),
    data.items.optionCurve,
  );
  final gear = <ItemOptionKind, double>{};
  (gearSpec['build'] as Map<String, dynamic>).forEach((k, n) {
    final kind = ItemOptionKind.fromKey(k);
    final range = data.items.optionPool.firstWhere((r) => r.kind == kind);
    final v = range.min + (range.maxAt(tierIdx) - range.min) * roll;
    gear[kind] = (gear[kind] ?? 0) + v * (n as num).toDouble();
  });

  return (
    upgrades: {
      for (final e in run.upgrades.entries)
        if (e.value.maxLevel != null) e.key: e.value.maxLevel!,
    },
    level: level,
    petAttackMult: bonus.attackMult,
    petHpMult: bonus.hpMult,
    gear: gear,
    dexConquered: data.speciesCount,
  );
}

/// [player] 가 현실적 최고치의 몇 %인가(0~1+).
///
/// 잣대는 화면의 **전투력**(`combatPower`)이다 — 사장님이 고른 기준이
/// "합친 전투력"이라서다(2026-09-15). 보스 DPS 로 재면 체력 쪽이 빠진다.
double powerPct(
  RunConfig run,
  CeilingData data,
  Map<String, dynamic> spec,
  PowerParts player,
) {
  final me = combatPower(composeStats(run, data, player));
  final top = combatPower(
    composeStats(run, data, ceilingParts(run, data, spec, level: player.level)),
  );
  return top <= 0 ? 0 : me / top;
}

/// 축별로 떼어 본다 — "무엇이 모자라서 %가 낮은가". 나머지 축을 최고치로
/// 두고 그 축만 유저 값으로 바꿨을 때의 % 다.
Map<String, double> powerPctByAxis(
  RunConfig run,
  CeilingData data,
  Map<String, dynamic> spec,
  PowerParts player,
) {
  final top = ceilingParts(run, data, spec, level: player.level);
  final topCp = combatPower(composeStats(run, data, top));
  double with_(PowerParts p) =>
      topCp <= 0 ? 0 : combatPower(composeStats(run, data, p)) / topCp;
  return {
    '강화': with_((
      upgrades: player.upgrades,
      level: top.level,
      petAttackMult: top.petAttackMult,
      petHpMult: top.petHpMult,
      gear: top.gear,
      dexConquered: top.dexConquered,
    )),
    '펫': with_((
      upgrades: top.upgrades,
      level: top.level,
      petAttackMult: player.petAttackMult,
      petHpMult: player.petHpMult,
      gear: top.gear,
      dexConquered: top.dexConquered,
    )),
    '장비': with_((
      upgrades: top.upgrades,
      level: top.level,
      petAttackMult: top.petAttackMult,
      petHpMult: top.petHpMult,
      gear: player.gear,
      dexConquered: top.dexConquered,
    )),
    '도감': with_((
      upgrades: top.upgrades,
      level: top.level,
      petAttackMult: top.petAttackMult,
      petHpMult: top.petHpMult,
      gear: top.gear,
      dexConquered: player.dexConquered,
    )),
  };
}

/// 최고치 한 줄 요약(보고서 머리말).
String describeCeiling(
  RunConfig run,
  CeilingData data,
  Map<String, dynamic> spec,
) {
  final p = ceilingParts(run, data, spec, level: 1);
  final s = composeStats(run, data, p);
  final gear = p.gear.entries
      .map((e) => '${e.key.key} +${e.value.toStringAsFixed(0)}%')
      .join(' · ');
  return '펫 공격 x${p.petAttackMult.toStringAsFixed(2)} · 체력 x${p.petHpMult.toStringAsFixed(2)}\n'
      '  장비 $gear\n'
      '  도감 ${p.dexConquered}종 · 전투력(레벨1) ${combatPower(s).toStringAsExponential(3)}';
}
