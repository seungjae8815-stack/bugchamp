import 'package:core_models/core_models.dart' show LocalizedText;
import 'package:meta/meta.dart';

/// 인앱결제 상품 종류(스토어 처리 방식).
enum IapKind {
  consumable('consumable'), // 젤리 등 반복 구매
  nonConsumable('nonConsumable'), // 광고제거·스킨·스타터(1회)
  timed('timed'); // 기간제 패스

  const IapKind(this.key);
  final String key;

  static IapKind fromKey(String k) =>
      values.firstWhere((e) => e.key == k, orElse: () => IapKind.consumable);
}

/// 상품이 게임에 주는 효과 종류.
enum IapType {
  jelly('jelly'), // 젤리 지급
  removeAds('removeAds'), // 광고 제거
  starter('starter'), // 스타터 패키지(1회 묶음)
  pass('pass'), // 기간제 패스
  skin('skin'); // 코스메틱

  const IapType(this.key);
  final String key;

  static IapType fromKey(String k) =>
      values.firstWhere((e) => e.key == k, orElse: () => IapType.jelly);
}

/// 상품 구매 시 지급되는 재화·편의 묶음.
@immutable
class IapGrant {
  const IapGrant({
    this.jelly = 0,
    this.gold = 0,
    this.chitin = 0,
    this.mineral = 0,
    this.sap = 0,
    this.incubatorSlots = 0,
  });

  final int jelly;
  final int gold;
  final int chitin;
  final int mineral;
  final int sap;

  /// 부화기 슬롯 영구 확장 수(편의 — 스탯 아님).
  final int incubatorSlots;

  bool get isEmpty =>
      jelly == 0 &&
      gold == 0 &&
      chitin == 0 &&
      mineral == 0 &&
      sap == 0 &&
      incubatorSlots == 0;

  factory IapGrant.fromJson(Map<String, dynamic> json) => IapGrant(
    jelly: (json['jelly'] as num?)?.toInt() ?? 0,
    gold: (json['gold'] as num?)?.toInt() ?? 0,
    chitin: (json['chitin'] as num?)?.toInt() ?? 0,
    mineral: (json['mineral'] as num?)?.toInt() ?? 0,
    sap: (json['sap'] as num?)?.toInt() ?? 0,
    incubatorSlots: (json['incubatorSlots'] as num?)?.toInt() ?? 0,
  );
}

/// 상품 1개 정의 (assets/data/iap.json).
@immutable
class IapProduct {
  const IapProduct({
    required this.id,
    required this.kind,
    required this.type,
    required this.priceKrw,
    this.name,
    this.desc,
    this.sort = 0,
    this.bonusPct = 0,
    this.skinId,
    this.grant = const IapGrant(),
  });

  /// 스토어 상품 ID(구글 플레이 콘솔에 동일하게 등록).
  final String id;

  /// 표시용 다국어 이름·설명(JSON `{ko,en,ja}`). 없으면 UI 가 id 로 대체.
  final LocalizedText? name;
  final LocalizedText? desc;
  final IapKind kind;
  final IapType type;
  final int priceKrw;
  final int sort;

  /// 젤리 팩 보너스 표기(%). 0이면 미표기.
  final int bonusPct;

  /// 스킨 상품이면 적용 스킨 id.
  final String? skinId;

  final IapGrant grant;

  factory IapProduct.fromJson(Map<String, dynamic> json) => IapProduct(
    id: json['id'] as String,
    name: json['name'] == null
        ? null
        : LocalizedText.fromJson(json['name'] as Map<String, dynamic>),
    desc: json['desc'] == null
        ? null
        : LocalizedText.fromJson(json['desc'] as Map<String, dynamic>),
    kind: IapKind.fromKey(json['kind'] as String? ?? 'consumable'),
    type: IapType.fromKey(json['type'] as String? ?? 'jelly'),
    priceKrw: (json['priceKrw'] as num?)?.toInt() ?? 0,
    sort: (json['sort'] as num?)?.toInt() ?? 0,
    bonusPct: (json['bonusPct'] as num?)?.toInt() ?? 0,
    skinId: json['skinId'] as String?,
    grant: json['grant'] == null
        ? const IapGrant()
        : IapGrant.fromJson(json['grant'] as Map<String, dynamic>),
  );
}

