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
    return '💎$n 即時回復';
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
    return '最高ランク: $name';
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
  String get synergyHint => '虫を2匹以上配置・前のスロットが後ろを生じるとシナジー（順番が重要）';

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
      '現在は端末の仮アカウントのため、アプリを削除するとバックアップも失われます。まもなくGoogleログインに対応予定です。';

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
  String get chatTitle => '全体チャット';

  @override
  String get chatPlaceholder => '全体チャット — タップで開く';

  @override
  String get characterTitle => 'マイキャラクター';

  @override
  String get statCombatPower => '戦闘力';

  @override
  String get statCrit => 'クリティカル';

  @override
  String get statMaxHp => '最大体力';

  @override
  String get statDefense => '防御力';

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
  String get giftClaimAd => '広告×2';

  @override
  String giftExpiresIn(String time) {
    return '$time 後に期限切れ';
  }

  @override
  String get giftClaimedSnack => 'ギフトを受け取りました！';

  @override
  String get giftDoubledSnack => '広告報酬2倍を獲得！';

  @override
  String get giftAdMoreTitle => '広告を見てもう1回？';

  @override
  String get giftAdMoreBody => '広告を見ると同じ報酬をもう1回受け取れます';

  @override
  String get giftAdMoreYes => '広告を見て受け取る';

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
  String evolveNext(String next, String time) {
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
    return '💎$n';
  }

  @override
  String trainJellySnack(int lv) {
    return '💎 即時修練！レベル +$lv';
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
    return '即時 💎$n';
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
    return 'スロット拡張 💎$n';
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
  String get accountSignInApple => 'Appleでサインイン';

  @override
  String get termsOfUse => '利用規約';

  @override
  String get privacyPolicy => 'プライバシーポリシー';
}
