import 'package:meta/meta.dart';

/// 장비 부위 8종 (§3.2). 부위마다 **담당 축이 다르다** — 같은 스탯을
/// 나눠 갖지 않아야 "무엇을 먼저 맞출까"가 생긴다.
enum EquipSlot {
  /// 채집도구 — 공격력(주력).
  tool('tool'),

  /// 모자 — 곤충 발견율.
  hat('hat'),

  /// 옷 — 체력.
  top('top'),

  /// 바지 — 방어.
  bottom('bottom'),

  /// 신발 — 공격속도.
  shoes('shoes'),

  /// 목걸이 — 골드 획득.
  necklace('necklace'),

  /// 반지 — 크리티컬.
  ring('ring'),

  /// 채집함 — 재료 획득 + 채집함 칸.
  box('box');

  const EquipSlot(this.key);
  final String key;

  static EquipSlot fromKey(String key) => values.firstWhere(
    (e) => e.key == key,
    orElse: () => throw ArgumentError('Unknown EquipSlot key: $key'),
  );

  /// 모르는 키면 null. **세이브에서 온 키**를 읽을 때 쓴다 — 신버전이 값을
  /// 추가해도 구버전 앱이 세이브를 통째로 못 읽는 일이 없어야 한다.
  /// (애셋 JSON 은 [fromKey] 로 읽어 오타를 로딩에서 잡는다.)
  static EquipSlot? fromKeyOrNull(String key) {
    for (final e in values) {
      if (e.key == key) return e;
    }
    return null;
  }
}

/// 장비 옵션 축. 기본 스탯과 하위 옵션이 **같은 축을 공유**한다 —
/// 채집도구의 기본 공격력과 반지에 붙은 공격력 옵션이 같은 방식으로 합산된다.
///
/// ⚠️ **이동속도는 없다.** 걷는 시간이 사이클의 7~18% 뿐이고 후반일수록 줄어
/// (2배로 올려도 3% 단축) 뽑으면 실망하는 옵션이 된다. 제련의 재미는
/// "나온 옵션이 전부 갖고 싶은 것"에서 나온다 — 죽은 옵션 하나가 굴림 전체를
/// 김빠지게 한다. 이동은 이미 업그레이드에 있다.
enum ItemOptionKind {
  attack('attack'),
  attackSpeed('attackSpeed'),
  critChance('critChance'),
  critDamage('critDamage'),
  maxHp('maxHp'),
  defense('defense'),

  /// 골드 획득.
  gold('gold'),

  /// 재료 획득.
  material('material'),

  /// 곤충 발견율.
  bugFind('bugFind'),

  /// 보스 추가 피해.
  bossDamage('bossDamage'),

  /// 스킬 피해.
  skillDamage('skillDamage'),

  /// 스킬 쿨타임 **감소**. 값이 클수록 좋다(다른 축과 부호를 맞추기 위함).
  skillCooldown('skillCooldown'),

  /// 탭 부스트 효율.
  boost('boost'),

  /// 오프라인 효율.
  offline('offline'),

  /// 펫 효과.
  pet('pet');

  const ItemOptionKind(this.key);
  final String key;

  static ItemOptionKind fromKey(String key) => values.firstWhere(
    (e) => e.key == key,
    orElse: () => throw ArgumentError('Unknown ItemOptionKind key: $key'),
  );

  /// 모르는 키면 null. **세이브에서 온 키**를 읽을 때 쓴다 — 신버전이 값을
  /// 추가해도 구버전 앱이 세이브를 통째로 못 읽는 일이 없어야 한다.
  /// (애셋 JSON 은 [fromKey] 로 읽어 오타를 로딩에서 잡는다.)
  static ItemOptionKind? fromKeyOrNull(String key) {
    for (final e in values) {
      if (e.key == key) return e;
    }
    return null;
  }
}

/// 제련으로 굴려진 하위 옵션 하나. [value] 는 **퍼센트**(12.0 = +12%).
@immutable
class ItemOption {
  const ItemOption({required this.kind, required this.value});

  final ItemOptionKind kind;
  final double value;

