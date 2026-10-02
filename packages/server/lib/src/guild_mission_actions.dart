import 'dart:math' as math;

import 'package:core_run/core_run.dart';

import 'guild_actions.dart' show GuildResult;
import 'guild_mission_store.dart';
import 'guild_store.dart';

/// 수령 결과 — 라우트가 서버 세이브에 넣는다(재료·화석·요정 알). 코인은 여기서 서버 테이블에 넣는다.
class GuildMissionClaim {
  const GuildMissionClaim({
    this.reward = const GuildMissionReward(),
    this.eggs = 0,
    this.missions = 0,
  });
  final GuildMissionReward reward;

  /// 요정 알 수([GuildMissionConfig.eggGrade] 등급).
  final int eggs;
  final int missions;
}

/// 길드 미션(docs/design_guild.md §2) — 게시판·출발·도와주기·판정·보상 받기.
///
/// 판정은 **끝난 뒤 첫 조회 때**(cron 없음 — 대회·시즌과 같은 구조). 누가 조회하든 한 번만 판정되게
/// DB 가 `settled=false` 조건으로 막는다.
class GuildMissionActions {
  GuildMissionActions({
    required this.guilds,
    required this.store,
    required this.config,
    required this.run,
    required this.now,
    required this.addExp,
  });

  final GuildStore guilds;
  final GuildMissionStore store;
  final GuildConfig config;
  final RunConfig run;
  final DateTime Function() now;

  /// 길드 경험치 더하기 + 레벨·인원 맞추기([GuildActions.addExp]).
  final Future<void> Function(String guildId, int exp) addExp;

  GuildMissionConfig get c => config.mission;

  static GuildResult _err(
    String code, [
    int status = 409,
    Map<String, dynamic> extra = const {},
  ]) => (status, {'error': code, ...extra});

  String _day(DateTime t) => guildDayKey(t, anchorHour: c.dayAnchorHourKst);
  DateTime _keepSince(DateTime t) =>
      t.subtract(Duration(days: c.rewardKeepDays));

  // ── 조회 ──

  /// 미션 탭 — 게시판 · 오늘 남은 출발 · 도움 목록 · 받을 보상.
  Future<GuildResult> view(String userId) async {
    final t = now().toUtc();
    final mine = await guilds.membershipOf(userId);
    final day = _day(t);
    var my = await _settleDue(
      await store.userMissions(userId, _keepSince(t)),
      t,
    );
    var inGuild = mine == null
        ? <GuildMissionRow>[]
        : await _settleDue(
            await store.guildMissions(
              mine.guildId,
              t.subtract(const Duration(days: 1)),
            ),
            t,
          );
    // 방금 판정한 것이 양쪽 목록에 다 있을 수 있다 — 판정 결과를 서로 맞춘다.
    final settled = {
      for (final m in [...my, ...inGuild])
        if (m.settled) m.id: m,
    };
    my = [for (final m in my) settled[m.id] ?? m];
    inGuild = [for (final m in inGuild) settled[m.id] ?? m];

    final claimed = await store.claimedIds(userId, _keepSince(t));
    final pending = _claimable(userId, my, claimed);
    final sum = pending.fold(
      const GuildMissionReward(),
      (a, m) => a + _rewardOf(userId, m),
    );
    return (
      200,
      {
        'dayKey': day,
        'nextDayAt': guildNextDayAt(
          t,
          anchorHour: c.dayAnchorHourKst,
        ).toIso8601String(),
        'now': t.toIso8601String(),
        'inGuild': mine != null,
        'board': mine == null
            ? const []
            : [for (final s in guildMissionBoard(c, userId, day)) s.toJson()],
        'startsLeft': math.max(0, c.dailyStarts - _startsOn(userId, my, day)),
        'helpRewardsLeft': math.max(
          0,
          c.helpRewardsPerDay - _helpRewardsOn(userId, my, day),
        ),
        'active': [
          for (final m in inGuild)
            if (!m.settled) _toApi(m, userId),
        ],
        'recent': [
          for (final m in inGuild)
            if (m.settled && m.dayKey == day) _toApi(m, userId),
        ],
        'claimable': {'missions': pending.length, ...sum.toJson()},
      },
    );
  }

  // ── 출발 · 도와주기 ──

