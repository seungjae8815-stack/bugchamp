import 'dart:math';

import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:uuid/uuid.dart';

import 'duel_session.dart';

/// 액션 처리 결과.
class ActionResult {
  const ActionResult.ok(this.save, {this.extra = const {}})
    : error = null,
      status = 200;
  const ActionResult.fail(this.error, {this.status = 400})
    : save = null,
      extra = const {};

  final SaveGame? save;
  final String? error;
  final int status;
  final Map<String, dynamic> extra;

  bool get isOk => save != null;
}

/// 서버 권위 액션들.
///
/// **여기 있는 함수만이 세이브를 바꾼다.** 클라이언트는 "무엇을 하고 싶다"만
/// 보내고, 얼마를 벌었는지·이겼는지는 전부 서버가 정한다.
///
/// 앱과 **같은 `core_*` 코드**로 계산하므로 결과가 어긋나지 않는다.
class GameActions {
  GameActions({required this.config, required this.now, this.rngFactory});

  final GameConfigLike config;

  /// 서버 시각(주입 가능 — 테스트 결정론).
  final DateTime Function() now;

  /// 드롭 롤용 난수. **서버가 소유한다** — 클라이언트가 굴리면 5성 전설을
  /// 마음대로 만들 수 있다(골드 조작보다 훨씬 치명적이다).
  /// 테스트에서 결정론을 위해 주입할 수 있다.
  final Random Function()? rngFactory;

  /// 탭 반격 **개발자 시험 계정** 요청 중인가(2026-10-08 — 출시 전 실기 확인용). 켜져 있으면 `clutchEnabled` 가
  /// false 여도 그 요청의 결투·대회 계산만 탭 반격을 켠다. app.dart 가 동기 호출 앞뒤로만 세운다(await 없음 — 다른
  /// 요청과 섞이지 않는다). 계정 목록은 환경변수 `CLUTCH_TEST_USERS`(쉼표로 구분한 user id).
  bool clutchTestUser = false;

  /// 한 번의 sync 에서 굴릴 드롭 롤 상한.
  /// 오래 비운 뒤 접속하면 처치 수가 수천이 될 수 있어 계산량을 묶는다.
  static const maxRollsPerSync = 300;

  static const _uuid = Uuid();

  /// 구매 지급. **영수증 검증은 호출 전에 끝나 있어야 한다.**
  ///
  /// [purchaseId] 로 중복 지급을 막는다 — 스토어는 같은 구매를 여러 번
  /// 전달할 수 있고, 클라이언트가 재요청할 수도 있다.
  ActionResult grantPurchase(
    SaveGame save, {
    required String productId,
    required String purchaseId,
  }) {
    final product = config.iap.byId(productId);
    if (product == null) {
      return const ActionResult.fail('unknown_product');
    }
    if (save.redeemedPurchases.contains(purchaseId)) {
      // 이미 지급됨 — 오류가 아니라 현재 상태를 그대로 돌려준다(멱등).
      return ActionResult.ok(save, extra: {'alreadyGranted': true});
    }
    final t = now().toUtc();
    // 계정당 1회 상품(스타터 · 요정/스킬 입문 패키지) — 두 번째 영수증 처리는 스타터와 같다.
    if (iapIsOncePerAccount(product) &&
        iapPurchaseBlock(save, product, battle: config.battle, now: t) ==
            IapBlock.owned) {
      // ⚠️ **운영 지급이 먼저 나간 뒤 진짜 결제가 들어오는 경우**가 있다.
      // "샀는데 안 들어왔다" 문의를 /admin/grant 로 먼저 막아 두면, 나중에
      // 검증이 고쳐져 같은 영수증이 흘러올 때 여기서 실패가 난다.
      // 실패로 돌려주면 앱이 스토어에 완료 통보를 못 하고, 승인되지 않은
      // 주문을 구글이 **3일 뒤 자동 환불**한다 — 물건은 이미 나갔는데 돈만
      // 돌아간다(2026-09-11 실제 사고).
      //
      // 그래서 **운영 지급으로 이미 받은 상품**에 한해 성공(멱등)으로
      // 돌려준다. 새로 주는 것은 없고, 앱이 주문을 승인할 수 있게만 한다.
      // 운영 지급 자신(`admin:`)은 예외에서 뺀다 — 스타터 계정당 1회 규칙이
      // 거기서 뚫리면 결제한 사람과 형평이 깨지고, 패널은 아무 일도 일어나지
      // 않은 지급을 "완료"로 보여 주게 된다.
      final grantedByAdmin = save.redeemedPurchases.any(
        (id) =>
            id.startsWith('admin:') &&
            id.split(':').skip(1).contains(productId),
      );
      if (purchaseId.startsWith('admin:') || !grantedByAdmin) {
        return const ActionResult.fail('already_owned');
      }
      return ActionResult.ok(
        save.copyWith(
          redeemedPurchases: {...save.redeemedPurchases, purchaseId},
        ),
        extra: {'alreadyGranted': true},
      );
    }

    // 요정 알은 요정함 상한을 설정에서 읽는다 — 설정이 없으면 실패가 아니라 **보류**(503)로 돌려
    // 앱이 완료 통보를 미루고 다시 보내게 한다(물건 없이 주문만 승인되면 안 된다).
    if (iapNeedsFairyConfig(product) && config.fairy == null) {
      return const ActionResult.fail('config_unavailable', status: 503);
    }
    // 지급 내용은 앱 로컬 지급과 **같은 함수**(core_save `applyIapGrant`). 주간 묶음의 같은 주
    // 두 번째 영수증도 여기서 지급한다 — 거절하면 구글 자동 환불·완료 통보 실패로 꼬인다(함수 주석).
    // 구매 전 차단은 앱 상점이 한다(`iapPurchaseBlock`).
    return ActionResult.ok(
      applyIapGrant(
        save,
        product,
        config.iap,
        battle: config.battle,
        now: t,
        fairy: config.fairy,
        purchaseId: purchaseId,
        speciesOf: (id) =>
            config.speciesList.where((x) => x.id == id).firstOrNull,
      ),
    );
  }

  /// 세이브 편집으로 위조하지 못하게 **서버가 소유하는** 필드들.
  /// 트로피·시즌기록(랭킹), IAP 지급물(결제)·부화기 슬롯(IAP). 업로드 때
  /// 클라 값을 무시하고 서버 저장본 값으로 덮는다.
  static const _serverOwnedKeys = {
    'pvpTrophies',
    'seasonPeakTrophies',
    'redeemedPurchases',
    'starterBought',
    // 요정·스킬 상품(2026-10) — 1회 상품 기록·성장 패스 만료·주간 묶음 산 주. 결제 전용 필드라
    // 전부 서버 소유다(지우면 1회 상품을 다시 사거나, 패스 매일 지급이 공짜로 켜진다).
    'boughtOnce',
    'growthPassExpiresAt',
    'weeklyBought',
    'adsRemoved',
    'passExpiresAt',
    // ⚠️ 무한 버프 패스도 **서버 소유**여야 한다. 여기 없던 탓에 서버가
    // 지급해도 다음 업로드에서 클라 값(null)으로 덮여 **아무 일도 안 일어났다**
    // (2026-09-01 실기: /admin/grant 로 줬는데 적용 안 됨).
    // 유저가 스스로 얻는 경로가 없는(=결제 전용) 필드는 전부 서버 소유다.
    'buffPassExpiresAt',
    // 닉네임 변경 요구(2026-09-02). 닉네임 자체는 서버 소유가 아니라서,
    // 이 플래그를 서버가 쥐고 있어야 앱이 옛 이름을 다시 올려도 요구가 남는다.
    'renameRequired',
    // 한 기기만 접속(2026-10-03, 1.0.16) — 표식은 `/session/claim` 만 바꾼다.
    // 앱이 올린 값을 믿으면 아무 기기나 표식을 들고 와 다른 기기를 밀어낼 수 있다.
    'activeSession',
    'ownedSkins',
    // ⚠️ 깜짝선물 2배 횟수(`giftDoubleDate/Count`)는 여기 두면 안 된다(2026-09-30).
    // 수령은 기기가 처리하는데 서버가 소유하면 서버 값이 영원히 0 이라, 서버 세이브를
    // 채택할 때마다 "오늘 첫 2배 젤리"가 되살아났다. 대신 줄어들 수 없게 병합한다
    // ([_mergeGiftDoubles]).
    // ⚠️ `incubatorCapacity` 는 여기 두면 안 된다. 부화기 슬롯은 IAP 뿐 아니라
    // **젤리로도 산다**(`expandIncubator`). 서버가 소유하면 젤리는 빠지고
    // 슬롯은 업로드 때 되돌아가, 앱을 껐다 켜면 산 게 사라진다(2026-08 버그).
    // 채집함 칸과 같은 정책 — 소유하지 않고 **상한만** 강제한다(enforceStorage).
    // 결투 티켓 = 하루 판수 제한. 세이브를 편집해 티켓을 채우면 제한이
    // 통째로 무의미해지므로(=트로피 랭킹이 다시 '많이 돌린 사람' 순),
    // 잔량·충전기준시각·광고 시청횟수 모두 서버가 소유한다.
    'pvpTickets',
    'ticketsAt',
    'adUseCounts',
    'adUseDate',
    // 이벤트(실물 경품) — 순위가 그대로 상품이 되므로 참가권·피로·기록을 전부
    // 서버가 소유한다. 세이브를 고쳐 참가권을 채우거나 피로를 지우면 최강
    // 3마리로 무한히 도전할 수 있어 제한이 통째로 무의미해진다.
    'eventTickets',
    'eventTicketsAt',
    'eventFatigue',
    'eventRoundId',
    'eventBestWave',
    'eventBestScore',
    // 회차 보상 수령 기록. 지우면 같은 회차 보상을 반복해서 받는다.
    'eventRewardRound',
    // 회차 뱃지. 세이브를 고쳐 챔피언을 달 수 있으면 표식이 무의미해진다.
    'eventBadges',
    // 결투 시즌 순위 보상(2026-09-28). 점수 시즌을 지우면 조회가 안 돌고,
    // 받은 시즌을 지우면 같은 시즌 보상을 반복해서 받는다.
    'pvpScoreSeason',
    'pvpRankRewardSeason',
    // 결투 리그 소속(2026-09-29). 고쳐서 다이아로 올리면 순위 보상이 커진다.
    'pvpLeague',
    // 심연 주간 순위(2026-09-28). 결투 순위와 같은 이유.
    'abyssScoreWeek',
    'abyRk',
    'abyssRewardWeek',
    // 심연 층 시간 예산 기준(2026-09-30). 지우면 예산이 다시 차서 층 상한이 풀린다.
    'abyssFloorAt',
  };

  /// 옛 결투 경로(`/battle`·`/battle/manual/*`, 1.0.13 이하 앱)의 점수를 **새 체계**로 자른다.
  ///
  /// 옛 트로피 규칙은 한 판에 +19 까지 줘서, 새 앱(상대에 따라 1~5점, 지면 0점)과 같은
  /// 순위표에서 3~4배 빨랐다(2026-09-30 점검). 경로를 닫으면 iOS 심사가 늦을 때 구버전
  /// 유저가 결투를 아예 못 하므로 열어 두되, 이기면 +1(새 체계의 야생 상대와 같은 값)·
  /// 지면 0 으로 맞춘다.
  static SaveGame legacyDuelScore(SaveGame before, SaveGame after) {
    final base = before.pvpTrophies;
    final t = after.pvpTrophies.clamp(base, base + 1);
    if (t == after.pvpTrophies) return after;
    return after.copyWith(
      pvpTrophies: t,
      seasonPeakTrophies: max(before.seasonPeakTrophies, t),
    );
  }

  /// 깜짝선물 2배 횟수 병합 — **같은 날엔 줄지 않고**, 날짜는 저장본보다 뒤이면서
  /// 서버의 오늘을 넘지 않을 때만 넘어간다. 0 을 올리거나 날짜를 바꿔 하루 상한·첫 2배 젤리를
  /// 되살리는 길을 막는다.
  static void _mergeGiftDoubles(
    SaveGame stored,
    Map<String, dynamic> merged,
    DateTime now,
  ) {
    final today = dailyDateKey(now);
    final sDate = stored.giftDoubleDate;
    final sCount = stored.giftDoubleCount;
    final cDate = merged['giftDoubleDate'] as String?;
    final cCount = (merged['giftDoubleCount'] as num?)?.toInt() ?? 0;
    String? date;
    int count;
    if (cDate != null && cDate == sDate) {
      date = sDate;
      count = max(cCount, sCount);
    } else if (cDate != null &&
        cDate.compareTo(today) <= 0 &&
        (sDate == null || cDate.compareTo(sDate) > 0)) {
      date = cDate;
      count = cCount;
    } else {
      date = sDate;
      count = sCount;
    }
    if (date == null) {
      merged.remove('giftDoubleDate');
      merged.remove('giftDoubleCount');
    } else {
      merged['giftDoubleDate'] = date;
      merged['giftDoubleCount'] = count;
    }
  }

  /// 세이브 기능 수준(`feat`)별로 **그 수준에서 새로 생긴, 기기가 쓰는 필드**.
  /// 서버 소유 필드는 [_serverOwnedKeys] 가 따로 지킨다.
  static const _fieldsSinceFeat = {
    14: [
      'duelTraining',
      'trainingJob',
      'pvpDefenseIds',
      'abyssUnlocked',
      'inAbyss',
      'abyssFloor',
      'abyssWeek',
      'abyssBest',
      'abyssBossBest',
    ],
    // 요정(1.0.15, docs/design_fairy.md) — 상태 전체가 필드 하나다.
    15: ['fairy'],
    // 곤충 잠금(1.0.15, 2026-10-02) — 모르는 앱이 올리면 저장본의 잠금을 지킨다.
    16: ['lockedBugs', 'reviewTier', 'reviewOpened'],
    // 올라갈 수 있는 한계(1.0.17, 쓰러지면 아래로 — zone_fall.dart). 모르는 앱이 올리면 저장본의 한계를 지킨다.
    17: ['capT', 'capS'],
    // 훈련 v2(1.0.18, docs/design_training_v2.md) — 포인트 배분·찍기 대기열·결투석. 모르는 앱이 올리면 저장본을 지킨다.
    // 옛 훈련 단계·대기열(`duelTraining`·`trainingJob`)은 **이전이 이미 된 계정만** 얼린다 — 아래
    // [_keepFieldsOldAppDoesNotKnow] 의 따로 처리.
    19: ['trainPoints', 'trainPointJob', 'duelStones'],
    // 공방 초월(1.0.19, 2026-10-10) — 모르는 앱이 올리면 저장본의 초월 단계를 지킨다.
    22: ['forgeTranscend'],
  };

  /// feat 20(1.0.18)에 생긴 **장비 옵션 키** — 그보다 낮은 앱은 모르고 빼고 올린다.
  static const _optionKeysSinceFeat20 = {'evade'};

  /// [stored] 장비에서 구버전이 모르는 옵션만 뺀 모양이 [incoming] 과 같으면 [stored] 를, 아니면 null.
  /// (저장본에 그런 옵션이 없으면 되돌릴 것도 없으니 null.)
  static Object? _restoreDroppedOptions(Object? stored, Object? incoming) {
    if (stored is! Map || incoming is! Map) return null;
    if (stored['s'] != incoming['s']) return null;
    if ((stored['t'] as num?)?.toInt() != (incoming['t'] as num?)?.toInt()) {
      return null;
    }
    final so = stored['o'];
    final co = incoming['o'];
    if (so is! List) return null;
    final kept = [
      for (final o in so)
        if (o is Map && !_optionKeysSinceFeat20.contains(o['k'])) o,
    ];
    if (kept.length == so.length) return null; // 빠진 옵션이 없다
    final inc = co is List ? co : const [];
    if (inc.length != kept.length) return null;
    for (var i = 0; i < kept.length; i++) {
      final a = kept[i];
      final b = inc[i];
      if (b is! Map || a['k'] != b['k']) return null;
      if ((a['v'] as num?)?.toDouble() != (b['v'] as num?)?.toDouble()) {
        return null;
      }
    }
    return stored;
  }

  /// feat 21(장비 v2) 키 — 1.0.18 이하 앱은 `EquipItem.tryFromJson` 이 s/t/o 만 읽어 **버리고** 올린다.
  /// [incoming] 이 [stored] 와 같은 장비(부위·등급·옵션 종류·값이 같다)면 저장본의 별(`st`)·환생 재료(`sx`)·
  /// 옵션 정성(`p`)을 얹은 사본을, 아니면 null(구버전 기기에서 장비를 바꿨으면 새 장비를 그대로 둔다).
  static Map<String, dynamic>? _restoreEquipV2(
    Object? stored,
    Object? incoming,
  ) {
    if (stored is! Map || incoming is! Map) return null;
    final hasV2 =
        stored.containsKey('st') ||
        stored.containsKey('sx') ||
        stored.containsKey('su') ||
        (stored['o'] is List &&
            (stored['o'] as List).any((o) => o is Map && o.containsKey('p')));
    if (!hasV2) return null;
    if (stored['s'] != incoming['s']) return null;
    if ((stored['t'] as num?)?.toInt() != (incoming['t'] as num?)?.toInt()) {
      return null;
    }
    final so = stored['o'];
    final co = incoming['o'];
    if (so is! List || co is! List || so.length != co.length) return null;
    final opts = <dynamic>[];
    for (var i = 0; i < so.length; i++) {
      final a = so[i];
      final b = co[i];
      if (a is! Map || b is! Map || a['k'] != b['k']) return null;
      if ((a['v'] as num?)?.toDouble() != (b['v'] as num?)?.toDouble()) {
        return null;
      }
      opts.add(<String, dynamic>{
        ...Map<String, dynamic>.from(b),
        if (a.containsKey('p')) 'p': a['p'],
      });
    }
    return <String, dynamic>{
      ...Map<String, dynamic>.from(incoming),
      'o': opts,
      if (stored.containsKey('st')) 'st': stored['st'],
      if (stored.containsKey('sx')) 'sx': stored['sx'],
      if (stored.containsKey('su')) 'su': stored['su'],
    };
  }

  /// [incoming] 을 쓴 앱이 모르는 필드는 [stored] 의 값으로 채운 사본(아는 앱이면 그대로).
  static Map<String, dynamic> _keepFieldsOldAppDoesNotKnow(
    SaveGame stored,
    Map<String, dynamic> incoming,
  ) {
    final feat = (incoming['feat'] as num?)?.toInt() ?? 0;
    if (feat >= kSaveFeatureLevel) return incoming;
    final storedJson = stored.toJson();
    final out = Map<String, dynamic>.from(incoming);
    // 곤충의 합성 단계(`su`, 1.0.14) — 구버전 앱은 모르고 떨어뜨린다. 같은 곤충이면 저장본 값을 되돌린다
    // (안 되돌리면 합성 5성이 다시 젤리가 된다).
    if (feat < 14) {
      final su = {
        for (final b in stored.bugs)
          if (b.synthUps > 0) b.id: b.synthUps,
      };
      final list = incoming['bugs'];
      if (su.isNotEmpty && list is List) {
        out['bugs'] = [
          for (final b in list)
            if (b is Map && su.containsKey(b['id']) && b['su'] == null)
              (Map<String, dynamic>.from(b)..['su'] = su[b['id']])
            else
              b,
        ];
      }
    }
    // 요정 상태 안의 1.0.18 칸 — 알 자동 분해(`ar`) · 젤리로 늘린 요정함(`bx`). 요정 상태는 필드 하나라
    // 통째로 지키면 1.0.17 의 요정 진행이 사라진다 — 모르는 칸만 저장본 값으로 되돌린다.
    // (안 되돌리면 1.0.17 기기 한 번 업로드로 산 요정함 칸이 사라진다.)
    if (feat >= 15 && feat < 18) {
      final sf = storedJson['fairy'];
      final cf = incoming['fairy'];
      if (sf is Map && cf is Map) {
        final merged = Map<String, dynamic>.from(cf);
        for (final k in const ['ar', 'bx']) {
          if (sf.containsKey(k) && !cf.containsKey(k)) merged[k] = sf[k];
        }
        out['fairy'] = merged;
      }
    }
    // 장비 옵션 `evade`(회피, 1.0.18 · feat 20) — 1.0.17 이하 앱은 모르는 옵션을 **빼고** 읽어
    // (ItemOption.tryFromJson) 그대로 다시 올린다. 같은 장비(부위·등급·나머지 옵션이 같다)면 저장본
    // 장비를 되돌린다. 구버전 기기에서 장비를 바꿨으면(나머지가 다르다) 올라온 새 장비를 그대로 둔다.
    if (feat < 20) {
      final se = storedJson['equippedItems'];
      final ce = incoming['equippedItems'];
      if (se is Map && ce is Map) {
        // ⚠️ 타입을 `Map<String, dynamic>` 으로 — SaveGame.fromJson 이 그 타입으로 캐스트한다.
        out['equippedItems'] = <String, dynamic>{
          for (final e in ce.entries)
            '${e.key}': _restoreDroppedOptions(se[e.key], e.value) ?? e.value,
        };
      }
      final ss = storedJson['forgeStack'];
      final cs = incoming['forgeStack'];
      if (ss is List && cs is List) {
        final pool = [...ss];
        out['forgeStack'] = <dynamic>[
          for (final item in cs)
            () {
              for (var i = 0; i < pool.length; i++) {
                final r = _restoreDroppedOptions(pool[i], item);
                if (r != null) {
                  pool.removeAt(i);
                  return r;
                }
              }
              return item;
            }(),
        ];
      }
    }
    // 장비 v2 키(feat 21) — 같은 장비면 저장본의 별·환생 재료·정성을 얹는다(위 회피 복원 뒤의 모양 기준).
    if (feat < 21) {
      final se = storedJson['equippedItems'];
      final ce = out['equippedItems'];
      if (se is Map && ce is Map) {
        out['equippedItems'] = <String, dynamic>{
          for (final e in ce.entries)
            '${e.key}': _restoreEquipV2(se[e.key], e.value) ?? e.value,
        };
      }
      final ss = storedJson['forgeStack'];
      final cs = out['forgeStack'];
      if (ss is List && cs is List) {
        final pool = [...ss];
        out['forgeStack'] = <dynamic>[
          for (final item in cs)
            () {
              for (var i = 0; i < pool.length; i++) {
                final r = _restoreEquipV2(pool[i], item);
                if (r != null) {
                  pool.removeAt(i);
                  return r;
                }
              }
              return item;
            }(),
        ];
      }
    }
    for (final e in _fieldsSinceFeat.entries) {
      if (feat >= e.key) continue;
      for (final k in e.value) {
        if (storedJson.containsKey(k)) {
          out[k] = storedJson[k];
        } else {
          out.remove(k);
        }
      }
    }
    // 옛 훈련 단계·대기열 — 1.0.18 기기가 이미 포인트로 옮긴 계정만 얼린다(그 뒤 1.0.17 기기가 올린 옛 단계가
    // 이전 상한 — 옛 투자로 다시 계산하는 칸 상한·보너스 한도 — 를 늘리지 못하게). 아직 아무 기기도 옮기지 않았으면
    // 1.0.17 의 투자를 그대로 받는다: 서버가 먼저 옮겨 굳히던 시절엔 서버 배포~앱 업데이트 사이(iOS 는 심사로 며칠)에
    // 1.0.17 에서 올린 부위 강화·훈련이 이전에 안 실려 사라졌다(2026-10-09 출시 전 점검). 앱이 켜질 때 직접 옮긴다.
    if (feat < 19 && stored.trainPoints.isNotEmpty) {
      for (final k in const ['duelTraining', 'trainingJob']) {
        if (storedJson.containsKey(k)) {
          out[k] = storedJson[k];
        } else {
          out.remove(k);
        }
      }
    }
    return out;
  }

  /// 한 번의 업로드에 실릴 수 있는 화석 조각의 **정상 최대치**.
  ///
  /// 가장 큰 정상 버스트는 **오프라인 정산 복귀**다 — 앱을 내려뒀다 열면
  /// 오프라인 상한(패스 12시간)만큼 쌓인 분이 한꺼번에 들어온다(약 800개).
  /// 여기에 여유를 곱해, 입장 후 네트워크가 끊긴 채 몇 시간 논 경우까지 덮는다.
  /// 상수를 손으로 박지 않는 이유: `fossilPerSecond` 를 JSON 에서 바꾸면
  /// 상한이 저절로 따라와야 한다(안 그러면 조용히 정상 유저를 자른다).
  int get _maxFossilGain {
    final f = config.forge;
    if (f == null) return 3000;
    const maxOfflineHours = 12; // 곤충학자 패스 기준
    final burst =
        f.fossilPerSecond * f.fossilOfflineRatio * maxOfflineHours * 3600;
    return (burst * _fossilSlack).round();
  }

  /// 골드 급증 상식 상한의 바닥 — 전투·미션·광고 등 **소소한 보상**만 덮는다.
  ///
  /// 예전엔 2,000,000 이었다. 큰 챕터 보상까지 이 값 하나로 덮으려다 보니
  /// 업로드(60초)마다 200만이 무조건 통과해 **하루 28억까지 정당화**됐다.
  /// 챕터 보상은 아래 [_chapterGrantAllowance] 로 따로 인정하므로 이 바닥은
  /// 작아도 된다.
  static const _goldSanityFloor = 200000;

  /// 젤리(프리미엄 재화) 급증 상한의 바닥. 솔로 획득(선물·분해)은 소량이라
  /// 통과하되, 세이브 편집으로 999999 를 넣는 건 막는다(결제 우회 차단).
  ///
  /// 1000 → 300(2026-09-30 점검): 업로드는 60초마다라 1000 이면 편집으로 하루 144만까지 통과했다.
  /// 기기에서 한꺼번에 들어오는 큰 젤리는 도감·보스 마일스톤뿐이라 그건 [_dexJellyAllowance] 로
  /// 따로 인정한다(결제·순위·대회·우편 젤리는 서버가 저장본에 먼저 넣어 증가분에 안 잡힌다).
  static const _jellySanityFloor = 300;

  /// 일반 재료(키틴·미네랄·수액) **업로드 1회당** 증가 상한.
  ///
  /// ⚠️ 예전엔 이 검사가 아예 없었다 — 젤리·화석만 막고 일반 재료는 통과였다
  /// (2026-09-01 발견). 세이브를 고쳐 올리면 수십억이 그대로 들어간다.
  ///
  /// 값의 근거: 재료는 처치당 드롭이고 수량이 깊이에 따라 자란다
  /// (`materialAmountMult`, 스테이지당 x1.01). 캠페인 끝(1000)의 시간당
  /// 수입이 약 140만이므로, 업로드 주기(60초)의 정상 최대는 약 2.4만이다.
  /// 오프라인 정산 복귀·교환소 한 번(628만)까지 덮으려면 여유가 크게 필요하다.
  /// 2000만이면 교환 3회분을 덮으면서도 "수십억 주입"은 막는다.
  static const _materialSanityFloor = 20000000;

  /// 업로드 1회당 증가 상한을 **밖에서도** 볼 수 있게 연다.
  ///
  /// 운영 정상화(`/admin/currency`)가 "원하는 최종 값"에서 이 값을 빼서
  /// 저장한다 — 앱에 남은 옛 값이 상한만큼 되올라간 뒤 멈추기 때문이다.
  /// 상수를 두 곳에 적으면 한쪽만 고쳐 조용히 어긋난다.
  static const goldUploadCap = _goldSanityFloor;

  static int uploadCapFor(MaterialKind k) => switch (k) {
    MaterialKind.jelly => _jellySanityFloor,
    // 화석은 설정에서 파생되므로 인스턴스 값이 필요하다 — 정상화 대상이
    // 아니라서 보수적으로 0(= 뺄셈 없음)을 준다.
    MaterialKind.fossil => 0,
    _ => _materialSanityFloor,
  };

  /// 화석 조각(제련용) 증가 상한의 여유 배수.
  ///
  /// ⚠️ **보유 상한이 아니라 업로드 1회당 증가 상한이다.** 모아뒀다 한 번에
  /// 쓰는 건 아무 제약이 없다(감소는 검사하지 않는다).
  ///
  /// ⚠️ **경과시간에 비례시키면 안 된다.** 오프라인 정산이 8시간(패스 12시간)
  /// 에서 멈추므로, 오래 비울수록 **상한만 부풀고 정상 획득은 그대로**다
  /// (3일 비우면 상한 4만인데 정상은 여전히 533). 긴 공백에서는 고정 상한이
  /// 오히려 더 촘촘하다.
  static const _fossilSlack = 4.0;

  /// 상한 계산용 넉넉한 방치 효율(액티브 플레이 여유 포함 — 절대치만 잡는다).
  ///
  /// ⚠️ **탭 부스트 상한과 함께 움직여야 한다.** 부스트는 연타로 배율이 쌓여
  /// `boostMultMax`(현재 5.0)까지 오르고, 데미지·공격속도에 모두 실려 최대
  /// 25배 DPS 가 된다. 이 값이 낮으면 **열심히 두드린 정상 유저의 골드가
  /// 잘린다** — 방어보다 오탐이 더 나쁘다. 방치 효율(0.3) 대비 100배까지 인정.
  static const _saveBoundEfficiency = 30.0;

  /// 상한 계산용 공격력 배율 — 강화만 반영한 전력에 곱한다.
  ///
  /// 상한은 저장본의 **강화**로만 전력을 잰다(펫·장비·버프·탭은 모른다). 난이도별
  /// 표(2026-09-15)에서는 펫·장비를 갖춘 유저가 강화만 한 전력보다 몬스터를 수십
  /// 배 빨리 잡아, 사냥터 중반부터 **정당한 수입이 잘렸다**(clamp_check 실측 x0.26).
  /// 처치 속도는 아무리 세도 **걷는 시간**(0.6초) 아래로 안 내려가므로, 공격을
  /// 넉넉히 줘서 처치를 걷는 시간에 붙인다 — 봉투는 여전히 "처치당 골드 × 걷는
  /// 속도"로 묶여 1→10억 같은 조작은 그대로 잘린다.
  static const _saveBoundAttackMult = 100.0;

