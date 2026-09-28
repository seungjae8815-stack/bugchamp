import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:server/src/actions.dart';
import 'package:server/src/game_config.dart';
import 'package:test/test.dart';

void main() {
  late GameConfig cfg;
  late GameActions actions;
  final t0 = DateTime.utc(2026, 9, 29, 3); // 월요일 12시 KST — 이번 주 = 2026-09-28
  const week = '2026-09-28';

  setUpAll(() async {
    cfg = await GameConfig.load(dir: '../app/assets/data');
    actions = GameActions(config: cfg, now: () => t0);
  });

  String finalBoss() =>
      cfg.run.bossArtId(abyssTier(cfg.run), cfg.run.zonesPerTier);

  /// 극한 끝에 선, 심연이 열린 저장본. 마지막 업로드는 [ago] 전.
  SaveGame stored({
    int floor = 5,
    int best = 4,
    Duration ago = const Duration(seconds: 60),
    bool unlocked = true,
  }) => SaveGame.initial(createdAt: t0).copyWith(
    lastSeen: t0.subtract(ago),
    zoneEpoch: kZoneEpoch,
    difficultyTier: 3,
    maxTierReached: 3,
    stageNumber: abyssStage(cfg.run),
    bossDex: {finalBoss()},
    abyssUnlocked: unlocked,
    inAbyss: unlocked,
    abyssFloor: floor,
    abyssBest: best,
    abyssWeek: week,
  );

  group('업로드 병합 — 층 위조 방어', () {
    test('시간 안에서 오른 층은 그대로 받는다', () {
      final s = stored();
      final client = s.copyWith(abyssFloor: 6, abyssBest: 5);
      final r = actions.mergeSave(s, client.toJson());
      expect(r.save!.abyssFloor, 6);
      expect(r.save!.abyssBest, 5);
      expect(r.extra['clampReasons'] ?? const [], isNot(contains('abyss')));
    });

    test('60초에 999층은 잘린다(층당 최소 시간)', () {
      final s = stored();
      final client = s.copyWith(abyssFloor: 999, abyssBest: 998);
      final r = actions.mergeSave(s, client.toJson());
      final perFloor = cfg.run.abyss.minSecondsPerFloor;
      final cap = 5 + (60 / perFloor).ceil();
      expect(r.save!.abyssFloor, cap);
      expect(r.save!.abyssBest, lessThan(cap));
      expect(r.extra['clampReasons'], contains('abyss'));
    });

    test('역대 최고는 줄지 않는다(구버전 앱이 키 없이 올려도)', () {
      final s = stored(best: 40);
      final json = s.toJson()
        ..remove('abyssBest')
        ..remove('abyssUnlocked');
      final r = actions.mergeSave(s, json);
      expect(r.save!.abyssBest, 40);
      expect(r.save!.abyssUnlocked, isTrue);
    });

    test('극한 최종 보스 없이 심연이 열렸다고 적어도 인정하지 않는다', () {
      final s = stored(unlocked: false).copyWith(bossDex: const {});
      final client = s.copyWith(abyssUnlocked: true, inAbyss: true);
      final r = actions.mergeSave(s, client.toJson());
      expect(r.save!.abyssUnlocked, isFalse);
      expect(r.save!.inAbyss, isFalse);
    });

    test('다음 주로 넘어가면 1층부터 다시 센다', () {
      // 5분이면 층당 최소 90초로 세 층까지 가능하다.
      final s = stored(
        floor: 30,
        ago: const Duration(minutes: 5),
      ).copyWith(abyssWeek: '2026-09-21');
      // 새 주에 들어와 3층까지 올렸다.
      final client = s.copyWith(abyssWeek: week, abyssFloor: 3);
      final r = actions.mergeSave(s, client.toJson());
      expect(r.save!.abyssWeek, week);
      expect(r.save!.abyssFloor, 3);
    });
  });

  group('주간 순위', () {
    test('층이 오르면 이번 주 점수를 찍는다 · 그대로면 다시 안 찍는다', () {
      final s = stored();
      final up = s.copyWith(abyssFloor: 7);
      final r = actions.abyssScoreFor(s, up);
      expect(r, isNotNull);
      expect(r!.week, week);
      expect(r.floor, 7);
      expect(r.save.abyssScoreWeek, week);
      expect(actions.abyssScoreFor(r.save, r.save), isNull);
    });

    test('같은 층에서 벽 보스를 더 깎으면 다시 기록한다(동률 판정)', () {
      final s = stored().copyWith(abyssScoreWeek: week, abyssBossBest: 300);
      final better = s.copyWith(abyssBossBest: 450);
      final r = actions.abyssScoreFor(s, better);
      expect(r, isNotNull);
      expect(r!.boss, 450);
      expect(r.floor, 5);
      // 덜 깎았으면 기록하지 않는다.
      expect(actions.abyssScoreFor(s, s.copyWith(abyssBossBest: 200)), isNull);
    });

    test('층이 잘린 업로드의 보스 피해는 버린다 · 범위를 자른다', () {
      final s = stored();
      final forged = s.copyWith(abyssFloor: 999, abyssBossBest: 900);
      expect(actions.mergeSave(s, forged.toJson()).save!.abyssBossBest, 0);
      final json = s.toJson()..['abyssBossBest'] = 5000;
      expect(actions.mergeSave(s, json).save!.abyssBossBest, 999);
    });

    test('끝난 주만 한 번 판정 · 10위까지 젤리', () {
      final s = stored().copyWith(abyssScoreWeek: '2026-09-21');
      expect(actions.abyssRewardDueWeek(s), '2026-09-21');
      final g = actions.grantAbyssRankReward(
        s,
        '2026-09-21',
        rank: 1,
        floor: 40,
      );
      final jelly = cfg.run.abyss.rankJelly(1);
      expect(g.save!.materialCount(MaterialKind.jelly), jelly);
      expect(g.save!.abyssRewardWeek, '2026-09-21');
      expect(actions.abyssRewardDueWeek(g.save!), isNull);
      // 순위권 밖 — 젤리 없이 판정 기록만.
      final out = actions.grantAbyssRankReward(
        s,
        '2026-09-21',
        rank: 11,
        floor: 40,
      );
      expect(out.save!.materialCount(MaterialKind.jelly), 0);
      expect(out.save!.abyssRewardWeek, '2026-09-21');
      // 이번 주는 아직 판정하지 않는다.
      expect(
        actions.abyssRewardDueWeek(s.copyWith(abyssScoreWeek: week)),
        isNull,
      );
    });

    test('판정 기록은 서버 소유 — 앱이 지워 올려도 되살아난다', () {
      final s = stored().copyWith(
        abyssScoreWeek: week,
        abyssRewardWeek: '2026-09-21',
      );
      final json = s.toJson()
        ..remove('abyssScoreWeek')
        ..remove('abyssRewardWeek');
      final r = actions.mergeSave(s, json);
      expect(r.save!.abyssScoreWeek, week);
      expect(r.save!.abyssRewardWeek, '2026-09-21');
    });
  });

  test('최종 사냥터 클리어 보상 — 최종 보스 도감이 있으면 허용치에 든다', () {
    final s = SaveGame.initial(createdAt: t0).copyWith(
      lastSeen: t0.subtract(const Duration(seconds: 60)),
      zoneEpoch: kZoneEpoch,
      stageNumber: cfg.run.zoneStartStage(cfg.run.zonesPerTier),
      bestStage: cfg.run.zoneStartStage(cfg.run.zonesPerTier),
    );
    final last = cfg.roadmap!.chapters.last;
    final key = chapterClearKey(last.id, 0);
    final client = s.copyWith(
      bossDex: {cfg.run.bossArtId(0, cfg.run.zonesPerTier)},
      clearedChapters: {key},
      gold: s.gold + chapterClearGold(cfg.run, last, 0),
    );
    final r = actions.mergeSave(s, client.toJson());
    expect(r.extra['clamped'], isFalse);
  });
}
