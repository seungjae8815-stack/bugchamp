// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => '곤충 키우기';

  @override
  String get navHome => '홈';

  @override
  String get navCollect => '채집';

  @override
  String get navStorage => '채집함';

  @override
  String get navBattle => '전투';

  @override
  String get battleTitle => '곤충 결투';

  @override
  String battleTrophies(int n) {
    return '트로피 $n';
  }

  @override
  String get battleMyTeam => '내 팀 (3)';

  @override
  String get autoBattleRunning => '자동 전투 진행 중';

  @override
  String get battleStart => '전투 시작';

  @override
  String get battleNeedBugs => '성충 곤충이 있어야 결투할 수 있어요';

  @override
  String get battlePickTitle => '곤충 선택 (성충)';

  @override
  String get battleEmptySlot => '빈 슬롯';

  @override
  String get battleWin => '승리!';

  @override
  String get battleLose => '패배…';

  @override
  String get battleDraw => '무승부';

  @override
  String get battleReward => '보상';

  @override
  String get battleVs => 'VS';

  @override
  String get battleRestrain => '상극!';

  @override
  String get battleFoe => '상대';

  @override
  String get battleLog => '전투 로그';

  @override
  String get battleAgain => '다시 도전';

  @override
  String get battleTeamEmpty => '팀에 곤충을 넣어주세요';

  @override
  String get battleSkip => '건너뛰기';

  @override
  String battleHpPct(String v) {
    return '체력 $v%';
  }

  @override
  String get battleAuto => '자동 전투';

  @override
  String get battleManual => '수동 전투';

  @override
  String get battleManualDesc => '심리전 · 매 수를 직접 선택';

  @override
  String get battleYourMove => '수를 고르세요';

  @override
  String get battleEnergy => '기력';

  @override
  String get battleClashWin => '기선제압!';

  @override
  String get battleClashLose => '허를 찔렸다';

  @override
  String get battleClashEven => '팽팽한 탐색';

  @override
  String get injuryTitle => '회복 중';

  @override
  String get injuryDesc => '회복 전까지 결투에 편성할 수 없어요';

  @override
  String injuryHealJelly(int n) {
    return '젤리 $n로 즉시회복';
  }

  @override
  String get notEnoughJelly => '곤충젤리가 부족해요';

  @override
  String get scoutBoard => '스카우트 보드';

  @override
  String get scoutRefresh => '새로고침';

  @override
  String get scoutRefreshFree => '새로고침 (무료)';

  @override
  String scoutRefreshJelly(int n) {
    return '새로고침 (젤리 $n)';
  }

  @override
  String get scoutRefreshDone => '오늘 새로고침 끝';

  @override
  String get scoutEasy => '약함';

  @override
  String get scoutEven => '대등';

  @override
  String get scoutHard => '강함';

  @override
  String get leagueBronze => '브론즈';

  @override
  String get leagueSilver => '실버';

  @override
  String get leagueGold => '골드';

  @override
  String get leaguePlatinum => '플래티넘';

  @override
  String get leagueDiamond => '다이아';

  @override
  String leagueToNext(int n, String name) {
    return '$name까지 $n🏆';
  }

  @override
  String get leagueMaxRank => '최고 등급';

  @override
  String get leagueClaimReward => '승급 보상 수령';

  @override
  String get leaguePromoTitle => '승급 보상';

  @override
  String get seasonEndTitle => '시즌 종료!';

  @override
  String seasonPeak(String name) {
    return '종료 시 등급: $name';
  }

  @override
  String seasonTrophyReset(int from, int to) {
    return '트로피 $from → $to';
  }

  @override
  String seasonEndsIn(String time) {
    return '시즌 $time 남음';
  }

  @override
  String get synergyLabel => '상생';

  @override
  String get synergyHint =>
      '곤충 2마리 이상 배치 · 앞 곤충이 뒤 곤충의 기운을 북돋우면 팀이 강해져요 (순서 중요)';

  @override
  String get teamReorderHint => '끌어서 순서 변경';

  @override
  String get leagueSeasonTitle => '리그 · 시즌';

  @override
  String get modeManual => '직접 던지기';

  @override
  String get modeAuto => '빠른 결투';

  @override
  String get opponentWild => '야생';

  @override
  String get opponentPick => '상대 고르기';

  @override
  String get accountTitle => '계정';

  @override
  String get accountAnonymous => '지금은 기기 임시 계정이에요';

  @override
  String accountSignedIn(String email) {
    return '$email 로 로그인됨';
  }

  @override
  String get accountSignIn => '구글로 로그인';

  @override
  String get accountDelete => '계정 삭제';

  @override
  String get accountDeleteTitle => '정말 계정을 삭제할까요?';

  @override
  String accountDeleteBody(String word) {
    return '곤충·재화·트로피·짝짓기 기록이 모두 사라지고 되돌릴 수 없어요.\n\n확인을 위해 아래에 «$word» 라고 입력해 주세요.';
  }

  @override
  String get accountDeleteWord => '삭제';

  @override
  String get accountDeleteConfirm => '영구 삭제';

  @override
  String get accountDeleteDone => '계정과 데이터를 삭제했어요';

  @override
  String get accountDeleteFailed => '삭제하지 못했어요. 잠시 후 다시 시도해 주세요';

  @override
  String get accountDeleteOffline => '온라인 연결이 없어 삭제할 수 없어요';

  @override
  String get accountDeleteWarnPurchase => '구매하신 상품은 환불되지 않으며, 복원할 수 없게 됩니다.';

  @override
  String get accountSignOut => '로그아웃';

  @override
  String get accountSignedOut => '로그아웃했어요';

  @override
  String get accountSignInFailed => '로그인하지 못했어요';

  @override
  String get accountWhy => '로그인하면 폰을 바꿔도 진행 상황을 이어서 할 수 있어요.';

  @override
  String get accountUnavailable => '지금 빌드에서는 로그인을 쓸 수 없어요';

  @override
  String get accountAnonRisk => '로그인하지 않으면 기기를 바꾸거나 앱을 지웠을 때 진행 상황을 되살릴 수 없어요.';

  @override
  String get loginNudge => '게스트 계정 · 눌러서 로그인하고 데이터를 지키세요';

  @override
  String get accountSyncTitle => '어느 진행 상황을 쓸까요?';

  @override
  String get accountSyncBody => '이 계정에 저장된 진행 상황이 있어요. 어느 쪽을 쓸지 골라주세요.';

  @override
  String get accountKeepDevice => '지금 기기 것';

  @override
  String get accountUseCloud => '저장된 것 불러오기';

  @override
  String get cloudTitle => '클라우드 백업';

  @override
  String get cloudBackup => '백업하기';

  @override
  String get cloudRestore => '복원하기';

  @override
  String get cloudBackupDone => '클라우드에 백업했어요';

  @override
  String get cloudRestoreDone => '백업에서 복원했어요';

  @override
  String get cloudRestoreConfirm => '지금 진행 상황을 백업 내용으로 덮어씁니다. 되돌릴 수 없어요.';

  @override
  String get cloudFailed => '실패했어요. 잠시 후 다시 시도해주세요';

  @override
  String get cloudNoBackup => '아직 백업이 없어요';

  @override
  String cloudLastBackup(String when) {
    return '마지막 백업: $when';
  }

  @override
  String get cloudUnavailable => '온라인 연결이 없어 백업을 쓸 수 없어요';

  @override
  String get cloudAnonWarning =>
      '지금은 기기 임시 계정이라, 앱을 삭제하면 백업도 함께 사라져요. 로그인하면 다른 기기에서도 이어서 할 수 있어요.';

  @override
  String get tabCraft => '제작';

  @override
  String get tabStore => '상점';

  @override
  String get adNotReady => '지금은 광고가 준비되지 않았어요. 잠시 후 다시 시도해 주세요';

  @override
  String get adDismissed => '광고를 끝까지 봐야 보상을 받을 수 있어요';

  @override
  String get adFailed => '광고를 불러오지 못했어요';

  @override
  String get adLoading => '광고 불러오는 중…';

  @override
  String get storeOwned => '보유중';

  @override
  String get storeRestore => '구매 복원';

  @override
  String get storeRestoreDone => '구매 내역을 복원했어요';

  @override
  String storeBought(String name) {
    return '$name 구매 완료!';
  }

  @override
  String get storeFailed => '구매하지 못했어요';

  @override
  String get storeCanceled => '구매를 취소했어요';

  @override
  String get storePending =>
      '결제를 확인하고 있어요. 확인되면 자동으로 지급돼요. 몇 분 뒤에도 안 들어오면 상점에서 \'구매 복원\'을 눌러 주세요';

  @override
  String get storeUnavailable => '이 기기에서는 결제를 쓸 수 없어요';

  @override
  String get storeNotRegistered => '아직 판매 준비 중인 상품이에요';

  @override
  String get storeDevMode => '개발 모드 — 실제 결제가 아니라 바로 지급됩니다';

  @override
  String storePassLeft(int days) {
    return '$days일 남음';
  }

  @override
  String get biomeForest => '숲';

  @override
  String get biomeVolcano => '용암굴';

  @override
  String get biomeBadlands => '황무지';

  @override
  String get biomeCity => '폐허도시';

  @override
  String get biomeDeep => '심해';

  @override
  String locationAffinity(String element) {
    return '$element 곤충 강화';
  }

  @override
  String get breedingTitle => '짝짓기';

  @override
  String breedingSlotsLabel(int used, int cap) {
    return '$used/$cap';
  }

  @override
  String get breedingNew => '새 짝짓기';

  @override
  String get breedingPickMother => '엄마 곤충 고르기 (♀ 어른)';

  @override
  String get breedingPickFather => '아빠 곤충 고르기 (♂ · 같은 종류)';

  @override
  String get breedingNoFemales => '짝짓기할 엄마(♀ 어른) 곤충이 없어요';

  @override
  String get breedingNoMate => '같은 종류의 아빠(♂ 어른) 곤충이 없어요';

  @override
  String get breedingInProgress => '알 낳는 중';

  @override
  String breedCooldownLeft(Object time) {
    return '$time 후 가능';
  }

  @override
  String get breedingGotEgg => '알이 나왔어요! 부화기에 넣어 키우세요';

  @override
  String get leaderboardLocalNote => '로컬 랭킹 · 온라인 연동 준비 중';

  @override
  String get leaderboardOnlineNote => '온라인 랭킹 · 실시간 반영';

  @override
  String get backendOnline => '온라인';

  @override
  String get backendLocal => '로컬';

  @override
  String get backendServer => '서버연결';

  @override
  String settingsBuildLabel(String label) {
    return '빌드 $label';
  }

  @override
  String get rankKindTrophies => '트로피';

  @override
  String get leaderboardUnranked => '순위권 밖';

  @override
  String get rankKindLevel => '레벨';

  @override
  String get rankKindStage => '진행도';

  @override
  String leaderboardMyRank(int n) {
    return '내 순위 #$n';
  }

  @override
  String get stanceAttack => '공격';

  @override
  String get stanceDefend => '방어';

  @override
  String get stanceHeal => '회복';

  @override
  String get elementFire => '화';

  @override
  String get elementWater => '수';

  @override
  String get elementWood => '목';

  @override
  String get elementMetal => '금';

  @override
  String get elementEarth => '토';

  @override
  String get homeTitle => '트랩 현황';

  @override
  String get homeMaterialsTitle => '재료';

  @override
  String slotLabel(int index) {
    return '슬롯 $index';
  }

  @override
  String get slotEmpty => '비어 있음';

  @override
  String get slotInstallCta => '트랩 설치하기';

  @override
  String elapsedLabel(String duration) {
    return '경과 $duration / 최대 8시간';
  }

  @override
  String get collectButton => '수령';

  @override
  String collectResultSnack(int materialCount, int bugCount) {
    return '재료 $materialCount개, 곤충 $bugCount마리 획득!';
  }

  @override
  String get collectNothingSnack => '아직 수령할 게 없어요';

  @override
  String get homeYard => '내 채집터';

  @override
  String get collecting => '채집 중';

  @override
  String get readyLabel => '수령 대기';

  @override
  String get collectAll => '모두 받기';

  @override
  String get comingSoon => '준비 중이에요';

  @override
  String offlineBanner(int materialCount, int bugCount) {
    return '돌아왔어요! 재료 $materialCount · 곤충 $bugCount 대기 중';
  }

  @override
  String chapterTitle(int n) {
    return '$n장';
  }

  @override
  String chapterRemaining(int count) {
    return '다음 챕터까지 곤충 $count마리';
  }

  @override
  String get statusForaging => '채집 중…';

  @override
  String get statusIdle => '트랩을 설치하면 채집을 시작해요';

  @override
  String get navUpgrade => '강화';

  @override
  String get navShop => '상점';

  @override
  String get upgradeTitle => '능력치 강화';

  @override
  String get retreat => '후퇴!';

  @override
  String offlineReward(String gold, String xp) {
    return '돌아왔어요! 💰$gold · 🔷$xp 획득';
  }

  @override
  String get offlineTitle => '돌아왔어요!';

  @override
  String offlineBugsBlocked(int count) {
    return '채집함이 가득 차서\n알 $count개를 받지 못했어요';
  }

  @override
  String get fairyRerollPending => '재굴림 결과 고르기';

  @override
  String offlineBugs(int count) {
    return '🥚 곤충 알 $count개를 채집했어요';
  }

  @override
  String offlineElapsed(String time) {
    return '$time 동안 모은 방치 보상이에요';
  }

  @override
  String get offlineGoldLabel => '골드';

  @override
  String get offlineXpLabel => '경험치';

  @override
  String durationHm(int h, int m) {
    return '$h시간 $m분';
  }

  @override
  String durationH(int h) {
    return '$h시간';
  }

  @override
  String durationM(int m) {
    return '$m분';
  }

  @override
  String durationS(int s) {
    return '$s초';
  }

  @override
  String get upAttack => '채집력';

  @override
  String get upAttackSpeed => '손놀림';

  @override
  String get upCrit => '급소 노리기';

  @override
  String get upCritDamage => '강타';

  @override
  String get upBossDamage => '투지';

  @override
  String get upMaxHp => '근성';

  @override
  String get upDefense => '맷집';

  @override
  String get upRegen => '회복력';

  @override
  String get upReward => '판매 수완';

  @override
  String get upXp => '채집 지식';

  @override
  String get upBugFind => '곤충 감각';

  @override
  String get upMaterialFind => '꼼꼼한 손질';

  @override
  String get upMoveSpeed => '발걸음';

  @override
  String get upBoost => '집중력';

  @override
  String get upBugBuff => '도감 통달';

  @override
  String get statAttack => '공격력';

  @override
  String get statAttackSpeed => '공격속도';

  @override
  String get statReward => '골드 보너스';

  @override
  String get notEnoughGold => '골드가 부족해요';

  @override
  String get curGold => '골드';

  @override
  String get rewardGained => '획득 보상';

  @override
  String get bossLabel => '보스';

  @override
  String zoneLabel(int n) {
    return '사냥터 $n';
  }

  @override
  String get zoneFinalLabel => '최종 사냥터';

  @override
  String get bossChallenge => '보스 도전';

  @override
  String bossChallengeLocked(int n) {
    return '보스 도전까지 $n마리';
  }

  @override
  String get bossChallengeFailed => '보스에게 밀려났어요. 더 강해져서 다시 도전하세요';

  @override
  String get bossFlee => '도망치기';

  @override
  String get bossFleeTitle => '도망칠까요?';

  @override
  String get bossFleeDesc => '사냥터 게이지가 비워져요.\n쓰러졌을 때와 같아요.';

  @override
  String get bossFled => '도망쳤어요 · 게이지가 비워졌어요';

  @override
  String zoneKillsLabel(int n, int m) {
    return '처치 $n/$m';
  }

  @override
  String get tapBoostHint => '화면을 탭해 부스트!';

  @override
  String levelBadge(int n) {
    return 'Lv $n';
  }

  @override
  String get collectTitle => '채집 필드';

  @override
  String get collectPickTrap => '트랩 선택';

  @override
  String get collectPickSlot => '슬롯 선택';

  @override
  String collectInstalledSnack(String trap, String field) {
    return '$field에 $trap 설치 완료';
  }

  @override
  String get locked => '잠김';

  @override
  String get install => '설치';

  @override
  String get storageTitle => '채집함';

  @override
  String get storageEmpty => '아직 수집한 곤충이 없어요.\n채집으로 모아보세요!';

  @override
  String storageCount(int count) {
    return '$count마리';
  }

  @override
  String storageCapacityCount(int used, int cap) {
    return '$used/$cap';
  }

  @override
  String storageCapacityLabel(int used, int cap) {
    return '채집함 $used / $cap칸';
  }

  @override
  String get storageFullBanner => '채집함이 가득 찼어요\n곤충이 들어오지 않아요';

  @override
  String get storageFullSnack => '채집함이 가득 찼어요. 분해하거나 확장해 주세요.';

  @override
  String storageExpand(int n, int jelly) {
    return '+$n칸 · 젤리 $jelly';
  }

  @override
  String get dexTitle => '곤충 도감';

  @override
  String get dexDiscovered => '발견';

  @override
  String get dexConquered => '정복';

  @override
  String get dexVariant => '이색';

  @override
  String get dexComplete => '이 종은 완료했어요';

  @override
  String get dexCompleteShort => '수집완료';

  @override
  String get dexConqueredYes => '완료';

  @override
  String get dexConqueredNo => '아직';

  @override
  String dexConquerNeed(int need, int now) {
    return '$need레벨 필요 (지금 $now)';
  }

  @override
  String get dexMaxSize => '최대 크기';

  @override
  String get dexMaxPotential => '최고 포텐셜';

  @override
  String get dexNotFound => '아직 만나지 못한 곤충이에요. 채집으로 찾아보세요!';

  @override
  String dexClaim(Object n) {
    return '도감 보상 $n개 받기';
  }

  @override
  String dexClaimedSnack(Object gold, Object jelly) {
    return '도감 보상 획득! 골드 $gold · 젤리 $jelly';
  }

  @override
  String get dexTabBugs => '곤충';

  @override
  String get dexTabBosses => '보스';

  @override
  String get dexBosses => '보스 수집';

  @override
  String get dexBossNotFound => '아직 잡지 못한 보스예요. 이 난이도의 사냥터에서 보스를 쓰러뜨리면 기록돼요.';

  @override
  String get dexBossHint => '난이도마다 따로 모아요. 아래 난이도로 내려가 잡아도 기록돼요.';

  @override
  String dexClaimedFossil(Object fossil) {
    return '화석 $fossil개도 받았어요';
  }

  @override
  String dexBonusSummary(String atk, String hp, String gold) {
    return '지금 도감 보너스 — 공격 +$atk% · 체력 +$hp% · 골드 +$gold%';
  }

  @override
  String get speciesPassiveTitle => '종 고유 능력';

  @override
  String get speciesPassiveHint =>
      '이 곤충을 애완펫으로 장착하면 붙어요. 같은 종을 여러 마리 장착하면 합쳐져요.';

  @override
  String get storageFilterLabel => '받을 등급';

  @override
  String get storageFilterAll => '전부';

  @override
  String storageFilterSnack(Object grade) {
    return '$grade 미만은 자동으로 놓아주고 재료로 바꿔요';
  }

  @override
  String get autoSynthTitle => '자동 합성';

  @override
  String autoSynthHint(Object n) {
    return '같은 종이 $n마리 모이면 자동으로 합성해 포텐셜을 올려요. 장착 중·부화 중인 곤충은 쓰지 않아요.';
  }

  @override
  String get autoSynthNone => '합성할 수 있는 곤충이 없어요';

  @override
  String autoSynthPreview(Object count, Object used) {
    return '$count개체 합성됩니다 ($used마리 사용)';
  }

  @override
  String autoSynthDone(Object count, Object used) {
    return '$count개체 합성했어요 ($used마리 사용)';
  }

  @override
  String get autoSynthRun => '자동 합성';

  @override
  String get eventIntroTitle => '왕충 선발대회란?';

  @override
  String get eventIntroStart => '시작하기';

  @override
  String get eventHelp => '대회 설명 다시 보기';

  @override
  String eventCardTitle(Object n) {
    return '$n웨이브 돌파!\n하나를 고르세요';
  }

  @override
  String get eventCardHint => '고른 강화는 이번 판이 끝날 때까지 남아요';

  @override
  String get cardHeal_s => '응급 처치';

  @override
  String get cardHeal_sDesc => '체력을 30% 회복해요';

  @override
  String get cardHeal_l => '완전 회복';

  @override
  String get cardHeal_lDesc => '체력을 70% 회복해요';

  @override
  String get cardAtk_s => '예리한 턱';

  @override
  String get cardAtk_sDesc => '공격력 +12%';

  @override
  String get cardAtk_l => '맹공';

  @override
  String get cardAtk_lDesc => '공격력 +28%';

  @override
  String get cardDef_s => '단단한 표피';

  @override
  String get cardDef_sDesc => '방어력 +18%';

  @override
  String get cardHp_s => '강인한 체격';

  @override
  String get cardHp_sDesc => '최대 체력 +15%';

  @override
  String get cardRevive => '생명의 이슬';

  @override
  String get cardReviveDesc => '체력이 바닥나도 한 번, 체력 50%로 일어나 같은 웨이브를 다시 싸워요';

  @override
  String get cardSkip => '우회로';

  @override
  String get cardSkipDesc => '다음 웨이브를 싸우지 않고 통과해요';

  @override
  String eventFlyerPeriod(String start, String end) {
    return '$start ~ $end';
  }

  @override
  String get eventPeriodLabel => '대회 기간';

  @override
  String get eventFlyerHeadline => '가장 멀리 간 곤충 조련사를 찾습니다';

  @override
  String get eventFlyerPrize => '1등에게 진짜 곤충을 보내드려요';

  @override
  String get eventFlyerPrizeNote => '국내 배송 · 판매처에서 직접 발송';

  @override
  String get eventFlyerHow => '참가 방법';

  @override
  String get eventFlyerHow1 => '가장 잘 키운 성충 1마리를 골라 출전';

  @override
  String get eventFlyerHow2 => '웨이브를 깰 때마다 강화 카드 1장 선택';

  @override
  String get eventFlyerHow3 => '더 멀리 간 사람이 순위 위로';

  @override
  String get eventFlyerRules => '꼭 알아두세요';

  @override
  String get eventFlyerRule1 =>
      '**키운 그대로** 싸워요 — 포텐셜·부위 강화·수련·훈련소가 모두 반영돼요(결투와 같은 능력치)';

  @override
  String get eventFlyerRule2 => '적의 오행은 웨이브마다 바뀌어요 — 내 곤충이 약한 색의 웨이브에서 고비가 와요';

  @override
  String get eventFlyerRule3 => '출전하면 곤충이 다쳐서 회복실에서 쉬어야 해요 — 젤리로 바로 회복할 수 있어요';

  @override
  String eventFlyerRule4(int daily, int jelly, int extra) {
    return '참가권은 매일 아침 $daily장씩 채워지고, 젤리 $jelly개로 하루 $extra장까지 더 충전할 수 있어요';
  }

  @override
  String get eventFlyerLogin => '순위에 오르려면 로그인이 필요해요 (게스트는 참여만 가능)';

  @override
  String get eventTitle => '왕충 선발대회';

  @override
  String eventBanner(Object n) {
    return '왕충 선발대회 진행 중 · 참가권 $n장';
  }

  @override
  String get eventClosed => '지금은 열린 대회가 없어요';

  @override
  String get battleNeedServer => '결투는 온라인 연결이 필요해요';

  @override
  String get eventQuitFailed => '그만두지 못했어요 — 연결을 확인하고 다시 눌러 주세요';

  @override
  String get eventBugUnavailable => '고른 곤충으로는 도전할 수 없어요 — 다른 곤충을 골라 주세요';

  @override
  String get injuryHealConfirmTitle => '즉시 회복';

  @override
  String injuryHealConfirm(int n) {
    return '젤리 $n개를 써서 지금 회복할까요?';
  }

  @override
  String get trainingInstantTitle => '훈련 즉시 완료';

  @override
  String get squadTrainingBadge => '훈련 중';

  @override
  String get eventNeedServer => '대회는 온라인 연결이 필요해요';

  @override
  String eventTickets(int n, int max) {
    return '참가권 $n/$max';
  }

  @override
  String get eventBestRecord => '내 최고 기록';

  @override
  String get eventNoRecord => '아직 도전하지 않았어요';

  @override
  String eventWaveRecord(String n) {
    return '$n웨이브';
  }

  @override
  String eventScore(Object n) {
    return '$n점';
  }

  @override
  String eventMyRank(Object n) {
    return '내 순위 #$n';
  }

  @override
  String get eventPickTeam => '출전 곤충 1마리를 고르세요';

  @override
  String get eventPickOrder => '적을 한 마리씩 연속으로 상대해요 · 판마다 던지기 게이지 · 체력이 목숨이에요';

  @override
  String get eventNormalizeTitle => '키운 만큼 강해요';

  @override
  String eventNormalizeBody(int pct) {
    return '결투와 같은 능력치로 싸워요 — 포텐셜·부위 강화·수련·훈련소·특성이 모두 반영돼요. 장외·뒤집기로 지면 체력이 $pct% 깎이고 같은 웨이브를 다시 싸워요. 체력이 바닥나면 끝이에요.';
  }

  @override
  String eventFatigueLeft(Object time) {
    return '$time 후 출전 가능';
  }

  @override
  String eventRestHours(Object h) {
    return '⏳$h시간';
  }

  @override
  String eventRestMinutes(Object m) {
    return '⏳$m분';
  }

  @override
  String get eventChallenge => '도전 (참가권 1장)';

  @override
  String get eventNoTicket => '참가권이 없어요';

  @override
  String get eventAdTicket => '무료 참가권 받기';

  @override
  String get eventJellyTicket => '참가권 충전';

  @override
  String get eventNoJelly => '젤리가 부족해요';

  @override
  String get eventAdLimit => '오늘 무료 보상을 모두 받았어요';

  @override
  String get eventTicketFull => '참가권이 가득 찼어요';

  @override
  String eventResultTitle(Object n) {
    return '$n웨이브 도달!';
  }

  @override
  String get eventLeadStrong => '유리';

  @override
  String get eventLeadWeak => '불리';

  @override
  String eventTicketBought(int n) {
    return '참가권 $n장을 충전했어요';
  }

  @override
  String eventTicketDaily(int used, int max) {
    return '오늘 $used/$max';
  }

  @override
  String get eventStopWipe => '팀이 전멸해서 여기서 끝났어요.';

  @override
  String get eventStopJudge =>
      '20라운드가 지나 체력 비율 판정에서 밀렸어요. 곤충이 남아 있어도 여기서 끝납니다.';

  @override
  String get eventStopMax => '마지막 웨이브까지 모두 클리어했어요!';

  @override
  String get eventNewBest => '최고 기록 갱신!';

  @override
  String eventKeptBest(Object n) {
    return '최고 기록은 $n웨이브예요';
  }

  @override
  String eventWaveCleared(Object n) {
    return '$n웨이브 돌파!';
  }

  @override
  String get eventFastForward => '빨리감기';

  @override
  String get eventNextWave => '다음 적 속성';

  @override
  String get eventLead => '선봉';

  @override
  String get eventSetLead => '선봉으로';

  @override
  String get eventLeadHint => '곤충을 눌러 다음 선봉을 정해요';

  @override
  String get eventRanking => '순위';

  @override
  String get eventRankEmpty => '아직 순위가 없어요';

  @override
  String get eventAnonWarn => '게스트 계정은 순위에 오르지 않아요. 로그인하면 참여할 수 있어요.';

  @override
  String get eventKoreaOnly =>
      '실물 경품은 국내 거주자에게만 배송돼요. 순위와 게임 내 보상은 누구나 참여할 수 있어요.';

  @override
  String get eventRules => '대회 규칙';

  @override
  String get storageFilterButton => '필터';

  @override
  String get storageFilterTitle => '받을 등급 고르기';

  @override
  String get autoReleaseTitle => '자동 분해';

  @override
  String get autoReleaseHint =>
      '고른 조건에 맞는 곤충을 한 번에 분해해 재료로 바꿔요. 장착 중·부화 중·키운 곤충(수련·돌파·강화)은 건드리지 않아요.';

  @override
  String get autoReleaseNone => '조건에 맞는 곤충이 없어요';

  @override
  String autoReleaseDone(Object count, Object mats) {
    return '$count마리를 분해해 재료 $mats개를 얻었어요';
  }

  @override
  String autoReleasePreview(Object count, Object mats) {
    return '$count마리를 분해해 재료 $mats개를 얻게 됩니다';
  }

  @override
  String get autoReleaseRun => '분해하기';

  @override
  String get autoFilterGrades => '대상 등급';

  @override
  String autoFilterPotential(Object n) {
    return '포텐셜 $n★ 이하만';
  }

  @override
  String get autoFilterEmpty => '등급을 하나 이상 골라주세요';

  @override
  String get autoPreviewTitle => '이번에 사라지는 곤충';

  @override
  String autoPreviewMore(Object n) {
    return '외 $n마리';
  }

  @override
  String autoPreviewLine(String name, int count) {
    return '$name $count마리';
  }

  @override
  String get storageExpandMaxed => '최대 확장';

  @override
  String get storageExpandedSnack => '채집함이 늘었어요!';

  @override
  String bugSize(String mm) {
    return '${mm}mm';
  }

  @override
  String bugPotential(int stars) {
    return '$stars★';
  }

  @override
  String get gradeCommon => '일반';

  @override
  String get gradeUncommon => '고급';

  @override
  String get gradeRare => '희귀';

  @override
  String get gradeEpic => '영웅';

  @override
  String get gradeLegendary => '전설';

  @override
  String get specialtyStrike => '치기';

  @override
  String get specialtyGrip => '집기';

  @override
  String get specialtyToss => '던지기';

  @override
  String get temperamentAggressive => '호전적';

  @override
  String get temperamentCautious => '신중';

  @override
  String get temperamentCunning => '교활';

  @override
  String get temperamentSteadfast => '우직';

  @override
  String get temperamentFickle => '변덕';

  @override
  String get traitFierce => '맹렬';

  @override
  String get traitSturdy => '강인';

  @override
  String get traitVital => '강건';

  @override
  String get traitNoble => '고귀';

  @override
  String get traitTitle => '혈통 특성';

  @override
  String get traitHint => '짝짓기로 태어난 곤충만 가질 수 있어요. 부모가 같은 특성이면 반드시 물려받아요.';

  @override
  String get breedInheritTitle => '물려받는 것';

  @override
  String get breedInheritHint =>
      '부모의 오행·기질·혈통 특성을 물려받아요. 같은 값을 가진 부모끼리 붙이면 확실해져요.';

  @override
  String get sexMale => '수컷';

  @override
  String get sexFemale => '암컷';

  @override
  String get materialChitin => '키틴조각';

  @override
  String get materialMineral => '미네랄';

  @override
  String get materialSap => '수액결정';

  @override
  String get materialJelly => '곤충젤리';

  @override
  String get combatPowerLabel => '전투력';

  @override
  String get chatTitle => '전체 채팅';

  @override
  String get chatPlaceholder => '전체 채팅 — 탭하면 열려요';

  @override
  String get characterTitle => '내 캐릭터';

  @override
  String get statCombatPower => '전투력';

  @override
  String get statCrit => '치명타';

  @override
  String get statMaxHp => '최대 체력';

  @override
  String get statDefense => '방어';

  @override
  String get rankingTitle => '랭킹';

  @override
  String get roadmapTitle => '로드맵';

  @override
  String roadmapStageRange(int start, int end) {
    return 'STAGE $start–$end';
  }

  @override
  String roadmapProgress(int cur, int total) {
    return '$cur / $total';
  }

  @override
  String get roadmapCleared => '클리어';

  @override
  String get roadmapCurrent => '진행 중';

  @override
  String get roadmapLocked => '잠김';

  @override
  String get roadmapFinalBoss => '최종 보스';

  @override
  String get roadmapEnter => '이어하기';

  @override
  String get roadmapReplay => '재도전';

  @override
  String get chapterClearTitle => '챕터 클리어! 🎉';

  @override
  String chapterClearMsg(String difficulty, String boss) {
    return '$difficulty 정복! 최종보스 $boss 격파!';
  }

  @override
  String get chapterClearReward => '클리어 보상';

  @override
  String get mailTitle => '편지함';

  @override
  String get mailEmpty => '새 편지가 없어요';

  @override
  String get mailDailyTitle => '일일 보상 (하루 2회)';

  @override
  String get dailyLunch => '점심 보상';

  @override
  String get dailyDinner => '저녁 보상';

  @override
  String get dailyClaim => '받기';

  @override
  String get dailyClaimedToday => '오늘 받음';

  @override
  String dailyLockedUntil(int hour) {
    return '$hour시부터';
  }

  @override
  String get dailyRewardSnack => '일일보상을 받았어요!';

  @override
  String get giftSectionTitle => '깜짝 선물 (3시간 내 수령)';

  @override
  String get giftClaim => '받기';

  @override
  String get giftClaimAd => '2배 받기';

  @override
  String giftExpiresIn(String time) {
    return '$time 후 만료';
  }

  @override
  String get giftClaimedSnack => '선물을 받았어요!';

  @override
  String get giftDoubledSnack => '보상 2배 획득!';

  @override
  String giftDoubledMult(String n) {
    return '보상 $n배 획득!';
  }

  @override
  String get giftAdMoreTitle => '오늘의 무료 2배!';

  @override
  String get giftAdMoreBody => '이 선물을 2배로 받을 수 있어요.';

  @override
  String get giftAdMoreYes => '2배로 받기';

  @override
  String get giftAdMoreLater => '그냥 받기';

  @override
  String get notifLunchTitle => '점심 보상이 도착했어요 🍱';

  @override
  String get notifDinnerTitle => '저녁 보상이 도착했어요 🌙';

  @override
  String get notifRewardBody => '지금 접속해서 받아가세요!';

  @override
  String get notifOfflineTitle => '방치 보상이 가득 찼어요 🐛';

  @override
  String get notifOfflineBody => '8시간치가 모두 모였어요. 접속해서 받으세요!';

  @override
  String get giftNone => '아직 도착한 선물이 없어요. 플레이하다 보면 도착해요!';

  @override
  String get settingsTitle => '설정';

  @override
  String get settingsSound => '사운드';

  @override
  String get settingsBgm => '배경음';

  @override
  String get settingsSfx => '효과음';

  @override
  String get settingsNickname => '닉네임';

  @override
  String get settingsNicknameHint => '이름을 입력하세요';

  @override
  String get actionSave => '저장';

  @override
  String get actionCancel => '취소';

  @override
  String get actionNext => '다음';

  @override
  String get actionClose => '닫기';

  @override
  String get exitTitle => '게임 종료';

  @override
  String get exitConfirm => '게임을 종료할까요?';

  @override
  String get exitAction => '종료';

  @override
  String get settingsReset => '게임 데이터 초기화';

  @override
  String get settingsResetConfirm => '모든 진행(곤충·재화·강화·스테이지)이 삭제됩니다. 정말 초기화할까요?';

  @override
  String get settingsResetDone => '초기화되었어요';

  @override
  String get questHunt => '몬스터 사냥';

  @override
  String get buffTitle => '버프';

  @override
  String get buffSheetTitle => '버프 활성화';

  @override
  String get buffWatchAd => '무료로 켜기';

  @override
  String buffMinutes(int minutes) {
    return '$minutes분';
  }

  @override
  String buffActivatedSnack(String buff, int minutes) {
    return '$buff 활성! ($minutes분)';
  }

  @override
  String get buffGoldRush => '황금 러시';

  @override
  String get buffGoldRushDesc => '골드 획득 ×2';

  @override
  String get buffXpBoost => '성장 가속';

  @override
  String get buffXpBoostDesc => '경험치 ×2';

  @override
  String get buffFrenzy => '광폭화';

  @override
  String get buffFrenzyDesc => '공격력·공격속도 상승';

  @override
  String get buffGatherer => '채집가의 손길';

  @override
  String get buffGathererDesc => '재료 획득 ×2';

  @override
  String get buffLuckyWind => '행운의 바람';

  @override
  String get buffLuckyWindDesc => '곤충 발견율 ×2';

  @override
  String get enhanceTitle => '부위 강화';

  @override
  String get partHornJaw => '뿔·큰턱';

  @override
  String get partCuticle => '표피';

  @override
  String get partWing => '날개';

  @override
  String get partBuild => '체격';

  @override
  String get enhanceAction => '강화';

  @override
  String get enhanceMaxed => '최대';

  @override
  String enhanceCap(int cur, int max) {
    return '강화 $cur/$max';
  }

  @override
  String enhancePerLevel(String pct) {
    return '+$pct%/Lv';
  }

  @override
  String get equipTitle => '장착 펫';

  @override
  String get equipEmpty => '빈 슬롯';

  @override
  String get equipAction => '장착';

  @override
  String get unequipAction => '해제';

  @override
  String get equipFull => '장착 슬롯이 가득 찼어요';

  @override
  String get equippedBadge => '장착중';

  @override
  String petBonus(String atk, String hp) {
    return '펫 보너스 · 공격 +$atk% · 체력 +$hp%';
  }

  @override
  String get stageEgg => '알';

  @override
  String get stageLarva => '유충';

  @override
  String get stagePupa => '번데기';

  @override
  String get stageAdult => '성충';

  @override
  String get evolveTitle => '진화';

  @override
  String evolveNext(String time, String next) {
    return '$next까지 $time';
  }

  @override
  String get evolveReady => '진화 준비 완료';

  @override
  String get evolveMaxed => '최종 진화 (성충)';

  @override
  String get accelerateAction => '촉진';

  @override
  String get synthTitle => '합성 (★강화)';

  @override
  String get synthConfirm => '아래 곤충이 사라집니다';

  @override
  String get synthConfirmTitle => '합성 확인';

  @override
  String get synthDo => '합성';

  @override
  String synthDesc(int have, int need) {
    return '같은 종 $have/$need마리 · 포텐셜 +1';
  }

  @override
  String get synthMaxed => '최대 포텐셜';

  @override
  String get synthSnack => '합성 완료! 포텐셜 +1';

  @override
  String get petEffectTitle => '장착 효과';

  @override
  String petAtkBonus(String v) {
    return '펫 공격력 +$v%';
  }

  @override
  String petHpBonus(String v) {
    return '펫 체력 +$v%';
  }

  @override
  String get trainTitle => '수련';

  @override
  String get trainLevel => '수련 레벨';

  @override
  String get trainAction => '수련';

  @override
  String get trainMaxed => '최대 레벨';

  @override
  String get trainSnack => '수련 완료! 레벨 +1';

  @override
  String trainJelly(int n) {
    return '젤리 $n';
  }

  @override
  String trainJellySnack(int lv) {
    return '즉시 수련! 레벨 +$lv';
  }

  @override
  String get breakthroughTitle => '돌파';

  @override
  String breakthroughTier(int n) {
    return '티어 $n';
  }

  @override
  String get breakthroughReady => '돌파 가능 · 레벨 상한 ↑';

  @override
  String breakthroughProgress(String time) {
    return '돌파 중 · $time';
  }

  @override
  String get breakthroughDone => '돌파 완료! 수령하세요';

  @override
  String get breakthroughMaxed => '최고 티어 달성';

  @override
  String get breakthroughDo => '돌파';

  @override
  String get breakthroughCollect => '수령';

  @override
  String breakthroughInstant(int n) {
    return '즉시 완료 · 젤리 $n';
  }

  @override
  String get breakthroughStartedSnack => '돌파를 시작했어요!';

  @override
  String get breakthroughDoneSnack => '돌파 완료! 레벨 상한이 올랐어요';

  @override
  String get incubatorTitle => '부화기';

  @override
  String incubatorSlots(int cur, int max) {
    return '슬롯 $cur/$max';
  }

  @override
  String get incubatorPlace => '넣기';

  @override
  String incubatorHatching(String time) {
    return '부화 중 · $time';
  }

  @override
  String get incubatorReady => '부화 완료!';

  @override
  String get incubatorCollect => '수령';

  @override
  String get incubatorFull => '부화기 가득 참';

  @override
  String incubatorExpand(int n) {
    return '슬롯 확장 · 젤리 $n';
  }

  @override
  String get incubatorPlacedSnack => '부화를 시작했어요!';

  @override
  String get incubatorCollectedSnack => '유충으로 부화했어요!';

  @override
  String get incubatorExpandedSnack => '부화기 슬롯이 늘었어요!';

  @override
  String get incubatorEmptySlot => '빈 슬롯';

  @override
  String incubatorWaitingEggs(int n) {
    return '대기 중인 알 $n';
  }

  @override
  String get incubatorNoEggs => '부화할 알이 없어요';

  @override
  String get incubatorHint => '빈 캡슐을 눌러 알을 넣고, 완료되면 눌러 수령하세요';

  @override
  String incubatorCollectAll(int n) {
    return '모두 수령 ($n)';
  }

  @override
  String incubatorCollectAllDone(int n) {
    return '$n마리를 수령했어요';
  }

  @override
  String get incubatorPick => '부화할 알 선택';

  @override
  String get disassembleTitle => '분해';

  @override
  String disassembleDesc(int n) {
    return '젤리 $n개로 환원';
  }

  @override
  String get disassembleConfirm => '이 곤충은 되찾기 어렵습니다. 정말 분해할까요?';

  @override
  String get disassembleAction => '분해';

  @override
  String get incubatingLabel => '부화 중';

  @override
  String get disassembleSnack => '분해 완료';

  @override
  String get disassembleEquipped => '장착 중인 곤충은 분해할 수 없어요';

  @override
  String get disassembleIncubating => '부화 중인 알은 분해할 수 없어요';

  @override
  String get disassembleFailed => '분해할 수 없어요';

  @override
  String get bugDescTitle => '설명';

  @override
  String get onlyAdultTrain => '성충만 수련할 수 있어요';

  @override
  String get craftTitle => '제작';

  @override
  String get craftMake => '제작';

  @override
  String craftPotion(String buff) {
    return '$buff 물약';
  }

  @override
  String get craftAllPotion => '올인원 물약';

  @override
  String craftedSnack(String name) {
    return '$name 제작 완료!';
  }

  @override
  String get missionsTitle => '미션';

  @override
  String get missionKillMonsters => '몬스터 사냥';

  @override
  String get missionKillBosses => '보스 처치';

  @override
  String get missionBuyUpgrades => '능력 강화';

  @override
  String get missionForgeItems => '장비 제련';

  @override
  String get missionReachStage => '스테이지 도달';

  @override
  String get missionClaim => '수집';

  @override
  String get missionComplete => '완료! 탭하여 수집';

  @override
  String get missionClaimedSnack => '미션 보상 획득!';

  @override
  String get upAttackDesc => '한 번의 타격으로 주는 피해량이 늘어납니다.';

  @override
  String get upAttackSpeedDesc => '초당 공격 횟수가 늘어 사냥이 빨라집니다.';

  @override
  String get upCritDesc => '치명타가 터질 확률이 올라갑니다.';

  @override
  String get upCritDamageDesc => '치명타가 터질 때 추가 피해 배수가 커집니다.';

  @override
  String get upBossDamageDesc => '보스에게 주는 피해가 추가로 늘어납니다.';

  @override
  String get upMaxHpDesc => '최대 체력이 늘어 더 오래 버팁니다.';

  @override
  String get upDefenseDesc => '적에게서 받는 피해가 줄어듭니다.';

  @override
  String get upRegenDesc => '매초 최대 체력의 일정 비율을 회복합니다. 맞고 버티는 시간이 길어져요.';

  @override
  String get upRewardDesc => '몬스터 처치 시 얻는 골드가 늘어납니다.';

  @override
  String get upXpDesc => '몬스터 처치 시 얻는 경험치가 늘어납니다.';

  @override
  String get upBugFindDesc => '곤충(개체)을 발견할 확률이 올라갑니다.';

  @override
  String get upMaterialFindDesc => '강화 재료 획득량이 늘어납니다.';

  @override
  String get upMoveSpeedDesc => '다음 사냥터로 이동하는 속도가 빨라집니다.';

  @override
  String get upBoostDesc => '화면을 탭할 때 발동하는 부스트 효과가 강해집니다.';

  @override
  String get upBugBuffDesc => '보유한 곤충 수에 따른 보상 보너스가 커집니다.';

  @override
  String get tagCommonMaterial => '일반 재료';

  @override
  String get tagPremium => '프리미엄 재화';

  @override
  String get materialChitinDesc =>
      '곤충의 단단한 외골격 조각. 고급 능력치 강화의 추가 비용과 부위 강화(뿔·큰턱)에 사용됩니다.';

  @override
  String get materialMineralDesc =>
      '땅에서 캔 단단한 광물. 고급 능력치 강화의 추가 비용과 부위 강화(표피)에 사용됩니다.';

  @override
  String get materialSapDesc =>
      '굳어 결정이 된 나무 수액. 고급 능력치 강화의 추가 비용과 부위 강화(날개)에 사용됩니다.';

  @override
  String get materialJellyDesc => '특별한 프리미엄 재화. 상점 제작(올인원 물약)과 특별 상품에 사용됩니다.';

  @override
  String get materialFossil => '화석 조각';

  @override
  String get materialFossilDesc => '곤충이 굳어 남은 조각. 공방에서 망치질 한 번에 하나씩 쓴다.';

  @override
  String get saveBrokenTitle => '세이브를 열지 못했어요';

  @override
  String get saveBrokenUpdate =>
      '이 계정의 저장 자료가 지금 앱보다 최신이에요.\n앱을 최신 버전으로 업데이트하면 그대로 이어집니다.';

  @override
  String get saveBrokenCorrupt =>
      '저장 자료를 읽을 수 없어요.\n원본은 기기에 안전하게 보관했고, 덮어쓰지 않았어요.';

  @override
  String get saveBrokenKeep =>
      '진행을 지키기 위해 게임을 멈췄어요. 이대로 계속하면 저장 자료가 지워질 수 있어요.';

  @override
  String get saveBrokenSupport => '문의하기';

  @override
  String get eventRewardTitle => '대회 결과가 나왔어요';

  @override
  String eventRewardRank(String round, int rank) {
    return '$round 회차 $rank위';
  }

  @override
  String get eventRewardNone => '이번 회차는 순위권에 들지 못했어요. 참가 보상을 받았어요!';

  @override
  String get eventRewardPhysical =>
      '실물 경품 대상이에요! 아래 신청서를 작성해 주세요. 실물 배송은 국내 주소만 가능하고, 해외에 계시면 게임 내 보상만 지급돼요.';

  @override
  String get eventRewardApply => '경품 신청하기';

  @override
  String get eventRewardClaim => '받기';

  @override
  String badgeChampion(int round) {
    return '$round회차 챔피언';
  }

  @override
  String badgeFinalist(int round) {
    return '$round회차 입상';
  }

  @override
  String get nicknameBadChars => '한글·영문·숫자만 쓸 수 있어요 (이모지·자음/모음 하나는 안 돼요)';

  @override
  String get nicknameSameName => '지금 쓰는 이름과 다른 이름을 지어 주세요.';

  @override
  String get eventRewardsTitle => '순위 보상';

  @override
  String get eventRankOne => '1위';

  @override
  String eventRankRange(int a, int b) {
    return '$a~$b위';
  }

  @override
  String get eventRewardRealBug => '진짜 곤충 (국내 배송)';

  @override
  String eventRewardJelly(int n) {
    return '젤리 $n';
  }

  @override
  String get eventRewardParticipationRow => '참가 (1판 이상)';

  @override
  String buffCooldownAsk(String t, int n) {
    return '무료 켜기는 $t 후에 다시 할 수 있어요.\n젤리 $n개로 바로 켤까요?';
  }

  @override
  String buffBtnFreeLeft(String t) {
    return '무료 $t 남음';
  }

  @override
  String buffBtnJelly(int n) {
    return '$n개로 켜기';
  }

  @override
  String buffBtnPassLeft(int n) {
    return '패스 $n일 남음';
  }

  @override
  String get settingsLanguage => '언어';

  @override
  String get languageSystem => '기기 설정';

  @override
  String eventRewardTitleAward(String name) {
    return '칭호 「$name」';
  }

  @override
  String get stanceCycle => '공 › 회 › 방 › 공';

  @override
  String tierClearTitle(String name) {
    return '$name 난이도를 모두 깼어요!';
  }

  @override
  String tierNextTitle(String name) {
    return '$name 난이도로 진입합니다';
  }

  @override
  String get tierNextBody =>
      '스테이지 · 레벨 · 능력치 강화 · 골드 · 재료가 처음으로 돌아갑니다.\n\n곤충 · 장비 · 도감 · 젤리 · 스킬은 그대로 남아요.\n\n랭킹은 난이도를 먼저 봅니다 — 난이도를 올리면 레벨이 낮아도 위로 올라가요.\n\n몬스터가 훨씬 더 강력해집니다.';

  @override
  String get tierNextGo => '진입하기';

  @override
  String get tierStayHere => '조금 더 있기';

  @override
  String get tierAllClear => '모든 난이도를 정복했어요! 최고의 곤충학자예요.';

  @override
  String get tierEasy => '쉬움';

  @override
  String get tierNormal => '보통';

  @override
  String get tierHard => '어려움';

  @override
  String get tierExtreme => '극한';

  @override
  String get netLostTitle => '연결이 끊겼어요';

  @override
  String get netLostBody => '인터넷 연결을 확인해 주세요.\n연결되어야 진행이 저장됩니다.';

  @override
  String get netRetry => '다시 시도';

  @override
  String get sessionTakenTitle => '다른 기기에서 접속 중이에요';

  @override
  String get sessionTakenBody =>
      '다른 기기에서\n같은 계정으로 접속했어요.\n\n이 기기에서 계속하면\n다른 기기의 진행을 불러와요.';

  @override
  String get sessionTakenContinue => '이 기기에서 계속하기';

  @override
  String get sessionTakenFailed => '불러오지 못했어요. 잠시 뒤 다시 시도해 주세요.';

  @override
  String get netToTitle => '타이틀로';

  @override
  String get netStillDown => '아직 연결되지 않았어요';

  @override
  String get materialsHint => '재료 — 능력치·부위 강화와 제작에 사용해요 (탭하면 상세)';

  @override
  String get chatHint => '메시지를 입력하세요';

  @override
  String get chatSend => '보내기';

  @override
  String get chatEmpty => '아직 대화가 없어요. 먼저 인사해 보세요!';

  @override
  String get chatUnavailable => '지금은 채팅을 쓸 수 없어요';

  @override
  String get chatSendFailed => '메시지를 보내지 못했어요';

  @override
  String chatTooLong(int max) {
    return '메시지가 너무 길어요 ($max자까지)';
  }

  @override
  String get chatBlockedWord => '사용할 수 없는 표현이 있어요';

  @override
  String get chatTooFast => '조금 천천히 보내주세요';

  @override
  String get chatReport => '신고';

  @override
  String get chatBlock => '차단';

  @override
  String get chatUnblock => '차단 해제';

  @override
  String get chatDelete => '삭제';

  @override
  String get chatDeleted => '메시지를 삭제했어요';

  @override
  String get chatDeleteTitle => '이 메시지를 삭제할까요?';

  @override
  String get chatDeleteBody => '내가 쓴 이 메시지를 모두에게서 지웁니다. 되돌릴 수 없어요.';

  @override
  String get chatReported => '신고했어요. 검토 후 조치할게요';

  @override
  String chatBlockedUser(String name) {
    return '$name 님을 차단했어요';
  }

  @override
  String chatUnblockedUser(String name) {
    return '$name 님 차단을 해제했어요';
  }

  @override
  String get chatBlockedMessage => '차단한 사용자의 메시지입니다';

  @override
  String get chatReportTitle => '이 메시지를 신고할까요?';

  @override
  String get chatReportBody =>
      '욕설·광고·사기 등 부적절한 내용을 신고할 수 있어요. 반복 신고된 사용자는 이용이 제한됩니다.';

  @override
  String chatBlockTitle(String name) {
    return '$name 님을 차단할까요?';
  }

  @override
  String get chatBlockBody => '이 사용자의 메시지가 더 이상 보이지 않아요. 설정에서 언제든 해제할 수 있어요.';

  @override
  String get chatRules => '서로 존중하는 대화를 부탁드려요. 욕설·광고·개인정보 공유는 제한됩니다.';

  @override
  String get nicknameBlockedWord => '닉네임에 사용할 수 없는 표현이 있어요';

  @override
  String get nicknameTaken => '이미 사용 중인 닉네임이에요';

  @override
  String get rankPopupTitle => '내 랭킹';

  @override
  String get rankSuffix => '위';

  @override
  String get rankFirstCheck => '첫 랭킹 확인이에요. 화이팅!';

  @override
  String get rankUnchanged => '지난번과 순위가 같아요';

  @override
  String rankChangedFromTo(int from, int to) {
    return '$from위 → $to위';
  }

  @override
  String rankTopStreak(int days) {
    return '1위 유지 $days일째 👑';
  }

  @override
  String get nicknameRequiredTitle => '닉네임을 정해주세요';

  @override
  String get nicknameRequiredBody => '다른 채집가들에게 표시될 이름이에요. 처음 한 번만 정하면 됩니다.';

  @override
  String get renameForcedTitle => '닉네임을 변경해 주세요';

  @override
  String get renameForcedBody =>
      '운영자가 닉네임 변경을 요청했어요.\n다른 이용자에게 표시되는 이름이라 규칙에 맞아야 합니다.\n이번 변경은 무료예요.';

  @override
  String get nicknameChangeTitle => '닉네임 변경';

  @override
  String get nicknameChangeBody => '닉네임을 바꾸려면 곤충젤리가 필요해요. 변경할까요?';

  @override
  String get nicknameChangeConfirm => '변경';

  @override
  String get nicknameFallback => '이용자';

  @override
  String get battleServerFailed => '전투 결과를 확인하지 못했어요. 연결을 확인해 주세요';

  @override
  String get updateRequiredTitle => '업데이트가 필요합니다';

  @override
  String get updateRequiredBody => '원활한 플레이를 위해 최신 버전으로 업데이트해 주세요.';

  @override
  String get updateAvailableTitle => '새 버전이 있어요';

  @override
  String get updateAvailableBody => '더 좋아진 버전이 준비됐어요. 지금 업데이트할까요?';

  @override
  String get updateNow => '업데이트';

  @override
  String get updateLater => '나중에';

  @override
  String get maintenanceTitle => '서버 점검 중';

  @override
  String get maintenanceBody => '지금 서버 점검 중이에요. 잠시 후 다시 시도해 주세요.';

  @override
  String get connectionRequiredTitle => '인터넷 연결 필요';

  @override
  String get connectionRequiredBody =>
      '게임을 하려면 인터넷 연결이 필요해요. 연결을 확인하고 다시 시도해 주세요.';

  @override
  String get retryButton => '다시 시도';

  @override
  String get accountSignInApple => 'Apple로 로그인';

  @override
  String get termsOfUse => '이용약관';

  @override
  String get privacyPolicy => '개인정보처리방침';

  @override
  String get titleStartGuest => '게스트로 시작하기';

  @override
  String get titleOr => '또는';

  @override
  String get titleLoading => '불러오는 중…';

  @override
  String get guestNudgeTitle => '로그인하고 시작할까요?';

  @override
  String get guestNudgeBody =>
      '로그인하지 않으면 기기를 바꾸거나 앱을 지웠을 때 진행 상황과 순위를 되살릴 수 없어요. 지금까지 모은 곤충과 순위를 지키려면 로그인해 주세요.';

  @override
  String get guestNudgeSignIn => '로그인하기';

  @override
  String get guestNudgeContinue => '게스트로 계속하기';

  @override
  String get guestWarnTitle => '게스트로 플레이 중이에요';

  @override
  String get guestWarnBody =>
      '지금은 기기 임시 계정이라, 앱을 지우거나 기기를 바꾸면 모아둔 곤충과 순위가 사라져요. 로그인해 두면 안전하게 이어서 할 수 있어요.';

  @override
  String get titleStoreName => '곤충 키우기';

  @override
  String get titleStoreTagline => '방치형 수집 배틀';

  @override
  String nicknameChangeCostHint(int cost) {
    return '변경 시 젤리 $cost 소모';
  }

  @override
  String incubatorAdSkip(int pct) {
    return '⏩ 무료 $pct% 단축';
  }

  @override
  String get incubatorAdSkipDone => '부화 시간이 줄었어요!';

  @override
  String get nicknameEditAction => '닉네임 변경';

  @override
  String nicknameEditActionCost(int cost) {
    return '젤리 $cost 변경';
  }

  @override
  String get notifHatchTitle => '부화 완료!';

  @override
  String get notifHatchBody => '알이 부화했어요. 채집함에서 확인해 보세요.';

  @override
  String get settingsNotify => '알림';

  @override
  String get notifyOfflineFull => '오프라인 보상 가득참';

  @override
  String get notifyHatchDone => '부화 완료';

  @override
  String get notifyDaily => '일일 보상 시간';

  @override
  String get incubatorInstant => '즉시 부화';

  @override
  String get incubatorAdSkipBtn => '무료로 단축';

  @override
  String get notifyAll => '알림 받기';

  @override
  String get notEnoughMaterials => '재료가 부족해요';

  @override
  String get notifGiftTitle => '깜짝선물 도착!';

  @override
  String get notifGiftBody => '선물이 기다리고 있어요. 사라지기 전에 받아 가세요.';

  @override
  String get notifyGift => '깜짝선물';

  @override
  String get notifyQuietHours => '야간 휴식 (밤 10시~아침 8시)';

  @override
  String get pvpTicketTitle => '결투 티켓';

  @override
  String pvpTicketCount(int tickets, int max) {
    return '$tickets/$max';
  }

  @override
  String pvpTicketNextIn(String time) {
    return '다음 충전 $time';
  }

  @override
  String get pvpTicketSettling => '정산 중이에요\n월요일 09시 새 시즌';

  @override
  String get pvpTicketFullLabel => '가득참';

  @override
  String get pvpTicketNone => '결투하려면 티켓이 필요해요. 아래에서 충전할 수 있어요.';

  @override
  String pvpTicketAdBtn(int amount) {
    return '무료 충전 +$amount장';
  }

  @override
  String pvpTicketAdLeft(int used, int limit) {
    return '오늘 $used/$limit회';
  }

  @override
  String pvpTicketJellyBtn(int cost) {
    return '젤리 $cost 만땅 충전';
  }

  @override
  String pvpTicketCharged(int amount) {
    return '티켓 +$amount장';
  }

  @override
  String get pvpTicketFilled => '티켓을 가득 채웠어요';

  @override
  String get pvpTicketAlreadyFull => '티켓이 이미 가득 찼어요';

  @override
  String get pvpTicketChargeFailed => '티켓을 충전하지 못했어요. 잠시 후 다시 시도해 주세요';

  @override
  String get pvpTicketWhy => '티켓은 트로피 랭킹을 \'많이 돌린 순\'이 아니라 \'전력 순\'으로 지켜 줘요.';

  @override
  String adDailyLimit(int limit) {
    return '오늘 무료 보상을 모두 받았어요 (하루 $limit회)';
  }

  @override
  String get noticeTitle => '공지사항';

  @override
  String get noticeEmpty => '아직 공지가 없어요.';

  @override
  String get noticeFailed => '공지를 불러오지 못했어요. 연결을 확인해 주세요.';

  @override
  String get mailNoticeSection => '운영자 우편';

  @override
  String get mailClaim => '받기';

  @override
  String get mailClaimAll => '모두 받기';

  @override
  String get mailReadMore => '전체 보기';

  @override
  String get mailConfirm => '확인';

  @override
  String get gachaTitle => '곤충 알 뽑기';

  @override
  String get gachaDesc => '포텐셜 3★ 이상 보장 (야생은 5★이 안 나와요) · 이색 확률 10배';

  @override
  String gachaPityLeft(int n) {
    return '$n회 안에 전설 확정';
  }

  @override
  String gachaDraw(int n) {
    return '젤리 $n개로 뽑기';
  }

  @override
  String get gachaResultTitle => '알에서 나온 것은…';

  @override
  String get gachaPickTitle => '카드를 고르세요';

  @override
  String get gachaPickHint => '세 장 중 하나. 무엇이 들었는지는 열어야 압니다';

  @override
  String get gachaResultHint => '알은 부화기에 넣어 키워요';

  @override
  String get gachaStorageFull => '채집함이 가득 찼어요';

  @override
  String get gachaOff => '지금은 이용할 수 없어요';

  @override
  String get giftCodeTitle => '선물코드';

  @override
  String get giftCodeHint => '이벤트·공지에서 받은 코드를 입력하세요.';

  @override
  String get giftCodeField => '코드 입력';

  @override
  String get giftCodeSubmit => '사용하기';

  @override
  String get giftCodeChecking => '확인 중…';

  @override
  String get giftCodeOk => '보상을 받았어요!';

  @override
  String get giftCodeBad => '없는 코드예요';

  @override
  String get giftCodeExpired => '기간이 지난 코드예요';

  @override
  String get giftCodeExhausted => '수량이 모두 소진된 코드예요';

  @override
  String get giftCodeUsed => '이미 사용했어요';

  @override
  String get giftCodeFailed => '서버에 연결하지 못했어요. 잠시 후 다시 시도해 주세요';

  @override
  String get reviewAction => '게임 평가하기';

  @override
  String get chatAdminBadge => '운영자';

  @override
  String get autoEquip => '자동장착';

  @override
  String get autoEquipDone => '가장 강한 곤충으로 장착했어요';

  @override
  String get autoEquipAlready => '이미 최고 조합이에요';

  @override
  String get autoTeam => '자동편성';

  @override
  String get autoTeamDone => '가장 강한 팀으로 편성했어요';

  @override
  String get autoTeamAlready => '이미 최고 팀이에요';

  @override
  String teamPower(String power) {
    return '팀 전투력 $power';
  }

  @override
  String get navCharacter => '캐릭터';

  @override
  String get slotTool => '채집도구';

  @override
  String get slotHat => '모자';

  @override
  String get slotTop => '상의';

  @override
  String get slotBottom => '하의';

  @override
  String get slotShoes => '신발';

  @override
  String get slotNecklace => '목걸이';

  @override
  String get slotRing => '반지';

  @override
  String get slotBox => '채집함';

  @override
  String get optAttack => '공격력';

  @override
  String get optAttackSpeed => '공격속도';

  @override
  String get optCritChance => '치명타 확률';

  @override
  String get optCritDamage => '치명타 피해';

  @override
  String get optMaxHp => '체력';

  @override
  String get optDefense => '방어';

  @override
  String get optGold => '골드 획득';

  @override
  String get optMaterial => '재료 획득';

  @override
  String get optBugFind => '곤충 발견율';

  @override
  String get optBossDamage => '보스 피해';

  @override
  String get optSkillDamage => '스킬 피해';

  @override
  String get optSkillCooldown => '스킬 쿨타임 감소';

  @override
  String get optBoost => '탭 부스트';

  @override
  String get optOffline => '오프라인 효율';

  @override
  String get optPet => '펫 효과';

  @override
  String get charEquipment => '장비';

  @override
  String get charPets => '펫';

  @override
  String get charSkills => '스킬';

  @override
  String get charPower => '전투력';

  @override
  String get charEmptySlot => '비어 있음';

  @override
  String get forgeTitle => '공방';

  @override
  String get forgeHammer => '제련';

  @override
  String get forgeAuto => '자동 제련';

  @override
  String get forgeResultKeep => '교체';

  @override
  String get forgeResultDrop => '판매';

  @override
  String forgeResultSell(String n) {
    return '판매 · $n';
  }

  @override
  String get forgeCurrent => '지금 낀 것';

  @override
  String get forgeNoFossil => '화석 조각이 없어요';

  @override
  String forgeLevel(int lv) {
    return '공방 등급 $lv';
  }

  @override
  String forgeStep(int cur, int max) {
    return '공방 업그레이드 $cur/$max';
  }

  @override
  String get forgeUpgrading => '업그레이드 중';

  @override
  String get forgeReady => '완료!';

  @override
  String get forgeRush => '가속';

  @override
  String get forgeClaim => '완료 받기';

  @override
  String get forgeNext => '다음 등급 확률';

  @override
  String get forgeMaxLevel => '최고 등급';

  @override
  String get forgeAutoTarget => '원하는 옵션';

  @override
  String get forgeStopOnHit => '원하는 게 나오면 멈추기';

  @override
  String get skillLearn => '습득';

  @override
  String skillLevelUp(int lv, int next) {
    return '레벨 $lv → $next';
  }

  @override
  String get skillEquipped => '장착 중';

  @override
  String get skillSlotsFull => '스킬 칸이 가득 찼어요';

  @override
  String get skillAuto => '자동';

  @override
  String get skillTimingBonus => '타이밍 보너스!';

  @override
  String skillReflect(String n) {
    return '반사 $n';
  }

  @override
  String get skillBlocked => '막음';

  @override
  String get skillGacha => '뽑기';

  @override
  String get skillGachaTitle => '스킬 뽑기';

  @override
  String skillGachaFreeLeft(String n) {
    return '오늘 무료 $n회';
  }

  @override
  String skillGachaPityLeft(String grade, String n) {
    return '$n회 안에 $grade 확정';
  }

  @override
  String get skillGachaFree => '무료 뽑기';

  @override
  String skillGachaOne(String n) {
    return '1회 · 젤리 $n';
  }

  @override
  String skillGachaTen(String n) {
    return '10회 · 젤리 $n';
  }

  @override
  String skillTimes(String n) {
    return '×$n';
  }

  @override
  String get skillGachaOdds => '확률 보기';

  @override
  String get skillGachaOddsTitle => '스킬 뽑기 확률';

  @override
  String skillGachaOddsGrade(String grade, String p, String each) {
    return '$grade $p% · 스킬 1종당 $each%';
  }

  @override
  String skillGachaOddsNote(String n, String pity, String grade) {
    return '1회에 한 스킬의 조각 $n개가 나와요. $pity회째 뽑기는 $grade 이상이 확정이고, $grade이 나오면 횟수가 다시 시작돼요.';
  }

  @override
  String skillGachaResult(String name, String n) {
    return '$name 조각 +$n';
  }

  @override
  String get skillSweep => '소탕';

  @override
  String get skillSweepTitle => '보스 소탕';

  @override
  String skillSweepDesc(String tier, String n) {
    return '잡아 본 가장 높은 난이도($tier)의 보스를 다시 잡은 것으로 쳐서 스킬 조각 $n개를 확정으로 받아요.';
  }

  @override
  String skillSweepToday(String used, String max) {
    return '오늘 $used/$max회 사용';
  }

  @override
  String skillSweepFree(String n) {
    return '무료 소탕 · $n회 남음';
  }

  @override
  String skillSweepPaid(String n) {
    return '소탕 · 젤리 $n';
  }

  @override
  String get skillSweepNoBoss => '사냥터 보스를 한 마리 이상\n잡아야 소탕할 수 있어요';

  @override
  String get skillSweepLocked => '보스 먼저';

  @override
  String get skillGradeUpShort => '조각 승급';

  @override
  String get skillShardsTitle => '내 조각';

  @override
  String get skillWildShort => '만능';

  @override
  String get skillSweepLimit => '오늘 소탕을 모두 썼어요';

  @override
  String skillShardPop(String n) {
    return '조각 +$n';
  }

  @override
  String get skillMaterials => '스킬 재료';

  @override
  String skillGradeWild(String grade) {
    return '$grade 만능';
  }

  @override
  String get skillGradeUp => '승급';

  @override
  String skillGradeUpTitle(String from, String to) {
    return '$from 조각 → $to 만능 조각';
  }

  @override
  String skillGradeUpDesc(String ratio, String from, String to) {
    return '$from 조각 $ratio개로 $to 만능 조각 1개를 만들어요. 만능 조각은 $to 스킬 아무 데나 쓸 수 있어요. 재료로 쓸 조각을 고르세요.';
  }

  @override
  String skillGradeUpMake(String n) {
    return '$n개 만들기';
  }

  @override
  String skillGradeUpDone(String n, String grade) {
    return '$grade 만능 조각 $n개를 만들었어요';
  }

  @override
  String get skillGradeUpPick => '재료로 쓸 조각을 골라 주세요';

  @override
  String get skillEquip => '장착';

  @override
  String get skillUnequip => '해제';

  @override
  String skillSlotsInfo(String n, String max) {
    return '장착 $n/$max';
  }

  @override
  String get skillNextSlotHint => '새 난이도에 가면 칸이 늘어나요';

  @override
  String skillShardProgress(String have, String need) {
    return '조각 $have/$need';
  }

  @override
  String get skillLocked => '미해금';

  @override
  String get skillMaxLevel => 'MAX';

  @override
  String get skillTrain => '수련';

  @override
  String skillTrainingNow(String name, String lv, String left) {
    return '$name Lv.$lv 수련 중 · $left';
  }

  @override
  String get skillTrainClaim => '수련 완료';

  @override
  String skillTrainInstant(String n) {
    return '즉시 완료 · 젤리 $n';
  }

  @override
  String get actionInstant => '즉시 완료';

  @override
  String get skillTrainConfirmTitle => '수련 즉시 완료';

  @override
  String skillTrainConfirm(String n) {
    return '젤리 $n개를 써서 지금 완료할까요?';
  }

  @override
  String skillTrainCostShards(String n, String time) {
    return '조각 $n · $time';
  }

  @override
  String skillTrainCostWithAny(String n, String any, String time) {
    return '조각 $n + 만능 $any · $time';
  }

  @override
  String skillTrainTitle(String name) {
    return '$name 수련';
  }

  @override
  String skillLevelUpDone(String name, String lv) {
    return '$name Lv.$lv 달성!';
  }

  @override
  String get skillErrNotEnoughShards => '조각이 부족해요';

  @override
  String get skillErrTrainingBusy => '이미 수련 중인 스킬이 있어요';

  @override
  String get skillActiveSoon => '액티브 스킬은 곧 열려요';

  @override
  String get skillHowToGet => '사냥터 보스(첫 처치 확정)와 정예 몬스터에게서 스킬 조각이 나와요';

  @override
  String skillCooldown(String s) {
    return '쿨타임 $s초';
  }

  @override
  String get skillKindActive => '액티브';

  @override
  String get skillKindPassive => '패시브';

  @override
  String skillShardsGot(String list) {
    return '스킬 조각 획득 · $list';
  }

  @override
  String get skillReviveToast => '탈피! 쓰러지지 않고 다시 일어났어요';

  @override
  String skillFxMaterialFind(String v) {
    return '재료 획득 +$v%';
  }

  @override
  String skillFxBugFind(String v) {
    return '곤충 발견 +$v%';
  }

  @override
  String skillFxBossDamage(String v) {
    return '보스 피해 +$v%';
  }

  @override
  String skillFxPerPetAttack(String v) {
    return '장착 곤충 1마리당 공격 +$v%';
  }

  @override
  String skillFxKillHeal(String v) {
    return '처치 회복 +$v%';
  }

  @override
  String skillFxRevive(String v) {
    return '쓰러지면 체력 $v%로 부활';
  }

  @override
  String skillFxMaterialBurst(String v, String d) {
    return '$d초간 재료 ×$v';
  }

  @override
  String skillFxAttackSpeed(String v, String d) {
    return '$d초간 공격속도 ×$v';
  }

  @override
  String skillFxAreaDamage(String v) {
    return '화면 전체에 $v초 분량 피해';
  }

  @override
  String skillFxPetPower(String v, String d) {
    return '$d초간 곤충 효과 ×$v';
  }

  @override
  String skillFxBurstDamage(String v) {
    return '$v초 분량 피해 일격';
  }

  @override
  String skillFxInvulnerable(String d) {
    return '$d초간 피해 무효';
  }

  @override
  String get charTabStats => '능력치';

  @override
  String get charTabPets => '펫';

  @override
  String get charTabSkills => '스킬';

  @override
  String get forgeGradeButton => '공방 등급';

  @override
  String get statHp => '체력';

  @override
  String get statGoldGain => '골드 획득';

  @override
  String get statMaterialGain => '재료 획득';

  @override
  String get statBugFind => '곤충 발견율';

  @override
  String get charNoPet => '펫 없음';

  @override
  String get charPetHint => '펫 편성은 채집함에서 해요';

  @override
  String get forgeAutoShort => '자동';

  @override
  String get forgeStackFull => '모루가 가득 찼습니다';

  @override
  String get forgeStackHint => '눌러서 확인';

  @override
  String get sceneCatchTap => '지금 탭!';

  @override
  String get forgeResultNew => '새로 뽑은 것';

  @override
  String get forgeFilter => '필터';

  @override
  String get forgeFilterHint => '체크한 능력치가 하나라도 붙은 것만 모루에 쌓입니다.';

  @override
  String get forgeFilterGrade => '최소 등급';

  @override
  String get forgeFilterGradeHint => '이 등급 미만은 버립니다.';

  @override
  String forgeFilterRangeHint(String tier) {
    return '범위는 $tier 등급 기준 최대치입니다';
  }

  @override
  String get optPerfect => '완벽';

  @override
  String get forgeFilterGradeAll => '전부';

  @override
  String get forgeFilterOption => '능력치';

  @override
  String forgeStrikes(int n) {
    return 'x$n';
  }

  @override
  String get forgeStrikePick => '망치질 개수';

  @override
  String get forgeStrikePickHint => '한 번 두드릴 때 뽑을 개수예요. 손으로 두드려도 같이 적용됩니다.';

  @override
  String forgeStrikeLocked(int n) {
    return '챕터 $n 필요';
  }

  @override
  String get forgeStrikeAuto => '최대';

  @override
  String get forgeReroll => '옵션 재굴림';

  @override
  String get forgeExpand => '칸 확장';

  @override
  String get forgeExpandMax => '확장 최대';

  @override
  String get forgeRushTitle => '망치질 가속';

  @override
  String forgeRushBody(int cost, int sec) {
    return '젤리 $cost개로 $sec초 동안 망치질이 두 배 빨라져요.\n가속 중에 다시 쓰면 남은 시간에 더해집니다.';
  }

  @override
  String forgeRushLeft(int sec) {
    return '남은 시간 $sec초';
  }

  @override
  String get forgeRerollHint => '등급·부위는 그대로, 옵션만 다시 굴려요';

  @override
  String forgeRushOn(int s) {
    return '가속 $s초';
  }

  @override
  String forgeStackCount(int n, int max) {
    return '모루 $n/$max';
  }

  @override
  String get forgeNoJelly => '젤리가 모자라요';

  @override
  String get upgradeMaxed => '최대';

  @override
  String get eliteLabel => '정예';

  @override
  String gateGearHint(String cur, String need) {
    return '장비 ×$cur · 권장 ×$need';
  }

  @override
  String get gateGearWeak => '장비가 약해요 — 제련으로 공격 옵션을 모으세요';

  @override
  String get regionElementTitle => '지역 속성';

  @override
  String get regionElementHint =>
      '이 속성을 克하는 곤충을 끼면 그 곤충의 타격이 세져요. 곤충은 캐릭터와 따로, 자기 속도로 때립니다.';

  @override
  String get forgeStrikeStart => '시작';

  @override
  String get forgeStopOnHitHint => '필터에 맞는 걸 뽑으면 거기서 자동을 멈춰요. 남은 화석을 안 태웁니다.';

  @override
  String get forgeStopOnHitNoFilter => '먼저 필터를 걸어야 멈출 기준이 생겨요';

  @override
  String get forgeStoppedOnHit => '원하는 장비를 찾았습니다';

  @override
  String get forgeStrikeAutoHint => '챕터를 깰 때마다 자동으로 늘어나요';

  @override
  String get forgeFiltered => '필터에 안 맞아 버렸습니다';

  @override
  String get elementWheelTitle => '오행 상성';

  @override
  String elementWheelRestrain(String mult) {
    return '상극 — 빨간 화살표가 가리키는 상대와 부딪히면 피해 $mult배';
  }

  @override
  String get traitNoneBadge => '특성 없음';

  @override
  String get elementWheelHint => '예) 수 → 화: 수 속성 곤충이 화 속성 곤충과 싸우면 더 큰 피해를 줘요.';

  @override
  String get leagueRewardListTitle => '최초 달성 보상 (등급마다 1회)';

  @override
  String get sideMine => '나';

  @override
  String get sideFoe => '상대';

  @override
  String get battleStarting => '결투 시작!';

  @override
  String get sideMineTeam => '나의 팀';

  @override
  String get sideFoeTeam => '상대 팀';

  @override
  String leagueNeedTrophy(int n) {
    return '트로피 $n';
  }

  @override
  String seasonRewardNow(String league) {
    return '시즌 종료 보상 · 지금 $league';
  }

  @override
  String get seasonRewardHint =>
      '매주 일요일 09시에 마감하고, 그 순간의 리그로 지급돼요. 마감 전에 올려두세요.';

  @override
  String eventOpensOn(String m, String d) {
    return '$m월 $d일에 열려요';
  }

  @override
  String eventOpensInDays(int n) {
    return 'D-$n';
  }

  @override
  String eventOpensInHours(int n) {
    return '$n시간 뒤 시작';
  }

  @override
  String eventOpensInMinutes(int n) {
    return '$n분 뒤 시작';
  }

  @override
  String get eventSeeFlyer => '대회 안내 보기';

  @override
  String eventSoonBanner(String when) {
    return '왕충 선발대회 대기중 · $when';
  }

  @override
  String get eventFlyerPrizeTag => '1등 상품';

  @override
  String adCooldown(int n) {
    return '잠시 후 다시 볼 수 있어요 ($n초)';
  }

  @override
  String get jellyContinueTitle => '젤리 사용';

  @override
  String jellyContinueAsk(int n) {
    return '오늘 무료 횟수를 다 썼어요. 젤리 $n개로 계속할까요?';
  }

  @override
  String get jellyContinueYes => '젤리 사용';

  @override
  String get giftDoubleCapTitle => '오늘의 무료 2배를 이미 받았어요';

  @override
  String get giftDoubleCapBody => '패스가 있으면 모든 선물을 계속 2배로 받고,\n자동으로 수령까지 해드려요.';

  @override
  String get exchangeTitle => '교환소';

  @override
  String get exchangeHint => '젤리를 지금 내 능력치(버프 제외)로 1시간 사냥한 만큼으로 바꿔요';

  @override
  String get exchangeToGold => '골드로';

  @override
  String get exchangeToMaterial => '재료로';

  @override
  String exchangeCost(int n) {
    return '젤리 $n';
  }

  @override
  String exchangeGetGold(String amount) {
    return '$amount 골드 받기';
  }

  @override
  String exchangeGetMaterial(String amount) {
    return '재료 3종 각 $amount 받기';
  }

  @override
  String get exchangeDone => '교환했어요!';

  @override
  String get curJelly => '젤리';

  @override
  String get exchangeHoldings => '보유 현황';

  @override
  String get elementGuideBtn => '오행 관계도';

  @override
  String get giftAdMoreFreeLine => '오늘의 무료 2배는 1회!';

  @override
  String get giftAdMorePassLine => '패스가 있으면 언제나 2배로 받아요';

  @override
  String giftDoubleJellyLine(int min, int max) {
    return '오늘 첫 2배 보너스: 곤충젤리 $min~$max개!';
  }

  @override
  String get giftGoPassBtn => '패스 보러 가기';

  @override
  String get eventLegalTitle => '대회 안내 및 규정';

  @override
  String get eventLegalHost =>
      '본 대회는 Bug Champ 운영팀(개발사)이 직접 주최·운영하며, 경품 제공·발송의 책임도 운영팀에 있어요.';

  @override
  String get eventLegalStores =>
      'Apple 과 Google 은 본 대회의 후원자가 아니며, 어떤 방식으로도 관여하지 않아요.';

  @override
  String get eventLegalPrize =>
      '순위는 대회 종료 시점 기록으로 확정되고, 1등에게는 앱 내 공지로 경품 수령 방법을 안내해요(수령을 위해 배송지 연락이 필요할 수 있어요). 경품은 구매 없이 참가만으로 받을 수 있어요.';

  @override
  String get eventLegalFair =>
      '부정 행위(조작된 데이터·비정상 접근)가 확인되면 순위와 경품 대상에서 제외될 수 있어요.';

  @override
  String get giftBuyPassBtn => '패스 구입하기';

  @override
  String get supportTitle => '운영자에게 문의';

  @override
  String get supportHint => '불편한 점이나 버그를 알려주세요. 닉네임·진행 상황은 자동으로 함께 전달돼요.';

  @override
  String get supportSend => '보내기';

  @override
  String get supportSent => '전달했어요. 확인 후 반영할게요!';

  @override
  String get supportFailed => '전송에 실패했어요. 잠시 후 다시 시도해 주세요.';

  @override
  String get supportTooFast => '조금 뒤에 다시 보낼 수 있어요.';

  @override
  String get zoneConquered => '점령함';

  @override
  String get zoneHere => '지금 여기';

  @override
  String get zoneLocked => '잠김';

  @override
  String badgeParticipant(int round) {
    return '$round회차 참가';
  }

  @override
  String get eventWaitingTitle => '대회 대기중';

  @override
  String eventNextRound(int no, String date) {
    return '$no회차 대회 · $date 개막';
  }

  @override
  String eventDateMd(int m, int d) {
    return '$m월 $d일';
  }

  @override
  String get eventHallTitle => '명예의 전당';

  @override
  String eventHallRound(int no, String n) {
    return '$no회차 · 참가 $n명';
  }

  @override
  String get eventHallEmpty => '아직 명예의 전당에 오른 사람이 없어요';

  @override
  String get eventHallTop10 => '4~10위';

  @override
  String get eventHallEntrants => '함께한 참가자';

  @override
  String get eventHallMore => '외 다수';

  @override
  String get eventRewardBadgeLabel => '획득한 뱃지';

  @override
  String tierMoveTitle(String name) {
    return '$name 난이도로 이동';
  }

  @override
  String get tierMoveBody =>
      '강화 · 재화 · 장비는 그대로예요.\n사냥터 클리어 보상은 가 본 가장 높은 난이도에서만 받을 수 있어요.';

  @override
  String get tierMoveGo => '이동';

  @override
  String tierMoved(String name) {
    return '$name 난이도로 이동했어요';
  }

  @override
  String get pvpRankRewardTitle => '결투 시즌 순위 보상';

  @override
  String pvpRankRewardBody(int rank) {
    return '지난 시즌 결투 $rank위를 차지했어요!';
  }

  @override
  String pvpRankN(int n) {
    return '$n위';
  }

  @override
  String pvpRankRewardHint(String list) {
    return '순위 보상(젤리) $list';
  }

  @override
  String get duelThrowButton => '던지기!';

  @override
  String duelGaugeHint(int pct) {
    return '화면 아무 곳이나 누르면 멈춰요 · 초록 칸에 가까울수록 이번 판 공격력이 올라요(최대 +$pct%)';
  }

  @override
  String duelBout(int n) {
    return '$n판';
  }

  @override
  String get duelFinishRingOut => '장외!';

  @override
  String get duelFinishFlip => '뒤집기!';

  @override
  String get duelFinishKnockout => '기절!';

  @override
  String get duelFinishTimeUp => '판정!';

  @override
  String get duelBoutWin => '이겼다!';

  @override
  String get duelBoutLose => '졌다…';

  @override
  String get duelSkip => '건너뛰기';

  @override
  String duelTrophy(String delta) {
    return '트로피 $delta';
  }

  @override
  String get duelResultOk => '확인';

  @override
  String get duelNeedThree => '결투에는 곤충 3마리가 필요해요';

  @override
  String get duelOrderHint => '1·2·3번이 한 판씩 붙어요 · 이 순서가 내 방어 순서가 돼요';

  @override
  String get abyssName => '심연';

  @override
  String abyssFloorLabel(int n) {
    return '심연 $n층';
  }

  @override
  String get abyssUnlockedTitle => '심연이 열렸어요!';

  @override
  String get abyssUnlockedBody =>
      '극한 너머로 끝없이 이어지는 층이에요. 강화·장비·곤충은 그대로 가져가요.\n매주 월요일 09시에 1층부터 다시 오르고, 일요일 09시 마감 때 가장 깊이 내려간 순위로 젤리를 받아요.';

  @override
  String get abyssEnter => '심연으로';

  @override
  String get abyssLater => '나중에';

  @override
  String get abyssLeave => '심연에서 나가기';

  @override
  String abyssFloorClear(int n) {
    return '$n층 돌파!';
  }

  @override
  String abyssMilestone(int n, int fossil) {
    return '$n층 첫 도달! 화석 +$fossil';
  }

  @override
  String abyssBest(int n) {
    return '역대 최고 $n층';
  }

  @override
  String get abyssWeekReset => '새 주가 시작됐어요 — 심연 1층부터!';

  @override
  String get abyssRankRewardTitle => '심연 주간 순위 보상';

  @override
  String abyssRankRewardBody(int floor, int rank) {
    return '지난주 심연 $floor층 · $rank위를 차지했어요!';
  }

  @override
  String get boardTitle => '순위표';

  @override
  String get boardTabDuel => '결투 리그';

  @override
  String get boardTabAbyss => '심연';

  @override
  String boardLeagueTitle(String league) {
    return '$league 리그';
  }

  @override
  String get boardAbyssTitle => '심연 주간 순위';

  @override
  String boardSeasonEndsIn(String time) {
    return '새 시즌 시작: $time';
  }

  @override
  String boardTimeLeftDays(int d, int h, int m) {
    return '$d일 $h시간 $m분';
  }

  @override
  String boardTimeLeft(int h, int m) {
    return '$h시간 $m분';
  }

  @override
  String boardZonesHint(int promote, int demote) {
    return '상위 $promote명 승급 · 하위 $demote명 강등';
  }

  @override
  String get boardEmpty => '아직 이번 주 기록이 없어요';

  @override
  String get boardMeNone => '이번 주 결투를 하면 순위에 올라요';

  @override
  String get boardAbyssMeNone => '이번 주 심연 1층을 깨면 순위에 올라요';

  @override
  String boardFloorShort(int n) {
    return '$n층';
  }

  @override
  String boardRewardsTitle(String league) {
    return '$league 리그 순위 보상';
  }

  @override
  String get boardAbyssRewardsTitle => '심연 주간 순위 보상';

  @override
  String get boardOpen => '순위표';

  @override
  String get leagueResultTitle => '리그 결산';

  @override
  String leagueResultUp(String league) {
    return '$league 리그로 승급!';
  }

  @override
  String leagueResultDown(String league) {
    return '$league 리그로 내려갔어요';
  }

  @override
  String leagueResultStay(String league) {
    return '$league 리그 유지';
  }

  @override
  String leagueResultRank(int rank, int total) {
    return '지난주 $total명 중 $rank위';
  }

  @override
  String get leagueResultInactive => '지난주 결투를 쉬어서 한 단계 내려갔어요';

  @override
  String get leagueZoneHint => '매주 일요일 09시 마감 · 상위 20% 승급 · 하위 20% 강등';

  @override
  String get duelSquadTitle => '출정 곤충';

  @override
  String get recoveryRoom => '회복실';

  @override
  String get trainingCenter => '훈련소';

  @override
  String get trainingSoon => '훈련소는 곧 열려요';

  @override
  String get leagueClaimPromo => '승급 보상 받기';

  @override
  String get battleSeasonClosed => '시즌이 종료되었습니다!';

  @override
  String get recoveryEmpty => '회복 중인 곤충이 없어요';

  @override
  String get opponentPickTitle => '상대 고르기';

  @override
  String opponentPickHint(String power) {
    return '내 팀 전투력 $power · 이기면 별을 받고, 져도 잃지 않아요';
  }

  @override
  String get opponentWinOnly => '승리 시';

  @override
  String boardSeasonClosesIn(String time) {
    return '시즌 마감: $time';
  }

  @override
  String boardMyRankNow(int rank) {
    return '지금 $rank위 — 받을 보상';
  }

  @override
  String profileCombatPower(String power) {
    return '전투력 $power';
  }

  @override
  String get profileNoTeam => '아직 방어팀이 없어요';

  @override
  String duelAutoThrowIn(int n) {
    return '$n초 뒤 자동으로 던져요';
  }

  @override
  String get duelRestrainHit => '상극!';

  @override
  String get duelCritHit => '치명타!';

  @override
  String get duelWeakHit => '약점!';

  @override
  String pvpTicketJellyGive(int amount) {
    return '+$amount장 충전';
  }

  @override
  String get bugInfoAtk => '공격력';

  @override
  String get bugInfoDef => '방어력';

  @override
  String get bugInfoSpd => '속도';

  @override
  String get bugInfoSpecialty => '주특기';

  @override
  String get bugInfoTemperament => '기질';

  @override
  String get bugInfoSize => '크기';

  @override
  String get bugInfoPotential => '포텐셜';

  @override
  String get squadDetailTitle => '출정 곤충';

  @override
  String get squadDeploy => '출정';

  @override
  String get squadInjured => '회복 중인 곤충이 있어요 — 회복실에서 회복하거나 다른 곤충으로 바꿔 주세요';

  @override
  String squadOrder(int n) {
    return '$n번째 출전';
  }

  @override
  String get duelAttackBtn => '공격';

  @override
  String get squadRelease => '해제';

  @override
  String get squadSwap => '교체';

  @override
  String get trainAttack => '공격';

  @override
  String get trainDefense => '방어';

  @override
  String get trainEvade => '회피';

  @override
  String get trainCrit => '치명';

  @override
  String get trainRecovery => '회복력';

  @override
  String get trainingNone => '지금 훈련 중인 곤충이 없어요';

  @override
  String trainingNow(String stat, int level) {
    return '$stat $level단계 훈련 중';
  }

  @override
  String get trainingDone => '훈련 완료!';

  @override
  String get trainingPickBug => '훈련할 곤충';

  @override
  String get trainingCapHint => '최대 단계는 포텐셜·기질·주특기·혈통 특성에 따라 곤충마다 달라요';

  @override
  String trainingLevel(int lv, int cap) {
    return '$lv / $cap단계';
  }

  @override
  String get trainingStart => '훈련';

  @override
  String get trainingMaxed => '최대';

  @override
  String get trainingBusy => '훈련소가 비어야 시작할 수 있어요(한 번에 한 마리)';

  @override
  String get trainingNoMaterials => '재료가 부족해요';

  @override
  String get trainingReset => '훈련 초기화';

  @override
  String trainingResetAsk(String n) {
    return '모든 단계를 0으로 되돌리고, 쓴 재료의 절반(종류마다 $n)을 돌려받아요';
  }

  @override
  String get trainingResetDone => '훈련을 초기화했어요';

  @override
  String get squadTraining => '훈련 중인 곤충은 출정할 수 없어요';

  @override
  String get duelMiss => '빗나감!';

  @override
  String get breedingConfirm => '짝짓기';

  @override
  String breedingTimeInfo(String t) {
    return '산란까지 $t';
  }

  @override
  String get incubatorStartConfirm => '부화 시작';

  @override
  String incubatorTimeInfo(String t) {
    return '부화까지 $t';
  }

  @override
  String get bugInfoSex => '성별';

  @override
  String get bugInfoElement => '오행';

  @override
  String leagueInfoTitle(String league) {
    return '$league 리그';
  }

  @override
  String get leagueInfoRank => '주간 순위 보상 (일요일 09시 마감)';

  @override
  String get leagueInfoSeason => '시즌 종료 보상';

  @override
  String get leagueInfoAll => '리그별 보상';

  @override
  String get leagueInfoCurrent => '현재';

  @override
  String get leagueInfoAllHint => '젤리 = 그 리그 1위 보상 · 골드 = 시즌 종료 보상';

  @override
  String get boardPromoteLine => '▲ 이 위로 승급 구간';

  @override
  String get boardDemoteLine => '▼ 이 아래로 강등 구간';

  @override
  String get squadAutoFilled => '출정 곤충을 자동으로 채웠어요. 확인하고 전투 시작을 다시 눌러 주세요';

  @override
  String get battleSeasonClosedShort => '시즌 종료';

  @override
  String leagueMyNow(int rank, int total) {
    return '지금 $rank위 / $total명';
  }

  @override
  String leagueMyPromote(String league) {
    return '▲ 승급권 — 다음 주 $league 리그';
  }

  @override
  String get leagueMyStay => '유지권 — 다음 주도 이 리그';

  @override
  String leagueMyDemote(String league) {
    return '▼ 강등권 — 다음 주 $league 리그';
  }

  @override
  String get leagueMyIfEnds => '이대로 끝나면 받는 보상';

  @override
  String boardBossPct(int n) {
    return '보스 $n%';
  }

  @override
  String get boardAbyssHint => '층이 같으면 다음 층 보스에게 넣은 최대 피해(보스 %)가 큰 쪽이 위예요';

  @override
  String rankProgressAbyss(String tier, int floor) {
    return '$tier · 심연 $floor층';
  }

  @override
  String duelLaunchBonus(int pct) {
    return '던지기 성공! 이번 판 공격 +$pct%';
  }

  @override
  String eventWaveHeader(int n) {
    return '웨이브 $n';
  }

  @override
  String get eventStopHp => '체력이 바닥나서 여기서 끝났어요.';

  @override
  String get eventDevPreview => '개발자 체험 — 서버 기록·보상·참가권·부상 없음';

  @override
  String get eventDevTry => '대회 체험(개발자)';

  @override
  String get eventEntryLabel => '출전 곤충';

  @override
  String get eventEntryEmpty => '아래에서 가장 잘 키운 곤충을 골라 무대에 올려요';

  @override
  String get eventBuffNow => '지금 받고 있는 강화';

  @override
  String get eventBuffNone => '받은 강화 없음';

  @override
  String eventBuffRevive(int n) {
    return '부활 $n';
  }

  @override
  String eventFallRetry(int pct) {
    return '체력 -$pct% · 같은 웨이브를 다시 싸워요';
  }

  @override
  String get eventReviveRetry => '부활! 같은 웨이브를 다시 싸워요';

  @override
  String get cardAgile => '날렵함';

  @override
  String get cardAgileDesc => '회피 +8%p — 부딪힘 피해를 통째로 피할 확률';

  @override
  String get cardVital => '급소 노리기';

  @override
  String get cardVitalDesc => '치명타 확률 +10%p';

  @override
  String get cardBreath => '숨 고르기';

  @override
  String get cardBreathDesc => '웨이브를 깰 때마다 체력 10% 더 회복';

  @override
  String get cardHeft => '무게 싣기';

  @override
  String get cardHeftDesc => '몸집 +40% — 무거워져서 장외로 잘 안 밀려요';

  @override
  String get cardBerserk => '광폭화';

  @override
  String get cardBerserkDesc => '공격력 +35% · 대신 방어력 -21%';

  @override
  String get cardIronhide => '철갑';

  @override
  String get cardIronhideDesc => '방어력 +40% · 대신 속도 -16%';

  @override
  String get cardLastStand => '배수진';

  @override
  String get cardLastStandDesc => '체력 50% 미만으로 들어가는 웨이브에서 공격력 +40%';

  @override
  String get eventBuffEvade => '회피';

  @override
  String get eventBuffCrit => '치명';

  @override
  String get eventBuffRecover => '회복';

  @override
  String get eventBuffSize => '몸집';

  @override
  String get eventBuffSpd => '속도';

  @override
  String get eventBuffLastStand => '배수진';

  @override
  String get eventQuit => '그만하기';

  @override
  String get eventQuitTitle => '여기서 그만할까요?';

  @override
  String eventQuitBody(int n, int hp, int injury) {
    return '지금까지 깬 $n웨이브로 기록을 확정해요.\n지금 체력 $hp% — 부상은 최대의 $injury%만 쉬어요.\n(체력이 많이 남을수록 덜 쉬어요)';
  }

  @override
  String get charTabFairy => '요정';

  @override
  String get fairyCompanion => '동행 요정';

  @override
  String get fairyNoCompanion => '동행 요정이 없어요 — 요정함에서 골라 주세요';

  @override
  String fairyBoxTitle(String n, String max) {
    return '요정함 $n/$max';
  }

  @override
  String fairyEggCount(String n) {
    return '알 $n개';
  }

  @override
  String get fairyEmptyBox => '아직 요정이 없어요. 요정 알을 뽑아 둥지에서 깨워 보세요!';

  @override
  String get fairyNest => '요정 둥지';

  @override
  String get fairyNestEmpty => '둥지가 비었어요 — 알을 넣어 주세요';

  @override
  String get fairyNestNoEgg => '넣을 알이 없어요';

  @override
  String get fairyNestPut => '둥지에 넣기';

  @override
  String get fairyNestCollect => '꺼내기';

  @override
  String get fairyNestReady => '다 깼어요!';

  @override
  String fairyNestLeft(String t) {
    return '$t 남음';
  }

  @override
  String fairyNestKindHint(String n) {
    return '종류는 $n가지 중 무작위예요';
  }

  @override
  String get fairyStone => '속성석';

  @override
  String get fairyStoneNone => '속성석 없이';

  @override
  String fairyStoneHint(String p) {
    return '속성석을 넣으면 그 부가 능력치가 $p% 확률로 나와요';
  }

  @override
  String get fairyAccel => '가속기';

  @override
  String fairyAccelMinutes(String t) {
    return '$t 단축';
  }

  @override
  String get fairyUse => '쓰기';

  @override
  String get fairyBuy => '사기';

  @override
  String fairyOwned(String n) {
    return '보유 $n';
  }

  @override
  String get fairyDex => '요정 도감';

  @override
  String fairyDexGrades(String n, String max) {
    return '등급 $n/$max';
  }

  @override
  String fairyDexSubs(String n, String max) {
    return '부가 능력치 $n/$max';
  }

  @override
  String get fairyGacha => '요정 알 뽑기';

  @override
  String get fairyGachaOne => '1회';

  @override
  String get fairyGachaTen => '10회';

  @override
  String fairyGachaPity(String n) {
    return '$n회 안에 전설 이상 확정';
  }

  @override
  String get fairyGachaOdds => '확률 공개';

  @override
  String get fairyGachaOddsNote =>
      '뽑기는 알의 등급만 정해요. 종류·부가 능력치·개체값은 둥지에서 깰 때 정해져요. 신화는 합성으로만 얻어요.';

  @override
  String fairyGachaGot(String n) {
    return '알 $n개를 얻었어요';
  }

  @override
  String get fairyDust => '요정 가루';

  @override
  String fairyLevel(String n) {
    return 'Lv.$n';
  }

  @override
  String get fairyLevelUp => '레벨업';

  @override
  String get fairyMaxLevel => '최고 레벨';

  @override
  String fairyQuality(String p) {
    return '품질 $p%';
  }

  @override
  String get fairyStatMain => '기본';

  @override
  String get fairyStatSub => '부가';

  @override
  String get fairySkill => '스킬';

  @override
  String fairyCooldown(String s) {
    return '쿨 $s초';
  }

  @override
  String get fairyGoCompanion => '동행하기';

  @override
  String get fairyIsCompanion => '동행 중';

  @override
  String get fairyMerge => '합성';

  @override
  String fairyMergeEpicNote(String n) {
    return '영웅 → 전설 합성은 $n마리가 필요해요.';
  }

  @override
  String fairyReroll(String left) {
    return '재굴림 · $left회 남음';
  }

  @override
  String get fairyRerollTitle => '요정 재굴림';

  @override
  String get fairyRerollConfirm =>
      '기본·부가 능력치를\n새로 굴려요.\n부가 종류도 바뀔 수 있어요.\n\n결과가 마음에 들지 않으면\n지금 값을 지킬 수 있어요.\n\n하루 횟수가 정해져 있어요.';

  @override
  String get fairyRerollPick => '어느 쪽으로 할까요?';

  @override
  String get fairyRerollNow => '지금';

  @override
  String get fairyRerollNew => '새 결과';

  @override
  String get fairyRerollKeep => '지금 값 유지';

  @override
  String get fairyRerollTake => '새 값으로';

  @override
  String get fairyRerollCap => '오늘 재굴림을 모두 썼어요. 내일 다시 할 수 있어요.';

  @override
  String get fairyRerollNetwork => '서버에 연결되어야 할 수 있어요. 잠시 뒤 다시 시도해 주세요.';

  @override
  String fairyMergeHint(String n) {
    return '같은 종류·등급 $n마리 → 같은 종류 한 등급 위 1마리. 기본·부가 능력치는 새 등급에서 새로 정해져요.';
  }

  @override
  String fairyMergePick(String n, String max) {
    return '재료 $n/$max';
  }

  @override
  String get fairyMergeNoMat => '같은 종류·등급 요정이 모자라요';

  @override
  String get fairyAutoMerge => '자동 합성';

  @override
  String fairyAutoMergeConfirm(String used, String made) {
    return '$used마리를 합쳐 $made마리가 돼요. 동행 중·레벨 올린 요정은 빠지고, 품질이 낮은 요정부터 써요. 결과 능력치는 새로 정해져요.';
  }

  @override
  String get fairyAutoMergeNone => '자동으로 합칠 요정이 없어요';

  @override
  String get fairyRelease => '분해';

  @override
  String fairyReleaseConfirm(String n) {
    return '분해하면 요정 가루 $n개를 얻어요. 되돌릴 수 없어요.';
  }

  @override
  String get fairyNew => '새 요정!';

  @override
  String get fairyErrJelly => '젤리가 모자라요';

  @override
  String get fairyErrDust => '요정 가루가 모자라요';

  @override
  String get fairyErrGeneric => '지금은 할 수 없어요';

  @override
  String get fairyGradeCommon => '일반';

  @override
  String get fairyGradeRare => '희귀';

  @override
  String get fairyGradeEpic => '영웅';

  @override
  String get fairyGradeLegendary => '전설';

  @override
  String get fairyGradeMythic => '신화';

  @override
  String get fairyStatAttack => '공격력';

  @override
  String get fairyStatHp => '체력';

  @override
  String get fairyStatDefense => '받는 피해 감소';

  @override
  String get fairyStatAttackSpeed => '공격속도';

  @override
  String get fairyStatCritDamage => '치명 피해';

  @override
  String get fairyStatBossDamage => '보스 피해';

  @override
  String get fairyStatPetShare => '곤충 피해';

  @override
  String fairySkillBurst(String s) {
    return '$s초 분량의 피해를 한 번에';
  }

  @override
  String fairySkillHeal(String p) {
    return '체력이 60% 아래면 최대 체력 $p% 회복';
  }

  @override
  String fairySkillGuard(String d, String p) {
    return '$d초 동안 받는 피해 −$p%';
  }

  @override
  String fairySkillHaste(String d, String p) {
    return '$d초 동안 공격속도 +$p%';
  }

  @override
  String fairySkillCrits(String s) {
    return '$s초 동안 모든 공격 치명';
  }

  @override
  String fairySkillBossBurst(String s) {
    return '보스에게 $s초 분량의 피해';
  }

  @override
  String fairySkillPet(String d, String p) {
    return '$d초 동안 곤충 피해 +$p%';
  }

  @override
  String fairySkillStand(String p) {
    return '쓰러질 때 한 번 버티고 체력 $p%로 일어남';
  }

  @override
  String fairyEggPop(String grade) {
    return '요정 알 · $grade';
  }

  @override
  String get guildTitle => '길드';

  @override
  String get guildIntro => '길드에 들어가면 길드원과 채팅할 수 있어요. 길드 미션·보스·길드전도 곧 열려요.';

  @override
  String get guildUnavailable => '길드 정보를 불러오지 못했어요. 잠시 후 다시 시도해 주세요.';

  @override
  String get guildRetry => '다시 시도';

  @override
  String get guildSearchHint => '길드 이름 검색';

  @override
  String get guildEmptyList => '조건에 맞는 길드가 없어요. 직접 만들어 보세요!';

  @override
  String get guildCreate => '길드 만들기';

  @override
  String guildNameHint(int min, int max) {
    return '길드 이름 ($min~$max자)';
  }

  @override
  String get guildJoinModeOpen => '공개 — 누구나 바로 가입';

  @override
  String get guildJoinModeApproval => '승인제 — 길드장·부길드장이 수락';

  @override
  String get guildJoinModeOpenShort => '공개';

  @override
  String get guildJoinModeApprovalShort => '승인제';

  @override
  String get guildJoin => '가입';

  @override
  String get guildRequest => '가입 신청';

  @override
  String get guildCancelRequest => '신청 취소';

  @override
  String get guildFull => '가득 참';

  @override
  String guildMembersCount(int n, int max) {
    return '길드원 $n/$max';
  }

  @override
  String guildAvgPower(String v) {
    return '평균 전투력 $v';
  }

  @override
  String guildCooldown(String time) {
    return '$time 뒤에 다른 길드에 들어갈 수 있어요';
  }

  @override
  String get guildTabMembers => '길드원';

  @override
  String get guildTabChat => '채팅';

  @override
  String guildTabRequests(int n) {
    return '신청 $n';
  }

  @override
  String get guildRoleLeader => '길드장';

  @override
  String get guildRoleDeputy => '부길드장';

  @override
  String get guildRoleMember => '길드원';

  @override
  String get guildLastSeenNow => '최근 접속';

  @override
  String guildLastSeenHours(int n) {
    return '$n시간 전';
  }

  @override
  String guildLastSeenDays(int n) {
    return '$n일 전';
  }

  @override
  String get guildNoticeEmpty => '길드 소개가 없어요';

  @override
  String get guildNoticeHint => '길드를 소개해 주세요';

  @override
  String get guildEditNotice => '소개 수정';

  @override
  String get guildChangeJoinMode => '가입 방식';

  @override
  String get guildSave => '저장';

  @override
  String get guildLeave => '길드 탈퇴';

  @override
  String guildLeaveConfirm(int hours) {
    return '길드를 나가면 $hours시간 동안 다른 길드에 들어갈 수 없어요. 나갈까요?';
  }

  @override
  String get guildLeaveLastConfirm => '마지막 길드원이라 나가면 길드가 사라져요. 나갈까요?';

  @override
  String get guildLeaderLeaveNote => '길드장은 부길드장(없으면 기여도가 높은 길드원)에게 넘어가요.';

  @override
  String get guildKick => '추방';

  @override
  String guildKickConfirm(String name) {
    return '$name 님을 길드에서 내보낼까요?';
  }

  @override
  String get guildMakeDeputy => '부길드장 임명';

  @override
  String get guildRemoveDeputy => '부길드장 해제';

  @override
  String get guildTransfer => '길드장 위임';

  @override
  String guildTransferConfirm(String name) {
    return '$name 님에게 길드장을 넘길까요?';
  }

  @override
  String get guildAccept => '수락';

  @override
  String get guildReject => '거절';

  @override
  String get guildNoRequests => '들어온 가입 신청이 없어요';

  @override
  String get guildCreated => '길드를 만들었어요!';

  @override
  String get guildJoined => '길드에 들어왔어요!';

  @override
  String get guildRequestSent => '가입 신청을 보냈어요';

  @override
  String get guildChatEmpty => '아직 길드 대화가 없어요. 먼저 인사해 보세요!';

  @override
  String get guildErrNameTaken => '이미 있는 이름이에요';

  @override
  String get guildErrNameInvalid => '쓸 수 없는 이름이에요 (길이·문자·금칙어 확인)';

  @override
  String get guildErrCooldown => '아직 다른 길드에 들어갈 수 없어요';

  @override
  String get guildErrFull => '길드 인원이 가득 찼어요';

  @override
  String get guildErrTooManyRequests => '넣어 둔 가입 신청이 너무 많아요. 하나를 취소해 주세요';

  @override
  String get guildErrRequestsFull => '이 길드는 신청이 밀려 있어요. 나중에 다시 신청해 주세요';

  @override
  String get guildErrDeputyFull => '부길드장 자리가 가득 찼어요';

  @override
  String get guildErrNoticeInvalid => '쓸 수 없는 소개예요';

  @override
  String get guildErrGeneric => '처리하지 못했어요. 잠시 후 다시 시도해 주세요';

  @override
  String guildCreateWithCost(int cost) {
    return '길드 만들기 · 젤리 $cost';
  }

  @override
  String guildCreateNeedJelly(int cost) {
    return '젤리 $cost개가 있어야 길드를 만들 수 있어요';
  }

  @override
  String get guildErrJelly => '젤리가 부족해요';

  @override
  String get guildTabMissions => '미션';

  @override
  String get guildMissionForest => '숲 탐사';

  @override
  String get guildMissionCave => '동굴 조사';

  @override
  String get guildMissionSwamp => '늪지 수색';

  @override
  String get guildMissionRuins => '유적 발굴';

  @override
  String get guildMissionCanyon => '협곡 정찰';

  @override
  String get guildMissionMeadow => '초원 채집';

  @override
  String get guildMissionErrNoStarts => '오늘 출발 횟수를 다 썼어요';

  @override
  String get guildMissionErrRunning => '이미 진행 중인 미션이 있어요';

  @override
  String get guildMissionErrClosed => '이미 끝난 미션이에요';

  @override
  String get guildMissionErrHelped => '이미 도운 미션이에요';

  @override
  String get guildMissionErrHelpersFull => '도울 자리가 다 찼어요';

  @override
  String get guildMissionErrOwn => '내 미션은 도울 수 없어요';

  @override
  String get guildMissionErrNothing => '받을 보상이 없어요';

  @override
  String get guildMissionHelped => '도왔어요! 전투력이 보태졌어요';

  @override
  String get guildMissionSoloHint => '혼자서도 충분해요 — 출발하면 바로 성공해요.';

  @override
  String get guildMissionWaitHint =>
      '얼마나 기다릴지 골라 주세요. 그 사이 길드원이 도와주면 전투력이 보태지고, 시간이 끝날 때 합이 요구 전투력을 넘으면 성공이에요. 도움이 3명 다 모이면 그 자리에서 성공! 오래 기다릴수록 보상이 커요.';

  @override
  String guildMissionWaitOption(int min, String mult) {
    return '$min분 대기 · 보상 ×$mult';
  }

  @override
  String get guildMissionClaimTitle => '미션 보상';

  @override
  String guildMissionCoins(int n) {
    return '길드 코인 +$n';
  }

  @override
  String guildMissionEgg(int n) {
    return '요정 알 $n개!';
  }

  @override
  String guildMissionStartsLeft(int n, int max) {
    return '출발 $n/$max';
  }

  @override
  String guildMissionHelpLeft(int n, int max) {
    return '도움 보상 $n/$max';
  }

  @override
  String guildMissionReset(String time) {
    return '$time 뒤 초기화';
  }

  @override
  String guildMissionClaimable(int n) {
    return '받을 보상 $n건';
  }

  @override
  String get guildMissionClaim => '보상 받기';

  @override
  String get guildMissionActive => '도움 요청';

  @override
  String get guildMissionNoActive => '지금 진행 중인 미션이 없어요';

  @override
  String get guildMissionBoard => '오늘의 게시판';

  @override
  String get guildMissionRecent => '오늘 결과';

  @override
  String get guildMissionMine => '내 미션';

  @override
  String guildMissionOwner(String name) {
    return '$name 님의 미션';
  }

  @override
  String guildMissionProgress(int p, int n, int max) {
    return '$p% · 도움 $n/$max명';
  }

  @override
  String get guildMissionHelp => '도와주기';

  @override
  String get guildMissionHelpedTag => '도움 완료';

  @override
  String guildMissionSlotSolo(double mult) {
    return '요구 전투력 ×$mult · 혼자 가능';
  }

  @override
  String guildMissionSlotNeed(double mult) {
    return '요구 전투력 ×$mult · 도움 필요';
  }

  @override
  String get guildMissionStart => '출발';

  @override
  String get guildMissionSuccess => '성공';

  @override
  String guildMissionPartial(int p) {
    return '달성 $p%';
  }

  @override
  String get guildMissionChatMine => '길드에 도움을 요청했어요';

  @override
  String guildMissionChatAsk(String name) {
    return '$name 님이 미션 도움을 요청했어요!';
  }

  @override
  String guildLevel(int n) {
    return '길드 Lv $n';
  }

  @override
  String guildCoins(int n) {
    return '코인 $n';
  }

  @override
  String get guildDonate => '출석';

  @override
  String get guildDonateDoneShort => '출석 완료';

  @override
  String get guildDonateOk => '출석했어요! 코인과 길드 경험치를 받았어요';

  @override
  String get guildDonateDone => '오늘은 이미 출석했어요';

  @override
  String get guildSkills => '스킬';

  @override
  String get guildShop => '상점';

  @override
  String get guildSkillAttack => '공격력';

  @override
  String get guildSkillHp => '체력';

  @override
  String get guildSkillGold => '골드 획득';

  @override
  String get guildSkillMaterial => '재료 발견';

  @override
  String get guildSkillXp => '경험치';

  @override
  String get guildSkillMission => '미션 보상';

  @override
  String guildSkillHeader(int n) {
    return '남은 스킬 포인트 $n';
  }

  @override
  String get guildSkillNote =>
      '길드원 모두에게 사냥 중 적용돼요(오프라인 골드 포함). 결투·대회에는 적용되지 않고, 길드를 나가면 사라져요. 길드 레벨 +1 = 포인트 1.';

  @override
  String guildSkillValue(String now, String max) {
    return '+$now% (최대 +$max%)';
  }

  @override
  String get guildSkillNoPoints => '남은 스킬 포인트가 없어요';

  @override
  String get guildSkillMax => '이미 최대 단계예요';

  @override
  String get guildSkillForbidden => '길드장·부길드장만 할 수 있어요';

  @override
  String get guildSkillReset => '초기화';

  @override
  String get guildSkillResetBody => '길드 스킬을 모두 초기화하고 포인트를 돌려받을까요?';

  @override
  String get guildShopNote => '코인은 미션·도움·출석·길드 보스에서 모여요.';

  @override
  String guildShopMaterials(String h) {
    return '재료 묶음 (사냥 $h시간치)';
  }

  @override
  String guildShopFossil(int n) {
    return '화석 $n개';
  }

  @override
  String guildShopFairyDust(int n) {
    return '요정 가루 $n';
  }

  @override
  String guildShopFairyEgg(int n) {
    return '요정 알 $n개';
  }

  @override
  String guildShopSkillShard(String grade, int n) {
    return '$grade 만능 조각 $n개';
  }

  @override
  String guildShopLimitDay(int n, int max) {
    return '오늘 $n/$max';
  }

  @override
  String guildShopLimitWeek(int n, int max) {
    return '이번 주 $n/$max';
  }

  @override
  String guildShopBought(String item) {
    return '구매했어요: $item';
  }

  @override
  String get guildShopSoldOut => '구매 한도에 닿았어요';

  @override
  String get guildShopSoldOutShort => '품절';

  @override
  String get guildShopNoCoins => '코인이 부족해요';

  @override
  String get guildTabBoss => '보스';

  @override
  String guildBossTitle(int n) {
    return '길드 보스 · $n단계';
  }

  @override
  String guildBossAttack(int n) {
    return '공격하기 (오늘 $n회 남음)';
  }

  @override
  String get guildBossNote =>
      '피해는 결투 방어팀 전투력으로 정해져요(요정·스킬·장비는 들어가지 않아요). 체력은 길드 전체가 공유하고 한 주 동안 이어져요.';

  @override
  String get guildBossNoTeam => '결투 방어팀을 등록해야 보스를 공격할 수 있어요.';

  @override
  String get guildBossNoAttacks => '오늘 공격을 다 썼어요';

  @override
  String guildBossHit(String d) {
    return '피해 $d';
  }

  @override
  String get guildBossKilled => '보스 처치! 다음 단계';

  @override
  String guildBossMine(String d) {
    return '이번 주 내 피해 $d';
  }

  @override
  String guildBossRank(int n) {
    return '이번 주 길드 순위 $n위';
  }

  @override
  String get guildBossRankNone => '아직 순위 밖이에요 — 공격하면 순위에 올라요';

  @override
  String guildBossTopRow(int s, int p) {
    return '$s단계 · $p%';
  }

  @override
  String guildBossLastWeek(int rank, int jelly) {
    return '지난주 $rank위 — 젤리 $jelly개';
  }

  @override
  String guildBossClaimed(int n) {
    return '젤리 $n개를 받았어요!';
  }

  @override
  String get guildTabWar => '길드전';

  @override
  String get guildWarBreed => '육성';

  @override
  String get guildWarForge => '제련';

  @override
  String get guildWarHunt => '사냥';

  @override
  String get guildWarDuel => '결투';

  @override
  String get guildWarTrain => '수련';

  @override
  String get guildWarBoss => '길드 보스';

  @override
  String get guildWarClash => '전투력 대결';

  @override
  String get guildWarBreedHint =>
      '짝짓기 수령·부화 수령·합성으로 점수를 얻어요. 젤리로 즉시 완료한 건 세지 않아요.';

  @override
  String get guildWarForgeHint => '제련하면 점수 — 높은 등급일수록 훨씬 커요.';

  @override
  String get guildWarHuntHint => '정예와 사냥터 보스를 잡으면 점수.';

  @override
  String get guildWarDuelHint => '결투에서 이기면 점수(서버가 확정한 승리만).';

  @override
  String get guildWarTrainHint => '곤충 수련·훈련소 단계·스킬 수련으로 점수.';

  @override
  String get guildWarBossHint => '길드 보스를 공격하면 점수.';

  @override
  String get guildWarClashHint =>
      '오늘은 할 일이 없어요! 결투 방어팀 전투력 순으로 1:1 대결이 자동으로 벌어지고, 이 탭을 열면 결과가 나와요.';

  @override
  String guildWarTier(String tier, int gr) {
    return '$tier 티어 · 등급점 $gr';
  }

  @override
  String get guildWarClosed => '길드전은 아직 열리지 않았어요.';

  @override
  String guildWarOpensOn(String date) {
    return '길드전은 $date 주부터 시작해요.';
  }

  @override
  String guildWarNeedMembers(int n) {
    return '이번 주 길드전에 나가려면 길드원이 $n명 이상이어야 해요.';
  }

  @override
  String guildWarVs(String name) {
    return 'vs $name';
  }

  @override
  String get guildWarVsVirtual => 'vs 야생 길드(같은 티어 평균)';

  @override
  String get guildWarVirtualName => '야생';

  @override
  String guildWarDayOf(int d, String theme) {
    return '$d일차 · $theme';
  }

  @override
  String guildWarMyToday(int n, int cap) {
    return '오늘 내 점수 $n/$cap';
  }

  @override
  String get guildWarWin => '승리';

  @override
  String get guildWarLose => '패배';

  @override
  String get guildWarDraw => '무승부';

  @override
  String guildWarPoints(int a, int b) {
    return '승점 $a : $b';
  }

  @override
  String guildWarClashResult(int a, int b) {
    return '7일차 대결 $a : $b';
  }

  @override
  String guildWarReward(String result, int coins, int jelly) {
    return '$result 보상 — 코인 $coins · 젤리 $jelly';
  }

  @override
  String guildWarClaimed(int coins, int jelly) {
    return '코인 $coins · 젤리 $jelly개를 받았어요!';
  }

  @override
  String duelPickDeployed(int n) {
    return '출정 중 · $n번';
  }

  @override
  String get fairyDexHelp =>
      '요정 도감은 지금까지 얻어 본 요정을 기록하는 곳이에요. 요정 8종마다 두 가지를 모아요.\n• 등급 점 — 그 요정을 그 등급으로 처음 얻으면 그 색의 점이 켜져요.\n• 속성석 — 그 요정을 그 부가 능력치로 처음 얻으면 그 속성석이 밝아져요.\n알을 둥지에서 부화시키거나 합성으로 새 요정을 얻을 때 기록되고, 요정을 분해해도 기록은 남아요. 칸을 모을수록 아래 보상(요정 가루·가속기·화석)을 받아요. 능력치를 올려 주지는 않아요.';

  @override
  String get fairyDexLegendGrades => '등급 점 (켜짐 = 그 등급으로 얻어 봄)';

  @override
  String get fairyDexLegendSubs => '속성석 (밝음 = 그 부가 능력치로 얻어 봄)';

  @override
  String fairyDexRewards(int n, int max) {
    return '도감 보상 · $n/$max칸 모음';
  }

  @override
  String get fairyDexClaimed => '도감 보상을 받았어요!';

  @override
  String get fairyNestPickEgg => '넣을 알을 먼저 골라 주세요';

  @override
  String get guideTitle => '공략집';

  @override
  String get guideIntro => '같은 종이라도 곤충마다 능력이 달라요. 궁금한 항목을 눌러 용어의 뜻을 확인하세요.';

  @override
  String get guideElementTitle => '오행 상성 (목·화·토·금·수)';

  @override
  String guideElementBody(String mult) {
    return '곤충마다 오행 속성이 하나 있어요. 결투에서 상극 관계인 상대와 부딪히면 피해가 $mult배가 돼요. 빨간 화살표가 이기는 방향이에요.';
  }

  @override
  String guideElementLine(String a, String b) {
    return '$a은(는) $b에 강해요';
  }

  @override
  String get guideSpecialtyTitle => '주특기 (싸우는 방식)';

  @override
  String get guideSpecialtyBody => '종마다 정해진 주특기가 결투에서 싸우는 방식을 정해요.';

  @override
  String get guideSpecialtyStrike => '돌진해서 들이받고 상대를 뒤집어요.';

  @override
  String get guideSpecialtyGrip => '물고 늘어져 상대를 밀어내요.';

  @override
  String get guideSpecialtyToss => '상대를 들어 올려 내던져요.';

  @override
  String get guideTemperamentTitle => '기질 (싸움 성향)';

  @override
  String get guideTemperamentBody =>
      '기질은 결투에서 곤충이 움직이는 성향이고, 훈련소에서 어떤 능력치를 더 높이 키울 수 있는지도 정해요.';

  @override
  String get guideTempAggressive => '돌진이 잦은 공격형이에요.';

  @override
  String get guideTempCautious => '가장자리를 피하고 상대의 돌진을 옆으로 흘려요.';

  @override
  String get guideTempCunning => '옆으로 돌아 들어가 약점을 노려요.';

  @override
  String get guideTempSteadfast => '잘 밀리지 않는 버팀형이에요.';

  @override
  String get guideTempFickle => '여러 전법을 섞어 써요.';

  @override
  String guideTrainCapMods(String mods) {
    return '훈련 상한: $mods';
  }

  @override
  String get guideSizeTitle => '크기 (무게)';

  @override
  String guideSizeBody(String min, String max) {
    return '크기는 종마다 정해진 범위 안에서 정해져요. 클수록 능력치가 ×$min~×$max로 높아지고, 결투에서 잘 밀리지 않고 장외로 덜 떨어져요.';
  }

  @override
  String get guidePotentialTitle => '포텐셜 (1~5성)';

  @override
  String guidePotentialBody(int perStar, int fodder) {
    return '별이 높을수록 부위 강화 최대 레벨(별 × 10)과 훈련 최대 단계(별 1개당 +$perStar)가 올라가요. 같은 종 $fodder마리를 합성하면 별이 하나 올라요.';
  }

  @override
  String get guideTraitTitle => '혈통 특성 (짝짓기 전용)';

  @override
  String get guideTraitBody =>
      '짝짓기로 태어난 곤충만 가질 수 있어요. 야생 곤충에게는 없어요. 펫으로 장착했을 때와 결투 모두에 효과가 있어요.';

  @override
  String guideTraitEffect(String atk, String hp) {
    return '공격 +$atk · 체력 +$hp';
  }

  @override
  String get guideBreedTitle => '짝짓기와 유전';

  @override
  String guideBreedBody(String el, String tm, String tr) {
    return '같은 종 수컷·암컷 성충을 짝지으면 알을 얻어요. 자식은 부모의 오행($el)과 기질($tm)을 높은 확률로, 부모의 특성($tr)을 물려받아요. 부모의 오행·기질·특성이 같으면 자식도 반드시 같아서, 원하는 계통을 대대로 이어 갈 수 있어요.';
  }

  @override
  String get guideVariantTitle => '이색 개체';

  @override
  String guideVariantBody(
    String wild,
    String breed,
    String parent,
    String gacha,
    String pet,
    String duel,
  ) {
    return '아주 드물게 색이 다른 곤충(무지개·알비노)이 나와요. 확률은 야생 $wild · 짝짓기 $breed · 부모가 이색이면 $parent · 알 뽑기 $gacha예요. 펫으로 장착하면 능력치 +$pet, 결투에서는 +$duel이에요.';
  }

  @override
  String get guideLifeTitle => '성장 단계';

  @override
  String get guideLifeBody =>
      '알 → 유충 → 번데기 → 성충 순서로 자라요. 알은 부화기에 넣어야 유충이 되고, 유충부터는 시간이 지나면 저절로 성충이 돼요. 수련·짝짓기·결투는 성충만 할 수 있어요.';

  @override
  String get guideDuelTitle => '결투';

  @override
  String guideDuelBody(int sec, String weak) {
    return '한 판은 원형 경기장에서 벌이는 $sec초 1:1 몸싸움이에요. 장외·뒤집기·기절로 이기고, 시간이 끝나면 남은 체력 %로 판정해요. 한 경기는 3마리가 이긴 곤충이 계속 나가는 승자 연속전이에요. 옆·뒤를 들이받으면 피해 ×$weak, 치명타와 회피도 있어요.';
  }

  @override
  String get guideTrainTitle => '훈련소';

  @override
  String guideTrainBody(int base) {
    return '곤충마다 결투 능력치 5가지(공격·방어·회피·치명·회복력)를 훈련해요. 최대 단계 = 기본 $base + 포텐셜 + 기질·주특기·특성 보정이라, 곤충마다 잘 키울 수 있는 능력치가 달라요. 역할이 다른 곤충을 섞어 팀을 짜 보세요!';
  }

  @override
  String bugInfoSizeDetail(String mm, String min, String max, String mult) {
    return '${mm}mm (범위 $min~$max) · 능력치 ×$mult';
  }

  @override
  String get eventHudShort => '왕충\n선발대회';

  @override
  String fairyStoneName(String stat) {
    return '$stat 속성석';
  }

  @override
  String fairyStoneEffect(String stat, String p) {
    return '부화한 요정의 부가 능력치가 $p% 확률로 \'$stat\'(으)로 나와요';
  }

  @override
  String get fairyStoneBuyTitle => '속성석 구입';

  @override
  String get fairyStoneBuyAction => '구입';

  @override
  String get fairyEquippedTag => '착용 중';

  @override
  String get fairyMergeEquipped => '착용 중인 요정은 합성할 수 없어요';

  @override
  String get fairyAutoMergeDone => '합성 결과';

  @override
  String get exchangeToDust => '요정 가루로';

  @override
  String get exchangeHintDust => '젤리를 요정 가루로 바꿔요 (젤리 1 = 가루 1)';

  @override
  String exchangeGetDust(String amount) {
    return '요정 가루 $amount 받기';
  }

  @override
  String fairyStatRange(String grade, String lo, String hi) {
    return '($grade 범위 $lo~$hi)';
  }

  @override
  String get fairyStopCompanion => '동행 해제';

  @override
  String get fairyHelpTitle => '도움말';

  @override
  String get fairyHelpGradeHead => '등급별 기본 능력치 범위 (Lv.1)';

  @override
  String fairyHelpGradeLine(String grade, String lo, String hi, String max) {
    return '$grade: $lo ~ $hi · 최대 Lv.$max';
  }

  @override
  String fairyHelpLevel(String p) {
    return '레벨이 1 오를 때마다 능력치가 Lv.1 값의 $p씩 늘어나요.';
  }

  @override
  String get fairyHelpSubHead => '부가 능력치 (요정마다 하나)';

  @override
  String fairyHelpSub(String p) {
    return '부화할 때 아래 중 하나가 붙어요. 크기는 기본 범위의 $p × 능력치별 비중이에요. 속성석을 넣으면 원하는 부가가 나올 확률이 올라가요.';
  }

  @override
  String fairyHelpSubLine(String stat, String grade, String lo, String hi) {
    return '$stat: $grade $lo ~ $hi';
  }

  @override
  String get fairyHelpMergeHead => '합성';

  @override
  String fairyHelpMerge(String n) {
    return '같은 종류·등급 $n마리 → 한 등급 위 1마리. 기본·부가 능력치는 새로 정해져서, 합성할 때마다 더 좋은 요정을 노릴 수 있어요.';
  }

  @override
  String fairyGachaOverflowWarn(String free, String lost) {
    return '요정함 빈칸이 $free칸이라, 알 $lost개는 요정 가루로 바뀌어요.';
  }

  @override
  String fairyOverflowToast(String n, String dust) {
    return '요정함이 가득 차 알 $n개가 요정 가루 $dust로 바뀌었어요';
  }

  @override
  String fairyOverflowPop(String dust) {
    return '요정함 가득 · 요정 가루 +$dust';
  }

  @override
  String fairyMergeInvestedConfirm(String n, String dust) {
    return '레벨을 올린 요정 $n마리가 재료로 들어가요. 쓴 가루 중 $dust를 돌려받아요. 합성할까요?';
  }

  @override
  String fairyMergeRefund(String dust) {
    return '요정 가루 $dust를 돌려받았어요';
  }

  @override
  String exchangeDustLeft(String n) {
    return '오늘 $n 남음';
  }

  @override
  String get exchangeDustCapReached => '오늘 교환 한도에 닿았어요';

  @override
  String get bugLock => '잠금';

  @override
  String get bugLocked => '잠김';

  @override
  String get bugUnlock => '잠금 해제';

  @override
  String get bugLockedToast => '잠갔어요 — 합성·분해 재료로 쓰지 않아요';

  @override
  String get bugUnlockedToast => '잠금을 풀었어요';

  @override
  String get disassembleLocked => '잠긴 곤충은 분해할 수 없어요. 잠금을 먼저 풀어 주세요.';

  @override
  String trainingSumShort(int n) {
    return '훈련 Lv.$n';
  }

  @override
  String get reviewAskTitle => '곤충 키우기, 재미있게 하고 계신가요?';

  @override
  String get reviewAskBody =>
      '잠깐 시간 내서 스토어에 리뷰를 남겨 주시면 혼자 만드는 게임에 큰 힘이 돼요.\n플레이해 주셔서 감사해요!';

  @override
  String get reviewAskLater => '나중에';

  @override
  String get trainingNoneShort => '미훈련';

  @override
  String get guildComingSoonTitle => '준비 중이에요';

  @override
  String get guildComingSoonBody =>
      '길드 미션 · 길드 보스 · 길드 상점 · 주간 길드전이 다음 업데이트에서 열려요. 조금만 기다려 주세요!';

  @override
  String get notifChannelName => '보상 알림';

  @override
  String get notifChannelDesc => '점심·저녁 보상, 오프라인 보상 가득참 알림';

  @override
  String get eggOddsTitle => '곤충 알 뽑기 확률';

  @override
  String get eggOddsGradeHead => '등급 (같은 등급 안의 종은 모두 같은 확률)';

  @override
  String get eggOddsPotentialHead => '포텐셜';

  @override
  String eggOddsVariant(String p) {
    return '이색(무지개·알비노): $p%';
  }

  @override
  String eggOddsPity(String n, String grade) {
    return '$n회째에는 $grade 이상 확정';
  }

  @override
  String get eggOddsNote =>
      '확률은 한 번 뽑을 때 기준이에요. 천장 횟수는 그 등급이 나올 때만 처음부터 다시 세요.';

  @override
  String eggOddsGradeLine(String grade, String p, String each) {
    return '$grade $p% · 종마다 $each%';
  }

  @override
  String get variantRainbow => '무지개';

  @override
  String get variantAlbino => '알비노';

  @override
  String get jellyShortTitle => '젤리가 부족해요';

  @override
  String get jellyShortBody => '상점에서 젤리를 구매하면 바로 이어서 할 수 있어요.';

  @override
  String get jellyShortGoShop => '상점 가기';

  @override
  String pvpRefillLimit(int n) {
    return '젤리 충전은 하루 $n번까지예요';
  }

  @override
  String get pvpTicketRefillTitle => '티켓 충전';

  @override
  String pvpTicketRefillBody(int n, int left) {
    return '젤리로 티켓 $n장을 받아요. (오늘 $left번 남음)';
  }

  @override
  String get starterOfferTitle => '스타터 패키지';

  @override
  String get starterOfferBody =>
      '젤리 300 · 골드 · 재료 · 부화기 1칸.\n계정당 한 번만 살 수 있는, 상점에서 가장 알찬 구성이에요!';

  @override
  String get starterOfferGo => '보러 가기';

  @override
  String mailGrantTitle(String name) {
    return '[운영자 지급] $name';
  }

  @override
  String get mailGrantBody => '운영자가 보낸 보상입니다. 받기를 눌러 수령하세요.';

  @override
  String get mailReplyTitle => '[운영자 답변]';

  @override
  String get jellyActExpand => '확장';

  @override
  String get jellyActCharge => '충전';

  @override
  String get jellyActExchange => '교환';

  @override
  String get jellyActReroll => '재굴림';

  @override
  String eventJellyTicketConfirm(int jelly, int n, int used, int max) {
    return '젤리 $jelly개로 참가권 $n장을 충전할까요?\n(오늘 $used/$max회 사용)';
  }

  @override
  String get storageExpandTitle => '채집함 확장';

  @override
  String storageExpandConfirm(int jelly, int n) {
    return '젤리 $jelly개로 채집함을 $n칸 늘릴까요?';
  }

  @override
  String get breedingExpandTitle => '짝짓기 슬롯 확장';

  @override
  String get incubatorExpandTitle => '부화기 확장';

  @override
  String slotExpandConfirm(int jelly) {
    return '젤리 $jelly개로 슬롯을 1칸 늘릴까요?';
  }

  @override
  String get breedingInstantTitle => '짝짓기 즉시 완료';

  @override
  String breedingInstantConfirm(int jelly) {
    return '젤리 $jelly개로 지금 바로 알을 받을까요?';
  }

  @override
  String incubatorInstantConfirm(int jelly) {
    return '젤리 $jelly개로 지금 바로 부화시킬까요?';
  }

  @override
  String get breakthroughInstantTitle => '돌파 즉시 완료';

  @override
  String breakthroughInstantConfirm(int jelly) {
    return '젤리 $jelly개로 돌파를 지금 끝낼까요?';
  }

  @override
  String get evolveAccelTitle => '진화 촉진';

  @override
  String evolveAccelConfirm(int jelly, String next) {
    return '젤리 $jelly개로 지금 바로 다음 단계($next)로 진화시킬까요?';
  }

  @override
  String get forgeExpandTitle => '모루 칸 확장';

  @override
  String forgeExpandConfirm(int jelly, int n) {
    return '젤리 $jelly개로 모루를 $n칸 늘릴까요?';
  }

  @override
  String forgeRerollConfirm(int jelly, String option) {
    return '젤리 $jelly개로 \'$option\' 옵션을 다시 굴릴까요?\n등급·부위는 그대로예요.';
  }

  @override
  String get forgeUpRushTitle => '공방 등급업 즉시 완료';

  @override
  String forgeUpRushConfirm(int jelly, String grade) {
    return '젤리 $jelly개로 $grade 등급업을 지금 끝낼까요?';
  }

  @override
  String exchangeConfirmGold(int jelly, String amount) {
    return '젤리 $jelly개 → 골드 $amount\n교환할까요?';
  }

  @override
  String exchangeConfirmMaterial(int jelly, String amount) {
    return '젤리 $jelly개로 재료 3종을 각 $amount씩 받을까요?';
  }

  @override
  String exchangeConfirmDust(int jelly, String amount) {
    return '젤리 $jelly개 → 요정 가루 $amount\n교환할까요?';
  }

  @override
  String zoneFellBack(String tier, String zone) {
    return '버티지 못하고 $tier · $zone까지 물러났어요. 보스를 다시 잡으면 올라가요';
  }

  @override
  String abyssFellBack(int floor) {
    return '버티지 못하고 심연 $floor층으로 물러났어요. 층 보스를 잡으면 다시 올라가요';
  }

  @override
  String get abyssFellOut => '버티지 못하고 심연에서 밀려났어요. 극한 최종 보스를 다시 잡으면 들어갈 수 있어요';

  @override
  String get zoneReclaim => '다시 잡아야 해요';
}
