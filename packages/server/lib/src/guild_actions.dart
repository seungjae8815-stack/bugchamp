import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';

import 'guild_store.dart';

/// (HTTP 상태, 응답 본문).
typedef GuildResult = (int, Map<String, dynamic>);

/// 길드 1단계 — 만들기·가입(공개/승인제)·탈퇴·추방·직책·소개(docs/design_guild.md §1).
///
/// 길드 상태는 **서버 테이블이 소유**한다(세이브에 없다). 권한·규칙은 여기서 보고,
/// 동시에 들어오는 요청의 최종 판정(이름 유일 · 한 사람 한 길드 · 인원 상한)은 DB 제약이 한다.
/// 로직이 커서 [GameActions] 와 파일을 나눴다.
class GuildActions {
  GuildActions({
    required this.store,
    required this.config,
    required this.rules,
    required this.now,
  });

  final GuildStore store;
  final GuildConfig config;
  final ChatRules rules;
  final DateTime Function() now;

  /// 마지막 접속을 이 간격보다 자주 쓰지 않는다(화면을 열 때마다 쓰기 방지).
  static const _touchEvery = Duration(minutes: 10);

  static GuildResult _ok(Map<String, dynamic> body) => (200, body);
  static GuildResult _err(
    String code, [
    int status = 409,
    Map<String, dynamic> extra = const {},
  ]) => (status, {'error': code, ...extra});

  // ── 조회 ──

  /// 내 길드 — 없으면 재가입 제한·넣어 둔 신청을 돌려준다.
  /// 앱은 시작할 때와 길드 화면을 열 때 부른다 → 여기서 마지막 접속을 적고,
  /// 길드장이 오래 비었으면 자동 위임한다(cron 없이 — 대회·시즌과 같은 구조).
  Future<GuildResult> me(String userId) async {
    final t = now().toUtc();
    final mine = await store.membershipOf(userId);
    if (mine == null) {
      final until = await _cooldownUntil(userId, t);
      return _ok({
        'guild': null,
        'cooldownUntil': ?until?.toIso8601String(),
        'requested': await store.requestedGuildsOf(userId),
      });
    }
    if (t.difference(mine.lastSeen) >= _touchEvery) {
      await store.touch(userId, t);
    }
    final g = await store.guild(mine.guildId);
    if (g == null) {
      // 길드 행이 사라진 멤버 행(있을 수 없지만) — 정리하고 길드 없음으로.
      await store.deleteMember(userId);
      return _ok({'guild': null, 'requested': const <String>[]});
    }
    var members = await store.members(g.id);
    if (await _delegateIfLeaderAway(g, members, t)) {
      members = await store.members(g.id);
    }
    final me = members.firstWhere(
      (m) => m.userId == userId,
      orElse: () => mine,
    );
    final synced = await _syncLevel(g);
    final lv = config.level.levelOf(synced.exp);
    final used = guildPointsUsed(config.skills, synced.skills);
    final day = guildDayKey(t, anchorHour: config.mission.dayAnchorHourKst);
    final periods = _periods(t);
    final bought = await store.boughtCounts(userId, periods);
    return _ok({
      'guild': {
        ...synced.toApi(),
        'exp': lv.into,
        'expNeed': lv.need,
        'skills': synced.skills,
        'pointsLeft': config.level.points(lv.level) - used,
      },
      'myCoins': mine.coins,
      'donatedToday': mine.donateDay == day,
      'shop': [
        for (final it in config.shop)
          {...it.toJson(), 'bought': bought[it.id] ?? 0},
      ],
      'myRole': me.role.key,
      'members': [for (final m in _sorted(members)) m.toApi()],
      if (me.role.canManage)
        'requests': [for (final r in await store.requestsOf(g.id)) r.toApi()],
    });
  }

  /// 추천·검색 목록.
  Future<GuildResult> list(
    String userId, {
    String lang = 'ko',
    String query = '',
  }) async {
    final q = query.trim();
    final rows = await store.listGuilds(
      userId: userId,
      lang: lang,
      query: q.length > config.nameMaxLength
          ? q.substring(0, config.nameMaxLength)
          : q,
      limit: config.listLimit,
    );
    return _ok({
      'guilds': [for (final g in rows) g.toApi()],
      'requested': await store.requestedGuildsOf(userId),
    });
  }

