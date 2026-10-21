import 'dart:math' as math;

import 'jelly_cost.dart';

import 'package:core_models/core_models.dart';
import 'package:meta/meta.dart';

import 'item_config.dart';

/// 공방(제련) 설정 (assets/data/forge.json).
@immutable
class ForgeConfig {
  const ForgeConfig({
    this.hammerSeconds = 3.0,
    this.centerPerLevel = 0.30,
    this.spread = 1.05,
    this.lowDecay = 0.25,
    this.lowDecayOffset = 1.2,
    this.maxLevel = 20,
    this.levelUpSteps = 10,
    this.levelUpGoldBase = 300000,
    this.levelUpGoldGrowth = 2.4,
    this.levelUpLateFrom = 0,
    this.levelUpLateGoldGrowth = 0,
    this.levelUpLateSpan = 0,
    this.levelUpEndGoldGrowth = 0,
    this.levelUpBaseSeconds = 3600,
    this.levelUpGrowth = 1.28,
    this.levelUpJellyPerHour = 2,
    this.levelUpJellyMin = 5,
    this.levelUpTranscendGoldMult = 1,
    this.levelUpTranscendTimeMult = 1,
    this.levelUpTranscendGoldFloorLevel = 0,
    this.levelUpTranscendTimeFloorHours = 0,
    this.fossilPerSecond = 0.0556,
    this.fossilOfflineRatio = 0.333,
    this.fossilMinPerDrop = 1,
    this.autoStrikeMax = 10,
    this.autoStrikeFullFromTier = 1,
    this.rerollJelly = 15,
    this.polishFossilPerTier = 20,
    this.polishKindMult = 3,
    this.polishCostGrowth = 1.0,
    this.transcendMax = 5,
    this.transcendStep = 0.15,
    this.transcendFossilBase = 10000,
    this.transcendBaseHours = 0,
    this.transcendStepHours = 0,
    this.sellMaterialBase = 2,
    this.sellMaterialPerTier = 1,
    this.rushSeconds = 60,
    this.rushJelly = 10,
    this.stackExpandJelly = 100,
    this.stackExpandStep = 2,
    this.stackExpandMax = 20,
  });

  /// 망치질 간격(초). 3초에 한 번 땅! — 연출이자 **속도 제한**이다.
  final double hammerSeconds;

  /// 확률 창의 중심이 레벨당 얼마나 오르는가.
  final double centerPerLevel;

  /// 창의 폭(클수록 여러 등급이 섞인다).
  final double spread;

  /// 중심보다 **아래** 등급을 얼마나 빨리 죽이는가(작을수록 빨리 0%).
  final double lowDecay;
  final double lowDecayOffset;

  final int maxLevel;

  /// 등급업 골드를 몇 칸으로 나눠 받는가.
  ///
  /// 한 번에 다 못 내도 **조금씩 부어둘 수 있고**, 얼마나 남았는지가 눈에 보인다.
  /// 칸을 다 채우면 그때 업그레이드(시간)가 시작된다.
  final int levelUpSteps;

  /// 레벨 0 → 1 에 드는 **총** 골드. 레벨마다 [levelUpGoldGrowth] 배.
  ///
  /// 골드는 업그레이드 15종과 경쟁한다 — "지금 공격력이냐 공방이냐"가 선택이 된다.
  /// 실측 골드 수입 곡선에 맞춰 역산했다(수입의 30% 투입 기준 레벨 20 = 36일).
  final double levelUpGoldBase;
  final double levelUpGoldGrowth;

  /// 이 레벨부터는 골드가 [levelUpLateGoldGrowth] 배씩 오른다(0 이면 끔).
  ///
  /// 후반만 비싸게 하려고 둔다(2026-09-15). 한 배율로는 앞까지 같이 비싸져 초반
  /// 장비가 늦어지는데, 극한에서는 최상급 장비가 며칠이면 최고치를 넘어
  /// 170% 까지 넘쳤다. 시간(타이머)은 건드리지 않는다 — 즉시완료 젤리 값이 따라 오른다.
  final int levelUpLateFrom;
  final double levelUpLateGoldGrowth;

  /// 가파른 구간의 길이(레벨 수). 0 이면 끝까지 가파르다. 그 뒤로는
  /// [levelUpEndGoldGrowth] 배씩 — 극한을 깬 뒤 몇 주에 걸쳐 올리는 **후반 목표**가
  /// 되게 한다(끝까지 x15 면 17등급부터 1경이라 영영 못 올렸다).
  final int levelUpLateSpan;
  final double levelUpEndGoldGrowth;

  /// 칸을 다 채운 뒤 걸리는 시간(레벨 0 → 1). 레벨마다 [levelUpGrowth] 배씩.
  final int levelUpBaseSeconds;
  final double levelUpGrowth;

  /// 즉시완료 젤리 — 남은 시간 1시간당.
  final int levelUpJellyPerHour;
  final int levelUpJellyMin;

  /// 초월 뒤 등급업(2026-10-12 사장님 재확정) — 초월 단계 t>0 이면 골드 =
  /// max(원래 비용(레벨), 원래 비용([levelUpTranscendGoldFloorLevel])) × 이 값^t.
  /// 앞쪽 레벨도 싸지 않고 전체는 단계마다 이 배율만큼 오른다. t=0 이면 원래 비용 그대로.
  final double levelUpTranscendGoldMult;

