import 'dart:convert';
import 'dart:io';

import 'package:core_run/core_run.dart';
import 'package:test/test.dart';

void main() {
  final b = BattleConfig.fromJson(
    jsonDecode(File('../app/assets/data/battle.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  test('승강 구간 — 상위·하위 20%, 작은 리그는 줄인다', () {
    expect(b.leagueZones(100), (promote: 20, demote: 20));
    expect(b.leagueZones(10), (promote: 2, demote: 2));
    expect(b.leagueZones(4), (promote: 1, demote: 0), reason: '4명 이하는 강등 없음');
    expect(b.leagueZones(2), (promote: 1, demote: 0));
    expect(b.leagueZones(1), (promote: 0, demote: 0), reason: '혼자면 그대로');
  });

  test('결산 — 맨 위·맨 아래 리그에서는 넘어가지 않는다', () {
    final top = b.leagues.length - 1;
    expect(b.leagueAfterSeason(top, rank: 1, total: 50, trophies: 99), top);
    expect(b.leagueAfterSeason(0, rank: 50, total: 50, trophies: 1), 0);
    expect(b.leagueAfterSeason(2, rank: 1, total: 50, trophies: 99), 3);
    expect(b.leagueAfterSeason(2, rank: 50, total: 50, trophies: 1), 1);
    expect(b.leagueAfterSeason(2, rank: 25, total: 50, trophies: 30), 2);
  });

  test('리그별 순위 보상 — 높은 리그일수록 많다, 10위까지', () {
    var prev = 0;
    for (final lg in b.leagues) {
      final j = b.seasonRankJelly(1, league: lg.id);
      expect(j, greaterThan(prev), reason: lg.id);
      prev = j;
      expect(b.seasonRankJelly(10, league: lg.id), greaterThan(0));
      expect(b.seasonRankJelly(11, league: lg.id), 0);
    }
  });

  group('시즌 시간표 — 월 09시 시작 · 일 09시 마감 · 정산 24시간', () {
    // KST = UTC+9. 2026-10-05(월) 09:00 KST = 2026-10-05 00:00 UTC.
    final mon9 = DateTime.utc(2026, 10, 5);
    test('집계 중 → 일 09시 전까지', () {
      final t = mon9.add(const Duration(days: 5, hours: 23)); // 일 08시 KST
      expect(seasonClosed(t, b), isFalse);
      expect(seasonStartAt(t, b), mon9);
      expect(seasonCloseAt(t, b), mon9.add(const Duration(days: 6)));
      expect(settleSeasonIdAt(t, b), '2026-09-28', reason: '아직 이번 시즌은 결산 못 한다');
    });
    test('정산 기간 → 이번 시즌을 결산한다', () {
      final t = mon9.add(const Duration(days: 6, hours: 1)); // 일 10시 KST
      expect(seasonClosed(t, b), isTrue);
      expect(settleSeasonIdAt(t, b), '2026-10-05');
    });
    test('월 09시 → 새 시즌, 결산 대상은 방금 끝난 시즌 그대로', () {
      final t = mon9.add(const Duration(days: 7, minutes: 1));
      expect(seasonClosed(t, b), isFalse);
      expect(seasonIdOf(seasonStartAt(t, b), b), '2026-10-12');
      expect(settleSeasonIdAt(t, b), '2026-10-05');
    });
  });

  group('상대 후보 5명 — 위 3명(3·4·5점) · 아래 2명(2·1점)', () {
    List<({String userId, int rank})> board(int n) => [
      for (var r = 1; r <= n; r++) (userId: 'u$r', rank: r),
    ];
    test('6위면 3·4·5·7·8위', () {
      final s = pickMatchSlots(
        ranked: board(20),
        myRank: 6,
        myUserId: 'u6',
        cfg: b,
      );
      expect([for (final x in s) x.rank], [3, 4, 5, 7, 8]);
      expect([for (final x in s) x.points], [5, 4, 3, 2, 1]);
    });
    test('1위면 아래 5명', () {
      final s = pickMatchSlots(
        ranked: board(20),
        myRank: 1,
        myUserId: 'u1',
        cfg: b,
      );
      expect([for (final x in s) x.rank], [2, 3, 4, 5, 6]);
      expect([for (final x in s) x.points], [2, 1, 1, 1, 1]);
    });
    test('순위 없음(첫 판)이면 맨 아래 5명 — 모두 위라 3~5점', () {
      final s = pickMatchSlots(
        ranked: board(20),
        myRank: null,
        myUserId: 'me',
        cfg: b,
      );
      expect([for (final x in s) x.rank], [16, 17, 18, 19, 20]);
      expect([for (final x in s) x.points], [5, 5, 5, 4, 3]);
    });
    test('사람이 모자라면 야생으로 채운다', () {
      final s = pickMatchSlots(
        ranked: board(2),
        myRank: 2,
        myUserId: 'u2',
        cfg: b,
      );
      expect(s.length, 5);
      expect(s.first.userId, 'u1');
      expect(s.first.points, 3);
      expect([for (final x in s.skip(1)) x.userId], everyElement(isNull));
      expect([
        for (final x in s.skip(1)) x.points,
      ], everyElement(b.matchWildPoints));
    });
  });
}
