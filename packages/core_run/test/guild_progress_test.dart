import 'dart:convert';
import 'dart:io';

import 'package:core_run/core_run.dart';
import 'package:test/test.dart';

void main() {
  final cfg = GuildConfig.fromJson(
    jsonDecode(File('../app/assets/data/guild.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  test('실데이터 — 스킬 6종 · 상점에 젤리·티켓 없음', () {
    expect(cfg.skills, hasLength(6));
    expect(cfg.shop.map((s) => s.kind), isNot(contains('jelly')));
    expect(cfg.shop.map((s) => s.kind), isNot(contains('ticket')));
    // 스킬 키는 applyGuildStats·서버가 아는 것만(오타면 버프가 조용히 사라진다).
    const known = {
      'attack',
      'hp',
      'gold',
      'materialFind',
      'xp',
      'missionReward',
    };
    for (final d in cfg.skills) {
      expect(known, contains(d.stat), reason: d.id);
    }
  });

  test('레벨 곡선 — 경험치 → 레벨 · 인원 +1 · 포인트', () {
    final lv = cfg.level;
    expect(lv.levelOf(0).level, 1);
    expect(lv.levelOf(lv.expFor(1)).level, 2);
    expect(lv.levelOf(1 << 40).level, lv.max);
    expect(lv.maxMembers(cfg.maxMembers, 1), cfg.maxMembers);
    expect(lv.maxMembers(cfg.maxMembers, lv.max), lv.membersCap);
    expect(lv.points(lv.max), lv.max - 1);
  });

  test('버프 합 · 최대 단계로 자른다 · 스탯에 곱한다', () {
    final b = guildBonus(cfg.skills, {'attack': 99, 'gold': 2});
    expect(b['attack'], closeTo(0.016 * 5, 1e-9));
    expect(b['gold'], closeTo(0.04, 1e-9));
    expect(guildPointsUsed(cfg.skills, {'attack': 99, 'gold': 2}), 7);
    const s = CharacterStats(
      attack: 100,
      attackSpeed: 1,
      rewardMultiplier: 1,
      critChance: 0,
      critDamage: 1,
      bossDamage: 1,
      maxHp: 1000,
      defense: 0,
      hpRegen: 0,
      xpMultiplier: 1,
      bugFind: 1,
      materialFind: 1,
      evade: 0,
      boostBonus: 0,
    );
    final t = applyGuildStats(s, b);
    expect(t.attack, closeTo(108, 1e-9));
    expect(t.rewardMultiplier, closeTo(1.04, 1e-9));
    expect(t.maxHp, 1000);
  });

  test('주 키 = 월요일 09시 KST(= 월 00시 UTC)', () {
    expect(guildWeekKey(DateTime.utc(2026, 10, 5)), '2026-10-05'); // 월
    expect(guildWeekKey(DateTime.utc(2026, 10, 4, 23, 59)), '2026-09-28'); // 일
    expect(guildWeekKey(DateTime.utc(2026, 10, 11, 12)), '2026-10-05');
  });

  test('출석 표 — 35칸 순환 · 7일차마다 큰 보상(젤리 없음)', () {
    final a = cfg.attend;
    expect(a.cycleDays, 35);
    expect(a.dayOf(0), 0);
    expect(a.nextDay(0), 1);
    expect(a.dayOf(1), 1);
    expect(a.dayOf(35), 35);
    expect(a.nextDay(35), 1, reason: '다 채우면 1일차로');
    expect(a.dayOf(36), 1);
    expect(a.dayOf(70), 35);
    expect([for (final b in a.bonuses) b.day], [7, 14, 21, 28, 35]);
    final table = a.bonusCoinsTable();
    expect(table, hasLength(35));
    expect(table[6], a.bonusOn(7)!.coins);
    expect(table[0], 0);
    expect(a.bonusOn(35)!.hasItems, isTrue);
    expect(a.bonusOn(3), isNull);
    // 큰 보상은 갈수록 크다(코인).
    final coins = [for (final b in a.bonuses) b.coins];
    expect(coins, orderedEquals([...coins]..sort()));
  });
}
