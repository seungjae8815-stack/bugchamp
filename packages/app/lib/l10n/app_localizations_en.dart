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
  String get navBattle => 'Battle';

  @override
  String get battleTitle => 'Bug Duel';

  @override
  String battleTrophies(int n) {
    return 'Trophies $n';
  }

  @override
  String get battleMyTeam => 'My Team (3)';

  @override
  String get autoBattleRunning => 'Auto battle in progress';

  @override
  String get battleStart => 'Start Battle';

  @override
  String get battleNeedBugs => 'You need adult bugs to duel';

  @override
  String get battlePickTitle => 'Choose a bug (adult)';

  @override
  String get battleEmptySlot => 'Empty';

  @override
  String get battleWin => 'Victory!';

  @override
  String get battleLose => 'Defeat…';

  @override
  String get battleDraw => 'Draw';

  @override
  String get battleReward => 'Reward';

  @override
  String get battleVs => 'VS';

  @override
  String get battleRestrain => 'Super effective!';

  @override
  String get battleFoe => 'Opponent';

  @override
  String get battleLog => 'Battle log';

  @override
  String get battleAgain => 'Duel again';

  @override
  String get battleTeamEmpty => 'Add bugs to your team';

  @override
  String get battleSkip => 'Skip';

  @override
  String battleHpPct(String v) {
    return 'HP $v%';
  }

  @override
  String get battleAuto => 'Auto Battle';

  @override
  String get battleManual => 'Manual Battle';

  @override
  String get battleManualDesc => 'Mind games — pick every move';

  @override
  String get battleYourMove => 'Choose your move';

  @override
  String get battleEnergy => 'Energy';

  @override
  String get battleClashWin => 'You read them!';

  @override
  String get battleClashLose => 'Caught off guard';

  @override
  String get battleClashEven => 'Feeling it out';

  @override
  String get injuryTitle => 'Recovering';

  @override
  String get injuryDesc => 'Can\'t be fielded in a duel until healed';

  @override
  String injuryHealJelly(int n) {
    return 'Heal now for $n jelly';
  }

  @override
  String get notEnoughJelly => 'Not enough jelly';

  @override
  String get scoutBoard => 'Scout Board';

  @override
  String get scoutRefresh => 'Refresh';

  @override
  String get scoutRefreshFree => 'Refresh (free)';

  @override
  String scoutRefreshJelly(int n) {
    return 'Refresh ($n jelly)';
  }

  @override
  String get scoutRefreshDone => 'No refreshes left';

  @override
  String get scoutEasy => 'Weak';

  @override
  String get scoutEven => 'Even';

  @override
  String get scoutHard => 'Strong';

  @override
  String get leagueBronze => 'Bronze';

  @override
  String get leagueSilver => 'Silver';

  @override
  String get leagueGold => 'Gold';

  @override
  String get leaguePlatinum => 'Platinum';

  @override
  String get leagueDiamond => 'Diamond';

  @override
  String leagueToNext(int n, String name) {
    return '$n🏆 to $name';
  }

  @override
  String get leagueMaxRank => 'Top rank';

  @override
  String get leagueClaimReward => 'Claim promotion';

  @override
  String get leaguePromoTitle => 'Promotion Reward';

  @override
  String get seasonEndTitle => 'Season Over!';

  @override
  String seasonPeak(String name) {
    return 'Rank at close: $name';
  }

  @override
  String seasonTrophyReset(int from, int to) {
    return 'Trophies $from → $to';
  }

  @override
  String seasonEndsIn(String time) {
    return 'Season $time left';
  }

  @override
  String get synergyLabel => 'Synergy';

  @override
  String get synergyHint =>
      'Place 2+ bugs · when a bug powers up the one behind it your team gets stronger (order matters)';

  @override
  String get teamReorderHint => 'Drag to reorder';

  @override
  String get leagueSeasonTitle => 'League · Season';

  @override
  String get modeManual => 'Throw';

  @override
  String get modeAuto => 'Quick';

  @override
  String get opponentWild => 'Wild';

  @override
  String get opponentPick => 'Pick Opponent';

  @override
  String get accountTitle => 'Account';

  @override
  String get accountAnonymous => 'You\'re on a temporary device account';

  @override
  String accountSignedIn(String email) {
    return 'Signed in as $email';
  }

  @override
  String get accountSignIn => 'Sign in with Google';

  @override
  String get accountDelete => 'Delete account';

  @override
  String get accountDeleteTitle => 'Delete your account?';

  @override
  String accountDeleteBody(String word) {
    return 'All bugs, currency, trophies and breeding records will be gone for good.\n\nType «$word» below to confirm.';
  }

  @override
  String get accountDeleteWord => 'DELETE';

  @override
  String get accountDeleteConfirm => 'Delete permanently';

  @override
  String get accountDeleteDone => 'Your account and data were deleted';

  @override
  String get accountDeleteFailed =>
      'Couldn\'t delete. Please try again shortly';

  @override
  String get accountDeleteOffline =>
      'Can\'t delete without an online connection';

  @override
  String get accountDeleteWarnPurchase =>
      'Purchases are not refunded and cannot be restored afterwards.';

  @override
  String get accountSignOut => 'Sign out';

  @override
  String get accountSignedOut => 'Signed out';

  @override
  String get accountSignInFailed => 'Sign-in failed';

  @override
  String get accountWhy =>
      'Sign in to keep your progress when you change phones.';

  @override
  String get accountUnavailable => 'Sign-in isn\'t available in this build';

  @override
  String get accountAnonRisk =>
      'Without signing in, your progress can\'t be recovered if you switch devices or delete the app.';

  @override
  String get loginNudge =>
      'Guest account · tap to sign in and protect your data';

  @override
  String get accountSyncTitle => 'Which progress do you want?';

  @override
  String get accountSyncBody =>
      'This account already has saved progress. Choose which one to keep.';

  @override
  String get accountKeepDevice => 'This device';

  @override
  String get accountUseCloud => 'Load saved';

  @override
  String get cloudTitle => 'Cloud Backup';

  @override
  String get cloudBackup => 'Back up';

  @override
  String get cloudRestore => 'Restore';

  @override
  String get cloudBackupDone => 'Backed up to the cloud';

  @override
  String get cloudRestoreDone => 'Restored from backup';

  @override
  String get cloudRestoreConfirm =>
      'This overwrites your current progress with the backup. It cannot be undone.';

  @override
  String get cloudFailed => 'Failed. Please try again in a moment';

  @override
  String get cloudNoBackup => 'No backup yet';

  @override
  String cloudLastBackup(String when) {
    return 'Last backup: $when';
  }

  @override
  String get cloudUnavailable => 'Backup unavailable — no online connection';

  @override
  String get cloudAnonWarning =>
      'You\'re on a temporary device account, so deleting the app also loses the backup. Sign in to keep your progress across devices.';

  @override
  String get tabCraft => 'Craft';

  @override
  String get tabStore => 'Store';

  @override
  String get adNotReady =>
      'No ad is ready right now. Please try again in a moment';

  @override
  String get adDismissed => 'Watch the full ad to get the reward';

  @override
  String get adFailed => 'Couldn\'t load the ad';

  @override
  String get adLoading => 'Loading ad…';

  @override
  String get storeOwned => 'Owned';

  @override
  String get storeRestore => 'Restore purchases';

  @override
  String get storeRestoreDone => 'Purchases restored';

  @override
  String storeBought(String name) {
    return '$name purchased!';
  }

  @override
  String get storeFailed => 'Purchase failed';

  @override
  String get storeCanceled => 'Purchase canceled';

  @override
  String get storePending =>
      'Confirming your payment. It will be granted automatically. If it hasn\'t arrived in a few minutes, tap Restore purchases in the shop';

  @override
  String get storeUnavailable =>
      'In-app purchases aren\'t available on this device';

  @override
  String get storeNotRegistered => 'This item isn\'t on sale yet';

  @override
  String get storeDevMode =>
      'Dev mode — no real payment; items are granted immediately';

  @override
  String storePassLeft(int days) {
    return '$days days left';
  }

  @override
  String get storePurchased => 'Purchased';

  @override
  String get storeStorageFull =>
      'Your storage is full, so the bonus egg can\'t be added. Free up a slot before buying.';

  @override
  String get storeWeeklyDone => 'Done this week';

  @override
  String get storeWeeklyNext => 'Available again next Monday at 09:00 (KST)';

  @override
  String get biomeForest => 'Forest';

  @override
  String get biomeVolcano => 'Lava Cave';

  @override
  String get biomeBadlands => 'Badlands';

  @override
  String get biomeCity => 'Ruined City';

  @override
  String get biomeDeep => 'Deep Sea';

  @override
  String locationAffinity(String element) {
    return '$element bugs boosted';
  }

  @override
  String get breedingTitle => 'Breeding';

  @override
  String breedingSlotsLabel(int used, int cap) {
    return '$used/$cap';
  }

  @override
  String get breedingNew => 'New breeding';

  @override
  String get breedingPickMother => 'Pick mother (♀ adult)';

  @override
  String get breedingPickFather => 'Pick father (♂ · same species)';

  @override
  String get breedingNoFemales => 'No breedable ♀ adults';

  @override
  String get breedingNoMate => 'No same-species ♂ adult';

  @override
  String get breedingInProgress => 'Breeding';

  @override
  String breedCooldownLeft(Object time) {
    return 'Ready in $time';
  }

  @override
  String get breedingGotEgg => 'Got an egg! Raise it in the incubator';

  @override
  String get leaderboardLocalNote => 'Local ranking · online sync coming';

  @override
  String get leaderboardOnlineNote => 'Online ranking · live';

  @override
  String get backendOnline => 'Online';

  @override
  String get backendLocal => 'Local';

  @override
  String get backendServer => 'Server';

  @override
  String settingsBuildLabel(String label) {
    return 'Build $label';
  }

  @override
  String get rankKindTrophies => 'Trophies';

  @override
  String get leaderboardUnranked => 'Unranked';

  @override
  String get rankKindLevel => 'Level';

  @override
  String get rankKindStage => 'Progress';

  @override
  String leaderboardMyRank(int n) {
    return 'My rank #$n';
  }

  @override
  String get stanceAttack => 'Attack';

  @override
  String get stanceDefend => 'Defend';

  @override
  String get stanceHeal => 'Heal';

  @override
  String get elementFire => 'Fire';

  @override
  String get elementWater => 'Water';

  @override
  String get elementWood => 'Wood';

  @override
  String get elementMetal => 'Metal';

  @override
  String get elementEarth => 'Earth';

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
  String get offlineTitle => 'Welcome back!';

  @override
  String offlineBugsBlocked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count eggs were',
      one: '1 egg was',
    );
    return 'Your collection box was full —\n$_temp0 not collected';
  }

  @override
  String get fairyRerollPending => 'Pick reroll result';

  @override
  String offlineBugs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bug eggs',
      one: '1 bug egg',
    );
    return '🥚 Collected $_temp0';
  }

  @override
  String offlineElapsed(String time) {
    return 'Idle rewards earned over $time';
  }

  @override
  String get offlineGoldLabel => 'Gold';

  @override
  String get offlineXpLabel => 'XP';

  @override
  String durationHm(int h, int m) {
    return '${h}h ${m}m';
  }

  @override
  String durationH(int h) {
    return '${h}h';
  }

  @override
  String durationM(int m) {
    return '${m}m';
  }

  @override
  String durationS(int s) {
    return '${s}s';
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
  String get upEvade => 'Evasion';

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
  String get curGold => 'Gold';

  @override
  String get rewardGained => 'Rewards';

  @override
  String get bossLabel => 'BOSS';

  @override
  String zoneLabel(int n) {
    return 'Hunting Ground $n';
  }

  @override
  String get zoneFinalLabel => 'Final Ground';

  @override
  String get bossChallenge => 'Boss Fight';

  @override
  String bossChallengeLocked(int n) {
    return '$n to boss';
  }

  @override
  String get bossChallengeFailed =>
      'The boss pushed you back. Grow stronger and try again';

  @override
  String bossAutoCountdown(int n) {
    return 'Auto in ${n}s';
  }

  @override
  String get bossIntroTitle => 'A boss appeared!';

  @override
  String get bossIntroBody =>
      'Defeat it to move on to the next hunting ground.';

  @override
  String get bossIntroAuto =>
      'Keep auto challenge on? When the gauge fills, you\'ll challenge the boss on your own shortly. You can change this anytime in Settings.';

  @override
  String get bossIntroOk => 'Got it';

  @override
  String get settingsGameplay => 'Gameplay';

  @override
  String get settingsAutoBoss => 'Auto boss challenge';

  @override
  String get bossFlee => 'Flee';

  @override
  String get bossFleeTitle => 'Flee the boss?';

  @override
  String get bossFleeDesc =>
      'Your hunting ground gauge resets.\nSame as being defeated.';

  @override
  String get bossFled => 'Fled - gauge reset';

  @override
  String bossChallengeFailedHp(int pct) {
    return 'The boss pushed you back · Boss HP $pct% left';
  }

  @override
  String bossAutoPaused(int pct) {
    return 'The boss is still too strong — Boss HP $pct% left. Tap to challenge once you\'re stronger';
  }

  @override
  String get bossAutoPausedShort => 'Auto paused';

  @override
  String get bossIntroKeepOn => 'Keep on';

  @override
  String get bossIntroTurnOff => 'Turn off';

  @override
  String get whatsNewTitle => 'What\'s New';

  @override
  String whatsNewSubtitle(String version) {
    return 'Changes in v$version';
  }

  @override
  String get whatsNewOk => 'OK';

  @override
  String get whatsNewPartsToPoints =>
      'Part upgrades moved to training points — you get points back for what you invested, so you won\'t get weaker';

  @override
  String get whatsNewFreeRespec => 'Your first training point reset is free';

  @override
  String get whatsNewClutch =>
      'Duel clutch — tap the screen rapidly in a crisis to hold on';

  @override
  String get whatsNewAutoBoss =>
      'Auto boss challenge — challenges the boss on its own when the gauge fills (turn off in Settings)';

  @override
  String get whatsNewUpgradeCap => 'Upgrade cap raised to 250';

  @override
  String get whatsNewGifts =>
      'Surprise gifts and daily rewards are much bigger';

  @override
  String get whatsNewMoveToEvade =>
      'The hunting upgrade Move Speed is now Evasion';

  @override
  String zoneKillsLabel(int n, int m) {
    return 'Kills $n/$m';
  }

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
  String collectInstalledSnack(String trap, String field) {
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
  String storageCapacityCount(int used, int cap) {
    return '$used/$cap';
  }

  @override
  String storageCapacityLabel(int used, int cap) {
    return 'Storage $used / $cap slots';
  }

  @override
  String get storageFullBanner =>
      'Your collection is full\nNo new bugs will be added';

  @override
  String get storageFullSnack =>
      'Storage is full. Release a bug or expand your storage.';

  @override
  String storageExpand(int n, int jelly) {
    return '+$n slots · $jelly jelly';
  }

  @override
  String get dexTitle => 'Bug Dex';

  @override
  String get dexDiscovered => 'Found';

  @override
  String get dexConquered => 'Raised';

  @override
  String get dexVariant => 'Variant';

  @override
  String get dexComplete => 'This species is complete';

  @override
  String get dexCompleteShort => 'Complete';

  @override
  String get dexConqueredYes => 'Done';

  @override
  String get dexConqueredNo => 'Not yet';

  @override
  String dexConquerNeed(int need, int now) {
    return 'Needs Lv$need (now $now)';
  }

  @override
  String get dexMaxSize => 'Largest';

  @override
  String get dexMaxPotential => 'Best potential';

  @override
  String get dexNotFound => 'You haven\'t met this bug yet. Go find one!';

  @override
  String dexClaim(Object n) {
    return 'Claim $n dex reward(s)';
  }

  @override
  String dexClaimedSnack(Object gold, Object jelly) {
    return 'Dex reward! $gold gold · $jelly jelly';
  }

  @override
  String get dexTabBugs => 'Bugs';

  @override
  String get dexTabBosses => 'Bosses';

  @override
  String get dexBosses => 'Bosses';

  @override
  String get dexBossNotFound =>
      'You haven\'t defeated this boss yet. Beat it in this difficulty\'s hunting ground to record it.';

  @override
  String get dexBossHint =>
      'Each difficulty counts separately. Beating one after moving down still counts.';

  @override
  String dexClaimedFossil(Object fossil) {
    return 'Plus $fossil fossils';
  }

  @override
  String dexBonusSummary(String atk, String hp, String gold) {
    return 'Dex bonus — ATK +$atk% · HP +$hp% · Gold +$gold%';
  }

  @override
  String get speciesPassiveTitle => 'Species ability';

  @override
  String get speciesPassiveHint =>
      'Applies while this bug is equipped as a pet. Equipping several of the same species stacks it.';

  @override
  String get storageFilterLabel => 'Keep';

  @override
  String get storageFilterAll => 'All';

  @override
  String storageFilterSnack(Object grade) {
    return 'Below $grade is released automatically and turned into materials';
  }

  @override
  String get autoSynthTitle => 'Auto fuse';

  @override
  String autoSynthHint(Object n) {
    return 'Fuses automatically whenever $n of the same species pile up. Equipped and incubating bugs are never used.';
  }

  @override
  String get autoSynthNone => 'Nothing can be fused right now';

  @override
  String autoSynthPreview(Object count, Object used) {
    return '$count will be fused (uses $used)';
  }

  @override
  String autoSynthDone(Object count, Object used) {
    return 'Fused $count time(s) ($used used)';
  }

  @override
  String get autoSynthRun => 'Auto fuse';

  @override
  String get eventIntroTitle => 'What is the Bug King Trials?';

  @override
  String get eventIntroStart => 'Start';

  @override
  String get eventHelp => 'How it works';

  @override
  String eventCardTitle(Object n) {
    return 'Wave $n cleared!\nChoose one';
  }

  @override
  String get eventCardHint => 'The boost lasts for the rest of this run';

  @override
  String get cardHeal_s => 'First Aid';

  @override
  String get cardHeal_sDesc => 'Restore 30% HP';

  @override
  String get cardHeal_l => 'Full Recovery';

  @override
  String get cardHeal_lDesc => 'Restore 70% HP';

  @override
  String get cardAtk_s => 'Sharp Mandibles';

  @override
  String get cardAtk_sDesc => 'Attack +12%';

  @override
  String get cardAtk_l => 'Onslaught';

  @override
  String get cardAtk_lDesc => 'Attack +28%';

  @override
  String get cardDef_s => 'Hardened Shell';

  @override
  String get cardDef_sDesc => 'Defense +18%';

  @override
  String get cardHp_s => 'Sturdy Build';

  @override
  String get cardHp_sDesc => 'Max HP +15%';

  @override
  String get cardRevive => 'Dew of Life';

  @override
  String get cardReviveDesc =>
      'When HP runs out, get back up once at 50% HP and retry the same wave';

  @override
  String get cardSkip => 'Detour';

  @override
  String get cardSkipDesc => 'Skip the next wave without fighting';

  @override
  String eventFlyerPeriod(String start, String end) {
    return '$start – $end';
  }

  @override
  String get eventPeriodLabel => 'Event period';

  @override
  String get eventFlyerHeadline =>
      'Looking for the bug handler who goes furthest';

  @override
  String get eventFlyerPrize => '1st place gets a real live beetle';

  @override
  String get eventFlyerPrizeNote =>
      'Ships within Korea, sent directly by the seller';

  @override
  String get eventFlyerHow => 'How to enter';

  @override
  String get eventFlyerHow1 => 'Enter with your single best-raised adult bug';

  @override
  String get eventFlyerHow2 => 'Choose one boost card after each wave';

  @override
  String get eventFlyerHow3 => 'The further you get, the higher you rank';

  @override
  String get eventFlyerRules => 'Good to know';

  @override
  String get eventFlyerRule1 =>
      'Your bug fights **as raised** — potential, train levels, breakthroughs and training points all count (same stats as Duels)';

  @override
  String get eventFlyerRule2 =>
      'Enemy elements change every wave — waves your bug is weak to are the hard ones';

  @override
  String get eventFlyerRule3 =>
      'Your bug gets injured and must rest in the recovery room — jelly heals it instantly';

  @override
  String eventFlyerRule4(int daily, int jelly, int extra) {
    return 'You get $daily tickets every morning, and can top up with $jelly jelly each, up to $extra more per day';
  }

  @override
  String get eventFlyerLogin =>
      'Sign in to appear in the ranking (guests can still play)';

  @override
  String get eventTitle => 'Bug King Trials';

  @override
  String eventBanner(Object n) {
    return 'Bug King Trials · $n tickets';
  }

  @override
  String get eventClosed => 'No event is running';

  @override
  String get battleNeedServer => 'Duels need an online connection';

  @override
  String get eventQuitFailed =>
      'Couldn\'t quit — check your connection and try again';

  @override
  String get eventBugUnavailable =>
      'That bug can\'t enter — please pick another one';

  @override
  String get injuryHealConfirmTitle => 'Heal now';

  @override
  String injuryHealConfirm(int n) {
    return 'Spend $n Jelly to heal now?';
  }

  @override
  String get trainingInstantTitle => 'Finish training now';

  @override
  String get squadTrainingBadge => 'Training';

  @override
  String get eventNeedServer => 'The event needs an online connection';

  @override
  String eventTickets(int n, int max) {
    return 'Tickets $n/$max';
  }

  @override
  String get eventBestRecord => 'Your best';

  @override
  String get eventNoRecord => 'No attempt yet';

  @override
  String eventWaveRecord(String n) {
    return 'Wave $n';
  }

  @override
  String eventScore(Object n) {
    return '$n pts';
  }

  @override
  String eventMyRank(Object n) {
    return 'Your rank #$n';
  }

  @override
  String get eventPickTeam => 'Pick 1 bug to enter';

  @override
  String get eventPickOrder =>
      'Face enemies one after another · throw gauge every bout · HP is your life';

  @override
  String get eventNormalizeTitle =>
      'The better you raise it, the stronger it is';

  @override
  String eventNormalizeBody(int pct) {
    return 'Fights with the same stats as Duels — potential, train levels, breakthroughs, training points and traits all count. Losing by ring-out or flip costs $pct% HP and you retry the same wave. When HP runs out, the run ends.';
  }

  @override
  String eventFatigueLeft(Object time) {
    return 'Ready in $time';
  }

  @override
  String eventRestHours(Object h) {
    return '⏳${h}h';
  }

  @override
  String eventRestMinutes(Object m) {
    return '⏳${m}m';
  }

  @override
  String get eventChallenge => 'Enter (1 ticket)';

  @override
  String get eventNoTicket => 'No tickets left';

  @override
  String get eventAdTicket => 'Claim free ticket';

  @override
  String get eventJellyTicket => 'Buy ticket';

  @override
  String get eventNoJelly => 'Not enough jelly';

  @override
  String get eventAdLimit => 'Today\'s free rewards are used up';

  @override
  String get eventTicketFull => 'Tickets are full';

  @override
  String eventResultTitle(Object n) {
    return 'Reached wave $n!';
  }

  @override
  String get eventLeadStrong => 'Strong';

  @override
  String get eventLeadWeak => 'Weak';

  @override
  String eventTicketBought(int n) {
    return 'Charged $n entry ticket(s)';
  }

  @override
  String eventTicketDaily(int used, int max) {
    return 'today $used/$max';
  }

  @override
  String get eventStopWipe => 'Your team was wiped out, so the run ends here.';

  @override
  String get eventStopJudge =>
      'Round 20 passed, so the wave was decided on remaining HP and you came up short. The run ends here even with bugs still standing.';

  @override
  String get eventStopMax => 'You cleared every wave to the last one!';

  @override
  String get eventNewBest => 'New best!';

  @override
  String eventKeptBest(Object n) {
    return 'Your best is wave $n';
  }

  @override
  String eventWaveCleared(Object n) {
    return 'Wave $n cleared!';
  }

  @override
  String get eventFastForward => 'Fast forward';

  @override
  String get eventNextWave => 'Next enemy';

  @override
  String get eventLead => 'Lead';

  @override
  String get eventSetLead => 'Set lead';

  @override
  String get eventLeadHint => 'Tap a bug to send it in first';

  @override
  String get eventRanking => 'Ranking';

  @override
  String get eventRankEmpty => 'No entries yet';

  @override
  String get eventAnonWarn =>
      'Guest accounts don\'t appear in the ranking. Sign in to take part.';

  @override
  String get eventKoreaOnly =>
      'Physical prizes ship within Korea only. Rankings and in-game rewards are open to everyone.';

  @override
  String get eventRules => 'Event rules';

  @override
  String get storageFilterButton => 'Filter';

  @override
  String get storageFilterTitle => 'Choose minimum grade';

  @override
  String get autoReleaseTitle => 'Auto release';

  @override
  String get autoReleaseHint =>
      'Releases every bug matching the filter at once and turns it into materials. Equipped, incubating and trained bugs (training, breakthrough, enhancement) are never touched.';

  @override
  String get autoReleaseNone => 'No bugs match the filter';

  @override
  String autoReleaseDone(Object count, Object mats) {
    return 'Released $count bugs for $mats materials';
  }

  @override
  String autoReleasePreview(Object count, Object mats) {
    return '$count bugs will be released for $mats materials';
  }

  @override
  String get autoReleaseRun => 'Release';

  @override
  String get autoFilterGrades => 'Target grades';

  @override
  String autoFilterPotential(Object n) {
    return 'Potential $n★ or lower';
  }

  @override
  String get autoFilterEmpty => 'Pick at least one grade';

  @override
  String get autoPreviewTitle => 'Bugs that will be gone';

  @override
  String autoPreviewMore(Object n) {
    return 'and $n more';
  }

  @override
  String autoPreviewLine(String name, int count) {
    return '$name ×$count';
  }

  @override
  String get storageExpandMaxed => 'Max size';

  @override
  String get storageExpandedSnack => 'Storage expanded!';

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
  String get traitFierce => 'Fierce';

  @override
  String get traitSturdy => 'Sturdy';

  @override
  String get traitVital => 'Vital';

  @override
  String get traitNoble => 'Noble';

  @override
  String get traitTitle => 'Bloodline trait';

  @override
  String get traitHint =>
      'Only bred bugs can have one. Matching parents always pass it on.';

  @override
  String get breedInheritTitle => 'Inherited';

  @override
  String get breedInheritHint =>
      'Element, temperament and bloodline trait pass from the parents. Pair parents that match to lock it in.';

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
  String get chatTitle => 'Global chat';

  @override
  String get chatPlaceholder => 'Global chat — tap to open';

  @override
  String get characterTitle => 'My Character';

  @override
  String get statCombatPower => 'Combat Power';

  @override
  String get statCrit => 'Critical';

  @override
  String get statMaxHp => 'Max HP';

  @override
  String get statDefense => 'Defense';

  @override
  String get rankingTitle => 'Ranking';

  @override
  String get roadmapTitle => 'Roadmap';

  @override
  String roadmapStageRange(int start, int end) {
    return 'STAGE $start–$end';
  }

  @override
  String roadmapProgress(int cur, int total) {
    return '$cur / $total';
  }

  @override
  String get roadmapCleared => 'Cleared';

  @override
  String get roadmapCurrent => 'In progress';

  @override
  String get roadmapLocked => 'Locked';

  @override
  String get roadmapFinalBoss => 'Final boss';

  @override
  String get roadmapEnter => 'Resume';

  @override
  String get roadmapReplay => 'Replay';

  @override
  String get chapterClearTitle => 'Chapter cleared! 🎉';

  @override
  String chapterClearMsg(String difficulty, String boss) {
    return 'Conquered $difficulty! Final boss $boss defeated!';
  }

  @override
  String get chapterClearReward => 'Clear reward';

  @override
  String get mailTitle => 'Mailbox';

  @override
  String get mailEmpty => 'No new mail';

  @override
  String get mailDailyTitle => 'Daily reward (twice a day)';

  @override
  String get dailyLunch => 'Lunch reward';

  @override
  String get dailyDinner => 'Dinner reward';

  @override
  String get dailyClaim => 'Claim';

  @override
  String get dailyClaimedToday => 'Claimed today';

  @override
  String dailyLockedUntil(int hour) {
    return 'from $hour:00';
  }

  @override
  String get dailyRewardSnack => 'Daily reward claimed!';

  @override
  String get giftSectionTitle => 'Surprise gifts (claim within 3h)';

  @override
  String get giftClaim => 'Claim';

  @override
  String get giftClaimAd => 'Claim x2';

  @override
  String giftExpiresIn(String time) {
    return 'expires in $time';
  }

  @override
  String get giftClaimedSnack => 'Gift claimed!';

  @override
  String get giftDoubledSnack => 'Double reward claimed!';

  @override
  String giftDoubledMult(String n) {
    return 'Reward x$n!';
  }

  @override
  String get giftAdMoreTitle => 'Today\'s free double!';

  @override
  String get giftAdMoreBody => 'Take this gift at double value.';

  @override
  String get giftAdMoreYes => 'Claim double';

  @override
  String get giftAdMoreLater => 'Claim as is';

  @override
  String get notifLunchTitle => 'Lunch reward is ready 🍱';

  @override
  String get notifDinnerTitle => 'Dinner reward is ready 🌙';

  @override
  String get notifRewardBody => 'Hop in and claim it!';

  @override
  String get notifOfflineTitle => 'Idle rewards are full 🐛';

  @override
  String get notifOfflineBody =>
      '8 hours\' worth has piled up. Come collect it!';

  @override
  String get giftNone => 'No gifts yet. Keep playing and they\'ll arrive!';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSound => 'Sound';

  @override
  String get settingsBgm => 'Music';

  @override
  String get settingsSfx => 'Sound effects';

  @override
  String get settingsNickname => 'Nickname';

  @override
  String get settingsNicknameHint => 'Enter a name';

  @override
  String get actionSave => 'Save';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionNext => 'Next';

  @override
  String get actionClose => 'Close';

  @override
  String get exitTitle => 'Exit game';

  @override
  String get exitConfirm => 'Quit the game?';

  @override
  String get exitAction => 'Quit';

  @override
  String get settingsReset => 'Reset game data';

  @override
  String get settingsResetConfirm =>
      'All progress (bugs, currency, upgrades, stage) will be deleted. Reset for real?';

  @override
  String get settingsResetDone => 'Game data reset';

  @override
  String get questHunt => 'Monster Hunt';

  @override
  String get buffTitle => 'Buffs';

  @override
  String get buffSheetTitle => 'Activate a buff';

  @override
  String get buffWatchAd => 'Activate free';

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
  String evolveNext(String time, String next) {
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
  String get synthConfirm => 'These bugs will be consumed';

  @override
  String get synthConfirmTitle => 'Confirm fusion';

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
  String trainJelly(int n) {
    return '$n jelly';
  }

  @override
  String trainJellySnack(int lv) {
    return 'Instant training! Level +$lv';
  }

  @override
  String get breakthroughTitle => 'Breakthrough';

  @override
  String breakthroughTier(int n) {
    return 'Tier $n';
  }

  @override
  String get breakthroughReady => 'Breakthrough ready · cap ↑';

  @override
  String breakthroughProgress(String time) {
    return 'Breaking through · $time';
  }

  @override
  String get breakthroughDone => 'Done! Collect it';

  @override
  String get breakthroughMaxed => 'Max tier reached';

  @override
  String get breakthroughDo => 'Break';

  @override
  String get breakthroughCollect => 'Collect';

  @override
  String breakthroughInstant(int n) {
    return 'Finish now · $n jelly';
  }

  @override
  String get breakthroughStartedSnack => 'Breakthrough started!';

  @override
  String get breakthroughDoneSnack => 'Breakthrough done! Level cap raised';

  @override
  String get incubatorTitle => 'Incubator';

  @override
  String incubatorSlots(int cur, int max) {
    return 'Slots $cur/$max';
  }

  @override
  String get incubatorPlace => 'Place';

  @override
  String incubatorHatching(String time) {
    return 'Hatching · $time';
  }

  @override
  String get incubatorReady => 'Hatched!';

  @override
  String get incubatorCollect => 'Collect';

  @override
  String get incubatorFull => 'Incubator full';

  @override
  String incubatorExpand(int n) {
    return 'Expand slot · $n jelly';
  }

  @override
  String get incubatorPlacedSnack => 'Incubation started!';

  @override
  String get incubatorCollectedSnack => 'Hatched into a larva!';

  @override
  String get incubatorExpandedSnack => 'Incubator slot added!';

  @override
  String get incubatorEmptySlot => 'Empty slot';

  @override
  String incubatorWaitingEggs(int n) {
    return 'Waiting eggs ($n)';
  }

  @override
  String get incubatorNoEggs => 'No eggs to hatch';

  @override
  String get incubatorHint =>
      'Tap an empty capsule to add an egg; tap a ready one to collect.';

  @override
  String incubatorCollectAll(int n) {
    return 'Collect all ($n)';
  }

  @override
  String incubatorCollectAllDone(int n) {
    return 'Collected $n bugs';
  }

  @override
  String get incubatorPick => 'Choose an egg';

  @override
  String get disassembleTitle => 'Disassemble';

  @override
  String disassembleDesc(int n) {
    return 'Convert to $n jelly';
  }

  @override
  String get disassembleConfirm =>
      'This bug is hard to get back. Disassemble it?';

  @override
  String get disassembleAction => 'Disassemble';

  @override
  String get incubatingLabel => 'Incubating';

  @override
  String get disassembleSnack => 'Disassembled';

  @override
  String get disassembleEquipped => 'Equipped bugs cannot be disassembled';

  @override
  String get disassembleIncubating =>
      'Eggs in the incubator cannot be disassembled';

  @override
  String get disassembleFailed => 'Cannot disassemble';

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
  String get missionForgeItems => 'Forge Gear';

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
  String get upRegenDesc =>
      'Recover a share of max HP every second. Lets you outlast hits.';

  @override
  String get upRewardDesc => 'More gold earned per monster kill.';

  @override
  String get upXpDesc => 'More XP earned per monster kill.';

  @override
  String get upBugFindDesc => 'Increases the chance to find bugs.';

  @override
  String get upMaterialFindDesc => 'Increases enhancement materials gained.';

  @override
  String get upEvadeDesc =>
      'Chance to dodge a monster\'s attack and take no damage. Works on bosses too.';

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
      'A hard exoskeleton shard. Used for advanced upgrade costs, training points and breakthroughs.';

  @override
  String get materialMineralDesc =>
      'A hard mined mineral. Used for advanced upgrade costs, training points and breakthroughs.';

  @override
  String get materialSapDesc =>
      'Hardened crystallized tree sap. Used for advanced upgrade costs, training points and breakthroughs.';

  @override
  String get materialJellyDesc =>
      'A special premium currency. Used for crafting (All-in-One Potion) and special goods.';

  @override
  String get materialFossil => 'Fossil Shard';

  @override
  String get materialFossilDesc =>
      'A shard of petrified insect. One is spent per hammer strike at the workshop.';

  @override
  String get saveBrokenTitle => 'Couldn\'t open your save';

  @override
  String get saveBrokenUpdate =>
      'This account’s save is newer than the app.\nUpdate to the latest version to continue where you left off.';

  @override
  String get saveBrokenCorrupt =>
      'Your save couldn\'t be read.\nThe original is kept safely on this device and was not overwritten.';

  @override
  String get saveBrokenKeep =>
      'The game is paused to protect your progress. Continuing could erase your save.';

  @override
  String get saveBrokenSupport => 'Contact support';

  @override
  String get eventRewardTitle => 'Championship results are in';

  @override
  String eventRewardRank(String round, int rank) {
    return 'Round $round — rank $rank';
  }

  @override
  String get eventRewardNone =>
      'You didn\'t place this round. Here\'s your entry reward!';

  @override
  String get eventRewardPhysical =>
      'You placed for a real prize! Fill in the form below. Physical prizes ship to Korean addresses only — outside Korea you receive the in-game rewards.';

  @override
  String get eventRewardApply => 'Claim prize';

  @override
  String get eventRewardClaim => 'Collect';

  @override
  String badgeChampion(int round) {
    return 'R$round Champion';
  }

  @override
  String badgeFinalist(int round) {
    return 'R$round Finalist';
  }

  @override
  String get nicknameBadChars =>
      'Letters and numbers only (no emoji or stray marks)';

  @override
  String get nicknameSameName =>
      'Please pick a name different from your current one.';

  @override
  String get eventRewardsTitle => 'Rank rewards';

  @override
  String get eventRankOne => '1st';

  @override
  String eventRankRange(int a, int b) {
    return '$a–$b';
  }

  @override
  String get eventRewardRealBug => 'Real beetle (ships in Korea)';

  @override
  String eventRewardJelly(int n) {
    return 'Jelly ×$n';
  }

  @override
  String get eventRewardParticipationRow => 'Entry (1+ runs)';

  @override
  String buffCooldownAsk(String t, int n) {
    return 'Next free activation in $t.\nActivate now for $n jelly?';
  }

  @override
  String buffBtnFreeLeft(String t) {
    return 'Free in $t';
  }

  @override
  String buffBtnJelly(int n) {
    return 'Use $n';
  }

  @override
  String buffBtnPassLeft(int n) {
    return 'Pass: ${n}d left';
  }

  @override
  String get settingsLanguage => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String eventRewardTitleAward(String name) {
    return 'Title “$name”';
  }

  @override
  String get stanceCycle => 'ATK › HEAL › DEF › ATK';

  @override
  String tierClearTitle(String name) {
    return '$name difficulty cleared!';
  }

  @override
  String tierNextTitle(String name) {
    return 'Entering $name difficulty';
  }

  @override
  String get tierNextBody =>
      'Stage, level, upgrades, gold and materials reset to the beginning.\n\nBugs, gear, the dex, jelly and skills all stay with you.\n\nRankings sort by difficulty first - moving up puts you above lower tiers even at a low level.\n\nMonsters get much stronger.';

  @override
  String get tierNextGo => 'Enter';

  @override
  String get tierStayHere => 'Stay a while';

  @override
  String get tierAllClear =>
      'You conquered every difficulty. A true entomologist!';

  @override
  String get tierEasy => 'Easy';

  @override
  String get tierNormal => 'Normal';

  @override
  String get tierHard => 'Hard';

  @override
  String get tierExtreme => 'Extreme';

  @override
  String get netLostTitle => 'Connection lost';

  @override
  String get netLostBody =>
      'Check your internet connection.\nProgress is only saved while connected.';

  @override
  String get netRetry => 'Retry';

  @override
  String get sessionTakenTitle => 'Playing on another device';

  @override
  String get sessionTakenBody =>
      'This account was opened on another device.\n\nContinue here to load the progress from that device.';

  @override
  String get sessionTakenContinue => 'Continue on this device';

  @override
  String get sessionTakenFailed =>
      'Couldn\'t load. Please try again in a moment.';

  @override
  String get netToTitle => 'Back to title';

  @override
  String get netStillDown => 'Still not connected';

  @override
  String get materialsHint =>
      'Materials — used for upgrades, training, breakthroughs & crafting (tap for details)';

  @override
  String get chatHint => 'Type a message';

  @override
  String get chatSend => 'Send';

  @override
  String get chatEmpty => 'No messages yet. Say hello!';

  @override
  String get chatUnavailable => 'Chat isn\'t available right now';

  @override
  String get chatSendFailed => 'Couldn\'t send your message';

  @override
  String chatTooLong(int max) {
    return 'Message is too long (max $max)';
  }

  @override
  String get chatBlockedWord => 'That message contains blocked words';

  @override
  String get chatTooFast => 'Please slow down a little';

  @override
  String get chatReport => 'Report';

  @override
  String get chatBlock => 'Block';

  @override
  String get chatUnblock => 'Unblock';

  @override
  String get chatDelete => 'Delete';

  @override
  String get chatDeleted => 'Message deleted';

  @override
  String get chatDeleteTitle => 'Delete this message?';

  @override
  String get chatDeleteBody =>
      'This removes your message for everyone. It can\'t be undone.';

  @override
  String get chatReported => 'Reported. We\'ll review it';

  @override
  String chatBlockedUser(String name) {
    return 'Blocked $name';
  }

  @override
  String chatUnblockedUser(String name) {
    return 'Unblocked $name';
  }

  @override
  String get chatBlockedMessage => 'Message from a blocked user';

  @override
  String get chatReportTitle => 'Report this message?';

  @override
  String get chatReportBody =>
      'Report abuse, spam or scams. Repeatedly reported users get restricted.';

  @override
  String chatBlockTitle(String name) {
    return 'Block $name?';
  }

  @override
  String get chatBlockBody =>
      'You won\'t see their messages anymore. You can undo this in settings.';

  @override
  String get chatRules =>
      'Please be respectful. Abuse, ads and sharing personal info are not allowed.';

  @override
  String get nicknameBlockedWord => 'That nickname contains blocked words';

  @override
  String get nicknameTaken => 'That nickname is already in use';

  @override
  String get rankPopupTitle => 'Progress Ranking';

  @override
  String get rankSuffix => 'th';

  @override
  String get rankFirstCheck => 'First ranking check — good luck!';

  @override
  String get rankUnchanged => 'No change since last time';

  @override
  String rankChangedFromTo(int from, int to) {
    return '#$from → #$to';
  }

  @override
  String rankTopStreak(int days) {
    return 'Day $days at #1 👑';
  }

  @override
  String get nicknameRequiredTitle => 'Choose a nickname';

  @override
  String get nicknameRequiredBody =>
      'This is the name other collectors will see. You only set it once.';

  @override
  String get renameForcedTitle => 'Please change your nickname';

  @override
  String get renameForcedBody =>
      'An operator asked you to change your nickname.\nIt is shown to other players, so it must follow the rules.\nThis change is free.';

  @override
  String get nicknameChangeTitle => 'Change nickname';

  @override
  String get nicknameChangeBody =>
      'Changing your nickname costs insect jelly. Proceed?';

  @override
  String get nicknameChangeConfirm => 'Change';

  @override
  String get nicknameFallback => 'Player';

  @override
  String get battleServerFailed =>
      'Couldn\'t confirm the battle result. Check your connection';

  @override
  String get updateRequiredTitle => 'Update required';

  @override
  String get updateRequiredBody =>
      'Please update to the latest version to keep playing.';

  @override
  String get updateAvailableTitle => 'New version available';

  @override
  String get updateAvailableBody => 'An improved version is ready. Update now?';

  @override
  String get updateNow => 'Update';

  @override
  String get updateLater => 'Later';

  @override
  String get maintenanceTitle => 'Under maintenance';

  @override
  String get maintenanceBody =>
      'The server is under maintenance. Please try again in a moment.';

  @override
  String get connectionRequiredTitle => 'Connection required';

  @override
  String get connectionRequiredBody =>
      'An internet connection is required to play. Check your network and try again.';

  @override
  String get retryButton => 'Retry';

  @override
  String get accountSignInApple => 'Sign in with Apple';

  @override
  String get termsOfUse => 'Terms of Use';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get titleStartGuest => 'Play as guest';

  @override
  String get titleOr => 'or';

  @override
  String get titleLoading => 'Loading…';

  @override
  String get guestNudgeTitle => 'Sign in before you start?';

  @override
  String get guestNudgeBody =>
      'Without signing in, your progress and rank can\'t be restored if you change devices or delete the app. Sign in to keep the bugs and the rank you earn.';

  @override
  String get guestNudgeSignIn => 'Sign in';

  @override
  String get guestNudgeContinue => 'Continue as guest';

  @override
  String get guestWarnTitle => 'You\'re playing as a guest';

  @override
  String get guestWarnBody =>
      'This is a temporary device account. If you delete the app or switch devices, your bugs and rank are gone. Sign in to keep them safe.';

  @override
  String get guestWarnPurchaseBody =>
      'Thanks for your purchase! You\'re playing as a guest, so deleting the app or switching devices will lose your purchases and progress. Link a Google (or Apple) account to keep them safe.';

  @override
  String get titleStoreName => 'Bug Champ';

  @override
  String get titleStoreTagline => 'Idle Insect RPG';

  @override
  String nicknameChangeCostHint(int cost) {
    return 'Costs $cost jelly to change';
  }

  @override
  String incubatorAdSkip(int pct) {
    return '⏩ Free $pct% skip';
  }

  @override
  String get incubatorAdSkipDone => 'Hatching time reduced!';

  @override
  String get nicknameEditAction => 'Change nickname';

  @override
  String nicknameEditActionCost(int cost) {
    return 'Change for $cost jelly';
  }

  @override
  String get notifHatchTitle => 'Hatched!';

  @override
  String get notifHatchBody => 'An egg has hatched. Check your collection.';

  @override
  String get settingsNotify => 'Notifications';

  @override
  String get notifyOfflineFull => 'Offline rewards full';

  @override
  String get notifyHatchDone => 'Hatching complete';

  @override
  String get notifyDaily => 'Daily reward time';

  @override
  String get incubatorInstant => 'Hatch now';

  @override
  String get incubatorAdSkipBtn => 'Skip for free';

  @override
  String get notifyAll => 'Enable notifications';

  @override
  String get notEnoughMaterials => 'Not enough materials';

  @override
  String get notifGiftTitle => 'A gift arrived!';

  @override
  String get notifGiftBody =>
      'Gifts are waiting. Claim them before they expire.';

  @override
  String get notifyGift => 'Surprise gifts';

  @override
  String get notifyQuietHours => 'Quiet hours (10 PM - 8 AM)';

  @override
  String get pvpTicketTitle => 'Duel tickets';

  @override
  String pvpTicketCount(int tickets, int max) {
    return '$tickets/$max';
  }

  @override
  String pvpTicketNextIn(String time) {
    return 'Next in $time';
  }

  @override
  String get pvpTicketSettling => 'Settling\nNew season Mon 09:00';

  @override
  String get pvpTicketFullLabel => 'Full';

  @override
  String get pvpTicketNone =>
      'You need a duel ticket to fight. Charge one below.';

  @override
  String pvpTicketAdBtn(int amount) {
    return 'Free refill +$amount';
  }

  @override
  String pvpTicketAdLeft(int used, int limit) {
    return '$used/$limit today';
  }

  @override
  String pvpTicketJellyBtn(int cost) {
    return 'Refill for $cost jelly';
  }

  @override
  String pvpTicketCharged(int amount) {
    return 'Tickets +$amount';
  }

  @override
  String get pvpTicketFilled => 'Tickets filled up';

  @override
  String get pvpTicketAlreadyFull => 'Tickets are already full';

  @override
  String get pvpTicketChargeFailed =>
      'Could not charge tickets. Try again in a moment.';

  @override
  String get pvpTicketWhy =>
      'Tickets keep the trophy ranking about strength, not how many matches you grind.';

  @override
  String adDailyLimit(int limit) {
    return 'Today\'s free rewards are used up ($limit/day)';
  }

  @override
  String get noticeTitle => 'Notices';

  @override
  String get noticeEmpty => 'No notices right now.';

  @override
  String get noticeFailed => 'Couldn\'t load notices. Check your connection.';

  @override
  String get mailNoticeSection => 'From the team';

  @override
  String get mailClaim => 'Claim';

  @override
  String get mailClaimAll => 'Claim all';

  @override
  String get mailReadMore => 'Read more';

  @override
  String get mailConfirm => 'OK';

  @override
  String get gachaTitle => 'Egg Draw';

  @override
  String get gachaDesc =>
      'Potential 3★+ guaranteed (wild never gives 5★) · 10x variant odds';

  @override
  String gachaPityLeft(int n) {
    return 'Legendary guaranteed within $n draws';
  }

  @override
  String gachaDraw(int n) {
    return 'Draw for $n jelly';
  }

  @override
  String get gachaResultTitle => 'From the egg...';

  @override
  String get gachaPickTitle => 'Pick a card';

  @override
  String get gachaPickHint => 'One of three. You only find out by opening it';

  @override
  String get gachaResultHint => 'Put the egg in an incubator to raise it';

  @override
  String get gachaStorageFull => 'Storage is full';

  @override
  String get gachaOff => 'Not available right now';

  @override
  String get giftCodeTitle => 'Gift code';

  @override
  String get giftCodeHint => 'Enter a code from an event or announcement.';

  @override
  String get giftCodeField => 'CODE';

  @override
  String get giftCodeSubmit => 'Redeem';

  @override
  String get giftCodeChecking => 'Checking…';

  @override
  String get giftCodeOk => 'Rewards claimed!';

  @override
  String get giftCodeBad => 'That code doesn\'t exist';

  @override
  String get giftCodeExpired => 'That code has expired';

  @override
  String get giftCodeExhausted => 'That code has run out';

  @override
  String get giftCodeUsed => 'You\'ve already used this';

  @override
  String get giftCodeFailed =>
      'Couldn\'t reach the server. Try again in a moment.';

  @override
  String get reviewAction => 'Rate the game';

  @override
  String get chatAdminBadge => 'STAFF';

  @override
  String get autoEquip => 'Auto';

  @override
  String get autoEquipDone => 'Equipped your strongest bugs';

  @override
  String get autoEquipAlready => 'Already the best line-up';

  @override
  String get autoTeam => 'Auto';

  @override
  String get autoTeamDone => 'Picked your strongest team';

  @override
  String get autoTeamAlready => 'Already the best team';

  @override
  String teamPower(String power) {
    return 'Team power $power';
  }

  @override
  String get navCharacter => 'Character';

  @override
  String get slotTool => 'Tool';

  @override
  String get slotHat => 'Hat';

  @override
  String get slotTop => 'Top';

  @override
  String get slotBottom => 'Legwear';

  @override
  String get slotShoes => 'Boots';

  @override
  String get slotNecklace => 'Necklace';

  @override
  String get slotRing => 'Ring';

  @override
  String get slotBox => 'Case';

  @override
  String get optAttack => 'Attack';

  @override
  String get optAttackSpeed => 'Attack Speed';

  @override
  String get optCritChance => 'Crit Chance';

  @override
  String get optCritDamage => 'Crit Damage';

  @override
  String get optMaxHp => 'Health';

  @override
  String get optDefense => 'Defense';

  @override
  String get optEvade => 'Evasion';

  @override
  String get optGold => 'Gold Gain';

  @override
  String get optMaterial => 'Material Gain';

  @override
  String get optBugFind => 'Bug Find';

  @override
  String get optBossDamage => 'Boss Damage';

  @override
  String get optSkillDamage => 'Skill Damage';

  @override
  String get optSkillCooldown => 'Skill Cooldown';

  @override
  String get optBoost => 'Tap Boost';

  @override
  String get optOffline => 'Idle Efficiency';

  @override
  String get optPet => 'Pet Power';

  @override
  String get charEquipment => 'Equipment';

  @override
  String get charPets => 'Pets';

  @override
  String get charSkills => 'Skills';

  @override
  String get charPower => 'Power';

  @override
  String get charEmptySlot => 'Empty';

  @override
  String get forgeTitle => 'Workshop';

  @override
  String get forgeHammer => 'Forge';

  @override
  String get forgeAuto => 'Auto forge';

  @override
  String get forgeResultKeep => 'Equip';

  @override
  String get forgeResultDrop => 'Sell';

  @override
  String forgeResultSell(String n) {
    return 'Sell for $n';
  }

  @override
  String get forgeCurrent => 'Equipped';

  @override
  String get forgeNoFossil => 'No fossil shards';

  @override
  String forgeLevel(int lv) {
    return 'Workshop Lv.$lv';
  }

  @override
  String forgeStep(int cur, int max) {
    return 'Workshop upgrade $cur/$max';
  }

  @override
  String get forgeUpgrading => 'Upgrading';

  @override
  String get forgeReady => 'Done!';

  @override
  String get forgeRush => 'Rush';

  @override
  String get forgeClaim => 'Claim';

  @override
  String get forgeNext => 'Next level odds';

  @override
  String get forgeMaxLevel => 'Max level';

  @override
  String get forgeAutoTarget => 'Wanted options';

  @override
  String get forgeStopOnHit => 'Stop when a match appears';

  @override
  String get skillLearn => 'Learn';

  @override
  String skillLevelUp(int lv, int next) {
    return 'Lv.$lv → $next';
  }

  @override
  String get skillEquipped => 'Equipped';

  @override
  String get skillSlotsFull => 'Skill slots are full';

  @override
  String get skillAuto => 'AUTO';

  @override
  String get skillTimingBonus => 'Perfect timing!';

  @override
  String skillReflect(String n) {
    return 'Reflect $n';
  }

  @override
  String get skillBlocked => 'Blocked';

  @override
  String get evadePop => 'Dodge!';

  @override
  String get skillGacha => 'Draw';

  @override
  String get skillGachaTitle => 'Skill Draw';

  @override
  String skillGachaFreeLeft(String n) {
    return '$n free today';
  }

  @override
  String skillGachaPityLeft(String grade, String n) {
    return '$grade guaranteed within $n';
  }

  @override
  String get skillGachaFree => 'Free draw';

  @override
  String skillGachaOne(String n) {
    return '1× · $n jelly';
  }

  @override
  String skillGachaTen(String n) {
    return '10× · $n jelly';
  }

  @override
  String skillTimes(String n) {
    return '×$n';
  }

  @override
  String get skillGachaOdds => 'View odds';

  @override
  String get skillGachaOddsTitle => 'Skill draw odds';

  @override
  String skillGachaOddsGrade(String grade, String p, String each) {
    return '$grade $p% · $each% per skill';
  }

  @override
  String skillGachaOddsNote(String n, String pity, String grade) {
    return 'Each draw gives $n shards of one skill. Draw #$pity is guaranteed $grade or better; the count restarts when $grade appears.';
  }

  @override
  String skillGachaResult(String name, String n) {
    return '$name shards +$n';
  }

  @override
  String get skillSweep => 'Sweep';

  @override
  String get skillSweepTitle => 'Boss Sweep';

  @override
  String skillSweepDesc(String tier, String n) {
    return 'Counts as defeating a boss again at your highest cleared difficulty ($tier) and gives $n skill shards (amount guaranteed; which skill is random).';
  }

  @override
  String skillSweepToday(String used, String max) {
    return 'Used $used/$max today';
  }

  @override
  String skillSweepFree(String n) {
    return 'Free sweep · $n left';
  }

  @override
  String skillSweepPaid(String n) {
    return 'Sweep · $n jelly';
  }

  @override
  String get skillSweepNoBoss =>
      'Defeat at least one\nhunting ground boss to sweep';

  @override
  String get skillSweepLocked => 'Beat a boss';

  @override
  String get skillGradeUpShort => 'Shard upgrade';

  @override
  String get skillShardsTitle => 'My shards';

  @override
  String get skillWildShort => 'Any';

  @override
  String get skillSweepLimit => 'No sweeps left today';

  @override
  String get skillSweepOddsTitle => 'Boss sweep odds';

  @override
  String skillSweepOddsNote(String n, String tier) {
    return 'Each sweep gives $n shards of one skill (amount guaranteed). The grade is drawn first, then every skill in that grade is equally likely. Based on your highest cleared difficulty ($tier).';
  }

  @override
  String skillShardPop(String n) {
    return 'Shard +$n';
  }

  @override
  String get skillMaterials => 'Skill materials';

  @override
  String skillGradeWild(String grade) {
    return '$grade wild';
  }

  @override
  String get skillGradeUp => 'Upgrade';

  @override
  String skillGradeUpTitle(String from, String to) {
    return '$from shards → $to wild shard';
  }

  @override
  String skillGradeUpDesc(String ratio, String from, String to) {
    return 'Turn $ratio $from shards into 1 $to wild shard, usable on any $to skill. Pick the shards to use.';
  }

  @override
  String skillGradeUpMake(String n) {
    return 'Make $n';
  }

  @override
  String skillGradeUpDone(String n, String grade) {
    return 'Made $n $grade wild shards';
  }

  @override
  String get skillGradeUpPick => 'Pick shards to use';

  @override
  String skillGradeUpHint(String grade, String n) {
    return 'Unused shards → $grade universal ×$n!';
  }

  @override
  String get skillGradeUpHintGo => 'Upgrade';

  @override
  String get skillEquip => 'Equip';

  @override
  String get skillUnequip => 'Unequip';

  @override
  String skillSlotsInfo(String n, String max) {
    return 'Equipped $n/$max';
  }

  @override
  String get skillNextSlotHint => 'More slots open at new difficulties';

  @override
  String skillShardProgress(String have, String need) {
    return 'Shards $have/$need';
  }

  @override
  String get skillLocked => 'Locked';

  @override
  String get skillMaxLevel => 'MAX';

  @override
  String get skillTrain => 'Train';

  @override
  String skillTrainingNow(String name, String lv, String left) {
    return 'Training $name Lv.$lv · $left';
  }

  @override
  String get skillTrainClaim => 'Finish';

  @override
  String skillTrainInstant(String n) {
    return 'Finish now · $n jelly';
  }

  @override
  String get actionInstant => 'Finish now';

  @override
  String get skillTrainConfirmTitle => 'Finish training now';

  @override
  String skillTrainConfirm(String n) {
    return 'Spend $n jelly to finish now?';
  }

  @override
  String skillTrainCostShards(String n, String time) {
    return '$n shards · $time';
  }

  @override
  String skillTrainCostWithAny(String n, String any, String time) {
    return '$n shards + $any wild · $time';
  }

  @override
  String skillTrainTitle(String name) {
    return 'Train $name';
  }

  @override
  String skillLevelUpDone(String name, String lv) {
    return '$name reached Lv.$lv!';
  }

  @override
  String get skillErrNotEnoughShards => 'Not enough shards';

  @override
  String get skillErrTrainingBusy => 'Another skill is already training';

  @override
  String get skillActiveSoon => 'Active skills are coming soon';

  @override
  String get skillHowToGet =>
      'Skill shards drop from hunting ground bosses (guaranteed on first kill) and elite monsters';

  @override
  String skillCooldown(String s) {
    return 'Cooldown ${s}s';
  }

  @override
  String get skillKindActive => 'Active';

  @override
  String get skillKindPassive => 'Passive';

  @override
  String skillShardsGot(String list) {
    return 'Skill shards · $list';
  }

  @override
  String get skillReviveToast => 'Molting! You got back up';

  @override
  String skillFxMaterialFind(String v) {
    return 'Material gain +$v%';
  }

  @override
  String skillFxBugFind(String v) {
    return 'Bug find +$v%';
  }

  @override
  String skillFxBossDamage(String v) {
    return 'Boss damage +$v%';
  }

  @override
  String skillFxPerPetAttack(String v) {
    return 'Attack +$v% per equipped bug';
  }

  @override
  String skillFxKillHeal(String v) {
    return 'Heal on kill +$v%';
  }

  @override
  String skillFxRevive(String v) {
    return 'Revive at $v% HP when defeated';
  }

  @override
  String skillFxMaterialBurst(String v, String d) {
    return 'Materials ×$v for ${d}s';
  }

  @override
  String skillFxAttackSpeed(String v, String d) {
    return 'Attack speed ×$v for ${d}s';
  }

  @override
  String skillFxAreaDamage(String v) {
    return 'Hit everything for ${v}s of damage';
  }

  @override
  String skillFxPetPower(String v, String d) {
    return 'Bug power ×$v for ${d}s';
  }

  @override
  String skillFxBurstDamage(String v) {
    return 'A strike worth ${v}s of damage';
  }

  @override
  String skillFxInvulnerable(String d) {
    return 'Immune to damage for ${d}s';
  }

  @override
  String get charTabStats => 'Stats';

  @override
  String get charTabPets => 'Pets';

  @override
  String get charTabSkills => 'Skills';

  @override
  String get forgeGradeButton => 'Workshop grade';

  @override
  String get statHp => 'Health';

  @override
  String get statGoldGain => 'Gold Gain';

  @override
  String get statMaterialGain => 'Material Gain';

  @override
  String get statBugFind => 'Bug Find';

  @override
  String get statEvade => 'Evasion';

  @override
  String get charNoPet => 'No pet';

  @override
  String get charPetHint => 'Manage pets in the collection box';

  @override
  String get forgeAutoShort => 'Auto';

  @override
  String get forgeStackFull => 'The anvil is full';

  @override
  String get forgeStackHint => 'Tap to open';

  @override
  String get sceneCatchTap => 'Tap now!';

  @override
  String get forgeResultNew => 'New';

  @override
  String get forgeFilter => 'Filter';

  @override
  String get forgeFilterHint =>
      'Only results with at least one checked stat are kept.';

  @override
  String get forgeFilterGrade => 'Min grade';

  @override
  String get forgeFilterGradeHint => 'Anything below this grade is discarded.';

  @override
  String forgeFilterRangeHint(String tier) {
    return 'Ranges show the max for $tier grade';
  }

  @override
  String get optPerfect => 'MAX';

  @override
  String get forgeFilterGradeAll => 'All';

  @override
  String get forgeFilterOption => 'Stats';

  @override
  String forgeStrikes(int n) {
    return 'x$n';
  }

  @override
  String get forgeStrikePick => 'Strikes per hammer';

  @override
  String get forgeStrikePickHint =>
      'How many to forge per hammer blow. Applies to manual taps too.';

  @override
  String forgeStrikeLocked(int n) {
    return 'Needs chapter $n';
  }

  @override
  String get forgeStrikeAuto => 'Max';

  @override
  String get forgeReroll => 'Reroll';

  @override
  String get forgeExpand => 'Expand';

  @override
  String get forgeExpandMax => 'MAX';

  @override
  String get forgeRushTitle => 'Hammer rush';

  @override
  String forgeRushBody(int cost, int sec) {
    return 'Spend $cost jelly to hammer twice as fast for ${sec}s.\nUsing it again adds to the remaining time.';
  }

  @override
  String forgeRushLeft(int sec) {
    return '${sec}s left';
  }

  @override
  String get forgeRerollHint =>
      'Same tier and slot — only the options are rerolled';

  @override
  String forgeRushOn(int s) {
    return 'Rush ${s}s';
  }

  @override
  String forgeStackCount(int n, int max) {
    return 'Anvil $n/$max';
  }

  @override
  String get forgeNoJelly => 'Not enough jelly';

  @override
  String get upgradeMaxed => 'MAX';

  @override
  String get eliteLabel => 'ELITE';

  @override
  String gateGearHint(String cur, String need) {
    return 'Gear ×$cur · suggested ×$need';
  }

  @override
  String get gateGearWeak => 'Gear is weak — forge attack options';

  @override
  String get regionElementTitle => 'Region element';

  @override
  String get regionElementHint =>
      'Equip bugs whose element overcomes it and their hits get stronger. Bugs attack on their own timing, separately from you.';

  @override
  String get forgeStrikeStart => 'Start';

  @override
  String get forgeStopOnHitHint =>
      'Stops the auto-forge as soon as one passes your filter, saving the rest of your fossils.';

  @override
  String get forgeStopOnHitNoFilter =>
      'Set a filter first so there is something to stop on';

  @override
  String get forgeStoppedOnHit => 'Found what you were after';

  @override
  String get forgeStrikeAutoHint => 'Grows automatically as you clear chapters';

  @override
  String get forgeFiltered => 'Discarded — no matching stat';

  @override
  String get elementWheelTitle => 'Elemental Chart';

  @override
  String elementWheelRestrain(String mult) {
    return 'Restrain: hitting the foe a red arrow points to deals ${mult}x damage';
  }

  @override
  String get traitNoneBadge => 'No trait';

  @override
  String get elementWheelHint =>
      'Example: Water → Fire. A Water bug deals more damage to a Fire bug in duels.';

  @override
  String get leagueRewardListTitle => 'First-time reward (once per rank)';

  @override
  String get sideMine => 'YOU';

  @override
  String get sideFoe => 'FOE';

  @override
  String get battleStarting => 'Battle start!';

  @override
  String get sideMineTeam => 'My team';

  @override
  String get sideFoeTeam => 'Opponent';

  @override
  String leagueNeedTrophy(int n) {
    return '$n trophies';
  }

  @override
  String seasonRewardNow(String league) {
    return 'Season reward · now $league';
  }

  @override
  String get seasonRewardHint =>
      'Closes every Sunday 09:00 (KST) and pays by your league at that moment. Climb before it closes.';

  @override
  String eventOpensOn(String m, String d) {
    return 'Opens on $m/$d';
  }

  @override
  String eventOpensInDays(int n) {
    return 'D-$n';
  }

  @override
  String eventOpensInHours(int n) {
    return 'Starts in ${n}h';
  }

  @override
  String eventOpensInMinutes(int n) {
    return 'Starts in ${n}m';
  }

  @override
  String get eventSeeFlyer => 'See the flyer';

  @override
  String eventSoonBanner(String when) {
    return 'Bug King Championship · opens $when';
  }

  @override
  String get eventFlyerPrizeTag => '1st place prize';

  @override
  String adCooldown(int n) {
    return 'Next ad available in ${n}s';
  }

  @override
  String get jellyContinueTitle => 'Spend jelly';

  @override
  String jellyContinueAsk(int n) {
    return 'Today\'s free uses are gone. Continue for $n jelly?';
  }

  @override
  String get jellyContinueYes => 'Use jelly';

  @override
  String get giftDoubleCapTitle => 'Free double already used today';

  @override
  String get giftDoubleCapBody =>
      'With a Pass, every gift stays doubled\nand gets claimed automatically.';

  @override
  String get exchangeTitle => 'Exchange';

  @override
  String exchangeHint(String hours) {
    return 'Trade jelly for $hours hours of hunting at your current power';
  }

  @override
  String get exchangeToGold => 'To gold';

  @override
  String get exchangeToMaterial => 'To materials';

  @override
  String exchangeCost(int n) {
    return '$n jelly';
  }

  @override
  String exchangeGetGold(String amount) {
    return 'Get $amount gold';
  }

  @override
  String exchangeGetMaterial(String amount) {
    return 'Get $amount of each material';
  }

  @override
  String get exchangeDone => 'Exchanged!';

  @override
  String get curJelly => 'Jelly';

  @override
  String get exchangeHoldings => 'Your holdings';

  @override
  String get elementGuideBtn => 'Element chart';

  @override
  String get giftAdMoreFreeLine => 'Free double: once a day!';

  @override
  String get giftAdMorePassLine => 'With a Pass, every gift is doubled';

  @override
  String giftDoubleJellyLine(int min, int max) {
    return 'Today\'s first double bonus: $min–$max Bug Jelly!';
  }

  @override
  String get giftGoPassBtn => 'See the Pass';

  @override
  String get eventLegalTitle => 'Contest terms';

  @override
  String get eventLegalHost =>
      'This contest is hosted and run by the Bug Champ team (the developer), who is solely responsible for providing and shipping the prize.';

  @override
  String get eventLegalStores =>
      'Apple and Google are not sponsors of this contest and are not involved in any way.';

  @override
  String get eventLegalPrize =>
      'Rankings are finalized at the end of the contest. The winner will be contacted in-app about prize delivery (a shipping address may be requested). No purchase is necessary to participate or win.';

  @override
  String get eventLegalFair =>
      'Entries involving cheating (tampered data or abnormal access) may be excluded from rankings and prizes.';

  @override
  String get giftBuyPassBtn => 'Buy the Pass';

  @override
  String get supportTitle => 'Contact us';

  @override
  String get supportHint =>
      'Tell us about a bug or anything inconvenient. Your nickname and progress are sent along automatically.';

  @override
  String get supportSend => 'Send';

  @override
  String get supportSent => 'Sent. We will look into it!';

  @override
  String get supportFailed => 'Could not send. Please try again shortly.';

  @override
  String get supportTooFast => 'You can send another one in a moment.';

  @override
  String get zoneConquered => 'Conquered';

  @override
  String get zoneHere => 'You are here';

  @override
  String get zoneLocked => 'Locked';

  @override
  String badgeParticipant(int round) {
    return 'R$round Entrant';
  }

  @override
  String get eventWaitingTitle => 'Waiting for the next contest';

  @override
  String eventNextRound(int no, String date) {
    return 'Round $no opens $date';
  }

  @override
  String eventDateMd(int m, int d) {
    return '$m/$d';
  }

  @override
  String get eventHallTitle => 'Hall of Fame';

  @override
  String eventHallRound(int no, String n) {
    return 'Round $no · $n entrants';
  }

  @override
  String get eventHallEmpty => 'No one is in the Hall of Fame yet';

  @override
  String get eventHallTop10 => '4th–10th';

  @override
  String get eventHallEntrants => 'Everyone who took part';

  @override
  String get eventHallMore => 'and more';

  @override
  String get eventRewardBadgeLabel => 'Badge earned';

  @override
  String tierMoveTitle(String name) {
    return 'Move to $name';
  }

  @override
  String get tierMoveBody =>
      'Upgrades, currency and gear stay as they are.\nZone clear rewards are only given on your highest difficulty.';

  @override
  String get tierMoveGo => 'Move';

  @override
  String tierMoved(String name) {
    return 'Moved to $name';
  }

  @override
  String get pvpRankRewardTitle => 'Duel Season Rank Reward';

  @override
  String pvpRankRewardBody(int rank) {
    return 'You finished #$rank in last season\'s duels!';
  }

  @override
  String pvpRankN(int n) {
    return '#$n';
  }

  @override
  String pvpRankRewardHint(String list) {
    return 'Rank rewards (Jelly) $list';
  }

  @override
  String get duelThrowButton => 'Throw!';

  @override
  String duelGaugeHint(int pct) {
    return 'Tap anywhere to stop · the closer to green, the stronger your attack this bout (up to +$pct%)';
  }

  @override
  String duelBout(int n) {
    return 'Bout $n';
  }

  @override
  String get duelFinishRingOut => 'Ring out!';

  @override
  String get duelFinishFlip => 'Flipped!';

  @override
  String get duelFinishKnockout => 'Knockout!';

  @override
  String get duelFinishTimeUp => 'Decision!';

  @override
  String get duelBoutWin => 'Bout won!';

  @override
  String get duelBoutLose => 'Bout lost…';

  @override
  String get duelSkip => 'Skip';

  @override
  String duelTrophy(String delta) {
    return 'Trophies $delta';
  }

  @override
  String get duelResultOk => 'OK';

  @override
  String get duelNeedThree => 'You need 3 bugs for a duel';

  @override
  String get duelOrderHint =>
      '#1, #2, #3 each fight one bout · this order is also your defense order';

  @override
  String get abyssName => 'Abyss';

  @override
  String abyssFloorLabel(int n) {
    return 'Abyss F$n';
  }

  @override
  String get abyssUnlockedTitle => 'The Abyss is open!';

  @override
  String get abyssUnlockedBody =>
      'Endless floors beyond Extreme. Your upgrades, gear and bugs come with you.\nEvery Monday 09:00 (KST) you start again from F1, and the deepest floor at the Sunday 09:00 close earns ranking Jelly.';

  @override
  String get abyssEnter => 'Enter the Abyss';

  @override
  String get abyssLater => 'Later';

  @override
  String get abyssLeave => 'Leave the Abyss';

  @override
  String abyssFloorClear(int n) {
    return 'F$n cleared!';
  }

  @override
  String abyssMilestone(int n, int fossil) {
    return 'First time reaching F$n! Fossils +$fossil';
  }

  @override
  String abyssBest(int n) {
    return 'Best F$n';
  }

  @override
  String get abyssWeekReset => 'A new week — back to Abyss F1!';

  @override
  String get abyssRankRewardTitle => 'Abyss Weekly Rank Reward';

  @override
  String abyssRankRewardBody(int floor, int rank) {
    return 'Last week you reached Abyss F$floor and placed #$rank!';
  }

  @override
  String get boardTitle => 'Rankings';

  @override
  String get boardTabDuel => 'Duel League';

  @override
  String get boardTabAbyss => 'Abyss';

  @override
  String boardLeagueTitle(String league) {
    return '$league League';
  }

  @override
  String get boardAbyssTitle => 'Abyss Weekly Ranking';

  @override
  String boardSeasonEndsIn(String time) {
    return 'New season in: $time';
  }

  @override
  String boardTimeLeftDays(int d, int h, int m) {
    return '${d}d ${h}h ${m}m';
  }

  @override
  String boardTimeLeft(int h, int m) {
    return '${h}h ${m}m';
  }

  @override
  String boardZonesHint(int promote, int demote) {
    return 'Top $promote promote · bottom $demote demote';
  }

  @override
  String get boardEmpty => 'No records this week yet';

  @override
  String get boardMeNone => 'Duel this week to appear in the ranking';

  @override
  String get boardAbyssMeNone =>
      'Clear Abyss F1 this week to appear in the ranking';

  @override
  String boardFloorShort(int n) {
    return 'F$n';
  }

  @override
  String boardRewardsTitle(String league) {
    return '$league League Rank Rewards';
  }

  @override
  String get boardAbyssRewardsTitle => 'Abyss Weekly Rank Rewards';

  @override
  String get boardOpen => 'Rankings';

  @override
  String get leagueResultTitle => 'League Results';

  @override
  String leagueResultUp(String league) {
    return 'Promoted to $league League!';
  }

  @override
  String leagueResultDown(String league) {
    return 'Moved down to $league League';
  }

  @override
  String leagueResultStay(String league) {
    return 'Staying in $league League';
  }

  @override
  String leagueResultRank(int rank, int total) {
    return 'Last week: #$rank of $total';
  }

  @override
  String get leagueResultInactive =>
      'You skipped duels last week, so you moved down one league';

  @override
  String get leagueZoneHint =>
      'Closes every Sunday 09:00 · top 20% promote · bottom 20% demote';

  @override
  String get duelSquadTitle => 'Squad';

  @override
  String get recoveryRoom => 'Recovery';

  @override
  String get trainingCenter => 'Training';

  @override
  String get trainingSoon => 'Training opens soon';

  @override
  String get leagueClaimPromo => 'Claim promotion reward';

  @override
  String get battleSeasonClosed => 'The season has ended!';

  @override
  String get recoveryEmpty => 'No bugs are recovering';

  @override
  String get opponentPickTitle => 'Choose an opponent';

  @override
  String opponentPickHint(String power) {
    return 'Your team power $power · Win to earn stars, lose nothing';
  }

  @override
  String get opponentWinOnly => 'on win';

  @override
  String boardSeasonClosesIn(String time) {
    return 'Season closes: $time';
  }

  @override
  String boardMyRankNow(int rank) {
    return 'Now #$rank — your reward';
  }

  @override
  String profileCombatPower(String power) {
    return 'Power $power';
  }

  @override
  String get profileNoTeam => 'No defense team yet';

  @override
  String duelAutoThrowIn(int n) {
    return 'Auto-throw in ${n}s';
  }

  @override
  String get duelRestrainHit => 'Counter!';

  @override
  String get duelCritHit => 'Critical!';

  @override
  String get duelWeakHit => 'Weak spot!';

  @override
  String pvpTicketJellyGive(int amount) {
    return 'Refill +$amount';
  }

  @override
  String get bugInfoAtk => 'Attack';

  @override
  String get bugInfoDef => 'Defense';

  @override
  String get bugInfoSpd => 'Speed';

  @override
  String get bugInfoSpecialty => 'Specialty';

  @override
  String get bugInfoTemperament => 'Temper';

  @override
  String get bugInfoSize => 'Size';

  @override
  String get bugInfoPotential => 'Potential';

  @override
  String get squadDetailTitle => 'Squad';

  @override
  String get squadDeploy => 'Deploy';

  @override
  String get squadInjured =>
      'A bug is recovering — heal it in Recovery or swap it out';

  @override
  String squadOrder(int n) {
    return 'Fighter $n';
  }

  @override
  String get duelAttackBtn => 'Attack';

  @override
  String get squadRelease => 'Remove';

  @override
  String get squadSwap => 'Swap';

  @override
  String get trainAttack => 'Attack';

  @override
  String get trainDefense => 'Defense';

  @override
  String get trainEvade => 'Evade';

  @override
  String get trainCrit => 'Critical';

  @override
  String get trainRecovery => 'Recovery';

  @override
  String get trainingNone => 'No bug is training right now';

  @override
  String trainingNow(String stat, int level) {
    return 'Training $stat Lv$level';
  }

  @override
  String get trainingDone => 'Training complete!';

  @override
  String get trainingPickBug => 'Bug to train';

  @override
  String get trainingCapHint =>
      'Max levels differ by potential, temper, specialty and bloodline trait';

  @override
  String trainingLevel(int lv, int cap) {
    return '$lv / $cap';
  }

  @override
  String get trainingStart => 'Train';

  @override
  String get trainingMaxed => 'Max';

  @override
  String get trainingBusy =>
      'One bug at a time — wait for the current training';

  @override
  String get trainingNoMaterials => 'Not enough materials';

  @override
  String get trainingReset => 'Reset training';

  @override
  String trainingResetAsk(String n) {
    return 'Reset all levels to 0 and get back half the materials ($n of each)';
  }

  @override
  String get trainingResetDone => 'Training reset';

  @override
  String get squadTraining => 'A training bug cannot be deployed';

  @override
  String get duelMiss => 'Miss!';

  @override
  String get breedingConfirm => 'Mate';

  @override
  String breedingTimeInfo(String t) {
    return 'Egg in $t';
  }

  @override
  String get incubatorStartConfirm => 'Start hatching';

  @override
  String incubatorTimeInfo(String t) {
    return 'Hatches in $t';
  }

  @override
  String get bugInfoSex => 'Sex';

  @override
  String get bugInfoElement => 'Element';

  @override
  String leagueInfoTitle(String league) {
    return '$league League';
  }

  @override
  String get leagueInfoRank => 'Weekly rank rewards (closes Sun 09:00)';

  @override
  String get leagueInfoSeason => 'Season-end reward';

  @override
  String get leagueInfoAll => 'Rewards by league';

  @override
  String get leagueInfoCurrent => 'Now';

  @override
  String get leagueInfoAllHint =>
      'Jelly = 1st place in that league · Gold = season-end reward';

  @override
  String get boardPromoteLine => '▲ Promotion zone above';

  @override
  String get boardDemoteLine => '▼ Demotion zone below';

  @override
  String get squadAutoFilled =>
      'Squad filled automatically. Check it and tap Start again';

  @override
  String get battleSeasonClosedShort => 'Season over';

  @override
  String leagueMyNow(int rank, int total) {
    return 'Now #$rank of $total';
  }

  @override
  String leagueMyPromote(String league) {
    return '▲ Promotion zone — $league League next week';
  }

  @override
  String get leagueMyStay => 'Safe — same league next week';

  @override
  String leagueMyDemote(String league) {
    return '▼ Demotion zone — $league League next week';
  }

  @override
  String get leagueMyIfEnds => 'Reward if the season ended now';

  @override
  String boardBossPct(int n) {
    return 'Boss $n%';
  }

  @override
  String get boardAbyssHint =>
      'Same floor? Higher max damage on the next floor boss (Boss %) ranks higher';

  @override
  String rankProgressAbyss(String tier, int floor) {
    return '$tier · Abyss F$floor';
  }

  @override
  String duelLaunchBonus(int pct) {
    return 'Great throw! Attack +$pct% this bout';
  }

  @override
  String eventWaveHeader(int n) {
    return 'Wave $n';
  }

  @override
  String get eventStopHp => 'Out of HP — the run ends here.';

  @override
  String get eventDevPreview =>
      'Developer preview — no server record, rewards, tickets or injuries';

  @override
  String get eventDevTry => 'Try the contest (dev)';

  @override
  String get eventEntryLabel => 'Your entry';

  @override
  String get eventEntryEmpty =>
      'Pick your best-raised bug below to put it on stage';

  @override
  String get eventBuffNow => 'Active boosts';

  @override
  String get eventCardMaxed => 'MAX';

  @override
  String get eventBuffNone => 'No boosts yet';

  @override
  String eventBuffRevive(int n) {
    return 'Revive $n';
  }

  @override
  String eventFallRetry(int pct) {
    return 'HP -$pct% · retry the same wave';
  }

  @override
  String get eventReviveRetry => 'Revived! Retry the same wave';

  @override
  String get cardAgile => 'Nimble';

  @override
  String get cardAgileDesc => 'Evade +8%p — chance to dodge a clash entirely';

  @override
  String get cardVital => 'Vital Strike';

  @override
  String get cardVitalDesc => 'Critical chance +10%p';

  @override
  String get cardBreath => 'Catch Breath';

  @override
  String get cardBreathDesc => 'Heal 10% more HP after each wave';

  @override
  String get cardHeft => 'Heavyweight';

  @override
  String get cardHeftDesc => 'Body +40% — heavier, harder to push out';

  @override
  String get cardBerserk => 'Berserk';

  @override
  String get cardBerserkDesc => 'Attack +35% · but Defense -21%';

  @override
  String get cardIronhide => 'Ironhide';

  @override
  String get cardIronhideDesc => 'Defense +40% · but Speed -16%';

  @override
  String get cardLastStand => 'Last Stand';

  @override
  String get cardLastStandDesc => 'Attack +40% in waves you enter below 50% HP';

  @override
  String get eventBuffEvade => 'Evade';

  @override
  String get eventBuffCrit => 'Crit';

  @override
  String get eventBuffRecover => 'Heal';

  @override
  String get eventBuffSize => 'Body';

  @override
  String get eventBuffSpd => 'Speed';

  @override
  String get eventBuffLastStand => 'Last Stand';

  @override
  String get eventQuit => 'Retreat';

  @override
  String get eventQuitTitle => 'Stop here?';

  @override
  String eventQuitBody(int n, int hp, int injury) {
    return 'Your record is locked in at $n waves cleared.\nHP now $hp% — injury lasts only $injury% of the maximum.\n(The more HP left, the shorter the rest)';
  }

  @override
  String get charTabFairy => 'Fairies';

  @override
  String get fairyCompanion => 'Companion';

  @override
  String get fairyNoCompanion => 'No companion yet — pick one below';

  @override
  String fairyBoxTitle(String n, String max) {
    return 'Fairies $n/$max';
  }

  @override
  String fairyEggCount(String n) {
    return '$n eggs';
  }

  @override
  String get fairyEmptyBox =>
      'No fairies yet. Draw a fairy egg and hatch it in the nest!';

  @override
  String get fairyNest => 'Fairy Nest';

  @override
  String get fairyNestEmpty => 'The nest is empty — place an egg';

  @override
  String get fairyNestNoEgg => 'No eggs to place';

  @override
  String get fairyNestPut => 'Place in nest';

  @override
  String get fairyNestCollect => 'Collect';

  @override
  String get fairyNestReady => 'Ready to hatch!';

  @override
  String fairyNestLeft(String t) {
    return '$t left';
  }

  @override
  String fairyNestKindHint(String n) {
    return 'The kind is random among $n';
  }

  @override
  String get fairyStone => 'Attribute Stone';

  @override
  String get fairyStoneNone => 'No stone';

  @override
  String fairyStoneHint(String p) {
    return 'With a stone, that bonus stat appears $p% of the time';
  }

  @override
  String get fairyAccel => 'Accelerator';

  @override
  String fairyAccelMinutes(String t) {
    return '-$t';
  }

  @override
  String get fairyUse => 'Use';

  @override
  String get fairyBuy => 'Buy';

  @override
  String fairyOwned(String n) {
    return 'Owned $n';
  }

  @override
  String get fairyDex => 'Fairy Codex';

  @override
  String fairyDexGrades(String n, String max) {
    return 'Grades $n/$max';
  }

  @override
  String fairyDexSubs(String n, String max) {
    return 'Bonus stats $n/$max';
  }

  @override
  String get fairyGacha => 'Fairy Egg Draw';

  @override
  String get fairyGachaOne => 'x1';

  @override
  String get fairyGachaTen => 'x10';

  @override
  String fairyGachaPity(String n) {
    return 'Legendary+ guaranteed within $n';
  }

  @override
  String get fairyGachaOdds => 'Odds';

  @override
  String get fairyGachaOddsNote =>
      'The draw sets only the egg grade. Type, bonus stat and quality are rolled when it hatches. Mythic comes only from merging.';

  @override
  String fairyGachaGot(String n) {
    return 'Got $n eggs';
  }

  @override
  String get fairyDust => 'Fairy Dust';

  @override
  String fairyLevel(String n) {
    return 'Lv.$n';
  }

  @override
  String get fairyLevelUp => 'Level up';

  @override
  String get fairyMaxLevel => 'Max level';

  @override
  String fairyQuality(String p) {
    return 'Quality $p%';
  }

  @override
  String get fairyStatMain => 'Base';

  @override
  String get fairyStatSub => 'Bonus';

  @override
  String get fairySkill => 'Skill';

  @override
  String fairyCooldown(String s) {
    return '${s}s cooldown';
  }

  @override
  String get fairyGoCompanion => 'Make companion';

  @override
  String get fairyIsCompanion => 'Companion';

  @override
  String get fairyMerge => 'Merge';

  @override
  String fairyMergeEpicNote(String n) {
    return 'Epic → Legendary merges need $n fairies.';
  }

  @override
  String fairyReroll(String left) {
    return 'Reroll ($left left)';
  }

  @override
  String get fairyRerollTitle => 'Fairy reroll';

  @override
  String get fairyRerollConfirm =>
      'Rerolls the base and bonus values. The bonus stat itself may change too. If you don\'t like the result, you can keep the current values.\n\nUses per day are limited.';

  @override
  String get fairyRerollPick => 'Which one do you want?';

  @override
  String get fairyRerollNow => 'Current';

  @override
  String get fairyRerollNew => 'New';

  @override
  String get fairyRerollKeep => 'Keep current';

  @override
  String get fairyRerollTake => 'Use new';

  @override
  String get fairyRerollCap => 'No rerolls left today. Try again tomorrow.';

  @override
  String get fairyRerollNetwork =>
      'Needs a server connection. Please try again shortly.';

  @override
  String fairyMergeHint(String n) {
    return '$n of the same type & grade → 1 of the next grade. Base and bonus stats are rolled fresh for the new grade.';
  }

  @override
  String fairyMergePick(String n, String max) {
    return 'Materials $n/$max';
  }

  @override
  String get fairyMergeNoMat => 'Not enough fairies of the same type & grade';

  @override
  String get fairyAutoMerge => 'Auto merge';

  @override
  String fairyAutoMergeConfirm(String used, String made) {
    return '$used fairies become $made. Companion and leveled fairies are skipped; lowest quality goes first. Results are rolled fresh.';
  }

  @override
  String get fairyAutoMergeNone => 'Nothing to auto merge';

  @override
  String get fairyRelease => 'Release';

  @override
  String get fairyNestBtn => 'Nest';

  @override
  String get fairyGachaBtn => 'Draw';

  @override
  String get fairyDexBtn => 'Codex';

  @override
  String get fairyMergeBtn => 'Merge';

  @override
  String get fairyReleaseBtn => 'Release';

  @override
  String fairyReleaseConfirm(String n) {
    return 'Releasing gives $n fairy dust.\nThis cannot be undone.';
  }

  @override
  String get fairyNew => 'New fairy!';

  @override
  String get fairyErrJelly => 'Not enough jelly';

  @override
  String get fairyErrDust => 'Not enough fairy dust';

  @override
  String get fairyErrGeneric => 'Can\'t do that right now';

  @override
  String get fairyGradeCommon => 'Common';

  @override
  String get fairyGradeRare => 'Rare';

  @override
  String get fairyGradeEpic => 'Epic';

  @override
  String get fairyGradeLegendary => 'Legendary';

  @override
  String get fairyGradeMythic => 'Mythic';

  @override
  String get fairyStatAttack => 'Attack';

  @override
  String get fairyStatHp => 'HP';

  @override
  String get fairyStatDefense => 'Damage taken';

  @override
  String get fairyStatAttackSpeed => 'Attack speed';

  @override
  String get fairyStatCritDamage => 'Crit damage';

  @override
  String get fairyStatBossDamage => 'Boss damage';

  @override
  String get fairyStatPetShare => 'Bug damage';

  @override
  String fairySkillBurst(String s) {
    return 'Deals ${s}s worth of damage at once';
  }

  @override
  String fairySkillHeal(String p) {
    return 'Heals $p% max HP when below 60%';
  }

  @override
  String fairySkillGuard(String d, String p) {
    return 'For ${d}s, -$p% damage taken';
  }

  @override
  String fairySkillHaste(String d, String p) {
    return 'For ${d}s, +$p% attack speed';
  }

  @override
  String fairySkillCrits(String s) {
    return 'All hits are critical for ${s}s';
  }

  @override
  String fairySkillBossBurst(String s) {
    return 'Deals ${s}s worth of damage to bosses';
  }

  @override
  String fairySkillPet(String d, String p) {
    return 'For ${d}s, +$p% bug damage';
  }

  @override
  String fairySkillStand(String p) {
    return 'Once, survive a fatal hit with $p% HP';
  }

  @override
  String fairyEggPop(String grade) {
    return 'Fairy egg · $grade';
  }

  @override
  String get guildTitle => 'Guild';

  @override
  String get guildIntro =>
      'Join a guild to take on missions, the guild boss and weekly guild wars together — plus check-ins, the guild shop and guild buffs.';

  @override
  String get guildUnavailable =>
      'Couldn\'t load guild info. Please try again in a moment.';

  @override
  String get guildRetry => 'Retry';

  @override
  String get guildSearchHint => 'Search guild name';

  @override
  String get guildEmptyList => 'No guilds found. Why not create one?';

  @override
  String get guildCreate => 'Create guild';

  @override
  String guildNameHint(int min, int max) {
    return 'Guild name ($min–$max chars)';
  }

  @override
  String get guildJoinModeOpen => 'Open — anyone can join instantly';

  @override
  String get guildJoinModeApproval => 'Approval — leaders review requests';

  @override
  String get guildJoinModeOpenShort => 'Open';

  @override
  String get guildJoinModeApprovalShort => 'Approval';

  @override
  String get guildJoin => 'Join';

  @override
  String get guildRequest => 'Request';

  @override
  String get guildCancelRequest => 'Cancel request';

  @override
  String get guildFull => 'Full';

  @override
  String guildMembersCount(int n, int max) {
    return '$n/$max members';
  }

  @override
  String guildAvgPower(String v) {
    return 'Avg. power $v';
  }

  @override
  String guildCooldown(String time) {
    return 'You can join another guild in $time';
  }

  @override
  String get guildTabMembers => 'Members';

  @override
  String get guildTabChat => 'Chat';

  @override
  String guildTabRequests(int n) {
    return 'Req. $n';
  }

  @override
  String get guildRoleLeader => 'Leader';

  @override
  String get guildRoleDeputy => 'Deputy';

  @override
  String get guildRoleMember => 'Member';

  @override
  String get guildLastSeenNow => 'Online recently';

  @override
  String guildLastSeenHours(int n) {
    return '${n}h ago';
  }

  @override
  String guildLastSeenDays(int n) {
    return '${n}d ago';
  }

  @override
  String get guildNoticeEmpty => 'No guild introduction yet';

  @override
  String get guildNoticeHint => 'Introduce your guild';

  @override
  String get guildEditNotice => 'Edit introduction';

  @override
  String get guildChangeJoinMode => 'Join mode';

  @override
  String get guildSave => 'Save';

  @override
  String get guildLeave => 'Leave guild';

  @override
  String guildLeaveConfirm(int hours) {
    return 'After leaving, you can\'t join another guild for $hours hours. Leave?';
  }

  @override
  String get guildLeaveLastConfirm =>
      'You\'re the last member — the guild will be disbanded. Leave?';

  @override
  String get guildLeaderLeaveNote =>
      'Leadership passes to a deputy (or the most active member).';

  @override
  String get guildKick => 'Remove from guild';

  @override
  String guildKickConfirm(String name) {
    return 'Remove $name from the guild?';
  }

  @override
  String get guildMakeDeputy => 'Make deputy';

  @override
  String get guildRemoveDeputy => 'Remove deputy';

  @override
  String get guildTransfer => 'Transfer leadership';

  @override
  String guildTransferConfirm(String name) {
    return 'Make $name the guild leader?';
  }

  @override
  String get guildAccept => 'Accept';

  @override
  String get guildReject => 'Decline';

  @override
  String get guildNoRequests => 'No join requests';

  @override
  String get guildCreated => 'Guild created!';

  @override
  String get guildJoined => 'You joined the guild!';

  @override
  String get guildRequestSent => 'Join request sent';

  @override
  String get guildChatEmpty => 'No guild messages yet. Say hello!';

  @override
  String get guildErrNameTaken => 'That name is already taken';

  @override
  String get guildErrNameInvalid =>
      'That name can\'t be used (check length, characters and words)';

  @override
  String get guildErrCooldown => 'You can\'t join another guild yet';

  @override
  String get guildErrFull => 'This guild is full';

  @override
  String get guildErrTooManyRequests =>
      'Too many pending requests — cancel one first';

  @override
  String get guildErrRequestsFull =>
      'This guild has too many requests. Try again later';

  @override
  String get guildErrDeputyFull => 'No more deputy slots';

  @override
  String get guildErrNoticeInvalid => 'That introduction can\'t be used';

  @override
  String get guildErrGeneric => 'Something went wrong. Please try again';

  @override
  String guildCreateWithCost(int cost) {
    return 'Create guild · $cost jelly';
  }

  @override
  String guildCreateNeedJelly(int cost) {
    return 'You need $cost jelly to create a guild';
  }

  @override
  String get guildErrJelly => 'Not enough jelly';

  @override
  String get guildTabMissions => 'Missions';

  @override
  String get guildMissionForest => 'Forest survey';

  @override
  String get guildMissionCave => 'Cave expedition';

  @override
  String get guildMissionSwamp => 'Swamp search';

  @override
  String get guildMissionRuins => 'Ruins dig';

  @override
  String get guildMissionCanyon => 'Canyon patrol';

  @override
  String get guildMissionMeadow => 'Meadow gathering';

  @override
  String get guildMissionErrNoStarts => 'No missions left today';

  @override
  String get guildMissionErrRunning => 'You already have a mission in progress';

  @override
  String get guildMissionErrClosed => 'That mission has already ended';

  @override
  String get guildMissionErrHelped => 'You already helped this mission';

  @override
  String get guildMissionErrHelpersFull =>
      'This mission already has enough helpers';

  @override
  String get guildMissionErrOwn => 'You can\'t help your own mission';

  @override
  String get guildMissionErrNothing => 'No rewards to claim';

  @override
  String get guildMissionHelped => 'Helped! Your power was added';

  @override
  String get guildMissionSoloHint =>
      'You can clear this one alone — it succeeds instantly.';

  @override
  String get guildMissionWaitHint =>
      'Choose how long to wait. Guildmates who help add their power — if the total beats the requirement when time runs out, you succeed. If 3 helpers join, it succeeds instantly! Longer waits give bigger rewards.';

  @override
  String guildMissionWaitOption(int min, String mult) {
    return 'Wait $min min · reward ×$mult';
  }

  @override
  String get guildMissionClaimTitle => 'Mission rewards';

  @override
  String guildMissionCoins(int n) {
    return 'Guild coins +$n';
  }

  @override
  String guildMissionEgg(int n) {
    return 'Fairy egg ×$n!';
  }

  @override
  String guildMissionStartsLeft(int n, int max) {
    return 'Missions $n/$max';
  }

  @override
  String guildMissionHelpLeft(int n, int max) {
    return 'Help rewards $n/$max';
  }

  @override
  String guildMissionReset(String time) {
    return 'resets in $time';
  }

  @override
  String guildMissionClaimable(int n) {
    return '$n mission rewards ready';
  }

  @override
  String get guildMissionClaim => 'Claim';

  @override
  String get guildMissionActive => 'Help requests';

  @override
  String get guildMissionNoActive => 'No missions in progress right now';

  @override
  String get guildMissionBoard => 'Today\'s board';

  @override
  String get guildMissionRecent => 'Today\'s results';

  @override
  String get guildMissionMine => 'My mission';

  @override
  String guildMissionOwner(String name) {
    return '$name\'s mission';
  }

  @override
  String guildMissionProgress(int p, int n, int max) {
    return '$p% · helpers $n/$max';
  }

  @override
  String get guildMissionHelp => 'Help';

  @override
  String get guildMissionHelpedTag => 'Helped';

  @override
  String guildMissionSlotSolo(String mult) {
    return 'Power ×$mult · clear it solo';
  }

  @override
  String guildMissionSlotNeed(String mult) {
    return 'Power ×$mult · needs help';
  }

  @override
  String get guildMissionStart => 'Start';

  @override
  String get guildMissionSuccess => 'Success';

  @override
  String guildMissionPartial(int p) {
    return '$p%';
  }

  @override
  String get guildMissionChatMine => 'You asked your guild for help';

  @override
  String guildMissionChatAsk(String name) {
    return '$name needs help with a mission!';
  }

  @override
  String guildLevel(int n) {
    return 'Lv $n';
  }

  @override
  String guildCoins(int n) {
    return '$n guild coins';
  }

  @override
  String get guildDonate => 'Check in';

  @override
  String get guildDonateDoneShort => 'Checked';

  @override
  String get guildDonateOk => 'Checked in! Guild coins and guild EXP added';

  @override
  String get guildDonateDone => 'Already checked in today';

  @override
  String get guildSkills => 'Skills';

  @override
  String get guildShop => 'Shop';

  @override
  String get guildSkillAttack => 'Attack';

  @override
  String get guildSkillHp => 'HP';

  @override
  String get guildSkillGold => 'Gold';

  @override
  String get guildSkillMaterial => 'Material find';

  @override
  String get guildSkillXp => 'EXP';

  @override
  String get guildSkillMission => 'Mission rewards';

  @override
  String guildSkillHeader(int n) {
    return 'Skill points left: $n';
  }

  @override
  String get guildSkillNote =>
      'Buffs apply to every guildmate while hunting (offline gold too). They don\'t apply to duels or events. Leaving the guild removes them. Guild level +1 = 1 point.';

  @override
  String guildSkillValue(String now, String max) {
    return '+$now% (max +$max%)';
  }

  @override
  String get guildSkillNoPoints => 'No skill points left';

  @override
  String get guildSkillMax => 'Already maxed';

  @override
  String get guildSkillForbidden => 'Only the leader can do this';

  @override
  String get guildSkillReset => 'Reset';

  @override
  String get guildSkillResetBody =>
      'Reset all guild skills and refund every point?';

  @override
  String get guildShopNote =>
      'Earn coins from missions, helping, check-ins and the guild boss.';

  @override
  String guildShopMaterials(String h) {
    return 'Materials (${h}h of hunting)';
  }

  @override
  String guildShopFossil(int n) {
    return 'Fossil ×$n';
  }

  @override
  String guildShopFairyDust(int n) {
    return 'Fairy dust ×$n';
  }

  @override
  String guildShopFairyEgg(int n) {
    return 'Fairy egg ×$n';
  }

  @override
  String guildShopSkillShard(String grade, int n) {
    return '$grade wild shard ×$n';
  }

  @override
  String guildShopLimitDay(int n, int max) {
    return 'Today $n/$max';
  }

  @override
  String guildShopLimitWeek(int n, int max) {
    return 'This week $n/$max';
  }

  @override
  String guildShopBought(String item) {
    return 'Bought: $item';
  }

  @override
  String get guildShopSoldOut => 'Purchase limit reached';

  @override
  String get guildShopSoldOutShort => 'Sold out';

  @override
  String get guildShopNoCoins => 'Not enough guild coins';

  @override
  String get guildTabBoss => 'Boss';

  @override
  String guildBossTitle(int n) {
    return 'Guild boss · Stage $n';
  }

  @override
  String guildBossAttack(int n) {
    return 'Attack ($n left today)';
  }

  @override
  String get guildBossNote =>
      'Damage comes from your duel defense team (fairies, skills and gear don\'t count). HP is shared by the whole guild and carries over all week.';

  @override
  String get guildBossNoTeam =>
      'Register a duel defense team to attack the boss.';

  @override
  String get guildBossNoAttacks => 'No attacks left today';

  @override
  String guildBossHit(String d) {
    return '$d damage';
  }

  @override
  String get guildBossKilled => 'Boss defeated! Next stage';

  @override
  String guildBossMine(String d) {
    return 'My damage this week: $d';
  }

  @override
  String guildBossRank(int n) {
    return 'Guild rank this week: #$n';
  }

  @override
  String get guildBossRankNone =>
      'Not ranked yet — attack to enter the ranking';

  @override
  String guildBossTopRow(int s, int p) {
    return 'Stage $s · $p%';
  }

  @override
  String guildBossLastWeek(int rank, int jelly) {
    return 'Last week #$rank — $jelly jelly';
  }

  @override
  String guildBossClaimed(int n) {
    return 'Received $n jelly!';
  }

  @override
  String get guildTabWar => 'War';

  @override
  String get guildWarBreed => 'Breeding';

  @override
  String get guildWarForge => 'Forging';

  @override
  String get guildWarHunt => 'Hunting';

  @override
  String get guildWarDuel => 'Duels';

  @override
  String get guildWarTrain => 'Training';

  @override
  String get guildWarBoss => 'Guild boss';

  @override
  String get guildWarClash => 'Power clash';

  @override
  String get guildWarBreedHint =>
      'Finish breeding, collect hatched eggs and synthesize. Jelly-rushed completions don\'t count.';

  @override
  String get guildWarForgeHint => 'Forge gear — higher grades score far more.';

  @override
  String get guildWarHuntHint => 'Defeat elites and zone bosses.';

  @override
  String get guildWarDuelHint => 'Win duels (confirmed by the server).';

  @override
  String get guildWarTrainHint =>
      'Level up bugs, start training steps and finish skill training.';

  @override
  String get guildWarBossHint => 'Attack the guild boss.';

  @override
  String get guildWarClashHint =>
      'Nothing to do today! Members are paired 1:1 by duel defense team power and fight automatically. Results come in when you open this tab.';

  @override
  String guildWarTier(String tier, int gr) {
    return '$tier tier · $gr GR';
  }

  @override
  String get guildWarClosed => 'Guild wars aren\'t open yet.';

  @override
  String guildWarOpensOn(String date) {
    return 'Guild wars start the week of $date.';
  }

  @override
  String guildWarNeedMembers(int n) {
    return 'A guild needs at least $n members to enter this week\'s war.';
  }

  @override
  String guildWarVs(String name) {
    return 'vs $name';
  }

  @override
  String get guildWarVsVirtual => 'vs Wild Guild (tier average)';

  @override
  String get guildWarVirtualName => 'Wild';

  @override
  String guildWarDayOf(int d, String theme) {
    return 'Day $d · $theme';
  }

  @override
  String guildWarMyToday(int n, int cap) {
    return 'My points today $n/$cap';
  }

  @override
  String get guildWarWin => 'Victory';

  @override
  String get guildWarLose => 'Defeat';

  @override
  String get guildWarDraw => 'Draw';

  @override
  String guildWarPoints(int a, int b) {
    return 'Points $a : $b';
  }

  @override
  String guildWarClashResult(int a, int b) {
    return 'Day 7 duels $a : $b';
  }

  @override
  String guildWarReward(String result, int coins, int jelly) {
    return '$result reward — $coins coins · $jelly jelly';
  }

  @override
  String guildWarClaimed(int coins, int jelly) {
    return 'Received $coins coins · $jelly jelly!';
  }

  @override
  String duelPickDeployed(int n) {
    return 'In slot $n';
  }

  @override
  String get fairyDexHelp =>
      'The Fairy Codex records every fairy you have ever obtained. Each of the 8 fairies has two rows to fill:\n• Grade dots — a dot lights up the first time you get that fairy at that grade.\n• Stat stones — a stone lights up the first time you get that fairy with that bonus stat.\nA fairy is recorded when it hatches from an egg in the nest or is made by merging, and records stay even if you release the fairy. Fill cells to earn rewards below (fairy dust, accelerators, fossils). It does not give stats.';

  @override
  String get fairyDexLegendGrades =>
      'Grade dots (lit = obtained at that grade)';

  @override
  String get fairyDexLegendSubs =>
      'Stat stones (bright = obtained with that bonus stat)';

  @override
  String fairyDexRewards(int n, int max) {
    return 'Codex rewards · $n/$max collected';
  }

  @override
  String get fairyDexClaimed => 'Codex reward received!';

  @override
  String get fairyNestPickEgg => 'Pick an egg to place first';

  @override
  String get guideTitle => 'Guidebook';

  @override
  String get guideIntro =>
      'Every bug is different even within a species. Tap a topic to see what each term means.';

  @override
  String get guideElementTitle => 'Elements (Wood·Fire·Earth·Metal·Water)';

  @override
  String guideElementBody(String mult) {
    return 'Each bug has one element. In duels, when a bug clashes with an element it restrains, it deals ${mult}x damage. The red arrows show who beats whom.';
  }

  @override
  String guideElementLine(String a, String b) {
    return '$a beats $b';
  }

  @override
  String get guideSpecialtyTitle => 'Specialty (fighting style)';

  @override
  String get guideSpecialtyBody =>
      'Each species has a specialty that decides how it fights in duels.';

  @override
  String get guideSpecialtyStrike => 'Charges in to ram and flip the opponent.';

  @override
  String get guideSpecialtyGrip =>
      'Bites and holds on, pushing the opponent out.';

  @override
  String get guideSpecialtyToss => 'Lifts the opponent and throws it.';

  @override
  String get guideTemperamentTitle => 'Temperament (fighting tendency)';

  @override
  String get guideTemperamentBody =>
      'Temperament decides how a bug moves in duels and which training slots it can put more points into (slot caps).';

  @override
  String get guideTempAggressive => 'Charges often — an attacker.';

  @override
  String get guideTempCautious => 'Avoids the edge and sidesteps charges.';

  @override
  String get guideTempCunning => 'Circles to the side to hit weak spots.';

  @override
  String get guideTempSteadfast => 'Hard to push — a tank.';

  @override
  String get guideTempFickle => 'Mixes all styles.';

  @override
  String guideTrainCapMods(String mods) {
    return 'Training slot caps: $mods';
  }

  @override
  String get guideSizeTitle => 'Size (weight)';

  @override
  String guideSizeBody(String min, String max) {
    return 'Size is rolled within the species\' range. Bigger bugs get stats ×$min~×$max, are harder to push and less likely to fall out of the ring in duels.';
  }

  @override
  String get guidePotentialTitle => 'Potential (1–5 stars)';

  @override
  String guidePotentialBody(int perStar, int fodder) {
    return 'More stars mean more training points ($perStar per star). Merge $fodder bugs of the same species to gain a star.';
  }

  @override
  String get guideTraitTitle => 'Bloodline traits (breeding only)';

  @override
  String get guideTraitBody =>
      'Only bugs born from breeding can have a trait — wild bugs never do. Traits work both as a pet and in duels.';

  @override
  String guideTraitEffect(String atk, String hp) {
    return 'Attack +$atk · HP +$hp';
  }

  @override
  String get guideBreedTitle => 'Breeding & inheritance';

  @override
  String guideBreedBody(String el, String tm, String tr) {
    return 'Pair a male and female adult of the same species to get an egg. The child inherits the parents\' element ($el) and temperament ($tm) with high chance, and a parent\'s trait ($tr). If both parents share the same element, temperament or trait, the child is guaranteed to get it — so you can build your own line.';
  }

  @override
  String get guideVariantTitle => 'Variant bugs';

  @override
  String guideVariantBody(
    String wild,
    String breed,
    String parent,
    String gacha,
    String pet,
    String duel,
  ) {
    return 'Very rarely a bug with different colors (rainbow / albino) appears. Chance: wild $wild · breeding $breed · variant parent $parent · egg draw $gacha. As a pet its stats are +$pet, in duels +$duel.';
  }

  @override
  String get guideLifeTitle => 'Life stages';

  @override
  String get guideLifeBody =>
      'Egg → Larva → Pupa → Adult. Eggs hatch into larvae only in the incubator. Larvae grow into adults over time. Only adults can be trained, bred and sent to duels.';

  @override
  String get guideDuelTitle => 'Duels';

  @override
  String guideDuelBody(int sec, String weak) {
    return 'A bout is a $sec-second 1:1 physical fight in a round arena. Win by ring-out, flipping, or knockout; when time runs out, remaining HP % decides. A match is 3 bugs, winner stays on. Hitting the side or back deals ×$weak damage, and critical hits and evasion also apply.';
  }

  @override
  String get guideTrainTitle => 'Training ground';

  @override
  String guideTrainBody(String perStar, String levels, String bt) {
    return 'Every bug earns training points — $perStar per potential star · 1 every $levels train levels · $bt per breakthrough tier. Spend them on the slots below. Each slot has a cap, and the caps add up to far more than your points, so you can\'t fill everything — what you pick is your strategy. Slot caps differ by temperament, specialty and bloodline trait.';
  }

  @override
  String bugInfoSizeDetail(String mm, String min, String max, String mult) {
    return '${mm}mm (range $min–$max) · stats ×$mult';
  }

  @override
  String get eventHudShort => 'King\nCup';

  @override
  String fairyStoneName(String stat) {
    return '$stat stone';
  }

  @override
  String fairyStoneEffect(String stat, String p) {
    return 'The hatched fairy\'s sub-stat becomes $stat with $p% chance';
  }

  @override
  String get fairyStoneBuyTitle => 'Buy element stone';

  @override
  String get fairyStoneBuyAction => 'Buy';

  @override
  String get fairyEquippedTag => 'Equipped';

  @override
  String get fairyMergeEquipped => 'An equipped fairy can\'t be merged';

  @override
  String get fairyAutoMergeDone => 'Merge results';

  @override
  String get exchangeToDust => 'Fairy dust';

  @override
  String get exchangeHintDust =>
      'Trade jelly for fairy dust (1 jelly = 1 dust)';

  @override
  String exchangeGetDust(String amount) {
    return 'Get $amount fairy dust';
  }

  @override
  String fairyStatRange(String grade, String lo, String hi) {
    return '($grade range $lo~$hi)';
  }

  @override
  String get fairyStopCompanion => 'Stop companion';

  @override
  String get fairyHelpTitle => 'Help';

  @override
  String get fairyHelpGradeHead => 'Base stat range by grade (Lv.1)';

  @override
  String fairyHelpGradeLine(String grade, String lo, String hi, String max) {
    return '$grade: $lo ~ $hi · max Lv.$max';
  }

  @override
  String fairyHelpLevel(String p) {
    return 'Each level adds +$p of the value (Lv.1 basis).';
  }

  @override
  String get fairyHelpSubHead => 'Sub-stat (one per fairy)';

  @override
  String fairyHelpSub(String p) {
    return 'Rolled at hatching from the list below — $p of the base range × the stat\'s weight. An element stone raises the chance of the one you want.';
  }

  @override
  String fairyHelpSubLine(String stat, String grade, String lo, String hi) {
    return '$stat: $grade $lo ~ $hi';
  }

  @override
  String get fairyHelpMergeHead => 'Merge';

  @override
  String fairyHelpMerge(String n) {
    return '$n fairies of the same kind and grade → 1 of the next grade. Base and sub stats are rolled again, so you can aim for a better one.';
  }

  @override
  String fairyGachaOverflowWarn(String free, String lost) {
    return 'Your fairy box has $free free slots — $lost eggs will turn into fairy dust.';
  }

  @override
  String fairyOverflowToast(String n, String dust) {
    return 'Box full — $n eggs became $dust fairy dust';
  }

  @override
  String fairyOverflowPop(String dust) {
    return 'Box full · Fairy dust +$dust';
  }

  @override
  String fairyMergeInvestedConfirm(String n, String dust) {
    return '$n leveled-up fairies will be used. You get back $dust fairy dust (part of what you spent). Merge?';
  }

  @override
  String fairyMergeRefund(String dust) {
    return '$dust fairy dust returned';
  }

  @override
  String get fairyReleaseHint =>
      'Pick fairies and eggs to release. They turn into fairy dust.\n(Cannot be undone)';

  @override
  String fairyReleasePicked(String n) {
    return '$n picked';
  }

  @override
  String fairyReleaseAllOf(String grade, String n) {
    return 'All $grade ($n)';
  }

  @override
  String get fairyReleaseEquipped => 'Your companion fairy cannot be released';

  @override
  String fairyReleaseBulkConfirm(String n, String dust) {
    return 'Release $n for $dust fairy dust?\nThis cannot be undone.';
  }

  @override
  String fairyReleaseValuableNote(String n) {
    return 'Includes $n leveled or Legendary+ fairies.';
  }

  @override
  String fairyReleaseDone(String dust) {
    return 'Fairy dust +$dust';
  }

  @override
  String get fairyAutoReleaseTitle => 'Auto-release eggs';

  @override
  String get fairyAutoReleaseOff => 'Off';

  @override
  String fairyAutoReleaseUpTo(String grade) {
    return '$grade & below';
  }

  @override
  String get fairyAutoReleaseHelp =>
      'New eggs at or below this grade turn into fairy dust instead of entering the box. Eggs bought in the guild shop are kept.';

  @override
  String fairyAutoReleasePop(String dust) {
    return 'Egg auto-released · Fairy dust +$dust';
  }

  @override
  String fairyAutoReleaseToast(String n, String dust) {
    return 'Auto-released $n eggs for $dust fairy dust';
  }

  @override
  String exchangeDustLeft(String n) {
    return '$n left today';
  }

  @override
  String get exchangeDustCapReached => 'Today\'s limit reached';

  @override
  String get bugLock => 'Lock';

  @override
  String get bugLocked => 'Locked';

  @override
  String get bugUnlock => 'Unlock';

  @override
  String get bugLockedToast =>
      'Locked — it won\'t be used for merging or dismantling';

  @override
  String get bugUnlockedToast => 'Unlocked';

  @override
  String get disassembleLocked =>
      'Locked bugs can\'t be dismantled. Unlock it first.';

  @override
  String trainingSumShort(int n) {
    return 'Train Lv.$n';
  }

  @override
  String get reviewAskTitle => 'Enjoying Bug Champ?';

  @override
  String get reviewAskBody =>
      'If you have a moment, a store review would really help a solo developer.\nThank you for playing!';

  @override
  String get reviewAskLater => 'Later';

  @override
  String get trainingNoneShort => 'Untrained';

  @override
  String get guildComingSoonTitle => 'Coming soon';

  @override
  String get guildComingSoonBody =>
      'Guilds — missions, guild boss, shop and weekly guild wars — are coming in an upcoming update. Stay tuned!';

  @override
  String get notifChannelName => 'Reward alerts';

  @override
  String get notifChannelDesc =>
      'Lunch/dinner rewards and full offline-reward alerts';

  @override
  String get eggOddsTitle => 'Bug egg draw odds';

  @override
  String get eggOddsGradeHead =>
      'Grade (each species in the grade is equally likely)';

  @override
  String get eggOddsPotentialHead => 'Potential';

  @override
  String eggOddsVariant(String p) {
    return 'Variant (rainbow/albino): $p%';
  }

  @override
  String eggOddsPity(String n, String grade) {
    return 'Every ${n}th draw guarantees $grade or higher';
  }

  @override
  String get eggOddsNote =>
      'Odds are per draw. The pity counter resets only when its grade appears.';

  @override
  String eggOddsGradeLine(String grade, String p, String each) {
    return '$grade $p% · each species $each%';
  }

  @override
  String get variantRainbow => 'Rainbow';

  @override
  String get variantAlbino => 'Albino';

  @override
  String get jellyShortTitle => 'Not enough jelly';

  @override
  String get jellyShortBody => 'Get jelly in the shop and continue right away.';

  @override
  String get jellyShortGoShop => 'Go to shop';

  @override
  String pvpRefillLimit(int n) {
    return 'You can refill with jelly up to $n times a day';
  }

  @override
  String get pvpTicketRefillTitle => 'Refill tickets';

  @override
  String pvpTicketRefillBody(int n, int left) {
    return 'Get $n tickets with jelly. ($left left today)';
  }

  @override
  String get starterOfferTitle => 'Starter package';

  @override
  String get starterOfferBody =>
      'Only once per account — the best value in the shop!';

  @override
  String get starterOfferGo => 'See it';

  @override
  String mailGrantTitle(String name) {
    return '[From the team] $name';
  }

  @override
  String get mailGrantBody =>
      'A reward from the team. Tap Claim to receive it.';

  @override
  String get mailReplyTitle => '[Reply from the team]';

  @override
  String get jellyActExpand => 'Expand';

  @override
  String get jellyActCharge => 'Buy';

  @override
  String get jellyActExchange => 'Exchange';

  @override
  String get jellyActReroll => 'Reroll';

  @override
  String eventJellyTicketConfirm(int jelly, int n, int used, int max) {
    return 'Spend $jelly Jelly for +$n entry tickets?\n(Used today: $used/$max)';
  }

  @override
  String get storageExpandTitle => 'Expand storage';

  @override
  String storageExpandConfirm(int jelly, int n) {
    return 'Spend $jelly Jelly to add $n storage slots?';
  }

  @override
  String get fairyBoxExpandTitle => 'Expand fairy box';

  @override
  String fairyBoxExpandConfirm(int jelly, int n) {
    return 'Spend $jelly Jelly to add $n fairy box slots?';
  }

  @override
  String get fairyBoxExpanded => 'Fairy box expanded!';

  @override
  String fairyBoxExpandSlots(int n) {
    return '+$n slots';
  }

  @override
  String get breedingExpandTitle => 'Expand breeding slots';

  @override
  String get incubatorExpandTitle => 'Expand incubator';

  @override
  String slotExpandConfirm(int jelly) {
    return 'Spend $jelly Jelly to add 1 slot?';
  }

  @override
  String get breedingInstantTitle => 'Finish breeding now';

  @override
  String breedingInstantConfirm(int jelly) {
    return 'Spend $jelly Jelly to get the egg right now?';
  }

  @override
  String incubatorInstantConfirm(int jelly) {
    return 'Spend $jelly Jelly to hatch it right now?';
  }

  @override
  String get breakthroughInstantTitle => 'Finish breakthrough now';

  @override
  String breakthroughInstantConfirm(int jelly) {
    return 'Spend $jelly Jelly to finish the breakthrough now?';
  }

  @override
  String get evolveAccelTitle => 'Speed up evolution';

  @override
  String evolveAccelConfirm(int jelly, String next) {
    return 'Spend $jelly Jelly to evolve to the next stage ($next) now?';
  }

  @override
  String get forgeExpandTitle => 'Expand anvil';

  @override
  String forgeExpandConfirm(int jelly, int n) {
    return 'Spend $jelly Jelly to add $n anvil slots?';
  }

  @override
  String forgeRerollConfirm(int jelly, String option) {
    return 'Spend $jelly Jelly to reroll \'$option\'?\nGrade and slot stay the same.';
  }

  @override
  String get forgeUpRushTitle => 'Finish workshop upgrade now';

  @override
  String forgeUpRushConfirm(int jelly, String grade) {
    return 'Spend $jelly Jelly to finish the $grade upgrade now?';
  }

  @override
  String exchangeConfirmGold(int jelly, String amount) {
    return 'Spend $jelly Jelly to get $amount gold?';
  }

  @override
  String exchangeConfirmMaterial(int jelly, String amount) {
    return 'Spend $jelly Jelly to get $amount of each of the 3 materials?';
  }

  @override
  String exchangeConfirmDust(int jelly, String amount) {
    return 'Spend $jelly Jelly to get $amount fairy dust?';
  }

  @override
  String zoneFellBack(String tier, String zone) {
    return 'You fell back to $tier · $zone. Defeat the boss again to climb back';
  }

  @override
  String abyssFellBack(int floor) {
    return 'You fell back to Abyss F$floor. Defeat the floor boss to climb back';
  }

  @override
  String get abyssFellOut =>
      'You were pushed out of the Abyss. Defeat the Extreme final boss again to re-enter';

  @override
  String get zoneReclaim => 'Reclaim it';

  @override
  String get guildNameFallback => 'Guild';

  @override
  String get guildErrAlreadyInGuild => 'You\'re already in a guild';

  @override
  String get guildErrNotFound =>
      'Couldn\'t find that guild. It may have been disbanded';

  @override
  String get guildErrNotInGuild => 'You\'re not in a guild';

  @override
  String get guildErrRequestNotFound => 'That request has already been handled';

  @override
  String get guildErrForbidden => 'You don\'t have permission to do that';

  @override
  String get guildErrStoreUnavailable =>
      'Guild features are temporarily unavailable. Please try again shortly';

  @override
  String get guildEmblemPick => 'Guild emblem';

  @override
  String get guildEmblemChange => 'Change emblem';

  @override
  String get guildEmblemChanged => 'Guild emblem changed';

  @override
  String get guildErrEmblemInvalid => 'That emblem can\'t be chosen';

  @override
  String get guildLeaveCoinsNote =>
      'If you leave, your guild coins and contribution will be lost for good.';

  @override
  String get guildKickCoinsNote =>
      'The member\'s guild coins and contribution will be lost for good.';

  @override
  String get guildReport => 'Report guild';

  @override
  String get guildReportBody =>
      'If this guild\'s name or description is inappropriate, let our team know. We\'ll review it and take action.';

  @override
  String get guildReported => 'Reported. Our team will take a look';

  @override
  String get guildDeputyCanAccept => 'Deputies can accept requests';

  @override
  String get guildSwitchOn => 'On';

  @override
  String get guildSwitchOff => 'Off';

  @override
  String get guildRankRookie => 'Rookie';

  @override
  String get guildRankWorker => 'Worker';

  @override
  String get guildRankElite => 'Elite';

  @override
  String get guildRankElder => 'Elder';

  @override
  String guildMyRank(String rank, String points) {
    return 'My rank $rank · Contribution $points';
  }

  @override
  String guildRankNext(String rank, String left) {
    return 'To $rank: $left left';
  }

  @override
  String get guildRankMax => 'Top rank reached';

  @override
  String get guildPermsTitle => 'Role permissions';

  @override
  String get guildPermAccept => 'Accept/decline requests';

  @override
  String get guildPermKick => 'Kick';

  @override
  String get guildPermSettings => 'Notice · intro · join mode';

  @override
  String get guildPermSkills => 'Assign/reset guild skills';

  @override
  String get guildPermRoles => 'Appoint/transfer roles';

  @override
  String guildPermDeputyNote(String state) {
    return 'Deputies can accept requests only if the leader allows it (now: $state).';
  }

  @override
  String get guildPermRanksNote =>
      'Member ranks rise automatically with the coins you earn in this guild (contribution). They are for display only, with no perks or permissions. Leaving the guild resets your contribution.';

  @override
  String get guildRecruitingTitle => 'Recruiting guilds';

  @override
  String get guildSearchResultTitle => 'Search results';

  @override
  String get guildRecruitingEmpty =>
      'No guilds are recruiting right now — why not create your own?';

  @override
  String get guildAttendTitle => 'Attendance card';

  @override
  String guildAttendNote(int cycle) {
    return 'Each day you check in fills one box (missed days don\'t reset it). After all $cycle boxes it starts over from Day 1. Changing guilds starts a new card.';
  }

  @override
  String guildAttendDay(int day) {
    return 'Day $day';
  }

  @override
  String guildAttendProgress(int n, int cycle) {
    return '$n / $cycle';
  }

  @override
  String guildAttendDaily(int coins, int exp) {
    return 'Every day: $coins coins · $exp guild EXP';
  }

  @override
  String get guildAttendBigNote =>
      'Big reward every 7th day (coins · fossils · fairy dust)';

  @override
  String get guildAttendButton => 'Check in today';

  @override
  String get guildAttendDoneToday => 'Checked in today — see you tomorrow';

  @override
  String guildAttendGot(int day) {
    return 'Day $day checked in!';
  }

  @override
  String guildMemberContribution(String n) {
    return 'Contribution $n';
  }

  @override
  String guildMemberLevel(int lv) {
    return 'Character Lv $lv';
  }

  @override
  String get guildMemberPets => 'Equipped bugs';

  @override
  String get guildMemberTeam => 'Duel defense team';

  @override
  String get guildMemberEquip => 'Equipment';

  @override
  String get guildMemberFairy => 'Companion fairy';

  @override
  String get guildMemberSkills => 'Equipped skills';

  @override
  String get guildMemberNone => 'None';

  @override
  String get guildMemberNoSave => 'Couldn\'t load this member\'s details';

  @override
  String get guildMemberFailed => 'Couldn\'t load member info';

  @override
  String get guildMissionOwnerTag => 'Leader';

  @override
  String get guildMissionTeamTitle => 'Members on this mission';

  @override
  String get guildMissionRewardSuccess => 'Success reward';

  @override
  String guildMissionExpShort(int n) {
    return 'Guild EXP $n';
  }

  @override
  String guildMissionEggChance(String pct) {
    return 'Fairy egg $pct%';
  }

  @override
  String guildMissionFailRule(int pct) {
    return 'If it fails: reward × progress × $pct%';
  }

  @override
  String guildMissionHelperRule(int pct, int coins) {
    return 'Helpers: $pct% of materials/fossils (by their own zone) + $coins coins';
  }

  @override
  String guildMissionWaitPick(int min) {
    return 'Wait $min min';
  }

  @override
  String get chatTabAll => 'All';

  @override
  String get chatTabGuild => 'Guild';

  @override
  String get trainSlotHp => 'HP';

  @override
  String get trainSlotPush => 'Push power';

  @override
  String get trainSlotMass => 'Weight class';

  @override
  String get trainSlotTech => 'Specialty skill';

  @override
  String get trainSlotGrit => 'Grit';

  @override
  String get trainWeight => 'Weight';

  @override
  String trainPtShort(String n) {
    return 'Trained $n';
  }

  @override
  String trainPtUsed(String used, String budget) {
    return 'Points $used / $budget';
  }

  @override
  String trainPtBonus(String n) {
    return 'Bonus +$n';
  }

  @override
  String trainPtLeft(String n) {
    return '$n points left';
  }

  @override
  String trainPtFree(String n) {
    return '$n paid points unspent — they apply instantly for free';
  }

  @override
  String get trainPtNext => 'Next point';

  @override
  String get trainPtHowTitle => 'How to earn more points';

  @override
  String trainPtHowLevel(String lv, String k) {
    return 'Reach Lv.$lv → +1 (every $k levels)';
  }

  @override
  String trainPtHowLevelCap(String lv) {
    return 'Reach Lv.$lv → +1 (level cap — breakthrough first)';
  }

  @override
  String trainPtHowBreak(String n, String pts) {
    return 'Breakthrough $n → +$pts';
  }

  @override
  String trainPtHowPotential(String pts) {
    return 'Potential +1★ → +$pts (synthesis · breeding)';
  }

  @override
  String get trainPtNoPoints =>
      'No points left — raise level, breakthrough or potential';

  @override
  String get trainPtMaxed => 'This slot is maxed';

  @override
  String get trainPtRespecBusy => 'Can\'t add points while a respec is pending';

  @override
  String trainPtJobNow(String slot, String n) {
    return 'Training $slot +$n';
  }

  @override
  String trainPtEffect(String per, String now) {
    return '$per per point · now $now';
  }

  @override
  String trainPtPer(String per) {
    return '$per/pt';
  }

  @override
  String trainMassPer(String w, String s) {
    return 'weight $w · speed $s';
  }

  @override
  String trainPushPer(String p) {
    return 'push force $p';
  }

  @override
  String get trainPresetTitle => 'Suggested builds';

  @override
  String get trainPresetBalanced => 'Balanced';

  @override
  String get trainPresetTank => 'Tank';

  @override
  String get trainPresetHeavy => 'Heavyweight';

  @override
  String get trainPresetHint =>
      'Builds that tested strong · ★ suggested for this specialty';

  @override
  String trainPresetNext(String slot) {
    return 'Next suggested slot: $slot';
  }

  @override
  String trainPresetFill(String n) {
    return 'Fill $n spare points';
  }

  @override
  String get trainPresetRespec => 'Respec to this build';

  @override
  String get trainPresetFilled => 'Filled with the suggested build';

  @override
  String get trainPresetApplied =>
      'Suggested build loaded — tap Apply to confirm';

  @override
  String get trainPresetNoRoom => 'All suggested slots are full';

  @override
  String get guideTrainPushNote =>
      'Push power — how hard your bug shoves on contact. It strengthens Strike flips and shoves, Grip bite-and-push, and Toss throws. Unlike Weight class it does not add weight (staying power). Points in the old Speed slot became Push power as-is.';

  @override
  String get guideTrainPresetBody =>
      'The Training Center\'s suggested builds are allocations that tested strong (Balanced · Tank · Heavyweight, ★ = suggested for that bug\'s specialty). Load one at once when respeccing; when adding new points it shows the next suggested slot.';

  @override
  String trainTechFlip(String v) {
    return 'Strike: flip chance $v';
  }

  @override
  String trainTechBite(String v) {
    return 'Grip: bite force $v';
  }

  @override
  String trainTechCooldown(String v) {
    return 'Toss: cooldown $v';
  }

  @override
  String trainGritDesc(String th, String uses, String hp) {
    return 'Tap counter — mash in a crisis to hold on. Threshold $th (lower is easier) · $uses× per bout · wake HP $hp';
  }

  @override
  String trainGritBonusUse(String n) {
    return '+1 use per bout from $n points';
  }

  @override
  String get trainBusyNote =>
      'Bugs training or waiting on a respec can\'t enter duels or the contest';

  @override
  String get trainRespec => 'Respec';

  @override
  String trainRespecHint(String n) {
    return 'Redistribute your $n paid points — no materials needed';
  }

  @override
  String trainRespecEditTitle(String n) {
    return 'New build — $n points left';
  }

  @override
  String get trainRespecApply => 'Apply';

  @override
  String trainRespecAskWait(String time) {
    return 'Switch to the new build. It takes $time, and this bug can\'t battle meanwhile. No materials needed.';
  }

  @override
  String get trainRespecAskFree =>
      'Switch to the new build. Your first respec is free with no wait.';

  @override
  String get trainRespecFreeBadge => 'First one free · no wait';

  @override
  String trainRespecWaitInfo(String time) {
    return 'Wait $time';
  }

  @override
  String trainRespecWaiting(String time) {
    return 'Respec pending · $time';
  }

  @override
  String get trainRespecCancel => 'Cancel wait';

  @override
  String get trainRespecCancelAsk => 'Cancelling keeps your current build';

  @override
  String get trainRespecSame => 'Nothing changed';

  @override
  String get trainRespecDone => 'Build changed';

  @override
  String get trainRespecStarted => 'Respec started';

  @override
  String get trainRespecInstantTitle => 'Finish respec now';

  @override
  String get trainRespecPending => 'New build (applies when the wait ends)';

  @override
  String get trainDuelSummary => 'Duel stats (training · level)';

  @override
  String get trainEditPreview => 'Editing — this is what you\'ll get';

  @override
  String get duelStoneTitle => 'Duel stones';

  @override
  String get duelStoneElement => 'Element stone';

  @override
  String get duelStoneTemperament => 'Temper stone';

  @override
  String duelStoneOwned(String n) {
    return '×$n';
  }

  @override
  String get duelStoneChangeElement => 'Change element';

  @override
  String get duelStoneChangeTemperament => 'Change temper';

  @override
  String get duelStoneHint =>
      'Set element or temper to any value (bloodline trait stays). Changes are inherited by offspring.';

  @override
  String get duelStonePickElement => 'Pick a new element';

  @override
  String get duelStonePickTemperament => 'Pick a new temper';

  @override
  String duelStoneAsk(String from, String to, String stone) {
    return 'Change $from → $to? Uses 1 $stone.';
  }

  @override
  String duelStoneBuyTitle(String stone) {
    return 'Buy $stone';
  }

  @override
  String duelStoneBuyBody(String stone, String n) {
    return 'You have no $stone. Buy one for $n jelly?';
  }

  @override
  String get duelStoneBuyAction => 'Buy';

  @override
  String get duelStoneDone => 'Changed!';

  @override
  String duelStonePop(String stone, String n) {
    return '$stone +$n';
  }

  @override
  String trainPtSummaryLine(String used, String budget) {
    return 'Training points $used / $budget';
  }

  @override
  String get trainGoCenter => 'Train at the center';

  @override
  String get duelClutchHold => 'Hold on!';

  @override
  String get duelClutchWake => 'Get up!';

  @override
  String get duelClutchTapHint => 'Tap the screen like crazy!';

  @override
  String get duelClutchCrisis => 'Crisis!';

  @override
  String get duelClutchTutorial => 'Tap rapidly to pass the white line';

  @override
  String get duelClutchTapToStart => 'Tap to start!';

  @override
  String get duelClutchSuccessMark => 'Success';

  @override
  String duelClutchChance(int k, int n) {
    return 'Chance $k/$n';
  }

  @override
  String get duelClutchSaved => 'Held on!';

  @override
  String get duelClutchWoke => 'Back up!';

  @override
  String get duelClutchFailed => 'Failed…';

  @override
  String duelClutchLeft(int n) {
    return 'Clutch $n';
  }

  @override
  String duelClutchPower(String p) {
    return 'Tap power ×$p';
  }

  @override
  String trainGritPower(String p) {
    return 'tap power ×$p';
  }

  @override
  String guideTrainGritPower(String p) {
    return 'tap power +$p';
  }

  @override
  String get guideTrainSlotsTitle => 'Slots (per point · base cap)';

  @override
  String guideTrainSlotLine(String slot, String effect, String cap) {
    return '$slot — $effect · cap $cap';
  }

  @override
  String guideTrainGritEffect(String th, String hp) {
    return 'tap counter threshold −$th · wake HP +$hp';
  }

  @override
  String get guideTrainCostBody =>
      'Materials (chitin, mineral, sap) and training time are paid only the first time you spend a point, rising a little each time. Jelly can skip the wait; a bug in training can\'t enter duels or the contest.';

  @override
  String guideTrainRespecBody(String base, String per, String max) {
    return 'Respec — redistribute your paid points. No materials are needed, but you wait $base min + $per min per point (up to $max h) and the bug can\'t fight meanwhile. Jelly can skip the wait.';
  }

  @override
  String guideTrainStoneBody(String el, String tm) {
    return 'Duel stones — an Element stone sets a bug\'s element and a Temper stone its temperament to the value you choose (bloodline trait stays; the new value is inherited by offspring). Get them from elites, bosses and the Abyss, or buy with jelly (Element $el · Temper $tm).';
  }

  @override
  String get guideTrainLegacyNote =>
      'Old part enhancements and training stages were converted into training points with the same effect — no bug got weaker.';

  @override
  String get guideClutchTitle => 'Tap counter (grit)';

  @override
  String guideClutchBody(
    String sec,
    String th,
    String cost,
    String hp,
    String uses,
    String bonus,
  ) {
    return 'When your bug is about to lose (pushed out of the ring · flipped · HP hits 0), the bout pauses and a gauge appears. Mash the screen for ${sec}s — if your score reaches the threshold $th, you survive: holding on costs $cost of max HP and pulls you back inside, waking up gets you back on your feet with $hp HP. $uses× per bout (+1 from $bonus Grit). More points in Grit make each tap stronger, lower the threshold and raise wake HP. Opponent bugs counter automatically.';
  }

  @override
  String get upgradeBuyMax => 'MAX';

  @override
  String skillGachaConfirm(String times, String jelly) {
    return 'Skill draw ×$times — this spends $jelly jelly.';
  }

  @override
  String skillSweepConfirm(String jelly) {
    return 'Today\'s free sweeps are used up. Sweep for $jelly jelly?';
  }
}
