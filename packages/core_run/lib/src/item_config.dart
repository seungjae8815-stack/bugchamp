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
  });

  final ItemOptionKind kind;
  final double min;
  final double max;

  factory ItemOptionRange.fromJson(Map<String, dynamic> json) =>
      ItemOptionRange(
        kind: ItemOptionKind.fromKey(json['kind'] as String),
        min: (json['min'] as num).toDouble(),
        max: (json['max'] as num).toDouble(),
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
