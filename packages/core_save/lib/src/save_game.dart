import 'dart:math';

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:meta/meta.dart';

import 'gift_mail.dart';

/// 현재 세이브 스키마 버전. SaveGame.toJson 이 이 값을 기록하고,
/// 로드 시 이 값보다 낮으면 마이그레이션이 실행된다 (see data/save_migrations.dart).
const int kSaveSchemaVersion = 18;

/// 채집함 기본 칸 수(구조적 기본값 — 확장 비용·상한은 pets.json §6).
///
/// 50 인 이유: `deriveStats` 의 곤충 수 버프가 `min(bugsCollected, 50)` 이라
/// 50마리를 넘겨도 캐릭터 스탯이 더 오르지 않는다. 즉 이 상한은 **밸런스를
/// 깎지 않으면서** 세이브 크기를 묶는다.
///
/// ⚠️ 이 상한이 없으면 세이브가 무한히 커진다(곤충 3만 마리 = 13.6MB 세이브
/// → 서버 업로드마다 수십 MB 트래픽·DB 타임아웃). 절대 제거하지 말 것.
///
/// **스키마 버전을 올리지 않은 이유**: `storageCapacity` 는 없으면 이 기본값으로
/// 읽히므로 구/신 버전이 서로의 세이브를 그대로 읽는다. 버전을 올리면 서버가
/// 새 버전 세이브를 저장하는 순간, 스토어에 이미 배포된 구버전 앱이
/// `migrateToCurrent` 에서 "다운그레이드 불가" 예외로 죽는다. 상한 적용은
/// 버전 게이트가 아니라 **로드·커밋 시 정리**(SaveController)와
/// **업로드 시 서버 강제**(GameActions.enforceStorage)로 처리한다.
const int kDefaultStorageCapacity = 50;

/// 모루 위에 쌓아 둘 수 있는 제련 결과 수.
///
/// ⚠️ 이건 **가방이 아니다.** 자동 제련은 3초에 하나씩 찍어내므로 상한이
/// 없으면 세이브가 무한히 커진다 — 2026-07 의 곤충 3만 마리(13.6MB) 와
/// 같은 사고다. 가득 차면 자동 제련이 멈춘다.
const int kMaxForgeStack = 10;

/// 닉네임 기본값(설정에서 변경 가능).
const String kDefaultNickname = '채집가';

/// 결투 티켓 기본 보유량(신규·구버전 세이브는 만땅에서 시작).
///
/// 실제 상한·충전속도는 `battle.json → tickets`(§6). 여기 값은 필드가 없는
/// 세이브를 읽을 때의 **구조적 기본값**일 뿐이라 밸런스가 아니다.
const int kDefaultPvpTickets = 10;

/// 하루 시청 상한이 걸린 광고 기능의 키(= [SaveGame.adUseCounts] 의 키).
/// 지금은 결투 티켓 하나뿐 — 다른 보상형 광고는 구조적 상한이 이미 있다
/// (버프=누적 6h, 부화단축=알이 다 부화하면 끝, 일일보상=자체 제한).
const String kAdFeaturePvpTicket = 'pvpTicket';

/// 이벤트 참가권 광고(실물 경품 랭킹 이벤트). 상한은 event.json.
const String kAdFeatureEventTicket = 'eventTicket';

/// 설치된 트랩 1개 (레거시 v1 채집 시스템. v2 에서는 미사용이나 세이브 호환 위해 유지).
class TrapInstallation {
  const TrapInstallation({
    required this.slotIndex,
    required this.fieldId,
    required this.trapId,
    required this.installedAt,
  });

  final int slotIndex;
  final String fieldId;
  final String trapId;
  final DateTime installedAt;

  TrapInstallation copyWith({DateTime? installedAt}) => TrapInstallation(
    slotIndex: slotIndex,
    fieldId: fieldId,
    trapId: trapId,
    installedAt: installedAt ?? this.installedAt,
  );

  factory TrapInstallation.fromJson(Map<String, dynamic> json) =>
      TrapInstallation(
        slotIndex: (json['slotIndex'] as num).toInt(),
        fieldId: json['fieldId'] as String,
        trapId: json['trapId'] as String,
        installedAt: DateTime.parse(json['installedAt'] as String).toUtc(),
      );

  Map<String, dynamic> toJson() => {
    'slotIndex': slotIndex,
    'fieldId': fieldId,
    'trapId': trapId,
    'installedAt': installedAt.toUtc().toIso8601String(),
  };
}

/// 브리딩(§2.5) 진행 슬롯 — 산란 완료 시 부모 스냅샷으로 자식(알)을 롤한다.
/// 부모를 잠그지 않고 스냅샷만 저장(부모가 사라져도 알은 영향 없음).
class BreedingSlot {
  const BreedingSlot({
    required this.id,
    required this.speciesId,
    required this.parentAvgSizeMm,
    required this.motherPotential,
    required this.fatherPotential,
    required this.endsAt,
    required this.seed,
    this.motherElement,
    this.fatherElement,
    this.motherTemperament,
    this.fatherTemperament,
    this.motherTrait = BugTrait.none,
    this.fatherTrait = BugTrait.none,
  });

  final String id;
  final String speciesId;
  final double parentAvgSizeMm;
  final int motherPotential;
  final int fatherPotential;
  final DateTime endsAt;
  final int seed;

  // ── 부모 스냅샷(2026-08-15) ───────────────────────────────────
  //
  // 오행·기질·특성 상속(§2.5)에 필요하다. 부모를 잠그지 않는 설계라
  // 수령 시점엔 부모가 이미 없을 수 있으므로 **시작할 때 찍어 둔다**.
  //
  // ⚠️ null 이면 상속을 건너뛰고 예전처럼 랜덤이 된다 — 개편 전에 시작해
  // 아직 돌고 있는 슬롯이 수령 시점에 깨지지 않게 하기 위한 폴백이다.
  final Element? motherElement;
  final Element? fatherElement;
  final Temperament? motherTemperament;
  final Temperament? fatherTemperament;
  final BugTrait motherTrait;
  final BugTrait fatherTrait;

  factory BreedingSlot.fromJson(Map<String, dynamic> json) => BreedingSlot(
    id: json['id'] as String,
    speciesId: json['speciesId'] as String,
    parentAvgSizeMm: (json['parentAvgSizeMm'] as num).toDouble(),
    motherPotential: (json['motherPotential'] as num).toInt(),
    fatherPotential: (json['fatherPotential'] as num).toInt(),
    endsAt: DateTime.parse(json['endsAt'] as String).toUtc(),
    seed: (json['seed'] as num).toInt(),
    motherElement: _element(json['motherElement']),
    fatherElement: _element(json['fatherElement']),
    motherTemperament: _temperament(json['motherTemperament']),
    fatherTemperament: _temperament(json['fatherTemperament']),
    motherTrait: BugTrait.fromKey(json['motherTrait'] as String? ?? 'none'),
    fatherTrait: BugTrait.fromKey(json['fatherTrait'] as String? ?? 'none'),
  );

  /// 모르는 키는 null 로 — 구버전 앱이 신규 값을 만나도 세이브가 죽지 않는다.
  static Element? _element(Object? raw) {
    if (raw is! String) return null;
    for (final e in Element.values) {
      if (e.key == raw) return e;
    }
    return null;
  }

