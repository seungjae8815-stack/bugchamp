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
  buffPass('buffPass'), // 무한 버프 패스(기간제)
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
    this.image,
    this.iosId,
    this.hidden = false,
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

  /// 상점에서 감춘다(판매 중단). 상품 정의는 남긴다 — **이미 산 사람의 혜택
  /// 지급 로직이 상품 정의를 참조**하므로, 지우면 보유자 혜택까지 사라진다.
  /// (광고 제거 패스: 광고 없는 운영 전환으로 핵심 가치가 소멸 → 판매 중단.)
  final bool hidden;

  /// iOS(App Store) 전용 제품 ID. null 이면 [id] 그대로.
  ///
  /// ⚠️ idle_pass 가 ASC 에 **비소모품으로 잘못 생성**돼 있었다(2026-08-20
  /// 발견). iOS 는 재구매 가능 여부를 ASC 유형이 정하는데 유형은 생성 후
  /// 변경 불가, 제품 ID 는 재사용 불가 — 그래서 iOS 만 새 ID(소모품)를 쓴다.
  /// Play 는 기존 ID 그대로다(consume 방식이라 유형 문제가 없다).
  /// 서버·앱의 상품 해석은 [IapConfig.byId] 가 별칭까지 매칭한다.
  final String? iosId;

  /// 상품 그림 파일명(확장자 없이). `assets/images/shop/{image}.webp`.
  ///
  /// 코드에 경로를 박지 않는다(§6) — 상품을 늘릴 때 JSON 만 고치면 된다.
  /// 파일이 없으면 UI 가 타입별 아이콘으로 떨어지므로 화면은 깨지지 않는다.
  final String? image;

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
    hidden: json['hidden'] == true,
    bonusPct: (json['bonusPct'] as num?)?.toInt() ?? 0,
    skinId: json['skinId'] as String?,
    image: json['image'] as String?,
    iosId: json['iosId'] as String?,
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
  const SkinDef({
    required this.id,
    required this.effect,
    this.speciesPrefix,
    this.releaseBonusPct = 0,
    this.incubateSpeedPct = 0,
    this.artSpecies = const {},
  });

  final String id;

  /// 색 처리 종류: 'gold' | 'albino' | 'arenaTheme'.
  final String effect;

  /// 적용 대상 종 접두사(예: 'rhino_' = 장수풍뎅이 계열).
  final String? speciesPrefix;

  /// 이 계열을 분해·방생할 때 재료 +N%.
  ///
  /// ⚠️ **전투 스탯은 절대 붙이지 않는다**(§2.6 스탯 직접 판매 금지).
  /// 대회 경품이 실물이라 결제로 순위가 바뀌면 도박성 시비가 된다.
  /// 시간·재료는 편의지 전력이 아니라 트로피·대회 순위에 영향이 없다.
  final int releaseBonusPct;

  /// 이 계열 알의 부화 시간 −N%.
  final int incubateSpeedPct;

  /// **전용 그림이 있는 종**. 여기 있는 종은 `{종}_adult_{n}_{effect}.webp` 를
  /// 쓰고 색 필터를 입히지 않는다 — 그림이 이미 그 색이라 두 번 물들면 뭉갠다.
  final Set<String> artSpecies;

  factory SkinDef.fromJson(Map<String, dynamic> json) => SkinDef(
    id: json['id'] as String,
    effect: json['effect'] as String? ?? 'gold',
    speciesPrefix: json['speciesPrefix'] as String?,
    releaseBonusPct: (json['releaseBonusPct'] as num?)?.toInt() ?? 0,
    incubateSpeedPct: (json['incubateSpeedPct'] as num?)?.toInt() ?? 0,
    artSpecies: {
      for (final x in (json['artSpecies'] as List? ?? const [])) '$x',
    },
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
    this.buffPassDurationDays = 30,
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

  /// [speciesId] 에 **전용 스킨 그림**이 있는가(= 색 필터를 입히면 안 되는가).
  bool skinHasArt(String effect, String speciesId) {
    for (final s in skins) {
      if (s.effect == effect) return s.artSpecies.contains(speciesId);
    }
    return false;
  }

  /// [speciesId] 에 걸린 스킨의 **계열 편의 보너스**. 미보유면 0.
  ///
  /// ⚠️ 근거는 세이브의 `ownedSkins` — **서버 소유 필드**라 위조할 수 없다.
  /// 방어팀 행에 실어 보내는 `skin` 값(그림용)과 혼동하지 말 것. 그쪽은
  /// 클라가 주장하는 값이고, 이 보너스와 아무 상관이 없다.
  ({int releaseBonusPct, int incubateSpeedPct}) skinPerkFor(
    Set<String> owned,
    String speciesId,
  ) {
    for (final s in skins) {
      final p = s.speciesPrefix;
      if (p == null || !owned.contains(s.id)) continue;
      if (speciesId.startsWith(p)) {
        return (
          releaseBonusPct: s.releaseBonusPct,
          incubateSpeedPct: s.incubateSpeedPct,
        );
      }
    }
    return (releaseBonusPct: 0, incubateSpeedPct: 0);
  }

  /// 계열 보너스를 적용한 분해·방생 재료량.
  int skinnedReleaseMaterial(int base, Set<String> owned, String speciesId) {
    final pct = skinPerkFor(owned, speciesId).releaseBonusPct;
    return pct <= 0 ? base : (base * (100 + pct) / 100).round();
  }

  /// 계열 보너스를 적용한 부화 시간(초). **1초 밑으로는 안 내려간다.**
  int skinnedIncubateSeconds(int base, Set<String> owned, String speciesId) {
    final pct = skinPerkFor(owned, speciesId).incubateSpeedPct;
    if (pct <= 0) return base;
    final v = (base * (100 - pct) / 100).round();
    return v < 1 ? 1 : v;
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

  /// 무한 버프 패스 기간(일).
  final int buffPassDurationDays;

  /// 정렬된 상품 목록(sort 오름차순).
  /// 상점 표시용 — 판매 중단(hidden) 상품은 뺀다.
  List<IapProduct> get sorted =>
      [...products.where((p) => !p.hidden)]
        ..sort((a, b) => a.sort.compareTo(b.sort));

  /// [type] 에 해당하는 상품들(정렬 유지).
  List<IapProduct> byType(IapType type) =>
      sorted.where((p) => p.type == type).toList();

  /// 대표 ID **또는 iOS 전용 ID**로 상품을 찾는다.
  ///
  /// 스토어(영수증·구매 스트림)가 돌려주는 ID 는 플랫폼에 따라 다를 수 있다 —
  /// 서버 지급([grantPurchase])과 앱 지급이 같은 해석을 쓰도록 여기 한 곳에 둔다.
  IapProduct? byId(String id) {
    for (final p in products) {
      if (p.id == id || p.iosId == id) return p;
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
    buffPassDurationDays: (json['buffPassDurationDays'] as num?)?.toInt() ?? 30,
  );
}