  ItemOption copyWith({ItemOptionKind? kind, double? value}) =>
      ItemOption(kind: kind ?? this.kind, value: value ?? this.value);

  Map<String, dynamic> toJson() => {'k': kind.key, 'v': value};

  factory ItemOption.fromJson(Map<String, dynamic> json) => ItemOption(
    kind: ItemOptionKind.fromKey(json['k'] as String),
    value: (json['v'] as num).toDouble(),
  );

  /// 모르는 옵션 축이면 null — 세이브에서 읽을 때 쓴다. 신버전이 옵션을 추가해도
  /// 구버전 앱이 장비를 통째로 못 읽는 일이 없어야 한다(옵션 하나만 빠진다).
  static ItemOption? tryFromJson(Map<String, dynamic> json) {
    final kind = ItemOptionKind.fromKeyOrNull(json['k'] as String? ?? '');
    if (kind == null) return null;
    return ItemOption(kind: kind, value: (json['v'] as num?)?.toDouble() ?? 0);
  }

  @override
  bool operator ==(Object other) =>
      other is ItemOption && other.kind == kind && other.value == value;

  @override
  int get hashCode => Object.hash(kind, value);

  @override
  String toString() => '${kind.key}+$value%';
}

/// 장착 중인 장비 하나.
///
/// **가방이 없다** — 부위마다 낀 것 1개만 존재하고, 제련해서 나온 새 장비는
/// 그 자리에서 교체하거나 버린다(§3.4). 그래서 세이브에 남는 장비는 8개뿐이라
/// 2026-07 의 세이브 비대화(곤충 3만 마리 = 13.6MB) 위험이 원천적으로 없다.
@immutable
class EquipItem {
  const EquipItem({
    required this.slot,
    required this.tier,
    required this.options,
  });

  final EquipSlot slot;

  /// 등급 인덱스(0 = 풀잎 … 9 = 호박). **enum 이 아니라 정수**다 —
  /// 등급은 JSON 목록이라 11·12(화석·여왕)를 콘텐츠 패치로 덧붙일 수 있어야 한다.
  final int tier;

  /// 제련으로 굴려진 하위 옵션(등급이 개수를 정한다).
  final List<ItemOption> options;

  EquipItem copyWith({EquipSlot? slot, int? tier, List<ItemOption>? options}) =>
      EquipItem(
        slot: slot ?? this.slot,
        tier: tier ?? this.tier,
        options: options ?? this.options,
      );

  Map<String, dynamic> toJson() => {
    's': slot.key,
    't': tier,
    'o': [for (final o in options) o.toJson()],
  };

  factory EquipItem.fromJson(Map<String, dynamic> json) => EquipItem(
    slot: EquipSlot.fromKey(json['s'] as String),
    tier: (json['t'] as num).toInt(),
    options: [
      for (final o in (json['o'] as List? ?? const []))
        ItemOption.fromJson(Map<String, dynamic>.from(o as Map)),
    ],
  );

  /// 모르는 **부위**면 null — 세이브에서 읽을 때 쓴다. 모르는 **옵션**은
  /// 그 옵션만 빼고 장비는 살린다([ItemOption.tryFromJson]).
  ///
  /// ⚠️ 여기서 걸러진 장비·옵션은 다시 저장되지 않아 **되돌아가면 사라진다**.
  /// 재료·업그레이드(`SaveGame.unknownMaterials`)처럼 보존하지 않는 이유 =
  /// 장비는 부위마다 1개뿐이라 구버전에서 교체하면 어차피 덮어써진다.
  static EquipItem? tryFromJson(Map<String, dynamic> json) {
    final slot = EquipSlot.fromKeyOrNull(json['s'] as String? ?? '');
    if (slot == null) return null;
    return EquipItem(
      slot: slot,
      tier: (json['t'] as num?)?.toInt() ?? 0,
      options: [
        for (final o in (json['o'] as List? ?? const []))
          ?ItemOption.tryFromJson(Map<String, dynamic>.from(o as Map)),
      ],
    );
  }

  @override
  String toString() => 'EquipItem(${slot.key}, t$tier, $options)';
}