  static Temperament? _temperament(Object? raw) {
    if (raw is! String) return null;
    for (final t in Temperament.values) {
      if (t.key == raw) return t;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'speciesId': speciesId,
    'parentAvgSizeMm': parentAvgSizeMm,
    'motherPotential': motherPotential,
    'fatherPotential': fatherPotential,
    'endsAt': endsAt.toUtc().toIso8601String(),
    'seed': seed,
    if (motherElement != null) 'motherElement': motherElement!.key,
    if (fatherElement != null) 'fatherElement': fatherElement!.key,
    if (motherTemperament != null) 'motherTemperament': motherTemperament!.key,
    if (fatherTemperament != null) 'fatherTemperament': fatherTemperament!.key,
    if (motherTrait != BugTrait.none) 'motherTrait': motherTrait.key,
    if (fatherTrait != BugTrait.none) 'fatherTrait': fatherTrait.key,
  };

  /// 부모 스냅샷([mother]/[father])을 그대로 담은 슬롯을 만든다.
  ///
  /// 앱·서버가 각자 필드를 채우면 한쪽만 오행을 안 찍는 사고가 난다
  /// — 그러면 그 유저는 영원히 "상속이 안 되는" 짝짓기를 하게 된다.
  factory BreedingSlot.from({
    required String id,
    required IndividualBug mother,
    required IndividualBug father,
    required DateTime endsAt,
    required int seed,
  }) => BreedingSlot(
    id: id,
    speciesId: mother.speciesId,
    parentAvgSizeMm: (mother.sizeMm + father.sizeMm) / 2,
    motherPotential: mother.potential,
    fatherPotential: father.potential,
    endsAt: endsAt,
    seed: seed,
    motherElement: mother.element,
    fatherElement: father.element,
    motherTemperament: mother.temperament,
    fatherTemperament: father.temperament,
    motherTrait: mother.trait,
    fatherTrait: father.trait,
  );

  /// 이 슬롯에서 자식(알) 하나를 롤한다.
  ///
  /// **앱과 서버가 같은 함수를 쓴다** — 공식이 두 벌이면 "앱에선 화 속성인데
  /// 서버가 준 건 수 속성"처럼 조용히 갈린다. 결정론: 같은 [seed] → 같은 자식.
  IndividualBug hatch({
    required String id,
    required Species species,
    required PetConfig cfg,
  }) => IndividualBug.breed(
    id: id,
    species: species,
    rng: Random(seed),
    parentAvgSizeMm: parentAvgSizeMm,
    motherPotential: motherPotential,
    fatherPotential: fatherPotential,
    sizeVariancePct: cfg.breedingSizeVariancePct,
    mutationChance: cfg.breedingMutationChance,
    mutationBonusPct: cfg.breedingMutationBonusPct,
    potUpChance: cfg.breedingPotUpChance,
    potDownChance: cfg.breedingPotDownChance,
    motherElement: motherElement,
    fatherElement: fatherElement,
    motherTemperament: motherTemperament,
    fatherTemperament: fatherTemperament,
    motherTrait: motherTrait,
    fatherTrait: fatherTrait,
    elementInheritChance: cfg.breedingElementInherit,
    temperamentInheritChance: cfg.breedingTemperamentInherit,
    traitInheritChance: cfg.breedingTraitInherit,
    traitNewChance: cfg.breedingTraitNew,
    traitWeights: cfg.traitWeights,
  );
}

/// 도감(§2.1) 한 종의 기록.
///
/// 왜 세이브에 두는가: 곤충은 분해·방생으로 **사라진다**. 보유 곤충만 보면
/// "예전에 100mm 짜리를 잡았다"가 남지 않아, 수집 게임인데 수집한 흔적이
/// 없어진다. 도감은 곤충이 없어져도 남는 **영구 기록**이다.
///
/// 크기: 20종 × 이 레코드라 세이브 부담이 없다(§2.1 의 3만 마리 사고와 다름).
/// 발견하지 않은 종은 아예 저장하지 않는다.
@immutable
class DexEntry {
  const DexEntry({
    this.maxSizeMm = 0,
    this.maxPotential = 0,
    this.raisedToAdult = false,
  });

  /// 이 종으로 잡은 **역대 최대 크기**(mm). 곤충 게임의 원초적 자랑거리다.
  final double maxSizeMm;

  /// 역대 최고 포텐셜.
  final int maxPotential;

  /// 성충까지 키운 적이 있는가(= '정복'). 도감 보상의 기준.
  final bool raisedToAdult;

  /// 이 기록을 [other] 로 갱신한 결과(각 항목의 최대치만 남긴다).
  DexEntry merge({double sizeMm = 0, int potential = 0, bool adult = false}) =>
      DexEntry(
        maxSizeMm: sizeMm > maxSizeMm ? sizeMm : maxSizeMm,
        maxPotential: potential > maxPotential ? potential : maxPotential,
        raisedToAdult: raisedToAdult || adult,
      );

  factory DexEntry.fromJson(Map<String, dynamic> json) => DexEntry(
    maxSizeMm: (json['s'] as num?)?.toDouble() ?? 0,
    maxPotential: (json['p'] as num?)?.toInt() ?? 0,
    raisedToAdult: json['a'] as bool? ?? false,
  );

  /// 키를 한 글자로 줄인다 — 20종 × 3필드라 작지만, 세이브는 60초마다
  /// 통째로 업로드되므로 습관적으로 아낀다(§3).
  Map<String, dynamic> toJson() => {
    if (maxSizeMm > 0) 's': maxSizeMm,
    if (maxPotential > 0) 'p': maxPotential,
    if (raisedToAdult) 'a': true,
  };
}

/// 보유 곤충 전체를 훑어 도감을 갱신한 결과. 바뀐 게 없으면 [current] 를 **그대로**
/// 돌려준다(같은 인스턴스) — 호출부가 `identical` 로 불필요한 저장·업로드를 건너뛴다.
///
/// [stageOf] 는 개체의 **실제 도달 단계**를 주는 콜백이다. 단계 계산은 경과시간
/// 기반이라 `core_run`(PetConfig) 이 필요한데, core_save 는 그 시각·설정을
/// 갖고 있지 않으므로 호출부가 넘긴다.
Map<String, DexEntry> updatedDex({
  required Map<String, DexEntry> current,
  required Iterable<IndividualBug> bugs,
  required LifeStage Function(IndividualBug) stageOf,
}) {
  Map<String, DexEntry>? next;
  for (final b in bugs) {
    final before = (next ?? current)[b.speciesId] ?? const DexEntry();
    final after = before.merge(
      sizeMm: b.sizeMm,
      potential: b.potential,
      adult: stageOf(b) == LifeStage.adult,
    );
    if (after.maxSizeMm == before.maxSizeMm &&
        after.maxPotential == before.maxPotential &&
        after.raisedToAdult == before.raisedToAdult &&
        current.containsKey(b.speciesId)) {
      continue; // 이미 기록된 것보다 나을 게 없다
    }
    next ??= Map<String, DexEntry>.from(current);
    next[b.speciesId] = after;
  }
  return next ?? current;
}

/// 채집함 상한 정리에 필요한 곤충 1마리의 최소 정보.
typedef BugTrimEntry = ({
  String id,
  int level,
  int tier,
  int potential,
  double size,
});

/// 채집함 상한([capacity])을 넘겼을 때 **남길 곤충 id** 집합.
///
/// [pinned](장착·부화 중)은 무조건 남긴다. 나머지는 **플레이어가 투자한 순서**로
/// 남긴다 — 수련 레벨 > 돌파 티어 > 포텐셜 > 사이즈. 골드·재료를 쏟은 개체가
/// 먼저 사라지면 그게 곧 클레임이 된다.
///
/// 앱(마이그레이션)과 서버(업로드 강제)가 **같은 결과**를 내야 하므로 정리
/// 기준은 이 함수 하나로만 정의한다.
Set<String> keepBugIds(
  List<BugTrimEntry> entries, {
  required int capacity,
  Set<String> pinned = const {},
}) {
  if (entries.length <= capacity) return {for (final e in entries) e.id};

  final pinnedHere = <String>{};
  final rest = <BugTrimEntry>[];
  for (final e in entries) {
    if (pinned.contains(e.id)) {
      pinnedHere.add(e.id);
    } else {
      rest.add(e);
    }
  }
  // 장착·부화 중만으로 상한을 넘는 극단 케이스(상한을 낮췄을 때) — 보호분만 남긴다.
  final room = capacity - pinnedHere.length;
  if (room <= 0) return pinnedHere;

  rest.sort((a, b) {
    var c = b.level.compareTo(a.level);
    if (c != 0) return c;
    c = b.tier.compareTo(a.tier);
    if (c != 0) return c;
    c = b.potential.compareTo(a.potential);
    if (c != 0) return c;
    c = b.size.compareTo(a.size);
    if (c != 0) return c;
    return a.id.compareTo(b.id); // 완전 동률이어도 결정론적으로.
  });
  return {...pinnedHere, for (final e in rest.take(room)) e.id};
}

/// 저장 루트 (버전드 JSON 스냅샷). v2: 횡스크롤 런 진행 상태 포함.
class SaveGame {
  const SaveGame({
    required this.schemaVersion,
    required this.bugs,
    required this.materials,
    required this.installations,
    required this.unlockedFieldIds,
    required this.createdAt,
    required this.lastSeen,
    required this.gold,
    required this.xp,
    required this.level,
    required this.upgradeLevels,
    required this.stageNumber,
    required this.nickname,
    required this.buffExpiry,
    required this.missionProgress,
    required this.missionClaims,
    required this.equippedBugIds,
    required this.dailyClaims,
    required this.gifts,
    required this.clearedChapters,
    this.dex = const {},
    this.claimedDex = const {},
    required this.incubatorCapacity,
    required this.incubating,
    this.breedCooldowns = const {},
    this.eventTickets = 0,
    this.eventTicketsAt,
    this.eventFatigue = const {},
    this.eventRoundId,
    this.eventBestWave = 0,
    this.eventBestScore = 0,
    required this.pvpTrophies,
    required this.injured,
    required this.claimedLeagues,
    this.nextGiftAt,
    this.seasonStartedAt,
    this.seasonPeakTrophies = 0,
    this.breeding = const [],
    this.breedingCapacity = 1,
    this.storageCapacity = kDefaultStorageCapacity,
    this.pvpTickets = kDefaultPvpTickets,
    this.ticketsAt,
    this.adUseCounts = const {},
    this.adUseDate,
    this.giftDoubleDate,
    this.giftDoubleCount = 0,
    this.lastReadNoticeId = 0,
    this.reviewAsked = false,
    this.adsRemoved = false,
    this.buffPassExpiresAt,
    this.starterBought = false,
    this.ownedSkins = const {},
    this.passExpiresAt,
    this.redeemedPurchases = const {},
    this.equippedItems = const {},
    this.forgeStack = const [],
    this.skillLevels = const {},
    this.equippedSkills = const [],
    this.forgeLevel = 0,
    this.forgeSteps = 0,
    this.forgeUpAt,
    this.autoForgeOptions = const {},
    this.autoForgeStopOnHit = true,
    this.blockedUserIds = const {},
    this.bugFilterMinGrade = Grade.common,
    this.nicknameSet = false,
    this.eventRewardRound,
    this.eventBadges = const {},
    this.unknownMaterials = const {},
    this.unknownUpgrades = const {},
  });

