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
    const cfg = BattleConfig(); // bronze0 / silver100 / gold300 / plat700 / dia1500

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
}
