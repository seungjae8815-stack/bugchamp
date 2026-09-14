import 'dart:math' as math;

import 'package:core_models/core_models.dart';
import 'package:meta/meta.dart';

import 'enums.dart';
import 'monster_config.dart';

/// 능력치 업그레이드 1종의 곡선 정의 (JSON).
@immutable
class UpgradeSpec {
  const UpgradeSpec({
    required this.kind,
    required this.baseCost,
    required this.costGrowth,
    required this.baseValue,
    required this.perLevel,
    this.materialKind,
    this.materialBaseCost = 0,
    this.materialCostGrowth = 1.0,
    this.valueGrowth,
    this.maxLevel,
  });

  /// 살 수 있는 최대 레벨. **null 이면 무제한**(구버전 JSON 호환).
  ///
  /// 상한을 두는 이유는 두 가지다(2026-09-09 확정).
  /// 1. 어떤 축은 일정 레벨 뒤로 **헛돈**이 된다 — 치명확률은 100% 를 넘으면
  ///    아무 의미가 없는데 상점은 160 레벨까지 팔았다.
  /// 2. 능력치만 뽑는 길에 끝이 있어야 **펫·장비를 뽑을 이유**가 생긴다.
  ///    능력치가 무한하면 그게 늘 가장 싼 길이라 가챠·제련이 밀린다.
  ///
  /// ⚠️ 상한을 만질 땐 `balance_sim` 을 돌린다 — 적응형 체력(§7)은
  /// 업그레이드+펫을 기준으로 잡으므로, 상한에 닿은 뒤의 진행은 장비(기준 밖)가
  /// 끌고 간다. 그 구간이 너무 길면 벽이 된다.
  final int? maxLevel;

  /// [level] 에서 더 살 수 있나.
  bool canBuyAt(int level) => maxLevel == null || level < maxLevel!;

  final UpgradeKind kind;
  final double baseCost;
  final double costGrowth;
  final double baseValue;
  final double perLevel;

  /// 이 업그레이드가 골드 외에 추가로 요구하는 재료(없으면 null).
  final MaterialKind? materialKind;
  final double materialBaseCost;
  final double materialCostGrowth;

  /// 레벨당 **곱연산** 성장률. 지정하면 [perLevel](덧셈) 대신 이걸 쓴다.
  ///
  /// 왜 필요한가: 덧셈 성장은 비용이 지수(`costGrowth`)라서 **스탯 ∝ log(골드)**
  /// 가 된다. 적 HP 는 스테이지당 `hpGrowth` 배로 지수 증가하므로, 파밍을
  /// 두 배 해도 다음 스테이지를 못 뚫는 구간(진행 벽)이 반드시 생긴다.
  /// [valueGrowth] 를 `costGrowth` 와 같은 값으로 두면 **스탯 ∝ 쓴 골드**가 되어
  /// "막히면 더 모아서 뚫는다"가 성립한다.
  ///
  /// null 이면 기존 덧셈 그대로 — JSON 에 없으면 동작이 안 바뀐다.
  final double? valueGrowth;

  /// 레벨 [level] 에서의 스탯 값.
  double valueAt(int level) => valueGrowth == null
      ? baseValue + perLevel * level
      : baseValue * math.pow(valueGrowth!, level);

  factory UpgradeSpec.fromJson(Map<String, dynamic> json) => UpgradeSpec(
    kind: UpgradeKind.fromKey(json['kind'] as String),
    baseCost: (json['baseCost'] as num).toDouble(),
    costGrowth: (json['costGrowth'] as num).toDouble(),
    baseValue: (json['baseValue'] as num).toDouble(),
    perLevel: (json['perLevel'] as num).toDouble(),
    materialKind: json['materialKind'] != null
        ? MaterialKind.fromKey(json['materialKind'] as String)
        : null,
    maxLevel: (json['maxLevel'] as num?)?.toInt(),
    materialBaseCost: (json['materialBaseCost'] as num?)?.toDouble() ?? 0,
    materialCostGrowth: (json['materialCostGrowth'] as num?)?.toDouble() ?? 1.0,
    valueGrowth: (json['valueGrowth'] as num?)?.toDouble(),
  );
}

/// 지역(테마) 정의.
@immutable
class RegionConfig {
  const RegionConfig({
    required this.id,
    required this.name,
    required this.bossName,
    required this.habitatKinds,
    this.monsterIds = const [],
    this.bossFlip = true,
    this.element,
  });

  /// 기존 필드 id 재활용 가능 (예: 'oak_forest').
  final String id;
  final LocalizedText name;
  final LocalizedText bossName;

  /// 구버전 필드(enum 5종). 새 `monsters` 를 안 쓰는 JSON 을 위해 남긴다.
  final List<HabitatKind> habitatKinds;

  /// 이 지역에 나오는 몬스터 id 목록(`RunConfig.monsters` 의 키).
  ///
  /// 비어 있으면 [habitatKinds] 를 그대로 쓴다 — 구버전 JSON 이 그대로 돈다.
  final List<String> monsterIds;

  /// 실제로 쓸 목록. 새 필드가 있으면 그것을, 없으면 옛 enum 을 문자열로.
  List<String> get monsterKeys => monsterIds.isNotEmpty
      ? monsterIds
      : habitatKinds.map((k) => k.key).toList();

  /// 보스 스프라이트를 좌우 반전해 캐릭터(좌측)를 바라보게 할지.
  /// 원본 아트가 오른쪽을 보면 true, 이미 왼쪽을 보면 false.
  final bool bossFlip;