  final int schemaVersion;

  /// 보관함(수집 개체).
  final List<IndividualBug> bugs;

  /// 재료 인벤토리.
  final Map<MaterialKind, int> materials;

  /// **이 버전이 모르는** 재료 키 → 수량. 신버전이 재료를 추가한 세이브를
  /// 구버전 앱이 읽었을 때 그 수량을 잃지 않기 위한 통이다.
  ///
  /// ⚠️ 그냥 건너뛰면 크래시는 막지만, 60초 뒤 전체 업로드(`ServerSaveUploader`)가
  /// **없는 상태를 서버에 덮어써** 재료가 영구 소실된다. 읽어서 그대로 다시 쓴다.
  /// 게임 로직은 이 통을 보지 않는다 — 오직 보존용이다.
  final Map<String, int> unknownMaterials;

  /// **이 버전이 모르는** 업그레이드 키 → 레벨. 이유는 [unknownMaterials] 와 같다.
  final Map<String, int> unknownUpgrades;

  /// (레거시 v1) 설치된 트랩.
  final List<TrapInstallation> installations;

  /// 해금된 필드/지역 id.
  final Set<String> unlockedFieldIds;

  final DateTime createdAt;

  /// 마지막 활동(저장) 시각. 오프라인 정산 기준.
  final DateTime lastSeen;

  // --- v2 런 진행 ---
  /// 골드 (업그레이드 재화).
  final int gold;

  /// 현재 레벨 진행 경험치.
  final int xp;

  /// 캐릭터 레벨.
  final int level;

  /// 능력치 업그레이드 레벨.
  final Map<UpgradeKind, int> upgradeLevels;

  /// 현재 도달 스테이지 (지역1 기준 1-based).
  final int stageNumber;

  /// 플레이어 표시 이름.
  final String nickname;

  /// 닉네임을 (기본값에서) 실제로 한 번 이상 확정했는지.
  /// 첫 설정은 무료, 이후 변경은 유료(젤리) — see SaveController.renamePlayer.
  final bool nicknameSet;

  /// 활성 버프별 만료 UTC 시각. now 이후면 활성으로 취급.
  final Map<BuffKind, DateTime> buffExpiry;

  /// 미션 id별 진행 카운터(카운터형 미션. reachStage 는 stageNumber 파생이라 미저장).
  final Map<String, int> missionProgress;

  /// 미션 id별 수집(클레임) 횟수 = 현재 티어.
  final Map<String, int> missionClaims;

  /// 장착한 애완펫(곤충) id 목록 (최대 3). 캐릭터 스탯 보너스.
  final List<String> equippedBugIds;

  bool isEquipped(String bugId) => equippedBugIds.contains(bugId);

  /// 일일보상 슬롯별 마지막 수령 로컬 날짜('yyyy-MM-dd').
  final Map<String, String> dailyClaims;

  String? dailyClaimedDate(String slotId) => dailyClaims[slotId];

  /// 편지함에 쌓인 깜짝 선물(만료 전).
  final List<GiftMail> gifts;

  /// 다음 깜짝 선물 예정 UTC 시각(온라인 중 도달 시 지급).
  final DateTime? nextGiftAt;

  /// 첫 클리어 보상을 이미 받은 로드맵 챕터 id 집합.
  final Set<String> clearedChapters;

  /// 도감(§2.1) — 종 id → 역대 기록. **발견한 종만** 들어 있다.
  ///
  /// 보유 곤충에서 파생되는 집계라 별도 갱신 지점이 없다 —
  /// `SaveController._commit` 이 저장할 때마다 훑어서 채운다. 그래서
  /// 획득 경로(실시간 처치·오프라인 정산·짝짓기·서버 세이브 채택)를
  /// 하나도 빠뜨리지 않는다.
  final Map<String, DexEntry> dex;

  /// 이미 받은 도감 마일스톤 id 집합(`DexMilestone.id`). 중복 수령 방지.
  final Set<String> claimedDex;

  /// 도감에 등록된(=한 번이라도 보유한) 종 수.
  int get dexDiscovered => dex.length;

  /// 성충까지 키운 종 수(= '정복'). 도감 보상의 기준.
  int get dexConquered => dex.values.where((e) => e.raisedToAdult).length;

  /// 도감 전체에서의 **역대 최대 크기**(mm). 사이즈 랭킹의 근거.
  double get dexBestSizeMm {
    var best = 0.0;
    for (final e in dex.values) {
      if (e.maxSizeMm > best) best = e.maxSizeMm;
    }
    return best;
  }

  /// 부화기 슬롯 개수(젤리로 확장).
  final int incubatorCapacity;

  /// 부화기에서 부화 중인 알: bugId → 부화 완료 UTC 시각.
  final Map<String, DateTime> incubating;

  /// 짝짓기에 쓴 부모의 **재사용 가능 시각**: bugId → UTC.
  ///
  /// 부모는 짝짓기 중에도 잠기지 않으므로(스냅샷 저장), 텀이 없으면 잘 뽑힌
  /// 한 쌍만 만들어 두고 같은 급 자식을 슬롯이 도는 속도만큼 계속 찍어낼 수
  /// 있다. 스탯이 무한히 오르진 않지만(사이즈는 종 상한, 포텐셜은 5성 천장)
  /// 천장 개체가 소모품이 되어 **희소성이 사라진다**.
  ///
  /// 기본값 `{}` 인 **호환 필드**라 스키마 버전을 올리지 않는다 — 구버전 앱은
  /// 이 값을 모른 채 그대로 보존한다.
  final Map<String, DateTime> breedCooldowns;

  // ── 실물 경품 랭킹 이벤트(웨이브 방어전) ──────────────────────
  //
  // ⚠️ 아래 6개는 전부 **서버 소유 필드**다(`GameActions._serverOwnedKeys`).
  // 순위가 그대로 실물 상품이 되므로, 세이브를 고쳐 참가권을 채우거나 피로를
  // 지우면 이벤트가 통째로 무의미해진다 — 결투 티켓과 같은 이유(§2.7).
  // 앱에 있는 값은 **화면에 보여주기 위한 사본**이고, 어긋나면 서버가 옳다.

  /// 남은 대회 참가권.
  final int eventTickets;

  /// 마지막으로 일일 참가권을 지급받은 시각(UTC).
  final DateTime? eventTicketsAt;

  /// 출전 피로: bugId → **재출전 가능 시각**(UTC).
  final Map<String, DateTime> eventFatigue;

  /// 지금 기록이 속한 회차 키(`2026-W34`). 회차가 바뀌면 기록을 0 으로 본다.
  final String? eventRoundId;

  /// 이번 회차 최고 도달 웨이브 / 최고 점수(표시용 사본).
  final int eventBestWave;
  final int eventBestScore;

  /// **회차 종료 보상을 받은** 회차 id. 같은 회차를 두 번 받지 못하게 한다.
  ///
  /// 회차마다 하나씩만 기억하면 되는 이유: 지난 회차 보상은 **다음 회차가 열리기
  /// 전에** 받게 되어 있고(접속하면 바로 판정), 그보다 더 오래 안 켠 사람은
  /// 그 사이 회차가 이미 지나가 순위 조회 대상이 아니다.
  ///
  /// ⚠️ **서버 소유 필드**여야 한다 — 세이브를 고쳐 지우면 같은 회차 보상을
  /// 반복해서 받을 수 있다(`GameActions._serverOwnedKeys`).
  final String? eventRewardRound;

