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

  test('승점 — 1~6일차 승 2 · 7일차 승 4 · 동점은 7일차 승수 → 총합', () {
    final o = guildWarOutcome(
      cfg,
      dayA: [10, 0, 5, 0, 0, 0],
      dayB: [0, 10, 5, 0, 0, 0],
      clashA: 3,
      clashB: 2,
    );
    expect(o.pointsA, 2 + 1 + 3 * 1 + 4);
    expect(o.winner, 0);
    final tie = guildWarOutcome(
      cfg,
      dayA: [10, 0, 0, 0, 0, 0],
      dayB: [0, 20, 0, 0, 0, 0],
      clashA: 1,
      clashB: 1,
    );
    expect(tie.pointsA, tie.pointsB);
    expect(tie.winner, 1, reason: '대결도 같으면 총합(20 > 10)');
  });
}
