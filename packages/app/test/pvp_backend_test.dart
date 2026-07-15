import 'package:app/domain/pvp_backend.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const backend = LocalPvpBackend();

  PvpProfile me(int trophies) =>
      PvpProfile(id: 'me', nickname: '나', trophies: trophies);

  test('리더보드: 나 포함 · 트로피 내림차순 · 랭크 연속', () async {
    final board = await backend.leaderboard(me: me(500), limit: 50);
    expect(board.any((e) => e.isMe), isTrue);
    for (var i = 1; i < board.length; i++) {
      expect(
        board[i].profile.trophies,
        lessThanOrEqualTo(board[i - 1].profile.trophies),
      );
      expect(board[i].rank, greaterThan(board[i - 1].rank));
    }
  });

  test('높은 트로피일수록 상위(작은) 랭크', () async {
    final low = await backend.leaderboard(me: me(0), limit: 50);
    final high = await backend.leaderboard(me: me(3000), limit: 50);
    final lowRank = low.firstWhere((e) => e.isMe).rank;
    final highRank = high.firstWhere((e) => e.isMe).rank;
    expect(highRank, lessThan(lowRank));
  });

  test('상위권 밖이어도 나는 결과에 포함(말미 덧붙임)', () async {
    final board = await backend.leaderboard(me: me(0), limit: 5);
    expect(board.any((e) => e.isMe), isTrue);
  });
}