  /// 대회 회차 뱃지(`champion:1`). 순위표에서 닉네임 옆에 붙는 표식이다.
  ///
  /// **실물을 받을 수 없는 해외 이용자에게 등가를 맞추는 축**이라, 세이브에만
  /// 있으면 의미가 없다 — 남이 봐야 자랑거리다. 서버가 지급하면서 `profiles`
  /// 에도 대표 뱃지를 써 순위표에 실린다.
  ///
  /// ⚠️ **서버 소유 필드**다. 세이브를 고쳐 챔피언 뱃지를 달 수 있으면
  /// 표식의 값어치가 통째로 사라진다.
  final Set<String> eventBadges;

  /// [bugId] 가 [now] 기준으로 아직 출전 피로 중인가.
  bool eventOnFatigue(String bugId, DateTime now) {
    final until = eventFatigue[bugId];
    return until != null && now.isBefore(until);
  }

  /// 만료된 피로를 걷어낸 맵 — 세이브가 무한히 커지지 않게 한다.
  Map<String, DateTime> prunedEventFatigue(DateTime now) => {
    for (final e in eventFatigue.entries)
      if (now.isBefore(e.value)) e.key: e.value,
  };

  /// [roundId] 기준 최고 기록(회차가 다르면 0 — 지난 회차 기록을 끌고 오지 않는다).
  int eventBestScoreIn(String roundId) =>
      eventRoundId == roundId ? eventBestScore : 0;

  /// [bugId] 가 [now] 기준으로 아직 짝짓기 쿨다운 중인가.
  bool breedOnCooldown(String bugId, DateTime now) {
    final until = breedCooldowns[bugId];
    return until != null && now.isBefore(until);
  }

  /// 만료된 쿨다운을 걷어낸 맵 — 세이브가 무한히 커지지 않게 한다.
  Map<String, DateTime> prunedBreedCooldowns(DateTime now) => {
    for (final e in breedCooldowns.entries)
      if (now.isBefore(e.value)) e.key: e.value,
  };

  /// 비동기 PvP(곤충 결투) 트로피 점수.
  final int pvpTrophies;

  /// 결투에서 KO된 곤충: bugId → 회복 완료 UTC 시각. 회복 전엔 결투 편성 불가.
  final Map<String, DateTime> injured;

  /// 승급 보상을 이미 받은 리그 id 집합(리그당 1회).
  final Set<String> claimedLeagues;

  /// 현재 시즌 시작 UTC 시각. null이면 로드 시 now로 초기화.
  final DateTime? seasonStartedAt;

  /// 이번 시즌 최고 도달 트로피(시즌 보상 산정 기준).
  final int seasonPeakTrophies;

  /// 진행 중인 브리딩 슬롯(산란 타이머).
  final List<BreedingSlot> breeding;

  /// 브리딩 슬롯 개수(젤리로 확장).
  final int breedingCapacity;

  /// 채집함 칸 수 = 보유 가능한 곤충 최대 마리 수(젤리로 확장, pets.json 상한).
  ///
  /// 가득 차면 새 곤충은 **획득되지 않는다**(드롭 스킵). 이 상한이 세이브
  /// 크기의 유일한 방어선이다 — §2.1, [kDefaultStorageCapacity] 주석 참조.
  final int storageCapacity;

  /// 보유 곤충이 칸 수를 채웠는지(= 새 곤충을 받을 수 없음).
  bool get storageFull => bugs.length >= storageCapacity;

  /// 남은 채집함 칸 수(0 이상).
  int get storageFree {
    final free = storageCapacity - bugs.length;
    return free < 0 ? 0 : free;
  }

  /// 채집함에 **받을 최소 등급**. [Grade.common] 이면 전부 받는다(기본).
  ///
  /// 미달 등급은 채집함에 들어오지 않고 **자동 방생**되어 재료로 환산된다
  /// (§2.1). 칸이 50~100개뿐이라, 필터가 없으면 후반에 일반 곤충이 칸을
  /// 채워 정작 쓸 개체가 안 들어온다 — 그때마다 손으로 분해해야 했다.
  ///
  /// ⚠️ 보상을 **젤리로 주지 않는다.** 젤리는 프리미엄 재화(§2.6)라, 자동으로
  /// 찍히면 방치만 해도 젤리가 쌓여 IAP 가 무의미해진다. 손으로 하는 분해
  /// (`disassembleBug`)는 젤리 그대로 — 그쪽은 사람의 손이 병목이라 안전하다.
  final Grade bugFilterMinGrade;

  /// 이 등급의 곤충을 채집함에 넣을지. false 면 자동 방생 대상.
  bool acceptsGrade(Grade g) => g.index >= bugFilterMinGrade.index;

  /// 도감 JSON → 맵. 모양이 어긋난 항목은 조용히 버린다 — 도감은 **파생
  /// 집계**라 잘못 저장돼도 다음 커밋에 다시 채워진다. 세이브가 안 열리는
  /// 것보다 낫다([[bugchamp-save-parser-hardening]] 과 같은 원칙).
  static Map<String, DexEntry> _dexFromJson(Object? raw) {
    if (raw is! Map) return const {};
    final out = <String, DexEntry>{};
    for (final e in raw.entries) {
      final k = e.key;
      final v = e.value;
      if (k is! String || v is! Map) continue;
      out[k] = DexEntry.fromJson(Map<String, dynamic>.from(v));
    }
    return out;
  }

  /// 등급 키 → [Grade]. 모르는 값이면 [Grade.common](= 필터 없음).
  static Grade _gradeOrCommon(Object? raw) {
    if (raw is! String) return Grade.common;
    for (final g in Grade.values) {
      if (g.key == raw) return g;
    }
    return Grade.common;
  }

  /// 장착 중이거나 부화기에 들어 있어 **상한 정리에서 보호되는** 곤충 id.
  Set<String> get pinnedBugIds => {...equippedBugIds, ...incubating.keys};

  /// 곤충 목록을 [storageCapacity] 이하로 줄인 세이브(초과분 폐기).
  ///
  /// 상한 내면 자기 자신을 그대로 돌려준다. 구버전 앱·조작된 업로드가 상한을
  /// 넘긴 세이브를 올려도 서버가 이걸로 잘라 세이브 비대화를 원천 차단한다.
  SaveGame trimmedToStorage() {
    if (bugs.length <= storageCapacity) return this;
    final keep = keepBugIds(
      [
        for (final b in bugs)
          (
            id: b.id,
            level: b.level,
            tier: b.breakthroughTier,
            potential: b.potential,
            size: b.sizeMm,
          ),
      ],
      capacity: storageCapacity,
      pinned: pinnedBugIds,
    );
    return copyWith(
      bugs: [
        for (final b in bugs)
          if (keep.contains(b.id)) b,
      ],
    );
  }

  // ── 결투 티켓(2026-08) ──
  //
  // **스키마 버전을 올리지 않았다** — `storageCapacity` 와 같은 이유다.
  // 없으면 기본값으로 읽히는 호환 필드라 구/신 버전이 서로의 세이브를 그대로
  // 읽는다. 버전을 올리면 서버가 새 세이브를 저장하는 순간 스토어의 구버전
  // 앱이 "다운그레이드 불가"로 죽는다(kDefaultStorageCapacity 주석 참조).

  /// 남은 결투 티켓. **화면에 쓸 값은 이 필드가 아니라** `regenTickets(...)` 의
  /// 결과다 — 저장된 값은 [ticketsAt] 이후 충전분이 반영되지 않은 원본이다.
  ///
  /// 서버 소유 필드(`GameActions._serverOwnedKeys`) — 세이브를 편집해 판수를
  /// 늘리면 티켓 제한 자체가 무의미해지므로 업로드 때 서버 값으로 덮는다.
  final int pvpTickets;

  /// 자연 충전 기준시각(UTC). null이면 "지금부터" 로 취급한다.
  final DateTime? ticketsAt;

  // ── 장비 · 공방 · 스킬 (2026-08) ─────────────────────────────
  //
  // **스키마 버전을 올리지 않는다.** 없으면 기본값으로 읽히는 호환 필드다 —
  // 올리면 서버가 새 세이브를 저장하는 순간 스토어의 구버전 앱이
  // "다운그레이드 불가"로 죽는다.

  /// 부위별로 **낀 것 1개**. 가방이 없으므로 세이브에 남는 장비는 최대 8개다
  /// — 제련은 초당 수십 개를 찍어낼 수 있어, 다 저장했다면 2026-07 의
  /// 세이브 비대화(곤충 3만 마리 = 13.6MB)가 그대로 재현됐을 것이다.
  final Map<EquipSlot, EquipItem> equippedItems;

  /// 모루 위에 쌓인 **아직 안 본** 제련 결과. 최대 [kMaxForgeStack] 개.
  final List<EquipItem> forgeStack;

