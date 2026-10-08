import 'dart:async';

import 'dart:math' as math;

import 'package:core_gathering/core_gathering.dart';
import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_run/core_run.dart' as forge_lib show forgeOnce;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:core_save/core_save.dart';
import 'package:core_save/core_save.dart'
    as core_skill
    show
        startSkillTraining,
        completeSkillTraining,
        grantEliteShards,
        drawSkills,
        sweepBoss;
import '../data/game_data.dart';
import '../data/save_repository.dart';
import 'bug_auto_filter.dart';
import 'gather_service.dart';
import 'combat_power.dart';
import 'guild_service.dart';
import 'game_server.dart';
import 'providers.dart';
import 'server_sync.dart' show flushSaveBeforeServerAction, withServerSaveLock;

/// 대회 회차 종료 보상(서버가 확정, UI 가 1회 표시).
///
/// ⚠️ **지역 정보가 없다.** [physical] 은 "실물 안내를 띄워라"는 표시일 뿐이고,
/// 국내 거주 여부는 신청 폼에서 운영이 가른다 — 기기 로케일은 바꾸면 그만이라
/// 실물 자격의 근거가 될 수 없다. 해외 이용자도 게임 내 보상은 똑같이 받는다.
class EventRewardReport {
  const EventRewardReport({
    required this.roundId,
    required this.rank,
    required this.jelly,
    required this.physical,
    required this.materials,
    required this.prizeFormUrl,
    this.roundNo = 0,
    this.badge = '',
  });

  final String roundId;

  /// 회차 번호(1부터). 0 이면 구버전 서버라 모른다 — 화면은 [roundId] 로 떨어진다.
  /// `2026-0901 회차 3위` 로 적히던 문제(roundId 를 그대로 보여줬다).
  final int roundNo;

  /// 이번에 받은 뱃지(`participant:1`). 없으면 빈 문자열.
  final String badge;

  /// 순위. 익명 계정이거나 순위권 밖이면 null(참가 보상만 받는다).
  final int? rank;
  final int jelly;
  final bool physical;
  final Map<String, int> materials;

  /// 실물 경품 신청 폼 주소. **서버가 내려준다** — 앱 번들에만 있으면 주소를
  /// 넣으려고 스토어 심사를 기다려야 한다. 비어 있으면 버튼을 감춘다.
  final String prizeFormUrl;

  factory EventRewardReport.fromJson(Map<String, dynamic> json) =>
      EventRewardReport(
        roundId: '${json['roundId']}',
        rank: (json['rank'] as num?)?.toInt(),
        jelly: (json['jelly'] as num?)?.toInt() ?? 0,
        physical: json['physical'] as bool? ?? false,
        materials: {
          for (final e in ((json['materials'] as Map?) ?? const {}).entries)
            '${e.key}': (e.value as num).toInt(),
        },
        prizeFormUrl: (json['prizeFormUrl'] as String?) ?? '',
        roundNo: (json['roundNo'] as num?)?.toInt() ?? 0,
        badge: (json['badge'] as String?) ?? '',
      );
}

/// 결투 시즌 **순위** 보상(2026-09-28) — 서버가 시즌이 끝난 뒤 첫 업로드에서
/// 지급하고 알려 준다. 순위권(10위) 안에 든 사람에게만 온다.
class PvpRankRewardReport {
  const PvpRankRewardReport({
    required this.season,
    required this.rank,
    required this.jelly,
    this.total = 0,
    this.floor = 0,
  });

  /// 심연 주간 순위일 때 그 주에 닿은 층(결투 순위면 0).
  final int floor;

  /// 시즌 id(`2026-09-28` = 그 시즌이 시작한 날).
  final String season;
  final int rank;
  final int jelly;

  /// 그 시즌 순위에 든 인원(트로피 1 이상).
  final int total;

  factory PvpRankRewardReport.fromJson(Map<String, dynamic> json) =>
      PvpRankRewardReport(
        season: '${json['season']}',
        rank: (json['rank'] as num?)?.toInt() ?? 0,
        jelly: (json['jelly'] as num?)?.toInt() ?? 0,
        total: (json['total'] as num?)?.toInt() ?? 0,
        floor: (json['floor'] as num?)?.toInt() ?? 0,
      );
}

/// 결투 **리그 주간 결산** 결과(2026-09-29) — 승급·유지·강등 · 지난주 순위 · 순위 젤리.
class LeagueResultReport {
  const LeagueResultReport({
    required this.from,
    required this.to,
    this.rank,
    this.total = 0,
    this.jelly = 0,
    this.inactive = false,
  });

  final String from;
  final String to;
  final int? rank;
  final int total;
  final int jelly;

  /// 지난주를 쉬어서 한 단계 내려갔나.
  final bool inactive;