  /// 이 지역 몬스터의 오행 속성. **null 이면 무속성**(상극이 안 걸린다).
  ///
  /// 지역 단위인 이유: 지역마다 편성을 바꾸는 것이 이 시스템이 만들려는
  /// 행동이다. 몬스터 개체마다 무작위로 주면 편성을 미리 고를 수 없어
  /// **판단 자체가 사라진다**.
  final Element? element;

  factory RegionConfig.fromJson(Map<String, dynamic> json) => RegionConfig(
    id: json['id'] as String,
    name: LocalizedText.fromJson(json['name'] as Map<String, dynamic>),
    bossName: LocalizedText.fromJson(json['bossName'] as Map<String, dynamic>),
    // ⚠️ 새 몬스터 id 는 enum 에 없다. `habitatKinds` 는 **enum 으로 읽히는
    // 것만** 담는다 — 아니면 `fromKey` 가 던져 로딩이 통째로 죽는다.
    habitatKinds: (json['habitatKinds'] as List? ?? const [])
        .cast<String>()
        .map(HabitatKind.fromKeyOrNull)
        .whereType<HabitatKind>()
        .toList(),
    monsterIds:
        (json['monsters'] as List? ?? json['habitatKinds'] as List? ?? const [])
            .cast<String>()
            .toList(),
    bossFlip: json['bossFlip'] as bool? ?? true,
    // `fromKey` 가 아니라 `fromKeyOrNull` 이다. 애셋 오타를 로딩에서 잡는
    // 다른 필드와 달리, 이건 **없어도 정상**(무속성)이라 던지면 안 된다.
    element: json['element'] == null
        ? null
        : Element.fromKeyOrNull(json['element'] as String),
  );
}

/// 런 밸런스 설정 전체 (assets/data/run_config.json 에서 로드).
@immutable
class RunConfig {
  const RunConfig({
    required this.hpBase,
    required this.hpGrowth,
    this.onlineGoldBonus = 0,
    this.sceneCatchChance = 0.35,
    this.sceneCatchWindow = 1.4,
    this.sceneCatchCooldown = 25,
    this.materialAmountGrowth = 1.0,
    this.hpAdaptTargetHits = 0,
    this.threatAdaptTargetPct = 0,
    this.threatAdaptPower = 0.85,
    this.threatAdaptMinRatio = 0.5,
    this.threatAdaptMaxRatio = 1000,
    this.threatAdaptDepthStart = 0,
    this.threatAdaptDepthGain = 0,
    this.threatAdaptDepthMax = 1,
    this.threatEquipShare = 0,
    this.hpAdaptPower = 0,
    this.hpAdaptMinRatio = 0.5,
    this.hpAdaptMaxRatio = 1000,
    required this.bossHpMult,
    required this.goldBase,
    required this.goldGrowth,
    required this.xpBase,
    required this.xpGrowth,
    required this.bossRewardMult,
    required this.habitatsPerStage,
    required this.bugDropChance,
    required this.materialDropChance,
    required this.regions,
    required this.upgrades,
    this.stagesPerRegion = 10,
    this.boostStepPerTap = 0.15,
    this.boostMultMax = 5.0,
    this.critChanceMax = 0.85,
    this.critBudgetUpgrade = 1.0,
    this.critBudgetGear = 1.0,
    this.critBudgetOther = 1.0,
    this.walkThreatMult = 0.0,
    this.boostDecayPerSec = 0.4,
    this.boostSpeedFactor = 1.0,
    this.threatBase = 3.0,
    this.threatGrowth = 1.12,
    this.bossThreatMult = 4.0,
    this.killHealPct = 0.05,
    this.bossKillHealPct = 0.3,
    this.killHealMissingPct = 0,
    this.bossKillHealMissingPct = 0,
    this.enemyFirstBiteDelay = 0,
    this.enemyFollowBiteMult = 1.0,
    this.enemyAtkInterval = 1.5,
    this.bossAtkInterval = 1.3,
    this.bossHitMult = 1.4,
    this.offlineEfficiency = 0.3,
    this.worldSize = 0,
    this.worldHpMult = 1.0,
    this.tierHitsMult = 1.0,
    this.tierThreatMult = 1.0,
    this.tierRewardMult = 1.0,
    this.zoneMode = false,
    this.bossUnlockKills = 100,
    this.zonesPerTier = 11,
    this.endParkedRewardMult = 1.0,
    this.rarePityKills = 0,
    this.dropGradeWeights = const {},
    this.worldGoldMult = 1.0,
    this.worldBossHpMult = 1.0,
    this.exchangeJellyPerTrade = 10,
    this.exchangeGoldHours = 1.0,
    this.exchangeMaterialHours = 1.0,
    this.exchangeKillsPerHour = 900,
    this.monsters = const {},
    this.eliteChance = 0.06,
    this.eliteHpMult = 3.0,
    this.eliteRewardMult = 4.0,
    this.eliteScale = 1.45,
    this.gearHintMult = 1.70,
    this.gearHintFullStage = 900,
    this.petRestrainMult = 1.5,
  });

  final double hpBase;

  /// 처치당 재료 **수량**의 깊이당 성장률(1.0 = 고정 수량, 기존 동작).
  ///
  /// 골드는 `goldGrowth^depth` 로 지수 성장하는데 재료만 고정이면, 중반엔
  /// 재료가 쌓이기만 하고(골드 병목) 후반엔 반대로 재료가 병목이 돼
  /// 골드가 남아돈다 — 실측으로 스테이지 400 까지 **재료의 90% 가 미사용**,
  /// 700 부터 뒤집혔다. 재료도 같이 자라게 해서 비율을 일정하게 유지한다.
  final double materialAmountGrowth;