  /// 보유한 스킬의 레벨(`skillId` → 레벨). 없으면 미보유.
  final Map<String, int> skillLevels;

  /// 장착한 스킬 id 5칸. **액티브·패시브 공용** — 칸을 나누면 선택이 사라진다.
  final List<String> equippedSkills;

  /// 공방 등급(0부터). 등급 확률 창의 위치를 정한다.
  final int forgeLevel;

  /// 다음 등급업에 부어둔 골드 **칸 수**(0~`levelUpSteps`).
  /// 한 번에 다 못 내도 조금씩 부어둘 수 있게 나눠 받는다.
  final int forgeSteps;

  /// 칸을 다 채운 뒤 등급업이 끝나는 시각(UTC). null 이면 진행 중이 아니다.
  final DateTime? forgeUpAt;

  /// 자동 제련이 노리는 옵션. 비어 있으면 전투력 비교만 한다.
  final Set<ItemOptionKind> autoForgeOptions;

  /// 목표를 찾으면 멈춘다. **기본값 true** — 아니면 원하는 걸 뽑고도
  /// 화석 조각을 계속 태운다.
  final bool autoForgeStopOnHit;

  /// 하루 상한이 걸린 광고의 기능별 오늘 시청 횟수([kAdFeaturePvpTicket] 등).
  /// [adUseDate] 가 오늘이 아니면 전부 0으로 본다(날짜가 바뀌면 자동 리셋).
  final Map<String, int> adUseCounts;

  /// [adUseCounts] 가 기록된 날짜('yyyy-MM-dd', 로컬 기준 `dailyDateKey`).
  final String? adUseDate;

  /// 깜짝선물 **무료 2배**를 오늘 몇 번 썼는지 — [giftDoubleDate] 기준.
  ///
  /// ⚠️ [adUseCounts] 에 넣으면 안 된다. 그 맵은 **서버 소유 필드**라(티켓 광고
  /// 위조 방지) 업로드 병합 때 서버 값으로 통째로 덮이는데, 선물 수령은 서버를
  /// 거치지 않아 서버가 이 카운트를 모른다 — 매 업로드마다 리셋되어 하루 상한이
  /// 무력해진다(출시 전 감사에서 발견 2026-08-20).
  final String? giftDoubleDate;
  final int giftDoubleCount;

  /// 오늘 무료 2배를 몇 번 썼는가(날짜가 다르면 0).
  int giftDoublesUsed(String today) =>
      giftDoubleDate == today ? giftDoubleCount : 0;

  /// [today] 기준 [feature] 광고를 오늘 몇 번 봤는지(날짜가 다르면 0).
  int adUseCount(String feature, String today) =>
      adUseDate == today ? (adUseCounts[feature] ?? 0) : 0;

  // ── 공지 · 리뷰(2026-08-07) ──

  /// 마지막으로 읽은 공지 id. 이 값보다 큰 id 가 있으면 "새 공지"다.
  ///
  /// 읽은 id 집합이 아니라 **최댓값 하나만** 쓴다 — 공지 id 는 증가하는
  /// 일련번호라 이걸로 충분하고, 집합은 해가 갈수록 세이브에 계속 쌓인다.
  final int lastReadNoticeId;

  /// 스토어 리뷰를 이미 한 번 요청했는지(중복 요청 방지).
  ///
  /// ⚠️ **리뷰 작성 여부가 아니다.** 스토어 API 는 유저가 실제로 썼는지,
  /// 별점이 몇 개인지 앱에 알려주지 않는다. 그래서 리뷰에 보상을 걸 수 없고
  /// (걸어도 검증 불가), 플레이·앱스토어 정책도 이를 금지한다.
  final bool reviewAsked;

  /// [noticeId] 가 아직 안 읽은 새 공지인지.
  bool isNewNotice(int noticeId) => noticeId > lastReadNoticeId;

  // ── 인앱결제 상태(v16) ──
  /// 광고 제거 구매 여부(강제 광고만 제거, 보상형 광고는 유지).
  final bool adsRemoved;

  /// 무한 버프 패스 만료 시각(UTC). null/과거면 없음.
  ///
  /// 곤충학자 패스(`passExpiresAt`)와 **별도 상품**이라 칸을 나눈다 — 하나로
  /// 합치면 한쪽만 산 사람에게 다른 쪽 혜택이 딸려간다.
  final DateTime? buffPassExpiresAt;

  /// 스타터 패키지 구매 여부(계정당 1회).
  final bool starterBought;

  /// 보유 스킨 id 집합(코스메틱 — 스탯 영향 없음).
  final Set<String> ownedSkins;

  /// 곤충학자 패스 만료 시각(UTC). null/과거면 미보유.
  final DateTime? passExpiresAt;

  /// 이미 지급 처리한 스토어 구매 식별자들(중복 지급 방지).
  ///
  /// 스토어 구매는 **스트림으로 여러 번 전달될 수 있다**(앱 재시작 시 미완료
  /// 구매 재전달, `restorePurchases()` 재전달 등). 지급 전에 여기 있는지
  /// 확인하고, 지급 후 추가한다. 소모성(젤리)도 구매마다 식별자가 달라
  /// 재구매는 정상 동작한다.
  final Set<String> redeemedPurchases;

  /// 채팅에서 차단한 사용자 id 집합.
  ///
  /// 차단은 **기기 로컬**로 처리한다 — 차단당한 쪽이 알 수 없고(보복 방지),
  /// 서버 왕복 없이 즉시 반영된다. 구글 플레이 UGC 정책의 '차단 수단' 요건.
  /// 닉네임이 아니라 계정 id 기준(닉네임은 바꿀 수 있으므로).
  final Set<String> blockedUserIds;

  /// [userId] 의 메시지를 숨겨야 하는지.
  bool isBlocked(String userId) => blockedUserIds.contains(userId);

  /// [now] 기준 패스가 유효한지.
  bool passActive(DateTime now) =>
      passExpiresAt != null && now.isBefore(passExpiresAt!);

  /// 강제 광고를 숨겨야 하는지(광고제거 구매 또는 패스 보유).
  bool adsHidden(DateTime now) => adsRemoved || passActive(now);

  /// 무한 버프 패스가 살아 있는가.
  bool buffPassActive(DateTime now) =>
      buffPassExpiresAt != null && buffPassExpiresAt!.isAfter(now);

  /// 패스(곤충학자 또는 무한버프) 보유자인가.
  ///
  /// 깜짝선물 **자동수령 + 2배 무제한**의 기준이다. 둘 중 아무거나 있으면
  /// 적용한다 — 하나만 산 사람이 "왜 나는 안 되지"를 겪지 않게.
  bool anyPassActive(DateTime now) => passActive(now) || buffPassActive(now);

  int missionClaimCount(String id) => missionClaims[id] ?? 0;
  int missionProgressCount(String id) => missionProgress[id] ?? 0;

  /// [bugId] 의 회복 완료 시각(부상 중이 아니면 null).
  DateTime? injuredUntil(String bugId) => injured[bugId];

  /// [now] 기준 [bugId] 가 아직 회복 중인지.
  bool isInjured(String bugId, DateTime now) {
    final until = injured[bugId];
    return until != null && now.isBefore(until);
  }

  factory SaveGame.initial({DateTime? createdAt}) => SaveGame(
    schemaVersion: kSaveSchemaVersion,
    bugs: const [],
    materials: const {},
    installations: const [],
    unlockedFieldIds: const {'oak_forest'},
    createdAt: (createdAt ?? DateTime.now()).toUtc(),
    lastSeen: (createdAt ?? DateTime.now()).toUtc(),
    gold: 0,
    xp: 0,
    level: 1,
    upgradeLevels: const {},
    stageNumber: 1,
    nickname: kDefaultNickname,
    buffExpiry: const {},
    missionProgress: const {},
    missionClaims: const {},
    equippedBugIds: const [],
    dailyClaims: const {},
    gifts: const [],
    clearedChapters: const {},
    dex: const {},
    claimedDex: const {},
    incubatorCapacity: 1,
    incubating: const {},
    breedCooldowns: const {},
    eventTickets: 0,
    eventFatigue: const {},
    pvpTrophies: 0,
    injured: const {},
    claimedLeagues: const {},
    seasonStartedAt: (createdAt ?? DateTime.now()).toUtc(),
    seasonPeakTrophies: 0,
    breeding: const [],
    breedingCapacity: 1,
    storageCapacity: kDefaultStorageCapacity,
    pvpTickets: kDefaultPvpTickets,
    ticketsAt: (createdAt ?? DateTime.now()).toUtc(),
    adUseCounts: const {},
    giftDoubleCount: 0,
    equippedItems: const {},
    forgeStack: const [],
    skillLevels: const {},
    equippedSkills: const [],
    forgeLevel: 0,
    forgeSteps: 0,
    autoForgeOptions: const {},
    autoForgeStopOnHit: true,
    adsRemoved: false,
    buffPassExpiresAt: null,
    starterBought: false,
    ownedSkins: const {},
    redeemedPurchases: const {},
    blockedUserIds: const {},
    bugFilterMinGrade: Grade.common,
  );

