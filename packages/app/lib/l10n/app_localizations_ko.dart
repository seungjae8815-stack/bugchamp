// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => '버그 챔프';

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
  String collectInstalledSnack(String field, String trap) {
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
  String get chatTitle => '채팅';

  @override
  String get chatPlaceholder => '채팅 (준비 중) — 탭하면 열려요';

  @override
  String get characterTitle => '내 캐릭터';

  @override
  String get statCombatPower => '전투력';

  @override
  String get statCrit => '치명타';

  @override
  String get statMaxHp => '최대 체력';

  @override
  String get statDefense => '방어력';

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
  String get giftNone => '아직 도착한 선물이 없어요. 플레이하다 보면 도착해요!';

  @override
  String get settingsTitle => '설정';

  @override
  String get settingsNickname => '닉네임';

  @override
  String get settingsNicknameHint => '이름을 입력하세요';

  @override
  String get actionSave => '저장';

  @override
  String get actionCancel => '취소';

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
  String evolveNext(String next, String time) {
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
}
