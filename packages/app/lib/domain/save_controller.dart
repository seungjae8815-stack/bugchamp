import 'dart:math' as math;

import 'package:core_gathering/core_gathering.dart';
import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_run/core_run.dart' as forge_lib show forgeOnce;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:core_save/core_save.dart';
import '../data/game_data.dart';
import '../data/save_repository.dart';
import 'bug_auto_filter.dart';
import 'gather_service.dart';
import 'game_server.dart';
import 'providers.dart';

/// 시즌 종료 정산 결과(UI 가 1회 표시). 트로피 소프트리셋 + 보상.
class SeasonReport {
  const SeasonReport({
    required this.endTrophies,
    required this.rewardGold,
    required this.rewardJelly,
    required this.fromTrophies,
    required this.toTrophies,
  });

  /// 서버가 정산한 시즌 내역(앱을 켜둔 채 경계를 넘긴 경우).
  ///
  /// 앱이 먼저 정산하면 로컬에서 만들지만, 켜둔 채 월요일 09시를 넘기면
  /// **서버가 먼저** 확정한다. 그때도 같은 다이얼로그를 띄우려고 받아온다.
  factory SeasonReport.fromJson(Map<String, dynamic> json) => SeasonReport(
    // 서버는 아직 `peakTrophies` 라는 이름으로 보낼 수 있다(구버전 서버).
    // 둘 다 읽어서 어느 쪽이 와도 화면이 비지 않게 한다.
    endTrophies:
        (json['endTrophies'] as num?)?.toInt() ??
        (json['peakTrophies'] as num?)?.toInt() ??
        0,
    rewardGold: (json['rewardGold'] as num?)?.toInt() ?? 0,
    rewardJelly: (json['rewardJelly'] as num?)?.toInt() ?? 0,
    fromTrophies: (json['fromTrophies'] as num?)?.toInt() ?? 0,
    toTrophies: (json['toTrophies'] as num?)?.toInt() ?? 0,
  );

  /// **시즌이 끝난 순간의** 트로피. 보상은 이 등급으로 계산된다.
  ///
  /// 예전엔 시즌 최고 기록(`seasonPeakTrophies`)으로 줬다. 마지막 날 지는 게
  /// 무섭지 않다는 장점이 있었지만, "지금 내 등급"과 받는 보상이 달라서
  /// 화면으로 설명할 수가 없었다 — 끝나는 순간의 등급으로 통일한다(2026-08-18).
  final int endTrophies;
  final int rewardGold;
  final int rewardJelly;
  final int fromTrophies;
  final int toTrophies;
}

/// 결투 티켓 충전 시도 결과(UI 안내 문구 분기용).
enum TicketCharge {
  ok,

  /// 오늘 광고 시청 상한에 걸렸다(광고제거 구매자도 동일).
  adLimit,

  /// 젤리가 모자란다.
  notEnoughJelly,

  /// 이미 가득 차 있다.
  alreadyFull,

  /// 서버가 거부했거나 통신 실패.
  failed,
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

    // 오프라인 정산 — 기기가 계산한다(기기 권위). 서버는 세이브를 저장만 한다.
    save = _applyOffline(save, data, now);

