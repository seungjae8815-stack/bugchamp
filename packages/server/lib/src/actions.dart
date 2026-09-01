import 'dart:math';

import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:uuid/uuid.dart';

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
    if (product.type == IapType.starter && save.starterBought) {
      return const ActionResult.fail('already_owned');
    }

    final t = now().toUtc();
    final g = product.grant;
    final mats = Map<MaterialKind, int>.from(save.materials);
    void add(MaterialKind k, int n) {
      if (n > 0) mats[k] = (mats[k] ?? 0) + n;
    }

    add(MaterialKind.jelly, g.jelly);
    add(MaterialKind.chitin, g.chitin);
    add(MaterialKind.mineral, g.mineral);
    add(MaterialKind.sap, g.sap);

    DateTime? passExpiry = save.passExpiresAt;
    if (product.type == IapType.pass) {
      final base = (passExpiry != null && passExpiry.isAfter(t))
          ? passExpiry
          : t;
      passExpiry = base.add(Duration(days: config.iap.passDurationDays));
    }
    // ⚠️ 무한 버프 패스는 오래 서버 쪽에 빠져 있었다 — 앱만 지급하고 있었다
    // (`SaveController.grantPurchase`). 서버 경로로 지급하면 칸이 비어 있어
    // **결제했는데 아무것도 안 켜지는** 상태가 된다. 앱과 같은 규칙으로 맞춘다:
    // 남은 기간이 있으면 이어 붙인다(중복 구매 시 손해 없게).
    DateTime? buffPassExpiry = save.buffPassExpiresAt;
    if (product.type == IapType.buffPass) {
      final base = (buffPassExpiry != null && buffPassExpiry.isAfter(t))
          ? buffPassExpiry
          : t;
      buffPassExpiry = base.add(
        Duration(days: config.iap.buffPassDurationDays),
      );
    }

    return ActionResult.ok(
      save.copyWith(
        gold: addCurrency(save.gold, g.gold),
        materials: mats,
        incubatorCapacity: save.incubatorCapacity + g.incubatorSlots,
        adsRemoved: save.adsRemoved || product.type == IapType.removeAds,
        starterBought: save.starterBought || product.type == IapType.starter,
        ownedSkins: product.skinId == null
            ? save.ownedSkins
            : {...save.ownedSkins, product.skinId!},
        passExpiresAt: passExpiry,
        buffPassExpiresAt: buffPassExpiry,
        redeemedPurchases: {...save.redeemedPurchases, purchaseId},
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
    'ownedSkins',
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
  };

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
  static const _jellySanityFloor = 1000;

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
    final stage = (clientJson['stageNumber'] as num?)?.toInt() ?? 0;
    final highest = stage > stored.stageNumber ? stage : stored.stageNumber;

    var sum = 0;
    for (final ch in chapters) {
      if (claimed.contains(ch.id) &&
          !already.contains(ch.id) &&
          ch.clearedBy(highest)) {
        sum += ch.rewardGold;
      }
    }
    return sum;
  }

  /// 기기 권위 세이브 업로드 병합.
  ///
  /// 솔로 루프(업그레이드·재화·육성·방치·수령)는 **기기가 확정**하고 여기로
  /// 올린다. 서버는 두 가지만 강제한다:
  ///  1. **보호 필드**(트로피·IAP)를 서버 저장본 값으로 덮는다 — 세이브 편집으로
  ///     랭킹·결제 상태를 위조하지 못하게.
  ///  2. 골드가 **말도 안 되게** 뛰면(1→10억) 상식 상한으로 자른다.
  /// PvP 전투·결제의 실제 지급은 별도 서버 액션이 확정한다.
  ActionResult mergeSave(SaveGame stored, Map<String, dynamic> clientJson) {
    final t = now().toUtc();
    var elapsed = t.difference(stored.lastSeen);
    if (elapsed.isNegative) elapsed = Duration.zero;

    final stats = deriveStats(
      config.run,
      upgradeLevels: stored.upgradeLevels,
      characterLevel: stored.level,
      bugsCollected: stored.bugs.length,
    );
    final generous = simulateIdleProgress(
      config: config.run,
      startStage: stored.stageNumber,
      stats: stats,
      elapsed: elapsed,
      efficiency: _saveBoundEfficiency,
      // 회차는 처치 속도(÷3)와 보상(×3)에 서로 반대로 실려 대략 상쇄되지만,
      // 정확히는 아니다 — 봉투가 회차를 모른 채 좁아지면 정당한 수입이 잘린다.
      tier: stored.difficultyTier,
    ).gold;
    final maxGain =
        _goldSanityFloor +
        generous +
        _chapterGrantAllowance(stored, clientJson);

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

    // 골드 상식 상한.
    final clientGold = (merged['gold'] as num?)?.toInt() ?? stored.gold;
    var clamped = false;
    if (clientGold - stored.gold > maxGain) {
      merged['gold'] = stored.gold + maxGain;
      clamped = true;
    }

    // 젤리(프리미엄) 상식 상한 — 결제로 사는 재화라 급증을 막는다.
    final mats = merged['materials'];
    if (mats is Map) {
      final clientJelly =
          (mats['jelly'] as num?)?.toInt() ??
          stored.materialCount(MaterialKind.jelly);
      final storedJelly = stored.materialCount(MaterialKind.jelly);
      if (clientJelly - storedJelly > _jellySanityFloor) {
        mats['jelly'] = storedJelly + _jellySanityFloor;
        clamped = true;
      }

      // 일반 재료도 급증을 막는다 — 여기가 비어 있던 탓에 조작 업로드가
      // 그대로 들어갔다. 감소는 검사하지 않는다(쓰는 건 자유).
      for (final k in _regularMaterials) {
        final client =
            (mats[k.key] as num?)?.toInt() ?? stored.materialCount(k);
        final have = stored.materialCount(k);
        if (client - have > _materialSanityFloor) {
          mats[k.key] = have + _materialSanityFloor;
          clamped = true;
        }
      }

      final clientFossil =
          (mats['fossil'] as num?)?.toInt() ??
          stored.materialCount(MaterialKind.fossil);
      final storedFossil = stored.materialCount(MaterialKind.fossil);
      if (clientFossil - storedFossil > _maxFossilGain) {
        mats['fossil'] = storedFossil + _maxFossilGain;
        clamped = true;
      }
    }
    merged['lastSeen'] = t.toIso8601String();

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
    final capped = enforceStorage(parsed);
    if (capped.bugs.length != parsed.bugs.length ||
        capped.storageCapacity != parsed.storageCapacity ||
        capped.incubatorCapacity != parsed.incubatorCapacity ||
        // ⚠️ 캠페인 끝 접기(`_enforceCampaignEnd`)가 빠져 있었다
        // (2026-09-01 발견). 서버는 1000 으로 접는데 앱은 계속 1078 을 들고
        // 60초마다 다시 올린다 — 화면에도 접히지 않은 값이 그대로 보이고,
        // 서버는 매 업로드마다 같은 일을 반복한다.
        capped.stageNumber != parsed.stageNumber) {
      clamped = true;
    }

    // 시즌 정산은 **서버가 확정한다**. 트로피는 서버 소유 필드라 앱이 혼자
    // 깎아 올려도 위에서 저장본 값으로 덮인다 — 그래서 앱만 리셋하던 시절엔
    // 주간 리셋이 아예 먹지 않았다(2026-08 버그).
    final settled = _settleSeason(stored, clientJson, capped, t);
    return ActionResult.ok(
      settled.save,
      extra: {
        'clamped': clamped,
        'season': settled.report != null,
        // 앱이 "시즌 종료" 다이얼로그를 그대로 띄울 수 있게 내역을 실어준다.
        if (settled.report != null) 'seasonReport': settled.report,
      },
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
    // 모루 위 제련 결과도 상한을 강제한다. 앱은 [kMaxForgeStack] 에서 멈추지만
    // 조작 업로드가 수천 개를 실으면 세이브가 비대해진다 — 곤충 3만 마리
    // 13.6MB 사고(§2.1)와 같은 경로다. 최근 것부터 남긴다.
    if (out.forgeStack.length > kMaxForgeStack) {
      out = out.copyWith(
        forgeStack: out.forgeStack.sublist(
          out.forgeStack.length - kMaxForgeStack,
        ),
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
    final rw = cfg.seasonReward(endTrophies);
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
    double per(BugPart p, double d) => enhance?.spec(p).effectPerLevel ?? d;

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
      team.add(
        buildBattleBug(
          bug: bug,
          species: sp,
          locale: 'ko',
          hornJawPerLevel: per(BugPart.hornJaw, 0.04),
          cuticlePerLevel: per(BugPart.cuticle, 0.04),
          wingPerLevel: per(BugPart.wing, 0.03),
          buildPerLevel: per(BugPart.build, 0.05),
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
    final newBugs = <IndividualBug>[];
    final mats = Map<MaterialKind, int>.from(save.materials);
    final species = config.speciesList;

    // 채집함 여유분까지만 받는다(가득 차면 곤충 획득 차단 — 재료·골드는 계속).
    var bugRoom = save.storageFree;

    // 희귀 천장(§2.1) — 앱과 같은 규칙. 서버가 안 굴리면 방치 정산은
    // 천장이 없는 셈이 되어, 켜 두는 쪽이 손해가 된다.
    var pity = save.rarePity;

    for (var i = 0; i < rolls; i++) {
      final pityDue = run.rarePityKills > 0 && pity >= run.rarePityKills;
      pity++;
      if (species.isNotEmpty &&
          (pityDue || rng.nextDouble() < run.bugDropChance * stats.bugFind)) {
        // 등급 가중치·한정 종 모두 앱과 **같은 함수**로 고른다.
        final sp = pickDropSpecies(
          rng,
          species,
          weights: run.dropGradeWeights,
          now: t,
          minGrade: pityDue ? Grade.rare : null,
        );
        if (sp == null) continue;
        // 되감기는 아래 분기에서 — 실제로 받았거나 필터로 재료가 됐을 때만.
        // 채집함이 가득 차 버려진 롤로 되감으면 천장이 허공에 쓰인다.
        final rarePlus = sp.grade.index >= Grade.rare.index;
        // 앱과 같은 분포: rng*rng 라 고포텐셜이 드물다.
        final potential = 1 + (rng.nextDouble() * rng.nextDouble() * 4).floor();
        // 등급 필터(§2.1)를 **서버도 건다.** 클라이언트만 거르면 구버전 앱·
        // 조작 업로드가 필터를 우회해 칸을 채운다.
        if (!save.acceptsGrade(sp.grade)) {
          // 자동 방생 → 일반 재료. 젤리를 주지 않는 이유는 pets.json 참조.
          // 스킨 계열 보너스(§2.6 — 재료만, 전투 스탯 아님).
          // 근거는 ownedSkins = **서버 소유 필드**라 위조할 수 없다.
          final give = config.iap.skinnedReleaseMaterial(
            config.pet.releaseMaterial(sp.grade),
            save.ownedSkins,
            sp.id,
          );
          if (give > 0) {
            final kind =
                _regularMaterials[rng.nextInt(_regularMaterials.length)];
            mats[kind] = (mats[kind] ?? 0) + give;
          }
          if (rarePlus) pity = 0; // 필터 방생은 유저의 선택 — "나온 것"으로 친다
        } else if (bugRoom > 0) {
          newBugs.add(
            IndividualBug.roll(
              id: _uuid.v4(),
              species: sp,
              rng: rng,
              potential: potential.clamp(1, 5),
              // 이색도 서버가 같은 확률로 굴린다 — 안 굴리면 방치 정산으로
              // 받은 곤충만 이색이 안 나와, 방치가 손해가 된다.
              variantChance: config.pet.variantWildChance,
            ).copyWith(stage: LifeStage.egg, stageSince: t),
          );
          bugRoom--;
          if (rarePlus) pity = 0;
        }
      }
      if (rng.nextDouble() < run.materialDropChance * stats.materialFind) {
        final kind = _regularMaterials[rng.nextInt(_regularMaterials.length)];
        mats[kind] = (mats[kind] ?? 0) + 1 + rng.nextInt(2);
      }
    }

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
      gold: tier.gold,
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
    double per(BugPart p, double d) => enhance?.spec(p).effectPerLevel ?? d;

    // 내 성충 로스터 → 전투 유닛 → 파워 상위 3마리 평균.
    final mine = <BattleBug>[];
    for (final bug in save.bugs) {
      final sp = speciesById[bug.speciesId];
      if (sp == null) continue;
      if (effectiveStage(bug.stage, bug.stageSince, t, petConfig) !=
          LifeStage.adult) {
        continue;
      }
      mine.add(
        buildBattleBug(
          bug: bug,
          species: sp,
          locale: 'ko',
          hornJawPerLevel: per(BugPart.hornJaw, 0.04),
          cuticlePerLevel: per(BugPart.cuticle, 0.04),
          wingPerLevel: per(BugPart.wing, 0.03),
          buildPerLevel: per(BugPart.build, 0.05),
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

  /// 부위 강화 1단계. 재료 비용·상한을 서버가 판정한다.
  ///
  /// 강화는 전투 스탯을 직접 올리므로 PvP 에 바로 영향을 준다.
  /// 클라이언트가 처리하면 재료 없이 만렙 강화가 가능해진다.
  ActionResult enhancePart(
    SaveGame save,
    String bugId,
    BugPart part, {
    required EnhanceConfig enhance,
  }) {
    final idx = save.bugs.indexWhere((b) => b.id == bugId);
    if (idx < 0) return const ActionResult.fail('bug_not_owned');
    final bug = save.bugs[idx];
    if (bug.enhancement.total >= bug.maxLevel) {
      return const ActionResult.fail('at_cap');
    }
    final spec = enhance.spec(part);
    // 등급 배수까지 **앱과 같은 계산**을 써야 한다. 여기만 옛 가격이면
    // 조작한 클라이언트가 이 엔드포인트로 싸게 강화하는 우회로가 된다.
    final grade = config.speciesList
        .where((s) => s.id == bug.speciesId)
        .firstOrNull
        ?.grade;
    final cost = grade == null
        ? spec.costAt(bug.enhancement.levelOf(part))
        : enhance.costFor(part, bug.enhancement.levelOf(part), grade);
    final have = save.materialCount(spec.material);
    if (have < cost) return const ActionResult.fail('insufficient_material');

    final mats = Map<MaterialKind, int>.from(save.materials)
      ..[spec.material] = have - cost;
    final bugs = List<IndividualBug>.from(save.bugs);
    bugs[idx] = bug.copyWith(enhancement: bug.enhancement.incremented(part));
    return ActionResult.ok(
      save.copyWith(bugs: bugs, materials: mats),
      extra: {'cost': cost, 'part': part.key},
    );
  }

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

  /// 깜짝선물 수령. 만료·없음이면 거부. [doubled]=광고 시청 배수.
  ///
  /// ⚠️ [doubled] 는 아직 클라 신뢰다 — AdMob SSV(서버 보상 검증)가 붙기 전까지.
  /// 출시 후 SSV 로 "실제로 광고를 봤는가"를 서버가 확인해야 이 배수를 신뢰한다.
  ActionResult claimGift(SaveGame save, String giftId, {bool doubled = false}) {
    final t = now().toUtc();
    final idx = save.gifts.indexWhere((g) => g.id == giftId);
    if (idx < 0) return const ActionResult.fail('gift_not_found');
    final g = save.gifts[idx];
    final gifts = List<GiftMail>.from(save.gifts)..removeAt(idx);
    // 만료된 선물은 지급하지 않는다(다음 sync 가 정리한다).
    if (g.isExpired(t)) return const ActionResult.fail('gift_expired');
    final mult = doubled ? (config.gift?.adMultiplier ?? 2) : 1;
    final mats = Map<MaterialKind, int>.from(save.materials);
    for (final e in g.materials.entries) {
      mats[e.key] = (mats[e.key] ?? 0) + e.value * mult;
    }
    return ActionResult.ok(
      save.copyWith(
        gold: addCurrency(save.gold, g.gold * mult),
        materials: mats,
        gifts: gifts,
      ),
      extra: {'gold': g.gold * mult, 'doubled': doubled},
    );
  }

  /// 일일보상 수령. **UTC 날짜당 슬롯 1회**만 지급한다.
  ///
  /// 앱은 로컬 벽시계로 "점심 12시/저녁 18시" 게이트를 두지만, 서버는
  /// 클라 타임존을 알 수 없다. 그래서 **시간 게이트는 UI(UX)에 맡기고**,
  /// 서버는 하루에 같은 슬롯을 여러 번 먹는 조작만 막는다(UTC 날짜 중복).
  ActionResult claimDaily(SaveGame save, String rewardId) {
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
    if (save.dailyClaims[rewardId] == today) {
      return const ActionResult.fail('already_claimed');
    }
    final mats = Map<MaterialKind, int>.from(save.materials);
    for (final e in reward.materials.entries) {
      mats[e.key] = (mats[e.key] ?? 0) + e.value;
    }
    final claims = Map<String, String>.from(save.dailyClaims)
      ..[rewardId] = today;
    return ActionResult.ok(
      save.copyWith(
        gold: addCurrency(save.gold, reward.gold),
        materials: mats,
        dailyClaims: claims,
      ),
      extra: {'gold': reward.gold},
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
      endsAt: t.add(Duration(seconds: petConfig.breedingDuration(sp.grade))),
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
    final reward = petConfig.disassembleJelly(bug.potential);
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
    final cur = regenTickets(
      tickets: save.pvpTickets,
      at: save.ticketsAt,
      now: t,
      cfg: cfg,
    );
    if (cur.tickets >= cfg.ticketMax) {
      return const ActionResult.fail('already_full');
    }
    final paid = spendJelly(save, cfg.ticketRefillJelly, reason: 'pvp_ticket');
    if (!paid.isOk) return paid;
    final next = refillTickets(
      tickets: save.pvpTickets,
      at: save.ticketsAt,
      now: t,
      cfg: cfg,
    );
    return ActionResult.ok(
      paid.save!.copyWith(pvpTickets: next.tickets, ticketsAt: next.at),
      extra: {
        'tickets': next.tickets,
        'ticketsAt': next.at.toIso8601String(),
        'jelly': paid.save!.materialCount(MaterialKind.jelly),
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
    return ActionResult.ok(
      save.copyWith(gold: addCurrency(save.gold, gold), materials: mats),
      extra: {
        'granted': {
          'gold': gold,
          for (final e in grant.entries)
            if (e.value > 0) e.key.key: e.value,
        },
      },
    );
  }

  /// 젤리 소비. 잔액이 모자라면 거부한다 — **클라이언트 말을 믿지 않는다.**
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

    final badge = rank == null ? null : cfg.badgeIdForRank(rank);

    return ActionResult.ok(
      save.copyWith(
        materials: mats,
        eventRewardRound: roundId,
        eventBadges: badge == null
            ? save.eventBadges
            : {...save.eventBadges, badge},
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
          if (cfg.roundNo > 0) 'roundNo': cfg.roundNo,
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
    final cfg = config.event;
    if (cfg == null) return const ActionResult.fail('event_closed');
    final t = now().toUtc();

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

  /// 실물 경품 랭킹 이벤트. 없으면 이벤트 API 는 닫힌다.
  EventConfig? get event;

  /// 드롭 롤 대상 종 목록.
  List<Species> get speciesList;
}

/// 일반 채집으로 나오는 재료(젤리는 프리미엄이라 제외 — 앱과 동일).
/// 일반 재료 3종은 `game_rules.dart` 한 곳에 있다(앱과 같은 목록이어야 한다).
const _regularMaterials = kRegularMaterials;