  /// **접속 중에만** 붙는 골드 보너스(0.5 = +50%).
  ///
  /// 방치 보상(효율 0.3 × 최대 8시간)이 활동 2시간보다 커서, 연타를 안 하면
  /// **켜두는 것보다 꺼두는 게 이득**이었다. 방치 보상을 깎으면 "안 켜도
  /// 벌린다"를 보고 온 유저가 이탈하므로, 대신 온라인에 얹는다.
  final double onlineGoldBonus;

  /// 캐릭터 화면 씬에서 채집망을 휘둘렀을 때 **잡을 기회가 열릴 확률**.
  ///
  /// 씬은 화면을 보고 있을 때만 돌아가므로 §2.4 의 "접속 보너스" 계열이다.
  /// ⚠️ 여기를 올리면 채집함(50칸)이 몇 분 만에 차고, 포텐셜 좋은 개체를
  /// 무한히 리롤할 수 있게 된다 — 방치 드롭률과 함께 봐야 한다.
  final double sceneCatchChance;

  /// 기회가 열렸을 때 **탭할 수 있는 시간**(초).
  final double sceneCatchWindow;

  /// 한 번 잡은 뒤 다음 기회까지 쉬는 시간(초).
  final double sceneCatchCooldown;

  /// 몬스터 한 대가 가져가야 할 **내 최대체력 비율**(0.015 = 1.5%).
  ///
  /// 0 이면 적응형 위협을 끈다(기존 동작).
  ///
  /// 체력에 적응형을 넣고 위협은 고정으로 뒀더니, 방어 전력이 지수로 커지는
  /// 동안 몬스터 공격은 스테이지당 ×1.025 라 **한 대가 체력의 0.0006%**(스테이지
  /// 50 실측)가 됐다. 절대 죽지 않으니 체력·방어·회복 업그레이드와 옷·바지
  /// 장비, 방어 스킬이 **전부 죽은 투자**였다.
  final double threatAdaptTargetPct;

  /// 위협 보정 지수. **1 미만**이라 방어에 투자할수록 상대적으로 안전해진다
  /// (1.0 이면 아무리 올려도 제자리라 투자할 이유가 사라진다).
  final double threatAdaptPower;
  final double threatAdaptMinRatio;
  final double threatAdaptMaxRatio;

  /// 후반 보정이 **켜지기 시작하는 스테이지**(깊이).
  ///
  /// 초반·중반은 이미 빠듯하거나 벽이라(수지 -125 ~ -378%) 손대면 신규가 먼저
  /// 죽는다. 문제는 **후반이 거꾸로 안전해지는 것**이므로 거기서만 켠다.
  final double threatAdaptDepthStart;

  /// 위협 비율이 **월드마다 얼마나 더 오르는가**(0 = 예전 동작, 전 구간 동일).
  ///
  /// [threatAdaptTargetPct] 를 전역으로 올리면 못 쓴다 — 전 구간에 곱해져
  /// 이미 빡빡한 초반(스테이지 10~200)이 먼저 무너진다(0.006 → 0.0065 만으로
  /// 신규 구간이 "너무 닳음"이 된 실측이 있다). 그래서 **깊이에만** 얹는다:
  /// 초반은 그대로 두고 뒤로 갈수록 맞는 게 아파진다.
  ///
  /// 이유: 기준 밖 전력(장비·도감·종패시브·회복)이 후반에 몰려 붙어서,
  /// 같은 비율이면 후반이 초반보다 훨씬 안전해진다(실측 수지 -178% → -20%).
  final double threatAdaptDepthGain;

  /// 위 증가분의 상한 배수. 무한히 두면 최종 월드에서 즉사한다.
  final double threatAdaptDepthMax;

  /// 위협 기준에 **장비 방어 전력을 얼마나 섞는가**(0 = 안 섞음).
  ///
  /// 장비는 원래 기준 밖이다 — 좋은 걸 껴도 몬스터가 같이 세지면 모으는 맛이
  /// 사라지기 때문이다(`_stats` 주석). 다만 0 으로 두면 장비가 쌓일수록
  /// 위협이 통째로 무의미해져서, **절반만** 섞어 둘을 절충한다.
  /// 껴서 얻는 이득은 남고(섞은 뒤에도 순이득), 무적은 막는다.
  final double threatEquipShare;

  // ── 적응형 체력(§7, 2026-08) ──
  // 공격은 업그레이드 레벨당 x1.15, 체력은 스테이지당 x1.015 로 자라 공격이
  // 항상 이긴다. "기준선 대비 얼마나 세졌나"를 체력에 일부 반영해 한 방을 막되,
  // 강해질수록 타격 수는 줄어들게(지수 < 1) 둔다. 0 이면 기능 꺼짐(기존 동작).

  /// 기준선에서 목표로 삼는 타격 수. 0 이면 적응형 끔.
  final double hpAdaptTargetHits;

  /// 보정 지수(0~1). 1 이면 항상 같은 타격 수(성장 실감 없음),
  /// 0 이면 보정 없음. 0.85 근처가 "줄긴 줄되 한 방은 안 되는" 구간.
  final double hpAdaptPower;

  /// 보정 비율의 하한 — 기준보다 약한 플레이어를 더 괴롭히지 않는다(따라잡기).
  final double hpAdaptMinRatio;

  /// 상한 — 극단적으로 센 계정에서 체력이 무한히 커지지 않게.
  final double hpAdaptMaxRatio;
  final double hpGrowth;
  final double bossHpMult;
  final double goldBase;
  final double goldGrowth;
  final double xpBase;
  final double xpGrowth;
  final double bossRewardMult;
  final int habitatsPerStage;
  final double bugDropChance;
  final double materialDropChance;
  final List<RegionConfig> regions;
  final Map<UpgradeKind, UpgradeSpec> upgrades;

  /// 지역 1개당 스테이지 수 (넘어가면 다음 지역).
  final int stagesPerRegion;

