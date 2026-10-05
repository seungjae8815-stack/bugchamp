import 'dart:convert';
import 'dart:io';

import 'package:core_run/core_run.dart';
import 'package:test/test.dart';

void main() {
  final cfg = GuildConfig.fromJson(
    jsonDecode(File('../app/assets/data/guild.json').readAsStringSync())
        as Map<String, dynamic>,
  ).war;

  test('실데이터 — 7일 · 7일차는 대결 · 티어 5개 · 승리 젤리는 티어가 높을수록 많다', () {
    expect(cfg.days, hasLength(7));
    expect(cfg.days.last.theme, 'clash');
    expect(cfg.tiers.map((t) => t.id), [
      'bronze',
      'silver',
      'gold',
      'platinum',
      'diamond',
    ]);
    for (var i = 1; i < cfg.tiers.length; i++) {
      expect(cfg.tiers[i].jelly, greaterThanOrEqualTo(cfg.tiers[i - 1].jelly));
      expect(cfg.tiers[i].minGr, greaterThan(cfg.tiers[i - 1].minGr));
    }
    // 점수 키가 주제와 이어져 있어야 한다(오타면 점수가 조용히 0).
    for (final k in cfg.points.keys) {
      final themes = cfg.days.map((d) => d.theme);
      expect(
        themes.any((t) => GuildWarConfig.actionOn(t, k)),
        isTrue,
        reason: k,
      );
    }
  });

  test('그날 주제만 · 상한으로 자른다 · 제련은 등급 지수', () {
    expect(cfg.dayScore(1, {'breedDone': 3, 'elite': 100}), 30);
    expect(cfg.dayScore(1, {'breedDone': 1000}), cfg.days[0].cap);
    expect(cfg.forgePoints(0), 1);
    expect(cfg.forgePoints(5), greaterThan(cfg.forgePoints(4)));
    expect(cfg.dayScore(2, {'forge:0': 3}), 3);
    expect(cfg.dayScore(7, {'breedDone': 3}), 0, reason: '7일차는 활동 점수 없음');
  });

  test('일차 = 월 09시 KST 부터', () {
    final start = guildWeekStart(DateTime.utc(2026, 10, 7));
    expect(start, DateTime.utc(2026, 10, 5));
    expect(guildWarDayIndex(DateTime.utc(2026, 10, 5, 0, 1), start), 1);
    expect(guildWarDayIndex(DateTime.utc(2026, 10, 11, 23), start), 7);
  });

  test('실데이터 — 일차 승점은 7칸 · 합이 홀수(한 주 동점 불가) · 뒤로 갈수록 크거나 같다', () {
    expect(cfg.dayPoints, hasLength(7));
    final sum = cfg.dayPoints.fold(0, (a, b) => a + b);
    expect(sum.isOdd, isTrue, reason: '합이 짝수면 한 주 결과가 동점이 될 수 있다($sum)');
    for (var i = 1; i < cfg.dayPoints.length; i++) {
      expect(cfg.dayPoints[i], greaterThanOrEqualTo(cfg.dayPoints[i - 1]));
    }
  });

  GuildWarDayStat st(int total, [int members = 1, DateTime? at]) =>
      GuildWarDayStat(total: total, members: members, reachedAt: at);
  final none = List.filled(6, const GuildWarDayStat());

  test('하루 무승부 없음 — 점수 → 참여 인원 → 먼저 도달 → seed', () {
    final t0 = DateTime.utc(2026, 10, 5, 1);
    final t1 = DateTime.utc(2026, 10, 5, 2);
    expect(guildWarDayWinner(st(10), st(5), seed: 1, day: 1), 0);
    expect(guildWarDayWinner(st(10, 2), st(10, 3), seed: 1, day: 1), 1);
    expect(guildWarDayWinner(st(10, 3, t1), st(10, 3, t0), seed: 1, day: 1), 1);
    // 기록이 없으면 seed — 같은 seed·같은 날은 늘 같은 답, 0·1 둘 다 나온다.
    final picks = {
      for (var s = 0; s < 40; s++)
        guildWarDayWinner(st(0, 0), st(0, 0), seed: s, day: 3),
    };
    expect(picks, {0, 1});
    expect(
      guildWarDayWinner(st(0, 0), st(0, 0), seed: 7, day: 3),
      guildWarDayWinner(st(0, 0), st(0, 0), seed: 7, day: 3),
    );
  });

  test('승점 — 이긴 날만 dayPoints · 7일차 동수면 1위 대결 · 한 주 동점 없음', () {
    final o = guildWarOutcome(
      cfg,
      dayA: [st(10), st(0), st(5, 2), st(0), st(0), st(0)],
      dayB: [st(0), st(10), st(5, 1), st(1), st(1), st(1)],
      clashA: 3,
      clashB: 2,
      seed: 1,
    );
    // A: 1일차(1) + 3일차(2, 인원) + 7일차(6) = 9 · B: 2(2) + 4(3) + 5(3) + 6(4) = 12.
    expect(o.pointsA, 1 + 2 + 6);
    expect(o.pointsB, 2 + 3 + 3 + 4);
    expect(o.winner, 1);
    expect(o.pointsA + o.pointsB, 21);
    expect(o.clashWinner, 0);

    final tie = guildWarOutcome(
      cfg,
      dayA: none,
      dayB: none,
      clashA: 2,
      clashB: 2,
      topWinA: false,
      seed: 99,
    );
    expect(tie.clashWinner, 1, reason: '승수가 같으면 1위끼리 대결 결과');
    expect(tie.pointsA + tie.pointsB, 21);
    expect(tie.pointsA == tie.pointsB, isFalse);
  });
}
