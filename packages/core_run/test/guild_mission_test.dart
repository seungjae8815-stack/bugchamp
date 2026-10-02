import 'dart:convert';
import 'dart:io';

import 'package:core_run/core_run.dart';
import 'package:test/test.dart';

Map<String, dynamic> _read(String f) =>
    jsonDecode(File('../app/assets/data/$f').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  final guild = GuildConfig.fromJson(_read('guild.json'));
  final c = guild.mission;
  final run = RunConfig.fromJson(_read('run_config.json'));

  test('실데이터를 읽는다', () {
    expect(guild.createJellyCost, 200);
    expect(c.boardMults, hasLength(5));
    expect(c.waitSeconds, hasLength(c.waitMults.length));
  });

  test('하루 경계는 KST 09시다', () {
    // 2026-10-05 08:59 KST = 10-04 23:59 UTC → 아직 10-04
    expect(guildDayKey(DateTime.utc(2026, 10, 4, 23, 59)), '2026-10-04');
    expect(guildDayKey(DateTime.utc(2026, 10, 5)), '2026-10-05');
    expect(
      guildNextDayAt(DateTime.utc(2026, 10, 4, 23, 59)),
      DateTime.utc(2026, 10, 5),
    );
  });

  test('게시판은 길드원마다 다르고(같은 날 다시 열면 같다), 배율은 칸 순서대로', () {
    final a = guildMissionBoard(c, 'u1', '2026-10-05');
    final again = guildMissionBoard(c, 'u1', '2026-10-05');
    expect(a.map((s) => s.kind), again.map((s) => s.kind));
    expect(a.map((s) => s.mult), c.boardMults);
    // 여러 길드원 중 적어도 한 명은 목록이 다르다.
    final others = [
      for (var i = 2; i < 12; i++)
        guildMissionBoard(c, 'u$i', '2026-10-05').map((s) => s.kind).join(),
    ];
    expect(others.any((o) => o != a.map((s) => s.kind).join()), isTrue);
  });

  test('실패 보상 — 어려운 칸을 혼자 실패해도 쉬운 칸 성공보다 적다', () {
    double pay(double mult) {
      final o = guildMissionOutcome(c, total: 1, need: mult);
      return mult * o.factor;
    }

    expect(pay(0.8), 0.8, reason: '×0.8 은 혼자 성공');
    for (final m in c.boardMults.where((m) => m > 1)) {
      expect(pay(m), lessThan(pay(0.8)), reason: '×$m 혼자 실패');
    }
  });

  test('보상은 자기 사냥터 기준 · 돕는 사람은 절반 · 스테이지가 깊을수록 많다', () {
    final lo = guildMissionReward(c, run, stage: 1, mult: 1.8, factor: 1);
    final hi = guildMissionReward(c, run, stage: 500, mult: 1.8, factor: 1);
    final help = guildMissionReward(
      c,
      run,
      stage: 1,
      mult: 1.8,
      factor: 1,
      helper: true,
    );
    expect(hi.chitin, greaterThan(lo.chitin * 10));
    expect(help.chitin, closeTo(lo.chitin / 2, 1));
    expect(help.coins, c.helperCoins);
    expect(lo.coins, (c.coinBase * 1.8).round());
    expect(lo.fossil, (c.fossilBase * 1.8).round());
  });
}
