import 'dart:math' as math;

import 'package:core_gathering/core_gathering.dart';
import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/save_migrations.dart';
import '../data/save_repository.dart';
import 'gather_service.dart';
import 'gift_mail.dart';
import 'providers.dart';
import 'save_game.dart';

/// 시즌 종료 정산 결과(UI 가 1회 표시). 트로피 소프트리셋 + 보상.
class SeasonReport {
  const SeasonReport({
    required this.peakTrophies,
    required this.rewardGold,
    required this.rewardJelly,
    required this.fromTrophies,
    required this.toTrophies,
  });

  final int peakTrophies;
  final int rewardGold;
  final int rewardJelly;
  final int fromTrophies;
  final int toTrophies;
}

/// 세이브 상태를 보유·변경하는 Riverpod 컨트롤러.
/// 변경 액션은 상태를 갱신하고 즉시 저장소에 반영(자동 저장)한다.
class SaveController extends AsyncNotifier<SaveGame> {
  /// 결제 혜택 일일 젤리 수령 기록용 키(dailyClaims 재사용 — 세이브 필드 추가 없이).
  static const _iapDailyKey = '_iapDaily';

  /// 마지막 로드 시 계산된 오프라인 보상(UI 가 1회 표시 후 [consumeOffline]).
  OfflineReport? pendingOffline;

  /// 마지막 로드 시 정산된 시즌 종료(UI 가 1회 표시 후 [consumeSeason]).
  SeasonReport? pendingSeason;

  @override
  Future<SaveGame> build() async {
    final data = await ref.watch(gameDataProvider.future);
    final repo = ref.watch(saveRepositoryProvider);
    final clock = ref.read(clockProvider);
    var save = await repo.load();
    final now = clock.now().toUtc();

    // 오프라인 정산
    final config = data.runConfig;
    if (config != null) {
      final elapsed = now.difference(save.lastSeen);
      if (elapsed.inSeconds > 60) {
        final stats = deriveStats(
          config,
          upgradeLevels: save.upgradeLevels,
          characterLevel: save.level,
          bugsCollected: save.bugs.length,
        );
        // 곤충학자 패스: 오프라인 상한 연장 + 방치 골드 배율(iap.json §6).
        final iap = data.iapConfig;
        final passOn = save.passActive(now);
        final raw = computeOfflineReward(
          config: config,
          stageNumber: save.stageNumber,
          stats: stats,
          elapsed: elapsed,
          efficiency: config.offlineEfficiency,
          maxAccrual: passOn
              ? Duration(hours: iap?.passOfflineCapHours ?? 12)
              : kMaxOfflineAccrual,
        );
        final report = passOn
            ? OfflineReport(
                gold: (raw.gold * (iap?.passIdleGoldMult ?? 1.2)).round(),
                xp: raw.xp,
                accrued: raw.accrued,
              )
            : raw;
        if (!report.isEmpty) {
          var xp = save.xp + report.xp;
          var level = save.level;
          while (xp >= xpForNextLevel(level)) {
            xp -= xpForNextLevel(level);
            level++;
          }
          save = save.copyWith(
            gold: save.gold + report.gold,
            xp: xp,
            level: level,
          );
          pendingOffline = report;
        }
      }
    }

    // 결제 혜택 일일 젤리(로컬 날짜 기준 1회). 패스가 광고제거보다 우선(중복 지급 금지).
    final iapCfg = data.iapConfig;
    if (iapCfg != null) {
      final today = dailyDateKey(ref.read(clockProvider).now());
      if (save.dailyClaims[_iapDailyKey] != today) {
        final jelly = save.passActive(now)
            ? iapCfg.passDailyJelly
            : (save.adsRemoved ? iapCfg.removeAdsDailyJelly : 0);
        if (jelly > 0) {
          final mats = Map<MaterialKind, int>.from(save.materials)
            ..[MaterialKind.jelly] =
                (save.materials[MaterialKind.jelly] ?? 0) + jelly;
          save = save.copyWith(
            materials: mats,
            dailyClaims: Map<String, String>.from(save.dailyClaims)
              ..[_iapDailyKey] = today,
          );
        }
      }
    }

    // 자가치유: 존재하지 않는 곤충을 가리키는 부화 항목 제거(슬롯 누수 방지).
    if (save.incubating.isNotEmpty) {
      final ids = {for (final b in save.bugs) b.id};
      final pruned = {
        for (final e in save.incubating.entries)
          if (ids.contains(e.key)) e.key: e.value,
      };
      if (pruned.length != save.incubating.length) {
        save = save.copyWith(incubating: pruned);
      }
    }

    // 자가치유: 회복 완료됐거나 존재하지 않는 곤충의 부상 기록 정리.
    if (save.injured.isNotEmpty) {
      final ids = {for (final b in save.bugs) b.id};
      final pruned = {
        for (final e in save.injured.entries)
          if (ids.contains(e.key) && now.isBefore(e.value)) e.key: e.value,
      };
      if (pruned.length != save.injured.length) {
        save = save.copyWith(injured: pruned);
      }
    }

    // 시즌: 시작시각 초기화 + 만료 시 소프트리셋·보상.
    final battleCfg = data.battleConfig;
    if (battleCfg != null) {
      if (save.seasonStartedAt == null) {
        save = save.copyWith(seasonStartedAt: now);
      }
      final start = save.seasonStartedAt!;
      if (now.difference(start).inDays >= battleCfg.seasonDays) {
        final peak = save.seasonPeakTrophies > save.pvpTrophies
            ? save.seasonPeakTrophies
            : save.pvpTrophies;
        final rw = battleCfg.seasonReward(peak);
        final reset = battleCfg.seasonResetTrophies(save.pvpTrophies);
        final mats = Map<MaterialKind, int>.from(save.materials)
          ..[MaterialKind.jelly] =
              (save.materials[MaterialKind.jelly] ?? 0) + rw.jelly;
        pendingSeason = SeasonReport(
          peakTrophies: peak,
          rewardGold: rw.gold,
          rewardJelly: rw.jelly,
          fromTrophies: save.pvpTrophies,
          toTrophies: reset,
        );
        save = save.copyWith(
          gold: save.gold + rw.gold,
          materials: mats,
          pvpTrophies: reset,
          seasonPeakTrophies: reset,
          seasonStartedAt: now,
        );
      }
    }

    save = save.copyWith(lastSeen: now);
    await repo.save(save);
    return save;
  }

