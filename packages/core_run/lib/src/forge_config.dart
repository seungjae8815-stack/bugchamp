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
    this.levelUpBaseSeconds = 3600,
    this.levelUpGrowth = 1.28,
    this.levelUpJellyPerHour = 2,
    this.levelUpJellyMin = 5,
    this.fossilPerSecond = 0.0556,
    this.fossilOfflineRatio = 0.333,
    this.fossilMinPerDrop = 1,
    this.autoStrikeMax = 10,
    this.autoStrikeFullFromTier = 1,
    this.rerollJelly = 15,
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

  /// 칸을 다 채운 뒤 걸리는 시간(레벨 0 → 1). 레벨마다 [levelUpGrowth] 배씩.
  final int levelUpBaseSeconds;
  final double levelUpGrowth;

  /// 즉시완료 젤리 — 남은 시간 1시간당.
  final int levelUpJellyPerHour;
  final int levelUpJellyMin;

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

  /// 현재 레벨 [level] → [level]+1 에 드는 **총** 골드.
  int levelUpGold(int level) =>
      (levelUpGoldBase * math.pow(levelUpGoldGrowth, level)).round();

  /// 칸 하나에 드는 골드(총액을 [levelUpSteps] 로 나눈 값).
  int levelUpStepGold(int level) {
    final steps = levelUpSteps <= 0 ? 1 : levelUpSteps;
    return (levelUpGold(level) / steps).ceil();
  }

  /// 등급업에 걸리는 시간 — 현재 레벨 [level] → [level]+1.
  Duration levelUpDuration(int level) => Duration(
    seconds: (levelUpBaseSeconds * math.pow(levelUpGrowth, level)).round(),
  );

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
      levelUpBaseSeconds: (lv['baseSeconds'] as num?)?.toInt() ?? 3600,
      levelUpGrowth: (lv['growth'] as num?)?.toDouble() ?? 1.28,
      levelUpJellyPerHour: (lv['jellyPerHour'] as num?)?.toInt() ?? 2,
      levelUpJellyMin: (lv['jellyMin'] as num?)?.toInt() ?? 5,
      fossilPerSecond: (fs['perSecondOnline'] as num?)?.toDouble() ?? 0.0556,
      fossilOfflineRatio: (fs['offlineRatio'] as num?)?.toDouble() ?? 0.333,
      fossilMinPerDrop: (fs['minPerDrop'] as num?)?.toInt() ?? 1,
      autoStrikeMax: (json['autoStrikeMax'] as num?)?.toInt() ?? 10,
      rerollJelly: (json['rerollJelly'] as num?)?.toInt() ?? 15,
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
    final hi = r.maxAt(item.tier);
    final v = r.min + roll * (hi - r.min);
    options.add(ItemOption(kind: r.kind, value: (v * 10).roundToDouble() / 10));
  }
  return EquipItem(slot: item.slot, tier: item.tier, options: options);
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
  final hi = r.maxAt(item.tier);
  final v = r.min + roll * (hi - r.min);
  final next = [...item.options];
  next[index] = ItemOption(kind: r.kind, value: (v * 10).roundToDouble() / 10);
  return EquipItem(slot: item.slot, tier: item.tier, options: next);
}

EquipItem forgeOnce({
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
    final hi = r.maxAt(tier);
    final v = r.min + roll * (hi - r.min);
    // 소수 한 자리까지만 — 화면에서 읽기 쉬우라고.
    options.add(ItemOption(kind: r.kind, value: (v * 10).roundToDouble() / 10));
  }
  return EquipItem(slot: picked, tier: tier, options: options);
}