  /// 출발 — [power] 는 앱이 보낸 내 전투력(홈 상단 값), [stage]·[nickname] 은 서버 세이브.
  Future<GuildResult> start(
    String userId, {
    required int slot,
    required int waitSec,
    required double power,
    required int stage,
    required String nickname,
  }) async {
    final mine = await guilds.membershipOf(userId);
    if (mine == null) return _err('not_in_guild');
    final t = now().toUtc();
    final day = _day(t);
    final board = guildMissionBoard(c, userId, day);
    if (slot < 0 || slot >= board.length) return _err('bad_request', 400);
    if (!c.waitSeconds.contains(waitSec)) return _err('bad_request', 400);
    final my = await _settleDue(
      await store.userMissions(userId, _keepSince(t)),
      t,
    );
    if (_startsOn(userId, my, day) >= c.dailyStarts) {
      return _err('no_starts_left');
    }
    if (my.any((m) => m.owner == userId && !m.settled)) {
      return _err('mission_running');
    }
    final pw = power.isFinite && power >= 1 ? power : 1.0;
    final s = board[slot];
    final need = pw * s.mult;
    final solo = pw >= need; // 혼자로 이미 충분 = 바로 성공
    var m = await store.insertMission(
      GuildMissionRow(
        guildId: mine.guildId,
        owner: userId,
        ownerNick: nickname,
        dayKey: day,
        slot: slot,
        kind: s.kind,
        mult: s.mult,
        waitSec: waitSec,
        needPower: need,
        ownerPower: pw,
        ownerStage: stage < 1 ? 1 : stage,
        startedAt: t,
        endsAt: solo ? t : t.add(Duration(seconds: waitSec)),
        solo: solo,
        helperMax: c.helperMax,
      ),
    );
    if (solo) {
      await _settleOne(m, t);
    } else {
      await store.postHelpChat(
        guildId: mine.guildId,
        userId: userId,
        nickname: nickname,
        missionId: m.id,
      );
    }
    await store.deleteOwnedBefore(userId, _keepSince(t));
    return view(userId);
  }

  Future<GuildResult> help(
    String userId,
    String missionId, {
    required double power,
    required int stage,
    required String nickname,
  }) async {
    final mine = await guilds.membershipOf(userId);
    if (mine == null) return _err('not_in_guild');
    final m = await store.mission(missionId);
    final t = now().toUtc();
    if (m == null || m.guildId != mine.guildId) {
      return _err('mission_not_found', 404);
    }
    if (m.owner == userId) return _err('own_mission');
    if (m.settled || !t.isBefore(m.endsAt)) return _err('mission_closed');
    if (m.helpers.any((h) => h.userId == userId)) {
      return _err('already_helped');
    }
    if (m.helpers.length >= c.helperMax) return _err('helpers_full');
    final day = _day(t);
    final my = await store.userMissions(userId, _keepSince(t));
    final rewarded = _helpRewardsOn(userId, my, day) < c.helpRewardsPerDay;
    final h = GuildHelperRow(
      missionId: m.id,
      userId: userId,
      nickname: nickname,
      // 한 사람 몫에 상한이 없다(2026-10-01 사장님 확정 — 센 길드원 한 명이 깨 줄 수 있다).
      power: power.isFinite && power > 0 ? power : 0,
      stage: stage < 1 ? 1 : stage,
      dayKey: day,
      rewarded: rewarded,
      createdAt: t,
    );
    if (!await store.insertHelper(h)) return _err('helpers_full');
    final after = m.copyWith(helpers: [...m.helpers, h]);
    // 전투력이 요구를 넘어도 시간은 계속 흐른다(끝나면 합산으로 판정).
    // **도움이 다 차면 그 자리에서 성공**(2026-10-01 사장님 확정).
    if (after.helpers.length >= after.helperMax) {
      await _settleOne(after, t, full: true);
    }
    final (st, body) = await view(userId);
    return (st, {...body, 'helpRewarded': rewarded});
  }

  // ── 보상 받기 ──

  /// 받을 수 있는 보상을 **모두** 받는다. 코인은 여기서 길드 테이블에 넣고, 재료·화석·알은
  /// 돌려주어 라우트가 서버 세이브에 넣는다. 수령 기록을 **먼저** 남기고 지급한다(우편과 같은 순서).
  Future<GuildMissionClaim> claimAll(String userId) async {
    final t = now().toUtc();
    final my = await _settleDue(
      await store.userMissions(userId, _keepSince(t)),
      t,
    );
    final claimed = await store.claimedIds(userId, _keepSince(t));
    var sum = const GuildMissionReward();
    var eggs = 0;
    var n = 0;
    // 길드 버프 "미션 보상" — **지금 속한 길드** 기준(나가면 사라진다, §5).
    final bonus = await _missionBonus(userId);
    for (final m in _claimable(userId, my, claimed)) {
      if (!await store.insertClaim(m.id, userId)) continue;
      sum = sum + _boost(_rewardOf(userId, m), bonus);
      n++;
      if (m.owner == userId && m.success && _eggRoll(m)) eggs++;
    }
    if (sum.coins > 0) await guilds.addCoins(userId, sum.coins);
    return GuildMissionClaim(reward: sum, eggs: eggs, missions: n);
  }

