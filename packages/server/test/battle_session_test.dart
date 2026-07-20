import 'dart:convert';

import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';
import 'package:server/src/battle_session.dart';
import 'package:test/test.dart';

BattleBug bug(String id, {double atk = 30, Element el = Element.wood}) =>
    BattleBug(
      id: id,
      name: id,
      element: el,
      temperament: Temperament.aggressive,
      preferredStance: Stance.attack,
      maxHp: 200,
      atk: atk,
      def: 20,
      spd: 15,
    );

BattleSession session({List<Stance> stances = const []}) => BattleSession(
  id: 's1',
  userId: 'u1',
  seed: 12345,
  myTeamBugIds: const ['mine'],
  foe: [bug('foe', el: Element.fire)],
  location: Element.wood,
  rewardMult: 1.0,
  stances: stances,
  finished: false,
);

void main() {
  final myTeam = [bug('mine')];

  group('세션 재생', () {
    test('수를 두지 않았으면 아직 아무 라운드도 진행되지 않았다', () {
      final st = replay(session(), myTeam, locationBonus: 0.2);
      expect(st.round, 0);
      expect(st.done, isFalse);
    });

    test('같은 수 목록이면 항상 같은 상태 (결정론)', () {
      const moves = [Stance.attack, Stance.defend, Stance.attack];
      final a = replay(session(stances: moves), myTeam, locationBonus: 0.2);
      final b = replay(session(stances: moves), myTeam, locationBonus: 0.2);
      expect(a.round, b.round);
      expect(a.hpA.first, b.hpA.first);
      expect(a.hpB.first, b.hpB.first);
    });

    test('다른 수를 두면 다른 상태가 된다 (선택이 실제로 반영됨)', () {
      final allAttack = replay(
        session(stances: const [Stance.attack, Stance.attack]),
        myTeam,
        locationBonus: 0.2,
      );
      final allDefend = replay(
        session(stances: const [Stance.defend, Stance.defend]),
        myTeam,
        locationBonus: 0.2,
      );
      expect(allAttack.hpB.first, isNot(allDefend.hpB.first));
    });

    test('수를 더 둘수록 라운드가 진행된다', () {
      final one = replay(
        session(stances: const [Stance.attack]),
        myTeam,
        locationBonus: 0.2,
      );
      final three = replay(
        session(stances: const [Stance.attack, Stance.attack, Stance.attack]),
        myTeam,
        locationBonus: 0.2,
      );
      expect(three.round, greaterThan(one.round));
    });
  });

  group('직렬화', () {
    test('왕복해도 값이 보존된다', () {
      final s = session(stances: const [Stance.attack, Stance.heal]);
      final back = BattleSession.fromJson(
        's1',
        'u1',
        jsonDecode(s.encode()) as Map<String, dynamic>,
      );
      expect(back.seed, s.seed);
      expect(back.stances, s.stances);
      expect(back.foe.first.atk, s.foe.first.atk);
      expect(back.location, s.location);
      expect(back.finished, isFalse);
    });

    test('상대 스탯이 그대로 복원된다 (클라가 못 바꾼다)', () {
      final s = BattleSession(
        id: 's',
        userId: 'u',
        seed: 1,
        myTeamBugIds: const ['m'],
        foe: [bug('f', atk: 9999)],
        location: Element.wood,
        rewardMult: 1.0,
        stances: const [],
        finished: false,
      );
      final back = BattleSession.fromJson(
        's',
        'u',
        jsonDecode(s.encode()) as Map<String, dynamic>,
      );
      expect(back.foe.first.atk, 9999);
    });
  });
}
