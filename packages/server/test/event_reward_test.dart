import 'package:core_models/core_models.dart';
import 'package:core_save/core_save.dart';
import 'package:server/src/actions.dart';
import 'package:test/test.dart';

import 'event_test.dart' show buildEventCfg;

/// 회차 종료 보상의 **서버 계약**. 여기가 재화를 만드는 경로다.
///
/// 특히 두 가지를 못 박는다:
///  1. 진행 중인 회차에는 주지 않는다.
///  2. 같은 회차를 두 번 주지 않는다(`eventRewardRound`).
void main() {
  final cfg = buildEventCfg();
  final ev = cfg.event!;
  final open = ev.startsAt!.add(const Duration(hours: 12));
  final closed = ev.endsAt!.add(const Duration(hours: 1));

  GameActions at(DateTime t) => GameActions(config: cfg, now: () => t);
  String roundOf(DateTime t) => at(t).eventRoundId();

  SaveGame played(DateTime t, {String? round, String? rewarded}) =>
      SaveGame.initial(createdAt: open).copyWith(
        eventRoundId: round ?? roundOf(t),
        eventBestScore: 1234,
        eventRewardRound: rewarded,
      );

  group('언제 주는가', () {
    test('회차가 진행 중이면 주지 않는다', () {
      final a = at(open);
      expect(a.eventRewardDueRound(played(open)), isNull);
    });

    test('회차가 끝나면 준다', () {
      final a = at(closed);
      expect(a.eventRewardDueRound(played(closed)), roundOf(closed));
    });

    test('이미 받은 회차는 다시 주지 않는다', () {
      final a = at(closed);
      final round = roundOf(closed);
      expect(a.eventRewardDueRound(played(closed, rewarded: round)), isNull);
    });

    test('한 판도 안 뛰었으면 줄 것이 없다', () {
      final a = at(closed);
      expect(a.eventRewardDueRound(SaveGame.initial(createdAt: open)), isNull);
    });

    /// ⚠️ 다음 회차를 열면 config 의 회차 id 가 바뀐다. 기준을 config 로 잡으면
    /// 그 사이 접속하지 않은 사람의 지난 회차 보상이 통째로 증발한다.
    test('다음 회차가 열려 있어도 지난 회차 기록이면 그 회차로 준다', () {
      final a = at(open);
      final due = a.eventRewardDueRound(played(open, round: '2020-0101'));
      expect(due, '2020-0101');
    });
  });

  group('무엇을 주는가', () {
    final a = at(closed);
    final round = roundOf(closed);

    test('1위는 최상위 구간 젤리 + 참가 보상을 받는다', () {
      final save = played(closed);
      final before = save.materialCount(MaterialKind.jelly);
      final r = a.grantEventReward(save, round, 1);
      expect(r.isOk, isTrue);
      final tier = ev.tierForRank(1)!;
      expect(r.save!.materialCount(MaterialKind.jelly), before + tier.jelly);
      for (final e in ev.participationMaterials.entries) {
        expect(r.save!.materialCount(e.key), greaterThanOrEqualTo(e.value));
      }
      expect((r.extra['eventReward'] as Map)['physical'], isTrue);
    });

    test('순위가 없어도(익명·순위권 밖) 참가 보상은 받는다', () {
      final r = a.grantEventReward(played(closed), round, null);
      expect(r.isOk, isTrue);
      // 젤리는 0 이어야 한다 — 참가는 회차마다 반복되는 통로다(§2.6).
      expect(r.save!.materialCount(MaterialKind.jelly), 0);
      expect(
        r.save!.materialCount(ev.participationMaterials.keys.first),
        ev.participationMaterials.values.first,
      );
      expect((r.extra['eventReward'] as Map)['physical'], isFalse);
    });

    test('순위권 밖(101위)은 구간이 없다 — 참가 보상만', () {
      final r = a.grantEventReward(played(closed), round, 101);
      expect(r.save!.materialCount(MaterialKind.jelly), 0);
    });

    test('지급하면 회차가 찍혀 두 번째 판정에서 걸러진다', () {
      final r = a.grantEventReward(played(closed), round, 5);
      expect(r.save!.eventRewardRound, round);
      expect(a.eventRewardDueRound(r.save!), isNull);
    });
  });

  group('회차 뱃지', () {
    final a = at(closed);
    final round = roundOf(closed);

    test('1위는 챔피언 뱃지를 받는다', () {
      final r = a.grantEventReward(played(closed), round, 1);
      expect(r.save!.eventBadges, contains('champion:${ev.roundNo}'));
      expect(
        (r.extra['eventReward'] as Map)['badge'],
        'champion:${ev.roundNo}',
      );
    });

    test('순위권 밖은 뱃지가 없다', () {
      final r = a.grantEventReward(played(closed), round, 101);
      expect(r.save!.eventBadges, isEmpty);
      expect((r.extra['eventReward'] as Map).containsKey('badge'), isFalse);
    });

    test('지난 회차 뱃지는 남는다 (누적)', () {
      final old = played(closed).copyWith(eventBadges: {'champion:0'});
      final r = a.grantEventReward(old, round, 1);
      expect(
        r.save!.eventBadges,
        containsAll(['champion:0', 'champion:${ev.roundNo}']),
      );
    });

    /// 세이브를 고쳐 챔피언을 달 수 있으면 표식의 값어치가 통째로 사라진다.
    test('eventBadges 는 서버 소유 필드다', () {
      final server = a.grantEventReward(played(closed), round, 50).save!;
      final forged = server.toJson()
        ..['eventBadges'] = ['champion:${ev.roundNo}'];
      final merged = a.mergeSave(server, forged);
      expect(merged.save!.eventBadges, isEmpty);
    });
  });

  /// 세이브를 고쳐 수령 기록을 지우면 같은 회차를 반복해서 받을 수 있다.
  test('eventRewardRound 는 서버 소유 필드다', () {
    final a = at(closed);
    final round = roundOf(closed);
    final server = a.grantEventReward(played(closed), round, 1).save!;
    // 클라이언트가 수령 기록을 지운 세이브를 올린다.
    final forged = server.toJson()..remove('eventRewardRound');
    final merged = a.mergeSave(server, forged);
    expect(merged.save!.eventRewardRound, round, reason: '서버 값으로 되돌아와야 한다');
  });
}