  // ── 만들기 · 가입 · 탈퇴 ──

  /// 개설 — [jelly] 는 서버 세이브의 젤리 잔액. 여기서는 **확인만** 하고, 차감은 성공한 뒤
  /// 라우트가 한다(이름 중복 등으로 실패하면 젤리를 쓰지 않는다).
  Future<GuildResult> create(
    String userId, {
    required int jelly,
    required String name,
    String lang = 'ko',
    String joinMode = 'open',
  }) async {
    if (jelly < config.createJellyCost) {
      return _err('insufficient_jelly', 409, {'cost': config.createJellyCost});
    }
    final clean = normalizeName(name);
    if (!nameOk(clean)) return _err('name_invalid', 400);
    if (await store.membershipOf(userId) != null) {
      return _err('already_in_guild');
    }
    final t = now().toUtc();
    final until = await _cooldownUntil(userId, t);
    if (until != null) {
      return _err('cooldown', 409, {'until': until.toIso8601String()});
    }
    final g = await store.insertGuild(
      name: clean,
      lang: _lang(lang),
      leader: userId,
      maxMembers: config.maxMembers,
      joinMode: GuildJoinMode.fromKey(joinMode),
    );
    if (g == null) return _err('name_taken');
    final r = await store.insertMember(g.id, userId, GuildRole.leader);
    if (r != GuildInsertResult.ok) {
      // 동시에 다른 길드에 들어갔다 — 방금 만든 빈 길드를 치운다.
      await store.deleteGuild(g.id);
      return _err('already_in_guild');
    }
    await store.deleteRequestsOf(userId);
    return me(userId);
  }

  /// 가입 — 공개 길드는 바로, 승인제는 신청만 넣는다.
  Future<GuildResult> join(String userId, String guildId) async {
    if (await store.membershipOf(userId) != null) {
      return _err('already_in_guild');
    }
    final t = now().toUtc();
    final until = await _cooldownUntil(userId, t);
    if (until != null) {
      return _err('cooldown', 409, {'until': until.toIso8601String()});
    }
    final g = await store.guild(guildId);
    if (g == null) return _err('guild_not_found', 404);
    if (g.full) return _err('guild_full');

    if (g.joinMode == GuildJoinMode.approval) {
      final mine = await store.requestedGuildsOf(userId);
      if (mine.contains(guildId)) return _ok({'requested': true});
      if (mine.length >= config.maxPendingRequests) {
        return _err('too_many_requests', 409, {
          'max': config.maxPendingRequests,
        });
      }
      if ((await store.requestsOf(guildId)).length >= config.requestLimit) {
        return _err('requests_full');
      }
      await store.insertRequest(guildId, userId);
      return _ok({'requested': true});
    }

    final r = await store.insertMember(guildId, userId, GuildRole.member);
    switch (r) {
      case GuildInsertResult.alreadyInGuild:
        return _err('already_in_guild');
      case GuildInsertResult.full:
        return _err('guild_full');
      case GuildInsertResult.ok:
        await store.deleteRequestsOf(userId);
        return me(userId);
    }
  }

  Future<GuildResult> cancelRequest(String userId, String guildId) async {
    await store.deleteRequest(guildId, userId);
    return _ok({'requested': await store.requestedGuildsOf(userId)});
  }

  /// 탈퇴 — 길드장이면 다음 사람에게 넘기고, 마지막 한 명이면 길드를 없앤다.
  /// 스스로 나가면 [GuildConfig.rejoinCooldownHours] 동안 다른 길드에 못 들어간다.
  Future<GuildResult> leave(String userId) async {
    final mine = await store.membershipOf(userId);
    if (mine == null) return _err('not_in_guild');
    final t = now().toUtc();
    final members = await store.members(mine.guildId);
    final others = [
      for (final m in members)
        if (m.userId != userId) m,
    ];
    if (others.isEmpty) {
      await store.deleteGuild(mine.guildId);
    } else {
      if (mine.role == GuildRole.leader) {
        final next = _successor(others, t)!;
        await _makeLeader(mine.guildId, next.userId, previous: null);
      }
      await store.deleteMember(userId);
    }
    await store.setLeftAt(userId, t);
    return _ok({
      'guild': null,
      'cooldownUntil': t
          .add(Duration(hours: config.rejoinCooldownHours))
          .toIso8601String(),
      'requested': const <String>[],
    });
  }