  /// 이번 업로드에서 **정당하게 받았을 수 있는 챕터 클리어 보상**의 합.
  ///
  /// 챕터 보상은 앱이 지급하고(`SaveController.grantChapterClears`) 세이브에
  /// 실려 올라온다. 6챕터부터 500만·1500만… 40억까지 커지는데, 이걸 인정하지
  /// 않으면 골드 상식 상한에 걸려 **정상 유저의 보상이 통째로 잘린다**.
  ///
  /// 부풀리기는 세 가지로 막는다:
  /// 1. 로드맵 설정에 있는 챕터만,
  /// 2. 저장본에 **없던** 챕터만(같은 챕터를 두 번 인정하지 않는다),
  /// 3. 올라온 최고 스테이지가 실제로 그 챕터를 넘겼을 때만.
  int _chapterGrantAllowance(SaveGame stored, Map<String, dynamic> clientJson) {
    final chapters = config.roadmap?.chapters;
    if (chapters == null || chapters.isEmpty) return 0;

    final claimed = ((clientJson['clearedChapters'] as List?) ?? const [])
        .map((e) => e.toString())
        .toSet();
    if (claimed.isEmpty) return 0;

    final already = stored.clearedChapters.toSet();
    // 사냥터 세대가 낮은 앱(구버전)이 올린 스테이지는 옛 진행도다 — 안 믿는다.
    final epoch = (clientJson['zoneEpoch'] as num?)?.toInt() ?? 0;
    final stage = epoch < kZoneEpoch
        ? 0
        : (clientJson['stageNumber'] as num?)?.toInt() ?? 0;

    // 기록 키는 난이도마다 따로다(`w3@2`). 올라온 세이브의 난이도 키만 인정한다 —
    // 쉬움에 있으면서 극한 키를 올려 큰 보상을 끼워 넣지 못하게.
    final tier =
        (clientJson['difficultyTier'] as num?)?.toInt() ??
        stored.difficultyTier;
    // 난이도는 기기 권위라 위조할 수 있고, 클리어 보상은 난이도에 따라 커진다.
    // 저장본이 가 본 최고 난이도에서 **한 계단**까지만 믿는다(업로드 사이에 최종
    // 보스를 깨고 넘어갔을 수 있다). 표가 없는 난이도도 인정하지 않는다.
    final storedTop = stored.topTier;
    if (tier < 0 || tier > storedTop + 1) return 0;
    if (config.run.zoneTiers.isNotEmpty &&
        tier >= config.run.zoneTiers.length) {
      return 0;
    }
    // 가 본 난이도로 내려가 있으면 앱이 클리어 보상을 주지 않는다
    // (`SaveController.grantChapterClears`).
    final clientTop = (clientJson['maxTierReached'] as num?)?.toInt() ?? tier;
    if (tier < clientTop) return 0;
    // 저장본 스테이지는 **같은 난이도**일 때만 근거가 된다 — 쉬움 1001 에서 보통으로
    // 넘어간 직후 그 1001 로 보통 챕터를 전부 넘긴 것처럼 보이면 안 된다.
    // 최고 기록(`bestStage`)도 본다 — 보스를 깨고 곧장 아래 사냥터로 내려가면
    // 지금 스테이지는 낮아지지만 방금 받은 보상은 정당하다(최고 기록은 최고
    // 난이도에서만 오른다, `SaveController._commit`).
    final storedStage = stored.difficultyTier == tier ? stored.stageNumber : 0;
    final best = epoch < kZoneEpoch
        ? 0
        : (clientJson['bestStage'] as num?)?.toInt() ?? 0;
    final highest = max(max(stage, storedStage), best);
    // 전환기(2026-09-15): 구버전 앱(난이도별 키·30분치 보상 이전)은 평문 키(`w3`)와
    // 옛 정액(`rewardGold`)을 올린다. 새 앱은 난이도 1 이상이면 `maxTierReached` 를
    // 싣는다 — 그 키가 없고 난이도 키 대신 평문 키가 있으면 구버전으로 보고 옛
    // 정액을 인정한다. 앱이 나갈 때까지 기존 유저의 챕터 보상이 통째로 잘리지
    // 않게 하려는 것이다(쉬움은 키가 같아 구분이 안 되므로 둘 중 큰 쪽).
    final maybeOld = tier >= 1 && !clientJson.containsKey('maxTierReached');
    // 마지막 사냥터는 최종 보스 도감으로 본다(`chapterClearedAt` — 앱과 같은 판정).
    final bossDex = {
      ...stored.bossDex,
      for (final e in (clientJson['bossDex'] as List? ?? const [])) '$e',
    };
    var sum = 0;
    for (final ch in chapters) {
      final key = chapterClearKey(ch.id, tier);
      if (already.contains(key) ||
          !chapterClearedAt(
            ch,
            roadmap: config.roadmap!,
            run: config.run,
            tier: tier,
            highestStage: highest,
            bossDex: bossDex,
          )) {
        continue;
      }
      if (claimed.contains(key)) {
        final now = chapterClearGold(config.run, ch, tier);
        sum += tier == 0 ? max(now, ch.rewardGold) : now;
      } else if (maybeOld &&
          claimed.contains(ch.id) &&
          !already.contains(ch.id)) {
        sum += ch.rewardGold;
      }
    }
    return sum;
  }

  /// 이번 업로드에서 **정당하게 받았을 수 있는 도감 보스 수집 화석**의 합.
  ///
  /// 보스 마일스톤(`dex.json → bossMilestones`)은 앱이 지급하고 `claimedDex` 에
  /// 실려 올라온다. 마지막 마일스톤은 화석 2,000, 도감을 늦게 열어 몇 개를
  /// 한꺼번에 받으면 오프라인 정산 상한(`_maxFossilGain`)을 넘겨 **정상 유저의
  /// 보상이 잘린다**. 저장본에 없던 마일스톤만, 모은 보스 수가 실제로 닿았을 때만.
  /// 이번 업로드에서 새로 받은 **도감 발견·정복·보스 수집 마일스톤 젤리**의 합.
  /// 조건은 골드·화석 허용치와 같다(새로 받았고, 올라온 세이브가 그 조건을 채운다).
  int _dexJellyAllowance(SaveGame stored, Map<String, dynamic> clientJson) {
    final dex = config.dex;
    if (dex == null) return 0;
    final claimed = ((clientJson['claimedDex'] as List?) ?? const [])
        .map((e) => e.toString())
        .toSet();
    if (claimed.isEmpty) return 0;
    final client = SaveGame.fromJson(clientJson);
    final bosses = collectedBosses(client, config.run, config.roadmap).length;
    var sum = 0;
    for (final (list, have) in [
      (dex.discoverMilestones, client.dexDiscovered),
      (dex.conquerMilestones, client.dexConqueredWith(dex.conquerLevel)),
      (dex.bossMilestones, bosses),
    ]) {
      for (final m in list) {
        if (claimed.contains(m.id) &&
            !stored.claimedDex.contains(m.id) &&
            have >= m.count) {
          sum += m.jelly;
        }
      }
    }
    return sum;
  }

  int _dexFossilAllowance(SaveGame stored, Map<String, dynamic> clientJson) {
    final dex = config.dex;
    if (dex == null || dex.bossMilestones.isEmpty) return 0;
    final claimed = ((clientJson['claimedDex'] as List?) ?? const [])
        .map((e) => e.toString())
        .toSet();
    if (claimed.isEmpty) return 0;
    // 모은 보스 수는 올라온 세이브 기준 — 수집 자체는 기기 권위(밸런스 축이 아니라
    // 젤리·화석 일시금뿐이라 위조 이득이 작다).
    final client = SaveGame.fromJson(clientJson);
    final bosses = collectedBosses(client, config.run, config.roadmap).length;
    var sum = 0;
    for (final m in dex.bossMilestones) {
      if (claimed.contains(m.id) &&
          !stored.claimedDex.contains(m.id) &&
          bosses >= m.count) {
        sum += m.fossil;
      }
    }
    return sum;
  }

  /// 이번 업로드에서 **정당하게 받았을 수 있는 도감 발견·정복 마일스톤 골드**의 합.
  ///
  /// 발견·정복 마일스톤은 **정액 골드**(3만~300만)를 앱이 바로 지급한다. 이게 빠져 있어서
  /// 신규 유저(60초 상한 ≈ 20만)가 15종 발견(40만)을 받는 순간 **정당한 보상이 잘렸다**
  /// (2026-09-28 운영 알림 `7e79fb55` — 쉬움 사냥터 1 · Lv21). 화석([_dexFossilAllowance])과
  /// 같은 규칙: 저장본에 없던 마일스톤만, 올라온 세이브의 발견·정복 수가 실제로 닿았을 때만.
  /// 수집은 기기 권위라 위조를 막을 수는 없지만 계정당 1회 일시금이라 이득이 작다.
  int _dexGoldAllowance(SaveGame stored, Map<String, dynamic> clientJson) {
    final dex = config.dex;
    if (dex == null) return 0;
    final claimed = ((clientJson['claimedDex'] as List?) ?? const [])
        .map((e) => e.toString())
        .toSet();
    if (claimed.isEmpty) return 0;
    final client = SaveGame.fromJson(clientJson);
    final discovered = client.dexDiscovered;
    final conquered = client.dexConqueredWith(dex.conquerLevel);
    var sum = 0;
    for (final (list, have) in [
      (dex.discoverMilestones, discovered),
      (dex.conquerMilestones, conquered),
    ]) {
      for (final m in list) {
        if (claimed.contains(m.id) &&
            !stored.claimedDex.contains(m.id) &&
            have >= m.count) {
          sum += m.gold;
        }
      }
    }
    return sum;
  }

  /// 한 번의 업로드에서 인정하는 **확률 조각 드롭**(정예·보스 재처치) 수.
  /// 온라인 처치는 시간당 약 1,600마리 × 정예 6% × 10% ≈ 10번이라 업로드 주기(60초)에
  /// 한 번도 드물다 — 네트워크가 끊긴 채 몇 시간 논 경우까지 덮도록 넉넉히 둔다.
  static const _skillDropSlack = 60;

  /// 스킬 필드 강제(§2.8). 처리는 기기 권위라 **위조를 완전히 막지는 못한다** —
  /// 결투·대회에 싣지 않는 것이 방어선이고, 여기는 세 가지를 막는다.
  ///
  /// 1. **스킬을 모르는 앱의 업로드가 조각·수련을 지우는 것.** 새 앱은
  ///    `skillGradeShards` 를 항상 싣는다. 그 키가 없으면 저장본의 스킬 필드를 지킨다
  ///    (`bossDex`·`maxTierReached` 와 같은 사고 — 구버전은 모르는 키를 빼고 올린다).
  /// 2. **조각을 쏟아 넣는 것.** 조각 수(스킬 조각 + 등급 만능)의 증가가 허용치
  ///    (새로 잡은 보스 × 첫 처치 + 확률 드롭 여유 × 가장 큰 한 번)를 넘으면 저장본으로.
  ///    등급 승급은 조각 수를 줄이기만 한다(10 → 1).
  /// 3. **조각 없이 레벨을 올리는 것.** 오른 레벨의 비용(해금·수련 조각 수)을
  ///    이번 업로드에서 줄어든 조각 수 + 허용치가 덮지 못하면 저장본으로.
  ///    수련은 시작할 때 조각을 내므로, 저장본에서 수련 중이던 스킬의 한 레벨은 선불이다.
  ///
  /// 레벨 ≤ 만렙 · 장착은 보유한 것만·열린 칸까지는 `enforceSkillRules`(앱 로드와 같은 함수).
  SaveGame _enforceSkills(
    SaveGame stored,
    SaveGame client,
    Map<String, dynamic> clientJson,
    SkillConfig cfg,
  ) {
    SaveGame restoreFromStored(
      SaveGame s, {
      required Map<String, int> levels,
    }) => s.copyWith(
      skillLevels: levels,
      skillShards: stored.skillShards,
      skillGradeShards: stored.skillGradeShards,
      skillTrainingId: stored.skillTrainingId,
      skillTrainingEndsAt: stored.skillTrainingEndsAt,
      clearSkillTraining: stored.skillTrainingId == null,
      skillGachaPity: stored.skillGachaPity,
      skillDayKey: stored.skillDayKey,
      skillFreeDrawsUsed: stored.skillFreeDrawsUsed,
      skillSweepsUsed: stored.skillSweepsUsed,
    );

    var out = client;
    if (!clientJson.containsKey('skillGradeShards')) {
      final levels = {...stored.skillLevels};
      for (final e in client.skillLevels.entries) {
        levels[e.key] = max(levels[e.key] ?? 0, e.value);
      }
      out = restoreFromStored(out, levels: levels);
    }
    out = enforceSkillRules(out, cfg);

    int count(SaveGame s) =>
        s.skillShards.values.fold(0, (a, b) => a + b) +
        s.skillGradeShards.values.fold(0, (a, b) => a + b);

    final biggestDrop = [
      cfg.eliteShards,
      ...cfg.bossRepeatShardsByTier,
    ].fold(0, max);
    final newBosses = max(0, out.bossDex.length - stored.bossDex.length);
    // 뽑기·소탕 — 이번 업로드에서 줄어든 젤리로 살 수 있었던 만큼 + 하루 무료분.
    final jellySpent = max(
      0,
      stored.materialCount(MaterialKind.jelly) -
          out.materialCount(MaterialKind.jelly),
    );
    final biggestSweep = cfg.sweepShardsByTier.fold(0, max);
    final cheapest = min(
      cfg.gachaJellyCost > 0 ? cfg.gachaJellyCost : 1 << 30,
      cfg.sweepJellyCost > 0 ? cfg.sweepJellyCost : 1 << 30,
    );
    final bought = cheapest >= 1 << 30
        ? 0
        : jellySpent ~/ cheapest * max(cfg.gachaShards, biggestSweep);
    final freebies =
        cfg.gachaFreePerDay * cfg.gachaShards +
        cfg.sweepFreePerDay * biggestSweep;
    // 심연 10층마다 첫 도달은 보스 첫 처치와 같은 조각(`clearAbyssFloor`).
    final abyssFirsts = abyssNewMilestones(stored, out);
    final allow =
        (newBosses + abyssFirsts) * cfg.bossFirstKillShards +
        _skillDropSlack * biggestDrop +
        bought +
        freebies;

    var levelCost = 0;
    for (final def in cfg.skills) {
      final from = stored.skillLevels[def.id] ?? 0;
      final to = out.skillLevels[def.id] ?? 0;
      for (var lv = from; lv < to; lv++) {
        if (lv == from && lv > 0 && stored.skillTrainingId == def.id) continue;
        levelCost += lv == 0 ? cfg.unlockShards : cfg.shardsForLevel(def, lv);
      }
    }
    if (count(out) - count(stored) + levelCost > allow) {
      final levels = {
        for (final e in out.skillLevels.entries)
          e.key: min(e.value, stored.skillLevels[e.key] ?? 0),
      }..removeWhere((_, v) => v <= 0);
      out = enforceSkillRules(restoreFromStored(out, levels: levels), cfg);
    }
    return _sameSkills(out, client) ? client : out;
  }

  static bool _sameSkills(SaveGame a, SaveGame b) =>
      _sameIntMap(a.skillGradeShards, b.skillGradeShards) &&
      a.skillTrainingId == b.skillTrainingId &&
      a.skillTrainingEndsAt == b.skillTrainingEndsAt &&
      _sameIntMap(a.skillLevels, b.skillLevels) &&
      _sameIntMap(a.skillShards, b.skillShards) &&
      a.equippedSkills.length == b.equippedSkills.length &&
      Iterable.generate(
        a.equippedSkills.length,
      ).every((i) => a.equippedSkills[i] == b.equippedSkills[i]);

  static bool _sameIntMap(Map<String, int> a, Map<String, int> b) =>
      a.length == b.length && a.entries.every((e) => b[e.key] == e.value);

  /// 한 업로드에서 **젤리 없이** 늘 수 있는 등급 가치(정예 드롭·보상 알의 여유 — 희귀 10개분).
  /// 보스 첫 처치 알은 여기가 아니라 새로 잡은 보스 수로 따로 인정한다.
  /// 스킬 조각 여유([_skillDropSlack])와 같은 역할. 알이 나오는 무료 경로가 늘면 함께 본다.
  /// ⚠️ "알 개수 × 가장 비싼 알"로 잡으면 여유가 전설 10개분(270)이라 **신화 3마리(243)를
  /// 만들어 넣어도 통과**했다. 여유는 가치로 잡아 신화 한 마리(81)도 못 들어오게 한다.
  static const _fairyFreeValue = 30;

  /// 한 업로드에서 젤리 없이 늘 수 있는 속성석·가속기 수(보상·상점 여유).
  static const _fairyItemSlack = 10;

  /// 한 업로드에서 사라진 요정·알 없이 늘 수 있는 가루(정예 알이 넘쳐 가루가 되는 몫 등).
  /// 정예 알 확률 2%·하루 180처치면 한 업로드(60초) 넘침은 한두 개 — 희귀 분해(15) 수십 개분.
  static const _fairyDustSlack = 500;

  /// 요정 강제(docs/design_fairy.md §5). 처리는 기기 권위라 **위조를 완전히 막지는 못한다** —
  /// 결투·대회·길드전에 싣지 않는 것이 방어선이고, 여기는 네 가지를 막는다.
  ///
  /// 1. **알 없이 높은 등급이 생기는 것.** 합성은 등급 가치 합([fairyStateValue])을 바꾸지 않으므로,
  ///    합이 (이번에 쓴 젤리로 뽑을 수 있었던 알 × 가장 비싼 알 가치 + 무료 여유)보다 더 늘면
  ///    **넘친 만큼만** 이번에 새로 생긴 알·요정에서 가치 큰 것부터 뺀다.
  ///    ⚠️ 통째로 저장본으로 되돌리면 안 된다 — 쓴 젤리는 순감소라 같은 구간에 젤리를 벌었으면
  ///    정상 유저도 걸리고, 그때 알·요정·레벨업이 전부 사라진다(2026-10-01 호환 검사).
  /// 2. **속성석·가속기를 쏟아 넣는 것.** 개수 증가가 (쓴 젤리 ÷ 가장 싼 값 + 여유)를 넘으면 저장본 개수로.
  /// 3. **세이브 부풀리기.** 모르는 종류·부가·가속기 키, 도감의 없는 칸을 걸러 낸다. 서버는 늘 최신 데이터라
  ///    모르는 키 = 조작이다. (앱에서는 거르지 않는다 — 구버전 앱이 새 종류를 지우면 안 된다.)
  /// 4. **가루 위조.** 한 업로드의 가루 증가를 (사라진 요정·알의 분해·환급 + 도감 + 교환소 + 여유)로 자른다.
  /// 5. **기존 요정 고쳐 쓰기.** 저장본에 있던 id 의 등급·종류·부가·개체값은 저장본 값으로([_keepFairyIdentity]).
  ///
  /// 레벨 ≤ 등급 상한 · 요정함 상한은 `enforceFairyRules`(앱 로드와 같은 함수).
  SaveGame _enforceFairy(SaveGame stored, SaveGame client, FairyConfig cfg) {
    final before = stored.fairy;
    var f = _fairyKnownKeysOnly(enforceFairyRules(client.fairy, cfg), cfg);
    // 이미 있던 요정·알의 **정체는 바뀌지 않는다**(레벨만 오른다). 가치 검사는 새 id 만 깎으므로,
    // 기존 요정의 등급을 신화로 고쳐 올리면 그대로 통과했다(2026-10-01 점검).
    f = _keepFairyIdentity(before, f, cfg);
    // 재굴림(2026-10-04) — 대기 결과·하루 횟수는 **서버만** 쓴다(mergeSave 가 판정 전에 이미 맞췄다 — 여기는 방어).
    f = _keepRerollFields(before, f);
    final jellySpent = max(
      0,
      stored.materialCount(MaterialKind.jelly) -
          client.materialCount(MaterialKind.jelly),
    );
    final eggsBought = cfg.gachaJelly > 0 ? jellySpent ~/ cfg.gachaJelly : 0;
    final topEgg = cfg.gachaWeights.keys.fold<int>(
      fairyGradeValue(FairyGrade.legendary),
      (a, g) => max(a, fairyGradeValue(g)),
    );
    // 보스 첫 처치는 난이도별 알을 **확정**으로 준다(design_fairy.md §1.4) — 새로 잡은 보스 수만큼 인정.
    // 안 넣으면 보스 두 마리를 잡고 한 번에 올린 정상 유저의 전설 알이 잘린다.
    final newBosses = max(0, client.bossDex.length - stored.bossDex.length);
    final bossEgg = cfg.drops.bossFirstEggGradeByTier.fold<int>(
      0,
      (a, g) => max(a, fairyGradeValue(g)),
    );
    final over =
        fairyStateValue(f) -
        fairyStateValue(before) -
        (eggsBought * topEgg + newBosses * bossEgg + _fairyFreeValue);
    if (over > 0) f = _trimNewFairyValue(before, f, over);

    // 요정 도감 마일스톤(2026-10-01) — 받은 수는 줄지 않고(되받기 방지), 도감 칸이 실제로 닿은 것만
    // 인정한다. 새로 받은 것만큼 가속기·가루 증가를 허용(화석은 mergeSave 의 화석 상한에서).
    final dexNew = fairyDexNewlyClaimed(before, f, cfg);
    final dexOk = before.dexClaimed + dexNew.length;
    final dexFixed = f.dexClaimed < before.dexClaimed
        ? before.dexClaimed
        : min(f.dexClaimed, dexOk);
    if (dexFixed != f.dexClaimed) f = f.copyWith(dexClaimed: dexFixed);

    int items(FairyState s) =>
        s.stones.values.fold(0, (a, b) => a + b) +
        s.accelerators.values.fold(0, (a, b) => a + b);
    final cheapest = [
      cfg.stoneJelly,
      for (final a in cfg.accelerators) a.jelly,
    ].where((p) => p > 0).fold<int>(1 << 30, min);
    final itemAllow =
        (cheapest >= 1 << 30 ? 0 : jellySpent ~/ cheapest) +
        newBosses * cfg.drops.bossFirstStones +
        dexNew.fold<int>(0, (a, m) => a + m.acceleratorCount) +
        _fairyItemSlack;
    if (items(f) - items(before) > itemAllow) {
      f = f.copyWith(stones: before.stones, accelerators: before.accelerators);
    }

    // 가루는 **사라진 것에서만** 나온다(2026-10-01 점검 — 예전엔 요정함 전부를 신화 만렙으로 분해한
    // 양(약 1,000만)을 매 업로드 허용해 사실상 상한이 없었다). 저장본에 있다 사라진 요정 = 분해 가루 +
    // 레벨업 환급(분해·합성 공통 상한), 사라진 알 = 분해 가루. 이번 업로드에 생겼다 바로 사라진 것
    // (넘친 알·뽑자마자 분해)은 쓴 젤리 · 새 보스 · 무료 여유로 덮는다.
    final nowIds = {
      for (final x in f.fairies) x.id,
      for (final e in f.eggs) e.id,
      if (f.nest != null) f.nest!.eggId,
    };
    var dustAllow = _fairyDustSlack;
    for (final x in before.fairies) {
      if (nowIds.contains(x.id)) continue;
      dustAllow +=
          (cfg.releaseDust[x.grade] ?? 0) +
          (cfg.dustSpentTo(x.grade, x.level) * cfg.mergeDustRefund).ceil();
    }
    final maxEggDust = cfg.releaseDust.values.fold<int>(0, max);
    for (final e in before.eggs) {
      if (!nowIds.contains(e.id)) dustAllow += cfg.releaseDust[e.grade] ?? 0;
    }
    dustAllow += (eggsBought + newBosses) * maxEggDust;
    final dustAllowAll =
        dustAllow +
        dexNew.fold<int>(0, (a, m) => a + m.dust) +
        // 상점 교환소(젤리 → 가루, 2026-10-01) — 하루 상한이 있으면 업로드당 그 값까지.
        min<int>(
          (jellySpent * cfg.exchangeDustPerJelly).ceil(),
          cfg.exchangeDustDailyCap > 0 ? cfg.exchangeDustDailyCap : 1 << 30,
        );
    if (f.dust - before.dust > dustAllowAll) {
      f = f.copyWith(dust: before.dust + dustAllowAll);
    }
    return f == client.fairy ? client : client.copyWith(fairy: f);
  }

  /// 재굴림 대기 결과·하루 횟수를 저장본 값으로(서버 소유). 같으면 [f] 를 그대로 돌려준다.
  /// 업로드로 대기 결과를 지어내거나(최고 개체값) 횟수를 0 으로 되돌리지 못하게 한다.
  static FairyState _keepRerollFields(FairyState before, FairyState f) {
    if (f.reroll == before.reroll &&
        f.rerollDay == before.rerollDay &&
        f.rerollCount == before.rerollCount) {
      return f;
    }
    return before.reroll == null
        ? f.copyWith(
            clearReroll: true,
            rerollDay: before.rerollDay,
            rerollCount: before.rerollCount,
          )
        : f.copyWith(
            reroll: before.reroll,
            rerollDay: before.rerollDay,
            rerollCount: before.rerollCount,
          );
  }

  /// 모르는 종류·부가를 가진 요정·둥지, 모르는 속성석·가속기 키, 없는 도감 칸을 버린다.
  static FairyState _fairyKnownKeysOnly(FairyState f, FairyConfig cfg) {
    final kinds = {for (final k in cfg.kinds) k.id};
    final subs = cfg.subWeight.keys.toSet();
    final accels = {for (final a in cfg.accelerators) a.id};
    bool known(String kind, String sub) =>
        kinds.contains(kind) && subs.contains(sub);
    final dexOk = {
      for (final k in kinds) ...[
        for (final g in FairyGrade.values) FairyState.dexKey(k, g),
        for (final b in subs) FairyState.dexSubKey(k, b),
      ],
    };
    final fairies = [
      for (final x in f.fairies)
        if (known(x.kind, x.sub)) x,
    ];
    final nest = f.nest;
    final out = f.copyWith(
      fairies: fairies,
      clearNest: nest != null && !known(nest.kind, nest.sub),
      clearCompanion:
          f.companionId != null && !fairies.any((x) => x.id == f.companionId),
      stones: {
        for (final e in f.stones.entries)
          if (subs.contains(e.key)) e.key: e.value,
      },
      accelerators: {
        for (final e in f.accelerators.entries)
          if (accels.contains(e.key)) e.key: e.value,
      },
      dex: f.dex.intersection(dexOk),
    );
    return out == f ? f : out;
  }

  /// 저장본에 있던 요정·알의 정체(등급·종류·부가·개체값)를 저장본 값으로 되돌리고, 같은 id 는 하나만 남긴다.
  /// 레벨은 올라갈 수 있으므로 클라 값을 쓰되 (되돌린) 등급의 상한으로 자른다.
  /// 둥지의 알이 저장본의 알·둥지였다면 등급도 그 값으로(종류·부가·개체값은 넣을 때 굴리므로 둥지가
  /// 저장본에 이미 있었을 때만 고정).
  static FairyState _keepFairyIdentity(
    FairyState before,
    FairyState f,
    FairyConfig cfg,
  ) {
    final oldF = {for (final x in before.fairies) x.id: x};
    final oldE = {for (final e in before.eggs) e.id: e};
    final seen = <String>{};
    var changed = false;
    final fairies = <Fairy>[];
    for (final x in f.fairies) {
      if (!seen.add(x.id)) {
        changed = true;
        continue;
      }
      final o = oldF[x.id];
      if (o == null ||
          (o.kind == x.kind &&
              o.grade == x.grade &&
              o.sub == x.sub &&
              o.baseRoll == x.baseRoll &&
              o.subRoll == x.subRoll)) {
        fairies.add(x);
        continue;
      }
      changed = true;
      fairies.add(
        o.copyWith(level: x.level.clamp(o.level, cfg.maxLevelOf(o.grade))),
      );
    }
    final eggs = <FairyEgg>[];
    for (final e in f.eggs) {
      if (!seen.add(e.id)) {
        changed = true;
        continue;
      }
      final o = oldE[e.id];
      if (o != null && o.grade != e.grade) {
        changed = true;
        eggs.add(o);
      } else {
        eggs.add(e);
      }
    }
    var nest = f.nest;
    if (nest != null) {
      final was = before.nest;
      final fromEgg = oldE[nest.eggId];
      if (seen.contains(nest.eggId)) {
        // 둥지 알 id 가 요정·알과 겹친다(넣은 알은 알 목록에서 빠진다) — 위조. 둥지를 비운다.
        changed = true;
        nest = null;
      } else if (was != null && was.eggId == nest.eggId) {
        // 같은 알이 둥지에 있었다 — 정체는 저장본, 완료 시각은 당겨질 수만 있다(가속기).
        final ends = nest.endsAt.isBefore(was.endsAt)
            ? nest.endsAt
            : was.endsAt;
        final fixed = was.copyWith(endsAt: ends);
        if (fixed != nest) {
          nest = fixed;
          changed = true;
        }
      } else if (fromEgg != null && fromEgg.grade != nest.grade) {
        // 저장본의 알을 넣었다 — 등급은 그 알의 등급.
        nest = FairyNest(
          eggId: nest.eggId,
          grade: fromEgg.grade,
          kind: nest.kind,
          sub: nest.sub,
          baseRoll: nest.baseRoll,
          subRoll: nest.subRoll,
          endsAt: nest.endsAt,
        );
        changed = true;
      }
    }
    if (!changed) return f;
    return f.copyWith(
      fairies: fairies,
      eggs: eggs,
      nest: nest,
      clearNest: nest == null && f.nest != null,
    );
  }