  SaveGame copyWith({
    List<IndividualBug>? bugs,
    Map<MaterialKind, int>? materials,
    List<TrapInstallation>? installations,
    Set<String>? unlockedFieldIds,
    DateTime? lastSeen,
    int? gold,
    int? xp,
    int? level,
    Map<UpgradeKind, int>? upgradeLevels,
    int? stageNumber,
    String? nickname,
    bool? nicknameSet,
    Map<BuffKind, DateTime>? buffExpiry,
    Map<String, int>? missionProgress,
    Map<String, int>? missionClaims,
    List<String>? equippedBugIds,
    Map<String, String>? dailyClaims,
    List<GiftMail>? gifts,
    DateTime? nextGiftAt,
    Set<String>? clearedChapters,
    Map<String, DexEntry>? dex,
    Set<String>? claimedDex,
    int? incubatorCapacity,
    Map<String, DateTime>? incubating,
    Map<String, DateTime>? breedCooldowns,
    int? eventTickets,
    DateTime? eventTicketsAt,
    Map<String, DateTime>? eventFatigue,
    String? eventRoundId,
    int? eventBestWave,
    int? eventBestScore,
    String? eventRewardRound,
    Set<String>? eventBadges,
    int? pvpTrophies,
    Map<String, DateTime>? injured,
    Set<String>? claimedLeagues,
    DateTime? seasonStartedAt,
    int? seasonPeakTrophies,
    List<BreedingSlot>? breeding,
    int? breedingCapacity,
    int? storageCapacity,
    int? pvpTickets,
    DateTime? ticketsAt,
    Map<String, int>? adUseCounts,
    String? giftDoubleDate,
    int? giftDoubleCount,
    String? adUseDate,
    Map<EquipSlot, EquipItem>? equippedItems,
    List<EquipItem>? forgeStack,
    Map<String, int>? skillLevels,
    List<String>? equippedSkills,
    int? forgeLevel,
    int? forgeSteps,
    DateTime? forgeUpAt,
    bool clearForgeUpAt = false,
    Set<ItemOptionKind>? autoForgeOptions,
    bool? autoForgeStopOnHit,
    int? lastReadNoticeId,
    bool? reviewAsked,
    bool? adsRemoved,
    DateTime? buffPassExpiresAt,
    bool? starterBought,
    Set<String>? ownedSkins,
    DateTime? passExpiresAt,
    Set<String>? redeemedPurchases,
    Set<String>? blockedUserIds,
    Grade? bugFilterMinGrade,
    Map<String, int>? unknownMaterials,
    Map<String, int>? unknownUpgrades,
  }) => SaveGame(
    schemaVersion: schemaVersion,
    bugs: bugs ?? this.bugs,
    materials: materials ?? this.materials,
    installations: installations ?? this.installations,
    unlockedFieldIds: unlockedFieldIds ?? this.unlockedFieldIds,
    createdAt: createdAt,
    lastSeen: lastSeen ?? this.lastSeen,
    gold: gold ?? this.gold,
    xp: xp ?? this.xp,
    level: level ?? this.level,
    upgradeLevels: upgradeLevels ?? this.upgradeLevels,
    stageNumber: stageNumber ?? this.stageNumber,
    nickname: nickname ?? this.nickname,
    nicknameSet: nicknameSet ?? this.nicknameSet,
    buffExpiry: buffExpiry ?? this.buffExpiry,
    missionProgress: missionProgress ?? this.missionProgress,
    missionClaims: missionClaims ?? this.missionClaims,
    equippedBugIds: equippedBugIds ?? this.equippedBugIds,
    dailyClaims: dailyClaims ?? this.dailyClaims,
    gifts: gifts ?? this.gifts,
    nextGiftAt: nextGiftAt ?? this.nextGiftAt,
    clearedChapters: clearedChapters ?? this.clearedChapters,
    dex: dex ?? this.dex,
    claimedDex: claimedDex ?? this.claimedDex,
    incubatorCapacity: incubatorCapacity ?? this.incubatorCapacity,
    incubating: incubating ?? this.incubating,
    breedCooldowns: breedCooldowns ?? this.breedCooldowns,
    eventTickets: eventTickets ?? this.eventTickets,
    eventTicketsAt: eventTicketsAt ?? this.eventTicketsAt,
    eventFatigue: eventFatigue ?? this.eventFatigue,
    eventRoundId: eventRoundId ?? this.eventRoundId,
    eventBestWave: eventBestWave ?? this.eventBestWave,
    eventBestScore: eventBestScore ?? this.eventBestScore,
    eventRewardRound: eventRewardRound ?? this.eventRewardRound,
    eventBadges: eventBadges ?? this.eventBadges,
    pvpTrophies: pvpTrophies ?? this.pvpTrophies,
    injured: injured ?? this.injured,
    claimedLeagues: claimedLeagues ?? this.claimedLeagues,
    seasonStartedAt: seasonStartedAt ?? this.seasonStartedAt,
    seasonPeakTrophies: seasonPeakTrophies ?? this.seasonPeakTrophies,
    breeding: breeding ?? this.breeding,
    breedingCapacity: breedingCapacity ?? this.breedingCapacity,
    storageCapacity: storageCapacity ?? this.storageCapacity,
    pvpTickets: pvpTickets ?? this.pvpTickets,
    ticketsAt: ticketsAt ?? this.ticketsAt,
    adUseCounts: adUseCounts ?? this.adUseCounts,
    giftDoubleDate: giftDoubleDate ?? this.giftDoubleDate,
    giftDoubleCount: giftDoubleCount ?? this.giftDoubleCount,
    adUseDate: adUseDate ?? this.adUseDate,
    equippedItems: equippedItems ?? this.equippedItems,
    forgeStack: forgeStack ?? this.forgeStack,
    skillLevels: skillLevels ?? this.skillLevels,
    equippedSkills: equippedSkills ?? this.equippedSkills,
    forgeLevel: forgeLevel ?? this.forgeLevel,
    forgeSteps: forgeSteps ?? this.forgeSteps,
    // 등급업이 끝나면 **null 로 지워야** 한다 — `??` 만으로는 못 지운다.
    forgeUpAt: clearForgeUpAt ? null : (forgeUpAt ?? this.forgeUpAt),
    autoForgeOptions: autoForgeOptions ?? this.autoForgeOptions,
    autoForgeStopOnHit: autoForgeStopOnHit ?? this.autoForgeStopOnHit,
    lastReadNoticeId: lastReadNoticeId ?? this.lastReadNoticeId,
    reviewAsked: reviewAsked ?? this.reviewAsked,
    adsRemoved: adsRemoved ?? this.adsRemoved,
    buffPassExpiresAt: buffPassExpiresAt ?? this.buffPassExpiresAt,
    starterBought: starterBought ?? this.starterBought,
    ownedSkins: ownedSkins ?? this.ownedSkins,
    passExpiresAt: passExpiresAt ?? this.passExpiresAt,
    redeemedPurchases: redeemedPurchases ?? this.redeemedPurchases,
    blockedUserIds: blockedUserIds ?? this.blockedUserIds,
    bugFilterMinGrade: bugFilterMinGrade ?? this.bugFilterMinGrade,
    unknownMaterials: unknownMaterials ?? this.unknownMaterials,
    unknownUpgrades: unknownUpgrades ?? this.unknownUpgrades,
  );

  int materialCount(MaterialKind kind) => materials[kind] ?? 0;

  int upgradeLevel(UpgradeKind kind) => upgradeLevels[kind] ?? 0;

  /// [now] 기준 활성(만료 전) 버프 종류들.
  ///
  /// **무한 버프 패스 보유 중이면 전부 활성**이다. 버프 효과를 읽는 곳이
  /// 여기 하나뿐이라(§ 화면·방치 계산 모두 이걸 본다), 여기서 한 번에 처리하면
  /// 지급 경로가 갈리지 않는다.
  Set<BuffKind> activeBuffs(DateTime now) => buffPassActive(now)
      ? BuffKind.values.toSet()
      : {
          for (final e in buffExpiry.entries)
            if (e.value.isAfter(now)) e.key,
        };

