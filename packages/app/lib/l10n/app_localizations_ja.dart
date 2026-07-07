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
}