  /// 이번 업로드에서 **새로 생긴**(저장본에 id 가 없는) 알·둥지·요정을 등급 가치 큰 것부터
  /// [over] 가 메워질 때까지 뺀다. 예전부터 있던 것은 건드리지 않는다.
  static FairyState _trimNewFairyValue(
    FairyState before,
    FairyState f,
    int over,
  ) {
    final oldIds = {
      for (final x in before.fairies) x.id,
      for (final e in before.eggs) e.id,
      if (before.nest != null) before.nest!.eggId,
    };
    final cands = <({String id, int value})>[
      for (final e in f.eggs)
        if (!oldIds.contains(e.id)) (id: e.id, value: fairyGradeValue(e.grade)),
      if (f.nest != null && !oldIds.contains(f.nest!.eggId))
        (id: f.nest!.eggId, value: fairyGradeValue(f.nest!.grade)),
      for (final x in f.fairies)
        if (!oldIds.contains(x.id)) (id: x.id, value: fairyGradeValue(x.grade)),
    ]..sort((a, b) => b.value.compareTo(a.value));
    final gone = <String>{};
    var left = over;
    for (final c in cands) {
      if (left <= 0) break;
      gone.add(c.id);
      left -= c.value;
    }
    if (gone.isEmpty) return f;
    return f.copyWith(
      fairies: [
        for (final x in f.fairies)
          if (!gone.contains(x.id)) x,
      ],
      eggs: [
        for (final e in f.eggs)
          if (!gone.contains(e.id)) e,
      ],
      clearNest: f.nest != null && gone.contains(f.nest!.eggId),
      clearCompanion: f.companionId != null && gone.contains(f.companionId),
    );
  }

  /// 기기 권위 세이브 업로드 병합.
  ///
  /// 솔로 루프(업그레이드·재화·육성·방치·수령)는 **기기가 확정**하고 여기로
  /// 올린다. 서버는 두 가지만 강제한다:
  ///  1. **보호 필드**(트로피·IAP)를 서버 저장본 값으로 덮는다 — 세이브 편집으로
  ///     랭킹·결제 상태를 위조하지 못하게.
  ///  2. 골드가 **말도 안 되게** 뛰면(1→10억) 상식 상한으로 자른다.
  /// PvP 전투·결제의 실제 지급은 별도 서버 액션이 확정한다.
  ActionResult mergeSave(SaveGame stored, Map<String, dynamic> incomingJson) {
    // 구버전 앱(1.0.13 이하)은 1.0.14 필드를 모른다 — 키 없이 올리면 기본값이 저장본을 덮어
    // 훈련소 기록·이번 주 심연 층이 사라졌다. 그 필드만 저장본 값으로 채워 넣고 진행한다.
    final clientJson = _keepFieldsOldAppDoesNotKnow(stored, incomingJson);
    final t = now().toUtc();
    var elapsed = t.difference(stored.lastSeen);
    if (elapsed.isNegative) elapsed = Duration.zero;

    final stats = _envelopeStats(stored);
    // 봉투는 **올라온 세이브가 있는 자리**로 잰다(2026-09-15). 가 본 난이도로는
    // 자유롭게 오갈 수 있어서(B안), 저장본이 쉬움인데 클라가 극한 사냥터 11 에
    // 올라가 60초를 놀면 저장본 기준 봉투(쉬움)로는 극한 수입이 100배라 잘린다.
    // 난이도는 저장본이 가 본 최고 +1 까지만, 스테이지는 저장본과 클라 중 큰 쪽.
    final clientTier =
        (clientJson['difficultyTier'] as num?)?.toInt() ??
        stored.difficultyTier;
    final envTier = clientTier.clamp(0, stored.topTier + 1).toInt();
    final clientStage = (clientJson['stageNumber'] as num?)?.toInt() ?? 0;
    final envStage = envTier == stored.difficultyTier
        ? max(stored.stageNumber, clientStage)
        : clientStage
              .clamp(1, config.run.zoneStartStage(config.run.zonesPerTier))
              .toInt();
    // 심연 — 층 증가 상한을 먼저 확정한다(봉투도 그 층으로 잰다).
    final abyss = _enforceAbyss(stored, clientJson, elapsed, t);
    final generous = simulateIdleProgress(
      config: config.run,
      startStage: envStage,
      stats: stats,
      elapsed: elapsed,
      efficiency: _saveBoundEfficiency,
      // 회차는 처치 속도(÷3)와 보상(×3)에 서로 반대로 실려 대략 상쇄되지만,
      // 정확히는 아니다 — 봉투가 회차를 모른 채 좁아지면 정당한 수입이 잘린다.
      tier: envTier,
      // 심연 층 골드는 층마다 자란다 — 빼면 심연 유저의 정당한 수입이 잘린다.
      abyssFloor: abyss.inAbyss ? abyss.floor : 0,
    ).gold;
    // 교환소(젤리 → 골드·재료) — 이번 업로드에서 **줄어든 젤리**만큼 교환을 인정한다(2026-10-05).
    // 교환 1회가 "직접 사냥 1시간치"라 60초 봉투로는 바로 잘린다. 젤리 감소는 위조로 늘릴 수 없는 값이다
    // (줄이면 그만큼 젤리를 잃는다). 같은 봉투(넉넉한 효율·공격)로 재서 펫·장비 배율이 빠진 것을 덮는다.
    final exchange = _exchangeAllowance(
      stored,
      clientJson,
      stats: stats,
      stage: envStage,
      tier: envTier,
      abyssFloor: abyss.inAbyss ? abyss.floor : 0,
    );
    // 길드 버프(골드 최대 +10% · 공격 +8%, guild.json skills)는 봉투에 **넣지 않는다** — 여유에 흡수된다.
    // 측정(2026-10-05, `core_run/tool/clamp_check.dart --guild` — 펫 x4·장비 x3·광폭화·골드러시·접속 보너스
    // 위에 길드 최대치): 60초 상한 최소 여유 x6.09(극한 사냥터 1) · 교환소 1회 최소 x27.3.
    // 여유가 2배 아래로 내려가면 여기서 길드 버프를 봉투에 넣는다(서버 settle 이 길드를 조회해야 한다).
    // 깜짝선물·일일보상(사냥 분치) — 기기에서 받으므로 이번 업로드에서 새로 받은 몫을 따로 인정한다.
    final hunt = _huntRewardAllowance(stored, clientJson, t);
    final maxGain =
        _goldSanityFloor +
        generous +
        exchange.gold +
        hunt.gold +
        _chapterGrantAllowance(stored, clientJson) +
        _dexGoldAllowance(stored, clientJson);

    final merged = Map<String, dynamic>.from(clientJson);
    // 보호 필드는 서버 저장본 값으로 (없는 키/null 까지 정확히).
    final storedJson = stored.toJson();
    for (final k in _serverOwnedKeys) {
      if (storedJson.containsKey(k)) {
        merged[k] = storedJson[k];
      } else {
        merged.remove(k);
      }
    }
    _mergeGiftDoubles(stored, merged, t);
    _mergeDailyClaims(stored, merged);
    // 저장 횟수(`rev`)는 **줄지 않는다** — 이 필드를 모르는 구버전 앱은 키 없이 올린다. 줄면 다른 기기가
    // 앱을 켤 때 동점 판정(`_localIsAhead`)이 서버의 새 세이브를 옛 것으로 본다.
    final clientRev = (merged['rev'] as num?)?.toInt() ?? 0;
    if (stored.saveRev > clientRev) merged['rev'] = stored.saveRev;
    // **줄어들 수 없는 기록**은 저장본과 합친다(2026-09-15). 이 필드를 모르는
    // 구버전 앱은 키 없이 올리고, 그러면 기본값(0·빈 집합)이 저장본을 덮어
    // 다른 기기에서 가 본 최고 난이도·도감 보스 수집이 사라진다.
    final clientTop = (merged['maxTierReached'] as num?)?.toInt() ?? 0;
    if (stored.maxTierReached > clientTop) {
      merged['maxTierReached'] = stored.maxTierReached;
    }
    if (stored.bossDex.isNotEmpty) {
      final clientBoss = ((merged['bossDex'] as List?) ?? const [])
          .map((e) => e.toString())
          .toSet();
      merged['bossDex'] = {...clientBoss, ...stored.bossDex}.toList();
    }

    // 골드 상식 상한.
    final clientGold = (merged['gold'] as num?)?.toInt() ?? stored.gold;
    // 무엇이 잘렸나 — 운영 요약(OpsMonitor)이 "누가 무엇을" 보여 주는 데 쓴다.
    final clampReasons = <String>[];
    if (clientGold - stored.gold > maxGain) {
      merged['gold'] = stored.gold + maxGain;
      clampReasons.add('gold');
    }

    // 젤리(프리미엄) 상식 상한 — 결제로 사는 재화라 급증을 막는다.
    final mats = merged['materials'];
    if (mats is Map) {
      final clientJelly =
          (mats['jelly'] as num?)?.toInt() ??
          stored.materialCount(MaterialKind.jelly);
      final storedJelly = stored.materialCount(MaterialKind.jelly);
      final jellyAllow =
          _jellySanityFloor + _dexJellyAllowance(stored, clientJson);
      if (clientJelly - storedJelly > jellyAllow) {
        mats['jelly'] = storedJelly + jellyAllow;
        clampReasons.add('jelly');
      }

      // 일반 재료도 급증을 막는다 — 여기가 비어 있던 탓에 조작 업로드가
      // 그대로 들어갔다. 감소는 검사하지 않는다(쓰는 건 자유).
      for (final k in _regularMaterials) {
        final client =
            (mats[k.key] as num?)?.toInt() ?? stored.materialCount(k);
        final have = stored.materialCount(k);
        final allow =
            _materialSanityFloor + exchange.materialsEach + hunt.materialsEach;
        if (client - have > allow) {
          mats[k.key] = have + allow;
          clampReasons.add('material:${k.key}');
        }
      }

      final clientFossil =
          (mats['fossil'] as num?)?.toInt() ??
          stored.materialCount(MaterialKind.fossil);
      final storedFossil = stored.materialCount(MaterialKind.fossil);
      // 심연 10층마다 첫 도달 화석(`clearAbyssFloor`).
      final every = config.run.abyss.milestoneEvery;
      final abyssFossil = every <= 0 || abyss.best <= stored.abyssBest
          ? 0
          : (abyss.best ~/ every - stored.abyssBest ~/ every) *
                config.run.abyss.milestoneFossil;
      final fairyCfg = config.fairy;
      final fairyDexFossil = fairyCfg == null || clientJson['fairy'] is! Map
          ? 0
          // ⚠️ 모르는 도감 칸을 **먼저 거른다** — 가짜 칸 100개로 마일스톤을 부풀리면 화석만 지급되고
          // 수령 기록은 _enforceFairy 에서 되돌려져 매 업로드 반복됐다(2026-10-01 점검).
          : fairyDexNewlyClaimed(
              stored.fairy,
              _fairyKnownKeysOnly(
                FairyState.fromJson(
                  Map<String, dynamic>.from(clientJson['fairy'] as Map),
                ),
                fairyCfg,
              ),
              fairyCfg,
            ).fold<int>(0, (a, m) => a + m.fossil);
      final fossilAllow =
          _maxFossilGain +
          _dexFossilAllowance(stored, clientJson) +
          abyssFossil +
          fairyDexFossil;
      if (clientFossil - storedFossil > fossilAllow) {
        mats['fossil'] = storedFossil + fossilAllow;
        clampReasons.add('fossil');
      }
    }
    merged['lastSeen'] = t.toIso8601String();
    merged['abyssUnlocked'] = abyss.unlocked;
    merged['inAbyss'] = abyss.inAbyss;
    merged['abyssFloor'] = abyss.floor;
    merged['abyssBest'] = abyss.best;
    merged['abyssBossBest'] = abyss.bossBest;
    if (abyss.week != null) merged['abyssWeek'] = abyss.week;
    if (abyss.floorAt != null) {
      merged['abyssFloorAt'] = abyss.floorAt!.toIso8601String();
    } else {
      merged.remove('abyssFloorAt');
    }
    if (abyss.clamped) clampReasons.add('abyss');

    final SaveGame parsed;
    try {
      parsed = SaveGame.fromJson(merged);
    } catch (_) {
      return const ActionResult.fail('bad_save');
    }

    // 닉네임 변경 요구는 **새 이름이 실제로 올라오면** 내린다.
    // 규칙 검사까지 하지 않는 이유: 앱이 이미 같은 `ChatRules` 로 막고,
    // 서버가 규칙을 두 벌로 들고 있으면 갈렸을 때 유저가 영영 못 벗어난다.
    if (stored.renameRequired) {
      final newName = (merged['nickname'] as String?)?.trim() ?? '';
      if (newName.isNotEmpty && newName != stored.nickname) {
        merged['renameRequired'] = false;
      }
    }

    // 채집함 상한 강제 — **세이브 비대화의 마지막 방어선**.
    //
    // 상한을 클라이언트에만 맡기면 구버전 앱·조작된 업로드가 곤충 수만 마리를
    // 그대로 올려 세이브가 10MB 를 넘고, 업로드마다 DB 가 타임아웃한다
    // (2026-07 실제 장애). 서버가 여기서 자르고 `clamped` 로 알려주면
    // 클라이언트가 잘린 세이브를 채택해 다음 업로드부터 정상 크기가 된다.
    var capped = enforceStorage(parsed);
    // 훈련 v2 — 이전(멱등, 앱 로드와 같은 함수) → 배분을 예산·칸 상한으로 → 결투석 급증.
    // 구버전(1.0.17, feat 19 미만) 업로드는 서버가 이전하지 않는다 — 1.0.18 앱이 켜질 때 그때까지의 투자로 옮긴다.
    final tv2 = _enforceTrainV2(
      stored,
      capped,
      migrate: ((incomingJson['feat'] as num?)?.toInt() ?? 0) >= 19,
    );
    if (tv2.clamped) clampReasons.add('train');
    capped = tv2.save;
    final skillCfg = config.skill;
    if (skillCfg != null) {
      final sk = _enforceSkills(stored, capped, clientJson, skillCfg);
      if (!identical(sk, capped)) clampReasons.add('skill');
      capped = sk;
    }
    final fairyCfg = config.fairy;
    if (fairyCfg != null) {
      // 재굴림 칸(서버 소유)은 **잘림 판정 전에** 저장본으로 맞춘다. 1.0.15 앱은 이 칸을 몰라 늘 비워 올려서,
      // 판정 안에서 되돌리면 매 업로드가 `clamped` → 세이브 왕복이 됐다(2026-10-04 호환 점검).
      final rr = _keepRerollFields(stored.fairy, capped.fairy);
      if (!identical(rr, capped.fairy)) {
        // 기기가 **서버와 다른 대기 결과**를 들고 있다(고르기 응답 유실 등) — 알려서 채택하게 한다.
        // 비워 올린 것(1.0.15 앱)은 알리지 않는다 — 알리면 매 업로드가 되튄다.
        if (capped.fairy.reroll != null &&
            capped.fairy.reroll != stored.fairy.reroll) {
          clampReasons.add('fairy');
        }
        capped = capped.copyWith(fairy: rr);
      }
      final fy = _enforceFairy(stored, capped, fairyCfg);
      if (!identical(fy, capped)) clampReasons.add('fairy');
      capped = fy;
    }
    if (capped.bugs.length != parsed.bugs.length ||
        capped.storageCapacity != parsed.storageCapacity ||
        capped.incubatorCapacity != parsed.incubatorCapacity ||
        // ⚠️ 캠페인 끝 접기(`_enforceCampaignEnd`)가 빠져 있었다
        // (2026-09-01 발견). 서버는 1000 으로 접는데 앱은 계속 1078 을 들고
        // 60초마다 다시 올린다 — 화면에도 접히지 않은 값이 그대로 보이고,
        // 서버는 매 업로드마다 같은 일을 반복한다.
        capped.stageNumber != parsed.stageNumber) {
      clampReasons.add('storage');
    }

    // 시즌 정산은 **서버가 확정한다**. 트로피는 서버 소유 필드라 앱이 혼자
    // 깎아 올려도 위에서 저장본 값으로 덮인다 — 그래서 앱만 리셋하던 시절엔
    // 주간 리셋이 아예 먹지 않았다(2026-08 버그).
    // 개편 전 세이브는 리그가 없다(-1) — **시즌 리셋 전 트로피**로 한 번 확정해 저장한다.
    // 리셋 뒤에 유도하면 트로피가 0 이라 모두 브론즈로 떨어진다(2026-09-29 리그 개편).
    if (capped.pvpLeague < 0) {
      capped = capped.copyWith(pvpLeague: pvpLeagueOf(stored, config.battle));
    }
    final settled = _settleSeason(stored, clientJson, capped, t);
    return ActionResult.ok(
      settled.save,
      extra: {
        'clamped': clampReasons.isNotEmpty,
        if (clampReasons.isNotEmpty) 'clampReasons': clampReasons,
        'season': settled.report != null,
        // 앱이 "시즌 종료" 다이얼로그를 그대로 띄울 수 있게 내역을 실어준다.
        if (settled.report != null) 'seasonReport': settled.report,
      },
    );
  }

  /// 훈련 v2 업로드 검사(design_training_v2.md §5·§6). 처리는 기기 권위라 위조를 완전히 막지는 못한다 —
  /// 결투 팀을 만들 때도 같은 함수로 한 번 더 자른다([trainingBonusOf]).
  ///
  /// 1. **이전** — 기록이 없는 곤충의 옛 부위 강화·옛 훈련 단계를 칸으로 옮긴다(`migrateTrainingV2`, 멱등).
  ///    [migrate] 가 거짓(1.0.17 업로드)이면 옮기지 않는다 — 서버가 먼저 굳히면 그 뒤 1.0.17 투자가 이전에 안 실린다.
  ///    그동안 결투는 옛 투자로 만든 가상 기록(`bugTrainOf`)으로 같은 값을 낸다.
  /// 2. **배분** — 칸 상한·예산(포텐셜·수련(돌파 상한으로 자름)·돌파 — 보너스는 2026-10-10 폐지)으로 자른다. 앱도 로드·저장마다 같은 함수를 돌려
  ///    보통은 여기서 바뀌는 게 없다(구버전 앱·조작 업로드만 걸린다).
  /// 3. **결투석 급증** — 증가가 (쓴 젤리로 살 수 있던 수 + 새 심연 마일스톤 × 개수 + 드롭 여유)를 넘으면 저장본 수로.
  ///
  /// [clamped] 는 2·3 에서 잘렸을 때만 참이다(이전은 정상 동작이라 알리지 않는다 — 알리면 1.0.17 기기가
  /// 업로드마다 세이브를 되받는다).
  ({SaveGame save, bool clamped}) _enforceTrainV2(
    SaveGame stored,
    SaveGame client, {
    bool migrate = true,
  }) {
    final tr = config.battle.training;
    final byId = {for (final sp in config.speciesList) sp.id: sp};
    var out = !migrate
        ? client
        : migrateTrainingV2(
            client,
            tr,
            speciesOf: (id) => byId[id],
            enhance: config.enhance,
          );
    final migrated = out;
    out = sanitizeTrainPoints(
      out,
      tr,
      speciesOf: (id) => byId[id],
      levelCapOf: config.pet.levelCap,
      enhance: config.enhance,
    );
    var clamped = !identical(out, migrated);

    int stones(SaveGame s) => s.duelStones.values.fold(0, (a, b) => a + b);
    final jellySpent = max(
      0,
      stored.materialCount(MaterialKind.jelly) -
          out.materialCount(MaterialKind.jelly),
    );
    final allow = duelStoneAllowance(
      tr.stones,
      jellySpent: jellySpent,
      abyssMilestones: abyssNewMilestones(stored, out),
    );
    if (stones(out) - stones(stored) > allow) {
      out = out.copyWith(duelStones: stored.duelStones);
      clamped = true;
    }
    return (save: out, clamped: clamped);
  }

  /// 봉투 능력치 — 강화만 아는 전력에 공격 [_saveBoundAttackMult] 배(펫·장비·버프가 빠진 것을 덮는다).
  /// 업로드 골드 상한·교환소·선물·일일보상 상한이 같은 능력치를 쓴다.
  CharacterStats _envelopeStats(SaveGame stored) {
    final bare = deriveStats(
      config.run,
      upgradeLevels: stored.upgradeLevels,
      characterLevel: stored.level,
      bugsCollected: stored.bugs.length,
    );
    return CharacterStats(
      attack: bare.attack * _saveBoundAttackMult,
      attackSpeed: bare.attackSpeed,
      rewardMultiplier: bare.rewardMultiplier,
      critChance: bare.critChance,
      critDamage: bare.critDamage,
      bossDamage: bare.bossDamage,
      maxHp: bare.maxHp,
      defense: bare.defense,
      hpRegen: bare.hpRegen,
      xpMultiplier: bare.xpMultiplier,
      bugFind: bare.bugFind,
      materialFind: bare.materialFind,
      evade: bare.evade,
      boostBonus: bare.boostBonus,
    );
  }

  /// 사냥 [minutes]분치 보상(선물·일일보상)의 **상한**(2026-10-08) — 앱은 `huntStatsOf` 로 계산한 금액을
  /// 보내거나 선물에 박아 두고, 서버는 넉넉한 봉투(효율 [_saveBoundEfficiency]·공격 [_saveBoundAttackMult])로
  /// 잰 값으로 자른다. 지금 자리와 **가 본 최고 난이도의 최종 사냥터** 중 큰 쪽 — 높은 난이도에서 받은 선물을
  /// 쉬움으로 내려가 열어도 잘리지 않게.
  ({int gold, int materialsEach}) _huntCap(SaveGame s, double minutes) {
    if (minutes <= 0) return (gold: 0, materialsEach: 0);
    final stats = _envelopeStats(s);
    ({int gold, int materialsEach}) at(int stage, int tier, int floor) =>
        huntMinutesReward(
          config.run,
          stats: stats,
          stage: stage,
          minutes: minutes,
          tier: tier,
          abyssFloor: floor,
          efficiency: _saveBoundEfficiency,
        );
    final here = at(s.stageNumber, s.difficultyTier, activeAbyssFloor(s));
    final top = at(
      config.run.zoneStartStage(config.run.zonesPerTier),
      s.topTier,
      activeAbyssFloor(s),
    );
    return (
      gold: max(here.gold, top.gold),
      materialsEach: max(here.materialsEach, top.materialsEach),
    );
  }

  /// 선물 [g] 를 상한으로 자른다 — 선물은 앱이 만들어 세이브에 올리므로 금액을 믿을 수 없다.
  /// 상한은 선물에 적힌 분이 아니라 **설정의 가장 큰 분**(`huntMinutes`)으로 잰다(분도 앱이 적는다).
  GiftMail _capGift(SaveGame s, GiftMail g) {
    final cfg = config.gift;
    if (cfg == null) return g;
    var maxMin = 0.0;
    var maxGold = 0;
    var maxMat = 0;
    for (final t in cfg.tiers) {
      maxMin = max(maxMin, t.huntMinutes);
      maxGold = max(maxGold, t.gold);
      maxMat = max(maxMat, max(t.chitin, max(t.mineral, t.sap)));
    }
    // 사냥 분치 선물이 없는 설정(구 데이터)이면 예전처럼 그대로 둔다.
    if (maxMin <= 0) return g;
    final cap = _huntCap(s, maxMin);
    final goldCap = max(maxGold, cap.gold);
    final matCap = max(maxMat, cap.materialsEach);
    if (g.gold <= goldCap &&
        g.chitin <= matCap &&
        g.mineral <= matCap &&
        g.sap <= matCap) {
      return g;
    }
    return g.capped(
      gold: min(g.gold, goldCap),
      chitin: min(g.chitin, matCap),
      mineral: min(g.mineral, matCap),
      sap: min(g.sap, matCap),
    );
  }

  /// 일일보상 수령 날짜는 **뒤로 가지 않는다**(슬롯마다 저장본과 늦은 쪽). 키를 지웠다 다시 적어
  /// [_huntRewardAllowance] 의 몫을 또 받는 것을 막는다. 날짜는 'yyyy-MM-dd' 라 문자열 비교가 곧 날짜 비교다.
  void _mergeDailyClaims(SaveGame stored, Map<String, dynamic> merged) {
    if (stored.dailyClaims.isEmpty) return;
    final raw = merged['dailyClaims'];
    final out = <String, String>{
      if (raw is Map)
        for (final e in raw.entries) '${e.key}': '${e.value}',
    };
    for (final e in stored.dailyClaims.entries) {
      final c = out[e.key];
      if (c == null || c.compareTo(e.value) < 0) out[e.key] = e.value;
    }
    merged['dailyClaims'] = out;
  }

  /// 깜짝선물·일일보상(사냥 분치) 허용치(2026-10-09 출시 전 점검). 둘 다 **기기에서** 받는다(솔로 루프는 기기 권위,
  /// 서버 `claimDaily`·선물 수령 경로는 앱이 쓰지 않는다). 금액이 사냥 1~5시간치라 60초 봉투로는 바로 잘려
  /// 받은 골드가 1~2분 뒤 되돌아갔다(쉬움 일일 5시간치 48% · 보통 26% 만 남음 — 재현). 이번 업로드에서 새로 받았을
  /// 수 있는 몫만큼 넉넉한 봉투([_huntCap])로 인정한다:
  ///  - 일일보상: `dailyClaims` 에서 날짜가 **앞으로 간** 슬롯마다(한 번 더 받기 `#2` 포함) 그 슬롯의 분치.
  ///    날짜는 저장본과 합칠 때 뒤로 가지 않는다([_mergeDailyClaims]) — 키를 지웠다 다시 적어 몫을 또 받지 못하게.
  ///  - 깜짝선물: 저장본에 있다 사라진 선물(최대 `maxActive`) + 업로드 사이에 생겼다 바로 받은 선물 1개. 후자는
  ///    **다음 선물 시각이 새로 잡힌 흔적**이 있을 때만 센다 — 앱은 예정 시각이 지나야 선물을 만들고 그때
  ///    다음 시각을 최소 간격 뒤로 잡는다(`maybeSpawnGift`). 기기 시계 차이는 2분까지 봐준다.
  ///    선물 하나 = 가장 큰 분치 × 최대 배수(2배 받기 2~4배).
  /// 위조로 늘릴 수 있는 것은 "받았다고 적기"뿐이고, 그 몫도 선물 간격·슬롯 수로 묶인다(다른 상식 상한과 같은 수준).
  ({int gold, int materialsEach}) _huntRewardAllowance(
    SaveGame stored,
    Map<String, dynamic> clientJson,
    DateTime t,
  ) {
    var gold = 0, each = 0;
    void add(({int gold, int materialsEach}) c, [int times = 1]) {
      gold = addCurrency(gold, c.gold * times);
      each = addCurrency(each, c.materialsEach * times);
    }

    final daily = config.daily;
    final claims = clientJson['dailyClaims'];
    if (daily != null && claims is Map) {
      for (final e in claims.entries) {
        final key = '${e.key}';
        final before = stored.dailyClaims[key];
        if (before != null && '${e.value}'.compareTo(before) <= 0) continue;
        final id = key.endsWith('#2') ? key.substring(0, key.length - 2) : key;
        final reward = daily.rewards.where((r) => r.id == id).firstOrNull;
        if (reward == null || reward.huntMinutes <= 0) continue;
        add(_huntCap(stored, reward.huntMinutes));
      }
    }
    final gift = config.gift;
    if (gift != null) {
      var maxMin = 0.0;
      for (final t in gift.tiers) {
        maxMin = max(maxMin, t.huntMinutes);
      }
      if (maxMin > 0) {
        final raw = clientJson['gifts'];
        final clientIds = <String>{
          if (raw is List)
            for (final g in raw)
              if (g is Map) '${g['id']}',
        };
        final gone = min(
          stored.gifts.where((g) => !clientIds.contains(g.id)).length,
          max(1, gift.maxActive),
        );
        const skew = Duration(minutes: 2);
        final rawNext = clientJson['nextGiftAt'];
        final clientNext = rawNext is String
            ? DateTime.tryParse(rawNext)?.toUtc()
            : null;
        final storedNext = stored.nextGiftAt;
        final due =
            storedNext == null || !t.isBefore(storedNext.subtract(skew));
        final rescheduled =
            clientNext != null &&
            (storedNext == null || clientNext.isAfter(storedNext)) &&
            !clientNext.isBefore(
              t.add(Duration(seconds: gift.intervalMinSec)).subtract(skew),
            );
        final fresh = due && rescheduled ? 1 : 0;
        final mult = max(1, max(gift.adMultiplier, gift.adMultiplierMax));
        add(_huntCap(stored, maxMin), (gone + fresh) * mult);
      }
    }
    return (gold: gold, materialsEach: each);
  }

  /// 교환소 허용치 — 저장본보다 줄어든 젤리 ÷ 교환 1회 젤리 = 교환 횟수로 보고, 골드·재료 각각
  /// 그 횟수만큼의 [exchangeOutput] 을 넉넉한 봉투로 잰다. 젤리를 다른 데 쓴 것도 교환으로 세지만
  /// (넉넉한 쪽으로 틀린다), 그만큼 젤리를 실제로 잃어야 하므로 위조 통로가 되지 않는다.
  ({int gold, int materialsEach}) _exchangeAllowance(
    SaveGame stored,
    Map<String, dynamic> clientJson, {
    required CharacterStats stats,
    required int stage,
    required int tier,
    required int abyssFloor,
  }) {
    final per = config.run.exchangeJellyPerTrade;
    final mats = clientJson['materials'];
    if (per <= 0 || mats is! Map) return (gold: 0, materialsEach: 0);
    final storedJelly = stored.materialCount(MaterialKind.jelly);
    final clientJelly = (mats['jelly'] as num?)?.toInt() ?? storedJelly;
    final trades = (storedJelly - clientJelly) ~/ per;
    if (trades <= 0) return (gold: 0, materialsEach: 0);
    return exchangeOutput(
      config.run,
      stats: stats,
      stage: stage,
      trades: trades,
      tier: tier,
      abyssFloor: abyssFloor,
      efficiency: _saveBoundEfficiency,
    );
  }