  // ── 탭 부스트(연타 콤보) ────────────────────────────────────────────
  // 탭할수록 배율이 쌓이고, 안 누르면 초당 [boostDecayPerSec] 씩 1.0 으로
  // 돌아간다. "계속 두드리면 보스를 뚫는다"가 이 게임의 능동 플레이 손잡이다.
  //
  // ⚠️ **플레이어 공격에만 적용된다.** 몬스터 공격은 따로 계산한다.

  /// 탭 1회에 오르는 배율. 실제 증가폭은 `boostBonus`(업그레이드) 를 곱한다.
  final double boostStepPerTap;

  /// 배율 상한. 데미지 `×배율`, 공격속도 `×(1 + (배율-1) × [boostSpeedFactor])`.
  final double boostMultMax;

  /// 몬스터 사이를 **걷는 동안** 받는 위협도 비율(0=무피해).
  ///
  /// 예전엔 이동 중이 완전 공짜였다(무피해 + 회복 2배). 몹이 몇 대에 죽는
  /// 구간에서는 전투 시간보다 이동 시간이 길어, **판의 절반이 안전지대**가
  /// 되고 처치 회복만 쌓여 피가 안 닳았다(2026-09-07 제보).
  final double walkThreatMult;

  /// 치명확률 상한. 넘친 만큼은 **치명피해로 돌아간다**(`capCritChance`).
  ///
  /// 1.0 이면 모든 타격이 치명타가 되어 노란 숫자·큰 흔들림이 기본값이 되고,
  /// 때리는 손맛이 통째로 죽는다(2026-09-07). 변동이 있어야 한 방이 특별하다.
  final double critChanceMax;

  /// 치명확률 **출처별 예산**(2026-09-14 사장님 확정). 상한 100% 를 강화·장비·
  /// 그 외(펫 패시브 등)에 나눠 준다 — 모든 콘텐츠를 다 채워도 합이 상한을
  /// 넘지 않게. 예전엔 강화만으로 100%, 장비 한 부위가 67% 라 두 부위면 끝이었다.
  /// 그러면 나머지 출처는 전부 죽은 투자가 된다. 1.0 = 예산 없음(예전 동작).
  final double critBudgetUpgrade;
  final double critBudgetGear;
  final double critBudgetOther;

  /// 탭을 멈췄을 때 초당 떨어지는 배율.
  final double boostDecayPerSec;

  /// 부스트가 공격속도에 얼마나 실릴지(1.0 이면 데미지와 같은 배율).
  final double boostSpeedFactor;

  /// 서식지의 곤충 반격 위협도(초당 피해) 스케일링.
  final double threatBase;
  final double threatGrowth;
  final double bossThreatMult;

  /// 서식지 곤충 **1마리를 잡을 때** 회복되는 최대체력 비율.
  ///
  /// 예전엔 코드에 30% 로 박혀 있었다. 한 스테이지가 서식지 20마리라
  /// **처치 회복만 600%** — 몬스터가 아무리 때려도 체력이 절대 안 닳았다.
  /// 한 스테이지의 총 피격량(대략 최대체력의 1.3배)과 균형이 맞는 값이어야
  /// "벽에서는 죽고, 순항 구간에서는 안 죽는다"가 성립한다.
  final double killHealPct;

  /// 보스를 잡을 때 회복되는 최대체력 비율. 보스전은 크게 깎이므로
  /// 다음 스테이지를 시작할 밑천을 여기서 돌려준다(서식지보다 크다).
  final double bossKillHealPct;

  /// 처치 회복의 **잃은 체력 비례** 몫(0 = 없음).
  ///
  /// 최대체력 비례 회복만 있으면 체력은 "가득" 아니면 "줄줄"이다 — 회복이 더
  /// 크면 늘 가득이고, 피격이 더 크면 한 방향으로 미끄러진다. 잃은 만큼에
  /// 비례해 채우면 **피격과 회복이 만나는 높이**가 생겨 체력이 그 근처를
  /// 오르내린다. 한 대 맞아 30% 로 떨어졌다가 잡아서 50% 로 돌아오는 리듬 —
  /// "죽을 듯 말 듯"이 여기서 나온다(2026-09-14 사장님 방향).
  ///
  /// 벽에서는 한 마리에 여러 대를 맞아 만나는 높이가 0 아래로 내려가 죽는다.
  /// 방어는 한 대의 크기를, 회복은 사이를, 체력 상한은 한 대를 견딜 폭을 맡는다.
  final double killHealMissingPct;
  final double bossKillHealMissingPct;

  /// 몬스터가 **달라붙고 이만큼 뒤에 반드시 한 번 문다**(초, 0 = 끔).
  ///
  /// 게이지(간격)만으로는 장비를 갖춘 유저가 몬스터를 1초에 잡아 **평생 한 대도
  /// 안 맞는다** — 스테이지 800 실측(2026-09-14). 위협도를 아무리 올려도
  /// 맞지 않으면 의미가 없다. 첫 물기는 처치 속도와 무관하게 "마리당 한 대"를
  /// 보장한다. 이 한 대가 크고(간격 x 초당 위협), 잡아서 되찾는 것이 리듬이다.
  /// 첫 물기 뒤에는 게이지를 0 에서 다시 센다 — 안 그러면 두 대가 겹친다.
  final double enemyFirstBiteDelay;

  /// 첫 물기 **다음** 물기의 배율(1.0 = 같은 크기).
  ///
  /// 긴 전투 구간(관문 직후, 한 마리 50대)에서는 첫 물기 뒤 두 번째 물기까지
  /// 맞아 한 마리에 45% 가 빠져 죽었다(2026-09-14 시뮬, 장비 유저 850).
  /// 첫 대는 크게(긴장), 이어지는 대는 작게(버틸 수 있게) — 그래야 벽이
  /// 아닌 구간에서 반복해 죽지 않는다.
  final double enemyFollowBiteMult;

