import 'package:app/domain/pvp_backend.dart';
import 'package:core_models/core_models.dart';
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

  test('로컬 백엔드: isRemote=false · 등록 no-op · 상대 없음', () async {
    expect(backend.isRemote, isFalse);
    // 등록은 던지지 않고 조용히 완료.
    await backend.registerDefender(
      me: me(500),
      team: const [
        DefenderBug(
          speciesId: 'stag',
          element: Element.wood,
          temperament: Temperament.aggressive,
          maxHp: 100,
          atk: 20,
          def: 10,
          spd: 15,
        ),
      ],
    );
    final foes = await backend.fetchOpponents(me: me(500), count: 3);
    expect(foes, isEmpty);
    // 트로피 라이브 반영도 로컬은 no-op(던지지 않고 완료).
    await backend.pushTrophies(me: me(750));
  });

  test('DefenderBug: toJson/fromJson 왕복 보존', () {
    const b = DefenderBug(
      speciesId: 'rhino_beetle',
      element: Element.fire,
      temperament: Temperament.cunning,
      maxHp: 123.5,
      atk: 42.25,
      def: 18.75,
      spd: 30.0,
    );
    final r = DefenderBug.fromJson(b.toJson());
    expect(r.speciesId, b.speciesId);
    expect(r.element, b.element);
    expect(r.temperament, b.temperament);
    expect(r.maxHp, b.maxHp);
    expect(r.atk, b.atk);
    expect(r.def, b.def);
    expect(r.spd, b.spd);
  });
}
