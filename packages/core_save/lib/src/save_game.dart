import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';

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
  });

  final String id;
  final String speciesId;
  final double parentAvgSizeMm;
  final int motherPotential;
  final int fatherPotential;
  final DateTime endsAt;
  final int seed;

  factory BreedingSlot.fromJson(Map<String, dynamic> json) => BreedingSlot(
    id: json['id'] as String,
    speciesId: json['speciesId'] as String,
    parentAvgSizeMm: (json['parentAvgSizeMm'] as num).toDouble(),
    motherPotential: (json['motherPotential'] as num).toInt(),
    fatherPotential: (json['fatherPotential'] as num).toInt(),
    endsAt: DateTime.parse(json['endsAt'] as String).toUtc(),
    seed: (json['seed'] as num).toInt(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'speciesId': speciesId,
    'parentAvgSizeMm': parentAvgSizeMm,
    'motherPotential': motherPotential,
    'fatherPotential': fatherPotential,
    'endsAt': endsAt.toUtc().toIso8601String(),
    'seed': seed,
  };
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
    required this.incubatorCapacity,
    required this.incubating,
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
    this.lastReadNoticeId = 0,
    this.reviewAsked = false,
    this.adsRemoved = false,
    this.starterBought = false,
    this.ownedSkins = const {},
    this.passExpiresAt,
    this.redeemedPurchases = const {},
    this.equippedItems = const {},
    this.skillLevels = const {},
    this.equippedSkills = const [],
    this.forgeLevel = 0,
    this.forgeSteps = 0,
    this.forgeUpAt,
    this.autoForgeOptions = const {},
    this.autoForgeStopOnHit = true,
    this.blockedUserIds = const {},
    this.nicknameSet = false,
  });

  final int schemaVersion;

  /// 보관함(수집 개체).
  final List<IndividualBug> bugs;

  /// 재료 인벤토리.
  final Map<MaterialKind, int> materials;

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

  /// 부화기 슬롯 개수(젤리로 확장).
  final int incubatorCapacity;

  /// 부화기에서 부화 중인 알: bugId → 부화 완료 UTC 시각.
  final Map<String, DateTime> incubating;

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
    incubatorCapacity: 1,
    incubating: const {},
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
    equippedItems: const {},
    skillLevels: const {},
    equippedSkills: const [],
    forgeLevel: 0,
    forgeSteps: 0,
    autoForgeOptions: const {},
    autoForgeStopOnHit: true,
    adsRemoved: false,
    starterBought: false,
    ownedSkins: const {},
    redeemedPurchases: const {},
    blockedUserIds: const {},
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
    int? incubatorCapacity,
    Map<String, DateTime>? incubating,
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
    String? adUseDate,
    Map<EquipSlot, EquipItem>? equippedItems,
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
    bool? starterBought,
    Set<String>? ownedSkins,
    DateTime? passExpiresAt,
    Set<String>? redeemedPurchases,
    Set<String>? blockedUserIds,
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
    incubatorCapacity: incubatorCapacity ?? this.incubatorCapacity,
    incubating: incubating ?? this.incubating,
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
    adUseDate: adUseDate ?? this.adUseDate,
    equippedItems: equippedItems ?? this.equippedItems,
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
    starterBought: starterBought ?? this.starterBought,
    ownedSkins: ownedSkins ?? this.ownedSkins,
    passExpiresAt: passExpiresAt ?? this.passExpiresAt,
    redeemedPurchases: redeemedPurchases ?? this.redeemedPurchases,
    blockedUserIds: blockedUserIds ?? this.blockedUserIds,
  );

  int materialCount(MaterialKind kind) => materials[kind] ?? 0;

  int upgradeLevel(UpgradeKind kind) => upgradeLevels[kind] ?? 0;

  /// [now] 기준 활성(만료 전) 버프 종류들.
  Set<BuffKind> activeBuffs(DateTime now) => {
    for (final e in buffExpiry.entries)
      if (e.value.isAfter(now)) e.key,
  };

  /// [kind] 버프의 남은 시간([now] 기준). 비활성이면 null.
  Duration? buffRemaining(BuffKind kind, DateTime now) {
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
    installations: (json['installations'] as List)
        .cast<Map<String, dynamic>>()
        .map(TrapInstallation.fromJson)
        .toList(),
    unlockedFieldIds: (json['unlockedFieldIds'] as List).cast<String>().toSet(),
    createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
    lastSeen: json['lastSeen'] != null
        ? DateTime.parse(json['lastSeen'] as String).toUtc()
        : DateTime.parse(json['createdAt'] as String).toUtc(),
    gold: (json['gold'] as num).toInt(),
    xp: (json['xp'] as num).toInt(),
    level: (json['level'] as num).toInt(),
    upgradeLevels: _upgradesFromJson(
      json['upgradeLevels'] as Map<String, dynamic>,
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
    incubatorCapacity: (json['incubatorCapacity'] as num?)?.toInt() ?? 1,
    incubating:
        (json['incubating'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, DateTime.parse(v as String).toUtc()),
        ) ??
        const {},
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
    equippedItems: {
      for (final e
          in (json['equippedItems'] as Map<String, dynamic>? ?? const {})
              .entries)
        EquipSlot.fromKey(e.key): EquipItem.fromJson(
          Map<String, dynamic>.from(e.value as Map),
        ),
    },
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
        ItemOptionKind.fromKey(v as String),
    },
    autoForgeStopOnHit: json['autoForgeStopOnHit'] as bool? ?? true,
    adUseDate: json['adUseDate'] as String?,
    lastReadNoticeId: (json['lastReadNoticeId'] as num?)?.toInt() ?? 0,
    reviewAsked: json['reviewAsked'] as bool? ?? false,
    adsRemoved: json['adsRemoved'] as bool? ?? false,
    starterBought: json['starterBought'] as bool? ?? false,
    ownedSkins:
        (json['ownedSkins'] as List?)?.cast<String>().toSet() ?? const {},
    redeemedPurchases:
        (json['redeemedPurchases'] as List?)?.cast<String>().toSet() ??
        const {},
    blockedUserIds:
        (json['blockedUserIds'] as List?)?.cast<String>().toSet() ?? const {},
    passExpiresAt: json['passExpiresAt'] == null
        ? null
        : DateTime.parse(json['passExpiresAt'] as String).toUtc(),
  );

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'bugs': bugs.map((b) => b.toJson()).toList(),
    'materials': {for (final e in materials.entries) e.key.key: e.value},
    'installations': installations.map((i) => i.toJson()).toList(),
    'unlockedFieldIds': unlockedFieldIds.toList(),
    'createdAt': createdAt.toUtc().toIso8601String(),
    'lastSeen': lastSeen.toUtc().toIso8601String(),
    'gold': gold,
    'xp': xp,
    'level': level,
    'upgradeLevels': {
      for (final e in upgradeLevels.entries) e.key.key: e.value,
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
    'incubatorCapacity': incubatorCapacity,
    'incubating': {
      for (final e in incubating.entries)
        e.key: e.value.toUtc().toIso8601String(),
    },
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
    if (skillLevels.isNotEmpty) 'skillLevels': skillLevels,
    if (equippedSkills.isNotEmpty) 'equippedSkills': equippedSkills,
    if (forgeLevel != 0) 'forgeLevel': forgeLevel,
    if (forgeSteps != 0) 'forgeSteps': forgeSteps,
    if (forgeUpAt != null) 'forgeUpAt': forgeUpAt!.toUtc().toIso8601String(),
    if (autoForgeOptions.isNotEmpty)
      'autoForgeOptions': [for (final o in autoForgeOptions) o.key],
    if (!autoForgeStopOnHit) 'autoForgeStopOnHit': false,
    if (adUseDate != null) 'adUseDate': adUseDate,
    'lastReadNoticeId': lastReadNoticeId,
    'reviewAsked': reviewAsked,
    'adsRemoved': adsRemoved,
    'starterBought': starterBought,
    'ownedSkins': ownedSkins.toList(),
    'redeemedPurchases': redeemedPurchases.toList(),
    'blockedUserIds': blockedUserIds.toList(),
    'passExpiresAt': passExpiresAt?.toIso8601String(),
  };

  static Map<MaterialKind, int> _materialsFromJson(Map<String, dynamic> json) {
    return {
      for (final e in json.entries)
        MaterialKind.fromKey(e.key): (e.value as num).toInt(),
    };
  }

  static Map<UpgradeKind, int> _upgradesFromJson(Map<String, dynamic> json) {
    return {
      for (final e in json.entries)
        UpgradeKind.fromKey(e.key): (e.value as num).toInt(),
    };
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