  /// 칸 수를 설정 상한(`pets.json` 의 `storageSlotsMax`·`incubatorSlotsMax`)으로,
  /// 보유 곤충을 칸 수로 자른다.
  ///
  /// 소유(덮어쓰기)가 아니라 **상한 강제**다 — 둘 다 젤리로 사는 편의 칸이라
  /// 상한만 지키면 경제·랭킹에 영향이 없다. 소유했다가 젤리로 산 슬롯이
  /// 사라지는 사고가 있었다.
  /// 캠페인 끝(로드맵 마지막 스테이지)을 넘은 스테이지를 접는다.
  ///
  /// 스테이지에 상한이 없던 시절(2026-08 이전) 세이브에는 1708 같은 값이
  /// 실제로 있다. 그 구간은 저항이 없어 의미가 없고, 지수 골드가 int64 를
  /// 넘겨 음수가 됐다(docs/design_difficulty_loop.md).
  ///
  /// ⚠️ 초과분을 **다음 회차로 환산하지 않는다.** 1708 → 보통 708 로 보내면
  /// 그 유저만 보통 난이도를 700스테이지 건너뛴다 — 회차의 의미가 첫 유저부터
  /// 무너진다. 끝(1000)으로 맞추고, 다음 회차는 본인이 1 부터 시작한다.
  ///
  /// ⚠️ 서버가 **앱보다 먼저** 이걸 갖고 있어야 한다. 앱만 먼저 나가면
  /// 구버전이 초과 스테이지를 계속 올려 보낸다.
  SaveGame _enforceCampaignEnd(SaveGame save) {
    final last = config.roadmap?.finalStage ?? 0;
    if (last <= 0) return save;
    if (save.stageNumber <= last) return save;
    return save.copyWith(stageNumber: last);
  }

  SaveGame enforceStorage(SaveGame save) {
    save = _enforceCampaignEnd(save);
    final max = config.pet.storageSlotsMax;
    final cap = save.storageCapacity > max ? max : save.storageCapacity;
    final incMax = config.pet.incubatorSlotsMax;
    final inc = save.incubatorCapacity > incMax
        ? incMax
        : save.incubatorCapacity;
    var out = (cap == save.storageCapacity && inc == save.incubatorCapacity)
        ? save
        : save.copyWith(storageCapacity: cap, incubatorCapacity: inc);
    // 모루 위 제련 결과도 상한을 강제한다. 조작 업로드가 수천 개를 실으면 세이브가 비대해진다 —
    // 곤충 3만 마리 13.6MB 사고(§2.1)와 같은 경로다. 최근 것부터 남긴다.
    // ⚠️ 상한은 **젤리로 넓힌 칸까지**다(앱 `_forgeCap` 과 같은 식, 최대 `stackExpandMax`). 예전엔 10 으로 잘라서,
    // 결투가 끝나 앱이 서버 세이브를 채택할 때마다 넓힌 칸의 장비가 사라졌다(2026-10-10 발견).
    final forge = config.forge;
    // (이 함수의 `max` 는 채집함 상한 지역 변수라 clamp 로 쓴다.)
    final stackCap = forge == null
        ? kMaxForgeStack
        : (kMaxForgeStack +
                  out.forgeStackBought.clamp(0, 1 << 20) *
                      forge.stackExpandStep)
              .clamp(
                kMaxForgeStack,
                forge.stackExpandMax < kMaxForgeStack
                    ? kMaxForgeStack
                    : forge.stackExpandMax,
              );
    if (out.forgeStack.length > stackCap) {
      out = out.copyWith(
        forgeStack: out.forgeStack.sublist(out.forgeStack.length - stackCap),
      );
    }
    return out.trimmedToStorage();
  }

  /// 주간 시즌 경계(KST 월 09:00)를 넘겼으면 **트로피를 소프트리셋**한다.
  ///
  /// 누가 보상을 주는가로 두 갈래다:
  ///  - **앱이 먼저 정산**(보통) — 앱이 시작할 때 보상·팝업을 처리하고
  ///    `seasonStartedAt` 을 새 경계로 올려 보낸다. 서버는 트로피만 깎는다.
  ///  - **서버가 먼저**(앱을 켜둔 채 경계를 넘김) — 앱은 아직 모르므로 보상까지
  ///    서버가 지급하고 `season: true` 로 알린다. 앱이 그 세이브를 채택한다.
  /// 어느 쪽이든 **보상은 한 번**이고, 저장본의 `seasonStartedAt` 이 경계로
  /// 올라가므로 다음 업로드에서 다시 깎이지 않는다.
  ({SaveGame save, Map<String, dynamic>? report}) _settleSeason(
    SaveGame stored,
    Map<String, dynamic> clientJson,
    SaveGame merged,
    DateTime t,
  ) {
    final cfg = config.battle;
    final curStart = seasonStartAt(t, cfg);
    final clientStart = DateTime.tryParse(
      clientJson['seasonStartedAt'] as String? ?? '',
    )?.toUtc();

    // 아직 경계를 안 넘었으면 **미래 날짜만** 막는다. 앞당겨 적어두면
    // 서버가 "이미 정산했다"고 착각해 리셋을 영영 건너뛴다.
    if (stored.seasonStartedAt == null ||
        !stored.seasonStartedAt!.isBefore(curStart)) {
      final safe = (clientStart == null || clientStart.isAfter(curStart))
          ? curStart
          : clientStart;
      return (
        save: merged.seasonStartedAt == safe
            ? merged
            : merged.copyWith(seasonStartedAt: safe),
        report: null,
      );
    }

    final reset = cfg.seasonResetTrophies(stored.pvpTrophies);
    var out = merged.copyWith(
      pvpTrophies: reset,
      seasonPeakTrophies: reset,
      seasonStartedAt: curStart,
    );

    // 앱이 이미 정산했으면(경계를 올려 보냄) 보상은 앱이 줬다 — 두 번 주지 않는다.
    final appPaid = clientStart != null && !clientStart.isBefore(curStart);
    if (appPaid) return (save: out, report: null);

    // **끝나는 순간의 등급**으로 준다(앱 `_applySeason` 과 같은 규칙).
    // 최고 기록으로 주던 시절이 있었는데, 화면에 뜨는 "지금 등급"과 실제 보상이
    // 달라 설명할 수가 없었다(2026-08-18 변경).
    final endTrophies = stored.pvpTrophies;
    // 리그 소속으로 준다(앱 `_applySeason` 과 같은 규칙, 2026-09-29 리그 개편).
    final rw = cfg.seasonRewardAt(pvpLeagueOf(stored, cfg));
    if (rw.gold > 0 || rw.jelly > 0) {
      final mats = Map<MaterialKind, int>.from(out.materials);
      mats[MaterialKind.jelly] = (mats[MaterialKind.jelly] ?? 0) + rw.jelly;
      out = out.copyWith(gold: addCurrency(out.gold, rw.gold), materials: mats);
    }
    return (
      save: out,
      report: {
        'endTrophies': endTrophies,
        // 구버전 앱은 `peakTrophies` 만 읽는다 — 당분간 둘 다 보낸다.
        'peakTrophies': endTrophies,
        'rewardGold': rw.gold,
        'rewardJelly': rw.jelly,
        'fromTrophies': stored.pvpTrophies,
        'toTrophies': reset,
      },
    );
  }

  /// 최초 이관(부트스트랩) 세이브를 정화한다.
  ///
  /// 부트스트랩은 저장본이 없어 `mergeSave` 의 보호가 안 걸린다. 그 틈으로
  /// 새 익명 계정이 **트로피·IAP 지급물을 위조**해 올릴 수 있어(랭킹 도배·무료
  /// 결제 혜택), 서버가 소유하는 필드를 **초기값으로 리셋**한다. 솔로 진행
  /// (골드·곤충·업그레이드)은 그대로 둔다 — 기기 권위라 편집을 수용하는 범위다.
  /// 기기 접속 표식으로 쓸 수 있는 값인가 — 앱이 켤 때마다 만드는 무작위 문자열.
  static bool validSession(Object? v) =>
      v is String && RegExp(r'^[A-Za-z0-9_-]{8,64}$').hasMatch(v);

  /// 이 업로드가 **다른 기기에 밀려난 기기**에서 왔는가(2026-10-03, 1.0.16).
  ///
  /// 거절하는 경우는 하나뿐이다: 앱이 표식을 보냈고, 저장본에도 표식이 있고, 둘이 다르다.
  ///  - 표식을 안 보낸 업로드 = 1.0.15 이하 앱. 지금처럼 통과시킨다(막으면 구버전이 저장을 못 한다).
  ///  - 저장본에 표식이 없다 = 아직 아무도 쥐지 않았다. 통과시키고 [adoptSession] 이 채운다.
  static bool sessionTaken(SaveGame stored, Object? session) =>
      validSession(session) &&
      stored.activeSession.isNotEmpty &&
      stored.activeSession != session;

  /// 비어 있는 표식을 이 업로드의 표식으로 채운다(첫 업로드가 곧 접속).
  static SaveGame adoptSession(SaveGame save, Object? session) =>
      save.activeSession.isEmpty && validSession(session)
      ? save.copyWith(activeSession: session as String)
      : save;

  Map<String, dynamic> sanitizeBootstrap(Map<String, dynamic> clientJson) {
    final fresh = SaveGame.initial(createdAt: now().toUtc()).toJson();
    final out = Map<String, dynamic>.from(clientJson);
    for (final k in _serverOwnedKeys) {
      if (fresh.containsKey(k)) {
        out[k] = fresh[k];
      } else {
        out.remove(k);
      }
    }
    return out;
  }

  /// 편성 검증 → 전투 유닛 목록. 실패 시 [error] 에 사유.
  ///
  /// 자동/수동 전투가 **같은 기준**을 쓰도록 분리했다 —
  /// 한쪽만 느슨하면 그쪽으로 우회한다.
  ({List<BattleBug> team, String? error}) validateTeam(
    SaveGame save,
    List<String> bugIds, {
    required Map<String, Species> speciesById,
    required PetConfig petConfig,
    EnhanceConfig? enhance,

    /// 부상 곤충을 허용한다 — **수동 세션의 step/finish 전용.**
    ///
    /// 수동 전투는 시작할 때 팀 전체에 부상을 선차감한다(중도 이탈 = KO 와
    /// 같은 대가). 그 상태가 주기 업로드로 서버 세이브에 실리므로, 진행 중
    /// 재검증이 부상을 거부하면 **자기 선차감에 자기가 걸려** 스텝이 죽는다.
    /// 시작 시 검증은 기본값(false)으로 진짜 부상을 걸러낸다.
    bool allowInjured = false,
  }) {
    if (bugIds.isEmpty) return (team: const [], error: 'empty_team');
    final t = now().toUtc();
    final byId = {for (final b in save.bugs) b.id: b};
    final team = <BattleBug>[];
    final tr = config.battle.training;

    for (final id in bugIds) {
      final bug = byId[id];
      if (bug == null) return (team: const [], error: 'bug_not_owned');
      if (!allowInjured && save.isInjured(bug.id, t)) {
        return (team: const [], error: 'bug_injured');
      }
      final sp = speciesById[bug.speciesId];
      if (sp == null) return (team: const [], error: 'unknown_species');
      if (effectiveStage(bug.stage, bug.stageSince, t, petConfig) !=
          LifeStage.adult) {
        return (team: const [], error: 'not_adult');
      }
      // **스탯 상한 검증** — 드롭 롤이 기기 권위라 세이브 편집으로 위조한
      // 5성 만렙 개체가 올라올 수 있다. 소유만 보면 그 곤충으로 트로피를
      // 쌓아 랭킹이 오염된다(⚠️ 2026-08-09 확인된 구멍). 정상 플레이로
      // 불가능한 값이면 편성 자체를 거부한다.
      final forged = bug.integrityError(
        sp,
        levelCap: petConfig.levelCap(bug.breakthroughTier),
        maxBreakthroughTier: petConfig.maxTier,
      );
      if (forged != null) return (team: const [], error: 'bug_forged:$forged');
      // 훈련 v2(2026-10-08) — 배분을 **예산·칸 상한으로 잘라서** 입힌다(세이브를 고쳐 칸에 99를 적어도
      // 소용없다). 부위 강화는 훈련 포인트로 이전돼 `buildBattleBug` 가 더 이상 읽지 않는다.
      final tb = trainingBonusOf(
        save,
        bug,
        sp,
        tr,
        levelCap: petConfig.levelCap(bug.breakthroughTier),
        enhance: enhance,
      );
      team.add(
        buildBattleBug(
          bug: bug,
          species: sp,
          locale: 'ko',
          trainAtkMult: tb.atkMult,
          trainDefMult: tb.defMult,
          trainHpMult: tb.hpMult,
          trainSpdMult: tb.spdMult,
          // 혈통 특성(§2.5)도 전투에 실린다 — 앱과 **같은 배율**이어야 한다.
          //
          // ⚠️ 특성 자체는 위조를 막을 수단이 없다(곤충 롤이 기기 권위).
          // 다만 위조 가능한 다른 값보다 효과가 작고, `integrityError` 가
          // 나머지 상한을 이미 막는다. 서버 발급 전환 시 함께 봉인한다.
          traitAtkBonus: petConfig.traitBattleAtk(bug.trait),
          variantAtkBonus: petConfig.variantBattleAtk(bug.variant),
          variantHpBonus: petConfig.variantBattleHp(bug.variant),
          traitHpBonus: petConfig.traitBattleHp(bug.trait),
        ),
      );
    }
    return (team: team, error: null);
  }

  /// 전투 결과 → 보상·트로피·부상 반영. 자동/수동 공용.
  ActionResult applyBattleOutcome(
    SaveGame save, {
    required BattleResult result,
    required List<BattleBug> myTeam,
    required double rewardMult,
    required Map<String, Species> speciesById,
    required PetConfig petConfig,

    /// 보상 계산 기준 트로피. 수동 전투는 시작할 때 패배분을 미리 깎으므로
    /// 현재 값으로 계산하면 보상이 낮게 잡힌다. null 이면 현재 값.
    int? trophiesAtStart,

    /// 시작할 때 이미 반영한 트로피 변동(음수). 결착에서 **차액만** 더한다.
    int trophyPrepaid = 0,

    /// KO 되지 않은 팀원의 부상을 **지운다** — 수동 전투 결착 전용.
    ///
    /// 수동은 시작할 때 팀 전체에 부상을 선차감하므로, 끝까지 살아남은
    /// 곤충은 여기서 되돌려야 한다. 시작 검증이 진짜 부상을 거부하므로
    /// 이 시점의 팀원 부상은 전부 선차감분이다 — 지워도 잃는 게 없다.
    bool healSurvivors = false,
  }) {
    final t = now().toUtc();
    final rw = pvpReward(
      won: result.outcome == BattleOutcome.teamA,
      draw: result.outcome == BattleOutcome.draw,
      trophies: trophiesAtStart ?? save.pvpTrophies,
      cfg: config.battle,
      rewardMult: rewardMult,
    );

    final byId = {for (final b in save.bugs) b.id: b};
    final injured = Map<String, DateTime>.from(save.injured);
    if (healSurvivors) {
      final koed = koedTeamAIds(myTeam, result.events).toSet();
      for (final b in myTeam) {
        if (!koed.contains(b.id)) injured.remove(b.id);
      }
    }
    for (final koedId in koedTeamAIds(myTeam, result.events)) {
      final bug = byId[koedId];
      if (bug == null) continue;
      final sp = speciesById[bug.speciesId];
      if (sp == null) continue;
      final until = t.add(
        Duration(seconds: petConfig.injuryDuration(sp.grade)),
      );
      final prev = injured[koedId];
      injured[koedId] = (prev != null && prev.isAfter(until)) ? prev : until;
    }

    // 선차감분을 빼고 **차액만** 반영한다. 두 번 깎으면 이겨도 손해다.
    final newTrophies = (save.pvpTrophies + rw.trophyDelta - trophyPrepaid)
        .clamp(0, 1 << 30);
    return ActionResult.ok(
      save.copyWith(
        gold: addCurrency(save.gold, rw.gold),
        pvpTrophies: newTrophies,
        seasonPeakTrophies: newTrophies > save.seasonPeakTrophies
            ? newTrophies
            : save.seasonPeakTrophies,
        injured: injured,
      ),
      extra: {
        'outcome': result.outcome.name,
        'gold': rw.gold,
        'trophyDelta': rw.trophyDelta,
        'rounds': result.rounds,
        'teamAHpPct': result.teamAHpPct,
        'teamBHpPct': result.teamBHpPct,
      },
    );
  }

  /// 자동 전투 — 서버가 시뮬레이션하고 결과를 확정한다.
  ///
  /// 클라이언트는 "누구와 싸우겠다"만 보낸다. 스탯은 **서버 세이브의 개체**에서
  /// 가져오고 시드도 서버가 정한다 — 앱과 같은 `core_battle` 코드를 쓰므로
  /// 결과가 어긋나지 않는다(그래서 서버를 Dart 로 만들었다).
  ActionResult runBattle(
    SaveGame save, {
    required List<String> myTeamBugIds,
    required List<BattleBug> foeTeam,
    required Element location,
    required int seed,
    required double rewardMult,
    required Map<String, Species> speciesById,
    required PetConfig petConfig,
    EnhanceConfig? enhance,
  }) {
    final built = validateTeam(
      save,
      myTeamBugIds,
      speciesById: speciesById,
      petConfig: petConfig,
      enhance: enhance,
    );
    if (built.error != null) return ActionResult.fail(built.error);
    if (foeTeam.isEmpty) return const ActionResult.fail('empty_foe');

    // 티켓 소모는 **전투 확정과 같은 액션 안에서** 한다. 분리하면 "티켓만 깎이고
    // 전투는 실패" 또는 그 반대가 생긴다.
    final ticketed = consumePvpTicket(save);
    if (!ticketed.isOk) return ticketed;
    final paid = ticketed.save!;

    final result = simulate(
      seed,
      built.team,
      foeTeam,
      location: location,
      locationBonus: config.battle.locationAffinityBonus,
    );

    final applied = applyBattleOutcome(
      paid,
      result: result,
      myTeam: built.team,
      rewardMult: rewardMult,
      speciesById: speciesById,
      petConfig: petConfig,
    );
    if (!applied.isOk) return applied;
    return ActionResult.ok(
      applied.save!,
      // 클라이언트가 같은 전개를 재생하도록 시드를 돌려준다(결정론).
      extra: {...ticketed.extra, ...applied.extra, 'seed': seed},
    );
  }

  // ── 결투(곤충 배틀 스타디움, 2026-09-28) ─────────────────────────────
  //
  // 1:1 · 3판 2선승 · 물리 경기장(docs/design_duel.md). 옛 스탠스 전투(`runBattle`·수동 세션)는
  // 1.0.13 이하 앱이 강제 업데이트될 때까지 그대로 둔다 — 대회는 계속 옛 엔진이다.

  /// 결투 수치(`battle.json → duel`).
  DuelParams get duelParams => DuelParams.fromJson(
    clutchTestUser
        ? {...config.battle.duelJson, 'clutchEnabled': true}
        : config.battle.duelJson,
  );

  /// 결투 편성 검증 → 출전 순서대로 결투 유닛. 검증 기준은 [validateTeam] 과 **같다**
  /// (보유·부상·성충·위조) — 한쪽만 느슨하면 그쪽으로 우회한다.
  ({List<DuelBug> team, String? error}) validateDuelTeam(
    SaveGame save,
    List<String> bugIds, {
    required Map<String, Species> speciesById,
    required PetConfig petConfig,
    EnhanceConfig? enhance,
    bool allowInjured = false,
    int? teamSize,
  }) {
    final p = duelParams;
    // 결투는 3마리(bestOf), 왕충 선발대회는 1마리(teamSize: 1).
    if (bugIds.length != (teamSize ?? p.bestOf)) {
      return (team: const [], error: 'team_size');
    }
    if (bugIds.toSet().length != bugIds.length) {
      return (team: const [], error: 'duplicate_bug');
    }
    final v = validateTeam(
      save,
      bugIds,
      speciesById: speciesById,
      petConfig: petConfig,
      enhance: enhance,
      allowInjured: allowInjured,
    );
    if (v.error != null) return (team: const [], error: v.error);
    // 훈련 중인 곤충은 출정할 수 없다(방어는 선다 — 자기가 훈련 중이어도 도전은 받는다).
    // 훈련 v2 — 포인트 찍는 중 · 다시 찍기 대기 중.
    final at = now();
    if (!allowInjured && bugIds.any((id) => trainBusy(save, id, at))) {
      return (team: const [], error: 'bug_training');
    }
    final byId = {for (final b in save.bugs) b.id: b};
    final tr = config.battle.training;
    return (
      team: [
        for (var i = 0; i < bugIds.length; i++)
          () {
            final bug = byId[bugIds[i]]!;
            final sp = speciesById[bug.speciesId]!;
            // 공격·방어·체력·속도는 [validateTeam] 이 이미 입혔다(같은 [trainingBonusOf] — 예산·칸 상한으로 자름).
            // 여기는 결투 전용 칸(회피·치명·회복력·체급·밀어내기 힘·주특기 기술·근성)만.
            final t = trainingBonusOf(
              save,
              bug,
              sp,
              tr,
              levelCap: petConfig.levelCap(bug.breakthroughTier),
              enhance: enhance,
            );
            return DuelBug.fromBattleBug(
              v.team[i],
              speciesId: bug.speciesId,
              sizeMm: bug.sizeMm,
              specialty: sp.specialty,
              // 크기는 결투에서 무게로만(2026-10-08 사장님 확정) — 스탯에 구워진 사이즈 배율을 알려 주면
              // 엔진이 `sizeStatExp` 로 덜어낸다. 방치 런·도감은 그대로. 앱 `duelBugFor` 와 같은 값.
              sizeStatMult: bug.statMultiplier(sp),
            ).withTraining(
              evade: t.evade,
              crit: t.crit,
              recovery: t.recovery,
              massMult: t.massMult,
              pushMult: t.pushMult,
              tech: t.tech,
              grit: t.grit,
            );
          }(),
      ],
      error: null,
    );
  }

  /// 상대 유저의 **세이브에서** 방어팀을 만든다(`pvpDefenseIds` 순서).
  ///
  /// 예전엔 앱이 계산해 `defenders` 에 올린 스탯을 그대로 믿었다(방어 스탯 위조 구멍).
  /// 방어 순서가 없거나 무효하면 null — 호출자가 옛 `defenders` 행으로 떨어진다.
  /// 방어 측 부상은 막지 않는다(자기가 결투하느라 다친 곤충도 방어는 선다).
  List<DuelBug>? defenderDuelTeam(
    SaveGame opponent, {
    required Map<String, Species> speciesById,
    required PetConfig petConfig,
    EnhanceConfig? enhance,
  }) {
    final ids = opponent.pvpDefenseIds;
    if (ids.length != duelParams.bestOf) return null;
    final v = validateDuelTeam(
      opponent,
      ids,
      speciesById: speciesById,
      petConfig: petConfig,
      enhance: enhance,
      allowInjured: true,
    );
    return v.error == null ? v.team : null;
  }

  /// 야생 상대 — [buildWildTeam] 과 같은 규칙(내 상위 3마리 평균 × 티어 배율)에 사이즈·주특기를 붙인다.
  /// 야생은 사이즈 롤이 없으니 **그 종의 중간 크기**로 둔다.
  ({List<DuelBug> team, List<String> speciesIds, ScoutTier tier})?
  buildWildDuelTeam(
    SaveGame save, {
    required String tierId,
    required Map<String, Species> speciesById,
    required PetConfig petConfig,
    EnhanceConfig? enhance,
    Random? rng,
    String locale = 'ko',
  }) {
    final w = buildWildTeam(
      save,
      tierId: tierId,
      speciesById: speciesById,
      petConfig: petConfig,
      enhance: enhance,
      rng: rng,
      locale: locale,
    );
    if (w == null) return null;
    final team = <DuelBug>[];
    for (var i = 0; i < w.team.length; i++) {
      final sp = speciesById[w.speciesIds[i]];
      if (sp == null) return null;
      final mid = (sp.sizeMinMm + sp.sizeMaxMm) / 2;
      team.add(
        DuelBug.fromBattleBug(
          w.team[i],
          speciesId: sp.id,
          sizeMm: mid,
          specialty: sp.specialty,
          // 야생 스탯은 내 곤충(사이즈 배율이 구워진) 평균에서 온다 — 중간 크기 배율로 같이 덜어낸다.
          sizeStatMult: sizeToStatMultiplier(mid, sp.sizeMinMm, sp.sizeMaxMm),
        ),
      );
    }
    return (team: team, speciesIds: w.speciesIds, tier: w.tier);
  }

  /// 결투 시작 — 티켓 1장 + **트로피·부상 선차감**(옛 수동 전투와 같은 규칙).
  ///
  /// 판마다 앱이 던지기를 보내므로 결착까지 시간이 걸린다. 지고 있을 때 앱을 끄면
  /// 트로피·부상을 피하는 꼼수를 막으려고 **먼저 지고 들어간다**. 결착에서 차액을 돌려준다.
  /// extra 의 `trophyPrepaid` 는 **실제로 깎인 양**이다(0 근처에서 잘린 만큼 되돌려주면 공짜 트로피).
  ActionResult startDuel(
    SaveGame save, {
    required List<String> myTeamBugIds,
    required double rewardMult,
    required Map<String, Species> speciesById,
    required PetConfig petConfig,
    int? winPoints,
  }) {
    final ticketed = consumePvpTicket(save);
    if (!ticketed.isOk) return ticketed;
    final start = ticketed.save!;
    // 승리 점수 방식(2026-09-29)은 **지면 0점**이라 미리 깎을 트로피가 없다.
    final prepaid = winPoints != null
        ? 0
        : pvpReward(
            won: false,
            draw: false,
            trophies: start.pvpTrophies,
            cfg: config.battle,
            rewardMult: rewardMult,
          ).trophyDelta;
    final t = now().toUtc();
    final injured = Map<String, DateTime>.from(start.injured);
    final byId = {for (final b in start.bugs) b.id: b};
    for (final id in myTeamBugIds) {
      final sp = speciesById[byId[id]?.speciesId];
      if (sp == null) continue;
      injured[id] = t.add(
        Duration(seconds: petConfig.injuryDuration(sp.grade)),
      );
    }
    final paid = start.copyWith(
      pvpTrophies: (start.pvpTrophies + prepaid).clamp(0, 1 << 30),
      injured: injured,
    );
    return ActionResult.ok(
      paid,
      extra: {
        ...ticketed.extra,
        'trophiesAtStart': start.pvpTrophies,
        'trophyPrepaid': paid.pvpTrophies - start.pvpTrophies,
      },
    );
  }

  /// 결투 결과 반영 — 보상·트로피·부상. 세션·자동 공용.
  ///
  /// 부상은 **진 판의 곤충**만. [healOthers] 면 나머지(이긴 곤충·안 뛴 곤충)의 선차감 부상을 지운다.
  ActionResult applyDuelOutcome(
    SaveGame save, {
    required bool won,
    required List<String> teamBugIds,
    required List<String> lostBugIds,
    required double rewardMult,
    required Map<String, Species> speciesById,
    required PetConfig petConfig,
    int? trophiesAtStart,
    int trophyPrepaid = 0,
    bool healOthers = false,
    int? winPoints,
    Map<String, dynamic> extra = const {},
  }) {
    final base = pvpReward(
      won: won,
      draw: false,
      trophies: trophiesAtStart ?? save.pvpTrophies,
      cfg: config.battle,
      rewardMult: rewardMult,
    );
    // 승리 점수 방식: 이기면 후보의 점수, 지면 0(골드는 그대로 공식).
    final rw = winPoints == null
        ? base
        : (gold: base.gold, trophyDelta: won ? winPoints : 0);
    final t = now().toUtc();
    final injured = Map<String, DateTime>.from(save.injured);
    final byId = {for (final b in save.bugs) b.id: b};
    final lost = lostBugIds.toSet();
    for (final id in teamBugIds) {
      if (lost.contains(id)) {
        final sp = speciesById[byId[id]?.speciesId];
        if (sp == null) continue;
        final until = t.add(
          Duration(seconds: petConfig.injuryDuration(sp.grade)),
        );
        final prev = injured[id];
        injured[id] = prev != null && prev.isAfter(until) ? prev : until;
      } else if (healOthers) {
        injured.remove(id);
      }
    }
    // 선차감분을 빼고 **차액만** 반영한다. 두 번 깎으면 이겨도 손해다.
    final trophies = (save.pvpTrophies + rw.trophyDelta - trophyPrepaid).clamp(
      0,
      1 << 30,
    );
    return ActionResult.ok(
      save.copyWith(
        gold: addCurrency(save.gold, rw.gold),
        pvpTrophies: trophies,
        seasonPeakTrophies: trophies > save.seasonPeakTrophies
            ? trophies
            : save.seasonPeakTrophies,
        injured: injured,
      ),
      extra: {
        ...extra,
        'outcome': won ? BattleOutcome.teamA.name : BattleOutcome.teamB.name,
        'gold': rw.gold,
        'trophyDelta': rw.trophyDelta,
      },
    );
  }

