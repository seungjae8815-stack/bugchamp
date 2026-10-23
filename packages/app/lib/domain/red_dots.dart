import 'dart:math' as math;

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/game_data.dart';
import '../features/character/skill_panel.dart' show skillIdleGradeUps;
import 'guild_service.dart' show guildBonusProvider;
import 'providers.dart';
import 'research_view.dart';
import 'save_controller.dart';

/// 빨간 점 — **놓치면 손해인 것**만(2026-10-19 사장님 확정: 공략집 · 하루 무료 · 빈 부화기·짝짓기 칸 ·
/// 끝난 타이머 · 받을 보상). 늘 켜져 있을 수 있는 것(등급 올리기 가능 등)은 넣지 않는다 — 점이 늘 떠 있으면
/// 아무 점도 안 보게 된다.
///
/// 판정은 여기 한 곳. 화면은 이 값을 읽어 버튼·하단 탭에 점을 단다(탭 점 = 그 탭 안 점의 합).
/// 홈 화면 안의 점(우편·공지·미션·버프)은 홈이 매 프레임 다시 그리며 스스로 판정한다.
class RedDots {
  const RedDots({
    this.guide = false,
    this.skillDraw = false,
    this.skillSweep = false,
    this.skillTraining = false,
    this.skillGradeUp = false,
    this.forge = false,
    this.starUp = false,
    this.incubator = false,
    this.breeding = false,
    this.dex = false,
    this.breakthroughBugs = const {},
    this.ticketFree = false,
    this.ticketFull = false,
    this.league = false,
    this.training = false,
    this.researchIdle = false,
    this.researchDone = false,
  });

  /// 이번 공략집을 아직 안 열어 봄(기기 플래그 — [guideSeenProvider]).
  final bool guide;

  /// 오늘 무료 스킬 뽑기 · 무료 보스 소탕이 남음.
  final bool skillDraw;
  final bool skillSweep;

  /// 스킬 수련이 끝나 받을 수 있음.
  final bool skillTraining;

  /// 놀고 있는 조각으로 스킬 승급 가능(2026-10-08 — 원래 있던 점).
  final bool skillGradeUp;

  /// 공방 등급업·초월이 끝나 받을 수 있음.
  final bool forge;

  /// 낀 장비 별 강화가 끝나 받을 수 있음.
  final bool starUp;

  /// 부화기: 부화가 끝났거나, 칸이 비었고 넣을 알이 있음.
  final bool incubator;

  /// 짝짓기: 산란이 끝났거나, 칸이 비었고 짝지을 수 있는 암수가 있음.
  final bool breeding;

  /// 도감·보스 수집 마일스톤을 받을 수 있음.
  final bool dex;

  /// 돌파가 끝나 받을 수 있는 곤충(칸에 점).
  final Set<String> breakthroughBugs;

  /// 결투 티켓: 오늘 무료 충전이 남았고 가득이 아님(충전 버튼) · 가득 차 자연 충전이 멈춤(전투 시작 버튼).
  final bool ticketFree;
  final bool ticketFull;

  /// 받지 않은 리그 승급 보상.
  final bool league;

  /// 훈련 칸이 비었고 출정(방어) 곤충에게 찍을 포인트가 남음.
  final bool training;

  /// 연구 칸이 비었고 지금 시작할 수 있는 연구가 있음(재화·선행 충족).
  final bool researchIdle;

  /// 끝난 연구가 칸에 남아 있음(자동 수령이 돌기 전 잠깐).
  final bool researchDone;

  bool get skills => skillDraw || skillSweep || skillTraining || skillGradeUp;
  bool get stats => forge || starUp;
  /// 하단 탭 점(2026-10-22 — 옛 캐릭터 탭이 장비·스킬·요정 탭으로 나뉘었다).
  bool get equipTab => stats;
  bool get skillsTab => skills;
  bool get storageTab =>
      incubator || breeding || dex || breakthroughBugs.isNotEmpty;
  bool get battleTab => ticketFree || ticketFull || league || training;

  /// 연구소 탭(연구 완료·칸 놀고 있음).
  bool get researchTab => researchIdle || researchDone;

