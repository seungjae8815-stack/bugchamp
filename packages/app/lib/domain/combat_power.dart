import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';

import '../data/game_data.dart';

/// 업그레이드·레벨·곤충 수만의 순수 능력치(펫·버프·장비 미포함).
CharacterStats baseStatsOf(SaveGame save, RunConfig config) => deriveStats(
  config,
  upgradeLevels: save.upgradeLevels,
  characterLevel: save.level,
  bugsCollected: save.bugs.length,
);

/// 장착 곤충(펫) 보너스까지 반영한 **영구** 능력치 — 버프는 뺀다.
///
/// 홈 상단 전투력과 랭킹 전투력이 **이 함수 하나**를 쓴다. 따로 계산하면
/// "내 화면엔 1.2M 인데 랭킹엔 980K"가 된다.
CharacterStats permanentStatsOf(SaveGame save, GameData data, DateTime now) {
  final base = baseStatsOf(save, data.runConfig!);
  final cfg = data.petConfig;
  if (cfg == null || save.equippedBugIds.isEmpty) return base;
  final pets = <PetStat>[];
  for (final id in save.equippedBugIds) {
    IndividualBug? bug;
    for (final b in save.bugs) {
      if (b.id == id) {
        bug = b;
        break;
      }
    }
    if (bug == null) continue;
    final sp = data.speciesById[bug.speciesId];
    if (sp == null) continue;
    pets.add(petStatOf(bug, sp, cfg, now));
  }
  final pb = computePetBonus(pets, cfg);
  return CharacterStats(
    attack: base.attack * pb.attackMult,
    attackSpeed: base.attackSpeed,
    rewardMultiplier: base.rewardMultiplier,
    critChance: base.critChance,
    critDamage: base.critDamage,
    bossDamage: base.bossDamage,
    maxHp: base.maxHp * pb.hpMult,
    defense: base.defense,
    hpRegen: base.hpRegen,
    xpMultiplier: base.xpMultiplier,
    bugFind: base.bugFind,
    materialFind: base.materialFind,
    moveSpeed: base.moveSpeed,
    boostBonus: base.boostBonus,
  );
}

/// 화면에 보이는 전투력(홈 상단) — 랭킹 진행도의 동률을 가르는 값이기도 하다.
/// 게임 데이터가 아직 없으면 null(모르는 값을 0 으로 올리면 서버를 덮어쓴다).
double? displayCombatPower(SaveGame save, GameData? data, DateTime now) {
  if (data?.runConfig == null) return null;
  return combatPower(permanentStatsOf(save, data!, now));
}