  factory LeagueResultReport.fromJson(Map<String, dynamic> j) =>
      LeagueResultReport(
        from: '${j['from']}',
        to: '${j['to']}',
        rank: (j['rank'] as num?)?.toInt(),
        total: (j['total'] as num?)?.toInt() ?? 0,
        jelly: (j['jelly'] as num?)?.toInt() ?? 0,
        inactive: j['inactive'] == true,
      );
}

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

  /// 정산 기간(일 09시~월 09시) — 결투를 받지 않아 충전도 막는다(2026-10-04).
  seasonClosed,

  /// 오늘 광고 시청 상한에 걸렸다(광고제거 구매자도 동일).
  adLimit,

  /// 젤리가 모자란다.
  notEnoughJelly,

  /// 오늘 젤리 충전 횟수를 다 썼다(battle.json tickets.refillDailyLimit).
  refillLimit,

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

  /// 성장 패스 오늘 몫을 준 사본(없거나 이미 받았으면 그대로).
  SaveGame _claimGrowthDaily(SaveGame save, GameData data) {
    final iap = data.iapConfig;
    if (iap == null) return save;
    return claimGrowthPassDaily(
          save,
          iap,
          now: ref.read(clockProvider).now().toUtc(),
          today: dailyDateKey(ref.read(clockProvider).now()),
          fairy: data.fairyConfig,
        ) ??
        save;
  }

  /// 마지막 로드 시 계산된 오프라인 보상(UI 가 1회 표시 후 [consumeOffline]).
  OfflineReport? pendingOffline;

  /// 마지막 로드 시 정산된 시즌 종료(UI 가 1회 표시 후 [consumeSeason]).
  SeasonReport? pendingSeason;

  /// 서버가 지급한 대회 회차 보상(UI 가 1회 표시 후 [consumeEventReward]).
  EventRewardReport? pendingEventReward;

  /// 결투 시즌 순위 보상(서버 지급) — 앱 셸이 1회 팝업으로 보여준다.
  PvpRankRewardReport? pendingPvpRankReward;

  /// 결투 리그 주간 결산(서버) — 앱 셸이 1회 팝업으로 보여준다.
  LeagueResultReport? pendingLeagueResult;
  void consumeLeagueResult() => pendingLeagueResult = null;

  /// 심연 주간 순위 보상(서버 지급) — 같은 모양이라 같은 보고서를 쓴다(`floor` 가 채워진다).
  PvpRankRewardReport? pendingAbyssRankReward;

  /// **지금 이 순간의** 세이브(로딩 중이면 null). 서버 세이브 잠금 안에서 올릴 세이브를 읽는 데 쓴다
  /// ([flushSaveBeforeServerAction] 의 `latest`) — 화면의 `ref` 는 잠금을 기다리는 사이 닫힐 수
  /// 있어서, 컨트롤러를 쥐어 두고 여기서 읽는다.
  SaveGame? get latestSave => state.value;

  @override
  Future<SaveGame> build() async {
    final data = await ref.watch(gameDataProvider.future);
    final repo = ref.watch(saveRepositoryProvider);
    final clock = ref.read(clockProvider);
    var save = await repo.load();
    // 못 읽었으면 화면이 게임을 덮는다(`saveUnreadable`). 아래 정산·자가치유는
    // 초기 세이브 위에서 돌지만 **저장도 업로드도 되지 않으므로** 흔적이 남지 않는다.
    saveUnreadable.value = repo.lastFailure;
    final now = clock.now().toUtc();

    // 사냥터 구조 세대(2026-09-14) — 옛 진행도는 처음으로. 서버 로드에서도
    // 같은 함수를 부른다(한쪽만 하면 동기화가 옛 진행도를 되살린다).
    save = applyZoneEpoch(save);

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

    // 요정·스킬 성장 패스 매일 지급(2026-10) — 곤충학자 패스 매일 젤리와 같은 구조(기기 날짜 1회).
    // 규칙은 core_save `claimGrowthPassDaily` 한 곳. 젤리는 없다(§2.6).
    save = _claimGrowthDaily(save, data);

    // 자가치유: 채집함 상한 초과분 정리.
    //
    // 상한 도입 전(2026-08 이전) 세이브에는 곤충이 수만 마리 쌓여 있어 업로드가
    // 통째로 실패했다. 여기서 한 번 잘라내면 그 계정이 정상 크기로 돌아온다.
    // 부화 항목 정리보다 **먼저** 해야 한다 — 잘린 곤충의 부화 기록이 남으면
    // 슬롯이 새기 때문(아래 자가치유가 이어서 걷어낸다).
    save = save.trimmedToStorage();

    // 훈련 v2 이전(2026-10-08) — 옛 부위 강화·옛 훈련 단계를 포인트 칸으로(멱등). 서버 업로드와 **같은 함수**다.
    save = _migrateTrainV2(save, data);

    // 스킬 필드를 규칙 안으로(만렙·장착 칸). 서버 업로드와 **같은 함수**다.
    final skillCfg = data.skillConfig;
    if (skillCfg != null) save = enforceSkillRules(save, skillCfg);

    // 요정도 규칙 안으로(등급 레벨 상한·요정함 상한). 서버 업로드와 **같은 함수**다.
    // ⚠️ 모르는 종류·부가 키는 여기서 거르지 않는다 — 구버전 앱이 새 종류를 지우면 안 된다(서버만 거른다).
    final fairyCfg = data.fairyConfig;
    if (fairyCfg != null) {
      save = save.copyWith(fairy: enforceFairyRules(save.fairy, fairyCfg));
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
        // 리그 소속으로 준다(트로피 문턱이 아니다 — 2026-09-29 리그 개편).
        final rw = battleCfg.seasonRewardAt(pvpLeagueOf(save, battleCfg));
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
          gold: addCurrency(save.gold, rw.gold),
          materials: mats,
          pvpTrophies: reset,
          seasonPeakTrophies: reset,
          seasonStartedAt: curStart,
        );
      }
    }

    // 심연 층은 **주간**이다(결투 시즌과 같은 경계) — 주가 바뀌었으면 1층부터(A안).
    // 한 번이라도 심연에 들어가 본 세이브만(주 기록이 없으면 들어갈 때 정한다).
    if (battleCfg != null && save.abyssWeek != null) {
      save = applyAbyssWeek(save, abyssWeekId(now, battleCfg));
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
      tier: save.difficultyTier,
      // 심연이면 층 배율(서버 정산과 같은 규칙).
      abyssFloor: activeAbyssFloor(save),
      // 끝에 눌러앉으면 방치 수입도 깎인다(온라인과 같은 규칙).
      finalStage: data.roadmapConfig?.finalStage,
      efficiency: config.offlineEfficiency,
      maxAccrual: passOn
          ? Duration(hours: iap?.passOfflineCapHours ?? 12)
          : kMaxOfflineAccrual,
    );
    final maxAccrual = passOn
        ? Duration(hours: iap?.passOfflineCapHours ?? 12)
        : kMaxOfflineAccrual;
    // 방치 중 처치 수 — 사냥터 게이지와 **곤충·재료 드롭**이 같은 값을 쓴다.
    final clears = estimateClears(
      config: config,
      stageNumber: save.stageNumber,
      stats: stats,
      elapsed: elapsed,
      tier: save.difficultyTier,
      abyssFloor: activeAbyssFloor(save),
      efficiency: config.offlineEfficiency,
      maxAccrual: maxAccrual,
    );
    // 곤충·재료 드롭(2026-10-04) — 처치마다 온라인과 같은 규칙으로 굴린다. 서버 `/sync` 와 같은 함수.
    // 기기 권위 전환(2026-07) 뒤 앱이 `/sync` 를 안 불러 오프라인 드롭이 통째로 빠져 있었다.
    final pet = data.petConfig;
    final drops = pet == null
        ? null
        : rollIdleDrops(
            save: save,
            rolls: clears.floor().clamp(0, _maxOfflineRolls),
            species: data.allSpecies,
            run: config,
            pet: pet,
            iap: iap,
            bugFind: stats.bugFind,
            materialFind: stats.materialFind,
            now: now,
            rng: math.Random(),
            newId: _devUuid.v4,
          );
    // 길드 버프 골드(1.0.15) — 방치가 주 플레이라 오프라인에도 건다(사장님 확정).
    // 길드 조회보다 먼저 돌기 때문에 기기 캐시를 쓴다([GuildBuffCache]).
    final guildGold = kGuildOpen
        ? 1 + (GuildBuffCache.bonus['gold'] ?? 0)
        : 1.0;
    final report = OfflineReport(
      gold:
          (raw.gold *
                  (passOn ? (iap?.passIdleGoldMult ?? 1.2) : 1.0) *
                  guildGold)
              .round(),
      xp: raw.xp,
      accrued: raw.accrued,
    );
    if (report.isEmpty) return save;

    var xp = save.xp + report.xp;
    var level = save.level;
    while (xp >= xpForNextLevel(level)) {
      xp -= xpForNextLevel(level);
      level++;
    }
    // 화석 조각은 **시간 비례**라 정산된 시간(오프라인 상한이 걸린 값)에 맞춰
    // 준다. 오프라인은 온라인의 1/3 — 켜두는 쪽이 이득이어야 한다.
    var mats = drops?.materials ?? save.materials;
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
    // 팝업에 보일 몫 = 정산 뒤 − 정산 전.
    final gained = <MaterialKind, int>{
      for (final e in mats.entries)
        if (e.value - (save.materials[e.key] ?? 0) > 0)
          e.key: e.value - (save.materials[e.key] ?? 0),
    };
    pendingOffline = OfflineReport(
      gold: report.gold,
      xp: report.xp,
      accrued: report.accrued,
      bugs: drops?.bugs.length ?? 0,
      materials: gained,
      bugsBlocked: drops?.blocked ?? 0,
    );
    // 사냥터 모드: 방치 중 잡은 수도 도전 게이지에 쌓인다(서버 정산과 같은 규칙).
    int? zoneKills;
    if (config.zoneMode) {
      zoneKills = save.zoneKills + clears.floor();
    }
    return save.copyWith(
      gold: addCurrency(save.gold, report.gold),
      xp: xp,
      level: level,
      materials: mats,
      zoneKills: zoneKills,
      bugs: (drops == null || drops.bugs.isEmpty)
          ? null
          : [...save.bugs, ...drops.bugs],
      rarePity: drops?.rarePity,
    );
  }

  /// 오프라인 정산 한 번에 굴리는 처치 수 상한 — 연산 방어(8시간·12시간 정산도 이보다 훨씬 적다).
  static const _maxOfflineRolls = 50000;

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
  void consumeEventReward() => pendingEventReward = null;
  void consumePvpRankReward() => pendingPvpRankReward = null;
  void consumeAbyssRankReward() => pendingAbyssRankReward = null;

  /// 다음 난이도 회차로 진입한다 — **성장 축을 리셋하고 자산은 남긴다**
  /// (프레스티지, `docs/design_difficulty_loop.md`).
  ///
  /// ⚠️ 처음엔 "스테이지만 1 로" 설계했다가 **실측으로 뒤집었다**(2026-08-30).
  /// 전력을 그대로 들고 가면 2회차부터 **이틀이면 끝난다**. 적응형 체력은
  /// "그 스테이지의 기본 체력"에 배율을 곱하는 구조라, 스테이지 1 은 기본
  /// 체력이 150 이라 3000배를 곱해도 20만이다 — 공격력이 1조든 100경이든
  /// **똑같이 한 방**이다. 배율로는 못 고친다.
  ///
  /// 그래서 **다시 약해져야** 회차가 길어진다:
  ///  - 리셋: 스테이지 · 능력치 강화(업그레이드) · 캐릭터 레벨/경험치
  ///  - 유지: 곤충 · 장비 · 도감 · 재화(골드·재료·젤리) · 부화기/짝짓기
  ///
  /// 남는 자산이 곧 "이번엔 훨씬 수월하다"는 성장 실감이다.
  ///
  /// ⚠️ **골드와 일반 재료는 성장 축이라 함께 처음으로 돌아간다**(2026-09-14 실측).
  /// 업그레이드 레벨만 지우고 재화를 남겼더니, 쌓아 둔 것으로 **넘어간 즉시
  /// 상한까지 다시 사서** 새 회차가 통째로 건너뛰어졌다 — 골드 113조면
  /// 216레벨, 키틴 300만이면 164레벨이 즉시 복구된다. 강화의 문턱이 골드와
  /// 재료 **둘**이므로 한쪽만 비우면 다른 쪽이 그대로 구멍이 된다.
  /// 비용 곡선을 회차마다 올려 막으려면 배율이 억 단위라야 해서 손잡이로 쓸 수 없다.
  ///
  /// 남는 것: 곤충 · 장비 · 도감 · **젤리**(프리미엄 — 돈 주고 산 것을 지울 수
  /// 없다) · **화석**(제련 전용이라 강화 문턱이 아니다). 그것이 "이번엔
  /// 수월하다"의 실체이고, 골드·재료는 그때그때 다시 번다.
  ///
  /// ⚠️ 사냥터 게이지(`zoneKills`)도 비운다. 안 비우면 새 난이도 첫 사냥터에
  /// 도착하자마자 **보스 도전이 열려 있다**(2026-09-14 지적).
  Future<void> enterNextTier() async {
    final run = ref.read(gameDataProvider).value?.runConfig;
    if (run == null) return;
    // 규칙은 core_save 의 순수 함수 하나(tier_progress.dart) — 처음 가는 난이도면
    // 성장 축 초기화, 이미 가 본 난이도면 그대로 이동.
    await _commit(enterNextTierSave(state.requireValue, run));
  }

  /// 로드맵에서 난이도를 고른다(가 본 가장 높은 난이도까지). 초기화 없음.
  Future<void> selectTier(int tier) async {
    final run = ref.read(gameDataProvider).value?.runConfig;
    if (run == null) return;
    final s = state.requireValue;
    final next = selectTierSave(s, run, tier);
    if (identical(next, s)) return;
    await _commit(next);
  }

  GatherService get _service => ref.read(gatherServiceProvider);
  SaveRepository get _repo => ref.read(saveRepositoryProvider);

  Future<void> _commit(SaveGame save) async {
    // 최고 도달 기록은 **저장되는 모든 경로**에서 한 번에 올린다. 획득 지점마다
    // 올리면 새 경로가 생길 때 빠뜨린다(도감 갱신과 같은 원칙).
    // 최고 기록은 **가 본 가장 높은 난이도 안에서만** 올린다 — 아래 난이도로
    // 내려가 있는 동안의 스테이지는 그 난이도 것이다(tier_progress.dart).
    if (save.difficultyTier >= save.topTier &&
        save.stageNumber > save.bestStage) {
      save = save.copyWith(bestStage: save.stageNumber);
    }
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
    // 장비 옵션 정리(§제련 개편)도 여기서 한다 — 낀 8개 + 모루 10개뿐이라
    // 비용이 없고, **어느 경로로 들어온 장비든** 지금 규칙을 따르게 된다
    // (서버 세이브 채택·구버전 세이브 로드까지 한 곳에서 걸린다).
    // 훈련소 — 끝난 훈련 반영 · 사라진 곤충의 훈련 기록 정리(어느 경로로 저장돼도 한 곳에서).
    // 훈련 v2 — 이전(서버 세이브 채택 경로도 여기서 걸린다 · 멱등) · 끝난 찍기·다시 찍기 반영.
    final data = ref.read(gameDataProvider).value;
    final trimmed = _withTrimmedItems(withDex).trimmedToStorage();
    final stamped = pruneTraining(
      finishTrainPointsIfDue(
        data == null ? trimmed : _migrateTrainV2(trimmed, data),
        now,
      ),
    ).copyWith(lastSeen: now, saveRev: save.saveRev + 1);
    state = AsyncData(stamped);
    await _repo.save(stamped);
  }

  /// 낀 장비·모루의 옵션을 지금 규칙(개수 상한·살아 있는 축)으로 정리한다.
  /// 바뀐 게 없으면 [save] 그대로 — 매 저장마다 도는 자리라 새 객체를 만들지 않는다.
  SaveGame _withTrimmedItems(SaveGame save) {
    final cfg = ref.read(gameDataProvider).value?.itemConfig;
    if (cfg == null) return save;
    var changed = false;
    final equipped = <EquipSlot, EquipItem>{};
    for (final e in save.equippedItems.entries) {
      // 상한을 넘으면 자르고, **모자라면 채운다**. 2026-09-09 에 모든 등급을
      // 옵션 2 개로 바꿨는데, 그 전 1 옵션 장비를 그대로 두면 기본 스탯이
      // 사라진 만큼만 약해져 가만히 있던 유저가 손해를 본다.
      final t = fillMissingOptions(
        rng: _forgeRng,
        items: cfg,
        item: trimItemOptions(e.value, cfg),
      );
      if (!identical(t, e.value)) changed = true;
      equipped[e.key] = t;
    }
    final stack = <EquipItem>[];
    for (final i in save.forgeStack) {
      final t = fillMissingOptions(
        rng: _forgeRng,
        items: cfg,
        item: trimItemOptions(i, cfg),
      );
      if (!identical(t, i)) changed = true;
      stack.add(t);
    }
    if (!changed) return save;
    return save.copyWith(equippedItems: equipped, forgeStack: stack);
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
    int? rarePity,

    /// 사냥터 처치 게이지에 셀 것인가(일반 몬스터 처치). 보스는 안 센다.
    bool zoneKill = false,
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
        gold: addCurrency(s.gold, gold),
        xp: newXp,
        level: newLevel,
        materials: newMaterials,
        bugs: accepted == null ? null : [...s.bugs, accepted],
        missionProgress: mission == null
            ? null
            : _bumpMissions(s.missionProgress, mission, 1),
        rarePity: rarePity,
        zoneKills: zoneKill ? s.zoneKills + 1 : null,
      ),
    );
  }

  /// 쓰러져서 후퇴할 때 사냥터 게이지를 비운다(사장님 확정 2026-09-18).
  ///
  /// ⚠️ 헌법 §2.4 는 "실패 벌칙 없음"이었다 — 이 지시로 **바뀐다**.
  /// 보스는 겨우 잡히는 체력으로 맞춰 둬서 실패가 잦은데, 그때마다 100마리를
  /// 다시 채워야 한다. 진행이 느려지면 이 규칙부터 되돌려 본다.
  Future<void> resetZoneKills() async {
    final s = state.requireValue;
    if (s.zoneKills == 0) return;
    await _commit(s.copyWith(zoneKills: 0));
  }

  /// 일반 몬스터에게 쓰러졌다 — 한 칸 아래로(심연이면 한 층 아래, zone_fall.dart). 바뀐 세이브를
  /// **바로** 돌려준다(저장은 이어서 — 화면이 같은 프레임에 새 자리로 옮겨야 한다). 바뀐 게 없거나
  /// 사냥터 모드가 아니면 null.
  SaveGame? fallAfterDefeat() {
    final run = ref.read(gameDataProvider).value?.runConfig;
    final s = state.requireValue;
    if (run == null || !run.zoneMode) return null;
    final next = fallOnDefeat(s, run);
    if (identical(next, s)) return null;
    // _commit 은 첫 await 전에 state 를 바꾼다 — 아래에서 읽는 값이 저장될 값이다.
    unawaited(_commit(next));
    return state.requireValue;
  }

  /// 보스 도전이 열렸는가 — 이 사냥터에서 [RunConfig.bossUnlockKills] 마리.
  bool get bossUnlocked {
    final run = ref.read(gameDataProvider).value?.runConfig;
    if (run == null || !run.zoneMode) return true;
    return state.requireValue.zoneKills >= run.bossUnlockKills;
  }

  /// 마지막 [advanceZone] 에서 떨어진 요정 알 등급(화면 알림용). 없으면 빈 목록.
  List<FairyGrade> lastBossFairyEggs = const [];

  /// 마지막 보스 첫 처치 알이 요정함이 차서 가루가 됐으면 그 수·가루.
  ({int eggs, int dust}) lastBossFairyOverflow = (eggs: 0, dust: 0);

  /// 같은 자리에서 알 자동 분해로 가루가 된 알 수와 가루(2026-10-06).
  ({int eggs, int dust}) lastBossFairyAuto = (eggs: 0, dust: 0);

  /// 보스를 깼다 — 다음 사냥터로. 스테이지는 사냥터 폭(worldSize)만큼 뛰고
  /// 도전 게이지는 0 부터. 마지막 사냥터(최종 보스)면 그대로 둔다 — 회차
  /// 전환은 유저가 누른다.
  ///
  /// 도감 보스 수집도 여기서 남긴다(2026-09-15) — 보스 처치가 들어오는 길은
  /// 이 한 곳이다. 아래 난이도로 내려가 잡아도 수집은 된다.
  ///
  /// 보스를 잡으면 **스킬 조각**도 떨어진다(§2.8) — 그 난이도에서 처음 잡은
  /// 보스면 많이, 다시 잡으면 조금. 받은 조각(스킬 id → 개수)을 돌려준다.
  /// 사냥터 보스 처치 → 다음 사냥터 — 길드전 3일차.
  Future<Map<String, int>> advanceZone({math.Random? rng}) async {
    // 쓰러져 내려온 칸의 보스를 다시 잡는 건 **되찾기**다 — 길드전 집계에 넣지 않는다. 넣으면 장비를 빼서
    // 일부러 쓰러지고(게이지가 찬 채 도착) 곧바로 잡는 반복이 4분에 한 번이던 처치를 몇 초에 한 번으로 만든다.
    final reclaim = (state.value?.capStage ?? 0) > 0;
    final r = await _advanceZoneImpl(rng: rng);
    if (!reclaim) {
      GuildWarTally.add('zoneClear', ref.read(clockProvider).now().toUtc());
    }
    return r;
  }

  Future<Map<String, int>> _advanceZoneImpl({math.Random? rng}) async {
    final data = ref.read(gameDataProvider).value;
    final run = data?.runConfig;
    final s = state.requireValue;
    if (run == null || !run.zoneMode) return const {};
    // 심연 층 보스는 사냥터 보스가 아니다 — 층 규칙(`clearAbyssFloor`)으로 따로 간다.
    if (s.inAbyss) return (await clearAbyssFloorNow(rng: rng)).shards;
    final zone = run.zoneOf(s.stageNumber);
    final artId = run.bossArtId(s.difficultyTier, zone);
    final firstKill = !s.bossDex.contains(artId);
    final bossDex = firstKill ? {...s.bossDex, artId} : s.bossDex;
    // 쓰러져 내려왔으면 한계를 한 칸 올린다(zone_fall.dart).
    var next = liftClimbCap(
      s.copyWith(bossDex: bossDex),
      run,
      tier: s.difficultyTier,
      zone: zone,
    );
    var shards = const <String, int>{};
    final skillCfg = data?.skillConfig;
    // 되찾기(한계가 있던 채로 잡음)는 재처치 조각을 굴리지 않는다 — 일부러 쓰러졌다 잡는 반복 파밍 차단.
    // 첫 처치(도감에 없던 보스)는 그대로 준다.
    final reclaim = s.capStage > 0;
    if (skillCfg != null && (firstKill || !reclaim)) {
      final got = grantBossShards(
        next,
        skillCfg,
        rng ?? math.Random(),
        tier: s.difficultyTier,
        firstKill: firstKill,
      );
      next = got.save;
      shards = got.shards;
    }
    // 결투석 — 보스 **재처치**(첫 처치·되찾기 제외)면 오행 1% · 기질 0.5%(design_training_v2.md §3).
    // 스킬 조각 뒤에 굴린다(rng 소비 순서를 바꾸면 같은 seed 의 조각이 달라진다).
    lastDuelStones = const {};
    if (!firstKill && !reclaim) {
      final st = rollDuelStones(
        next,
        _stoneCfg,
        rng ?? math.Random(),
        DuelStoneSource.bossRepeat,
      );
      next = st.save;
      lastDuelStones = st.got;
    }
    // 요정 — 보스 **첫 처치**면 난이도별 알 1개 확정 + 속성석(§2.8 무료 경로, design_fairy.md §1.4).
    // 스킬 조각 뒤에 굴린다(rng 소비 순서를 바꾸면 같은 seed 의 조각이 달라진다).
    lastBossFairyEggs = const [];
    lastBossFairyOverflow = (eggs: 0, dust: 0);
    lastBossFairyAuto = (eggs: 0, dust: 0);
    final fairyCfg = data?.fairyConfig;
    if (fairyCfg != null && firstKill) {
      final drop = fairyBossDrop(
        next.fairy,
        fairyCfg,
        rng ?? math.Random(),
        tier: s.difficultyTier,
        firstKill: true,
      );
      next = next.copyWith(fairy: drop.state);
      lastBossFairyEggs = drop.extra['eggs'] as List<FairyGrade>;
      lastBossFairyOverflow = (
        eggs: (drop.extra['overflowEggs'] as int?) ?? 0,
        dust: (drop.extra['overflowDust'] as int?) ?? 0,
      );
      lastBossFairyAuto = (
        eggs: (drop.extra['autoEggs'] as int?) ?? 0,
        dust: (drop.extra['autoDust'] as int?) ?? 0,
      );
    }
    if (!run.isFinalZone(zone)) {
      next = next.copyWith(
        stageNumber: run.zoneStartStage(zone + 1),
        zoneKills: 0,
      );
    } else {
      // 최종 보스도 게이지를 비운다 — 예전엔 안 비워서 최종 보스를 곧바로 무한 반복했다
      // (보스 골드 ×8 + 조각이 사실상의 엔드게임이었다, 2026-09-28 조사).
      next = next.copyWith(zoneKills: 0);
      // 극한 최종 보스 → 심연이 열린다.
      if (s.difficultyTier >= abyssTier(run)) next = unlockAbyss(next);
    }
    await _commit(next);
    return shards;
  }

  // ── 심연(극한 이후 무한 층, docs/design_abyss.md) ───────────────────

  String _abyssWeekNow() => abyssWeekId(
    ref.read(clockProvider).now().toUtc(),
    ref.read(gameDataProvider).requireValue.battleConfig ??
        const BattleConfig(),
  );

  /// 심연으로 — 극한 끝에 고정, 게이지 비움, 주가 바뀌었으면 1층.
  Future<void> enterAbyssNow() async {
    final run = ref.read(gameDataProvider).requireValue.runConfig;
    if (run == null) return;
    final s = state.requireValue;
    if (!s.abyssUnlocked) return;
    await _commit(enterAbyss(s, run, _abyssWeekNow()));
  }

  /// 심연 보스에게 넣은 피해 비율 기록(주간 순위 동률 판정). 바뀔 때만 저장한다.
  Future<void> recordAbyssBossDamageNow(double fraction) async {
    final s = state.requireValue;
    final next = recordAbyssBossDamage(s, fraction);
    if (!identical(next, s)) await _commit(next);
  }

  /// 심연에서 나온다(극한 최종 사냥터로).
  Future<void> leaveAbyssNow() async {
    await _commit(leaveAbyss(state.requireValue));
  }

  /// 층 보스 처치 → 다음 층(+ 10층마다 첫 도달 보상). 주가 바뀌었으면 1층으로만 돌린다.
  Future<({bool milestone, int floor, Map<String, int> shards, int fossil})>
  clearAbyssFloorNow({math.Random? rng}) async {
    final data = ref.read(gameDataProvider).requireValue;
    final run = data.runConfig;
    final s0 = state.requireValue;
    if (run == null || !s0.inAbyss) {
      return (
        milestone: false,
        floor: s0.abyssFloor,
        shards: const <String, int>{},
        fossil: 0,
      );
    }
    final week = _abyssWeekNow();
    if (s0.abyssWeek != week) {
      final reset = applyAbyssWeek(s0, week);
      await _commit(reset);
      return (
        milestone: false,
        floor: reset.abyssFloor,
        shards: const <String, int>{},
        fossil: 0,
      );
    }
    final r = clearAbyssFloor(
      s0,
      run,
      skill: data.skillConfig,
      rng: rng ?? math.Random(),
    );
    // 결투석 — 10층마다 **첫 도달**(역대 최고 기준, 화석·조각과 같은 판정)에 오행 2 · 기질 1.
    var saved = r.save;
    lastDuelStones = const {};
    if (r.milestone) {
      final st = grantAbyssDuelStones(saved, _stoneCfg, s0.abyssFloor);
      saved = st.save;
      lastDuelStones = st.got;
    }
    await _commit(saved);
    return (
      milestone: r.milestone,
      floor: r.save.abyssFloor,
      shards: r.shards,
      fossil: r.fossil,
    );
  }

  /// 도감에 잡힌 보스 수(옛 클리어 기록 포함, `collectedBosses`).
  int get collectedBossCount {
    final data = ref.read(gameDataProvider).value;
    final run = data?.runConfig;
    if (data == null || run == null) return 0;
    return collectedBosses(state.requireValue, run, data.roadmapConfig).length;
  }

  /// 사냥터를 고른다(로드맵에서 탭). 점령한 사냥터까지만.
  Future<void> selectZone(int zone) async {
    final run = ref.read(gameDataProvider).value?.runConfig;
    final s = state.requireValue;
    if (run == null || !run.zoneMode) return;
    final current = run.zoneOf(s.stageNumber);
    // 점령한 사냥터까지는 오간다(내려갔다가 다시 올라와도 된다). 그 위는 보스를
    // 깨야 한다. 게이지는 사냥터마다 따로 세지 않는다(단순함) — 옮기면 0 부터.
    final top = math.min(
      run.zoneOf(s.highestStageInTier(run)),
      run.zonesPerTier,
    );
    final target = zone.clamp(1, top);
    if (target == current) return;
    await _commit(
      s.copyWith(stageNumber: run.zoneStartStage(target), zoneKills: 0),
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
      // 상한(§6 `maxLevel`). 여기서 막아야 한다 — 화면만 막으면 연타·구버전
      // 앱이 그대로 넘긴다.
      if (!spec.canBuyAt(level)) break;
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
  ///
  /// [tier] 를 주면 **그 난이도일 때만** 쓴다(2026-10-05) — 최종 보스 직후 다음 난이도로 자동으로
  /// 넘어간 세이브에 옛 난이도의 스테이지(1001)를 써넣어, 새 난이도 사냥터 1~10 이 통째로 깬 것이 됐다.
  Future<void> reachStage(int stage, {int? tier}) async {
    final s = state.requireValue;
    if (tier != null && s.difficultyTier != tier) return;
    if (stage <= s.stageNumber) return;
    await _commit(s.copyWith(stageNumber: stage));
  }

  /// 최고 도달 스테이지 기준으로 **처음 클리어한 챕터**들의 보상을 지급하고,
  /// 새로 클리어한 챕터 목록을 반환한다(UI 축하 팝업용). 없으면 빈 리스트.
  ///
  /// 기록 키와 골드는 난이도마다 다르다(`chapterClearKey` · `chapterClearGold`,
  /// 서버 허용치와 같은 함수).
  ///
  /// [tier] 를 주면 지금 난이도가 그와 다를 때 아무것도 안 한다 — [reachStage] 와 같은 이유.
  Future<List<({RoadmapChapter chapter, int gold})>> grantChapterClears({
    int? tier,
  }) async {
    final data = ref.read(gameDataProvider).requireValue;
    final cfg = data.roadmapConfig;
    final run = data.runConfig;
    if (cfg == null || run == null) return const [];
    final s = state.requireValue;
    // 클리어 보상은 **가 본 가장 높은 난이도**에서만 — 아래 난이도로 내려가면
    // 이미 다 깬 곳이라, 기록이 없는 옛 세이브가 한꺼번에 받는 일이 없게.
    if (s.difficultyTier < s.topTier) return const [];
    if (tier != null && s.difficultyTier != tier) return const [];
    final at = s.difficultyTier;
    final newly = <({RoadmapChapter chapter, int gold})>[];
    for (final ch in cfg.chapters) {
      if (chapterClearedAt(
            ch,
            roadmap: cfg,
            run: run,
            tier: at,
            highestStage: s.stageNumber,
            bossDex: s.bossDex,
          ) &&
          !s.clearedChapters.contains(chapterClearKey(ch.id, at))) {
        newly.add((chapter: ch, gold: chapterClearGold(run, ch, at)));
      }
    }
    if (newly.isEmpty) return const [];
    var gold = s.gold;
    final mats = Map<MaterialKind, int>.from(s.materials);
    final cleared = Set<String>.from(s.clearedChapters);
    for (final c in newly) {
      gold += c.gold;
      for (final e in c.chapter.rewardMaterials.entries) {
        mats[e.key] = (mats[e.key] ?? 0) + e.value;
      }
      cleared.add(chapterClearKey(c.chapter.id, at));
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
    final data = ref.read(gameDataProvider).value;
    final run = data?.runConfig;
    // 2026-10-08: **이 유저가 지금 자리에서 직접 사냥한 N분치**(교환소와 같은 식) — 정액과 큰 쪽.
    // 맨몸 기준 골드 표(giftGold)로 재던 시절엔 "2.7분치"가 실제로 18초~1초 미만이었다.
    final hunt = run == null || data == null || t.huntMinutes <= 0
        ? null
        : huntMinutesReward(
            run,
            stats: huntStatsOf(
              s,
              data,
              now,
              guildBonus: ref.read(guildBonusProvider),
            ),
            stage: s.stageNumber,
            minutes: t.huntMinutes,
            tier: s.difficultyTier,
            abyssFloor: activeAbyssFloor(s),
          );
    final gift = GiftMail(
      id: _devUuid.v4(),
      expiry: now.add(Duration(hours: cfg.expiryHours)),
      gold: hunt != null
          ? math.max(t.gold, hunt.gold)
          : run == null
          ? t.gold
          // 정액과 **지금 사냥터 분치** 중 큰 쪽(2026-09-18, 옛 데이터용).
          : giftGold(
              run,
              s.stageNumber,
              s.difficultyTier,
              t.gold,
              t.goldMinutes,
            ),
      jelly: t.jelly,
      chitin: math.max(t.chitin, hunt?.materialsEach ?? 0),
      mineral: math.max(t.mineral, hunt?.materialsEach ?? 0),
      sap: math.max(t.sap, hunt?.materialsEach ?? 0),
      minutes: hunt == null ? 0 : t.huntMinutes,
    );
    await _commit(s.copyWith(gifts: [...alive, gift], nextGiftAt: reschedule));
  }

  /// 지금 2배로 받을 수 있는가. (false 면 1배로만 수령된다)
  ///
  /// 패스 보유자는 무제한 — 나머지는 하루 [GiftConfig.freeDoubleDaily] 회.
  /// 카운터는 전용 필드([SaveGame.giftDoubleCount])다 — `adUseCounts` 는 서버
  /// 소유라 업로드마다 덮여 상한이 리셋됐다(감사에서 발견 2026-08-20).
  bool canDoubleGift() {
    final s = state.requireValue;
    final now = ref.read(clockProvider).now().toUtc();
    if (s.anyPassActive(now)) return true;
    final cfg = ref.read(gameDataProvider).requireValue.giftConfig;
    final cap = cfg?.freeDoubleDaily ?? 1;
    return s.giftDoublesUsed(dailyDateKey(now)) < cap;
  }

  /// 깜짝 선물 수령. [doubled]=2배 요청. 만료/없음이면 false.
  ///
  /// 2배는 **요청해도 자격이 없으면 1배로** 나간다(수령 자체는 막지 않는다) —
  /// 이미 뜬 보상을 못 받게 하면 불만이 크고, 유도는 화면에서 하면 된다.
  Future<bool> claimGift(String id, {bool doubled = false}) async {
    final viaServer = await _viaServer(
      () => ref.read(gameServerProvider).claimGift(id, doubled: doubled),
    );
    if (viaServer != null) return viaServer;

    // 규칙(2배 자격·배수·첫 2배 젤리)은 서버와 같은 공용 함수 한 곳에 있다(§4).
    final r = claimGiftOn(
      state.requireValue,
      ref.read(gameDataProvider).requireValue.giftConfig,
      id,
      doubled: doubled,
      now: ref.read(clockProvider).now().toUtc(),
    );
    if (r.save != null) await _commit(r.save!);
    return r.error == null;
  }

  /// 오늘 2배로 받으면 젤리가 붙는가(받기 전에 안내하려고).
  bool hasGiftDoubleJelly() => giftDoubleJellyPending(
    state.requireValue,
    ref.read(gameDataProvider).requireValue.giftConfig,
    ref.read(clockProvider).now().toUtc(),
  );

  /// 패스 보유자용 **자동수령** — 쌓인 선물을 전부 2배로 받는다.
  ///
  /// 선물은 접속 1시간에 5.5개씩 나와서 탭 노동이 만만치 않다. 그 노동을
  /// 없애는 게 패스의 값어치다(젤리를 더 주는 것보다 상품성이 좋다).
  /// 만료된 선물은 그냥 버린다(수령 로직과 같은 규칙).
  Future<int> autoClaimGifts() async {
    final now = ref.read(clockProvider).now().toUtc();
    if (!state.requireValue.anyPassActive(now)) return 0;
    var n = 0;
    // id 목록을 먼저 뜬다 — 수령할 때마다 목록이 바뀐다.
    for (final id in [...state.requireValue.gifts.map((g) => g.id)]) {
      if (await claimGift(id, doubled: true)) n++;
    }
    return n;
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

    final battle =
        ref.read(gameDataProvider).requireValue.battleConfig ??
        const BattleConfig();
    final fairyCfg = ref.read(gameDataProvider).requireValue.fairyConfig;
    // 계정당 1회(스타터 · 요정/스킬 입문 패키지).
    if (iapIsOncePerAccount(p) &&
        iapPurchaseBlock(s, p, battle: battle, now: now) == IapBlock.owned) {
      return false;
    }
    // 요정 알은 요정함 상한을 설정에서 읽는다 — 설정이 없으면 지급하지 않는다(서버도 보류한다).
    if (iapNeedsFairyConfig(p) && fairyCfg == null) return false;

    // 지급 내용은 서버 `GameActions.grantPurchase` 와 **같은 함수**(core_save `applyIapGrant`).
    // 주간 묶음은 여기서 막지 않는다 — 결제가 끝난 영수증이다. 구매 전 차단은 상점이 한다.
    var next = applyIapGrant(
      s,
      p,
      cfg ?? const IapConfig(products: []),
      battle: battle,
      now: now,
      fairy: fairyCfg,
      purchaseId: purchaseId,
      speciesOf: (id) => ref.read(gameDataProvider).value?.speciesById[id],
    );
    // 성장 패스를 샀으면 오늘 몫을 바로 준다(다음 실행까지 기다리게 하지 않는다).
    if (cfg != null) {
      next =
          claimGrowthPassDaily(
            next,
            cfg,
            now: now,
            today: dailyDateKey(ref.read(clockProvider).now()),
            fairy: fairyCfg,
          ) ??
          next;
    }
    await _commit(next);
    return true;
  }

  // ⚠️ `grantGiftBonus`(선물 1배 수령 뒤 로컬로 1배 더 얹기)는 삭제했다
  // (2026-09-12). 수령이 서버 경로라 **서버가 돌려준 세이브를 채택**하는 순간
  // 로컬로 올려 둔 무료 2배 횟수가 날아가, 하루 1회 제한이 사실상 없었다.
  // 2배는 이제 [claimGift] 한 곳에서 **서버가 판정하고 센다**.

  /// PvP 결과 반영: 승리 시 골드 지급, 트로피 증감(최소 0).
  /// 결투 결과 반영: 골드·트로피 정산 + KO된 내 곤충([koedBugIds])에 부상 회복 타이머 부여.
  /// (수동 전투) **부상 선차감** — 팀 전체에 회복 타이머를 미리 건다.
  ///
  /// 트로피만 미리 깎으면 곤충은 멀쩡히 빠져나간다 — 지고 있을 때 이탈하면
  /// KO 대가(회복 타이머)를 통째로 피할 수 있었다(감사 후 보완 2026-08-20).
  /// 결착에서 살아남은 곤충은 [applyBattleResult] 의 healBugIds 로 되돌린다.
  /// 편성 검증이 부상 곤충을 거부하므로, 이 시점의 팀은 전부 무부상이다.
  /// 결투 **방어 순서**를 저장한다(곤충 id 3개). 다른 유저가 도전하면 서버가 이 순서로
  /// **내 세이브에서** 방어팀 스탯을 계산한다 — 앱이 스탯을 올리던 옛 방식의 위조 구멍을 닫는다.
  /// 결투할 때의 출전 순서를 그대로 쓴다(따로 고르는 화면 없이 "내가 싸우는 순서 = 지키는 순서").
  Future<void> setPvpDefense(List<String> bugIds) async {
    final s = state.requireValue;
    if (bugIds.length == s.pvpDefenseIds.length &&
        [
          for (var i = 0; i < bugIds.length; i++)
            bugIds[i] == s.pvpDefenseIds[i],
        ].every((x) => x)) {
      return;
    }
    await _commit(s.copyWith(pvpDefenseIds: List.unmodifiable(bugIds)));
  }

  Future<void> preInjureTeam(List<String> bugIds) async {
    final data = ref.read(gameDataProvider).requireValue;
    final cfg = data.petConfig;
    if (cfg == null) return;
    final now = ref.read(clockProvider).now().toUtc();
    final s = state.requireValue;
    final injured = Map<String, DateTime>.from(s.injured);
    for (final id in bugIds) {
      final bug = s.bugs.cast<IndividualBug?>().firstWhere(
        (b) => b!.id == id,
        orElse: () => null,
      );
      final sp = bug == null ? null : data.speciesById[bug.speciesId];
      if (sp == null) continue;
      injured[id] = now.add(Duration(seconds: cfg.injuryDuration(sp.grade)));
    }
    await _commit(s.copyWith(injured: injured));
  }

  Future<void> applyBattleResult({
    required int gold,
    required int trophyDelta,
    List<String> koedBugIds = const [],

    /// 부상을 **지울** 곤충(수동 결착의 생존자). 선차감(preInjureTeam)을
    /// 되돌리는 용도다 — KO 목록보다 먼저 처리되므로 KO 는 그대로 걸린다.
    List<String> healBugIds = const [],
  }) async {
    final data = ref.read(gameDataProvider).requireValue;
    final cfg = data.petConfig;
    final now = ref.read(clockProvider).now().toUtc();
    final s = state.requireValue;
    final injured = Map<String, DateTime>.from(s.injured);
    for (final id in healBugIds) {
      injured.remove(id);
    }
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
        gold: addCurrency(s.gold, gold < 0 ? 0 : gold),
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

  /// 게임 안 리뷰 창을 [tier] 난이도에서 띄웠다고 기록. [opened] 면 스토어를 연 것 — 더 묻지 않는다.
  Future<void> markReviewPrompt(int tier, {required bool opened}) async {
    final s = state.requireValue;
    await _commit(
      s.copyWith(
        reviewAsked: true,
        reviewPromptTier: tier > s.reviewPromptTier ? tier : s.reviewPromptTier,
        reviewOpened: s.reviewOpened || opened,
      ),
    );
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
    final refillUsed = (data['refillUsed'] as num?)?.toInt();
    final today = dailyDateKey(ref.read(clockProvider).now().toUtc());
    final touched = adUsed != null || refillUsed != null;
    await _commit(
      s.copyWith(
        pvpTickets: tickets,
        ticketsAt: at,
        adUseCounts: !touched
            ? null
            : {
                ...(s.adUseDate == today ? s.adUseCounts : const {}),
                kAdFeaturePvpTicket: ?adUsed,
                kAdFeaturePvpRefill: ?refillUsed,
              },
        adUseDate: !touched ? null : today,
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
      return switch (res.error) {
        'ad_limit' => TicketCharge.adLimit,
        'season_closed' => TicketCharge.seasonClosed,
        _ => TicketCharge.failed,
      };
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
    final today = dailyDateKey(now);
    final refillUsed = s.adUseCount(kAdFeaturePvpRefill, today);
    if (cfg.ticketRefillDailyLimit > 0 &&
        refillUsed >= cfg.ticketRefillDailyLimit) {
      return TicketCharge.refillLimit;
    }
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
          'refill_limit' => TicketCharge.refillLimit,
          'season_closed' => TicketCharge.seasonClosed,
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
        adUseCounts: {
          ...(s.adUseDate == today ? s.adUseCounts : const {}),
          kAdFeaturePvpRefill: refillUsed + 1,
        },
        adUseDate: today,
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
    final claimable = cfg.claimableUpTo(pvpLeagueOf(s, cfg), s.claimedLeagues);
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
      s.copyWith(
        gold: addCurrency(s.gold, gold),
        materials: mats,
        claimedLeagues: claimed,
      ),
    );
    return (gold: gold, jelly: jelly);
  }

  // ── 훈련 v2(2026-10-08, docs/design_training_v2.md) ─────────────────
  //
  // 솔로 루프와 같은 기기 권위 — 규칙은 core_save/train_points.dart(서버와 같은 함수).
  // 서버는 업로드 때 배분을 예산·칸 상한으로 자르고(`sanitizeTrainPoints`), 결투 팀을 만들 때도 자른다.
  // 화면(훈련소 재작성)은 다음 단계 — 여기는 화면이 붙을 API 다.

  /// 이전(옛 부위 강화·훈련 단계 → 칸). 기록이 있는 곤충은 건드리지 않는다(멱등).
  SaveGame _migrateTrainV2(SaveGame s, GameData data) => migrateTrainingV2(
    s,
    (data.battleConfig ?? const BattleConfig()).training,
    speciesOf: (id) => data.speciesById[id],
    enhance: data.enhanceConfig,
  );

  /// 이 곤충의 훈련 기록(이전 전이면 옛 투자로 만든 가상 기록).
  BugTrain bugTrainNow(String bugId) {
    final data = ref.read(gameDataProvider).requireValue;
    final s = state.requireValue;
    final bug = s.bugs.where((b) => b.id == bugId).firstOrNull;
    if (bug == null) return const BugTrain();
    return bugTrainOf(
      s,
      bug,
      data.species(bug.speciesId),
      _battleCfg.training,
      enhance: data.enhanceConfig,
    );
  }

  /// 이 곤충의 포인트 예산(보너스 포함)과 칸 상한.
  ({int budget, Map<TrainSlot, int> caps}) trainLimitsNow(String bugId) {
    final data = ref.read(gameDataProvider).requireValue;
    final s = state.requireValue;
    final bug = s.bugs.where((b) => b.id == bugId).firstOrNull;
    if (bug == null) return (budget: 0, caps: const {});
    final sp = data.species(bug.speciesId);
    final cfg = _battleCfg.training;
    final legacy = legacyTrainPoints(
      s,
      bug,
      sp,
      cfg,
      enhance: data.enhanceConfig,
    );
    return (
      budget: trainBudgetOf(s, bug, sp, cfg, enhance: data.enhanceConfig),
      caps: {
        for (final sl in TrainSlot.values)
          sl: trainSlotCapOf(s, bug, sp, sl, cfg, legacy: legacy),
      },
    );
  }

  /// 칸 [slot] 에 [count]포인트 찍기. 성공하면 null, 실패하면 사유
  /// (`no_bug`·`respec`·`busy`·`maxed`·`points`·`materials`). 재료를 낸 포인트가 남아 있으면 바로 찍힌다.
  /// 길드전 5일차 훈련 집계는 재료를 내고 시작할 때 센다(옛 훈련소 단계와 같은 자리).
  Future<String?> allocTrainPointNow(
    String bugId,
    TrainSlot slot, {
    int count = 1,
  }) async {
    final data = ref.read(gameDataProvider).requireValue;
    final s = state.requireValue;
    final bug = s.bugs.where((b) => b.id == bugId).firstOrNull;
    if (bug == null) return 'no_bug';
    final now = ref.read(clockProvider).now().toUtc();
    final r = allocTrainPoint(
      s,
      _battleCfg.training,
      bug,
      data.species(bug.speciesId),
      slot,
      now,
      count: count,
      enhance: data.enhanceConfig,
    );
    if (r.save == null) return r.error;
    final startedJob = r.save!.trainPointJob != null && s.trainPointJob == null;
    await _commit(r.save!);
    if (startedJob) GuildWarTally.add('trainStep', now);
    return null;
  }

  /// 지금 포인트 찍기를 젤리로 끝낸다. 성공하면 null, 부족하면 `jelly`.
  Future<String?> finishTrainPointWithJelly() async {
    final r = instantFinishTrainPoint(
      state.requireValue,
      _battleCfg.training,
      ref.read(clockProvider).now().toUtc(),
    );
    if (r.save == null) return r.error;
    await _commit(r.save!);
    return null;
  }

  /// 다시 찍기 — 배분을 [next] 로(재료 없음 · 대기). 성공하면 null
  /// (`busy`·`respec`·`bad`·`maxed`·`points`·`same`).
  Future<String?> startTrainRespecNow(
    String bugId,
    Map<TrainSlot, int> next,
  ) async {
    final data = ref.read(gameDataProvider).requireValue;
    final s = state.requireValue;
    final bug = s.bugs.where((b) => b.id == bugId).firstOrNull;
    if (bug == null) return 'no_bug';
    final r = startTrainRespec(
      s,
      _battleCfg.training,
      bug,
      data.species(bug.speciesId),
      next,
      ref.read(clockProvider).now().toUtc(),
      enhance: data.enhanceConfig,
    );
    if (r.save == null) return r.error;
    await _commit(r.save!);
    return null;
  }

  /// 다시 찍기 대기를 젤리로 당긴다. 성공하면 null(`none`·`jelly`).
  Future<String?> finishTrainRespecWithJelly(String bugId) async {
    final r = instantFinishTrainRespec(
      state.requireValue,
      _battleCfg.training,
      bugId,
      ref.read(clockProvider).now().toUtc(),
    );
    if (r.save == null) return r.error;
    await _commit(r.save!);
    return null;
  }

  /// 다시 찍기 대기 취소(배분은 그대로).
  Future<String?> cancelTrainRespecNow(String bugId) async {
    final r = cancelTrainRespec(state.requireValue, bugId);
    if (r.save == null) return r.error;
    await _commit(r.save!);
    return null;
  }

  /// 이 곤충이 훈련 때문에 출전할 수 없나(찍는 중 · 다시 찍기 대기).
  bool trainBusyNow(String bugId) => trainBusy(
    state.requireValue,
    bugId,
    ref.read(clockProvider).now().toUtc(),
  );

  /// 젤리로 결투석 사기. 성공하면 null(`off`·`count`·`jelly`).
  Future<String?> buyDuelStoneNow(DuelStone kind, {int count = 1}) async {
    final r = buyDuelStone(
      state.requireValue,
      _battleCfg.training.stones,
      kind,
      count: count,
    );
    if (r.save == null) return r.error;
    await _commit(r.save!);
    return null;
  }

  /// 결투석으로 오행·기질 바꾸기(둘 중 하나만). 성공하면 null(`no_bug`·`bad`·`same`·`stone`).
  Future<String?> useDuelStoneNow(
    String bugId, {
    Element? element,
    Temperament? temperament,
  }) async {
    final r = useDuelStone(
      state.requireValue,
      bugId,
      element: element,
      temperament: temperament,
    );
    if (r.save == null) return r.error;
    await _commit(r.save!);
    return null;
  }

  /// 결투석 드롭 설정.
  DuelStoneConfig get _stoneCfg => _battleCfg.training.stones;

  /// 마지막 정예·보스·심연 처치에서 떨어진 결투석(화면 알림용 — 다음 단계 UI).
  Map<DuelStone, int> lastDuelStones = const {};

  // ── 옛 훈련소 화면 다리(화면 재작성 전까지) ──────────────────────────
  // 옛 화면(training_screen)이 부르는 이름을 v2 로 잇는다 — 옛 능력치 5종을 같은 이름의 칸에 1포인트씩.
  // 옛 단계를 올리는 함수는 없어졌다(옛 단계는 이전 원본으로만 남는다).

  /// 옛 화면의 "훈련" — 같은 이름의 칸에 1포인트 찍기.
  Future<String?> startDuelTraining(String bugId, TrainStat stat) =>
      allocTrainPointNow(bugId, TrainSlot.fromKeyOrNull(stat.key)!);

  /// 옛 화면의 "젤리로 끝내기".
  Future<String?> finishDuelTrainingWithJelly() => finishTrainPointWithJelly();

  /// 옛 화면의 "초기화" — v2 에는 환불형 초기화가 없다(다시 찍기로 대신). 늘 실패(null).
  Future<int?> resetDuelTraining(String bugId) async => null;

  /// 부상 회복. [viaJelly] 면 남은 시간 비례 젤리를 소비해 즉시 회복,
  /// 아니면 회복 시각이 지났을 때만 정리. 성공 시 true.
  Future<bool> healInjury(String bugId, {bool viaJelly = false}) async {
    final cfg = ref.read(gameDataProvider).requireValue.petConfig;
    if (cfg == null) return false;
    final now = ref.read(clockProvider).now().toUtc();
    final s = state.requireValue;
    // 대회 부상은 서버 소유(`eventFatigue`) — 로컬로 지우면 다음 업로드에 되살아나고 젤리만
    // 사라진다. 서버가 젤리를 깎고 두 기록을 함께 지운 세이브를 채택한다.
    final server = ref.read(gameServerProvider);
    if (viaJelly && server.available && s.eventOnFatigue(bugId, now)) {
      return withServerSaveLock(() async {
        if (!await flushSaveBeforeServerAction(server, () => latestSave)) {
          return false;
        }
        final r = await server.eventDuelHeal(bugId);
        final json = r.save;
        if (!r.isOk || json == null) return false;
        await adoptServerSave(json);
        return true;
      });
    }
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

  /// 저장 횟수([SaveGame.saveRev])를 [rev] 보다 크게 맞춘다(이미 크면 그대로).
  /// 앱을 켤 때 기기 세이브를 지키기로 한 경우에 부른다 — 서버 횟수를 이어 세야 다음 동점 판정이 맞다.
  Future<void> catchUpSaveRev(int rev) async {
    final s = state.value;
    if (s == null || s.saveRev > rev) return;
    await _commit(s.copyWith(saveRev: rev));
  }

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
      // 성장 패스 오늘 몫 — 결제 직후 서버 세이브를 채택하는 경로(`_grantViaServer`)가 여기다.
      // 이 기기에서 이미 받았다면 채택본에도 오늘 키가 있어(올린 뒤 결제) 두 번 나가지 않는다.
      save = _claimGrowthDaily(save, data);
    }
    // 저장 횟수는 **이어 센다**(둘 중 큰 쪽) — 채택한 뒤의 저장이 이 기기의 옛 횟수보다 작으면
    // 다음 실행의 동점 판정([SaveGame.saveRev])이 거꾸로 간다.
    final localRev = state.value?.saveRev ?? 0;
    if (localRev > save.saveRev) save = save.copyWith(saveRev: localRev);
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

  /// 일일보상 [reward] 의 **지금 금액** — 정액과 "이 유저가 지금 자리에서 직접 사냥한
  /// [DailyReward.huntMinutes]분치"(교환소와 같은 식) 중 큰 쪽(2026-10-08 사장님 확정).
  /// 화면 표시와 수령이 같은 값을 쓴다. 서버는 이 값을 넉넉한 상한으로 잘라 지급한다.
  ({int gold, Map<MaterialKind, int> materials}) dailyRewardAmount(
    DailyReward reward,
  ) {
    final fixed = (gold: reward.gold, materials: reward.materials);
    if (reward.huntMinutes <= 0) return fixed;
    final data = ref.read(gameDataProvider).value;
    final run = data?.runConfig;
    final s = state.value;
    if (data == null || run == null || s == null) return fixed;
    final hunt = huntMinutesReward(
      run,
      stats: huntStatsOf(
        s,
        data,
        ref.read(clockProvider).now().toUtc(),
        guildBonus: ref.read(guildBonusProvider),
      ),
      stage: s.stageNumber,
      minutes: reward.huntMinutes,
      tier: s.difficultyTier,
      abyssFloor: activeAbyssFloor(s),
    );
    return (
      gold: math.max(reward.gold, hunt.gold),
      materials: {
        for (final k in kBreakthroughMaterials)
          k: math.max(reward.materials[k] ?? 0, hunt.materialsEach),
        if (reward.jelly > 0) MaterialKind.jelly: reward.jelly,
      },
    );
  }

  /// 일일보상 수령(편지함). 아직 시간 전·오늘 이미 수령이면 false.
  /// 판정은 **로컬 시각** 기준(점심 12시/저녁 18시).
  ///
  /// [bonus] = 받은 뒤 "한 번 더 받기"(1배 더). 슬롯마다 하루 1회 — 2026-10-08 부터 서버가 센다
  /// (금액이 사냥 분치로 커져서 앱 로컬 지급은 업로드 골드 상한에 잘린다).
  Future<bool> claimDaily(DailyReward reward, {bool bonus = false}) async {
    final now = ref.read(clockProvider).now(); // 로컬 벽시계
    // 시간 게이트(점심/저녁)는 로컬 UI 판정으로 남긴다 — 서버는 UTC 타임존을
    // 모른다. 서버는 하루에 같은 슬롯을 여러 번 먹는 조작만 막는다.
    if (now.hour < reward.hour) return false;
    final amt = dailyRewardAmount(reward);
    final each = amt.materials[MaterialKind.chitin] ?? 0;

    final viaServer = await _viaServer(
      () => ref
          .read(gameServerProvider)
          .claimDaily(
            reward.id,
            gold: amt.gold,
            materialsEach: each,
            bonus: bonus,
          ),
    );
    if (viaServer != null) return viaServer;

    final today = dailyDateKey(now);
    final s = state.requireValue;
    final key = bonus ? dailyBonusKey(reward.id) : reward.id;
    if (s.dailyClaims[key] == today) return false;
    if (bonus && s.dailyClaims[reward.id] != today) return false;
    final mats = Map<MaterialKind, int>.from(s.materials);
    for (final e in amt.materials.entries) {
      mats[e.key] = (mats[e.key] ?? 0) + e.value;
    }
    final claims = Map<String, String>.from(s.dailyClaims)..[key] = today;
    await _commit(
      s.copyWith(
        gold: addCurrency(s.gold, amt.gold),
        materials: mats,
        dailyClaims: claims,
      ),
    );
    return true;
  }

  // ── 개발자(테스트) 전용 ───────────────────────────────────────
  static const _devUuid = Uuid();

  /// (개발) 심연 바로 시험 — 난이도를 극한으로 올리고(가 본 최고도 극한) 심연을 열어 1층으로 들어간다.
  /// 극한 최종 보스를 실제로 잡으려면 며칠 걸려서 만든 지름길이다. 이후 흐름은 전부 실제 코드다.
  Future<void> devOpenAbyss() async {
    final run = ref.read(gameDataProvider).requireValue.runConfig;
    if (run == null) return;
    final tier = abyssTier(run);
    var s = state.requireValue.copyWith(
      difficultyTier: tier,
      maxTierReached: math.max(state.requireValue.maxTierReached, tier),
    );
    s = unlockAbyss(s);
    s = enterAbyss(s, run, _abyssWeekNow());
    await _commit(s);
  }

  /// (개발) 사냥 강화를 전부 최대 레벨로 — 쉬움 전력으로는 극한·심연 몬스터를 못 잡는다.
  Future<void> devMaxUpgrades() async {
    final run = ref.read(gameDataProvider).requireValue.runConfig;
    if (run == null) return;
    final lv = <UpgradeKind, int>{
      for (final k in UpgradeKind.values)
        if (run.upgrades.containsKey(k)) k: run.upgrade(k).maxLevel ?? 500,
    };
    await _commit(state.requireValue.copyWith(upgradeLevels: lv));
  }

  /// (개발) 심연 층을 [n] 만큼 올린다(층 보스를 잡은 것처럼 실제 함수로 — 10층마다 첫 도달 보상 포함).
  Future<void> devAbyssFloors(int n) async {
    for (var i = 0; i < n; i++) {
      await clearAbyssFloorNow();
    }
  }

  /// (개발) 요정 8종을 한 마리씩 넣고 영웅 한 마리를 동행으로 — 방치 런 반영·날아다니는 표시 확인용.
  ///
  /// ⚠️ 서버는 업로드에서 **알 없이 늘어난 등급 가치**를 자른다(무료 여유 30). 그래서 일반 6·희귀 1·영웅 1
  /// (가치 18)만 준다 — 더 주면 다음 업로드에서 높은 것부터 잘려 "넣었는데 사라졌다"가 된다.
  Future<void> devGrantFairies() async {
    final cfg = ref.read(gameDataProvider).requireValue.fairyConfig;
    if (cfg == null) return;
    final rng = math.Random();
    var f = state.requireValue.fairy;
    final subs = cfg.subWeight.keys.toList();
    String? epicId;
    for (final (i, k) in cfg.kinds.indexed) {
      final grade = i == 0
          ? FairyGrade.epic
          : i == 1
          ? FairyGrade.rare
          : FairyGrade.common;
      final id = 'f${f.seq + 1}';
      f = f.copyWith(
        seq: f.seq + 1,
        fairies: [
          ...f.fairies,
          Fairy(
            id: id,
            kind: k.id,
            grade: grade,
            sub: subs[rng.nextInt(subs.length)],
            baseRoll: cfg.rollQuality(rng),
            subRoll: cfg.rollQuality(rng),
          ),
        ],
        dex: {...f.dex, FairyState.dexKey(k.id, grade)},
      );
      if (grade == FairyGrade.epic) epicId = id;
    }
    f = enforceFairyRules(f.copyWith(companionId: epicId), cfg);
    await _commit(state.requireValue.copyWith(fairy: f));
  }

  // ── (개발) 요정 점검 묶음(2026-10-01 사장님 요청) ──
  // ⚠️ 테스트 앱도 운영 서버에 붙는다 — 서버 업로드 상한(요정 가치 급증)이 개발로 넣은 요정·알을
  // 다음 업로드 때 잘라 낼 수 있다. 화면 확인용이다.

  FairyConfig? get _fairyCfg =>
      ref.read(gameDataProvider).requireValue.fairyConfig;

  Future<void> _devFairy(
    FairyState Function(FairyState f, FairyConfig cfg) fn,
  ) async {
    final cfg = _fairyCfg;
    if (cfg == null) return;
    final s = state.requireValue;
    await _commit(s.copyWith(fairy: fn(s.fairy, cfg)));
  }

  /// (개발) 요정 알 — 등급마다 하나씩(일반~신화).
  Future<void> devFairyEggs() => _devFairy((f, cfg) {
    final op = grantFairyEggs(f, cfg, FairyGrade.values);
    return op.state ?? f;
  });

  /// (개발) 둥지 부화를 지금 끝낸다(수령 버튼 확인용).
  Future<void> devFairyNestNow() => _devFairy((f, cfg) {
    final n = f.nest;
    if (n == null) return f;
    return f.copyWith(
      nest: n.copyWith(endsAt: ref.read(clockProvider).now().toUtc()),
    );
  });

  /// (개발) 속성석 7종 ×10 · 가속기 전 종류 ×5 · 요정 가루 +5,000.
  Future<void> devFairyItems() => _devFairy(
    (f, cfg) => grantFairyItems(
      f,
      stones: {for (final k in cfg.subWeight.keys) k: 10},
      accelerators: {for (final a in cfg.accelerators) a.id: 5},
      dust: 5000,
    ),
  );

  /// (개발) 자동 합성 재료 — 첫 번째 종류의 일반 요정 9마리(합성하면 희귀 3마리).
  Future<void> devFairyMergeFodder() => _devFairy((f, cfg) {
    final rng = math.Random();
    final subs = cfg.subWeight.keys.toList();
    var out = f;
    for (var i = 0; i < 9; i++) {
      out = out.copyWith(
        seq: out.seq + 1,
        fairies: [
          ...out.fairies,
          Fairy(
            id: 'f${out.seq + 1}',
            kind: cfg.kinds.first.id,
            grade: FairyGrade.common,
            sub: subs[rng.nextInt(subs.length)],
            baseRoll: cfg.rollQuality(rng),
            subRoll: cfg.rollQuality(rng),
          ),
        ],
      );
    }
    return enforceFairyRules(out, cfg);
  });

  /// (개발) 뽑기 천장 직전(다음 한 번이 천장).
  Future<void> devFairyPityNear() =>
      _devFairy((f, cfg) => f.copyWith(gachaPity: cfg.gachaPity - 1));

  /// (개발) 요정 전부 비우기(요정·알·둥지·아이템·도감).
  Future<void> devFairyReset() => _devFairy((f, cfg) => FairyState.empty);

  /// (개발) 동행 요정을 다음 요정으로 바꾼다(없으면 첫 요정). 요정 스킬을 종류별로 확인하는 용도.
  Future<String?> devCycleFairy() async {
    final f = state.requireValue.fairy;
    if (f.fairies.isEmpty) return null;
    final i = f.fairies.indexWhere((x) => x.id == f.companionId);
    final next = f.fairies[(i + 1) % f.fairies.length];
    await _commit(
      state.requireValue.copyWith(fairy: f.copyWith(companionId: next.id)),
    );
    return next.kind;
  }

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

  /// (개발) 스킨 보유를 켜고 끈다.
  ///
  /// 스킨은 IAP 로만 얻는데 사이드로드 빌드에서는 Play Billing 이 동작하지
  /// 않아 **실기에서 확인할 방법이 없었다**. 색 필터가 종마다 어떻게 나오는지는
  /// 실기로 봐야 하므로(2026-08-18 알비노가 회색이던 사고) 여기서 넣고 뺀다.
  /// ⚠️ `ownedSkins` 는 서버 소유 필드라 **업로드하면 서버 값으로 되돌아간다**
  /// — 로컬에서 보는 용도다.
  Future<bool> devToggleSkin(String skinId) async {
    final s = state.requireValue;
    final on = !s.ownedSkins.contains(skinId);
    await _commit(
      s.copyWith(
        ownedSkins: on
            ? {...s.ownedSkins, skinId}
            : (s.ownedSkins.toSet()..remove(skinId)),
      ),
    );
    return on;
  }

  /// (개발) 스테이지 세이브 기록. 라이브 점프는 PlayScreen 에서 처리.
  Future<void> devSetStage(int stage) async {
    final n = stage < 1 ? 1 : stage;
    await _commit(state.requireValue.copyWith(stageNumber: n));
  }

  /// (개발) 패스를 전부 해제한다 — 켠 뒤 **끄고 다시 보는** 확인이 필요하다.
  ///
  /// ⚠️ 서버 권위 모드에서는 `passExpiresAt`·`buffPassExpiresAt` 가 서버 소유라
  /// 다음 업로드에 서버 값으로 되돌아온다. 로컬 확인용이다.
  Future<void> devClearPasses() async {
    final s = state.requireValue;
    await _commit(
      s.copyWith(
        passExpiresAt: DateTime.fromMillisecondsSinceEpoch(0).toUtc(),
        buffPassExpiresAt: DateTime.fromMillisecondsSinceEpoch(0).toUtc(),
      ),
    );
  }

  /// (개발) 보유 곤충의 이색을 바꾼다 — 1/300 을 실기에서 기다릴 수 없어서.
  ///
  /// 새로 만들지 않고 **가진 것을 바꾼다**: 채집함 상한·도감 갱신 경로를
  /// 그대로 타야 "이색이 도감에 남는가"까지 진짜로 확인된다.
  /// [v] 가 none 이면 전부 보통으로 되돌린다.
  Future<String> devMakeVariant(BugVariant v) async {
    final s = state.requireValue;
    if (s.bugs.isEmpty) return '곤충이 없다';
    if (v == BugVariant.none) {
      await _commit(
        s.copyWith(bugs: [for (final b in s.bugs) b.copyWith(variant: v)]),
      );
      return '전부 보통으로';
    }
    // 이미 그 이색이 아닌 첫 마리를 바꾼다 — 누르는 만큼 늘어난다.
    final idx = s.bugs.indexWhere((b) => b.variant != v);
    if (idx < 0) return '전부 이미 ${v.key}';
    final bugs = List<IndividualBug>.from(s.bugs);
    bugs[idx] = bugs[idx].copyWith(variant: v);
    await _commit(s.copyWith(bugs: bugs));
    return '${bugs[idx].speciesId} → ${v.key}';
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

  /// **개발자 모드 전용** — 스킬 하나를 원하는 레벨로 켜고 칸이 남으면 장착한다.
  ///
  /// 스킬은 보스 조각으로만 열리므로(§2.8) 실기기에서 12종을 보려면
  /// 며칠이 걸린다. 미리 보기 위한 스위치다 — 규칙 강제(`enforceSkillRules`)를
  /// 그대로 통과하므로 상한을 넘은 값은 저장되지 않는다.
  Future<void> devSetSkillLevel(String id, int level) async {
    final cfg = ref.read(gameDataProvider).value?.skillConfig;
    if (cfg == null || cfg.byId(id) == null) return;
    final s = state.requireValue;
    final levels = Map<String, int>.from(s.skillLevels);
    if (level <= 0) {
      levels.remove(id);
    } else {
      levels[id] = level.clamp(1, cfg.maxLevel);
    }
    final equipped = [...s.equippedSkills];
    if (level <= 0) {
      equipped.remove(id);
    } else if (!equipped.contains(id) &&
        equipped.length < cfg.slotsFor(s.topTier)) {
      equipped.add(id);
    }
    await _commit(
      enforceSkillRules(
        s.copyWith(skillLevels: levels, equippedSkills: equipped),
        cfg,
      ),
    );
  }

  /// **개발자 모드 전용** — 12종 전부 켜거나 전부 끈다.
  Future<void> devAllSkills({required bool on, int level = 1}) async {
    final cfg = ref.read(gameDataProvider).value?.skillConfig;
    if (cfg == null) return;
    final s = state.requireValue;
    if (!on) {
      await _commit(
        s.copyWith(skillLevels: const {}, equippedSkills: const []),
      );
      return;
    }
    final levels = <String, int>{
      for (final d in cfg.skills) d.id: level.clamp(1, cfg.maxLevel),
    };
    // 장착은 열린 칸만큼만 — 넘치면 규칙 강제가 자른다.
    final equipped = [
      for (final d in cfg.skills.take(cfg.slotsFor(s.topTier))) d.id,
    ];
    await _commit(
      enforceSkillRules(
        s.copyWith(skillLevels: levels, equippedSkills: equipped),
        cfg,
      ),
    );
  }

  /// **개발자 모드 전용** — 스킬 장착 칸을 전부 연다.
  ///
  /// 칸은 **처음 가 본 난이도**로만 열린다(§2.8) — 쉬움만 가 봤으면 2칸이라
  /// 5칸짜리 로드아웃을 시험할 수 없다. 그래서 `maxTierReached` 를 올린다.
  ///
  /// ⚠️ 이 값은 **난이도 이동(§2.4)과 서버 허용치**도 함께 연다 — 개발자
  /// 모드 전용인 이유다. 되돌리려면 세이브를 초기화해야 한다.
  Future<void> devOpenAllSkillSlots() async {
    final cfg = ref.read(gameDataProvider).value?.skillConfig;
    final s = state.requireValue;
    if (cfg == null) return;
    // 최대 칸이 열리는 난이도 = slotsByTier 의 마지막 칸.
    final want = cfg.maxSlots;
    var tier = s.topTier;
    while (tier < 10 && cfg.slotsFor(tier) < want) {
      tier++;
    }
    if (tier <= s.maxTierReached) return;
    await _commit(s.copyWith(maxTierReached: tier));
  }

  /// **개발자 모드 전용** — 스킬 조각을 등급별 만능 조각으로 채운다.
  Future<void> devAddGradeShards(int n) async {
    final s = state.requireValue;
    final m = Map<String, int>.from(s.skillGradeShards);
    for (final g in kSkillGrades.skip(1)) {
      m[g.key] = ((m[g.key] ?? 0) + n).clamp(0, 1 << 30);
    }
    await _commit(s.copyWith(skillGradeShards: m));
  }

  /// 교환소 — 젤리를 **지금 스테이지 기준 방치 산출**로 바꾼다.
  ///
  /// 지급량을 현재 스테이지에 비례시키는 이유: 정액이면 후반엔 껌값이라 아무도
  /// 안 쓴다. 정작 젤리가 남아도는 시점이 후반이다(영구 소비처를 다 산 뒤).
  ///
  /// ⚠️ **반대 방향(골드→젤리)은 만들지 않는다.** 골드는 방치로 무한히 벌리므로
  /// §2.6 의 "무한히 늘어나는 통로에 젤리를 붙이지 않는다"를 정면으로 위반한다.
  ///
  /// P2W 여부: 골드는 업그레이드로 가는데, 업그레이드는 **적응형 몬스터 체력의
  /// 기준 안**에 있다(§7). 즉 사서 올려도 몬스터가 같이 세져 콘텐츠가 뭉개지지
  /// 않는다 — 사는 것은 진행 속도(시간)이지 난이도 우회가 아니다.
  ///
  /// [trades] 회 교환. 성공하면 지급된 (gold, materials) 를 돌려준다.
  ({int gold, int materials})? exchangeJelly({
    required int trades,
    required bool wantGold,
  }) {
    if (trades <= 0) return null;
    final cfg = ref.read(gameDataProvider).requireValue.runConfig;
    if (cfg == null) return null;
    final s = state.requireValue;
    final cost = cfg.exchangeJellyPerTrade * trades;
    if (s.materialCount(MaterialKind.jelly) < cost) return null;

    // 교환 1회 = 이 유저가 지금 자리에서 **직접 사냥한** 1시간치(버프·접속 보너스 제외, exchangeOutput).
    // ⚠️ 회차·심연 층을 넘긴다 — 안 넘기면 어느 난이도에서나 쉬움 골드가 나왔다(2026-09-18).
    final data = ref.read(gameDataProvider).requireValue;
    final out = exchangeOutput(
      cfg,
      stats: huntStatsOf(
        s,
        data,
        ref.read(clockProvider).now().toUtc(),
        guildBonus: ref.read(guildBonusProvider),
      ),
      stage: s.stageNumber,
      trades: trades,
      tier: s.difficultyTier,
      abyssFloor: activeAbyssFloor(s),
    );
    return (
      gold: wantGold ? out.gold : 0,
      materials: wantGold ? 0 : out.materialsEach,
    );
  }

  /// 교환소 오늘 남은 가루(하루 상한이 없으면 null).
  int? exchangeDustLeftToday() {
    final fc = ref.read(gameDataProvider).requireValue.fairyConfig;
    if (fc == null || fc.exchangeDustDailyCap <= 0) return null;
    final f = state.requireValue.fairy;
    final today = dailyDateKey(ref.read(clockProvider).now());
    final used = f.exchangeDay == today ? f.exchangedDust : 0;
    return math.max(0, fc.exchangeDustDailyCap - used);
  }

  /// 교환소 젤리 → 요정 가루 미리보기(받을 가루). 못 바꾸면(젤리 부족·오늘 상한 초과) null.
  int? exchangeDust({required int trades}) {
    final data = ref.read(gameDataProvider).requireValue;
    final cfg = data.runConfig;
    final fc = data.fairyConfig;
    if (trades <= 0 || cfg == null || fc == null) return null;
    if (fc.exchangeDustPerJelly <= 0) return null;
    final cost = cfg.exchangeJellyPerTrade * trades;
    if (state.requireValue.materialCount(MaterialKind.jelly) < cost) {
      return null;
    }
    final dust = (cost * fc.exchangeDustPerJelly).floor();
    final left = exchangeDustLeftToday();
    if (left != null && dust > left) return null;
    return dust;
  }

  /// 교환소 젤리 → 요정 가루 실행.
  Future<bool> tradeJellyForDust({required int trades}) async {
    final dust = exchangeDust(trades: trades);
    if (dust == null) return false;
    final cfg = ref.read(gameDataProvider).requireValue.runConfig!;
    final s = state.requireValue;
    final cost = cfg.exchangeJellyPerTrade * trades;
    final mats = Map<MaterialKind, int>.from(s.materials)
      ..[MaterialKind.jelly] = s.materialCount(MaterialKind.jelly) - cost;
    final today = dailyDateKey(ref.read(clockProvider).now());
    final usedToday = s.fairy.exchangeDay == today ? s.fairy.exchangedDust : 0;
    await _commit(
      s.copyWith(
        materials: mats,
        fairy: s.fairy.copyWith(
          dust: s.fairy.dust + dust,
          exchangeDay: today,
          exchangedDust: usedToday + dust,
        ),
      ),
    );
    return true;
  }

  /// 교환 실행. 미리보기는 [exchangeJelly] 로 같은 값을 얻는다.
  Future<bool> tradeJelly({required int trades, required bool wantGold}) async {
    final out = exchangeJelly(trades: trades, wantGold: wantGold);
    if (out == null) return false;
    final cfg = ref.read(gameDataProvider).requireValue.runConfig!;
    final s = state.requireValue;
    final cost = cfg.exchangeJellyPerTrade * trades;
    final mats = Map<MaterialKind, int>.from(s.materials)
      ..[MaterialKind.jelly] = s.materialCount(MaterialKind.jelly) - cost;
    if (out.materials > 0) {
      for (final k in [
        MaterialKind.chitin,
        MaterialKind.mineral,
        MaterialKind.sap,
      ]) {
        mats[k] = (mats[k] ?? 0) + out.materials;
      }
    }
    await _commit(
      s.copyWith(gold: addCurrency(s.gold, out.gold), materials: mats),
    );
    return true;
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
  /// 수련(레벨업) — 길드전 5일차.
  Future<bool> trainBug(String bugId) async {
    final ok = await _trainBugImpl(bugId);
    if (ok) {
      GuildWarTally.add('bugLevel', ref.read(clockProvider).now().toUtc());
    }
    return ok;
  }

  Future<bool> _trainBugImpl(String bugId) async {
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
    // 스킨 계열 편의 보너스(§2.6 — 시간만, 전투 스탯 아님).
    final sec =
        data.iapConfig?.skinnedIncubateSeconds(
          cfg.incubateDuration(sp.grade),
          s.ownedSkins,
          bug.speciesId,
        ) ??
        cfg.incubateDuration(sp.grade);
    final endsAt = now.add(Duration(seconds: sec));
    final inc = Map<String, DateTime>.from(s.incubating)..[bugId] = endsAt;
    await _commit(s.copyWith(incubating: inc));
    return true;
  }

  /// 곤충 알 뽑기(가챠, §2.6 각주) — 젤리를 태워 알 하나를 뽑는다.
  ///
  /// - 고급 이상 보장(일반 없음) — 일반이 나오는 뽑기는 젤리 모욕이다.
  /// - 이색 확률 1/30(야생의 10배) — 뽑기의 값어치 축.
  /// - [PetConfig.gachaEpicPity] 회마다 영웅+ 천장(세이브 `gachaPity`).
  /// - 스탯 직접 판매가 아니다: 드롭이 주는 것과 같은 물건을 **더 빨리** 줄
  ///   뿐이고, PvP 는 서버 편성 검증·적응형 체력이 이미 완충한다.
  ///
  /// 실패 사유를 돌려준다 — "안 된다"만 뜨면 유저는 버그로 읽는다.
  Future<({IndividualBug? bug, String? error})> gachaDraw() async {
    final data = ref.read(gameDataProvider).requireValue;
    final cfg = data.petConfig;
    if (cfg == null || cfg.gachaJellyCost <= 0) {
      return (bug: null, error: 'off');
    }
    final s = state.requireValue;
    if (s.storageFull) return (bug: null, error: 'storage_full');
    if (s.materialCount(MaterialKind.jelly) < cfg.gachaJellyCost) {
      return (bug: null, error: 'no_jelly');
    }
    final now = ref.read(clockProvider).now().toUtc();
    final rng = math.Random();
    final pityDue =
        cfg.gachaEpicPity > 0 && s.gachaPity >= cfg.gachaEpicPity - 1;

    // 등급: 가중치 롤. 천장이면 보장 등급 미만을 잘라낸다.
    var weights = Map<Grade, double>.from(cfg.gachaWeights);
    weights.remove(Grade.common); // 어떤 설정이 와도 일반은 안 나온다
    if (pityDue) {
      weights = {
        for (final e in weights.entries)
          if (e.key.index >= cfg.gachaPityGrade.index) e.key: e.value,
      };
    }
    if (weights.isEmpty) return (bug: null, error: 'off');
    final total = weights.values.fold<double>(0, (a, b) => a + b);
    var pick = rng.nextDouble() * total;
    var grade = weights.keys.last;
    for (final e in weights.entries) {
      pick -= e.value;
      if (pick <= 0) {
        grade = e.key;
        break;
      }
    }
    // 그 등급의 종 중에서(한정 종은 기간 안에만).
    final pool = [
      for (final sp in data.allSpecies)
        if (sp.grade == grade && sp.availableAt(now)) sp,
    ];
    if (pool.isEmpty) return (bug: null, error: 'off');
    final sp = pool[rng.nextInt(pool.length)];
    final bug = IndividualBug.roll(
      id: const Uuid().v4(),
      species: sp,
      rng: rng,
      // ⚠️ **여기가 뽑기의 존재 이유다.** 야생 공식은 5성이 수학적으로
      // 불가능하고 4성도 3.4% 뿐이다(1 + floor(r*r*4) → 1~4). 곤충 자체는
      // 1분에 한 마리씩 나오므로 등급만 팔아서는 젤리 값이 안 나온다 —
      // 야생에 없는 것(5성)을 파는 게 유일하게 성립하는 축이다.
      // 표가 비어 있으면 야생 공식으로 떨어진다(구버전 데이터 호환).
      potential: () {
        final p = cfg.rollGachaPotential(rng.nextDouble());
        return p > 0
            ? p.clamp(1, 5)
            : (1 + (rng.nextDouble() * rng.nextDouble() * 4).floor()).clamp(
                1,
                5,
              );
      }(),
      variantChance: cfg.gachaVariantChance,
    ).copyWith(stage: LifeStage.egg, stageSince: now);

    final mats = Map<MaterialKind, int>.from(s.materials);
    mats[MaterialKind.jelly] =
        (mats[MaterialKind.jelly] ?? 0) - cfg.gachaJellyCost;
    await _commit(
      s.copyWith(
        materials: mats,
        bugs: [...s.bugs, bug],
        // ⚠️ **보장 등급이 나왔을 때만** 되감는다. 영웅에서 초기화하면
        // 전설을 노리는 유저의 카운터가 계속 리셋돼, "N회 안에 확정"이
        // 정작 목표에는 닿지 않는다.
        gachaPity: grade.index >= cfg.gachaPityGrade.index
            ? 0
            : s.gachaPity + 1,
      ),
    );
    return (bug: bug, error: null);
  }

  /// 부화 완료된 알을 수령 → 유충으로. 미완료/없음이면 false.
  /// 부화 수령 — 길드전 1일차.
  Future<bool> collectIncubated(String bugId) async {
    final ok = await _collectIncubatedImpl(bugId);
    final rushed = GuildWarTally.rushed.remove(bugId);
    if (ok && !rushed) {
      GuildWarTally.add('hatch', ref.read(clockProvider).now().toUtc());
    }
    return ok;
  }

  Future<bool> _collectIncubatedImpl(String bugId) async {
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
    // 젤리로 당긴 부화는 길드전 점수에 안 센다(수령 때 확인).
    GuildWarTally.rushed.add(bugId);
    return true;
  }

  /// 부화기 슬롯 확장(젤리). 최대치·젤리부족이면 false.
  Future<bool> expandIncubator() async {
    final cfg = ref.read(gameDataProvider).requireValue.petConfig;
    if (cfg == null) return false;
    final s = state.requireValue;
    if (s.incubatorCapacity >= cfg.incubatorSlotsMax) return false;
    final cost = cfg.incubatorExpandCost(s.incubatorCapacity);
    final have = s.materials[MaterialKind.jelly] ?? 0;
    if (have < cost) return false;
    final mats = Map<MaterialKind, int>.from(s.materials)
      ..[MaterialKind.jelly] = have - cost;
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
  /// 제련 한 번 — 길드전 2일차(결과 등급 단계만큼 지수 점수).
  Future<({EquipItem? item, bool kept})> forgeOnce() async {
    final r = await _forgeOnceImpl();
    final item = r.item;
    if (item != null) {
      GuildWarTally.add(
        'forge:${item.tier}',
        ref.read(clockProvider).now().toUtc(),
      );
    }
    return r;
  }

  Future<({EquipItem? item, bool kept})> _forgeOnceImpl() async {
    final r = await forgeMany(1);
    return (item: r.last, kept: r.kept > 0);
  }

  /// 망치질 **한 번**에 [times] 개를 뽑는다(§자동 제련 배수).
  ///
  /// 화석은 뽑은 만큼 든다 — 배수는 **시간을 줄여 줄 뿐 공짜가 아니다**.
  /// 필터에 걸려 버려진 것도 화석은 이미 탔다(그게 거르는 값이다).
  ///
  /// 모루가 차면 거기서 멈춘다. ⚠️ **화석은 그만큼만 태운다** — 남은 횟수를
  /// 마저 돌려 버리면 쌓이지도 않은 것에 재료를 쓴 셈이 된다.
  /// 제련 전용 난수 — **컨트롤러가 오래 들고 있는다**.
  ///
  /// 예전엔 뽑을 때마다 `Random()` 을 새로 만들었다. 새 인스턴스는 시각으로
  /// 씨앗을 잡는데, 망치질이 잇달으면 같은 씨앗이 잡혀 **같은 장비가 연달아
  /// 나왔다**(2026-09-07 제보). 하나를 계속 쓰면 수열이 이어져 그럴 일이 없다.
  final math.Random _forgeRng = math.Random();

  /// [hit] = 필터에 맞는 걸 뽑아서 **일부러 멈췄다**([SaveGame.autoForgeStopOnHit]).
  Future<
    ({
      EquipItem? last,
      int forged,
      int kept,
      bool full,
      bool dry,
      bool hit,

      /// 필터에 걸려 **판** 장비의 대금(재료 -> 수량). 화면이 모루 위에 띄운다.
      Map<MaterialKind, int> sold,
    })
  >
  forgeMany(int times) async {
    const nothing = (
      last: null,
      forged: 0,
      kept: 0,
      full: false,
      dry: false,
      hit: false,
      sold: <MaterialKind, int>{},
    );
    final data = ref.read(gameDataProvider).value;
    final items = data?.itemConfig;
    final forge = data?.forgeConfig;
    if (items == null || forge == null) return nothing;
    final s = state.requireValue;
    if (s.forgeStack.length >= _forgeCap(s, forge)) {
      return (
        last: null,
        forged: 0,
        kept: 0,
        full: true,
        dry: false,
        hit: false,
        sold: const <MaterialKind, int>{},
      );
    }
    var have = s.materialCount(MaterialKind.fossil);
    if (have < 1) {
      return (
        last: null,
        forged: 0,
        kept: 0,
        full: false,
        dry: true,
        hit: false,
        sold: const <MaterialKind, int>{},
      );
    }

    final want = s.autoForgeOptions;
    final minTier = s.autoForgeMinTier;
    final stack = [...s.forgeStack];
    // 멈출 기준이 있을 때만 멈춘다. 필터가 비어 있으면 **전부가 목표**라
    // 첫 개에서 멈춰 배수가 통째로 죽는다.
    final stopOnHit = s.autoForgeStopOnHit && (want.isNotEmpty || minTier > 0);
    EquipItem? last;
    var forged = 0, kept = 0;
    var full = false, dry = false, hit = false;
    // 필터에 걸려 버려진 장비의 판매 대금(재료 종류 -> 수량).
    // 한 번의 제련(배수 포함)에서는 **재료 한 종류**로 모은다 — 팔 때마다 종류를
    // 따로 뽑으면 모루 위에 "+1 +1 +1" 이 여러 개 떠서 같은 그림이 반복돼
    // 보였다(2026-09-22 사장님 지적). 종류별 기대값은 그대로다.
    final sold = <MaterialKind, int>{};
    MaterialKind? saleKind;

    for (var i = 0; i < times; i++) {
      if (have < 1) {
        dry = true;
        break;
      }
      if (stack.length >= _forgeCap(s, forge)) {
        full = true;
        break;
      }
      final item = forge_lib.forgeOnce(
        rng: _forgeRng,
        items: items,
        forge: forge,
        // 최대 레벨을 내렸을 때(20→16, 2026-09-15) 이미 넘은 계정도 최대로 본다.
        forgeLevel: math.min(s.forgeLevel, forge.maxLevel),
      );
      have--;
      forged++;
      last = item;
      // 두 축을 **모두** 넘어야 쌓인다. 등급이 먼저다 — 옵션이 맞아도 등급이
      // 낮으면 수치가 배율에 눌려 쓸모가 없다.
      final okTier = item.tier >= minTier;
      final okOption =
          want.isEmpty || item.options.any((o) => want.contains(o.kind));
      if (okTier && okOption) {
        stack.add(item);
        kept++;
        // 원하는 걸 찾았으면 남은 횟수를 안 돌린다 — 배수가 10이면 뽑고도
        // 화석 9개를 더 태우게 된다.
        if (stopOnHit) {
          hit = true;
          break;
        }
      } else {
        final kind = saleKind ??= sellMaterialFor(_forgeRng);
        sold[kind] = (sold[kind] ?? 0) + forge.sellMaterialCount(item.tier);
      }
    }

    final mats = Map<MaterialKind, int>.from(s.materials)
      ..[MaterialKind.fossil] = have;
    // 필터에 걸려 버려진 장비도 **판 것으로 본다**(사장님 지시 2026-09-18).
    // 예전엔 그냥 사라져서 화석만 태운 셈이었다. 창은 띄우지 않고 모루 위에
    // 아이콘만 잠깐 보여 준다(화면 쪽에서 처리).
    // ⚠️ 젤리·화석은 주지 않는다 — 자동 제련은 방치 중에도 도는 무한 통로다.
    for (final e in sold.entries) {
      mats[e.key] = (mats[e.key] ?? 0) + e.value;
    }
    await _commit(
      s.copyWith(
        materials: mats,
        forgeStack: stack,
        // 제련 미션(2026-09-15). 필터에 걸려 버려진 것도 화석은 탔으므로 센다.
        missionProgress: forged <= 0
            ? null
            : _bumpMissions(s.missionProgress, MissionType.forgeItems, forged),
      ),
    );
    return (
      last: last,
      forged: forged,
      kept: kept,
      full: full,
      dry: dry,
      hit: hit,
      sold: sold,
    );
  }

  /// 모루 맨 위 장비를 **판다** — 일반 재료로 바꾼다(사장님 지시 2026-09-18).
  ///
  /// 예전에는 "버리기"라 아무것도 주지 않았다. 판 재료는 자동 제련에서 필터에
  /// 걸린 것과 **같은 규칙**이다(`sellMaterialFor` · `sellMaterialCount`).
  /// 판 결과(재료 -> 수량)를 돌려주므로 화면이 얼마 받았는지 보여 줄 수 있다.
  Future<Map<MaterialKind, int>> sellTopItem() async {
    final forge = ref.read(gameDataProvider).value?.forgeConfig;
    final s = state.requireValue;
    if (forge == null || s.forgeStack.isEmpty) return const {};
    final item = s.forgeStack.last;
    final kind = sellMaterialFor(_forgeRng);
    final n = forge.sellMaterialCount(item.tier);
    final mats = Map<MaterialKind, int>.from(s.materials)
      ..[kind] = (s.materials[kind] ?? 0) + n;
    await _commit(
      s.copyWith(materials: mats, forgeStack: [...s.forgeStack]..removeLast()),
    );
    return {kind: n};
  }

  /// 지금 모루 칸 수 = 기본 + 젤리로 넓힌 만큼(상한은 설정이 정한다).
  int _forgeCap(SaveGame s, ForgeConfig forge) {
    final cap = kMaxForgeStack + s.forgeStackBought * forge.stackExpandStep;
    return cap > forge.stackExpandMax ? forge.stackExpandMax : cap;
  }

  /// 모루 맨 위 장비의 **옵션만** 다시 굴린다(젤리). 등급·부위는 그대로.
  ///
  /// 등급을 바꾸면 물건을 파는 것이라 §2.6 을 넘는다 — 옵션은 제련을 계속
  /// 돌리면 언젠가 나오는 조합이라 파는 것이 시간 절약이다.
  Future<bool> rerollForgeTop() async {
    final data = ref.read(gameDataProvider).value;
    final items = data?.itemConfig;
    final forge = data?.forgeConfig;
    if (items == null || forge == null) return false;
    final s = state.requireValue;
    if (s.forgeStack.isEmpty) return false;
    final cost = forge.rerollJelly;
    final have = s.materialCount(MaterialKind.jelly);
    if (have < cost) return false;
    final stack = [...s.forgeStack];
    stack[stack.length - 1] = rerollOptions(
      rng: _forgeRng,
      items: items,
      item: stack.last,
    );
    final mats = Map<MaterialKind, int>.from(s.materials)
      ..[MaterialKind.jelly] = have - cost;
    await _commit(s.copyWith(forgeStack: stack, materials: mats));
    return true;
  }

  /// 옵션 **한 칸만** 다시 굴린다 — 모루 맨 위(`equipped: false`) 또는
  /// 이미 낀 장비(`equipped: true`, 부위를 [slot] 으로 지정).
  ///
  /// 사장님 확정(2026-09-09): 두 옵션을 각각 바꿀 수 있어야 하고, **이미 낀
  /// 장비도** 바꿀 수 있어야 한다. 낀 것을 못 바꾸면 좋은 등급을 뽑고도
  /// 옵션이 나쁘면 버려야 해서, 등급을 모으는 의미가 줄어든다.
  Future<bool> rerollOption({
    required int index,
    bool equipped = false,
    EquipSlot? slot,
  }) async {
    final data = ref.read(gameDataProvider).value;
    final items = data?.itemConfig;
    final forge = data?.forgeConfig;
    if (items == null || forge == null) return false;
    final s = state.requireValue;

    final target = equipped
        ? (slot == null ? null : s.equippedItems[slot])
        : (s.forgeStack.isEmpty ? null : s.forgeStack.last);
    if (target == null || index >= target.options.length) return false;

    final cost = forge.rerollJelly;
    final have = s.materialCount(MaterialKind.jelly);
    if (have < cost) return false;

    final next = rerollOptionAt(
      rng: _forgeRng,
      items: items,
      item: target,
      index: index,
    );
    final mats = Map<MaterialKind, int>.from(s.materials)
      ..[MaterialKind.jelly] = have - cost;

    if (equipped) {
      final eq = Map<EquipSlot, EquipItem>.from(s.equippedItems)
        ..[slot!] = next;
      await _commit(s.copyWith(equippedItems: eq, materials: mats));
    } else {
      final stack = [...s.forgeStack];
      stack[stack.length - 1] = next;
      await _commit(s.copyWith(forgeStack: stack, materials: mats));
    }
    return true;
  }

  /// 망치질 가속(젤리) — 이미 켜져 있으면 남은 시간에 **이어 붙인다**.
  ///
  /// 덮어쓰면 남은 시간을 산 사람이 손해를 본다.
  Future<bool> rushForgeHammer() async {
    final forge = ref.read(gameDataProvider).value?.forgeConfig;
    if (forge == null) return false;
    final s = state.requireValue;
    final cost = forge.rushJelly;
    final have = s.materialCount(MaterialKind.jelly);
    if (have < cost) return false;
    final now = ref.read(clockProvider).now().toUtc();
    final base = (s.forgeRushUntil?.isAfter(now) ?? false)
        ? s.forgeRushUntil!
        : now;
    final mats = Map<MaterialKind, int>.from(s.materials)
      ..[MaterialKind.jelly] = have - cost;
    await _commit(
      s.copyWith(
        materials: mats,
        forgeRushUntil: base.add(Duration(seconds: forge.rushSeconds)),
      ),
    );
    return true;
  }

  /// 모루 칸 확장(젤리). 비용은 살수록 오른다.
  Future<bool> expandForgeStack() async {
    final forge = ref.read(gameDataProvider).value?.forgeConfig;
    if (forge == null) return false;
    final s = state.requireValue;
    if (_forgeCap(s, forge) >= forge.stackExpandMax) return false;
    final cost = forge.stackExpandCost(s.forgeStackBought);
    final have = s.materialCount(MaterialKind.jelly);
    if (have < cost) return false;
    final mats = Map<MaterialKind, int>.from(s.materials)
      ..[MaterialKind.jelly] = have - cost;
    await _commit(
      s.copyWith(materials: mats, forgeStackBought: s.forgeStackBought + 1),
    );
    return true;
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
    int? minTier,
    int? strikes,
    bool? stopOnHit,
  }) async {
    final s = state.requireValue;
    await _commit(
      s.copyWith(
        autoForgeOptions: options,
        autoForgeMinTier: minTier,
        autoForgeStrikes: strikes,
        autoForgeStopOnHit: stopOnHit,
      ),
    );
  }

  /// 스킬 장착/해제. 실패면 사유 키(`slots_full`·`not_owned`)를 돌려준다 —
  /// 눌렀는데 아무 일도 없으면 고장으로 읽힌다.
  Future<String?> toggleSkill(String id) =>
      _skillOp((s, cfg) => toggleSkillEquip(s, cfg, id));

  /// 스킬 수련 시작(조각 + 부족분 만능 조각, 타이머). 규칙은 `core_save` 한 곳.
  Future<String?> startSkillTraining(String id) => _skillOp(
    (s, cfg) => core_skill.startSkillTraining(
      s,
      cfg,
      id,
      ref.read(clockProvider).now().toUtc(),
    ),
  );

  /// 스킬 수련 완료. [viaJelly] = 남은 시간만큼 젤리로 즉시.
  /// 스킬 수련 완료 — 젤리로 당기지 않은 것만 길드전 5일차.
  Future<String?> completeSkillTraining({bool viaJelly = false}) async {
    final err = await _completeSkillTrainingImpl(viaJelly: viaJelly);
    if (err == null && !viaJelly) {
      GuildWarTally.add('skillTrain', ref.read(clockProvider).now().toUtc());
    }
    return err;
  }

  Future<String?> _completeSkillTrainingImpl({bool viaJelly = false}) =>
      _skillOp(
        (s, cfg) => core_skill.completeSkillTraining(
          s,
          cfg,
          ref.read(clockProvider).now().toUtc(),
          viaJelly: viaJelly,
        ),
      );

  /// 등급 승급 — [from] 등급 조각을 [sources] 순서대로 `비율 × times` 개 태워
  /// 한 단계 위 등급 만능 조각 [times] 개를 만든다.
  Future<String?> gradeUpSkillShards({
    required Grade from,
    required List<String> sources,
    required int times,
  }) => _skillOp(
    (s, cfg) =>
        gradeUpShards(s, cfg, from: from, sources: sources, times: times),
  );

  /// 홈 스킬 바 자동발동 켜기/끄기(§2.8).
  Future<void> setSkillAutoCast(bool on) async {
    final s = state.requireValue;
    if (s.skillAutoCast == on) return;
    await _commit(s.copyWith(skillAutoCast: on));
  }

  // ── 요정(docs/design_fairy.md) ────────────────────────────────
  // 규칙은 전부 core_save `fairy_progress.dart`(서버 업로드 검사와 같은 함수).
  // 여기는 젤리 차감·시각·난수·저장만 한다. 기기 권위(알 뽑기·스킬 뽑기와 같다).

  /// 요정 액션 공용 — 실패면 상태를 바꾸지 않고 사유 키가 담긴 결과를 그대로 준다.
  Future<FairyOp> _fairyOp(
    FairyOp Function(FairyState f, FairyConfig cfg, int jelly) op,
  ) async {
    final cfg = ref.read(gameDataProvider).value?.fairyConfig;
    if (cfg == null) return const FairyOp.fail('off');
    final s = state.requireValue;
    final have = s.materialCount(MaterialKind.jelly);
    final r = op(s.fairy, cfg, have);
    if (!r.isOk) return r;
    var next = s.copyWith(fairy: r.state);
    if (r.jelly > 0) {
      next = next.copyWith(
        materials: Map<MaterialKind, int>.from(s.materials)
          ..[MaterialKind.jelly] = have - r.jelly,
      );
    }
    await _commit(next);
    return r;
  }

  DateTime get _fairyNow => ref.read(clockProvider).now().toUtc();

  /// 둥지에 알을 넣는다([stoneSub] = 속성석 부가 키).
  Future<FairyOp> fairyPlaceEgg(
    String eggId, {
    String? stoneSub,
    math.Random? rng,
  }) => _fairyOp(
    (f, cfg, _) => placeFairyEgg(
      f,
      cfg,
      rng ?? math.Random(),
      eggId: eggId,
      now: _fairyNow,
      stoneSub: stoneSub,
    ),
  );

  /// 다 깬 알을 꺼낸다. 결과 `extra['fairy']`.
  Future<FairyOp> fairyCollectNest() =>
      _fairyOp((f, _, _) => collectFairyNest(f, now: _fairyNow));

  Future<FairyOp> fairyUseAccelerator(String accelId) => _fairyOp(
    (f, cfg, _) =>
        useFairyAccelerator(f, cfg, accelId: accelId, now: _fairyNow),
  );

  Future<FairyOp> fairyBuyAccelerator(String accelId, {int count = 1}) =>
      _fairyOp(
        (f, cfg, jelly) => buyFairyAccelerator(
          f,
          cfg,
          accelId: accelId,
          count: count,
          jellyHave: jelly,
        ),
      );

  Future<FairyOp> fairyBuyStone(String sub, {int count = 1}) => _fairyOp(
    (f, cfg, jelly) =>
        buyFairyStone(f, cfg, sub: sub, count: count, jellyHave: jelly),
  );

  /// 합성 — 결과(부가·개체값)는 새로 굴린다(design_fairy.md §1.6).
  Future<FairyOp> fairyMerge(List<String> ids, {math.Random? rng}) =>
      _fairyOp((f, cfg, _) => mergeFairies(f, cfg, ids, rng ?? math.Random()));

  /// 자동 합성 — [dryRun] 이면 저장하지 않고 예상만(실행 전 확인, §2.7).
  /// 결과를 새로 굴리므로 예상은 **수(몇 마리를 써서 몇 마리)** 만 믿을 수 있다.
  Future<FairyOp> fairyAutoMerge({bool dryRun = false}) async {
    if (dryRun) {
      final cfg = ref.read(gameDataProvider).value?.fairyConfig;
      if (cfg == null) return const FairyOp.fail('off');
      return autoMergeFairies(
        state.requireValue.fairy,
        cfg,
        math.Random(0),
        dryRun: true,
      );
    }
    return _fairyOp((f, cfg, _) => autoMergeFairies(f, cfg, math.Random()));
  }

  /// 요정 재굴림(2026-10-04, 조정안 C) — **서버가 굴린다**(기기에서 굴리면 서버의 정체 고정이 되돌린다).
  /// 직전에 세이브를 올리고(안 그러면 최근 진행이 서버 저장본으로 덮인다) 응답 세이브를 채택한다.
  /// 결과는 대기로 적힌다 — [fairyRerollChoose] 로 고른다. 오류 키는 서버 것 그대로(`reroll_cap` 등).
  Future<FairyOp> fairyReroll(String id) =>
      _fairyServerOp((server) => server.fairyReroll(id));

  /// 재굴림 결과 고르기 — [accept] 면 새 값, 아니면 원래 값을 지킨다.
  Future<FairyOp> fairyRerollChoose({required bool accept}) =>
      _fairyServerOp((server) => server.fairyRerollChoose(accept: accept));

  Future<FairyOp> _fairyServerOp(
    Future<ServerResult> Function(GameServer server) call,
  ) async {
    final server = ref.read(gameServerProvider);
    if (!server.available) return const FairyOp.fail('network');
    // 올리기 → 서버 행동 → 채택을 한 줄로(다른 서버 세이브 흐름과 엇갈리지 않게).
    return withServerSaveLock(() async {
      if (!await flushSaveBeforeServerAction(server, () => latestSave)) {
        return const FairyOp.fail('network');
      }
      final r = await call(server);
      // 서버엔 고를 결과가 없다 — 고르기 응답이 유실됐거나 업로드가 정리했다. 기기만 대기 중이라 믿고 있으면
      // 재굴림이 영영 막히므로 서버 세이브를 받아 맞춘다(2026-10-04 출시 전 리뷰).
      if (r.error == 'no_reroll') {
        final st = await server.fetchState();
        final fresh = st.save;
        if (st.isOk && fresh != null) await adoptServerSave(fresh);
        return FairyOp.ok(state.requireValue.fairy);
      }
      final json = r.save;
      if (!r.isOk || json == null) return FairyOp.fail(r.error ?? 'network');
      await adoptServerSave(json);
      return FairyOp.ok(state.requireValue.fairy);
    });
  }

  Future<FairyOp> fairyLevelUp(String id) =>
      _fairyOp((f, cfg, _) => levelUpFairy(f, cfg, id));

  Future<FairyOp> fairySetCompanion(String? id) =>
      _fairyOp((f, _, _) => setFairyCompanion(f, id));

  /// 요정 도감 마일스톤 하나 받기(요정 가루·가속기·화석 — 젤리 없음). 못 받으면 false.
  Future<bool> fairyClaimDex() async {
    final cfg = ref.read(gameDataProvider).value?.fairyConfig;
    if (cfg == null) return false;
    final next = claimFairyDexMilestone(state.requireValue, cfg);
    if (next == null) return false;
    await _commit(next);
    return true;
  }

  Future<FairyOp> fairyRelease(String id) =>
      _fairyOp((f, cfg, _) => releaseFairy(f, cfg, id));

  /// 분해 창 — 요정·알 여러 개를 한 번에 가루로(2026-10-06). 결과 `extra['dust']`.
  Future<FairyOp> fairyReleaseBulk({
    List<String> fairyIds = const [],
    List<String> eggIds = const [],
  }) => _fairyOp(
    (f, cfg, _) =>
        releaseFairiesBulk(f, cfg, fairyIds: fairyIds, eggIds: eggIds),
  );

  /// 알 자동 분해 등급(null = 끔).
  Future<FairyOp> fairySetAutoRelease(FairyGrade? upTo) =>
      _fairyOp((f, _, _) => setFairyAutoRelease(f, upTo));

  /// 요정함 확장(젤리, 2026-10-08) — 10칸씩 최대 60칸. 최대·젤리 부족이면 실패.
  Future<FairyOp> fairyExpandBox() =>
      _fairyOp((f, cfg, jelly) => expandFairyBox(f, cfg, jellyHave: jelly));

  /// 요정 알 뽑기(젤리). 결과 `extra['grades']`.
  Future<FairyOp> fairyDraw(int times, {math.Random? rng}) => _fairyOp(
    (f, cfg, jelly) => drawFairyEggs(
      f,
      cfg,
      rng ?? math.Random(),
      times: times,
      jellyHave: jelly,
    ),
  );

  /// 스킬 뽑기(§2.8) — [free] 면 하루 무료 1회, 아니면 젤리로 [times] 회.
  /// 기기 권위라 시드는 기기가 정한다(알 뽑기와 같다). 실패하면 사유 키.
  Future<({List<SkillDraw> draws, String? error})> drawSkills({
    required int times,
    bool free = false,
    math.Random? rng,
  }) async {
    final cfg = ref.read(gameDataProvider).value?.skillConfig;
    if (cfg == null) return (draws: const <SkillDraw>[], error: 'off');
    final op = core_skill.drawSkills(
      state.requireValue,
      cfg,
      rng ?? math.Random(),
      dayKey: dailyDateKey(ref.read(clockProvider).now()),
      times: times,
      free: free,
    );
    if (!op.isOk) return (draws: const <SkillDraw>[], error: op.error);
    await _commit(op.save!);
    return (draws: op.extra['draws'] as List<SkillDraw>, error: null);
  }

  /// 보스 소탕(§2.8) — 잡아 본 가장 높은 난이도 기준 확정 조각.
  Future<({Map<String, int> shards, String? error})> sweepSkillBoss({
    math.Random? rng,
  }) async {
    final data = ref.read(gameDataProvider).value;
    final cfg = data?.skillConfig;
    final run = data?.runConfig;
    if (cfg == null || run == null) {
      return (shards: const <String, int>{}, error: 'off');
    }
    final op = core_skill.sweepBoss(
      state.requireValue,
      cfg,
      run,
      rng ?? math.Random(),
      dayKey: dailyDateKey(ref.read(clockProvider).now()),
    );
    if (!op.isOk) return (shards: const <String, int>{}, error: op.error);
    await _commit(op.save!);
    return (shards: op.extra['shards'] as Map<String, int>, error: null);
  }

  /// 오늘 쓴 무료 뽑기·소탕 횟수.
  ({int freeDraws, int sweeps}) get skillDailyUsedToday => skillDailyUsed(
    state.requireValue,
    dailyDateKey(ref.read(clockProvider).now()),
  );

  /// 정예 처치 조각(확률, §2.8). 나오면 받은 조각(스킬 id → 개수), 아니면 빈 맵.
  /// 안 나왔으면 커밋하지 않는다 — 정예마다 세이브를 쓰면 저장이 잦아진다.
  Future<Map<String, int>> grantEliteShards({math.Random? rng}) async {
    final cfg = ref.read(gameDataProvider).value?.skillConfig;
    final s = state.requireValue;
    final r = rng ?? math.Random();
    var next = s;
    var shards = const <String, int>{};
    if (cfg != null) {
      final got = core_skill.grantEliteShards(
        next,
        cfg,
        r,
        tier: s.difficultyTier,
      );
      next = got.save;
      shards = got.shards;
    }
    // 결투석(오행석 0.2%, design_training_v2.md §3) — 스킬 조각 **뒤에** 굴린다(같은 seed 의 조각이 안 바뀌게).
    final st = rollDuelStones(next, _stoneCfg, r, DuelStoneSource.elite);
    lastDuelStones = st.got;
    if (shards.isEmpty && st.got.isEmpty) return const {};
    await _commit(st.save);
    return shards;
  }

  /// 정예 처치 요정 드롭(확률 — 알·속성석·가속기, §2.8 무료 경로). 아무것도 안 나오면 저장하지 않는다.
  /// 정예 처치(요정 드롭 판정과 같은 자리) — 길드전 3일차.
  Future<FairyOp> grantEliteFairy({math.Random? rng}) async {
    GuildWarTally.add('elite', ref.read(clockProvider).now().toUtc());
    return _grantEliteFairyImpl(rng: rng);
  }

  Future<FairyOp> _grantEliteFairyImpl({math.Random? rng}) async {
    final cfg = ref.read(gameDataProvider).value?.fairyConfig;
    if (cfg == null) return const FairyOp.fail('off');
    final s = state.requireValue;
    final r = fairyEliteDrop(s.fairy, cfg, rng ?? math.Random());
    if (identical(r.state, s.fairy)) return r;
    await _commit(s.copyWith(fairy: r.state));
    return r;
  }

  Future<String?> _skillOp(SkillOp Function(SaveGame, SkillConfig) op) async {
    final cfg = ref.read(gameDataProvider).value?.skillConfig;
    if (cfg == null) return 'off';
    final r = op(state.requireValue, cfg);
    if (!r.isOk) return r.error;
    await _commit(r.save!);
    return null;
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
      // 스킨 계열 편의 보너스(산란 시간 −N%, 2026-10-08). 서버와 같은 함수.
      endsAt: now.add(
        Duration(
          seconds:
              ref
                  .read(gameDataProvider)
                  .value
                  ?.iapConfig
                  ?.skinnedBreedSeconds(
                    cfg.breedingDuration(sp.grade),
                    s.ownedSkins,
                    sp.id,
                  ) ??
              cfg.breedingDuration(sp.grade),
        ),
      ),
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
  /// 짝짓기 수령. 젤리로 당기지 않은 수령만 길드전 점수(1일차)에 센다.
  Future<bool> collectBreeding(String slotId, {bool viaJelly = false}) async {
    final ok = await _collectBreedingImpl(slotId, viaJelly: viaJelly);
    if (ok && !viaJelly) {
      GuildWarTally.add('breedDone', ref.read(clockProvider).now().toUtc());
    }
    return ok;
  }

  Future<bool> _collectBreedingImpl(
    String slotId, {
    bool viaJelly = false,
  }) async {
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
    final cost = cfg.breedingExpandCost(s.breedingCapacity);
    final have = s.materials[MaterialKind.jelly] ?? 0;
    if (have < cost) return false;
    final mats = Map<MaterialKind, int>.from(s.materials)
      ..[MaterialKind.jelly] = have - cost;
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
      s.dexConqueredWith(cfg.conquerLevel),
      s.claimedDex,
      bosses: collectedBossCount,
    );
    if (claimable.isEmpty) return const [];

    var gold = s.gold;
    final mats = Map<MaterialKind, int>.from(s.materials);
    for (final m in claimable) {
      gold += m.gold;
      if (m.jelly > 0) {
        mats[MaterialKind.jelly] = (mats[MaterialKind.jelly] ?? 0) + m.jelly;
      }
      if (m.fossil > 0) {
        mats[MaterialKind.fossil] = (mats[MaterialKind.fossil] ?? 0) + m.fossil;
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
    final cost = cfg.storageExpandCost(s.storageCapacity);
    final have = s.materials[MaterialKind.jelly] ?? 0;
    if (have < cost) return false;
    final next = (s.storageCapacity + cfg.storageExpandAmount).clamp(
      0,
      cfg.storageSlotsMax,
    );
    final mats = Map<MaterialKind, int>.from(s.materials)
      ..[MaterialKind.jelly] = have - cost;
    await _commit(s.copyWith(storageCapacity: next, materials: mats));
    return true;
  }

  /// 분해: 미장착 곤충 [bugId] 를 없애고 젤리로 환원. 장착/없음이면 false.
  /// 분해 결과 — **무엇이 얼마나 들어왔는지**를 돌려준다.
  ///
  /// 예전엔 bool 이라 화면이 "분해 완료"만 띄웠다. 재료가 2~32 개라 큰 수
  /// 사이에 묻혀 **아무것도 안 들어온 것처럼 보였고**, 실패했을 때도 같은
  /// 침묵이라 "전설 알이 분해가 안 된다"를 구분할 수 없었다(2026-09-01 지적).
  Future<({bool ok, String? error, int jelly, MaterialKind? kind, int amount})>
  disassembleBug(String bugId) async {
    const fail = (ok: false, error: 'unknown', jelly: 0, kind: null, amount: 0);
    final s = state.requireValue;
    // 실패 사유를 갈라 준다 — 같은 침묵이면 유저는 버그로 읽는다.
    if (s.isEquipped(bugId)) {
      return (ok: false, error: 'equipped', jelly: 0, kind: null, amount: 0);
    }
    if (s.incubating.containsKey(bugId)) {
      return (ok: false, error: 'incubating', jelly: 0, kind: null, amount: 0);
    }
    if (s.lockedBugIds.contains(bugId)) {
      return (ok: false, error: 'locked', jelly: 0, kind: null, amount: 0);
    }
    final idx = s.bugs.indexWhere((b) => b.id == bugId);
    if (idx < 0) return fail;
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
    // 젤리는 **획득 시점 포텐셜**로 — 합성으로 올린 5성을 분해하면 젤리가 무한히 나왔다(2026-09-30).
    final reward = cfg?.disassembleJelly(bug.bornPotential) ?? 0;
    final grade = data.speciesById[bug.speciesId]?.grade;
    final matGain = (cfg == null || grade == null)
        ? 0
        : data.iapConfig?.skinnedReleaseMaterial(
                cfg.releaseMaterial(grade),
                s.ownedSkins,
                bug.speciesId,
              ) ??
              cfg.releaseMaterial(grade);
    final mats = Map<MaterialKind, int>.from(s.materials);
    if (reward > 0) {
      mats[MaterialKind.jelly] = (mats[MaterialKind.jelly] ?? 0) + reward;
    }
    MaterialKind? gainedKind;
    if (matGain > 0) {
      // 자동 방생과 **같은 재료표**를 쓴다 — 분해와 방생의 가치가 갈리면
      // "필터에 걸리게 두는 게 이득"처럼 이상한 최적 전략이 생긴다.
      gainedKind =
          kRegularMaterials[math.Random().nextInt(kRegularMaterials.length)];
      mats[gainedKind] = (mats[gainedKind] ?? 0) + matGain;
    }
    final bugs = List<IndividualBug>.from(s.bugs)..removeAt(idx);
    await _commit(s.copyWith(bugs: bugs, materials: mats));
    return (
      ok: true,
      error: null,
      jelly: reward > 0 ? reward : 0,
      kind: matGain > 0 ? gainedKind : null,
      amount: matGain,
    );
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
  /// 이 개체를 합성할 때 **재료로 쓸 곤충**(모자라면 빈 목록).
  ///
  /// 화면이 실행 전에 "무엇이 사라지는지" 보여주려고 따로 뽑는다 —
  /// 예전엔 저장 순서대로 앞 3마리를 그냥 지워서, 이색·수련한 개체가
  /// 경고 없이 사라졌다(2026-09-25 제보).
  List<IndividualBug> synthFodderFor(String targetId) {
    final cfg = ref.read(gameDataProvider).value?.petConfig;
    final s = state.value;
    if (cfg == null || s == null || cfg.synthFodder <= 0) return const [];
    IndividualBug? target;
    for (final b in s.bugs) {
      if (b.id == targetId) {
        target = b;
        break;
      }
    }
    if (target == null || target.potential >= cfg.synthMaxPotential) {
      return const [];
    }
    // 보호: 장착 중 · 부화 중 · 훈련 · **잠금**(pinnedBugIds) · 이색 · 투자한 개체(isPreciousBug).
    final pool =
        s.bugs
            .where(
              (b) =>
                  b.id != targetId &&
                  b.speciesId == target!.speciesId &&
                  _isSynthFodder(s, b, target.potential),
            )
            .toList()
          // 덜 아까운 것부터 — 자동 합성·상한 정리와 같은 축이다.
          ..sort((a, b) => bugFodderRank(a).compareTo(bugFodderRank(b)));
    if (pool.length < cfg.synthFodder) return const [];
    return pool.take(cfg.synthFodder).toList();
  }

  /// 합성 — 길드전 1일차.
  Future<bool> synthesize(String targetId) async {
    final ok = await _synthesizeImpl(targetId);
    if (ok) GuildWarTally.add('synth', ref.read(clockProvider).now().toUtc());
    return ok;
  }

  Future<bool> _synthesizeImpl(String targetId) async {
    final cfg = ref.read(gameDataProvider).requireValue.petConfig;
    if (cfg == null) return false;
    final s = state.requireValue;
    final fodder = synthFodderFor(targetId);
    if (fodder.length < cfg.synthFodder) return false;
    final fodderIds = fodder.map((b) => b.id).toSet();
    final bugs = <IndividualBug>[];
    for (final b in s.bugs) {
      if (b.id == targetId) {
        bugs.add(
          b.copyWith(potential: b.potential + 1, synthUps: b.synthUps + 1),
        );
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
      // 장착·부화·훈련·잠금·이색·투자 개체는 재료로 쓰지 않는다(수동 합성과 같은 보호).
      if (s.pinnedBugIds.contains(b.id) || isPreciousBug(b)) {
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
        // 다음 후보로 넘어가며 재료를 처음부터 다시 훑으므로, 이미 재료로 쓰인 개체가 대상 자리에 올 수 있다.
        if (consumed.contains(target.id)) {
          targetIdx++;
          continue;
        }
        var pot = upgraded[target.id] ?? target.potential;
        if (pot >= cfg.synthMaxPotential) {
          targetIdx++; // 이미 만렙이면 다음 후보를 올린다
          continue;
        }
        // 뒤에서부터 재료를 모은다(타깃 자신은 제외).
        final picked = <String>[];
        while (picked.length < cfg.synthFodder && tail > targetIdx) {
          final b = alive[tail--];
          // 대상보다 포텐셜이 높은 곤충은 태우지 않는다(수동 합성과 같은 규칙).
          if (consumed.contains(b.id) || !isFodder(b) || b.potential > pot) {
            continue;
          }
          picked.add(b.id);
        }
        if (picked.length < cfg.synthFodder) {
          // 이 대상에 맞는 재료가 모자란다 — **다음 후보로** 넘어간다(2026-10-04 문의).
          // 끊으면 수련한 ★2 성충이 대상일 때 ★4 알(대상보다 높아 재료 불가)끼리도 못 합쳐
          // "알이 많은데 합성할 게 없다"가 됐다. 재료는 처음부터 다시 훑는다(쓴 건 consumed 가 거른다).
          targetIdx++;
          tail = alive.length - 1;
          continue;
        }
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
      bugs.add(
        pot == null
            ? b
            : b.copyWith(
                potential: pot,
                synthUps: b.synthUps + (pot - b.potential),
              ),
      );
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
      // 이색·투자 개체는 건드리지 않는다 — 자동 합성·상한 정리와 같은 규칙.
      // 장착·부화·훈련·잠금(pinnedBugIds)은 건드리지 않는다.
      if (s.pinnedBugIds.contains(b.id)) continue;
      if (isPreciousBug(b)) continue;
      final grade = data.speciesById[b.speciesId]?.grade;
      if (grade == null) continue; // 종을 모르면 건드리지 않는다
      if (filter != null && !filter.accepts(grade, b.potential)) continue;
      targets.add(b);
      gain +=
          data.iapConfig?.skinnedReleaseMaterial(
            cfg.releaseMaterial(grade),
            s.ownedSkins,
            b.speciesId,
          ) ??
          cfg.releaseMaterial(grade);
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
      final amount =
          data.iapConfig?.skinnedReleaseMaterial(
            cfg.releaseMaterial(grade),
            s.ownedSkins,
            b.speciesId,
          ) ??
          cfg.releaseMaterial(grade);
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

  /// [target] 종으로 **실제로 재료가 되는** 같은 종 개체 수.
  ///
  /// 보호(장착·부화 중·이색·투자)를 그대로 반영한다 — 화면의 "3/3" 과 실제 소비가
  /// 갈리면 버튼이 켜졌는데 아무 일도 안 일어난다(예전엔 실제로 그랬다).
  int synthFodderCount(SaveGame s, String targetId, String speciesId) {
    final target = s.bugs.where((b) => b.id == targetId).firstOrNull;
    if (target == null) return 0;
    return s.bugs
        .where(
          (b) =>
              b.id != targetId &&
              b.speciesId == speciesId &&
              _isSynthFodder(s, b, target.potential),
        )
        .length;
  }

  /// 합성 재료가 될 수 있나(수동·자동·개수 공용).
  ///
  /// - 장착·부화·훈련·**잠금**(`pinnedBugIds`) · 이색·투자한 개체(`isPreciousBug`)는 안 된다.
  ///   ⚠️ `pinnedBugIds`(훈련·잠금 포함)는 만들어만 두고 합성에서 쓰지 않고 있었다(2026-10-02 발견).
  /// - **대상보다 포텐셜이 높은 곤충은 안 된다**(2026-10-02 문의: 3포텐셜 알을 강화했더니 장착 안 한
  ///   4·5포텐셜 성충이 재료로 사라졌다). 낮은 걸 올리려고 높은 걸 태우는 경우는 없다.
  bool _isSynthFodder(SaveGame s, IndividualBug b, int targetPotential) =>
      !s.pinnedBugIds.contains(b.id) &&
      !isPreciousBug(b) &&
      b.potential <= targetPotential;

  /// 곤충 잠금 켜기/끄기 — 잠근 곤충은 합성·분해 재료에서 빠진다.
  Future<bool> toggleBugLock(String bugId) async {
    final s = state.requireValue;
    if (!s.bugs.any((b) => b.id == bugId)) return false;
    final locked = s.lockedBugIds.contains(bugId);
    await _commit(
      s.copyWith(
        lockedBugIds: locked
            ? ({...s.lockedBugIds}..remove(bugId))
            : {...s.lockedBugIds, bugId},
      ),
    );
    return !locked;
  }

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
      final c = petContribution(
        petStatOf(
          b,
          sp,
          cfg,
          now,
          trainMult: trainPetMult(s, b.id, _battleCfg.training),
        ),
        cfg,
      );
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
    if (trimmed == s.nickname && s.nicknameSet) {
      // ⚠️ 운영자가 변경을 요구한 상태에서 **같은 이름**을 낸 경우를 따로 돌려준다.
      //
      // 예전엔 둘 다 noChange 였고 화면은 "쓸 수 없는 문자"를 띄웠다. 이름에는
      // 아무 문제가 없으니 유저는 바꿨다고 생각하는데, 서버는 새 이름이 올라와야
      // 플래그를 내리므로(`mergeSave`) **안내가 영원히 다시 뜬다**
      // (2026-09-17 문의: "바꿔도 계속 글이 떠요").
      return s.renameRequired ? RenameResult.sameName : RenameResult.noChange;
    }
    // 운영자가 변경을 요구한 경우엔 **무료**다 — 부적절한 이름을 고치라면서
    // 돈을 받으면 그건 벌금이지 조치가 아니다. 플래그는 여기서 내리지만
    // 서버가 새 이름을 보고 다시 내린다(서버 소유라 앱이 못 내린다).
    if (s.renameRequired) {
      await _commit(
        s.copyWith(nickname: trimmed, nicknameSet: true, renameRequired: false),
      );
      return RenameResult.ok;
    }
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
enum RenameResult { ok, notEnoughJelly, noChange, sameName }

final saveControllerProvider = AsyncNotifierProvider<SaveController, SaveGame>(
  SaveController.new,
);