  /// 초월 뒤 등급업 시간 — t>0 이면 max(원래 시간, [levelUpTranscendTimeFloorHours]시간) × 이 값^t
  /// (즉시 완료 젤리도 시간에서 나와 따라 오른다).
  final double levelUpTranscendTimeMult;

  /// 초월 뒤 골드 바닥 = 이 레벨의 원래 등급업 비용.
  final int levelUpTranscendGoldFloorLevel;

  /// 초월 뒤 시간 바닥(시간).
  final int levelUpTranscendTimeFloorHours;

  /// 등급업 골드 상한 — int64(9.2e18) 넘침 방지. 초월 뒤 후반 비용이 이 값을 넘으면 여기서 자른다.
  static const int levelUpGoldCap = 9000000000000000000;

  /// 화석 조각 **온라인 초당 기대 획득**.
  ///
  /// ⚠️ 재료(`materialAmountGrowth`)처럼 스테이지에 따라 키우면 **안 된다.**
  /// 제련 비용은 영원히 1개 고정이라 수입도 절대량으로 일정해야 한다 —
  /// 지수로 키우면 후반에 무한히 남아돈다.
  final double fossilPerSecond;

  /// 오프라인 획득 비율(온라인 대비).
  final double fossilOfflineRatio;

  final int fossilMinPerDrop;

  /// 자동 제련 **한 번의 망치질로 뽑는 개수**의 상한.
  final int autoStrikeMax;

  /// 이 회차([SaveGame.difficultyTier]) 부터는 챕터와 무관하게 [autoStrikeMax].
  ///
  /// 회차를 넘기면 스테이지가 1로 돌아가므로(§랭킹 3축), 챕터만 보면
  /// **2회차 시작이 1회차 끝보다 느려진다** — 넘어갈 이유가 사라진다.
  final int autoStrikeFullFromTier;

  /// 망치질 한 번에 뽑는 개수. 챕터가 곧 개수이고, [autoStrikeFullFromTier]
  /// 이상의 회차면 처음부터 상한이다.
  ///
  /// 필터와 **한 세트**다 — 모루는 10칸뿐이라 거르지 않으면 한 번에 차서
  /// 자동이 곧바로 멈춘다. 거르고 돌릴 때 비로소 빨라진다.
  int autoStrikes({required int difficultyTier, required int chapter}) {
    if (difficultyTier >= autoStrikeFullFromTier) return autoStrikeMax;
    final n = chapter < 1 ? 1 : chapter;
    return n > autoStrikeMax ? autoStrikeMax : n;
  }

  /// 실제로 뽑을 개수 — 유저가 고른 [chosen] 을 해금 상한으로 자른다.
  ///
  /// [chosen] 이 0 이하면 **상한 그대로**다. 고른 적 없는 유저(기본값 0)의
  /// 체감이 바뀌면 안 되고, 챕터를 깨서 상한이 오르면 자동으로 따라 오른다.
  ///
  /// ⚠️ 상한으로 자르는 건 여기 한 곳이다 — 세이브의 [chosen] 은 손으로
  /// 고칠 수 있으므로 화면이 아니라 계산에서 잘라야 챕터를 건너뛸 수 없다.
  int effectiveStrikes({
    required int difficultyTier,
    required int chapter,
    required int chosen,
  }) {
    final max = autoStrikes(difficultyTier: difficultyTier, chapter: chapter);
    if (chosen <= 0 || chosen > max) return max;
    return chosen;
  }

  /// 모루 위 장비의 **옵션만** 다시 굴리는 값(§2.6).
  ///
  /// 등급은 안 바뀐다 — 등급을 젤리로 바꾸면 그건 물건을 사는 것이다.
  /// 옵션은 제련을 계속 돌리면 언젠가 나오는 조합이라, 파는 것은 시간 절약이다.
  final int rerollJelly;

  /// 다듬기 화석 비용 = 이 값 × (등급 + 1)(2026-10-21 40 — 풀잎 40 · 호박 400 ≈ 접속 2시간).
  /// 화석 경로가 있어 젤리([rerollJelly])는 시간 절약이다(§2.6 — 젤리로만 되면 스탯 판매).
  final int polishFossilPerTier;

  /// 옵션 종류를 지정해 다듬을 때 비용 배율(화석·젤리 모두).
  final int polishKindMult;

  /// 다듬기 비용이 **그 줄을 다듬은 횟수**마다 곱해지는 배율(2026-10-16 사장님 확정 — 다듬기는 늘 더 좋은 값이
  /// 나오는 대신 할수록 비싸진다). 1 이면 예전처럼 정액. 오르기는 `ItemConfig.polishMaxStacks` 번에서 멈춘다(정성 상한).
  final double polishCostGrowth;

  /// 공방 초월(2026-10-10 사장님 확정) — 공방 최대 레벨에서 초월하면 장비가 전부 사라지고 공방이 **풀잎부터 다시**,
  /// 대신 모든 등급의 옵션 최대치가 단계마다 [transcendStep] 씩 오른다(5단계 +75%).
  final int transcendMax;
  final double transcendStep;

