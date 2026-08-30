import 'package:app/domain/pvp_backend.dart';
import 'package:flutter_test/flutter_test.dart';

/// 회차제(쉬움 1-1000 → 보통 1부터)를 넣으면서, 진행도 랭킹이 스테이지 숫자만
/// 보면 **회차를 넘어가는 순간 꼴찌**가 된다. 넘어갈 이유가 사라지므로
/// 회차가 1차 키여야 한다. 서버 정렬(leaderboard_top)과 같은 규칙이다.
void main() {
  PvpProfile p(String id, {int tier = 0, int stage = 1}) => PvpProfile(
    id: id,
    nickname: id,
    trophies: 0,
    stageNumber: stage,
    difficultyTier: tier,
  );

  test('보통 1스테이지가 쉬움 1000스테이지보다 위다', () {
    final normalStart = p('보통', tier: 1, stage: 1);
    final easyEnd = p('쉬움끝', tier: 0, stage: 1000);
    expect(
      normalStart.scoreFor(RankingKind.stage),
      greaterThan(easyEnd.scoreFor(RankingKind.stage)),
    );
  });

  test('같은 회차 안에서는 스테이지가 가른다', () {
    expect(
      p('a', tier: 2, stage: 300).scoreFor(RankingKind.stage),
      greaterThan(p('b', tier: 2, stage: 299).scoreFor(RankingKind.stage)),
    );
  });

  test('폴백 사다리는 합성 점수를 회차·스테이지로 되돌린다', () async {
    // 합성값을 그대로 넣으면 화면에 `쉬움 1000-32` 같은 없는 구간이 뜬다.
    final board = await LocalPvpBackend().leaderboard(
      me: p('me', tier: 3, stage: 500),
      kind: RankingKind.stage,
    );
    for (final e in board.entries) {
      expect(
        e.profile.stageNumber,
        lessThan(100000),
        reason: '스테이지 칸에 합성 점수가 새어 들어갔다',
      );
    }
  });
}
