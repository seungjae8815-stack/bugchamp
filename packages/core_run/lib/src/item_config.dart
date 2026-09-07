import 'package:core_models/core_models.dart';
import 'package:meta/meta.dart';

/// 등급 1단계 (풀잎~호박). **흔한 자연물 → 금속 → 곤충 소재 → 보석** 으로
/// 한 방향으로만 귀해진다.
@immutable
class ItemTierDef {
  const ItemTierDef({
    required this.id,
    required this.name,
    required this.statMult,
    required this.options,
    required this.color,
  });

  final String id;
  final LocalizedText name;

  /// 기본 스탯 배수(풀잎 1.0 → 호박 17.0).
  final double statMult;

  /// 이 등급이 굴리는 하위 옵션 **개수**.
  final int options;

  /// 표시 색(ARGB 16진 문자열).
  final String color;

  factory ItemTierDef.fromJson(Map<String, dynamic> json) => ItemTierDef(
    id: json['id'] as String,
    name: LocalizedText.fromJson(
      Map<String, dynamic>.from(json['name'] as Map),
    ),
    statMult: (json['statMult'] as num).toDouble(),
    options: (json['options'] as num).toInt(),
    color: json['color'] as String? ?? 'FF9E9E9E',
  );
}

/// 부위 1종의 정의 — 담당 축, 기본치, 등급별 이름.
@immutable
class ItemSlotDef {
  const ItemSlotDef({
    required this.slot,
    required this.baseStat,
    required this.baseValue,
    required this.names,
    this.storageSlots = const [],
  });

  final EquipSlot slot;

  /// 이 부위가 담당하는 축. 부위마다 달라야 "무엇을 먼저 맞출까"가 생긴다.
  final ItemOptionKind baseStat;

  /// 등급 1(풀잎)에서의 기본 수치(%). 등급 배수를 곱해 쓴다.
  final double baseValue;

  /// 등급별 이름(길이 = 등급 수).
  final List<LocalizedText> names;

  /// 채집함 부위 전용 — 등급별 추가 칸 수. 다른 부위는 빈 목록.
  final List<int> storageSlots;

  /// 등급 [tier] 에서의 기본 수치(%).
  double valueAt(int tier, List<ItemTierDef> tiers) {
    if (tiers.isEmpty) return baseValue;
    final t = tier.clamp(0, tiers.length - 1);
    return baseValue * tiers[t].statMult;
  }

  /// 등급 [tier] 에서 늘어나는 채집함 칸(해당 없으면 0).
  int storageAt(int tier) => storageSlots.isEmpty
      ? 0
      : storageSlots[tier.clamp(0, storageSlots.length - 1)];

  factory ItemSlotDef.fromJson(Map<String, dynamic> json) => ItemSlotDef(
    slot: EquipSlot.fromKey(json['slot'] as String),
    baseStat: ItemOptionKind.fromKey(json['baseStat'] as String),
    baseValue: (json['baseValue'] as num).toDouble(),
    names: [
      for (final n in (json['names'] as List))
        LocalizedText.fromJson(Map<String, dynamic>.from(n as Map)),
    ],
    storageSlots: [
      for (final v in (json['storageSlots'] as List? ?? const []))
        (v as num).toInt(),
    ],
  );
}

/// 하위 옵션 하나의 굴림 범위(%).
@immutable
class ItemOptionRange {
  const ItemOptionRange({
    required this.kind,
    required this.min,
    required this.max,
    this.maxByTier = const [],
  });

  final ItemOptionKind kind;
  final double min;

  /// 등급별 최대치가 없을 때 쓰는 값(구버전 데이터 호환).
  final double max;

  /// **등급별** 최대치. 옵션마다 성격이 달라 배율 하나로 못 묶는다
  /// (2026-09-07): 치명확률은 더하기 + 100% 상한이라 가파르게 올리면 상위
  /// 등급에서 **그 옵션만 버려지고**, 치명피해는 곱하기라 같은 배율이 훨씬
  /// 크게 먹힌다. 그래서 축마다 곡선을 따로 잡는다.
  final List<double> maxByTier;

  /// 등급 [tier] 에서의 최대치. 표가 없으면 [max] 로 떨어진다.
  double maxAt(int tier) {
    if (maxByTier.isEmpty) return max;
    return maxByTier[tier.clamp(0, maxByTier.length - 1)];
  }

  factory ItemOptionRange.fromJson(Map<String, dynamic> json) =>
      ItemOptionRange(
        kind: ItemOptionKind.fromKey(json['kind'] as String),
        min: (json['min'] as num).toDouble(),
        // 표가 있으면 `max` 는 그 마지막 값이다. 0 으로 두면 표를 안 보는
        // 옛 코드에서 범위가 1~0 이 되어 조용히 최소치만 나온다.
        max:
            (json['max'] as num?)?.toDouble() ??
            ((json['maxByTier'] as List?)?.isNotEmpty == true
                ? ((json['maxByTier'] as List).last as num).toDouble()
                : 0),
        maxByTier: [
          for (final v in (json['maxByTier'] as List? ?? const []))
            (v as num).toDouble(),
        ],
      );
}