  // ── 관리(길드장·부길드장) ──

  /// 추방 — 길드장은 부길드장·멤버를, 부길드장은 멤버만. 추방당한 쪽은 재가입 제한이 없다
  /// (스스로 나간 게 아니다).
  Future<GuildResult> kick(String actorId, String targetId) async {
    if (actorId == targetId) return _err('forbidden', 403);
    final ctx = await _pair(actorId, targetId);
    if (ctx == null) return _err('not_same_guild', 404);
    final (actor, target) = ctx;
    if (!_outranks(actor.role, target.role)) return _err('forbidden', 403);
    await store.deleteMember(targetId);
    return me(actorId);
  }

  /// 직책 바꾸기(길드장만). `leader` 를 주면 위임 — 원래 길드장은 부길드장(자리가 없으면 멤버)이 된다.
  Future<GuildResult> setRole(
    String actorId,
    String targetId,
    String roleKey,
  ) async {
    if (actorId == targetId) return _err('forbidden', 403);
    final ctx = await _pair(actorId, targetId);
    if (ctx == null) return _err('not_same_guild', 404);
    final (actor, target) = ctx;
    if (actor.role != GuildRole.leader) return _err('forbidden', 403);
    final role = GuildRole.fromKey(roleKey);
    if (role == target.role) return me(actorId);
    final members = await store.members(actor.guildId);
    final deputies = members
        .where((m) => m.role == GuildRole.deputy && m.userId != targetId)
        .length;
    switch (role) {
      case GuildRole.leader:
        await _makeLeader(
          actor.guildId,
          targetId,
          previous: actorId,
          previousRole: deputies < config.deputyMax
              ? GuildRole.deputy
              : GuildRole.member,
        );
      case GuildRole.deputy:
        if (deputies >= config.deputyMax) {
          return _err('deputy_full', 409, {'max': config.deputyMax});
        }
        await store.setRole(targetId, GuildRole.deputy);
      case GuildRole.member:
        await store.setRole(targetId, GuildRole.member);
    }
    return me(actorId);
  }

  /// 가입 신청 수락·거절.
  Future<GuildResult> answerRequest(
    String actorId,
    String applicantId, {
    required bool accept,
  }) async {
    final actor = await store.membershipOf(actorId);
    if (actor == null) return _err('not_in_guild');
    if (!actor.role.canManage) return _err('forbidden', 403);
    final reqs = await store.requestsOf(actor.guildId);
    if (!reqs.any((r) => r.userId == applicantId)) {
      return _err('request_not_found', 404);
    }
    if (!accept) {
      await store.deleteRequest(actor.guildId, applicantId);
      return me(actorId);
    }
    final r = await store.insertMember(
      actor.guildId,
      applicantId,
      GuildRole.member,
    );
    switch (r) {
      case GuildInsertResult.full:
        return _err('guild_full');
      case GuildInsertResult.alreadyInGuild:
        // 그 사이 다른 길드에 들어갔다 — 신청만 치운다.
        await store.deleteRequest(actor.guildId, applicantId);
        return _err('already_in_guild');
      case GuildInsertResult.ok:
        await store.deleteRequestsOf(applicantId);
        return me(actorId);
    }
  }

  /// 길드 소개·가입 방식(길드장·부길드장).
  Future<GuildResult> settings(
    String actorId, {
    String? notice,
    String? joinMode,
  }) async {
    final actor = await store.membershipOf(actorId);
    if (actor == null) return _err('not_in_guild');
    if (!actor.role.canManage) return _err('forbidden', 403);
    final patch = <String, dynamic>{};
    if (notice != null) {
      final n = notice.trim();
      if (n.length > config.noticeMaxLength || rules.hasBannedWord(n)) {
        return _err('notice_invalid', 400);
      }
      patch['notice'] = n;
    }
    if (joinMode != null) {
      patch['join_mode'] = GuildJoinMode.fromKey(joinMode).key;
    }
    if (patch.isNotEmpty) await store.updateGuild(actor.guildId, patch);
    return me(actorId);
  }

