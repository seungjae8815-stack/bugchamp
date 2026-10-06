import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:server/src/guild_actions.dart';
import 'package:server/src/guild_store.dart';
import 'package:test/test.dart';

void main() {
  late DateTime t;
  late MemoryGuildStore store;
  late GuildActions g;

  setUp(() {
    t = DateTime.utc(2026, 10, 5, 12);
    store = MemoryGuildStore(clock: () => t);
    g = GuildActions(
      store: store,
      config: const GuildConfig(maxMembers: 3, deputyMax: 1),
      rules: const ChatRules(bannedWords: ['badword'], reservedNames: ['운영자']),
      now: () => t,
    );
  });

  Future<String> create(
    String uid, {
    String name = '장수풍뎅이단',
    String mode = 'open',
  }) async {
    final (st, body) = await g.create(
      uid,
      jelly: 500,
      name: name,
      joinMode: mode,
    );
    expect(st, 200, reason: '$body');
    return (body['guild'] as Map)['id'] as String;
  }

  group('만들기', () {
    test('젤리가 개설 비용(500)보다 적으면 못 만든다', () async {
      final (st, body) = await g.create('a', jelly: 499, name: '길드');
      expect(st, 409);
      expect(body['error'], 'insufficient_jelly');
      expect(body['cost'], 500);
      expect(store.guilds, isEmpty);
    });

    test('이름 규칙 — 길이·금칙어·운영자 사칭·깨진 문자', () async {
      for (final bad in ['a', '가나다라마바사아자차카타파', 'badword단', '운영자길드', 'ㅃㅃㅃ']) {
        final (st, body) = await g.create('a', jelly: 500, name: bad);
        expect(st, 400, reason: bad);
        expect(body['error'], 'name_invalid');
      }
    });

    test('이름은 대소문자를 무시하고 겹치면 안 된다', () async {
      await create('a', name: 'Beetle');
      final (st, body) = await g.create('b', jelly: 500, name: 'beetle');
      expect(st, 409);
      expect(body['error'], 'name_taken');
    });

    test('만든 사람이 길드장이다 · 이미 길드가 있으면 못 만든다', () async {
      await create('a');
      expect(store.memberRows['a']!.role, GuildRole.leader);
      final (st, _) = await g.create('a', jelly: 500, name: '두번째');
      expect(st, 409);
    });
  });

  group('문장', () {
    test('만들 때 고른 문장(1~10)이 응답·목록에 실린다 · 안 고르면 null', () async {
      final (st, body) = await g.create(
        'a',
        jelly: 500,
        name: '문장길드',
        emblem: 7,
      );
      expect(st, 200);
      expect((body['guild'] as Map)['emblem'], 7);
      final id = await create('b', name: '기본길드');
      expect(store.guilds[id]!.emblem, isNull);
      final (_, list) = await g.list('c', lang: 'ko');
      final rows = (list['guilds'] as List).cast<Map>();
      expect(rows.firstWhere((r) => r['name'] == '문장길드')['emblem'], 7);
      expect(rows.firstWhere((r) => r['name'] == '기본길드')['emblem'], isNull);
    });

    test('범위 밖 문장은 400 · 길드도 젤리 확인도 하기 전에 거른다', () async {
      for (final bad in [0, 11, -1]) {
        final (st, body) = await g.create(
          'a',
          jelly: 500,
          name: '문장길드',
          emblem: bad,
        );
        expect(st, 400, reason: '$bad');
        expect(body['error'], 'emblem_invalid');
      }
      expect(store.guilds, isEmpty);
    });

    test('문장 바꾸기 — 길드장만 · 범위 검사', () async {
      final id = await create('a');
      await g.join('b', id);
      expect((await g.settings('b', emblem: 3)).$1, 403);
      final (bad, badBody) = await g.settings('a', emblem: 11);
      expect(bad, 400);
      expect(badBody['error'], 'emblem_invalid');
      expect(store.guilds[id]!.emblem, isNull);
      final (st, body) = await g.settings('a', emblem: 3);
      expect(st, 200);
      expect((body['guild'] as Map)['emblem'], 3);
      // 다른 설정만 바꿔도 문장은 그대로.
      await g.settings('a', notice: '안녕');
      expect(store.guilds[id]!.emblem, 3);
    });
  });

  group('가입', () {
    test('공개 길드는 바로 들어가고, 가득 차면 막힌다', () async {
      final id = await create('a');
      expect((await g.join('b', id)).$1, 200);
      expect((await g.join('c', id)).$1, 200);
      final (st, body) = await g.join('d', id);
      expect(st, 409);
      expect(body['error'], 'guild_full');
    });

    test('승인제는 신청만 넣고, 길드장이 수락하면 들어온다', () async {
      final id = await create('a', mode: 'approval');
      final (st, body) = await g.join('b', id);
      expect(st, 200);
      expect(body['requested'], true);
      expect(store.memberRows.containsKey('b'), isFalse);

      final (_, meA) = await g.me('a');
      expect((meA['requests'] as List).single['userId'], 'b');

      expect((await g.answerRequest('a', 'b', accept: true)).$1, 200);
      expect(store.memberRows['b']!.guildId, id);
      expect(store.requests, isEmpty);
    });

    test('멤버는 신청을 받을 수 없다', () async {
      final id = await create('a', mode: 'approval');
      await store.insertMember(id, 'b', GuildRole.member);
      await g.join('c', id);
      final (st, _) = await g.answerRequest('b', 'c', accept: true);
      expect(st, 403);
    });

    test('신청은 한 사람당 상한이 있다', () async {
      final g2 = GuildActions(
        store: store,
        config: const GuildConfig(maxPendingRequests: 2),
        rules: const ChatRules(),
        now: () => t,
      );
      final ids = [
        for (final (i, u) in ['a', 'b', 'c'].indexed)
          await create(u, name: '길드$i', mode: 'approval'),
      ];
      expect((await g2.join('z', ids[0])).$1, 200);
      expect((await g2.join('z', ids[1])).$1, 200);
      final (st, body) = await g2.join('z', ids[2]);
      expect(st, 409);
      expect(body['error'], 'too_many_requests');
    });

    test('가입하면 다른 길드에 넣어 둔 신청이 지워진다', () async {
      final ap = await create('a', name: '승인길드', mode: 'approval');
      final op = await create('b', name: '공개길드');
      await g.join('z', ap);
      await g.join('z', op);
      expect(store.requests, isEmpty);
    });
  });

  group('탈퇴 · 재가입 제한', () {
    test('스스로 나가면 24시간 동안 다른 길드에 못 들어간다', () async {
      final id = await create('a');
      final other = await create('b', name: '다른길드');
      await g.join('c', id);
      final (st, body) = await g.leave('c');
      expect(st, 200);
      expect(body['cooldownUntil'], isNotNull);

      final (st2, b2) = await g.join('c', other);
      expect(st2, 409);
      expect(b2['error'], 'cooldown');

      t = t.add(const Duration(hours: 24, minutes: 1));
      expect((await g.join('c', other)).$1, 200);
    });

    test('추방당한 쪽은 재가입 제한이 없다', () async {
      final id = await create('a');
      final other = await create('b', name: '다른길드');
      await g.join('c', id);
      expect((await g.kick('a', 'c')).$1, 200);
      expect((await g.join('c', other)).$1, 200);
    });

    test('길드장이 나가면 부길드장에게 넘어가고, 마지막 한 명이면 길드가 없어진다', () async {
      final id = await create('a');
      await g.join('b', id);
      await g.join('c', id);
      await g.setRole('a', 'c', 'deputy');
      await g.leave('a');
      expect(store.memberRows['c']!.role, GuildRole.leader);
      expect(store.guilds[id]!.leader, 'c');

      await g.leave('b');
      await g.leave('c');
      expect(store.guilds.containsKey(id), isFalse);
    });
  });

  group('직책', () {
    test('추방은 길드장만 — 부길드장은 멤버도 못 내보낸다(2026-10-05)', () async {
      final id = await create('a');
      await g.join('b', id);
      await g.join('c', id);
      await g.setRole('a', 'b', 'deputy');
      expect((await g.kick('b', 'a')).$1, 403);
      final (st, body) = await g.kick('b', 'c');
      expect(st, 403);
      expect(body['error'], 'forbidden');
      expect((await g.kick('c', 'b')).$1, 403, reason: '멤버');
      expect((await g.kick('a', 'b')).$1, 200, reason: '길드장 → 부길드장');
      expect((await g.kick('a', 'c')).$1, 200, reason: '길드장 → 멤버');
    });

    test('설정·임명은 길드장만 — 부길드장 403', () async {
      final id = await create('a');
      await g.join('b', id);
      await g.join('c', id);
      await g.setRole('a', 'b', 'deputy');
      expect((await g.settings('b', notice: '안녕')).$1, 403);
      expect((await g.settings('b', joinMode: 'approval')).$1, 403);
      expect((await g.settings('b', deputyCanAccept: false)).$1, 403);
      expect((await g.setRole('b', 'c', 'deputy')).$1, 403);
      expect((await g.settings('a', notice: '안녕')).$1, 200);
      expect(store.guilds[id]!.notice, '안녕');
    });

    test('부길드장 가입 수락 — 길드장 스위치(기본 켜짐)를 따른다', () async {
      final id = await create('a', mode: 'approval');
      await store.insertMember(id, 'b', GuildRole.deputy);
      await g.join('c', id);
      await g.join('d', id);

      // 기본 켜짐 — 응답에 스위치 값과 신청 목록이 실린다.
      final (_, meB) = await g.me('b');
      expect((meB['guild'] as Map)['deputyCanAccept'], isTrue);
      expect(meB['requests'], isNotNull);

      // 길드장이 끈다 → 부길드장 수락·거절 403, 신청 목록도 안 실린다.
      final (st, body) = await g.settings('a', deputyCanAccept: false);
      expect(st, 200);
      expect((body['guild'] as Map)['deputyCanAccept'], isFalse);
      expect((await g.answerRequest('b', 'c', accept: true)).$1, 403);
      expect((await g.answerRequest('b', 'c', accept: false)).$1, 403);
      expect((await g.me('b')).$2['requests'], isNull);
      expect(store.memberRows.containsKey('c'), isFalse);

      // 다시 켠다 → 200.
      await g.settings('a', deputyCanAccept: true);
      expect((await g.answerRequest('b', 'c', accept: true)).$1, 200);
      expect(store.memberRows['c']!.guildId, id);
      // 길드장은 스위치와 상관없이 늘 된다.
      await g.settings('a', deputyCanAccept: false);
      expect((await g.answerRequest('a', 'd', accept: false)).$1, 200);
    });

    test('부길드장 수에는 상한이 있다', () async {
      final id = await create('a');
      await g.join('b', id);
      await g.join('c', id);
      expect((await g.setRole('a', 'b', 'deputy')).$1, 200);
      final (st, body) = await g.setRole('a', 'c', 'deputy');
      expect(st, 409);
      expect(body['error'], 'deputy_full');
    });

    test('길드장 위임 — 원래 길드장은 자리가 있으면 부길드장이 된다', () async {
      final id = await create('a');
      await g.join('b', id);
      expect((await g.setRole('a', 'b', 'leader')).$1, 200);
      expect(store.memberRows['b']!.role, GuildRole.leader);
      expect(store.memberRows['a']!.role, GuildRole.deputy);
      expect(store.guilds[id]!.leader, 'b');
    });

    test('길드장이 7일 동안 안 들어오면 최근에 들어온 부길드장에게 넘어간다', () async {
      final id = await create('a');
      await g.join('b', id);
      await g.join('c', id);
      await g.setRole('a', 'c', 'deputy');
      store.setLastSeen('a', t.subtract(const Duration(days: 8)));
      final (_, body) = await g.me('b');
      expect(store.memberRows['c']!.role, GuildRole.leader);
      expect(store.memberRows['a']!.role, GuildRole.member);
      expect(store.guilds[id]!.leader, 'c');
      expect(body['myRole'], 'member');
    });

    test('소개 글 — 금칙어·길이 검사', () async {
      await create('a');
      expect((await g.settings('a', notice: 'badword')).$1, 400);
      expect((await g.settings('a', notice: 'x' * 81)).$1, 400);
      final (st, body) = await g.settings(
        'a',
        notice: '매일 접속해요',
        joinMode: 'approval',
      );
      expect(st, 200);
      expect((body['guild'] as Map)['notice'], '매일 접속해요');
      expect((body['guild'] as Map)['joinMode'], 'approval');
    });
  });

  group('3단계 — 레벨 · 출석 · 스킬 · 상점', () {
    late GuildActions g3;
    const cfg3 = GuildConfig(
      maxMembers: 20,
      level: GuildLevelConfig(expBase: 100, expGrowth: 1.0),
      skills: [
        GuildSkillDef(id: 'attack', stat: 'attack', perLevel: 0.016, max: 5),
        GuildSkillDef(id: 'gold', stat: 'gold', perLevel: 0.02, max: 5),
      ],
      shop: [
        GuildShopItem(
          id: 'fossil',
          kind: 'fossil',
          amount: 20,
          cost: 30,
          limit: 2,
        ),
      ],
    );
    setUp(() {
      g3 = GuildActions(
        store: store,
        config: cfg3,
        rules: const ChatRules(),
        now: () => t,
      );
    });

    Future<String> make() async {
      final (_, b) = await g3.create('a', jelly: 500, name: '레벨길드');
      return (b['guild'] as Map)['id'] as String;
    }

    test('출석은 하루 한 번 — 코인과 길드 경험치', () async {
      final id = await make();
      final (st, body) = await g3.donate('a');
      expect(st, 200);
      expect(body['myCoins'], cfg3.donateCoins);
      expect(body['donatedToday'], true);
      expect(store.guilds[id]!.exp, cfg3.donateExp);
      expect((await g3.donate('a')).$2['error'], 'already_donated');
      t = t.add(const Duration(days: 1));
      expect((await g3.donate('a')).$1, 200);
    });

    test('출석은 유저 기준 — 다른 길드로 옮겨도 같은 날엔 다시 못 한다', () async {
      await make();
      expect((await g3.donate('a')).$1, 200);
      await store.deleteMember('a');
      final (_, b2) = await g3.create('a', jelly: 500, name: '두번째길드');
      expect(b2['guild'], isNotNull);
      final (_, me) = await g3.me('a');
      expect(me['donatedToday'], true, reason: '화면도 출석함으로');
      expect((await g3.donate('a')).$2['error'], 'already_donated');
      expect(store.memberRows['a']!.coins, 0);
      t = t.add(const Duration(days: 1));
      expect((await g3.donate('a')).$1, 200);
    });

    test('상점 — 지급(저장)이 실패하면 코인·구매 수를 되돌린다', () async {
      await make();
      await store.addCoins('a', 100);
      await expectLater(
        g3.buy('a', 'fossil', deliver: (_) async => throw StateError('db')),
        throwsStateError,
      );
      expect(store.memberRows['a']!.coins, 100);
      expect((await g3.buy('a', 'fossil')).$1, 200);
      expect((await g3.buy('a', 'fossil')).$1, 200, reason: '한도 2 그대로');
      expect((await g3.buy('a', 'fossil')).$2['error'], 'shop_limit');
    });

    test('경험치로 레벨이 오르면 인원과 스킬 포인트가 는다', () async {
      final id = await make();
      await g3.addExp(id, 250); // 100씩 → 3레벨
      expect(store.guilds[id]!.level, 3);
      expect(store.guilds[id]!.maxMembers, 22);
      final (_, body) = await g3.me('a');
      expect((body['guild'] as Map)['pointsLeft'], 2);
    });

    test('스킬은 포인트만큼 · 길드장만 · 최대 단계까지 · 초기화는 길드장만', () async {
      final id = await make();
      await store.insertMember(id, 'b', GuildRole.member);
      expect((await g3.skillUp('a', 'attack')).$2['error'], 'no_points');
      await g3.addExp(id, 200); // 3레벨 = 2포인트
      expect((await g3.skillUp('b', 'attack')).$1, 403);
      // 부길드장도 스킬을 못 찍는다(2026-10-05 — 길드장만).
      await store.insertMember(id, 'd', GuildRole.deputy);
      expect((await g3.skillUp('d', 'attack')).$1, 403);
      expect((await g3.skillReset('d')).$1, 403);
      expect((await g3.skillUp('a', 'attack')).$1, 200);
      expect((await g3.skillUp('a', 'gold')).$1, 200);
      expect((await g3.skillUp('a', 'gold')).$2['error'], 'no_points');
      expect(store.guilds[id]!.skills, {'attack': 1, 'gold': 1});
      expect((await g3.skillReset('b')).$1, 403);
      await g3.skillReset('a');
      expect(store.guilds[id]!.skills, isEmpty);
    });

    test('상점 — 코인이 모자라면 못 사고, 기간 한도가 있다', () async {
      await make();
      expect((await g3.buy('a', 'fossil')).$2['error'], 'not_enough_coins');
      await store.addCoins('a', 100);
      expect((await g3.buy('a', 'fossil')).$1, 200);
      expect((await g3.buy('a', 'fossil')).$1, 200);
      expect((await g3.buy('a', 'fossil')).$2['error'], 'shop_limit');
      expect(store.memberRows['a']!.coins, 40);
      t = t.add(const Duration(days: 1));
      expect((await g3.buy('a', 'fossil')).$1, 200, reason: '다음 날 다시');
    });

    test('출석 표 — 출석한 날만 한 칸씩(연속 아님) · 7일차 큰 보상 · 35칸 뒤 1일차', () async {
      const cfgA = GuildConfig(
        attend: GuildAttendConfig(
          cycleDays: 35,
          bonuses: [
            GuildAttendBonus(day: 7, coins: 50, fossil: 10),
            GuildAttendBonus(day: 35, coins: 120, fossil: 30, fairyDust: 50),
          ],
        ),
      );
      final ga = GuildActions(
        store: store,
        config: cfgA,
        rules: const ChatRules(),
        now: () => t,
      );
      await ga.create('a', jelly: 500, name: '출석길드');
      final delivered = <GuildAttendBonus>[];
      Future<GuildResult> attend() =>
          ga.donate('a', deliver: (b) async => delivered.add(b));
      for (var d = 1; d <= 6; d++) {
        final (st, body) = await attend();
        expect(st, 200);
        expect((body['attend'] as Map)['day'], d);
        expect(body['attendCount'], d);
        // 이틀씩 건너뛰어도(연속 아님) 다음 칸으로 이어진다.
        t = t.add(Duration(days: d.isEven ? 3 : 1));
      }
      expect(delivered, isEmpty, reason: '큰 보상 전에는 세이브를 건드리지 않는다');
      final coins6 = store.memberRows['a']!.coins;
      expect(coins6, 6 * cfgA.donateCoins);
      final (_, b7) = await attend();
      expect((b7['attend'] as Map)['day'], 7);
      expect((b7['attend'] as Map)['coins'], cfgA.donateCoins + 50);
      expect((b7['attend'] as Map)['fossil'], 10);
      expect(store.memberRows['a']!.coins, coins6 + cfgA.donateCoins + 50);
      expect(delivered.single.day, 7);
      // 35일차까지 채운 뒤 다음은 1일차.
      for (var d = 8; d <= 35; d++) {
        t = t.add(const Duration(days: 1));
        await attend();
      }
      expect(store.memberRows['a']!.attendCount, 35);
      expect(delivered.last.day, 35);
      t = t.add(const Duration(days: 1));
      final (_, b36) = await attend();
      expect((b36['attend'] as Map)['day'], 1, reason: '다 채우면 1일차로');
    });

    test('출석 표 — 길드를 옮기면 처음부터 · 큰 보상 저장이 실패하면 출석을 되돌린다', () async {
      const cfgA = GuildConfig(
        attend: GuildAttendConfig(
          cycleDays: 3,
          bonuses: [GuildAttendBonus(day: 2, coins: 7, fairyDust: 30)],
        ),
      );
      final ga = GuildActions(
        store: store,
        config: cfgA,
        rules: const ChatRules(),
        now: () => t,
      );
      await ga.create('a', jelly: 500, name: '옮기기길드');
      expect((await ga.donate('a')).$1, 200);
      t = t.add(const Duration(days: 1));
      // 2일차 = 큰 보상 — 지급 저장 실패 → 출석이 통째로 되돌아간다(다시 누를 수 있다).
      await expectLater(
        ga.donate('a', deliver: (_) async => throw StateError('db')),
        throwsStateError,
      );
      expect(store.memberRows['a']!.attendCount, 1);
      expect(store.memberRows['a']!.coins, cfgA.donateCoins);
      final (st, again) = await ga.donate('a', deliver: (_) async {});
      expect(st, 200);
      expect((again['attend'] as Map)['day'], 2);
      expect((again['attend'] as Map)['fairyDust'], 30);
      // 탈퇴 → 다른 길드: 출석 표가 1일차부터.
      await ga.leave('a');
      t = t.add(const Duration(days: 2));
      await ga.create('a', jelly: 500, name: '새길드');
      final (_, fresh) = await ga.donate('a');
      expect((fresh['attend'] as Map)['day'], 1);
      expect(fresh['attendCount'], 1);
    });
  });

  group('길드원 정보 · 모집 목록', () {
    test('길드원 정보는 같은 길드만 — 다른 길드·길드 없음은 403', () async {
      final id = await create('a');
      await g.join('b', id);
      store.profiles['b'] = (nickname: '비', power: 1234);
      final (st, body) = await g.member('a', 'b');
      expect(st, 200);
      final m = body['member'] as Map;
      expect(m['nickname'], '비');
      expect(m['power'], 1234);
      expect(m['role'], 'member');
      expect(m['rank'], 'rookie');
      // 다른 길드 사람.
      final other = await create('c', name: '다른길드');
      expect(other, isNot(id));
      expect((await g.member('a', 'c')).$1, 403);
      expect((await g.member('c', 'b')).$1, 403);
      // 길드 없는 사람을 보거나, 길드 없는 사람이 보면.
      expect((await g.member('a', 'nobody')).$1, 403);
      expect((await g.member('nobody', 'a')).$2['error'], 'not_in_guild');
    });

    test('검색어가 없으면 자리가 남은 길드만(모집 중) · 검색하면 꽉 찬 길드도', () async {
      final full = await create('a', name: '만원길드');
      await g.join('b', full);
      await g.join('c', full); // maxMembers 3 → 가득
      await create('d', name: '빈자리길드', mode: 'approval');
      final (_, list) = await g.list('x');
      final names = [
        for (final r in list['guilds'] as List) (r as Map)['name'],
      ];
      expect(names, ['빈자리길드'], reason: '승인제도 모집 중');
      final (_, found) = await g.list('x', query: '만원');
      expect(
        [for (final r in found['guilds'] as List) (r as Map)['name']],
        ['만원길드'],
      );
    });
  });
}