  /// 세션의 다음 판을 던진다. 결착이면 보상까지 반영한다.
  ///
  /// 내 팀은 **매 판 세이브에서 다시 검증**한다(시작 뒤 곤충을 분해·합성했으면 거부).
  /// 시작 때 선차감한 부상은 허용한다(자기 선차감에 자기가 걸리지 않게).
  ///
  /// [clutch] = 앱이 탭 반격을 안다(1.0.18+). 그러면 내 곤충 위기에서 판이 멈추고(`clutch` 를 돌려준다)
  /// `/duel/clutch` 로 점수를 받아 이어 간다. false(구버전 앱)면 자동 점수로 끝까지 — 멈춘 판을 받지 않는다.
  ({ActionResult result, DuelSession? session}) duelThrow(
    SaveGame save,
    DuelSession session, {
    required double launch,
    required Map<String, Species> speciesById,
    required PetConfig petConfig,
    EnhanceConfig? enhance,
    bool clutch = false,
  }) {
    if (session.finished) {
      return (
        result: const ActionResult.fail('session_finished'),
        session: null,
      );
    }
    // 위기에서 멈춘 판이 있으면 그 점수부터(`/duel/clutch`) — 다음 판을 던져 건너뛰지 못하게.
    if (session.clutchPending) {
      return (
        result: const ActionResult.fail('clutch_pending', status: 409),
        session: null,
      );
    }
    final q = launch.isFinite
        ? launch.clamp(0.0, 1.0).toDouble()
        : duelParams.launchAuto;
    return _duelPlayBout(
      save,
      session,
      launch: q,
      clutchScores: clutch ? const <double>[] : null,
      speciesById: speciesById,
      petConfig: petConfig,
      enhance: enhance,
    );
  }

  /// 탭 반격 점수 — 멈춘 위기([DuelSession.pendingIndex])에 [score](0~1)를 넣고 **같은 seed·같은 던지기 값으로
  /// 처음부터 다시 계산**해 다음 위기 또는 판 끝까지. [index] 가 멈춘 위기 번호와 다르면 거부
  /// (같은 위기에 두 번 넣거나 앞질러 넣지 못하게). ⚠️ 점수는 앱이 보낸다 — 조작 앱은 늘 만점(설계 §4).
  ({ActionResult result, DuelSession? session}) duelClutch(
    SaveGame save,
    DuelSession session, {
    required int index,
    required double score,
    required Map<String, Species> speciesById,
    required PetConfig petConfig,
    EnhanceConfig? enhance,
  }) {
    if (session.finished) {
      return (
        result: const ActionResult.fail('session_finished'),
        session: null,
      );
    }
    if (!session.clutchPending) {
      return (
        result: const ActionResult.fail('no_clutch', status: 409),
        session: null,
      );
    }
    if (index != session.pendingIndex) {
      return (
        result: const ActionResult.fail('clutch_index', status: 409),
        session: null,
      );
    }
    final sc = score.isFinite ? score.clamp(0.0, 1.0).toDouble() : 0.0;
    return _duelPlayBout(
      save,
      session,
      launch: session.pendingLaunch!,
      clutchScores: [...?session.clutchScores, sc],
      speciesById: speciesById,
      petConfig: petConfig,
      enhance: enhance,
    );
  }

  /// 세션의 다음 판(또는 멈춘 판)을 [launch]·[clutchScores] 로 계산한다. 위기에서 멈추면 판을 넘기지 않고
  /// 세션에 점수 목록·던지기 값을 남긴다. 끝나면 판을 넘기고, 경기가 끝나면 보상까지.
  ({ActionResult result, DuelSession? session}) _duelPlayBout(
    SaveGame save,
    DuelSession session, {
    required double launch,
    required List<double>? clutchScores,
    required Map<String, Species> speciesById,
    required PetConfig petConfig,
    EnhanceConfig? enhance,
  }) {
    final p = duelParams;
    final i = session.nextBout;
    // 승자 연속 — 진 쪽만 다음 곤충으로 바뀐다(내 곤충 = B 가 이긴 판 수번째).
    final ia = session.winsB, ib = session.winsA;
    if (ia >= session.myTeamBugIds.length || ib >= session.foe.length) {
      return (result: const ActionResult.fail('no_bout'), session: null);
    }
    final mine = validateDuelTeam(
      save,
      session.myTeamBugIds,
      speciesById: speciesById,
      petConfig: petConfig,
      enhance: enhance,
      allowInjured: true,
    );
    if (mine.error != null) {
      return (result: ActionResult.fail(mine.error), session: null);
    }
    final q = launch;
    final bout = simulateBout(
      seed: duelBoutSeed(session.seed, i),
      a: mine.team[ia],
      b: session.foe[ib],
      params: p,
      launchA: q,
      hpA: session.hpA,
      hpB: session.hpB,
      clutchScores: clutchScores,
    );
    final stop = bout.pending;
    if (stop != null) {
      // 내 곤충 위기 — 판을 넘기지 않는다. 앱은 여기까지 재생하고 탭 게이지를 띄운다.
      return (
        result: ActionResult.ok(
          save,
          extra: {
            'index': i,
            'ia': ia,
            'ib': ib,
            'bout': bout.toJson(),
            'winsA': session.winsA,
            'winsB': session.winsB,
            'done': false,
            'clutch': duelClutchJson(stop, i),
          },
        ),
        session: session.copyWith(
          clutchScores: clutchScores ?? const [],
          pendingLaunch: q,
          pendingIndex: stop.index,
        ),
      );
    }
    final aWon = bout.winner == 0;
    var next = session.copyWith(
      clearClutch: true,
      winners: [...session.winners, bout.winner],
      launches: [...session.launches, q],
      hpA: aWon ? duelCarryHp(bout.hpPctA, mine.team[ia], p) : 1.0,
      hpB: aWon ? 1.0 : duelCarryHp(bout.hpPctB, session.foe[ib], p),
    );
    final done =
        next.winsA >= session.foe.length ||
        next.winsB >= session.myTeamBugIds.length;
    final extra = <String, dynamic>{
      'index': i,
      'ia': ia,
      'ib': ib,
      'bout': bout.toJson(),
      'winsA': next.winsA,
      'winsB': next.winsB,
      'done': done,
    };
    if (!done)
      return (result: ActionResult.ok(save, extra: extra), session: next);

    next = next.copyWith(finished: true);
    final applied = applyDuelOutcome(
      save,
      won: next.winsA > next.winsB,
      teamBugIds: next.myTeamBugIds,
      // 쓰러진 내 곤충 = 앞에서부터 B 가 이긴 판 수만큼. 안 나간 곤충은 부상 없음.
      lostBugIds: [
        for (var j = 0; j < next.winsB && j < next.myTeamBugIds.length; j++)
          next.myTeamBugIds[j],
      ],
      rewardMult: next.rewardMult,
      speciesById: speciesById,
      petConfig: petConfig,
      trophiesAtStart: next.trophiesAtStart,
      trophyPrepaid: next.trophyPrepaid,
      healOthers: true,
      winPoints: next.winPoints,
      extra: extra,
    );
    return (result: applied, session: next);
  }

  /// 경과시간만큼 방치 수입을 정산한다.
  ///
  /// **클라이언트가 "얼마 벌었다"고 보고하지 않는다.** 서버가 `lastSeen` 부터
  /// 지금까지를 직접 계산한다. 방치 수입은 (스탯, 스테이지, 경과시간)의
  /// 결정론적 함수이므로 서버가 정확히 재현할 수 있다.
  ///
  /// 이 게임엔 **수동 탭 공격이 없다**(자동 전투만). 그래서 클라이언트가
  /// 보고할 것이 아예 없고, 탭 상한 같은 방어도 필요 없다.
  ActionResult sync(SaveGame save) {
    final t = now().toUtc();
    final elapsed = t.difference(save.lastSeen);
    if (elapsed.isNegative) {
      // 기기 시계가 과거로 조작된 경우 — 수입 없이 시각만 맞춘다.
      return ActionResult.ok(save.copyWith(lastSeen: t));
    }

    final run = config.run;
    final stats = deriveStats(
      run,
      upgradeLevels: save.upgradeLevels,
      characterLevel: save.level,
      bugsCollected: save.bugs.length,
    );

    // 곤충학자 패스: 오프라인 상한 연장 + 방치 골드 배율(앱과 동일).
    // 서버 모드에선 이걸 서버가 반영하지 않으면 패스 혜택이 sync 마다 사라진다.
    final passOn = save.passActive(t);
    final maxAccrual = passOn
        ? Duration(hours: config.iap.passOfflineCapHours)
        : kMaxOfflineAccrual;

    // **스테이지가 오르며** 진행을 계산한다 — 앱과 같은 core_run 함수.
    // 스테이지가 서버에 반영돼야 재시작해도 진행이 남고 수입이 맞는다.
    final prog = simulateIdleProgress(
      config: run,
      startStage: save.stageNumber,
      stats: stats,
      elapsed: elapsed,
      efficiency: run.offlineEfficiency,
      maxAccrual: maxAccrual,
      tier: save.difficultyTier,
      // 심연이면 층 배율(앱 `_applyOffline` 과 같은 규칙).
      abyssFloor: activeAbyssFloor(save),
      // 캠페인 끝을 넘겨 전진시키지 않는다 — 회차 전환은 유저가 직접 누른다.
      finalStage: config.roadmap?.finalStage,
    );
    final goldGain = passOn
        ? (prog.gold * config.iap.passIdleGoldMult).round()
        : prog.gold;

    var xp = save.xp + prog.xp;
    var level = save.level;
    while (xp >= xpForNextLevel(level)) {
      xp -= xpForNextLevel(level);
      level++;
    }

    // 처치 수 → 곤충·재료 드롭. **서버가 굴린다.**
    final rolls = prog.habitatClears.floor().clamp(0, maxRollsPerSync);
    final rng = (rngFactory ?? Random.new)();
    // 앱 오프라인 정산과 **같은 함수**(core_save `rollIdleDrops`) — 규칙이 두 벌이면 갈린다.
    final drops = rollIdleDrops(
      save: save,
      rolls: rolls,
      species: config.speciesList,
      run: run,
      pet: config.pet,
      iap: config.iap,
      bugFind: stats.bugFind,
      materialFind: stats.materialFind,
      now: t,
      rng: rng,
      newId: _uuid.v4,
    );
    final newBugs = drops.bugs;
    final mats = drops.materials;
    final pity = drops.rarePity;

    // 미션 진행(처치) — 활성 미션이 killMonsters/killBosses 면 반영.
    // 하나만 활성이라 둘 중 최대 하나가 실제로 바뀐다.
    var mp = _bumpMission(
      save,
      save.missionProgress,
      MissionType.killMonsters,
      prog.habitatClears.floor(),
    );
    mp = _bumpMission(save, mp, MissionType.killBosses, prog.bossClears);

    // 깜짝선물 스폰(시각 기반, 서버 RNG).
    final (gifts, nextGiftAt) = _spawnGifts(save, t, rng);

    return ActionResult.ok(
      save.copyWith(
        gold: addCurrency(save.gold, goldGain),
        xp: xp,
        level: level,
        lastSeen: t,
        stageNumber: prog.newStage,
        // 사냥터 모드: 방치 중 잡은 수가 보스 도전 게이지에 쌓인다.
        zoneKills: run.zoneMode
            ? save.zoneKills + prog.habitatClears.floor()
            : null,
        rarePity: pity,
        bugs: newBugs.isEmpty ? null : [...save.bugs, ...newBugs],
        materials: mats,
        missionProgress: mp,
        gifts: gifts,
        nextGiftAt: nextGiftAt,
      ),
      extra: {
        'gold': goldGain,
        'xp': prog.xp,
        'elapsedSeconds': elapsed.inSeconds,
        'bugsGained': newBugs.length,
        'clears': rolls,
        'newStage': prog.newStage,
        'bossClears': prog.bossClears,
      },
    );
  }

  /// 활성 미션 1개를 [by] 만큼 진행시킨다(앱 `_bumpMissions` 와 같은 규칙).
  ///
  /// 활성 미션 = 총 수령횟수 % 미션수 — 수령할 때마다 다음 미션으로 순환한다.
  /// 타입이 맞고 `reachStage` 가 아닐 때만 올린다(reachStage 는 스테이지 파생).
  Map<String, int> _bumpMission(
    SaveGame save,
    Map<String, int> progress,
    MissionType type,
    int by,
  ) {
    final cfg = config.mission;
    if (cfg == null || cfg.missions.isEmpty || by <= 0) return progress;
    var totalClaims = 0;
    for (final v in save.missionClaims.values) {
      totalClaims += v;
    }
    final active = cfg.missions[totalClaims % cfg.missions.length];
    if (active.type != type || active.type == MissionType.reachStage) {
      return progress;
    }
    return Map<String, int>.from(progress)
      ..[active.id] = (progress[active.id] ?? 0) + by;
  }

  /// 깜짝선물 스폰(앱 `maybeSpawnGift` 의 서버 포팅, 서버 RNG).
  /// 만료된 선물을 정리하고, 예정 시각을 지났으면 하나 스폰한다.
  (List<GiftMail>, DateTime) _spawnGifts(
    SaveGame save,
    DateTime t,
    Random rng,
  ) {
    final alive = save.gifts.where((g) => !g.isExpired(t)).toList();
    final cfg = config.gift;
    if (cfg == null) return (alive, save.nextGiftAt ?? t);

    final next = save.nextGiftAt;
    if (next == null) {
      // 최초: 첫 선물 예약만.
      return (alive, t.add(Duration(seconds: cfg.firstDelaySec)));
    }
    if (t.isBefore(next)) return (alive, next); // 아직 예정 시각 전

    final rescheduled = t.add(Duration(seconds: cfg.nextIntervalSec(rng)));
    if (alive.length >= cfg.maxActive) {
      return (alive, rescheduled); // 가득 참 → 간격만 재예약
    }
    final tier = cfg.rollTier(rng);
    final gift = GiftMail(
      id: _uuid.v4(),
      expiry: t.add(Duration(hours: cfg.expiryHours)),
      // 정액과 **지금 사냥터 분치** 중 큰 쪽 — 앱과 같은 함수(§4).
      gold: giftGold(
        config.run,
        save.stageNumber,
        save.difficultyTier,
        tier.gold,
        tier.goldMinutes,
      ),
      jelly: tier.jelly,
      chitin: tier.chitin,
      mineral: tier.mineral,
      sap: tier.sap,
    );
    return ([...alive, gift], rescheduled);
  }

  /// 업그레이드 구매(일괄 [count] 단계까지).
  ///
  /// **비용 계산과 잔액 확인을 서버가 한다.** 앱과 같은 규칙:
  /// 골드나 재료가 모자라면 **거기서 멈추고 산 만큼만** 반영한다.
  ActionResult upgrade(SaveGame save, UpgradeKind kind, {int count = 1}) {
    if (count <= 0) return const ActionResult.fail('bad_count');
    final spec = config.run.upgrades[kind];
    if (spec == null) return const ActionResult.fail('unknown_upgrade');

    final matKind = spec.materialKind;
    var level = save.upgradeLevel(kind);
    var gold = save.gold;
    final mats = Map<MaterialKind, int>.from(save.materials);
    var bought = 0;

    for (var i = 0; i < count; i++) {
      final cost = upgradeCost(spec, level);
      if (gold < cost) break;
      final matCost = upgradeMaterialCost(spec, level);
      if (matKind != null && (mats[matKind] ?? 0) < matCost) break;
      gold -= cost;
      if (matKind != null && matCost > 0) {
        mats[matKind] = (mats[matKind] ?? 0) - matCost;
      }
      level++;
      bought++;
    }
    if (bought == 0) return const ActionResult.fail('insufficient_gold');

    // 미션 진행(강화 구매) — 산 만큼 활성 미션에 반영.
    final mp = _bumpMission(
      save,
      save.missionProgress,
      MissionType.buyUpgrades,
      bought,
    );

    return ActionResult.ok(
      save.copyWith(
        gold: gold,
        upgradeLevels: {...save.upgradeLevels, kind: level},
        materials: mats,
        missionProgress: mp,
      ),
      extra: {
        'bought': bought,
        'newLevel': level,
        'goldSpent': save.gold - gold,
      },
    );
  }

  /// 야생(합성) 상대 팀을 **서버가** 만든다.
  ///
  /// 클라이언트가 상대를 만들어 보내면 약한 팀으로 트로피를 쓸어담을 수 있다.
  /// 내 로스터 상위 3마리 평균 × 티어 배율로 만드는 규칙은 앱과 같지만,
  /// **난수와 배율 선택을 서버가 쥔다** — 클라는 티어 id 만 고른다.
  ({List<BattleBug> team, List<String> speciesIds, ScoutTier tier})?
  buildWildTeam(
    SaveGame save, {
    required String tierId,
    required Map<String, Species> speciesById,
    required PetConfig petConfig,
    EnhanceConfig? enhance,
    Random? rng,
    String locale = 'ko',
  }) {
    final tier = config.battle.scoutTiers
        .where((t) => t.id == tierId)
        .firstOrNull;
    if (tier == null) return null; // 클라가 임의 배율을 못 넣게 id 로만 받는다

    final t = now().toUtc();
    final tr = config.battle.training;

    // 내 성충 로스터 → 전투 유닛 → 파워 상위 3마리 평균.
    final mine = <BattleBug>[];
    for (final bug in save.bugs) {
      final sp = speciesById[bug.speciesId];
      if (sp == null) continue;
      if (effectiveStage(bug.stage, bug.stageSince, t, petConfig) !=
          LifeStage.adult) {
        continue;
      }
      final tb = trainingBonusOf(
        save,
        bug,
        sp,
        tr,
        levelCap: petConfig.levelCap(bug.breakthroughTier),
        enhance: enhance,
      );
      mine.add(
        buildBattleBug(
          bug: bug,
          species: sp,
          locale: 'ko',
          trainAtkMult: tb.atkMult,
          trainDefMult: tb.defMult,
          trainHpMult: tb.hpMult,
          trainSpdMult: tb.spdMult,
        ),
      );
    }
    if (mine.isEmpty) return null;

    double power(BattleBug b) => b.maxHp + b.atk * 10 + b.def * 5 + b.spd * 2;
    mine.sort((a, b) => power(b).compareTo(power(a)));
    final top = mine.take(3).toList();
    final n = top.length;
    final avgHp = top.fold(0.0, (s, b) => s + b.maxHp) / n;
    final avgAtk = top.fold(0.0, (s, b) => s + b.atk) / n;
    final avgDef = top.fold(0.0, (s, b) => s + b.def) / n;
    final avgSpd = top.fold(0.0, (s, b) => s + b.spd) / n;

    final r = rng ?? (rngFactory ?? Random.new)();
    final species = config.speciesList;
    // 종 데이터가 없으면 상대를 만들 수 없다. 여기서 막지 않으면
    // nextInt(0) 으로 500 이 난다(`sync` 는 이미 같은 가드가 있다).
    if (species.isEmpty) return null;
    // 앱이 같은 상대를 그리려면 종 id 도 알아야 한다(스프라이트).
    final speciesIds = <String>[];
    final team = List.generate(3, (i) {
      final sp = species[r.nextInt(species.length)];
      speciesIds.add(sp.id);
      final f = (0.9 + r.nextDouble() * 0.2) * tier.powerMult;
      return BattleBug(
        id: 'wild_$i',
        // ⚠️ 하드코딩하지 않는다 — 앱이 자기 표시 언어를 보낸다. 예전엔 'ko'
        // 고정이라 영어로 바꿔도 상대 이름만 한글로 나왔다(2026-08-27).
        name: sp.name.resolve(locale),
        element: Element.values[r.nextInt(Element.values.length)],
        temperament: Temperament.values[r.nextInt(Temperament.values.length)],
        preferredStance: preferredStanceOf(sp.specialty),
        maxHp: avgHp * f,
        atk: avgAtk * f,
        def: avgDef * f,
        spd: avgSpd * f,
      );
    });
    return (team: team, speciesIds: speciesIds, tier: tier);
  }

  /// 부위 강화 1단계 — **닫혔다**(2026-10-08 훈련 v2). 부위 강화는 훈련 포인트로 흡수돼(design_training_v2.md §2)
  /// 1.0.17 이하 앱이 부르면 `update_required`(426)로 업데이트를 안내한다(1.0.14 결투 개편의 `event_update` 와 같은 방식).
  /// 열어 두면 구버전이 계속 강화를 올려 이전 상한(옛 투자로 다시 계산하는 칸 상한·보너스)이 늘어난다.
  ActionResult enhancePart(
    SaveGame save,
    String bugId,
    BugPart part, {
    required EnhanceConfig enhance,
  }) => const ActionResult.fail('update_required', status: 426);

  /// 수련(성충 레벨업). 골드 비용·티어 상한·돌파중 여부를 서버가 확인한다.
  ActionResult trainBug(
    SaveGame save,
    String bugId, {
    required PetConfig petConfig,
  }) {
    final t = now().toUtc();
    final idx = save.bugs.indexWhere((b) => b.id == bugId);
    if (idx < 0) return const ActionResult.fail('bug_not_owned');
    final bug = save.bugs[idx];
    if (effectiveStage(bug.stage, bug.stageSince, t, petConfig) !=
        LifeStage.adult) {
      return const ActionResult.fail('not_adult');
    }
    if (bug.breakthroughEndsAt != null) {
      return const ActionResult.fail('breakthrough_in_progress');
    }
    if (bug.level >= petConfig.levelCap(bug.breakthroughTier)) {
      return const ActionResult.fail('at_cap');
    }
    final cost = petConfig.trainCost(bug.level);
    if (save.gold < cost) return const ActionResult.fail('insufficient_gold');

    final bugs = List<IndividualBug>.from(save.bugs);
    bugs[idx] = bug.copyWith(level: bug.level + 1);
    return ActionResult.ok(
      save.copyWith(gold: save.gold - cost, bugs: bugs),
      extra: {'cost': cost, 'newLevel': bug.level + 1},
    );
  }

  /// 돌파에 쓰는 재료 3종(젤리 제외). 앱·UI 와 **같은 목록**을 써야 한다
  /// — 어긋나면 "화면엔 3종인데 서버는 2종만 차감"이 조용히 생긴다.
  static const _breakMats = kBreakthroughMaterials;

  /// 돌파 시작 — 티어 상한을 채운 성충의 레벨 상한을 올린다(타이머 시작).
  ///
  /// 돌파는 수련 상한을 늘려 **곤충 스탯을 직접 올린다** → PvP 에 영향.
  /// 클라이언트가 처리하면 재화 없이 상한을 뚫어 강해질 수 있다.
  ActionResult startBreakthrough(
    SaveGame save,
    String bugId, {
    required PetConfig petConfig,
  }) {
    final t = now().toUtc();
    final idx = save.bugs.indexWhere((b) => b.id == bugId);
    if (idx < 0) return const ActionResult.fail('bug_not_owned');
    final bug = save.bugs[idx];
    if (effectiveStage(bug.stage, bug.stageSince, t, petConfig) !=
        LifeStage.adult) {
      return const ActionResult.fail('not_adult');
    }
    if (bug.breakthroughEndsAt != null) {
      return const ActionResult.fail('breakthrough_in_progress');
    }
    final tier = bug.breakthroughTier;
    if (tier >= petConfig.maxTier)
      return const ActionResult.fail('at_max_tier');
    // 현재 티어 상한을 다 채워야 돌파할 수 있다.
    if (bug.level < petConfig.levelCap(tier)) {
      return const ActionResult.fail('cap_not_reached');
    }
    final gold = petConfig.breakthroughGoldCost(tier);
    final matCost = petConfig.breakthroughMatCost(tier);
    if (save.gold < gold) return const ActionResult.fail('insufficient_gold');
    for (final k in _breakMats) {
      if (save.materialCount(k) < matCost) {
        return const ActionResult.fail('insufficient_material');
      }
    }

    final mats = Map<MaterialKind, int>.from(save.materials);
    for (final k in _breakMats) {
      mats[k] = save.materialCount(k) - matCost;
    }
    final endsAt = t.add(
      Duration(seconds: petConfig.breakthroughDuration(tier)),
    );
    final bugs = List<IndividualBug>.from(save.bugs);
    bugs[idx] = bug.copyWith(breakthroughEndsAt: endsAt);
    return ActionResult.ok(
      save.copyWith(gold: save.gold - gold, materials: mats, bugs: bugs),
      extra: {
        'gold': gold,
        'material': matCost,
        'endsAt': endsAt.toIso8601String(),
      },
    );
  }

  /// 돌파 완료 수령. [viaJelly]=남은시간 비례 젤리로 즉시완료,
  /// 아니면 타이머 종료 후에만. 완료 전 젤리 없이 수령하는 조작을 막는다.
  ActionResult completeBreakthrough(
    SaveGame save,
    String bugId, {
    required PetConfig petConfig,
    bool viaJelly = false,
  }) {
    final t = now().toUtc();
    final idx = save.bugs.indexWhere((b) => b.id == bugId);
    if (idx < 0) return const ActionResult.fail('bug_not_owned');
    final bug = save.bugs[idx];
    final endsAt = bug.breakthroughEndsAt;
    if (endsAt == null) return const ActionResult.fail('not_breaking');

    final bugs = List<IndividualBug>.from(save.bugs);
    final upgraded = bug.copyWith(
      breakthroughTier: bug.breakthroughTier + 1,
      clearBreakthrough: true,
    );

    if (viaJelly) {
      final cost = petConfig.breakthroughJelly(endsAt.difference(t));
      final have = save.materialCount(MaterialKind.jelly);
      if (have < cost) return const ActionResult.fail('insufficient_jelly');
      final mats = Map<MaterialKind, int>.from(save.materials)
        ..[MaterialKind.jelly] = have - cost;
      bugs[idx] = upgraded;
      return ActionResult.ok(
        save.copyWith(bugs: bugs, materials: mats),
        extra: {'jelly': cost, 'newTier': upgraded.breakthroughTier},
      );
    }
    if (t.isBefore(endsAt)) return const ActionResult.fail('not_ready');
    bugs[idx] = upgraded;
    return ActionResult.ok(
      save.copyWith(bugs: bugs),
      extra: {'newTier': upgraded.breakthroughTier},
    );
  }

  /// 미션 보상 수령. 목표 미달·정의 없음이면 거부.
  ///
  /// 서버가 진행도를 소유하므로(§sync·upgrade 에서 bump), 클라가 진행도를
  /// 속여 수령할 수 없다. 수령하면 티어(claims)가 1 오르고(→ 다음 미션 순환)
  /// 진행도 전체를 초기화한다(앱 `claimMission` 과 같은 규칙).
  ActionResult claimMission(SaveGame save, String missionId) {
    final cfg = config.mission;
    if (cfg == null) return const ActionResult.fail('unavailable');
    MissionDef? def;
    for (final d in cfg.missions) {
      if (d.id == missionId) {
        def = d;
        break;
      }
    }
    if (def == null) return const ActionResult.fail('unknown_mission');

    final claims = save.missionClaimCount(missionId);
    final goal = def.goalAt(claims);
    if (save.missionProgressCount(missionId) < goal) {
      return const ActionResult.fail('goal_not_reached');
    }

    var gold = save.gold;
    final mats = Map<MaterialKind, int>.from(save.materials);
    final amount = def.rewardAt(claims);
    switch (def.reward) {
      case 'gold':
        gold += amount;
      case 'jelly':
        mats[MaterialKind.jelly] = (mats[MaterialKind.jelly] ?? 0) + amount;
      case 'material':
        final m = def.rewardMaterial;
        if (m != null) mats[m] = (mats[m] ?? 0) + amount;
    }

    final claimsMap = Map<String, int>.from(save.missionClaims)
      ..[missionId] = claims + 1;
    return ActionResult.ok(
      save.copyWith(
        gold: gold,
        materials: mats,
        missionClaims: claimsMap,
        missionProgress: const {},
      ),
      extra: {'reward': def.reward, 'amount': amount},
    );
  }

  /// 깜짝선물 수령. 만료·없음이면 거부. [doubled]=2배 요청.
  ///
  /// ⚠️ **2배 자격은 서버가 판정한다.** 앱에도 같은 규칙([canDoubleGift])이
  /// 있지만, 수령은 서버 경로가 먼저라 여기가 비어 있으면 앱의 제한이 통째로
  /// 무의미해진다 — 실제로 무료 하루 1회가 **매번 2배**로 나가고 있었다
  /// (2026-09-12 사장님 지적). 선물은 접속 시간에 비례해 무한히 나오는
  /// 통로라(§2.6 젤리 수도꼭지), 여기서 새면 최상위 티어의 젤리도 함께 샌다.
  ///
  /// 규칙은 앱과 같다: 패스 보유자는 무제한, 나머지는 하루
  /// [GiftConfig.freeDoubleDaily] 회. 자격이 없으면 **거부가 아니라 1배**로
  /// 지급한다 — 이미 뜬 보상을 못 받게 하면 불만이 크다.
  ActionResult claimGift(SaveGame save, String giftId, {bool doubled = false}) {
    // 규칙(2배 자격·배수·첫 2배 젤리)은 앱과 같은 공용 함수 한 곳에 있다(§4).
    // 금액은 앱이 만든 값이라 상한으로 자른 뒤 지급한다(2026-10-08 — 사냥 분치로 커졌다).
    final capped = save.copyWith(
      gifts: [
        for (final g in save.gifts) g.id == giftId ? _capGift(save, g) : g,
      ],
    );
    final r = claimGiftOn(
      capped,
      config.gift,
      giftId,
      doubled: doubled,
      now: now().toUtc(),
    );
    // 만료된 선물은 지급하지 않는다(다음 sync 가 정리한다).
    if (r.error != null) return ActionResult.fail(r.error!);
    return ActionResult.ok(
      r.save!,
      extra: {
        'gold': r.gold,
        'doubled': r.doubled,
        'mult': r.mult,
        'bonusJelly': r.bonusJelly,
      },
    );
  }