  void consumeOffline() => pendingOffline = null;
  void consumeSeason() => pendingSeason = null;

  GatherService get _service => ref.read(gatherServiceProvider);
  SaveRepository get _repo => ref.read(saveRepositoryProvider);

  Future<void> _commit(SaveGame save) async {
    final stamped = save.copyWith(
      lastSeen: ref.read(clockProvider).now().toUtc(),
    );
    state = AsyncData(stamped);
    await _repo.save(stamped);
  }

  /// 슬롯에 트랩 설치/교체 후 저장.
  Future<void> installTrap({
    required int slotIndex,
    required String fieldId,
    required String trapId,
  }) async {
    final updated = _service.installTrap(
      state.requireValue,
      slotIndex: slotIndex,
      fieldId: fieldId,
      trapId: trapId,
    );
    await _commit(updated);
  }

  /// 슬롯 수령. 산출이 있으면 세이브에 반영·저장하고, 획득분을 반환한다.
  Future<GatherYield> collect(int slotIndex) async {
    final result = _service.collect(state.requireValue, slotIndex: slotIndex);
    if (!result.harvest.isEmpty) {
      await _commit(result.save);
    }
    return result.harvest;
  }

  // --- v2 런 액션 ---

  /// 서식지/보스 파괴 보상 반영. 경험치 초과 시 레벨업(넘침 이월).
  Future<void> applyReward({
    required int gold,
    required int xp,
    IndividualBug? bug,
    Map<MaterialKind, int>? materials,
    MissionType? mission,
  }) async {
    final s = state.requireValue;
    var newXp = s.xp + xp;
    var newLevel = s.level;
    while (newXp >= xpForNextLevel(newLevel)) {
      newXp -= xpForNextLevel(newLevel);
      newLevel++;
    }
    final newMaterials = Map<MaterialKind, int>.from(s.materials);
    if (materials != null) {
      for (final e in materials.entries) {
        newMaterials[e.key] = (newMaterials[e.key] ?? 0) + e.value;
      }
    }
    await _commit(
      s.copyWith(
        gold: s.gold + gold,
        xp: newXp,
        level: newLevel,
        materials: newMaterials,
        bugs: bug == null ? null : [...s.bugs, bug],
        missionProgress: mission == null
            ? null
            : _bumpMissions(s.missionProgress, mission, 1),
      ),
    );
  }

  /// **현재 활성 미션 1개만** 진행시킨다(순차 미션). 타입이 맞을 때만 [by] 증가.
  /// 활성 미션 = 총 수집 횟수 % 미션 수 (수집할 때마다 다음 미션으로 넘어감).
  Map<String, int>? _bumpMissions(
    Map<String, int> progress,
    MissionType type,
    int by,
  ) {
    final cfg = ref.read(gameDataProvider).requireValue.missionConfig;
    if (cfg == null || cfg.missions.isEmpty) return null;
    final s = state.requireValue;
    var totalClaims = 0;
    for (final v in s.missionClaims.values) {
      totalClaims += v;
    }
    final active = cfg.missions[totalClaims % cfg.missions.length];
    // reachStage 는 stageNumber 파생이라 카운터를 쓰지 않는다.
    if (active.type != type || active.type == MissionType.reachStage) {
      return null;
    }
    final out = Map<String, int>.from(progress);
    out[active.id] = (out[active.id] ?? 0) + by;
    return out;
  }

  /// 업그레이드를 최대 [count] 레벨까지 구매(골드 되는 만큼). 구매한 레벨 수 반환.
  Future<int> buyUpgrade(UpgradeKind kind, {int count = 1}) async {
    final config = ref.read(gameDataProvider).requireValue.runConfig;
    if (config == null) return 0;
    final s = state.requireValue;
    final spec = config.upgrade(kind);
    final matKind = spec.materialKind;
    var level = s.upgradeLevel(kind);
    var gold = s.gold;
    final mats = Map<MaterialKind, int>.from(s.materials);
    var bought = 0;
    for (var i = 0; i < count; i++) {
      final cost = upgradeCost(spec, level);
      if (gold < cost) break;
      // 골드 외에 재료가 필요한 업그레이드는 재료도 충분해야 구매 가능.
      final matCost = upgradeMaterialCost(spec, level);
      if (matKind != null && (mats[matKind] ?? 0) < matCost) break;
      gold -= cost;
      if (matKind != null && matCost > 0) {
        mats[matKind] = (mats[matKind] ?? 0) - matCost;
      }
      level++;
      bought++;
    }
    if (bought == 0) return 0;
    final levels = Map<UpgradeKind, int>.from(s.upgradeLevels)..[kind] = level;
    await _commit(
      s.copyWith(
        gold: gold,
        upgradeLevels: levels,
        materials: mats,
        missionProgress: _bumpMissions(
          s.missionProgress,
          MissionType.buyUpgrades,
          bought,
        ),
      ),
    );
    return bought;
  }

  /// 미션 [id] 완료 보상 수집. 목표 미달·정의 없음이면 false.
  /// 수집 시 티어(claims)가 1 오르고(→ 목표 상승), 카운터형은 목표만큼 차감(초과분 이월).
  Future<bool> claimMission(String id) async {
    final cfg = ref.read(gameDataProvider).requireValue.missionConfig;
    if (cfg == null) return false;
    MissionDef? def;
    for (final d in cfg.missions) {
      if (d.id == id) {
        def = d;
        break;
      }
    }
    if (def == null) return false;
    final s = state.requireValue;
    final claims = s.missionClaimCount(id);
    final goal = def.goalAt(claims);
    if (s.missionProgressCount(id) < goal) return false;

    // 보상 지급.
    var gold = s.gold;
    final mats = Map<MaterialKind, int>.from(s.materials);
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

    // 티어 +1(다음 미션으로 순환) & 진행도 전체 초기화(다음 미션은 0부터 새로).
    final claimsMap = Map<String, int>.from(s.missionClaims)..[id] = claims + 1;
    await _commit(
      s.copyWith(
        gold: gold,
        materials: mats,
        missionClaims: claimsMap,
        missionProgress: const {},
      ),
    );
    return true;
  }

  /// 도달 스테이지 갱신(최고 기록만).
  Future<void> reachStage(int stage) async {
    final s = state.requireValue;
    if (stage <= s.stageNumber) return;
    await _commit(s.copyWith(stageNumber: stage));
  }

