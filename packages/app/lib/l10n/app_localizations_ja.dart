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
  String get navBattle => '戦闘';

  @override
  String get battleTitle => '虫の決闘';

  @override
  String battleTrophies(int n) {
    return 'トロフィー $n';
  }

  @override
  String get battleMyTeam => 'マイチーム (3)';

  @override
  String get autoBattleRunning => '自動戦闘中';

  @override
  String get battleStart => '戦闘開始';

  @override
  String get battleNeedBugs => '決闘には成虫が必要です';

  @override
  String get battlePickTitle => '虫を選択（成虫）';

  @override
  String get battleEmptySlot => '空きスロット';

  @override
  String get battleWin => '勝利！';

  @override
  String get battleLose => '敗北…';

  @override
  String get battleDraw => '引き分け';

  @override
  String get battleReward => '報酬';

  @override
  String get battleVs => 'VS';

  @override
  String get battleRestrain => '相克！';

  @override
  String get battleFoe => '相手';

  @override
  String get battleLog => '戦闘ログ';

  @override
  String get battleAgain => 'もう一度挑戦';

  @override
  String get battleTeamEmpty => 'チームに虫を入れてください';

  @override
  String get battleSkip => 'スキップ';

  @override
  String battleHpPct(String v) {
    return '体力 $v%';
  }

  @override
  String get battleAuto => '自動戦闘';

  @override
  String get battleManual => '手動戦闘';

  @override
  String get battleManualDesc => '心理戦・毎手を自分で選択';

  @override
  String get battleYourMove => '手を選んでください';

  @override
  String get battleEnergy => '気力';

  @override
  String get battleClashWin => '機先を制した！';

  @override
  String get battleClashLose => '不意を突かれた';

  @override
  String get battleClashEven => '互角の探り合い';

  @override
  String get injuryTitle => '回復中';

  @override
  String get injuryDesc => '回復するまで決闘に編成できません';

  @override
  String injuryHealJelly(int n) {
    return 'ゼリー$nで即時回復';
  }

  @override
  String get notEnoughJelly => '昆虫ゼリーが足りません';

  @override
  String get scoutBoard => 'スカウトボード';

  @override
  String get scoutRefresh => '更新';

  @override
  String get scoutEasy => '弱い';

  @override
  String get scoutEven => '互角';

  @override
  String get scoutHard => '強い';

  @override
  String get leagueBronze => 'ブロンズ';

  @override
  String get leagueSilver => 'シルバー';

  @override
  String get leagueGold => 'ゴールド';

  @override
  String get leaguePlatinum => 'プラチナ';

  @override
  String get leagueDiamond => 'ダイヤ';

  @override
  String leagueToNext(int n, String name) {
    return '$nameまで $n🏆';
  }

  @override
  String get leagueMaxRank => '最高ランク';

  @override
  String get leagueClaimReward => '昇格報酬を受け取る';

  @override
  String get leaguePromoTitle => '昇格報酬';

  @override
  String get seasonEndTitle => 'シーズン終了！';

  @override
  String seasonPeak(String name) {
    return '終了時の等級: $name';
  }

  @override
  String seasonTrophyReset(int from, int to) {
    return 'トロフィー $from → $to';
  }

  @override
  String seasonEndsIn(String time) {
    return 'シーズン残り $time';
  }

  @override
  String get synergyLabel => '相生';

  @override
  String get synergyHint => '虫を2匹以上配置・前の虫が後ろの虫を強めるとチームが強くなります（順番が大事）';

  @override
  String get teamReorderHint => 'ドラッグで並び替え';

  @override
  String get leagueSeasonTitle => 'リーグ・シーズン';

  @override
  String get modeManual => '手動';

  @override
  String get modeAuto => '自動';

  @override
  String get opponentWild => '野生';

  @override
  String get opponentPick => '相手を選ぶ';

  @override
  String get accountTitle => 'アカウント';

  @override
  String get accountAnonymous => '現在は端末の仮アカウントです';

  @override
  String accountSignedIn(String email) {
    return '$email でログイン中';
  }

  @override
  String get accountSignIn => 'Googleでログイン';

  @override
  String get accountDelete => 'アカウント削除';

  @override
  String get accountDeleteTitle => '本当にアカウントを削除しますか？';

  @override
  String accountDeleteBody(String word) {
    return '虫・通貨・トロフィー・交配の記録がすべて消え、元に戻せません。\n\n確認のため、下に «$word» と入力してください。';
  }

  @override
  String get accountDeleteWord => '削除';

  @override
  String get accountDeleteConfirm => '完全に削除';

  @override
  String get accountDeleteDone => 'アカウントとデータを削除しました';

  @override
  String get accountDeleteFailed => '削除できませんでした。しばらくしてからもう一度お試しください';

  @override
  String get accountDeleteOffline => 'オンライン接続がないため削除できません';

  @override
  String get accountDeleteWarnPurchase => '購入した商品は返金されず、復元もできなくなります。';

  @override
  String get accountSignOut => 'ログアウト';

  @override
  String get accountSignedOut => 'ログアウトしました';

  @override
  String get accountSignInFailed => 'ログインできませんでした';

  @override
  String get accountWhy => 'ログインすると、スマホを変えても進行状況を引き継げます。';

  @override
  String get accountUnavailable => 'このビルドではログインを利用できません';

  @override
  String get accountAnonRisk => 'ログインしないと、機種変更やアプリ削除のときに進行状況を復元できません。';

  @override
  String get loginNudge => 'ゲストアカウント · タップしてログインしデータを守る';

  @override
  String get accountSyncTitle => 'どちらの進行状況を使いますか？';

  @override
  String get accountSyncBody => 'このアカウントには保存された進行状況があります。どちらを使うか選んでください。';

  @override
  String get accountKeepDevice => 'この端末のデータ';

  @override
  String get accountUseCloud => '保存データを読み込む';

  @override
  String get cloudTitle => 'クラウドバックアップ';

  @override
  String get cloudBackup => 'バックアップ';

  @override
  String get cloudRestore => '復元';

  @override
  String get cloudBackupDone => 'クラウドにバックアップしました';

  @override
  String get cloudRestoreDone => 'バックアップから復元しました';

  @override
  String get cloudRestoreConfirm => '現在の進行状況をバックアップの内容で上書きします。元に戻せません。';

  @override
  String get cloudFailed => '失敗しました。しばらくしてからもう一度お試しください';

  @override
  String get cloudNoBackup => 'まだバックアップがありません';

  @override
  String cloudLastBackup(String when) {
    return '最終バックアップ: $when';
  }

  @override
  String get cloudUnavailable => 'オンライン接続がないためバックアップを利用できません';

  @override
  String get cloudAnonWarning =>
      '現在は端末の仮アカウントのため、アプリを削除するとバックアップも失われます。ログインすると他の端末でも続けられます。';

  @override
  String get tabCraft => 'クラフト';

  @override
  String get tabStore => 'ショップ';

  @override
  String get adNotReady => '現在、広告の準備ができていません。しばらくしてからもう一度お試しください';

  @override
  String get adDismissed => '報酬を受け取るには広告を最後まで見てください';

  @override
  String get adFailed => '広告を読み込めませんでした';

  @override
  String get adLoading => '広告を読み込み中…';

  @override
  String get storeOwned => '所持中';

  @override
  String get storeRestore => '購入を復元';

  @override
  String get storeRestoreDone => '購入履歴を復元しました';

  @override
  String storeBought(String name) {
    return '$name を購入しました！';
  }

  @override
  String get storeFailed => '購入できませんでした';

  @override
  String get storeCanceled => '購入をキャンセルしました';

  @override
  String get storePending => '決済を確認中です。完了すると自動で付与されます';

  @override
  String get storeUnavailable => 'この端末では課金を利用できません';

  @override
  String get storeNotRegistered => 'まだ販売準備中の商品です';

  @override
  String get storeDevMode => '開発モード — 実際の決済ではなく、すぐに付与されます';

  @override
  String storePassLeft(int days) {
    return '残り $days 日';
  }

  @override
  String get biomeForest => '森';

  @override
  String get biomeVolcano => '溶岩洞';

  @override
  String get biomeBadlands => '荒野';

  @override
  String get biomeCity => '廃墟都市';

  @override
  String get biomeDeep => '深海';

  @override
  String locationAffinity(String element) {
    return '$element の虫を強化';
  }

  @override
  String get breedingTitle => '交配';

  @override
  String breedingSlotsLabel(int used, int cap) {
    return '$used/$cap';
  }

  @override
  String get breedingNew => '新しい交配';

  @override
  String get breedingPickMother => '母虫を選ぶ（♀ 成虫）';

  @override
  String get breedingPickFather => '父虫を選ぶ（♂・同じ種類）';

  @override
  String get breedingNoFemales => '交配できる母虫（♀ 成虫）がいません';

  @override
  String get breedingNoMate => '同じ種類の父虫（♂ 成虫）がいません';

  @override
  String get breedingInProgress => '産卵中';

  @override
  String breedCooldownLeft(Object time) {
    return '$time後に可能';
  }

  @override
  String get breedingGotEgg => '卵が生まれました！孵化器に入れて育てましょう';

  @override
  String get leaderboardLocalNote => 'ローカルランキング・オンライン連携準備中';

  @override
  String get leaderboardOnlineNote => 'オンラインランキング・リアルタイム反映';

  @override
  String get backendOnline => 'オンライン';

  @override
  String get backendLocal => 'ローカル';

  @override
  String get backendServer => 'サーバー接続';

  @override
  String settingsBuildLabel(String label) {
    return 'ビルド $label';
  }

  @override
  String get rankKindTrophies => 'トロフィー';

  @override
  String get rankKindLevel => 'レベル';

  @override
  String get rankKindStage => '進行度';

  @override
  String leaderboardMyRank(int n) {
    return '自分の順位 #$n';
  }

  @override
  String get stanceAttack => '攻撃';

  @override
  String get stanceDefend => '防御';

  @override
  String get stanceHeal => '回復';

  @override
  String get elementFire => '火';

  @override
  String get elementWater => '水';

  @override
  String get elementWood => '木';

  @override
  String get elementMetal => '金';

  @override
  String get elementEarth => '土';

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
  String get offlineTitle => 'おかえりなさい！';

  @override
  String offlineElapsed(String time) {
    return '$time の間に貯まった放置報酬です';
  }

  @override
  String get offlineGoldLabel => 'ゴールド';

  @override
  String get offlineXpLabel => '経験値';

  @override
  String durationHm(int h, int m) {
    return '$h時間 $m分';
  }

  @override
  String durationM(int m) {
    return '$m分';
  }

  @override
  String durationS(int s) {
    return '$s秒';
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
  String get curGold => 'ゴールド';

  @override
  String get rewardGained => '獲得報酬';

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
  String collectInstalledSnack(String trap, String field) {
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
  String storageCapacityCount(int used, int cap) {
    return '$used/$cap';
  }

  @override
  String storageCapacityLabel(int used, int cap) {
    return '採集箱 $used / $cap枠';
  }

  @override
  String get storageFullBanner => '採集ボックスが満杯です\n虫が入りません';

  @override
  String get storageFullSnack => '採集箱がいっぱいです。分解するか拡張してください。';

  @override
  String storageExpand(int n, int jelly) {
    return '+$n枠・ゼリー$jelly';
  }

  @override
  String get dexTitle => '昆虫図鑑';

  @override
  String get dexDiscovered => '発見';

  @override
  String get dexConquered => '制覇';

  @override
  String get dexVariant => '色違い';

  @override
  String get dexConqueredYes => '完了';

  @override
  String get dexConqueredNo => 'まだ';

  @override
  String get dexMaxSize => '最大サイズ';

  @override
  String get dexMaxPotential => '最高ポテンシャル';

  @override
  String get dexNotFound => 'まだ出会っていない虫です。採集で探してみましょう！';

  @override
  String dexClaim(Object n) {
    return '図鑑報酬 $n件を受け取る';
  }

  @override
  String dexClaimedSnack(Object gold, Object jelly) {
    return '図鑑報酬獲得！ゴールド$gold・ゼリー$jelly';
  }

  @override
  String dexBonusSummary(String atk, String hp, String gold) {
    return '図鑑ボーナス — 攻撃 +$atk% · 体力 +$hp% · ゴールド +$gold%';
  }

  @override
  String get speciesPassiveTitle => '種族固有能力';

  @override
  String get speciesPassiveHint => 'この虫をペットとして装備すると付きます。同じ種を複数装備すると重なります。';

  @override
  String get storageFilterLabel => '受け取る等級';

  @override
  String get storageFilterAll => 'すべて';

  @override
  String storageFilterSnack(Object grade) {
    return '$grade 未満は自動で逃がして素材に変えます';
  }

  @override
  String get autoSynthTitle => '自動合成';

  @override
  String autoSynthHint(Object n) {
    return '同じ種が $n 匹たまると自動で合成してポテンシャルを上げます。装備中・孵化中の虫は使いません。';
  }

  @override
  String get autoSynthNone => '合成できる虫がありません';

  @override
  String autoSynthPreview(Object count, Object used) {
    return '$count体が合成されます（$used匹使用）';
  }

  @override
  String autoSynthDone(Object count, Object used) {
    return '$count 回合成しました（$used 匹使用）';
  }

  @override
  String get autoSynthRun => '自動合成';

  @override
  String get eventIntroTitle => '王虫選抜大会とは？';

  @override
  String get eventIntroStart => 'はじめる';

  @override
  String get eventHelp => '大会の説明を見る';

  @override
  String eventCardTitle(Object n) {
    return '$nウェーブ突破！1つ選んでください';
  }

  @override
  String get eventCardHint => '選んだ強化はこの挑戦が終わるまで残ります';

  @override
  String get cardHeal_s => '応急処置';

  @override
  String get cardHeal_sDesc => '体力を30%回復します';

  @override
  String get cardHeal_l => '完全回復';

  @override
  String get cardHeal_lDesc => '体力を70%回復します';

  @override
  String get cardAtk_s => '鋭い顎';

  @override
  String get cardAtk_sDesc => '攻撃力 +12%';

  @override
  String get cardAtk_l => '猛攻';

  @override
  String get cardAtk_lDesc => '攻撃力 +28%';

  @override
  String get cardDef_s => '硬い外皮';

  @override
  String get cardDef_sDesc => '防御力 +18%';

  @override
  String get cardHp_s => '強靭な体格';

  @override
  String get cardHp_sDesc => '最大体力 +15%';

  @override
  String get cardRevive => '命の露';

  @override
  String get cardReviveDesc => '倒れた虫1匹を半分の体力で復活させます';

  @override
  String get cardSkip => '迂回路';

  @override
  String get cardSkipDesc => '次のウェーブを戦わずに通過します';

  @override
  String eventFlyerPeriod(String start, String end) {
    return '$start ~ $end';
  }

  @override
  String get eventPeriodLabel => '大会期間';

  @override
  String get eventFlyerHeadline => '最も遠くまで進む虫使いを探しています';

  @override
  String get eventFlyerPrize => '1位には本物の昆虫をお届けします';

  @override
  String get eventFlyerPrizeNote => '韓国国内配送・販売店から直接発送';

  @override
  String get eventFlyerHow => '参加方法';

  @override
  String get eventFlyerHow1 => '成虫3匹を選んで出場';

  @override
  String get eventFlyerHow2 => 'ウェーブ突破ごとに強化カードを1枚選択';

  @override
  String get eventFlyerHow3 => 'より遠くまで進んだ人が上位';

  @override
  String get eventFlyerRules => '必ずご確認ください';

  @override
  String get eventFlyerRule1 =>
      'この大会は**ステータスが平準化**されます — 種・五行・気質のみ反映され、修練・強化・サイズは適用されません';

  @override
  String get eventFlyerRule2 => '敵の五行はウェーブごとに変わります — 一属性だけでは詰まります';

  @override
  String get eventFlyerRule3 => '出場した虫は1日休みます — 良い虫を多く揃えると有利です';

  @override
  String get eventFlyerRule4 => '参加券は毎朝補充され、無料チャージで1日2枚まで追加できます';

  @override
  String get eventFlyerLogin => '順位に載るにはログインが必要です（ゲストは参加のみ可能）';

  @override
  String get eventTitle => '王虫選抜大会';

  @override
  String eventBanner(Object n) {
    return '王虫選抜大会 開催中・参加券$n枚';
  }

  @override
  String get eventClosed => '現在開催中の大会はありません';

  @override
  String get eventNeedServer => '大会にはオンライン接続が必要です';

  @override
  String eventTickets(int n, int max) {
    return '参加券 $n/$max';
  }

  @override
  String get eventBestRecord => '自己ベスト';

  @override
  String get eventNoRecord => 'まだ挑戦していません';

  @override
  String eventWaveRecord(Object n) {
    return '$nウェーブ';
  }

  @override
  String eventScore(Object n) {
    return '$n点';
  }

  @override
  String eventMyRank(Object n) {
    return '自分の順位 #$n';
  }

  @override
  String get eventPickTeam => '出場する虫を3匹選んでください';

  @override
  String get eventPickOrder => '左から順に出ます・前の虫が後ろの虫を強めるとさらに強くなります';

  @override
  String get eventNormalizeTitle => 'この大会はステータスが平準化されます';

  @override
  String get eventNormalizeBody =>
      '種・五行・気質・得意技だけが反映されます。修練・突破・部位強化・ポテンシャル・サイズは適用されません — 同じ条件で編成の巧さを競う大会です。';

  @override
  String eventFatigueLeft(Object time) {
    return '$time後に出場可能';
  }

  @override
  String eventRestHours(Object h) {
    return '⏳$h時間';
  }

  @override
  String eventRestMinutes(Object m) {
    return '⏳$m分';
  }

  @override
  String get eventChallenge => '挑戦（参加券1枚）';

  @override
  String get eventNoTicket => '参加券がありません';

  @override
  String get eventAdTicket => '無料参加券を受け取る';

  @override
  String get eventAdLimit => '本日の無料報酬は受け取り済みです';

  @override
  String get eventTicketFull => '参加券が満杯です';

  @override
  String eventResultTitle(Object n) {
    return '$nウェーブ到達！';
  }

  @override
  String get eventNewBest => '自己ベスト更新！';

  @override
  String eventKeptBest(Object n) {
    return '自己ベストは$nウェーブです';
  }

  @override
  String eventWaveCleared(Object n) {
    return '$nウェーブ突破！';
  }

  @override
  String get eventFastForward => '早送り';

  @override
  String get eventNextWave => '次の敵の属性';

  @override
  String get eventLead => '先鋒';

  @override
  String get eventSetLead => '先鋒に';

  @override
  String get eventLeadHint => '虫をタップして次の先鋒を決めます';

  @override
  String get eventRanking => '順位';

  @override
  String get eventRankEmpty => 'まだ順位がありません';

  @override
  String get eventAnonWarn => 'ゲストアカウントは順位に載りません。ログインすると参加できます。';

  @override
  String get eventKoreaOnly => '実物賞品は韓国国内のみ配送されます。順位とゲーム内報酬は誰でも参加できます。';

  @override
  String get eventRules => '大会ルール';

  @override
  String get storageFilterButton => 'フィルター';

  @override
  String get storageFilterTitle => '受け取る等級を選ぶ';

  @override
  String get autoReleaseTitle => '自動分解';

  @override
  String get autoReleaseHint =>
      '条件に合う虫をまとめて分解し、素材に変えます。装着中・孵化中・育てた虫（修練・突破・強化）は対象外です。';

  @override
  String get autoReleaseNone => '条件に合う虫がいません';

  @override
  String autoReleaseDone(Object count, Object mats) {
    return '$count匹を分解して素材$mats個を獲得しました';
  }

  @override
  String autoReleasePreview(Object count, Object mats) {
    return '$count匹を分解して素材$mats個を獲得します';
  }

  @override
  String get autoReleaseRun => '分解する';

  @override
  String get autoFilterGrades => '対象の等級';

  @override
  String autoFilterPotential(Object n) {
    return 'ポテンシャル$n★以下のみ';
  }

  @override
  String get autoFilterEmpty => '等級を1つ以上選んでください';

  @override
  String get autoPreviewTitle => '今回いなくなる虫';

  @override
  String autoPreviewMore(Object n) {
    return 'ほか$n匹';
  }

  @override
  String autoPreviewLine(String name, int count) {
    return '$name $count匹';
  }

  @override
  String get storageExpandMaxed => '拡張上限';

  @override
  String get storageExpandedSnack => '採集箱が広がりました！';

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
  String get traitFierce => '猛烈';

  @override
  String get traitSturdy => '強靭';

  @override
  String get traitVital => '強健';

  @override
  String get traitNoble => '高貴';

  @override
  String get traitTitle => '血統特性';

  @override
  String get traitHint => '交配で生まれた虫だけが持てます。両親が同じ特性なら必ず受け継ぎます。';

  @override
  String get breedInheritTitle => '受け継ぐもの';

  @override
  String get breedInheritHint => '両親の五行・気質・血統特性を受け継ぎます。同じ値の親同士を組ませると確実になります。';

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
  String get chatTitle => '全体チャット';

  @override
  String get chatPlaceholder => '全体チャット — タップで開く';

  @override
  String get characterTitle => 'マイキャラクター';

  @override
  String get statCombatPower => '戦闘力';

  @override
  String get statCrit => '会心';

  @override
  String get statMaxHp => '最大体力';

  @override
  String get statDefense => '防御';

  @override
  String get rankingTitle => 'ランキング';

  @override
  String get roadmapTitle => 'ロードマップ';

  @override
  String roadmapStageRange(int start, int end) {
    return 'STAGE $start–$end';
  }

  @override
  String roadmapProgress(int cur, int total) {
    return '$cur / $total';
  }

  @override
  String get roadmapCleared => 'クリア';

  @override
  String get roadmapCurrent => '進行中';

  @override
  String get roadmapLocked => 'ロック中';

  @override
  String get roadmapFinalBoss => '最終ボス';

  @override
  String get roadmapEnter => '続きから';

  @override
  String get roadmapReplay => '再挑戦';

  @override
  String get chapterClearTitle => 'チャプタークリア！🎉';

  @override
  String chapterClearMsg(String difficulty, String boss) {
    return '$difficulty 制覇！最終ボス $boss を撃破！';
  }

  @override
  String get chapterClearReward => 'クリア報酬';

  @override
  String get mailTitle => 'メールボックス';

  @override
  String get mailEmpty => '新しいメールはありません';

  @override
  String get mailDailyTitle => 'デイリー報酬（1日2回）';

  @override
  String get dailyLunch => 'ランチ報酬';

  @override
  String get dailyDinner => 'ディナー報酬';

  @override
  String get dailyClaim => '受け取る';

  @override
  String get dailyClaimedToday => '本日受取済み';

  @override
  String dailyLockedUntil(int hour) {
    return '$hour時から';
  }

  @override
  String get dailyRewardSnack => 'デイリー報酬を受け取りました！';

  @override
  String get giftSectionTitle => 'サプライズギフト（3時間以内に受取）';

  @override
  String get giftClaim => '受け取る';

  @override
  String get giftClaimAd => '2倍受け取る';

  @override
  String giftExpiresIn(String time) {
    return '$time 後に期限切れ';
  }

  @override
  String get giftClaimedSnack => 'ギフトを受け取りました！';

  @override
  String get giftDoubledSnack => '報酬2倍獲得！';

  @override
  String get giftAdMoreTitle => '本日の無料2倍！';

  @override
  String get giftAdMoreBody => '同じ報酬をもう一度受け取れます。';

  @override
  String get giftAdMoreYes => 'もう一度受け取る';

  @override
  String get giftAdMoreLater => 'いいえ、結構です';

  @override
  String get notifLunchTitle => 'ランチ報酬が届きました 🍱';

  @override
  String get notifDinnerTitle => 'ディナー報酬が届きました 🌙';

  @override
  String get notifRewardBody => '今すぐログインして受け取りましょう！';

  @override
  String get notifOfflineTitle => '放置報酬がいっぱいです 🐛';

  @override
  String get notifOfflineBody => '8時間分が貯まりました。ログインして受け取りましょう！';

  @override
  String get giftNone => 'まだ届いたギフトはありません。プレイしていると届きます！';

  @override
  String get settingsTitle => '設定';

  @override
  String get settingsSound => 'サウンド';

  @override
  String get settingsBgm => 'BGM';

  @override
  String get settingsSfx => '効果音';

  @override
  String get settingsNickname => 'ニックネーム';

  @override
  String get settingsNicknameHint => '名前を入力してください';

  @override
  String get actionSave => '保存';

  @override
  String get actionCancel => 'キャンセル';

  @override
  String get actionNext => '次へ';

  @override
  String get actionClose => '閉じる';

  @override
  String get exitTitle => 'ゲーム終了';

  @override
  String get exitConfirm => 'ゲームを終了しますか？';

  @override
  String get exitAction => '終了';

  @override
  String get settingsReset => 'ゲームデータ初期化';

  @override
  String get settingsResetConfirm =>
      'すべての進行状況（虫・通貨・強化・ステージ）が削除されます。本当に初期化しますか？';

  @override
  String get settingsResetDone => '初期化しました';

  @override
  String get questHunt => 'モンスター狩り';

  @override
  String get buffTitle => 'バフ';

  @override
  String get buffSheetTitle => 'バフを発動';

  @override
  String get buffWatchAd => '無料で発動';

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
  String get equipTitle => '装備中のペット';

  @override
  String get equipEmpty => '空きスロット';

  @override
  String get equipAction => '装備';

  @override
  String get unequipAction => '解除';

  @override
  String get equipFull => '装備スロットがいっぱいです';

  @override
  String get equippedBadge => '装備中';

  @override
  String petBonus(String atk, String hp) {
    return 'ペットボーナス・攻撃 +$atk% ・体力 +$hp%';
  }

  @override
  String get stageEgg => '卵';

  @override
  String get stageLarva => '幼虫';

  @override
  String get stagePupa => 'さなぎ';

  @override
  String get stageAdult => '成虫';

  @override
  String get evolveTitle => '進化';

  @override
  String evolveNext(String time, String next) {
    return '$nextまで $time';
  }

  @override
  String get evolveReady => '進化準備完了';

  @override
  String get evolveMaxed => '最終進化（成虫）';

  @override
  String get accelerateAction => '促進';

  @override
  String get synthTitle => '合成（★強化）';

  @override
  String get synthDo => '合成';

  @override
  String synthDesc(int have, int need) {
    return '同じ種 $have/$need匹・ポテンシャル +1';
  }

  @override
  String get synthMaxed => '最大ポテンシャル';

  @override
  String get synthSnack => '合成完了！ポテンシャル +1';

  @override
  String get petEffectTitle => '装備効果';

  @override
  String petAtkBonus(String v) {
    return 'ペット攻撃力 +$v%';
  }

  @override
  String petHpBonus(String v) {
    return 'ペット体力 +$v%';
  }

  @override
  String get trainTitle => '修練';

  @override
  String get trainLevel => '修練レベル';

  @override
  String get trainAction => '修練';

  @override
  String get trainMaxed => '最大レベル';

  @override
  String get trainSnack => '修練完了！レベル +1';

  @override
  String trainJelly(int n) {
    return 'ゼリー$n';
  }

  @override
  String trainJellySnack(int lv) {
    return '即時修練！レベル+$lv';
  }

  @override
  String get breakthroughTitle => '突破';

  @override
  String breakthroughTier(int n) {
    return 'ティア $n';
  }

  @override
  String get breakthroughReady => '突破可能・レベル上限 ↑';

  @override
  String breakthroughProgress(String time) {
    return '突破中・$time';
  }

  @override
  String get breakthroughDone => '突破完了！受け取りましょう';

  @override
  String get breakthroughMaxed => '最高ティア達成';

  @override
  String get breakthroughDo => '突破';

  @override
  String get breakthroughCollect => '受け取る';

  @override
  String breakthroughInstant(int n) {
    return '即完了・ゼリー$n';
  }

  @override
  String get breakthroughStartedSnack => '突破を開始しました！';

  @override
  String get breakthroughDoneSnack => '突破完了！レベル上限が上がりました';

  @override
  String get incubatorTitle => '孵化器';

  @override
  String incubatorSlots(int cur, int max) {
    return 'スロット $cur/$max';
  }

  @override
  String get incubatorPlace => '入れる';

  @override
  String incubatorHatching(String time) {
    return '孵化中・$time';
  }

  @override
  String get incubatorReady => '孵化完了！';

  @override
  String get incubatorCollect => '受け取る';

  @override
  String get incubatorFull => '孵化器がいっぱい';

  @override
  String incubatorExpand(int n) {
    return 'スロット拡張・ゼリー$n';
  }

  @override
  String get incubatorPlacedSnack => '孵化を開始しました！';

  @override
  String get incubatorCollectedSnack => '幼虫に孵化しました！';

  @override
  String get incubatorExpandedSnack => '孵化器のスロットが増えました！';

  @override
  String get incubatorEmptySlot => '空きスロット';

  @override
  String incubatorWaitingEggs(int n) {
    return '待機中の卵 $n';
  }

  @override
  String get incubatorNoEggs => '孵化する卵がありません';

  @override
  String get incubatorHint => '空のカプセルをタップして卵を入れ、完了したらタップして受け取りましょう';

  @override
  String incubatorCollectAll(int n) {
    return 'すべて受け取る ($n)';
  }

  @override
  String incubatorCollectAllDone(int n) {
    return '$n匹を受け取りました';
  }

  @override
  String get incubatorPick => '孵化する卵を選択';

  @override
  String get disassembleTitle => '分解';

  @override
  String disassembleDesc(int n) {
    return 'ゼリー $n個に還元';
  }

  @override
  String get disassembleAction => '分解';

  @override
  String get disassembleSnack => '分解完了';

  @override
  String get bugDescTitle => '説明';

  @override
  String get onlyAdultTrain => '成虫のみ修練できます';

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
  String get missionComplete => '完了！タップして受け取る';

  @override
  String get missionClaimedSnack => 'ミッション報酬を獲得！';

  @override
  String get upAttackDesc => '一撃で与えるダメージ量が増えます。';

  @override
  String get upAttackSpeedDesc => '秒間の攻撃回数が増え、狩りが速くなります。';

  @override
  String get upCritDesc => 'クリティカルの発生確率が上がります。';

  @override
  String get upCritDamageDesc => 'クリティカル時の追加ダメージ倍率が大きくなります。';

  @override
  String get upBossDamageDesc => 'ボスに与えるダメージがさらに増えます。';

  @override
  String get upMaxHpDesc => '最大体力が増え、より長く持ちこたえます。';

  @override
  String get upDefenseDesc => '敵から受けるダメージが減ります。';

  @override
  String get upRegenDesc => '秒間の体力回復量が増えます。';

  @override
  String get upRewardDesc => 'モンスター撃破時に得られるゴールドが増えます。';

  @override
  String get upXpDesc => 'モンスター撃破時に得られる経験値が増えます。';

  @override
  String get upBugFindDesc => '虫（個体）を発見する確率が上がります。';

  @override
  String get upMaterialFindDesc => '強化素材の獲得量が増えます。';

  @override
  String get upMoveSpeedDesc => '次の狩場への移動速度が速くなります。';

  @override
  String get upBoostDesc => '画面をタップしたときに発動するブースト効果が強くなります。';

  @override
  String get upBugBuffDesc => '所持している虫の数に応じた報酬ボーナスが大きくなります。';

  @override
  String get tagCommonMaterial => '一般素材';

  @override
  String get tagPremium => 'プレミアム通貨';

  @override
  String get materialChitinDesc =>
      '虫の硬い外骨格の欠片。上級ステータス強化の追加コストと部位強化（角・大あご）に使われます。';

  @override
  String get materialMineralDesc =>
      '地中から採掘した硬い鉱物。上級ステータス強化の追加コストと部位強化（表皮）に使われます。';

  @override
  String get materialSapDesc => '固まって結晶になった樹液。上級ステータス強化の追加コストと部位強化（羽）に使われます。';

  @override
  String get materialJellyDesc =>
      '特別なプレミアム通貨。ショップのクラフト（オールインワンポーション）と特別商品に使われます。';

  @override
  String get materialFossil => '化石のかけら';

  @override
  String get materialFossilDesc => '昆虫が固まって残ったかけら。工房で一振りにつき一つ使う。';

  @override
  String get saveBrokenTitle => 'セーブを開けませんでした';

  @override
  String get saveBrokenUpdate => 'このアカウントのセーブがアプリより新しいです。\n最新版に更新すると続きから遊べます。';

  @override
  String get saveBrokenCorrupt =>
      'セーブを読み込めませんでした。\n元のデータは端末に安全に保管され、上書きしていません。';

  @override
  String get saveBrokenKeep => '進行を守るためにゲームを停止しました。このまま続けるとセーブが消える可能性があります。';

  @override
  String get saveBrokenSupport => 'お問い合わせ';

  @override
  String get eventRewardTitle => '大会の結果が出ました';

  @override
  String eventRewardRank(String round, int rank) {
    return '$round 回 $rank位';
  }

  @override
  String get eventRewardNone => '今回は入賞できませんでした。参加報酬をお受け取りください！';

  @override
  String get eventRewardPhysical =>
      '実物賞品の対象です！下の申込フォームをご記入ください。実物の配送は韓国国内の住所のみで、海外の方はゲーム内報酬のみとなります。';

  @override
  String get eventRewardApply => '賞品を申し込む';

  @override
  String get eventRewardClaim => '受け取る';

  @override
  String badgeChampion(int round) {
    return '$round回 チャンピオン';
  }

  @override
  String badgeFinalist(int round) {
    return '$round回 入賞';
  }

  @override
  String get nicknameBadChars => '文字と数字のみ使えます（絵文字・単独の記号は不可）';

  @override
  String get eventRewardsTitle => '順位報酬';

  @override
  String get eventRankOne => '1位';

  @override
  String eventRankRange(int a, int b) {
    return '$a~$b位';
  }

  @override
  String get eventRewardRealBug => '本物の昆虫（韓国国内配送）';

  @override
  String eventRewardJelly(int n) {
    return 'ゼリー $n';
  }

  @override
  String get eventRewardParticipationRow => '参加（1回以上）';

  @override
  String buffCooldownAsk(String t, int n) {
    return '次の無料起動まで $t。\nゼリー $n個で今すぐ起動しますか？';
  }

  @override
  String buffBtnFreeLeft(String t) {
    return '無料まで $t';
  }

  @override
  String buffBtnJelly(int n) {
    return '$n個で起動';
  }

  @override
  String get settingsLanguage => '言語';

  @override
  String get languageSystem => '端末の設定';

  @override
  String eventRewardTitleAward(String name) {
    return '称号「$name」';
  }

  @override
  String get stanceCycle => '攻 › 回 › 防 › 攻';

  @override
  String tierClearTitle(String name) {
    return '$name難易度をすべてクリア！';
  }

  @override
  String tierNextTitle(String name) {
    return '$name難易度に進みます';
  }

  @override
  String get tierNextBody =>
      'ステージと能力強化が最初に戻ります。\n昆虫・装備・図鑑・資材はそのまま残ります。\nモンスターがさらに強力になります。';

  @override
  String get tierNextGo => '進む';

  @override
  String get tierStayHere => 'もう少し残る';

  @override
  String get tierAllClear => 'すべての難易度を制覇しました！最高の昆虫学者です。';

  @override
  String get tierEasy => 'やさしい';

  @override
  String get tierNormal => 'ふつう';

  @override
  String get tierHard => 'むずかしい';

  @override
  String get tierExtreme => '極限';

  @override
  String get netLostTitle => '接続が切れました';

  @override
  String get netLostBody => 'インターネット接続を確認してください。\n接続中のみ進行が保存されます。';

  @override
  String get netRetry => '再試行';

  @override
  String get netToTitle => 'タイトルへ';

  @override
  String get netStillDown => 'まだ接続できていません';

  @override
  String get materialsHint => '素材 — ステータス・部位強化とクラフトに使用（タップで詳細）';

  @override
  String get chatHint => 'メッセージを入力してください';

  @override
  String get chatSend => '送信';

  @override
  String get chatEmpty => 'まだ会話がありません。まず挨拶してみましょう！';

  @override
  String get chatUnavailable => '現在チャットを利用できません';

  @override
  String get chatSendFailed => 'メッセージを送信できませんでした';

  @override
  String chatTooLong(int max) {
    return 'メッセージが長すぎます（$max文字まで）';
  }

  @override
  String get chatBlockedWord => '使用できない表現が含まれています';

  @override
  String get chatTooFast => 'もう少しゆっくり送ってください';

  @override
  String get chatReport => '通報';

  @override
  String get chatBlock => 'ブロック';

  @override
  String get chatUnblock => 'ブロック解除';

  @override
  String get chatDelete => '削除';

  @override
  String get chatDeleted => 'メッセージを削除しました';

  @override
  String get chatDeleteTitle => 'このメッセージを削除しますか？';

  @override
  String get chatDeleteBody => '自分のこのメッセージを全員から削除します。元に戻せません。';

  @override
  String get chatReported => '通報しました。確認のうえ対応します';

  @override
  String chatBlockedUser(String name) {
    return '$name さんをブロックしました';
  }

  @override
  String chatUnblockedUser(String name) {
    return '$name さんのブロックを解除しました';
  }

  @override
  String get chatBlockedMessage => 'ブロックしたユーザーのメッセージです';

  @override
  String get chatReportTitle => 'このメッセージを通報しますか？';

  @override
  String get chatReportBody =>
      '暴言・広告・詐欺などの不適切な内容を通報できます。繰り返し通報されたユーザーは利用が制限されます。';

  @override
  String chatBlockTitle(String name) {
    return '$name さんをブロックしますか？';
  }

  @override
  String get chatBlockBody => 'このユーザーのメッセージが表示されなくなります。設定からいつでも解除できます。';

  @override
  String get chatRules => 'お互いを尊重した会話をお願いします。暴言・広告・個人情報の共有は制限されます。';

  @override
  String get nicknameBlockedWord => 'ニックネームに使用できない表現が含まれています';

  @override
  String get nicknameTaken => 'そのニックネームは既に使われています';

  @override
  String get rankPopupTitle => 'マイランキング';

  @override
  String get rankSuffix => '位';

  @override
  String get rankFirstCheck => '初めてのランキング確認です！';

  @override
  String get rankUnchanged => '前回と同じ順位です';

  @override
  String rankChangedFromTo(int from, int to) {
    return '$from位 → $to位';
  }

  @override
  String rankTopStreak(int days) {
    return '1位を$days日連続キープ 👑';
  }

  @override
  String get nicknameRequiredTitle => 'ニックネームを決めてください';

  @override
  String get nicknameRequiredBody => '他の採集者に表示される名前です。最初の一度だけ設定します。';

  @override
  String get nicknameChangeTitle => 'ニックネーム変更';

  @override
  String get nicknameChangeBody => 'ニックネームの変更には昆虫ゼリーが必要です。変更しますか？';

  @override
  String get nicknameChangeConfirm => '変更';

  @override
  String get nicknameFallback => 'プレイヤー';

  @override
  String get battleServerFailed => '戦闘結果を確認できませんでした。接続を確認してください';

  @override
  String get updateRequiredTitle => 'アップデートが必要です';

  @override
  String get updateRequiredBody => '快適にプレイするため、最新バージョンに更新してください。';

  @override
  String get updateAvailableTitle => '新しいバージョンがあります';

  @override
  String get updateAvailableBody => '改善されたバージョンが準備できました。今すぐ更新しますか？';

  @override
  String get updateNow => 'アップデート';

  @override
  String get updateLater => 'あとで';

  @override
  String get maintenanceTitle => 'メンテナンス中';

  @override
  String get maintenanceBody => 'ただいまサーバーメンテナンス中です。しばらくしてからもう一度お試しください。';

  @override
  String get connectionRequiredTitle => 'インターネット接続が必要です';

  @override
  String get connectionRequiredBody =>
      'プレイするにはインターネット接続が必要です。接続を確認してもう一度お試しください。';

  @override
  String get retryButton => '再試行';

  @override
  String get accountSignInApple => 'Appleでサインイン';

  @override
  String get termsOfUse => '利用規約';

  @override
  String get privacyPolicy => 'プライバシーポリシー';

  @override
  String get titleStartGuest => 'ゲストで始める';

  @override
  String get titleOr => 'または';

  @override
  String get titleLoading => '読み込み中…';

  @override
  String get guestNudgeTitle => 'ログインしてから始めますか？';

  @override
  String get guestNudgeBody =>
      'ログインしないと、機種変更やアプリ削除のときに進行状況と順位を戻せません。集めた虫と順位を守るためにログインしてください。';

  @override
  String get guestNudgeSignIn => 'ログインする';

  @override
  String get guestNudgeContinue => 'ゲストで続ける';

  @override
  String get guestWarnTitle => 'ゲストでプレイ中です';

  @override
  String get guestWarnBody =>
      '現在は端末の仮アカウントです。アプリを削除したり機種を変更すると、集めた虫と順位が消えます。ログインしておくと安全に引き継げます。';

  @override
  String get titleStoreName => '昆虫チャンプ';

  @override
  String get titleStoreTagline => '放置コレクトバトル';

  @override
  String nicknameChangeCostHint(int cost) {
    return '変更にゼリー$cost消費';
  }

  @override
  String incubatorAdSkip(int pct) {
    return '⏩ 無料$pct%短縮';
  }

  @override
  String get incubatorAdSkipDone => '孵化時間が短くなりました！';

  @override
  String get nicknameEditAction => 'ニックネーム変更';

  @override
  String nicknameEditActionCost(int cost) {
    return 'ゼリー$costで変更';
  }

  @override
  String get notifHatchTitle => '孵化完了！';

  @override
  String get notifHatchBody => '卵が孵化しました。採集ボックスで確認してください。';

  @override
  String get settingsNotify => '通知';

  @override
  String get notifyOfflineFull => '放置報酬が満タン';

  @override
  String get notifyHatchDone => '孵化完了';

  @override
  String get notifyDaily => 'デイリー報酬の時間';

  @override
  String get incubatorInstant => 'すぐ孵化';

  @override
  String get incubatorAdSkipBtn => '無料で短縮';

  @override
  String get notifyAll => '通知を受け取る';

  @override
  String get notEnoughMaterials => '素材が足りません';

  @override
  String get notifGiftTitle => 'サプライズギフト到着！';

  @override
  String get notifGiftBody => 'ギフトが待っています。消える前に受け取ってください。';

  @override
  String get notifyGift => 'サプライズギフト';

  @override
  String get notifyQuietHours => 'おやすみ時間（22時〜8時）';

  @override
  String get pvpTicketTitle => '決闘チケット';

  @override
  String pvpTicketCount(int tickets, int max) {
    return '$tickets/$max';
  }

  @override
  String pvpTicketNextIn(String time) {
    return '次の回復 $time';
  }

  @override
  String get pvpTicketFullLabel => '満タン';

  @override
  String get pvpTicketNone => '決闘にはチケットが必要です。下から補充できます。';

  @override
  String pvpTicketAdBtn(int amount) {
    return '無料チャージ+$amount枚';
  }

  @override
  String pvpTicketAdLeft(int used, int limit) {
    return '本日 $used/$limit回';
  }

  @override
  String pvpTicketJellyBtn(int cost) {
    return 'ゼリー$costで満タン';
  }

  @override
  String pvpTicketCharged(int amount) {
    return 'チケット+$amount枚';
  }

  @override
  String get pvpTicketFilled => 'チケットを満タンにしました';

  @override
  String get pvpTicketAlreadyFull => 'チケットはすでに満タンです';

  @override
  String get pvpTicketChargeFailed => 'チケットを補充できませんでした。しばらくしてからお試しください';

  @override
  String get pvpTicketWhy => 'チケットはトロフィーランキングを「回数」ではなく「戦力」で決めるための仕組みです。';

  @override
  String adDailyLimit(int limit) {
    return '本日の無料報酬は受け取り済みです（1日$limit回）';
  }

  @override
  String get noticeTitle => 'お知らせ';

  @override
  String get noticeEmpty => '現在お知らせはありません。';

  @override
  String get noticeFailed => 'お知らせを読み込めませんでした。接続を確認してください。';

  @override
  String get mailNoticeSection => '運営からのメール';

  @override
  String get mailClaim => '受け取る';

  @override
  String get mailClaimAll => 'すべて受け取る';

  @override
  String get gachaTitle => '虫のタマゴガチャ';

  @override
  String get gachaDesc => '高級以上確定 · 色違い確率10倍 · 天井が貯まります';

  @override
  String gachaPityLeft(int n) {
    return 'あと$n回で英雄以上確定';
  }

  @override
  String gachaDraw(int n) {
    return 'ゼリー$n個で引く';
  }

  @override
  String get gachaResultTitle => 'タマゴから出たのは…';

  @override
  String get gachaResultHint => 'タマゴは孵化器で育てましょう';

  @override
  String get gachaStorageFull => 'コレクションがいっぱいです';

  @override
  String get gachaOff => '現在利用できません';

  @override
  String get giftCodeTitle => 'ギフトコード';

  @override
  String get giftCodeHint => 'イベント・お知らせで配布されたコードを入力してください。';

  @override
  String get giftCodeField => 'コード入力';

  @override
  String get giftCodeSubmit => '使用する';

  @override
  String get giftCodeChecking => '確認中…';

  @override
  String get giftCodeOk => '報酬を受け取りました！';

  @override
  String get giftCodeBad => '存在しないコードです';

  @override
  String get giftCodeExpired => '期限切れのコードです';

  @override
  String get giftCodeExhausted => '配布数が上限に達しました';

  @override
  String get giftCodeUsed => 'すでに使用済みです';

  @override
  String get giftCodeFailed => 'サーバーに接続できませんでした。しばらくしてからお試しください';

  @override
  String get reviewAction => 'ゲームを評価する';

  @override
  String get chatAdminBadge => '運営';

  @override
  String get autoEquip => '自動装着';

  @override
  String get autoEquipDone => '最も強い虫を装着しました';

  @override
  String get autoEquipAlready => 'すでに最適な組み合わせです';

  @override
  String get autoTeam => '自動編成';

  @override
  String get autoTeamDone => '最も強いチームを編成しました';

  @override
  String get autoTeamAlready => 'すでに最適なチームです';

  @override
  String teamPower(String power) {
    return 'チーム戦力 $power';
  }

  @override
  String get navCharacter => 'キャラ';

  @override
  String get slotTool => '採集道具';

  @override
  String get slotHat => '帽子';

  @override
  String get slotTop => '上着';

  @override
  String get slotBottom => '脚衣';

  @override
  String get slotShoes => '靴';

  @override
  String get slotNecklace => '首飾り';

  @override
  String get slotRing => '指輪';

  @override
  String get slotBox => '標本箱';

  @override
  String get optAttack => '攻撃力';

  @override
  String get optAttackSpeed => '攻撃速度';

  @override
  String get optCritChance => '会心率';

  @override
  String get optCritDamage => '会心ダメージ';

  @override
  String get optMaxHp => '体力';

  @override
  String get optDefense => '防御';

  @override
  String get optGold => '金貨獲得';

  @override
  String get optMaterial => '素材獲得';

  @override
  String get optBugFind => '昆虫発見率';

  @override
  String get optBossDamage => 'ボスダメージ';

  @override
  String get optSkillDamage => 'スキルダメージ';

  @override
  String get optSkillCooldown => 'スキル再使用短縮';

  @override
  String get optBoost => 'タップブースト';

  @override
  String get optOffline => '放置効率';

  @override
  String get optPet => 'ペット効果';

  @override
  String get charEquipment => '装備';

  @override
  String get charPets => 'ペット';

  @override
  String get charSkills => 'スキル';

  @override
  String get charPower => '戦闘力';

  @override
  String get charEmptySlot => '空き';

  @override
  String get forgeTitle => '工房';

  @override
  String get forgeHammer => '製錬';

  @override
  String get forgeAuto => '自動製錬';

  @override
  String get forgeResultKeep => '装備';

  @override
  String get forgeResultDrop => '捨てる';

  @override
  String get forgeCurrent => '装備中';

  @override
  String get forgeNoFossil => '化石のかけらがありません';

  @override
  String forgeLevel(int lv) {
    return '工房レベル $lv';
  }

  @override
  String forgeStep(int cur, int max) {
    return '工房アップグレード $cur/$max';
  }

  @override
  String get forgeUpgrading => 'アップグレード中';

  @override
  String get forgeReady => '完了！';

  @override
  String get forgeRush => '今すぐ完了';

  @override
  String get forgeClaim => '受け取る';

  @override
  String get forgeNext => '次のレベルの確率';

  @override
  String get forgeMaxLevel => '最高レベル';

  @override
  String get forgeAutoTarget => '希望オプション';

  @override
  String get forgeStopOnHit => '見つけたら停止';

  @override
  String get skillLearn => '習得';

  @override
  String skillLevelUp(int lv, int next) {
    return 'レベル $lv → $next';
  }

  @override
  String get skillEquipped => '装備中';

  @override
  String get skillSlotsFull => 'スキル枠がいっぱいです';

  @override
  String get charTabStats => '能力値';

  @override
  String get charTabPets => 'ペット';

  @override
  String get charTabSkills => 'スキル';

  @override
  String get forgeGradeButton => '工房グレード';

  @override
  String get statHp => '体力';

  @override
  String get statGoldGain => '金貨獲得';

  @override
  String get statMaterialGain => '素材獲得';

  @override
  String get statBugFind => '昆虫発見率';

  @override
  String get charNoPet => 'ペットなし';

  @override
  String get charPetHint => 'ペットの編成は採集箱で行います';

  @override
  String get forgeAutoShort => '自動';

  @override
  String get forgeStackFull => '金床がいっぱいです';

  @override
  String get forgeStackHint => 'タップで確認';

  @override
  String get sceneCatchTap => '今タップ！';

  @override
  String get forgeResultNew => '新しい装備';

  @override
  String get forgeFilter => 'フィルタ';

  @override
  String get forgeFilterHint => 'チェックした能力が1つ以上付いたものだけ残します。';

  @override
  String get forgeFiltered => '条件に合わず破棄しました';

  @override
  String get elementWheelTitle => '五行相性';

  @override
  String get elementWheelRestrain => '相克 — 赤い矢印が指す相手を攻撃するとダメージ1.5倍';

  @override
  String get elementWheelGenerate => '相生 — 編成で直前の枠が緑の矢印で自分を指すとチーム全体の攻撃・回復+10%';

  @override
  String get traitNoneBadge => '特性なし';

  @override
  String get elementWheelHint => '編成は緑の矢印に沿って並べます。木 → 火 → 土 なら連結2つで+20%。';

  @override
  String get leagueRewardListTitle => '初回達成報酬（等級ごと1回）';

  @override
  String get sideMine => '自分';

  @override
  String get sideFoe => '相手';

  @override
  String get battleStarting => '決闘開始！';

  @override
  String get sideMineTeam => '自分のチーム';

  @override
  String get sideFoeTeam => '相手チーム';

  @override
  String leagueNeedTrophy(int n) {
    return 'トロフィー$n';
  }

  @override
  String seasonRewardNow(String league) {
    return 'シーズン報酬・現在 $league';
  }

  @override
  String get seasonRewardHint => '毎週月曜9時、その瞬間の等級で支給されます。終わる前に上げておきましょう。';

  @override
  String eventOpensOn(String m, String d) {
    return '$m月$d日に開幕';
  }

  @override
  String eventOpensInDays(int n) {
    return 'D-$n';
  }

  @override
  String eventOpensInHours(int n) {
    return '$n時間後に開始';
  }

  @override
  String eventOpensInMinutes(int n) {
    return '$n分後に開始';
  }

  @override
  String get eventSeeFlyer => '大会案内を見る';

  @override
  String eventSoonBanner(String when) {
    return '王蟲選抜大会・$when 開幕';
  }

  @override
  String get eventFlyerPrizeTag => '1位の賞品';

  @override
  String adCooldown(int n) {
    return '次の広告まで$n秒';
  }

  @override
  String get jellyContinueTitle => 'ゼリーを使う';

  @override
  String jellyContinueAsk(int n) {
    return '本日の無料回数を使い切りました。ゼリー$n個で続けますか？';
  }

  @override
  String get jellyContinueYes => 'ゼリーを使う';

  @override
  String get giftDoubleCapTitle => '本日の無料2倍は受け取り済み';

  @override
  String get giftDoubleCapBody => 'パスがあればすべてのギフトがずっと2倍、\n受け取りも自動です。';

  @override
  String get exchangeTitle => '交換所';

  @override
  String get exchangeHint => 'ゼリーを現在ステージの放置1時間分に交換します';

  @override
  String get exchangeToGold => 'ゴールドへ';

  @override
  String get exchangeToMaterial => '素材へ';

  @override
  String exchangeCost(int n) {
    return 'ゼリー$n';
  }

  @override
  String exchangeGetGold(String amount) {
    return '$amount ゴールド獲得';
  }

  @override
  String exchangeGetMaterial(String amount) {
    return '素材3種を各$amount獲得';
  }

  @override
  String get exchangeDone => '交換しました！';

  @override
  String get curJelly => 'ゼリー';

  @override
  String get exchangeHoldings => '所持状況';

  @override
  String get elementGuideBtn => '五行の相性';

  @override
  String get giftAdMoreFreeLine => '無料2倍は1日1回！';

  @override
  String get giftAdMorePassLine => 'パスがあればいつでも2倍';

  @override
  String get giftGoPassBtn => 'パスを見る';

  @override
  String get eventLegalTitle => '大会の規定';

  @override
  String get eventLegalHost =>
      '本大会はBug Champ運営チーム（開発元）が主催・運営し、賞品の提供・発送の責任も運営チームにあります。';

  @override
  String get eventLegalStores =>
      'AppleおよびGoogleは本大会のスポンサーではなく、いかなる形でも関与していません。';

  @override
  String get eventLegalPrize =>
      '順位は大会終了時点の記録で確定し、1位の方にはアプリ内のお知らせで賞品の受け取り方法をご案内します（受け取りのため配送先の確認が必要な場合があります）。賞品の獲得に購入は必要ありません。';

  @override
  String get eventLegalFair =>
      '不正行為（改ざんデータ・異常なアクセス）が確認された場合、順位および賞品の対象から除外されることがあります。';

  @override
  String get giftBuyPassBtn => 'パスを購入';

  @override
  String get supportTitle => '運営に問い合わせ';

  @override
  String get supportHint => '不具合や不便な点を教えてください。ニックネームと進行状況も自動で送られます。';

  @override
  String get supportSend => '送信';

  @override
  String get supportSent => '送信しました。確認して対応します！';

  @override
  String get supportFailed => '送信できませんでした。しばらくしてからお試しください。';

  @override
  String get supportTooFast => '少し経ってからもう一度送れます。';
}