  /// 일일보상 수령. **UTC 날짜당 슬롯 1회**만 지급한다.
  ///
  /// 앱은 로컬 벽시계로 "점심 12시/저녁 18시" 게이트를 두지만, 서버는
  /// 클라 타임존을 알 수 없다. 그래서 **시간 게이트는 UI(UX)에 맡기고**,
  /// 서버는 하루에 같은 슬롯을 여러 번 먹는 조작만 막는다(UTC 날짜 중복).
  ///
  /// 2026-10-08: 금액 = 정액과 **사냥 [DailyReward.huntMinutes]분치** 중 큰 쪽. 분치는 앱이 펫·장비가 실린
  /// 능력치로 계산해 보내고([clientGold]·[clientMaterialsEach]) 서버는 봉투 상한([_huntCap])으로 자른다.
  /// 구버전 앱은 금액을 안 보내서 정액만 받는다. [bonus] = "한 번 더 받기"(1배 더) — 그 슬롯을 오늘 받은
  /// 뒤에만, 하루 1회([dailyBonusKey]). 예전엔 앱이 로컬로 얹어서 금액이 커지면 업로드 상한에 잘렸다.
  ActionResult claimDaily(
    SaveGame save,
    String rewardId, {
    int clientGold = 0,
    int clientMaterialsEach = 0,
    bool bonus = false,
  }) {
    final cfg = config.daily;
    if (cfg == null) return const ActionResult.fail('unavailable');
    DailyReward? reward;
    for (final r in cfg.rewards) {
      if (r.id == rewardId) {
        reward = r;
        break;
      }
    }
    if (reward == null) return const ActionResult.fail('unknown_reward');

    final today = dailyDateKey(now().toUtc());
    final key = bonus ? dailyBonusKey(rewardId) : rewardId;
    if (save.dailyClaims[key] == today) {
      return const ActionResult.fail('already_claimed');
    }
    if (bonus && save.dailyClaims[rewardId] != today) {
      return const ActionResult.fail('not_claimed');
    }
    final cap = _huntCap(save, reward.huntMinutes);
    final gold = max(reward.gold, min(max(clientGold, 0), cap.gold));
    final each = min(max(clientMaterialsEach, 0), cap.materialsEach);
    final mats = Map<MaterialKind, int>.from(save.materials);
    final fixed = reward.materials;
    for (final k in kBreakthroughMaterials) {
      final add = max(fixed[k] ?? 0, each);
      if (add > 0) mats[k] = (mats[k] ?? 0) + add;
    }
    if (reward.jelly > 0) {
      mats[MaterialKind.jelly] = (mats[MaterialKind.jelly] ?? 0) + reward.jelly;
    }
    final claims = Map<String, String>.from(save.dailyClaims)..[key] = today;
    return ActionResult.ok(
      save.copyWith(
        gold: addCurrency(save.gold, gold),
        materials: mats,
        dailyClaims: claims,
      ),
      extra: {'gold': gold},
    );
  }

  /// 최고 도달 스테이지 기준 **처음 클리어한 챕터** 보상을 지급한다.
  ///
  /// 스테이지를 서버가 소유하므로(sync 에서 올림) 챕터 클리어도 서버가 확정한다.
  /// 이미 받은 챕터는 건너뛴다(중복 지급 방지). 새로 받은 챕터 id 를 extra 로.
  ActionResult grantChapterClears(SaveGame save) {
    final cfg = config.roadmap;
    if (cfg == null) return const ActionResult.fail('unavailable');
    final newly = <String>[];
    var gold = save.gold;
    final mats = Map<MaterialKind, int>.from(save.materials);
    final cleared = Set<String>.from(save.clearedChapters);
    for (final ch in cfg.chapters) {
      if (ch.clearedBy(save.stageNumber) && !cleared.contains(ch.id)) {
        gold += ch.rewardGold;
        for (final e in ch.rewardMaterials.entries) {
          mats[e.key] = (mats[e.key] ?? 0) + e.value;
        }
        cleared.add(ch.id);
        newly.add(ch.id);
      }
    }
    if (newly.isEmpty) {
      return ActionResult.ok(save, extra: {'cleared': const <String>[]});
    }
    return ActionResult.ok(
      save.copyWith(gold: gold, materials: mats, clearedChapters: cleared),
      extra: {'cleared': newly},
    );
  }

  /// 짝짓기 시작. 조건 검사와 **자식 롤 시드 생성을 서버가 한다.**
  ///
  /// ⚠️ 기존 앱은 시드를 UI 가 만들어 넘겼다. 그러면 시드를 골라가며
  /// 완벽한 자식이 나올 때까지 돌려볼 수 있다(브루트포스).
  /// 서버가 시드를 정하고 슬롯에 박아두면 결과가 미리 확정된다.
  ActionResult startBreeding(
    SaveGame save, {
    required String motherId,
    required String fatherId,
    required Map<String, Species> speciesById,
    required PetConfig petConfig,
  }) {
    if (motherId == fatherId) return const ActionResult.fail('same_bug');
    if (save.breeding.length >= save.breedingCapacity) {
      return const ActionResult.fail('no_slot');
    }
    final t = now().toUtc();
    IndividualBug? find(String id) {
      for (final b in save.bugs) {
        if (b.id == id) return b;
      }
      return null;
    }

    final mother = find(motherId);
    final father = find(fatherId);
    if (mother == null || father == null) {
      return const ActionResult.fail('bug_not_owned');
    }
    if (mother.speciesId != father.speciesId) {
      return const ActionResult.fail('species_mismatch');
    }
    if (mother.sex != Sex.female || father.sex != Sex.male) {
      return const ActionResult.fail('sex_mismatch');
    }
    LifeStage eff(IndividualBug b) =>
        effectiveStage(b.stage, b.stageSince, t, petConfig);
    if (eff(mother) != LifeStage.adult || eff(father) != LifeStage.adult) {
      return const ActionResult.fail('not_adult');
    }
    final sp = speciesById[mother.speciesId];
    if (sp == null) return const ActionResult.fail('unknown_species');
    // 짝짓기 텀(§2.5) — 앱과 **같은 규칙**으로 서버도 막는다. 구버전 앱이나
    // 세이브를 고친 요청이 같은 부모를 계속 돌리지 못하게 한다.
    if (save.breedOnCooldown(motherId, t) ||
        save.breedOnCooldown(fatherId, t)) {
      return const ActionResult.fail('breed_cooldown');
    }

    final rng = (rngFactory ?? Random.new)();
    // 부모의 오행·기질·특성까지 스냅샷한다(§2.5 상속). 앱과 **같은 생성자**를
    // 써야 한쪽만 값을 빠뜨려 "상속이 안 되는 유저"가 생기지 않는다.
    final slot = BreedingSlot.from(
      id: _uuid.v4(),
      mother: mother,
      father: father,
      // 스킨 계열 편의 보너스(산란 시간 −N%, 2026-10-08 — 시간만, 전투 스탯 아님). 앱과 같은 함수.
      endsAt: t.add(
        Duration(
          seconds: config.iap.skinnedBreedSeconds(
            petConfig.breedingDuration(sp.grade),
            save.ownedSkins,
            sp.id,
          ),
        ),
      ),
      // 서버가 정한다 — 클라이언트가 고를 수 없다.
      seed: rng.nextInt(1 << 31),
    );
    // 쿨다운은 **시작 시점**에 건다 — 수령을 미뤄 텀을 피할 수 없게.
    final cool = petConfig.breedingCooldown(sp.grade);
    final cooldowns = save.prunedBreedCooldowns(t);
    if (cool > 0) {
      final until = t.add(Duration(seconds: cool));
      cooldowns[motherId] = until;
      cooldowns[fatherId] = until;
    }
    return ActionResult.ok(
      save.copyWith(
        breeding: [...save.breeding, slot],
        breedCooldowns: cooldowns,
      ),
      extra: {'slotId': slot.id, 'endsAt': slot.endsAt.toIso8601String()},
    );
  }

  /// 산란 완료 슬롯 수령. [viaJelly] 면 남은 시간만큼 젤리로 즉시 완료.
  ActionResult collectBreeding(
    SaveGame save,
    String slotId, {
    required Map<String, Species> speciesById,
    required PetConfig petConfig,
    bool viaJelly = false,
  }) {
    final t = now().toUtc();
    final idx = save.breeding.indexWhere((b) => b.id == slotId);
    if (idx < 0) return const ActionResult.fail('slot_not_found');
    final slot = save.breeding[idx];
    final sp = speciesById[slot.speciesId];
    if (sp == null) return const ActionResult.fail('unknown_species');

    // 채집함이 가득 차면 수령을 거부한다 — 슬롯을 남겨 자리를 비운 뒤 받게 한다
    // (여기서 알을 버리면 산란에 쓴 시간·젤리가 통째로 날아간다).
    if (save.storageFull) return const ActionResult.fail('storage_full');

    var mats = save.materials;
    if (t.isBefore(slot.endsAt)) {
      if (!viaJelly) return const ActionResult.fail('not_ready');
      final cost = petConfig.breedingJelly(slot.endsAt.difference(t));
      final have = save.materialCount(MaterialKind.jelly);
      if (have < cost) return const ActionResult.fail('insufficient_jelly');
      mats = Map<MaterialKind, int>.from(save.materials)
        ..[MaterialKind.jelly] = have - cost;
    }

    // 자식 롤 — 슬롯에 박힌 서버 시드로 결정론적으로 굴린다.
    // 공식은 슬롯이 들고 있다(앱과 **같은 함수**).
    final egg = slot
        .hatch(id: _uuid.v4(), species: sp, cfg: petConfig)
        .copyWith(stageSince: t);

    final breeding = List<BreedingSlot>.from(save.breeding)..removeAt(idx);
    return ActionResult.ok(
      save.copyWith(
        bugs: [...save.bugs, egg],
        breeding: breeding,
        materials: mats,
      ),
      extra: {'bugId': egg.id, 'potential': egg.potential},
    );
  }

  /// 부화 수령(알 → 유충). 완료 전이면 거부.
  ActionResult collectIncubated(SaveGame save, String bugId) {
    final t = now().toUtc();
    final endsAt = save.incubating[bugId];
    if (endsAt == null) return const ActionResult.fail('not_incubating');
    if (t.isBefore(endsAt)) return const ActionResult.fail('not_ready');
    final idx = save.bugs.indexWhere((b) => b.id == bugId);
    if (idx < 0) return const ActionResult.fail('bug_not_owned');

    final bugs = List<IndividualBug>.from(save.bugs);
    bugs[idx] = bugs[idx].copyWith(stage: LifeStage.larva, stageSince: t);
    final inc = Map<String, DateTime>.from(save.incubating)..remove(bugId);
    return ActionResult.ok(save.copyWith(bugs: bugs, incubating: inc));
  }

  /// 곤충 분해 → 젤리. 지급량은 `pets.json` 이 정한다(§6).
  ///
  /// 편성 중이거나 부상 중인 개체는 분해할 수 없다 —
  /// 전투 도중 사라지면 상태가 꼬인다.
  ActionResult disassembleBug(
    SaveGame save,
    String bugId, {
    required PetConfig petConfig,
  }) {
    final t = now().toUtc();
    final idx = save.bugs.indexWhere((b) => b.id == bugId);
    if (idx < 0) return const ActionResult.fail('bug_not_owned');
    if (save.equippedBugIds.contains(bugId)) {
      return const ActionResult.fail('equipped');
    }
    if (save.isInjured(bugId, t)) return const ActionResult.fail('injured');
    if (save.incubating.containsKey(bugId)) {
      return const ActionResult.fail('incubating');
    }

    final bug = save.bugs[idx];
    // 앱과 **같은 규칙**: 재료는 항상, 젤리는 문턱(포텐셜)을 넘는 개체만.
    // 곤충은 무한히 나오므로 분해에 젤리를 무제한으로 붙이면 프리미엄 재화가
    // 파밍으로 뽑힌다(§2.6). 규칙이 두 벌이면 "앱에선 젤리를 줬는데 서버가 안 준다"가 된다.
    // 획득 시점 포텐셜 기준(합성으로 올린 몫은 젤리가 없다, 2026-09-30).
    final reward = petConfig.disassembleJelly(bug.bornPotential);
    final grade = config.speciesList
        .where((s) => s.id == bug.speciesId)
        .map((s) => s.grade)
        .firstOrNull;
    final matGain = grade == null
        ? 0
        : config.iap.skinnedReleaseMaterial(
            petConfig.releaseMaterial(grade),
            save.ownedSkins,
            bug.speciesId,
          );
    final mats = Map<MaterialKind, int>.from(save.materials);
    if (reward > 0) {
      mats[MaterialKind.jelly] =
          save.materialCount(MaterialKind.jelly) + reward;
    }
    if (matGain > 0) {
      final rng = (rngFactory ?? Random.new)();
      final kind = _regularMaterials[rng.nextInt(_regularMaterials.length)];
      mats[kind] = (mats[kind] ?? 0) + matGain;
    }
    final bugs = List<IndividualBug>.from(save.bugs)..removeAt(idx);
    return ActionResult.ok(
      save.copyWith(bugs: bugs, materials: mats),
      extra: {'jelly': reward, 'material': matGain},
    );
  }

  // ── 결투 티켓(2026-08) ──
  //
  // 티켓은 **서버 소유**다([_serverOwnedKeys]). 그래서 소모·지급도 전부 여기서
  // 확정한다 — 앱이 로컬로 깎아 올려봐야 업로드 때 서버 값으로 덮인다.
  // 계산 자체는 `core_run` 의 순수 함수를 앱과 공유한다(같은 결과 보장).

  /// [save] 의 티켓을 지금 시각 기준으로 정산한 값.
  TicketState ticketsNow(SaveGame save) => regenTickets(
    tickets: save.pvpTickets,
    at: save.ticketsAt,
    now: now().toUtc(),
    cfg: config.battle,
  );

  /// 결투 1판분 티켓 소모. 없으면 `no_tickets` 로 거부한다.
  ActionResult consumePvpTicket(SaveGame save) {
    final next = consumeTicket(
      tickets: save.pvpTickets,
      at: save.ticketsAt,
      now: now().toUtc(),
      cfg: config.battle,
    );
    if (next == null) return const ActionResult.fail('no_tickets');
    return ActionResult.ok(
      save.copyWith(pvpTickets: next.tickets, ticketsAt: next.at),
      extra: {'tickets': next.tickets, 'ticketsAt': next.at.toIso8601String()},
    );
  }

  /// 광고 보상 티켓 지급. 하루 상한을 넘으면 `ad_limit`.
  ///
  /// 상한은 **광고제거·패스 구매자에게도 동일**하다. 광고제거는 광고를 스킵하고
  /// 즉시 받는 '시간 절약'이지 판수를 더 사는 수단이 아니다(랭킹 보호).
  ActionResult grantAdTicket(SaveGame save) {
    final cfg = config.battle;
    if (cfg.ticketAdGrant <= 0) return const ActionResult.fail('disabled');
    final t = now().toUtc();
    // 정산 기간엔 결투를 받지 않는다 — 충전해 봐야 쓸 곳이 없고 하루 무료 횟수만 날아간다(2026-10-04).
    if (seasonClosed(t, cfg)) return const ActionResult.fail('season_closed');
    // 날짜 경계는 UTC. 서버는 기기 타임존을 모르고, 알더라도 타임존을 바꿔가며
    // 상한을 리셋하는 우회가 생긴다.
    final today = dailyDateKey(t);
    final used = save.adUseCount(kAdFeaturePvpTicket, today);
    if (cfg.ticketAdDailyLimit > 0 && used >= cfg.ticketAdDailyLimit) {
      return const ActionResult.fail('ad_limit');
    }
    final next = grantTickets(
      tickets: save.pvpTickets,
      at: save.ticketsAt,
      now: t,
      cfg: cfg,
      amount: cfg.ticketAdGrant,
    );
    // 날짜가 바뀌었으면 카운터를 통째로 새로 시작한다(다른 기능 키까지 리셋).
    final counts = save.adUseDate == today
        ? Map<String, int>.from(save.adUseCounts)
        : <String, int>{};
    counts[kAdFeaturePvpTicket] = used + 1;
    return ActionResult.ok(
      save.copyWith(
        pvpTickets: next.tickets,
        ticketsAt: next.at,
        adUseCounts: counts,
        adUseDate: today,
      ),
      extra: {
        'tickets': next.tickets,
        'ticketsAt': next.at.toIso8601String(),
        'adUsed': used + 1,
        'adLimit': cfg.ticketAdDailyLimit,
      },
    );
  }

  /// 젤리로 티켓을 상한까지 즉시 충전. 이미 가득이면 `already_full`.
  ActionResult refillPvpTickets(SaveGame save) {
    final cfg = config.battle;
    final t = now().toUtc();
    // 정산 기간엔 결투를 받지 않는다 — 젤리만 쓰고 쓸 곳이 없다(2026-10-04).
    if (seasonClosed(t, cfg)) return const ActionResult.fail('season_closed');
    final cur = regenTickets(
      tickets: save.pvpTickets,
      at: save.ticketsAt,
      now: t,
      cfg: cfg,
    );
    if (cur.tickets >= cfg.ticketMax) {
      return const ActionResult.fail('already_full');
    }
    // 하루 횟수(2026-10-02) — 패스 구매자도 같다(결제로 판수를 사지 못하게, §2.8).
    final today = dailyDateKey(t);
    final used = save.adUseCount(kAdFeaturePvpRefill, today);
    if (cfg.ticketRefillDailyLimit > 0 && used >= cfg.ticketRefillDailyLimit) {
      return const ActionResult.fail('refill_limit');
    }
    final paid = spendJelly(save, cfg.ticketRefillJelly, reason: 'pvp_ticket');
    if (!paid.isOk) return paid;
    final next = refillTickets(
      tickets: save.pvpTickets,
      at: save.ticketsAt,
      now: t,
      cfg: cfg,
    );
    final counts = save.adUseDate == today
        ? Map<String, int>.from(save.adUseCounts)
        : <String, int>{};
    counts[kAdFeaturePvpRefill] = used + 1;
    return ActionResult.ok(
      paid.save!.copyWith(
        pvpTickets: next.tickets,
        ticketsAt: next.at,
        adUseCounts: counts,
        adUseDate: today,
      ),
      extra: {
        'tickets': next.tickets,
        'ticketsAt': next.at.toIso8601String(),
        'jelly': paid.save!.materialCount(MaterialKind.jelly),
        'refillUsed': used + 1,
        'refillLimit': cfg.ticketRefillDailyLimit,
      },
    );
  }

  /// 운영 지급(공지 보상·선물코드) 반영.
  ///
  /// **지급은 서버가 하고 클라이언트는 결과 세이브를 채택한다**(구매와 같은 방식).
  /// 앱이 자기 세이브에 직접 더하게 하면 다음 업로드에서 골드 급증 상한
  /// ([_goldSanityFloor])에 걸려 정당한 보상이 잘린다.
  ///
  /// [row] 는 `user_mail` / `gift_codes` 행(gold·jelly·chitin·mineral·sap).
  ActionResult grantRewardRow(SaveGame save, Map<String, dynamic> row) {
    int n(String k) {
      final v = row[k];
      final i = (v is num) ? v.toInt() : 0;
      return i < 0 ? 0 : i; // 음수 지급은 없다(운영 실수로 재화를 뺏지 않게)
    }

    final gold = n('gold');
    final grant = {
      MaterialKind.jelly: n('jelly'),
      MaterialKind.chitin: n('chitin'),
      MaterialKind.mineral: n('mineral'),
      MaterialKind.sap: n('sap'),
    };
    final mats = Map<MaterialKind, int>.from(save.materials);
    for (final e in grant.entries) {
      if (e.value > 0) mats[e.key] = save.materialCount(e.key) + e.value;
    }
    // 요정 재료(우편 `fairy` 칸, 2026-10-05) — 가루·속성석·가속기. 선물코드 행엔 없다(null).
    var fairyState = save.fairy;
    final fr = row['fairy'];
    final fairyGranted = <String, dynamic>{};
    if (fr is Map) {
      int fn(Object? v) {
        final i = (v is num) ? v.toInt() : 0;
        return i < 0 ? 0 : i;
      }

      Map<String, int> add(Map<String, int> cur, Object? raw) {
        final out = Map<String, int>.from(cur);
        if (raw is Map) {
          for (final e in raw.entries) {
            final v = fn(e.value);
            if (v > 0) out['${e.key}'] = addCurrency(out['${e.key}'] ?? 0, v);
          }
        }
        return out;
      }

      final dust = fn(fr['dust']);
      fairyState = fairyState.copyWith(
        dust: addCurrency(fairyState.dust, dust),
        stones: add(fairyState.stones, fr['stones']),
        accelerators: add(fairyState.accelerators, fr['accelerators']),
      );
      if (dust > 0) fairyGranted['dust'] = dust;
      if (fr['stones'] is Map) fairyGranted['stones'] = fr['stones'];
      if (fr['accelerators'] is Map) {
        fairyGranted['accelerators'] = fr['accelerators'];
      }
    }
    return ActionResult.ok(
      save.copyWith(
        gold: addCurrency(save.gold, gold),
        materials: mats,
        fairy: fairyState,
      ),
      extra: {
        'granted': {
          'gold': gold,
          for (final e in grant.entries)
            if (e.value > 0) e.key.key: e.value,
          if (fairyGranted.isNotEmpty) 'fairy': fairyGranted,
        },
      },
    );
  }

  /// 젤리 소비. 잔액이 모자라면 거부한다 — **클라이언트 말을 믿지 않는다.**
  /// 요정 재굴림 — **서버가 굴린다**(2026-10-04, 조정안 C). 기기에서 굴리면 [_keepFairyIdentity] 가 되돌리고,
  /// 그 고정을 풀면 개체값 위조가 열린다. 결과는 대기로 적고 [fairyRerollChoose] 로 고른다.
  /// 하루 횟수는 KST 날짜 — 서버 시계라 기기 시계로 늘릴 수 없다.
  ActionResult fairyReroll(SaveGame save, String fairyId) {
    final cfg = config.fairy;
    if (cfg == null) return const ActionResult.fail('off');
    final k = now().toUtc().add(const Duration(hours: 9));
    final today =
        '${k.year}-${k.month.toString().padLeft(2, '0')}-${k.day.toString().padLeft(2, '0')}';
    final op = rollFairyReroll(
      save.fairy,
      cfg,
      (rngFactory ?? Random.secure)(),
      fairyId: fairyId,
      today: today,
      jellyHave: save.materialCount(MaterialKind.jelly),
    );
    if (!op.isOk) return ActionResult.fail(op.error!);
    final paid = spendJelly(save, op.jelly, reason: 'fairy_reroll');
    if (!paid.isOk) return paid;
    final r = op.extra['reroll']! as FairyReroll;
    return ActionResult.ok(
      paid.save!.copyWith(fairy: op.state),
      extra: {'reroll': r.toJson()},
    );
  }

  /// 재굴림 결과 고르기 — [accept] 면 새 값, 아니면 원래 값을 지킨다.
  ActionResult fairyRerollChoose(SaveGame save, {required bool accept}) {
    final op = chooseFairyReroll(save.fairy, accept: accept);
    if (!op.isOk) return ActionResult.fail(op.error!);
    return ActionResult.ok(save.copyWith(fairy: op.state));
  }

  ActionResult spendJelly(SaveGame save, int amount, {String? reason}) {
    if (amount <= 0) return const ActionResult.fail('bad_amount');
    final have = save.materialCount(MaterialKind.jelly);
    if (have < amount) return const ActionResult.fail('insufficient');
    final mats = Map<MaterialKind, int>.from(save.materials)
      ..[MaterialKind.jelly] = have - amount;
    return ActionResult.ok(save.copyWith(materials: mats));
  }

  // ── 실물 경품 랭킹 이벤트 — 웨이브 방어전 ────────────────────────
  //
  // docs/event_ranking_prize.md. 이 모드의 순위는 **그대로 실물 상품**이 되므로,
  // 앱이 계산한 값을 받아 적는 경로를 아예 만들지 않는다. 서버가 참가권을 깎고,
  // 편성을 검증하고, seed 를 정하고, 웨이브를 돌려 점수를 확정한다.
  // 앱은 그 seed 로 같은 판을 **재생만** 한다(core_battle 결정론 §2.3).

  /// 지금 시각이 속한 회차 키.
  String eventRoundId() {
    final cfg = config.event;
    final t = now().toUtc();
    return cfg == null ? EventConfig.roundIdOf(t) : cfg.roundIdAt(t);
  }

  /// 지금 대회가 열려 있는가(기간 밖이면 도전·기록을 받지 않는다).
  bool get eventOpen {
    final cfg = config.event;
    return cfg != null && cfg.isOpen(now().toUtc());
  }

  /// 참가권 일일 지급 경계(KST 09:00). 시즌·이벤트가 같은 앵커를 쓴다 —
  /// 기기 타임존을 바꿔 하루에 두 번 받는 우회를 막으려면 고정 오프셋이어야 한다.
  static String _eventGrantDayKey(DateTime utc, int anchorHourKst) {
    final kst = utc.toUtc().add(const Duration(hours: 9));
    final shifted = kst.subtract(Duration(hours: anchorHourKst));
    return '${shifted.year}-${shifted.month}-${shifted.day}';
  }

  /// [save] 의 참가권을 지금 시각 기준으로 정산한다(일일 지급 반영).
  ({int tickets, DateTime at}) eventTicketsNow(SaveGame save) {
    final cfg = config.event;
    final t = now().toUtc();
    if (cfg == null) return (tickets: save.eventTickets, at: t);
    final last = save.eventTicketsAt;
    final today = _eventGrantDayKey(t, cfg.anchorHourKst);
    if (last != null && _eventGrantDayKey(last, cfg.anchorHourKst) == today) {
      return (tickets: save.eventTickets, at: last);
    }
    // 하루치 지급 — 여러 날 비웠어도 **한 번만** 준다(모아두는 게임이 아니다).
    final next = save.eventTickets + cfg.ticketDailyGrant;
    return (tickets: next > cfg.ticketMax ? cfg.ticketMax : next, at: t);
  }

  // ── 심연(극한 이후 무한 층, 2026-09-28) ──────────────────────────────
  //
  // 심연 진행은 솔로 루프라 **기기 권위**다. 세이브를 고쳐 999층을 적으면 주간 1위가 된다 —
  // 결투처럼 서버가 싸움을 확정할 수 없으므로, 업로드마다 **시간으로 층 증가를 묶는다**
  // (층 하나 = 몬스터 100마리 + 보스라 `minSecondsPerFloor` 보다 빠를 수 없다).
  // 골드 상한과 같은 수준의 방어다 — 전력 자체가 기기 권위라 완벽하지 않다(design_abyss §2).

  /// 올라온 심연 필드를 규칙 안으로 — 열림(최종 보스 도감) · 주(이번 주/저장본 주만) ·
  /// 층(시간 상한) · 역대 최고(깬 층까지, 줄지 않음).
  ({
    bool unlocked,
    bool inAbyss,
    int floor,
    int best,
    int bossBest,
    String? week,
    bool clamped,
    DateTime? floorAt,
  })
  _enforceAbyss(
    SaveGame stored,
    Map<String, dynamic> clientJson,
    Duration elapsed,
    DateTime t,
  ) {
    final run = config.run;
    final cfg = run.abyss;
    final bossDex = {
      ...stored.bossDex,
      for (final e in (clientJson['bossDex'] as List? ?? const [])) '$e',
    };
    final finalKilled = bossDex.contains(
      run.bossArtId(abyssTier(run), run.zonesPerTier),
    );
    final unlocked =
        stored.abyssUnlocked ||
        (clientJson['abyssUnlocked'] == true && finalKilled);
    final current = abyssWeekId(t, config.battle);
    final clientWeek = clientJson['abyssWeek'] as String?;
    final week = clientWeek == current || clientWeek == stored.abyssWeek
        ? clientWeek
        : (stored.abyssWeek ?? (unlocked ? current : null));
    final base = week != null && week == stored.abyssWeek
        ? stored.abyssFloor
        : 1;
    final perFloor = cfg.minSecondsPerFloor <= 0 ? 1.0 : cfg.minSecondsPerFloor;
    // 시간 예산은 서버가 기억하는 기준 시각(`abyssFloorAt`)부터 잰다 — 층을 인정할 때마다
    // 층 수 × perFloor 만큼만 앞으로 민다(남은 몫은 다음 업로드로 이월). 업로드마다 경과를
    // **올림**으로 재면 잘게 쪼개 올릴수록 층이 공짜로 늘었다(1초 × 300번 = 305층).
    final sameWeek = week != null && week == stored.abyssWeek;
    final anchor = sameWeek && stored.abyssFloorAt != null
        ? stored.abyssFloorAt!
        : t.subtract(elapsed);
    // 한 층의 여유(+1)는 둔다 — 층을 막 깬 직후 업로드가 경계에 걸려 정상 유저가 잘리지 않게.
    // 여유를 쓰면 기준 시각이 지금보다 뒤로 밀려 예산이 음수가 되므로, 쪼개 올려도 총 1층
    // 이상 앞설 수 없다.
    final budgetSec = t.difference(anchor).inMilliseconds / 1000;
    final int maxFloor = base + max(0, (budgetSec / perFloor).floor() + 1);
    final clientFloor = (clientJson['abyssFloor'] as num?)?.toInt() ?? 1;
    var floor = clientFloor < 1 ? 1 : clientFloor;
    var clamped = false;
    if (floor > maxFloor) {
      floor = maxFloor;
      clamped = true;
    }
    // 오른 층만큼 기준 시각을 앞으로, **내려간 층만큼은 뒤로** 돌려준다(2026-10-05 쓰러지면 한 칸 아래로).
    // 안 돌려주면 벽에서 쓰러졌다 곧바로 아래 보스를 잡고 복귀하는 정상 유저가, 이미 한 번 인정받은 층을
    // 다시 오를 때마다 예산을 써서 잘린다. 일부러 내려갔다 오르는 건 그대로 0 이라 이득이 없다.
    final steps = floor - base;
    final floorAt = anchor.add(
      Duration(milliseconds: (steps * perFloor * 1000).round()),
    );
    final clientBest = (clientJson['abyssBest'] as num?)?.toInt() ?? 0;
    final best = max(stored.abyssBest, min(clientBest, floor - 1));
    if (clientBest > best) clamped = true;
    final inAbyss = unlocked && clientJson['inAbyss'] == true;
    // 벽 보스 피해(천분율) — 기기 권위라 검증할 수 없다. 범위만 자른다(잡지 못했으면 100% 가 아니다).
    // 층이 잘렸으면 그 층의 기록이 아니므로 버린다.
    final bossBest = clamped
        ? 0
        : ((clientJson['abyssBossBest'] as num?)?.toInt() ?? 0).clamp(0, 999);
    return (
      unlocked: unlocked,
      inAbyss: inAbyss,
      floor: floor,
      best: best,
      bossBest: bossBest,
      week: week,
      clamped: clamped,
      floorAt: week == null ? null : floorAt,
    );
  }

