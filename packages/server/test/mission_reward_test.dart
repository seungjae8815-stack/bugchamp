// 미션 보상 개편(2026-10-10 사장님 확정) — 사냥·강화 미션 = 사냥 10분치 · 젤리 미션 = 하루 2번까지.
//
// 목표 상한(사냥 1,000마리) 뒤로 한 바퀴가 온라인 사냥 약 45분이 되자 옛 식(`rewardGrowth^claims`)이 받을 때마다
// 1.6배씩 커져(쉬움에서 94만~10억 골드) 경제를 부쉈고, 제련 미션 젤리는 켜 둔 시간에 비례해 하루 30개까지 나왔다.
// 미션은 기기에서 받으므로 서버는 ① 업로드 골드·재료 상한에 "새로 받은 미션 몫"을 더하고(안 그러면 받은 골드가
// 1~2분 뒤 되돌아간다) ② 옛 서버 수령 경로(`claimMission`)도 같은 규칙으로 막는다.
import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:server/src/actions.dart';
import 'package:server/src/game_config.dart';
import 'package:test/test.dart';

final t0 = DateTime.utc(2026, 10, 10, 12);

void main() {
  late GameConfig cfg;
  late GameActions actions;

  setUpAll(() async {
    cfg = await GameConfig.load(dir: '../app/assets/data');
    actions = GameActions(config: cfg, now: () => t0);
  });

  MissionDef def(String reward) =>
      cfg.mission!.missions.firstWhere((m) => m.reward == reward);

  // 난이도·사냥터·강화 채움으로 저장본과 그 자리의 미션 사냥 분치 골드를 만든다(펫·장비 없음 — 봉투가 가장 빠듯한 쪽).
  ({SaveGame stored, int gold}) at(int tier, int zone, double fill) {
    final run = cfg.run;
    final stage = run.zoneStartStage(zone);
    final levels = <UpgradeKind, int>{
      for (final e in run.upgrades.entries)
        e.key: ((e.value.maxLevel ?? 100) * fill).round(),
    };
    final stored = SaveGame.initial(createdAt: t0).copyWith(
      lastSeen: t0.subtract(const Duration(seconds: 60)),
      difficultyTier: tier,
      maxTierReached: tier,
      stageNumber: stage,
      bestStage: stage,
      upgradeLevels: levels,
      gold: 1000000,
      level: 30,
      nextGiftAt: t0.add(const Duration(minutes: 5)),
    );
    final stats = deriveStats(
      run,
      upgradeLevels: levels,
      characterLevel: 30,
      bugsCollected: 0,
    );
    final hunt = def('gold');
    final r = huntMinutesReward(
      run,
      stats: stats,
      stage: stage,
      minutes: hunt.huntMinutes,
      tier: tier,
    );
    return (stored: stored, gold: r.gold);
  }

  final cases = [(0, 1, 0.1), (0, 8, 0.5), (1, 1, 0.1), (2, 5, 0.4)];

  test('사냥 미션(사냥 10분치)을 받은 직후 업로드는 골드가 잘리지 않는다', () {
    final hunt = def('gold');
    for (final (tier, zone, fill) in cases) {
      final c = at(tier, zone, fill);
      final up = c.stored.copyWith(
        gold: c.stored.gold + c.gold,
        missionClaims: {hunt.id: c.stored.missionClaimCount(hunt.id) + 1},
      );
      final r = actions.mergeSave(c.stored, up.toJson());
      expect(r.isOk, isTrue, reason: r.error);
      expect(
        (r.extra['clampReasons'] as List?) ?? const [],
        isNot(contains('gold')),
        reason: '난이도 $tier 사냥터 $zone',
      );
      expect(r.save!.gold, c.stored.gold + c.gold);
    }
  });

  test('받은 횟수를 크게 부풀려도 허용치는 업로드당 3번분뿐이다', () {
    final hunt = def('gold');
    final c = at(0, 8, 0.5);
    // 서버 봉투는 일부러 넉넉하다(강화만 아는 전력 · 최고 난이도 끝 기준). 그래도 3번분이라 터무니없는 골드는 잘린다.
    final up = c.stored.copyWith(
      gold: c.stored.gold + c.gold * 1000000,
      missionClaims: {hunt.id: 1000000},
    );
    final r = actions.mergeSave(c.stored, up.toJson());
    expect(r.extra['clampReasons'], contains('gold'));
    expect(r.save!.gold, lessThan(c.stored.gold + c.gold * 1000000));
  });

  test('옛 서버 수령 경로도 젤리 미션은 하루 2번까지 — 세 번째는 젤리 없이 넘어간다', () {
    final forge = def('jelly');
    var s = SaveGame.initial(createdAt: t0);
    int jelly(SaveGame x) => x.materialCount(MaterialKind.jelly);
    for (var i = 0; i < 3; i++) {
      final before = jelly(s);
      final r = actions.claimMission(
        s.copyWith(missionProgress: {forge.id: forge.goalAt(i)}),
        forge.id,
      );
      expect(r.isOk, isTrue, reason: r.error);
      s = r.save!;
      expect(s.missionClaimCount(forge.id), i + 1);
      if (i < 2) {
        expect(jelly(s), greaterThan(before), reason: '${i + 1}번째');
      } else {
        expect(jelly(s), before, reason: '하루 한도를 넘었다');
      }
    }
  });

  test('옛 서버 수령 경로의 사냥 미션 골드는 받은 횟수와 상관없이 사냥 분치다(1.6배 성장 없음)', () {
    final hunt = def('gold');
    final c = at(0, 1, 0.1);
    int gain(int claims) {
      final s = c.stored.copyWith(
        missionClaims: {hunt.id: claims},
        missionProgress: {hunt.id: hunt.goalAt(claims)},
      );
      return actions.claimMission(s, hunt.id).save!.gold - s.gold;
    }

    expect(gain(30), gain(0));
    expect(gain(30), lessThan(hunt.rewardAt(30)));
  });
}