  /// 몬스터가 무는 간격(초). 길수록 한 대가 크다(같은 DPS 를 뭉쳐서 준다).
  ///
  /// 1.5초마다 1~2% 씩 빼면 가랑비라 아무 긴장이 없다. 3초에 15~20% 면
  /// 한 대가 보이고, 죽여서 되찾는 리듬이 생긴다.
  final double enemyAtkInterval;
  final double bossAtkInterval;

  /// 보스 한 대의 배율(같은 DPS 에서 뭉치는 정도).
  final double bossHitMult;

  /// 오프라인 파밍 효율(실시간 대비). 온라인이 훨씬 유리하도록 <1.
  final double offlineEfficiency;

  // ── 월드(회차 아님 — "1-37" 의 1) ──────────────────────────────
  /// 한 월드의 스테이지 수. **0 이면 월드 없음**(구버전 동작 그대로).
  ///
  /// 월드 구조(2026-08 확정): 구간 내에서는 hp·gold 가 같은 속도로 늘어
  /// 순항하고, 월드 경계에서 적 HP 가 [worldHpMult] 배 점프해 **벽**이 된다.
  /// 벽은 이전 월드에서 재화를 모아 업그레이드해야 뚫린다(방치 루프의 핵).
  final int worldSize;

  /// 월드가 하나 넘어갈 때마다 적 HP(·위협도)에 곱해지는 점프.
  final double worldHpMult;

  /// 난이도 회차 **한 단계당** 곱해지는 값들
  /// (`docs/design_difficulty_loop.md`). 회차 n 이면 `^n`.
  ///
  /// ⚠️ **체력에 직접 곱하지 않는다.** 적응형 체력은 이미 "몇 대에 죽나"를
  /// [hpAdaptTargetHits] 로 맞추고 있어서, 거기에 배율을 곱하면 **타격 수가
  /// 그대로 배가 된다** — 실측 극한 회차에서 몬스터 하나에 13,777대였다
  /// (2026-08-30). 그건 어려운 게 아니라 지루한 스펀지다.
  ///
  /// 대신 두 축으로 나눈다:
  ///  - [tierHitsMult] : 목표 타격 수를 늘린다(전투가 **조금** 길어진다).
  ///  - [tierThreatMult] : 몬스터 공격을 올린다(**죽을 수 있게** 만든다).
  ///
  /// 난이도는 "때리는 횟수"가 아니라 **위험**에서 나와야 한다 — 그래야
  /// 체력·방어·회복과 장비 옵션이 실제 선택이 된다.
  final double tierHitsMult;
  final double tierThreatMult;

  /// 회차 [tier] 의 타격 배율(목표 타격 수·보정 상한에 함께 곱한다).
  double tierHits(int tier) =>
      tier <= 0 ? 1.0 : math.pow(tierHitsMult, tier).toDouble();

  /// 회차 [tier] 의 목표 타격 수(적응형 기준).
  double tierTargetHits(int tier) => hpAdaptTargetHits * tierHits(tier);

  /// 회차 [tier] 의 위협도 배율.
  double tierThreat(int tier) =>
      tier <= 0 ? 1.0 : math.pow(tierThreatMult, tier).toDouble();

  /// 회차 한 단계당 **보상** 배율. 몬스터가 세지는 만큼 벌이도 올라야
  /// 회차를 넘어갈 이유가 생긴다.
  final double tierRewardMult;

  // ── 사냥터·보스 구조(2026-09-14 사장님 확정, docs/design_zones.md) ──
  //
  // 스테이지 1000개 × 20마리 대신 난이도마다 **사냥터 10 + 최종 1**.
  // 사냥터 안의 몬스터는 세기가 **평탄**하고 무한히 나온다. 재화를 모아
  // 강화한 뒤 "보스 도전"을 눌러 깨면 다음 사냥터가 열린다(몬스터도 보상도
  // 한 단계 세진다). 낮은 사냥터에 눌러앉아 모으지 못하게 보상은 사냥터마다
  // 오른다.
  //
  // 구현은 기존 축을 재사용한다: 사냥터 k = 스테이지 (k-1)×worldSize+1.
  // 스테이지 번호는 사냥터 안에서 **오르지 않고**, 보스를 깨면 worldSize 만큼
  // 뛴다. 그래서 지역(stagesPerRegion=worldSize)·월드 배율·로드맵 챕터가
  // 그대로 "사냥터 단위"가 된다. 적응형 체력·위협은 끈다(hpAdaptTargetHits 0,
  // threatAdaptTargetPct 0) — 몬스터는 정해진 세기이고 내가 성장해서 넘는다.

  /// 사냥터 모드. false 면 예전 스테이지 진행(하위호환·테스트용).
  final bool zoneMode;

  /// 보스 도전이 열리는 처치 수(사냥터에 들어온 뒤 누적).
  final int bossUnlockKills;

  /// 난이도(회차)마다 사냥터 수. 마지막 하나가 최종 보스 사냥터다.
  final int zonesPerTier;

  /// 사냥터 번호(1-based). 사냥터 모드가 아니어도 월드 번호와 같다.
  int zoneOf(int stageNumber) =>
      worldSize <= 0 ? 1 : ((stageNumber - 1) ~/ worldSize) + 1;

  /// 사냥터 [zone] 의 대표 스테이지(그 사냥터에 있는 동안 stageNumber 값).
  int zoneStartStage(int zone) =>
      worldSize <= 0 ? zone : (zone - 1) * worldSize + 1;