  /// 초월 비용(화석) = 이 값 × (지금 단계 + 1). 젤리로 사지 못한다(단계 = 영구 능력치 — §2.6).
  final int transcendFossilBase;

  /// 초월에 걸리는 시간(2026-10-12 사장님 확정) — 지금 단계 n(0부터) → n+1 에
  /// [transcendBaseHours] + [transcendStepHours] × n 시간(24·36·48·60·72). 0 이면 즉시.
  /// 즉시 완료 젤리는 등급업과 같은 값표([levelUpJelly]).
  final int transcendBaseHours;
  final int transcendStepHours;

  /// 초월 [n] 단계 → [n]+1 에 걸리는 시간.
  Duration transcendDuration(int n) => Duration(
    hours: transcendBaseHours + transcendStepHours * n.clamp(0, transcendMax),
  );

  /// 초월 [n] 단계의 옵션 최대치 배율.
  double transcendMaxMult(int n) =>
      1 + transcendStep * n.clamp(0, transcendMax);

  /// 초월 [n] 단계 → [n]+1 비용(화석).
  int transcendFossilCost(int n) => transcendFossilBase * (n + 1);

  /// 다듬기 1회 비용 — 화석으로 낼 때 / 젤리로 낼 때. [done] = 그 줄을 이미 다듬은 횟수(옵션 `p`).
  /// 횟수마다 ×[polishCostGrowth](젤리는 5·10 단위 가격표로 — `roundJellyCost`).
  ({int fossils, int jelly}) polishCost(
    int tier, {
    required bool pickKind,
    int done = 0,
  }) {
    final m = pickKind ? polishKindMult : 1;
    final g = math.pow(polishCostGrowth, done.clamp(0, 99)).toDouble();
    return (
      fossils: (polishFossilPerTier * (tier.clamp(0, 1 << 10) + 1) * m * g)
          .round(),
      jelly: g == 1 ? rerollJelly * m : roundJellyCost(rerollJelly * m * g),
    );
  }

  /// 장비를 팔 때 주는 일반 재료 — `base + perTier * 등급`.
  ///
  /// ⚠️ **젤리·화석은 주지 않는다.** 자동 제련은 방치 중에도 계속 돌아
  /// 무한 통로이고(§2.6 젤리 수도꼭지), 화석을 되돌려주면 제련이 공짜가 된다.
  final int sellMaterialBase;
  final int sellMaterialPerTier;

  /// 장비 [tier] 를 팔 때 나오는 재료 수.
  int sellMaterialCount(int tier) =>
      (sellMaterialBase + sellMaterialPerTier * tier).clamp(0, 1 << 20);

  /// 망치질 가속 — [rushJelly] 젤리로 [rushSeconds] 초 동안 간격 절반.
  final int rushSeconds;
  final int rushJelly;

  /// 모루 칸 확장 — 첫 값 [stackExpandJelly], [stackExpandStep] 칸씩,
  /// [stackExpandMax] 까지. 비용은 **살수록 오른다**(계단식).
  final int stackExpandJelly;
  final int stackExpandStep;
  final int stackExpandMax;

  /// [bought] 번째 확장(0-based)의 젤리 값. 채집함과 같은 계단식이다 —
  /// 정액이면 다 사고 나서 젤리 쓸 데가 없어진다(§2.6).
  int stackExpandCost(int bought) =>
      roundJellyCost(stackExpandJelly * math.pow(1.35, bought).toDouble());

  /// 현재 레벨 [level] → [level]+1 에 드는 **총** 골드. [transcend] = 초월 단계(진행 중 포함 —
  /// core_save `forgeCostTranscend`). t>0 이면 [levelUpTranscendGoldMult] 주석의 식. [levelUpGoldCap] 에서 자른다.
  int levelUpGold(int level, {int transcend = 0}) {
    var v = _baseLevelUpGold(level);
    if (transcend > 0) {
      v =
          math.max(v, _baseLevelUpGold(levelUpTranscendGoldFloorLevel)) *
          math.pow(levelUpTranscendGoldMult, transcend);
    }
    if (!v.isFinite || v >= levelUpGoldCap) return levelUpGoldCap;
    return v.round();
  }

  double _baseLevelUpGold(int level) {
    final on = levelUpLateFrom > 0 && levelUpLateGoldGrowth > 0;
    final beyond = on ? math.max(0, level - levelUpLateFrom) : 0;
    final late = levelUpLateSpan > 0
        ? math.min(beyond, levelUpLateSpan)
        : beyond;
    final end = beyond - late;
    final early = level - beyond;
    return levelUpGoldBase *
        math.pow(levelUpGoldGrowth, early) *
        math.pow(on ? levelUpLateGoldGrowth : 1, late) *
        math.pow(
          levelUpEndGoldGrowth <= 0 ? levelUpGoldGrowth : levelUpEndGoldGrowth,
          end,
        );
  }