  /// 최고 도달 스테이지 기준으로 **처음 클리어한 챕터**들의 보상을 지급하고,
  /// 새로 클리어한 챕터 목록을 반환한다(UI 축하 팝업용). 없으면 빈 리스트.
  Future<List<RoadmapChapter>> grantChapterClears() async {
    final cfg = ref.read(gameDataProvider).requireValue.roadmapConfig;
    if (cfg == null) return const [];
    final s = state.requireValue;
    final newly = <RoadmapChapter>[];
    for (final ch in cfg.chapters) {
      if (ch.clearedBy(s.stageNumber) && !s.clearedChapters.contains(ch.id)) {
        newly.add(ch);
      }
    }
    if (newly.isEmpty) return const [];
    var gold = s.gold;
    final mats = Map<MaterialKind, int>.from(s.materials);
    final cleared = Set<String>.from(s.clearedChapters);
    for (final ch in newly) {
      gold += ch.rewardGold;
      for (final e in ch.rewardMaterials.entries) {
        mats[e.key] = (mats[e.key] ?? 0) + e.value;
      }
      cleared.add(ch.id);
    }
    await _commit(
      s.copyWith(gold: gold, materials: mats, clearedChapters: cleared),
    );
    return newly;
  }

  /// 온라인 중 주기적으로 호출 → 예정 시각 도달 시 깜짝 선물 1개 지급.
  /// 만료된 선물은 정리한다. 상태가 바뀔 때만 저장.
  Future<void> maybeSpawnGift() async {
    final cfg = ref.read(gameDataProvider).requireValue.giftConfig;
    if (cfg == null) return;
    final now = ref.read(clockProvider).now().toUtc();
    final s = state.requireValue;
    final alive = s.gifts.where((g) => !g.isExpired(now)).toList();
    final prunedAny = alive.length != s.gifts.length;

    // 최초: 첫 선물 예약만.
    if (s.nextGiftAt == null) {
      await _commit(
        s.copyWith(
          gifts: alive,
          nextGiftAt: now.add(Duration(seconds: cfg.firstDelaySec)),
        ),
      );
      return;
    }
    // 아직 예정 시각 전.
    if (now.isBefore(s.nextGiftAt!)) {
      if (prunedAny) await _commit(s.copyWith(gifts: alive));
      return;
    }
    final rng = math.Random();
    final reschedule = now.add(Duration(seconds: cfg.nextIntervalSec(rng)));
    // 가득 찼으면 지급 보류(간격만 재예약).
    if (alive.length >= cfg.maxActive) {
      await _commit(s.copyWith(gifts: alive, nextGiftAt: reschedule));
      return;
    }
    final t = cfg.rollTier(rng);
    final gift = GiftMail(
      id: _devUuid.v4(),
      expiry: now.add(Duration(hours: cfg.expiryHours)),
      gold: t.gold,
      jelly: t.jelly,
      chitin: t.chitin,
      mineral: t.mineral,
      sap: t.sap,
    );
    await _commit(s.copyWith(gifts: [...alive, gift], nextGiftAt: reschedule));
  }

  /// 깜짝 선물 수령. [doubled]=광고 시청 시 배수. 만료/없음이면 false.
  Future<bool> claimGift(String id, {bool doubled = false}) async {
    final cfg = ref.read(gameDataProvider).requireValue.giftConfig;
    final now = ref.read(clockProvider).now().toUtc();
    final s = state.requireValue;
    final idx = s.gifts.indexWhere((g) => g.id == id);
    if (idx < 0) return false;
    final g = s.gifts[idx];
    final gifts = List<GiftMail>.from(s.gifts)..removeAt(idx);
    if (g.isExpired(now)) {
      await _commit(s.copyWith(gifts: gifts));
      return false;
    }
    final mult = doubled ? (cfg?.adMultiplier ?? 2) : 1;
    final mats = Map<MaterialKind, int>.from(s.materials);
    for (final e in g.materials.entries) {
      mats[e.key] = (mats[e.key] ?? 0) + e.value * mult;
    }
    await _commit(
      s.copyWith(gold: s.gold + g.gold * mult, materials: mats, gifts: gifts),
    );
    return true;
  }

  /// 클라우드에서 받은 세이브 JSON 으로 **덮어쓰기** 복원.
  /// 구버전 백업도 마이그레이션을 거치며, 손상 데이터면 false(현재 세이브 유지).
  Future<bool> restoreFromJson(Map<String, dynamic> json) async {
    try {
      final restored = SaveGame.fromJson(migrateToCurrent(json));
      await _commit(restored);
      return true;
    } catch (e) {
      debugPrint('cloud restore failed: $e');
      return false;
    }
  }

  /// 인앱결제 상품 [p] 지급/적용. 성공하면 true.
  ///
  /// - 재화·재료·부화기 슬롯은 `grant` 대로 지급
  /// - `removeAds` → 영구 광고 제거, `starter` → 계정당 1회(중복 구매 방지)
  /// - `skin` → 보유 스킨에 추가, `pass` → 남은 기간에 **이어서** 연장
  ///
  /// 수치는 전부 `iap.json`(IapConfig). 스탯은 지급하지 않는다(§2.6 P2W 금지).
  /// [purchaseId] 는 스토어 구매 1건의 고유 식별자(`PurchaseDetails.purchaseID`).
  /// 주면 **중복 지급을 막는다** — 스토어는 같은 구매를 여러 번 전달할 수 있다
  /// (앱 재시작 시 미완료 구매 재전달, 복원 등). 개발용 로컬 구매는 null.
  Future<bool> applyPurchase(IapProduct p, {String? purchaseId}) async {
    final cfg = ref.read(gameDataProvider).requireValue.iapConfig;
    final now = ref.read(clockProvider).now().toUtc();
    final s = state.requireValue;

    // 이미 지급한 구매면 조용히 성공 처리(스토어에는 완료 통보해야 하므로 true).
    if (purchaseId != null && s.redeemedPurchases.contains(purchaseId)) {
      return true;
    }

    // 스타터는 계정당 1회.
    if (p.type == IapType.starter && s.starterBought) return false;

    final g = p.grant;
    final mats = Map<MaterialKind, int>.from(s.materials);
    void add(MaterialKind k, int n) {
      if (n > 0) mats[k] = (mats[k] ?? 0) + n;
    }

    add(MaterialKind.jelly, g.jelly);
    add(MaterialKind.chitin, g.chitin);
    add(MaterialKind.mineral, g.mineral);
    add(MaterialKind.sap, g.sap);

    // 패스는 남은 기간에 이어서 연장(중복 구매 시 손해 없게).
    DateTime? passExpiry = s.passExpiresAt;
    if (p.type == IapType.pass) {
      final days = cfg?.passDurationDays ?? 30;
      final base = (passExpiry != null && passExpiry.isAfter(now))
          ? passExpiry
          : now;
      passExpiry = base.add(Duration(days: days));
    }

    await _commit(
      s.copyWith(
        gold: s.gold + g.gold,
        materials: mats,
        incubatorCapacity: s.incubatorCapacity + g.incubatorSlots,
        adsRemoved: s.adsRemoved || p.type == IapType.removeAds,
        starterBought: s.starterBought || p.type == IapType.starter,
        ownedSkins: p.skinId == null
            ? s.ownedSkins
            : {...s.ownedSkins, p.skinId!},
        passExpiresAt: passExpiry,
        redeemedPurchases: purchaseId == null
            ? s.redeemedPurchases
            : {...s.redeemedPurchases, purchaseId},
      ),
    );
    return true;
  }

