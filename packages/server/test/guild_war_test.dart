import 'dart:convert';
import 'dart:io';

import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:server/src/guild_store.dart';
import 'package:server/src/guild_war_actions.dart';
import 'package:server/src/guild_war_store.dart';
import 'package:test/test.dart';

DuelBug _bug(String id, [double scale = 1]) => DuelBug(
  id: id,
  name: id,
  speciesId: 'x',
  element: Element.wood,
  temperament: Temperament.steadfast,
  specialty: Specialty.grip,
  sizeMm: 60,
  maxHp: 150 * scale,
  atk: 60 * scale,
  def: 50 * scale,
  spd: 50 * scale,
);

void main() {
  late DateTime t;
  late Map<String, List<DuelBug>> teams;
  late MemoryGuildStore guilds;
  late MemoryGuildWarStore store;
  late GuildWarActions w;
  late GuildConfig cfg;
  late String ga, gb;

  setUp(() async {
    final j =
        jsonDecode(File('../app/assets/data/guild.json').readAsStringSync())
            as Map<String, dynamic>;
    (j['war'] as Map)['startWeek'] = '2026-10-05';
    cfg = GuildConfig.fromJson(j);
    t = DateTime.utc(2026, 10, 4, 12); // 대전 전 주 일요일 — 이때 가입
    guilds = MemoryGuildStore(clock: () => t);
    teams = {};
    store = MemoryGuildWarStore(
      clock: () => t,
      membersOf: (g) =>
          guilds.memberRows.values.where((m) => m.guildId == g).length,
      guildOf: (g) {
        final x = guilds.guilds[g];
        return x == null ? null : (tier: x.tier, gr: x.gr);
      },
    );
    w = GuildWarActions(
      guilds: guilds,
      store: store,
      config: cfg,
      now: () => t,
      teamOf: (u) async => teams[u],
      duelParams: const DuelParams(),
      addExp: guilds.addGuildExp,
    );
    Future<String> make(String name, String prefix) async {
      final g = (await guilds.insertGuild(
        name: name,
        lang: 'ko',
        leader: '${prefix}0',
        maxMembers: 20,
        joinMode: GuildJoinMode.open,
      ))!;
      for (var i = 0; i < 5; i++) {
        await guilds.insertMember(g.id, '$prefix$i', GuildRole.member);
      }
      store.knownGuilds.add(g.id);
      return g.id;
    }

    ga = await make('A길드', 'a');
    gb = await make('B길드', 'b');
  });

  String day(DateTime x) => guildDayKey(x);

  test('startWeek 전에는 열리지 않고 점수도 안 쌓인다', () async {
    await w.recordTally('a0', day(t), {'breedDone': 5});
    expect(store.scores, isEmpty);
    final (_, v) = await w.view('a0');
    expect(v['open'], false);
  });

  test('1일차(육성) — 주제에 맞는 행동만 · 멤버 하루 상한 · 다른 날 행동은 무시', () async {
    t = DateTime.utc(2026, 10, 5, 3); // 월 12시 KST = 1일차
    await w.recordTally('a0', day(t), {'breedDone': 50, 'elite': 999});
    expect(await store.myScore('2026-10-05', 'a0', 1), 100, reason: '상한 100');
    await w.recordTally('a1', day(t), {'synth': 2});
    expect(await store.myScore('2026-10-05', 'a1', 1), 6);
    // 결투는 1일차 주제가 아니다.
    await w.recordServerAction('a0', 'duelWin');
    expect(await store.myScore('2026-10-05', 'a0', 1), 100);
  });

  test('4일차 결투 승리·6일차 보스 공격은 서버가 센다(상한까지)', () async {
    t = DateTime.utc(2026, 10, 8, 3); // 목 = 4일차
    for (var i = 0; i < 9; i++) {
      await w.recordServerAction('a0', 'duelWin');
    }
    expect(await store.myScore('2026-10-05', 'a0', 4), 50);
    await w.recordTally('a0', day(t), {'duelWin': 99}); // 앱이 보낸 결투 수는 무시
    expect(await store.myScore('2026-10-05', 'a0', 4), 50);
  });

  test('매칭 — 5명 이상 두 길드가 붙고, 7일차에 결과·등급점·보상', () async {
    t = DateTime.utc(2026, 10, 5, 3);
    final (_, v) = await w.view('a0');
    expect((v['match'] as Map)['opponent'], 'B길드');
    // 상대 문장 — 고른 적 없으면 null(앱이 opponentId 해시로 기본 문장), 고르면 그 값.
    expect((v['match'] as Map)['opponentId'], gb);
    expect((v['match'] as Map)['opponentEmblem'], isNull);
    await guilds.updateGuild(gb, {'emblem': 9});
    final (_, v2) = await w.view('a0');
    expect((v2['match'] as Map)['opponentEmblem'], 9);
    // A 가 1·2·4·5·6일차(1+2+3+3+4 = 13), B 가 3일차(2)를 이긴다. 7일차(6)는 누가 이겨도 A 승.
    await w.recordTally('a0', day(t), {'breedDone': 5});
    t = DateTime.utc(2026, 10, 6, 3);
    await w.recordTally('a0', day(t), {'forge:3': 10});
    t = DateTime.utc(2026, 10, 7, 3);
    await w.recordTally('b0', day(t), {'zoneClear': 2});
    t = DateTime.utc(2026, 10, 8, 3);
    await w.recordServerAction('a0', 'duelWin');
    t = DateTime.utc(2026, 10, 9, 3);
    await w.recordTally('a0', day(t), {'bugLevel': 1});
    t = DateTime.utc(2026, 10, 10, 3);
    await w.recordServerAction('a0', 'bossAttack');
    // 7일차(일 09시 KST 이후).
    t = DateTime.utc(2026, 10, 11, 3);
    final (_, r) = await w.view('a0');
    final res = r['result'] as Map;
    expect(res['won'], true);
    expect(res['draw'], false);
    expect(res['points'], greaterThan(res['theirPoints'] as int));
    expect(
      (res['points'] as int) + (res['theirPoints'] as int),
      21,
      reason: '무승부 없음 — 날마다 한쪽이 승점을 가져간다',
    );
    expect(guilds.guilds[ga]!.gr, cfg.war.grWin);
    expect(guilds.guilds[gb]!.gr, 0, reason: '0 아래로는 내려가지 않는다');
    // 결과는 한 번만 — 다시 봐도 등급점이 안 바뀐다.
    await w.view('b0');
    expect(guilds.guilds[ga]!.gr, cfg.war.grWin);

    final (st, out, jelly) = await w.claim('a0');
    expect(st, 200);
    expect(jelly, cfg.war.tiers.first.jelly);
    expect(out['coins'], cfg.war.tiers.first.coins);
    expect((await w.claim('a0')).$1, 409, reason: '한 번만');
    // 진 쪽은 절반.
    final (_, _, lose) = await w.claim('b0');
    expect(lose, (cfg.war.tiers.first.jelly * cfg.war.loseShare).round());
    // 점수를 안 낸 사람은 못 받는다.
    expect((await w.claim('a4')).$1, 409);
  });

  test('주중에 들어온 사람은 그 주 보상을 못 받는다', () async {
    t = DateTime.utc(2026, 10, 5, 3);
    await guilds.insertMember(ga, 'late', GuildRole.member);
    await w.recordTally('late', day(t), {'breedDone': 1});
    t = DateTime.utc(2026, 10, 11, 3);
    await w.view('late');
    expect((await w.claim('late')).$1, 409);
  });

  test('상대가 없으면 가상 길드(같은 티어 평균)', () async {
    for (var i = 0; i < 5; i++) {
      await guilds.deleteMember('b$i');
    }
    t = DateTime.utc(2026, 10, 5, 3);
    final (_, v) = await w.view('a0');
    expect((v['match'] as Map)['virtual'], true);
  });

  test('인원 미달이면 매칭하지 않는다', () async {
    await guilds.deleteMember('a4');
    t = DateTime.utc(2026, 10, 5, 3);
    final (_, v) = await w.view('a0');
    expect(v['match'], isNull);
  });

  test('직전 주 상대는 피한다 — 다른 후보가 없으면 다시 붙는다', () async {
    // C 길드(5명) 추가 — 등급점이 멀어 원래라면 B 가 먼저 뽑힌다.
    final gc = (await guilds.insertGuild(
      name: 'C길드',
      lang: 'ko',
      leader: 'c0',
      maxMembers: 20,
      joinMode: GuildJoinMode.open,
    ))!.id;
    for (var i = 0; i < 5; i++) {
      await guilds.insertMember(gc, 'c$i', GuildRole.member);
    }
    store.knownGuilds.add(gc);
    await guilds.updateGuild(gc, {'gr': 500});

    t = DateTime.utc(2026, 10, 5, 3); // 1주차
    final (_, w1) = await w.view('a0');
    expect((w1['match'] as Map)['opponent'], 'B길드');
    await w.view('c0'); // C 는 상대가 없어 가상

    t = DateTime.utc(2026, 10, 12, 3); // 2주차 — A 가 먼저 조회
    final (_, w2) = await w.view('a0');
    expect((w2['match'] as Map)['opponent'], 'C길드', reason: 'B 는 직전 상대');

    // 3주차: 후보가 직전 상대(C)뿐이면 가상 길드 대신 다시 붙는다.
    for (var i = 0; i < 5; i++) {
      await guilds.deleteMember('b$i');
    }
    t = DateTime.utc(2026, 10, 19, 3);
    final (_, w3) = await w.view('a0');
    expect((w3['match'] as Map)['opponent'], 'C길드');
  });

  test('하루 점수가 같으면 그날 점수 낸 인원이 많은 쪽 → 같으면 먼저 도달한 쪽', () async {
    t = DateTime.utc(2026, 10, 5, 1);
    await w.view('a0');
    // 1일차: A 는 한 명이 30, B 는 세 명이 10씩(합 30) → B.
    await w.recordTally('a0', day(t), {'breedDone': 3});
    for (final u in ['b0', 'b1', 'b2']) {
      await w.recordTally(u, day(t), {'breedDone': 1});
    }
    // 2일차: 둘 다 한 명이 5점 — A 가 먼저.
    t = DateTime.utc(2026, 10, 6, 1);
    await w.recordTally('a0', day(t), {'forge:0': 5});
    t = DateTime.utc(2026, 10, 6, 2);
    await w.recordTally('b0', day(t), {'forge:0': 5});
    t = DateTime.utc(2026, 10, 11, 3);
    final (_, r) = await w.view('a0');
    final days = (r['result'] as Map)['days'] as List;
    expect(days[0], 1, reason: '인원 많은 B');
    expect(days[1], 0, reason: '먼저 도달한 A');
    expect(days.every((d) => d == 0 || d == 1), isTrue, reason: '무승부 없음');
  });

  test('7일차에 아무도 안 열었으면 다음 주 조회·수령 때 지난주를 판정한다', () async {
    t = DateTime.utc(2026, 10, 5, 3);
    await w.view('a0'); // 매칭만
    await w.recordTally('a0', day(t), {'breedDone': 5});
    await w.recordTally('b0', day(t), {'breedDone': 1});
    // 7일차를 건너뛰고 다음 주 월요일에 바로 수령.
    t = DateTime.utc(2026, 10, 12, 3);
    final m = await store.matchOf('2026-10-05', ga);
    expect(m!.result, isNull);
    final (st, _, _) = await w.claim('a0');
    expect(st, 200, reason: '수령하면서 지난주 경기를 판정한다');
    expect((await store.matchOf('2026-10-05', ga))!.result, isNotNull);
    final (_, v) = await w.view('b0');
    expect((v['lastWeek'] as Map)['eligible'], true);
  });

  test('판정은 한 번만 맡는다 — 다른 요청이 판정 중이면 계산하지 않는다', () async {
    t = DateTime.utc(2026, 10, 5, 3);
    await w.view('a0');
    final m = await store.matchOf('2026-10-05', ga);
    expect(await store.tryLockResolve(m!.id), isTrue);
    t = DateTime.utc(2026, 10, 11, 3);
    final (_, v) = await w.view('a0');
    expect(v['result'], isNull, reason: '판정 중 — 결과를 다시 계산하지 않는다');
    expect(guilds.guilds[ga]!.gr, 0);
  });

  test('7일차 대결은 그 주 월 09시 전에 가입한 길드원만(용병 차단)', () async {
    for (var i = 0; i < 5; i++) {
      teams['a$i'] = [_bug('a$i')];
      teams['b$i'] = [_bug('b$i')];
    }
    t = DateTime.utc(2026, 10, 5, 3);
    await w.view('a0');
    // 수요일에 센 용병이 A 에 들어온다.
    t = DateTime.utc(2026, 10, 7, 3);
    await guilds.insertMember(ga, 'merc', GuildRole.member);
    teams['merc'] = [_bug('merc', 50)];
    t = DateTime.utc(2026, 10, 11, 3);
    final (_, r) = await w.view('a0');
    final pairs = (r['result'] as Map)['pairs'] as List;
    expect(pairs, hasLength(5));
    expect(pairs.any((p) => (p as Map)['me'] == 'merc'), isFalse);
  });

  test('같은 사람·같은 날 점수는 길드를 옮겨도 합쳐서 상한까지', () async {
    t = DateTime.utc(2026, 10, 5, 3);
    await w.recordTally('a0', day(t), {'breedDone': 10}); // 100(상한)
    await guilds.deleteMember('a0');
    await guilds.insertMember(gb, 'a0', GuildRole.member);
    await w.recordTally('a0', day(t), {'breedDone': 12});
    expect(await store.myScore('2026-10-05', 'a0', 1), 100);
    final b = await store.dayStats('2026-10-05', gb);
    expect(b[0].total, 0, reason: '이미 A 에서 상한을 채웠다');
  });

  test('GUILD_WAR_START_WEEK — 월요일이면 덮고, 아니면 무시', () {
    final logs = <String>[];
    final c2 = guildConfigWithStartWeekEnv(cfg, '2026-10-12', log: logs.add);
    expect(c2.war.startWeek, '2026-10-12');
    expect(c2.war.dayPoints, cfg.war.dayPoints);
    expect(
      guildConfigWithStartWeekEnv(
        cfg,
        '2026-10-13',
        log: logs.add,
      ).war.startWeek,
      cfg.war.startWeek,
      reason: '화요일',
    );
    expect(
      guildConfigWithStartWeekEnv(
        cfg,
        '2026-02-30',
        log: logs.add,
      ).war.startWeek,
      cfg.war.startWeek,
    );
    expect(
      guildConfigWithStartWeekEnv(cfg, null).war.startWeek,
      cfg.war.startWeek,
    );
    expect(logs.where((l) => l.contains('무시')), hasLength(2));
  });
}
