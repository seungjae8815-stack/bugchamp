import 'dart:math' as math;

import 'package:core_run/core_run.dart';

import 'guild_actions.dart' show GuildResult, guildUndo;
import 'guild_boss_store.dart';
import 'guild_store.dart';

/// 길드 보스(docs/design_guild.md §3) — 조회 · 공격 · 지난주 순위 보상.
///
/// 주 경계 = 월 09:00 KST(결투 시즌·심연과 같다). 보스는 그 주 첫 조회·공격 때 만든다(cron 없음).
class GuildBossActions {
  GuildBossActions({
    required this.guilds,
    required this.store,
    required this.config,
    required this.now,
    required this.teamPowerOf,
    required this.addExp,
    math.Random? rng,
    this.onDamage,
  }) : _rng = rng ?? math.Random.secure();

  final GuildStore guilds;
  final GuildBossStore store;
  final GuildConfig config;
  final DateTime Function() now;

  /// 결투 방어팀 전투력(서버 검증을 거친 값). 방어팀이 없으면 null.
  final Future<double?> Function(String userId) teamPowerOf;
  final Future<void> Function(String guildId, int exp) addExp;

  /// 길드전 6일차(보스 피해) 점수 — 5단계가 건다.
  final Future<void> Function(String userId, String guildId, double damage)?
  onDamage;
  final math.Random _rng;

  GuildBossConfig get c => config.boss;

  static GuildResult _err(String code, [int status = 409]) =>
      (status, {'error': code});

  String _day(DateTime t) =>
      guildDayKey(t, anchorHour: config.mission.dayAnchorHourKst);

  /// 이번 주 보스(없으면 만든다). 만들 때 체력은 방어팀이 있는 길드원 전투력 합으로 **추정**만 하고
  /// (`estPower`), 그 주에 공격하는 길드원이 자기 몫을 공격 순간 체력에 더한다(`basePower`,
  /// [GuildBossStore.hit]) — 방어팀을 비운 채 열어 체력을 4 로 만드는 구멍(2026-10-05 점검).
  Future<GuildBossRow> _ensure(String week, GuildRow g) async {
    final have = await store.boss(week, g.id);
    if (have != null) return have;
    var sum = 0.0;
    for (final m in await guilds.members(g.id)) {
      sum += await teamPowerOf(m.userId) ?? 0;
    }
    final hp = c.hpFor(sum, 1);
    return store.ensure(
      GuildBossRow(
        week: week,
        guildId: g.id,
        tier: g.tier,
        hpMax: hp,
        hpLeft: hp,
        estPower: sum,
      ),
    );
  }

  Future<GuildResult> view(String userId) async {
    final mine = await guilds.membershipOf(userId);
    if (mine == null) return _err('not_in_guild');
    final g = await guilds.guild(mine.guildId);
    if (g == null) return _err('not_in_guild');
    final t = now().toUtc();
    final week = guildWeekKey(t);
    final b = await _ensure(week, g);
    final h = await store.hitsOf(week, userId);
    // 하루 공격 수는 **유저 기준**(길드를 옮겨도 이어진다 — 추방 → 재가입으로 하루 두 번 치던 구멍).
    final myToday = h?.hitsOn(_day(t)) ?? 0;
    final last = await _lastWeek(userId, t);
    return (
      200,
      {
        'week': week,
        'endsAt': guildWeekStart(
          t,
        ).add(const Duration(days: 7)).toIso8601String(),
        'now': t.toIso8601String(),
        'stage': b.stage,
        'hpMax': b.hpMax,
        'hpLeft': b.hpLeft,
        'attacksLeft': math.max(0, c.attacksPerDay - myToday),
        'myDamage': h != null && h.guildId == g.id ? h.damage : 0,
        'rank': await store.rankOf(week, g.id),
        'top': await store.top(week, b.tier, 10),
        'hasTeam': await teamPowerOf(userId) != null,
        'lastWeek': last,
      },
    );
  }

  Future<GuildResult> attack(String userId) async {
    final mine = await guilds.membershipOf(userId);
    if (mine == null) return _err('not_in_guild');
    final g = await guilds.guild(mine.guildId);
    if (g == null) return _err('not_in_guild');
    final power = await teamPowerOf(userId);
    if (power == null) return _err('no_defense_team');
    final t = now().toUtc();
    final week = guildWeekKey(t);
    final b = await _ensure(week, g);
    final dmg = c.damage(power, _rng.nextDouble());
    final r = await store.hit(
      week: week,
      guildId: g.id,
      userId: userId,
      day: _day(t),
      damage: dmg,
      power: power,
      hpPerPower: c.hitsPerMember,
      maxDaily: c.attacksPerDay,
      growth: c.stageGrowth,
      killCoinsPerStage: c.killCoinsPerStage,
    );
    if (!r.ok) return _err('no_attacks');
    // 상자 비율의 분모 = 내 몫을 더한 뒤의 체력(더하기 전 체력으로 나누면 첫 공격이 늘 큰 상자다).
    final hpAt = r.hpHit > 0 ? r.hpHit : b.hpMax;
    final chest = c.chestFor(hpAt <= 0 ? 0 : dmg / hpAt);
    await guilds.addCoins(userId, c.attackCoins + chest);
    await addExp(g.id, c.attackExp + r.killed * c.killExp);
    await onDamage?.call(userId, g.id, dmg);
    final (st, body) = await view(userId);
    return (
      st,
      {
        ...body,
        'hit': {
          'damage': dmg,
          'coins': c.attackCoins + chest,
          'chest': chest,
          'killed': r.killed,
        },
      },
    );
  }

  /// 지난주 순위 보상 — 그 주에 한 번이라도 공격했고, 길드가 순위 안이면 젤리.
  Future<Map<String, dynamic>?> _lastWeek(String userId, DateTime t) async {
    final week = guildWeekKey(t.subtract(const Duration(days: 7)));
    final h = await store.hitsOf(week, userId);
    if (h == null || h.hits <= 0) return null;
    final rank = await store.rankOf(week, h.guildId);
    final jelly = c.rankJelly(rank ?? 0);
    return {
      'week': week,
      'rank': rank,
      'jelly': jelly,
      'claimed': await store.claimed(week, userId),
    };
  }

  /// 지난주 보상 수령 — 수령 기록을 **먼저** 남기고 [deliver](라우트가 젤리를 서버 세이브에 넣고 저장)를
  /// 부른다. [deliver] 가 실패하면 수령 기록을 되돌리고 오류를 다시 던진다(보상 유실 방지).
  Future<(int, Map<String, dynamic>, int)> claimLastWeek(
    String userId, {
    Future<void> Function(int jelly)? deliver,
  }) async {
    final t = now().toUtc();
    final last = await _lastWeek(userId, t);
    final jelly = (last?['jelly'] as int?) ?? 0;
    if (last == null || jelly <= 0) {
      return (409, <String, dynamic>{'error': 'nothing_to_claim'}, 0);
    }
    final week = last['week'] as String;
    if (!await store.insertClaim(week, userId)) {
      return (409, <String, dynamic>{'error': 'already_claimed'}, 0);
    }
    if (deliver != null) {
      try {
        await deliver(jelly);
      } catch (_) {
        await guildUndo('boss', () => store.deleteClaim(week, userId));
        rethrow;
      }
    }
    return (200, <String, dynamic>{'rank': last['rank']}, jelly);
  }
}