  /// 칸 하나에 드는 골드(총액을 [levelUpSteps] 로 나눈 값).
  int levelUpStepGold(int level, {int transcend = 0}) {
    final steps = levelUpSteps <= 0 ? 1 : levelUpSteps;
    // 정수 올림 나눗셈 — 후반 비용(수경)은 double 로 나누면 정밀도가 모자라
    // 칸 × 10 이 총액보다 몇 골드 작아진다. (상한 9e18 + 칸 수는 int64 안이다.)
    return (levelUpGold(level, transcend: transcend) + steps - 1) ~/ steps;
  }

  /// 등급업에 걸리는 시간 — 현재 레벨 [level] → [level]+1. [transcend] = 초월 단계(진행 중 포함).
  /// t>0 이면 max(원래 시간, [levelUpTranscendTimeFloorHours]시간) × [levelUpTranscendTimeMult]^t.
  Duration levelUpDuration(int level, {int transcend = 0}) {
    var sec = levelUpBaseSeconds * math.pow(levelUpGrowth, level).toDouble();
    if (transcend > 0) {
      sec =
          math.max(sec, levelUpTranscendTimeFloorHours * 3600.0) *
          math.pow(levelUpTranscendTimeMult, transcend);
    }
    return Duration(seconds: sec.round());
  }

  /// 남은 시간 [remaining] 을 즉시 끝내는 젤리 값.
  int levelUpJelly(Duration remaining) {
    if (remaining <= Duration.zero) return 0;
    final hours = remaining.inSeconds / 3600.0;
    // 가격표로 읽히게 5·10 단위로 맞춘다(§2.6) — 하한은 그대로.
    final v = roundJellyCost(hours * levelUpJellyPerHour);
    return v < levelUpJellyMin ? levelUpJellyMin : v;
  }

  /// 공방 레벨 [level] 에서의 **등급별 확률**(합 1.0).
  ///
  /// 레벨이 오르면 하위 등급이 **아예 0%** 가 되고 창이 위로 미끄러진다 —
  /// 항상 3~4개 등급만 나온다. 레벨마다 표를 손으로 적지 않는 이유는,
  /// 등급을 11·12 로 늘려도 계수 두 개만 만지면 되기 때문이다.
  List<double> tierWeights(int level, int tierCount) {
    if (tierCount <= 0) return const [];
    final center = level * centerPerLevel;
    final raw = <double>[];
    for (var i = 0; i < tierCount; i++) {
      final d = (i - center) / spread;
      var w = math.exp(-(d * d));
      // 중심보다 아래는 추가로 깎는다 — "하위는 이제 안 나온다"를 만든다.
      final below = center - i - lowDecayOffset;
      if (below > 0) w *= math.pow(lowDecay, below);
      raw.add(w);
    }
    final total = raw.fold<double>(0, (a, b) => a + b);
    if (total <= 0) {
      return [for (var i = 0; i < tierCount; i++) i == 0 ? 1.0 : 0.0];
    }
    return [for (final w in raw) w / total];
  }