  /// [kind] 버프의 남은 시간([now] 기준). 비활성이면 null.
  ///
  /// 무한 패스 중에는 **패스 남은 기간**을 돌려준다 — 화면이 "무한"을 표현할
  /// 방법이 없으면 30분짜리처럼 보여서 계속 눌러 켜려 하게 된다.
  Duration? buffRemaining(BuffKind kind, DateTime now) {
    if (buffPassActive(now)) return buffPassExpiresAt!.difference(now);
    final exp = buffExpiry[kind];
    if (exp == null || !exp.isAfter(now)) return null;
    return exp.difference(now);
  }

  TrapInstallation? installationAt(int slotIndex) {
    for (final i in installations) {
      if (i.slotIndex == slotIndex) return i;
    }
    return null;
  }

  factory SaveGame.fromJson(Map<String, dynamic> json) => SaveGame(
    schemaVersion: (json['schemaVersion'] as num).toInt(),
    bugs: (json['bugs'] as List)
        .cast<Map<String, dynamic>>()
        .map(IndividualBug.fromJson)
        .toList(),
    materials: _materialsFromJson(json['materials'] as Map<String, dynamic>),
    unknownMaterials: _unknownIntsFromJson(
      json['materials'] as Map<String, dynamic>,
      (k) => MaterialKind.fromKeyOrNull(k) != null,
    ),
    installations: (json['installations'] as List)
        .cast<Map<String, dynamic>>()
        .map(TrapInstallation.fromJson)
        .toList(),
    unlockedFieldIds: (json['unlockedFieldIds'] as List).cast<String>().toSet(),
    createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
    lastSeen: json['lastSeen'] != null
        ? DateTime.parse(json['lastSeen'] as String).toUtc()
        : DateTime.parse(json['createdAt'] as String).toUtc(),
    // ⚠️ 재화는 읽을 때 **자른다**. int64 가 넘쳐 음수가 된 세이브(2026-08-30
    // 제보)를 그대로 읽으면 화면에 마이너스가 그대로 뜨고, 거기서 또 더하면
    // 계속 음수다. 여기서 0 으로 되돌려야 스스로 회복된다.
    gold: clampCurrency(json['gold'] as num),
    xp: clampCurrency(json['xp'] as num),
    level: (json['level'] as num).toInt(),
    upgradeLevels: _upgradesFromJson(
      json['upgradeLevels'] as Map<String, dynamic>,
    ),
    unknownUpgrades: _unknownIntsFromJson(
      json['upgradeLevels'] as Map<String, dynamic>,
      (k) => UpgradeKind.fromKeyOrNull(k) != null,
    ),
    stageNumber: (json['stageNumber'] as num).toInt(),
    nickname: json['nickname'] as String? ?? kDefaultNickname,
    // 신규 필드 — 기존 세이브가 커스텀 닉네임이면 확정으로 간주(재입력 방지).
    nicknameSet:
        json['nicknameSet'] as bool? ??
        (json['nickname'] as String? ?? kDefaultNickname) != kDefaultNickname,
    buffExpiry: _buffsFromJson(
      json['buffExpiry'] as Map<String, dynamic>? ?? const {},
    ),
    missionProgress: _intMapFromJson(
      json['missionProgress'] as Map<String, dynamic>? ?? const {},
    ),
    missionClaims: _intMapFromJson(
      json['missionClaims'] as Map<String, dynamic>? ?? const {},
    ),
    equippedBugIds:
        (json['equippedBugIds'] as List?)?.cast<String>().toList() ?? const [],
    dailyClaims:
        (json['dailyClaims'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, v as String),
        ) ??
        const {},
    gifts:
        (json['gifts'] as List?)
            ?.cast<Map<String, dynamic>>()
            .map(GiftMail.fromJson)
            .toList() ??
        const [],
    nextGiftAt: json['nextGiftAt'] == null
        ? null
        : DateTime.parse(json['nextGiftAt'] as String).toUtc(),
    clearedChapters:
        (json['clearedChapters'] as List?)?.cast<String>().toSet() ?? const {},
    dex: _dexFromJson(json['dex']),
    claimedDex:
        (json['claimedDex'] as List?)?.cast<String>().toSet() ?? const {},
    incubatorCapacity: (json['incubatorCapacity'] as num?)?.toInt() ?? 1,
    incubating:
        (json['incubating'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, DateTime.parse(v as String).toUtc()),
        ) ??
        const {},
    breedCooldowns:
        (json['breedCooldowns'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, DateTime.parse(v as String).toUtc()),
        ) ??
        const {},
    eventTickets: (json['eventTickets'] as num?)?.toInt() ?? 0,
    eventTicketsAt: json['eventTicketsAt'] == null
        ? null
        : DateTime.parse(json['eventTicketsAt'] as String).toUtc(),
    eventFatigue:
        (json['eventFatigue'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, DateTime.parse(v as String).toUtc()),
        ) ??
        const {},
    eventRoundId: json['eventRoundId'] as String?,
    eventBestWave: (json['eventBestWave'] as num?)?.toInt() ?? 0,
    eventBestScore: (json['eventBestScore'] as num?)?.toInt() ?? 0,
    eventRewardRound: json['eventRewardRound'] as String?,
    eventBadges:
        (json['eventBadges'] as List?)?.cast<String>().toSet() ?? const {},
    pvpTrophies: (json['pvpTrophies'] as num?)?.toInt() ?? 0,
    injured:
        (json['injured'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, DateTime.parse(v as String).toUtc()),
        ) ??
        const {},
    claimedLeagues:
        (json['claimedLeagues'] as List?)?.cast<String>().toSet() ?? const {},
    seasonStartedAt: json['seasonStartedAt'] == null
        ? null
        : DateTime.parse(json['seasonStartedAt'] as String).toUtc(),
    seasonPeakTrophies: (json['seasonPeakTrophies'] as num?)?.toInt() ?? 0,
    breeding:
        (json['breeding'] as List?)
            ?.cast<Map<String, dynamic>>()
            .map(BreedingSlot.fromJson)
            .toList() ??
        const [],
    breedingCapacity: (json['breedingCapacity'] as num?)?.toInt() ?? 1,
    storageCapacity:
        (json['storageCapacity'] as num?)?.toInt() ?? kDefaultStorageCapacity,
    pvpTickets: (json['pvpTickets'] as num?)?.toInt() ?? kDefaultPvpTickets,
    ticketsAt: json['ticketsAt'] == null
        ? null
        : DateTime.parse(json['ticketsAt'] as String).toUtc(),
    adUseCounts: _intMapFromJson(
      json['adUseCounts'] as Map<String, dynamic>? ?? const {},
    ),
    // 모르는 부위·옵션은 건너뛴다(구버전이 신버전 세이브를 읽어도 안 죽는다).
    equippedItems: {
      for (final e
          in (json['equippedItems'] as Map<String, dynamic>? ?? const {})
              .entries)
        if (EquipSlot.fromKeyOrNull(e.key) case final slot?)
          if (EquipItem.tryFromJson(Map<String, dynamic>.from(e.value as Map))
              case final item?)
            slot: item,
    },
    forgeStack: [
      for (final e in json['forgeStack'] as List<dynamic>? ?? const [])
        ?EquipItem.tryFromJson(Map<String, dynamic>.from(e as Map)),
    ],
    skillLevels: _intMapFromJson(
      json['skillLevels'] as Map<String, dynamic>? ?? const {},
    ),
    equippedSkills: [
      for (final v in (json['equippedSkills'] as List? ?? const []))
        v as String,
    ],
    forgeLevel: (json['forgeLevel'] as num?)?.toInt() ?? 0,
    forgeSteps: (json['forgeSteps'] as num?)?.toInt() ?? 0,
    forgeUpAt: json['forgeUpAt'] == null
        ? null
        : DateTime.parse(json['forgeUpAt'] as String).toUtc(),
    autoForgeOptions: {
      for (final v in (json['autoForgeOptions'] as List? ?? const []))
        ?ItemOptionKind.fromKeyOrNull(v as String),
    },
    autoForgeStopOnHit: json['autoForgeStopOnHit'] as bool? ?? true,
    adUseDate: json['adUseDate'] as String?,
    giftDoubleDate: json['giftDoubleDate'] as String?,
    giftDoubleCount: (json['giftDoubleCount'] as num?)?.toInt() ?? 0,
    lastReadNoticeId: (json['lastReadNoticeId'] as num?)?.toInt() ?? 0,
    reviewAsked: json['reviewAsked'] as bool? ?? false,
    adsRemoved: json['adsRemoved'] as bool? ?? false,
    buffPassExpiresAt: json['buffPassExpiresAt'] == null
        ? null
        : DateTime.parse(json['buffPassExpiresAt'] as String).toUtc(),
    starterBought: json['starterBought'] as bool? ?? false,
    ownedSkins:
        (json['ownedSkins'] as List?)?.cast<String>().toSet() ?? const {},
    redeemedPurchases:
        (json['redeemedPurchases'] as List?)?.cast<String>().toSet() ??
        const {},
    blockedUserIds:
        (json['blockedUserIds'] as List?)?.cast<String>().toSet() ?? const {},
    // 모르는 등급 키는 common(=필터 없음)으로 — 필터 때문에 세이브가 안 열리는
    // 일이 있어선 안 된다. 최악이라도 '전부 받는' 안전한 쪽으로 떨어진다.
    bugFilterMinGrade: _gradeOrCommon(json['bugFilterMinGrade']),
    passExpiresAt: json['passExpiresAt'] == null
        ? null
        : DateTime.parse(json['passExpiresAt'] as String).toUtc(),
  );

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'bugs': bugs.map((b) => b.toJson()).toList(),
    // 모르는 키도 그대로 되돌려준다 — 구버전이 신버전 세이브를 덮어써
    // 재료가 사라지는 걸 막는다(§unknownMaterials).
    'materials': {
      for (final e in materials.entries) e.key.key: e.value,
      ...unknownMaterials,
    },
    'installations': installations.map((i) => i.toJson()).toList(),
    'unlockedFieldIds': unlockedFieldIds.toList(),
    'createdAt': createdAt.toUtc().toIso8601String(),
    'lastSeen': lastSeen.toUtc().toIso8601String(),
    'gold': gold,
    'xp': xp,
    'level': level,
    'upgradeLevels': {
      for (final e in upgradeLevels.entries) e.key.key: e.value,
      ...unknownUpgrades,
    },
    'stageNumber': stageNumber,
    'nickname': nickname,
    'nicknameSet': nicknameSet,
    'buffExpiry': {
      for (final e in buffExpiry.entries)
        e.key.key: e.value.toUtc().toIso8601String(),
    },
    'missionProgress': missionProgress,
    'missionClaims': missionClaims,
    'equippedBugIds': equippedBugIds,
    'dailyClaims': dailyClaims,
    'gifts': gifts.map((g) => g.toJson()).toList(),
    if (nextGiftAt != null) 'nextGiftAt': nextGiftAt!.toUtc().toIso8601String(),
    'clearedChapters': clearedChapters.toList(),
    // 빈 도감은 키를 싣지 않는다 — 신규 유저 세이브가 괜히 커지지 않게.
    if (dex.isNotEmpty)
      'dex': {for (final e in dex.entries) e.key: e.value.toJson()},
    if (claimedDex.isNotEmpty) 'claimedDex': claimedDex.toList(),
    'incubatorCapacity': incubatorCapacity,
    'incubating': {
      for (final e in incubating.entries)
        e.key: e.value.toUtc().toIso8601String(),
    },
    if (breedCooldowns.isNotEmpty)
      'breedCooldowns': {
        for (final e in breedCooldowns.entries)
          e.key: e.value.toUtc().toIso8601String(),
      },
    // 이벤트 필드는 **참여자만** 싣는다 — 안 하는 유저의 세이브를 키우지 않는다.
    if (eventTickets > 0) 'eventTickets': eventTickets,
    if (eventTicketsAt != null)
      'eventTicketsAt': eventTicketsAt!.toUtc().toIso8601String(),
    if (eventFatigue.isNotEmpty)
      'eventFatigue': {
        for (final e in eventFatigue.entries)
          e.key: e.value.toUtc().toIso8601String(),
      },
    if (eventRoundId != null) 'eventRoundId': eventRoundId,
    if (eventBestWave > 0) 'eventBestWave': eventBestWave,
    if (eventBestScore > 0) 'eventBestScore': eventBestScore,
    if (eventRewardRound != null) 'eventRewardRound': eventRewardRound,
    if (eventBadges.isNotEmpty) 'eventBadges': eventBadges.toList(),
    'pvpTrophies': pvpTrophies,
    'injured': {
      for (final e in injured.entries) e.key: e.value.toUtc().toIso8601String(),
    },
    'claimedLeagues': claimedLeagues.toList(),
    if (seasonStartedAt != null)
      'seasonStartedAt': seasonStartedAt!.toUtc().toIso8601String(),
    'seasonPeakTrophies': seasonPeakTrophies,
    'breeding': breeding.map((b) => b.toJson()).toList(),
    'breedingCapacity': breedingCapacity,
    'storageCapacity': storageCapacity,
    'pvpTickets': pvpTickets,
    if (ticketsAt != null) 'ticketsAt': ticketsAt!.toUtc().toIso8601String(),
    'adUseCounts': adUseCounts,
    // 빈 값은 **아예 안 싣는다** — 60초마다 올리는 세이브라 빈 맵/리스트도
    // 쌓이면 이그레스가 된다(구버전 앱은 어차피 기본값으로 읽는다).
    if (equippedItems.isNotEmpty)
      'equippedItems': {
        for (final e in equippedItems.entries) e.key.key: e.value.toJson(),
      },
    if (forgeStack.isNotEmpty)
      'forgeStack': [for (final i in forgeStack) i.toJson()],
    if (skillLevels.isNotEmpty) 'skillLevels': skillLevels,
    if (equippedSkills.isNotEmpty) 'equippedSkills': equippedSkills,
    if (forgeLevel != 0) 'forgeLevel': forgeLevel,
    if (forgeSteps != 0) 'forgeSteps': forgeSteps,
    if (forgeUpAt != null) 'forgeUpAt': forgeUpAt!.toUtc().toIso8601String(),
    if (autoForgeOptions.isNotEmpty)
      'autoForgeOptions': [for (final o in autoForgeOptions) o.key],
    if (!autoForgeStopOnHit) 'autoForgeStopOnHit': false,
    if (adUseDate != null) 'adUseDate': adUseDate,
    if (giftDoubleDate != null) 'giftDoubleDate': giftDoubleDate,
    if (giftDoubleCount != 0) 'giftDoubleCount': giftDoubleCount,
    'lastReadNoticeId': lastReadNoticeId,
    'reviewAsked': reviewAsked,
    'adsRemoved': adsRemoved,
    'buffPassExpiresAt': buffPassExpiresAt?.toIso8601String(),
    'starterBought': starterBought,
    'ownedSkins': ownedSkins.toList(),
    'redeemedPurchases': redeemedPurchases.toList(),
    'blockedUserIds': blockedUserIds.toList(),
    if (bugFilterMinGrade != Grade.common)
      'bugFilterMinGrade': bugFilterMinGrade.key,
    'passExpiresAt': passExpiresAt?.toIso8601String(),
  };

