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
    power
      ..clear()
      ..addAll({'a': 100, 'b': 100});
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

  test('방어팀을 비우고 열어도 — 공격자 몫이 그 순간 체력에 더해진다', () async {
    // 아무도 방어팀이 없을 때 처음 열림 → 체력은 자리표시(1 × 2).
    power.remove('a');
    power.remove('b');
    final (_, v0) = await a.view('a');
    expect(v0['hpMax'], 2);
    // 방어팀을 다시 채우고 공격 — 내 몫(100 × 2)이 먼저 들어가고 그다음 피해.
    power['a'] = 100;
    final (_, r) = await a.attack('a');
    expect(r['hpMax'], 200);
    expect(r['hpLeft'], 100);
    expect(r['stage'], 1, reason: '한 방에 잡히지 않는다');
    // 두 번째 공격은 이미 넣은 몫이라 체력이 안 는다 · b 가 처음 치면 b 몫이 더해진다.
    power['b'] = 100;
    final (_, r2) = await a.attack('b');
    expect(r2['hpMax'], 400);
    expect(r2['hpLeft'], 400 - 100 - 100);
  });

  test('세진 만큼만 더 넣는다 — 약한 팀으로 열고 센 팀으로 바꿔 치는 구멍', () async {
    power['a'] = 10;
    power['b'] = 10;
    await a.view('a'); // 추정 = 20 → 체력 40
    await a.attack('a'); // 몫 10 (추정 안)
    power['a'] = 1000;
    final (_, r) = await a.attack('a');
    // 공격자 합 = 10 + 990 = 1000 → 체력 2000.
    expect(r['hpMax'], 2000);
  });

  test('하루 공격 수는 유저 기준 — 다른 길드로 옮겨도 이어진다', () async {
    await a.attack('a');
    await a.attack('a');
    await guilds.deleteMember('a');
    final g2 = (await guilds.insertGuild(
      name: '두번째',
      lang: 'ko',
      leader: 'a',
      maxMembers: 20,
      joinMode: GuildJoinMode.open,
    ))!.id;
    await guilds.insertMember(g2, 'a', GuildRole.leader);
    expect(guilds.memberRows['a']!.guildId, g2);
    final (_, v) = await a.view('a');
    expect(v['attacksLeft'], 0);
    expect((await a.attack('a')).$2['error'], 'no_attacks');
  });

  test('보상 지급(저장)이 실패하면 수령 기록을 되돌린다', () async {
    await a.attack('a');
    t = t.add(const Duration(days: 7));
    await expectLater(
      a.claimLastWeek('a', deliver: (_) async => throw StateError('db')),
      throwsStateError,
    );
    final (st, _, jelly) = await a.claimLastWeek('a');
    expect(st, 200, reason: '실패한 수령은 기록이 남지 않는다');
    expect(jelly, 30);
  });
}
