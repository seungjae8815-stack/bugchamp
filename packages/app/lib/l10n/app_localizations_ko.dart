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
    return '💎$n 즉시회복';
  }

  @override
  String get notEnoughJelly => '곤충젤리가 부족해요';

  @override
  String get scoutBoard => '스카우트 보드';

  @override
  String get scoutRefresh => '새로고침';

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
    return '최고 등급: $name';
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
  String get synergyHint => '곤충 2마리 이상 배치 · 앞 슬롯이 뒤를 生하면 시너지(순서 중요)';

  @override
  String get teamReorderHint => '끌어서 순서 변경';

  @override
  String get leagueSeasonTitle => '리그 · 시즌';

  @override
  String get modeManual => '수동';

  @override
  String get modeAuto => '자동';

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
  String get storePending => '결제 확인 중이에요. 완료되면 자동으로 지급돼요';

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
    return '+$n칸 💎$jelly';
  }

  @override
  String get dexTitle => '곤충 도감';

  @override
  String get dexDiscovered => '발견';

  @override
  String get dexConquered => '정복';

  @override
  String get dexConqueredYes => '완료';

  @override
  String get dexConqueredNo => '아직';

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
    return '도감 보상 획득! 💰$gold · 💎$jelly';
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
    return '$n웨이브 돌파! 하나를 고르세요';
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
  String get cardReviveDesc => '쓰러진 곤충 하나를 절반 체력으로 되살려요';

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
  String get eventFlyerHow1 => '성충 3마리를 골라 출전';

  @override
  String get eventFlyerHow2 => '웨이브를 깰 때마다 강화 카드 1장 선택';

  @override
  String get eventFlyerHow3 => '더 멀리 간 사람이 순위 위로';

  @override
  String get eventFlyerRules => '꼭 알아두세요';

  @override
  String get eventFlyerRule1 =>
      '이 대회는 **스탯이 평준화**돼요 — 종·오행·기질만 반영되고 수련·강화·크기는 적용되지 않아요';

  @override
  String get eventFlyerRule2 => '적의 오행은 웨이브마다 바뀌어요 — 한 속성만 모으면 막혀요';

  @override
  String get eventFlyerRule3 => '출전한 곤충은 하루 쉬어요 — 좋은 곤충을 여러 마리 모아두면 유리해요';

  @override
  String get eventFlyerRule4 => '참가권은 매일 아침 채워지고, 광고로 하루 2장까지 더 받을 수 있어요';

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
  String eventWaveRecord(Object n) {
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
  String get eventPickTeam => '출전 곤충 3마리를 고르세요';

  @override
  String get eventPickOrder => '왼쪽부터 순서대로 나가요 · 앞이 뒤를 生하면 시너지';

  @override
  String get eventNormalizeTitle => '이 대회는 스탯이 평준화돼요';

  @override
  String get eventNormalizeBody =>
      '종·오행·기질·주특기만 반영돼요. 수련·돌파·부위 강화·포텐셜·크기는 적용되지 않아요 — 모두 같은 조건에서 편성으로 겨루는 대회예요.';

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
  String get eventAdTicket => '광고 보고 참가권 받기';

  @override
  String get eventAdLimit => '오늘 광고 보상을 모두 받았어요';

  @override
  String get eventTicketFull => '참가권이 가득 찼어요';

  @override
  String eventResultTitle(Object n) {
    return '$n웨이브 도달!';
  }

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
  String get giftClaimAd => '광고 2배';

  @override
  String giftExpiresIn(String time) {
    return '$time 후 만료';
  }

  @override
  String get giftClaimedSnack => '선물을 받았어요!';

  @override
  String get giftDoubledSnack => '광고 보상 2배 획득!';

  @override
  String get giftAdMoreTitle => '광고 보고 한 번 더?';

  @override
  String get giftAdMoreBody => '광고를 보면 같은 보상을 한 번 더 받아요';

  @override
  String get giftAdMoreYes => '광고 보고 받기';

  @override
  String get giftAdMoreLater => '괜찮아요';

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
  String get buffWatchAd => '광고 보기';

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
    return '💎$n';
  }

  @override
  String trainJellySnack(int lv) {
    return '💎 즉시 수련! 레벨 +$lv';
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
    return '즉시 💎$n';
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
    return '슬롯 확장 💎$n';
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
  String get incubatorPick => '부화할 알 선택';

  @override
  String get disassembleTitle => '분해';

  @override
  String disassembleDesc(int n) {
    return '젤리 $n개로 환원';
  }

  @override
  String get disassembleAction => '분해';

  @override
  String get disassembleSnack => '분해 완료';

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
  String get upRegenDesc => '초당 체력 회복량이 늘어납니다.';

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
  String get netLostTitle => '연결이 끊겼어요';

  @override
  String get netLostBody => '인터넷 연결을 확인해 주세요.\n연결되어야 진행이 저장됩니다.';

  @override
  String get netRetry => '다시 시도';

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
    return '변경 시 💎$cost 소모';
  }

  @override
  String incubatorAdSkip(int pct) {
    return '📺 광고보고 $pct% 단축';
  }

  @override
  String get incubatorAdSkipDone => '부화 시간이 줄었어요!';

  @override
  String get nicknameEditAction => '닉네임 변경';

  @override
  String nicknameEditActionCost(int cost) {
    return '💎$cost 변경';
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
  String get incubatorAdSkipBtn => '광고 보고 단축';

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
  String get pvpTicketFullLabel => '가득참';

  @override
  String get pvpTicketNone => '결투하려면 티켓이 필요해요. 아래에서 충전할 수 있어요.';

  @override
  String pvpTicketAdBtn(int amount) {
    return '광고 보고 +$amount장';
  }

  @override
  String pvpTicketAdLeft(int used, int limit) {
    return '오늘 $used/$limit회';
  }

  @override
  String pvpTicketJellyBtn(int cost) {
    return '💎$cost 만땅 충전';
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
    return '오늘 볼 수 있는 광고를 모두 봤어요 (하루 $limit회)';
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
  String get forgeResultDrop => '버리기';

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
  String get forgeRush => '즉시 완료';

  @override
  String get forgeClaim => '완료 받기';

  @override
  String get forgeNext => '다음 등급 확률';

  @override
  String get forgeMaxLevel => '최고 등급';

  @override
  String get forgeAutoTarget => '원하는 옵션';

  @override
  String get forgeStopOnHit => '찾으면 멈춤';

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
  String get forgeFiltered => '필터에 안 맞아 버렸습니다';

  @override
  String get elementWheelTitle => '오행 상성';

  @override
  String get elementWheelRestrain => '상극 — 빨간 화살표가 가리키는 상대를 때리면 데미지 1.5배';

  @override
  String get elementWheelGenerate =>
      '상생 — 편성에서 바로 앞자리가 초록 화살표로 나를 가리키면 팀 전체 공격·회복 +10%';

  @override
  String get traitNoneBadge => '특성 없음';

  @override
  String get elementWheelHint =>
      '편성은 초록 화살표를 따라가게 짜세요. 예) 목 → 화 → 토 로 세우면 연결 2개라 +20%.';

  @override
  String get leagueRewardListTitle => '리그 승급 보상 (계정당 1회)';
}