  /// 모르는 재료 키는 **던지지 않고 건너뛴다** — 신버전이 재료를 하나만 추가해도
  /// 구버전 앱이 그 세이브에서 통째로 죽던 구멍(2026-08-26). 건너뛴 키는
  /// [_unknownIntsFromJson] 이 따로 담아 toJson 이 그대로 되돌려준다.
  static Map<MaterialKind, int> _materialsFromJson(Map<String, dynamic> json) {
    final out = <MaterialKind, int>{};
    for (final e in json.entries) {
      final kind = MaterialKind.fromKeyOrNull(e.key);
      if (kind == null) continue;
      out[kind] = (e.value as num?)?.toInt() ?? 0;
    }
    return out;
  }

  /// 모르는 업그레이드 키도 마찬가지로 건너뛴다.
  static Map<UpgradeKind, int> _upgradesFromJson(Map<String, dynamic> json) {
    final out = <UpgradeKind, int>{};
    for (final e in json.entries) {
      final kind = UpgradeKind.fromKeyOrNull(e.key);
      if (kind == null) continue;
      out[kind] = (e.value as num?)?.toInt() ?? 0;
    }
    return out;
  }

  /// [json] 에서 [isKnown] 이 false 인 항목만 원본 문자열 키 그대로 담는다(보존용).
  static Map<String, int> _unknownIntsFromJson(
    Map<String, dynamic> json,
    bool Function(String key) isKnown,
  ) {
    final out = <String, int>{};
    for (final e in json.entries) {
      if (isKnown(e.key)) continue;
      final v = e.value;
      if (v is num) out[e.key] = v.toInt();
    }
    return out;
  }

  static Map<String, int> _intMapFromJson(Map<String, dynamic> json) => {
    for (final e in json.entries) e.key: (e.value as num).toInt(),
  };

  /// 알 수 없는 버프 key 는 무시(미래 버전 호환).
  static Map<BuffKind, DateTime> _buffsFromJson(Map<String, dynamic> json) {
    final out = <BuffKind, DateTime>{};
    for (final e in json.entries) {
      final kind = BuffKind.fromKey(e.key);
      if (kind == null) continue;
      out[kind] = DateTime.parse(e.value as String).toUtc();
    }
    return out;
  }
}
