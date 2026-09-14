import 'dart:convert';
import 'dart:io';

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:test/test.dart';

/// 회차 종료 보상의 **구조 규칙**을 검사한다(수치가 아니라 규칙 — 밸런싱은
/// JSON 을 고치는 일이므로 값을 못 박으면 테스트가 방해만 된다).
void main() {
  final cfg = EventConfig.fromJson(
    jsonDecode(File('../app/assets/data/event.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  test('순위 구간은 위에서부터 먼저 맞는 하나만 적용된다', () {
    expect(cfg.tierForRank(1)!.maxRank, 1);
    expect(cfg.tierForRank(2)!.maxRank, 3);
    expect(cfg.tierForRank(4)!.maxRank, 10);
  });

  /// 젤리는 **10위까지만** 나간다(2026-08-26). 그 아래는 참가 보상(재료)뿐이라
  /// 젤리가 넓게 퍼지지 않고, 상위권 경쟁에도 의미가 생긴다.
  test('순위권 밖·0 이하는 구간이 없다', () {
    expect(cfg.tierForRank(11), isNull);
    expect(cfg.tierForRank(0), isNull);
  });

  /// 실물은 1위 한 명뿐이다 — 그렇다고 2위가 1위보다 많이 받으면 안 된다.
  test('보상은 누적이다 (순위가 높은데 덜 받는 역전이 없다)', () {
    for (var r = 2; r <= 10; r++) {
      expect(
        cfg.tierForRank(r)!.jelly,
        lessThanOrEqualTo(cfg.tierForRank(r - 1)!.jelly),
      );
    }
  });

  test('구간은 순위가 낮아질수록 젤리가 줄어든다 (역전 금지)', () {
    for (var i = 1; i < cfg.rewardTiers.length; i++) {
      expect(
        cfg.rewardTiers[i].jelly,
        lessThanOrEqualTo(cfg.rewardTiers[i - 1].jelly),
        reason: '${cfg.rewardTiers[i].maxRank}위 구간이 더 많이 받는다',
      );
      expect(
        cfg.rewardTiers[i].maxRank,
        greaterThan(cfg.rewardTiers[i - 1].maxRank),
        reason: 'maxRank 는 오름차순이어야 먼저-맞는-구간 규칙이 성립한다',
      );
    }
  });

  /// §2.6 — 참가는 **회차마다 반복되는 통로**다. 젤리를 붙이면 대회를 여는
  /// 것만으로 프리미엄 재화가 전원에게 뿌려진다.
  test('참가 보상에는 젤리가 없다', () {
    expect(cfg.participationMaterials.containsKey(MaterialKind.jelly), isFalse);
    expect(cfg.participationMaterials, isNotEmpty);
  });

  group('회차 뱃지', () {
    final no = cfg.roundNo;

    /// 뱃지는 실물을 못 받는 해외 이용자에게 **등가를 맞추는 축**이다.
    /// 젤리로 맞추면 그 유저의 경제가 끝난다(§2.6).
    test('순위 뱃지는 상위 구간에만 붙는다', () {
      expect(cfg.badgeIdForRank(1, roundNo: no), isNotNull);
      expect(cfg.badgeIdForRank(10, roundNo: no), isNotNull);
      expect(
        cfg.badgeIdForRank(50, roundNo: no),
        isNull,
        reason: '흔하면 자랑거리가 아니다',
      );
      expect(cfg.badgeIdForRank(101, roundNo: no), isNull);
    });

    /// 1회차 챔피언과 3회차 챔피언은 **다른** 자랑거리다.
    test('id 에 회차 번호가 붙는다', () {
      expect(no, greaterThan(0), reason: 'event.json round.no 누락');
      expect(cfg.badgeIdForRank(1, roundNo: no), 'champion:$no');
      expect(
        cfg.badgeIdForRank(1, roundNo: no),
        isNot(cfg.badgeIdForRank(10, roundNo: no)),
      );
    });

    test('번호를 모르면(0) 뱃지를 주지 않는다 — `0회차 챔피언` 이 안 생긴다', () {
      expect(cfg.badgeIdForRank(1, roundNo: 0), isNull);
      expect(cfg.participantBadgeId(0), isNull);
      expect(cfg.badgeFor(null, roundNo: 0), isNull);
    });

    /// 순위 뱃지는 10명뿐이다. 나온 사람 전원에게 남는 표식이 있어야 한다.
    test('순위권 밖·익명은 참가 뱃지로 떨어진다', () {
      expect(cfg.participationBadge, isNotEmpty);
      expect(cfg.badgeFor(null, roundNo: no), 'participant:$no');
      expect(cfg.badgeFor(11, roundNo: no), 'participant:$no');
      expect(cfg.badgeFor(1, roundNo: no), 'champion:$no');
    });

    test('대표 뱃지는 급이 먼저, 같은 급이면 최근 회차', () {
      expect(bestEventBadge(['participant:2', 'champion:1']), 'champion:1');
      expect(bestEventBadge(['finalist:1', 'finalist:3']), 'finalist:3');
      expect(bestEventBadge(['participant:1', 'mystery:9']), 'participant:1');
      expect(bestEventBadge(const []), '');
    });
  });

  /// 다음 회차를 열어도 지난 회차의 번호를 잃지 않아야 한다 — 그 사이 접속하지
  /// 않은 입상자가 다음 회차 뱃지를 받는 일이 생긴다.
  group('회차 이력', () {
    test('지난 회차는 번호가 겹치지 않고 이번 회차보다 앞이다', () {
      final nos = {for (final r in cfg.pastRounds) r.no};
      expect(nos.length, cfg.pastRounds.length, reason: '회차 번호 중복');
      for (final r in cfg.pastRounds) {
        expect(r.no, lessThan(cfg.roundNo));
        expect(r.endsAt.isAfter(r.startsAt), isTrue);
        if (cfg.startsAt != null) {
          expect(r.endsAt.isAfter(cfg.startsAt!), isFalse);
        }
        expect(cfg.roundNoOf(r.roundId), r.no);
      }
    });

    test('이번 회차 id 로도 번호를 찾고, 모르는 id 는 0', () {
      final cur = cfg.currentRound;
      if (cur != null) expect(cfg.roundNoOf(cur.roundId), cfg.roundNo);
      expect(cfg.roundNoOf('1999-0101'), 0);
    });

    test('가장 최근에 끝난 회차 — 이번 회차가 끝나면 이번 회차로 넘어간다', () {
      final c = EventConfig(
        roundNo: 2,
        startsAt: DateTime.utc(2026, 9, 27, 15),
        endsAt: DateTime.utc(2026, 10, 11, 15),
        pastRounds: [
          EventRound(
            no: 1,
            startsAt: DateTime.utc(2026, 8, 31, 15),
            endsAt: DateTime.utc(2026, 9, 14, 15),
          ),
        ],
      );
      expect(c.lastEndedRound(DateTime.utc(2026, 9, 1)), isNull);
      expect(c.lastEndedRound(DateTime.utc(2026, 9, 20))!.no, 1);
      expect(c.lastEndedRound(DateTime.utc(2026, 10, 1))!.no, 1);
      expect(c.lastEndedRound(DateTime.utc(2026, 10, 12))!.no, 2);
      expect(c.roundNoOf('2026-0901'), 1);
      expect(c.roundNoOf('2026-0928'), 2);
    });
  });

  /// 실물은 **안내 대상**을 고르는 표시일 뿐이다 — 지역 판정은 코드가 하지
  /// 않는다(신청 폼에서 운영이 가른다).
  test('실물 안내는 1위 한 명에게만 간다', () {
    final physical = cfg.rewardTiers.where((t) => t.physical).toList();
    expect(physical.length, 1);
    expect(physical.first.maxRank, 1, reason: '2026-08-26 — 실물은 1위만');
    expect(cfg.tierForRank(2)!.physical, isFalse);
  });
}
