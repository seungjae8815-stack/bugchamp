import 'dart:convert';
import 'dart:io';

import 'package:app/features/battle/league_rules_view.dart';
import 'package:core_run/core_run.dart';
import 'package:flutter_test/flutter_test.dart';

/// 리그 순위표의 보상·승강 표시가 **서버 결산과 같은 core 함수** 결과인지(2026-10-11 규칙).
void main() {
  final cfg = BattleConfig.fromJson(
    jsonDecode(File('assets/data/battle.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  const people = [1, 2, 3, 5, 9, 10, 20];

  test('인원별 순위 젤리·구간이 core 함수와 같다', () {
    for (final lg in cfg.leagues) {
      final idx = cfg.leagueIndexOf(lg.id);
      for (final n in people) {
        final v = LeagueRulesView(cfg, league: lg.id, total: n);
        final ranges = v.rewardRanges();
        for (var rank = 1; rank <= n; rank++) {
          for (final trophies in const [0, 5]) {
            final core = trophies <= 0
                ? 0
                : cfg.leagueRankJelly(rank, league: lg.id, people: n);
            expect(
              v.jellyFor(rank, trophies),
              core,
              reason: '${lg.id} $n명 $rank위',
            );
            final next = cfg.leagueAfterSeason(
              idx,
              rank: rank,
              total: n,
              trophies: trophies,
            );
            expect(
              v.zoneOf(rank, trophies),
              (next - idx).sign,
              reason: '${lg.id} $n명 $rank위 구간',
            );
          }
          // 보상표 = 받을 수 있는 순위만(트로피 있는 사람 기준).
          final inTable = ranges
              .where((r) => rank >= r.from && rank <= r.to)
              .map((r) => r.jelly)
              .firstOrNull;
          final core = cfg.leagueRankJelly(rank, league: lg.id, people: n);
          expect(inTable ?? 0, core, reason: '${lg.id} $n명 표 $rank위');
          if (core == 0) expect(inTable, isNull);
        }
      }
    }
  });

  test('구체 값 — 인원 보정·승급 문턱·합류', () {
    // 1·2명: 순위 젤리 없음, 위 리그는 아래로 합류.
    for (final n in const [1, 2]) {
      final gold = LeagueRulesView(cfg, league: 'gold', total: n);
      expect(gold.rewardRanges(), isEmpty);
      expect(gold.merges, isTrue);
      expect(gold.notice, LeagueFewNotice.merge);
      expect(gold.zoneOf(1, 30), -1);
      final bronze = LeagueRulesView(cfg, league: 'bronze', total: n);
      expect(bronze.merges, isFalse);
      expect(bronze.notice, LeagueFewNotice.noReward);
      expect(bronze.zoneOf(1, 30), 0);
    }
    // 3명: 1위만(절반 내림 = 1), 금액 × 0.3. 승급 없음.
    final s3 = LeagueRulesView(cfg, league: 'silver', total: 3);
    expect(s3.jellyFor(1, 9), (40 * 3 / 10).round());
    expect(s3.jellyFor(2, 9), 0);
    expect(s3.promote, 0);
    expect(s3.notice, LeagueFewNotice.partial);
    // 5명: 1·2위, × 0.5.
    final s5 = LeagueRulesView(cfg, league: 'silver', total: 5);
    expect(s5.rewardRanges(), [
      (from: 1, to: 1, jelly: 20),
      (from: 2, to: 2, jelly: 10),
    ]);
    expect((s5.promote, s5.demote), (0, 1));
    // 9명: 아직 승급 없음.
    expect(LeagueRulesView(cfg, league: 'silver', total: 9).promote, 0);
    // 10명: 승급 2명 · 전체 보상 · 안내 없음.
    final s10 = LeagueRulesView(cfg, league: 'silver', total: 10);
    expect((s10.promote, s10.demote), (2, 2));
    expect(s10.jellyFor(1, 9), 40);
    expect(s10.jellyFor(5, 9), 5);
    expect(s10.jellyFor(6, 9), 0);
    expect(s10.notice, LeagueFewNotice.none);
    // 20명: 1~10위 원래 표.
    final s20 = LeagueRulesView(cfg, league: 'silver', total: 20);
    expect(s20.rewardRanges(), s20.rewardRanges(fullTable: true));
    expect(s20.rewardRanges().last.to, 10);
  });
}
