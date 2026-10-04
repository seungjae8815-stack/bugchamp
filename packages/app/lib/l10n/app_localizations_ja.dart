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
  String get scoutRefreshFree => '更新 (無料)';

  @override
  String scoutRefreshJelly(int n) {
    return '更新 (ゼリー$n)';
  }

  @override
  String get scoutRefreshDone => '本日の更新は終了';

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
  String get modeManual => '投げる';

  @override
  String get modeAuto => 'クイック';

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
  String get storePending =>
      '決済を確認しています。確認できると自動で付与されます。数分待っても届かない場合はショップの「購入を復元」を押してください';

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
  String get leaderboardUnranked => '圏外';

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
  String offlineBugs(int count) {
    return '🥚 虫の卵を$count個採集しました';
  }

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
  String durationH(int h) {
    return '$h時間';
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
  String zoneLabel(int n) {
    return '狩り場 $n';
  }

  @override
  String get zoneFinalLabel => '最終狩り場';

  @override
  String get bossChallenge => 'ボスに挑戦';

  @override
  String bossChallengeLocked(int n) {
    return '挑戦まであと$n体';
  }

  @override
  String get bossChallengeFailed => 'ボスに押し返されました。強くなって再挑戦しましょう';

  @override
  String get bossFlee => '逃げる';

  @override
  String get bossFleeTitle => '逃げますか？';

  @override
  String get bossFleeDesc => '狩場ゲージが空になります。\n倒れたときと同じです。';

  @override
  String get bossFled => '逃げました · ゲージが空に';

  @override
  String zoneKillsLabel(int n, int m) {
    return '討伐 $n/$m';
  }

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
  String get dexComplete => 'この種はコンプリート';

  @override
  String get dexCompleteShort => 'コンプ';

  @override
  String get dexConqueredYes => '完了';

  @override
  String get dexConqueredNo => 'まだ';

  @override
  String dexConquerNeed(int need, int now) {
    return 'Lv$need必要 (現在$now)';
  }

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
  String get dexTabBugs => '昆虫';

  @override
  String get dexTabBosses => 'ボス';

  @override
  String get dexBosses => 'ボス収集';

  @override
  String get dexBossNotFound => 'まだ倒していないボスです。この難易度の狩場でボスを倒すと記録されます。';

  @override
  String get dexBossHint => '難易度ごとに別々に集めます。下の難易度に戻って倒しても記録されます。';

  @override
  String dexClaimedFossil(Object fossil) {
    return '化石$fossil個も獲得';
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
    return '$nウェーブ突破！\n1つ選んでください';
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
  String get cardReviveDesc => '体力が尽きても一度だけ、体力50%で起き上がり同じウェーブに再挑戦';

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
  String get eventFlyerHow1 => '一番育てた成虫1匹を選んで出場';

  @override
  String get eventFlyerHow2 => 'ウェーブ突破ごとに強化カードを1枚選択';

  @override
  String get eventFlyerHow3 => 'より遠くまで進んだ人が上位';

  @override
  String get eventFlyerRules => '必ずご確認ください';

  @override
  String get eventFlyerRule1 =>
      '**育てたまま**戦います — ポテンシャル・部位強化・修練・訓練所がすべて反映(決闘と同じ能力値)';

  @override
  String get eventFlyerRule2 => '敵の五行はウェーブごとに変わります — 自分が苦手な色のウェーブが山場です';

  @override
  String get eventFlyerRule3 => '出場すると虫がケガをして回復室で休みます — ゼリーですぐ回復できます';

  @override
  String eventFlyerRule4(int daily, int jelly, int extra) {
    return '参加券は毎朝$daily枚補充され、ゼリー$jelly個で1日$extra枚まで追加チャージできます';
  }

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
  String get battleNeedServer => '決闘にはオンライン接続が必要です';

  @override
  String get eventQuitFailed => 'やめられませんでした — 接続を確認してもう一度押してください';

  @override
  String get eventBugUnavailable => 'その昆虫では挑戦できません — 別の昆虫を選んでください';

  @override
  String get injuryHealConfirmTitle => '即時回復';

  @override
  String injuryHealConfirm(int n) {
    return 'ゼリー$n個を使って今すぐ回復しますか？';
  }

  @override
  String get trainingInstantTitle => '訓練を即時完了';

  @override
  String get squadTrainingBadge => '訓練中';

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
  String eventWaveRecord(String n) {
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
  String get eventPickTeam => '出場する虫を1匹選んでください';

  @override
  String get eventPickOrder => '敵と1匹ずつ連続で戦います · 毎試合投げゲージ · 体力が命です';

  @override
  String get eventNormalizeTitle => '育てた分だけ強い';

  @override
  String eventNormalizeBody(int pct) {
    return '決闘と同じ能力値で戦います — ポテンシャル・部位強化・修練・訓練所・特性がすべて反映されます。場外・ひっくり返しで負けると体力が$pct%減って同じウェーブに再挑戦。体力が尽きたら終了です。';
  }

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
  String get eventJellyTicket => '参加券を購入';

  @override
  String get eventNoJelly => 'ゼリーが足りません';

  @override
  String get eventAdLimit => '本日の無料報酬は受け取り済みです';

  @override
  String get eventTicketFull => '参加券が満杯です';

  @override
  String eventResultTitle(Object n) {
    return '$nウェーブ到達！';
  }

  @override
  String get eventLeadStrong => '有利';

  @override
  String get eventLeadWeak => '不利';

  @override
  String eventTicketBought(int n) {
    return '参加券を$n枚チャージしました';
  }

  @override
  String eventTicketDaily(int used, int max) {
    return '本日 $used/$max';
  }

  @override
  String get eventStopWipe => 'チームが全滅したのでここで終了です。';

  @override
  String get eventStopJudge => '20ラウンドが過ぎ、残りHPの判定で及ばずでした。虫が残っていてもここで終了します。';

  @override
  String get eventStopMax => '最後のウェーブまですべてクリアしました！';

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
  String giftDoubledMult(String n) {
    return '報酬 x$n 獲得!';
  }

  @override
  String get giftAdMoreTitle => '本日の無料2倍！';

  @override
  String get giftAdMoreBody => 'このプレゼントを2倍で受け取れます。';

  @override
  String get giftAdMoreYes => '2倍で受け取る';

  @override
  String get giftAdMoreLater => 'そのまま受け取る';

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
  String get synthConfirm => 'この昆虫が消えます';

  @override
  String get synthConfirmTitle => '合成の確認';

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
  String get disassembleConfirm => 'この昆虫は取り戻しにくいです。本当に分解しますか?';

  @override
  String get disassembleAction => '分解';

  @override
  String get incubatingLabel => '孵化中';

  @override
  String get disassembleSnack => '分解完了';

  @override
  String get disassembleEquipped => '装備中の虫は分解できません';

  @override
  String get disassembleIncubating => '孵化中のタマゴは分解できません';

  @override
  String get disassembleFailed => '分解できません';

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
  String get missionForgeItems => '装備製錬';

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
  String get upRegenDesc => '毎秒、最大体力の一定割合を回復します。攻撃に耐える時間が伸びます。';

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
  String get nicknameSameName => '今の名前とは違う名前を入力してください。';

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
  String buffBtnPassLeft(int n) {
    return 'パス残り$n日';
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
      'ステージ・レベル・強化・ゴールド・素材が最初に戻ります。\n\n昆虫・装備・図鑑・ゼリー・スキルはそのまま残ります。\n\nランキングは難易度が優先です —難易度を上げるとレベルが低くても上位になります。\n\nモンスターがずっと強くなります。';

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
  String get sessionTakenTitle => '別の端末で接続中です';

  @override
  String get sessionTakenBody =>
      '同じアカウントで別の端末からゲームが開始されました。\nこの端末で続けると、別の端末の進行を読み込みます。';

  @override
  String get sessionTakenContinue => 'この端末で続ける';

  @override
  String get sessionTakenFailed => '読み込めませんでした。少し待ってから再試行してください。';

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
  String get renameForcedTitle => 'ニックネームを変更してください';

  @override
  String get renameForcedBody =>
      '運営がニックネームの変更を求めています。\n他のプレイヤーに表示される名前のため、ルールに沿う必要があります。\n今回の変更は無料です。';

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
  String get mailReadMore => '全文を見る';

  @override
  String get mailConfirm => '確認';

  @override
  String get gachaTitle => '虫のタマゴガチャ';

  @override
  String get gachaDesc => 'ポテンシャル3★以上確定 (野生では5★が出ません) · 色違い確率10倍';

  @override
  String gachaPityLeft(int n) {
    return 'あと$n回で伝説確定';
  }

  @override
  String gachaDraw(int n) {
    return 'ゼリー$n個で引く';
  }

  @override
  String get gachaResultTitle => 'タマゴから出たのは…';

  @override
  String get gachaPickTitle => 'カードを選んでください';

  @override
  String get gachaPickHint => '3枚から1枚。開けるまで分かりません';

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
  String get forgeResultDrop => '売る';

  @override
  String forgeResultSell(String n) {
    return '売る · $n';
  }

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
  String get forgeRush => '加速';

  @override
  String get forgeClaim => '受け取る';

  @override
  String get forgeNext => '次のレベルの確率';

  @override
  String get forgeMaxLevel => '最高レベル';

  @override
  String get forgeAutoTarget => '希望オプション';

  @override
  String get forgeStopOnHit => '目当てが出たら止める';

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
  String get skillAuto => 'オート';

  @override
  String get skillTimingBonus => 'タイミングボーナス！';

  @override
  String skillReflect(String n) {
    return '反射 $n';
  }

  @override
  String get skillBlocked => 'ブロック';

  @override
  String get skillGacha => 'ガチャ';

  @override
  String get skillGachaTitle => 'スキルガチャ';

  @override
  String skillGachaFreeLeft(String n) {
    return '本日無料 $n回';
  }

  @override
  String skillGachaPityLeft(String grade, String n) {
    return '$n回以内に$grade確定';
  }

  @override
  String get skillGachaFree => '無料ガチャ';

  @override
  String skillGachaOne(String n) {
    return '1回 · ゼリー $n';
  }

  @override
  String skillGachaTen(String n) {
    return '10回 · ゼリー $n';
  }

  @override
  String skillTimes(String n) {
    return '×$n';
  }

  @override
  String get skillGachaOdds => '確率を見る';

  @override
  String get skillGachaOddsTitle => 'スキルガチャの確率';

  @override
  String skillGachaOddsGrade(String grade, String p, String each) {
    return '$grade $p% · スキル1種あたり $each%';
  }

  @override
  String skillGachaOddsNote(String n, String pity, String grade) {
    return '1回でスキル1種のかけらが$n個出ます。$pity回目は$grade以上が確定し、$gradeが出ると回数がリセットされます。';
  }

  @override
  String skillGachaResult(String name, String n) {
    return '$nameのかけら +$n';
  }

  @override
  String get skillSweep => '掃討';

  @override
  String get skillSweepTitle => 'ボス掃討';

  @override
  String skillSweepDesc(String tier, String n) {
    return '倒したことのある最も高い難易度（$tier）のボスを再び倒したものとして、スキルのかけらを$n個確定で受け取ります。';
  }

  @override
  String skillSweepToday(String used, String max) {
    return '本日 $used/$max回 使用';
  }

  @override
  String skillSweepFree(String n) {
    return '無料掃討 · 残り$n回';
  }

  @override
  String skillSweepPaid(String n) {
    return '掃討 · ゼリー $n';
  }

  @override
  String get skillSweepNoBoss => '狩場のボスを1体以上\n倒すと掃討できます';

  @override
  String get skillSweepLocked => 'ボス撃破が先';

  @override
  String get skillGradeUpShort => 'カケラ昇級';

  @override
  String get skillShardsTitle => '所持カケラ';

  @override
  String get skillWildShort => '万能';

  @override
  String get skillSweepLimit => '本日の掃討はすべて使いました';

  @override
  String skillShardPop(String n) {
    return 'かけら +$n';
  }

  @override
  String get skillMaterials => 'スキル素材';

  @override
  String skillGradeWild(String grade) {
    return '$grade万能';
  }

  @override
  String get skillGradeUp => '昇級';

  @override
  String skillGradeUpTitle(String from, String to) {
    return '$fromのかけら → $to万能のかけら';
  }

  @override
  String skillGradeUpDesc(String ratio, String from, String to) {
    return '$fromのかけら$ratio個で$to万能のかけらを1個作ります。万能のかけらはどの$toスキルにも使えます。材料にするかけらを選んでください。';
  }

  @override
  String skillGradeUpMake(String n) {
    return '$n個作る';
  }

  @override
  String skillGradeUpDone(String n, String grade) {
    return '$grade万能のかけらを$n個作りました';
  }

  @override
  String get skillGradeUpPick => '材料にするかけらを選んでください';

  @override
  String get skillEquip => '装備';

  @override
  String get skillUnequip => '外す';

  @override
  String skillSlotsInfo(String n, String max) {
    return '装備 $n/$max';
  }

  @override
  String get skillNextSlotHint => '新しい難易度で枠が増えます';

  @override
  String skillShardProgress(String have, String need) {
    return 'かけら $have/$need';
  }

  @override
  String get skillLocked => '未解放';

  @override
  String get skillMaxLevel => 'MAX';

  @override
  String get skillTrain => '修練';

  @override
  String skillTrainingNow(String name, String lv, String left) {
    return '$name Lv.$lv 修練中 · $left';
  }

  @override
  String get skillTrainClaim => '修練完了';

  @override
  String skillTrainInstant(String n) {
    return '今すぐ完了 · ゼリー $n';
  }

  @override
  String get actionInstant => '即時完了';

  @override
  String get skillTrainConfirmTitle => '修練を今すぐ完了';

  @override
  String skillTrainConfirm(String n) {
    return 'ゼリー$n個で今すぐ完了しますか？';
  }

  @override
  String skillTrainCostShards(String n, String time) {
    return 'かけら $n · $time';
  }

  @override
  String skillTrainCostWithAny(String n, String any, String time) {
    return 'かけら $n + 万能 $any · $time';
  }

  @override
  String skillTrainTitle(String name) {
    return '$nameの修練';
  }

  @override
  String skillLevelUpDone(String name, String lv) {
    return '$name Lv.$lv 達成！';
  }

  @override
  String get skillErrNotEnoughShards => 'かけらが足りません';

  @override
  String get skillErrTrainingBusy => '修練中のスキルがあります';

  @override
  String get skillActiveSoon => 'アクティブスキルは近日公開';

  @override
  String get skillHowToGet => '狩場のボス（初回撃破で確定）とエリートモンスターからスキルのかけらが手に入ります';

  @override
  String skillCooldown(String s) {
    return 'クールタイム $s秒';
  }

  @override
  String get skillKindActive => 'アクティブ';

  @override
  String get skillKindPassive => 'パッシブ';

  @override
  String skillShardsGot(String list) {
    return 'スキルのかけら獲得 · $list';
  }

  @override
  String get skillReviveToast => '脱皮！倒れずに立ち上がりました';

  @override
  String skillFxMaterialFind(String v) {
    return '素材獲得 +$v%';
  }

  @override
  String skillFxBugFind(String v) {
    return '昆虫発見 +$v%';
  }

  @override
  String skillFxBossDamage(String v) {
    return 'ボスダメージ +$v%';
  }

  @override
  String skillFxPerPetAttack(String v) {
    return '装備した昆虫1匹につき攻撃 +$v%';
  }

  @override
  String skillFxKillHeal(String v) {
    return '撃破回復 +$v%';
  }

  @override
  String skillFxRevive(String v) {
    return '倒れると体力$v%で復活';
  }

  @override
  String skillFxMaterialBurst(String v, String d) {
    return '$d秒間 素材 ×$v';
  }

  @override
  String skillFxAttackSpeed(String v, String d) {
    return '$d秒間 攻撃速度 ×$v';
  }

  @override
  String skillFxAreaDamage(String v) {
    return '画面全体に$v秒分のダメージ';
  }

  @override
  String skillFxPetPower(String v, String d) {
    return '$d秒間 昆虫効果 ×$v';
  }

  @override
  String skillFxBurstDamage(String v) {
    return '$v秒分のダメージの一撃';
  }

  @override
  String skillFxInvulnerable(String d) {
    return '$d秒間 ダメージ無効';
  }

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
  String get forgeFilterGrade => '最低グレード';

  @override
  String get forgeFilterGradeHint => 'このグレード未満は捨てます。';

  @override
  String forgeFilterRangeHint(String tier) {
    return '範囲は$tierグレードの最大値です';
  }

  @override
  String get optPerfect => '完璧';

  @override
  String get forgeFilterGradeAll => 'すべて';

  @override
  String get forgeFilterOption => '能力値';

  @override
  String forgeStrikes(int n) {
    return 'x$n';
  }

  @override
  String get forgeStrikePick => 'ハンマーごとの個数';

  @override
  String get forgeStrikePickHint => '一度叩くたびに作る個数です。手動タップにも適用されます。';

  @override
  String forgeStrikeLocked(int n) {
    return 'チャプター$nが必要';
  }

  @override
  String get forgeStrikeAuto => '最大';

  @override
  String get forgeReroll => '再抽選';

  @override
  String get forgeExpand => '枠拡張';

  @override
  String get forgeExpandMax => '最大';

  @override
  String get forgeRushTitle => 'ハンマー加速';

  @override
  String forgeRushBody(int cost, int sec) {
    return 'ゼリー$cost個で$sec秒間、ハンマーが2倍速に。\n加速中に使うと残り時間に加算されます。';
  }

  @override
  String forgeRushLeft(int sec) {
    return '残り$sec秒';
  }

  @override
  String get forgeRerollHint => '等級・部位はそのまま、オプションのみ再抽選';

  @override
  String forgeRushOn(int s) {
    return '加速 $s秒';
  }

  @override
  String forgeStackCount(int n, int max) {
    return '金床 $n/$max';
  }

  @override
  String get forgeNoJelly => 'ゼリーが足りません';

  @override
  String get upgradeMaxed => '最大';

  @override
  String get eliteLabel => '精鋭';

  @override
  String gateGearHint(String cur, String need) {
    return '装備 ×$cur · 推奨 ×$need';
  }

  @override
  String get gateGearWeak => '装備が弱い — 鍛冶で攻撃オプションを集めよう';

  @override
  String get regionElementTitle => '地域の属性';

  @override
  String get regionElementHint =>
      'この属性を克する昆虫を装備すると、その攻撃が強くなります。昆虫はキャラクターとは別に、自分の速さで攻撃します。';

  @override
  String get forgeStrikeStart => '開始';

  @override
  String get forgeStopOnHitHint => 'フィルターに合うものが出たら自動を止めます。残りの化石を使いません。';

  @override
  String get forgeStopOnHitNoFilter => '先にフィルターを設定してください';

  @override
  String get forgeStoppedOnHit => '目当ての装備が出ました';

  @override
  String get forgeStrikeAutoHint => 'チャプターを進めると自動で増えます';

  @override
  String get forgeFiltered => '条件に合わず破棄しました';

  @override
  String get elementWheelTitle => '五行相性';

  @override
  String elementWheelRestrain(String mult) {
    return '相剋 — 赤い矢印の先の相手にぶつかるとダメージ$mult倍';
  }

  @override
  String get traitNoneBadge => '特性なし';

  @override
  String get elementWheelHint => '例）水 → 火：水属性の虫は火属性の虫に大きなダメージを与えます。';

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
  String get seasonRewardHint => '毎週日曜9時に締め切り、その瞬間のリーグで支給されます。締め切り前に上げておきましょう。';

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
  String giftDoubleJellyLine(int min, int max) {
    return '本日初の2倍ボーナス：昆虫ゼリー$min〜$max個！';
  }

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

  @override
  String get zoneConquered => '制圧済み';

  @override
  String get zoneHere => '現在地';

  @override
  String get zoneLocked => 'ロック';

  @override
  String badgeParticipant(int round) {
    return '$round回 参加';
  }

  @override
  String get eventWaitingTitle => '次の大会を準備中';

  @override
  String eventNextRound(int no, String date) {
    return '第$no回大会・$date 開幕';
  }

  @override
  String eventDateMd(int m, int d) {
    return '$m月$d日';
  }

  @override
  String get eventHallTitle => '殿堂';

  @override
  String eventHallRound(int no, String n) {
    return '第$no回・参加 $n名';
  }

  @override
  String get eventHallEmpty => 'まだ殿堂入りした人はいません';

  @override
  String get eventHallTop10 => '4〜10位';

  @override
  String get eventHallEntrants => '参加した皆さん';

  @override
  String get eventHallMore => 'ほか多数';

  @override
  String get eventRewardBadgeLabel => '獲得バッジ';

  @override
  String tierMoveTitle(String name) {
    return '$name難易度へ移動';
  }

  @override
  String get tierMoveBody => '強化・通貨・装備はそのままです。\n狩場クリア報酬は到達した最高難易度でのみ受け取れます。';

  @override
  String get tierMoveGo => '移動';

  @override
  String tierMoved(String name) {
    return '$name難易度へ移動しました';
  }

  @override
  String get pvpRankRewardTitle => '決闘シーズン順位報酬';

  @override
  String pvpRankRewardBody(int rank) {
    return '前シーズンの決闘で$rank位になりました！';
  }

  @override
  String pvpRankN(int n) {
    return '$n位';
  }

  @override
  String pvpRankRewardHint(String list) {
    return '順位報酬（ゼリー） $list';
  }

  @override
  String get duelThrowButton => '投げる！';

  @override
  String duelGaugeHint(int pct) {
    return '画面のどこでもタップで停止 · 緑に近いほどこの試合の攻撃力が上がる(最大+$pct%)';
  }

  @override
  String duelBout(int n) {
    return '第$n戦';
  }

  @override
  String get duelFinishRingOut => '場外！';

  @override
  String get duelFinishFlip => 'ひっくり返し！';

  @override
  String get duelFinishKnockout => '気絶！';

  @override
  String get duelFinishTimeUp => '判定！';

  @override
  String get duelBoutWin => '勝った！';

  @override
  String get duelBoutLose => '負けた…';

  @override
  String get duelSkip => 'スキップ';

  @override
  String duelTrophy(String delta) {
    return 'トロフィー $delta';
  }

  @override
  String get duelResultOk => 'OK';

  @override
  String get duelNeedThree => '決闘には昆虫が3匹必要です';

  @override
  String get duelOrderHint => '1・2・3番が1戦ずつ戦います・この順番が防衛の順番になります';

  @override
  String get abyssName => '深淵';

  @override
  String abyssFloorLabel(int n) {
    return '深淵 $n階';
  }

  @override
  String get abyssUnlockedTitle => '深淵が開きました！';

  @override
  String get abyssUnlockedBody =>
      '極限の先に果てしなく続く階層です。強化・装備・昆虫はそのまま持っていけます。\n毎週月曜9時に1階からやり直し、日曜9時の締め切りで最も深く潜った順位でゼリーがもらえます。';

  @override
  String get abyssEnter => '深淵へ';

  @override
  String get abyssLater => 'あとで';

  @override
  String get abyssLeave => '深淵から出る';

  @override
  String abyssFloorClear(int n) {
    return '$n階突破！';
  }

  @override
  String abyssMilestone(int n, int fossil) {
    return '$n階に初到達！化石 +$fossil';
  }

  @override
  String abyssBest(int n) {
    return '最高 $n階';
  }

  @override
  String get abyssWeekReset => '新しい週です — 深淵1階から！';

  @override
  String get abyssRankRewardTitle => '深淵 週間順位報酬';

  @override
  String abyssRankRewardBody(int floor, int rank) {
    return '先週は深淵$floor階・$rank位でした！';
  }

  @override
  String get boardTitle => 'ランキング';

  @override
  String get boardTabDuel => '決闘リーグ';

  @override
  String get boardTabAbyss => '深淵';

  @override
  String boardLeagueTitle(String league) {
    return '$leagueリーグ';
  }

  @override
  String get boardAbyssTitle => '深淵 週間ランキング';

  @override
  String boardSeasonEndsIn(String time) {
    return '新シーズンまで：$time';
  }

  @override
  String boardTimeLeftDays(int d, int h, int m) {
    return '$d日$h時間$m分';
  }

  @override
  String boardTimeLeft(int h, int m) {
    return '$h時間$m分';
  }

  @override
  String boardZonesHint(int promote, int demote) {
    return '上位$promote人昇格・下位$demote人降格';
  }

  @override
  String get boardEmpty => '今週の記録はまだありません';

  @override
  String get boardMeNone => '今週決闘するとランキングに載ります';

  @override
  String get boardAbyssMeNone => '今週深淵1階を突破するとランキングに載ります';

  @override
  String boardFloorShort(int n) {
    return '$n階';
  }

  @override
  String boardRewardsTitle(String league) {
    return '$leagueリーグ 順位報酬';
  }

  @override
  String get boardAbyssRewardsTitle => '深淵 週間順位報酬';

  @override
  String get boardOpen => 'ランキング';

  @override
  String get leagueResultTitle => 'リーグ決算';

  @override
  String leagueResultUp(String league) {
    return '$leagueリーグに昇格！';
  }

  @override
  String leagueResultDown(String league) {
    return '$leagueリーグに降格しました';
  }

  @override
  String leagueResultStay(String league) {
    return '$leagueリーグ残留';
  }

  @override
  String leagueResultRank(int rank, int total) {
    return '先週 $total人中 $rank位';
  }

  @override
  String get leagueResultInactive => '先週決闘を休んだため1段階降格しました';

  @override
  String get leagueZoneHint => '毎週日曜9時締切・上位20%昇格・下位20%降格';

  @override
  String get duelSquadTitle => '出陣昆虫';

  @override
  String get recoveryRoom => '回復室';

  @override
  String get trainingCenter => '訓練所';

  @override
  String get trainingSoon => '訓練所はまもなくオープン';

  @override
  String get leagueClaimPromo => '昇格報酬を受け取る';

  @override
  String get battleSeasonClosed => 'シーズンが終了しました！';

  @override
  String get recoveryEmpty => '回復中の昆虫はいません';

  @override
  String get opponentPickTitle => '対戦相手を選ぶ';

  @override
  String opponentPickHint(String power) {
    return 'チーム戦闘力 $power・勝てば星を獲得、負けても失わない';
  }

  @override
  String get opponentWinOnly => '勝利時';

  @override
  String boardSeasonClosesIn(String time) {
    return 'シーズン締切：$time';
  }

  @override
  String boardMyRankNow(int rank) {
    return '現在$rank位 — 獲得報酬';
  }

  @override
  String profileCombatPower(String power) {
    return '戦闘力 $power';
  }

  @override
  String get profileNoTeam => 'まだ防衛チームがありません';

  @override
  String duelAutoThrowIn(int n) {
    return '$n秒後に自動で投げます';
  }

  @override
  String get duelRestrainHit => '相克！';

  @override
  String get duelCritHit => 'クリティカル！';

  @override
  String get duelWeakHit => '弱点！';

  @override
  String pvpTicketJellyGive(int amount) {
    return '+$amount枚チャージ';
  }

  @override
  String get bugInfoAtk => '攻撃力';

  @override
  String get bugInfoDef => '防御力';

  @override
  String get bugInfoSpd => '素早さ';

  @override
  String get bugInfoSpecialty => '得意技';

  @override
  String get bugInfoTemperament => '気質';

  @override
  String get bugInfoSize => 'サイズ';

  @override
  String get bugInfoPotential => 'ポテンシャル';

  @override
  String get squadDetailTitle => '出陣昆虫';

  @override
  String get squadDeploy => '出陣';

  @override
  String get squadInjured => '回復中の昆虫がいます — 回復室で回復するか入れ替えてください';

  @override
  String squadOrder(int n) {
    return '$n番目';
  }

  @override
  String get duelAttackBtn => '攻撃';

  @override
  String get squadRelease => '解除';

  @override
  String get squadSwap => '交代';

  @override
  String get trainAttack => '攻撃';

  @override
  String get trainDefense => '防御';

  @override
  String get trainEvade => '回避';

  @override
  String get trainCrit => '会心';

  @override
  String get trainRecovery => '回復力';

  @override
  String get trainingNone => '訓練中の昆虫はいません';

  @override
  String trainingNow(String stat, int level) {
    return '$stat $level段階 訓練中';
  }

  @override
  String get trainingDone => '訓練完了！';

  @override
  String get trainingPickBug => '訓練する昆虫';

  @override
  String get trainingCapHint => '最大段階はポテンシャル・気質・得意技・血統特性で昆虫ごとに違います';

  @override
  String trainingLevel(int lv, int cap) {
    return '$lv / $cap段階';
  }

  @override
  String get trainingStart => '訓練';

  @override
  String get trainingMaxed => '最大';

  @override
  String get trainingBusy => '訓練所は一度に1匹だけです';

  @override
  String get trainingNoMaterials => '素材が足りません';

  @override
  String get trainingReset => '訓練リセット';

  @override
  String trainingResetAsk(String n) {
    return 'すべての段階を0に戻し、使った素材の半分（各$n）を返します';
  }

  @override
  String get trainingResetDone => '訓練をリセットしました';

  @override
  String get squadTraining => '訓練中の昆虫は出陣できません';

  @override
  String get duelMiss => 'ミス！';

  @override
  String get breedingConfirm => '交配';

  @override
  String breedingTimeInfo(String t) {
    return '産卵まで $t';
  }

  @override
  String get incubatorStartConfirm => '孵化開始';

  @override
  String incubatorTimeInfo(String t) {
    return '孵化まで $t';
  }

  @override
  String get bugInfoSex => '性別';

  @override
  String get bugInfoElement => '五行';

  @override
  String leagueInfoTitle(String league) {
    return '$leagueリーグ';
  }

  @override
  String get leagueInfoRank => '週間順位報酬（日曜9時締切）';

  @override
  String get leagueInfoSeason => 'シーズン終了報酬';

  @override
  String get leagueInfoAll => 'リーグ別報酬';

  @override
  String get leagueInfoCurrent => '現在';

  @override
  String get leagueInfoAllHint => 'ゼリー＝そのリーグの1位報酬・ゴールド＝シーズン終了報酬';

  @override
  String get boardPromoteLine => '▲ ここより上は昇格圏';

  @override
  String get boardDemoteLine => '▼ ここより下は降格圏';

  @override
  String get squadAutoFilled => '出陣昆虫を自動で編成しました。確認してもう一度開始を押してください';

  @override
  String get battleSeasonClosedShort => 'シーズン終了';

  @override
  String leagueMyNow(int rank, int total) {
    return '現在 $total人中 $rank位';
  }

  @override
  String leagueMyPromote(String league) {
    return '▲ 昇格圏 — 来週 $leagueリーグ';
  }

  @override
  String get leagueMyStay => '残留圏 — 来週も同じリーグ';

  @override
  String leagueMyDemote(String league) {
    return '▼ 降格圏 — 来週 $leagueリーグ';
  }

  @override
  String get leagueMyIfEnds => '今終わった場合の報酬';

  @override
  String boardBossPct(int n) {
    return 'ボス $n%';
  }

  @override
  String get boardAbyssHint => '同じ階なら次の階のボスに与えた最大ダメージ（ボス%）が大きい方が上';

  @override
  String rankProgressAbyss(String tier, int floor) {
    return '$tier・深淵 $floor階';
  }

  @override
  String duelLaunchBonus(int pct) {
    return 'ナイス投げ！この試合の攻撃 +$pct%';
  }

  @override
  String eventWaveHeader(int n) {
    return 'ウェーブ $n';
  }

  @override
  String get eventStopHp => '体力が尽きてここで終了です。';

  @override
  String get eventDevPreview => '開発者体験 — サーバー記録・報酬・参加券・ケガなし';

  @override
  String get eventDevTry => '大会体験(開発者)';

  @override
  String get eventEntryLabel => '出場する虫';

  @override
  String get eventEntryEmpty => '下から一番育てた虫を選んで舞台に上げよう';

  @override
  String get eventBuffNow => '今受けている強化';

  @override
  String get eventBuffNone => '強化なし';

  @override
  String eventBuffRevive(int n) {
    return '復活 $n';
  }

  @override
  String eventFallRetry(int pct) {
    return '体力 -$pct% · 同じウェーブに再挑戦';
  }

  @override
  String get eventReviveRetry => '復活！同じウェーブに再挑戦';

  @override
  String get cardAgile => '身軽さ';

  @override
  String get cardAgileDesc => '回避 +8%p — ぶつかりダメージを丸ごと避ける確率';

  @override
  String get cardVital => '急所狙い';

  @override
  String get cardVitalDesc => 'クリティカル確率 +10%p';

  @override
  String get cardBreath => '息を整える';

  @override
  String get cardBreathDesc => 'ウェーブ突破ごとに体力を10%多く回復';

  @override
  String get cardHeft => '重みを乗せる';

  @override
  String get cardHeftDesc => '体格 +40% — 重くなって場外に押し出されにくい';

  @override
  String get cardBerserk => '狂暴化';

  @override
  String get cardBerserkDesc => '攻撃力 +35% · 代わりに防御力 -21%';

  @override
  String get cardIronhide => '鉄甲';

  @override
  String get cardIronhideDesc => '防御力 +40% · 代わりに速度 -16%';

  @override
  String get cardLastStand => '背水の陣';

  @override
  String get cardLastStandDesc => '体力50%未満で入るウェーブで攻撃力 +40%';

  @override
  String get eventBuffEvade => '回避';

  @override
  String get eventBuffCrit => '会心';

  @override
  String get eventBuffRecover => '回復';

  @override
  String get eventBuffSize => '体格';

  @override
  String get eventBuffSpd => '速度';

  @override
  String get eventBuffLastStand => '背水';

  @override
  String get eventQuit => 'ここでやめる';

  @override
  String get eventQuitTitle => 'ここでやめますか？';

  @override
  String eventQuitBody(int n, int hp, int injury) {
    return 'ここまで突破した$nウェーブで記録を確定します。\n今の体力 $hp% — ケガは最大の$injury%だけ休みます。\n(体力が多く残るほど休みが短い)';
  }

  @override
  String get charTabFairy => '妖精';

  @override
  String get fairyCompanion => '同行の妖精';

  @override
  String get fairyNoCompanion => '同行の妖精がいません — 下から選んでください';

  @override
  String fairyBoxTitle(String n, String max) {
    return '妖精 $n/$max';
  }

  @override
  String fairyEggCount(String n) {
    return '卵 $n個';
  }

  @override
  String get fairyEmptyBox => 'まだ妖精がいません。妖精の卵を引いて巣で孵してみましょう！';

  @override
  String get fairyNest => '妖精の巣';

  @override
  String get fairyNestEmpty => '巣が空です — 卵を置いてください';

  @override
  String get fairyNestNoEgg => '置く卵がありません';

  @override
  String get fairyNestPut => '巣に置く';

  @override
  String get fairyNestCollect => '取り出す';

  @override
  String get fairyNestReady => '孵化しました！';

  @override
  String fairyNestLeft(String t) {
    return '残り $t';
  }

  @override
  String fairyNestKindHint(String n) {
    return '種類は$n種からランダムです';
  }

  @override
  String get fairyStone => '属性石';

  @override
  String get fairyStoneNone => '属性石なし';

  @override
  String fairyStoneHint(String p) {
    return '属性石を置くとその付加能力が$p%の確率で出ます';
  }

  @override
  String get fairyAccel => '加速器';

  @override
  String fairyAccelMinutes(String t) {
    return '$t 短縮';
  }

  @override
  String get fairyUse => '使う';

  @override
  String get fairyBuy => '買う';

  @override
  String fairyOwned(String n) {
    return '所持 $n';
  }

  @override
  String get fairyDex => '妖精図鑑';

  @override
  String fairyDexGrades(String n, String max) {
    return '等級 $n/$max';
  }

  @override
  String fairyDexSubs(String n, String max) {
    return '付加能力 $n/$max';
  }

  @override
  String get fairyGacha => '妖精の卵ガチャ';

  @override
  String get fairyGachaOne => '1回';

  @override
  String get fairyGachaTen => '10回';

  @override
  String fairyGachaPity(String n) {
    return '$n回以内に伝説以上確定';
  }

  @override
  String get fairyGachaOdds => '確率表示';

  @override
  String get fairyGachaOddsNote =>
      'ガチャは卵の等級だけを決めます。種類・付加能力・個体値は孵化時に決まります。神話は合成でのみ入手できます。';

  @override
  String fairyGachaGot(String n) {
    return '卵を$n個入手';
  }

  @override
  String get fairyDust => '妖精の粉';

  @override
  String fairyLevel(String n) {
    return 'Lv.$n';
  }

  @override
  String get fairyLevelUp => 'レベルアップ';

  @override
  String get fairyMaxLevel => '最大レベル';

  @override
  String fairyQuality(String p) {
    return '品質 $p%';
  }

  @override
  String get fairyStatMain => '基本';

  @override
  String get fairyStatSub => '付加';

  @override
  String get fairySkill => 'スキル';

  @override
  String fairyCooldown(String s) {
    return 'クール$s秒';
  }

  @override
  String get fairyGoCompanion => '同行させる';

  @override
  String get fairyIsCompanion => '同行中';

  @override
  String get fairyMerge => '合成';

  @override
  String fairyMergeEpicNote(String n) {
    return '英雄 → 伝説の合成には$n体必要です。';
  }

  @override
  String fairyReroll(String left, String max) {
    return '再抽選 $left/$max';
  }

  @override
  String get fairyRerollTitle => '妖精の再抽選';

  @override
  String get fairyRerollConfirm =>
      'サブ能力と数値を引き直します。\n結果が気に入らなければ\n今の値をそのまま残せます。\n\n1日に使える回数に上限があります。';

  @override
  String get fairyRerollPick => 'どちらにしますか？';

  @override
  String get fairyRerollNow => '現在';

  @override
  String get fairyRerollNew => '新しい結果';

  @override
  String get fairyRerollKeep => '今の値を残す';

  @override
  String get fairyRerollTake => '新しい値にする';

  @override
  String get fairyRerollCap => '今日の再抽選はすべて使いました。明日また使えます。';

  @override
  String get fairyRerollNetwork => 'サーバー接続が必要です。少し待ってから再試行してください。';

  @override
  String fairyMergeHint(String n) {
    return '同じ種類・等級$n体 → 同じ種類の1段階上1体。基本・付加能力は新しい等級で改めて決まります。';
  }

  @override
  String fairyMergePick(String n, String max) {
    return '素材 $n/$max';
  }

  @override
  String get fairyMergeNoMat => '同じ種類・等級の妖精が足りません';

  @override
  String get fairyAutoMerge => '自動合成';

  @override
  String fairyAutoMergeConfirm(String used, String made) {
    return '$used体を合わせて$made体になります。同行中・レベルを上げた妖精は除外し、品質の低い妖精から使います。結果の能力は新しく決まります。';
  }

  @override
  String get fairyAutoMergeNone => '自動合成できる妖精がいません';

  @override
  String get fairyRelease => '分解';

  @override
  String fairyReleaseConfirm(String n) {
    return '分解すると妖精の粉を$n個得ます。元に戻せません。';
  }

  @override
  String get fairyNew => '新しい妖精！';

  @override
  String get fairyErrJelly => 'ゼリーが足りません';

  @override
  String get fairyErrDust => '妖精の粉が足りません';

  @override
  String get fairyErrGeneric => '今はできません';

  @override
  String get fairyGradeCommon => 'ノーマル';

  @override
  String get fairyGradeRare => 'レア';

  @override
  String get fairyGradeEpic => 'エピック';

  @override
  String get fairyGradeLegendary => 'レジェンド';

  @override
  String get fairyGradeMythic => 'ミシック';

  @override
  String get fairyStatAttack => '攻撃力';

  @override
  String get fairyStatHp => '体力';

  @override
  String get fairyStatDefense => '被ダメージ軽減';

  @override
  String get fairyStatAttackSpeed => '攻撃速度';

  @override
  String get fairyStatCritDamage => 'クリティカルダメージ';

  @override
  String get fairyStatBossDamage => 'ボスダメージ';

  @override
  String get fairyStatPetShare => '昆虫ダメージ';

  @override
  String fairySkillBurst(String s) {
    return '$s秒分のダメージを一気に';
  }

  @override
  String fairySkillHeal(String p) {
    return '体力60%未満で最大体力の$p%回復';
  }

  @override
  String fairySkillGuard(String d, String p) {
    return '$d秒間 被ダメージ−$p%';
  }

  @override
  String fairySkillHaste(String d, String p) {
    return '$d秒間 攻撃速度+$p%';
  }

  @override
  String fairySkillCrits(String s) {
    return '$s秒間 すべての攻撃がクリティカル';
  }

  @override
  String fairySkillBossBurst(String s) {
    return 'ボスに$s秒分のダメージ';
  }

  @override
  String fairySkillPet(String d, String p) {
    return '$d秒間 昆虫ダメージ+$p%';
  }

  @override
  String fairySkillStand(String p) {
    return '倒れる時に一度耐え、体力$p%で立ち上がる';
  }

  @override
  String fairyEggPop(String grade) {
    return '妖精の卵・$grade';
  }

  @override
  String get guildTitle => 'ギルド';

  @override
  String get guildIntro =>
      'ギルドに入るとギルドメンバーとチャットできます。ギルドミッション・ボス・ギルド戦もまもなく登場します。';

  @override
  String get guildUnavailable => 'ギルド情報を読み込めませんでした。しばらくしてからもう一度お試しください。';

  @override
  String get guildRetry => '再試行';

  @override
  String get guildSearchHint => 'ギルド名で検索';

  @override
  String get guildEmptyList => '条件に合うギルドがありません。自分で作ってみましょう！';

  @override
  String get guildCreate => 'ギルドを作る';

  @override
  String guildNameHint(int min, int max) {
    return 'ギルド名（$min〜$max文字）';
  }

  @override
  String get guildJoinModeOpen => '公開 — 誰でもすぐ加入';

  @override
  String get guildJoinModeApproval => '承認制 — マスター・サブマスターが承認';

  @override
  String get guildJoinModeOpenShort => '公開';

  @override
  String get guildJoinModeApprovalShort => '承認制';

  @override
  String get guildJoin => '加入';

  @override
  String get guildRequest => '加入申請';

  @override
  String get guildCancelRequest => '申請取消';

  @override
  String get guildFull => '満員';

  @override
  String guildMembersCount(int n, int max) {
    return 'メンバー $n/$max';
  }

  @override
  String guildAvgPower(String v) {
    return '平均戦闘力 $v';
  }

  @override
  String guildCooldown(String time) {
    return '$time後に他のギルドに加入できます';
  }

  @override
  String get guildTabMembers => 'メンバー';

  @override
  String get guildTabChat => 'チャット';

  @override
  String guildTabRequests(int n) {
    return '申請 $n';
  }

  @override
  String get guildRoleLeader => 'マスター';

  @override
  String get guildRoleDeputy => 'サブマスター';

  @override
  String get guildRoleMember => 'メンバー';

  @override
  String get guildLastSeenNow => '最近ログイン';

  @override
  String guildLastSeenHours(int n) {
    return '$n時間前';
  }

  @override
  String guildLastSeenDays(int n) {
    return '$n日前';
  }

  @override
  String get guildNoticeEmpty => 'ギルド紹介がありません';

  @override
  String get guildNoticeHint => 'ギルドを紹介してください';

  @override
  String get guildEditNotice => '紹介を編集';

  @override
  String get guildChangeJoinMode => '加入方式';

  @override
  String get guildSave => '保存';

  @override
  String get guildLeave => 'ギルド脱退';

  @override
  String guildLeaveConfirm(int hours) {
    return '脱退すると$hours時間は他のギルドに加入できません。脱退しますか？';
  }

  @override
  String get guildLeaveLastConfirm => '最後のメンバーなので、脱退するとギルドが解散します。脱退しますか？';

  @override
  String get guildLeaderLeaveNote => 'マスターはサブマスター（いなければ貢献度の高いメンバー）に引き継がれます。';

  @override
  String get guildKick => '追放';

  @override
  String guildKickConfirm(String name) {
    return '$nameさんをギルドから追放しますか？';
  }

  @override
  String get guildMakeDeputy => 'サブマスターに任命';

  @override
  String get guildRemoveDeputy => 'サブマスター解除';

  @override
  String get guildTransfer => 'マスター委任';

  @override
  String guildTransferConfirm(String name) {
    return '$nameさんにマスターを譲りますか？';
  }

  @override
  String get guildAccept => '承認';

  @override
  String get guildReject => '拒否';

  @override
  String get guildNoRequests => '加入申請はありません';

  @override
  String get guildCreated => 'ギルドを作りました！';

  @override
  String get guildJoined => 'ギルドに加入しました！';

  @override
  String get guildRequestSent => '加入申請を送りました';

  @override
  String get guildChatEmpty => 'まだギルドの会話がありません。あいさつしてみましょう！';

  @override
  String get guildErrNameTaken => 'すでに使われている名前です';

  @override
  String get guildErrNameInvalid => '使えない名前です（文字数・文字・禁止語を確認）';

  @override
  String get guildErrCooldown => 'まだ他のギルドに加入できません';

  @override
  String get guildErrFull => 'ギルドの人数がいっぱいです';

  @override
  String get guildErrTooManyRequests => '申請中のギルドが多すぎます。1つ取り消してください';

  @override
  String get guildErrRequestsFull => 'このギルドは申請が混み合っています。しばらくしてから申請してください';

  @override
  String get guildErrDeputyFull => 'サブマスターの枠がいっぱいです';

  @override
  String get guildErrNoticeInvalid => '使えない紹介文です';

  @override
  String get guildErrGeneric => '処理できませんでした。しばらくしてからもう一度お試しください';

  @override
  String guildCreateWithCost(int cost) {
    return 'ギルドを作る · ゼリー $cost';
  }

  @override
  String guildCreateNeedJelly(int cost) {
    return 'ギルドを作るにはゼリーが$cost個必要です';
  }

  @override
  String get guildErrJelly => 'ゼリーが足りません';

  @override
  String get guildTabMissions => 'ミッション';

  @override
  String get guildMissionForest => '森の探索';

  @override
  String get guildMissionCave => '洞窟の調査';

  @override
  String get guildMissionSwamp => '沼地の捜索';

  @override
  String get guildMissionRuins => '遺跡の発掘';

  @override
  String get guildMissionCanyon => '峡谷の偵察';

  @override
  String get guildMissionMeadow => '草原の採集';

  @override
  String get guildMissionErrNoStarts => '今日の出発回数を使い切りました';

  @override
  String get guildMissionErrRunning => 'すでに進行中のミッションがあります';

  @override
  String get guildMissionErrClosed => 'すでに終わったミッションです';

  @override
  String get guildMissionErrHelped => 'すでに手伝ったミッションです';

  @override
  String get guildMissionErrHelpersFull => '手伝える枠が埋まっています';

  @override
  String get guildMissionErrOwn => '自分のミッションは手伝えません';

  @override
  String get guildMissionErrNothing => '受け取れる報酬がありません';

  @override
  String get guildMissionHelped => '手伝いました！戦闘力が加わりました';

  @override
  String get guildMissionSoloHint => 'ひとりでも十分です — 出発するとすぐ成功します。';

  @override
  String get guildMissionWaitHint =>
      '待つ時間を選んでください。その間にメンバーが手伝うと戦闘力が加わり、時間切れのときに合計が必要戦闘力を超えれば成功です。手伝いが3人そろうとその場で成功！長く待つほど報酬が増えます。';

  @override
  String guildMissionWaitOption(int min, String mult) {
    return '$min分待機 · 報酬 ×$mult';
  }

  @override
  String get guildMissionClaimTitle => 'ミッション報酬';

  @override
  String guildMissionCoins(int n) {
    return 'ギルドコイン +$n';
  }

  @override
  String guildMissionEgg(int n) {
    return '妖精の卵 $n個！';
  }

  @override
  String guildMissionStartsLeft(int n, int max) {
    return '出発 $n/$max';
  }

  @override
  String guildMissionHelpLeft(int n, int max) {
    return '手伝い報酬 $n/$max';
  }

  @override
  String guildMissionReset(String time) {
    return '$time後にリセット';
  }

  @override
  String guildMissionClaimable(int n) {
    return '受け取れる報酬 $n件';
  }

  @override
  String get guildMissionClaim => '報酬を受け取る';

  @override
  String get guildMissionActive => '手伝い依頼';

  @override
  String get guildMissionNoActive => '進行中のミッションはありません';

  @override
  String get guildMissionBoard => '今日の掲示板';

  @override
  String get guildMissionRecent => '今日の結果';

  @override
  String get guildMissionMine => '自分のミッション';

  @override
  String guildMissionOwner(String name) {
    return '$nameさんのミッション';
  }

  @override
  String guildMissionProgress(int p, int n, int max) {
    return '$p% · 手伝い $n/$max人';
  }

  @override
  String get guildMissionHelp => '手伝う';

  @override
  String get guildMissionHelpedTag => '手伝い済み';

  @override
  String guildMissionSlotSolo(double mult) {
    return '必要戦闘力 ×$mult · ひとりで可';
  }

  @override
  String guildMissionSlotNeed(double mult) {
    return '必要戦闘力 ×$mult · 手伝いが必要';
  }

  @override
  String get guildMissionStart => '出発';

  @override
  String get guildMissionSuccess => '成功';

  @override
  String guildMissionPartial(int p) {
    return '達成 $p%';
  }

  @override
  String get guildMissionChatMine => 'ギルドに手伝いを依頼しました';

  @override
  String guildMissionChatAsk(String name) {
    return '$nameさんがミッションの手伝いを求めています！';
  }

  @override
  String guildLevel(int n) {
    return 'ギルド Lv $n';
  }

  @override
  String guildCoins(int n) {
    return 'コイン $n';
  }

  @override
  String get guildDonate => '出席';

  @override
  String get guildDonateDoneShort => '出席済み';

  @override
  String get guildDonateOk => '出席しました！コインとギルド経験値を受け取りました';

  @override
  String get guildDonateDone => '今日はすでに出席しました';

  @override
  String get guildSkills => 'スキル';

  @override
  String get guildShop => 'ショップ';

  @override
  String get guildSkillAttack => '攻撃力';

  @override
  String get guildSkillHp => '体力';

  @override
  String get guildSkillGold => 'ゴールド獲得';

  @override
  String get guildSkillMaterial => '素材発見';

  @override
  String get guildSkillXp => '経験値';

  @override
  String get guildSkillMission => 'ミッション報酬';

  @override
  String guildSkillHeader(int n) {
    return '残りスキルポイント $n';
  }

  @override
  String get guildSkillNote =>
      'メンバー全員の狩り中に適用されます（オフラインのゴールドも含む）。決闘・大会には適用されず、ギルドを抜けると消えます。ギルドレベル +1 = ポイント 1。';

  @override
  String guildSkillValue(String now, String max) {
    return '+$now%（最大 +$max%）';
  }

  @override
  String get guildSkillNoPoints => 'スキルポイントが残っていません';

  @override
  String get guildSkillMax => 'すでに最大段階です';

  @override
  String get guildSkillForbidden => 'マスター・サブマスターのみ操作できます';

  @override
  String get guildSkillReset => 'リセット';

  @override
  String get guildSkillResetBody => 'ギルドスキルをすべてリセットしてポイントを戻しますか？';

  @override
  String get guildShopNote => 'コインはミッション・手伝い・出席・ギルドボスで貯まります。';

  @override
  String guildShopMaterials(String h) {
    return '素材セット（狩り$h時間分）';
  }

  @override
  String guildShopFossil(int n) {
    return '化石のかけら $n個';
  }

  @override
  String guildShopFairyDust(int n) {
    return '妖精の粉 $n';
  }

  @override
  String guildShopFairyEgg(int n) {
    return '妖精の卵 $n個';
  }

  @override
  String guildShopSkillShard(String grade, int n) {
    return '$grade万能のかけら $n個';
  }

  @override
  String guildShopLimitDay(int n, int max) {
    return '今日 $n/$max';
  }

  @override
  String guildShopLimitWeek(int n, int max) {
    return '今週 $n/$max';
  }

  @override
  String guildShopBought(String item) {
    return '購入しました：$item';
  }

  @override
  String get guildShopSoldOut => '購入上限に達しました';

  @override
  String get guildShopSoldOutShort => '売り切れ';

  @override
  String get guildShopNoCoins => 'コインが足りません';

  @override
  String get guildTabBoss => 'ボス';

  @override
  String guildBossTitle(int n) {
    return 'ギルドボス · $n段階';
  }

  @override
  String guildBossAttack(int n) {
    return '攻撃する（今日あと$n回）';
  }

  @override
  String get guildBossNote =>
      'ダメージは決闘の防衛チームの戦闘力で決まります（妖精・スキル・装備は含まれません）。体力はギルド全体で共有し、1週間引き継がれます。';

  @override
  String get guildBossNoTeam => 'ボスを攻撃するには決闘の防衛チームを登録してください。';

  @override
  String get guildBossNoAttacks => '今日の攻撃回数を使い切りました';

  @override
  String guildBossHit(String d) {
    return 'ダメージ $d';
  }

  @override
  String get guildBossKilled => 'ボス撃破！次の段階へ';

  @override
  String guildBossMine(String d) {
    return '今週の自分のダメージ $d';
  }

  @override
  String guildBossRank(int n) {
    return '今週のギルド順位 $n位';
  }

  @override
  String get guildBossRankNone => 'まだ圏外です — 攻撃すると順位に載ります';

  @override
  String guildBossTopRow(int s, int p) {
    return '$s段階 · $p%';
  }

  @override
  String guildBossLastWeek(int rank, int jelly) {
    return '先週 $rank位 — ゼリー $jelly個';
  }

  @override
  String guildBossClaimed(int n) {
    return 'ゼリーを$n個受け取りました！';
  }

  @override
  String get guildTabWar => 'ギルド戦';

  @override
  String get guildWarBreed => '育成';

  @override
  String get guildWarForge => '鍛冶';

  @override
  String get guildWarHunt => '狩り';

  @override
  String get guildWarDuel => '決闘';

  @override
  String get guildWarTrain => '修練';

  @override
  String get guildWarBoss => 'ギルドボス';

  @override
  String get guildWarClash => '戦闘力対決';

  @override
  String get guildWarBreedHint =>
      '交配の受け取り・孵化の受け取り・合成でポイントを獲得。ゼリーで即完了したものはカウントされません。';

  @override
  String get guildWarForgeHint => '鍛冶でポイント — 高い等級ほど大きく増えます。';

  @override
  String get guildWarHuntHint => 'エリートと狩場のボスを倒すとポイント。';

  @override
  String get guildWarDuelHint => '決闘に勝つとポイント（サーバーが確定した勝利のみ）。';

  @override
  String get guildWarTrainHint => '昆虫の修練・訓練所の段階・スキル修練でポイント。';

  @override
  String get guildWarBossHint => 'ギルドボスを攻撃するとポイント。';

  @override
  String get guildWarClashHint =>
      '今日はやることがありません！決闘の防衛チームの戦闘力順に1対1の対決が自動で行われ、このタブを開くと結果が出ます。';

  @override
  String guildWarTier(String tier, int gr) {
    return '$tierティア · ランクポイント $gr';
  }

  @override
  String get guildWarClosed => 'ギルド戦はまだ始まっていません。';

  @override
  String guildWarOpensOn(String date) {
    return 'ギルド戦は$dateの週から始まります。';
  }

  @override
  String guildWarNeedMembers(int n) {
    return '今週のギルド戦に出るにはメンバーが$n人以上必要です。';
  }

  @override
  String guildWarVs(String name) {
    return 'vs $name';
  }

  @override
  String get guildWarVsVirtual => 'vs 野生ギルド（同じティアの平均）';

  @override
  String get guildWarVirtualName => '野生';

  @override
  String guildWarDayOf(int d, String theme) {
    return '$d日目 · $theme';
  }

  @override
  String guildWarMyToday(int n, int cap) {
    return '今日の自分のポイント $n/$cap';
  }

  @override
  String get guildWarWin => '勝利';

  @override
  String get guildWarLose => '敗北';

  @override
  String get guildWarDraw => '引き分け';

  @override
  String guildWarPoints(int a, int b) {
    return '勝ち点 $a : $b';
  }

  @override
  String guildWarClashResult(int a, int b) {
    return '7日目の対決 $a : $b';
  }

  @override
  String guildWarReward(String result, int coins, int jelly) {
    return '$result報酬 — コイン $coins · ゼリー $jelly';
  }

  @override
  String guildWarClaimed(int coins, int jelly) {
    return 'コイン $coins · ゼリー $jelly個を受け取りました！';
  }

  @override
  String duelPickDeployed(int n) {
    return '出撃中 · $n番';
  }

  @override
  String get fairyDexHelp =>
      '妖精図鑑は、これまでに手に入れた妖精を記録します。妖精8種それぞれに2つの項目があります。\n• 等級の点 — その妖精をその等級で初めて手に入れると、その色の点が灯ります。\n• 属性石 — その妖精をその追加能力値で初めて手に入れると、その属性石が明るくなります。\n巣で卵を孵化させるか、合成で新しい妖精を手に入れると記録され、分解しても記録は残ります。マスを集めるほど下の報酬（妖精の粉・加速器・化石）がもらえます。能力値は上がりません。';

  @override
  String get fairyDexLegendGrades => '等級の点（点灯 = その等級で入手済み）';

  @override
  String get fairyDexLegendSubs => '属性石（明るい = その追加能力値で入手済み）';

  @override
  String fairyDexRewards(int n, int max) {
    return '図鑑報酬 · $n/$maxマス';
  }

  @override
  String get fairyDexClaimed => '図鑑報酬を受け取りました！';

  @override
  String get fairyNestPickEgg => '入れる卵を先に選んでください';

  @override
  String get guideTitle => '攻略ガイド';

  @override
  String get guideIntro => '同じ種でも虫ごとに能力が違います。気になる項目をタップして用語の意味を確認しましょう。';

  @override
  String get guideElementTitle => '五行の相性（木・火・土・金・水）';

  @override
  String guideElementBody(String mult) {
    return '虫にはそれぞれ五行属性が一つあります。決闘で相剋の相手にぶつかるとダメージが$mult倍になります。赤い矢印が勝つ向きです。';
  }

  @override
  String guideElementLine(String a, String b) {
    return '$aは$bに強い';
  }

  @override
  String get guideSpecialtyTitle => '特技（戦い方）';

  @override
  String get guideSpecialtyBody => '種ごとに決まった特技が決闘での戦い方を決めます。';

  @override
  String get guideSpecialtyStrike => '突進して体当たりし、相手をひっくり返します。';

  @override
  String get guideSpecialtyGrip => 'かみついて離さず、相手を押し出します。';

  @override
  String get guideSpecialtyToss => '相手を持ち上げて投げ飛ばします。';

  @override
  String get guideTemperamentTitle => '気質（戦いの傾向）';

  @override
  String get guideTemperamentBody => '気質は決闘での動き方の傾向で、訓練所でどの能力値を高く伸ばせるかも決めます。';

  @override
  String get guideTempAggressive => '突進が多い攻撃型です。';

  @override
  String get guideTempCautious => '端を避け、相手の突進を横にかわします。';

  @override
  String get guideTempCunning => '横に回り込んで弱点を狙います。';

  @override
  String get guideTempSteadfast => '押されにくい耐久型です。';

  @override
  String get guideTempFickle => 'いろいろな戦法を混ぜて使います。';

  @override
  String guideTrainCapMods(String mods) {
    return '訓練上限：$mods';
  }

  @override
  String get guideSizeTitle => 'サイズ（重さ）';

  @override
  String guideSizeBody(String min, String max) {
    return 'サイズは種ごとの範囲内で決まります。大きいほど能力値が×$min〜×$maxに上がり、決闘で押されにくく場外に落ちにくくなります。';
  }

  @override
  String get guidePotentialTitle => 'ポテンシャル（1〜5つ星）';

  @override
  String guidePotentialBody(int perStar, int fodder) {
    return '星が多いほど部位強化の最大レベル（星×10）と訓練の最大段階（星1つにつき+$perStar）が上がります。同じ種$fodder匹を合成すると星が1つ上がります。';
  }

  @override
  String get guideTraitTitle => '血統特性（交配のみ）';

  @override
  String get guideTraitBody =>
      '交配で生まれた虫だけが持てます。野生の虫にはありません。ペット装着時と決闘の両方で効果があります。';

  @override
  String guideTraitEffect(String atk, String hp) {
    return '攻撃 +$atk・体力 +$hp';
  }

  @override
  String get guideBreedTitle => '交配と遺伝';

  @override
  String guideBreedBody(String el, String tm, String tr) {
    return '同じ種のオス・メスの成虫を交配させると卵が手に入ります。子は親の五行（$el）と気質（$tm）を高い確率で、親の特性（$tr）を受け継ぎます。両親の五行・気質・特性が同じなら子も必ず同じになるので、好みの系統を代々つないでいけます。';
  }

  @override
  String get guideVariantTitle => '色違い個体';

  @override
  String guideVariantBody(
    String wild,
    String breed,
    String parent,
    String gacha,
    String pet,
    String duel,
  ) {
    return 'ごくまれに色の違う虫（レインボー・アルビノ）が出ます。確率は野生 $wild・交配 $breed・親が色違いなら $parent・卵ガチャ $gacha。ペット装着で能力値 +$pet、決闘では +$duelです。';
  }

  @override
  String get guideLifeTitle => '成長段階';

  @override
  String get guideLifeBody =>
      '卵 → 幼虫 → さなぎ → 成虫の順に育ちます。卵は孵化器に入れると幼虫になり、幼虫からは時間が経つと自然に成虫になります。修練・交配・決闘は成虫だけができます。';

  @override
  String get guideDuelTitle => '決闘';

  @override
  String guideDuelBody(int sec, String weak) {
    return '1戦は円形の闘技場で行う$sec秒の1対1の取っ組み合いです。場外・ひっくり返し・気絶で勝ち、時間切れなら残り体力%で判定します。1試合は3匹の勝ち抜き戦です。横・後ろにぶつかるとダメージ×$weak、クリティカルと回避もあります。';
  }

  @override
  String get guideTrainTitle => '訓練所';

  @override
  String guideTrainBody(int base) {
    return '虫ごとに決闘の能力値5種（攻撃・防御・回避・会心・回復力）を訓練します。最大段階 = 基本$base + ポテンシャル + 気質・特技・特性の補正なので、虫ごとに伸ばしやすい能力値が違います。役割の違う虫を混ぜてチームを組みましょう！';
  }

  @override
  String bugInfoSizeDetail(String mm, String min, String max, String mult) {
    return '${mm}mm（範囲 $min〜$max）・能力値 ×$mult';
  }

  @override
  String get eventHudShort => '王虫\n選抜大会';

  @override
  String fairyStoneName(String stat) {
    return '$statの属性石';
  }

  @override
  String fairyStoneEffect(String stat, String p) {
    return '孵化した妖精のサブ能力が$p%の確率で「$stat」になります';
  }

  @override
  String get fairyStoneBuyTitle => '属性石の購入';

  @override
  String get fairyStoneBuyAction => '購入';

  @override
  String get fairyEquippedTag => '装着中';

  @override
  String get fairyMergeEquipped => '装着中の妖精は合成できません';

  @override
  String get fairyAutoMergeDone => '合成結果';

  @override
  String get exchangeToDust => '妖精の粉へ';

  @override
  String get exchangeHintDust => 'ゼリーを妖精の粉に交換します（ゼリー1 = 粉1）';

  @override
  String exchangeGetDust(String amount) {
    return '妖精の粉 $amount を受け取る';
  }

  @override
  String fairyStatRange(String grade, String lo, String hi) {
    return '（$gradeの範囲 $lo〜$hi）';
  }

  @override
  String get fairyStopCompanion => '同行解除';

  @override
  String get fairyHelpTitle => 'ヘルプ';

  @override
  String get fairyHelpGradeHead => '等級別の基本能力範囲（Lv.1）';

  @override
  String fairyHelpGradeLine(String grade, String lo, String hi, String max) {
    return '$grade：$lo 〜 $hi・最大Lv.$max';
  }

  @override
  String fairyHelpLevel(String p) {
    return 'レベルが1上がるごとに能力値がLv.1の値の$pずつ増えます。';
  }

  @override
  String get fairyHelpSubHead => 'サブ能力（妖精ごとに1つ）';

  @override
  String fairyHelpSub(String p) {
    return '孵化時に下のうち1つが付きます。大きさは基本範囲の$p×能力ごとの比重です。属性石を入れると狙ったサブ能力が出やすくなります。';
  }

  @override
  String fairyHelpSubLine(String stat, String grade, String lo, String hi) {
    return '$stat：$grade $lo 〜 $hi';
  }

  @override
  String get fairyHelpMergeHead => '合成';

  @override
  String fairyHelpMerge(String n) {
    return '同じ種類・等級$n匹 → 1つ上の等級1匹。基本・サブ能力は新しく決まるので、合成のたびにより良い妖精を狙えます。';
  }

  @override
  String fairyGachaOverflowWarn(String free, String lost) {
    return '妖精ボックスの空きが$free枠なので、卵$lost個は妖精の粉になります。';
  }

  @override
  String fairyOverflowToast(String n, String dust) {
    return 'ボックスが満杯で卵$n個が妖精の粉$dustになりました';
  }

  @override
  String fairyOverflowPop(String dust) {
    return 'ボックス満杯・妖精の粉 +$dust';
  }

  @override
  String fairyMergeInvestedConfirm(String n, String dust) {
    return 'レベルを上げた妖精$n匹が素材になります。使った粉のうち$dustが戻ります。合成しますか？';
  }

  @override
  String fairyMergeRefund(String dust) {
    return '妖精の粉$dustが戻りました';
  }

  @override
  String exchangeDustLeft(String n) {
    return '本日あと$n';
  }

  @override
  String get exchangeDustCapReached => '本日の交換上限です';

  @override
  String get bugLock => 'ロック';

  @override
  String get bugLocked => 'ロック中';

  @override
  String get bugUnlock => 'ロック解除';

  @override
  String get bugLockedToast => 'ロックしました — 合成・分解の素材に使いません';

  @override
  String get bugUnlockedToast => 'ロックを解除しました';

  @override
  String get disassembleLocked => 'ロック中の虫は分解できません。先にロックを解除してください。';

  @override
  String trainingSumShort(int n) {
    return '訓練 Lv.$n';
  }

  @override
  String get reviewAskTitle => 'バグチャンプ、楽しんでいますか？';

  @override
  String get reviewAskBody =>
      '少しお時間があれば、ストアにレビューをいただけると一人で作っているゲームの大きな励みになります。\n遊んでくれてありがとう！';

  @override
  String get reviewAskLater => 'あとで';

  @override
  String get trainingNoneShort => '未訓練';

  @override
  String get guildComingSoonTitle => '準備中です';

  @override
  String get guildComingSoonBody =>
      'ギルドミッション・ギルドボス・ギルドショップ・週間ギルド戦が次のアップデートで開きます。もう少しお待ちください！';

  @override
  String get notifChannelName => '報酬のお知らせ';

  @override
  String get notifChannelDesc => '昼・夜の報酬、オフライン報酬が満タンになったときのお知らせ';

  @override
  String get eggOddsTitle => '虫の卵ガチャ確率';

  @override
  String get eggOddsGradeHead => '等級（同じ等級の種はすべて同じ確率）';

  @override
  String get eggOddsPotentialHead => 'ポテンシャル';

  @override
  String eggOddsVariant(String p) {
    return '色違い（レインボー・アルビノ）：$p%';
  }

  @override
  String eggOddsPity(String n, String grade) {
    return '$n回目は$grade以上確定';
  }

  @override
  String get eggOddsNote => '確率は1回あたりです。天井の回数はその等級が出たときだけリセットされます。';

  @override
  String eggOddsGradeLine(String grade, String p, String each) {
    return '$grade $p%・種ごとに $each%';
  }

  @override
  String get variantRainbow => 'レインボー';

  @override
  String get variantAlbino => 'アルビノ';

  @override
  String get jellyShortTitle => 'ゼリーが足りません';

  @override
  String get jellyShortBody => 'ショップでゼリーを購入すると、すぐに続けられます。';

  @override
  String get jellyShortGoShop => 'ショップへ';

  @override
  String pvpRefillLimit(int n) {
    return 'ゼリーでの補充は1日$n回までです';
  }

  @override
  String get pvpTicketRefillTitle => 'チケット補充';

  @override
  String pvpTicketRefillBody(int n, int left) {
    return 'ゼリーでチケット$n枚を受け取ります。（本日あと$left回）';
  }

  @override
  String get starterOfferTitle => 'スターターパッケージ';

  @override
  String get starterOfferBody =>
      'ゼリー300・ゴールド・素材・孵化器1枠。\n1アカウント1回だけ、ショップで一番お得なセットです！';

  @override
  String get starterOfferGo => '見に行く';

  @override
  String mailGrantTitle(String name) {
    return '[運営からの付与] $name';
  }

  @override
  String get mailGrantBody => '運営からの報酬です。受け取るをタップしてください。';

  @override
  String get mailReplyTitle => '[運営からの返信]';
}