  /// 이미 수령한 선물 [g] 를 광고 보상으로 **한 번 더**(추가 1배) 지급.
  /// "그냥 받기" 후 광고 보고 한 번 더 받기 흐름용(선물은 이미 목록에서 제거됨).
  Future<void> grantGiftBonus(GiftMail g) async {
    final s = state.requireValue;
    final mats = Map<MaterialKind, int>.from(s.materials);
    for (final e in g.materials.entries) {
      mats[e.key] = (mats[e.key] ?? 0) + e.value;
    }
    await _commit(s.copyWith(gold: s.gold + g.gold, materials: mats));
  }

  /// PvP 결과 반영: 승리 시 골드 지급, 트로피 증감(최소 0).
  /// 결투 결과 반영: 골드·트로피 정산 + KO된 내 곤충([koedBugIds])에 부상 회복 타이머 부여.
  Future<void> applyBattleResult({
    required int gold,
    required int trophyDelta,
    List<String> koedBugIds = const [],
  }) async {
    final data = ref.read(gameDataProvider).requireValue;
    final cfg = data.petConfig;
    final now = ref.read(clockProvider).now().toUtc();
    final s = state.requireValue;
    final injured = Map<String, DateTime>.from(s.injured);
    if (cfg != null) {
      for (final id in koedBugIds) {
        final bug = s.bugs.cast<IndividualBug?>().firstWhere(
          (b) => b!.id == id,
          orElse: () => null,
        );
        if (bug == null) continue;
        final sp = data.speciesById[bug.speciesId];
        if (sp == null) continue;
        // 이미 부상 중이면 더 늦은 회복 시각으로 갱신(중복 KO 방어).
        final until = now.add(Duration(seconds: cfg.injuryDuration(sp.grade)));
        final prev = injured[id];
        injured[id] = (prev != null && prev.isAfter(until)) ? prev : until;
      }
    }
    final newTrophies = (s.pvpTrophies + trophyDelta).clamp(0, 1 << 30);
    await _commit(
      s.copyWith(
        gold: s.gold + (gold < 0 ? 0 : gold),
        pvpTrophies: newTrophies,
        seasonPeakTrophies: newTrophies > s.seasonPeakTrophies
            ? newTrophies
            : s.seasonPeakTrophies,
        injured: injured,
      ),
    );
  }

  /// 도달했지만 미수령한 리그 승급 보상을 일괄 수령. 없으면 null,
  /// 있으면 지급한 총 골드·젤리를 반환(UI 다이얼로그용).
  Future<({int gold, int jelly})?> claimLeagueRewards() async {
    final cfg = ref.read(gameDataProvider).requireValue.battleConfig;
    if (cfg == null) return null;
    final s = state.requireValue;
    final claimable = cfg.claimableLeagues(s.pvpTrophies, s.claimedLeagues);
    if (claimable.isEmpty) return null;
    var gold = 0;
    var jelly = 0;
    for (final lg in claimable) {
      gold += lg.rewardGold;
      jelly += lg.rewardJelly;
    }
    final mats = Map<MaterialKind, int>.from(s.materials)
      ..[MaterialKind.jelly] = (s.materials[MaterialKind.jelly] ?? 0) + jelly;
    final claimed = {...s.claimedLeagues, for (final lg in claimable) lg.id};
    await _commit(
      s.copyWith(gold: s.gold + gold, materials: mats, claimedLeagues: claimed),
    );
    return (gold: gold, jelly: jelly);
  }

  /// 부상 회복. [viaJelly] 면 남은 시간 비례 젤리를 소비해 즉시 회복,
  /// 아니면 회복 시각이 지났을 때만 정리. 성공 시 true.
  Future<bool> healInjury(String bugId, {bool viaJelly = false}) async {
    final cfg = ref.read(gameDataProvider).requireValue.petConfig;
    if (cfg == null) return false;
    final now = ref.read(clockProvider).now().toUtc();
    final s = state.requireValue;
    final until = s.injured[bugId];
    if (until == null) return false;
    final injured = Map<String, DateTime>.from(s.injured)..remove(bugId);
    if (viaJelly) {
      if (!now.isBefore(until)) {
        // 이미 회복 완료 → 젤리 없이 정리.
        await _commit(s.copyWith(injured: injured));
        return true;
      }
      final cost = cfg.injuryJelly(until.difference(now));
      final have = s.materials[MaterialKind.jelly] ?? 0;
      if (have < cost) return false;
      final mats = Map<MaterialKind, int>.from(s.materials)
        ..[MaterialKind.jelly] = have - cost;
      await _commit(s.copyWith(injured: injured, materials: mats));
      return true;
    }
    if (now.isBefore(until)) return false; // 아직 회복 안 됨
    await _commit(s.copyWith(injured: injured));
    return true;
  }

  /// 채팅 사용자 차단/해제(로컬). 차단하면 그 사람 메시지가 보이지 않는다.
  ///
  /// 서버에 알리지 않는 이유: 차단당한 쪽이 알면 보복·우회 계정으로 이어진다.
  /// 닉네임이 아니라 계정 id 로 막는다(닉네임은 바꿀 수 있으므로).
  Future<void> setUserBlocked(String userId, bool blocked) async {
    final s = state.requireValue;
    final next = {...s.blockedUserIds};
    if (blocked) {
      next.add(userId);
    } else {
      next.remove(userId);
    }
    await _commit(s.copyWith(blockedUserIds: next));
  }

