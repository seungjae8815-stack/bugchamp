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
    expect(cfg.tierForRank(1)!.maxRank, 3);
    expect(cfg.tierForRank(3)!.maxRank, 3);
    expect(cfg.tierForRank(4)!.maxRank, 10);
    expect(cfg.tierForRank(100)!.maxRank, 100);
  });

  test('순위권 밖·0 이하는 구간이 없다', () {
    expect(cfg.tierForRank(101), isNull);
    expect(cfg.tierForRank(0), isNull);
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
    /// 뱃지는 실물을 못 받는 해외 이용자에게 **등가를 맞추는 축**이다.
    /// 젤리로 맞추면 그 유저의 경제가 끝난다(§2.6).
    test('상위 구간에만 붙는다', () {
      expect(cfg.badgeIdForRank(1), isNotNull);
      expect(cfg.badgeIdForRank(10), isNotNull);
      expect(cfg.badgeIdForRank(50), isNull, reason: '흔하면 자랑거리가 아니다');
      expect(cfg.badgeIdForRank(101), isNull);
    });

    /// 1회차 챔피언과 3회차 챔피언은 **다른** 자랑거리다.
    test('id 에 회차 번호가 붙는다', () {
      expect(cfg.roundNo, greaterThan(0), reason: 'event.json round.no 누락');
      expect(cfg.badgeIdForRank(1), 'champion:${cfg.roundNo}');
      expect(cfg.badgeIdForRank(1), isNot(cfg.badgeIdForRank(10)));
    });
  });

  /// 실물은 **안내 대상**을 고르는 표시일 뿐이다 — 지역 판정은 코드가 하지
  /// 않는다(신청 폼에서 운영이 가른다).
  test('실물 안내는 최상위 구간에만 붙는다', () {
    final physical = cfg.rewardTiers.where((t) => t.physical).toList();
    expect(physical.length, 1);
    expect(physical.first.maxRank, cfg.rewardTiers.first.maxRank);
  });
}
