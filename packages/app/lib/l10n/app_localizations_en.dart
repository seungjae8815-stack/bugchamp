// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Bug Champ';

  @override
  String get navHome => 'Home';

  @override
  String get navCollect => 'Collect';

  @override
  String get navStorage => 'Storage';

  @override
  String get homeTitle => 'Traps';

  @override
  String get homeMaterialsTitle => 'Materials';

  @override
  String slotLabel(int index) {
    return 'Slot $index';
  }

  @override
  String get slotEmpty => 'Empty';

  @override
  String get slotInstallCta => 'Install a trap';

  @override
  String elapsedLabel(String duration) {
    return 'Elapsed $duration / max 8h';
  }

  @override
  String get collectButton => 'Claim';

  @override
  String collectResultSnack(int materialCount, int bugCount) {
    return 'Got $materialCount materials, $bugCount bugs!';
  }

  @override
  String get collectNothingSnack => 'Nothing to collect yet';

  @override
  String get homeYard => 'My Yard';

  @override
  String get collecting => 'Collecting';

  @override
  String get readyLabel => 'Ready';

  @override
  String get collectAll => 'Collect all';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String offlineBanner(int materialCount, int bugCount) {
    return 'Welcome back! $materialCount materials, $bugCount bugs waiting';
  }

  @override
  String chapterTitle(int n) {
    return 'Chapter $n';
  }

  @override
  String chapterRemaining(int count) {
    return '$count more bugs to the next chapter';
  }

  @override
  String get statusForaging => 'Foraging…';

  @override
  String get statusIdle => 'Install a trap to start foraging';

  @override
  String get navUpgrade => 'Upgrade';

  @override
  String get navShop => 'Shop';

  @override
  String get upgradeTitle => 'Upgrades';

  @override
  String get retreat => 'Retreat!';

  @override
  String offlineReward(String gold, String xp) {
    return 'Welcome back! +$gold gold, +$xp XP';
  }

  @override
  String get upAttack => 'Harvest Power';

  @override
  String get upAttackSpeed => 'Swift Hands';

  @override
  String get upCrit => 'Weak Point';

  @override
  String get upCritDamage => 'Heavy Blow';

  @override
  String get upBossDamage => 'Fighting Spirit';

  @override
  String get upMaxHp => 'Grit';

  @override
  String get upDefense => 'Toughness';

  @override
  String get upRegen => 'Recovery';

  @override
  String get upReward => 'Merchant Skill';

  @override
  String get upXp => 'Foraging Lore';

  @override
  String get upBugFind => 'Bug Sense';

  @override
  String get upMaterialFind => 'Careful Harvest';

  @override
  String get upMoveSpeed => 'Footwork';

  @override
  String get upBoost => 'Focus';

  @override
  String get upBugBuff => 'Codex Mastery';

  @override
  String get statAttack => 'Attack';

  @override
  String get statAttackSpeed => 'Attack Speed';

  @override
  String get statReward => 'Gold Bonus';

  @override
  String get notEnoughGold => 'Not enough gold';

  @override
  String get bossLabel => 'BOSS';

  @override
  String get tapBoostHint => 'Tap to boost!';

  @override
  String levelBadge(int n) {
    return 'Lv $n';
  }

  @override
  String get collectTitle => 'Fields';

  @override
  String get collectPickTrap => 'Choose a trap';

  @override
  String get collectPickSlot => 'Choose a slot';

  @override
  String collectInstalledSnack(String field, String trap) {
    return 'Installed $trap at $field';
  }

  @override
  String get locked => 'Locked';

  @override
  String get install => 'Install';

  @override
  String get storageTitle => 'Storage';

  @override
  String get storageEmpty => 'No bugs yet.\nGather some from the fields!';

  @override
  String storageCount(int count) {
    return '$count bugs';
  }

  @override
  String bugSize(String mm) {
    return '${mm}mm';
  }

  @override
  String bugPotential(int stars) {
    return '$stars★';
  }

  @override
  String get gradeCommon => 'Common';

  @override
  String get gradeUncommon => 'Uncommon';

  @override
  String get gradeRare => 'Rare';

  @override
  String get gradeEpic => 'Epic';

  @override
  String get gradeLegendary => 'Legendary';

  @override
  String get specialtyStrike => 'Strike';

  @override
  String get specialtyGrip => 'Grip';

  @override
  String get specialtyToss => 'Toss';

  @override
  String get temperamentAggressive => 'Aggressive';

  @override
  String get temperamentCautious => 'Cautious';

  @override
  String get temperamentCunning => 'Cunning';

  @override
  String get temperamentSteadfast => 'Steadfast';

  @override
  String get temperamentFickle => 'Fickle';

  @override
  String get sexMale => 'Male';

  @override
  String get sexFemale => 'Female';

  @override
  String get materialChitin => 'Chitin';

  @override
  String get materialMineral => 'Mineral';

  @override
  String get materialSap => 'Sap Crystal';

  @override
  String get materialJelly => 'Bug Jelly';

  @override
  String get combatPowerLabel => 'Power';

  @override
  String get chatTitle => 'Chat';

  @override
  String get chatPlaceholder => 'Chat (coming soon) — tap to open';

  @override
  String get characterTitle => 'My Character';

  @override
  String get statCombatPower => 'Combat Power';

  @override
  String get statCrit => 'Crit';

  @override
  String get statMaxHp => 'Max HP';

  @override
  String get statDefense => 'Defense';

  @override
  String get rankingTitle => 'Ranking';

  @override
  String get mailTitle => 'Mailbox';

  @override
  String get mailEmpty => 'No new mail';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsNickname => 'Nickname';

  @override
  String get settingsNicknameHint => 'Enter a name';

  @override
  String get actionSave => 'Save';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionClose => 'Close';

  @override
  String get exitTitle => 'Exit game';

  @override
  String get exitConfirm => 'Quit the game?';

  @override
  String get exitAction => 'Quit';

  @override
  String get questHunt => 'Monster Hunt';

  @override
  String get buffTitle => 'Buffs';

  @override
  String get buffSheetTitle => 'Activate a buff';

  @override
  String get buffWatchAd => 'Watch ad';

  @override
  String buffMinutes(int minutes) {
    return '${minutes}m';
  }

  @override
  String buffActivatedSnack(String buff, int minutes) {
    return '$buff active! (${minutes}m)';
  }

  @override
  String get buffGoldRush => 'Gold Rush';

  @override
  String get buffGoldRushDesc => 'Gold gain ×2';

  @override
  String get buffXpBoost => 'XP Boost';

  @override
  String get buffXpBoostDesc => 'XP gain ×2';

  @override
  String get buffFrenzy => 'Frenzy';

  @override
  String get buffFrenzyDesc => 'Attack & attack speed up';

  @override
  String get buffGatherer => 'Gatherer\'s Touch';

  @override
  String get buffGathererDesc => 'Material gain ×2';

  @override
  String get buffLuckyWind => 'Lucky Wind';

  @override
  String get buffLuckyWindDesc => 'Bug find rate ×2';

  @override
  String get enhanceTitle => 'Enhance Parts';

  @override
  String get partHornJaw => 'Horn/Jaw';

  @override
  String get partCuticle => 'Cuticle';

  @override
  String get partWing => 'Wings';

  @override
  String get partBuild => 'Build';

  @override
  String get enhanceAction => 'Enhance';

  @override
  String get enhanceMaxed => 'MAX';

  @override
  String enhanceCap(int cur, int max) {
    return 'Enhance $cur/$max';
  }

  @override
  String enhancePerLevel(String pct) {
    return '+$pct%/Lv';
  }

  @override
  String get equipTitle => 'Equipped Pets';

  @override
  String get equipEmpty => 'Empty';

  @override
  String get equipAction => 'Equip';

  @override
  String get unequipAction => 'Unequip';

  @override
  String get equipFull => 'Equip slots are full';

  @override
  String get equippedBadge => 'ON';

  @override
  String petBonus(String atk, String hp) {
    return 'Pet bonus · ATK +$atk% · HP +$hp%';
  }

  @override
  String get stageEgg => 'Egg';

  @override
  String get stageLarva => 'Larva';

  @override
  String get stagePupa => 'Pupa';

  @override
  String get stageAdult => 'Adult';

  @override
  String get evolveTitle => 'Evolve';

  @override
  String evolveNext(String next, String time) {
    return '$time to $next';
  }

  @override
  String get evolveReady => 'Ready to evolve';

  @override
  String get evolveMaxed => 'Fully evolved (Adult)';

  @override
  String get accelerateAction => 'Speed up';

  @override
  String get synthTitle => 'Synthesis (★ up)';

  @override
  String get synthDo => 'Synthesize';

  @override
  String synthDesc(int have, int need) {
    return 'Same species $have/$need · Potential +1';
  }

  @override
  String get synthMaxed => 'Max potential';

  @override
  String get synthSnack => 'Synthesis complete! Potential +1';

  @override
  String get petEffectTitle => 'Equip effect';

  @override
  String petAtkBonus(String v) {
    return 'Pet ATK +$v%';
  }

  @override
  String petHpBonus(String v) {
    return 'Pet HP +$v%';
  }

  @override
  String get trainTitle => 'Train';

  @override
  String get trainLevel => 'Train level';

  @override
  String get trainAction => 'Train';

  @override
  String get trainMaxed => 'Max level';

  @override
  String get trainSnack => 'Trained! Level +1';

  @override
  String get disassembleTitle => 'Disassemble';

  @override
  String disassembleDesc(int n) {
    return 'Convert to $n jelly';
  }

  @override
  String get disassembleAction => 'Disassemble';

  @override
  String get disassembleSnack => 'Disassembled';

  @override
  String get bugDescTitle => 'About';

  @override
  String get onlyAdultTrain => 'Only adults can be trained';

  @override
  String get craftTitle => 'Craft';

  @override
  String get craftMake => 'Craft';

  @override
  String craftPotion(String buff) {
    return '$buff Potion';
  }

  @override
  String get craftAllPotion => 'All-in-One Potion';

  @override
  String craftedSnack(String name) {
    return 'Crafted $name!';
  }

  @override
  String get missionsTitle => 'Missions';

  @override
  String get missionKillMonsters => 'Hunt Monsters';

  @override
  String get missionKillBosses => 'Defeat Bosses';

  @override
  String get missionBuyUpgrades => 'Upgrade Stats';

  @override
  String get missionReachStage => 'Reach Stage';

  @override
  String get missionClaim => 'Claim';

  @override
  String get missionComplete => 'Complete! Tap to claim';

  @override
  String get missionClaimedSnack => 'Mission reward claimed!';

  @override
  String get upAttackDesc => 'Increases damage dealt per hit.';

  @override
  String get upAttackSpeedDesc => 'More attacks per second; faster hunting.';

  @override
  String get upCritDesc => 'Increases critical hit chance.';

  @override
  String get upCritDamageDesc =>
      'Increases the critical hit damage multiplier.';

  @override
  String get upBossDamageDesc => 'Extra damage dealt to bosses.';

  @override
  String get upMaxHpDesc => 'Increases max HP so you last longer.';

  @override
  String get upDefenseDesc => 'Reduces damage taken from enemies.';

  @override
  String get upRegenDesc => 'Increases HP regenerated per second.';

  @override
  String get upRewardDesc => 'More gold earned per monster kill.';

  @override
  String get upXpDesc => 'More XP earned per monster kill.';

  @override
  String get upBugFindDesc => 'Increases the chance to find bugs.';

  @override
  String get upMaterialFindDesc => 'Increases enhancement materials gained.';

  @override
  String get upMoveSpeedDesc => 'Faster travel to the next hunting spot.';

  @override
  String get upBoostDesc => 'Strengthens the tap-to-boost effect.';

  @override
  String get upBugBuffDesc => 'Bonus scales with the number of bugs collected.';

  @override
  String get tagCommonMaterial => 'Material';

  @override
  String get tagPremium => 'Premium';

  @override
  String get materialChitinDesc =>
      'A hard exoskeleton shard. Used for advanced upgrade costs and horn/jaw enhancement.';

  @override
  String get materialMineralDesc =>
      'A hard mined mineral. Used for advanced upgrade costs and cuticle enhancement.';

  @override
  String get materialSapDesc =>
      'Hardened crystallized tree sap. Used for advanced upgrade costs and wing enhancement.';

  @override
  String get materialJellyDesc =>
      'A special premium currency. Used for crafting (All-in-One Potion) and special goods.';
}