  factory ForgeConfig.fromJson(Map<String, dynamic> json) {
    final tier = json['tier'] as Map<String, dynamic>? ?? const {};
    final lv = json['levelUp'] as Map<String, dynamic>? ?? const {};
    final fs = json['fossil'] as Map<String, dynamic>? ?? const {};
    return ForgeConfig(
      hammerSeconds: (json['hammerSeconds'] as num?)?.toDouble() ?? 3.0,
      centerPerLevel: (tier['centerPerLevel'] as num?)?.toDouble() ?? 0.30,
      spread: (tier['spread'] as num?)?.toDouble() ?? 1.05,
      lowDecay: (tier['lowDecay'] as num?)?.toDouble() ?? 0.25,
      lowDecayOffset: (tier['lowDecayOffset'] as num?)?.toDouble() ?? 1.2,
      maxLevel: (json['maxLevel'] as num?)?.toInt() ?? 20,
      levelUpSteps: (lv['steps'] as num?)?.toInt() ?? 10,
      levelUpGoldBase: (lv['goldBase'] as num?)?.toDouble() ?? 300000,
      levelUpGoldGrowth: (lv['goldGrowth'] as num?)?.toDouble() ?? 2.4,
      levelUpLateFrom: (lv['lateFrom'] as num?)?.toInt() ?? 0,
      levelUpLateGoldGrowth: (lv['lateGoldGrowth'] as num?)?.toDouble() ?? 0,
      levelUpLateSpan: (lv['lateSpan'] as num?)?.toInt() ?? 0,
      levelUpEndGoldGrowth: (lv['endGoldGrowth'] as num?)?.toDouble() ?? 0,
      levelUpBaseSeconds: (lv['baseSeconds'] as num?)?.toInt() ?? 3600,
      levelUpGrowth: (lv['growth'] as num?)?.toDouble() ?? 1.28,
      levelUpJellyPerHour: (lv['jellyPerHour'] as num?)?.toInt() ?? 2,
      levelUpJellyMin: (lv['jellyMin'] as num?)?.toInt() ?? 5,
      levelUpTranscendGoldMult:
          (lv['transcendGoldMult'] as num?)?.toDouble() ?? 1,
      levelUpTranscendTimeMult:
          (lv['transcendTimeMult'] as num?)?.toDouble() ?? 1,
      levelUpTranscendGoldFloorLevel:
          (lv['transcendGoldFloorLevel'] as num?)?.toInt() ?? 0,
      levelUpTranscendTimeFloorHours:
          (lv['transcendTimeFloorHours'] as num?)?.toInt() ?? 0,
      fossilPerSecond: (fs['perSecondOnline'] as num?)?.toDouble() ?? 0.0556,
      fossilOfflineRatio: (fs['offlineRatio'] as num?)?.toDouble() ?? 0.333,
      fossilMinPerDrop: (fs['minPerDrop'] as num?)?.toInt() ?? 1,
      autoStrikeMax: (json['autoStrikeMax'] as num?)?.toInt() ?? 10,
      rerollJelly: (json['rerollJelly'] as num?)?.toInt() ?? 15,
      polishFossilPerTier: (json['polishFossilPerTier'] as num?)?.toInt() ?? 20,
      polishKindMult: (json['polishKindMult'] as num?)?.toInt() ?? 3,
      polishCostGrowth: (json['polishCostGrowth'] as num?)?.toDouble() ?? 1.0,
      transcendMax: (json['transcendMax'] as num?)?.toInt() ?? 5,
      transcendStep: (json['transcendStep'] as num?)?.toDouble() ?? 0.15,
      transcendFossilBase:
          (json['transcendFossilBase'] as num?)?.toInt() ?? 10000,
      transcendBaseHours: (json['transcendBaseHours'] as num?)?.toInt() ?? 0,
      transcendStepHours: (json['transcendStepHours'] as num?)?.toInt() ?? 0,
      sellMaterialBase:
          ((json['sell'] as Map<String, dynamic>?)?['materialBase'] as num?)
              ?.toInt() ??
          2,
      sellMaterialPerTier:
          ((json['sell'] as Map<String, dynamic>?)?['materialPerTier'] as num?)
              ?.toInt() ??
          1,
      rushSeconds: (json['rushSeconds'] as num?)?.toInt() ?? 60,
      rushJelly: (json['rushJelly'] as num?)?.toInt() ?? 10,
      stackExpandJelly: (json['stackExpandJelly'] as num?)?.toInt() ?? 100,
      stackExpandStep: (json['stackExpandStep'] as num?)?.toInt() ?? 2,
      stackExpandMax: (json['stackExpandMax'] as num?)?.toInt() ?? 20,
      autoStrikeFullFromTier:
          (json['autoStrikeFullFromTier'] as num?)?.toInt() ?? 1,
    );
  }
}

/// 제련 1회 — 망치질 한 번으로 장비 하나가 나온다.
///
/// **완전 결정론**: 같은 [rng] 상태 + 같은 인자 → 같은 장비(헌법 §5).
/// 장비의 **옵션만** 다시 굴린다. 부위·등급은 그대로.
///
/// ⚠️ 등급을 건드리면 안 된다 — 등급을 젤리로 올리는 건 물건을 사는 것이라
/// §2.6 P2W 금지선을 넘는다. 옵션은 제련을 계속 돌리면 언젠가 나오는 조합이라
/// 파는 것이 **시간 절약**이다(곤충 알 뽑기 각주와 같은 논리).
///
/// 옵션 개수·최대치는 **그 등급의 규칙**을 그대로 따른다(`forgeOnce` 와 같은 코드).
EquipItem rerollOptions({
  double maxMult = 1,
  required math.Random rng,
  required ItemConfig items,
  required EquipItem item,
}) {
  final count = items.tier(item.tier).options;
  final pool = List<ItemOptionRange>.from(items.optionPool);
  final options = <ItemOption>[];
  for (var i = 0; i < count && pool.isNotEmpty; i++) {
    final r = pool.removeAt(rng.nextInt(pool.length));
    final roll = math.pow(rng.nextDouble(), items.optionCurve).toDouble();
    final hi = r.maxAt(item.tier) * maxMult;
    final v = r.min + roll * (hi - r.min);
    options.add(ItemOption(kind: r.kind, value: (v * 10).roundToDouble() / 10));
  }
  return item.copyWith(options: options);
}

/// 옵션 **한 칸만** 다시 굴린다(0-based [index]).
///
/// 사장님 확정(2026-09-09): 옵션 두 개를 **각각** 바꿀 수 있어야 한다. 통째로
/// 굴리면 마음에 드는 한 줄까지 같이 날아가서, 원하는 조합을 맞추는 게
/// 사실상 불가능하다.
///
/// ⚠️ **같은 종류가 겹치면 안 된다** — 나머지 칸에 이미 있는 종류를 빼고
/// 뽑는다. 공격력 두 줄이 붙으면 합산이라 한 줄과 다를 바가 없고,
/// 무엇보다 그 장비의 축이 하나로 줄어든다.
/// 등급·부위는 그대로다(등급을 젤리로 바꾸면 §2.6 P2W 금지선을 넘는다).
EquipItem rerollOptionAt({
  double maxMult = 1,
  required math.Random rng,
  required ItemConfig items,
  required EquipItem item,
  required int index,
}) {
  if (index < 0 || index >= item.options.length) return item;
  final others = {
    for (var i = 0; i < item.options.length; i++)
      if (i != index) item.options[i].kind,
  };
  final pool = items.optionPool
      .where((r) => !others.contains(r.kind))
      .toList(growable: false);
  if (pool.isEmpty) return item;
  final r = pool[rng.nextInt(pool.length)];
  final roll = math.pow(rng.nextDouble(), items.optionCurve).toDouble();
  final hi = r.maxAt(item.tier) * maxMult;
  final v = r.min + roll * (hi - r.min);
  final next = [...item.options];
  next[index] = ItemOption(kind: r.kind, value: (v * 10).roundToDouble() / 10);
  return item.copyWith(options: next);
}