  /// 빨간 점을 달 하단 탭 번호(길드 가입 신청은 길드 서비스가 따로 더한다).
  Set<int> get tabDots => {
    if (guide) 0,
    if (storageTab) kStorageTabIndex,
    if (battleTab) kBattleTabIndex,
    if (equipTab) kEquipTabIndex,
    if (skillsTab) kSkillTabIndex,
    if (researchTab) kResearchTabIndex,
  };
}

/// 지금 보이지 않는 쪽의 탭에 점이 있나 — ⇄ 전환 버튼의 점. 홈은 양쪽에 있어 세지 않는다.
bool otherNavPageHasDot(int page, Set<int> dots) {
  final other = kNavPages[1 - page];
  return dots.any((i) => i != 0 && other.contains(i));
}

/// 시간이 지나 바뀌는 점(타이머 끝·날짜 바뀜)을 홈 밖에서도 띄우려는 30초 박자.
/// 세이브가 바뀔 때도 다시 계산되지만, 사냥이 멈추면 커밋도 멈춘다.
final redDotTickProvider = StreamProvider<int>(
  (ref) => Stream<int>.periodic(const Duration(seconds: 30), (i) => i),
);

/// 공략집을 이번 판까지 열어 봤나. 공략집 내용을 크게 바꾸면 [kGuideRevision] 을 올린다 — 기기마다 점이 다시 뜬다.
const kGuideRevision = '2026-10-19';
const _kGuideSeenKey = 'guide.seen';

class GuideSeenNotifier extends Notifier<bool> {
  @override
  bool build() {
    // 읽기 전엔 "봤음"으로 둔다 — 켜자마자 점이 번쩍였다 사라지지 않게.
    SharedPreferences.getInstance()
        .then((p) {
          final seen = p.getString(_kGuideSeenKey) == kGuideRevision;
          if (!seen) state = false;
        })
        .catchError((_) {});
    return true;
  }

  void markSeen() {
    state = true;
    SharedPreferences.getInstance()
        .then((p) => p.setString(_kGuideSeenKey, kGuideRevision))
        .catchError((_) => false);
  }
}

final guideSeenProvider = NotifierProvider<GuideSeenNotifier, bool>(
  GuideSeenNotifier.new,
);

final redDotsProvider = Provider<RedDots>((ref) {
  ref.watch(redDotTickProvider);
  final guide = !ref.watch(guideSeenProvider);
  final save = ref.watch(saveControllerProvider).value;
  final data = ref.watch(gameDataProvider).value;
  if (save == null || data == null) return RedDots(guide: guide);
  final clock = ref.read(clockProvider);
  return computeRedDots(
    save: save,
    data: data,
    nowUtc: clock.now().toUtc(),
    localNow: clock.now(),
    guide: guide,
    guildBonus: ref.watch(guildBonusProvider),
  );
});

