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
  String get mailTitle => 'メールボックス';

  @override
  String get mailEmpty => '新しいメールはありません';

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