/// 다듬기(2026-10-10 장비 v2, 옛 재굴림 대체) — 줄 [index] 의 **새 후보**를 굴린다. 고르는 건 호출부다.
///
/// - [kind] 를 주면 그 종류로(다른 줄에 이미 있는 종류면 null), 안 주면 다른 줄과 겹치지 않게 무작위.
///   무작위인데 지금 줄이 이미 최대면 지금 종류는 빼고 굴린다(같은 값만 나와 비용만 오르지 않게).
/// - 정성 +1(상한 `polishMaxStacks`) — 굴림 바닥 = 정성 × `polishFloorPerStack`(등급 범위 대비).
/// - [kept] = 정성만 오른 지금 장비(이전 값 유지를 고르면 이것), [candidate] = 새 값(고르면 [applyPolish]).
/// 정성은 **어느 쪽을 골라도 오른다** — 투자한 만큼 다음 굴림이 좋아진다.
/// 같은 종류면 새 값은 **지금 값 + 0.1 이상**(최대 이하)이다 — 0.1 단위 반올림 때문에 초월 배율로 최대가
/// 0.1 단위가 아니면(치명 확률 3 × 1.15 = 3.45) 늘 같은 값으로 반올림됐다(2026-10-16 출시 전 검토).
({EquipItem kept, ItemOption candidate})? polishOptionAt({
  double maxMult = 1,
  required math.Random rng,
  required ItemConfig items,
  required EquipItem item,
  required int index,
  ItemOptionKind? kind,
}) {
  if (index < 0 || index >= item.options.length) return null;
  final others = {
    for (var i = 0; i < item.options.length; i++)
      if (i != index) item.options[i].kind,
  };
  final curOpt = item.options[index];
  final curMaxed = _polishAtCap(items, item, index, maxMult);
  final pool = items.optionPool
      .where(
        (r) =>
            !others.contains(r.kind) &&
            (kind == null || r.kind == kind) &&
            // 같은 종류로 다듬어도 오를 데가 없으면 그 종류는 후보가 아니다.
            !(r.kind == curOpt.kind && curMaxed),
      )
      .toList(growable: false);
  if (pool.isEmpty) return null;
  final r = pool[rng.nextInt(pool.length)];
  final polish = math.min(curOpt.polish + 1, items.polishMaxStacks);
  // **늘 지금보다 좋게**(2026-10-16 사장님 확정) — 지금 값의 범위 안 위치(0~1)와 최대 사이에서 굴린다.
  // 종류가 바뀌어도 "범위 안 위치"로 견준다. 예전엔 바닥(정성)만 올라 높은 값 뒤에 낮은 값이 나왔다.
  final at = polishPositionOf(items, item, index, maxMult: maxMult);
  final hi = r.maxAt(item.tier) * maxMult;
  final roll = at + (1 - at) * (0.05 + 0.95 * rng.nextDouble());
  final v = r.min + roll.clamp(0.0, 1.0) * (hi - r.min);
  final cap = math.max(polishCapOf(r, item.tier, maxMult), _round1(r.min));
  var value = math.min(_round1(v), cap);
  if (r.kind == curOpt.kind) {
    value = math.min(math.max(value, _round1(curOpt.value + 0.1)), cap);
  }
  final cur = [...item.options];
  cur[index] = cur[index].copyWith(polish: polish);
  return (
    kept: item.copyWith(options: cur),
    candidate: ItemOption(kind: r.kind, value: value, polish: polish),
  );
}

double _round1(double v) => (v * 10).roundToDouble() / 10;

/// 다듬기로 닿을 수 있는 가장 큰 값 — 그 등급 최대 × [maxMult] 를 0.1 단위로 **내린** 값
/// (3 × 1.15 = 3.45 → 3.4). 다듬기 값은 0.1 단위라 이보다 크게는 못 간다.
double polishCapOf(ItemOptionRange r, int tier, double maxMult) =>
    (r.maxAt(tier) * maxMult * 10 + 1e-6).floorToDouble() / 10;

bool _polishAtCap(ItemConfig items, EquipItem item, int index, double maxMult) {
  final o = item.options[index];
  final r = items.optionPool.where((x) => x.kind == o.kind).firstOrNull;
  if (r == null) return true;
  return o.value >= polishCapOf(r, item.tier, maxMult) - 1e-9;
}

/// 줄 [index] 의 지금 값이 그 종류 범위(최소 ~ 그 등급 최대 × [maxMult]) 안에서 어디쯤인지(0~1).
double polishPositionOf(
  ItemConfig items,
  EquipItem item,
  int index, {
  double maxMult = 1,
}) {
  final o = item.options[index];
  final r = items.optionPool.where((x) => x.kind == o.kind).firstOrNull;
  if (r == null) return 0;
  final hi = r.maxAt(item.tier) * maxMult;
  if (hi <= r.min) return 1;
  return ((o.value - r.min) / (hi - r.min)).clamp(0.0, 1.0);
}

