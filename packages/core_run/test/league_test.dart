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
}
