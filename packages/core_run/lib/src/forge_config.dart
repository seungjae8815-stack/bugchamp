import 'dart:math' as math;

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
    this.maxLevel = 40,
    this.levelUpBaseSeconds = 3600,
    this.levelUpGrowth = 1.30,
    this.levelUpJellyPerHour = 2,
    this.levelUpJellyMin = 5,
    this.fossilPerSecond = 0.0556,
    this.fossilOfflineRatio = 0.333,
    this.fossilMinPerDrop = 1,
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

  /// 등급업 소요 시간(레벨 0 → 1). 레벨마다 [levelUpGrowth] 배씩 늘어난다.
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

  /// 등급업에 걸리는 시간 — 현재 레벨 [level] → [level]+1.
  Duration levelUpDuration(int level) => Duration(
    seconds: (levelUpBaseSeconds * math.pow(levelUpGrowth, level)).round(),
  );

  /// 남은 시간 [remaining] 을 즉시 끝내는 젤리 값.
  int levelUpJelly(Duration remaining) {
    if (remaining <= Duration.zero) return 0;
    final hours = remaining.inSeconds / 3600.0;
    final v = (hours * levelUpJellyPerHour).ceil();
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
      maxLevel: (json['maxLevel'] as num?)?.toInt() ?? 40,
      levelUpBaseSeconds: (lv['baseSeconds'] as num?)?.toInt() ?? 3600,
      levelUpGrowth: (lv['growth'] as num?)?.toDouble() ?? 1.30,
      levelUpJellyPerHour: (lv['jellyPerHour'] as num?)?.toInt() ?? 2,
      levelUpJellyMin: (lv['jellyMin'] as num?)?.toInt() ?? 5,
      fossilPerSecond: (fs['perSecondOnline'] as num?)?.toDouble() ?? 0.0556,
      fossilOfflineRatio: (fs['offlineRatio'] as num?)?.toDouble() ?? 0.333,
      fossilMinPerDrop: (fs['minPerDrop'] as num?)?.toInt() ?? 1,
    );
  }
}

/// 제련 1회 — 망치질 한 번으로 장비 하나가 나온다.
///
/// **완전 결정론**: 같은 [rng] 상태 + 같은 인자 → 같은 장비(헌법 §5).
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
    final v = r.min + rng.nextDouble() * (r.max - r.min);
    // 소수 한 자리까지만 — 화면에서 읽기 쉬우라고.
    options.add(ItemOption(kind: r.kind, value: (v * 10).roundToDouble() / 10));
  }
  return EquipItem(slot: picked, tier: tier, options: options);
}