  // ── 3단계: 경험치 · 출석 · 스킬 · 상점 ──

  /// 길드 경험치를 더하고 레벨·인원을 맞춘다(미션 판정·출석·보스·길드전 공용).
  Future<void> addExp(String guildId, int exp) async {
    if (exp <= 0) return;
    await store.addGuildExp(guildId, exp);
    final g = await store.guild(guildId);
    if (g != null) await _syncLevel(g);
  }

  /// 저장된 레벨·인원이 경험치와 어긋나면 고친다(곡선을 JSON 에서 바꿔도 따라온다).
  Future<GuildRow> _syncLevel(GuildRow g) async {
    final lv = config.level.levelOf(g.exp).level;
    final cap = config.level.maxMembers(config.maxMembers, lv);
    if (lv == g.level && cap == g.maxMembers) return g;
    await store.updateGuild(g.id, {'level': lv, 'max_members': cap});
    return g.copyWith(level: lv, maxMembers: cap);
  }

  /// 하루 한 번 출석(무료) — 내 코인 + 길드 경험치.
  Future<GuildResult> donate(String userId) async {
    final mine = await store.membershipOf(userId);
    if (mine == null) return _err('not_in_guild');
    final day = guildDayKey(
      now().toUtc(),
      anchorHour: config.mission.dayAnchorHourKst,
    );
    if (!await store.donate(userId, day, config.donateCoins)) {
      return _err('already_donated');
    }
    await addExp(mine.guildId, config.donateExp);
    return me(userId);
  }

  /// 스킬 한 단계 올리기(길드장·부길드장). 포인트 = (레벨 − 1).
  Future<GuildResult> skillUp(String actorId, String skillId) async {
    final actor = await store.membershipOf(actorId);
    if (actor == null) return _err('not_in_guild');
    if (!actor.role.canManage) return _err('forbidden', 403);
    final def = config.skill(skillId);
    final g = await store.guild(actor.guildId);
    if (def == null || g == null) return _err('bad_request', 400);
    final lv = config.level.levelOf(g.exp).level;
    final cur = g.skills[skillId] ?? 0;
    if (cur >= def.max) return _err('skill_max');
    if (guildPointsUsed(config.skills, g.skills) >= config.level.points(lv)) {
      return _err('no_points');
    }
    await store.updateGuild(g.id, {
      'skill_points': {...g.skills, skillId: cur + 1},
    });
    return me(actorId);
  }

  /// 스킬 초기화(길드장만) — 포인트를 모두 돌려받는다.
  Future<GuildResult> skillReset(String actorId) async {
    final actor = await store.membershipOf(actorId);
    if (actor == null) return _err('not_in_guild');
    if (actor.role != GuildRole.leader) return _err('forbidden', 403);
    await store.updateGuild(actor.guildId, {'skill_points': <String, int>{}});
    return me(actorId);
  }

  /// 상점 구매 — 코인·기간 한도를 DB 가 한 번에 확인·차감한다. 성공하면 `item` 을 돌려주고
  /// 라우트가 서버 세이브에 넣는다.
  Future<GuildResult> buy(String userId, String itemId) async {
    final mine = await store.membershipOf(userId);
    if (mine == null) return _err('not_in_guild');
    final it = config.shopItem(itemId);
    if (it == null) return _err('bad_request', 400);
    final r = await store.buy(
      userId: userId,
      itemId: it.id,
      period: _periods(now().toUtc())[it.id]!,
      limit: it.limit,
      cost: it.cost,
    );
    return switch (r) {
      GuildBuyResult.ok => _ok({'item': it.toJson()}),
      GuildBuyResult.limit => _err('shop_limit'),
      GuildBuyResult.coins => _err('not_enough_coins'),
    };
  }

  /// 품목 → 이번 기간 키(하루 = KST 09시, 주 = 월 09시).
  Map<String, String> _periods(DateTime t) {
    final day = guildDayKey(t, anchorHour: config.mission.dayAnchorHourKst);
    final week = 'w${guildWeekKey(t)}';
    return {
      for (final it in config.shop) it.id: it.period == 'week' ? week : day,
    };
  }