  /// 게임 데이터 전체 초기화(설정). 저장소를 비우고 새 세이브로 교체.
  Future<void> resetGame() async {
    await _repo.clear();
    final now = ref.read(clockProvider).now().toUtc();
    final fresh = SaveGame.initial(createdAt: now).copyWith(lastSeen: now);
    await _repo.save(fresh);
    pendingOffline = null;
    state = AsyncData(fresh);
  }

  /// 일일보상 수령(편지함). 아직 시간 전·오늘 이미 수령이면 false.
  /// 판정은 **로컬 시각** 기준(점심 12시/저녁 18시).
  Future<bool> claimDaily(DailyReward reward) async {
    final now = ref.read(clockProvider).now(); // 로컬 벽시계
    if (now.hour < reward.hour) return false;
    final today = dailyDateKey(now);
    final s = state.requireValue;
    if (s.dailyClaims[reward.id] == today) return false;
    final mats = Map<MaterialKind, int>.from(s.materials);
    for (final e in reward.materials.entries) {
      mats[e.key] = (mats[e.key] ?? 0) + e.value;
    }
    final claims = Map<String, String>.from(s.dailyClaims)..[reward.id] = today;
    await _commit(
      s.copyWith(
        gold: s.gold + reward.gold,
        materials: mats,
        dailyClaims: claims,
      ),
    );
    return true;
  }

  // ── 개발자(테스트) 전용 ───────────────────────────────────────
  static const _devUuid = Uuid();

  /// (개발) 채집함 비우기(장착 해제 포함).
  Future<void> devClearBugs() async {
    await _commit(
      state.requireValue.copyWith(bugs: const [], equippedBugIds: const []),
    );
  }

  /// (개발) 모든 종을 성충으로 [perSpecies]마리씩 채집함에 추가.
  Future<void> devFillBugs({int perSpecies = 3}) async {
    final data = ref.read(gameDataProvider).requireValue;
    final rng = math.Random();
    final s = state.requireValue;
    final bugs = List<IndividualBug>.from(s.bugs);
    for (final sp in data.allSpecies) {
      for (var i = 0; i < perSpecies; i++) {
        final potential = 1 + (rng.nextDouble() * rng.nextDouble() * 4).floor();
        bugs.add(
          IndividualBug.roll(
            id: _devUuid.v4(),
            species: sp,
            rng: rng,
            potential: potential.clamp(1, 5),
          ),
        );
      }
    }
    await _commit(s.copyWith(bugs: bugs));
  }

  /// (개발) 스테이지 세이브 기록. 라이브 점프는 PlayScreen 에서 처리.
  Future<void> devSetStage(int stage) async {
    final n = stage < 1 ? 1 : stage;
    await _commit(state.requireValue.copyWith(stageNumber: n));
  }

  /// (개발) 재화 추가(음수면 차감).
  Future<void> devAddResources({
    int gold = 0,
    int chitin = 0,
    int mineral = 0,
    int sap = 0,
    int jelly = 0,
    int xp = 0,
  }) async {
    final s = state.requireValue;
    final mats = Map<MaterialKind, int>.from(s.materials);
    void bump(MaterialKind k, int v) {
      if (v != 0) mats[k] = ((mats[k] ?? 0) + v).clamp(0, 1 << 40);
    }

    bump(MaterialKind.chitin, chitin);
    bump(MaterialKind.mineral, mineral);
    bump(MaterialKind.sap, sap);
    bump(MaterialKind.jelly, jelly);
    await _commit(
      s.copyWith(
        gold: (s.gold + gold).clamp(0, 1 << 40),
        xp: (s.xp + xp).clamp(0, 1 << 40),
        materials: mats,
      ),
    );
  }

  /// 광고 시청 등으로 버프를 활성화/연장. 남은 시간에 duration 을 더하되
  /// buffs.json 의 maxSeconds 상한까지만 누적된다.
  Future<void> activateBuff(BuffKind kind) async {
    final buffs = ref.read(gameDataProvider).requireValue.buffConfig;
    if (buffs == null) return;
    final now = ref.read(clockProvider).now().toUtc();
    final s = state.requireValue;
    final current = s.buffExpiry[kind];
    // 이미 활성이면 남은 시간에 이어붙이고, 아니면 지금부터 시작.
    final base = (current != null && current.isAfter(now)) ? current : now;
    var next = base.add(Duration(seconds: buffs.durationSeconds));
    final cap = now.add(Duration(seconds: buffs.maxSeconds));
    if (next.isAfter(cap)) next = cap;
    final updated = Map<BuffKind, DateTime>.from(s.buffExpiry)..[kind] = next;
    await _commit(s.copyWith(buffExpiry: updated));
  }

  /// 만료된 버프 항목을 세이브에서 정리(선택적 위생 관리).
  Future<void> pruneExpiredBuffs() async {
    final now = ref.read(clockProvider).now().toUtc();
    final s = state.requireValue;
    final active = {
      for (final e in s.buffExpiry.entries)
        if (e.value.isAfter(now)) e.key: e.value,
    };
    if (active.length == s.buffExpiry.length) return;
    await _commit(s.copyWith(buffExpiry: active));
  }

  /// 레시피 재료가 충분한지.
  bool canCraft(CraftRecipe recipe) {
    final s = state.requireValue;
    for (final e in recipe.inputs.entries) {
      if (s.materialCount(e.key) < e.value) return false;
    }
    return true;
  }

  /// 제작(§C): 재료를 소비하고 결과 버프를 발동한다. 재료 부족이면 false.
  Future<bool> craft(CraftRecipe recipe) async {
    final buffs = ref.read(gameDataProvider).requireValue.buffConfig;
    if (buffs == null) return false;
    final now = ref.read(clockProvider).now().toUtc();
    final s = state.requireValue;
    for (final e in recipe.inputs.entries) {
      if (s.materialCount(e.key) < e.value) return false;
    }
    // 재료 차감.
    final mats = Map<MaterialKind, int>.from(s.materials);
    for (final e in recipe.inputs.entries) {
      mats[e.key] = (mats[e.key] ?? 0) - e.value;
    }
    // 발동할 버프 목록.
    final targets = recipe.allBuffs
        ? BuffKind.values
        : (recipe.buff != null ? [recipe.buff!] : const <BuffKind>[]);
    final expiry = Map<BuffKind, DateTime>.from(s.buffExpiry);
    for (final k in targets) {
      final current = expiry[k];
      final base = (current != null && current.isAfter(now)) ? current : now;
      var next = base.add(Duration(seconds: buffs.durationSeconds));
      final cap = now.add(Duration(seconds: buffs.maxSeconds));
      if (next.isAfter(cap)) next = cap;
      expiry[k] = next;
    }
    await _commit(s.copyWith(materials: mats, buffExpiry: expiry));
    return true;
  }

