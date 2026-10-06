import 'dart:convert';
import 'dart:io';

import 'package:core_run/core_run.dart';
import 'package:server/src/guild_mission_actions.dart';
import 'package:server/src/guild_mission_store.dart';
import 'package:server/src/guild_store.dart';
import 'package:test/test.dart';

void main() {
  late DateTime t;
  late MemoryGuildStore guilds;
  late MemoryGuildMissionStore store;
  late GuildMissionActions a;
  const cfg = GuildConfig();
  final run = RunConfig.fromJson(
    jsonDecode(File('../app/assets/data/run_config.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  late String gid;

  setUp(() async {
    t = DateTime.utc(2026, 10, 5, 3); // KST 12:00
    guilds = MemoryGuildStore(clock: () => t);
    store = MemoryGuildMissionStore();
    a = GuildMissionActions(
      guilds: guilds,
      store: store,
      config: cfg,
      run: run,
      now: () => t,
      addExp: guilds.addGuildExp,
    );
    final g = await guilds.insertGuild(
      name: '장수풍뎅이단',
      lang: 'ko',
      leader: 'a',
      maxMembers: 20,
      joinMode: GuildJoinMode.open,
    );
    gid = g!.id;
    for (final u in ['a', 'b', 'c', 'd', 'e']) {
      await guilds.insertMember(gid, u, GuildRole.member);
    }
  });

  Future<Map<String, dynamic>> start(
    String u, {
    int slot = 0,
    int wait = 60,
    double power = 100,
    int stage = 1,
  }) async {
    final (st, body) = await a.start(
      u,
      slot: slot,
      waitSec: wait,
      power: power,
      stage: stage,
      nickname: u,
    );
    expect(st, 200, reason: '$body');
    return body;
  }

  String activeId(Map<String, dynamic> body) =>
      ((body['active'] as List).first as Map)['id'] as String;

  test('×0.8 칸은 혼자 바로 성공하고 보상을 받는다 · 두 번은 못 받는다', () async {
    final body = await start('a', wait: 600);
    expect(body['active'], isEmpty);
    expect((body['recent'] as List).single['success'], true);
    expect(store.chat, isEmpty, reason: '바로 끝났으면 도움 요청을 안 올린다');
    expect(guilds.guilds[gid]!.exp, cfg.mission.expSuccess);

    final r = await a.claimAll('a');
    // 혼자 바로 성공은 10분을 골라도 대기 배율 1.
    final want = guildMissionReward(
      cfg.mission,
      run,
      stage: 1,
      mult: 0.8,
      factor: 1,
    );
    expect(r.missions, 1);
    expect(r.reward.chitin, want.chitin);
    expect(r.reward.coins, want.coins);
    expect(guilds.memberRows['a']!.coins, want.coins);
    expect((await a.claimAll('a')).missions, 0);
  });

  test('×3.5 칸 — 도움 요청이 채팅에 뜨고, 세 명이 모이면 바로 성공', () async {
    final body = await start('a', slot: 4);
    final id = activeId(body);
    expect(store.chat, ['#help:$id']);
    for (final u in ['b', 'c']) {
      final (st, _) = await a.help(u, id, power: 100, stage: 1, nickname: u);
      expect(st, 200);
    }
    expect(store.rows[id]!.settled, isFalse, reason: '도움 2명 — 아직');
    final (_, last) = await a.help(
      'd',
      id,
      power: 100,
      stage: 1,
      nickname: 'd',
    );
    expect(store.rows[id]!.success, isTrue, reason: '3명 다 모임');
    expect(last['active'], isEmpty);
  });

  test('센 길드원 한 명이 도우면 깬다 — 단, 시간은 끝까지 흐르고 그때 판정', () async {
    final id = activeId(await start('a', slot: 4)); // 요구 350
    await a.help('b', id, power: 1e12, stage: 1, nickname: 'b');
    final m = store.rows[id]!;
    expect(m.helpers.single.power, 1e12, reason: '몫 상한 없음');
    expect(m.settled, isFalse, reason: '도움이 다 차기 전엔 시간이 흐른다');
    t = t.add(const Duration(seconds: 61));
    await a.view('a');
    expect(store.rows[id]!.success, isTrue);
  });

  test('도움 3명이 다 모이면 전투력이 모자라도 그 자리에서 성공', () async {
    final id = activeId(await start('a', slot: 4, wait: 600)); // 요구 350
    for (final u in ['b', 'c', 'd']) {
      await a.help(u, id, power: 1, stage: 1, nickname: u); // 합 103
    }
    final m = store.rows[id]!;
    expect(m.success, isTrue);
    expect(m.endsAt, t, reason: '10분을 기다리지 않는다');
  });

  test('시간이 끝나면 조회 때 부분 판정 — 보상 = 배율 × 달성률 × 0.5', () async {
    final id = activeId(await start('a', slot: 3)); // ×2.5, 요구 250
    await a.help('b', id, power: 100, stage: 1, nickname: 'b'); // 200/250
    t = t.add(const Duration(seconds: 61));
    final (_, body) = await a.view('c');
    final done = (body['recent'] as List).single as Map;
    expect(done['success'], false);
    expect(done['ratio'], closeTo(0.8, 1e-9));
    final r = await a.claimAll('a');
    final want = guildMissionReward(
      cfg.mission,
      run,
      stage: 1,
      mult: 2.5,
      factor: 0.8 * cfg.mission.partialRewardMult,
    );
    expect(r.reward.chitin, want.chitin);
  });

  test('돕는 사람 보상은 **자기 사냥터** 기준 · 절반', () async {
    final id = activeId(await start('a', slot: 1, stage: 1)); // ×1.3
    await a.help('b', id, power: 100, stage: 800, nickname: 'b');
    t = t.add(const Duration(seconds: 61)); // 시간이 끝나야 판정
    final r = await a.claimAll('b');
    final want = guildMissionReward(
      cfg.mission,
      run,
      stage: 800,
      mult: 1.3,
      factor: 1,
      helper: true,
    );
    expect(r.reward.chitin, want.chitin);
    expect(r.reward.coins, cfg.mission.helperCoins);
    expect(r.eggs, 0, reason: '요정 알은 출발자만');
  });

  test('하루 출발 3회 · 진행 중이면 새로 못 떠난다', () async {
    final id = activeId(await start('a', slot: 4));
    final (st, body) = await a.start(
      'a',
      slot: 0,
      waitSec: 60,
      power: 100,
      stage: 1,
      nickname: 'a',
    );
    expect(st, 409);
    expect(body['error'], 'mission_running');
    t = t.add(const Duration(minutes: 2));
    await a.view('a'); // 판정
    expect(store.rows[id]!.settled, isTrue);
    await start('a');
    await start('a');
    final (st2, b2) = await a.start(
      'a',
      slot: 0,
      waitSec: 60,
      power: 100,
      stage: 1,
      nickname: 'a',
    );
    expect(st2, 409);
    expect(b2['error'], 'no_starts_left');

    // 다음 날 09시(KST)에 다시 3회.
    t = DateTime.utc(2026, 10, 6, 0, 1);
    final (_, v) = await a.view('a');
    expect(v['startsLeft'], 3);
  });

  test('도움 보상은 하루 5회까지 — 그 뒤로도 도울 수는 있다', () async {
    final owners = ['a', 'c', 'd', 'e'];
    var n = 0;
    for (var round = 0; round < 2; round++) {
      for (final o in owners) {
        if (n == 6) break;
        final id = activeId(await start(o, slot: 4));
        final (st, body) = await a.help(
          'b',
          id,
          power: 1,
          stage: 1,
          nickname: 'b',
        );
        expect(st, 200);
        expect(body['helpRewarded'], n < 5, reason: '${n + 1}번째 도움');
        n++;
        t = t.add(const Duration(minutes: 2));
        await a.view(o);
      }
    }
  });

  test('자기 미션·다른 길드 미션은 도울 수 없다', () async {
    final id = activeId(await start('a', slot: 4));
    expect(
      (await a.help('a', id, power: 1, stage: 1, nickname: 'a')).$2['error'],
      'own_mission',
    );
    expect(
      (await a.help('zz', id, power: 1, stage: 1, nickname: 'zz')).$2['error'],
      'not_in_guild',
    );
  });

  test('동시에 여러 번 출발해도 한 번만(진행 중 1개) — DB 가 유저 잠금 아래 다시 센다', () async {
    final rs = await Future.wait([
      for (var i = 0; i < 6; i++)
        a.start('a', slot: 4, waitSec: 60, power: 100, stage: 1, nickname: 'a'),
    ]);
    expect(rs.where((r) => r.$1 == 200), hasLength(1));
    expect(store.rows.values.where((m) => m.owner == 'a'), hasLength(1));
  });

  test('도움 보상 하루 5회 — 동시에 6건을 도와도 보상 칸은 5건', () async {
    for (final u in ['f', 'g']) {
      await guilds.insertMember(gid, u, GuildRole.member);
    }
    final ids = <String>[];
    for (final u in ['a', 'b', 'c', 'd', 'e', 'f']) {
      final body = await start(u, slot: 4, wait: 600);
      ids.add(
        (body['active'] as List).cast<Map>().firstWhere(
              (m) => m['owner'] == u,
            )['id']
            as String,
      );
    }
    await Future.wait([
      for (final id in ids) a.help('g', id, power: 1, stage: 1, nickname: 'g'),
    ]);
    final rewarded = store.rows.values
        .expand((m) => m.helpers)
        .where((h) => h.userId == 'g' && h.rewarded)
        .length;
    expect(rewarded, cfg.mission.helpRewardsPerDay);
  });

  test('보상 지급(저장)이 실패하면 수령 기록을 되돌리고 코인도 안 준다', () async {
    await start('a', wait: 600); // ×0.8 혼자 성공
    await expectLater(
      a.claimAll('a', deliver: (_) async => throw StateError('db')),
      throwsStateError,
    );
    expect(store.claims, isEmpty);
    expect(guilds.memberRows['a']!.coins, 0);
    final r = await a.claimAll('a');
    expect(r.missions, 1, reason: '다시 받을 수 있다');
  });

  test('진행 중 미션에 돕는 길드원(닉네임·보탠 전투력)과 출발자 전투력이 실린다', () async {
    final id = activeId(await start('a', slot: 4, power: 120)); // 요구 420
    await a.help('b', id, power: 77, stage: 1, nickname: '비');
    final (_, body) = await a.view('c');
    final m = (body['active'] as List).single as Map;
    expect(m['ownerPower'], 120);
    expect(m['ownerNick'], 'a');
    final hs = (m['helpers'] as List).cast<Map>();
    expect(hs.single['nickname'], '비');
    expect(hs.single['power'], 77);
  });

  test(
    '예상 보상(core_run guildMissionExpected) = 실제 지급 — 출발자·도우미 · 대기 배율',
    () async {
      final id = activeId(await start('a', slot: 4, wait: 600, stage: 300));
      for (final u in ['b', 'c', 'd']) {
        await a.help(u, id, power: 1, stage: 500, nickname: u); // 3명 = 성공
      }
      final owner = await a.claimAll('a');
      final wantOwner = guildMissionExpected(
        cfg.mission,
        run,
        stage: 300,
        mult: cfg.mission.boardMults[4],
        waitSec: 600,
      );
      expect(owner.reward.toJson(), wantOwner.toJson());
      final helper = await a.claimAll('b');
      final wantHelper = guildMissionExpected(
        cfg.mission,
        run,
        stage: 500,
        mult: cfg.mission.boardMults[4],
        waitSec: 600,
        helper: true,
      );
      expect(helper.reward.toJson(), wantHelper.toJson());
    },
  );
}