  /// 진행도 랭킹의 심연 값(`profiles.abyss_best`) — **이번 주 지금 깬 층**(2026-10-05 사장님 확정:
  /// 약해져 내려가면 랭킹도 내려간다). 주가 바뀌면 0 부터. 역대 최고(`abyssBest`)는 마일스톤 판정에만 쓴다.
  int abyssRankFloor(SaveGame save) {
    final week = abyssWeekId(now().toUtc(), config.battle);
    if (!save.abyssUnlocked || save.abyssWeek != week) return 0;
    return max(0, save.abyssFloor - 1);
  }

  /// 진행도 랭킹의 심연 값을 새로 적어야 하면 (적을 값, 표식을 찍은 세이브). 이미 적은 값이면 null.
  /// 심연을 연 적 없는 계정은 적지 않는다(늘 0 이다).
  ({int floor, SaveGame save})? abyssRankUpdate(SaveGame save) {
    if (!save.abyssUnlocked) return null;
    final week = abyssWeekId(now().toUtc(), config.battle);
    final floor = abyssRankFloor(save);
    final mark = '$week:$floor';
    if (save.abyssRankMark == mark) return null;
    return (floor: floor, save: save.copyWith(abyssRankMark: mark));
  }

  /// 이번 업로드에서 새로 닿은 심연 마일스톤 수(역대 최고가 `milestoneEvery` 배수를 넘은 수).
  int abyssNewMilestones(SaveGame stored, SaveGame out) {
    final every = config.run.abyss.milestoneEvery;
    if (every <= 0 || out.abyssBest <= stored.abyssBest) return 0;
    return out.abyssBest ~/ every - stored.abyssBest ~/ every;
  }

  /// 저장할 세이브에 **이번 주 점수 기록**을 찍는다. 기록할 (주, 층, 벽 보스 피해)을 돌려준다
  /// (층이 바뀌었거나 — 내려간 것도 — 같은 층에서 벽 보스를 더 깎았을 때만).
  ({SaveGame save, String week, int floor, int boss})? abyssScoreFor(
    SaveGame stored,
    SaveGame save,
  ) {
    final t = now().toUtc();
    final week = abyssWeekId(t, config.battle);
    // 정산 기간(일 09시~월 09시)에는 기록하지 않는다 — 결투 시즌과 같은 시간표(2026-09-29).
    if (seasonClosed(t, config.battle)) return null;
    if (!save.abyssUnlocked || save.abyssWeek != week) return null;
    final sameWeek = stored.abyssWeek == week;
    final before = sameWeek ? stored.abyssFloor : 0;
    // 주간 순위는 **지금 층**이다(2026-10-05 사장님 확정) — 쓰러져 내려가면 기록도 내려간다.
    // 1층은 기록하지 않지만, 이번 주 기록이 있는 채로 1층까지 내려왔으면 1층으로 덮는다(순위에서 빠진다).
    if (save.abyssFloor <= 1 &&
        !(stored.abyssScoreWeek == week && before > 1)) {
      return null;
    }
    final bossBefore = sameWeek && save.abyssFloor == stored.abyssFloor
        ? stored.abyssBossBest
        : -1;
    final changed =
        save.abyssFloor != before || save.abyssBossBest > bossBefore;
    if (!changed && stored.abyssScoreWeek == week) return null;
    return (
      save: save.copyWith(abyssScoreWeek: week),
      week: week,
      floor: save.abyssFloor,
      boss: save.abyssBossBest,
    );
  }

  /// 순위 보상을 아직 판정하지 않은 **끝난 주**가 있으면 그 주 id.
  String? abyssRewardDueWeek(SaveGame save) {
    final played = save.abyssScoreWeek;
    if (played == null || played.isEmpty) return null;
    if (save.abyssRewardWeek == played) return null;
    if (config.run.abyss.rankRewards.isEmpty) return null;
    final t = now().toUtc();
    final current = abyssWeekId(t, config.battle);
    // 이번 주도 집계가 닫혔으면(정산 기간) 바로 준다.
    return played == current && !seasonClosed(t, config.battle) ? null : played;
  }

  /// 심연 주간 순위 보상 — 결투 순위와 같은 구조(순위권 밖이어도 판정 기록은 찍는다).
  ActionResult grantAbyssRankReward(
    SaveGame save,
    String week, {
    int? rank,
    int floor = 0,
    int total = 0,
  }) {
    final jelly = rank == null || floor <= 1
        ? 0
        : config.run.abyss.rankJelly(rank);
    var out = save.copyWith(abyssRewardWeek: week);
    if (jelly > 0) {
      final mats = Map<MaterialKind, int>.from(out.materials);
      mats[MaterialKind.jelly] = (mats[MaterialKind.jelly] ?? 0) + jelly;
      out = out.copyWith(materials: mats);
    }
    return ActionResult.ok(
      out,
      extra: {
        if (jelly > 0)
          'abyssRankReward': {
            'week': week,
            'rank': rank,
            'floor': floor,
            'total': total,
            'jelly': jelly,
          },
      },
    );
  }

  // ── 결투 시즌 순위 보상(2026-09-28) ─────────────────────────────────
  //
  // 대회와 같은 구조다 — cron 없이 **끝난 뒤 첫 업로드에서** 판정한다.
  // 시즌이 끝나면 그 시즌 점수는 더 이상 기록되지 않으므로(기록은 늘 **지금
  // 시즌** 키로 들어간다) 끝난 뒤 조회한 순위가 곧 확정값이다.
  //
  // ⚠️ 순위를 `profiles.trophies` 로 매기지 않는다 — 그 칸은 앱이 직접 쓴다
  // (`supabase_pvp_backend.pushTrophies`). 누구나 99999 를 적을 수 있는 값에
  // 젤리 100 을 걸면 그대로 뚫린다. 점수는 **서버가 결투를 확정할 때만** 적는다.

  /// 결투를 확정한 세이브에 **이번 시즌 점수 기록**을 찍는다. 기록할 시즌 id 를
  /// 함께 돌려준다(호출자가 `pvp_season_scores` 에 쓴다). 기록하지 않으면 null.
  ///
  /// 시즌 정산 전의 세이브(경계를 넘긴 뒤 `/save` 보다 결투가 먼저 온 경우)는
  /// 기록하지 않는다 — 트로피가 **지난 시즌 값**이라, 새 시즌 1위로 들어간다.
  /// 다음 `/save` 가 시즌을 정산한 뒤부터 기록된다.
  ({SaveGame save, String seasonId})? pvpScoreFor(SaveGame save) {
    final cfg = config.battle;
    final t = now().toUtc();
    final start = seasonStartAt(t, cfg);
    final settled = save.seasonStartedAt;
    if (settled == null || settled.isBefore(start)) return null;
    // 정산 기간에는 순위가 굳어 있어야 한다(보상을 이미 받아 간 사람이 있다).
    if (seasonClosed(t, cfg)) return null;
    final sid = seasonIdOf(start, cfg);
    return (save: save.copyWith(pvpScoreSeason: sid), seasonId: sid);
  }

  /// 주간 **리그 결산**이 남았으면 (점수 낸 끝난 시즌, 마지막으로 끝난 시즌), 없으면 null.
  ///
  /// 결산 규칙(2026-09-29 사장님 확정): 리그 = 등급 하나. 점수를 낸 시즌은 **리그 안 순위**로
  /// 보상(리그별 표)과 승강(상위 20% 승급 · 하위 20% 강등)을 정하고, 마지막으로 끝난 시즌을
  /// 쉬었으면 한 단계 강등한다. `pvpRankRewardSeason` = 어디까지 결산했나(서버 소유).
  /// 결투를 한 번도 안 한 유저는 결산할 것이 없다(브론즈에서 떨어질 곳도 없다).
  ({String? played, String lastEnded})? pvpLeagueDue(SaveGame save) {
    final cfg = config.battle;
    final t = now().toUtc();
    final current = seasonIdOf(seasonStartAt(t, cfg), cfg);
    // 정산 기간(일 09시~)이면 이번 시즌, 아니면 지난 시즌이 결산 대상이다(2026-09-29).
    final lastEnded = settleSeasonIdAt(t, cfg);
    if (save.pvpRankRewardSeason == lastEnded) return null;
    final played = save.pvpScoreSeason;
    if (played == null || played.isEmpty) return null;
    final open = played == current && !seasonClosed(t, cfg);
    // ⚠️ 결산 기록에는 "마지막으로 끝난 시즌"을 적는다 — `played != 기록` 으로 비교하면 두 주 이상
    // 쉰 유저에게 옛 시즌 순위 젤리가 매주 다시 나갔다(2026-09-30 점검). 시즌 id 는 날짜라 크기로
    // 비교해 **기록보다 뒤에 점수를 낸 시즌**만 결산한다.
    final settledUpTo = save.pvpRankRewardSeason;
    final pending =
        !open && (settledUpTo == null || played.compareTo(settledUpTo) > 0)
        ? played
        : null;
    return (played: pending, lastEnded: lastEnded);
  }

  /// 리그 결산 — [rank]·[total]·[trophies] 는 [played] 시즌의 **그 리그 안** 기록(없으면 null·0).
  ///
  /// 순위권 밖이어도 결산 기록은 찍는다(안 찍으면 업로드마다 순위를 다시 조회한다).
  /// 트로피 0 은 순위가 있어도 보상·승급이 없다.
  ActionResult settlePvpLeague(
    SaveGame save, {
    String? played,
    required String lastEnded,
    int? rank,
    int total = 0,
    int trophies = 0,
  }) {
    final cfg = config.battle;
    final from = pvpLeagueOf(save, cfg);
    var league = from;
    var jelly = 0;
    if (played != null && rank != null) {
      final id = cfg.leagueAt(from).id;
      jelly = trophies <= 0 ? 0 : cfg.seasonRankJelly(rank, league: id);
      league = cfg.leagueAfterSeason(
        from,
        rank: rank,
        total: total,
        trophies: trophies,
      );
    }
    // 마지막으로 끝난 시즌을 쉬었으면 한 단계 내려간다(여러 주를 쉬어도 한 번만).
    final inactive = played != lastEnded;
    if (inactive && league > 0) league -= 1;
    var out = save.copyWith(pvpRankRewardSeason: lastEnded, pvpLeague: league);
    if (jelly > 0) {
      final mats = Map<MaterialKind, int>.from(out.materials);
      mats[MaterialKind.jelly] = (mats[MaterialKind.jelly] ?? 0) + jelly;
      out = out.copyWith(materials: mats);
    }
    final changed = league != from || jelly > 0;
    return ActionResult.ok(
      out,
      extra: {
        if (changed)
          'pvpLeagueResult': {
            'season': played ?? lastEnded,
            'from': cfg.leagueAt(from).id,
            'to': cfg.leagueAt(league).id,
            'rank': ?rank,
            'total': total,
            'trophies': trophies,
            'jelly': jelly,
            'inactive': inactive,
          },
        // 1.0.13 이하 앱 호환 — 젤리가 있으면 옛 보고서 모양도 싣는다(채택 사유는 `season`).
        if (jelly > 0)
          'pvpRankReward': {
            'season': played,
            'rank': rank,
            'trophies': trophies,
            'total': total,
            'jelly': jelly,
          },
      },
    );
  }

  // ── 회차 종료 보상 ────────────────────────────────────────────────
  //
  // **cron 이 필요 없다.** 회차가 끝나면 점수가 더 이상 바뀌지 않으므로
  // (기간 밖은 도전을 받지 않는다) 종료 후에 조회한 순위는 그 자체로 확정값이다.
  // 유저가 다음에 접속했을 때 판정하면 된다.
  //
  // ⚠️ `/event` 가 아니라 `/save` 에서 돈다. `/event` 는 대회가 닫히면 404 라
  // **끝난 뒤에는 영영 호출되지 않는다** — 지급을 거기 두면 아무도 못 받는다.

  /// 이 세이브가 **아직 못 받은 끝난 회차**가 있으면 그 회차 id, 없으면 null.
  ///
  /// 기준을 `config` 가 아니라 **`save.eventRoundId`(그 유저가 실제로 뛴 회차)**
  /// 로 잡는다. 다음 회차를 열면 `config` 의 회차 id 가 바뀌어 **지난 회차 id 를
  /// 알 방법이 사라지기** 때문이다 — 그 사이 접속하지 않은 사람이 통째로 누락된다.
  String? eventRewardDueRound(SaveGame save) {
    final cfg = config.event;
    if (cfg == null || cfg.rewardTiers.isEmpty) return null;
    final played = save.eventRoundId;
    // 한 판도 안 뛰었으면 줄 것이 없다(참가 보상도 참가한 사람 몫이다).
    if (played == null || played.isEmpty) return null;
    if (save.eventRewardRound == played) return null; // 이미 받았다

    final current = eventRoundId();
    // 다른 회차를 뛴 기록이면 그 회차는 이미 끝났다.
    if (played != current) return played;
    // 같은 회차면 **끝났을 때만** 준다(진행 중에 주면 안 된다).
    return eventOpen ? null : played;
  }

  /// 회차 보상 지급. [rank] 는 순위(1 부터), 순위권 밖이거나 익명이면 null.
  ///
  /// 순위가 없어도 **참가 보상은 준다** — 대회에 나온 사람이 빈손으로 끝나면
  /// 다음 회차에 안 나온다.
  ActionResult grantEventReward(SaveGame save, String roundId, int? rank) {
    final cfg = config.event;
    if (cfg == null) return const ActionResult.fail('event_closed');
    final tier = rank == null ? null : cfg.tierForRank(rank);

    final mats = Map<MaterialKind, int>.from(save.materials);
    void add(MaterialKind k, int n) {
      if (n <= 0) return;
      mats[k] = (mats[k] ?? 0) + n;
    }

    add(MaterialKind.jelly, tier?.jelly ?? 0);
    for (final e in (tier?.materials ?? const <MaterialKind, int>{}).entries) {
      add(e.key, e.value);
    }
    // 참가 보상은 순위와 무관하게 누구나. ❌ 젤리는 없다(§2.6 — 참가는
    // 회차마다 반복되는 통로다).
    for (final e in cfg.participationMaterials.entries) {
      add(e.key, e.value);
    }

    // ⚠️ 번호는 **그 유저가 뛴 회차**의 것이다. 이번 설정의 번호를 쓰면, 다음
    // 회차를 연 뒤에 접속한 지난 회차 입상자가 다음 회차 뱃지를 받는다.
    final roundNo = cfg.roundNoOf(roundId);
    // 순위권 밖·익명은 참가 뱃지로 떨어진다(2026-09-15).
    final badge = cfg.badgeFor(rank, roundNo: roundNo);
    final badges = badge == null
        ? save.eventBadges
        : {...save.eventBadges, badge};

    return ActionResult.ok(
      save.copyWith(
        materials: mats,
        eventRewardRound: roundId,
        eventBadges: badges,
      ),
      extra: {
        'eventReward': {
          'roundId': roundId,
          if (rank != null) 'rank': rank,
          'jelly': tier?.jelly ?? 0,
          // 실물은 **안내 대상**이라는 표시일 뿐이다. 국내 거주 여부는 신청
          // 폼에서 운영이 가른다 — 기기 로케일은 바꾸면 그만이라 자격의
          // 근거가 될 수 없다(해외 이용자도 게임 내 보상은 똑같이 받는다).
          'physical': tier?.physical ?? false,
          // ⚠️ 폼 주소를 **서버가 내려준다.** 앱 번들의 event.json 에만 있으면
          // 주소를 넣으려고 스토어 배포·심사를 기다려야 한다(iOS 는 며칠).
          // 서버 재배포만으로 바꿀 수 있어야 한다 — 당첨자가 신청을 못 하는
          // 상황을 빌드 일정에 걸어둘 수는 없다.
          if ((tier?.physical ?? false) && cfg.prizeFormUrl.isNotEmpty)
            'prizeFormUrl': cfg.prizeFormUrl,
          if (badge != null) 'badge': badge,
          // 순위표·채팅에 실을 **대표** 뱃지. 새로 받은 것을 그대로 쓰면
          // 1회차 챔피언이 2회차 참가 뱃지로 내려앉는다.
          'displayBadge': bestEventBadge(badges),
          if (roundNo > 0) 'roundNo': roundNo,
          'materials': {
            for (final e in {
              ...?tier?.materials,
              ...cfg.participationMaterials,
            }.entries)
              e.key.key:
                  (tier?.materials[e.key] ?? 0) +
                  (cfg.participationMaterials[e.key] ?? 0),
          },
        },
      },
    );
  }

  /// 이미 보상을 받은 회차에 **뱃지가 하나도 없으면** 참가 뱃지를 채운다.
  /// 채울 게 없으면 null.
  ///
  /// 참가 뱃지는 1회차가 끝난 **뒤에** 생겼다(2026-09-15). 그 전에 보상을 받아
  /// 간 순위권 밖 참가자는 [eventRewardDueRound] 가 다시 잡지 않으므로(이미
  /// 받았다) 여기서 한 번 채운다. 뱃지가 하나라도 있으면 손대지 않는다 —
  /// 입상자에게 참가 뱃지를 겹쳐 줄 이유가 없다.
  ActionResult? backfillEventBadge(SaveGame save) {
    final cfg = config.event;
    if (cfg == null) return null;
    final paid = save.eventRewardRound;
    if (paid == null || paid.isEmpty) return null;
    final roundNo = cfg.roundNoOf(paid);
    final badge = cfg.participantBadgeId(roundNo);
    if (badge == null) return null;
    final has = save.eventBadges.any(
      (b) => parseEventBadge(b)?.round == roundNo,
    );
    if (has) return null;
    final badges = {...save.eventBadges, badge};
    return ActionResult.ok(
      save.copyWith(eventBadges: badges),
      extra: {'eventBadges': true, 'displayBadge': bestEventBadge(badges)},
    );
  }

  /// 명예의 전당이 보여줄 회차 — **가장 최근에 끝난** 회차. 없으면 null.
  EventRound? eventLastEndedRound() => config.event?.lastEndedRound(now());

  /// 아직 열리지 않은 이번 회차(개막 전이면). 열렸거나 끝났으면 null.
  EventRound? eventUpcomingRound() {
    final cfg = config.event;
    if (cfg == null || !cfg.notYetOpen(now())) return null;
    return cfg.currentRound;
  }

  /// **젤리로** 참가권 [EventConfig.ticketAdGrant] 장(2026-09-01 전환).
  ///
  /// 예전엔 무료(하루 상한만)였다 — 상한만 걸린 공짜라 대회 참가가 사실상
  /// 무제한이었고, 순위가 "얼마나 자주 켰나"로 갈렸다. 젤리를 쓰게 하면
  /// 도전 한 번이 선택이 되고, 젤리에 소비처가 하나 더 생긴다(§2.6).
  ///
  /// 하루 상한은 **그대로 둔다** — 젤리만 있으면 무한히 도전해 순위를
  /// 돈으로 사는 구조가 되면 실물 경품이 걸린 대회로서 성립하지 않는다.
  /// 상한은 결제자에게도 동일하다(§2.6 P2W 금지).
  ///
  /// ⚠️ 젤리는 서버 소유 필드가 아니다(유저가 버는 값이라 소유할 수 없다).
  /// 그래서 **차감분을 세이브에 써서 돌려주고**, 앱이 그 세이브를 채택한다 —
  /// 참가권(서버 소유)과 젤리(클라 소유)를 한 응답에 같이 실어야 어긋나지 않는다.
  ActionResult grantEventAdTicket(SaveGame save) {
    final cfg = config.event;
    if (cfg == null) return const ActionResult.fail('event_closed');
    if (cfg.ticketAdGrant <= 0) return const ActionResult.fail('disabled');
    final t = now().toUtc();
    final today = dailyDateKey(t);
    final used = save.adUseCount(kAdFeatureEventTicket, today);
    if (cfg.ticketAdDailyLimit > 0 && used >= cfg.ticketAdDailyLimit) {
      return const ActionResult.fail('ad_limit');
    }
    final cur = eventTicketsNow(save);
    if (cur.tickets >= cfg.ticketMax) {
      return const ActionResult.fail('ticket_full');
    }
    final cost = cfg.ticketJelly;
    final have = save.materialCount(MaterialKind.jelly);
    if (cost > 0 && have < cost) {
      return const ActionResult.fail('no_jelly');
    }
    final mats = Map<MaterialKind, int>.from(save.materials);
    if (cost > 0) mats[MaterialKind.jelly] = have - cost;
    final counts = save.adUseDate == today
        ? Map<String, int>.from(save.adUseCounts)
        : <String, int>{};
    counts[kAdFeatureEventTicket] = used + 1;
    final next = cur.tickets + cfg.ticketAdGrant;
    return ActionResult.ok(
      save.copyWith(
        eventTickets: next > cfg.ticketMax ? cfg.ticketMax : next,
        eventTicketsAt: cur.at,
        materials: mats,
        adUseCounts: counts,
        adUseDate: today,
      ),
      extra: {'tickets': next, 'adUsed': used + 1, 'jellySpent': cost},
    );
  }

  /// 이벤트 팀을 **이벤트 규격**으로 환산한다(개체 스탯은 쓰지 않는다).
  /// [buffs] 는 카드로 쌓인 강화.
  ({List<BattleBug> units, String? error}) _eventUnits(
    SaveGame save,
    List<String> teamIds,
    Map<String, Species> speciesById,
    EventConfig cfg,
    EventBuffs buffs,
  ) {
    final byId = {for (final b in save.bugs) b.id: b};
    final units = <BattleBug>[];
    for (final id in teamIds) {
      final bug = byId[id];
      if (bug == null) return (units: const [], error: 'bad_team');
      final sp = speciesById[bug.speciesId];
      if (sp == null) return (units: const [], error: 'unknown_species');
      final n = cfg.normalized(sp.grade);
      units.add(
        buildEventBug(
          bug: bug,
          species: sp,
          locale: 'ko',
          hp: n.hp * (1 + buffs.maxHp),
          atk: n.atk * (1 + buffs.atk),
          def: n.def * (1 + buffs.def),
          spd: n.spd,
        ),
      );
    }
    return (units: units, error: null);
  }

  WaveEnemySpec _eventSpec(EventConfig cfg) => WaveEnemySpec(
    baseHp: cfg.enemyBaseHp,
    baseAtk: cfg.enemyBaseAtk,
    baseDef: cfg.enemyBaseDef,
    baseSpd: cfg.enemyBaseSpd,
    growth: cfg.enemyGrowth,
    count: cfg.enemyCount,
  );

  /// 웨이브 하나를 치른다. [hpIn] 이 null 이면 만피로 시작.
  ({bool won, List<double> hp, int rounds}) _runOneWave(
    EventConfig cfg,
    int seed,
    int wave,
    List<BattleBug> units,
    List<double>? hpIn,
  ) {
    final st = initBattle(
      seed + wave * 7919,
      units,
      eventWaveEnemies(seed, wave, _eventSpec(cfg)),
      initialHpA: hpIn,
      maxRounds: kMaxEventRounds,
    );
    var guard = 0;
    while (!st.done && guard < kMaxEventRounds * 2) {
      st.step();
      guard++;
    }
    final r = st.toResult();
    return (
      won: r.outcome == BattleOutcome.teamA,
      hp: [...st.hpA],
      rounds: r.rounds,
    );
  }

  static double _hpPct(List<double> hp, List<BattleBug> units) {
    var max = 0.0;
    for (final u in units) {
      max += u.maxHp;
    }
    if (max <= 0) return 0;
    var cur = 0.0;
    for (final v in hp) {
      cur += v;
    }
    final r = cur / max;
    return r < 0 ? 0 : (r > 1 ? 1 : r);
  }

  /// **이벤트 도전 시작.** 참가권을 깎고 **1웨이브만** 치른다.
  ///
  /// 판 전체를 한 번에 돌리지 않는 이유: 웨이브를 깰 때마다 **카드를 고르게**
  /// 하기 때문이다(로그라이크). 그 선택이 다음 웨이브 계산에 들어가므로
  /// 서버가 진행 상태를 세션으로 들고 있어야 한다.
  ///
  /// 거부: `event_closed` · `no_ticket` · `bad_team` · `not_adult` · `fatigued`.
  ActionResult eventStart(
    SaveGame save, {
    required List<String> teamIds,
    required Map<String, Species> speciesById,
  }) {
    // 2회차부터 곤충 1마리 · 결투 엔진(eventDuelStart). 구버전 앱이 옛 규칙으로 뛰지 못하게 닫는다.
    if (config.event?.duelMode ?? false) {
      return const ActionResult.fail('event_update', status: 426);
    }
    final cfg = config.event;
    if (cfg == null) return const ActionResult.fail('event_closed');
    final t = now().toUtc();
    // 기간 밖이면 시작할 수 없다 — 진행 중이던 판은 끝까지 갈 수 있게 둔다
    // (마지막 순간에 시작한 유저의 판을 중간에 끊으면 참가권만 날아간다).
    if (!cfg.isOpen(t)) return const ActionResult.fail('event_closed');

    if (teamIds.length != 3 || teamIds.toSet().length != 3) {
      return const ActionResult.fail('bad_team');
    }
    final byId = {for (final b in save.bugs) b.id: b};
    for (final id in teamIds) {
      final bug = byId[id];
      if (bug == null) return const ActionResult.fail('bad_team');
      if (effectiveStage(bug.stage, bug.stageSince, t, config.pet) !=
          LifeStage.adult) {
        return const ActionResult.fail('not_adult');
      }
      if (save.eventOnFatigue(id, t)) {
        return const ActionResult.fail('fatigued');
      }
    }

    final cur = eventTicketsNow(save);
    if (cur.tickets <= 0) return const ActionResult.fail('no_ticket');

    const buffs = EventBuffs();
    final built = _eventUnits(save, teamIds, speciesById, cfg, buffs);
    if (built.error != null) return ActionResult.fail(built.error!);

    final roundId = cfg.roundIdAt(t);
    final seed = EventConfig.roundSeedOf(roundId);
    final w = _runOneWave(cfg, seed, 1, built.units, null);

    // 클리어 회복은 다음 웨이브로 넘어갈 때 적용한다(엔진과 같은 규칙).
    final hp = [...w.hp];
    if (w.won && cfg.waveHealPct > 0) {
      for (var i = 0; i < hp.length && i < built.units.length; i++) {
        if (hp[i] > 0) {
          final m = built.units[i].maxHp;
          final v = hp[i] + m * cfg.waveHealPct;
          hp[i] = v > m ? m : v;
        }
      }
    }

    // 출전 피로는 **시작 시점**에 건다 — 도중에 앱을 꺼서 피하지 못하게.
    final fatigue = save.prunedEventFatigue(t);
    final until = t.add(Duration(hours: cfg.fatigueHours));
    for (final id in teamIds) {
      fatigue[id] = until;
    }

    final cleared = w.won ? 1 : 0;
    final done = !w.won;
    final score = cfg.score(
      clearedWaves: cleared,
      hpPct: 1,
      survivors: hp.where((v) => v > 0).length,
      totalRounds: w.rounds,
    );

    var out = save.copyWith(
      eventTickets: cur.tickets - 1,
      eventTicketsAt: cur.at,
      eventFatigue: fatigue,
      eventRoundId: roundId,
    );
    var isBest = false;
    if (done) {
      final prevBest = save.eventBestScoreIn(roundId);
      isBest = score > prevBest;
      out = out.copyWith(
        eventBestWave: isBest ? cleared : save.eventBestWave,
        eventBestScore: isBest ? score : prevBest,
      );
    }

    return ActionResult.ok(
      out,
      extra: {
        'roundId': roundId,
        'seed': seed,
        'wave': 1,
        'won': w.won,
        'hp': hp,
        'cleared': cleared,
        'done': done,
        'score': score,
        'isBest': isBest,
        'session': {
          'roundId': roundId,
          'seed': seed,
          'teamIds': teamIds,
          'hp': hp,
          'wave': 1,
          'cleared': cleared,
          'rounds': w.rounds,
          'hpPct': 1.0,
          'buffs': buffs.toJson(),
          'done': done,
        },
        'cards': w.won
            ? [
                for (final c in cfg.drawCards(seed, 1))
                  {'id': c.id, 'kind': c.kind, 'value': c.value},
              ]
            : const [],
        'tickets': cur.tickets - 1,
      },
    );
  }

  // ── 왕충 선발대회: 곤충 1마리 · 결투 엔진 웨이브전(2026-09-29 사장님 확정, 2회차부터) ──────────
  //
  // 규칙은 core_battle `event_duel.dart` 한 곳(앱 재생·개발자 체험과 같은 함수). 서버는 세션에
  // 진행 상태(EventDuelRun)를 들고 판마다 확정한다 — 결투 `/duel/throw` 와 같은 구조.
  // 출전 피로 대신 **결투 부상**: 시작할 때 미리 건다(도중에 앱을 꺼서 피하지 못하게).