/// 이 다듬기가 더 나아질 수 없나 — [kind] 는 [polishOptionAt] 에 넘길 값 그대로(null = 무작위).
///
/// - 지정 종류가 지금 종류와 **다르면** 막지 않는다(종류를 바꾸는 다듬기 — 최소 = 최대인 줄도 바꿀 수 있다).
/// - 지정 종류가 지금 종류와 같으면 지금 값이 0.1 단위로 내린 최대([polishCapOf]) 이상일 때 최대.
/// - 무작위는 다른 종류가 나올 수 있으니 막지 않는다 — 다른 줄과 겹치지 않는 후보가 지금 종류뿐일 때만 위처럼 검사.
bool polishMaxed(
  ItemConfig items,
  EquipItem item,
  int index, {
  double maxMult = 1,
  ItemOptionKind? kind,
}) {
  if (index < 0 || index >= item.options.length) return true;
  final curKind = item.options[index].kind;
  if (kind != null) {
    if (kind != curKind) return false;
    return _polishAtCap(items, item, index, maxMult);
  }
  final others = {
    for (var i = 0; i < item.options.length; i++)
      if (i != index) item.options[i].kind,
  };
  final otherKindPossible = items.optionPool.any(
    (r) => !others.contains(r.kind) && r.kind != curKind,
  );
  if (otherKindPossible) return false;
  return _polishAtCap(items, item, index, maxMult);
}

/// 다듬기 결과에서 **새 값**을 고른다.
EquipItem applyPolish(EquipItem item, int index, ItemOption candidate) {
  if (index < 0 || index >= item.options.length) return item;
  final next = [...item.options];
  next[index] = candidate;
  return item.copyWith(options: next);
}

/// [fodder] 를 [target] 의 별 재료로 쓸 수 있는지 — 같은 부위 · 등급이 (장착 등급 − `starTierSlack`) 이상 ·
/// 별 만렙 아님 · 재료가 만렙까지 남은 합([ItemConfig.starNeedRemaining])보다 적음.
/// **강화 시간이 도는 중에도 받는다**(2026-10-14 사장님 확정 — 다음 별 몫으로 이월). 예전엔 이번 별 몫이 차거나
/// 강화 중이면 같은 부위 장비가 일반 재료로 팔려 "별이 꽉 차면 적립이 안 된다"로 보였다.
bool canFeedStar(ItemConfig items, EquipItem target, EquipItem fodder) =>
    fodder.slot == target.slot &&
    target.stars < items.starMax &&
    target.starExp < items.starNeedRemaining(target.stars) &&
    fodder.tier >= target.tier - items.starTierSlack;

/// 별 재료 하나를 먹인다. 다 모여도 별은 바로 오르지 않는다 — [startStarUp] 으로 강화 시간을 건다(2026-10-10).
/// 이번 별 몫을 넘긴 재료는 다음 별로 이월된다([finishStarUp] 이 이번 몫만 뺀다).
EquipItem feedStar(ItemConfig items, EquipItem target) {
  if (target.stars >= items.starMax) return target;
  if (target.starExp >= items.starNeedRemaining(target.stars)) return target;
  return target.copyWith(starExp: target.starExp + 1);
}

/// 이번 별 강화에 쓸 재료가 다 모였나(강화를 시작할 수 있나) — 화면의 "★ 준비 완료" 표시용.
bool starReady(ItemConfig items, EquipItem target) =>
    target.stars < items.starMax &&
    target.starUntil == null &&
    target.starExp >= items.starNeedAt(target.stars);

/// 재료가 다 모였으면 별 강화를 시작한다(끝나는 시각 = [now] + `starUpDuration`). 못 하면 null.
EquipItem? startStarUp(ItemConfig items, EquipItem target, DateTime now) {
  if (target.stars >= items.starMax || target.starUntil != null) return null;
  if (target.starExp < items.starNeedAt(target.stars)) return null;
  return target.copyWith(
    starUntil: now.toUtc().add(
      items.starUpDuration(target.stars, tier: target.tier),
    ),
  );
}

/// 별 강화 마치기 — 시간이 됐거나 [force](젤리로 당김)면 별 +1. 못 하면 null.
EquipItem? finishStarUp(
  ItemConfig items,
  EquipItem target,
  DateTime now, {
  bool force = false,
}) {
  final until = target.starUntil;
  if (until == null) return null;
  if (!force && now.toUtc().isBefore(until)) return null;
  final next = (target.stars + 1).clamp(0, items.starMax);
  // 이번 별 몫만 빼고 나머지는 다음 별로 넘긴다(만렙이면 0, 2026-10-14).
  final left = target.starExp - items.starNeedAt(target.stars);
  return target.copyWith(
    stars: next,
    starExp: next >= items.starMax
        ? 0
        : left.clamp(0, items.starNeedRemaining(next)),
    clearStarUntil: true,
  );
}

