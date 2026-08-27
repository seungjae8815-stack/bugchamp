import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
    Locale('ko'),
  ];

  /// Application title
  ///
  /// In en, this message translates to:
  /// **'Bug Champ'**
  String get appTitle;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navCollect.
  ///
  /// In en, this message translates to:
  /// **'Collect'**
  String get navCollect;

  /// No description provided for @navStorage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get navStorage;

  /// No description provided for @navBattle.
  ///
  /// In en, this message translates to:
  /// **'Battle'**
  String get navBattle;

  /// No description provided for @battleTitle.
  ///
  /// In en, this message translates to:
  /// **'Bug Duel'**
  String get battleTitle;

  /// No description provided for @battleTrophies.
  ///
  /// In en, this message translates to:
  /// **'Trophies {n}'**
  String battleTrophies(int n);

  /// No description provided for @battleMyTeam.
  ///
  /// In en, this message translates to:
  /// **'My Team (3)'**
  String get battleMyTeam;

  /// No description provided for @autoBattleRunning.
  ///
  /// In en, this message translates to:
  /// **'Auto battle in progress'**
  String get autoBattleRunning;

  /// No description provided for @battleStart.
  ///
  /// In en, this message translates to:
  /// **'Start Battle'**
  String get battleStart;

  /// No description provided for @battleNeedBugs.
  ///
  /// In en, this message translates to:
  /// **'You need adult bugs to duel'**
  String get battleNeedBugs;

  /// No description provided for @battlePickTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a bug (adult)'**
  String get battlePickTitle;

  /// No description provided for @battleEmptySlot.
  ///
  /// In en, this message translates to:
  /// **'Empty'**
  String get battleEmptySlot;

  /// No description provided for @battleWin.
  ///
  /// In en, this message translates to:
  /// **'Victory!'**
  String get battleWin;

  /// No description provided for @battleLose.
  ///
  /// In en, this message translates to:
  /// **'Defeat…'**
  String get battleLose;

  /// No description provided for @battleDraw.
  ///
  /// In en, this message translates to:
  /// **'Draw'**
  String get battleDraw;

  /// No description provided for @battleReward.
  ///
  /// In en, this message translates to:
  /// **'Reward'**
  String get battleReward;

  /// No description provided for @battleVs.
  ///
  /// In en, this message translates to:
  /// **'VS'**
  String get battleVs;

  /// No description provided for @battleRestrain.
  ///
  /// In en, this message translates to:
  /// **'Super effective!'**
  String get battleRestrain;

  /// No description provided for @battleFoe.
  ///
  /// In en, this message translates to:
  /// **'Opponent'**
  String get battleFoe;

  /// No description provided for @battleLog.
  ///
  /// In en, this message translates to:
  /// **'Battle log'**
  String get battleLog;

  /// No description provided for @battleAgain.
  ///
  /// In en, this message translates to:
  /// **'Duel again'**
  String get battleAgain;

  /// No description provided for @battleTeamEmpty.
  ///
  /// In en, this message translates to:
  /// **'Add bugs to your team'**
  String get battleTeamEmpty;

  /// No description provided for @battleSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get battleSkip;

  /// No description provided for @battleHpPct.
  ///
  /// In en, this message translates to:
  /// **'HP {v}%'**
  String battleHpPct(String v);

  /// No description provided for @battleAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto Battle'**
  String get battleAuto;

  /// No description provided for @battleManual.
  ///
  /// In en, this message translates to:
  /// **'Manual Battle'**
  String get battleManual;

  /// No description provided for @battleManualDesc.
  ///
  /// In en, this message translates to:
  /// **'Mind games — pick every move'**
  String get battleManualDesc;

  /// No description provided for @battleYourMove.
  ///
  /// In en, this message translates to:
  /// **'Choose your move'**
  String get battleYourMove;

  /// No description provided for @battleEnergy.
  ///
  /// In en, this message translates to:
  /// **'Energy'**
  String get battleEnergy;

  /// No description provided for @battleClashWin.
  ///
  /// In en, this message translates to:
  /// **'You read them!'**
  String get battleClashWin;

  /// No description provided for @battleClashLose.
  ///
  /// In en, this message translates to:
  /// **'Caught off guard'**
  String get battleClashLose;

  /// No description provided for @battleClashEven.
  ///
  /// In en, this message translates to:
  /// **'Feeling it out'**
  String get battleClashEven;

  /// No description provided for @injuryTitle.
  ///
  /// In en, this message translates to:
  /// **'Recovering'**
  String get injuryTitle;

  /// No description provided for @injuryDesc.
  ///
  /// In en, this message translates to:
  /// **'Can\'t be fielded in a duel until healed'**
  String get injuryDesc;

  /// No description provided for @injuryHealJelly.
  ///
  /// In en, this message translates to:
  /// **'Heal now for {n} jelly'**
  String injuryHealJelly(int n);

  /// No description provided for @notEnoughJelly.
  ///
  /// In en, this message translates to:
  /// **'Not enough jelly'**
  String get notEnoughJelly;

  /// No description provided for @scoutBoard.
  ///
  /// In en, this message translates to:
  /// **'Scout Board'**
  String get scoutBoard;

  /// No description provided for @scoutRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get scoutRefresh;

  /// No description provided for @scoutEasy.
  ///
  /// In en, this message translates to:
  /// **'Weak'**
  String get scoutEasy;

  /// No description provided for @scoutEven.
  ///
  /// In en, this message translates to:
  /// **'Even'**
  String get scoutEven;

  /// No description provided for @scoutHard.
  ///
  /// In en, this message translates to:
  /// **'Strong'**
  String get scoutHard;

  /// No description provided for @leagueBronze.
  ///
  /// In en, this message translates to:
  /// **'Bronze'**
  String get leagueBronze;

  /// No description provided for @leagueSilver.
  ///
  /// In en, this message translates to:
  /// **'Silver'**
  String get leagueSilver;

  /// No description provided for @leagueGold.
  ///
  /// In en, this message translates to:
  /// **'Gold'**
  String get leagueGold;

  /// No description provided for @leaguePlatinum.
  ///
  /// In en, this message translates to:
  /// **'Platinum'**
  String get leaguePlatinum;

  /// No description provided for @leagueDiamond.
  ///
  /// In en, this message translates to:
  /// **'Diamond'**
  String get leagueDiamond;

  /// No description provided for @leagueToNext.
  ///
  /// In en, this message translates to:
  /// **'{n}🏆 to {name}'**
  String leagueToNext(int n, String name);

  /// No description provided for @leagueMaxRank.
  ///
  /// In en, this message translates to:
  /// **'Top rank'**
  String get leagueMaxRank;

  /// No description provided for @leagueClaimReward.
  ///
  /// In en, this message translates to:
  /// **'Claim promotion'**
  String get leagueClaimReward;

  /// No description provided for @leaguePromoTitle.
  ///
  /// In en, this message translates to:
  /// **'Promotion Reward'**
  String get leaguePromoTitle;

  /// No description provided for @seasonEndTitle.
  ///
  /// In en, this message translates to:
  /// **'Season Over!'**
  String get seasonEndTitle;

  /// No description provided for @seasonPeak.
  ///
  /// In en, this message translates to:
  /// **'Rank at close: {name}'**
  String seasonPeak(String name);

  /// No description provided for @seasonTrophyReset.
  ///
  /// In en, this message translates to:
  /// **'Trophies {from} → {to}'**
  String seasonTrophyReset(int from, int to);

  /// No description provided for @seasonEndsIn.
  ///
  /// In en, this message translates to:
  /// **'Season {time} left'**
  String seasonEndsIn(String time);

  /// No description provided for @synergyLabel.
  ///
  /// In en, this message translates to:
  /// **'Synergy'**
  String get synergyLabel;

  /// No description provided for @synergyHint.
  ///
  /// In en, this message translates to:
  /// **'Place 2+ bugs · when a bug powers up the one behind it your team gets stronger (order matters)'**
  String get synergyHint;

  /// No description provided for @teamReorderHint.
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder'**
  String get teamReorderHint;

  /// No description provided for @leagueSeasonTitle.
  ///
  /// In en, this message translates to:
  /// **'League · Season'**
  String get leagueSeasonTitle;

  /// No description provided for @modeManual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get modeManual;

  /// No description provided for @modeAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get modeAuto;

  /// No description provided for @opponentWild.
  ///
  /// In en, this message translates to:
  /// **'Wild'**
  String get opponentWild;

  /// No description provided for @opponentPick.
  ///
  /// In en, this message translates to:
  /// **'Pick Opponent'**
  String get opponentPick;

  /// No description provided for @accountTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountTitle;

  /// No description provided for @accountAnonymous.
  ///
  /// In en, this message translates to:
  /// **'You\'re on a temporary device account'**
  String get accountAnonymous;

  /// No description provided for @accountSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {email}'**
  String accountSignedIn(String email);

  /// No description provided for @accountSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get accountSignIn;

  /// No description provided for @accountDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get accountDelete;

  /// No description provided for @accountDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get accountDeleteTitle;

  /// No description provided for @accountDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'All bugs, currency, trophies and breeding records will be gone for good.\n\nType «{word}» below to confirm.'**
  String accountDeleteBody(String word);

  /// No description provided for @accountDeleteWord.
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get accountDeleteWord;

  /// No description provided for @accountDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete permanently'**
  String get accountDeleteConfirm;

  /// No description provided for @accountDeleteDone.
  ///
  /// In en, this message translates to:
  /// **'Your account and data were deleted'**
  String get accountDeleteDone;

  /// No description provided for @accountDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete. Please try again shortly'**
  String get accountDeleteFailed;

  /// No description provided for @accountDeleteOffline.
  ///
  /// In en, this message translates to:
  /// **'Can\'t delete without an online connection'**
  String get accountDeleteOffline;

  /// No description provided for @accountDeleteWarnPurchase.
  ///
  /// In en, this message translates to:
  /// **'Purchases are not refunded and cannot be restored afterwards.'**
  String get accountDeleteWarnPurchase;

  /// No description provided for @accountSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get accountSignOut;

  /// No description provided for @accountSignedOut.
  ///
  /// In en, this message translates to:
  /// **'Signed out'**
  String get accountSignedOut;

  /// No description provided for @accountSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed'**
  String get accountSignInFailed;

  /// No description provided for @accountWhy.
  ///
  /// In en, this message translates to:
  /// **'Sign in to keep your progress when you change phones.'**
  String get accountWhy;

  /// No description provided for @accountUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Sign-in isn\'t available in this build'**
  String get accountUnavailable;

  /// No description provided for @accountAnonRisk.
  ///
  /// In en, this message translates to:
  /// **'Without signing in, your progress can\'t be recovered if you switch devices or delete the app.'**
  String get accountAnonRisk;

  /// No description provided for @loginNudge.
  ///
  /// In en, this message translates to:
  /// **'Guest account · tap to sign in and protect your data'**
  String get loginNudge;

  /// No description provided for @accountSyncTitle.
  ///
  /// In en, this message translates to:
  /// **'Which progress do you want?'**
  String get accountSyncTitle;

  /// No description provided for @accountSyncBody.
  ///
  /// In en, this message translates to:
  /// **'This account already has saved progress. Choose which one to keep.'**
  String get accountSyncBody;

  /// No description provided for @accountKeepDevice.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get accountKeepDevice;

  /// No description provided for @accountUseCloud.
  ///
  /// In en, this message translates to:
  /// **'Load saved'**
  String get accountUseCloud;

  /// No description provided for @cloudTitle.
  ///
  /// In en, this message translates to:
  /// **'Cloud Backup'**
  String get cloudTitle;

  /// No description provided for @cloudBackup.
  ///
  /// In en, this message translates to:
  /// **'Back up'**
  String get cloudBackup;

  /// No description provided for @cloudRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get cloudRestore;

  /// No description provided for @cloudBackupDone.
  ///
  /// In en, this message translates to:
  /// **'Backed up to the cloud'**
  String get cloudBackupDone;

  /// No description provided for @cloudRestoreDone.
  ///
  /// In en, this message translates to:
  /// **'Restored from backup'**
  String get cloudRestoreDone;

  /// No description provided for @cloudRestoreConfirm.
  ///
  /// In en, this message translates to:
  /// **'This overwrites your current progress with the backup. It cannot be undone.'**
  String get cloudRestoreConfirm;

  /// No description provided for @cloudFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed. Please try again in a moment'**
  String get cloudFailed;

  /// No description provided for @cloudNoBackup.
  ///
  /// In en, this message translates to:
  /// **'No backup yet'**
  String get cloudNoBackup;

  /// No description provided for @cloudLastBackup.
  ///
  /// In en, this message translates to:
  /// **'Last backup: {when}'**
  String cloudLastBackup(String when);

  /// No description provided for @cloudUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Backup unavailable — no online connection'**
  String get cloudUnavailable;

  /// No description provided for @cloudAnonWarning.
  ///
  /// In en, this message translates to:
  /// **'You\'re on a temporary device account, so deleting the app also loses the backup. Sign in to keep your progress across devices.'**
  String get cloudAnonWarning;

  /// No description provided for @tabCraft.
  ///
  /// In en, this message translates to:
  /// **'Craft'**
  String get tabCraft;

  /// No description provided for @tabStore.
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get tabStore;

  /// No description provided for @adNotReady.
  ///
  /// In en, this message translates to:
  /// **'No ad is ready right now. Please try again in a moment'**
  String get adNotReady;

  /// No description provided for @adDismissed.
  ///
  /// In en, this message translates to:
  /// **'Watch the full ad to get the reward'**
  String get adDismissed;

  /// No description provided for @adFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the ad'**
  String get adFailed;

  /// No description provided for @adLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading ad…'**
  String get adLoading;

  /// No description provided for @storeOwned.
  ///
  /// In en, this message translates to:
  /// **'Owned'**
  String get storeOwned;

  /// No description provided for @storeRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get storeRestore;

  /// No description provided for @storeRestoreDone.
  ///
  /// In en, this message translates to:
  /// **'Purchases restored'**
  String get storeRestoreDone;

  /// No description provided for @storeBought.
  ///
  /// In en, this message translates to:
  /// **'{name} purchased!'**
  String storeBought(String name);

  /// No description provided for @storeFailed.
  ///
  /// In en, this message translates to:
  /// **'Purchase failed'**
  String get storeFailed;

  /// No description provided for @storeCanceled.
  ///
  /// In en, this message translates to:
  /// **'Purchase canceled'**
  String get storeCanceled;

  /// No description provided for @storePending.
  ///
  /// In en, this message translates to:
  /// **'Confirming payment. It\'ll be granted automatically once it completes'**
  String get storePending;

  /// No description provided for @storeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'In-app purchases aren\'t available on this device'**
  String get storeUnavailable;

  /// No description provided for @storeNotRegistered.
  ///
  /// In en, this message translates to:
  /// **'This item isn\'t on sale yet'**
  String get storeNotRegistered;

  /// No description provided for @storeDevMode.
  ///
  /// In en, this message translates to:
  /// **'Dev mode — no real payment; items are granted immediately'**
  String get storeDevMode;

  /// No description provided for @storePassLeft.
  ///
  /// In en, this message translates to:
  /// **'{days} days left'**
  String storePassLeft(int days);

  /// No description provided for @biomeForest.
  ///
  /// In en, this message translates to:
  /// **'Forest'**
  String get biomeForest;

  /// No description provided for @biomeVolcano.
  ///
  /// In en, this message translates to:
  /// **'Lava Cave'**
  String get biomeVolcano;

  /// No description provided for @biomeBadlands.
  ///
  /// In en, this message translates to:
  /// **'Badlands'**
  String get biomeBadlands;

  /// No description provided for @biomeCity.
  ///
  /// In en, this message translates to:
  /// **'Ruined City'**
  String get biomeCity;

  /// No description provided for @biomeDeep.
  ///
  /// In en, this message translates to:
  /// **'Deep Sea'**
  String get biomeDeep;

  /// No description provided for @locationAffinity.
  ///
  /// In en, this message translates to:
  /// **'{element} bugs boosted'**
  String locationAffinity(String element);

  /// No description provided for @breedingTitle.
  ///
  /// In en, this message translates to:
  /// **'Breeding'**
  String get breedingTitle;

  /// No description provided for @breedingSlotsLabel.
  ///
  /// In en, this message translates to:
  /// **'{used}/{cap}'**
  String breedingSlotsLabel(int used, int cap);

  /// No description provided for @breedingNew.
  ///
  /// In en, this message translates to:
  /// **'New breeding'**
  String get breedingNew;

  /// No description provided for @breedingPickMother.
  ///
  /// In en, this message translates to:
  /// **'Pick mother (♀ adult)'**
  String get breedingPickMother;

  /// No description provided for @breedingPickFather.
  ///
  /// In en, this message translates to:
  /// **'Pick father (♂ · same species)'**
  String get breedingPickFather;

  /// No description provided for @breedingNoFemales.
  ///
  /// In en, this message translates to:
  /// **'No breedable ♀ adults'**
  String get breedingNoFemales;

  /// No description provided for @breedingNoMate.
  ///
  /// In en, this message translates to:
  /// **'No same-species ♂ adult'**
  String get breedingNoMate;

  /// No description provided for @breedingInProgress.
  ///
  /// In en, this message translates to:
  /// **'Breeding'**
  String get breedingInProgress;

  /// No description provided for @breedCooldownLeft.
  ///
  /// In en, this message translates to:
  /// **'Ready in {time}'**
  String breedCooldownLeft(Object time);

  /// No description provided for @breedingGotEgg.
  ///
  /// In en, this message translates to:
  /// **'Got an egg! Raise it in the incubator'**
  String get breedingGotEgg;

  /// No description provided for @leaderboardLocalNote.
  ///
  /// In en, this message translates to:
  /// **'Local ranking · online sync coming'**
  String get leaderboardLocalNote;

  /// No description provided for @leaderboardOnlineNote.
  ///
  /// In en, this message translates to:
  /// **'Online ranking · live'**
  String get leaderboardOnlineNote;

  /// No description provided for @backendOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get backendOnline;

  /// No description provided for @backendLocal.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get backendLocal;

  /// No description provided for @backendServer.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get backendServer;

  /// No description provided for @settingsBuildLabel.
  ///
  /// In en, this message translates to:
  /// **'Build {label}'**
  String settingsBuildLabel(String label);

  /// No description provided for @rankKindTrophies.
  ///
  /// In en, this message translates to:
  /// **'Trophies'**
  String get rankKindTrophies;

  /// No description provided for @rankKindLevel.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get rankKindLevel;

  /// No description provided for @rankKindStage.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get rankKindStage;

  /// No description provided for @leaderboardMyRank.
  ///
  /// In en, this message translates to:
  /// **'My rank #{n}'**
  String leaderboardMyRank(int n);

  /// No description provided for @stanceAttack.
  ///
  /// In en, this message translates to:
  /// **'Attack'**
  String get stanceAttack;

  /// No description provided for @stanceDefend.
  ///
  /// In en, this message translates to:
  /// **'Defend'**
  String get stanceDefend;

  /// No description provided for @stanceHeal.
  ///
  /// In en, this message translates to:
  /// **'Heal'**
  String get stanceHeal;

  /// No description provided for @elementFire.
  ///
  /// In en, this message translates to:
  /// **'Fire'**
  String get elementFire;

  /// No description provided for @elementWater.
  ///
  /// In en, this message translates to:
  /// **'Water'**
  String get elementWater;

  /// No description provided for @elementWood.
  ///
  /// In en, this message translates to:
  /// **'Wood'**
  String get elementWood;

  /// No description provided for @elementMetal.
  ///
  /// In en, this message translates to:
  /// **'Metal'**
  String get elementMetal;

  /// No description provided for @elementEarth.
  ///
  /// In en, this message translates to:
  /// **'Earth'**
  String get elementEarth;

  /// No description provided for @homeTitle.
  ///
  /// In en, this message translates to:
  /// **'Traps'**
  String get homeTitle;

  /// No description provided for @homeMaterialsTitle.
  ///
  /// In en, this message translates to:
  /// **'Materials'**
  String get homeMaterialsTitle;

  /// No description provided for @slotLabel.
  ///
  /// In en, this message translates to:
  /// **'Slot {index}'**
  String slotLabel(int index);

  /// No description provided for @slotEmpty.
  ///
  /// In en, this message translates to:
  /// **'Empty'**
  String get slotEmpty;

  /// No description provided for @slotInstallCta.
  ///
  /// In en, this message translates to:
  /// **'Install a trap'**
  String get slotInstallCta;

  /// No description provided for @elapsedLabel.
  ///
  /// In en, this message translates to:
  /// **'Elapsed {duration} / max 8h'**
  String elapsedLabel(String duration);

  /// No description provided for @collectButton.
  ///
  /// In en, this message translates to:
  /// **'Claim'**
  String get collectButton;

  /// No description provided for @collectResultSnack.
  ///
  /// In en, this message translates to:
  /// **'Got {materialCount} materials, {bugCount} bugs!'**
  String collectResultSnack(int materialCount, int bugCount);

  /// No description provided for @collectNothingSnack.
  ///
  /// In en, this message translates to:
  /// **'Nothing to collect yet'**
  String get collectNothingSnack;

  /// No description provided for @homeYard.
  ///
  /// In en, this message translates to:
  /// **'My Yard'**
  String get homeYard;

  /// No description provided for @collecting.
  ///
  /// In en, this message translates to:
  /// **'Collecting'**
  String get collecting;

  /// No description provided for @readyLabel.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get readyLabel;

  /// No description provided for @collectAll.
  ///
  /// In en, this message translates to:
  /// **'Collect all'**
  String get collectAll;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;

  /// No description provided for @offlineBanner.
  ///
  /// In en, this message translates to:
  /// **'Welcome back! {materialCount} materials, {bugCount} bugs waiting'**
  String offlineBanner(int materialCount, int bugCount);

  /// No description provided for @chapterTitle.
  ///
  /// In en, this message translates to:
  /// **'Chapter {n}'**
  String chapterTitle(int n);

  /// No description provided for @chapterRemaining.
  ///
  /// In en, this message translates to:
  /// **'{count} more bugs to the next chapter'**
  String chapterRemaining(int count);

  /// No description provided for @statusForaging.
  ///
  /// In en, this message translates to:
  /// **'Foraging…'**
  String get statusForaging;

  /// No description provided for @statusIdle.
  ///
  /// In en, this message translates to:
  /// **'Install a trap to start foraging'**
  String get statusIdle;

  /// No description provided for @navUpgrade.
  ///
  /// In en, this message translates to:
  /// **'Upgrade'**
  String get navUpgrade;

  /// No description provided for @navShop.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get navShop;

  /// No description provided for @upgradeTitle.
  ///
  /// In en, this message translates to:
  /// **'Upgrades'**
  String get upgradeTitle;

  /// No description provided for @retreat.
  ///
  /// In en, this message translates to:
  /// **'Retreat!'**
  String get retreat;

  /// No description provided for @offlineReward.
  ///
  /// In en, this message translates to:
  /// **'Welcome back! +{gold} gold, +{xp} XP'**
  String offlineReward(String gold, String xp);

  /// No description provided for @offlineTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome back!'**
  String get offlineTitle;

  /// No description provided for @offlineElapsed.
  ///
  /// In en, this message translates to:
  /// **'Idle rewards earned over {time}'**
  String offlineElapsed(String time);

  /// No description provided for @offlineGoldLabel.
  ///
  /// In en, this message translates to:
  /// **'Gold'**
  String get offlineGoldLabel;

  /// No description provided for @offlineXpLabel.
  ///
  /// In en, this message translates to:
  /// **'XP'**
  String get offlineXpLabel;

  /// No description provided for @durationHm.
  ///
  /// In en, this message translates to:
  /// **'{h}h {m}m'**
  String durationHm(int h, int m);

  /// No description provided for @durationM.
  ///
  /// In en, this message translates to:
  /// **'{m}m'**
  String durationM(int m);

  /// No description provided for @durationS.
  ///
  /// In en, this message translates to:
  /// **'{s}s'**
  String durationS(int s);

  /// No description provided for @upAttack.
  ///
  /// In en, this message translates to:
  /// **'Harvest Power'**
  String get upAttack;

  /// No description provided for @upAttackSpeed.
  ///
  /// In en, this message translates to:
  /// **'Swift Hands'**
  String get upAttackSpeed;

  /// No description provided for @upCrit.
  ///
  /// In en, this message translates to:
  /// **'Weak Point'**
  String get upCrit;

  /// No description provided for @upCritDamage.
  ///
  /// In en, this message translates to:
  /// **'Heavy Blow'**
  String get upCritDamage;

  /// No description provided for @upBossDamage.
  ///
  /// In en, this message translates to:
  /// **'Fighting Spirit'**
  String get upBossDamage;

  /// No description provided for @upMaxHp.
  ///
  /// In en, this message translates to:
  /// **'Grit'**
  String get upMaxHp;

  /// No description provided for @upDefense.
  ///
  /// In en, this message translates to:
  /// **'Toughness'**
  String get upDefense;

  /// No description provided for @upRegen.
  ///
  /// In en, this message translates to:
  /// **'Recovery'**
  String get upRegen;

  /// No description provided for @upReward.
  ///
  /// In en, this message translates to:
  /// **'Merchant Skill'**
  String get upReward;

  /// No description provided for @upXp.
  ///
  /// In en, this message translates to:
  /// **'Foraging Lore'**
  String get upXp;

  /// No description provided for @upBugFind.
  ///
  /// In en, this message translates to:
  /// **'Bug Sense'**
  String get upBugFind;

  /// No description provided for @upMaterialFind.
  ///
  /// In en, this message translates to:
  /// **'Careful Harvest'**
  String get upMaterialFind;

  /// No description provided for @upMoveSpeed.
  ///
  /// In en, this message translates to:
  /// **'Footwork'**
  String get upMoveSpeed;

  /// No description provided for @upBoost.
  ///
  /// In en, this message translates to:
  /// **'Focus'**
  String get upBoost;

  /// No description provided for @upBugBuff.
  ///
  /// In en, this message translates to:
  /// **'Codex Mastery'**
  String get upBugBuff;

  /// No description provided for @statAttack.
  ///
  /// In en, this message translates to:
  /// **'Attack'**
  String get statAttack;

  /// No description provided for @statAttackSpeed.
  ///
  /// In en, this message translates to:
  /// **'Attack Speed'**
  String get statAttackSpeed;

  /// No description provided for @statReward.
  ///
  /// In en, this message translates to:
  /// **'Gold Bonus'**
  String get statReward;

  /// No description provided for @notEnoughGold.
  ///
  /// In en, this message translates to:
  /// **'Not enough gold'**
  String get notEnoughGold;

  /// No description provided for @curGold.
  ///
  /// In en, this message translates to:
  /// **'Gold'**
  String get curGold;

  /// No description provided for @rewardGained.
  ///
  /// In en, this message translates to:
  /// **'Rewards'**
  String get rewardGained;

  /// No description provided for @bossLabel.
  ///
  /// In en, this message translates to:
  /// **'BOSS'**
  String get bossLabel;

  /// No description provided for @tapBoostHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to boost!'**
  String get tapBoostHint;

  /// No description provided for @levelBadge.
  ///
  /// In en, this message translates to:
  /// **'Lv {n}'**
  String levelBadge(int n);

  /// No description provided for @collectTitle.
  ///
  /// In en, this message translates to:
  /// **'Fields'**
  String get collectTitle;

  /// No description provided for @collectPickTrap.
  ///
  /// In en, this message translates to:
  /// **'Choose a trap'**
  String get collectPickTrap;

  /// No description provided for @collectPickSlot.
  ///
  /// In en, this message translates to:
  /// **'Choose a slot'**
  String get collectPickSlot;

  /// No description provided for @collectInstalledSnack.
  ///
  /// In en, this message translates to:
  /// **'Installed {trap} at {field}'**
  String collectInstalledSnack(String trap, String field);

  /// No description provided for @locked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get locked;

  /// No description provided for @install.
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get install;

  /// No description provided for @storageTitle.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get storageTitle;

  /// No description provided for @storageEmpty.
  ///
  /// In en, this message translates to:
  /// **'No bugs yet.\nGather some from the fields!'**
  String get storageEmpty;

  /// No description provided for @storageCount.
  ///
  /// In en, this message translates to:
  /// **'{count} bugs'**
  String storageCount(int count);

  /// No description provided for @storageCapacityCount.
  ///
  /// In en, this message translates to:
  /// **'{used}/{cap}'**
  String storageCapacityCount(int used, int cap);

  /// No description provided for @storageCapacityLabel.
  ///
  /// In en, this message translates to:
  /// **'Storage {used} / {cap} slots'**
  String storageCapacityLabel(int used, int cap);

  /// No description provided for @storageFullBanner.
  ///
  /// In en, this message translates to:
  /// **'Your collection is full\nNo new bugs will be added'**
  String get storageFullBanner;

  /// No description provided for @storageFullSnack.
  ///
  /// In en, this message translates to:
  /// **'Storage is full. Release a bug or expand your storage.'**
  String get storageFullSnack;

  /// No description provided for @storageExpand.
  ///
  /// In en, this message translates to:
  /// **'+{n} slots · {jelly} jelly'**
  String storageExpand(int n, int jelly);

  /// No description provided for @dexTitle.
  ///
  /// In en, this message translates to:
  /// **'Bug Dex'**
  String get dexTitle;

  /// No description provided for @dexDiscovered.
  ///
  /// In en, this message translates to:
  /// **'Found'**
  String get dexDiscovered;

  /// No description provided for @dexConquered.
  ///
  /// In en, this message translates to:
  /// **'Raised'**
  String get dexConquered;

  /// No description provided for @dexConqueredYes.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get dexConqueredYes;

  /// No description provided for @dexConqueredNo.
  ///
  /// In en, this message translates to:
  /// **'Not yet'**
  String get dexConqueredNo;

  /// No description provided for @dexMaxSize.
  ///
  /// In en, this message translates to:
  /// **'Largest'**
  String get dexMaxSize;

  /// No description provided for @dexMaxPotential.
  ///
  /// In en, this message translates to:
  /// **'Best potential'**
  String get dexMaxPotential;

  /// No description provided for @dexNotFound.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t met this bug yet. Go find one!'**
  String get dexNotFound;

  /// No description provided for @dexClaim.
  ///
  /// In en, this message translates to:
  /// **'Claim {n} dex reward(s)'**
  String dexClaim(Object n);

  /// No description provided for @dexClaimedSnack.
  ///
  /// In en, this message translates to:
  /// **'Dex reward! {gold} gold · {jelly} jelly'**
  String dexClaimedSnack(Object gold, Object jelly);

  /// No description provided for @dexBonusSummary.
  ///
  /// In en, this message translates to:
  /// **'Dex bonus — ATK +{atk}% · HP +{hp}% · Gold +{gold}%'**
  String dexBonusSummary(String atk, String hp, String gold);

  /// No description provided for @speciesPassiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Species ability'**
  String get speciesPassiveTitle;

  /// No description provided for @speciesPassiveHint.
  ///
  /// In en, this message translates to:
  /// **'Applies while this bug is equipped as a pet. Equipping several of the same species stacks it.'**
  String get speciesPassiveHint;

  /// No description provided for @storageFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get storageFilterLabel;

  /// No description provided for @storageFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get storageFilterAll;

  /// No description provided for @storageFilterSnack.
  ///
  /// In en, this message translates to:
  /// **'Below {grade} is released automatically and turned into materials'**
  String storageFilterSnack(Object grade);

  /// No description provided for @autoSynthTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto fuse'**
  String get autoSynthTitle;

  /// No description provided for @autoSynthHint.
  ///
  /// In en, this message translates to:
  /// **'Fuses automatically whenever {n} of the same species pile up. Equipped and incubating bugs are never used.'**
  String autoSynthHint(Object n);

  /// No description provided for @autoSynthNone.
  ///
  /// In en, this message translates to:
  /// **'Nothing can be fused right now'**
  String get autoSynthNone;

  /// No description provided for @autoSynthPreview.
  ///
  /// In en, this message translates to:
  /// **'{count} will be fused (uses {used})'**
  String autoSynthPreview(Object count, Object used);

  /// No description provided for @autoSynthDone.
  ///
  /// In en, this message translates to:
  /// **'Fused {count} time(s) ({used} used)'**
  String autoSynthDone(Object count, Object used);

  /// No description provided for @autoSynthRun.
  ///
  /// In en, this message translates to:
  /// **'Auto fuse'**
  String get autoSynthRun;

  /// No description provided for @eventIntroTitle.
  ///
  /// In en, this message translates to:
  /// **'What is the Bug King Trials?'**
  String get eventIntroTitle;

  /// No description provided for @eventIntroStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get eventIntroStart;

  /// No description provided for @eventHelp.
  ///
  /// In en, this message translates to:
  /// **'How it works'**
  String get eventHelp;

  /// No description provided for @eventCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Wave {n} cleared! Choose one'**
  String eventCardTitle(Object n);

  /// No description provided for @eventCardHint.
  ///
  /// In en, this message translates to:
  /// **'The boost lasts for the rest of this run'**
  String get eventCardHint;

  /// No description provided for @cardHeal_s.
  ///
  /// In en, this message translates to:
  /// **'First Aid'**
  String get cardHeal_s;

  /// No description provided for @cardHeal_sDesc.
  ///
  /// In en, this message translates to:
  /// **'Restore 30% HP'**
  String get cardHeal_sDesc;

  /// No description provided for @cardHeal_l.
  ///
  /// In en, this message translates to:
  /// **'Full Recovery'**
  String get cardHeal_l;

  /// No description provided for @cardHeal_lDesc.
  ///
  /// In en, this message translates to:
  /// **'Restore 70% HP'**
  String get cardHeal_lDesc;

  /// No description provided for @cardAtk_s.
  ///
  /// In en, this message translates to:
  /// **'Sharp Mandibles'**
  String get cardAtk_s;

  /// No description provided for @cardAtk_sDesc.
  ///
  /// In en, this message translates to:
  /// **'Attack +12%'**
  String get cardAtk_sDesc;

  /// No description provided for @cardAtk_l.
  ///
  /// In en, this message translates to:
  /// **'Onslaught'**
  String get cardAtk_l;

  /// No description provided for @cardAtk_lDesc.
  ///
  /// In en, this message translates to:
  /// **'Attack +28%'**
  String get cardAtk_lDesc;

  /// No description provided for @cardDef_s.
  ///
  /// In en, this message translates to:
  /// **'Hardened Shell'**
  String get cardDef_s;

  /// No description provided for @cardDef_sDesc.
  ///
  /// In en, this message translates to:
  /// **'Defense +18%'**
  String get cardDef_sDesc;

  /// No description provided for @cardHp_s.
  ///
  /// In en, this message translates to:
  /// **'Sturdy Build'**
  String get cardHp_s;

  /// No description provided for @cardHp_sDesc.
  ///
  /// In en, this message translates to:
  /// **'Max HP +15%'**
  String get cardHp_sDesc;

  /// No description provided for @cardRevive.
  ///
  /// In en, this message translates to:
  /// **'Dew of Life'**
  String get cardRevive;

  /// No description provided for @cardReviveDesc.
  ///
  /// In en, this message translates to:
  /// **'Revive one fallen bug at half HP'**
  String get cardReviveDesc;

  /// No description provided for @cardSkip.
  ///
  /// In en, this message translates to:
  /// **'Detour'**
  String get cardSkip;

  /// No description provided for @cardSkipDesc.
  ///
  /// In en, this message translates to:
  /// **'Skip the next wave without fighting'**
  String get cardSkipDesc;

  /// No description provided for @eventFlyerPeriod.
  ///
  /// In en, this message translates to:
  /// **'{start} – {end}'**
  String eventFlyerPeriod(String start, String end);

  /// No description provided for @eventPeriodLabel.
  ///
  /// In en, this message translates to:
  /// **'Event period'**
  String get eventPeriodLabel;

  /// No description provided for @eventFlyerHeadline.
  ///
  /// In en, this message translates to:
  /// **'Looking for the bug handler who goes furthest'**
  String get eventFlyerHeadline;

  /// No description provided for @eventFlyerPrize.
  ///
  /// In en, this message translates to:
  /// **'1st place gets a real live beetle'**
  String get eventFlyerPrize;

  /// No description provided for @eventFlyerPrizeNote.
  ///
  /// In en, this message translates to:
  /// **'Ships within Korea, sent directly by the seller'**
  String get eventFlyerPrizeNote;

  /// No description provided for @eventFlyerHow.
  ///
  /// In en, this message translates to:
  /// **'How to enter'**
  String get eventFlyerHow;

  /// No description provided for @eventFlyerHow1.
  ///
  /// In en, this message translates to:
  /// **'Pick 3 adult bugs and enter'**
  String get eventFlyerHow1;

  /// No description provided for @eventFlyerHow2.
  ///
  /// In en, this message translates to:
  /// **'Choose one boost card after each wave'**
  String get eventFlyerHow2;

  /// No description provided for @eventFlyerHow3.
  ///
  /// In en, this message translates to:
  /// **'The further you get, the higher you rank'**
  String get eventFlyerHow3;

  /// No description provided for @eventFlyerRules.
  ///
  /// In en, this message translates to:
  /// **'Good to know'**
  String get eventFlyerRules;

  /// No description provided for @eventFlyerRule1.
  ///
  /// In en, this message translates to:
  /// **'Stats are **equalized** — only species, element and temperament count; training, enhancement and size do not apply'**
  String get eventFlyerRule1;

  /// No description provided for @eventFlyerRule2.
  ///
  /// In en, this message translates to:
  /// **'Enemy elements rotate every wave — a single-element team will hit a wall'**
  String get eventFlyerRule2;

  /// No description provided for @eventFlyerRule3.
  ///
  /// In en, this message translates to:
  /// **'Bugs that entered rest for a day — keeping several good bugs pays off'**
  String get eventFlyerRule3;

  /// No description provided for @eventFlyerRule4.
  ///
  /// In en, this message translates to:
  /// **'Tickets refill every morning; free top-ups add up to 2 more per day'**
  String get eventFlyerRule4;

  /// No description provided for @eventFlyerLogin.
  ///
  /// In en, this message translates to:
  /// **'Sign in to appear in the ranking (guests can still play)'**
  String get eventFlyerLogin;

  /// No description provided for @eventTitle.
  ///
  /// In en, this message translates to:
  /// **'Bug King Trials'**
  String get eventTitle;

  /// No description provided for @eventBanner.
  ///
  /// In en, this message translates to:
  /// **'Bug King Trials · {n} tickets'**
  String eventBanner(Object n);

  /// No description provided for @eventClosed.
  ///
  /// In en, this message translates to:
  /// **'No event is running'**
  String get eventClosed;

  /// No description provided for @eventNeedServer.
  ///
  /// In en, this message translates to:
  /// **'The event needs an online connection'**
  String get eventNeedServer;

  /// No description provided for @eventTickets.
  ///
  /// In en, this message translates to:
  /// **'Tickets {n}/{max}'**
  String eventTickets(int n, int max);

  /// No description provided for @eventBestRecord.
  ///
  /// In en, this message translates to:
  /// **'Your best'**
  String get eventBestRecord;

  /// No description provided for @eventNoRecord.
  ///
  /// In en, this message translates to:
  /// **'No attempt yet'**
  String get eventNoRecord;

  /// No description provided for @eventWaveRecord.
  ///
  /// In en, this message translates to:
  /// **'Wave {n}'**
  String eventWaveRecord(Object n);

  /// No description provided for @eventScore.
  ///
  /// In en, this message translates to:
  /// **'{n} pts'**
  String eventScore(Object n);

  /// No description provided for @eventMyRank.
  ///
  /// In en, this message translates to:
  /// **'Your rank #{n}'**
  String eventMyRank(Object n);

  /// No description provided for @eventPickTeam.
  ///
  /// In en, this message translates to:
  /// **'Pick 3 bugs to enter'**
  String get eventPickTeam;

  /// No description provided for @eventPickOrder.
  ///
  /// In en, this message translates to:
  /// **'They fight left to right · a bug that powers up the one behind it makes the team stronger'**
  String get eventPickOrder;

  /// No description provided for @eventNormalizeTitle.
  ///
  /// In en, this message translates to:
  /// **'Stats are equalized in this event'**
  String get eventNormalizeTitle;

  /// No description provided for @eventNormalizeBody.
  ///
  /// In en, this message translates to:
  /// **'Only species, element, temperament and specialty count. Training, breakthrough, part enhancement, potential and size do not apply — everyone competes on formation alone.'**
  String get eventNormalizeBody;

  /// No description provided for @eventFatigueLeft.
  ///
  /// In en, this message translates to:
  /// **'Ready in {time}'**
  String eventFatigueLeft(Object time);

  /// No description provided for @eventRestHours.
  ///
  /// In en, this message translates to:
  /// **'⏳{h}h'**
  String eventRestHours(Object h);

  /// No description provided for @eventRestMinutes.
  ///
  /// In en, this message translates to:
  /// **'⏳{m}m'**
  String eventRestMinutes(Object m);

  /// No description provided for @eventChallenge.
  ///
  /// In en, this message translates to:
  /// **'Enter (1 ticket)'**
  String get eventChallenge;

  /// No description provided for @eventNoTicket.
  ///
  /// In en, this message translates to:
  /// **'No tickets left'**
  String get eventNoTicket;

  /// No description provided for @eventAdTicket.
  ///
  /// In en, this message translates to:
  /// **'Claim free ticket'**
  String get eventAdTicket;

  /// No description provided for @eventAdLimit.
  ///
  /// In en, this message translates to:
  /// **'Today\'s free rewards are used up'**
  String get eventAdLimit;

  /// No description provided for @eventTicketFull.
  ///
  /// In en, this message translates to:
  /// **'Tickets are full'**
  String get eventTicketFull;

  /// No description provided for @eventResultTitle.
  ///
  /// In en, this message translates to:
  /// **'Reached wave {n}!'**
  String eventResultTitle(Object n);

  /// No description provided for @eventNewBest.
  ///
  /// In en, this message translates to:
  /// **'New best!'**
  String get eventNewBest;

  /// No description provided for @eventKeptBest.
  ///
  /// In en, this message translates to:
  /// **'Your best is wave {n}'**
  String eventKeptBest(Object n);

  /// No description provided for @eventWaveCleared.
  ///
  /// In en, this message translates to:
  /// **'Wave {n} cleared!'**
  String eventWaveCleared(Object n);

  /// No description provided for @eventFastForward.
  ///
  /// In en, this message translates to:
  /// **'Fast forward'**
  String get eventFastForward;

  /// No description provided for @eventNextWave.
  ///
  /// In en, this message translates to:
  /// **'Next enemy'**
  String get eventNextWave;

  /// No description provided for @eventLead.
  ///
  /// In en, this message translates to:
  /// **'Lead'**
  String get eventLead;

  /// No description provided for @eventSetLead.
  ///
  /// In en, this message translates to:
  /// **'Set lead'**
  String get eventSetLead;

  /// No description provided for @eventLeadHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a bug to send it in first'**
  String get eventLeadHint;

  /// No description provided for @eventRanking.
  ///
  /// In en, this message translates to:
  /// **'Ranking'**
  String get eventRanking;

  /// No description provided for @eventRankEmpty.
  ///
  /// In en, this message translates to:
  /// **'No entries yet'**
  String get eventRankEmpty;

  /// No description provided for @eventAnonWarn.
  ///
  /// In en, this message translates to:
  /// **'Guest accounts don\'t appear in the ranking. Sign in to take part.'**
  String get eventAnonWarn;

  /// No description provided for @eventKoreaOnly.
  ///
  /// In en, this message translates to:
  /// **'Physical prizes ship within Korea only. Rankings and in-game rewards are open to everyone.'**
  String get eventKoreaOnly;

  /// No description provided for @eventRules.
  ///
  /// In en, this message translates to:
  /// **'Event rules'**
  String get eventRules;

  /// No description provided for @storageFilterButton.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get storageFilterButton;

  /// No description provided for @storageFilterTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose minimum grade'**
  String get storageFilterTitle;

  /// No description provided for @autoReleaseTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto release'**
  String get autoReleaseTitle;

  /// No description provided for @autoReleaseHint.
  ///
  /// In en, this message translates to:
  /// **'Releases every bug matching the filter at once and turns it into materials. Equipped, incubating and trained bugs (training, breakthrough, enhancement) are never touched.'**
  String get autoReleaseHint;

  /// No description provided for @autoReleaseNone.
  ///
  /// In en, this message translates to:
  /// **'No bugs match the filter'**
  String get autoReleaseNone;

  /// No description provided for @autoReleaseDone.
  ///
  /// In en, this message translates to:
  /// **'Released {count} bugs for {mats} materials'**
  String autoReleaseDone(Object count, Object mats);

  /// No description provided for @autoReleasePreview.
  ///
  /// In en, this message translates to:
  /// **'{count} bugs will be released for {mats} materials'**
  String autoReleasePreview(Object count, Object mats);

  /// No description provided for @autoReleaseRun.
  ///
  /// In en, this message translates to:
  /// **'Release'**
  String get autoReleaseRun;

  /// No description provided for @autoFilterGrades.
  ///
  /// In en, this message translates to:
  /// **'Target grades'**
  String get autoFilterGrades;

  /// No description provided for @autoFilterPotential.
  ///
  /// In en, this message translates to:
  /// **'Potential {n}★ or lower'**
  String autoFilterPotential(Object n);

  /// No description provided for @autoFilterEmpty.
  ///
  /// In en, this message translates to:
  /// **'Pick at least one grade'**
  String get autoFilterEmpty;

  /// No description provided for @autoPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Bugs that will be gone'**
  String get autoPreviewTitle;

  /// No description provided for @autoPreviewMore.
  ///
  /// In en, this message translates to:
  /// **'and {n} more'**
  String autoPreviewMore(Object n);

  /// No description provided for @autoPreviewLine.
  ///
  /// In en, this message translates to:
  /// **'{name} ×{count}'**
  String autoPreviewLine(String name, int count);

  /// No description provided for @storageExpandMaxed.
  ///
  /// In en, this message translates to:
  /// **'Max size'**
  String get storageExpandMaxed;

  /// No description provided for @storageExpandedSnack.
  ///
  /// In en, this message translates to:
  /// **'Storage expanded!'**
  String get storageExpandedSnack;

  /// No description provided for @bugSize.
  ///
  /// In en, this message translates to:
  /// **'{mm}mm'**
  String bugSize(String mm);

  /// No description provided for @bugPotential.
  ///
  /// In en, this message translates to:
  /// **'{stars}★'**
  String bugPotential(int stars);

  /// No description provided for @gradeCommon.
  ///
  /// In en, this message translates to:
  /// **'Common'**
  String get gradeCommon;

  /// No description provided for @gradeUncommon.
  ///
  /// In en, this message translates to:
  /// **'Uncommon'**
  String get gradeUncommon;

  /// No description provided for @gradeRare.
  ///
  /// In en, this message translates to:
  /// **'Rare'**
  String get gradeRare;

  /// No description provided for @gradeEpic.
  ///
  /// In en, this message translates to:
  /// **'Epic'**
  String get gradeEpic;

  /// No description provided for @gradeLegendary.
  ///
  /// In en, this message translates to:
  /// **'Legendary'**
  String get gradeLegendary;

  /// No description provided for @specialtyStrike.
  ///
  /// In en, this message translates to:
  /// **'Strike'**
  String get specialtyStrike;

  /// No description provided for @specialtyGrip.
  ///
  /// In en, this message translates to:
  /// **'Grip'**
  String get specialtyGrip;

  /// No description provided for @specialtyToss.
  ///
  /// In en, this message translates to:
  /// **'Toss'**
  String get specialtyToss;

  /// No description provided for @temperamentAggressive.
  ///
  /// In en, this message translates to:
  /// **'Aggressive'**
  String get temperamentAggressive;

  /// No description provided for @temperamentCautious.
  ///
  /// In en, this message translates to:
  /// **'Cautious'**
  String get temperamentCautious;

  /// No description provided for @temperamentCunning.
  ///
  /// In en, this message translates to:
  /// **'Cunning'**
  String get temperamentCunning;

  /// No description provided for @temperamentSteadfast.
  ///
  /// In en, this message translates to:
  /// **'Steadfast'**
  String get temperamentSteadfast;

  /// No description provided for @temperamentFickle.
  ///
  /// In en, this message translates to:
  /// **'Fickle'**
  String get temperamentFickle;

  /// No description provided for @traitFierce.
  ///
  /// In en, this message translates to:
  /// **'Fierce'**
  String get traitFierce;

  /// No description provided for @traitSturdy.
  ///
  /// In en, this message translates to:
  /// **'Sturdy'**
  String get traitSturdy;

  /// No description provided for @traitVital.
  ///
  /// In en, this message translates to:
  /// **'Vital'**
  String get traitVital;

  /// No description provided for @traitNoble.
  ///
  /// In en, this message translates to:
  /// **'Noble'**
  String get traitNoble;

  /// No description provided for @traitTitle.
  ///
  /// In en, this message translates to:
  /// **'Bloodline trait'**
  String get traitTitle;

  /// No description provided for @traitHint.
  ///
  /// In en, this message translates to:
  /// **'Only bred bugs can have one. Matching parents always pass it on.'**
  String get traitHint;

  /// No description provided for @breedInheritTitle.
  ///
  /// In en, this message translates to:
  /// **'Inherited'**
  String get breedInheritTitle;

  /// No description provided for @breedInheritHint.
  ///
  /// In en, this message translates to:
  /// **'Element, temperament and bloodline trait pass from the parents. Pair parents that match to lock it in.'**
  String get breedInheritHint;

  /// No description provided for @sexMale.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get sexMale;

  /// No description provided for @sexFemale.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get sexFemale;

  /// No description provided for @materialChitin.
  ///
  /// In en, this message translates to:
  /// **'Chitin'**
  String get materialChitin;

  /// No description provided for @materialMineral.
  ///
  /// In en, this message translates to:
  /// **'Mineral'**
  String get materialMineral;

  /// No description provided for @materialSap.
  ///
  /// In en, this message translates to:
  /// **'Sap Crystal'**
  String get materialSap;

  /// No description provided for @materialJelly.
  ///
  /// In en, this message translates to:
  /// **'Bug Jelly'**
  String get materialJelly;

  /// No description provided for @combatPowerLabel.
  ///
  /// In en, this message translates to:
  /// **'Power'**
  String get combatPowerLabel;

  /// No description provided for @chatTitle.
  ///
  /// In en, this message translates to:
  /// **'Global chat'**
  String get chatTitle;

  /// No description provided for @chatPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Global chat — tap to open'**
  String get chatPlaceholder;

  /// No description provided for @characterTitle.
  ///
  /// In en, this message translates to:
  /// **'My Character'**
  String get characterTitle;

  /// No description provided for @statCombatPower.
  ///
  /// In en, this message translates to:
  /// **'Combat Power'**
  String get statCombatPower;

  /// No description provided for @statCrit.
  ///
  /// In en, this message translates to:
  /// **'Critical'**
  String get statCrit;

  /// No description provided for @statMaxHp.
  ///
  /// In en, this message translates to:
  /// **'Max HP'**
  String get statMaxHp;

  /// No description provided for @statDefense.
  ///
  /// In en, this message translates to:
  /// **'Defense'**
  String get statDefense;

  /// No description provided for @rankingTitle.
  ///
  /// In en, this message translates to:
  /// **'Ranking'**
  String get rankingTitle;

  /// No description provided for @roadmapTitle.
  ///
  /// In en, this message translates to:
  /// **'Roadmap'**
  String get roadmapTitle;

  /// No description provided for @roadmapStageRange.
  ///
  /// In en, this message translates to:
  /// **'STAGE {start}–{end}'**
  String roadmapStageRange(int start, int end);

  /// No description provided for @roadmapProgress.
  ///
  /// In en, this message translates to:
  /// **'{cur} / {total}'**
  String roadmapProgress(int cur, int total);

  /// No description provided for @roadmapCleared.
  ///
  /// In en, this message translates to:
  /// **'Cleared'**
  String get roadmapCleared;

  /// No description provided for @roadmapCurrent.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get roadmapCurrent;

  /// No description provided for @roadmapLocked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get roadmapLocked;

  /// No description provided for @roadmapFinalBoss.
  ///
  /// In en, this message translates to:
  /// **'Final boss'**
  String get roadmapFinalBoss;

  /// No description provided for @roadmapEnter.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get roadmapEnter;

  /// No description provided for @roadmapReplay.
  ///
  /// In en, this message translates to:
  /// **'Replay'**
  String get roadmapReplay;

  /// No description provided for @chapterClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Chapter cleared! 🎉'**
  String get chapterClearTitle;

  /// No description provided for @chapterClearMsg.
  ///
  /// In en, this message translates to:
  /// **'Conquered {difficulty}! Final boss {boss} defeated!'**
  String chapterClearMsg(String difficulty, String boss);

  /// No description provided for @chapterClearReward.
  ///
  /// In en, this message translates to:
  /// **'Clear reward'**
  String get chapterClearReward;

  /// No description provided for @mailTitle.
  ///
  /// In en, this message translates to:
  /// **'Mailbox'**
  String get mailTitle;

  /// No description provided for @mailEmpty.
  ///
  /// In en, this message translates to:
  /// **'No new mail'**
  String get mailEmpty;

  /// No description provided for @mailDailyTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily reward (twice a day)'**
  String get mailDailyTitle;

  /// No description provided for @dailyLunch.
  ///
  /// In en, this message translates to:
  /// **'Lunch reward'**
  String get dailyLunch;

  /// No description provided for @dailyDinner.
  ///
  /// In en, this message translates to:
  /// **'Dinner reward'**
  String get dailyDinner;

  /// No description provided for @dailyClaim.
  ///
  /// In en, this message translates to:
  /// **'Claim'**
  String get dailyClaim;

  /// No description provided for @dailyClaimedToday.
  ///
  /// In en, this message translates to:
  /// **'Claimed today'**
  String get dailyClaimedToday;

  /// No description provided for @dailyLockedUntil.
  ///
  /// In en, this message translates to:
  /// **'from {hour}:00'**
  String dailyLockedUntil(int hour);

  /// No description provided for @dailyRewardSnack.
  ///
  /// In en, this message translates to:
  /// **'Daily reward claimed!'**
  String get dailyRewardSnack;

  /// No description provided for @giftSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Surprise gifts (claim within 3h)'**
  String get giftSectionTitle;

  /// No description provided for @giftClaim.
  ///
  /// In en, this message translates to:
  /// **'Claim'**
  String get giftClaim;

  /// No description provided for @giftClaimAd.
  ///
  /// In en, this message translates to:
  /// **'Claim x2'**
  String get giftClaimAd;

  /// No description provided for @giftExpiresIn.
  ///
  /// In en, this message translates to:
  /// **'expires in {time}'**
  String giftExpiresIn(String time);

  /// No description provided for @giftClaimedSnack.
  ///
  /// In en, this message translates to:
  /// **'Gift claimed!'**
  String get giftClaimedSnack;

  /// No description provided for @giftDoubledSnack.
  ///
  /// In en, this message translates to:
  /// **'Double reward claimed!'**
  String get giftDoubledSnack;

  /// No description provided for @giftAdMoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Today\'s free double!'**
  String get giftAdMoreTitle;

  /// No description provided for @giftAdMoreBody.
  ///
  /// In en, this message translates to:
  /// **'Claim the same reward once more.'**
  String get giftAdMoreBody;

  /// No description provided for @giftAdMoreYes.
  ///
  /// In en, this message translates to:
  /// **'Claim again'**
  String get giftAdMoreYes;

  /// No description provided for @giftAdMoreLater.
  ///
  /// In en, this message translates to:
  /// **'No thanks'**
  String get giftAdMoreLater;

  /// No description provided for @notifLunchTitle.
  ///
  /// In en, this message translates to:
  /// **'Lunch reward is ready 🍱'**
  String get notifLunchTitle;

  /// No description provided for @notifDinnerTitle.
  ///
  /// In en, this message translates to:
  /// **'Dinner reward is ready 🌙'**
  String get notifDinnerTitle;

  /// No description provided for @notifRewardBody.
  ///
  /// In en, this message translates to:
  /// **'Hop in and claim it!'**
  String get notifRewardBody;

  /// No description provided for @notifOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'Idle rewards are full 🐛'**
  String get notifOfflineTitle;

  /// No description provided for @notifOfflineBody.
  ///
  /// In en, this message translates to:
  /// **'8 hours\' worth has piled up. Come collect it!'**
  String get notifOfflineBody;

  /// No description provided for @giftNone.
  ///
  /// In en, this message translates to:
  /// **'No gifts yet. Keep playing and they\'ll arrive!'**
  String get giftNone;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsSound.
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get settingsSound;

  /// No description provided for @settingsBgm.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get settingsBgm;

  /// No description provided for @settingsSfx.
  ///
  /// In en, this message translates to:
  /// **'Sound effects'**
  String get settingsSfx;

  /// No description provided for @settingsNickname.
  ///
  /// In en, this message translates to:
  /// **'Nickname'**
  String get settingsNickname;

  /// No description provided for @settingsNicknameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get settingsNicknameHint;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get actionNext;

  /// No description provided for @actionClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get actionClose;

  /// No description provided for @exitTitle.
  ///
  /// In en, this message translates to:
  /// **'Exit game'**
  String get exitTitle;

  /// No description provided for @exitConfirm.
  ///
  /// In en, this message translates to:
  /// **'Quit the game?'**
  String get exitConfirm;

  /// No description provided for @exitAction.
  ///
  /// In en, this message translates to:
  /// **'Quit'**
  String get exitAction;

  /// No description provided for @settingsReset.
  ///
  /// In en, this message translates to:
  /// **'Reset game data'**
  String get settingsReset;

  /// No description provided for @settingsResetConfirm.
  ///
  /// In en, this message translates to:
  /// **'All progress (bugs, currency, upgrades, stage) will be deleted. Reset for real?'**
  String get settingsResetConfirm;

  /// No description provided for @settingsResetDone.
  ///
  /// In en, this message translates to:
  /// **'Game data reset'**
  String get settingsResetDone;

  /// No description provided for @questHunt.
  ///
  /// In en, this message translates to:
  /// **'Monster Hunt'**
  String get questHunt;

  /// No description provided for @buffTitle.
  ///
  /// In en, this message translates to:
  /// **'Buffs'**
  String get buffTitle;

  /// No description provided for @buffSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Activate a buff'**
  String get buffSheetTitle;

  /// No description provided for @buffWatchAd.
  ///
  /// In en, this message translates to:
  /// **'Activate free'**
  String get buffWatchAd;

  /// No description provided for @buffMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m'**
  String buffMinutes(int minutes);

  /// No description provided for @buffActivatedSnack.
  ///
  /// In en, this message translates to:
  /// **'{buff} active! ({minutes}m)'**
  String buffActivatedSnack(String buff, int minutes);

  /// No description provided for @buffGoldRush.
  ///
  /// In en, this message translates to:
  /// **'Gold Rush'**
  String get buffGoldRush;

  /// No description provided for @buffGoldRushDesc.
  ///
  /// In en, this message translates to:
  /// **'Gold gain ×2'**
  String get buffGoldRushDesc;

  /// No description provided for @buffXpBoost.
  ///
  /// In en, this message translates to:
  /// **'XP Boost'**
  String get buffXpBoost;

  /// No description provided for @buffXpBoostDesc.
  ///
  /// In en, this message translates to:
  /// **'XP gain ×2'**
  String get buffXpBoostDesc;

  /// No description provided for @buffFrenzy.
  ///
  /// In en, this message translates to:
  /// **'Frenzy'**
  String get buffFrenzy;

  /// No description provided for @buffFrenzyDesc.
  ///
  /// In en, this message translates to:
  /// **'Attack & attack speed up'**
  String get buffFrenzyDesc;

  /// No description provided for @buffGatherer.
  ///
  /// In en, this message translates to:
  /// **'Gatherer\'s Touch'**
  String get buffGatherer;

  /// No description provided for @buffGathererDesc.
  ///
  /// In en, this message translates to:
  /// **'Material gain ×2'**
  String get buffGathererDesc;

  /// No description provided for @buffLuckyWind.
  ///
  /// In en, this message translates to:
  /// **'Lucky Wind'**
  String get buffLuckyWind;

  /// No description provided for @buffLuckyWindDesc.
  ///
  /// In en, this message translates to:
  /// **'Bug find rate ×2'**
  String get buffLuckyWindDesc;

  /// No description provided for @enhanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Enhance Parts'**
  String get enhanceTitle;

  /// No description provided for @partHornJaw.
  ///
  /// In en, this message translates to:
  /// **'Horn/Jaw'**
  String get partHornJaw;

  /// No description provided for @partCuticle.
  ///
  /// In en, this message translates to:
  /// **'Cuticle'**
  String get partCuticle;

  /// No description provided for @partWing.
  ///
  /// In en, this message translates to:
  /// **'Wings'**
  String get partWing;

  /// No description provided for @partBuild.
  ///
  /// In en, this message translates to:
  /// **'Build'**
  String get partBuild;

  /// No description provided for @enhanceAction.
  ///
  /// In en, this message translates to:
  /// **'Enhance'**
  String get enhanceAction;

  /// No description provided for @enhanceMaxed.
  ///
  /// In en, this message translates to:
  /// **'MAX'**
  String get enhanceMaxed;

  /// No description provided for @enhanceCap.
  ///
  /// In en, this message translates to:
  /// **'Enhance {cur}/{max}'**
  String enhanceCap(int cur, int max);

  /// No description provided for @enhancePerLevel.
  ///
  /// In en, this message translates to:
  /// **'+{pct}%/Lv'**
  String enhancePerLevel(String pct);

  /// No description provided for @equipTitle.
  ///
  /// In en, this message translates to:
  /// **'Equipped Pets'**
  String get equipTitle;

  /// No description provided for @equipEmpty.
  ///
  /// In en, this message translates to:
  /// **'Empty'**
  String get equipEmpty;

  /// No description provided for @equipAction.
  ///
  /// In en, this message translates to:
  /// **'Equip'**
  String get equipAction;

  /// No description provided for @unequipAction.
  ///
  /// In en, this message translates to:
  /// **'Unequip'**
  String get unequipAction;

  /// No description provided for @equipFull.
  ///
  /// In en, this message translates to:
  /// **'Equip slots are full'**
  String get equipFull;

  /// No description provided for @equippedBadge.
  ///
  /// In en, this message translates to:
  /// **'ON'**
  String get equippedBadge;

  /// No description provided for @petBonus.
  ///
  /// In en, this message translates to:
  /// **'Pet bonus · ATK +{atk}% · HP +{hp}%'**
  String petBonus(String atk, String hp);

  /// No description provided for @stageEgg.
  ///
  /// In en, this message translates to:
  /// **'Egg'**
  String get stageEgg;

  /// No description provided for @stageLarva.
  ///
  /// In en, this message translates to:
  /// **'Larva'**
  String get stageLarva;

  /// No description provided for @stagePupa.
  ///
  /// In en, this message translates to:
  /// **'Pupa'**
  String get stagePupa;

  /// No description provided for @stageAdult.
  ///
  /// In en, this message translates to:
  /// **'Adult'**
  String get stageAdult;

  /// No description provided for @evolveTitle.
  ///
  /// In en, this message translates to:
  /// **'Evolve'**
  String get evolveTitle;

  /// No description provided for @evolveNext.
  ///
  /// In en, this message translates to:
  /// **'{time} to {next}'**
  String evolveNext(String time, String next);

  /// No description provided for @evolveReady.
  ///
  /// In en, this message translates to:
  /// **'Ready to evolve'**
  String get evolveReady;

  /// No description provided for @evolveMaxed.
  ///
  /// In en, this message translates to:
  /// **'Fully evolved (Adult)'**
  String get evolveMaxed;

  /// No description provided for @accelerateAction.
  ///
  /// In en, this message translates to:
  /// **'Speed up'**
  String get accelerateAction;

  /// No description provided for @synthTitle.
  ///
  /// In en, this message translates to:
  /// **'Synthesis (★ up)'**
  String get synthTitle;

  /// No description provided for @synthDo.
  ///
  /// In en, this message translates to:
  /// **'Synthesize'**
  String get synthDo;

  /// No description provided for @synthDesc.
  ///
  /// In en, this message translates to:
  /// **'Same species {have}/{need} · Potential +1'**
  String synthDesc(int have, int need);

  /// No description provided for @synthMaxed.
  ///
  /// In en, this message translates to:
  /// **'Max potential'**
  String get synthMaxed;

  /// No description provided for @synthSnack.
  ///
  /// In en, this message translates to:
  /// **'Synthesis complete! Potential +1'**
  String get synthSnack;

  /// No description provided for @petEffectTitle.
  ///
  /// In en, this message translates to:
  /// **'Equip effect'**
  String get petEffectTitle;

  /// No description provided for @petAtkBonus.
  ///
  /// In en, this message translates to:
  /// **'Pet ATK +{v}%'**
  String petAtkBonus(String v);

  /// No description provided for @petHpBonus.
  ///
  /// In en, this message translates to:
  /// **'Pet HP +{v}%'**
  String petHpBonus(String v);

  /// No description provided for @trainTitle.
  ///
  /// In en, this message translates to:
  /// **'Train'**
  String get trainTitle;

  /// No description provided for @trainLevel.
  ///
  /// In en, this message translates to:
  /// **'Train level'**
  String get trainLevel;

  /// No description provided for @trainAction.
  ///
  /// In en, this message translates to:
  /// **'Train'**
  String get trainAction;

  /// No description provided for @trainMaxed.
  ///
  /// In en, this message translates to:
  /// **'Max level'**
  String get trainMaxed;

  /// No description provided for @trainSnack.
  ///
  /// In en, this message translates to:
  /// **'Trained! Level +1'**
  String get trainSnack;

  /// No description provided for @trainJelly.
  ///
  /// In en, this message translates to:
  /// **'{n} jelly'**
  String trainJelly(int n);

  /// No description provided for @trainJellySnack.
  ///
  /// In en, this message translates to:
  /// **'Instant training! Level +{lv}'**
  String trainJellySnack(int lv);

  /// No description provided for @breakthroughTitle.
  ///
  /// In en, this message translates to:
  /// **'Breakthrough'**
  String get breakthroughTitle;

  /// No description provided for @breakthroughTier.
  ///
  /// In en, this message translates to:
  /// **'Tier {n}'**
  String breakthroughTier(int n);

  /// No description provided for @breakthroughReady.
  ///
  /// In en, this message translates to:
  /// **'Breakthrough ready · cap ↑'**
  String get breakthroughReady;

  /// No description provided for @breakthroughProgress.
  ///
  /// In en, this message translates to:
  /// **'Breaking through · {time}'**
  String breakthroughProgress(String time);

  /// No description provided for @breakthroughDone.
  ///
  /// In en, this message translates to:
  /// **'Done! Collect it'**
  String get breakthroughDone;

  /// No description provided for @breakthroughMaxed.
  ///
  /// In en, this message translates to:
  /// **'Max tier reached'**
  String get breakthroughMaxed;

  /// No description provided for @breakthroughDo.
  ///
  /// In en, this message translates to:
  /// **'Break'**
  String get breakthroughDo;

  /// No description provided for @breakthroughCollect.
  ///
  /// In en, this message translates to:
  /// **'Collect'**
  String get breakthroughCollect;

  /// No description provided for @breakthroughInstant.
  ///
  /// In en, this message translates to:
  /// **'Finish now · {n} jelly'**
  String breakthroughInstant(int n);

  /// No description provided for @breakthroughStartedSnack.
  ///
  /// In en, this message translates to:
  /// **'Breakthrough started!'**
  String get breakthroughStartedSnack;

  /// No description provided for @breakthroughDoneSnack.
  ///
  /// In en, this message translates to:
  /// **'Breakthrough done! Level cap raised'**
  String get breakthroughDoneSnack;

  /// No description provided for @incubatorTitle.
  ///
  /// In en, this message translates to:
  /// **'Incubator'**
  String get incubatorTitle;

  /// No description provided for @incubatorSlots.
  ///
  /// In en, this message translates to:
  /// **'Slots {cur}/{max}'**
  String incubatorSlots(int cur, int max);

  /// No description provided for @incubatorPlace.
  ///
  /// In en, this message translates to:
  /// **'Place'**
  String get incubatorPlace;

  /// No description provided for @incubatorHatching.
  ///
  /// In en, this message translates to:
  /// **'Hatching · {time}'**
  String incubatorHatching(String time);

  /// No description provided for @incubatorReady.
  ///
  /// In en, this message translates to:
  /// **'Hatched!'**
  String get incubatorReady;

  /// No description provided for @incubatorCollect.
  ///
  /// In en, this message translates to:
  /// **'Collect'**
  String get incubatorCollect;

  /// No description provided for @incubatorFull.
  ///
  /// In en, this message translates to:
  /// **'Incubator full'**
  String get incubatorFull;

  /// No description provided for @incubatorExpand.
  ///
  /// In en, this message translates to:
  /// **'Expand slot · {n} jelly'**
  String incubatorExpand(int n);

  /// No description provided for @incubatorPlacedSnack.
  ///
  /// In en, this message translates to:
  /// **'Incubation started!'**
  String get incubatorPlacedSnack;

  /// No description provided for @incubatorCollectedSnack.
  ///
  /// In en, this message translates to:
  /// **'Hatched into a larva!'**
  String get incubatorCollectedSnack;

  /// No description provided for @incubatorExpandedSnack.
  ///
  /// In en, this message translates to:
  /// **'Incubator slot added!'**
  String get incubatorExpandedSnack;

  /// No description provided for @incubatorEmptySlot.
  ///
  /// In en, this message translates to:
  /// **'Empty slot'**
  String get incubatorEmptySlot;

  /// No description provided for @incubatorWaitingEggs.
  ///
  /// In en, this message translates to:
  /// **'Waiting eggs ({n})'**
  String incubatorWaitingEggs(int n);

  /// No description provided for @incubatorNoEggs.
  ///
  /// In en, this message translates to:
  /// **'No eggs to hatch'**
  String get incubatorNoEggs;

  /// No description provided for @incubatorHint.
  ///
  /// In en, this message translates to:
  /// **'Tap an empty capsule to add an egg; tap a ready one to collect.'**
  String get incubatorHint;

  /// No description provided for @incubatorPick.
  ///
  /// In en, this message translates to:
  /// **'Choose an egg'**
  String get incubatorPick;

  /// No description provided for @disassembleTitle.
  ///
  /// In en, this message translates to:
  /// **'Disassemble'**
  String get disassembleTitle;

  /// No description provided for @disassembleDesc.
  ///
  /// In en, this message translates to:
  /// **'Convert to {n} jelly'**
  String disassembleDesc(int n);

  /// No description provided for @disassembleAction.
  ///
  /// In en, this message translates to:
  /// **'Disassemble'**
  String get disassembleAction;

  /// No description provided for @disassembleSnack.
  ///
  /// In en, this message translates to:
  /// **'Disassembled'**
  String get disassembleSnack;

  /// No description provided for @bugDescTitle.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get bugDescTitle;

  /// No description provided for @onlyAdultTrain.
  ///
  /// In en, this message translates to:
  /// **'Only adults can be trained'**
  String get onlyAdultTrain;

  /// No description provided for @craftTitle.
  ///
  /// In en, this message translates to:
  /// **'Craft'**
  String get craftTitle;

  /// No description provided for @craftMake.
  ///
  /// In en, this message translates to:
  /// **'Craft'**
  String get craftMake;

  /// No description provided for @craftPotion.
  ///
  /// In en, this message translates to:
  /// **'{buff} Potion'**
  String craftPotion(String buff);

  /// No description provided for @craftAllPotion.
  ///
  /// In en, this message translates to:
  /// **'All-in-One Potion'**
  String get craftAllPotion;

  /// No description provided for @craftedSnack.
  ///
  /// In en, this message translates to:
  /// **'Crafted {name}!'**
  String craftedSnack(String name);

  /// No description provided for @missionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Missions'**
  String get missionsTitle;

  /// No description provided for @missionKillMonsters.
  ///
  /// In en, this message translates to:
  /// **'Hunt Monsters'**
  String get missionKillMonsters;

  /// No description provided for @missionKillBosses.
  ///
  /// In en, this message translates to:
  /// **'Defeat Bosses'**
  String get missionKillBosses;

  /// No description provided for @missionBuyUpgrades.
  ///
  /// In en, this message translates to:
  /// **'Upgrade Stats'**
  String get missionBuyUpgrades;

  /// No description provided for @missionReachStage.
  ///
  /// In en, this message translates to:
  /// **'Reach Stage'**
  String get missionReachStage;

  /// No description provided for @missionClaim.
  ///
  /// In en, this message translates to:
  /// **'Claim'**
  String get missionClaim;

  /// No description provided for @missionComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete! Tap to claim'**
  String get missionComplete;

  /// No description provided for @missionClaimedSnack.
  ///
  /// In en, this message translates to:
  /// **'Mission reward claimed!'**
  String get missionClaimedSnack;

  /// No description provided for @upAttackDesc.
  ///
  /// In en, this message translates to:
  /// **'Increases damage dealt per hit.'**
  String get upAttackDesc;

  /// No description provided for @upAttackSpeedDesc.
  ///
  /// In en, this message translates to:
  /// **'More attacks per second; faster hunting.'**
  String get upAttackSpeedDesc;

  /// No description provided for @upCritDesc.
  ///
  /// In en, this message translates to:
  /// **'Increases critical hit chance.'**
  String get upCritDesc;

  /// No description provided for @upCritDamageDesc.
  ///
  /// In en, this message translates to:
  /// **'Increases the critical hit damage multiplier.'**
  String get upCritDamageDesc;

  /// No description provided for @upBossDamageDesc.
  ///
  /// In en, this message translates to:
  /// **'Extra damage dealt to bosses.'**
  String get upBossDamageDesc;

  /// No description provided for @upMaxHpDesc.
  ///
  /// In en, this message translates to:
  /// **'Increases max HP so you last longer.'**
  String get upMaxHpDesc;

  /// No description provided for @upDefenseDesc.
  ///
  /// In en, this message translates to:
  /// **'Reduces damage taken from enemies.'**
  String get upDefenseDesc;

  /// No description provided for @upRegenDesc.
  ///
  /// In en, this message translates to:
  /// **'Increases HP regenerated per second.'**
  String get upRegenDesc;

  /// No description provided for @upRewardDesc.
  ///
  /// In en, this message translates to:
  /// **'More gold earned per monster kill.'**
  String get upRewardDesc;

  /// No description provided for @upXpDesc.
  ///
  /// In en, this message translates to:
  /// **'More XP earned per monster kill.'**
  String get upXpDesc;

  /// No description provided for @upBugFindDesc.
  ///
  /// In en, this message translates to:
  /// **'Increases the chance to find bugs.'**
  String get upBugFindDesc;

  /// No description provided for @upMaterialFindDesc.
  ///
  /// In en, this message translates to:
  /// **'Increases enhancement materials gained.'**
  String get upMaterialFindDesc;

  /// No description provided for @upMoveSpeedDesc.
  ///
  /// In en, this message translates to:
  /// **'Faster travel to the next hunting spot.'**
  String get upMoveSpeedDesc;

  /// No description provided for @upBoostDesc.
  ///
  /// In en, this message translates to:
  /// **'Strengthens the tap-to-boost effect.'**
  String get upBoostDesc;

  /// No description provided for @upBugBuffDesc.
  ///
  /// In en, this message translates to:
  /// **'Bonus scales with the number of bugs collected.'**
  String get upBugBuffDesc;

  /// No description provided for @tagCommonMaterial.
  ///
  /// In en, this message translates to:
  /// **'Material'**
  String get tagCommonMaterial;

  /// No description provided for @tagPremium.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get tagPremium;

  /// No description provided for @materialChitinDesc.
  ///
  /// In en, this message translates to:
  /// **'A hard exoskeleton shard. Used for advanced upgrade costs and horn/jaw enhancement.'**
  String get materialChitinDesc;

  /// No description provided for @materialMineralDesc.
  ///
  /// In en, this message translates to:
  /// **'A hard mined mineral. Used for advanced upgrade costs and cuticle enhancement.'**
  String get materialMineralDesc;

  /// No description provided for @materialSapDesc.
  ///
  /// In en, this message translates to:
  /// **'Hardened crystallized tree sap. Used for advanced upgrade costs and wing enhancement.'**
  String get materialSapDesc;

  /// No description provided for @materialJellyDesc.
  ///
  /// In en, this message translates to:
  /// **'A special premium currency. Used for crafting (All-in-One Potion) and special goods.'**
  String get materialJellyDesc;

  /// No description provided for @materialFossil.
  ///
  /// In en, this message translates to:
  /// **'Fossil Shard'**
  String get materialFossil;

  /// No description provided for @materialFossilDesc.
  ///
  /// In en, this message translates to:
  /// **'A shard of petrified insect. One is spent per hammer strike at the workshop.'**
  String get materialFossilDesc;

  /// No description provided for @saveBrokenTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open your save'**
  String get saveBrokenTitle;

  /// No description provided for @saveBrokenUpdate.
  ///
  /// In en, this message translates to:
  /// **'This account’s save is newer than the app.\nUpdate to the latest version to continue where you left off.'**
  String get saveBrokenUpdate;

  /// No description provided for @saveBrokenCorrupt.
  ///
  /// In en, this message translates to:
  /// **'Your save couldn\'t be read.\nThe original is kept safely on this device and was not overwritten.'**
  String get saveBrokenCorrupt;

  /// No description provided for @saveBrokenKeep.
  ///
  /// In en, this message translates to:
  /// **'The game is paused to protect your progress. Continuing could erase your save.'**
  String get saveBrokenKeep;

  /// No description provided for @saveBrokenSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact support'**
  String get saveBrokenSupport;

  /// No description provided for @eventRewardTitle.
  ///
  /// In en, this message translates to:
  /// **'Championship results are in'**
  String get eventRewardTitle;

  /// No description provided for @eventRewardRank.
  ///
  /// In en, this message translates to:
  /// **'Round {round} — rank {rank}'**
  String eventRewardRank(String round, int rank);

  /// No description provided for @eventRewardNone.
  ///
  /// In en, this message translates to:
  /// **'You didn\'t place this round. Here\'s your entry reward!'**
  String get eventRewardNone;

  /// No description provided for @eventRewardPhysical.
  ///
  /// In en, this message translates to:
  /// **'You placed for a real prize! Fill in the form below. Physical prizes ship to Korean addresses only — outside Korea you receive the in-game rewards.'**
  String get eventRewardPhysical;

  /// No description provided for @eventRewardApply.
  ///
  /// In en, this message translates to:
  /// **'Claim prize'**
  String get eventRewardApply;

  /// No description provided for @eventRewardClaim.
  ///
  /// In en, this message translates to:
  /// **'Collect'**
  String get eventRewardClaim;

  /// No description provided for @badgeChampion.
  ///
  /// In en, this message translates to:
  /// **'R{round} Champion'**
  String badgeChampion(int round);

  /// No description provided for @badgeFinalist.
  ///
  /// In en, this message translates to:
  /// **'R{round} Finalist'**
  String badgeFinalist(int round);

  /// No description provided for @nicknameBadChars.
  ///
  /// In en, this message translates to:
  /// **'Letters and numbers only (no emoji or stray marks)'**
  String get nicknameBadChars;

  /// No description provided for @eventRewardsTitle.
  ///
  /// In en, this message translates to:
  /// **'Rank rewards'**
  String get eventRewardsTitle;

  /// No description provided for @eventRankOne.
  ///
  /// In en, this message translates to:
  /// **'1st'**
  String get eventRankOne;

  /// No description provided for @eventRankRange.
  ///
  /// In en, this message translates to:
  /// **'{a}–{b}'**
  String eventRankRange(int a, int b);

  /// No description provided for @eventRewardRealBug.
  ///
  /// In en, this message translates to:
  /// **'Real beetle (ships in Korea)'**
  String get eventRewardRealBug;

  /// No description provided for @eventRewardJelly.
  ///
  /// In en, this message translates to:
  /// **'Jelly ×{n}'**
  String eventRewardJelly(int n);

  /// No description provided for @eventRewardParticipationRow.
  ///
  /// In en, this message translates to:
  /// **'Entry (1+ runs)'**
  String get eventRewardParticipationRow;

  /// No description provided for @eventFlyerSubPrize.
  ///
  /// In en, this message translates to:
  /// **'Rewards down to 10th — jelly prizes plus leaderboard badges for top ranks!'**
  String get eventFlyerSubPrize;

  /// No description provided for @netLostTitle.
  ///
  /// In en, this message translates to:
  /// **'Connection lost'**
  String get netLostTitle;

  /// No description provided for @netLostBody.
  ///
  /// In en, this message translates to:
  /// **'Check your internet connection.\nProgress is only saved while connected.'**
  String get netLostBody;

  /// No description provided for @netRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get netRetry;

  /// No description provided for @netToTitle.
  ///
  /// In en, this message translates to:
  /// **'Back to title'**
  String get netToTitle;

  /// No description provided for @netStillDown.
  ///
  /// In en, this message translates to:
  /// **'Still not connected'**
  String get netStillDown;

  /// No description provided for @materialsHint.
  ///
  /// In en, this message translates to:
  /// **'Materials — used for upgrades, part enhancement & crafting (tap for details)'**
  String get materialsHint;

  /// No description provided for @chatHint.
  ///
  /// In en, this message translates to:
  /// **'Type a message'**
  String get chatHint;

  /// No description provided for @chatSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get chatSend;

  /// No description provided for @chatEmpty.
  ///
  /// In en, this message translates to:
  /// **'No messages yet. Say hello!'**
  String get chatEmpty;

  /// No description provided for @chatUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Chat isn\'t available right now'**
  String get chatUnavailable;

  /// No description provided for @chatSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send your message'**
  String get chatSendFailed;

  /// No description provided for @chatTooLong.
  ///
  /// In en, this message translates to:
  /// **'Message is too long (max {max})'**
  String chatTooLong(int max);

  /// No description provided for @chatBlockedWord.
  ///
  /// In en, this message translates to:
  /// **'That message contains blocked words'**
  String get chatBlockedWord;

  /// No description provided for @chatTooFast.
  ///
  /// In en, this message translates to:
  /// **'Please slow down a little'**
  String get chatTooFast;

  /// No description provided for @chatReport.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get chatReport;

  /// No description provided for @chatBlock.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get chatBlock;

  /// No description provided for @chatUnblock.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get chatUnblock;

  /// No description provided for @chatDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get chatDelete;

  /// No description provided for @chatDeleted.
  ///
  /// In en, this message translates to:
  /// **'Message deleted'**
  String get chatDeleted;

  /// No description provided for @chatDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this message?'**
  String get chatDeleteTitle;

  /// No description provided for @chatDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'This removes your message for everyone. It can\'t be undone.'**
  String get chatDeleteBody;

  /// No description provided for @chatReported.
  ///
  /// In en, this message translates to:
  /// **'Reported. We\'ll review it'**
  String get chatReported;

  /// No description provided for @chatBlockedUser.
  ///
  /// In en, this message translates to:
  /// **'Blocked {name}'**
  String chatBlockedUser(String name);

  /// No description provided for @chatUnblockedUser.
  ///
  /// In en, this message translates to:
  /// **'Unblocked {name}'**
  String chatUnblockedUser(String name);

  /// No description provided for @chatBlockedMessage.
  ///
  /// In en, this message translates to:
  /// **'Message from a blocked user'**
  String get chatBlockedMessage;

  /// No description provided for @chatReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Report this message?'**
  String get chatReportTitle;

  /// No description provided for @chatReportBody.
  ///
  /// In en, this message translates to:
  /// **'Report abuse, spam or scams. Repeatedly reported users get restricted.'**
  String get chatReportBody;

  /// No description provided for @chatBlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Block {name}?'**
  String chatBlockTitle(String name);

  /// No description provided for @chatBlockBody.
  ///
  /// In en, this message translates to:
  /// **'You won\'t see their messages anymore. You can undo this in settings.'**
  String get chatBlockBody;

  /// No description provided for @chatRules.
  ///
  /// In en, this message translates to:
  /// **'Please be respectful. Abuse, ads and sharing personal info are not allowed.'**
  String get chatRules;

  /// No description provided for @nicknameBlockedWord.
  ///
  /// In en, this message translates to:
  /// **'That nickname contains blocked words'**
  String get nicknameBlockedWord;

  /// No description provided for @nicknameTaken.
  ///
  /// In en, this message translates to:
  /// **'That nickname is already in use'**
  String get nicknameTaken;

  /// No description provided for @rankPopupTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Ranking'**
  String get rankPopupTitle;

  /// No description provided for @rankSuffix.
  ///
  /// In en, this message translates to:
  /// **'th'**
  String get rankSuffix;

  /// No description provided for @rankFirstCheck.
  ///
  /// In en, this message translates to:
  /// **'First ranking check — good luck!'**
  String get rankFirstCheck;

  /// No description provided for @rankUnchanged.
  ///
  /// In en, this message translates to:
  /// **'No change since last time'**
  String get rankUnchanged;

  /// No description provided for @rankChangedFromTo.
  ///
  /// In en, this message translates to:
  /// **'#{from} → #{to}'**
  String rankChangedFromTo(int from, int to);

  /// No description provided for @rankTopStreak.
  ///
  /// In en, this message translates to:
  /// **'Day {days} at #1 👑'**
  String rankTopStreak(int days);

  /// No description provided for @nicknameRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a nickname'**
  String get nicknameRequiredTitle;

  /// No description provided for @nicknameRequiredBody.
  ///
  /// In en, this message translates to:
  /// **'This is the name other collectors will see. You only set it once.'**
  String get nicknameRequiredBody;

  /// No description provided for @nicknameChangeTitle.
  ///
  /// In en, this message translates to:
  /// **'Change nickname'**
  String get nicknameChangeTitle;

  /// No description provided for @nicknameChangeBody.
  ///
  /// In en, this message translates to:
  /// **'Changing your nickname costs insect jelly. Proceed?'**
  String get nicknameChangeBody;

  /// No description provided for @nicknameChangeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get nicknameChangeConfirm;

  /// No description provided for @nicknameFallback.
  ///
  /// In en, this message translates to:
  /// **'Player'**
  String get nicknameFallback;

  /// No description provided for @battleServerFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t confirm the battle result. Check your connection'**
  String get battleServerFailed;

  /// No description provided for @updateRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Update required'**
  String get updateRequiredTitle;

  /// No description provided for @updateRequiredBody.
  ///
  /// In en, this message translates to:
  /// **'Please update to the latest version to keep playing.'**
  String get updateRequiredBody;

  /// No description provided for @updateAvailableTitle.
  ///
  /// In en, this message translates to:
  /// **'New version available'**
  String get updateAvailableTitle;

  /// No description provided for @updateAvailableBody.
  ///
  /// In en, this message translates to:
  /// **'An improved version is ready. Update now?'**
  String get updateAvailableBody;

  /// No description provided for @updateNow.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get updateNow;

  /// No description provided for @updateLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get updateLater;

  /// No description provided for @maintenanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Under maintenance'**
  String get maintenanceTitle;

  /// No description provided for @maintenanceBody.
  ///
  /// In en, this message translates to:
  /// **'The server is under maintenance. Please try again in a moment.'**
  String get maintenanceBody;

  /// No description provided for @connectionRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Connection required'**
  String get connectionRequiredTitle;

  /// No description provided for @connectionRequiredBody.
  ///
  /// In en, this message translates to:
  /// **'An internet connection is required to play. Check your network and try again.'**
  String get connectionRequiredBody;

  /// No description provided for @retryButton.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retryButton;

  /// No description provided for @accountSignInApple.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Apple'**
  String get accountSignInApple;

  /// No description provided for @termsOfUse.
  ///
  /// In en, this message translates to:
  /// **'Terms of Use'**
  String get termsOfUse;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @titleStartGuest.
  ///
  /// In en, this message translates to:
  /// **'Play as guest'**
  String get titleStartGuest;

  /// No description provided for @titleOr.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get titleOr;

  /// No description provided for @titleLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get titleLoading;

  /// No description provided for @guestNudgeTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in before you start?'**
  String get guestNudgeTitle;

  /// No description provided for @guestNudgeBody.
  ///
  /// In en, this message translates to:
  /// **'Without signing in, your progress and rank can\'t be restored if you change devices or delete the app. Sign in to keep the bugs and the rank you earn.'**
  String get guestNudgeBody;

  /// No description provided for @guestNudgeSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get guestNudgeSignIn;

  /// No description provided for @guestNudgeContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue as guest'**
  String get guestNudgeContinue;

  /// No description provided for @guestWarnTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re playing as a guest'**
  String get guestWarnTitle;

  /// No description provided for @guestWarnBody.
  ///
  /// In en, this message translates to:
  /// **'This is a temporary device account. If you delete the app or switch devices, your bugs and rank are gone. Sign in to keep them safe.'**
  String get guestWarnBody;

  /// No description provided for @titleStoreName.
  ///
  /// In en, this message translates to:
  /// **'Bug Champ'**
  String get titleStoreName;

  /// No description provided for @titleStoreTagline.
  ///
  /// In en, this message translates to:
  /// **'Idle Insect RPG'**
  String get titleStoreTagline;

  /// No description provided for @nicknameChangeCostHint.
  ///
  /// In en, this message translates to:
  /// **'Costs {cost} jelly to change'**
  String nicknameChangeCostHint(int cost);

  /// No description provided for @incubatorAdSkip.
  ///
  /// In en, this message translates to:
  /// **'⏩ Free {pct}% skip'**
  String incubatorAdSkip(int pct);

  /// No description provided for @incubatorAdSkipDone.
  ///
  /// In en, this message translates to:
  /// **'Hatching time reduced!'**
  String get incubatorAdSkipDone;

  /// No description provided for @nicknameEditAction.
  ///
  /// In en, this message translates to:
  /// **'Change nickname'**
  String get nicknameEditAction;

  /// No description provided for @nicknameEditActionCost.
  ///
  /// In en, this message translates to:
  /// **'Change for {cost} jelly'**
  String nicknameEditActionCost(int cost);

  /// No description provided for @notifHatchTitle.
  ///
  /// In en, this message translates to:
  /// **'Hatched!'**
  String get notifHatchTitle;

  /// No description provided for @notifHatchBody.
  ///
  /// In en, this message translates to:
  /// **'An egg has hatched. Check your collection.'**
  String get notifHatchBody;

  /// No description provided for @settingsNotify.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotify;

  /// No description provided for @notifyOfflineFull.
  ///
  /// In en, this message translates to:
  /// **'Offline rewards full'**
  String get notifyOfflineFull;

  /// No description provided for @notifyHatchDone.
  ///
  /// In en, this message translates to:
  /// **'Hatching complete'**
  String get notifyHatchDone;

  /// No description provided for @notifyDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily reward time'**
  String get notifyDaily;

  /// No description provided for @incubatorInstant.
  ///
  /// In en, this message translates to:
  /// **'Hatch now'**
  String get incubatorInstant;

  /// No description provided for @incubatorAdSkipBtn.
  ///
  /// In en, this message translates to:
  /// **'Skip for free'**
  String get incubatorAdSkipBtn;

  /// No description provided for @notifyAll.
  ///
  /// In en, this message translates to:
  /// **'Enable notifications'**
  String get notifyAll;

  /// No description provided for @notEnoughMaterials.
  ///
  /// In en, this message translates to:
  /// **'Not enough materials'**
  String get notEnoughMaterials;

  /// No description provided for @notifGiftTitle.
  ///
  /// In en, this message translates to:
  /// **'A gift arrived!'**
  String get notifGiftTitle;

  /// No description provided for @notifGiftBody.
  ///
  /// In en, this message translates to:
  /// **'Gifts are waiting. Claim them before they expire.'**
  String get notifGiftBody;

  /// No description provided for @notifyGift.
  ///
  /// In en, this message translates to:
  /// **'Surprise gifts'**
  String get notifyGift;

  /// No description provided for @notifyQuietHours.
  ///
  /// In en, this message translates to:
  /// **'Quiet hours (10 PM - 8 AM)'**
  String get notifyQuietHours;

  /// No description provided for @pvpTicketTitle.
  ///
  /// In en, this message translates to:
  /// **'Duel tickets'**
  String get pvpTicketTitle;

  /// No description provided for @pvpTicketCount.
  ///
  /// In en, this message translates to:
  /// **'{tickets}/{max}'**
  String pvpTicketCount(int tickets, int max);

  /// No description provided for @pvpTicketNextIn.
  ///
  /// In en, this message translates to:
  /// **'Next in {time}'**
  String pvpTicketNextIn(String time);

  /// No description provided for @pvpTicketFullLabel.
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get pvpTicketFullLabel;

  /// No description provided for @pvpTicketNone.
  ///
  /// In en, this message translates to:
  /// **'You need a duel ticket to fight. Charge one below.'**
  String get pvpTicketNone;

  /// No description provided for @pvpTicketAdBtn.
  ///
  /// In en, this message translates to:
  /// **'Free refill +{amount}'**
  String pvpTicketAdBtn(int amount);

  /// No description provided for @pvpTicketAdLeft.
  ///
  /// In en, this message translates to:
  /// **'{used}/{limit} today'**
  String pvpTicketAdLeft(int used, int limit);

  /// No description provided for @pvpTicketJellyBtn.
  ///
  /// In en, this message translates to:
  /// **'Refill for {cost} jelly'**
  String pvpTicketJellyBtn(int cost);

  /// No description provided for @pvpTicketCharged.
  ///
  /// In en, this message translates to:
  /// **'Tickets +{amount}'**
  String pvpTicketCharged(int amount);

  /// No description provided for @pvpTicketFilled.
  ///
  /// In en, this message translates to:
  /// **'Tickets filled up'**
  String get pvpTicketFilled;

  /// No description provided for @pvpTicketAlreadyFull.
  ///
  /// In en, this message translates to:
  /// **'Tickets are already full'**
  String get pvpTicketAlreadyFull;

  /// No description provided for @pvpTicketChargeFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not charge tickets. Try again in a moment.'**
  String get pvpTicketChargeFailed;

  /// No description provided for @pvpTicketWhy.
  ///
  /// In en, this message translates to:
  /// **'Tickets keep the trophy ranking about strength, not how many matches you grind.'**
  String get pvpTicketWhy;

  /// No description provided for @adDailyLimit.
  ///
  /// In en, this message translates to:
  /// **'Today\'s free rewards are used up ({limit}/day)'**
  String adDailyLimit(int limit);

  /// No description provided for @noticeTitle.
  ///
  /// In en, this message translates to:
  /// **'Notices'**
  String get noticeTitle;

  /// No description provided for @noticeEmpty.
  ///
  /// In en, this message translates to:
  /// **'No notices right now.'**
  String get noticeEmpty;

  /// No description provided for @noticeFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load notices. Check your connection.'**
  String get noticeFailed;

  /// No description provided for @mailNoticeSection.
  ///
  /// In en, this message translates to:
  /// **'From the team'**
  String get mailNoticeSection;

  /// No description provided for @mailClaim.
  ///
  /// In en, this message translates to:
  /// **'Claim'**
  String get mailClaim;

  /// No description provided for @giftCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Gift code'**
  String get giftCodeTitle;

  /// No description provided for @giftCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a code from an event or announcement.'**
  String get giftCodeHint;

  /// No description provided for @giftCodeField.
  ///
  /// In en, this message translates to:
  /// **'CODE'**
  String get giftCodeField;

  /// No description provided for @giftCodeSubmit.
  ///
  /// In en, this message translates to:
  /// **'Redeem'**
  String get giftCodeSubmit;

  /// No description provided for @giftCodeChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get giftCodeChecking;

  /// No description provided for @giftCodeOk.
  ///
  /// In en, this message translates to:
  /// **'Rewards claimed!'**
  String get giftCodeOk;

  /// No description provided for @giftCodeBad.
  ///
  /// In en, this message translates to:
  /// **'That code doesn\'t exist'**
  String get giftCodeBad;

  /// No description provided for @giftCodeExpired.
  ///
  /// In en, this message translates to:
  /// **'That code has expired'**
  String get giftCodeExpired;

  /// No description provided for @giftCodeExhausted.
  ///
  /// In en, this message translates to:
  /// **'That code has run out'**
  String get giftCodeExhausted;

  /// No description provided for @giftCodeUsed.
  ///
  /// In en, this message translates to:
  /// **'You\'ve already used this'**
  String get giftCodeUsed;

  /// No description provided for @giftCodeFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach the server. Try again in a moment.'**
  String get giftCodeFailed;

  /// No description provided for @reviewAction.
  ///
  /// In en, this message translates to:
  /// **'Rate the game'**
  String get reviewAction;

  /// No description provided for @chatAdminBadge.
  ///
  /// In en, this message translates to:
  /// **'STAFF'**
  String get chatAdminBadge;

  /// No description provided for @autoEquip.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get autoEquip;

  /// No description provided for @autoEquipDone.
  ///
  /// In en, this message translates to:
  /// **'Equipped your strongest bugs'**
  String get autoEquipDone;

  /// No description provided for @autoEquipAlready.
  ///
  /// In en, this message translates to:
  /// **'Already the best line-up'**
  String get autoEquipAlready;

  /// No description provided for @autoTeam.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get autoTeam;

  /// No description provided for @autoTeamDone.
  ///
  /// In en, this message translates to:
  /// **'Picked your strongest team'**
  String get autoTeamDone;

  /// No description provided for @autoTeamAlready.
  ///
  /// In en, this message translates to:
  /// **'Already the best team'**
  String get autoTeamAlready;

  /// No description provided for @teamPower.
  ///
  /// In en, this message translates to:
  /// **'Team power {power}'**
  String teamPower(String power);

  /// No description provided for @navCharacter.
  ///
  /// In en, this message translates to:
  /// **'Character'**
  String get navCharacter;

  /// No description provided for @slotTool.
  ///
  /// In en, this message translates to:
  /// **'Tool'**
  String get slotTool;

  /// No description provided for @slotHat.
  ///
  /// In en, this message translates to:
  /// **'Hat'**
  String get slotHat;

  /// No description provided for @slotTop.
  ///
  /// In en, this message translates to:
  /// **'Top'**
  String get slotTop;

  /// No description provided for @slotBottom.
  ///
  /// In en, this message translates to:
  /// **'Legwear'**
  String get slotBottom;

  /// No description provided for @slotShoes.
  ///
  /// In en, this message translates to:
  /// **'Boots'**
  String get slotShoes;

  /// No description provided for @slotNecklace.
  ///
  /// In en, this message translates to:
  /// **'Necklace'**
  String get slotNecklace;

  /// No description provided for @slotRing.
  ///
  /// In en, this message translates to:
  /// **'Ring'**
  String get slotRing;

  /// No description provided for @slotBox.
  ///
  /// In en, this message translates to:
  /// **'Case'**
  String get slotBox;

  /// No description provided for @optAttack.
  ///
  /// In en, this message translates to:
  /// **'Attack'**
  String get optAttack;

  /// No description provided for @optAttackSpeed.
  ///
  /// In en, this message translates to:
  /// **'Attack Speed'**
  String get optAttackSpeed;

  /// No description provided for @optCritChance.
  ///
  /// In en, this message translates to:
  /// **'Crit Chance'**
  String get optCritChance;

  /// No description provided for @optCritDamage.
  ///
  /// In en, this message translates to:
  /// **'Crit Damage'**
  String get optCritDamage;

  /// No description provided for @optMaxHp.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get optMaxHp;

  /// No description provided for @optDefense.
  ///
  /// In en, this message translates to:
  /// **'Defense'**
  String get optDefense;

  /// No description provided for @optGold.
  ///
  /// In en, this message translates to:
  /// **'Gold Gain'**
  String get optGold;

  /// No description provided for @optMaterial.
  ///
  /// In en, this message translates to:
  /// **'Material Gain'**
  String get optMaterial;

  /// No description provided for @optBugFind.
  ///
  /// In en, this message translates to:
  /// **'Bug Find'**
  String get optBugFind;

  /// No description provided for @optBossDamage.
  ///
  /// In en, this message translates to:
  /// **'Boss Damage'**
  String get optBossDamage;

  /// No description provided for @optSkillDamage.
  ///
  /// In en, this message translates to:
  /// **'Skill Damage'**
  String get optSkillDamage;

  /// No description provided for @optSkillCooldown.
  ///
  /// In en, this message translates to:
  /// **'Skill Cooldown'**
  String get optSkillCooldown;

  /// No description provided for @optBoost.
  ///
  /// In en, this message translates to:
  /// **'Tap Boost'**
  String get optBoost;

  /// No description provided for @optOffline.
  ///
  /// In en, this message translates to:
  /// **'Idle Efficiency'**
  String get optOffline;

  /// No description provided for @optPet.
  ///
  /// In en, this message translates to:
  /// **'Pet Power'**
  String get optPet;

  /// No description provided for @charEquipment.
  ///
  /// In en, this message translates to:
  /// **'Equipment'**
  String get charEquipment;

  /// No description provided for @charPets.
  ///
  /// In en, this message translates to:
  /// **'Pets'**
  String get charPets;

  /// No description provided for @charSkills.
  ///
  /// In en, this message translates to:
  /// **'Skills'**
  String get charSkills;

  /// No description provided for @charPower.
  ///
  /// In en, this message translates to:
  /// **'Power'**
  String get charPower;

  /// No description provided for @charEmptySlot.
  ///
  /// In en, this message translates to:
  /// **'Empty'**
  String get charEmptySlot;

  /// No description provided for @forgeTitle.
  ///
  /// In en, this message translates to:
  /// **'Workshop'**
  String get forgeTitle;

  /// No description provided for @forgeHammer.
  ///
  /// In en, this message translates to:
  /// **'Forge'**
  String get forgeHammer;

  /// No description provided for @forgeAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto forge'**
  String get forgeAuto;

  /// No description provided for @forgeResultKeep.
  ///
  /// In en, this message translates to:
  /// **'Equip'**
  String get forgeResultKeep;

  /// No description provided for @forgeResultDrop.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get forgeResultDrop;

  /// No description provided for @forgeCurrent.
  ///
  /// In en, this message translates to:
  /// **'Equipped'**
  String get forgeCurrent;

  /// No description provided for @forgeNoFossil.
  ///
  /// In en, this message translates to:
  /// **'No fossil shards'**
  String get forgeNoFossil;

  /// No description provided for @forgeLevel.
  ///
  /// In en, this message translates to:
  /// **'Workshop Lv.{lv}'**
  String forgeLevel(int lv);

  /// No description provided for @forgeStep.
  ///
  /// In en, this message translates to:
  /// **'Workshop upgrade {cur}/{max}'**
  String forgeStep(int cur, int max);

  /// No description provided for @forgeUpgrading.
  ///
  /// In en, this message translates to:
  /// **'Upgrading'**
  String get forgeUpgrading;

  /// No description provided for @forgeReady.
  ///
  /// In en, this message translates to:
  /// **'Done!'**
  String get forgeReady;

  /// No description provided for @forgeRush.
  ///
  /// In en, this message translates to:
  /// **'Finish now'**
  String get forgeRush;

  /// No description provided for @forgeClaim.
  ///
  /// In en, this message translates to:
  /// **'Claim'**
  String get forgeClaim;

  /// No description provided for @forgeNext.
  ///
  /// In en, this message translates to:
  /// **'Next level odds'**
  String get forgeNext;

  /// No description provided for @forgeMaxLevel.
  ///
  /// In en, this message translates to:
  /// **'Max level'**
  String get forgeMaxLevel;

  /// No description provided for @forgeAutoTarget.
  ///
  /// In en, this message translates to:
  /// **'Wanted options'**
  String get forgeAutoTarget;

  /// No description provided for @forgeStopOnHit.
  ///
  /// In en, this message translates to:
  /// **'Stop when found'**
  String get forgeStopOnHit;

  /// No description provided for @skillLearn.
  ///
  /// In en, this message translates to:
  /// **'Learn'**
  String get skillLearn;

  /// No description provided for @skillLevelUp.
  ///
  /// In en, this message translates to:
  /// **'Lv.{lv} → {next}'**
  String skillLevelUp(int lv, int next);

  /// No description provided for @skillEquipped.
  ///
  /// In en, this message translates to:
  /// **'Equipped'**
  String get skillEquipped;

  /// No description provided for @skillSlotsFull.
  ///
  /// In en, this message translates to:
  /// **'Skill slots are full'**
  String get skillSlotsFull;

  /// No description provided for @charTabStats.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get charTabStats;

  /// No description provided for @charTabPets.
  ///
  /// In en, this message translates to:
  /// **'Pets'**
  String get charTabPets;

  /// No description provided for @charTabSkills.
  ///
  /// In en, this message translates to:
  /// **'Skills'**
  String get charTabSkills;

  /// No description provided for @forgeGradeButton.
  ///
  /// In en, this message translates to:
  /// **'Workshop grade'**
  String get forgeGradeButton;

  /// No description provided for @statHp.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get statHp;

  /// No description provided for @statGoldGain.
  ///
  /// In en, this message translates to:
  /// **'Gold Gain'**
  String get statGoldGain;

  /// No description provided for @statMaterialGain.
  ///
  /// In en, this message translates to:
  /// **'Material Gain'**
  String get statMaterialGain;

  /// No description provided for @statBugFind.
  ///
  /// In en, this message translates to:
  /// **'Bug Find'**
  String get statBugFind;

  /// No description provided for @charNoPet.
  ///
  /// In en, this message translates to:
  /// **'No pet'**
  String get charNoPet;

  /// No description provided for @charPetHint.
  ///
  /// In en, this message translates to:
  /// **'Manage pets in the collection box'**
  String get charPetHint;

  /// No description provided for @forgeAutoShort.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get forgeAutoShort;

  /// No description provided for @forgeStackFull.
  ///
  /// In en, this message translates to:
  /// **'The anvil is full'**
  String get forgeStackFull;

  /// No description provided for @forgeStackHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to open'**
  String get forgeStackHint;

  /// No description provided for @sceneCatchTap.
  ///
  /// In en, this message translates to:
  /// **'Tap now!'**
  String get sceneCatchTap;

  /// No description provided for @forgeResultNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get forgeResultNew;

  /// No description provided for @forgeFilter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get forgeFilter;

  /// No description provided for @forgeFilterHint.
  ///
  /// In en, this message translates to:
  /// **'Only results with at least one checked stat are kept.'**
  String get forgeFilterHint;

  /// No description provided for @forgeFiltered.
  ///
  /// In en, this message translates to:
  /// **'Discarded — no matching stat'**
  String get forgeFiltered;

  /// No description provided for @elementWheelTitle.
  ///
  /// In en, this message translates to:
  /// **'Elemental Chart'**
  String get elementWheelTitle;

  /// No description provided for @elementWheelRestrain.
  ///
  /// In en, this message translates to:
  /// **'Overcome — 1.5x damage when you hit whoever the red arrow points at'**
  String get elementWheelRestrain;

  /// No description provided for @elementWheelGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate — +10% team attack and healing when the slot right before points at you with a green arrow'**
  String get elementWheelGenerate;

  /// No description provided for @traitNoneBadge.
  ///
  /// In en, this message translates to:
  /// **'No trait'**
  String get traitNoneBadge;

  /// No description provided for @elementWheelHint.
  ///
  /// In en, this message translates to:
  /// **'Order your team along the green arrows. Wood > Fire > Earth is two links, so +20%.'**
  String get elementWheelHint;

  /// No description provided for @leagueRewardListTitle.
  ///
  /// In en, this message translates to:
  /// **'First-time reward (once per rank)'**
  String get leagueRewardListTitle;

  /// No description provided for @sideMine.
  ///
  /// In en, this message translates to:
  /// **'YOU'**
  String get sideMine;

  /// No description provided for @sideFoe.
  ///
  /// In en, this message translates to:
  /// **'FOE'**
  String get sideFoe;

  /// No description provided for @battleStarting.
  ///
  /// In en, this message translates to:
  /// **'Battle start!'**
  String get battleStarting;

  /// No description provided for @sideMineTeam.
  ///
  /// In en, this message translates to:
  /// **'My team'**
  String get sideMineTeam;

  /// No description provided for @sideFoeTeam.
  ///
  /// In en, this message translates to:
  /// **'Opponent'**
  String get sideFoeTeam;

  /// No description provided for @leagueNeedTrophy.
  ///
  /// In en, this message translates to:
  /// **'{n} trophies'**
  String leagueNeedTrophy(int n);

  /// No description provided for @seasonRewardNow.
  ///
  /// In en, this message translates to:
  /// **'Season reward · now {league}'**
  String seasonRewardNow(String league);

  /// No description provided for @seasonRewardHint.
  ///
  /// In en, this message translates to:
  /// **'Paid every Monday 09:00 at your rank at that moment. Climb before it ends.'**
  String get seasonRewardHint;

  /// No description provided for @eventOpensOn.
  ///
  /// In en, this message translates to:
  /// **'Opens on {m}/{d}'**
  String eventOpensOn(String m, String d);

  /// No description provided for @eventOpensInDays.
  ///
  /// In en, this message translates to:
  /// **'D-{n}'**
  String eventOpensInDays(int n);

  /// No description provided for @eventOpensInHours.
  ///
  /// In en, this message translates to:
  /// **'Starts in {n}h'**
  String eventOpensInHours(int n);

  /// No description provided for @eventOpensInMinutes.
  ///
  /// In en, this message translates to:
  /// **'Starts in {n}m'**
  String eventOpensInMinutes(int n);

  /// No description provided for @eventSeeFlyer.
  ///
  /// In en, this message translates to:
  /// **'See the flyer'**
  String get eventSeeFlyer;

  /// No description provided for @eventSoonBanner.
  ///
  /// In en, this message translates to:
  /// **'Bug King Championship · opens {when}'**
  String eventSoonBanner(String when);

  /// No description provided for @eventFlyerPrizeTag.
  ///
  /// In en, this message translates to:
  /// **'1st place prize'**
  String get eventFlyerPrizeTag;

  /// No description provided for @adCooldown.
  ///
  /// In en, this message translates to:
  /// **'Next ad available in {n}s'**
  String adCooldown(int n);

  /// No description provided for @jellyContinueTitle.
  ///
  /// In en, this message translates to:
  /// **'Spend jelly'**
  String get jellyContinueTitle;

  /// No description provided for @jellyContinueAsk.
  ///
  /// In en, this message translates to:
  /// **'Today\'s free uses are gone. Continue for {n} jelly?'**
  String jellyContinueAsk(int n);

  /// No description provided for @jellyContinueYes.
  ///
  /// In en, this message translates to:
  /// **'Use jelly'**
  String get jellyContinueYes;

  /// No description provided for @giftDoubleCapTitle.
  ///
  /// In en, this message translates to:
  /// **'Free double already used today'**
  String get giftDoubleCapTitle;

  /// No description provided for @giftDoubleCapBody.
  ///
  /// In en, this message translates to:
  /// **'With a Pass, every gift stays doubled\nand gets claimed automatically.'**
  String get giftDoubleCapBody;

  /// No description provided for @exchangeTitle.
  ///
  /// In en, this message translates to:
  /// **'Exchange'**
  String get exchangeTitle;

  /// No description provided for @exchangeHint.
  ///
  /// In en, this message translates to:
  /// **'Trade jelly for one hour of idle output at your stage'**
  String get exchangeHint;

  /// No description provided for @exchangeToGold.
  ///
  /// In en, this message translates to:
  /// **'To gold'**
  String get exchangeToGold;

  /// No description provided for @exchangeToMaterial.
  ///
  /// In en, this message translates to:
  /// **'To materials'**
  String get exchangeToMaterial;

  /// No description provided for @exchangeCost.
  ///
  /// In en, this message translates to:
  /// **'{n} jelly'**
  String exchangeCost(int n);

  /// No description provided for @exchangeGetGold.
  ///
  /// In en, this message translates to:
  /// **'Get {amount} gold'**
  String exchangeGetGold(String amount);

  /// No description provided for @exchangeGetMaterial.
  ///
  /// In en, this message translates to:
  /// **'Get {amount} of each material'**
  String exchangeGetMaterial(String amount);

  /// No description provided for @exchangeDone.
  ///
  /// In en, this message translates to:
  /// **'Exchanged!'**
  String get exchangeDone;

  /// No description provided for @curJelly.
  ///
  /// In en, this message translates to:
  /// **'Jelly'**
  String get curJelly;

  /// No description provided for @exchangeHoldings.
  ///
  /// In en, this message translates to:
  /// **'Your holdings'**
  String get exchangeHoldings;

  /// No description provided for @elementGuideBtn.
  ///
  /// In en, this message translates to:
  /// **'Element chart'**
  String get elementGuideBtn;

  /// No description provided for @giftAdMoreFreeLine.
  ///
  /// In en, this message translates to:
  /// **'Free double: once a day!'**
  String get giftAdMoreFreeLine;

  /// No description provided for @giftAdMorePassLine.
  ///
  /// In en, this message translates to:
  /// **'With a Pass, every gift is doubled'**
  String get giftAdMorePassLine;

  /// No description provided for @giftGoPassBtn.
  ///
  /// In en, this message translates to:
  /// **'See the Pass'**
  String get giftGoPassBtn;

  /// No description provided for @eventLegalTitle.
  ///
  /// In en, this message translates to:
  /// **'Contest terms'**
  String get eventLegalTitle;

  /// No description provided for @eventLegalHost.
  ///
  /// In en, this message translates to:
  /// **'This contest is hosted and run by the Bug Champ team (the developer), who is solely responsible for providing and shipping the prize.'**
  String get eventLegalHost;

  /// No description provided for @eventLegalStores.
  ///
  /// In en, this message translates to:
  /// **'Apple and Google are not sponsors of this contest and are not involved in any way.'**
  String get eventLegalStores;

  /// No description provided for @eventLegalPrize.
  ///
  /// In en, this message translates to:
  /// **'Rankings are finalized at the end of the contest. The winner will be contacted in-app about prize delivery (a shipping address may be requested). No purchase is necessary to participate or win.'**
  String get eventLegalPrize;

  /// No description provided for @eventLegalFair.
  ///
  /// In en, this message translates to:
  /// **'Entries involving cheating (tampered data or abnormal access) may be excluded from rankings and prizes.'**
  String get eventLegalFair;

  /// No description provided for @giftBuyPassBtn.
  ///
  /// In en, this message translates to:
  /// **'Buy the Pass'**
  String get giftBuyPassBtn;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
