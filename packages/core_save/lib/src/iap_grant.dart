import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';

import 'fairy_progress.dart';
import 'save_game.dart';

/// 인앱결제 지급 규칙 — **한 곳**(CLAUDE.md §4, 로직 복제 금지).
///
/// 서버 `GameActions.grantPurchase`(권위 지급)와 앱 `SaveController.applyPurchase`(서버가 없을 때의
/// 로컬 지급)가 같은 함수를 부른다. 한쪽만 고치면 "로컬에선 들어왔는데 서버 세이브엔 없다"가 된다.
///
/// 여기는 **무엇을 주는가**만 정한다. 중복 지급(purchaseId)·계정당 1회 거절(`already_owned`)
/// 판단은 호출부 몫이다 — 서버는 운영 지급 예외를, 앱은 조용한 성공을 다르게 처리한다.

/// 결제 상품의 "이번 주" id — 결투 시즌과 **같은 월요일 09:00(KST) 경계**(`seasonStartAt`).
String iapWeekId(DateTime now, BattleConfig battle) =>
    seasonIdOf(seasonStartAt(now, battle), battle);

/// 주간 묶음을 다시 살 수 있게 되는 시각(다음 주 경계, UTC).
DateTime iapNextWeekAt(DateTime now, BattleConfig battle) =>
    seasonEndAt(now, battle);

/// 상점이 구매 버튼을 막아야 하는 이유.
enum IapBlock {
  /// 살 수 있다.
  none,

  /// 계정당 1회 상품을 이미 샀다(스타터·입문 패키지).
  owned,

  /// 주 1회 상품을 이번 주에 이미 샀다.
  thisWeek,
}

/// [p] 를 지금 살 수 있는가 — **앱이 결제창을 열기 전에** 본다.
///
/// ⚠️ 주간 묶음은 서버가 거절하지 않는다([applyIapGrant] 주석). 그래서 막는 곳은 여기뿐이다.
IapBlock iapPurchaseBlock(
  SaveGame s,
  IapProduct p, {
  required BattleConfig battle,
  required DateTime now,
}) {
  switch (p.type) {
    case IapType.starter:
      return s.starterBought ? IapBlock.owned : IapBlock.none;
    case IapType.oncePack:
      return s.boughtOnce.contains(p.id) ? IapBlock.owned : IapBlock.none;
    case IapType.weekly:
      return s.weeklyBought[p.id] == iapWeekId(now, battle)
          ? IapBlock.thisWeek
          : IapBlock.none;
    default:
      return IapBlock.none;
  }
}

/// 계정당 1회 상품인가(두 번째 영수증을 거절하는 대상).
bool iapIsOncePerAccount(IapProduct p) =>
    p.type == IapType.starter || p.type == IapType.oncePack;

/// [p] 의 지급 내용에 요정 설정이 필요한데 없는가 — 호출부는 지급을 **보류**한다(실패가 아니라 재시도).
/// 알은 요정함 상한·넘침 가루를 설정에서 읽는다.
bool iapNeedsFairyConfig(IapProduct p) => p.grant.hasFairy;

/// 구매 1건을 세이브에 반영한 사본. [purchaseId] 가 있으면 지급 기록에 더한다.
///
/// - 재화·재료·부화기 슬롯·요정(가루·속성석·가속기·알)·스킬 만능 조각은 `grant` 대로.
///   산 알은 **자동 분해하지 않는다**(`autoRelease: false`). 요정함이 차면 넘친 알은 기존 규칙대로 가루.
/// - 기간제(곤충학자·무한 버프·성장 패스)는 남은 기간에 **이어 붙인다**.
/// - 계정당 1회(스타터·입문 패키지)는 표식을 남긴다.
/// - 주간 묶음은 이번 주 id 를 적는다.
///
/// ⚠️ **주간 묶음의 같은 주 두 번째 영수증도 지급한다**(거절하지 않는다). 결제가 이미 끝난 영수증을
/// 서버가 거절하면 앱이 스토어에 완료 통보를 못 하고, 승인되지 않은 주문을 구글이 3일 뒤 자동
/// 환불한다 — 물건은 안 나갔는데 결제 기록만 꼬인다(2026-09-11 스타터 사고와 같은 구조).
/// 소모성이라 Play 가 "이미 보유"로 막아 주지도 않는다. 두 번째 영수증이 오는 길은 앱의 구매 전 차단을
/// 뚫은 경우(옛 세이브로 연 상점·두 기기 동시 구매)뿐이고, 그 사람은 **돈을 한 번 더 냈다** — 물건을 주는
/// 쪽이 맞다. 중복 지급은 purchaseId 로 막는다(같은 영수증 재전달은 한 번만).
SaveGame applyIapGrant(
  SaveGame s,
  IapProduct p,
  IapConfig iap, {
  required BattleConfig battle,
  required DateTime now,
  FairyConfig? fairy,
  String? purchaseId,
}) {
  final t = now.toUtc();
  var out = _applyGrantGoods(s, p.grant, fairy);

  DateTime? extend(DateTime? cur, int days) {
    final base = (cur != null && cur.isAfter(t)) ? cur : t;
    return base.add(Duration(days: days));
  }

  return out.copyWith(
    adsRemoved: out.adsRemoved || p.type == IapType.removeAds,
    starterBought: out.starterBought || p.type == IapType.starter,
    boughtOnce: p.type == IapType.oncePack
        ? {...out.boughtOnce, p.id}
        : out.boughtOnce,
    weeklyBought: p.type == IapType.weekly
        ? {...out.weeklyBought, p.id: iapWeekId(t, battle)}
        : out.weeklyBought,
    ownedSkins: p.skinId == null
        ? out.ownedSkins
        : {...out.ownedSkins, p.skinId!},
    passExpiresAt: p.type == IapType.pass
        ? extend(out.passExpiresAt, iap.passDurationDays)
        : out.passExpiresAt,
    buffPassExpiresAt: p.type == IapType.buffPass
        ? extend(out.buffPassExpiresAt, iap.buffPassDurationDays)
        : out.buffPassExpiresAt,
    growthPassExpiresAt: p.type == IapType.growthPass
        ? extend(out.growthPassExpiresAt, iap.growthPassDurationDays)
        : out.growthPassExpiresAt,
    redeemedPurchases: purchaseId == null
        ? out.redeemedPurchases
        : {...out.redeemedPurchases, purchaseId},
  );
}

