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
  /// **'💎{n} Heal now'**
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
  /// **'Peak rank: {name}'**
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
  /// **'Place 2+ bugs so a front slot generates the next (order matters)'**
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
  /// **'You\'re on a temporary device account, so deleting the app also loses the backup. Google sign-in is coming soon.'**
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

  /// No description provided for @settingsBuildLabel.
  ///
  /// In en, this message translates to:
  /// **'Build {label}'**
  String settingsBuildLabel(String label);

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
  String collectInstalledSnack(String field, String trap);

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
  /// **'Crit'**
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
  /// **'Ad ×2'**
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
  /// **'Ad reward ×2!'**
  String get giftDoubledSnack;

  /// No description provided for @giftAdMoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Watch an ad for one more?'**
  String get giftAdMoreTitle;

  /// No description provided for @giftAdMoreBody.
  ///
  /// In en, this message translates to:
  /// **'Watch an ad to get the same reward once more'**
  String get giftAdMoreBody;

  /// No description provided for @giftAdMoreYes.
  ///
  /// In en, this message translates to:
  /// **'Watch ad'**
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
  /// **'Watch ad'**
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
  String evolveNext(String next, String time);

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
  /// **'💎{n}'**
  String trainJelly(int n);

  /// No description provided for @trainJellySnack.
  ///
  /// In en, this message translates to:
  /// **'Instant train! Level +{lv}'**
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
  /// **'Now 💎{n}'**
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
  /// **'Expand 💎{n}'**
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