  /// 마지막 사냥터(최종 보스)인가.
  bool isFinalZone(int zone) => zone >= zonesPerTier;

  /// 보스 아트 파일 id — `assets/images/bosses/<id>.webp`.
  ///
  /// 난이도 접두(쉬움 e · 보통 n · 어려움 h · 극한 x) + 사냥터 두 자리,
  /// 최종 보스는 `_final`. 예: `e01`, `n10`, `x_final`. 44마리가 전부 다른
  /// 종이라(2026-09-14 확정) 지역 그림을 돌려쓰지 않는다. 파일이 없으면
  /// 호출부가 지역 보스 그림으로 떨어진다(`gameImageChain`).
  String bossArtId(int tier, int zone) {
    const prefix = ['e', 'n', 'h', 'x'];
    final p = prefix[tier.clamp(0, prefix.length - 1)];
    if (isFinalZone(zone)) return '${p}_final';
    return '$p${zone.toString().padLeft(2, '0')}';
  }

  /// 캠페인 **끝(마지막 스테이지)에 눌러앉아** 파밍할 때 곱하는 보상 배율.
  ///
  /// 끝에 닿으면 더 나아가지 않고 그 자리에서 계속 잡을 수 있는데, 그 구간은
  /// 이미 자기 전력에 한참 못 미치는 난이도다. 그대로 두면 **회차를 넘기지
  /// 않고 눌러앉는 게 최적**이 된다 — 다음 회차는 몬스터가 세지니까.
  /// 회차를 넘기는 쪽이 늘 이득이어야 회차 시스템이 성립한다.
  final double endParkedRewardMult;

  /// 희귀 천장 — 희귀 이상을 얻지 못한 처치가 이 수에 닿으면 다음 드롭을
  /// 희귀 이상으로 보장한다. 0 = 꺼짐.
  final int rarePityKills;

  /// 야생 드롭의 **등급 가중치**. 비어 있으면 전 종 균등(구버전 동작).
  ///
  /// 없으면 희소성이 종 개수 비율로만 정해져 전설이 드롭의 10% 가 된다.
  final Map<Grade, double> dropGradeWeights;

  /// 회차 [tier] 의 보상 배율.
  double tierReward(int tier) =>
      tier <= 0 ? 1.0 : math.pow(tierRewardMult, tier).toDouble();

  /// 월드가 하나 넘어갈 때마다 골드·경험치 보상에 곱해지는 점프.
  /// [worldHpMult] 보다 작아야 벽이 생긴다(같으면 벽이 없다).
  final double worldGoldMult;

  /// 월드 **마지막 스테이지 보스**(1-100 의 보스)에 추가로 곱하는 HP 배.
  /// 다음 월드로 가는 관문 — 이 벽을 넘으면 월드가 바뀐다.
  final double worldBossHpMult;

  /// 스테이지가 몇 번째 월드인지(1-based). 월드 없으면 항상 1.
  int worldOf(int stageNumber) =>
      worldSize <= 0 ? 1 : (stageNumber - 1) ~/ worldSize + 1;

  /// 월드 안에서의 스테이지 번호(1-based). "1-37" 의 37.
  int stageInWorld(int stageNumber) =>
      worldSize <= 0 ? stageNumber : (stageNumber - 1) % worldSize + 1;

  /// 이 스테이지가 월드의 마지막(월드 보스)인가.
  bool isWorldFinal(int stageNumber) =>
      worldSize > 0 && stageNumber % worldSize == 0;

  /// 깊이(depth = stage-1)에 대한 월드 점프 누적 배율.
  double worldMult(double per, int depth) =>
      worldSize <= 0 ? 1.0 : math.pow(per, depth ~/ worldSize).toDouble();

  /// 첫 지역 (하위호환).
  RegionConfig get region => regions.first;

  /// 스테이지 번호(1-based)에 해당하는 지역.
  ///
  /// 지역은 **순환**한다(1-25 참나무숲 → … → 1-100 밤숲 → 2-1 다시 참나무숲).
  /// 아트 4종으로 월드 10개를 채우기 위함 — 마지막 지역에서 멈추지 않는다.
  RegionConfig regionForStage(int stageNumber) {
    final idx = ((stageNumber - 1) ~/ stagesPerRegion) % regions.length;
    return regions[idx];
  }

  UpgradeSpec upgrade(UpgradeKind kind) => upgrades[kind]!;

  /// 교환소 — 젤리 [exchangeJellyPerTrade] 개당 방치 몇 시간치를 주는가.
  ///
  /// 지급량을 현재 스테이지 산출에 비례시키는 이유: 정액이면 후반엔 껌값이라
  /// 아무도 안 쓴다. 정작 젤리가 남아도는 시점이 후반이다.
  final int exchangeJellyPerTrade;
  final double exchangeGoldHours;
  final double exchangeMaterialHours;
  final int exchangeKillsPerHour;

  /// 몬스터 도감(id → 정의). JSON `monsters` 배열에서 읽는다.
  ///
  /// 비어 있으면 지역의 옛 `habitatKinds` 가 그대로 쓰인다(구버전 호환).
  final Map<String, MonsterDef> monsters;

  /// 엘리트가 나올 확률(서식지 한 칸당). 보스 칸에는 안 걸린다.
  final double eliteChance;

  /// 엘리트 체력 배율. **적응형 체력 위에** 곱한다 — 월드 관문(worldHpMult)과
  /// 같은 층이다. 기준(§7)에 넣으면 안 된다: 넣는 순간 일반 몬스터까지
  /// 같이 세져서 엘리트가 "특별한 놈"이 아니라 그냥 인플레가 된다.
  final double eliteHpMult;

