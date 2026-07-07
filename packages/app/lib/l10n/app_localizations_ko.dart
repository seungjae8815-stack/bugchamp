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
  String get navStorage => '보관함';

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
  String get storageTitle => '보관함';

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
}
