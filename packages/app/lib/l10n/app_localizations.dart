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
  /// **'Chat'**
  String get chatTitle;

  /// No description provided for @chatPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Chat (coming soon) — tap to open'**
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