  /// 개체 [bugId] 의 [part] 를 1레벨 강화(§2.2). 재료를 차감한다.
  /// 강화 상한(포텐셜×10) 도달·재료 부족·개체 없음이면 false.
  Future<bool> enhancePart(String bugId, BugPart part) async {
    final cfg = ref.read(gameDataProvider).requireValue.enhanceConfig;
    if (cfg == null) return false;
    final s = state.requireValue;
    final idx = s.bugs.indexWhere((b) => b.id == bugId);
    if (idx < 0) return false;
    final bug = s.bugs[idx];
    if (bug.enhancement.total >= bug.maxLevel) return false; // 상한 도달
    final spec = cfg.spec(part);
    final cost = spec.costAt(bug.enhancement.levelOf(part));
    final have = s.materials[spec.material] ?? 0;
    if (have < cost) return false;
    final mats = Map<MaterialKind, int>.from(s.materials)
      ..[spec.material] = have - cost;
    final bugs = List<IndividualBug>.from(s.bugs);
    bugs[idx] = bug.copyWith(enhancement: bug.enhancement.incremented(part));
    await _commit(s.copyWith(bugs: bugs, materials: mats));
    return true;
  }

  /// 수련: 골드를 소비해 성충 [bugId] 의 레벨을 1 올린다.
  /// 성충 아님·티어 상한 도달·돌파 진행중·골드부족·없음이면 false.
  Future<bool> trainBug(String bugId) async {
    final cfg = ref.read(gameDataProvider).requireValue.petConfig;
    if (cfg == null) return false;
    final now = ref.read(clockProvider).now().toUtc();
    final s = state.requireValue;
    final idx = s.bugs.indexWhere((b) => b.id == bugId);
    if (idx < 0) return false;
    final bug = s.bugs[idx];
    if (effectiveStage(bug.stage, bug.stageSince, now, cfg) !=
        LifeStage.adult) {
      return false;
    }
    if (bug.breakthroughEndsAt != null) return false; // 돌파 중엔 수련 불가
    if (bug.level >= cfg.levelCap(bug.breakthroughTier)) return false;
    final cost = cfg.trainCost(bug.level);
    if (s.gold < cost) return false;
    final bugs = List<IndividualBug>.from(s.bugs);
    bugs[idx] = bug.copyWith(level: bug.level + 1);
    await _commit(s.copyWith(gold: s.gold - cost, bugs: bugs));
    return true;
  }

  static const _breakMats = [
    MaterialKind.chitin,
    MaterialKind.mineral,
    MaterialKind.sap,
  ];

  /// 돌파 시작: 티어 상한을 채운 성충의 레벨 상한을 올리는 업그레이드(타이머 시작).
  /// 재화(골드+재료) 소비. 조건 미달이면 false.
  Future<bool> breakthrough(String bugId) async {
    final cfg = ref.read(gameDataProvider).requireValue.petConfig;
    if (cfg == null) return false;
    final now = ref.read(clockProvider).now().toUtc();
    final s = state.requireValue;
    final idx = s.bugs.indexWhere((b) => b.id == bugId);
    if (idx < 0) return false;
    final bug = s.bugs[idx];
    if (effectiveStage(bug.stage, bug.stageSince, now, cfg) !=
        LifeStage.adult) {
      return false;
    }
    if (bug.breakthroughEndsAt != null) return false; // 이미 진행 중
    final tier = bug.breakthroughTier;
    if (tier >= cfg.maxTier) return false; // 최대
    if (bug.level < cfg.levelCap(tier)) return false; // 상한 미달
    final gold = cfg.breakthroughGoldCost(tier);
    final matCost = cfg.breakthroughMatCost(tier);
    if (s.gold < gold) return false;
    for (final k in _breakMats) {
      if ((s.materials[k] ?? 0) < matCost) return false;
    }
    final mats = Map<MaterialKind, int>.from(s.materials);
    for (final k in _breakMats) {
      mats[k] = (mats[k] ?? 0) - matCost;
    }
    final endsAt = now.add(Duration(seconds: cfg.breakthroughDuration(tier)));
    final bugs = List<IndividualBug>.from(s.bugs);
    bugs[idx] = bug.copyWith(breakthroughEndsAt: endsAt);
    await _commit(s.copyWith(gold: s.gold - gold, materials: mats, bugs: bugs));
    return true;
  }

  /// 돌파 완료 수령. [viaJelly]=남은시간 비례 젤리로 즉시완료. 아니면 타이머 종료 후만.
  Future<bool> completeBreakthrough(
    String bugId, {
    bool viaJelly = false,
  }) async {
    final cfg = ref.read(gameDataProvider).requireValue.petConfig;
    if (cfg == null) return false;
    final now = ref.read(clockProvider).now().toUtc();
    final s = state.requireValue;
    final idx = s.bugs.indexWhere((b) => b.id == bugId);
    if (idx < 0) return false;
    final bug = s.bugs[idx];
    final endsAt = bug.breakthroughEndsAt;
    if (endsAt == null) return false;
    final bugs = List<IndividualBug>.from(s.bugs);
    if (viaJelly) {
      final cost = cfg.breakthroughJelly(endsAt.difference(now));
      final have = s.materials[MaterialKind.jelly] ?? 0;
      if (have < cost) return false;
      final mats = Map<MaterialKind, int>.from(s.materials)
        ..[MaterialKind.jelly] = have - cost;
      bugs[idx] = bug.copyWith(
        breakthroughTier: bug.breakthroughTier + 1,
        clearBreakthrough: true,
      );
      await _commit(s.copyWith(bugs: bugs, materials: mats));
    } else {
      if (now.isBefore(endsAt)) return false; // 아직 안 끝남
      bugs[idx] = bug.copyWith(
        breakthroughTier: bug.breakthroughTier + 1,
        clearBreakthrough: true,
      );
      await _commit(s.copyWith(bugs: bugs));
    }
    return true;
  }