/// 새 장비로 바꿀 때 이전 장비의 별 일부를 이어받는다(`starInheritRatio`, 내림).
/// 새 장비가 원래 더 많은 별을 갖고 있으면 그대로 둔다. 모으던 재료·진행 중이던 강화는 이어받지 않는다.
EquipItem inheritStars(ItemConfig items, EquipItem? from, EquipItem to) {
  if (from == null || from.stars <= 0) return to;
  final carried = (from.stars * items.starInheritRatio).floor();
  if (carried <= to.stars) return to;
  return to.copyWith(
    stars: carried.clamp(0, items.starMax),
    starExp: 0,
    clearStarUntil: true,
  );
}

/// 옵션이 **모자란 옛 장비**를 그 등급의 개수만큼 채운다.
///
/// 2026-09-09 에 부위 기본 스탯을 없애고 모든 등급을 옵션 2 개로 바꿨다.
/// 그 전에 뽑힌 1 옵션 장비를 그대로 두면 기본 스탯이 사라진 만큼만 약해져
/// **가만히 있던 유저가 손해**를 본다. 모자란 칸을 채워 준다.
///
/// ⚠️ 이미 있는 옵션은 **건드리지 않는다**(값이 바뀌면 그것도 손해다).
/// 중복도 피한다 — 같은 축 두 줄은 합산이라 한 줄과 다를 바가 없다.
EquipItem fillMissingOptions({
  double maxMult = 1,
  required math.Random rng,
  required ItemConfig items,
  required EquipItem item,
}) {
  final want = items.tier(item.tier).options;
  if (item.options.length >= want) return item;
  final have = {for (final o in item.options) o.kind};
  final pool = items.optionPool.where((r) => !have.contains(r.kind)).toList();
  final next = [...item.options];
  while (next.length < want && pool.isNotEmpty) {
    final r = pool.removeAt(rng.nextInt(pool.length));
    final roll = math.pow(rng.nextDouble(), items.optionCurve).toDouble();
    final v = r.min + roll * (r.maxAt(item.tier) * maxMult - r.min);
    next.add(ItemOption(kind: r.kind, value: (v * 10).roundToDouble() / 10));
  }
  return item.copyWith(options: next);
}

EquipItem forgeOnce({
  double maxMult = 1,
  required math.Random rng,
  required ItemConfig items,
  required ForgeConfig forge,
  required int forgeLevel,
  EquipSlot? slot,
}) {
  final slots = items.slots.keys.toList(growable: false);
  final picked = slot ?? slots[rng.nextInt(slots.length)];

  // 등급 — 공방 레벨의 확률 창에서 뽑는다.
  final weights = forge.tierWeights(forgeLevel, items.tierCount);
  var roll = rng.nextDouble();
  var tier = 0;
  for (var i = 0; i < weights.length; i++) {
    roll -= weights[i];
    if (roll <= 0) {
      tier = i;
      break;
    }
    tier = i;
  }

  // 하위 옵션 — 등급이 정한 개수만큼 **중복 없이**.
  final count = items.tier(tier).options;
  final pool = List<ItemOptionRange>.from(items.optionPool);
  final options = <ItemOption>[];
  for (var i = 0; i < count && pool.isNotEmpty; i++) {
    final r = pool.removeAt(rng.nextInt(pool.length));
    // ⚠️ 균등분포가 아니다. `optionCurve` 로 값을 아래로 몰아 **높은 롤을
    // 귀하게** 만든다(1.0 이면 예전처럼 균등). 자세한 이유는 ItemConfig 참조.
    final roll = math.pow(rng.nextDouble(), items.optionCurve).toDouble();
    // 최대치는 **등급별**이다 — 예전엔 모든 등급이 같은 풀에서 굴려,
    // 풀잎이 호박과 똑같은 15% 공격을 뽑을 수 있었다(2026-09-07). 그러면
    // 상위 등급의 이점이 "같은 숫자를 더 많이"뿐이라 모을 이유가 없다.
    final hi = r.maxAt(tier) * maxMult;
    final v = r.min + roll * (hi - r.min);
    // 소수 한 자리까지만 — 화면에서 읽기 쉬우라고.
    options.add(ItemOption(kind: r.kind, value: (v * 10).roundToDouble() / 10));
  }
  return EquipItem(slot: picked, tier: tier, options: options);
}

/// 장비를 팔면 나오는 재료 **종류** — 일반 재료 셋 중 하나를 무작위로.
///
/// 처음엔 부위로 고정했는데(도구→키틴 식) 사장님 지적대로 **부위와 재료 사이에
/// 아무 뜻이 없어** 규칙을 외울 이유가 없었다. 무작위면 "무엇이 나올까"가
/// 조금이라도 남고, 세 재료가 고르게 쌓인다(강화 2차 비용이 세 종류를 다 쓴다).
///
/// [rng] 는 **호출부가 넣는다**(§5 결정론) — 제련은 이미 인스턴스 하나를
/// 계속 쓰고 있다. 새로 만들면 시각으로 씨앗이 잡혀 같은 재료가 연달아 나온다.
MaterialKind sellMaterialFor(math.Random rng) =>
    kRegularMaterials[rng.nextInt(kRegularMaterials.length)];