/// [redDotsProvider] 의 계산 — 세이브·데이터·시각만 받는 순수 함수(테스트용).
RedDots computeRedDots({
  required SaveGame save,
  required GameData data,
  required DateTime nowUtc,
  required DateTime localNow,
  bool guide = false,
  Map<String, double> guildBonus = const {},
}) {
  final now = nowUtc;
  bool due(DateTime? t) => t != null && !now.isBefore(t);

  // ── 캐릭터: 스킬 · 공방 · 장비 ──
  final skill = data.skillConfig;
  final run = data.runConfig;
  var skillDraw = false, skillSweep = false, skillGradeUp = false;
  if (skill != null) {
    final used = skillDailyUsed(save, dailyDateKey(localNow));
    skillDraw = used.freeDraws < skill.gachaFreePerDay;
    skillSweep =
        run != null &&
        used.sweeps < skill.sweepFreePerDay &&
        bestSweepTier(save, run) >= 0;
    skillGradeUp = skillIdleGradeUps(skill, save).isNotEmpty;
  }
  final skillTraining = due(save.skillTrainingEndsAt);
  final forge = due(save.forgeUpAt) || due(save.forgeTranscendAt);
  final starUp = save.equippedItems.values.any((e) => due(e.starUntil));

  // ── 채집함: 부화기 · 짝짓기 · 도감 · 돌파 ──
  final pet = data.petConfig;
  LifeStage stageOf(IndividualBug b) =>
      pet == null ? b.stage : effectiveStage(b.stage, b.stageSince, now, pet);
  final incubDone = save.incubating.values.any(due);
  final waitingEgg =
      save.incubating.length < save.incubatorCapacity &&
      save.bugs.any(
        (b) =>
            !save.incubating.containsKey(b.id) && stageOf(b) == LifeStage.egg,
      );
  final breedDone = save.breeding.any((b) => due(b.endsAt));
  var breedIdle = false;
  // 채집함이 가득이면 산란한 알을 받을 수 없다 — 빈 칸을 재촉하지 않는다.
  if (save.breeding.length < save.breedingCapacity && !save.storageFull) {
    final females = <String>{};
    final males = <String>{};
    for (final b in save.bugs) {
      if (stageOf(b) != LifeStage.adult || save.breedOnCooldown(b.id, now)) {
        continue;
      }
      (b.sex == Sex.female ? females : males).add(b.speciesId);
    }
    breedIdle = females.any(males.contains);
  }
  final dexCfg = data.dexConfig;
  var dex = false;
  if (dexCfg != null) {
    final bosses = run == null
        ? 0
        : collectedBosses(save, run, data.roadmapConfig).length;
    dex = dexCfg
        .claimable(
          save.dexDiscovered,
          save.dexConqueredWith(dexCfg.conquerLevel),
          save.claimedDex,
          bosses: bosses,
        )
        .isNotEmpty;
  }
  final breakthroughBugs = {
    for (final b in save.bugs)
      if (due(b.breakthroughEndsAt)) b.id,
  };

  // ── 결투: 티켓 · 리그 · 훈련소 ──
  final battle = data.battleConfig ?? const BattleConfig();
  var ticketFree = false, ticketFull = false;
  if (!seasonClosed(now, battle)) {
    final t = regenTickets(
      tickets: save.pvpTickets,
      at: save.ticketsAt,
      now: now,
      cfg: battle,
    ).tickets;
    final freeLeft =
        save.adUseCount(kAdFeaturePvpTicket, dailyDateKey(now)) <
        battle.ticketAdDailyLimit;
    ticketFull = t >= battle.ticketMax;
    ticketFree = !ticketFull && freeLeft;
  }
  final league = battle
      .claimableUpTo(pvpLeagueOf(save, battle), save.claimedLeagues)
      .isNotEmpty;
  var training = false;
  if (save.trainPointJob == null) {
    final cfg = battle.training;
    for (final id in save.pvpDefenseIds) {
      final b = save.bugs.where((x) => x.id == id).firstOrNull;
      final sp = b == null ? null : data.speciesById[b.speciesId];
      if (b == null || sp == null || stageOf(b) != LifeStage.adult) continue;
      final rec = bugTrainOf(save, b, sp, cfg, enhance: data.enhanceConfig);
      final budget = trainBudgetOf(
        save,
        b,
        sp,
        cfg,
        enhance: data.enhanceConfig,
      );
      if (math.max(0, budget - rec.allocated) > 0) {
        training = true;
        break;
      }
    }
  }

  // ── 연구소: 빈 칸 + 시작 가능 · 끝난 연구 ──
  final researchDone = save.researchSlots.any((r) => due(r.endsAt));
  final researchIdle = anyResearchStartable(
    save,
    data,
    now,
    guildBonus: guildBonus,
  );

  return RedDots(
    guide: guide,
    skillDraw: skillDraw,
    skillSweep: skillSweep,
    skillTraining: skillTraining,
    skillGradeUp: skillGradeUp,
    forge: forge,
    starUp: starUp,
    incubator: incubDone || waitingEgg,
    breeding: breedDone || breedIdle,
    dex: dex,
    breakthroughBugs: breakthroughBugs,
    ticketFree: ticketFree,
    ticketFull: ticketFull,
    league: league,
    training: training,
    researchIdle: researchIdle,
    researchDone: researchDone,
  );
}
