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
    pets.add(
      petStatOf(
        bug,
        sp,
        cfg,
        now,
        trainMult: trainPetMult(
          save,
          bug.id,
          (data.battleConfig ?? const BattleConfig()).training,
        ),
      ),
    );
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

/// 전투력 **표시용** 능력치 — 영구 능력치 + 장비(2026-10-04 사장님 확정).
///
/// 장비를 빼고 보여 주던 시절, 좋은 장비를 껴도 전투력 숫자가 그대로라 "장비가 차이가 없다"로 읽혔다.
/// 장비는 회차가 바뀌어도 남는 영구 축이라 표시에 넣는다(버프는 여전히 뺀다).
/// ⚠️ **적응형 몬스터 기준에 쓰지 않는다** — 기준은 [permanentStatsOf](장비 밖)다. 여기를 기준에
/// 넣으면 장비를 낄 때 몬스터도 같이 세진다(§2.7).
CharacterStats displayStatsOf(SaveGame save, GameData data, DateTime now) =>
    applyEquipment(
      permanentStatsOf(save, data, now),
      equipmentBonus(save.equippedItems.values, data.itemConfig),
      critBudget: data.runConfig!.critBudgetGear,
    );

/// 화면에 보이는 전투력(홈 상단) — 랭킹 진행도의 동률을 가르는 값이기도 하다.
/// 게임 데이터가 아직 없으면 null(모르는 값을 0 으로 올리면 서버를 덮어쓴다).
double? displayCombatPower(SaveGame save, GameData? data, DateTime now) {
  if (data?.runConfig == null) return null;
  return combatPower(displayStatsOf(save, data!, now));
}