  // ── 부화기 ────────────────────────────────────────────────────
  /// 알 [bugId] 를 부화기 슬롯에 넣는다(등급별 시간). 알 아님·슬롯 부족·중복이면 false.
  Future<bool> placeInIncubator(String bugId) async {
    final data = ref.read(gameDataProvider).requireValue;
    final cfg = data.petConfig;
    if (cfg == null) return false;
    final now = ref.read(clockProvider).now().toUtc();
    final s = state.requireValue;
    if (s.incubating.containsKey(bugId)) return false;
    if (s.incubating.length >= s.incubatorCapacity) return false;
    final idx = s.bugs.indexWhere((b) => b.id == bugId);
    if (idx < 0) return false;
    final bug = s.bugs[idx];
    if (effectiveStage(bug.stage, bug.stageSince, now, cfg) != LifeStage.egg) {
      return false;
    }
    final sp = data.speciesById[bug.speciesId];
    if (sp == null) return false;
    final endsAt = now.add(Duration(seconds: cfg.incubateDuration(sp.grade)));
    final inc = Map<String, DateTime>.from(s.incubating)..[bugId] = endsAt;
    await _commit(s.copyWith(incubating: inc));
    return true;
  }

  /// 부화 완료된 알을 수령 → 유충으로. 미완료/없음이면 false.
  Future<bool> collectIncubated(String bugId) async {
    final now = ref.read(clockProvider).now().toUtc();
    final s = state.requireValue;
    final endsAt = s.incubating[bugId];
    if (endsAt == null) return false;
    if (now.isBefore(endsAt)) return false;
    final idx = s.bugs.indexWhere((b) => b.id == bugId);
    if (idx < 0) return false;
    final bugs = List<IndividualBug>.from(s.bugs);
    bugs[idx] = bugs[idx].copyWith(stage: LifeStage.larva, stageSince: now);
    final inc = Map<String, DateTime>.from(s.incubating)..remove(bugId);
    await _commit(s.copyWith(bugs: bugs, incubating: inc));
    return true;
  }

  /// 부화기 슬롯 확장(젤리). 최대치·젤리부족이면 false.
  Future<bool> expandIncubator() async {
    final cfg = ref.read(gameDataProvider).requireValue.petConfig;
    if (cfg == null) return false;
    final s = state.requireValue;
    if (s.incubatorCapacity >= cfg.incubatorSlotsMax) return false;
    final have = s.materials[MaterialKind.jelly] ?? 0;
    if (have < cfg.incubatorExpandJelly) return false;
    final mats = Map<MaterialKind, int>.from(s.materials)
      ..[MaterialKind.jelly] = have - cfg.incubatorExpandJelly;
    await _commit(
      s.copyWith(incubatorCapacity: s.incubatorCapacity + 1, materials: mats),
    );
    return true;
  }

  // ── 브리딩 (§2.5) ─────────────────────────────────────────────
  static const _uuid = Uuid();

  /// 같은 종 ♂+♀ 성충으로 산란 시작(등급별 타이머). 슬롯은 부모 스냅샷만 저장(부모 미잠금).
  /// [seed] 는 UI에서 생성해 주입(자식 롤 결정론). 조건 불충족이면 false.
  Future<bool> startBreeding(String motherId, String fatherId, int seed) async {
    final data = ref.read(gameDataProvider).requireValue;
    final cfg = data.petConfig;
    if (cfg == null || motherId == fatherId) return false;
    final now = ref.read(clockProvider).now().toUtc();
    final s = state.requireValue;
    if (s.breeding.length >= s.breedingCapacity) return false;
    final mother = s.bugs.cast<IndividualBug?>().firstWhere(
      (b) => b!.id == motherId,
      orElse: () => null,
    );
    final father = s.bugs.cast<IndividualBug?>().firstWhere(
      (b) => b!.id == fatherId,
      orElse: () => null,
    );
    if (mother == null || father == null) return false;
    if (mother.speciesId != father.speciesId) return false;
    if (mother.sex != Sex.female || father.sex != Sex.male) return false;
    LifeStage eff(IndividualBug b) =>
        effectiveStage(b.stage, b.stageSince, now, cfg);
    if (eff(mother) != LifeStage.adult || eff(father) != LifeStage.adult) {
      return false;
    }
    final sp = data.speciesById[mother.speciesId];
    if (sp == null) return false;
    final slot = BreedingSlot(
      id: _uuid.v4(),
      speciesId: mother.speciesId,
      parentAvgSizeMm: (mother.sizeMm + father.sizeMm) / 2,
      motherPotential: mother.potential,
      fatherPotential: father.potential,
      endsAt: now.add(Duration(seconds: cfg.breedingDuration(sp.grade))),
      seed: seed,
    );
    await _commit(s.copyWith(breeding: [...s.breeding, slot]));
    return true;
  }

  /// 산란 완료 슬롯 수령 → 자식(알)을 보관함에 추가. [viaJelly]=남은시간 비례 젤리 즉시완료.
  Future<bool> collectBreeding(String slotId, {bool viaJelly = false}) async {
    final data = ref.read(gameDataProvider).requireValue;
    final cfg = data.petConfig;
    if (cfg == null) return false;
    final now = ref.read(clockProvider).now().toUtc();
    final s = state.requireValue;
    final idx = s.breeding.indexWhere((b) => b.id == slotId);
    if (idx < 0) return false;
    final slot = s.breeding[idx];
    final sp = data.speciesById[slot.speciesId];
    if (sp == null) return false;
    var mats = s.materials;
    if (viaJelly) {
      if (now.isBefore(slot.endsAt)) {
        final cost = cfg.breedingJelly(slot.endsAt.difference(now));
        final have = s.materials[MaterialKind.jelly] ?? 0;
        if (have < cost) return false;
        mats = Map<MaterialKind, int>.from(s.materials)
          ..[MaterialKind.jelly] = have - cost;
      }
    } else if (now.isBefore(slot.endsAt)) {
      return false; // 아직 산란 중
    }
    final egg = IndividualBug.breed(
      id: _uuid.v4(),
      species: sp,
      rng: math.Random(slot.seed),
      parentAvgSizeMm: slot.parentAvgSizeMm,
      motherPotential: slot.motherPotential,
      fatherPotential: slot.fatherPotential,
      sizeVariancePct: cfg.breedingSizeVariancePct,
      mutationChance: cfg.breedingMutationChance,
      mutationBonusPct: cfg.breedingMutationBonusPct,
      potUpChance: cfg.breedingPotUpChance,
      potDownChance: cfg.breedingPotDownChance,
    ).copyWith(stageSince: now);
    final breeding = List<BreedingSlot>.from(s.breeding)..removeAt(idx);
    await _commit(
      s.copyWith(bugs: [...s.bugs, egg], breeding: breeding, materials: mats),
    );
    return true;
  }

