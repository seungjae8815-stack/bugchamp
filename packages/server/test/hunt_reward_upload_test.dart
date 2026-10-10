// 깜짝선물·일일보상(사냥 분치)을 기기에서 받은 직후 업로드가 잘리지 않는다(2026-10-09 출시 전 점검).
//
// 둘 다 기기 권위로 받는데 금액이 사냥 1~5시간치라, 업로드 골드 상한(60초 봉투)에 잘려 받은 골드가 1~2분 뒤
// 되돌아갔다(쉬움 일일 5시간치 48% · 보통 26% 만 남음). 서버가 "이번 업로드에서 새로 받은 몫"을 따로 인정한다
// (`GameActions._huntRewardAllowance`). 흔적 없이 골드만 늘리면 예전처럼 잘려야 한다.
import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:server/src/actions.dart';
import 'package:server/src/game_config.dart';
import 'package:test/test.dart';

final t0 = DateTime.utc(2026, 10, 9, 12);

void main() {
  late GameConfig cfg;
  late GameActions actions;

  setUpAll(() async {
    cfg = await GameConfig.load(dir: '../app/assets/data');
    actions = GameActions(config: cfg, now: () => t0);
  });

  // 난이도·사냥터·강화 채움으로 저장본을 만든다(펫·장비 없음 — 봉투가 가장 빠듯한 쪽).
  ({SaveGame stored, int gift3h, int daily5h, int mats5h}) at(
    int tier,
    int zone,
    double fill,
  ) {
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
      // 다음 선물은 아직 멀었다(흔적 없는 업로드의 기본).
      nextGiftAt: t0.add(const Duration(minutes: 5)),
    );
    final stats = deriveStats(
      run,
      upgradeLevels: levels,
      characterLevel: 30,
      bugsCollected: 0,
    );
    final gift = huntMinutesReward(
      run,
      stats: stats,
      stage: stage,
      minutes: 180,
      tier: tier,
    );
    final daily = huntMinutesReward(
      run,
      stats: stats,
      stage: stage,
      minutes: 300,
      tier: tier,
    );
    return (
      stored: stored,
      gift3h: gift.gold,
      daily5h: daily.gold,
      mats5h: daily.materialsEach,
    );
  }

  final today = dailyDateKey(t0);
  final cases = [(0, 1, 0.1), (0, 8, 0.5), (1, 1, 0.1), (1, 5, 0.4)];

  test('일일보상 저녁 5시간치 + 한 번 더 받기 직후 업로드는 잘리지 않는다', () {
    for (final (tier, zone, fill) in cases) {
      final c = at(tier, zone, fill);
      final client = c.stored.copyWith(
        gold: c.stored.gold + c.daily5h * 2,
        dailyClaims: {'dinner': today, dailyBonusKey('dinner'): today},
      );
      final r = actions.mergeSave(c.stored, client.toJson());
      expect(
        r.save!.gold,
        client.gold,
        reason: '난이도 $tier 사냥터 $zone: ${r.extra['clampReasons']}',
      );
      expect(r.extra['clamped'], isNot(true));
    }
  });

  test('미래 날짜로 적은 일일보상은 허용치를 열지 않는다(2026-10-10 점검 — 2099-01-01 우회)', () {
    final c = at(0, 8, 0.5);
    final client = c.stored.copyWith(
      gold: c.stored.gold + c.daily5h * 2,
      dailyClaims: {
        'dinner': '2099-01-01',
        dailyBonusKey('dinner'): '2099-01-01',
      },
    );
    final r = actions.mergeSave(c.stored, client.toJson());
    expect(r.extra['clampReasons'], contains('gold'));
    // 내일 날짜(기기 시간대가 서버 UTC 보다 앞선 경우)는 인정한다.
    final tomorrow = dailyDateKey(t0.add(const Duration(days: 1)));
    final ok = c.stored.copyWith(
      gold: c.stored.gold + c.daily5h,
      dailyClaims: {'dinner': tomorrow},
    );
    expect(
      actions.mergeSave(c.stored, ok.toJson()).extra['clamped'],
      isNot(true),
    );
  });

  test('저장본에 있던 선물(3시간치)을 4배로 받은 직후 업로드는 잘리지 않는다', () {
    for (final (tier, zone, fill) in cases) {
      final c = at(tier, zone, fill);
      final g = GiftMail(
        id: 'g1',
        expiry: t0.add(const Duration(hours: 2)),
        gold: c.gift3h,
        minutes: 180,
      );
      final stored = c.stored.copyWith(gifts: [g]);
      final client = stored.copyWith(
        gold: stored.gold + c.gift3h * 4,
        gifts: const [],
      );
      final r = actions.mergeSave(stored, client.toJson());
      expect(r.save!.gold, client.gold, reason: '난이도 $tier 사냥터 $zone');
    }
  });

  test('업로드 사이에 생겼다 바로 받은 선물 — 다음 선물 시각이 새로 잡혔으면 인정한다', () {
    final c = at(1, 1, 0.1);
    // 예정 시각이 지났고(앱이 선물을 만들 때), 다음 시각이 최소 간격 뒤로 잡혔다.
    final stored = c.stored.copyWith(
      nextGiftAt: t0.subtract(const Duration(seconds: 20)),
    );
    final client = stored.copyWith(
      gold: stored.gold + c.gift3h * 2,
      nextGiftAt: t0.add(const Duration(minutes: 8)),
    );
    final r = actions.mergeSave(stored, client.toJson());
    expect(r.save!.gold, client.gold);
  });

  test('흔적 없이 골드만 늘리면 예전처럼 잘린다', () {
    final c = at(1, 1, 0.1);
    final client = c.stored.copyWith(gold: c.stored.gold + c.daily5h * 2);
    final r = actions.mergeSave(c.stored, client.toJson());
    expect(r.save!.gold, lessThan(client.gold));
    expect(r.extra['clamped'], isTrue);

    // 다음 선물 시각이 아직 안 됐는데 새로 잡은 척해도 인정하지 않는다.
    final fake = c.stored.copyWith(
      gold: c.stored.gold + c.gift3h * 2,
      nextGiftAt: t0.add(const Duration(minutes: 20)),
    );
    final r2 = actions.mergeSave(c.stored, fake.toJson());
    expect(r2.save!.gold, lessThan(fake.gold));
  });

  test('일일보상 날짜는 뒤로 가지 않는다 — 지웠다 다시 적어 몫을 또 받지 못한다', () {
    final c = at(1, 1, 0.1);
    final claimed = c.stored.copyWith(dailyClaims: {'dinner': today});
    // 키를 지운 업로드 — 저장본 날짜가 남는다.
    final wiped = actions.mergeSave(
      claimed,
      claimed.copyWith(dailyClaims: const {}).toJson(),
    );
    expect(wiped.save!.dailyClaims['dinner'], today);
    // 다시 적고 골드를 얹어도 새로 받은 게 아니라 잘린다.
    final again = wiped.save!.copyWith(
      lastSeen: t0.subtract(const Duration(seconds: 60)),
    );
    final client = again.copyWith(
      gold: again.gold + c.daily5h * 2,
      dailyClaims: {'dinner': today},
    );
    final r = actions.mergeSave(again, client.toJson());
    expect(r.save!.gold, lessThan(client.gold));
  });

  test('재료(사냥 5시간치)도 일일보상 몫만큼 인정한다', () {
    final c = at(0, 8, 0.5);
    final mats = Map<MaterialKind, int>.from(c.stored.materials);
    for (final k in kBreakthroughMaterials) {
      mats[k] = (mats[k] ?? 0) + c.mats5h * 2;
    }
    final client = c.stored.copyWith(
      materials: mats,
      dailyClaims: {'dinner': today, dailyBonusKey('dinner'): today},
    );
    final r = actions.mergeSave(c.stored, client.toJson());
    for (final k in kBreakthroughMaterials) {
      expect(r.save!.materialCount(k), client.materialCount(k), reason: '$k');
    }
  });
}
