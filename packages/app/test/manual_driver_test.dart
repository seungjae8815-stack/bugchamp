import 'package:app/domain/game_server.dart';
import 'package:app/features/battle/manual_driver.dart';
import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// 대본대로 응답하는 가짜 서버.
class _ScriptedServer extends NoGameServer {
  _ScriptedServer(this.replies);

  final List<ServerResult> replies;
  final List<String> sent = [];

  @override
  bool get available => true;

  @override
  Future<ServerResult> stepManualBattle({
    required String sessionId,
    required String stance,
  }) async {
    sent.add(stance);
    return replies.isEmpty
        ? const ServerResult.fail('drained', 0)
        : replies.removeAt(0);
  }
}

Map<String, dynamic> _event({
  double dmgToB = 12,
  bool bDown = false,
  double aHp = 100,
  double bHp = 88,
}) => {
  'round': 1,
  'aName': '내벌레',
  'bName': '상대벌레',
  'aStance': 'attack',
  'bStance': 'defend',
  'rps': 0,
  'dmgToA': 0.0,
  'dmgToB': dmgToB,
  'healToA': 3.0,
  'healToB': 0.0,
  'aHp': aHp,
  'bHp': bHp,
  'aDown': false,
  'bDown': bDown,
};

void main() {
  ServerManualDriver driverWith(List<ServerResult> replies) =>
      ServerManualDriver(
        server: _ScriptedServer(replies),
        sessionId: 's1',
        startEnergy: 1,
      );

  test('서버가 준 이벤트를 그대로 복원한다 — 연출이 로컬과 같아야 한다', () async {
    final d = driverWith([
      ServerResult.ok({
        'round': 1,
        'done': false,
        'energyA': 2,
        'event': _event(),
      }),
    ]);
    final step = await d.step(Stance.attack);

    expect(step, isNotNull);
    expect(step!.event.aStance, Stance.attack);
    expect(step.event.bStance, Stance.defend);
    expect(step.event.dmgToB, 12);
    expect(step.event.healToA, 3);
    expect(step.event.aHp, 100);
    expect(step.event.bHp, 88);
    expect(step.energyA, 2);
    expect(d.done, isFalse);
  });

  test('서버가 거부하면 null — 로컬로 대신 계산하지 않는다', () async {
    final d = driverWith([const ServerResult.fail('forbidden', 403)]);
    expect(await d.step(Stance.attack), isNull);
    expect(d.done, isFalse);
  });

  test('결착하면 서버가 확정한 보상이 실려오고, 다시 지급하지 않는다', () async {
    final d = driverWith([
      ServerResult.ok({
        'round': 3,
        'done': true,
        'energyA': 0,
        'event': _event(bDown: true, bHp: 0),
        'outcome': 'teamA',
        'teamAHpPct': 0.62,
        'teamBHpPct': 0.0,
        'gold': 250,
        'trophyDelta': 18,
        'save': {'gold': 999},
      }),
    ]);
    final step = await d.step(Stance.attack);
    expect(step!.done, isTrue);

    final f = await d.finish();
    expect(f, isNotNull);
    expect(f!.result.outcome, BattleOutcome.teamA);
    expect(f.result.teamAHpPct, 0.62);
    expect(f.gold, 250);
    expect(f.trophyDelta, 18);
    // 서버가 이미 지급했다 — 화면이 또 주면 두 배가 된다.
    expect(f.rewardsApplied, isTrue);
    expect(f.save, {'gold': 999});
  });

  test('결착 전에 finish 하면 승패를 지어내지 않는다', () async {
    final d = driverWith([
      ServerResult.ok({'round': 1, 'done': false, 'event': _event()}),
    ]);
    await d.step(Stance.attack);
    expect(await d.finish(), isNull);
  });

  test('이벤트가 누락된 응답은 진행으로 치지 않는다', () async {
    final d = driverWith([
      ServerResult.ok({'round': 1, 'done': false}),
    ]);
    expect(await d.step(Stance.attack), isNull);
  });

  test('모든 스탠스가 서버로 그대로 전달된다', () async {
    final server = _ScriptedServer([
      for (var i = 0; i < 3; i++)
        ServerResult.ok({'round': i + 1, 'done': false, 'event': _event()}),
    ]);
    final d = ServerManualDriver(
      server: server,
      sessionId: 's1',
      startEnergy: 1,
    );
    for (final s in [Stance.attack, Stance.defend, Stance.heal]) {
      await d.step(s);
    }
    expect(server.sent, ['attack', 'defend', 'heal']);
  });

  test('로컬 드라이버는 보상을 화면이 지급하게 둔다', () async {
    final team = [
      for (var i = 0; i < 3; i++)
        BattleBug(
          id: 'b$i',
          name: 'b$i',
          element: Element.wood,
          temperament: Temperament.aggressive,
          preferredStance: Stance.attack,
          maxHp: 100,
          atk: 20,
          def: 10,
          spd: 10,
        ),
    ];
    final d = LocalManualDriver(initBattle(7, team, team));
    final step = await d.step(Stance.attack);
    expect(step, isNotNull);
    expect(d.round, 1);

    final f = await d.finish();
    expect(f!.rewardsApplied, isFalse);
    expect(f.save, isNull);
  });

  group('서버 상대 복원', () {
    test('서버가 준 상대를 그대로 복원한다 — 앱이 따로 만들면 연출이 갈린다', () {
      final team = foeTeamFromServer([
        {
          'id': 'wild_0',
          'sp': 'stag',
          'name': '사슴벌레',
          'el': 'metal',
          'tm': 'cunning',
          'stance': 'defend',
          'hp': 240.5,
          'atk': 33.0,
          'def': 21.0,
          'spd': 14.0,
        },
      ]);
      expect(team, hasLength(1));
      final e = team.first;
      expect(e.speciesId, 'stag');
      expect(e.bug.id, 'wild_0');
      expect(e.bug.element, Element.metal);
      expect(e.bug.temperament, Temperament.cunning);
      expect(e.bug.preferredStance, Stance.defend);
      expect(e.bug.maxHp, 240.5);
      expect(e.bug.atk, 33.0);
    });

    test('상대가 없거나 형식이 아니면 빈 목록 — 호출부가 로컬 상대로 남는다', () {
      expect(foeTeamFromServer(null), isEmpty);
      expect(foeTeamFromServer('nonsense'), isEmpty);
      expect(foeTeamFromServer([]), isEmpty);
    });

    test('필드가 빠져도 터지지 않는다', () {
      final team = foeTeamFromServer([
        {'id': 'x'},
      ]);
      expect(team, hasLength(1));
      expect(team.first.bug.maxHp, greaterThan(0));
      expect(team.first.speciesId, '');
    });
  });
}
