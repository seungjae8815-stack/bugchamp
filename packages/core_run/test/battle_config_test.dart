import 'package:core_run/core_run.dart';
import 'package:test/test.dart';

void main() {
  group('BattleConfig 보상', () {
    const cfg = BattleConfig(); // 기본값

    test('승리 골드 = (기본 + 트로피×계수) × 보상배율', () {
      expect(cfg.winGold(0, 1.0), 4000); // 4000 + 0
      expect(cfg.winGold(100, 1.0), 7000); // 4000 + 100×30
      expect(cfg.winGold(0, 1.6), 6400); // 4000 × 1.6 (hard 티어)
    });

    test('승리 트로피 = 기본 × 보상배율(최소 1)', () {
      expect(cfg.trophyOnWin(1.0), 12);
      expect(cfg.trophyOnWin(1.6), 19); // round(19.2)
      expect(cfg.trophyOnWin(0.01), 1); // 최소 1 보장
    });

    test('기본 스카우트 티어 3종(약/대등/강)', () {
      expect(cfg.scoutTiers.length, 3);
      expect(cfg.scoutTiers.first.powerMult, lessThan(1.0)); // easy
      expect(cfg.scoutTiers.last.powerMult, greaterThan(1.0)); // hard
      expect(cfg.scoutTiers.last.rewardMult, greaterThan(1.0));
    });

    test('fromJson: 커스텀 티어·보상 파싱', () {
      final c = BattleConfig.fromJson({
        'winGoldBase': 1000,
        'trophyWin': 20,
        'scout': {
          'tiers': [
            {'id': 'even', 'powerMult': 1.0, 'rewardMult': 1.0},
          ],
        },
      });
      expect(c.winGoldBase, 1000);
      expect(c.trophyOnWin(1.0), 20);
      expect(c.scoutTiers.single.id, 'even');
    });
  });

  group('BattleConfig 리그', () {
    const cfg =
        BattleConfig(); // bronze0 / silver100 / gold300 / plat700 / dia1500

    test('트로피 → 현재 리그(경계 포함)', () {
      expect(cfg.leagueFor(0).id, 'bronze');
      expect(cfg.leagueFor(99).id, 'bronze');
      expect(cfg.leagueFor(100).id, 'silver');
      expect(cfg.leagueFor(500).id, 'gold');
      expect(cfg.leagueFor(99999).id, 'diamond');
    });

    test('다음 리그 / 진행도', () {
      expect(cfg.nextLeagueAfter(cfg.leagueFor(0))!.id, 'silver');
      // bronze(0)~silver(100) 중 50 → 0.5
      expect(cfg.leagueProgress(50), closeTo(0.5, 1e-9));
      // 최고 등급이면 다음 없음 & 진행도 1.0
      expect(cfg.nextLeagueAfter(cfg.leagueFor(2000)), isNull);
      expect(cfg.leagueProgress(2000), 1.0);
    });

    test('도달·미수령 승급 보상만 반환(bronze는 보상 없음)', () {
      // 400 트로피 → bronze/silver/gold 도달, bronze는 보상 없음
      final claim = cfg.claimableLeagues(400, {});
      expect(claim.map((l) => l.id), ['silver', 'gold']);
      // silver 이미 수령 시 gold 만
      expect(cfg.claimableLeagues(400, {'silver'}).map((l) => l.id), ['gold']);
      // 트로피 부족이면 없음
      expect(cfg.claimableLeagues(50, {}), isEmpty);
    });
  });

  group('BattleConfig 시즌', () {
    const cfg = BattleConfig(); // days14 / reset0.5 / mult3

    test('시즌 보상 = 최고 리그 승급보상 × 배율', () {
      // 최고 트로피 800 → platinum(40000골드,20젤리) × 3
      final r = cfg.seasonReward(800);
      expect(r.gold, 120000);
      expect(r.jelly, 60);
      // bronze 피크(0 보상)면 시즌 보상도 0
      expect(cfg.seasonReward(50), (gold: 0, jelly: 0));
    });

    test('시즌 리셋 트로피 = 절반(내림)', () {
      expect(cfg.seasonResetTrophies(1001), 500);
      expect(cfg.seasonResetTrophies(0), 0);
    });
  });

  group('결투 티켓', () {
    const cfg = BattleConfig(); // max10 / 30분당 1 / 광고+3(30회) / 젤리10
    final t0 = DateTime.utc(2026, 8, 6, 12);

    test('30분당 1개씩 충전, 상한에서 멈춘다', () {
      // 29분 → 아직 0개
      expect(
        regenTickets(
          tickets: 3,
          at: t0,
          now: t0.add(const Duration(minutes: 29)),
          cfg: cfg,
        ).tickets,
        3,
      );
      // 95분 → 3개(자투리 5분은 기준시각에 보존)
      final r = regenTickets(
        tickets: 3,
        at: t0,
        now: t0.add(const Duration(minutes: 95)),
        cfg: cfg,
      );
      expect(r.tickets, 6);
      expect(r.at, t0.add(const Duration(minutes: 90)));
      // 하루가 지나도 상한 10에서 멈춘다
      expect(
        regenTickets(
          tickets: 3,
          at: t0,
          now: t0.add(const Duration(days: 1)),
          cfg: cfg,
        ).tickets,
        10,
      );
    });

    test('가득 찬 동안에는 충전분이 쌓이지 않는다', () {
      // 상한에서 6시간 대기 → 여전히 10, 기준시각은 now
      final full = regenTickets(
        tickets: 10,
        at: t0,
        now: t0.add(const Duration(hours: 6)),
        cfg: cfg,
      );
      expect(full.tickets, 10);
      expect(full.at, t0.add(const Duration(hours: 6)));
      // 그 상태에서 한 장 쓰면 30분 뒤에 채워진다(즉시 복구 아님)
      final used = consumeTicket(
        tickets: full.tickets,
        at: full.at,
        now: full.at,
        cfg: cfg,
      )!;
      expect(used.tickets, 9);
      expect(
        regenTickets(
          tickets: used.tickets,
          at: used.at,
          now: used.at.add(const Duration(minutes: 29)),
          cfg: cfg,
        ).tickets,
        9,
      );
    });

    test('소모: 없으면 null, 있으면 충전 진행도를 유지', () {
      expect(consumeTicket(tickets: 0, at: t0, now: t0, cfg: cfg), isNull);
      // 20분 경과(충전 진행 중) 상태에서 소모 → 자투리 20분이 유지된다
      final now = t0.add(const Duration(minutes: 20));
      final r = consumeTicket(tickets: 5, at: t0, now: now, cfg: cfg)!;
      expect(r.tickets, 4);
      expect(r.at, t0);
    });

    test('광고 지급은 상한을 넘길 수 있고, 젤리는 상한까지 채운다', () {
      final ad = grantTickets(
        tickets: 9,
        at: t0,
        now: t0,
        cfg: cfg,
        amount: cfg.ticketAdGrant,
      );
      expect(ad.tickets, 12); // 9+3 — 광고를 낭비시키지 않는다
      expect(refillTickets(tickets: 2, at: t0, now: t0, cfg: cfg).tickets, 10);
      // 이미 상한 이상이면 젤리를 써도 늘지 않는다(호출부가 막아야 한다)
      expect(refillTickets(tickets: 12, at: t0, now: t0, cfg: cfg).tickets, 12);
    });

    test('기기 시계를 되돌려도 충전이 멈추지 않는다', () {
      final back = regenTickets(
        tickets: 2,
        at: t0,
        now: t0.subtract(const Duration(days: 3)),
        cfg: cfg,
      );
      expect(back.tickets, 2);
      expect(back.at, t0.subtract(const Duration(days: 3))); // 기준시각만 재조정
    });

    test('남은 시간: 상한이면 null, 아니면 다음 1개까지', () {
      expect(
        ticketRegenRemaining(tickets: 10, at: t0, now: t0, cfg: cfg),
        isNull,
      );
      expect(
        ticketRegenRemaining(
          tickets: 1,
          at: t0,
          now: t0.add(const Duration(minutes: 10)),
          cfg: cfg,
        ),
        const Duration(minutes: 20),
      );
    });

    test('fromJson: tickets 블록 파싱(§6 — 수치는 JSON에서만)', () {
      final c = BattleConfig.fromJson({
        'tickets': {
          'max': 5,
          'regenSeconds': 600,
          'adGrant': 1,
          'adDailyLimit': 4,
          'refillJelly': 25,
        },
      });
      expect(c.ticketMax, 5);
      expect(c.ticketRegen, const Duration(minutes: 10));
      expect(c.ticketAdGrant, 1);
      expect(c.ticketAdDailyLimit, 4);
      expect(c.ticketRefillJelly, 25);
    });
  });
}