  /// 엘리트 보상 배율(골드·재료·경험치).
  ///
  /// ⚠️ **이 값이 [eliteHpMult] 보다 커야 한다.** 안 그러면 엘리트가 시간만
  /// 먹는 **세금**이 된다: 시간은 `1-c+c*hp` 배, 수입은 `1-c+c*reward` 배로
  /// 늘어나므로 `reward < hp` 면 시간당 수입이 **줄어든다**.
  /// (초안 체력 x4 · 보상 x3 이 정확히 그랬다 — 시간당 -5.1%.)
  /// 지금 값: 시간 +12% · 수입 +18% · **시간당 +5.4%**.
  final double eliteRewardMult;

  /// 엘리트 크기 배율(연출). 한눈에 달라 보여야 사건이 된다.
  final double eliteScale;

  /// 관문(월드 보스) 앞 장비 안내의 **권장 장비 공격 배율** — 완성치와 완성 시점.
  ///
  /// 권장치 = `1 + (gearHintMult - 1) × min(1, 스테이지 / gearHintFullStage)`.
  /// balance_sim 의 "평균 유저" 장비 가정(x1.70@900)과 **같은 숫자**여야 한다 —
  /// 시뮬이 그 장비로 22일에 끝나니, 그보다 약하면 실제로 벽에 막힌다.
  /// 안내는 벽을 만들지 않는다. **왜 막히는지, 무엇을 모으면 되는지**를 말할 뿐이다.
  final double gearHintMult;
  final int gearHintFullStage;

  /// [stageNumber] 에서 권장하는 장비 공격 배율.
  double gearHintAt(int stageNumber) {
    if (gearHintFullStage <= 0) return gearHintMult;
    final t = (stageNumber / gearHintFullStage).clamp(0.0, 1.0);
    return 1 + (gearHintMult - 1) * t;
  }

  /// 곤충 속성이 몬스터를 克할 때 **그 곤충의 타격에만** 곱하는 배율(§2.3).
  ///
  /// 이것이 이 시스템의 **유일한 §7 기준 밖 이득**이다. 3마리 다 상극이어도
  /// 총 DPS 는 `1 + petShare x (이 값 - 1)` 을 넘지 않는다 — 전설 3마리 기준
  /// x1.21. 올리기 전에 `balance_sim --pet-restrain` 을 반드시 돌린다.
  ///
  /// "편성을 맞췄는데 체감이 약하다"면 이 값이 아니라 **곤충 지분**
  /// (`pets.json → gradeAttackPct`)을 키운다 — 여기만 올리면 편성을 못 맞춘
  /// 유저와의 격차만 벌어지고 총량은 별로 안 는다.
  final double petRestrainMult;