  /// 대회 웨이브 설정(`event.json → duelWave`).
  EventDuelSpec get eventDuelSpec =>
      EventDuelSpec.fromJson(config.event?.duelWaveJson);

  /// 대회용 결투 수치 — `duelWave.statCompress` 가 있으면 결투 값을 덮어쓴다(앱과 같은 함수).
  DuelParams get eventDuelParams => eventDuelParamsOf(
    clutchTestUser
        ? {...config.battle.duelJson, 'clutchEnabled': true}
        : config.battle.duelJson,
    eventDuelSpec,
  );

  /// 웨이브 [wave] 의 적 — 모습(종)은 회차 seed 로 고른다(앱과 같은 순서: 종 id 정렬).
  DuelBug eventDuelEnemyOf(
    int roundSeed,
    int wave,
    Map<String, Species> speciesById,
  ) {
    final ids = speciesById.keys.toList()..sort();
    final spId = eventWaveSpeciesId(roundSeed, wave, 0, ids) ?? '';
    return eventDuelEnemy(
      roundSeed: roundSeed,
      wave: wave,
      spec: eventDuelSpec,
      speciesId: spId,
      specialty: speciesById[spId]?.specialty ?? Specialty.strike,
    );
  }

  /// 대회 도전 시작 — 곤충 1마리. 참가권 −1 · 그 곤충 부상(등급별) · 세션 생성.
  ///
  /// 거부: `event_closed` · `no_ticket` · 편성 검증 사유(`bug_not_owned` · `bug_injured` ·
  /// `not_adult` · `bug_training` · `bug_forged:*` …).
  ActionResult eventDuelStart(
    SaveGame save, {
    required String bugId,
    required Map<String, Species> speciesById,
    required PetConfig petConfig,
    EnhanceConfig? enhance,
  }) {
    final cfg = config.event;
    if (cfg == null || !cfg.duelMode) {
      return const ActionResult.fail('event_closed');
    }
    final t = now().toUtc();
    if (!cfg.isOpen(t)) return const ActionResult.fail('event_closed');
    final v = validateDuelTeam(
      save,
      [bugId],
      speciesById: speciesById,
      petConfig: petConfig,
      enhance: enhance,
      teamSize: 1,
    );
    if (v.error != null) return ActionResult.fail(v.error!);
    // 대회 부상은 서버 소유(`eventFatigue` 를 대회 부상 기록으로 다시 쓴다). `injured` 는 앱이
    // 젤리로 지우는 필드라 세이브를 고치면 최강 곤충으로 계속 도전할 수 있었다(2026-09-30 점검).
    if (save.eventOnFatigue(bugId, t)) {
      return const ActionResult.fail('bug_injured');
    }
    final cur = eventTicketsNow(save);
    if (cur.tickets <= 0) return const ActionResult.fail('no_ticket');

    final bug = save.bugs.firstWhere((b) => b.id == bugId);
    final grade = speciesById[bug.speciesId]!.grade;
    final until = t.add(Duration(seconds: petConfig.injuryDuration(grade)));
    final injured = Map<String, DateTime>.from(save.injured)..[bugId] = until;
    final eventInjured = save.prunedEventFatigue(t)..[bugId] = until;
    final roundId = cfg.roundIdAt(t);
    final roundSeed = EventConfig.roundSeedOf(roundId);
    // ⚠️ 추측 불가능한 난수 — 시각(마이크로초)으로 만들면 응답의 부상 시각에서 그대로 복원돼
    // 게이지 결과를 미리 볼 수 있었다(2026-09-30 점검).
    final seed = (rngFactory ?? Random.secure)().nextInt(0x7fffffff);
    const run = EventDuelRun();
    // 회차가 바뀌면 최고 기록을 비운다 — 안 비우면 1회차 점수(옛 단위 1,200만)가 남아
    // 2회차 점수(수만)가 영영 "최고 기록 아님"이 되어 순위표에 안 올라간다.
    final newRound = save.eventRoundId != roundId;
    final out = save.copyWith(
      eventTickets: cur.tickets - 1,
      eventTicketsAt: cur.at,
      eventRoundId: roundId,
      eventBestScore: newRound ? 0 : save.eventBestScore,
      eventBestWave: newRound ? 0 : save.eventBestWave,
      injured: injured,
      eventFatigue: eventInjured,
    );
    return ActionResult.ok(
      out,
      extra: {
        'roundId': roundId,
        'roundSeed': roundSeed,
        'bug': v.team.first.toJson(),
        'run': run.toJson(),
        'tickets': cur.tickets - 1,
        'session': {
          'roundId': roundId,
          'roundSeed': roundSeed,
          'seed': seed,
          'bugId': bugId,
          'run': run.toJson(),
          'cards': const <String>[],
          'done': false,
        },
      },
    );
  }

  /// 대회 한 판 — 카드가 걸려 있으면 [cardId] 를 먼저 적용하고, 지금 웨이브를 [launch] 로 싸운다.
  /// 끝나면 점수를 확정한다(`done`·`score`·`isBest`).
  ///
  /// 거부: `session_done` · `card_required` · `bad_card` · 편성 사유(곤충이 사라졌으면 `bug_not_owned`).
  ActionResult eventDuelThrow(
    SaveGame save, {
    required Map<String, dynamic> session,
    required double launch,
    String? cardId,
    required Map<String, Species> speciesById,
    required PetConfig petConfig,
    EnhanceConfig? enhance,
    bool clutch = false,
  }) {
    final cfg = config.event;
    if (cfg == null) return const ActionResult.fail('event_closed');
    if (session['done'] == true) return const ActionResult.fail('session_done');
    // 지난 회차(또는 기간 밖)에 연 판은 더 싸우지 못한다 — 그만하기로만 닫는다(기록 없음).
    if (!_eventSessionLive(session)) {
      return const ActionResult.fail('event_closed');
    }
    // 위기에서 멈춘 판이 있으면 그 점수부터(`/event/duel/clutch`).
    if (session['cl'] is Map) {
      return const ActionResult.fail('clutch_pending', status: 409);
    }
    final spec = eventDuelSpec;
    var run = EventDuelRun.fromJson(
      Map<String, dynamic>.from(session['run'] as Map),
    );
    final offered = [
      for (final c in (session['cards'] as List? ?? const [])) '$c',
    ];
    if (offered.isNotEmpty) {
      if (cardId == null || cardId.isEmpty) {
        return const ActionResult.fail('card_required');
      }
      if (!offered.contains(cardId)) return const ActionResult.fail('bad_card');
      final card = cfg.cardById(cardId);
      if (card == null) return const ActionResult.fail('bad_card');
      run = run.applyCard(card.kind, card.value, spec);
    }
    return _eventDuelResolve(
      save,
      session: session,
      run: run,
      launch: launch.isFinite ? launch.clamp(0.0, 1.0).toDouble() : 0.0,
      clutchScores: clutch ? const <double>[] : null,
      speciesById: speciesById,
      petConfig: petConfig,
      enhance: enhance,
    );
  }

  /// 대회 탭 반격 점수 — 멈춘 위기(세션 `cl.i`)에 [score](0~1)를 넣고 같은 seed·같은 던지기 값으로 그 웨이브를
  /// 처음부터 다시 싸운다(다음 위기 또는 판 끝까지). [index] 가 멈춘 위기 번호와 다르면 거부.
  ActionResult eventDuelClutch(
    SaveGame save, {
    required Map<String, dynamic> session,
    required int index,
    required double score,
    required Map<String, Species> speciesById,
    required PetConfig petConfig,
    EnhanceConfig? enhance,
  }) {
    if (config.event == null) return const ActionResult.fail('event_closed');
    if (session['done'] == true) return const ActionResult.fail('session_done');
    if (!_eventSessionLive(session)) {
      return const ActionResult.fail('event_closed');
    }
    final cl = session['cl'];
    if (cl is! Map) return const ActionResult.fail('no_clutch', status: 409);
    if ((cl['i'] as num?)?.toInt() != index) {
      return const ActionResult.fail('clutch_index', status: 409);
    }
    final sc = score.isFinite ? score.clamp(0.0, 1.0).toDouble() : 0.0;
    return _eventDuelResolve(
      save,
      session: session,
      // 카드는 멈추기 전에 이미 적용해 세션 run 에 넣어 두었다.
      run: EventDuelRun.fromJson(
        Map<String, dynamic>.from(session['run'] as Map),
      ),
      launch: (cl['l'] as num).toDouble(),
      clutchScores: [
        for (final e in (cl['s'] as List? ?? const [])) (e as num).toDouble(),
        sc,
      ],
      speciesById: speciesById,
      petConfig: petConfig,
      enhance: enhance,
    );
  }

  /// 지금 웨이브를 [run](카드 적용 뒤)·[launch]·[clutchScores] 로 싸운다. 내 곤충 위기에서 멈추면 진행을
  /// 넘기지 않고 세션에 `cl`(던지기 값·점수 목록·위기 번호)을 남긴다. 끝나면 카드·점수를 확정한다.
  ActionResult _eventDuelResolve(
    SaveGame save, {
    required Map<String, dynamic> session,
    required EventDuelRun run,
    required double launch,
    required List<double>? clutchScores,
    required Map<String, Species> speciesById,
    required PetConfig petConfig,
    EnhanceConfig? enhance,
  }) {
    final cfg = config.event!;
    final spec = eventDuelSpec;
    final roundSeed = (session['roundSeed'] as num).toInt();
    final bugId = '${session['bugId']}';
    final v = validateDuelTeam(
      save,
      [bugId],
      speciesById: speciesById,
      petConfig: petConfig,
      enhance: enhance,
      allowInjured: true,
      teamSize: 1,
    );
    if (v.error != null) return ActionResult.fail(v.error!);

    DuelBout? bout;
    var won = false;
    // 건너뛰기 카드로 상한에 닿았으면 싸우지 않고 끝.
    if (!run.over) {
      final step = eventDuelFight(
        seed: (session['seed'] as num).toInt(),
        run: run,
        bug: v.team.first,
        enemy: eventDuelEnemyOf(roundSeed, run.wave, speciesById),
        params: eventDuelParams,
        spec: spec,
        launch: launch,
        clutchScores: clutchScores,
      );
      final stop = step.bout.pending;
      if (stop != null) {
        // 내 곤충 위기 — 진행(run)은 그대로, 카드는 이미 썼다. 앱은 여기까지 재생하고 탭 게이지를 띄운다.
        return ActionResult.ok(
          save,
          extra: {
            'bout': step.bout.toJson(),
            'won': false,
            'run': run.toJson(),
            'cleared': run.cleared,
            'cards': const <Map<String, dynamic>>[],
            'done': false,
            'score': 0,
            'isBest': false,
            'clutch': duelClutchJson(stop, 0),
            'session': {
              ...session,
              'run': run.toJson(),
              'cards': const <String>[],
              'done': false,
              'cl': {
                'l': launch,
                's': clutchScores ?? const <double>[],
                'i': stop.index,
              },
            },
          },
        );
      }
      run = step.run;
      bout = step.bout;
      won = step.won;
    }
    final done = run.over;
    final cards = !done && won
        ? cfg.drawCards(roundSeed, run.cleared)
        : const <EventCard>[];
    final fin = _eventDuelFinish(
      save,
      session,
      run,
      speciesById: speciesById,
      petConfig: petConfig,
    );
    final score = fin.score;
    final isBest = fin.isBest;
    final out = fin.save;
    return ActionResult.ok(
      out,
      extra: {
        'bout': bout?.toJson(),
        'won': won,
        'run': run.toJson(),
        'cleared': run.cleared,
        'cards': [
          for (final c in cards) {'id': c.id, 'kind': c.kind, 'value': c.value},
        ],
        'done': done,
        'score': score,
        'isBest': isBest,
        'session': {
          ...session,
          'run': run.toJson(),
          'cards': [for (final c in cards) c.id],
          'done': done,
        }..remove('cl'),
      },
    );
  }

  /// 끝난 판의 점수·최고 기록·부상. 끝나지 않았으면 점수만 계산하고 세이브는 그대로.
  ///
  /// 부상 = 등급별 최대 × `injuryRatio(끝 체력)` — **지금부터** 잰다(시작할 때 건 최대 부상을
  /// 대신한다). 그만두면 체력이 남아 덜 쉬고, 바닥나서 끝나면 최대.
  ({SaveGame save, int score, bool isBest}) _eventDuelFinish(
    SaveGame save,
    Map<String, dynamic> session,
    EventDuelRun run, {
    required Map<String, Species> speciesById,
    required PetConfig petConfig,
  }) {
    final cfg = config.event!;
    final score = cfg.score(
      clearedWaves: run.cleared,
      hpPct: run.hpAtEntry,
      survivors: 0,
      totalRounds: run.ticks ~/ duelParams.tickHz,
    );
    if (!run.over) return (save: save, score: score, isBest: false);
    final roundId = '${session['roundId']}';
    final prevBest = save.eventBestScoreIn(roundId);
    // 지난 회차에 연 판을 이번 회차에 끝내면 이번 회차 기록으로 들어갔다(회차 끝 직전에 판을
    // 여러 개 열어 두면 다음 회차 도전이 늘어난다). 판을 연 회차가 지금 회차이고 그 유저가
    // 뛰는 회차일 때만 최고 기록을 고친다. 부상은 그대로 건다.
    final isBest =
        _eventSessionLive(session) &&
        save.eventRoundId == roundId &&
        score > prevBest;
    final bugId = '${session['bugId']}';
    final bug = save.bugs.where((b) => b.id == bugId).firstOrNull;
    final grade = speciesById[bug?.speciesId]?.grade;
    final t = now().toUtc();
    final injured = Map<String, DateTime>.from(save.injured);
    final eventInjured = save.prunedEventFatigue(t);
    if (grade != null) {
      final full = petConfig.injuryDuration(grade);
      final sec = (full * eventDuelSpec.injuryRatio(run.hpPct)).round();
      final until = t.add(Duration(seconds: sec));
      injured[bugId] = until;
      eventInjured[bugId] = until;
    }
    return (
      save: save.copyWith(
        eventBestWave: isBest ? run.cleared : save.eventBestWave,
        eventBestScore: isBest ? score : save.eventBestScore,
        injured: injured,
        eventFatigue: eventInjured,
      ),
      score: score,
      isBest: isBest,
    );
  }

  /// 대회 부상 **젤리 즉시 회복**(§2.7 예외 — 참가권 하루 상한은 그대로라 시간만 산다).
  ///
  /// 대회 부상은 서버 소유(`eventFatigue`)라 앱이 지울 수 없다 — 젤리도 서버가 깎는다.
  /// 결투 부상(`injured`)도 함께 지운다. 거부: `not_injured` · `no_jelly`.
  ActionResult eventHealJelly(
    SaveGame save, {
    required String bugId,
    required PetConfig petConfig,
  }) {
    final t = now().toUtc();
    final until = save.eventFatigue[bugId];
    if (until == null || !t.isBefore(until)) {
      return const ActionResult.fail('not_injured');
    }
    final cost = petConfig.injuryJelly(until.difference(t));
    final have = save.materialCount(MaterialKind.jelly);
    if (have < cost) return const ActionResult.fail('no_jelly');
    final mats = Map<MaterialKind, int>.from(save.materials)
      ..[MaterialKind.jelly] = have - cost;
    return ActionResult.ok(
      save.copyWith(
        materials: mats,
        injured: Map<String, DateTime>.from(save.injured)..remove(bugId),
        eventFatigue: save.prunedEventFatigue(t)..remove(bugId),
      ),
      extra: {'jelly': cost},
    );
  }

  /// [session] 이 지금 열려 있는 회차에서 연 판인가.
  bool _eventSessionLive(Map<String, dynamic> session) =>
      eventOpen && '${session['roundId']}' == eventRoundId();

  /// 대회 **그만하기** — 지금까지의 기록으로 확정한다. 부상은 남은 체력만큼 줄어든다.
  ActionResult eventDuelQuit(
    SaveGame save, {
    required Map<String, dynamic> session,
    required Map<String, Species> speciesById,
    required PetConfig petConfig,
  }) {
    if (config.event == null) return const ActionResult.fail('event_closed');
    if (session['done'] == true) return const ActionResult.fail('session_done');
    final run = EventDuelRun.fromJson(
      Map<String, dynamic>.from(session['run'] as Map),
    ).quit();
    final fin = _eventDuelFinish(
      save,
      session,
      run,
      speciesById: speciesById,
      petConfig: petConfig,
    );
    return ActionResult.ok(
      fin.save,
      extra: {
        'run': run.toJson(),
        'cleared': run.cleared,
        'done': true,
        'score': fin.score,
        'isBest': fin.isBest,
        'session': {
          ...session,
          'run': run.toJson(),
          'cards': const <String>[],
          'done': true,
        }..remove('cl'),
      },
    );
  }

  /// **카드를 고르고 다음 웨이브로.** 판이 끝나면 점수를 확정한다.
  ///
  /// [cardId] 가 이번 웨이브의 후보에 없으면 거부한다 — 원하는 카드를 아무거나
  /// 보낼 수 있으면 로그라이크가 아니라 치트가 된다.
  ActionResult eventPick(
    SaveGame save, {
    required Map<String, dynamic> session,
    required String cardId,
    required Map<String, Species> speciesById,

    /// 다음 웨이브에 **앞세울 곤충**(세션 팀 안의 id). 생략하면 순서 유지.
    ///
    /// 웨이브 사이에 선봉을 바꿀 수 있어야 상성 대응이 된다 — 다음 적 속성을
    /// 미리 보여주는데 편성을 못 바꾸면 그 정보가 쓸모가 없다.
    String? leadBugId,
  }) {
    // 2회차부터 곤충 1마리 · 결투 엔진(eventDuelStart). 구버전 앱이 옛 규칙으로 뛰지 못하게 닫는다.
    if (config.event?.duelMode ?? false) {
      return const ActionResult.fail('event_update', status: 426);
    }
    final cfg = config.event;
    if (cfg == null) return const ActionResult.fail('event_closed');
    if (session['done'] == true) return const ActionResult.fail('session_done');

    final seed = (session['seed'] as num).toInt();
    final wave = (session['wave'] as num).toInt();
    final teamIds = (session['teamIds'] as List).map((e) => '$e').toList();
    final roundId = '${session['roundId']}';

    // 선봉 교체 — **순서만 바꾼다.** 곤충을 새로 넣을 수는 없다(출전 피로를
    // 우회해 쉬는 곤충을 끌어오는 길이 되면 안 된다).
    var hpOrder = (session['hp'] as List)
        .map((e) => (e as num).toDouble())
        .toList();
    if (leadBugId != null && leadBugId != teamIds.first) {
      final at = teamIds.indexOf(leadBugId);
      // 없는 id 이거나 이미 쓰러진 자리는 무시한다.
      if (at > 0 && at < hpOrder.length && hpOrder[at] > 0) {
        final id = teamIds.removeAt(at);
        teamIds.insert(0, id);
        final hp = hpOrder.removeAt(at);
        hpOrder.insert(0, hp);
      }
    }

    // 이번 웨이브에 실제로 제시된 카드만 받는다.
    EventCard? card;
    for (final c in cfg.drawCards(seed, wave)) {
      if (c.id == cardId) card = c;
    }
    if (card == null) return const ActionResult.fail('bad_card');

    var buffs = EventBuffs.fromJson(
      (session['buffs'] as Map?)?.cast<String, dynamic>(),
    );
    var hp = hpOrder;
    var cleared = (session['cleared'] as num).toInt();
    var rounds = (session['rounds'] as num).toInt();

    final skipNext = card.kind == 'skip';
    if (!skipNext && card.kind != 'heal' && card.kind != 'revive') {
      buffs = buffs.plus(card.kind, card.value);
    }

    final built = _eventUnits(save, teamIds, speciesById, cfg, buffs);
    if (built.error != null) return ActionResult.fail(built.error!);
    final units = built.units;

    // maxHp 를 올렸으면 현재 체력도 같은 비율로 늘린다 — 안 그러면
    // "최대치만 늘고 지금은 그대로"라 체감이 없다.
    if (card.kind == 'maxHp') {
      for (var i = 0; i < hp.length; i++) {
        if (hp[i] > 0) hp[i] = hp[i] * (1 + card.value);
      }
    }
    if (card.kind == 'heal') {
      for (var i = 0; i < hp.length && i < units.length; i++) {
        if (hp[i] > 0) {
          final m = units[i].maxHp;
          final v = hp[i] + m * card.value;
          hp[i] = v > m ? m : v;
        }
      }
    }
    if (card.kind == 'revive') {
      for (var i = 0; i < hp.length && i < units.length; i++) {
        if (hp[i] <= 0) {
          hp[i] = units[i].maxHp * card.value;
          break; // 한 마리만
        }
      }
    }

    final nextWave = wave + 1;
    final hpPctAtEntry = _hpPct(hp, units);

    // ⚠️ 카드까지 반영된 **웨이브 진입 체력**. 앱은 이 값에서 재생을 시작해야
    // 한다 — 직전 웨이브 종료 체력에서 시작하면 회복·부활·최대체력 카드가
    // 재생에 빠져 "살린다를 골랐는데 안 살아난다"가 된다(2026-09-02 제보).
    // 그러면 그림만 어긋나는 게 아니라 **전투 자체가 서버와 갈린다**.
    final entryHp = [...hp];

    bool won;
    if (skipNext) {
      won = true; // 건너뛴 웨이브는 클리어로 친다
    } else {
      final r = _runOneWave(cfg, seed, nextWave, units, hp);
      won = r.won;
      hp = r.hp;
      rounds += r.rounds;
    }
    if (won) cleared = nextWave;

    if (won && cfg.waveHealPct > 0) {
      for (var i = 0; i < hp.length && i < units.length; i++) {
        if (hp[i] > 0) {
          final m = units[i].maxHp;
          final v = hp[i] + m * cfg.waveHealPct;
          hp[i] = v > m ? m : v;
        }
      }
    }

    final done = !won || nextWave >= cfg.maxWave;
    final score = cfg.score(
      clearedWaves: cleared,
      hpPct: hpPctAtEntry,
      survivors: hp.where((v) => v > 0).length,
      totalRounds: rounds,
    );

    var out = save;
    var isBest = false;
    if (done) {
      final prevBest = save.eventBestScoreIn(roundId);
      isBest = score > prevBest;
      out = save.copyWith(
        eventRoundId: roundId,
        eventBestWave: isBest ? cleared : save.eventBestWave,
        eventBestScore: isBest ? score : prevBest,
      );
    }

    return ActionResult.ok(
      out,
      extra: {
        'wave': nextWave,
        'won': won,
        'skipped': skipNext,
        'hp': hp,
        'hpEntry': entryHp,
        'cleared': cleared,
        'done': done,
        'score': score,
        'isBest': isBest,
        'buffs': buffs.toJson(),
        'session': {
          ...session,
          'teamIds': teamIds,
          'wave': nextWave,
          'hp': hp,
          'cleared': cleared,
          'rounds': rounds,
          'hpPct': hpPctAtEntry,
          'buffs': buffs.toJson(),
          'done': done,
        },
        'cards': (!done && won)
            ? [
                for (final c in cfg.drawCards(seed, nextWave))
                  {'id': c.id, 'kind': c.kind, 'value': c.value},
              ]
            : const [],
      },
    );
  }

  /// **이벤트 도전 1회.** 참가권을 깎고, 웨이브를 돌려 점수를 확정한다.
  ///
  /// 거부 사유: `event_closed` · `no_ticket` · `bad_team`(3마리·중복·미보유) ·
  /// `not_adult` · `fatigued`(출전 피로).
  ActionResult eventChallenge(
    SaveGame save, {
    required List<String> teamIds,
    required Map<String, Species> speciesById,
  }) {
    // 2회차부터 곤충 1마리 · 결투 엔진(eventDuelStart). 구버전 앱이 옛 규칙으로 뛰지 못하게 닫는다.
    if (config.event?.duelMode ?? false) {
      return const ActionResult.fail('event_update', status: 426);
    }
    final cfg = config.event;
    if (cfg == null) return const ActionResult.fail('event_closed');
    final t = now().toUtc();
    // ⚠️ 기간 밖이면 받지 않는다. 이 옛 한 판 경로에만 검사가 빠져 있어서,
    // 회차가 끝난 뒤에도 점수를 써 넣을 수 있었다 — 보상은 각자 접속할 때
    // 순위를 확인하므로, 끝난 뒤에 점수가 바뀌면 챔피언이 둘이 될 수 있다.
    if (!cfg.isOpen(t)) return const ActionResult.fail('event_closed');

    if (teamIds.length != 3 || teamIds.toSet().length != 3) {
      return const ActionResult.fail('bad_team');
    }

    final byId = {for (final b in save.bugs) b.id: b};
    final team = <IndividualBug>[];
    for (final id in teamIds) {
      final bug = byId[id];
      if (bug == null) return const ActionResult.fail('bad_team');
      if (effectiveStage(bug.stage, bug.stageSince, t, config.pet) !=
          LifeStage.adult) {
        return const ActionResult.fail('not_adult');
      }
      // 출전 피로 — 같은 3마리로 계속 도전하지 못하게 한다(기획 §3-1).
      if (save.eventOnFatigue(id, t)) {
        return const ActionResult.fail('fatigued');
      }
      team.add(bug);
    }

    final cur = eventTicketsNow(save);
    if (cur.tickets <= 0) return const ActionResult.fail('no_ticket');

    // 정규화 — 개체 스탯을 쓰지 않는다. 앱과 **같은 함수**(buildEventBug).
    final units = <BattleBug>[];
    for (final bug in team) {
      final sp = speciesById[bug.speciesId];
      if (sp == null) return const ActionResult.fail('unknown_species');
      final n = cfg.normalized(sp.grade);
      units.add(
        buildEventBug(
          bug: bug,
          species: sp,
          locale: 'ko',
          hp: n.hp,
          atk: n.atk,
          def: n.def,
          spd: n.spd,
        ),
      );
    }

    final roundId = cfg.roundIdAt(t);
    final seed = EventConfig.roundSeedOf(roundId);
    final spec = WaveEnemySpec(
      baseHp: cfg.enemyBaseHp,
      baseAtk: cfg.enemyBaseAtk,
      baseDef: cfg.enemyBaseDef,
      baseSpd: cfg.enemyBaseSpd,
      growth: cfg.enemyGrowth,
      count: cfg.enemyCount,
    );
    final run = simulateWaveRun(
      seed: seed,
      team: units,
      enemyOf: (w) => eventWaveEnemies(seed, w, spec),
      maxWave: cfg.maxWave,
      waveHealPct: cfg.waveHealPct,
    );
    final score = cfg.score(
      clearedWaves: run.clearedWaves,
      hpPct: run.hpPctAtLastWave,
      survivors: run.survivors,
      totalRounds: run.totalRounds,
    );

    // 출전 피로 — 이긴 판이든 진 판이든 나갔으면 쉰다.
    final fatigue = save.prunedEventFatigue(t);
    final until = t.add(Duration(hours: cfg.fatigueHours));
    for (final id in teamIds) {
      fatigue[id] = until;
    }

    // 회차가 바뀌었으면 지난 기록을 끌고 오지 않는다.
    final prevBest = save.eventBestScoreIn(roundId);
    final isBest = score > prevBest;

    return ActionResult.ok(
      save.copyWith(
        eventTickets: cur.tickets - 1,
        eventTicketsAt: cur.at,
        eventFatigue: fatigue,
        eventRoundId: roundId,
        eventBestWave: isBest ? run.clearedWaves : save.eventBestWave,
        eventBestScore: isBest ? score : prevBest,
      ),
      extra: {
        'roundId': roundId,
        'seed': seed,
        'wave': run.clearedWaves,
        'score': score,
        'best': isBest ? score : prevBest,
        'isBest': isBest,
        'tickets': cur.tickets - 1,
        'fatigueUntil': until.toIso8601String(),
      },
    );
  }
}

/// [GameActions] 가 필요로 하는 설정만 추린 인터페이스 —
/// 테스트에서 가짜 설정을 넣기 쉽게 한다.
abstract interface class GameConfigLike {
  IapConfig get iap;
  BattleConfig get battle;
  RunConfig get run;
  PetConfig get pet;
  EnhanceConfig? get enhance;

  /// 공방 — 화석 조각 증가 상한 계산에만 쓴다(제련 자체는 기기 권위).
  ForgeConfig? get forge;

  /// 미션·선물·일일보상·로드맵 — 방치 보상 루프. 없으면 해당 기능은 서버가 건너뛴다.
  MissionConfig? get mission;
  GiftConfig? get gift;
  DailyConfig? get daily;
  RoadmapConfig? get roadmap;

  /// 도감 — 보스 수집 마일스톤의 화석 증가 허용치 계산에만 쓴다.
  DexConfig? get dex;

  /// 실물 경품 랭킹 이벤트. 없으면 이벤트 API 는 닫힌다.
  EventConfig? get event;

  /// 캐릭터 스킬 — 업로드의 조각 급증 상한·레벨/장착 규칙에만 쓴다(처리는 기기 권위).
  SkillConfig? get skill;

  /// 요정 — 업로드의 등급 가치 급증 상한·요정함 상한에만 쓴다(처리는 기기 권위).
  FairyConfig? get fairy;

  /// 드롭 롤 대상 종 목록.
  List<Species> get speciesList;
}

/// 일반 채집으로 나오는 재료(젤리는 프리미엄이라 제외 — 앱과 동일).
/// 일반 재료 3종은 `game_rules.dart` 한 곳에 있다(앱과 같은 목록이어야 한다).
const _regularMaterials = kRegularMaterials;