  // ── 규칙 ──

  /// 앞뒤 공백을 자르고 가운데 연속 공백을 하나로.
  static String normalizeName(String name) =>
      name.trim().replaceAll(RegExp(r'\s+'), ' ');

  /// 길드 이름 — 닉네임과 **같은 기준**(문자 구성·금칙어·운영자 사칭) + 길이.
  bool nameOk(String name) {
    final n = name.runes.length;
    return n >= config.nameMinLength &&
        n <= config.nameMaxLength &&
        rules.nicknameAllowed(name);
  }

  static String _lang(String l) =>
      const {'ko', 'en', 'ja'}.contains(l) ? l : 'en';

  Future<DateTime?> _cooldownUntil(String userId, DateTime t) async {
    final left = await store.leftAt(userId);
    if (left == null) return null;
    final until = left.add(Duration(hours: config.rejoinCooldownHours));
    return t.isBefore(until) ? until : null;
  }

  /// 같은 길드의 두 사람. 아니면 null.
  Future<(GuildMemberRow, GuildMemberRow)?> _pair(String a, String b) async {
    final ma = await store.membershipOf(a);
    final mb = await store.membershipOf(b);
    if (ma == null || mb == null || ma.guildId != mb.guildId) return null;
    return (ma, mb);
  }

  static int _rank(GuildRole r) => switch (r) {
    GuildRole.leader => 2,
    GuildRole.deputy => 1,
    GuildRole.member => 0,
  };

  static bool _outranks(GuildRole a, GuildRole b) => _rank(a) > _rank(b);

  /// 화면 순서 — 직책 → 전투력.
  static List<GuildMemberRow> _sorted(List<GuildMemberRow> ms) =>
      [...ms]..sort((a, b) {
        final r = _rank(b.role) - _rank(a.role);
        if (r != 0) return r;
        return b.power.compareTo(a.power);
      });

  bool _active(GuildMemberRow m, DateTime t) =>
      t.difference(m.lastSeen) < Duration(days: config.leaderInactiveDays);

  /// 다음 길드장 — 최근 접속한 사람 중 부길드장 → 기여도 → 먼저 들어온 순.
  /// 모두 오래 비었으면 같은 순서로 그중에서 고른다(길드장 자리를 비워 두지 않는다).
  GuildMemberRow? _successor(List<GuildMemberRow> candidates, DateTime t) {
    if (candidates.isEmpty) return null;
    final list = [...candidates]
      ..sort((a, b) {
        final act = (_active(b, t) ? 1 : 0) - (_active(a, t) ? 1 : 0);
        if (act != 0) return act;
        final dep =
            (b.role == GuildRole.deputy ? 1 : 0) -
            (a.role == GuildRole.deputy ? 1 : 0);
        if (dep != 0) return dep;
        final c = b.contribution.compareTo(a.contribution);
        if (c != 0) return c;
        return a.joinedAt.compareTo(b.joinedAt);
      });
    return list.first;
  }

  Future<void> _makeLeader(
    String guildId,
    String userId, {
    required String? previous,
    GuildRole previousRole = GuildRole.member,
  }) async {
    if (previous != null) await store.setRole(previous, previousRole);
    await store.setRole(userId, GuildRole.leader);
    await store.updateGuild(guildId, {'leader': userId});
  }

  /// 길드장이 [GuildConfig.leaderInactiveDays] 동안 안 들어왔고, 그보다 최근에 들어온 사람이 있으면 넘긴다.
  Future<bool> _delegateIfLeaderAway(
    GuildRow g,
    List<GuildMemberRow> members,
    DateTime t,
  ) async {
    final leader = members.where((m) => m.role == GuildRole.leader).firstOrNull;
    if (leader != null && _active(leader, t)) return false;
    final others = [
      for (final m in members)
        if (m.userId != leader?.userId && _active(m, t)) m,
    ];
    final next = _successor(others, t);
    if (next == null) return false;
    await _makeLeader(g.id, next.userId, previous: leader?.userId);
    return true;
  }
}