/// 성장 패스 매일 지급 기록 키(`dailyClaims` 재사용 — 곤충학자 패스 매일 젤리 `_iapDaily` 와 같은 방식).
const kGrowthPassDailyKey = '_growthDaily';

/// 성장 패스 **오늘 몫**을 준다. 패스가 없거나 오늘([today], 기기 날짜 키) 이미 받았으면 null.
///
/// 처리는 기기에서 한다(곤충학자 패스 매일 젤리와 같다). 서버는 업로드 검사 여유(가루 500 ·
/// 속성석·가속기 10 · 조각 급증 여유) 안에서 통과시킨다 — 하루 지급량이 그보다 한참 작아야 한다.
/// 밀린 날을 몰아 주지 않는다(하루 한 번, 켠 날만).
SaveGame? claimGrowthPassDaily(
  SaveGame s,
  IapConfig iap, {
  required DateTime now,
  required String today,
  FairyConfig? fairy,
}) {
  if (!s.growthPassActive(now.toUtc())) return null;
  if (s.dailyClaims[kGrowthPassDailyKey] == today) return null;
  final g = iap.growthPassDaily;
  if (g.isEmpty) return null;
  if (g.hasFairy && fairy == null) return null;
  final out = _applyGrantGoods(s, g, fairy);
  return out.copyWith(
    dailyClaims: {...out.dailyClaims, kGrowthPassDailyKey: today},
  );
}

/// 묶음의 **물건**만 넣는다(재화·재료·슬롯·요정·스킬 조각). 상품 표식·기간은 [applyIapGrant] 몫.
SaveGame _applyGrantGoods(SaveGame s, IapGrant g, FairyConfig? fairy) {
  final mats = Map<MaterialKind, int>.from(s.materials);
  void add(MaterialKind k, int n) {
    if (n > 0) mats[k] = (mats[k] ?? 0) + n;
  }

  add(MaterialKind.jelly, g.jelly);
  add(MaterialKind.chitin, g.chitin);
  add(MaterialKind.mineral, g.mineral);
  add(MaterialKind.sap, g.sap);

  var f = s.fairy;
  if (g.hasFairy) {
    f = grantFairyItems(
      f,
      stones: g.fairyStones,
      accelerators: g.fairyAccelerators,
      dust: g.fairyDust,
    );
    if (fairy != null) {
      // 높은 등급부터 넣는다 — 요정함이 차서 넘치면 낮은 등급이 가루가 되게.
      final eggs = <FairyGrade>[
        for (final e in g.fairyEggs.entries)
          if (FairyGrade.fromKeyOrNull(e.key) case final grade?)
            for (var i = 0; i < e.value; i++) grade,
      ]..sort((a, b) => b.index.compareTo(a.index));
      final op = grantFairyEggs(f, fairy, eggs, autoRelease: false);
      if (op.state != null) f = op.state!;
    }
  }

  var shards = s.skillGradeShards;
  if (g.skillGradeShards.values.any((v) => v > 0)) {
    shards = Map<String, int>.from(shards);
    for (final e in g.skillGradeShards.entries) {
      if (e.value > 0) shards[e.key] = (shards[e.key] ?? 0) + e.value;
    }
  }

  return s.copyWith(
    gold: addCurrency(s.gold, g.gold),
    materials: mats,
    incubatorCapacity: s.incubatorCapacity + g.incubatorSlots,
    fairy: f,
    skillGradeShards: shards,
  );
}
