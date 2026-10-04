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

  /// No description provided for @scoutRefreshFree.
  ///
  /// In en, this message translates to:
  /// **'Refresh (free)'**
  String get scoutRefreshFree;

  /// No description provided for @scoutRefreshJelly.
  ///
  /// In en, this message translates to:
  /// **'Refresh ({n} jelly)'**
  String scoutRefreshJelly(int n);

  /// No description provided for @scoutRefreshDone.
  ///
  /// In en, this message translates to:
  /// **'No refreshes left'**
  String get scoutRefreshDone;

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
  /// **'Throw'**
  String get modeManual;

  /// No description provided for @modeAuto.
  ///
  /// In en, this message translates to:
  /// **'Quick'**
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
  /// **'Confirming your payment. It will be granted automatically. If it hasn\'t arrived in a few minutes, tap Restore purchases in the shop'**
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

  /// No description provided for @leaderboardUnranked.
  ///
  /// In en, this message translates to:
  /// **'Unranked'**
  String get leaderboardUnranked;

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

  /// No description provided for @offlineBugs.
  ///
  /// In en, this message translates to:
  /// **'🥚 Collected {count} bug eggs'**
  String offlineBugs(int count);

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

  /// No description provided for @durationH.
  ///
  /// In en, this message translates to:
  /// **'{h}h'**
  String durationH(int h);

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

  /// No description provided for @zoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Hunting Ground {n}'**
  String zoneLabel(int n);

  /// No description provided for @zoneFinalLabel.
  ///
  /// In en, this message translates to:
  /// **'Final Ground'**
  String get zoneFinalLabel;

  /// No description provided for @bossChallenge.
  ///
  /// In en, this message translates to:
  /// **'Challenge Boss'**
  String get bossChallenge;

  /// No description provided for @bossChallengeLocked.
  ///
  /// In en, this message translates to:
  /// **'{n} more kills to challenge'**
  String bossChallengeLocked(int n);

  /// No description provided for @bossChallengeFailed.
  ///
  /// In en, this message translates to:
  /// **'The boss pushed you back. Grow stronger and try again'**
  String get bossChallengeFailed;

  /// Boss fight - retreat button
  ///
  /// In en, this message translates to:
  /// **'Flee'**
  String get bossFlee;

  /// Flee confirm dialog title
  ///
  /// In en, this message translates to:
  /// **'Flee the boss?'**
  String get bossFleeTitle;

  /// Flee confirm dialog body
  ///
  /// In en, this message translates to:
  /// **'Your hunting ground gauge resets.\nSame as being defeated.'**
  String get bossFleeDesc;

  /// Toast right after fleeing
  ///
  /// In en, this message translates to:
  /// **'Fled - gauge reset'**
  String get bossFled;

  /// No description provided for @zoneKillsLabel.
  ///
  /// In en, this message translates to:
  /// **'Kills {n}/{m}'**
  String zoneKillsLabel(int n, int m);

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

  /// No description provided for @dexVariant.
  ///
  /// In en, this message translates to:
  /// **'Variant'**
  String get dexVariant;

  /// No description provided for @dexComplete.
  ///
  /// In en, this message translates to:
  /// **'This species is complete'**
  String get dexComplete;

  /// No description provided for @dexCompleteShort.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get dexCompleteShort;

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

  /// No description provided for @dexConquerNeed.
  ///
  /// In en, this message translates to:
  /// **'Needs Lv{need} (now {now})'**
  String dexConquerNeed(int need, int now);

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

  /// No description provided for @dexTabBugs.
  ///
  /// In en, this message translates to:
  /// **'Bugs'**
  String get dexTabBugs;

  /// No description provided for @dexTabBosses.
  ///
  /// In en, this message translates to:
  /// **'Bosses'**
  String get dexTabBosses;

  /// No description provided for @dexBosses.
  ///
  /// In en, this message translates to:
  /// **'Bosses'**
  String get dexBosses;

  /// No description provided for @dexBossNotFound.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t defeated this boss yet. Beat it in this difficulty\'s hunting ground to record it.'**
  String get dexBossNotFound;

  /// No description provided for @dexBossHint.
  ///
  /// In en, this message translates to:
  /// **'Each difficulty counts separately. Beating one after moving down still counts.'**
  String get dexBossHint;

  /// No description provided for @dexClaimedFossil.
  ///
  /// In en, this message translates to:
  /// **'Plus {fossil} fossils'**
  String dexClaimedFossil(Object fossil);

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
  /// **'Wave {n} cleared!\nChoose one'**
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
  /// **'When HP runs out, get back up once at 50% HP and retry the same wave'**
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
  /// **'Enter with your single best-raised adult bug'**
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
  /// **'Your bug fights **as raised** — potential, part upgrades, training and drills all count (same stats as Duels)'**
  String get eventFlyerRule1;

  /// No description provided for @eventFlyerRule2.
  ///
  /// In en, this message translates to:
  /// **'Enemy elements change every wave — waves your bug is weak to are the hard ones'**
  String get eventFlyerRule2;

  /// No description provided for @eventFlyerRule3.
  ///
  /// In en, this message translates to:
  /// **'Your bug gets injured and must rest in the recovery room — jelly heals it instantly'**
  String get eventFlyerRule3;

  /// No description provided for @eventFlyerRule4.
  ///
  /// In en, this message translates to:
  /// **'You get {daily} tickets every morning, and can top up with {jelly} jelly each, up to {extra} more per day'**
  String eventFlyerRule4(int daily, int jelly, int extra);

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

  /// No description provided for @battleNeedServer.
  ///
  /// In en, this message translates to:
  /// **'Duels need an online connection'**
  String get battleNeedServer;

  /// No description provided for @eventQuitFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t quit — check your connection and try again'**
  String get eventQuitFailed;

  /// No description provided for @eventBugUnavailable.
  ///
  /// In en, this message translates to:
  /// **'That bug can\'t enter — please pick another one'**
  String get eventBugUnavailable;

  /// No description provided for @injuryHealConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Heal now'**
  String get injuryHealConfirmTitle;

  /// No description provided for @injuryHealConfirm.
  ///
  /// In en, this message translates to:
  /// **'Spend {n} Jelly to heal now?'**
  String injuryHealConfirm(int n);

  /// No description provided for @trainingInstantTitle.
  ///
  /// In en, this message translates to:
  /// **'Finish training now'**
  String get trainingInstantTitle;

  /// No description provided for @squadTrainingBadge.
  ///
  /// In en, this message translates to:
  /// **'Training'**
  String get squadTrainingBadge;

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
  String eventWaveRecord(String n);

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
  /// **'Pick 1 bug to enter'**
  String get eventPickTeam;

  /// No description provided for @eventPickOrder.
  ///
  /// In en, this message translates to:
  /// **'Face enemies one after another · throw gauge every bout · HP is your life'**
  String get eventPickOrder;

  /// No description provided for @eventNormalizeTitle.
  ///
  /// In en, this message translates to:
  /// **'The better you raise it, the stronger it is'**
  String get eventNormalizeTitle;

  /// No description provided for @eventNormalizeBody.
  ///
  /// In en, this message translates to:
  /// **'Fights with the same stats as Duels — potential, part upgrades, training, drills and traits all count. Losing by ring-out or flip costs {pct}% HP and you retry the same wave. When HP runs out, the run ends.'**
  String eventNormalizeBody(int pct);

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

  /// No description provided for @eventJellyTicket.
  ///
  /// In en, this message translates to:
  /// **'Buy ticket'**
  String get eventJellyTicket;

  /// No description provided for @eventNoJelly.
  ///
  /// In en, this message translates to:
  /// **'Not enough jelly'**
  String get eventNoJelly;

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

  /// No description provided for @eventLeadStrong.
  ///
  /// In en, this message translates to:
  /// **'Strong'**
  String get eventLeadStrong;

  /// No description provided for @eventLeadWeak.
  ///
  /// In en, this message translates to:
  /// **'Weak'**
  String get eventLeadWeak;

  /// No description provided for @eventTicketBought.
  ///
  /// In en, this message translates to:
  /// **'Charged {n} entry ticket(s)'**
  String eventTicketBought(int n);

  /// No description provided for @eventTicketDaily.
  ///
  /// In en, this message translates to:
  /// **'today {used}/{max}'**
  String eventTicketDaily(int used, int max);

  /// No description provided for @eventStopWipe.
  ///
  /// In en, this message translates to:
  /// **'Your team was wiped out, so the run ends here.'**
  String get eventStopWipe;

  /// No description provided for @eventStopJudge.
  ///
  /// In en, this message translates to:
  /// **'Round 20 passed, so the wave was decided on remaining HP and you came up short. The run ends here even with bugs still standing.'**
  String get eventStopJudge;

  /// No description provided for @eventStopMax.
  ///
  /// In en, this message translates to:
  /// **'You cleared every wave to the last one!'**
  String get eventStopMax;

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

  /// No description provided for @giftDoubledMult.
  ///
  /// In en, this message translates to:
  /// **'Reward x{n}!'**
  String giftDoubledMult(String n);

  /// No description provided for @giftAdMoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Today\'s free double!'**
  String get giftAdMoreTitle;

  /// No description provided for @giftAdMoreBody.
  ///
  /// In en, this message translates to:
  /// **'Take this gift at double value.'**
  String get giftAdMoreBody;

  /// No description provided for @giftAdMoreYes.
  ///
  /// In en, this message translates to:
  /// **'Claim double'**
  String get giftAdMoreYes;

  /// No description provided for @giftAdMoreLater.
  ///
  /// In en, this message translates to:
  /// **'Claim as is'**
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

  /// No description provided for @synthConfirm.
  ///
  /// In en, this message translates to:
  /// **'These bugs will be consumed'**
  String get synthConfirm;

  /// No description provided for @synthConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm fusion'**
  String get synthConfirmTitle;

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

  /// No description provided for @incubatorCollectAll.
  ///
  /// In en, this message translates to:
  /// **'Collect all ({n})'**
  String incubatorCollectAll(int n);

  /// No description provided for @incubatorCollectAllDone.
  ///
  /// In en, this message translates to:
  /// **'Collected {n} bugs'**
  String incubatorCollectAllDone(int n);

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

  /// No description provided for @disassembleConfirm.
  ///
  /// In en, this message translates to:
  /// **'This bug is hard to get back. Disassemble it?'**
  String get disassembleConfirm;

  /// No description provided for @disassembleAction.
  ///
  /// In en, this message translates to:
  /// **'Disassemble'**
  String get disassembleAction;

  /// No description provided for @incubatingLabel.
  ///
  /// In en, this message translates to:
  /// **'Incubating'**
  String get incubatingLabel;

  /// No description provided for @disassembleSnack.
  ///
  /// In en, this message translates to:
  /// **'Disassembled'**
  String get disassembleSnack;

  /// No description provided for @disassembleEquipped.
  ///
  /// In en, this message translates to:
  /// **'Equipped bugs cannot be disassembled'**
  String get disassembleEquipped;

  /// No description provided for @disassembleIncubating.
  ///
  /// In en, this message translates to:
  /// **'Eggs in the incubator cannot be disassembled'**
  String get disassembleIncubating;

  /// No description provided for @disassembleFailed.
  ///
  /// In en, this message translates to:
  /// **'Cannot disassemble'**
  String get disassembleFailed;

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

  /// No description provided for @missionForgeItems.
  ///
  /// In en, this message translates to:
  /// **'Forge Gear'**
  String get missionForgeItems;

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
  /// **'Recover a share of max HP every second. Lets you outlast hits.'**
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

  /// No description provided for @nicknameSameName.
  ///
  /// In en, this message translates to:
  /// **'Please pick a name different from your current one.'**
  String get nicknameSameName;

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

  /// No description provided for @buffCooldownAsk.
  ///
  /// In en, this message translates to:
  /// **'Next free activation in {t}.\nActivate now for {n} jelly?'**
  String buffCooldownAsk(String t, int n);

  /// No description provided for @buffBtnFreeLeft.
  ///
  /// In en, this message translates to:
  /// **'Free in {t}'**
  String buffBtnFreeLeft(String t);

  /// No description provided for @buffBtnJelly.
  ///
  /// In en, this message translates to:
  /// **'Use {n}'**
  String buffBtnJelly(int n);

  /// No description provided for @buffBtnPassLeft.
  ///
  /// In en, this message translates to:
  /// **'Pass: {n}d left'**
  String buffBtnPassLeft(int n);

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// No description provided for @eventRewardTitleAward.
  ///
  /// In en, this message translates to:
  /// **'Title “{name}”'**
  String eventRewardTitleAward(String name);

  /// No description provided for @stanceCycle.
  ///
  /// In en, this message translates to:
  /// **'ATK › HEAL › DEF › ATK'**
  String get stanceCycle;

  /// No description provided for @tierClearTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} difficulty cleared!'**
  String tierClearTitle(String name);

  /// No description provided for @tierNextTitle.
  ///
  /// In en, this message translates to:
  /// **'Entering {name} difficulty'**
  String tierNextTitle(String name);

  /// No description provided for @tierNextBody.
  ///
  /// In en, this message translates to:
  /// **'Stage, level, upgrades, gold and materials reset to the beginning.\n\nBugs, gear, the dex, jelly and skills all stay with you.\n\nRankings sort by difficulty first - moving up puts you above lower tiers even at a low level.\n\nMonsters get much stronger.'**
  String get tierNextBody;

  /// No description provided for @tierNextGo.
  ///
  /// In en, this message translates to:
  /// **'Enter'**
  String get tierNextGo;

  /// No description provided for @tierStayHere.
  ///
  /// In en, this message translates to:
  /// **'Stay a while'**
  String get tierStayHere;

  /// No description provided for @tierAllClear.
  ///
  /// In en, this message translates to:
  /// **'You conquered every difficulty. A true entomologist!'**
  String get tierAllClear;

  /// No description provided for @tierEasy.
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get tierEasy;

  /// No description provided for @tierNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get tierNormal;

  /// No description provided for @tierHard.
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get tierHard;

  /// No description provided for @tierExtreme.
  ///
  /// In en, this message translates to:
  /// **'Extreme'**
  String get tierExtreme;

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

  /// No description provided for @sessionTakenTitle.
  ///
  /// In en, this message translates to:
  /// **'Playing on another device'**
  String get sessionTakenTitle;

  /// No description provided for @sessionTakenBody.
  ///
  /// In en, this message translates to:
  /// **'This account was opened on another device.\nContinue here to load the progress from that device.'**
  String get sessionTakenBody;

  /// No description provided for @sessionTakenContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue on this device'**
  String get sessionTakenContinue;

  /// No description provided for @sessionTakenFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load. Please try again in a moment.'**
  String get sessionTakenFailed;

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

  /// No description provided for @renameForcedTitle.
  ///
  /// In en, this message translates to:
  /// **'Please change your nickname'**
  String get renameForcedTitle;

  /// No description provided for @renameForcedBody.
  ///
  /// In en, this message translates to:
  /// **'An operator asked you to change your nickname.\nIt is shown to other players, so it must follow the rules.\nThis change is free.'**
  String get renameForcedBody;

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

  /// No description provided for @mailClaimAll.
  ///
  /// In en, this message translates to:
  /// **'Claim all'**
  String get mailClaimAll;

  /// No description provided for @mailReadMore.
  ///
  /// In en, this message translates to:
  /// **'Read more'**
  String get mailReadMore;

  /// No description provided for @mailConfirm.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get mailConfirm;

  /// No description provided for @gachaTitle.
  ///
  /// In en, this message translates to:
  /// **'Egg Draw'**
  String get gachaTitle;

  /// No description provided for @gachaDesc.
  ///
  /// In en, this message translates to:
  /// **'Potential 3★+ guaranteed (wild never gives 5★) · 10x variant odds'**
  String get gachaDesc;

  /// No description provided for @gachaPityLeft.
  ///
  /// In en, this message translates to:
  /// **'Legendary guaranteed within {n} draws'**
  String gachaPityLeft(int n);

  /// No description provided for @gachaDraw.
  ///
  /// In en, this message translates to:
  /// **'Draw for {n} jelly'**
  String gachaDraw(int n);

  /// No description provided for @gachaResultTitle.
  ///
  /// In en, this message translates to:
  /// **'From the egg...'**
  String get gachaResultTitle;

  /// No description provided for @gachaPickTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a card'**
  String get gachaPickTitle;

  /// No description provided for @gachaPickHint.
  ///
  /// In en, this message translates to:
  /// **'One of three. You only find out by opening it'**
  String get gachaPickHint;

  /// No description provided for @gachaResultHint.
  ///
  /// In en, this message translates to:
  /// **'Put the egg in an incubator to raise it'**
  String get gachaResultHint;

  /// No description provided for @gachaStorageFull.
  ///
  /// In en, this message translates to:
  /// **'Storage is full'**
  String get gachaStorageFull;

  /// No description provided for @gachaOff.
  ///
  /// In en, this message translates to:
  /// **'Not available right now'**
  String get gachaOff;

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
  /// **'Sell'**
  String get forgeResultDrop;

  /// No description provided for @forgeResultSell.
  ///
  /// In en, this message translates to:
  /// **'Sell for {n}'**
  String forgeResultSell(String n);

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
  /// **'Rush'**
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
  /// **'Stop when a match appears'**
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

  /// No description provided for @skillAuto.
  ///
  /// In en, this message translates to:
  /// **'AUTO'**
  String get skillAuto;

  /// No description provided for @skillTimingBonus.
  ///
  /// In en, this message translates to:
  /// **'Perfect timing!'**
  String get skillTimingBonus;

  /// No description provided for @skillReflect.
  ///
  /// In en, this message translates to:
  /// **'Reflect {n}'**
  String skillReflect(String n);

  /// No description provided for @skillBlocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get skillBlocked;

  /// No description provided for @skillGacha.
  ///
  /// In en, this message translates to:
  /// **'Draw'**
  String get skillGacha;

  /// No description provided for @skillGachaTitle.
  ///
  /// In en, this message translates to:
  /// **'Skill Draw'**
  String get skillGachaTitle;

  /// No description provided for @skillGachaFreeLeft.
  ///
  /// In en, this message translates to:
  /// **'{n} free today'**
  String skillGachaFreeLeft(String n);

  /// No description provided for @skillGachaPityLeft.
  ///
  /// In en, this message translates to:
  /// **'{grade} guaranteed within {n}'**
  String skillGachaPityLeft(String grade, String n);

  /// No description provided for @skillGachaFree.
  ///
  /// In en, this message translates to:
  /// **'Free draw'**
  String get skillGachaFree;

  /// No description provided for @skillGachaOne.
  ///
  /// In en, this message translates to:
  /// **'1× · {n} jelly'**
  String skillGachaOne(String n);

  /// No description provided for @skillGachaTen.
  ///
  /// In en, this message translates to:
  /// **'10× · {n} jelly'**
  String skillGachaTen(String n);

  /// No description provided for @skillTimes.
  ///
  /// In en, this message translates to:
  /// **'×{n}'**
  String skillTimes(String n);

  /// No description provided for @skillGachaOdds.
  ///
  /// In en, this message translates to:
  /// **'View odds'**
  String get skillGachaOdds;

  /// No description provided for @skillGachaOddsTitle.
  ///
  /// In en, this message translates to:
  /// **'Skill draw odds'**
  String get skillGachaOddsTitle;

  /// No description provided for @skillGachaOddsGrade.
  ///
  /// In en, this message translates to:
  /// **'{grade} {p}% · {each}% per skill'**
  String skillGachaOddsGrade(String grade, String p, String each);

  /// No description provided for @skillGachaOddsNote.
  ///
  /// In en, this message translates to:
  /// **'Each draw gives {n} shards of one skill. Draw #{pity} is guaranteed {grade} or better; the count restarts when {grade} appears.'**
  String skillGachaOddsNote(String n, String pity, String grade);

  /// No description provided for @skillGachaResult.
  ///
  /// In en, this message translates to:
  /// **'{name} shards +{n}'**
  String skillGachaResult(String name, String n);

  /// No description provided for @skillSweep.
  ///
  /// In en, this message translates to:
  /// **'Sweep'**
  String get skillSweep;

  /// No description provided for @skillSweepTitle.
  ///
  /// In en, this message translates to:
  /// **'Boss Sweep'**
  String get skillSweepTitle;

  /// No description provided for @skillSweepDesc.
  ///
  /// In en, this message translates to:
  /// **'Counts as defeating a boss again at your highest cleared difficulty ({tier}) and gives {n} skill shards for sure.'**
  String skillSweepDesc(String tier, String n);

  /// No description provided for @skillSweepToday.
  ///
  /// In en, this message translates to:
  /// **'Used {used}/{max} today'**
  String skillSweepToday(String used, String max);

  /// No description provided for @skillSweepFree.
  ///
  /// In en, this message translates to:
  /// **'Free sweep · {n} left'**
  String skillSweepFree(String n);

  /// No description provided for @skillSweepPaid.
  ///
  /// In en, this message translates to:
  /// **'Sweep · {n} jelly'**
  String skillSweepPaid(String n);

  /// No description provided for @skillSweepNoBoss.
  ///
  /// In en, this message translates to:
  /// **'Defeat at least one\nhunting ground boss to sweep'**
  String get skillSweepNoBoss;

  /// Sweep button - short locked label
  ///
  /// In en, this message translates to:
  /// **'Beat a boss'**
  String get skillSweepLocked;

  /// Grade-up dialog title, kept short
  ///
  /// In en, this message translates to:
  /// **'Shard upgrade'**
  String get skillGradeUpShort;

  /// Skill screen - shards by grade row title
  ///
  /// In en, this message translates to:
  /// **'My shards'**
  String get skillShardsTitle;

  /// Short word before the wild shard count
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get skillWildShort;

  /// No description provided for @skillSweepLimit.
  ///
  /// In en, this message translates to:
  /// **'No sweeps left today'**
  String get skillSweepLimit;

  /// No description provided for @skillShardPop.
  ///
  /// In en, this message translates to:
  /// **'Shard +{n}'**
  String skillShardPop(String n);

  /// No description provided for @skillMaterials.
  ///
  /// In en, this message translates to:
  /// **'Skill materials'**
  String get skillMaterials;

  /// No description provided for @skillGradeWild.
  ///
  /// In en, this message translates to:
  /// **'{grade} wild'**
  String skillGradeWild(String grade);

  /// No description provided for @skillGradeUp.
  ///
  /// In en, this message translates to:
  /// **'Upgrade'**
  String get skillGradeUp;

  /// No description provided for @skillGradeUpTitle.
  ///
  /// In en, this message translates to:
  /// **'{from} shards → {to} wild shard'**
  String skillGradeUpTitle(String from, String to);

  /// No description provided for @skillGradeUpDesc.
  ///
  /// In en, this message translates to:
  /// **'Turn {ratio} {from} shards into 1 {to} wild shard, usable on any {to} skill. Pick the shards to use.'**
  String skillGradeUpDesc(String ratio, String from, String to);

  /// No description provided for @skillGradeUpMake.
  ///
  /// In en, this message translates to:
  /// **'Make {n}'**
  String skillGradeUpMake(String n);

  /// No description provided for @skillGradeUpDone.
  ///
  /// In en, this message translates to:
  /// **'Made {n} {grade} wild shards'**
  String skillGradeUpDone(String n, String grade);

  /// No description provided for @skillGradeUpPick.
  ///
  /// In en, this message translates to:
  /// **'Pick shards to use'**
  String get skillGradeUpPick;

  /// No description provided for @skillEquip.
  ///
  /// In en, this message translates to:
  /// **'Equip'**
  String get skillEquip;

  /// No description provided for @skillUnequip.
  ///
  /// In en, this message translates to:
  /// **'Unequip'**
  String get skillUnequip;

  /// No description provided for @skillSlotsInfo.
  ///
  /// In en, this message translates to:
  /// **'Equipped {n}/{max}'**
  String skillSlotsInfo(String n, String max);

  /// No description provided for @skillNextSlotHint.
  ///
  /// In en, this message translates to:
  /// **'More slots open at new difficulties'**
  String get skillNextSlotHint;

  /// No description provided for @skillShardProgress.
  ///
  /// In en, this message translates to:
  /// **'Shards {have}/{need}'**
  String skillShardProgress(String have, String need);

  /// No description provided for @skillLocked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get skillLocked;

  /// No description provided for @skillMaxLevel.
  ///
  /// In en, this message translates to:
  /// **'MAX'**
  String get skillMaxLevel;

  /// No description provided for @skillTrain.
  ///
  /// In en, this message translates to:
  /// **'Train'**
  String get skillTrain;

  /// No description provided for @skillTrainingNow.
  ///
  /// In en, this message translates to:
  /// **'Training {name} Lv.{lv} · {left}'**
  String skillTrainingNow(String name, String lv, String left);

  /// No description provided for @skillTrainClaim.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get skillTrainClaim;

  /// No description provided for @skillTrainInstant.
  ///
  /// In en, this message translates to:
  /// **'Finish now · {n} jelly'**
  String skillTrainInstant(String n);

  /// No description provided for @actionInstant.
  ///
  /// In en, this message translates to:
  /// **'Finish now'**
  String get actionInstant;

  /// No description provided for @skillTrainConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Finish training now'**
  String get skillTrainConfirmTitle;

  /// No description provided for @skillTrainConfirm.
  ///
  /// In en, this message translates to:
  /// **'Spend {n} jelly to finish now?'**
  String skillTrainConfirm(String n);

  /// No description provided for @skillTrainCostShards.
  ///
  /// In en, this message translates to:
  /// **'{n} shards · {time}'**
  String skillTrainCostShards(String n, String time);

  /// No description provided for @skillTrainCostWithAny.
  ///
  /// In en, this message translates to:
  /// **'{n} shards + {any} wild · {time}'**
  String skillTrainCostWithAny(String n, String any, String time);

  /// No description provided for @skillTrainTitle.
  ///
  /// In en, this message translates to:
  /// **'Train {name}'**
  String skillTrainTitle(String name);

  /// No description provided for @skillLevelUpDone.
  ///
  /// In en, this message translates to:
  /// **'{name} reached Lv.{lv}!'**
  String skillLevelUpDone(String name, String lv);

  /// No description provided for @skillErrNotEnoughShards.
  ///
  /// In en, this message translates to:
  /// **'Not enough shards'**
  String get skillErrNotEnoughShards;

  /// No description provided for @skillErrTrainingBusy.
  ///
  /// In en, this message translates to:
  /// **'Another skill is already training'**
  String get skillErrTrainingBusy;

  /// No description provided for @skillActiveSoon.
  ///
  /// In en, this message translates to:
  /// **'Active skills are coming soon'**
  String get skillActiveSoon;

  /// No description provided for @skillHowToGet.
  ///
  /// In en, this message translates to:
  /// **'Skill shards drop from hunting ground bosses (guaranteed on first kill) and elite monsters'**
  String get skillHowToGet;

  /// No description provided for @skillCooldown.
  ///
  /// In en, this message translates to:
  /// **'Cooldown {s}s'**
  String skillCooldown(String s);

  /// No description provided for @skillKindActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get skillKindActive;

  /// No description provided for @skillKindPassive.
  ///
  /// In en, this message translates to:
  /// **'Passive'**
  String get skillKindPassive;

  /// No description provided for @skillShardsGot.
  ///
  /// In en, this message translates to:
  /// **'Skill shards · {list}'**
  String skillShardsGot(String list);

  /// No description provided for @skillReviveToast.
  ///
  /// In en, this message translates to:
  /// **'Molting! You got back up'**
  String get skillReviveToast;

  /// No description provided for @skillFxMaterialFind.
  ///
  /// In en, this message translates to:
  /// **'Material gain +{v}%'**
  String skillFxMaterialFind(String v);

  /// No description provided for @skillFxBugFind.
  ///
  /// In en, this message translates to:
  /// **'Bug find +{v}%'**
  String skillFxBugFind(String v);

  /// No description provided for @skillFxBossDamage.
  ///
  /// In en, this message translates to:
  /// **'Boss damage +{v}%'**
  String skillFxBossDamage(String v);

  /// No description provided for @skillFxPerPetAttack.
  ///
  /// In en, this message translates to:
  /// **'Attack +{v}% per equipped bug'**
  String skillFxPerPetAttack(String v);

  /// No description provided for @skillFxKillHeal.
  ///
  /// In en, this message translates to:
  /// **'Heal on kill +{v}%'**
  String skillFxKillHeal(String v);

  /// No description provided for @skillFxRevive.
  ///
  /// In en, this message translates to:
  /// **'Revive at {v}% HP when defeated'**
  String skillFxRevive(String v);

  /// No description provided for @skillFxMaterialBurst.
  ///
  /// In en, this message translates to:
  /// **'Materials ×{v} for {d}s'**
  String skillFxMaterialBurst(String v, String d);

  /// No description provided for @skillFxAttackSpeed.
  ///
  /// In en, this message translates to:
  /// **'Attack speed ×{v} for {d}s'**
  String skillFxAttackSpeed(String v, String d);

  /// No description provided for @skillFxAreaDamage.
  ///
  /// In en, this message translates to:
  /// **'Hit everything for {v}s of damage'**
  String skillFxAreaDamage(String v);

  /// No description provided for @skillFxPetPower.
  ///
  /// In en, this message translates to:
  /// **'Bug power ×{v} for {d}s'**
  String skillFxPetPower(String v, String d);

  /// No description provided for @skillFxBurstDamage.
  ///
  /// In en, this message translates to:
  /// **'A strike worth {v}s of damage'**
  String skillFxBurstDamage(String v);

  /// No description provided for @skillFxInvulnerable.
  ///
  /// In en, this message translates to:
  /// **'Immune to damage for {d}s'**
  String skillFxInvulnerable(String d);

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

  /// No description provided for @forgeFilterGrade.
  ///
  /// In en, this message translates to:
  /// **'Min grade'**
  String get forgeFilterGrade;

  /// No description provided for @forgeFilterGradeHint.
  ///
  /// In en, this message translates to:
  /// **'Anything below this grade is discarded.'**
  String get forgeFilterGradeHint;

  /// No description provided for @forgeFilterRangeHint.
  ///
  /// In en, this message translates to:
  /// **'Ranges show the max for {tier} grade'**
  String forgeFilterRangeHint(String tier);

  /// No description provided for @optPerfect.
  ///
  /// In en, this message translates to:
  /// **'MAX'**
  String get optPerfect;

  /// No description provided for @forgeFilterGradeAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get forgeFilterGradeAll;

  /// No description provided for @forgeFilterOption.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get forgeFilterOption;

  /// No description provided for @forgeStrikes.
  ///
  /// In en, this message translates to:
  /// **'x{n}'**
  String forgeStrikes(int n);

  /// No description provided for @forgeStrikePick.
  ///
  /// In en, this message translates to:
  /// **'Strikes per hammer'**
  String get forgeStrikePick;

  /// No description provided for @forgeStrikePickHint.
  ///
  /// In en, this message translates to:
  /// **'How many to forge per hammer blow. Applies to manual taps too.'**
  String get forgeStrikePickHint;

  /// No description provided for @forgeStrikeLocked.
  ///
  /// In en, this message translates to:
  /// **'Needs chapter {n}'**
  String forgeStrikeLocked(int n);

  /// No description provided for @forgeStrikeAuto.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get forgeStrikeAuto;

  /// No description provided for @forgeReroll.
  ///
  /// In en, this message translates to:
  /// **'Reroll'**
  String get forgeReroll;

  /// No description provided for @forgeExpand.
  ///
  /// In en, this message translates to:
  /// **'Expand'**
  String get forgeExpand;

  /// No description provided for @forgeExpandMax.
  ///
  /// In en, this message translates to:
  /// **'MAX'**
  String get forgeExpandMax;

  /// No description provided for @forgeRushTitle.
  ///
  /// In en, this message translates to:
  /// **'Hammer rush'**
  String get forgeRushTitle;

  /// No description provided for @forgeRushBody.
  ///
  /// In en, this message translates to:
  /// **'Spend {cost} jelly to hammer twice as fast for {sec}s.\nUsing it again adds to the remaining time.'**
  String forgeRushBody(int cost, int sec);

  /// No description provided for @forgeRushLeft.
  ///
  /// In en, this message translates to:
  /// **'{sec}s left'**
  String forgeRushLeft(int sec);

  /// No description provided for @forgeRerollHint.
  ///
  /// In en, this message translates to:
  /// **'Same tier and slot — only the options are rerolled'**
  String get forgeRerollHint;

  /// No description provided for @forgeRushOn.
  ///
  /// In en, this message translates to:
  /// **'Rush {s}s'**
  String forgeRushOn(int s);

  /// No description provided for @forgeStackCount.
  ///
  /// In en, this message translates to:
  /// **'Anvil {n}/{max}'**
  String forgeStackCount(int n, int max);

  /// No description provided for @forgeNoJelly.
  ///
  /// In en, this message translates to:
  /// **'Not enough jelly'**
  String get forgeNoJelly;

  /// No description provided for @upgradeMaxed.
  ///
  /// In en, this message translates to:
  /// **'MAX'**
  String get upgradeMaxed;

  /// No description provided for @eliteLabel.
  ///
  /// In en, this message translates to:
  /// **'ELITE'**
  String get eliteLabel;

  /// No description provided for @gateGearHint.
  ///
  /// In en, this message translates to:
  /// **'Gear ×{cur} · suggested ×{need}'**
  String gateGearHint(String cur, String need);

  /// No description provided for @gateGearWeak.
  ///
  /// In en, this message translates to:
  /// **'Gear is weak — forge attack options'**
  String get gateGearWeak;

  /// No description provided for @regionElementTitle.
  ///
  /// In en, this message translates to:
  /// **'Region element'**
  String get regionElementTitle;

  /// No description provided for @regionElementHint.
  ///
  /// In en, this message translates to:
  /// **'Equip bugs whose element overcomes it and their hits get stronger. Bugs attack on their own timing, separately from you.'**
  String get regionElementHint;

  /// No description provided for @forgeStrikeStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get forgeStrikeStart;

  /// No description provided for @forgeStopOnHitHint.
  ///
  /// In en, this message translates to:
  /// **'Stops the auto-forge as soon as one passes your filter, saving the rest of your fossils.'**
  String get forgeStopOnHitHint;

  /// No description provided for @forgeStopOnHitNoFilter.
  ///
  /// In en, this message translates to:
  /// **'Set a filter first so there is something to stop on'**
  String get forgeStopOnHitNoFilter;

  /// No description provided for @forgeStoppedOnHit.
  ///
  /// In en, this message translates to:
  /// **'Found what you were after'**
  String get forgeStoppedOnHit;

  /// No description provided for @forgeStrikeAutoHint.
  ///
  /// In en, this message translates to:
  /// **'Grows automatically as you clear chapters'**
  String get forgeStrikeAutoHint;

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
  /// **'Restrain: hitting the foe a red arrow points to deals {mult}x damage'**
  String elementWheelRestrain(String mult);

  /// No description provided for @traitNoneBadge.
  ///
  /// In en, this message translates to:
  /// **'No trait'**
  String get traitNoneBadge;

  /// No description provided for @elementWheelHint.
  ///
  /// In en, this message translates to:
  /// **'Example: Water → Fire. A Water bug deals more damage to a Fire bug in duels.'**
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
  /// **'Closes every Sunday 09:00 (KST) and pays by your league at that moment. Climb before it closes.'**
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

  /// No description provided for @giftDoubleJellyLine.
  ///
  /// In en, this message translates to:
  /// **'Today\'s first double bonus: {min}–{max} Bug Jelly!'**
  String giftDoubleJellyLine(int min, int max);

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

  /// No description provided for @supportTitle.
  ///
  /// In en, this message translates to:
  /// **'Contact us'**
  String get supportTitle;

  /// No description provided for @supportHint.
  ///
  /// In en, this message translates to:
  /// **'Tell us about a bug or anything inconvenient. Your nickname and progress are sent along automatically.'**
  String get supportHint;

  /// No description provided for @supportSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get supportSend;

  /// No description provided for @supportSent.
  ///
  /// In en, this message translates to:
  /// **'Sent. We will look into it!'**
  String get supportSent;

  /// No description provided for @supportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send. Please try again shortly.'**
  String get supportFailed;

  /// No description provided for @supportTooFast.
  ///
  /// In en, this message translates to:
  /// **'You can send another one in a moment.'**
  String get supportTooFast;

  /// No description provided for @zoneConquered.
  ///
  /// In en, this message translates to:
  /// **'Conquered'**
  String get zoneConquered;

  /// No description provided for @zoneHere.
  ///
  /// In en, this message translates to:
  /// **'You are here'**
  String get zoneHere;

  /// No description provided for @zoneLocked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get zoneLocked;

  /// No description provided for @badgeParticipant.
  ///
  /// In en, this message translates to:
  /// **'R{round} Entrant'**
  String badgeParticipant(int round);

  /// No description provided for @eventWaitingTitle.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the next contest'**
  String get eventWaitingTitle;

  /// No description provided for @eventNextRound.
  ///
  /// In en, this message translates to:
  /// **'Round {no} opens {date}'**
  String eventNextRound(int no, String date);

  /// No description provided for @eventDateMd.
  ///
  /// In en, this message translates to:
  /// **'{m}/{d}'**
  String eventDateMd(int m, int d);

  /// No description provided for @eventHallTitle.
  ///
  /// In en, this message translates to:
  /// **'Hall of Fame'**
  String get eventHallTitle;

  /// No description provided for @eventHallRound.
  ///
  /// In en, this message translates to:
  /// **'Round {no} · {n} entrants'**
  String eventHallRound(int no, String n);

  /// No description provided for @eventHallEmpty.
  ///
  /// In en, this message translates to:
  /// **'No one is in the Hall of Fame yet'**
  String get eventHallEmpty;

  /// No description provided for @eventHallTop10.
  ///
  /// In en, this message translates to:
  /// **'4th–10th'**
  String get eventHallTop10;

  /// No description provided for @eventHallEntrants.
  ///
  /// In en, this message translates to:
  /// **'Everyone who took part'**
  String get eventHallEntrants;

  /// No description provided for @eventHallMore.
  ///
  /// In en, this message translates to:
  /// **'and more'**
  String get eventHallMore;

  /// No description provided for @eventRewardBadgeLabel.
  ///
  /// In en, this message translates to:
  /// **'Badge earned'**
  String get eventRewardBadgeLabel;

  /// No description provided for @tierMoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Move to {name}'**
  String tierMoveTitle(String name);

  /// No description provided for @tierMoveBody.
  ///
  /// In en, this message translates to:
  /// **'Upgrades, currency and gear stay as they are.\nZone clear rewards are only given on your highest difficulty.'**
  String get tierMoveBody;

  /// No description provided for @tierMoveGo.
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get tierMoveGo;

  /// No description provided for @tierMoved.
  ///
  /// In en, this message translates to:
  /// **'Moved to {name}'**
  String tierMoved(String name);

  /// No description provided for @pvpRankRewardTitle.
  ///
  /// In en, this message translates to:
  /// **'Duel Season Rank Reward'**
  String get pvpRankRewardTitle;

  /// No description provided for @pvpRankRewardBody.
  ///
  /// In en, this message translates to:
  /// **'You finished #{rank} in last season\'s duels!'**
  String pvpRankRewardBody(int rank);

  /// No description provided for @pvpRankN.
  ///
  /// In en, this message translates to:
  /// **'#{n}'**
  String pvpRankN(int n);

  /// No description provided for @pvpRankRewardHint.
  ///
  /// In en, this message translates to:
  /// **'Rank rewards (Jelly) {list}'**
  String pvpRankRewardHint(String list);

  /// No description provided for @duelThrowButton.
  ///
  /// In en, this message translates to:
  /// **'Throw!'**
  String get duelThrowButton;

  /// No description provided for @duelGaugeHint.
  ///
  /// In en, this message translates to:
  /// **'Tap anywhere to stop · the closer to green, the stronger your attack this bout (up to +{pct}%)'**
  String duelGaugeHint(int pct);

  /// No description provided for @duelBout.
  ///
  /// In en, this message translates to:
  /// **'Bout {n}'**
  String duelBout(int n);

  /// No description provided for @duelFinishRingOut.
  ///
  /// In en, this message translates to:
  /// **'Ring out!'**
  String get duelFinishRingOut;

  /// No description provided for @duelFinishFlip.
  ///
  /// In en, this message translates to:
  /// **'Flipped!'**
  String get duelFinishFlip;

  /// No description provided for @duelFinishKnockout.
  ///
  /// In en, this message translates to:
  /// **'Knockout!'**
  String get duelFinishKnockout;

  /// No description provided for @duelFinishTimeUp.
  ///
  /// In en, this message translates to:
  /// **'Decision!'**
  String get duelFinishTimeUp;

  /// No description provided for @duelBoutWin.
  ///
  /// In en, this message translates to:
  /// **'Bout won!'**
  String get duelBoutWin;

  /// No description provided for @duelBoutLose.
  ///
  /// In en, this message translates to:
  /// **'Bout lost…'**
  String get duelBoutLose;

  /// No description provided for @duelSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get duelSkip;

  /// No description provided for @duelTrophy.
  ///
  /// In en, this message translates to:
  /// **'Trophies {delta}'**
  String duelTrophy(String delta);

  /// No description provided for @duelResultOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get duelResultOk;

  /// No description provided for @duelNeedThree.
  ///
  /// In en, this message translates to:
  /// **'You need 3 bugs for a duel'**
  String get duelNeedThree;

  /// No description provided for @duelOrderHint.
  ///
  /// In en, this message translates to:
  /// **'#1, #2, #3 each fight one bout · this order is also your defense order'**
  String get duelOrderHint;

  /// No description provided for @abyssName.
  ///
  /// In en, this message translates to:
  /// **'Abyss'**
  String get abyssName;

  /// No description provided for @abyssFloorLabel.
  ///
  /// In en, this message translates to:
  /// **'Abyss F{n}'**
  String abyssFloorLabel(int n);

  /// No description provided for @abyssUnlockedTitle.
  ///
  /// In en, this message translates to:
  /// **'The Abyss is open!'**
  String get abyssUnlockedTitle;

  /// No description provided for @abyssUnlockedBody.
  ///
  /// In en, this message translates to:
  /// **'Endless floors beyond Extreme. Your upgrades, gear and bugs come with you.\nEvery Monday 09:00 (KST) you start again from F1, and the deepest floor at the Sunday 09:00 close earns ranking Jelly.'**
  String get abyssUnlockedBody;

  /// No description provided for @abyssEnter.
  ///
  /// In en, this message translates to:
  /// **'Enter the Abyss'**
  String get abyssEnter;

  /// No description provided for @abyssLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get abyssLater;

  /// No description provided for @abyssLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave the Abyss'**
  String get abyssLeave;

  /// No description provided for @abyssFloorClear.
  ///
  /// In en, this message translates to:
  /// **'F{n} cleared!'**
  String abyssFloorClear(int n);

  /// No description provided for @abyssMilestone.
  ///
  /// In en, this message translates to:
  /// **'First time reaching F{n}! Fossils +{fossil}'**
  String abyssMilestone(int n, int fossil);

  /// No description provided for @abyssBest.
  ///
  /// In en, this message translates to:
  /// **'Best F{n}'**
  String abyssBest(int n);

  /// No description provided for @abyssWeekReset.
  ///
  /// In en, this message translates to:
  /// **'A new week — back to Abyss F1!'**
  String get abyssWeekReset;

  /// No description provided for @abyssRankRewardTitle.
  ///
  /// In en, this message translates to:
  /// **'Abyss Weekly Rank Reward'**
  String get abyssRankRewardTitle;

  /// No description provided for @abyssRankRewardBody.
  ///
  /// In en, this message translates to:
  /// **'Last week you reached Abyss F{floor} and placed #{rank}!'**
  String abyssRankRewardBody(int floor, int rank);

  /// No description provided for @boardTitle.
  ///
  /// In en, this message translates to:
  /// **'Rankings'**
  String get boardTitle;

  /// No description provided for @boardTabDuel.
  ///
  /// In en, this message translates to:
  /// **'Duel League'**
  String get boardTabDuel;

  /// No description provided for @boardTabAbyss.
  ///
  /// In en, this message translates to:
  /// **'Abyss'**
  String get boardTabAbyss;

  /// No description provided for @boardLeagueTitle.
  ///
  /// In en, this message translates to:
  /// **'{league} League'**
  String boardLeagueTitle(String league);

  /// No description provided for @boardAbyssTitle.
  ///
  /// In en, this message translates to:
  /// **'Abyss Weekly Ranking'**
  String get boardAbyssTitle;

  /// No description provided for @boardSeasonEndsIn.
  ///
  /// In en, this message translates to:
  /// **'New season in: {time}'**
  String boardSeasonEndsIn(String time);

  /// No description provided for @boardTimeLeftDays.
  ///
  /// In en, this message translates to:
  /// **'{d}d {h}h {m}m'**
  String boardTimeLeftDays(int d, int h, int m);

  /// No description provided for @boardTimeLeft.
  ///
  /// In en, this message translates to:
  /// **'{h}h {m}m'**
  String boardTimeLeft(int h, int m);

  /// No description provided for @boardZonesHint.
  ///
  /// In en, this message translates to:
  /// **'Top {promote} promote · bottom {demote} demote'**
  String boardZonesHint(int promote, int demote);

  /// No description provided for @boardEmpty.
  ///
  /// In en, this message translates to:
  /// **'No records this week yet'**
  String get boardEmpty;

  /// No description provided for @boardMeNone.
  ///
  /// In en, this message translates to:
  /// **'Duel this week to appear in the ranking'**
  String get boardMeNone;

  /// No description provided for @boardAbyssMeNone.
  ///
  /// In en, this message translates to:
  /// **'Clear Abyss F1 this week to appear in the ranking'**
  String get boardAbyssMeNone;

  /// No description provided for @boardFloorShort.
  ///
  /// In en, this message translates to:
  /// **'F{n}'**
  String boardFloorShort(int n);

  /// No description provided for @boardRewardsTitle.
  ///
  /// In en, this message translates to:
  /// **'{league} League Rank Rewards'**
  String boardRewardsTitle(String league);

  /// No description provided for @boardAbyssRewardsTitle.
  ///
  /// In en, this message translates to:
  /// **'Abyss Weekly Rank Rewards'**
  String get boardAbyssRewardsTitle;

  /// No description provided for @boardOpen.
  ///
  /// In en, this message translates to:
  /// **'Rankings'**
  String get boardOpen;

  /// No description provided for @leagueResultTitle.
  ///
  /// In en, this message translates to:
  /// **'League Results'**
  String get leagueResultTitle;

  /// No description provided for @leagueResultUp.
  ///
  /// In en, this message translates to:
  /// **'Promoted to {league} League!'**
  String leagueResultUp(String league);

  /// No description provided for @leagueResultDown.
  ///
  /// In en, this message translates to:
  /// **'Moved down to {league} League'**
  String leagueResultDown(String league);

  /// No description provided for @leagueResultStay.
  ///
  /// In en, this message translates to:
  /// **'Staying in {league} League'**
  String leagueResultStay(String league);

  /// No description provided for @leagueResultRank.
  ///
  /// In en, this message translates to:
  /// **'Last week: #{rank} of {total}'**
  String leagueResultRank(int rank, int total);

  /// No description provided for @leagueResultInactive.
  ///
  /// In en, this message translates to:
  /// **'You skipped duels last week, so you moved down one league'**
  String get leagueResultInactive;

  /// No description provided for @leagueZoneHint.
  ///
  /// In en, this message translates to:
  /// **'Closes every Sunday 09:00 · top 20% promote · bottom 20% demote'**
  String get leagueZoneHint;

  /// No description provided for @duelSquadTitle.
  ///
  /// In en, this message translates to:
  /// **'Squad'**
  String get duelSquadTitle;

  /// No description provided for @recoveryRoom.
  ///
  /// In en, this message translates to:
  /// **'Recovery'**
  String get recoveryRoom;

  /// No description provided for @trainingCenter.
  ///
  /// In en, this message translates to:
  /// **'Training'**
  String get trainingCenter;

  /// No description provided for @trainingSoon.
  ///
  /// In en, this message translates to:
  /// **'Training opens soon'**
  String get trainingSoon;

  /// No description provided for @leagueClaimPromo.
  ///
  /// In en, this message translates to:
  /// **'Claim promotion reward'**
  String get leagueClaimPromo;

  /// No description provided for @battleSeasonClosed.
  ///
  /// In en, this message translates to:
  /// **'The season has ended!'**
  String get battleSeasonClosed;

  /// No description provided for @recoveryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No bugs are recovering'**
  String get recoveryEmpty;

  /// No description provided for @opponentPickTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose an opponent'**
  String get opponentPickTitle;

  /// No description provided for @opponentPickHint.
  ///
  /// In en, this message translates to:
  /// **'Your team power {power} · Win to earn stars, lose nothing'**
  String opponentPickHint(String power);

  /// No description provided for @opponentWinOnly.
  ///
  /// In en, this message translates to:
  /// **'on win'**
  String get opponentWinOnly;

  /// No description provided for @boardSeasonClosesIn.
  ///
  /// In en, this message translates to:
  /// **'Season closes: {time}'**
  String boardSeasonClosesIn(String time);

  /// No description provided for @boardMyRankNow.
  ///
  /// In en, this message translates to:
  /// **'Now #{rank} — your reward'**
  String boardMyRankNow(int rank);

  /// No description provided for @profileCombatPower.
  ///
  /// In en, this message translates to:
  /// **'Power {power}'**
  String profileCombatPower(String power);

  /// No description provided for @profileNoTeam.
  ///
  /// In en, this message translates to:
  /// **'No defense team yet'**
  String get profileNoTeam;

  /// No description provided for @duelAutoThrowIn.
  ///
  /// In en, this message translates to:
  /// **'Auto-throw in {n}s'**
  String duelAutoThrowIn(int n);

  /// No description provided for @duelRestrainHit.
  ///
  /// In en, this message translates to:
  /// **'Counter!'**
  String get duelRestrainHit;

  /// No description provided for @duelCritHit.
  ///
  /// In en, this message translates to:
  /// **'Critical!'**
  String get duelCritHit;

  /// No description provided for @duelWeakHit.
  ///
  /// In en, this message translates to:
  /// **'Weak spot!'**
  String get duelWeakHit;

  /// No description provided for @pvpTicketJellyGive.
  ///
  /// In en, this message translates to:
  /// **'Refill +{amount}'**
  String pvpTicketJellyGive(int amount);

  /// No description provided for @bugInfoAtk.
  ///
  /// In en, this message translates to:
  /// **'Attack'**
  String get bugInfoAtk;

  /// No description provided for @bugInfoDef.
  ///
  /// In en, this message translates to:
  /// **'Defense'**
  String get bugInfoDef;

  /// No description provided for @bugInfoSpd.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get bugInfoSpd;

  /// No description provided for @bugInfoSpecialty.
  ///
  /// In en, this message translates to:
  /// **'Specialty'**
  String get bugInfoSpecialty;

  /// No description provided for @bugInfoTemperament.
  ///
  /// In en, this message translates to:
  /// **'Temper'**
  String get bugInfoTemperament;

  /// No description provided for @bugInfoSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get bugInfoSize;

  /// No description provided for @bugInfoPotential.
  ///
  /// In en, this message translates to:
  /// **'Potential'**
  String get bugInfoPotential;

  /// No description provided for @squadDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Squad'**
  String get squadDetailTitle;

  /// No description provided for @squadDeploy.
  ///
  /// In en, this message translates to:
  /// **'Deploy'**
  String get squadDeploy;

  /// No description provided for @squadInjured.
  ///
  /// In en, this message translates to:
  /// **'A bug is recovering — heal it in Recovery or swap it out'**
  String get squadInjured;

  /// No description provided for @squadOrder.
  ///
  /// In en, this message translates to:
  /// **'Fighter {n}'**
  String squadOrder(int n);

  /// No description provided for @duelAttackBtn.
  ///
  /// In en, this message translates to:
  /// **'Attack'**
  String get duelAttackBtn;

  /// No description provided for @squadRelease.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get squadRelease;

  /// No description provided for @squadSwap.
  ///
  /// In en, this message translates to:
  /// **'Swap'**
  String get squadSwap;

  /// No description provided for @trainAttack.
  ///
  /// In en, this message translates to:
  /// **'Attack'**
  String get trainAttack;

  /// No description provided for @trainDefense.
  ///
  /// In en, this message translates to:
  /// **'Defense'**
  String get trainDefense;

  /// No description provided for @trainEvade.
  ///
  /// In en, this message translates to:
  /// **'Evade'**
  String get trainEvade;

  /// No description provided for @trainCrit.
  ///
  /// In en, this message translates to:
  /// **'Critical'**
  String get trainCrit;

  /// No description provided for @trainRecovery.
  ///
  /// In en, this message translates to:
  /// **'Recovery'**
  String get trainRecovery;

  /// No description provided for @trainingNone.
  ///
  /// In en, this message translates to:
  /// **'No bug is training right now'**
  String get trainingNone;

  /// No description provided for @trainingNow.
  ///
  /// In en, this message translates to:
  /// **'Training {stat} Lv{level}'**
  String trainingNow(String stat, int level);

  /// No description provided for @trainingDone.
  ///
  /// In en, this message translates to:
  /// **'Training complete!'**
  String get trainingDone;

  /// No description provided for @trainingPickBug.
  ///
  /// In en, this message translates to:
  /// **'Bug to train'**
  String get trainingPickBug;

  /// No description provided for @trainingCapHint.
  ///
  /// In en, this message translates to:
  /// **'Max levels differ by potential, temper, specialty and bloodline trait'**
  String get trainingCapHint;

  /// No description provided for @trainingLevel.
  ///
  /// In en, this message translates to:
  /// **'{lv} / {cap}'**
  String trainingLevel(int lv, int cap);

  /// No description provided for @trainingStart.
  ///
  /// In en, this message translates to:
  /// **'Train'**
  String get trainingStart;

  /// No description provided for @trainingMaxed.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get trainingMaxed;

  /// No description provided for @trainingBusy.
  ///
  /// In en, this message translates to:
  /// **'One bug at a time — wait for the current training'**
  String get trainingBusy;

  /// No description provided for @trainingNoMaterials.
  ///
  /// In en, this message translates to:
  /// **'Not enough materials'**
  String get trainingNoMaterials;

  /// No description provided for @trainingReset.
  ///
  /// In en, this message translates to:
  /// **'Reset training'**
  String get trainingReset;

  /// No description provided for @trainingResetAsk.
  ///
  /// In en, this message translates to:
  /// **'Reset all levels to 0 and get back half the materials ({n} of each)'**
  String trainingResetAsk(String n);

  /// No description provided for @trainingResetDone.
  ///
  /// In en, this message translates to:
  /// **'Training reset'**
  String get trainingResetDone;

  /// No description provided for @squadTraining.
  ///
  /// In en, this message translates to:
  /// **'A training bug cannot be deployed'**
  String get squadTraining;

  /// No description provided for @duelMiss.
  ///
  /// In en, this message translates to:
  /// **'Miss!'**
  String get duelMiss;

  /// No description provided for @breedingConfirm.
  ///
  /// In en, this message translates to:
  /// **'Mate'**
  String get breedingConfirm;

  /// No description provided for @breedingTimeInfo.
  ///
  /// In en, this message translates to:
  /// **'Egg in {t}'**
  String breedingTimeInfo(String t);

  /// No description provided for @incubatorStartConfirm.
  ///
  /// In en, this message translates to:
  /// **'Start hatching'**
  String get incubatorStartConfirm;

  /// No description provided for @incubatorTimeInfo.
  ///
  /// In en, this message translates to:
  /// **'Hatches in {t}'**
  String incubatorTimeInfo(String t);

  /// No description provided for @bugInfoSex.
  ///
  /// In en, this message translates to:
  /// **'Sex'**
  String get bugInfoSex;

  /// No description provided for @bugInfoElement.
  ///
  /// In en, this message translates to:
  /// **'Element'**
  String get bugInfoElement;

  /// No description provided for @leagueInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'{league} League'**
  String leagueInfoTitle(String league);

  /// No description provided for @leagueInfoRank.
  ///
  /// In en, this message translates to:
  /// **'Weekly rank rewards (closes Sun 09:00)'**
  String get leagueInfoRank;

  /// No description provided for @leagueInfoSeason.
  ///
  /// In en, this message translates to:
  /// **'Season-end reward'**
  String get leagueInfoSeason;

  /// No description provided for @leagueInfoAll.
  ///
  /// In en, this message translates to:
  /// **'Rewards by league'**
  String get leagueInfoAll;

  /// No description provided for @leagueInfoCurrent.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get leagueInfoCurrent;

  /// No description provided for @leagueInfoAllHint.
  ///
  /// In en, this message translates to:
  /// **'Jelly = 1st place in that league · Gold = season-end reward'**
  String get leagueInfoAllHint;

  /// No description provided for @boardPromoteLine.
  ///
  /// In en, this message translates to:
  /// **'▲ Promotion zone above'**
  String get boardPromoteLine;

  /// No description provided for @boardDemoteLine.
  ///
  /// In en, this message translates to:
  /// **'▼ Demotion zone below'**
  String get boardDemoteLine;

  /// No description provided for @squadAutoFilled.
  ///
  /// In en, this message translates to:
  /// **'Squad filled automatically. Check it and tap Start again'**
  String get squadAutoFilled;

  /// No description provided for @battleSeasonClosedShort.
  ///
  /// In en, this message translates to:
  /// **'Season over'**
  String get battleSeasonClosedShort;

  /// No description provided for @leagueMyNow.
  ///
  /// In en, this message translates to:
  /// **'Now #{rank} of {total}'**
  String leagueMyNow(int rank, int total);

  /// No description provided for @leagueMyPromote.
  ///
  /// In en, this message translates to:
  /// **'▲ Promotion zone — {league} League next week'**
  String leagueMyPromote(String league);

  /// No description provided for @leagueMyStay.
  ///
  /// In en, this message translates to:
  /// **'Safe — same league next week'**
  String get leagueMyStay;

  /// No description provided for @leagueMyDemote.
  ///
  /// In en, this message translates to:
  /// **'▼ Demotion zone — {league} League next week'**
  String leagueMyDemote(String league);

  /// No description provided for @leagueMyIfEnds.
  ///
  /// In en, this message translates to:
  /// **'Reward if the season ended now'**
  String get leagueMyIfEnds;

  /// No description provided for @boardBossPct.
  ///
  /// In en, this message translates to:
  /// **'Boss {n}%'**
  String boardBossPct(int n);

  /// No description provided for @boardAbyssHint.
  ///
  /// In en, this message translates to:
  /// **'Same floor? Higher max damage on the next floor boss (Boss %) ranks higher'**
  String get boardAbyssHint;

  /// No description provided for @rankProgressAbyss.
  ///
  /// In en, this message translates to:
  /// **'{tier} · Abyss F{floor}'**
  String rankProgressAbyss(String tier, int floor);

  /// No description provided for @duelLaunchBonus.
  ///
  /// In en, this message translates to:
  /// **'Great throw! Attack +{pct}% this bout'**
  String duelLaunchBonus(int pct);

  /// No description provided for @eventWaveHeader.
  ///
  /// In en, this message translates to:
  /// **'Wave {n}'**
  String eventWaveHeader(int n);

  /// No description provided for @eventStopHp.
  ///
  /// In en, this message translates to:
  /// **'Out of HP — the run ends here.'**
  String get eventStopHp;

  /// No description provided for @eventDevPreview.
  ///
  /// In en, this message translates to:
  /// **'Developer preview — no server record, rewards, tickets or injuries'**
  String get eventDevPreview;

  /// No description provided for @eventDevTry.
  ///
  /// In en, this message translates to:
  /// **'Try the contest (dev)'**
  String get eventDevTry;

  /// No description provided for @eventEntryLabel.
  ///
  /// In en, this message translates to:
  /// **'Your entry'**
  String get eventEntryLabel;

  /// No description provided for @eventEntryEmpty.
  ///
  /// In en, this message translates to:
  /// **'Pick your best-raised bug below to put it on stage'**
  String get eventEntryEmpty;

  /// No description provided for @eventBuffNow.
  ///
  /// In en, this message translates to:
  /// **'Active boosts'**
  String get eventBuffNow;

  /// No description provided for @eventBuffNone.
  ///
  /// In en, this message translates to:
  /// **'No boosts yet'**
  String get eventBuffNone;

  /// No description provided for @eventBuffRevive.
  ///
  /// In en, this message translates to:
  /// **'Revive {n}'**
  String eventBuffRevive(int n);

  /// No description provided for @eventFallRetry.
  ///
  /// In en, this message translates to:
  /// **'HP -{pct}% · retry the same wave'**
  String eventFallRetry(int pct);

  /// No description provided for @eventReviveRetry.
  ///
  /// In en, this message translates to:
  /// **'Revived! Retry the same wave'**
  String get eventReviveRetry;

  /// No description provided for @cardAgile.
  ///
  /// In en, this message translates to:
  /// **'Nimble'**
  String get cardAgile;

  /// No description provided for @cardAgileDesc.
  ///
  /// In en, this message translates to:
  /// **'Evade +8%p — chance to dodge a clash entirely'**
  String get cardAgileDesc;

  /// No description provided for @cardVital.
  ///
  /// In en, this message translates to:
  /// **'Vital Strike'**
  String get cardVital;

  /// No description provided for @cardVitalDesc.
  ///
  /// In en, this message translates to:
  /// **'Critical chance +10%p'**
  String get cardVitalDesc;

  /// No description provided for @cardBreath.
  ///
  /// In en, this message translates to:
  /// **'Catch Breath'**
  String get cardBreath;

  /// No description provided for @cardBreathDesc.
  ///
  /// In en, this message translates to:
  /// **'Heal 10% more HP after each wave'**
  String get cardBreathDesc;

  /// No description provided for @cardHeft.
  ///
  /// In en, this message translates to:
  /// **'Heavyweight'**
  String get cardHeft;

  /// No description provided for @cardHeftDesc.
  ///
  /// In en, this message translates to:
  /// **'Body +40% — heavier, harder to push out'**
  String get cardHeftDesc;

  /// No description provided for @cardBerserk.
  ///
  /// In en, this message translates to:
  /// **'Berserk'**
  String get cardBerserk;

  /// No description provided for @cardBerserkDesc.
  ///
  /// In en, this message translates to:
  /// **'Attack +35% · but Defense -21%'**
  String get cardBerserkDesc;

  /// No description provided for @cardIronhide.
  ///
  /// In en, this message translates to:
  /// **'Ironhide'**
  String get cardIronhide;

  /// No description provided for @cardIronhideDesc.
  ///
  /// In en, this message translates to:
  /// **'Defense +40% · but Speed -16%'**
  String get cardIronhideDesc;

  /// No description provided for @cardLastStand.
  ///
  /// In en, this message translates to:
  /// **'Last Stand'**
  String get cardLastStand;

  /// No description provided for @cardLastStandDesc.
  ///
  /// In en, this message translates to:
  /// **'Attack +40% in waves you enter below 50% HP'**
  String get cardLastStandDesc;

  /// No description provided for @eventBuffEvade.
  ///
  /// In en, this message translates to:
  /// **'Evade'**
  String get eventBuffEvade;

  /// No description provided for @eventBuffCrit.
  ///
  /// In en, this message translates to:
  /// **'Crit'**
  String get eventBuffCrit;

  /// No description provided for @eventBuffRecover.
  ///
  /// In en, this message translates to:
  /// **'Heal'**
  String get eventBuffRecover;

  /// No description provided for @eventBuffSize.
  ///
  /// In en, this message translates to:
  /// **'Body'**
  String get eventBuffSize;

  /// No description provided for @eventBuffSpd.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get eventBuffSpd;

  /// No description provided for @eventBuffLastStand.
  ///
  /// In en, this message translates to:
  /// **'Last Stand'**
  String get eventBuffLastStand;

  /// No description provided for @eventQuit.
  ///
  /// In en, this message translates to:
  /// **'Retreat'**
  String get eventQuit;

  /// No description provided for @eventQuitTitle.
  ///
  /// In en, this message translates to:
  /// **'Stop here?'**
  String get eventQuitTitle;

  /// No description provided for @eventQuitBody.
  ///
  /// In en, this message translates to:
  /// **'Your record is locked in at {n} waves cleared.\nHP now {hp}% — injury lasts only {injury}% of the maximum.\n(The more HP left, the shorter the rest)'**
  String eventQuitBody(int n, int hp, int injury);

  /// No description provided for @charTabFairy.
  ///
  /// In en, this message translates to:
  /// **'Fairies'**
  String get charTabFairy;

  /// No description provided for @fairyCompanion.
  ///
  /// In en, this message translates to:
  /// **'Companion'**
  String get fairyCompanion;

  /// No description provided for @fairyNoCompanion.
  ///
  /// In en, this message translates to:
  /// **'No companion yet — pick one below'**
  String get fairyNoCompanion;

  /// No description provided for @fairyBoxTitle.
  ///
  /// In en, this message translates to:
  /// **'Fairies {n}/{max}'**
  String fairyBoxTitle(String n, String max);

  /// No description provided for @fairyEggCount.
  ///
  /// In en, this message translates to:
  /// **'{n} eggs'**
  String fairyEggCount(String n);

  /// No description provided for @fairyEmptyBox.
  ///
  /// In en, this message translates to:
  /// **'No fairies yet. Draw a fairy egg and hatch it in the nest!'**
  String get fairyEmptyBox;

  /// No description provided for @fairyNest.
  ///
  /// In en, this message translates to:
  /// **'Fairy Nest'**
  String get fairyNest;

  /// No description provided for @fairyNestEmpty.
  ///
  /// In en, this message translates to:
  /// **'The nest is empty — place an egg'**
  String get fairyNestEmpty;

  /// No description provided for @fairyNestNoEgg.
  ///
  /// In en, this message translates to:
  /// **'No eggs to place'**
  String get fairyNestNoEgg;

  /// No description provided for @fairyNestPut.
  ///
  /// In en, this message translates to:
  /// **'Place in nest'**
  String get fairyNestPut;

  /// No description provided for @fairyNestCollect.
  ///
  /// In en, this message translates to:
  /// **'Collect'**
  String get fairyNestCollect;

  /// No description provided for @fairyNestReady.
  ///
  /// In en, this message translates to:
  /// **'Ready to hatch!'**
  String get fairyNestReady;

  /// No description provided for @fairyNestLeft.
  ///
  /// In en, this message translates to:
  /// **'{t} left'**
  String fairyNestLeft(String t);

  /// No description provided for @fairyNestKindHint.
  ///
  /// In en, this message translates to:
  /// **'The kind is random among {n}'**
  String fairyNestKindHint(String n);

  /// No description provided for @fairyStone.
  ///
  /// In en, this message translates to:
  /// **'Attribute Stone'**
  String get fairyStone;

  /// No description provided for @fairyStoneNone.
  ///
  /// In en, this message translates to:
  /// **'No stone'**
  String get fairyStoneNone;

  /// No description provided for @fairyStoneHint.
  ///
  /// In en, this message translates to:
  /// **'With a stone, that bonus stat appears {p}% of the time'**
  String fairyStoneHint(String p);

  /// No description provided for @fairyAccel.
  ///
  /// In en, this message translates to:
  /// **'Accelerator'**
  String get fairyAccel;

  /// No description provided for @fairyAccelMinutes.
  ///
  /// In en, this message translates to:
  /// **'-{t}'**
  String fairyAccelMinutes(String t);

  /// No description provided for @fairyUse.
  ///
  /// In en, this message translates to:
  /// **'Use'**
  String get fairyUse;

  /// No description provided for @fairyBuy.
  ///
  /// In en, this message translates to:
  /// **'Buy'**
  String get fairyBuy;

  /// No description provided for @fairyOwned.
  ///
  /// In en, this message translates to:
  /// **'Owned {n}'**
  String fairyOwned(String n);

  /// No description provided for @fairyDex.
  ///
  /// In en, this message translates to:
  /// **'Fairy Codex'**
  String get fairyDex;

  /// No description provided for @fairyDexGrades.
  ///
  /// In en, this message translates to:
  /// **'Grades {n}/{max}'**
  String fairyDexGrades(String n, String max);

  /// No description provided for @fairyDexSubs.
  ///
  /// In en, this message translates to:
  /// **'Bonus stats {n}/{max}'**
  String fairyDexSubs(String n, String max);

  /// No description provided for @fairyGacha.
  ///
  /// In en, this message translates to:
  /// **'Fairy Egg Draw'**
  String get fairyGacha;

  /// No description provided for @fairyGachaOne.
  ///
  /// In en, this message translates to:
  /// **'x1'**
  String get fairyGachaOne;

  /// No description provided for @fairyGachaTen.
  ///
  /// In en, this message translates to:
  /// **'x10'**
  String get fairyGachaTen;

  /// No description provided for @fairyGachaPity.
  ///
  /// In en, this message translates to:
  /// **'Legendary+ guaranteed within {n}'**
  String fairyGachaPity(String n);

  /// No description provided for @fairyGachaOdds.
  ///
  /// In en, this message translates to:
  /// **'Odds'**
  String get fairyGachaOdds;

  /// No description provided for @fairyGachaOddsNote.
  ///
  /// In en, this message translates to:
  /// **'The draw sets only the egg grade. Type, bonus stat and quality are rolled when it hatches. Mythic comes only from merging.'**
  String get fairyGachaOddsNote;

  /// No description provided for @fairyGachaGot.
  ///
  /// In en, this message translates to:
  /// **'Got {n} eggs'**
  String fairyGachaGot(String n);

  /// No description provided for @fairyDust.
  ///
  /// In en, this message translates to:
  /// **'Fairy Dust'**
  String get fairyDust;

  /// No description provided for @fairyLevel.
  ///
  /// In en, this message translates to:
  /// **'Lv.{n}'**
  String fairyLevel(String n);

  /// No description provided for @fairyLevelUp.
  ///
  /// In en, this message translates to:
  /// **'Level up'**
  String get fairyLevelUp;

  /// No description provided for @fairyMaxLevel.
  ///
  /// In en, this message translates to:
  /// **'Max level'**
  String get fairyMaxLevel;

  /// No description provided for @fairyQuality.
  ///
  /// In en, this message translates to:
  /// **'Quality {p}%'**
  String fairyQuality(String p);

  /// No description provided for @fairyStatMain.
  ///
  /// In en, this message translates to:
  /// **'Base'**
  String get fairyStatMain;

  /// No description provided for @fairyStatSub.
  ///
  /// In en, this message translates to:
  /// **'Bonus'**
  String get fairyStatSub;

  /// No description provided for @fairySkill.
  ///
  /// In en, this message translates to:
  /// **'Skill'**
  String get fairySkill;

  /// No description provided for @fairyCooldown.
  ///
  /// In en, this message translates to:
  /// **'{s}s cooldown'**
  String fairyCooldown(String s);

  /// No description provided for @fairyGoCompanion.
  ///
  /// In en, this message translates to:
  /// **'Make companion'**
  String get fairyGoCompanion;

  /// No description provided for @fairyIsCompanion.
  ///
  /// In en, this message translates to:
  /// **'Companion'**
  String get fairyIsCompanion;

  /// No description provided for @fairyMerge.
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get fairyMerge;

  /// No description provided for @fairyMergeEpicNote.
  ///
  /// In en, this message translates to:
  /// **'Epic → Legendary merges need {n}.'**
  String fairyMergeEpicNote(String n);

  /// No description provided for @fairyReroll.
  ///
  /// In en, this message translates to:
  /// **'Reroll {left}/{max}'**
  String fairyReroll(String left, String max);

  /// No description provided for @fairyRerollTitle.
  ///
  /// In en, this message translates to:
  /// **'Fairy reroll'**
  String get fairyRerollTitle;

  /// No description provided for @fairyRerollConfirm.
  ///
  /// In en, this message translates to:
  /// **'Rerolls the bonus stat and stat values.\nYou can keep the current values after seeing the result (it never gets worse).\nUses per day are limited.'**
  String get fairyRerollConfirm;

  /// No description provided for @fairyRerollPick.
  ///
  /// In en, this message translates to:
  /// **'Which one do you want?'**
  String get fairyRerollPick;

  /// No description provided for @fairyRerollNow.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get fairyRerollNow;

  /// No description provided for @fairyRerollNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get fairyRerollNew;

  /// No description provided for @fairyRerollKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep current'**
  String get fairyRerollKeep;

  /// No description provided for @fairyRerollTake.
  ///
  /// In en, this message translates to:
  /// **'Use new'**
  String get fairyRerollTake;

  /// No description provided for @fairyRerollCap.
  ///
  /// In en, this message translates to:
  /// **'No rerolls left today. Try again tomorrow.'**
  String get fairyRerollCap;

  /// No description provided for @fairyRerollNetwork.
  ///
  /// In en, this message translates to:
  /// **'Needs a server connection. Please try again shortly.'**
  String get fairyRerollNetwork;

  /// No description provided for @fairyMergeHint.
  ///
  /// In en, this message translates to:
  /// **'{n} of the same type & grade → 1 of the next grade. Base and bonus stats are rolled fresh for the new grade.'**
  String fairyMergeHint(String n);

  /// No description provided for @fairyMergePick.
  ///
  /// In en, this message translates to:
  /// **'Materials {n}/{max}'**
  String fairyMergePick(String n, String max);

  /// No description provided for @fairyMergeNoMat.
  ///
  /// In en, this message translates to:
  /// **'Not enough fairies of the same type & grade'**
  String get fairyMergeNoMat;

  /// No description provided for @fairyAutoMerge.
  ///
  /// In en, this message translates to:
  /// **'Auto merge'**
  String get fairyAutoMerge;

  /// No description provided for @fairyAutoMergeConfirm.
  ///
  /// In en, this message translates to:
  /// **'{used} fairies become {made}. Companion and leveled fairies are skipped; lowest quality goes first. Results are rolled fresh.'**
  String fairyAutoMergeConfirm(String used, String made);

  /// No description provided for @fairyAutoMergeNone.
  ///
  /// In en, this message translates to:
  /// **'Nothing to auto merge'**
  String get fairyAutoMergeNone;

  /// No description provided for @fairyRelease.
  ///
  /// In en, this message translates to:
  /// **'Release'**
  String get fairyRelease;

  /// No description provided for @fairyReleaseConfirm.
  ///
  /// In en, this message translates to:
  /// **'Releasing gives {n} fairy dust. This cannot be undone.'**
  String fairyReleaseConfirm(String n);

  /// No description provided for @fairyNew.
  ///
  /// In en, this message translates to:
  /// **'New fairy!'**
  String get fairyNew;

  /// No description provided for @fairyErrJelly.
  ///
  /// In en, this message translates to:
  /// **'Not enough jelly'**
  String get fairyErrJelly;

  /// No description provided for @fairyErrDust.
  ///
  /// In en, this message translates to:
  /// **'Not enough fairy dust'**
  String get fairyErrDust;

  /// No description provided for @fairyErrGeneric.
  ///
  /// In en, this message translates to:
  /// **'Can\'t do that right now'**
  String get fairyErrGeneric;

  /// No description provided for @fairyGradeCommon.
  ///
  /// In en, this message translates to:
  /// **'Common'**
  String get fairyGradeCommon;

  /// No description provided for @fairyGradeRare.
  ///
  /// In en, this message translates to:
  /// **'Rare'**
  String get fairyGradeRare;

  /// No description provided for @fairyGradeEpic.
  ///
  /// In en, this message translates to:
  /// **'Epic'**
  String get fairyGradeEpic;

  /// No description provided for @fairyGradeLegendary.
  ///
  /// In en, this message translates to:
  /// **'Legendary'**
  String get fairyGradeLegendary;

  /// No description provided for @fairyGradeMythic.
  ///
  /// In en, this message translates to:
  /// **'Mythic'**
  String get fairyGradeMythic;

  /// No description provided for @fairyStatAttack.
  ///
  /// In en, this message translates to:
  /// **'Attack'**
  String get fairyStatAttack;

  /// No description provided for @fairyStatHp.
  ///
  /// In en, this message translates to:
  /// **'HP'**
  String get fairyStatHp;

  /// No description provided for @fairyStatDefense.
  ///
  /// In en, this message translates to:
  /// **'Damage taken'**
  String get fairyStatDefense;

  /// No description provided for @fairyStatAttackSpeed.
  ///
  /// In en, this message translates to:
  /// **'Attack speed'**
  String get fairyStatAttackSpeed;

  /// No description provided for @fairyStatCritDamage.
  ///
  /// In en, this message translates to:
  /// **'Crit damage'**
  String get fairyStatCritDamage;

  /// No description provided for @fairyStatBossDamage.
  ///
  /// In en, this message translates to:
  /// **'Boss damage'**
  String get fairyStatBossDamage;

  /// No description provided for @fairyStatPetShare.
  ///
  /// In en, this message translates to:
  /// **'Bug damage'**
  String get fairyStatPetShare;

  /// No description provided for @fairySkillBurst.
  ///
  /// In en, this message translates to:
  /// **'Deals {s}s worth of damage at once'**
  String fairySkillBurst(String s);

  /// No description provided for @fairySkillHeal.
  ///
  /// In en, this message translates to:
  /// **'Heals {p}% max HP when below 60%'**
  String fairySkillHeal(String p);

  /// No description provided for @fairySkillGuard.
  ///
  /// In en, this message translates to:
  /// **'For {d}s, -{p}% damage taken'**
  String fairySkillGuard(String d, String p);

  /// No description provided for @fairySkillHaste.
  ///
  /// In en, this message translates to:
  /// **'For {d}s, +{p}% attack speed'**
  String fairySkillHaste(String d, String p);

  /// No description provided for @fairySkillCrits.
  ///
  /// In en, this message translates to:
  /// **'All hits are critical for {s}s'**
  String fairySkillCrits(String s);

  /// No description provided for @fairySkillBossBurst.
  ///
  /// In en, this message translates to:
  /// **'Deals {s}s worth of damage to bosses'**
  String fairySkillBossBurst(String s);

  /// No description provided for @fairySkillPet.
  ///
  /// In en, this message translates to:
  /// **'For {d}s, +{p}% bug damage'**
  String fairySkillPet(String d, String p);

  /// No description provided for @fairySkillStand.
  ///
  /// In en, this message translates to:
  /// **'Once, survive a fatal hit with {p}% HP'**
  String fairySkillStand(String p);

  /// No description provided for @fairyEggPop.
  ///
  /// In en, this message translates to:
  /// **'Fairy egg · {grade}'**
  String fairyEggPop(String grade);

  /// No description provided for @guildTitle.
  ///
  /// In en, this message translates to:
  /// **'Guild'**
  String get guildTitle;

  /// No description provided for @guildIntro.
  ///
  /// In en, this message translates to:
  /// **'Join a guild to chat with guildmates — guild missions, bosses and guild wars are coming soon.'**
  String get guildIntro;

  /// No description provided for @guildUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load guild info. Please try again in a moment.'**
  String get guildUnavailable;

  /// No description provided for @guildRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get guildRetry;

  /// No description provided for @guildSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search guild name'**
  String get guildSearchHint;

  /// No description provided for @guildEmptyList.
  ///
  /// In en, this message translates to:
  /// **'No guilds found. Why not create one?'**
  String get guildEmptyList;

  /// No description provided for @guildCreate.
  ///
  /// In en, this message translates to:
  /// **'Create guild'**
  String get guildCreate;

  /// No description provided for @guildNameHint.
  ///
  /// In en, this message translates to:
  /// **'Guild name ({min}–{max} chars)'**
  String guildNameHint(int min, int max);

  /// No description provided for @guildJoinModeOpen.
  ///
  /// In en, this message translates to:
  /// **'Open — anyone can join instantly'**
  String get guildJoinModeOpen;

  /// No description provided for @guildJoinModeApproval.
  ///
  /// In en, this message translates to:
  /// **'Approval — leaders review requests'**
  String get guildJoinModeApproval;

  /// No description provided for @guildJoinModeOpenShort.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get guildJoinModeOpenShort;

  /// No description provided for @guildJoinModeApprovalShort.
  ///
  /// In en, this message translates to:
  /// **'Approval'**
  String get guildJoinModeApprovalShort;

  /// No description provided for @guildJoin.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get guildJoin;

  /// No description provided for @guildRequest.
  ///
  /// In en, this message translates to:
  /// **'Request'**
  String get guildRequest;

  /// No description provided for @guildCancelRequest.
  ///
  /// In en, this message translates to:
  /// **'Cancel request'**
  String get guildCancelRequest;

  /// No description provided for @guildFull.
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get guildFull;

  /// No description provided for @guildMembersCount.
  ///
  /// In en, this message translates to:
  /// **'{n}/{max} members'**
  String guildMembersCount(int n, int max);

  /// No description provided for @guildAvgPower.
  ///
  /// In en, this message translates to:
  /// **'Avg. power {v}'**
  String guildAvgPower(String v);

  /// No description provided for @guildCooldown.
  ///
  /// In en, this message translates to:
  /// **'You can join another guild in {time}'**
  String guildCooldown(String time);

  /// No description provided for @guildTabMembers.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get guildTabMembers;

  /// No description provided for @guildTabChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get guildTabChat;

  /// No description provided for @guildTabRequests.
  ///
  /// In en, this message translates to:
  /// **'Req. {n}'**
  String guildTabRequests(int n);

  /// No description provided for @guildRoleLeader.
  ///
  /// In en, this message translates to:
  /// **'Leader'**
  String get guildRoleLeader;

  /// No description provided for @guildRoleDeputy.
  ///
  /// In en, this message translates to:
  /// **'Deputy'**
  String get guildRoleDeputy;

  /// No description provided for @guildRoleMember.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get guildRoleMember;

  /// No description provided for @guildLastSeenNow.
  ///
  /// In en, this message translates to:
  /// **'Online recently'**
  String get guildLastSeenNow;

  /// No description provided for @guildLastSeenHours.
  ///
  /// In en, this message translates to:
  /// **'{n}h ago'**
  String guildLastSeenHours(int n);

  /// No description provided for @guildLastSeenDays.
  ///
  /// In en, this message translates to:
  /// **'{n}d ago'**
  String guildLastSeenDays(int n);

  /// No description provided for @guildNoticeEmpty.
  ///
  /// In en, this message translates to:
  /// **'No guild introduction yet'**
  String get guildNoticeEmpty;

  /// No description provided for @guildNoticeHint.
  ///
  /// In en, this message translates to:
  /// **'Introduce your guild'**
  String get guildNoticeHint;

  /// No description provided for @guildEditNotice.
  ///
  /// In en, this message translates to:
  /// **'Edit introduction'**
  String get guildEditNotice;

  /// No description provided for @guildChangeJoinMode.
  ///
  /// In en, this message translates to:
  /// **'Join mode'**
  String get guildChangeJoinMode;

  /// No description provided for @guildSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get guildSave;

  /// No description provided for @guildLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave guild'**
  String get guildLeave;

  /// No description provided for @guildLeaveConfirm.
  ///
  /// In en, this message translates to:
  /// **'After leaving, you can\'t join another guild for {hours} hours. Leave?'**
  String guildLeaveConfirm(int hours);

  /// No description provided for @guildLeaveLastConfirm.
  ///
  /// In en, this message translates to:
  /// **'You\'re the last member — the guild will be disbanded. Leave?'**
  String get guildLeaveLastConfirm;

  /// No description provided for @guildLeaderLeaveNote.
  ///
  /// In en, this message translates to:
  /// **'Leadership passes to a deputy (or the most active member).'**
  String get guildLeaderLeaveNote;

  /// No description provided for @guildKick.
  ///
  /// In en, this message translates to:
  /// **'Remove from guild'**
  String get guildKick;

  /// No description provided for @guildKickConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove {name} from the guild?'**
  String guildKickConfirm(String name);

  /// No description provided for @guildMakeDeputy.
  ///
  /// In en, this message translates to:
  /// **'Make deputy'**
  String get guildMakeDeputy;

  /// No description provided for @guildRemoveDeputy.
  ///
  /// In en, this message translates to:
  /// **'Remove deputy'**
  String get guildRemoveDeputy;

  /// No description provided for @guildTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer leadership'**
  String get guildTransfer;

  /// No description provided for @guildTransferConfirm.
  ///
  /// In en, this message translates to:
  /// **'Make {name} the guild leader?'**
  String guildTransferConfirm(String name);

  /// No description provided for @guildAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get guildAccept;

  /// No description provided for @guildReject.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get guildReject;

  /// No description provided for @guildNoRequests.
  ///
  /// In en, this message translates to:
  /// **'No join requests'**
  String get guildNoRequests;

  /// No description provided for @guildCreated.
  ///
  /// In en, this message translates to:
  /// **'Guild created!'**
  String get guildCreated;

  /// No description provided for @guildJoined.
  ///
  /// In en, this message translates to:
  /// **'You joined the guild!'**
  String get guildJoined;

  /// No description provided for @guildRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Join request sent'**
  String get guildRequestSent;

  /// No description provided for @guildChatEmpty.
  ///
  /// In en, this message translates to:
  /// **'No guild messages yet. Say hello!'**
  String get guildChatEmpty;

  /// No description provided for @guildErrNameTaken.
  ///
  /// In en, this message translates to:
  /// **'That name is already taken'**
  String get guildErrNameTaken;

  /// No description provided for @guildErrNameInvalid.
  ///
  /// In en, this message translates to:
  /// **'That name can\'t be used (check length, characters and words)'**
  String get guildErrNameInvalid;

  /// No description provided for @guildErrCooldown.
  ///
  /// In en, this message translates to:
  /// **'You can\'t join another guild yet'**
  String get guildErrCooldown;

  /// No description provided for @guildErrFull.
  ///
  /// In en, this message translates to:
  /// **'This guild is full'**
  String get guildErrFull;

  /// No description provided for @guildErrTooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many pending requests — cancel one first'**
  String get guildErrTooManyRequests;

  /// No description provided for @guildErrRequestsFull.
  ///
  /// In en, this message translates to:
  /// **'This guild has too many requests. Try again later'**
  String get guildErrRequestsFull;

  /// No description provided for @guildErrDeputyFull.
  ///
  /// In en, this message translates to:
  /// **'No more deputy slots'**
  String get guildErrDeputyFull;

  /// No description provided for @guildErrNoticeInvalid.
  ///
  /// In en, this message translates to:
  /// **'That introduction can\'t be used'**
  String get guildErrNoticeInvalid;

  /// No description provided for @guildErrGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again'**
  String get guildErrGeneric;

  /// No description provided for @guildCreateWithCost.
  ///
  /// In en, this message translates to:
  /// **'Create guild · {cost} jelly'**
  String guildCreateWithCost(int cost);

  /// No description provided for @guildCreateNeedJelly.
  ///
  /// In en, this message translates to:
  /// **'You need {cost} jelly to create a guild'**
  String guildCreateNeedJelly(int cost);

  /// No description provided for @guildErrJelly.
  ///
  /// In en, this message translates to:
  /// **'Not enough jelly'**
  String get guildErrJelly;

  /// No description provided for @guildTabMissions.
  ///
  /// In en, this message translates to:
  /// **'Missions'**
  String get guildTabMissions;

  /// No description provided for @guildMissionForest.
  ///
  /// In en, this message translates to:
  /// **'Forest survey'**
  String get guildMissionForest;

  /// No description provided for @guildMissionCave.
  ///
  /// In en, this message translates to:
  /// **'Cave expedition'**
  String get guildMissionCave;

  /// No description provided for @guildMissionSwamp.
  ///
  /// In en, this message translates to:
  /// **'Swamp search'**
  String get guildMissionSwamp;

  /// No description provided for @guildMissionRuins.
  ///
  /// In en, this message translates to:
  /// **'Ruins dig'**
  String get guildMissionRuins;

  /// No description provided for @guildMissionCanyon.
  ///
  /// In en, this message translates to:
  /// **'Canyon patrol'**
  String get guildMissionCanyon;

  /// No description provided for @guildMissionMeadow.
  ///
  /// In en, this message translates to:
  /// **'Meadow gathering'**
  String get guildMissionMeadow;

  /// No description provided for @guildMissionErrNoStarts.
  ///
  /// In en, this message translates to:
  /// **'No missions left today'**
  String get guildMissionErrNoStarts;

  /// No description provided for @guildMissionErrRunning.
  ///
  /// In en, this message translates to:
  /// **'You already have a mission in progress'**
  String get guildMissionErrRunning;

  /// No description provided for @guildMissionErrClosed.
  ///
  /// In en, this message translates to:
  /// **'That mission has already ended'**
  String get guildMissionErrClosed;

  /// No description provided for @guildMissionErrHelped.
  ///
  /// In en, this message translates to:
  /// **'You already helped this mission'**
  String get guildMissionErrHelped;

  /// No description provided for @guildMissionErrHelpersFull.
  ///
  /// In en, this message translates to:
  /// **'This mission already has enough helpers'**
  String get guildMissionErrHelpersFull;

  /// No description provided for @guildMissionErrOwn.
  ///
  /// In en, this message translates to:
  /// **'You can\'t help your own mission'**
  String get guildMissionErrOwn;

  /// No description provided for @guildMissionErrNothing.
  ///
  /// In en, this message translates to:
  /// **'No rewards to claim'**
  String get guildMissionErrNothing;

  /// No description provided for @guildMissionHelped.
  ///
  /// In en, this message translates to:
  /// **'Helped! Your power was added'**
  String get guildMissionHelped;

  /// No description provided for @guildMissionSoloHint.
  ///
  /// In en, this message translates to:
  /// **'You can clear this one alone — it succeeds instantly.'**
  String get guildMissionSoloHint;

  /// No description provided for @guildMissionWaitHint.
  ///
  /// In en, this message translates to:
  /// **'Choose how long to wait. Guildmates who help add their power — if the total beats the requirement when time runs out, you succeed. If 3 helpers join, it succeeds instantly! Longer waits give bigger rewards.'**
  String get guildMissionWaitHint;

  /// No description provided for @guildMissionWaitOption.
  ///
  /// In en, this message translates to:
  /// **'Wait {min} min · reward ×{mult}'**
  String guildMissionWaitOption(int min, String mult);

  /// No description provided for @guildMissionClaimTitle.
  ///
  /// In en, this message translates to:
  /// **'Mission rewards'**
  String get guildMissionClaimTitle;

  /// No description provided for @guildMissionCoins.
  ///
  /// In en, this message translates to:
  /// **'Guild coins +{n}'**
  String guildMissionCoins(int n);

  /// No description provided for @guildMissionEgg.
  ///
  /// In en, this message translates to:
  /// **'Fairy egg ×{n}!'**
  String guildMissionEgg(int n);

  /// No description provided for @guildMissionStartsLeft.
  ///
  /// In en, this message translates to:
  /// **'Missions {n}/{max}'**
  String guildMissionStartsLeft(int n, int max);

  /// No description provided for @guildMissionHelpLeft.
  ///
  /// In en, this message translates to:
  /// **'Help rewards {n}/{max}'**
  String guildMissionHelpLeft(int n, int max);

  /// No description provided for @guildMissionReset.
  ///
  /// In en, this message translates to:
  /// **'resets in {time}'**
  String guildMissionReset(String time);

  /// No description provided for @guildMissionClaimable.
  ///
  /// In en, this message translates to:
  /// **'{n} mission rewards ready'**
  String guildMissionClaimable(int n);

  /// No description provided for @guildMissionClaim.
  ///
  /// In en, this message translates to:
  /// **'Claim'**
  String get guildMissionClaim;

  /// No description provided for @guildMissionActive.
  ///
  /// In en, this message translates to:
  /// **'Help requests'**
  String get guildMissionActive;

  /// No description provided for @guildMissionNoActive.
  ///
  /// In en, this message translates to:
  /// **'No missions in progress right now'**
  String get guildMissionNoActive;

  /// No description provided for @guildMissionBoard.
  ///
  /// In en, this message translates to:
  /// **'Today\'s board'**
  String get guildMissionBoard;

  /// No description provided for @guildMissionRecent.
  ///
  /// In en, this message translates to:
  /// **'Today\'s results'**
  String get guildMissionRecent;

  /// No description provided for @guildMissionMine.
  ///
  /// In en, this message translates to:
  /// **'My mission'**
  String get guildMissionMine;

  /// No description provided for @guildMissionOwner.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s mission'**
  String guildMissionOwner(String name);

  /// No description provided for @guildMissionProgress.
  ///
  /// In en, this message translates to:
  /// **'{p}% · helpers {n}/{max}'**
  String guildMissionProgress(int p, int n, int max);

  /// No description provided for @guildMissionHelp.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get guildMissionHelp;

  /// No description provided for @guildMissionHelpedTag.
  ///
  /// In en, this message translates to:
  /// **'Helped'**
  String get guildMissionHelpedTag;

  /// No description provided for @guildMissionSlotSolo.
  ///
  /// In en, this message translates to:
  /// **'Power ×{mult} · clear it solo'**
  String guildMissionSlotSolo(double mult);

  /// No description provided for @guildMissionSlotNeed.
  ///
  /// In en, this message translates to:
  /// **'Power ×{mult} · needs help'**
  String guildMissionSlotNeed(double mult);

  /// No description provided for @guildMissionStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get guildMissionStart;

  /// No description provided for @guildMissionSuccess.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get guildMissionSuccess;

  /// No description provided for @guildMissionPartial.
  ///
  /// In en, this message translates to:
  /// **'{p}%'**
  String guildMissionPartial(int p);

  /// No description provided for @guildMissionChatMine.
  ///
  /// In en, this message translates to:
  /// **'You asked your guild for help'**
  String get guildMissionChatMine;

  /// No description provided for @guildMissionChatAsk.
  ///
  /// In en, this message translates to:
  /// **'{name} needs help with a mission!'**
  String guildMissionChatAsk(String name);

  /// No description provided for @guildLevel.
  ///
  /// In en, this message translates to:
  /// **'Lv {n}'**
  String guildLevel(int n);

  /// No description provided for @guildCoins.
  ///
  /// In en, this message translates to:
  /// **'{n} guild coins'**
  String guildCoins(int n);

  /// No description provided for @guildDonate.
  ///
  /// In en, this message translates to:
  /// **'Check in'**
  String get guildDonate;

  /// No description provided for @guildDonateDoneShort.
  ///
  /// In en, this message translates to:
  /// **'Checked'**
  String get guildDonateDoneShort;

  /// No description provided for @guildDonateOk.
  ///
  /// In en, this message translates to:
  /// **'Checked in! Guild coins and guild EXP added'**
  String get guildDonateOk;

  /// No description provided for @guildDonateDone.
  ///
  /// In en, this message translates to:
  /// **'Already checked in today'**
  String get guildDonateDone;

  /// No description provided for @guildSkills.
  ///
  /// In en, this message translates to:
  /// **'Skills'**
  String get guildSkills;

  /// No description provided for @guildShop.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get guildShop;

  /// No description provided for @guildSkillAttack.
  ///
  /// In en, this message translates to:
  /// **'Attack'**
  String get guildSkillAttack;

  /// No description provided for @guildSkillHp.
  ///
  /// In en, this message translates to:
  /// **'HP'**
  String get guildSkillHp;

  /// No description provided for @guildSkillGold.
  ///
  /// In en, this message translates to:
  /// **'Gold'**
  String get guildSkillGold;

  /// No description provided for @guildSkillMaterial.
  ///
  /// In en, this message translates to:
  /// **'Material find'**
  String get guildSkillMaterial;

  /// No description provided for @guildSkillXp.
  ///
  /// In en, this message translates to:
  /// **'EXP'**
  String get guildSkillXp;

  /// No description provided for @guildSkillMission.
  ///
  /// In en, this message translates to:
  /// **'Mission rewards'**
  String get guildSkillMission;

  /// No description provided for @guildSkillHeader.
  ///
  /// In en, this message translates to:
  /// **'Skill points left: {n}'**
  String guildSkillHeader(int n);

  /// No description provided for @guildSkillNote.
  ///
  /// In en, this message translates to:
  /// **'Buffs apply to every guildmate while hunting (offline gold too). They don\'t apply to duels or events. Leaving the guild removes them. Guild level +1 = 1 point.'**
  String get guildSkillNote;

  /// No description provided for @guildSkillValue.
  ///
  /// In en, this message translates to:
  /// **'+{now}% (max +{max}%)'**
  String guildSkillValue(String now, String max);

  /// No description provided for @guildSkillNoPoints.
  ///
  /// In en, this message translates to:
  /// **'No skill points left'**
  String get guildSkillNoPoints;

  /// No description provided for @guildSkillMax.
  ///
  /// In en, this message translates to:
  /// **'Already maxed'**
  String get guildSkillMax;

  /// No description provided for @guildSkillForbidden.
  ///
  /// In en, this message translates to:
  /// **'Only the leader and deputies can do this'**
  String get guildSkillForbidden;

  /// No description provided for @guildSkillReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get guildSkillReset;

  /// No description provided for @guildSkillResetBody.
  ///
  /// In en, this message translates to:
  /// **'Reset all guild skills and refund every point?'**
  String get guildSkillResetBody;

  /// No description provided for @guildShopNote.
  ///
  /// In en, this message translates to:
  /// **'Earn coins from missions, helping, check-ins and the guild boss.'**
  String get guildShopNote;

  /// No description provided for @guildShopMaterials.
  ///
  /// In en, this message translates to:
  /// **'Materials ({h}h of hunting)'**
  String guildShopMaterials(String h);

  /// No description provided for @guildShopFossil.
  ///
  /// In en, this message translates to:
  /// **'Fossil ×{n}'**
  String guildShopFossil(int n);

  /// No description provided for @guildShopFairyDust.
  ///
  /// In en, this message translates to:
  /// **'Fairy dust ×{n}'**
  String guildShopFairyDust(int n);

  /// No description provided for @guildShopFairyEgg.
  ///
  /// In en, this message translates to:
  /// **'Fairy egg ×{n}'**
  String guildShopFairyEgg(int n);

  /// No description provided for @guildShopSkillShard.
  ///
  /// In en, this message translates to:
  /// **'{grade} wild shard ×{n}'**
  String guildShopSkillShard(String grade, int n);

  /// No description provided for @guildShopLimitDay.
  ///
  /// In en, this message translates to:
  /// **'Today {n}/{max}'**
  String guildShopLimitDay(int n, int max);

  /// No description provided for @guildShopLimitWeek.
  ///
  /// In en, this message translates to:
  /// **'This week {n}/{max}'**
  String guildShopLimitWeek(int n, int max);

  /// No description provided for @guildShopBought.
  ///
  /// In en, this message translates to:
  /// **'Bought: {item}'**
  String guildShopBought(String item);

  /// No description provided for @guildShopSoldOut.
  ///
  /// In en, this message translates to:
  /// **'Purchase limit reached'**
  String get guildShopSoldOut;

  /// No description provided for @guildShopSoldOutShort.
  ///
  /// In en, this message translates to:
  /// **'Sold out'**
  String get guildShopSoldOutShort;

  /// No description provided for @guildShopNoCoins.
  ///
  /// In en, this message translates to:
  /// **'Not enough guild coins'**
  String get guildShopNoCoins;

  /// No description provided for @guildTabBoss.
  ///
  /// In en, this message translates to:
  /// **'Boss'**
  String get guildTabBoss;

  /// No description provided for @guildBossTitle.
  ///
  /// In en, this message translates to:
  /// **'Guild boss · Stage {n}'**
  String guildBossTitle(int n);

  /// No description provided for @guildBossAttack.
  ///
  /// In en, this message translates to:
  /// **'Attack ({n} left today)'**
  String guildBossAttack(int n);

  /// No description provided for @guildBossNote.
  ///
  /// In en, this message translates to:
  /// **'Damage comes from your duel defense team (fairies, skills and gear don\'t count). HP is shared by the whole guild and carries over all week.'**
  String get guildBossNote;

  /// No description provided for @guildBossNoTeam.
  ///
  /// In en, this message translates to:
  /// **'Register a duel defense team to attack the boss.'**
  String get guildBossNoTeam;

  /// No description provided for @guildBossNoAttacks.
  ///
  /// In en, this message translates to:
  /// **'No attacks left today'**
  String get guildBossNoAttacks;

  /// No description provided for @guildBossHit.
  ///
  /// In en, this message translates to:
  /// **'{d} damage'**
  String guildBossHit(String d);

  /// No description provided for @guildBossKilled.
  ///
  /// In en, this message translates to:
  /// **'Boss defeated! Next stage'**
  String get guildBossKilled;

  /// No description provided for @guildBossMine.
  ///
  /// In en, this message translates to:
  /// **'My damage this week: {d}'**
  String guildBossMine(String d);

  /// No description provided for @guildBossRank.
  ///
  /// In en, this message translates to:
  /// **'Guild rank this week: #{n}'**
  String guildBossRank(int n);

  /// No description provided for @guildBossRankNone.
  ///
  /// In en, this message translates to:
  /// **'Not ranked yet — attack to enter the ranking'**
  String get guildBossRankNone;

  /// No description provided for @guildBossTopRow.
  ///
  /// In en, this message translates to:
  /// **'Stage {s} · {p}%'**
  String guildBossTopRow(int s, int p);

  /// No description provided for @guildBossLastWeek.
  ///
  /// In en, this message translates to:
  /// **'Last week #{rank} — {jelly} jelly'**
  String guildBossLastWeek(int rank, int jelly);

  /// No description provided for @guildBossClaimed.
  ///
  /// In en, this message translates to:
  /// **'Received {n} jelly!'**
  String guildBossClaimed(int n);

  /// No description provided for @guildTabWar.
  ///
  /// In en, this message translates to:
  /// **'War'**
  String get guildTabWar;

  /// No description provided for @guildWarBreed.
  ///
  /// In en, this message translates to:
  /// **'Breeding'**
  String get guildWarBreed;

  /// No description provided for @guildWarForge.
  ///
  /// In en, this message translates to:
  /// **'Forging'**
  String get guildWarForge;

  /// No description provided for @guildWarHunt.
  ///
  /// In en, this message translates to:
  /// **'Hunting'**
  String get guildWarHunt;

  /// No description provided for @guildWarDuel.
  ///
  /// In en, this message translates to:
  /// **'Duels'**
  String get guildWarDuel;

  /// No description provided for @guildWarTrain.
  ///
  /// In en, this message translates to:
  /// **'Training'**
  String get guildWarTrain;

  /// No description provided for @guildWarBoss.
  ///
  /// In en, this message translates to:
  /// **'Guild boss'**
  String get guildWarBoss;

  /// No description provided for @guildWarClash.
  ///
  /// In en, this message translates to:
  /// **'Power clash'**
  String get guildWarClash;

  /// No description provided for @guildWarBreedHint.
  ///
  /// In en, this message translates to:
  /// **'Finish breeding, collect hatched eggs and synthesize. Jelly-rushed completions don\'t count.'**
  String get guildWarBreedHint;

  /// No description provided for @guildWarForgeHint.
  ///
  /// In en, this message translates to:
  /// **'Forge gear — higher grades score far more.'**
  String get guildWarForgeHint;

  /// No description provided for @guildWarHuntHint.
  ///
  /// In en, this message translates to:
  /// **'Defeat elites and zone bosses.'**
  String get guildWarHuntHint;

  /// No description provided for @guildWarDuelHint.
  ///
  /// In en, this message translates to:
  /// **'Win duels (confirmed by the server).'**
  String get guildWarDuelHint;

  /// No description provided for @guildWarTrainHint.
  ///
  /// In en, this message translates to:
  /// **'Level up bugs, start training steps and finish skill training.'**
  String get guildWarTrainHint;

  /// No description provided for @guildWarBossHint.
  ///
  /// In en, this message translates to:
  /// **'Attack the guild boss.'**
  String get guildWarBossHint;

  /// No description provided for @guildWarClashHint.
  ///
  /// In en, this message translates to:
  /// **'Nothing to do today! Members are paired 1:1 by duel defense team power and fight automatically. Results come in when you open this tab.'**
  String get guildWarClashHint;

  /// No description provided for @guildWarTier.
  ///
  /// In en, this message translates to:
  /// **'{tier} tier · {gr} GR'**
  String guildWarTier(String tier, int gr);

  /// No description provided for @guildWarClosed.
  ///
  /// In en, this message translates to:
  /// **'Guild wars aren\'t open yet.'**
  String get guildWarClosed;

  /// No description provided for @guildWarOpensOn.
  ///
  /// In en, this message translates to:
  /// **'Guild wars start the week of {date}.'**
  String guildWarOpensOn(String date);

  /// No description provided for @guildWarNeedMembers.
  ///
  /// In en, this message translates to:
  /// **'A guild needs at least {n} members to enter this week\'s war.'**
  String guildWarNeedMembers(int n);

  /// No description provided for @guildWarVs.
  ///
  /// In en, this message translates to:
  /// **'vs {name}'**
  String guildWarVs(String name);

  /// No description provided for @guildWarVsVirtual.
  ///
  /// In en, this message translates to:
  /// **'vs Wild Guild (tier average)'**
  String get guildWarVsVirtual;

  /// No description provided for @guildWarVirtualName.
  ///
  /// In en, this message translates to:
  /// **'Wild'**
  String get guildWarVirtualName;

  /// No description provided for @guildWarDayOf.
  ///
  /// In en, this message translates to:
  /// **'Day {d} · {theme}'**
  String guildWarDayOf(int d, String theme);

  /// No description provided for @guildWarMyToday.
  ///
  /// In en, this message translates to:
  /// **'My points today {n}/{cap}'**
  String guildWarMyToday(int n, int cap);

  /// No description provided for @guildWarWin.
  ///
  /// In en, this message translates to:
  /// **'Victory'**
  String get guildWarWin;

  /// No description provided for @guildWarLose.
  ///
  /// In en, this message translates to:
  /// **'Defeat'**
  String get guildWarLose;

  /// No description provided for @guildWarDraw.
  ///
  /// In en, this message translates to:
  /// **'Draw'**
  String get guildWarDraw;

  /// No description provided for @guildWarPoints.
  ///
  /// In en, this message translates to:
  /// **'Points {a} : {b}'**
  String guildWarPoints(int a, int b);

  /// No description provided for @guildWarClashResult.
  ///
  /// In en, this message translates to:
  /// **'Day 7 duels {a} : {b}'**
  String guildWarClashResult(int a, int b);

  /// No description provided for @guildWarReward.
  ///
  /// In en, this message translates to:
  /// **'{result} reward — {coins} coins · {jelly} jelly'**
  String guildWarReward(String result, int coins, int jelly);

  /// No description provided for @guildWarClaimed.
  ///
  /// In en, this message translates to:
  /// **'Received {coins} coins · {jelly} jelly!'**
  String guildWarClaimed(int coins, int jelly);

  /// No description provided for @duelPickDeployed.
  ///
  /// In en, this message translates to:
  /// **'In slot {n}'**
  String duelPickDeployed(int n);

  /// No description provided for @fairyDexHelp.
  ///
  /// In en, this message translates to:
  /// **'The Fairy Codex records every fairy you have ever obtained. Each of the 8 fairies has two rows to fill:\n• Grade dots — a dot lights up the first time you get that fairy at that grade.\n• Stat stones — a stone lights up the first time you get that fairy with that bonus stat.\nA fairy is recorded when it hatches from an egg in the nest or is made by merging, and records stay even if you release the fairy. Fill cells to earn rewards below (fairy dust, accelerators, fossils). It does not give stats.'**
  String get fairyDexHelp;

  /// No description provided for @fairyDexLegendGrades.
  ///
  /// In en, this message translates to:
  /// **'Grade dots (lit = obtained at that grade)'**
  String get fairyDexLegendGrades;

  /// No description provided for @fairyDexLegendSubs.
  ///
  /// In en, this message translates to:
  /// **'Stat stones (bright = obtained with that bonus stat)'**
  String get fairyDexLegendSubs;

  /// No description provided for @fairyDexRewards.
  ///
  /// In en, this message translates to:
  /// **'Codex rewards · {n}/{max} collected'**
  String fairyDexRewards(int n, int max);

  /// No description provided for @fairyDexClaimed.
  ///
  /// In en, this message translates to:
  /// **'Codex reward received!'**
  String get fairyDexClaimed;

  /// No description provided for @fairyNestPickEgg.
  ///
  /// In en, this message translates to:
  /// **'Pick an egg to place first'**
  String get fairyNestPickEgg;

  /// No description provided for @guideTitle.
  ///
  /// In en, this message translates to:
  /// **'Guidebook'**
  String get guideTitle;

  /// No description provided for @guideIntro.
  ///
  /// In en, this message translates to:
  /// **'Every bug is different even within a species. Tap a topic to see what each term means.'**
  String get guideIntro;

  /// No description provided for @guideElementTitle.
  ///
  /// In en, this message translates to:
  /// **'Elements (Wood·Fire·Earth·Metal·Water)'**
  String get guideElementTitle;

  /// No description provided for @guideElementBody.
  ///
  /// In en, this message translates to:
  /// **'Each bug has one element. In duels, when a bug clashes with an element it restrains, it deals {mult}x damage. The red arrows show who beats whom.'**
  String guideElementBody(String mult);

  /// No description provided for @guideElementLine.
  ///
  /// In en, this message translates to:
  /// **'{a} beats {b}'**
  String guideElementLine(String a, String b);

  /// No description provided for @guideSpecialtyTitle.
  ///
  /// In en, this message translates to:
  /// **'Specialty (fighting style)'**
  String get guideSpecialtyTitle;

  /// No description provided for @guideSpecialtyBody.
  ///
  /// In en, this message translates to:
  /// **'Each species has a specialty that decides how it fights in duels.'**
  String get guideSpecialtyBody;

  /// No description provided for @guideSpecialtyStrike.
  ///
  /// In en, this message translates to:
  /// **'Charges in to ram and flip the opponent.'**
  String get guideSpecialtyStrike;

  /// No description provided for @guideSpecialtyGrip.
  ///
  /// In en, this message translates to:
  /// **'Bites and holds on, pushing the opponent out.'**
  String get guideSpecialtyGrip;

  /// No description provided for @guideSpecialtyToss.
  ///
  /// In en, this message translates to:
  /// **'Lifts the opponent and throws it.'**
  String get guideSpecialtyToss;

  /// No description provided for @guideTemperamentTitle.
  ///
  /// In en, this message translates to:
  /// **'Temperament (fighting tendency)'**
  String get guideTemperamentTitle;

  /// No description provided for @guideTemperamentBody.
  ///
  /// In en, this message translates to:
  /// **'Temperament decides how a bug moves in duels and which stats it can train higher.'**
  String get guideTemperamentBody;

  /// No description provided for @guideTempAggressive.
  ///
  /// In en, this message translates to:
  /// **'Charges often — an attacker.'**
  String get guideTempAggressive;

  /// No description provided for @guideTempCautious.
  ///
  /// In en, this message translates to:
  /// **'Avoids the edge and sidesteps charges.'**
  String get guideTempCautious;

  /// No description provided for @guideTempCunning.
  ///
  /// In en, this message translates to:
  /// **'Circles to the side to hit weak spots.'**
  String get guideTempCunning;

  /// No description provided for @guideTempSteadfast.
  ///
  /// In en, this message translates to:
  /// **'Hard to push — a tank.'**
  String get guideTempSteadfast;

  /// No description provided for @guideTempFickle.
  ///
  /// In en, this message translates to:
  /// **'Mixes all styles.'**
  String get guideTempFickle;

  /// No description provided for @guideTrainCapMods.
  ///
  /// In en, this message translates to:
  /// **'Training cap: {mods}'**
  String guideTrainCapMods(String mods);

  /// No description provided for @guideSizeTitle.
  ///
  /// In en, this message translates to:
  /// **'Size (weight)'**
  String get guideSizeTitle;

  /// No description provided for @guideSizeBody.
  ///
  /// In en, this message translates to:
  /// **'Size is rolled within the species\' range. Bigger bugs get stats ×{min}~×{max}, are harder to push and less likely to fall out of the ring in duels.'**
  String guideSizeBody(String min, String max);

  /// No description provided for @guidePotentialTitle.
  ///
  /// In en, this message translates to:
  /// **'Potential (1–5 stars)'**
  String get guidePotentialTitle;

  /// No description provided for @guidePotentialBody.
  ///
  /// In en, this message translates to:
  /// **'Higher stars raise the part-enhance max level (stars × 10) and the training cap (+{perStar} per star). Merge {fodder} bugs of the same species to gain a star.'**
  String guidePotentialBody(int perStar, int fodder);

  /// No description provided for @guideTraitTitle.
  ///
  /// In en, this message translates to:
  /// **'Bloodline traits (breeding only)'**
  String get guideTraitTitle;

  /// No description provided for @guideTraitBody.
  ///
  /// In en, this message translates to:
  /// **'Only bugs born from breeding can have a trait — wild bugs never do. Traits work both as a pet and in duels.'**
  String get guideTraitBody;

  /// No description provided for @guideTraitEffect.
  ///
  /// In en, this message translates to:
  /// **'Attack +{atk} · HP +{hp}'**
  String guideTraitEffect(String atk, String hp);

  /// No description provided for @guideBreedTitle.
  ///
  /// In en, this message translates to:
  /// **'Breeding & inheritance'**
  String get guideBreedTitle;

  /// No description provided for @guideBreedBody.
  ///
  /// In en, this message translates to:
  /// **'Pair a male and female adult of the same species to get an egg. The child inherits the parents\' element ({el}) and temperament ({tm}) with high chance, and a parent\'s trait ({tr}). If both parents share the same element, temperament or trait, the child is guaranteed to get it — so you can build your own line.'**
  String guideBreedBody(String el, String tm, String tr);

  /// No description provided for @guideVariantTitle.
  ///
  /// In en, this message translates to:
  /// **'Variant bugs'**
  String get guideVariantTitle;

  /// No description provided for @guideVariantBody.
  ///
  /// In en, this message translates to:
  /// **'Very rarely a bug with different colors (rainbow / albino) appears. Chance: wild {wild} · breeding {breed} · variant parent {parent} · egg draw {gacha}. As a pet its stats are +{pet}, in duels +{duel}.'**
  String guideVariantBody(
    String wild,
    String breed,
    String parent,
    String gacha,
    String pet,
    String duel,
  );

  /// No description provided for @guideLifeTitle.
  ///
  /// In en, this message translates to:
  /// **'Life stages'**
  String get guideLifeTitle;

  /// No description provided for @guideLifeBody.
  ///
  /// In en, this message translates to:
  /// **'Egg → Larva → Pupa → Adult. Eggs hatch into larvae only in the incubator. Larvae grow into adults over time. Only adults can be trained, bred and sent to duels.'**
  String get guideLifeBody;

  /// No description provided for @guideDuelTitle.
  ///
  /// In en, this message translates to:
  /// **'Duels'**
  String get guideDuelTitle;

  /// No description provided for @guideDuelBody.
  ///
  /// In en, this message translates to:
  /// **'A bout is a {sec}-second 1:1 physical fight in a round arena. Win by ring-out, flipping, or knockout; when time runs out, remaining HP % decides. A match is 3 bugs, winner stays on. Hitting the side or back deals ×{weak} damage, and critical hits and evasion also apply.'**
  String guideDuelBody(int sec, String weak);

  /// No description provided for @guideTrainTitle.
  ///
  /// In en, this message translates to:
  /// **'Training ground'**
  String get guideTrainTitle;

  /// No description provided for @guideTrainBody.
  ///
  /// In en, this message translates to:
  /// **'Train 5 duel stats per bug: attack, defense, evasion, crit and recovery. Max stage = {base} + potential + temperament/specialty/trait bonuses, so every bug has its own strengths. Mix bugs with different roles in your team!'**
  String guideTrainBody(int base);

  /// No description provided for @bugInfoSizeDetail.
  ///
  /// In en, this message translates to:
  /// **'{mm}mm (range {min}–{max}) · stats ×{mult}'**
  String bugInfoSizeDetail(String mm, String min, String max, String mult);

  /// No description provided for @eventHudShort.
  ///
  /// In en, this message translates to:
  /// **'King\nCup'**
  String get eventHudShort;

  /// No description provided for @fairyStoneName.
  ///
  /// In en, this message translates to:
  /// **'{stat} stone'**
  String fairyStoneName(String stat);

  /// No description provided for @fairyStoneEffect.
  ///
  /// In en, this message translates to:
  /// **'The hatched fairy\'s sub-stat becomes {stat} with {p}% chance'**
  String fairyStoneEffect(String stat, String p);

  /// No description provided for @fairyStoneBuyTitle.
  ///
  /// In en, this message translates to:
  /// **'Buy element stone'**
  String get fairyStoneBuyTitle;

  /// No description provided for @fairyStoneBuyAction.
  ///
  /// In en, this message translates to:
  /// **'Buy'**
  String get fairyStoneBuyAction;

  /// No description provided for @fairyEquippedTag.
  ///
  /// In en, this message translates to:
  /// **'Equipped'**
  String get fairyEquippedTag;

  /// No description provided for @fairyMergeEquipped.
  ///
  /// In en, this message translates to:
  /// **'An equipped fairy can\'t be merged'**
  String get fairyMergeEquipped;

  /// No description provided for @fairyAutoMergeDone.
  ///
  /// In en, this message translates to:
  /// **'Merge results'**
  String get fairyAutoMergeDone;

  /// No description provided for @exchangeToDust.
  ///
  /// In en, this message translates to:
  /// **'Fairy dust'**
  String get exchangeToDust;

  /// No description provided for @exchangeHintDust.
  ///
  /// In en, this message translates to:
  /// **'Trade jelly for fairy dust (1 jelly = 1 dust)'**
  String get exchangeHintDust;

  /// No description provided for @exchangeGetDust.
  ///
  /// In en, this message translates to:
  /// **'Get {amount} fairy dust'**
  String exchangeGetDust(String amount);

  /// No description provided for @fairyStatRange.
  ///
  /// In en, this message translates to:
  /// **'({grade} range {lo}~{hi})'**
  String fairyStatRange(String grade, String lo, String hi);

  /// No description provided for @fairyStopCompanion.
  ///
  /// In en, this message translates to:
  /// **'Stop companion'**
  String get fairyStopCompanion;

  /// No description provided for @fairyHelpTitle.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get fairyHelpTitle;

  /// No description provided for @fairyHelpGradeHead.
  ///
  /// In en, this message translates to:
  /// **'Base stat range by grade (Lv.1)'**
  String get fairyHelpGradeHead;

  /// No description provided for @fairyHelpGradeLine.
  ///
  /// In en, this message translates to:
  /// **'{grade}: {lo} ~ {hi} · max Lv.{max}'**
  String fairyHelpGradeLine(String grade, String lo, String hi, String max);

  /// No description provided for @fairyHelpLevel.
  ///
  /// In en, this message translates to:
  /// **'Each level adds +{p} of the value (Lv.1 basis).'**
  String fairyHelpLevel(String p);

  /// No description provided for @fairyHelpSubHead.
  ///
  /// In en, this message translates to:
  /// **'Sub-stat (one per fairy)'**
  String get fairyHelpSubHead;

  /// No description provided for @fairyHelpSub.
  ///
  /// In en, this message translates to:
  /// **'Rolled at hatching from the list below — {p} of the base range × the stat\'s weight. An element stone raises the chance of the one you want.'**
  String fairyHelpSub(String p);

  /// No description provided for @fairyHelpSubLine.
  ///
  /// In en, this message translates to:
  /// **'{stat}: {grade} {lo} ~ {hi}'**
  String fairyHelpSubLine(String stat, String grade, String lo, String hi);

  /// No description provided for @fairyHelpMergeHead.
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get fairyHelpMergeHead;

  /// No description provided for @fairyHelpMerge.
  ///
  /// In en, this message translates to:
  /// **'{n} fairies of the same kind and grade → 1 of the next grade. Base and sub stats are rolled again, so you can aim for a better one.'**
  String fairyHelpMerge(String n);

  /// No description provided for @fairyGachaOverflowWarn.
  ///
  /// In en, this message translates to:
  /// **'Your fairy box has {free} free slots — {lost} eggs will turn into fairy dust.'**
  String fairyGachaOverflowWarn(String free, String lost);

  /// No description provided for @fairyOverflowToast.
  ///
  /// In en, this message translates to:
  /// **'Box full — {n} eggs became {dust} fairy dust'**
  String fairyOverflowToast(String n, String dust);

  /// No description provided for @fairyOverflowPop.
  ///
  /// In en, this message translates to:
  /// **'Box full · Fairy dust +{dust}'**
  String fairyOverflowPop(String dust);

  /// No description provided for @fairyMergeInvestedConfirm.
  ///
  /// In en, this message translates to:
  /// **'{n} leveled-up fairies will be used. You get back {dust} fairy dust (part of what you spent). Merge?'**
  String fairyMergeInvestedConfirm(String n, String dust);

  /// No description provided for @fairyMergeRefund.
  ///
  /// In en, this message translates to:
  /// **'{dust} fairy dust returned'**
  String fairyMergeRefund(String dust);

  /// No description provided for @exchangeDustLeft.
  ///
  /// In en, this message translates to:
  /// **'{n} left today'**
  String exchangeDustLeft(String n);

  /// No description provided for @exchangeDustCapReached.
  ///
  /// In en, this message translates to:
  /// **'Today\'s limit reached'**
  String get exchangeDustCapReached;

  /// No description provided for @bugLock.
  ///
  /// In en, this message translates to:
  /// **'Lock'**
  String get bugLock;

  /// No description provided for @bugLocked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get bugLocked;

  /// No description provided for @bugUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get bugUnlock;

  /// No description provided for @bugLockedToast.
  ///
  /// In en, this message translates to:
  /// **'Locked — it won\'t be used for merging or dismantling'**
  String get bugLockedToast;

  /// No description provided for @bugUnlockedToast.
  ///
  /// In en, this message translates to:
  /// **'Unlocked'**
  String get bugUnlockedToast;

  /// No description provided for @disassembleLocked.
  ///
  /// In en, this message translates to:
  /// **'Locked bugs can\'t be dismantled. Unlock it first.'**
  String get disassembleLocked;

  /// No description provided for @trainingSumShort.
  ///
  /// In en, this message translates to:
  /// **'Train Lv.{n}'**
  String trainingSumShort(int n);

  /// No description provided for @reviewAskTitle.
  ///
  /// In en, this message translates to:
  /// **'Enjoying Bug Champ?'**
  String get reviewAskTitle;

  /// No description provided for @reviewAskBody.
  ///
  /// In en, this message translates to:
  /// **'If you have a moment, a store review would really help a solo developer.\nThank you for playing!'**
  String get reviewAskBody;

  /// No description provided for @reviewAskLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get reviewAskLater;

  /// No description provided for @trainingNoneShort.
  ///
  /// In en, this message translates to:
  /// **'Untrained'**
  String get trainingNoneShort;

  /// No description provided for @guildComingSoonTitle.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get guildComingSoonTitle;

  /// No description provided for @guildComingSoonBody.
  ///
  /// In en, this message translates to:
  /// **'Guilds — missions, guild boss, shop and weekly guild wars — are coming in an upcoming update. Stay tuned!'**
  String get guildComingSoonBody;

  /// No description provided for @notifChannelName.
  ///
  /// In en, this message translates to:
  /// **'Reward alerts'**
  String get notifChannelName;

  /// No description provided for @notifChannelDesc.
  ///
  /// In en, this message translates to:
  /// **'Lunch/dinner rewards and full offline-reward alerts'**
  String get notifChannelDesc;

  /// No description provided for @eggOddsTitle.
  ///
  /// In en, this message translates to:
  /// **'Bug egg draw odds'**
  String get eggOddsTitle;

  /// No description provided for @eggOddsGradeHead.
  ///
  /// In en, this message translates to:
  /// **'Grade (each species in the grade is equally likely)'**
  String get eggOddsGradeHead;

  /// No description provided for @eggOddsPotentialHead.
  ///
  /// In en, this message translates to:
  /// **'Potential'**
  String get eggOddsPotentialHead;

  /// No description provided for @eggOddsVariant.
  ///
  /// In en, this message translates to:
  /// **'Variant (rainbow/albino): {p}%'**
  String eggOddsVariant(String p);

  /// No description provided for @eggOddsPity.
  ///
  /// In en, this message translates to:
  /// **'Every {n}th draw guarantees {grade} or higher'**
  String eggOddsPity(String n, String grade);

  /// No description provided for @eggOddsNote.
  ///
  /// In en, this message translates to:
  /// **'Odds are per draw. The pity counter resets only when its grade appears.'**
  String get eggOddsNote;

  /// No description provided for @eggOddsGradeLine.
  ///
  /// In en, this message translates to:
  /// **'{grade} {p}% · each species {each}%'**
  String eggOddsGradeLine(String grade, String p, String each);

  /// No description provided for @variantRainbow.
  ///
  /// In en, this message translates to:
  /// **'Rainbow'**
  String get variantRainbow;

  /// No description provided for @variantAlbino.
  ///
  /// In en, this message translates to:
  /// **'Albino'**
  String get variantAlbino;

  /// No description provided for @jellyShortTitle.
  ///
  /// In en, this message translates to:
  /// **'Not enough jelly'**
  String get jellyShortTitle;

  /// No description provided for @jellyShortBody.
  ///
  /// In en, this message translates to:
  /// **'Get jelly in the shop and continue right away.'**
  String get jellyShortBody;

  /// No description provided for @jellyShortGoShop.
  ///
  /// In en, this message translates to:
  /// **'Go to shop'**
  String get jellyShortGoShop;

  /// No description provided for @pvpRefillLimit.
  ///
  /// In en, this message translates to:
  /// **'You can refill with jelly up to {n} times a day'**
  String pvpRefillLimit(int n);

  /// No description provided for @pvpTicketRefillTitle.
  ///
  /// In en, this message translates to:
  /// **'Refill tickets'**
  String get pvpTicketRefillTitle;

  /// No description provided for @pvpTicketRefillBody.
  ///
  /// In en, this message translates to:
  /// **'Get {n} tickets with jelly. ({left} left today)'**
  String pvpTicketRefillBody(int n, int left);

  /// No description provided for @starterOfferTitle.
  ///
  /// In en, this message translates to:
  /// **'Starter package'**
  String get starterOfferTitle;

  /// No description provided for @starterOfferBody.
  ///
  /// In en, this message translates to:
  /// **'Jelly 300 · gold · materials · +1 incubator slot.\nOnly once per account — the best value in the shop!'**
  String get starterOfferBody;

  /// No description provided for @starterOfferGo.
  ///
  /// In en, this message translates to:
  /// **'See it'**
  String get starterOfferGo;

  /// No description provided for @mailGrantTitle.
  ///
  /// In en, this message translates to:
  /// **'[From the team] {name}'**
  String mailGrantTitle(String name);

  /// No description provided for @mailGrantBody.
  ///
  /// In en, this message translates to:
  /// **'A reward from the team. Tap Claim to receive it.'**
  String get mailGrantBody;

  /// No description provided for @mailReplyTitle.
  ///
  /// In en, this message translates to:
  /// **'[Reply from the team]'**
  String get mailReplyTitle;
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