  factory RunConfig.fromJson(Map<String, dynamic> json) {
    final upgradeList = (json['upgrades'] as List)
        .cast<Map<String, dynamic>>()
        .map(UpgradeSpec.fromJson);
    return RunConfig(
      hpBase: (json['hpBase'] as num).toDouble(),
      onlineGoldBonus: (json['onlineGoldBonus'] as num?)?.toDouble() ?? 0,
      exchangeJellyPerTrade:
          ((json['exchange'] as Map<String, dynamic>?)?['jellyPerTrade']
                  as num?)
              ?.toInt() ??
          10,
      exchangeGoldHours:
          ((json['exchange'] as Map<String, dynamic>?)?['goldHours'] as num?)
              ?.toDouble() ??
          1.0,
      exchangeMaterialHours:
          ((json['exchange'] as Map<String, dynamic>?)?['materialHours']
                  as num?)
              ?.toDouble() ??
          1.0,
      exchangeKillsPerHour:
          ((json['exchange'] as Map<String, dynamic>?)?['killsPerHour'] as num?)
              ?.toInt() ??
          900,
      sceneCatchChance: (json['sceneCatchChance'] as num?)?.toDouble() ?? 0.35,
      sceneCatchWindow: (json['sceneCatchWindow'] as num?)?.toDouble() ?? 1.4,
      sceneCatchCooldown:
          (json['sceneCatchCooldown'] as num?)?.toDouble() ?? 25,
      materialAmountGrowth:
          (json['materialAmountGrowth'] as num?)?.toDouble() ?? 1.0,
      threatAdaptTargetPct:
          (json['threatAdaptTargetPct'] as num?)?.toDouble() ?? 0,
      threatAdaptPower: (json['threatAdaptPower'] as num?)?.toDouble() ?? 0.85,
      threatAdaptMinRatio:
          (json['threatAdaptMinRatio'] as num?)?.toDouble() ?? 0.5,
      threatAdaptMaxRatio:
          (json['threatAdaptMaxRatio'] as num?)?.toDouble() ?? 1000,
      threatAdaptDepthStart:
          (json['threatAdaptDepthStart'] as num?)?.toDouble() ?? 0,
      threatAdaptDepthGain:
          (json['threatAdaptDepthGain'] as num?)?.toDouble() ?? 0,
      threatAdaptDepthMax:
          (json['threatAdaptDepthMax'] as num?)?.toDouble() ?? 1,
      threatEquipShare: (json['threatEquipShare'] as num?)?.toDouble() ?? 0,
      hpAdaptTargetHits: (json['hpAdaptTargetHits'] as num?)?.toDouble() ?? 0,
      hpAdaptPower: (json['hpAdaptPower'] as num?)?.toDouble() ?? 0,
      hpAdaptMinRatio: (json['hpAdaptMinRatio'] as num?)?.toDouble() ?? 0.5,
      hpAdaptMaxRatio: (json['hpAdaptMaxRatio'] as num?)?.toDouble() ?? 1000,
      hpGrowth: (json['hpGrowth'] as num).toDouble(),
      bossHpMult: (json['bossHpMult'] as num).toDouble(),
      goldBase: (json['goldBase'] as num).toDouble(),
      goldGrowth: (json['goldGrowth'] as num).toDouble(),
      xpBase: (json['xpBase'] as num).toDouble(),
      xpGrowth: (json['xpGrowth'] as num).toDouble(),
      bossRewardMult: (json['bossRewardMult'] as num).toDouble(),
      habitatsPerStage: (json['habitatsPerStage'] as num).toInt(),
      bugDropChance: (json['bugDropChance'] as num).toDouble(),
      materialDropChance: (json['materialDropChance'] as num).toDouble(),
      regions: json['regions'] != null
          ? (json['regions'] as List)
                .cast<Map<String, dynamic>>()
                .map(RegionConfig.fromJson)
                .toList()
          : [RegionConfig.fromJson(json['region'] as Map<String, dynamic>)],
      stagesPerRegion: (json['stagesPerRegion'] as num?)?.toInt() ?? 10,
      boostStepPerTap: (json['boostStepPerTap'] as num?)?.toDouble() ?? 0.15,
      boostMultMax: (json['boostMultMax'] as num?)?.toDouble() ?? 5.0,
      critChanceMax: (json['critChanceMax'] as num?)?.toDouble() ?? 0.85,
      critBudgetUpgrade: (json['critBudgetUpgrade'] as num?)?.toDouble() ?? 1.0,
      critBudgetGear: (json['critBudgetGear'] as num?)?.toDouble() ?? 1.0,
      critBudgetOther: (json['critBudgetOther'] as num?)?.toDouble() ?? 1.0,
      walkThreatMult: (json['walkThreatMult'] as num?)?.toDouble() ?? 0.0,
      boostDecayPerSec: (json['boostDecayPerSec'] as num?)?.toDouble() ?? 0.4,
      boostSpeedFactor: (json['boostSpeedFactor'] as num?)?.toDouble() ?? 1.0,
      upgrades: {for (final u in upgradeList) u.kind: u},
      threatBase: (json['threatBase'] as num?)?.toDouble() ?? 3.0,
      threatGrowth: (json['threatGrowth'] as num?)?.toDouble() ?? 1.12,
      bossThreatMult: (json['bossThreatMult'] as num?)?.toDouble() ?? 4.0,
      killHealPct: (json['killHealPct'] as num?)?.toDouble() ?? 0.05,
      bossKillHealPct: (json['bossKillHealPct'] as num?)?.toDouble() ?? 0.3,
      killHealMissingPct: (json['killHealMissingPct'] as num?)?.toDouble() ?? 0,
      bossKillHealMissingPct:
          (json['bossKillHealMissingPct'] as num?)?.toDouble() ?? 0,
      enemyFirstBiteDelay:
          (json['enemyFirstBiteDelay'] as num?)?.toDouble() ?? 0,
      enemyFollowBiteMult:
          (json['enemyFollowBiteMult'] as num?)?.toDouble() ?? 1.0,
      enemyAtkInterval: (json['enemyAtkInterval'] as num?)?.toDouble() ?? 1.5,
      bossAtkInterval: (json['bossAtkInterval'] as num?)?.toDouble() ?? 1.3,
      bossHitMult: (json['bossHitMult'] as num?)?.toDouble() ?? 1.4,
      offlineEfficiency: (json['offlineEfficiency'] as num?)?.toDouble() ?? 0.3,
      worldSize: (json['worldSize'] as num?)?.toInt() ?? 0,
      worldHpMult: (json['worldHpMult'] as num?)?.toDouble() ?? 1.0,
      tierHitsMult: (json['tierHitsMult'] as num?)?.toDouble() ?? 1.0,
      tierThreatMult: (json['tierThreatMult'] as num?)?.toDouble() ?? 1.0,
      endParkedRewardMult:
          (json['endParkedRewardMult'] as num?)?.toDouble() ?? 1.0,
      rarePityKills: (json['rarePityKills'] as num?)?.toInt() ?? 0,
      dropGradeWeights: {
        if (json['dropGradeWeights'] is Map)
          for (final e in (json['dropGradeWeights'] as Map).entries)
            if (Grade.fromKeyOrNull(e.key as String) != null)
              Grade.fromKeyOrNull(e.key as String)!: (e.value as num)
                  .toDouble(),
      },
      tierRewardMult: (json['tierRewardMult'] as num?)?.toDouble() ?? 1.0,
      zoneMode: json['zoneMode'] as bool? ?? false,
      bossUnlockKills: (json['bossUnlockKills'] as num?)?.toInt() ?? 100,
      zonesPerTier: (json['zonesPerTier'] as num?)?.toInt() ?? 11,
      worldGoldMult: (json['worldGoldMult'] as num?)?.toDouble() ?? 1.0,
      worldBossHpMult: (json['worldBossHpMult'] as num?)?.toDouble() ?? 1.0,
      monsters: {
        for (final m in (json['monsters'] as List? ?? const []))
          (m as Map<String, dynamic>)['id'] as String: MonsterDef.fromJson(m),
      },
      eliteChance: (json['eliteChance'] as num?)?.toDouble() ?? 0.06,
      eliteHpMult: (json['eliteHpMult'] as num?)?.toDouble() ?? 3.0,
      eliteRewardMult: (json['eliteRewardMult'] as num?)?.toDouble() ?? 4.0,
      eliteScale: (json['eliteScale'] as num?)?.toDouble() ?? 1.45,
      gearHintMult: (json['gearHintMult'] as num?)?.toDouble() ?? 1.70,
      gearHintFullStage: (json['gearHintFullStage'] as num?)?.toInt() ?? 900,
      petRestrainMult: (json['petRestrainMult'] as num?)?.toDouble() ?? 1.5,
    );
  }
}