  /// 브리딩 슬롯 확장(젤리). 최대치·젤리부족이면 false.
  Future<bool> expandBreedingSlots() async {
    final cfg = ref.read(gameDataProvider).requireValue.petConfig;
    if (cfg == null) return false;
    final s = state.requireValue;
    if (s.breedingCapacity >= cfg.breedingSlotsMax) return false;
    final have = s.materials[MaterialKind.jelly] ?? 0;
    if (have < cfg.breedingExpandJelly) return false;
    final mats = Map<MaterialKind, int>.from(s.materials)
      ..[MaterialKind.jelly] = have - cfg.breedingExpandJelly;
    await _commit(
      s.copyWith(breedingCapacity: s.breedingCapacity + 1, materials: mats),
    );
    return true;
  }

  /// 분해: 미장착 곤충 [bugId] 를 없애고 젤리로 환원. 장착/없음이면 false.
  Future<bool> disassembleBug(String bugId) async {
    final s = state.requireValue;
    if (s.isEquipped(bugId)) return false;
    if (s.incubating.containsKey(bugId)) return false; // 부화 중 보호
    final idx = s.bugs.indexWhere((b) => b.id == bugId);
    if (idx < 0) return false;
    final bug = s.bugs[idx];
    // 분해 보상(젤리)은 pets.json 의 PetConfig 계수로 결정(§6). config 없으면 포텐셜만큼.
    final cfg = ref.read(gameDataProvider).requireValue.petConfig;
    final reward = cfg?.disassembleJelly(bug.potential) ?? bug.potential;
    final mats = Map<MaterialKind, int>.from(s.materials)
      ..[MaterialKind.jelly] = (s.materials[MaterialKind.jelly] ?? 0) + reward;
    final bugs = List<IndividualBug>.from(s.bugs)..removeAt(idx);
    await _commit(s.copyWith(bugs: bugs, materials: mats));
    return true;
  }

  /// 진화 촉진: 젤리를 소비해 [bugId] 를 다음 단계로. 성충/젤리부족/없음이면 false.
  Future<bool> accelerateEvolution(String bugId) async {
    final cfg = ref.read(gameDataProvider).requireValue.petConfig;
    if (cfg == null) return false;
    final now = ref.read(clockProvider).now().toUtc();
    final s = state.requireValue;
    final idx = s.bugs.indexWhere((b) => b.id == bugId);
    if (idx < 0) return false;
    final bug = s.bugs[idx];
    final eff = effectiveStage(bug.stage, bug.stageSince, now, cfg);
    if (eff.isFinal) return false;
    final jelly = s.materialCount(MaterialKind.jelly);
    if (jelly < cfg.accelerateJelly) return false;
    final mats = Map<MaterialKind, int>.from(s.materials)
      ..[MaterialKind.jelly] = jelly - cfg.accelerateJelly;
    final bugs = List<IndividualBug>.from(s.bugs);
    bugs[idx] = bug.copyWith(stage: eff.next, stageSince: now);
    await _commit(s.copyWith(bugs: bugs, materials: mats));
    return true;
  }

  /// 합성(★강화): 같은 종의 미장착 곤충 synthFodder마리를 소비해 [targetId] 포텐셜 +1.
  /// 최대 포텐셜 도달·재료 부족이면 false.
  Future<bool> synthesize(String targetId) async {
    final cfg = ref.read(gameDataProvider).requireValue.petConfig;
    if (cfg == null) return false;
    final s = state.requireValue;
    IndividualBug? target;
    for (final b in s.bugs) {
      if (b.id == targetId) {
        target = b;
        break;
      }
    }
    if (target == null || target.potential >= cfg.synthMaxPotential) {
      return false;
    }
    final targetSpeciesId = target.speciesId;
    final fodder = s.bugs
        .where(
          (b) =>
              b.id != targetId &&
              b.speciesId == targetSpeciesId &&
              !s.isEquipped(b.id) &&
              !s.incubating.containsKey(b.id), // 부화 중 보호
        )
        .take(cfg.synthFodder)
        .toList();
    if (fodder.length < cfg.synthFodder) return false;
    final fodderIds = fodder.map((b) => b.id).toSet();
    final bugs = <IndividualBug>[];
    for (final b in s.bugs) {
      if (b.id == targetId) {
        bugs.add(b.copyWith(potential: b.potential + 1));
      } else if (!fodderIds.contains(b.id)) {
        bugs.add(b);
      }
    }
    await _commit(s.copyWith(bugs: bugs));
    return true;
  }

  /// [target] 종으로 합성 가능한(미장착·타깃 제외) 같은 종 재료 수.
  int synthFodderCount(SaveGame s, String targetId, String speciesId) => s.bugs
      .where(
        (b) =>
            b.id != targetId && b.speciesId == speciesId && !s.isEquipped(b.id),
      )
      .length;

  /// 곤충 [bugId] 를 애완펫으로 장착(최대 maxEquip). 이미 장착이면 무시.
  Future<void> equipBug(String bugId) async {
    final petCfg = ref.read(gameDataProvider).requireValue.petConfig;
    final maxEquip = petCfg?.maxEquip ?? 3;
    final s = state.requireValue;
    if (s.isEquipped(bugId)) return;
    if (s.equippedBugIds.length >= maxEquip) return;
    if (!s.bugs.any((b) => b.id == bugId)) return;
    await _commit(s.copyWith(equippedBugIds: [...s.equippedBugIds, bugId]));
  }

  /// 장착 해제.
  Future<void> unequipBug(String bugId) async {
    final s = state.requireValue;
    if (!s.isEquipped(bugId)) return;
    await _commit(
      s.copyWith(
        equippedBugIds: s.equippedBugIds.where((id) => id != bugId).toList(),
      ),
    );
  }

  /// 플레이어 닉네임 변경(공백 트림, 빈 값은 무시).
  Future<void> renamePlayer(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final s = state.requireValue;
    if (trimmed == s.nickname) return;
    await _commit(s.copyWith(nickname: trimmed));
  }
}

final saveControllerProvider = AsyncNotifierProvider<SaveController, SaveGame>(
  SaveController.new,
);