/// 스킨 1종의 적용 규칙 (코스메틱 — 스탯 영향 없음).
///
/// [speciesPrefix] 로 시작하는 종의 **내 곤충**에 [effect] 색 처리를 입힌다.
/// prefix 가 없으면 곤충이 아닌 곳(예: 아레나 테마)에 쓰는 스킨.
@immutable
class SkinDef {
  const SkinDef({required this.id, required this.effect, this.speciesPrefix});

  final String id;

  /// 색 처리 종류: 'gold' | 'albino' | 'arenaTheme'.
  final String effect;

  /// 적용 대상 종 접두사(예: 'rhino_' = 장수풍뎅이 계열).
  final String? speciesPrefix;

  factory SkinDef.fromJson(Map<String, dynamic> json) => SkinDef(
    id: json['id'] as String,
    effect: json['effect'] as String? ?? 'gold',
    speciesPrefix: json['speciesPrefix'] as String?,
  );
}

/// 인앱결제 카탈로그 + 패스/광고제거 효과 수치 (assets/data/iap.json, §6).
@immutable
class IapConfig {
  const IapConfig({
    required this.products,
    this.skins = const [],
    this.currency = 'KRW',
    this.passDurationDays = 30,
    this.passDailyJelly = 30,
    this.passOfflineCapHours = 12,
    this.passIdleGoldMult = 1.2,
    this.removeAdsDailyJelly = 10,
  });

  final List<IapProduct> products;

  /// 스킨 적용 규칙(구매한 스킨이 실제로 보이게 하는 정의).
  final List<SkinDef> skins;

  final String currency;

  /// [speciesId] 에 적용될 스킨 효과. [owned] 에 없는 스킨은 무시.
  /// 없으면 null(기본 외형).
  String? skinEffectFor(Set<String> owned, String speciesId) {
    for (final s in skins) {
      final p = s.speciesPrefix;
      if (p == null || !owned.contains(s.id)) continue;
      if (speciesId.startsWith(p)) return s.effect;
    }
    return null;
  }

  /// 보유한 스킨 중 곤충이 아닌 대상(아레나 테마 등)의 효과들.
  bool ownsEffect(Set<String> owned, String effect) => skins.any(
    (s) =>
        s.effect == effect && s.speciesPrefix == null && owned.contains(s.id),
  );

  /// 패스 기간(일)·매일 젤리·오프라인 상한(시간)·방치 골드 배율.
  final int passDurationDays;
  final int passDailyJelly;
  final int passOfflineCapHours;
  final double passIdleGoldMult;

  /// 광고 제거 구매자의 매일 젤리.
  final int removeAdsDailyJelly;

  /// 정렬된 상품 목록(sort 오름차순).
  List<IapProduct> get sorted =>
      [...products]..sort((a, b) => a.sort.compareTo(b.sort));

  /// [type] 에 해당하는 상품들(정렬 유지).
  List<IapProduct> byType(IapType type) =>
      sorted.where((p) => p.type == type).toList();

  IapProduct? byId(String id) {
    for (final p in products) {
      if (p.id == id) return p;
    }
    return null;
  }

  factory IapConfig.fromJson(Map<String, dynamic> json) => IapConfig(
    products: [
      for (final p in (json['products'] as List? ?? const []))
        IapProduct.fromJson(p as Map<String, dynamic>),
    ],
    skins: [
      for (final s in (json['skins'] as List? ?? const []))
        SkinDef.fromJson(s as Map<String, dynamic>),
    ],
    currency: json['currency'] as String? ?? 'KRW',
    passDurationDays: (json['passDurationDays'] as num?)?.toInt() ?? 30,
    passDailyJelly: (json['passDailyJelly'] as num?)?.toInt() ?? 30,
    passOfflineCapHours: (json['passOfflineCapHours'] as num?)?.toInt() ?? 12,
    passIdleGoldMult: (json['passIdleGoldMult'] as num?)?.toDouble() ?? 1.2,
    removeAdsDailyJelly: (json['removeAdsDailyJelly'] as num?)?.toInt() ?? 10,
  );
}