    // 패스 일일 젤리(로컬 날짜 기준 1회).
    //
    // 광고 제거 패스는 삭제했다(2026-08-18) — 1회 결제로 **매일 젤리 10개를
    // 영구히** 주는 구조라 §2.6("무한히 늘어나는 통로에 젤리 금지")을 정면으로
    // 위반했다. 12개월 보유 시 실질 단가가 젤리 1개당 ₩2.1 까지 떨어졌다.
    // 구매자가 0명이라 회수 문제 없이 지웠다.
    final iapCfg = data.iapConfig;
    if (iapCfg != null) {
      final today = dailyDateKey(ref.read(clockProvider).now());
      if (save.dailyClaims[_iapDailyKey] != today) {
        final jelly = save.passActive(now) ? iapCfg.passDailyJelly : 0;
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

    // 자가치유: 채집함 상한 초과분 정리.
    //
    // 상한 도입 전(2026-08 이전) 세이브에는 곤충이 수만 마리 쌓여 있어 업로드가
    // 통째로 실패했다. 여기서 한 번 잘라내면 그 계정이 정상 크기로 돌아온다.
    // 부화 항목 정리보다 **먼저** 해야 한다 — 잘린 곤충의 부화 기록이 남으면
    // 슬롯이 새기 때문(아래 자가치유가 이어서 걷어낸다).
    save = save.trimmedToStorage();

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

    save = _applySeason(save, data, now);

    save = save.copyWith(lastSeen: now);
    await repo.save(save);
    return save;
  }

  /// 시즌 경계(주간·KST 월 09:00)를 넘겼으면 소프트리셋·보상을 적용한다.
  ///
  /// 앱 시작([build])과 **서버 세이브 채택**([adoptServerSave]) 양쪽에서 부른다.
  /// 채택 뒤에 다시 돌리지 않으면, 시작하자마자 채택이 방금 한 정산을 지워
  /// 트로피가 잠깐 되돌아가고 "시즌 종료" 팝업이 두 번 뜬다.
  /// 최종 확정은 서버가 한다(`GameActions.mergeSave`) — 여기서는 화면용.
  SaveGame _applySeason(SaveGame save, GameData data, DateTime now) {
    final battleCfg = data.battleConfig;
    if (battleCfg != null) {
      // 시즌 경계는 요일·시각 앵커로 **모두에게 같은 순간**이다(주간).
      // 저장된 값은 "내가 마지막으로 정산한 시즌의 시작". 그보다 최근 경계가
      // 지나갔으면 시즌이 끝난 것 — 여러 주를 비워도 한 번만 정산된다.
      final curStart = seasonStartAt(now, battleCfg);
      if (save.seasonStartedAt == null) {
        save = save.copyWith(seasonStartedAt: curStart);
      }
      if (save.seasonStartedAt!.isBefore(curStart)) {
        // **끝나는 순간의 등급**으로 준다. 최고 기록이 아니다.
        final endTrophies = save.pvpTrophies;
        final rw = battleCfg.seasonReward(endTrophies);
        final reset = battleCfg.seasonResetTrophies(save.pvpTrophies);
        final mats = Map<MaterialKind, int>.from(save.materials)
          ..[MaterialKind.jelly] =
              (save.materials[MaterialKind.jelly] ?? 0) + rw.jelly;
        pendingSeason = SeasonReport(
          endTrophies: endTrophies,
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
          seasonStartedAt: curStart,
        );
      }
    }

    return save;
  }

  /// [save.lastSeen] 이후 흐른 시간만큼 방치 보상을 얹은 세이브를 돌려준다.
  /// 보상이 있으면 [pendingOffline] 에 담는다(화면이 1회 팝업으로 보여준다).
  ///
  /// 앱 시작([build])과 **백그라운드 복귀**([settleOffline]) 양쪽에서 쓴다 —
  /// 시작할 때만 정산하면, 앱을 내려놨다가 다시 열었을 때 그 시간이 통째로
  /// 사라진다(실제로 그 버그가 있었다).
  SaveGame _applyOffline(SaveGame save, GameData data, DateTime now) {
    final config = data.runConfig;
    if (config == null) return save;
    final elapsed = now.difference(save.lastSeen);
    if (elapsed.inSeconds <= 60) return save;

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
    if (report.isEmpty) return save;

    var xp = save.xp + report.xp;
    var level = save.level;
    while (xp >= xpForNextLevel(level)) {
      xp -= xpForNextLevel(level);
      level++;
    }
    pendingOffline = report;
    // 화석 조각은 **시간 비례**라 정산된 시간(오프라인 상한이 걸린 값)에 맞춰
    // 준다. 오프라인은 온라인의 1/3 — 켜두는 쪽이 이득이어야 한다.
    var mats = save.materials;
    final forge = data.forgeConfig;
    if (forge != null) {
      final give =
          (report.accrued.inSeconds *
                  forge.fossilPerSecond *
                  forge.fossilOfflineRatio)
              .floor();
      if (give > 0) {
        mats = Map<MaterialKind, int>.from(mats)
          ..[MaterialKind.fossil] = (mats[MaterialKind.fossil] ?? 0) + give;
      }
    }
    return save.copyWith(
      gold: save.gold + report.gold,
      xp: xp,
      level: level,
      materials: mats,
    );
  }

  /// 백그라운드에서 돌아왔을 때 그동안의 방치 보상을 정산한다.
  /// 보상이 생겼으면 true — 호출부가 [pendingOffline] 을 팝업으로 보여준다.
  ///
  /// `_commit` 이 저장할 때마다 `lastSeen` 을 지금으로 찍으므로, 앱이 떠 있는
  /// 동안에는 경과가 쌓이지 않는다(중복 지급 없음).
  Future<bool> settleOffline() async {
    final data = ref.read(gameDataProvider).value;
    final s = state.value;
    if (data == null || s == null) return false;
    final now = ref.read(clockProvider).now().toUtc();
    final settled = _applyOffline(s, data, now);
    if (identical(settled, s)) return false;
    await _commit(settled);
    return pendingOffline != null;
  }

  void consumeOffline() => pendingOffline = null;
  void consumeSeason() => pendingSeason = null;

  GatherService get _service => ref.read(gatherServiceProvider);
  SaveRepository get _repo => ref.read(saveRepositoryProvider);

  Future<void> _commit(SaveGame save) async {
    // 채집함 상한은 **저장되는 모든 경로**에서 지켜져야 한다. 획득 지점마다
    // 막아두긴 했지만, 여기서 한 번 더 자르면 새 획득 경로가 생겨도 세이브가
    // 비대해지지 않는다(상한 이하면 그대로 통과 — 비용 없음).
    final now = ref.read(clockProvider).now().toUtc();
    // 도감(§2.1)도 여기서 갱신한다. 보유 곤충에서 파생되는 **집계**라
    // 획득 지점마다 손으로 기록하면 반드시 한 곳을 빠뜨린다(실시간 처치·
    // 오프라인 정산·짝짓기 수령·서버 세이브 채택 — 경로가 넷이다).
    // 저장 직전에 한 번 훑으면 어느 경로로 들어와도 남는다.
    //
    // ⚠️ 곤충이 **사라지기 전에** 기록되는 게 요점이다 — 상한 정리(trim)와
    // 분해로 개체는 없어지지만 도감 기록은 남아야 한다. 그래서 trim **전에**
    // 훑는다.
    final withDex = _withUpdatedDex(save, now);
    final stamped = withDex.trimmedToStorage().copyWith(lastSeen: now);
    state = AsyncData(stamped);
    await _repo.save(stamped);
  }

  /// 보유 곤충을 훑어 도감을 갱신한 세이브. 바뀐 게 없으면 [save] 그대로.
  SaveGame _withUpdatedDex(SaveGame save, DateTime now) {
    final cfg = ref.read(gameDataProvider).value?.petConfig;
    if (cfg == null || save.bugs.isEmpty) return save;
    final next = updatedDex(
      current: save.dex,
      bugs: save.bugs,
      stageOf: (b) => effectiveStage(b.stage, b.stageSince, now, cfg),
    );
    // identical 이면 저장할 게 없다 — 불필요한 업로드를 만들지 않는다.
    return identical(next, save.dex) ? save : save.copyWith(dex: next);
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
    bool idle = false,
  }) async {
    // 기기 권위 — 아이들 처치 보상도 로컬에서 즉시 반영(재화 즉각 누적).
    // 세이브는 [ServerSaveUploader] 가 주기적으로 올린다. [idle] 은 이제 표시용.
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
    // 채집함이 가득 차면 새 곤충은 **버린다**(획득 차단). 골드·재료·경험치는
    // 그대로 들어온다 — 방치 보상이 통째로 끊기지는 않게.
    final accepted = bug != null && !s.storageFull ? bug : null;
    await _commit(
      s.copyWith(
        gold: s.gold + gold,
        xp: newXp,
        level: newLevel,
        materials: newMaterials,
        bugs: accepted == null ? null : [...s.bugs, accepted],
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
  ///
  /// **기기 권위** — 즉시 로컬 반영(버튼 딜레이 없음). 세이브는 주기 업로드.
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
    final viaServer = await _viaServer(
      () => ref.read(gameServerProvider).claimMission(id),
    );
    if (viaServer != null) return viaServer;

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

  /// 도달 스테이지 갱신(최고 기록만). 기기 권위 — 로컬 즉시 반영.
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
    // 기기 권위 — 선물 스폰도 로컬에서. 세이브는 주기 업로드로 보존된다.
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
    final viaServer = await _viaServer(
      () => ref.read(gameServerProvider).claimGift(id, doubled: doubled),
    );
    if (viaServer != null) return viaServer;

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
    // 무한 버프 패스도 같은 규칙으로 이어 붙인다(칸만 다르다).
    DateTime? buffPassExpiry = s.buffPassExpiresAt;
    if (p.type == IapType.buffPass) {
      final days = cfg?.buffPassDurationDays ?? 30;
      final base = (buffPassExpiry != null && buffPassExpiry.isAfter(now))
          ? buffPassExpiry
          : now;
      buffPassExpiry = base.add(Duration(days: days));
    }

    await _commit(
      s.copyWith(
        gold: s.gold + g.gold,
        materials: mats,
        incubatorCapacity: s.incubatorCapacity + g.incubatorSlots,
        adsRemoved: s.adsRemoved || p.type == IapType.removeAds,
        buffPassExpiresAt: buffPassExpiry,
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

  /// 이미 수령한 일일보상 [reward] 를 광고 보상으로 **한 번 더**(추가 1배) 지급.
  /// 점심/저녁 보상 "광고 보고 한 번 더 받기" 흐름용(로컬 전용 — 선물 보너스와 동일).
  Future<void> grantDailyBonus(DailyReward reward) async {
    final s = state.requireValue;
    final mats = Map<MaterialKind, int>.from(s.materials);
    for (final e in reward.materials.entries) {
      mats[e.key] = (mats[e.key] ?? 0) + e.value;
    }
    await _commit(s.copyWith(gold: s.gold + reward.gold, materials: mats));
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

  /// 공지를 [maxNoticeId] 까지 읽은 것으로 기록(느낌표 해제).
  /// 뒤로 가지 않는다 — 이미 더 큰 값을 읽었으면 그대로 둔다.
  Future<void> markNoticesRead(int maxNoticeId) async {
    final s = state.requireValue;
    if (s.lastReadNoticeId >= maxNoticeId) return;
    await _commit(s.copyWith(lastReadNoticeId: maxNoticeId));
  }

  /// 스토어 리뷰를 요청했다고 기록(계정당 1회만 띄우기 위함).
  ///
  /// ⚠️ 리뷰를 **썼는지**가 아니라 **요청창을 띄웠는지**다. 스토어 API 는 작성
  /// 여부·별점을 알려주지 않으므로 리뷰에 보상을 걸 수 없다(정책상 금지이기도).
  Future<void> markReviewAsked() async {
    final s = state.requireValue;
    if (s.reviewAsked) return;
    await _commit(s.copyWith(reviewAsked: true));
  }

  // ── 결투 티켓 ──
  //
  // 티켓은 **서버 소유**다(GameActions._serverOwnedKeys). 로컬 변경은 화면이
  // 즉시 반응하게 하는 낙관 반영일 뿐이고, 진짜 잔량은 서버가 확정한다
  // (전투는 /battle·/battle/manual/start, 충전은 /pvp/ticket/*).
  // 계산은 core_run 의 순수 함수를 서버와 공유하므로 값이 갈리지 않는다.

  BattleConfig get _battleCfg =>
      ref.read(gameDataProvider).requireValue.battleConfig ??
      const BattleConfig();

  /// 자연 충전을 반영한 **지금 쓸 수 있는** 티켓 수.
  int get ticketsNow {
    final s = state.requireValue;
    return regenTickets(
      tickets: s.pvpTickets,
      at: s.ticketsAt,
      now: ref.read(clockProvider).now().toUtc(),
      cfg: _battleCfg,
    ).tickets;
  }

  /// 다음 티켓 1장까지 남은 시간(가득이면 null).
  Duration? get ticketRemaining {
    final s = state.requireValue;
    final now = ref.read(clockProvider).now().toUtc();
    final cfg = _battleCfg;
    final cur = regenTickets(
      tickets: s.pvpTickets,
      at: s.ticketsAt,
      now: now,
      cfg: cfg,
    );
    return ticketRegenRemaining(
      tickets: cur.tickets,
      at: cur.at,
      now: now,
      cfg: cfg,
    );
  }

  /// 결투 1판분 티켓을 로컬에서 먼저 깎는다(낙관 반영). 없으면 false.
  ///
  /// 서버가 붙어 있으면 전투 요청에서 서버도 같은 계산으로 깎고, 전투 후
  /// `adoptServerSave` 가 서버 값으로 덮는다. 로컬만 깎고 서버 요청이 실패한
  /// 경우를 대비해 [restorePvpTicket] 로 되돌릴 수 있게 해 둔다.
  Future<bool> consumePvpTicket() async {
    final s = state.requireValue;
    final next = consumeTicket(
      tickets: s.pvpTickets,
      at: s.ticketsAt,
      now: ref.read(clockProvider).now().toUtc(),
      cfg: _battleCfg,
    );
    if (next == null) return false;
    await _commit(s.copyWith(pvpTickets: next.tickets, ticketsAt: next.at));
    return true;
  }

  /// 낙관 차감한 티켓을 되돌린다(전투 시작 실패 시).
  /// 서버 값이 진실이므로 여기서 늘려도 다음 전투 때 서버가 다시 확정한다.
  Future<void> restorePvpTicket() async {
    final s = state.requireValue;
    await _commit(s.copyWith(pvpTickets: s.pvpTickets + 1));
  }

  /// 서버가 돌려준 티켓 상태를 로컬에 반영(세이브 왕복 없이 몇 바이트만).
  Future<void> adoptTicketState(Map<String, dynamic> data) async {
    final s = state.requireValue;
    final tickets = (data['tickets'] as num?)?.toInt();
    if (tickets == null) return;
    final at = data['ticketsAt'] == null
        ? s.ticketsAt
        : DateTime.parse(data['ticketsAt'] as String).toUtc();
    final adUsed = (data['adUsed'] as num?)?.toInt();
    final today = dailyDateKey(ref.read(clockProvider).now().toUtc());
    await _commit(
      s.copyWith(
        pvpTickets: tickets,
        ticketsAt: at,
        adUseCounts: adUsed == null
            ? null
            : {
                ...(s.adUseDate == today ? s.adUseCounts : const {}),
                kAdFeaturePvpTicket: adUsed,
              },
        adUseDate: adUsed == null ? null : today,
      ),
    );
  }

  /// 광고 보상 티켓 지급. **광고 시청은 호출부 책임**(`watchAdForReward`).
  ///
  /// 하루 상한은 서버가 센다 — 앱만 세면 세이브를 지우거나 시계를 돌려
  /// 무제한으로 받을 수 있고, 그러면 판수 제한이 무의미해진다.
  Future<TicketCharge> grantAdTickets() async {
    final cfg = _battleCfg;
    final server = ref.read(gameServerProvider);
    if (server.available) {
      final res = await server.pvpTicketAd();
      if (res.isOk) {
        await adoptTicketState(res.data!);
        return TicketCharge.ok;
      }
      return res.error == 'ad_limit'
          ? TicketCharge.adLimit
          : TicketCharge.failed;
    }

    // 서버 미연결(개발·오프라인) — 로컬로 처리한다.
    final now = ref.read(clockProvider).now().toUtc();
    final today = dailyDateKey(now);
    final s = state.requireValue;
    final used = s.adUseCount(kAdFeaturePvpTicket, today);
    if (cfg.ticketAdDailyLimit > 0 && used >= cfg.ticketAdDailyLimit) {
      return TicketCharge.adLimit;
    }
    final next = grantTickets(
      tickets: s.pvpTickets,
      at: s.ticketsAt,
      now: now,
      cfg: cfg,
      amount: cfg.ticketAdGrant,
    );
    await _commit(
      s.copyWith(
        pvpTickets: next.tickets,
        ticketsAt: next.at,
        adUseCounts: {
          ...(s.adUseDate == today ? s.adUseCounts : const {}),
          kAdFeaturePvpTicket: used + 1,
        },
        adUseDate: today,
      ),
    );
    return TicketCharge.ok;
  }

  /// 젤리로 티켓을 상한까지 즉시 충전.
  Future<TicketCharge> refillTicketsWithJelly() async {
    final cfg = _battleCfg;
    final now = ref.read(clockProvider).now().toUtc();
    final s = state.requireValue;
    if (ticketsNow >= cfg.ticketMax) return TicketCharge.alreadyFull;
    final have = s.materialCount(MaterialKind.jelly);
    if (have < cfg.ticketRefillJelly) return TicketCharge.notEnoughJelly;

    final server = ref.read(gameServerProvider);
    if (server.available) {
      // 서버가 먼저 값을 치르고 채운다 — 실패하면 로컬 젤리도 건드리지 않는다.
      final res = await server.pvpTicketRefill();
      if (!res.isOk) {
        return switch (res.error) {
          'insufficient' => TicketCharge.notEnoughJelly,
          'already_full' => TicketCharge.alreadyFull,
          _ => TicketCharge.failed,
        };
      }
      // 젤리는 기기 권위 필드라 **서버가 준 잔액을 받지 않는다**(서버 값이
      // 낡아 최근 획득분이 사라질 수 있다). 같은 비용을 로컬에서 뺀다.
      final s2 = state.requireValue;
      await _commit(
        s2.copyWith(
          materials: Map<MaterialKind, int>.from(s2.materials)
            ..[MaterialKind.jelly] =
                s2.materialCount(MaterialKind.jelly) - cfg.ticketRefillJelly,
        ),
      );
      await adoptTicketState(res.data!);
      return TicketCharge.ok;
    }

    final next = refillTickets(
      tickets: s.pvpTickets,
      at: s.ticketsAt,
      now: now,
      cfg: cfg,
    );
    await _commit(
      s.copyWith(
        pvpTickets: next.tickets,
        ticketsAt: next.at,
        materials: Map<MaterialKind, int>.from(s.materials)
          ..[MaterialKind.jelly] = have - cfg.ticketRefillJelly,
      ),
    );
    return TicketCharge.ok;
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

  /// 서버 권위 모드면 [call] 로 서버에 처리를 맡기고 결과를 채택한다.
  ///
  /// 반환값이 null 이면 서버가 없다는 뜻이므로 호출부가 기존 로컬 경로를 쓴다.
  /// **서버가 있는데 실패한 경우는 false** — 로컬로 폴백하지 않는다.
  /// 폴백하면 "서버가 거부하면 로컬로 처리"가 되어 권위가 무의미해진다.
  /// (구조 전환 2026-07-21) **솔로 루프는 기기 권위**다 — 업그레이드·재화·육성·
  /// 방치·수령을 로컬에서 즉시 처리하고, 서버에는 주기적으로 세이브를 올린다
  /// ([ServerSaveUploader]). 그래서 이 헬퍼는 항상 null 을 돌려주어 호출부가
  /// **로컬 경로**로 떨어지게 한다(즉각 반응). PvP 전투·결제만 서버가 확정한다.
  ///
  /// 서버 액션 메서드(GameServer.upgrade 등)는 서버에 남아 있지만 클라는 쓰지
  /// 않는다 — 나중에 특정 액션만 다시 서버 권위로 돌릴 때를 위한 여지다.
  Future<bool?> _viaServer(Future<ServerResult> Function() call) async => null;

  /// 권위 서버가 확정한 세이브를 그대로 채택한다.
  ///
  /// 서버 권위 모드에서는 **서버가 진실**이므로 로컬 계산 결과를 버리고
  /// 서버 값으로 덮어쓴다. 마이그레이션을 거치는 이유: 서버가 더 낮은
  /// 스키마로 저장돼 있을 수 있다(배포 시점 차이).
  Future<void> adoptServerSave(Map<String, dynamic> json) async {
    final migrated = migrateToCurrent(json);
    var save = SaveGame.fromJson(migrated);
    final data = ref.read(gameDataProvider).value;
    if (data != null) {
      final now = ref.read(clockProvider).now().toUtc();
      // 채택한 세이브가 **아직 정산 전 시즌**일 수 있다(서버는 다음 업로드에서
      // 확정한다). 여기서 한 번 더 돌리지 않으면 시작 직후 트로피가 되돌아간
      // 것처럼 보이고, 60초 뒤 서버 정산이 오면서 팝업이 두 번 뜬다.
      save = _applySeason(save, data, now);
      // ⚠️ **방치 보상도 다시 정산해야 한다.**
      //
      // 서버 세이브의 `lastSeen` 은 마지막 업로드 시점이라 여기도 과거다.
      // 안 돌리면 시작할 때 `build()` 가 계산한 보상이 이 채택으로 통째로
      // 지워지는데(골드가 원래대로 돌아간다), `pendingOffline` 은 남아 있어
      // **받지도 않은 금액을 팝업이 보여준다**(실측: +1,358 표시, 실제 0).
      // `_commit` 이 `lastSeen` 을 지금으로 찍으므로 여기서 놓치면 그 구간은
      // 영영 정산되지 않는다.
      save = _applyOffline(save, data, now);
    }
    await _commit(save);
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
    // 시간 게이트(점심/저녁)는 로컬 UI 판정으로 남긴다 — 서버는 UTC 타임존을
    // 모른다. 서버는 하루에 같은 슬롯을 여러 번 먹는 조작만 막는다.
    if (now.hour < reward.hour) return false;

    final viaServer = await _viaServer(
      () => ref.read(gameServerProvider).claimDaily(reward.id),
    );
    if (viaServer != null) return viaServer;

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
    int fossil = 0,
    int xp = 0,
  }) async {
    final s = state.requireValue;
    final mats = Map<MaterialKind, int>.from(s.materials);
    void bump(MaterialKind k, int v) {
      if (v != 0) mats[k] = ((mats[k] ?? 0) + v).clamp(0, 1 << 40);
    }

    bump(MaterialKind.fossil, fossil);

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

  /// 젤리 [cost] 를 차감한다. 부족하면 false(차감 없음).
  ///
  /// 소액 편의 지출(스카우트 새로고침·버프 젤리 발동)용 공용 경로 —
  /// 기능마다 차감 코드를 복제하면 하나만 검증을 빠뜨리는 날이 온다.
  Future<bool> trySpendJelly(int cost) async {
    if (cost <= 0) return true;
    final s = state.requireValue;
    final have = s.materialCount(MaterialKind.jelly);
    if (have < cost) return false;
    await _commit(
      s.copyWith(
        materials: Map<MaterialKind, int>.from(s.materials)
          ..[MaterialKind.jelly] = have - cost,
      ),
    );
    return true;
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

  /// [recipe] 를 지금 만드는 데 드는 재료(스테이지에 따라 오른다).
  ///
  /// 화면·차감이 **같은 값**을 쓰도록 한곳에서 계산한다 — 어긋나면
  /// "만들 수 있다고 떠서 눌렀는데 실패"가 된다.
  Map<MaterialKind, int> craftInputs(CraftRecipe recipe) {
    final cfg = ref.read(gameDataProvider).value?.craftConfig;
    final stage = state.value?.stageNumber ?? 1;
    return cfg?.inputsAt(recipe, stage) ?? recipe.inputs;
  }

  /// 레시피 재료가 충분한지.
  bool canCraft(CraftRecipe recipe) {
    final s = state.requireValue;
    for (final e in craftInputs(recipe).entries) {
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
    final inputs = craftInputs(recipe);
    for (final e in inputs.entries) {
      if (s.materialCount(e.key) < e.value) return false;
    }
    // 재료 차감.
    final mats = Map<MaterialKind, int>.from(s.materials);
    for (final e in inputs.entries) {
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
    final viaServer = await _viaServer(
      () => ref.read(gameServerProvider).enhance(bugId, part.key),
    );
    if (viaServer != null) return viaServer;

    final cfg = ref.read(gameDataProvider).requireValue.enhanceConfig;
    if (cfg == null) return false;
    final s = state.requireValue;
    final idx = s.bugs.indexWhere((b) => b.id == bugId);
    if (idx < 0) return false;
    final bug = s.bugs[idx];
    if (bug.enhancement.total >= bug.maxLevel) return false; // 상한 도달
    final spec = cfg.spec(part);
    // 등급이 높을수록 비싸다 — 강화 총량이 유한해서 배수가 없으면 후반엔
    // 전설도 사실상 공짜로 만렙이 된다.
    final grade = ref
        .read(gameDataProvider)
        .requireValue
        .speciesById[bug.speciesId]
        ?.grade;
    final cost = grade == null
        ? spec.costAt(bug.enhancement.levelOf(part))
        : cfg.costFor(part, bug.enhancement.levelOf(part), grade);
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
    final viaServer = await _viaServer(
      () => ref.read(gameServerProvider).train(bugId),
    );
    if (viaServer != null) return viaServer;

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

  /// 돌파 재료 종류는 §2.7 의 시스템 규칙이라 `game_rules.dart` 한 곳에 있다
  /// — 앱·서버·비용 표시가 각자 목록을 들면 조용히 어긋난다.
  static const _breakMats = kBreakthroughMaterials;

  /// 돌파 시작: 티어 상한을 채운 성충의 레벨 상한을 올리는 업그레이드(타이머 시작).
  /// 재화(골드+재료) 소비. 조건 미달이면 false.
  Future<bool> breakthrough(String bugId) async {
    final viaServer = await _viaServer(
      () => ref.read(gameServerProvider).breakthrough(bugId),
    );
    if (viaServer != null) return viaServer;

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
    final viaServer = await _viaServer(
      () => ref
          .read(gameServerProvider)
          .completeBreakthrough(bugId, viaJelly: viaJelly),
    );
    if (viaServer != null) return viaServer;

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
    final viaServer = await _viaServer(
      () => ref.read(gameServerProvider).collectIncubated(bugId),
    );
    if (viaServer != null) return viaServer;

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

  /// 광고 보상으로 부화 시간을 당긴다. **광고 시청은 호출부 책임**
  /// (`watchAdForReward` 가 true 를 준 뒤에만 부른다).
  ///
  /// 줄이는 양은 등급별 전체 부화시간의 `incubateAdSkipRatio` — 고정 분수로
  /// 하면 5분짜리 일반 알은 광고 한 번에 끝나고 80분짜리 전설만 의미가 남는다.
  /// 비율이면 어느 등급이든 체감이 같다. 횟수 제한은 두지 않는다.
  Future<bool> adSkipIncubation(String bugId) async {
    final data = ref.read(gameDataProvider).requireValue;
    final cfg = data.petConfig;
    if (cfg == null) return false;
    final s = state.requireValue;
    final endsAt = s.incubating[bugId];
    if (endsAt == null) return false;

    final bug = s.bugs.firstWhere(
      (b) => b.id == bugId,
      orElse: () => throw StateError('bug not found'),
    );
    final grade = data.speciesById[bug.speciesId]?.grade ?? Grade.common;
    final fullSec = cfg.incubateDuration(grade); // 등급별 전체 부화시간(초)
    final cut = Duration(seconds: (fullSec * cfg.incubateAdSkipRatio).round());
    if (cut <= Duration.zero) return false;

    final now = ref.read(clockProvider).now().toUtc();
    var next = endsAt.subtract(cut);
    if (next.isBefore(now)) next = now; // 즉시 수령 가능 상태로
    final inc = Map<String, DateTime>.from(s.incubating)..[bugId] = next;
    await _commit(s.copyWith(incubating: inc));
    return true;
  }

  /// 젤리로 부화 즉시완료. 남은 시간 비례 비용(산란·돌파와 같은 방식).
  /// 젤리 부족·대상 없음이면 false.
  Future<bool> instantIncubate(String bugId) async {
    final cfg = ref.read(gameDataProvider).requireValue.petConfig;
    if (cfg == null) return false;
    final s = state.requireValue;
    final endsAt = s.incubating[bugId];
    if (endsAt == null) return false;

    final now = ref.read(clockProvider).now().toUtc();
    final rem = endsAt.difference(now);
    if (rem <= Duration.zero) return true; // 이미 완료 — 수령만 하면 된다
    final cost = cfg.incubateJelly(rem);
    if (s.materialCount(MaterialKind.jelly) < cost) return false;

    final mats = Map<MaterialKind, int>.from(s.materials);
    mats[MaterialKind.jelly] = (mats[MaterialKind.jelly] ?? 0) - cost;
    final inc = Map<String, DateTime>.from(s.incubating)..[bugId] = now;
    await _commit(s.copyWith(materials: mats, incubating: inc));
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

  // ── 장비 · 공방 · 스킬 (2026-08) ─────────────────────────────

  /// 부위에 장비를 낀다. **가방이 없으므로 기존 것은 사라진다**(§3.4) —
  /// 창고·보유상한·자동분해가 통째로 필요 없어지고, 세이브에 남는 장비는 8개뿐이다.
  Future<void> equipItem(EquipItem item) async {
    final s = state.requireValue;
    await _commit(
      s.copyWith(equippedItems: {...s.equippedItems, item.slot: item}),
    );
  }

  /// 제련 1회 — 화석 조각 1개를 태워 장비 하나를 뽑아 **모루 위에 쌓는다**.
  ///
  /// 화석이 없거나 자리가 없으면 `item` 이 null.
  /// 결과를 낄지는 나중에 정한다 — 뽑을 때마다 창이 뜨면 자동을 돌릴 수 없다.
  ///
  /// 필터([SaveGame.autoForgeOptions])를 걸어 두면 **그 능력치가 하나도 없는
  /// 건 쌓지 않고 버린다**(`kept == false`). 10칸이 금방 차 버리면 자동이
  /// 멈춰서, 원하는 것만 골라 받는 게 필터의 목적이다.
  Future<({EquipItem? item, bool kept})> forgeOnce() async {
    const nothing = (item: null, kept: false);
    final data = ref.read(gameDataProvider).value;
    final items = data?.itemConfig;
    final forge = data?.forgeConfig;
    if (items == null || forge == null) return nothing;
    final s = state.requireValue;
    if (s.forgeStack.length >= kMaxForgeStack) return nothing;
    final have = s.materialCount(MaterialKind.fossil);
    if (have < 1) return nothing;
    final item = forge_lib.forgeOnce(
      rng: math.Random(),
      items: items,
      forge: forge,
      forgeLevel: s.forgeLevel,
    );
    final want = s.autoForgeOptions;
    final kept = want.isEmpty || item.options.any((o) => want.contains(o.kind));
    final mats = Map<MaterialKind, int>.from(s.materials)
      ..[MaterialKind.fossil] = have - 1;
    await _commit(
      s.copyWith(
        materials: mats,
        forgeStack: kept ? [...s.forgeStack, item] : null,
      ),
    );
    return (item: item, kept: kept);
  }

  /// 모루 위에서 **맨 위 하나**를 집는다. 비었으면 null.
  Future<EquipItem?> takeForgeItem() async {
    final s = state.requireValue;
    if (s.forgeStack.isEmpty) return null;
    final item = s.forgeStack.last;
    await _commit(
      s.copyWith(forgeStack: s.forgeStack.sublist(0, s.forgeStack.length - 1)),
    );
    return item;
  }

  /// 지금 낀 것보다 나은지 — 자동 제련의 교체 판단.
  ///
  /// 목표 옵션을 지정했으면 **그 옵션이 붙었는지**가 우선이고, 없으면 등급으로 본다.
  bool isBetterItem(EquipItem candidate) {
    final s = state.requireValue;
    final cur = s.equippedItems[candidate.slot];
    if (cur == null) return true;
    final want = s.autoForgeOptions;
    if (want.isNotEmpty) {
      int hits(EquipItem i) =>
          i.options.where((o) => want.contains(o.kind)).length;
      final a = hits(candidate);
      final b = hits(cur);
      if (a != b) return a > b;
    }
    return candidate.tier > cur.tier;
  }

  /// 공방 등급업에 골드 한 칸을 붓는다. 골드 부족·이미 진행 중이면 false.
  ///
  /// 칸으로 나눠 받는 이유: 한 번에 다 못 내도 조금씩 부어둘 수 있고, 얼마나
  /// 남았는지가 눈에 보인다.
  Future<bool> payForgeStep() async {
    final forge = ref.read(gameDataProvider).value?.forgeConfig;
    if (forge == null) return false;
    final s = state.requireValue;
    if (s.forgeUpAt != null) return false; // 이미 업그레이드 중
    if (s.forgeLevel >= forge.maxLevel) return false;
    if (s.forgeSteps >= forge.levelUpSteps) return false;
    final cost = forge.levelUpStepGold(s.forgeLevel);
    if (s.gold < cost) return false;

    final steps = s.forgeSteps + 1;
    final full = steps >= forge.levelUpSteps;
    final now = ref.read(clockProvider).now().toUtc();
    await _commit(
      s.copyWith(
        gold: s.gold - cost,
        forgeSteps: steps,
        // 칸을 다 채우면 그때 업그레이드(시간)가 시작된다.
        forgeUpAt: full ? now.add(forge.levelUpDuration(s.forgeLevel)) : null,
      ),
    );
    return true;
  }

  /// 등급업 완료 수령(시간이 다 됐을 때). 아직이면 false.
  Future<bool> claimForgeUpgrade() async {
    final s = state.requireValue;
    final at = s.forgeUpAt;
    if (at == null) return false;
    final now = ref.read(clockProvider).now().toUtc();
    if (now.isBefore(at)) return false;
    await _commit(
      s.copyWith(
        forgeLevel: s.forgeLevel + 1,
        forgeSteps: 0,
        clearForgeUpAt: true,
      ),
    );
    return true;
  }

  /// 등급업 남은 시간을 젤리로 즉시 끝낸다.
  ///
  /// ⚠️ **시간만 산다.** 골드 칸은 젤리로 팔지 않는다 — 파는 순간 전력을
  /// 돈으로 사는 게 되어 헌법 §2.6 위반이다.
  Future<bool> rushForgeUpgrade() async {
    final forge = ref.read(gameDataProvider).value?.forgeConfig;
    if (forge == null) return false;
    final s = state.requireValue;
    final at = s.forgeUpAt;
    if (at == null) return false;
    final now = ref.read(clockProvider).now().toUtc();
    final cost = forge.levelUpJelly(at.difference(now));
    final have = s.materialCount(MaterialKind.jelly);
    if (have < cost) return false;
    final mats = Map<MaterialKind, int>.from(s.materials)
      ..[MaterialKind.jelly] = have - cost;
    await _commit(
      s.copyWith(
        materials: mats,
        forgeLevel: s.forgeLevel + 1,
        forgeSteps: 0,
        clearForgeUpAt: true,
      ),
    );
    return true;
  }

  /// 자동 제련 설정 저장.
  Future<void> setAutoForge({
    Set<ItemOptionKind>? options,
    bool? stopOnHit,
  }) async {
    final s = state.requireValue;
    await _commit(
      s.copyWith(autoForgeOptions: options, autoForgeStopOnHit: stopOnHit),
    );
  }

  /// 스킬 장착/해제. 칸(기본 5)을 넘으면 무시한다.
  Future<void> toggleSkill(String id) async {
    final cfg = ref.read(gameDataProvider).value?.skillConfig;
    final s = state.requireValue;
    final next = [...s.equippedSkills];
    if (next.remove(id)) {
      await _commit(s.copyWith(equippedSkills: next));
      return;
    }
    if (next.length >= (cfg?.equipSlots ?? 5)) return;
    if (!s.skillLevels.containsKey(id)) return; // 미보유
    next.add(id);
    await _commit(s.copyWith(equippedSkills: next));
  }

  /// 스킬 레벨업(골드+재료). 미보유면 **레벨 1로 습득**한다.
  Future<bool> levelUpSkill(String id) async {
    final cfg = ref.read(gameDataProvider).value?.skillConfig;
    if (cfg == null || cfg.byId(id) == null) return false;
    final s = state.requireValue;
    final lv = s.skillLevels[id] ?? 0;
    if (lv >= cfg.maxLevel) return false;
    final cost = cfg.levelUpCost(lv + 1);
    if (s.gold < cost.gold) return false;
    final have = s.materialCount(MaterialKind.chitin);
    if (have < cost.material) return false;
    final mats = Map<MaterialKind, int>.from(s.materials)
      ..[MaterialKind.chitin] = have - cost.material;
    await _commit(
      s.copyWith(
        gold: s.gold - cost.gold,
        materials: mats,
        skillLevels: {...s.skillLevels, id: lv + 1},
      ),
    );
    return true;
  }

  // ── 브리딩 (§2.5) ─────────────────────────────────────────────
  static const _uuid = Uuid();

  /// 같은 종 ♂+♀ 성충으로 산란 시작(등급별 타이머). 슬롯은 부모 스냅샷만 저장(부모 미잠금).
  /// [seed] 는 UI에서 생성해 주입(자식 롤 결정론). 조건 불충족이면 false.
  Future<bool> startBreeding(String motherId, String fatherId, int seed) async {
    // 서버 권위 모드에서는 **시드도 서버가 정한다** — 인자로 받은 seed 는 무시된다.
    // 클라가 시드를 고를 수 있으면 완벽한 자식이 나올 때까지 돌려볼 수 있다.
    final viaServer = await _viaServer(
      () => ref.read(gameServerProvider).breed(motherId, fatherId),
    );
    if (viaServer != null) return viaServer;

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
    // 짝짓기 텀 — 방금 쓴 부모는 잠시 다시 쓸 수 없다(§2.5).
    if (s.breedOnCooldown(motherId, now) || s.breedOnCooldown(fatherId, now)) {
      return false;
    }
    // 부모의 오행·기질·특성까지 찍어 둔다(§2.5 상속) — 부모를 잠그지 않는
    // 설계라 수령 시점엔 이미 없을 수 있다.
    final slot = BreedingSlot.from(
      id: _uuid.v4(),
      mother: mother,
      father: father,
      endsAt: now.add(Duration(seconds: cfg.breedingDuration(sp.grade))),
      seed: seed,
    );
    // 쿨다운은 **시작할 때** 건다(수령이 아니라). 수령을 미루는 것으로 텀을
    // 피할 수 있으면 제한이 없는 것과 같다.
    final cool = cfg.breedingCooldown(sp.grade);
    final cooldowns = s.prunedBreedCooldowns(now);
    if (cool > 0) {
      final until = now.add(Duration(seconds: cool));
      cooldowns[motherId] = until;
      cooldowns[fatherId] = until;
    }
    await _commit(
      s.copyWith(breeding: [...s.breeding, slot], breedCooldowns: cooldowns),
    );
    return true;
  }

  /// 산란 완료 슬롯 수령 → 자식(알)을 보관함에 추가. [viaJelly]=남은시간 비례 젤리 즉시완료.
  Future<bool> collectBreeding(String slotId, {bool viaJelly = false}) async {
    final viaServer = await _viaServer(
      () => ref
          .read(gameServerProvider)
          .collectBreeding(slotId, viaJelly: viaJelly),
    );
    if (viaServer != null) return viaServer;

    final data = ref.read(gameDataProvider).requireValue;
    final cfg = data.petConfig;
    if (cfg == null) return false;
    final now = ref.read(clockProvider).now().toUtc();
    final s = state.requireValue;
    // 채집함이 가득 차면 수령하지 않는다 — 슬롯을 그대로 두어 자리를 비운 뒤
    // 다시 받게 한다(여기서 알을 버리면 산란 시간이 통째로 날아간다).
    if (s.storageFull) return false;
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
    // 롤 공식은 슬롯이 들고 있다 — 서버(`GameActions.collectBreeding`)와
    // **같은 함수**를 써야 같은 seed 에서 같은 자식이 나온다.
    final egg = slot
        .hatch(id: _uuid.v4(), species: sp, cfg: cfg)
        .copyWith(stageSince: now);
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

  /// 도감(§2.1) 마일스톤 **일괄 수령**. 받은 게 있으면 그 목록을 돌려준다.
  ///
  /// 하나씩 누르게 하지 않는 이유: 마일스톤은 발견/정복이 오를 때 **여러 개가
  /// 동시에** 열릴 수 있고(예: 5종 발견과 3종 정복이 같은 곤충으로 동시 달성),
  /// 그때마다 팝업을 여러 번 띄우면 성가시다.
  Future<List<DexMilestone>> claimDexMilestones() async {
    final cfg = ref.read(gameDataProvider).requireValue.dexConfig;
    if (cfg == null) return const [];
    final s = state.requireValue;
    final claimable = cfg.claimable(
      s.dexDiscovered,
      s.dexConquered,
      s.claimedDex,
    );
    if (claimable.isEmpty) return const [];

    var gold = s.gold;
    final mats = Map<MaterialKind, int>.from(s.materials);
    for (final m in claimable) {
      gold += m.gold;
      if (m.jelly > 0) {
        mats[MaterialKind.jelly] = (mats[MaterialKind.jelly] ?? 0) + m.jelly;
      }
    }
    await _commit(
      s.copyWith(
        gold: gold,
        materials: mats,
        claimedDex: {...s.claimedDex, for (final m in claimable) m.id},
      ),
    );
    return claimable;
  }

  /// 채집함 등급 필터 설정(§2.1). [Grade.common] = 필터 없음(전부 받음).
  ///
  /// 미달 등급은 채집함에 들어오지 않고 재료로 환산된다(자동 방생).
  /// 강제 지점은 획득 지점 **및 서버**(`GameActions.settle`) — 클라이언트만
  /// 거르면 구버전 앱·조작 업로드가 필터를 우회한다.
  Future<void> setBugFilterMinGrade(Grade g) async {
    final s = state.requireValue;
    if (s.bugFilterMinGrade == g) return; // 불필요한 업로드 방지
    await _commit(s.copyWith(bugFilterMinGrade: g));
  }

  /// 채집함 확장(젤리). 최대치·젤리부족이면 false.
  ///
  /// 1회에 `storageExpandAmount` 칸씩 `storageSlotsMax` 까지. 상한은 세이브
  /// 크기의 방어선이라 **서버도 같은 상한으로 자른다**(actions.mergeSave).
  Future<bool> expandStorage() async {
    final cfg = ref.read(gameDataProvider).requireValue.petConfig;
    if (cfg == null) return false;
    final s = state.requireValue;
    if (s.storageCapacity >= cfg.storageSlotsMax) return false;
    final have = s.materials[MaterialKind.jelly] ?? 0;
    if (have < cfg.storageExpandJelly) return false;
    final next = (s.storageCapacity + cfg.storageExpandAmount).clamp(
      0,
      cfg.storageSlotsMax,
    );
    final mats = Map<MaterialKind, int>.from(s.materials)
      ..[MaterialKind.jelly] = have - cfg.storageExpandJelly;
    await _commit(s.copyWith(storageCapacity: next, materials: mats));
    return true;
  }

  /// 분해: 미장착 곤충 [bugId] 를 없애고 젤리로 환원. 장착/없음이면 false.
  Future<bool> disassembleBug(String bugId) async {
    final viaServer = await _viaServer(
      () => ref.read(gameServerProvider).disassemble(bugId),
    );
    if (viaServer != null) return viaServer;

    final s = state.requireValue;
    if (s.isEquipped(bugId)) return false;
    if (s.incubating.containsKey(bugId)) return false; // 부화 중 보호
    final idx = s.bugs.indexWhere((b) => b.id == bugId);
    if (idx < 0) return false;
    final bug = s.bugs[idx];
    // 분해 보상은 pets.json 의 PetConfig 계수로 결정(§6).
    //
    // **재료는 항상, 젤리는 드문 개체만.** 곤충은 무한히 나오므로 분해에
    // 젤리를 무제한으로 붙이면 프리미엄 재화가 파밍으로 뽑히고 IAP 가 죽는다
    // (실측: 젤리 수입의 50%가 분해였다 — `core_run/tool/jelly_sim.dart`).
    // 문턱(`disassembleJellyMinPotential`)을 넘는 개체만 젤리를 주면,
    // 수입은 줄면서 "좋은 걸 분해하는 순간"의 가치는 오히려 올라간다.
    final data = ref.read(gameDataProvider).requireValue;
    final cfg = data.petConfig;
    final reward = cfg?.disassembleJelly(bug.potential) ?? bug.potential;
    final grade = data.speciesById[bug.speciesId]?.grade;
    final matGain = (cfg == null || grade == null)
        ? 0
        : cfg.releaseMaterial(grade);
    final mats = Map<MaterialKind, int>.from(s.materials);
    if (reward > 0) {
      mats[MaterialKind.jelly] = (mats[MaterialKind.jelly] ?? 0) + reward;
    }
    if (matGain > 0) {
      // 자동 방생과 **같은 재료표**를 쓴다 — 분해와 방생의 가치가 갈리면
      // "필터에 걸리게 두는 게 이득"처럼 이상한 최적 전략이 생긴다.
      final kind =
          kRegularMaterials[math.Random().nextInt(kRegularMaterials.length)];
      mats[kind] = (mats[kind] ?? 0) + matGain;
    }
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

  /// 자동 합성 한 번의 결과 — 몇 번 합성했고 어떤 개체를 썼는지.
  /// [consumed] 는 미리보기에서 "무엇이 사라지는지"를 보여주기 위해 싣는다.
  static ({int fused, int used, List<String> consumed}) _emptySynth() =>
      (fused: 0, used: 0, consumed: const []);

  /// **자동 합성**: 같은 종이 충분히 쌓인 곳을 전부 합성해 포텐셜을 올린다.
  ///
  /// 손으로 하면 종을 찾아 들어가 3마리씩 골라 누르길 반복해야 한다 —
  /// 채집함이 50~100칸이라 이 반복이 곧 관리 비용이다.
  ///
  /// **재료로 쓰지 않는 것**(안전장치):
  ///  - 장착 중 · 부화 중 곤충
  ///  - **투자한 곤충** — 수련 레벨 2 이상, 돌파 티어 1 이상, 부위 강화가
  ///    하나라도 있는 개체. 골드·재료를 쏟은 개체가 조용히 사라지면 그게 곧
  ///    클레임이다(채집함 상한 정리 `trimBugsTo` 와 같은 원칙).
  ///
  /// 타깃은 **가장 많이 투자된 개체**, 재료는 가장 안 쓴 개체부터 쓴다.
  /// [dryRun] 이면 세이브를 건드리지 않고 예상 결과만 돌려준다(확인 다이얼로그용).
  ///
  /// [filter] 를 주면 **재료로 쓸 후보**를 그 조건으로 더 좁힌다(등급·포텐셜).
  /// 타깃(포텐셜이 오르는 개체)은 필터와 무관하다 — 좋은 개체를 올리는 게 목적이다.
  Future<({int fused, int used, List<String> consumed})> autoSynthesize({
    bool dryRun = false,
    BugAutoFilter? filter,
  }) async {
    final data = ref.read(gameDataProvider).requireValue;
    final cfg = data.petConfig;
    if (cfg == null || cfg.synthFodder <= 0) return _emptySynth();
    final s = state.requireValue;

    // 재료로 쓸 수 있는 개체인지 — 위 안전장치 + 사용자가 고른 필터.
    bool isFodder(IndividualBug b) {
      if (s.isEquipped(b.id) ||
          s.incubating.containsKey(b.id) ||
          b.level > 1 ||
          b.breakthroughTier > 0 ||
          b.enhancement.total > 0) {
        return false;
      }
      if (filter == null) return true;
      final grade = data.speciesById[b.speciesId]?.grade;
      // 종을 모르면 건드리지 않는다 — 정체를 모르는 개체를 지우는 쪽보다
      // 남기는 쪽이 안전하다.
      return grade != null && filter.accepts(grade, b.potential);
    }

    // 투자 점수(높을수록 남긴다) — trimBugsTo 와 같은 우선순위.
    int invested(IndividualBug b) =>
        b.level * 1000000 + b.breakthroughTier * 10000 + b.enhancement.total;

    final bySpecies = <String, List<IndividualBug>>{};
    for (final b in s.bugs) {
      bySpecies.putIfAbsent(b.speciesId, () => []).add(b);
    }

    final consumed = <String>{};
    final upgraded = <String, int>{}; // bugId → 오른 포텐셜
    var fused = 0;

    for (final group in bySpecies.values) {
      // 이 종에서 남길 후보(투자 많은 순) / 재료 후보(투자 적은 순).
      final alive = group.where((b) => !consumed.contains(b.id)).toList()
        ..sort((a, b) {
          final inv = invested(b).compareTo(invested(a));
          if (inv != 0) return inv;
          final pot = b.potential.compareTo(a.potential);
          if (pot != 0) return pot;
          return b.sizeMm.compareTo(a.sizeMm);
        });
      if (alive.isEmpty) continue;

      // 타깃 = 목록 맨 앞(가장 많이 투자된 개체). 재료 = 뒤에서부터.
      var targetIdx = 0;
      var tail = alive.length - 1;
      while (targetIdx < alive.length) {
        final target = alive[targetIdx];
        var pot = upgraded[target.id] ?? target.potential;
        if (pot >= cfg.synthMaxPotential) {
          targetIdx++; // 이미 만렙이면 다음 후보를 올린다
          continue;
        }
        // 뒤에서부터 재료를 모은다(타깃 자신은 제외).
        final picked = <String>[];
        while (picked.length < cfg.synthFodder && tail > targetIdx) {
          final b = alive[tail--];
          if (consumed.contains(b.id) || !isFodder(b)) continue;
          picked.add(b.id);
        }
        if (picked.length < cfg.synthFodder) break; // 이 종은 재료가 모자란다
        consumed.addAll(picked);
        pot += 1;
        upgraded[target.id] = pot;
        fused++;
      }
    }

    if (fused == 0) return _emptySynth();
    final result = (
      fused: fused,
      used: consumed.length,
      consumed: consumed.toList(),
    );
    if (dryRun) return result;

    final bugs = <IndividualBug>[];
    for (final b in s.bugs) {
      if (consumed.contains(b.id)) continue;
      final pot = upgraded[b.id];
      bugs.add(pot == null ? b : b.copyWith(potential: pot));
    }
    await _commit(s.copyWith(bugs: bugs));
    return result;
  }

  /// **자동 분해**: 필터에 맞는 개체를 한 번에 정리해 재료로 바꾼다.
  ///
  /// 보호 대상은 자동 합성과 같다 — 장착 중 · 부화 중 · 투자한 개체
  /// (수련 2↑ · 돌파 1↑ · 부위 강화 1↑)는 필터에 걸려도 건드리지 않는다.
  ///
  /// ⚠️ **젤리는 주지 않는다.** 수동 분해는 포텐셜 문턱(4성↑) 위에서 젤리를
  /// 주지만, 그건 "한 마리씩 손으로 누른다"가 병목이라 안전한 것이다. 일괄
  /// 분해엔 그 병목이 없어 돌릴수록 젤리가 쌓인다 — **무한히 늘어나는 통로에는
  /// 젤리를 붙이지 않는다**(§2.6). 자동 방생이 재료만 주는 것과 같은 이유다.
  ///
  /// [dryRun] 이면 세이브를 건드리지 않고 예상 결과만 돌려준다.
  Future<({int released, int materials, List<String> consumed})> autoRelease({
    bool dryRun = false,
    BugAutoFilter? filter,
  }) async {
    const empty = (released: 0, materials: 0, consumed: <String>[]);
    final data = ref.read(gameDataProvider).requireValue;
    final cfg = data.petConfig;
    if (cfg == null) return empty;
    final s = state.requireValue;

    final targets = <IndividualBug>[];
    var gain = 0;
    for (final b in s.bugs) {
      if (s.isEquipped(b.id) || s.incubating.containsKey(b.id)) continue;
      if (b.level > 1 || b.breakthroughTier > 0 || b.enhancement.total > 0) {
        continue;
      }
      final grade = data.speciesById[b.speciesId]?.grade;
      if (grade == null) continue; // 종을 모르면 건드리지 않는다
      if (filter != null && !filter.accepts(grade, b.potential)) continue;
      targets.add(b);
      gain += cfg.releaseMaterial(grade);
    }
    if (targets.isEmpty) return empty;

    final result = (
      released: targets.length,
      materials: gain,
      consumed: [for (final b in targets) b.id],
    );
    if (dryRun) return result;

    // 재료 종류는 개체마다 하나씩 굴린다 — 수동 분해·자동 방생과 같은 규칙이라
    // "어느 경로로 없애는 게 이득"이라는 이상한 최적 전략이 생기지 않는다.
    final mats = Map<MaterialKind, int>.from(s.materials);
    final rng = math.Random();
    for (final b in targets) {
      final grade = data.speciesById[b.speciesId]!.grade;
      final amount = cfg.releaseMaterial(grade);
      if (amount <= 0) continue;
      final kind = kRegularMaterials[rng.nextInt(kRegularMaterials.length)];
      mats[kind] = (mats[kind] ?? 0) + amount;
    }
    final gone = result.consumed.toSet();
    final bugs = [
      for (final b in s.bugs)
        if (!gone.contains(b.id)) b,
    ];
    await _commit(s.copyWith(bugs: bugs, materials: mats));
    return result;
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

  /// 보유 곤충 중 **가장 보너스가 큰 순서**로 자동 장착한다.
  ///
  /// "상위 곤충"을 등급이나 레벨 같은 한 축으로 고르지 않는다 — 실제 이득은
  /// 등급·포텐셜·사이즈·강화·성장단계·레벨이 곱해진 값이고, 그 계산은 이미
  /// `petContribution` 에 있다. 화면에 뜨는 보너스와 **같은 식**을 써야
  /// "자동으로 맞췄는데 수치가 더 낮다"가 안 생긴다.
  ///
  /// 이미 최적이면 아무것도 저장하지 않는다(불필요한 업로드 방지).
  Future<bool> autoEquipBest() async {
    final data = ref.read(gameDataProvider).requireValue;
    final cfg = data.petConfig;
    if (cfg == null) return false;
    final now = ref.read(clockProvider).now().toUtc();
    final s = state.requireValue;

    final scored = <({String id, double score})>[];
    for (final b in s.bugs) {
      final sp = data.speciesById[b.speciesId];
      if (sp == null) continue;
      final c = petContribution(petStatOf(b, sp, cfg, now), cfg);
      scored.add((id: b.id, score: c.attack + c.hp));
    }
    if (scored.isEmpty) return false;
    scored.sort((a, b) {
      final d = b.score.compareTo(a.score);
      return d != 0 ? d : a.id.compareTo(b.id); // 동점이어도 결과가 흔들리지 않게
    });
    final best = [for (final e in scored.take(cfg.maxEquip)) e.id];
    // 순서까지 같으면 바꿀 게 없다.
    if (best.length == s.equippedBugIds.length &&
        List.generate(
          best.length,
          (i) => best[i] == s.equippedBugIds[i],
        ).every((x) => x)) {
      return false;
    }
    await _commit(s.copyWith(equippedBugIds: best));
    return true;
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

  /// 닉네임 변경 비용(곤충젤리). 첫 설정은 무료, 이후 변경마다 소비.
  static const int kNicknameChangeCost = 100;

  /// 플레이어 닉네임 변경. 첫 설정(미확정)은 무료, 이후 변경은 젤리 [kNicknameChangeCost] 소비.
  /// 공백은 [RenameResult.noChange], 젤리 부족 시 변경 없이 [RenameResult.notEnoughJelly].
  Future<RenameResult> renamePlayer(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return RenameResult.noChange;
    final s = state.requireValue;
    if (trimmed == s.nickname && s.nicknameSet) return RenameResult.noChange;
    if (s.nicknameSet) {
      // 이미 한 번 확정한 뒤의 변경 → 젤리 소비.
      final have = s.materials[MaterialKind.jelly] ?? 0;
      if (have < kNicknameChangeCost) return RenameResult.notEnoughJelly;
      final mats = Map<MaterialKind, int>.from(s.materials)
        ..[MaterialKind.jelly] = have - kNicknameChangeCost;
      await _commit(
        s.copyWith(nickname: trimmed, nicknameSet: true, materials: mats),
      );
    } else {
      // 첫 설정 — 무료.
      await _commit(s.copyWith(nickname: trimmed, nicknameSet: true));
    }
    return RenameResult.ok;
  }
}

/// [SaveController.renamePlayer] 결과.
enum RenameResult { ok, notEnoughJelly, noChange }

final saveControllerProvider = AsyncNotifierProvider<SaveController, SaveGame>(
  SaveController.new,
);
