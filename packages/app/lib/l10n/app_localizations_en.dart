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
    return '💎$n Heal now';
  }

  @override
  String get notEnoughJelly => 'Not enough jelly';

  @override
  String get scoutBoard => 'Scout Board';

  @override
  String get scoutRefresh => 'Refresh';

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
    return 'Peak rank: $name';
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
      'Place 2+ bugs so a front slot generates the next (order matters)';

  @override
  String get teamReorderHint => 'Drag to reorder';

  @override
  String get leagueSeasonTitle => 'League · Season';

  @override
  String get modeManual => 'Manual';

  @override
  String get modeAuto => 'Auto';

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
      'Confirming payment. It\'ll be granted automatically once it completes';

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
  String get curGold => 'Gold';

  @override
  String get rewardGained => 'Rewards';

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
    return '+$n 💎$jelly';
  }

  @override
  String get dexTitle => 'Bug Dex';

  @override
  String get dexDiscovered => 'Found';

  @override
  String get dexConquered => 'Raised';

  @override
  String get dexConqueredYes => 'Done';

  @override
  String get dexConqueredNo => 'Not yet';

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
    return 'Dex reward! 💰$gold · 💎$jelly';
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
    return 'Wave $n cleared! Choose one';
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
  String get cardReviveDesc => 'Revive one fallen bug at half HP';

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
  String get eventFlyerHow1 => 'Pick 3 adult bugs and enter';

  @override
  String get eventFlyerHow2 => 'Choose one boost card after each wave';

  @override
  String get eventFlyerHow3 => 'The further you get, the higher you rank';

  @override
  String get eventFlyerRules => 'Good to know';

  @override
  String get eventFlyerRule1 =>
      'Stats are **equalized** — only species, element and temperament count; training, enhancement and size do not apply';

  @override
  String get eventFlyerRule2 =>
      'Enemy elements rotate every wave — a single-element team will hit a wall';

  @override
  String get eventFlyerRule3 =>
      'Bugs that entered rest for a day — keeping several good bugs pays off';

  @override
  String get eventFlyerRule4 =>
      'Tickets refill each morning, plus up to 2 more per day from ads';

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
  String eventWaveRecord(Object n) {
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
  String get eventPickTeam => 'Pick 3 bugs to enter';

  @override
  String get eventPickOrder =>
      'They fight left to right — a bug generating the next one grants synergy';

  @override
  String get eventNormalizeTitle => 'Stats are equalized in this event';

  @override
  String get eventNormalizeBody =>
      'Only species, element, temperament and specialty count. Training, breakthrough, part enhancement, potential and size do not apply — everyone competes on formation alone.';

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
  String get eventAdTicket => 'Watch an ad for a ticket';

  @override
  String get eventAdLimit => 'You\'ve claimed every ad reward today';

  @override
  String get eventTicketFull => 'Tickets are full';

  @override
  String eventResultTitle(Object n) {
    return 'Reached wave $n!';
  }

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
  String get giftClaimAd => 'Ad ×2';

  @override
  String giftExpiresIn(String time) {
    return 'expires in $time';
  }

  @override
  String get giftClaimedSnack => 'Gift claimed!';

  @override
  String get giftDoubledSnack => 'Ad reward ×2!';

  @override
  String get giftAdMoreTitle => 'Watch an ad for one more?';

  @override
  String get giftAdMoreBody => 'Watch an ad to get the same reward once more';

  @override
  String get giftAdMoreYes => 'Watch ad';

  @override
  String get giftAdMoreLater => 'No thanks';

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
    return '💎$n';
  }

  @override
  String trainJellySnack(int lv) {
    return 'Instant train! Level +$lv';
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
    return 'Now 💎$n';
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
    return 'Expand 💎$n';
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
  String get incubatorPick => 'Choose an egg';

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

  @override
  String get materialFossil => 'Fossil Shard';

  @override
  String get materialFossilDesc =>
      'A shard of petrified insect. One is spent per hammer strike at the workshop.';

  @override
  String get netLostTitle => 'Connection lost';

  @override
  String get netLostBody =>
      'Check your internet connection.\nProgress is only saved while connected.';

  @override
  String get netRetry => 'Retry';

  @override
  String get netToTitle => 'Back to title';

  @override
  String get netStillDown => 'Still not connected';

  @override
  String get materialsHint =>
      'Materials — used for upgrades, part enhancement & crafting (tap for details)';

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
  String get rankPopupTitle => 'Your Ranking';

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
  String get titleStoreName => 'Bug Champ';

  @override
  String get titleStoreTagline => 'Idle Insect RPG';

  @override
  String nicknameChangeCostHint(int cost) {
    return 'Costs 💎$cost to change';
  }

  @override
  String incubatorAdSkip(int pct) {
    return '📺 Watch ad: -$pct%';
  }

  @override
  String get incubatorAdSkipDone => 'Hatching time reduced!';

  @override
  String get nicknameEditAction => 'Change nickname';

  @override
  String nicknameEditActionCost(int cost) {
    return 'Change 💎$cost';
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
  String get incubatorAdSkipBtn => 'Watch ad to speed up';

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
  String get pvpTicketFullLabel => 'Full';

  @override
  String get pvpTicketNone =>
      'You need a duel ticket to fight. Charge one below.';

  @override
  String pvpTicketAdBtn(int amount) {
    return 'Watch ad +$amount';
  }

  @override
  String pvpTicketAdLeft(int used, int limit) {
    return '$used/$limit today';
  }

  @override
  String pvpTicketJellyBtn(int cost) {
    return 'Fill up 💎$cost';
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
    return 'You\'ve watched all of today\'s ads ($limit/day)';
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
  String get forgeResultDrop => 'Discard';

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
  String get forgeRush => 'Finish now';

  @override
  String get forgeClaim => 'Claim';

  @override
  String get forgeNext => 'Next level odds';

  @override
  String get forgeMaxLevel => 'Max level';

  @override
  String get forgeAutoTarget => 'Wanted options';

  @override
  String get forgeStopOnHit => 'Stop when found';

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
  String get forgeFiltered => 'Discarded — no matching stat';
}
