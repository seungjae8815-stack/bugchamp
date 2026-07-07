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
}