/// 장비 설정 전체 (assets/data/items.json).
@immutable
class ItemConfig {
  const ItemConfig({
    required this.tiers,
    required this.slots,
    required this.optionPool,
    this.optionCurve = 1.0,
  });

  final List<ItemTierDef> tiers;
  final Map<EquipSlot, ItemSlotDef> slots;
  final List<ItemOptionRange> optionPool;

  /// 옵션 값 뽑기 곡선. `v = min + (max-min) × r^optionCurve` (r 은 0~1 균등).
  ///
  /// **1.0 = 균등분포**(예전 동작). 크면 값이 아래로 몰려 **낮은 롤이 흔하고
  /// 높은 롤이 귀해진다** — 그래야 계속 돌릴 이유가 생긴다.
  ///
  /// 균등분포였을 때는 치명피해 1~80 에서 56 이상이 **30%** 로 나와
  /// "잘 뽑았다"가 흔했고, 상위 5% 롤이 평균의 1.88배뿐이었다. 평균 장비로
  /// 충분하니 아무도 더 안 돌렸다(2026-08-30 사장님 지적).
  ///
  /// ⚠️ 지수를 올리면 **평균도 함께 내려간다**(평균 = min + (max-min)/(k+1)).
  /// 그게 의도다 — 평균이 그대로면 "평균에 만족하고 그만두는" 구간이 남는다.
  /// 다만 장비 평균이 내려가면 진행이 느려지므로 `balance_sim --equip-scale`
  /// 로 함께 확인한다.
  final double optionCurve;

  int get tierCount => tiers.length;

  ItemSlotDef? slot(EquipSlot s) => slots[s];

  /// 등급 [tier] 의 정의(범위를 벗어나면 양 끝으로 자른다).
  ItemTierDef tier(int t) => tiers[t.clamp(0, tiers.length - 1)];

  /// 화면에 쓸 이름 — `[호박] 지휘봉` 의 뒷부분.
  LocalizedText? nameOf(EquipSlot s, int tier) {
    final def = slots[s];
    if (def == null || def.names.isEmpty) return null;
    return def.names[tier.clamp(0, def.names.length - 1)];
  }

  factory ItemConfig.fromJson(Map<String, dynamic> json) {
    final slotList = (json['slots'] as List).cast<Map<String, dynamic>>().map(
      ItemSlotDef.fromJson,
    );
    return ItemConfig(
      tiers: (json['tiers'] as List)
          .cast<Map<String, dynamic>>()
          .map(ItemTierDef.fromJson)
          .toList(growable: false),
      slots: {for (final s in slotList) s.slot: s},
      optionPool: (json['optionPool'] as List)
          .cast<Map<String, dynamic>>()
          .map(ItemOptionRange.fromJson)
          .toList(growable: false),
      optionCurve: (json['optionCurve'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

/// 장비 하나를 **지금 규칙에 맞게** 정리한다.
///
/// 하는 일 두 가지 (2026-09-07 개편):
///  1. 풀에서 빠진 옵션 축을 버린다 — 효과가 구현되지 않은 4종(스킬피해·
///     스킬쿨감·오프라인·펫)을 뺐다. 남겨 두면 **아무 일도 안 하는 옵션**이
///     2칸 중 한 칸을 차지한다.
///  2. 옵션을 그 등급의 개수까지 자른다. 무엇을 남길지는 **그 등급 최대치
///     대비 비율**로 고른다 — 축마다 눈금이 달라(치명피해 150 vs 공격 30)
///     날값으로 줄 세우면 치명피해가 항상 이긴다.
///
/// ⚠️ 값을 **깎지는 않는다**. 개편 전 옵션은 옛 최대치(공격 15)로 굴려져
/// 새 최대치(30)보다 낮다 — 깎을 이유가 없고, 건드리면 "가만있는데 약해졌다"가 된다.
EquipItem trimItemOptions(EquipItem item, ItemConfig config) {
  final live = {for (final r in config.optionPool) r.kind: r};
  final keep = [
    for (final o in item.options)
      if (live.containsKey(o.kind)) o,
  ];
  final limit = config.tier(item.tier).options;
  if (keep.length == item.options.length && keep.length <= limit) return item;
  if (keep.length > limit) {
    double score(ItemOption o) {
      final hi = live[o.kind]!.maxAt(item.tier);
      return hi <= 0 ? 0 : o.value / hi;
    }

    keep.sort((a, b) => score(b).compareTo(score(a)));
    keep.removeRange(limit, keep.length);
  }
  return item.copyWith(options: keep);
}
