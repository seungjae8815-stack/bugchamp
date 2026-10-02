import 'dart:math';

import 'package:core_run/core_run.dart';
import 'package:server/src/guild_boss_actions.dart';
import 'package:server/src/guild_boss_store.dart';
import 'package:server/src/guild_store.dart';
import 'package:test/test.dart';

void main() {
  late DateTime t;
  late MemoryGuildStore guilds;
  late MemoryGuildBossStore store;
  late GuildBossActions a;
  late String gid;
  final power = <String, double>{'a': 100, 'b': 100};
  const cfg = GuildConfig(
    boss: GuildBossConfig(
      attacksPerDay: 2,
      hitsPerMember: 2,
      stageGrowth: 2,
      variance: 0,
      attackCoins: 10,
      chestShares: [0.1],
      chestCoins: [5],
      killCoinsPerStage: 20,
      rankRewards: [SeasonRankReward(maxRank: 1, jelly: 30)],
    ),
  );

  setUp(() async {
    t = DateTime.utc(2026, 10, 5, 3); // 월
    guilds = MemoryGuildStore(clock: () => t);
    store = MemoryGuildBossStore(onKillCoins: guilds.addCoins);
    a = GuildBossActions(
      guilds: guilds,
      store: store,
      config: cfg,
      now: () => t,
      teamPowerOf: (u) async => power[u],
      addExp: guilds.addGuildExp,
      rng: Random(1),
    );
    gid = (await guilds.insertGuild(
      name: '보스길드',
      lang: 'ko',
      leader: 'a',
      maxMembers: 20,
      joinMode: GuildJoinMode.open,
    ))!.id;
    for (final u in ['a', 'b', 'c']) {
      await guilds.insertMember(gid, u, GuildRole.member);
    }
  });

  test('체력 = 방어팀 있는 길드원 전투력 합 × hitsPerMember', () async {
    final (_, v) = await a.view('a');
    expect(v['hpMax'], 200 * 2);
    expect(v['attacksLeft'], 2);
    expect(v['hasTeam'], true);
  });

  test('방어팀이 없으면 공격 못 한다 · 하루 2회', () async {
    expect((await a.attack('c')).$2['error'], 'no_defense_team');
    expect((await a.attack('a')).$1, 200);
    expect((await a.attack('a')).$1, 200);
    expect((await a.attack('a')).$2['error'], 'no_attacks');
    t = t.add(const Duration(days: 1));
    expect((await a.attack('a')).$1, 200);
  });

  test('공격마다 코인 + 피해 구간 상자 · 처치하면 공격한 전원 코인 · 다음 단계', () async {
    final (_, r) = await a.attack('a'); // 100 / 400 = 25% → 상자
    expect((r['hit'] as Map)['coins'], 15);
    await a.attack('b');
    await a.attack('a');
    final (_, k) = await a.attack('b'); // 400 → 처치
    expect((k['hit'] as Map)['killed'], 1);
    expect(k['stage'], 2);
    expect(k['hpMax'], 800);
    // a: 15+15 + 처치 20 · b: 15+15 + 20
    expect(guilds.memberRows['a']!.coins, 50);
    expect(guilds.memberRows['b']!.coins, 50);
    expect(guilds.guilds[gid]!.exp, greaterThan(0));
  });

  test('지난주 순위 보상 — 공격한 사람만 · 한 번만', () async {
    await a.attack('a');
    t = t.add(const Duration(days: 7));
    final (_, v) = await a.view('a');
    expect((v['lastWeek'] as Map)['jelly'], 30);
    final (st, _, jelly) = await a.claimLastWeek('a');
    expect(st, 200);
    expect(jelly, 30);
    expect((await a.claimLastWeek('a')).$1, 409);
    expect((await a.claimLastWeek('b')).$1, 409, reason: 'b 는 공격 안 함');
  });
}
