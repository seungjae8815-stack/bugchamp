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