  // ── 내부 ──

  Future<double> _missionBonus(String userId) async {
    final mine = await guilds.membershipOf(userId);
    if (mine == null) return 0;
    final g = await guilds.guild(mine.guildId);
    if (g == null) return 0;
    return guildBonus(config.skills, g.skills)['missionReward'] ?? 0;
  }

  /// 재료·화석만 늘린다(코인은 그대로 — 코인 상점 가격이 흔들리지 않게).
  static GuildMissionReward _boost(GuildMissionReward r, double b) => b <= 0
      ? r
      : GuildMissionReward(
          chitin: (r.chitin * (1 + b)).round(),
          mineral: (r.mineral * (1 + b)).round(),
          sap: (r.sap * (1 + b)).round(),
          fossil: (r.fossil * (1 + b)).round(),
          coins: r.coins,
        );

  /// 요정 알 — 미션 id 로 seed 를 고정한다(다시 받기로 다시 굴릴 수 없다).
  bool _eggRoll(GuildMissionRow m) =>
      c.eggChance > 0 &&
      math.Random(fnv1a32('egg|${m.id}')).nextDouble() < c.eggChance;

  List<GuildMissionRow> _claimable(
    String userId,
    List<GuildMissionRow> my,
    Set<String> claimed,
  ) => [
    for (final m in my)
      if (m.settled &&
          !claimed.contains(m.id) &&
          (m.owner == userId ||
              m.helpers.any((h) => h.userId == userId && h.rewarded)))
        m,
  ];

  GuildMissionReward _rewardOf(String userId, GuildMissionRow m) {
    final o = guildMissionOutcome(c, total: m.total, need: m.needPower);
    final factor = m.settled
        ? (m.success ? 1.0 : m.ratio * c.partialRewardMult)
        : o.factor;
    if (m.owner == userId) {
      return guildMissionReward(
        c,
        run,
        stage: m.ownerStage,
        mult: m.mult,
        factor: factor,
        waitMult: m.solo ? 1.0 : c.waitMultOf(m.waitSec),
      );
    }
    final h = m.helpers.where((h) => h.userId == userId).firstOrNull;
    if (h == null || !h.rewarded) return const GuildMissionReward();
    return guildMissionReward(
      c,
      run,
      stage: h.stage,
      mult: m.mult,
      factor: factor,
      waitMult: c.waitMultOf(m.waitSec),
      helper: true,
    );
  }

  int _startsOn(String userId, List<GuildMissionRow> my, String day) =>
      my.where((m) => m.owner == userId && m.dayKey == day).length;

  int _helpRewardsOn(String userId, List<GuildMissionRow> my, String day) => my
      .where(
        (m) => m.helpers.any(
          (h) => h.userId == userId && h.dayKey == day && h.rewarded,
        ),
      )
      .length;

  Future<List<GuildMissionRow>> _settleDue(
    List<GuildMissionRow> ms,
    DateTime t,
  ) async => [
    for (final m in ms)
      (!m.settled && !t.isBefore(m.endsAt)) ? await _settleOne(m, t) : m,
  ];

  /// [full] = 도움이 다 모임 → 전투력과 무관하게 성공.
  Future<GuildMissionRow> _settleOne(
    GuildMissionRow m,
    DateTime t, {
    bool full = false,
  }) async {
    final o = full
        ? (ratio: 1.0, success: true, factor: 1.0)
        : guildMissionOutcome(c, total: m.total, need: m.needPower);
    final early = t.isBefore(m.endsAt);
    final mine = await store.settle(
      m.id,
      ratio: o.ratio,
      success: o.success,
      endsAt: early ? t : null,
    );
    final gid = m.guildId;
    if (mine && gid != null) {
      await addExp(gid, o.success ? c.expSuccess : c.expPartial);
    }
    return m.copyWith(
      settled: true,
      ratio: o.ratio,
      success: o.success,
      endsAt: early ? t : null,
    );
  }

  Map<String, dynamic> _toApi(GuildMissionRow m, String me) => {
    'id': m.id,
    'owner': m.owner,
    'ownerNick': m.ownerNick,
    'mine': m.owner == me,
    'kind': m.kind,
    'mult': m.mult,
    'waitSec': m.waitSec,
    'need': m.needPower,
    'total': m.total,
    'endsAt': m.endsAt.toIso8601String(),
    'settled': m.settled,
    'success': m.success,
    'ratio': m.ratio,
    'helpers': [
      for (final h in m.helpers) {'userId': h.userId, 'nickname': h.nickname},
    ],
    'helped': m.helpers.any((h) => h.userId == me),
    'helperMax': c.helperMax,
  };
}
