// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'バグチャンプ';

  @override
  String get navHome => 'ホーム';

  @override
  String get navCollect => '採集';

  @override
  String get navStorage => 'コレクション';

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
      'You\'re on a temporary device account, so deleting the app also loses the backup. Google sign-in is coming soon.';

  @override
  String get tabCraft => 'Craft';

  @override
  String get tabStore => 'Store';

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
  String settingsBuildLabel(String label) {
    return 'Build $label';
  }

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
  String get homeTitle => 'トラップ状況';

  @override
  String get homeMaterialsTitle => '素材';

  @override
  String slotLabel(int index) {
    return 'スロット $index';
  }

  @override
  String get slotEmpty => '空き';

  @override
  String get slotInstallCta => 'トラップを設置';

  @override
  String elapsedLabel(String duration) {
    return '経過 $duration / 最大8時間';
  }

  @override
  String get collectButton => '回収';

  @override
  String collectResultSnack(int materialCount, int bugCount) {
    return '素材 $materialCount個、昆虫 $bugCount匹 獲得!';
  }

  @override
  String get collectNothingSnack => 'まだ回収できるものがありません';

  @override
  String get homeYard => 'わたしの採集場';

  @override
  String get collecting => '採集中';

  @override
  String get readyLabel => '回収可能';

  @override
  String get collectAll => 'すべて回収';

  @override
  String get comingSoon => '準備中です';

  @override
  String offlineBanner(int materialCount, int bugCount) {
    return 'おかえり!素材 $materialCount・昆虫 $bugCount 待機中';
  }

  @override
  String chapterTitle(int n) {
    return '第$n章';
  }

  @override
  String chapterRemaining(int count) {
    return '次の章まであと昆虫 $count匹';
  }

  @override
  String get statusForaging => '採集中…';

  @override
  String get statusIdle => 'トラップを設置すると採集を始めます';

  @override
  String get navUpgrade => '強化';

  @override
  String get navShop => 'ショップ';

  @override
  String get upgradeTitle => '能力強化';

  @override
  String get retreat => '撤退!';

  @override
  String offlineReward(String gold, String xp) {
    return 'おかえり!💰$gold・🔷$xp 獲得';
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
  String get upAttack => '採集力';

  @override
  String get upAttackSpeed => '手さばき';

  @override
  String get upCrit => '急所狙い';

  @override
  String get upCritDamage => '強打';

  @override
  String get upBossDamage => '闘志';

  @override
  String get upMaxHp => '根性';

  @override
  String get upDefense => '打たれ強さ';

  @override
  String get upRegen => '回復力';

  @override
  String get upReward => '商才';

  @override
  String get upXp => '採集知識';

  @override
  String get upBugFind => '虫の勘';

  @override
  String get upMaterialFind => '丁寧な採取';

  @override
  String get upMoveSpeed => '足取り';

  @override
  String get upBoost => '集中力';

  @override
  String get upBugBuff => '図鑑の達人';

  @override
  String get statAttack => '攻撃力';

  @override
  String get statAttackSpeed => '攻撃速度';

  @override
  String get statReward => 'ゴールド倍率';

  @override
  String get notEnoughGold => 'ゴールドが足りません';

  @override
  String get curGold => 'Gold';

  @override
  String get rewardGained => 'Rewards';

  @override
  String get bossLabel => 'ボス';

  @override
  String get tapBoostHint => 'タップでブースト!';

  @override
  String levelBadge(int n) {
    return 'Lv $n';
  }

  @override
  String get collectTitle => '採集フィールド';

  @override
  String get collectPickTrap => 'トラップ選択';

  @override
  String get collectPickSlot => 'スロット選択';

  @override
  String collectInstalledSnack(String field, String trap) {
    return '$fieldに$trapを設置しました';
  }

  @override
  String get locked => 'ロック';

  @override
  String get install => '設置';

  @override
  String get storageTitle => 'コレクション';

  @override
  String get storageEmpty => 'まだ昆虫がいません。\n採集で集めましょう!';

  @override
  String storageCount(int count) {
    return '$count匹';
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
  String get gradeCommon => '一般';

  @override
  String get gradeUncommon => '上級';

  @override
  String get gradeRare => 'レア';

  @override
  String get gradeEpic => '英雄';

  @override
  String get gradeLegendary => '伝説';

  @override
  String get specialtyStrike => '打撃';

  @override
  String get specialtyGrip => 'はさみ';

  @override
  String get specialtyToss => '投げ';

  @override
  String get temperamentAggressive => '好戦的';

  @override
  String get temperamentCautious => '慎重';

  @override
  String get temperamentCunning => '狡猾';

  @override
  String get temperamentSteadfast => '実直';

  @override
  String get temperamentFickle => '気まぐれ';

  @override
  String get sexMale => 'オス';

  @override
  String get sexFemale => 'メス';

  @override
  String get materialChitin => 'キチン片';

  @override
  String get materialMineral => 'ミネラル';

  @override
  String get materialSap => '樹液結晶';

  @override
  String get materialJelly => '昆虫ゼリー';

  @override
  String get combatPowerLabel => '戦闘力';

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
  String get rankingTitle => 'ランキング';

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
  String get mailTitle => 'メールボックス';

  @override
  String get mailEmpty => '新しいメールはありません';

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
  String get settingsTitle => '設定';

  @override
  String get settingsNickname => 'ニックネーム';

  @override
  String get settingsNicknameHint => '名前を入力してください';

  @override
  String get actionSave => '保存';

  @override
  String get actionCancel => 'キャンセル';

  @override
  String get actionClose => '閉じる';

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
  String get questHunt => 'モンスター狩り';

  @override
  String get buffTitle => 'バフ';

  @override
  String get buffSheetTitle => 'バフを発動';

  @override
  String get buffWatchAd => '広告を見る';

  @override
  String buffMinutes(int minutes) {
    return '$minutes分';
  }

  @override
  String buffActivatedSnack(String buff, int minutes) {
    return '$buff 発動！（$minutes分）';
  }

  @override
  String get buffGoldRush => 'ゴールドラッシュ';

  @override
  String get buffGoldRushDesc => 'ゴールド獲得 ×2';

  @override
  String get buffXpBoost => '成長加速';

  @override
  String get buffXpBoostDesc => '経験値 ×2';

  @override
  String get buffFrenzy => '狂乱';

  @override
  String get buffFrenzyDesc => '攻撃力・攻撃速度アップ';

  @override
  String get buffGatherer => '採集の手';

  @override
  String get buffGathererDesc => '素材獲得 ×2';

  @override
  String get buffLuckyWind => '幸運の風';

  @override
  String get buffLuckyWindDesc => '虫の発見率 ×2';

  @override
  String get enhanceTitle => '部位強化';

  @override
  String get partHornJaw => '角・大顎';

  @override
  String get partCuticle => '表皮';

  @override
  String get partWing => '翅';

  @override
  String get partBuild => '体格';

  @override
  String get enhanceAction => '強化';

  @override
  String get enhanceMaxed => '最大';

  @override
  String enhanceCap(int cur, int max) {
    return '強化 $cur/$max';
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
  String get craftTitle => '製作';

  @override
  String get craftMake => '製作';

  @override
  String craftPotion(String buff) {
    return '$buffの薬';
  }

  @override
  String get craftAllPotion => 'オールインワン薬';

  @override
  String craftedSnack(String name) {
    return '$name を製作！';
  }

  @override
  String get missionsTitle => 'ミッション';

  @override
  String get missionKillMonsters => 'モンスター狩り';

  @override
  String get missionKillBosses => 'ボス討伐';

  @override
  String get missionBuyUpgrades => '能力強化';

  @override
  String get missionReachStage => 'ステージ到達';

  @override
  String get missionClaim => '受取';

  @override
  String get missionComplete => 'Complete! Tap to claim';

  @override
  String get missionClaimedSnack => 'ミッション報酬を獲得！';

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
