// 젤리 업로드 허용치(2026-10-23) — 업로드당 정액 300 대신 근거 있는 기기 수입 + 시간으로만 차오르는 여유(시간당 2 · 최대 20).
// 예전엔 60초마다 +300 위조가 통과해 하루 43만 젤리였고, 그 젤리가 결투 연구 즉시 완료를 샀다.
import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:server/src/actions.dart';
import 'package:server/src/game_config.dart';
import 'package:test/test.dart';

final t0 = DateTime.utc(2026, 10, 23, 3);

void main() {
  late GameConfig cfg;

  setUpAll(() async {
    cfg = await GameConfig.load(dir: '../app/assets/data');
  });

  SaveGame stored({int jelly = 100, DateTime? lastSeen}) =>
      SaveGame.initial(
        createdAt: t0.subtract(const Duration(days: 40)),
      ).copyWith(
        lastSeen: lastSeen ?? t0.subtract(const Duration(seconds: 60)),
        zoneEpoch: kZoneEpoch,
        materials: {MaterialKind.jelly: jelly},
      );

  SaveGame upAt(DateTime t, SaveGame s, SaveGame client) {
    final r = GameActions(
      config: cfg,
      now: () => t,
    ).mergeSave(s, client.toJson());
    expect(r.isOk, isTrue, reason: r.error);
    return r.save!;
  }

  SaveGame withJelly(SaveGame s, int jelly) =>
      s.copyWith(materials: {...s.materials, MaterialKind.jelly: jelly});

  test('근거 없는 +300 위조는 저장본 + 여유(20)까지만 — 바로 다음 업로드는 0', () {
    var s = stored();
    s = upAt(t0, s, withJelly(s, 400));
    expect(s.materialCount(MaterialKind.jelly), 120);
    expect(s.jellySlackAt, isNotNull);
    // 60초 뒤 다시 +300 — 여유가 시간당 2 라 아직 0.
    final t1 = t0.add(const Duration(seconds: 60));
    s = upAt(t1, s.copyWith(lastSeen: t0), withJelly(s, 420));
    expect(s.materialCount(MaterialKind.jelly), 120);
    // 60초마다 하루 동안 올려도 하루 몫은 시간당 2 × 24 = 48 을 넘지 못한다.
    var t = t1;
    for (var i = 0; i < 24 * 60; i++) {
      t = t.add(const Duration(seconds: 60));
      final have = s.materialCount(MaterialKind.jelly);
      s = upAt(t, s, withJelly(s, have + 300));
    }
    expect(s.materialCount(MaterialKind.jelly), lessThanOrEqualTo(120 + 48));
  });

  test('앱이 기준 시각(jSA)을 고쳐 올려도 서버 값이 남는다', () {
    var s = stored();
    s = upAt(t0, s, withJelly(s, 400));
    final at = s.jellySlackAt;
    final t1 = t0.add(const Duration(seconds: 60));
    final json = withJelly(s, 400).toJson()
      ..['jSA'] = t0.subtract(const Duration(days: 30)).toIso8601String();
    final r = GameActions(config: cfg, now: () => t1).mergeSave(s, json);
    expect(r.save!.materialCount(MaterialKind.jelly), 120);
    expect(r.save!.jellySlackAt, at);
  });

  test('긴 공백(3일) 뒤에도 근거 없는 증가는 여유 최대 20 까지', () {
    final s = stored(lastSeen: t0.subtract(const Duration(days: 3)));
    final out = upAt(t0, s, withJelly(s, 1000));
    expect(out.materialCount(MaterialKind.jelly), 120);
  });

  test('여유는 시간으로 다시 찬다 — 10시간 뒤 다시 20', () {
    var s = stored();
    s = upAt(t0, s, withJelly(s, 120));
    expect(s.materialCount(MaterialKind.jelly), 120);
    final t1 = t0.add(const Duration(hours: 10));
    s = upAt(t1, s, withJelly(s, 140));
    expect(s.materialCount(MaterialKind.jelly), 140);
  });

  test('정직한 기기 수입(패스 일일·미션·선물 첫 2배·도감 보스·최종 사냥터 클리어)은 같은 업로드에 다 받는다', () {
    final today = dailyDateKey(t0);
    final run = cfg.run;
    final roadmap = cfg.roadmap!;
    final dexMs = cfg.dex!.bossMilestones.first;
    final forge = cfg.mission!.missions.firstWhere((d) => d.reward == 'jelly');
    final last = roadmap.chapters.last;
    final base = stored().copyWith(
      passExpiresAt: t0.add(const Duration(days: 10)),
      // 쉬움 최종 사냥터에 있다(보스 도전 직전).
      stageNumber: run.zoneStartStage(run.zonesPerTier),
      bestStage: run.zoneStartStage(run.zonesPerTier),
      bossDex: {for (var z = 1; z < run.zonesPerTier; z++) run.bossArtId(0, z)},
    );
    final income =
        cfg.iap.passDailyJelly +
        forge.rewardAt(0) +
        cfg.gift!.doubleJellyMax +
        dexMs.jelly +
        last.rewardJelly;
    expect(last.rewardJelly, greaterThan(0));
    final client = withJelly(base, 100 + income).copyWith(
      dailyClaims: {'_iapDaily': today, missionJellyKey(forge.id, 0): today},
      giftDoubleDate: today,
      giftDoubleCount: 1,
      claimedDex: {dexMs.id},
      bossDex: {...base.bossDex, run.bossArtId(0, run.zonesPerTier)},
      clearedChapters: {
        for (final ch in roadmap.chapters) chapterClearKey(ch.id, 0),
      },
    );
    final out = upAt(t0, base, client);
    expect(out.materialCount(MaterialKind.jelly), 100 + income);
    // 근거로 설명되는 몫은 여유를 쓰지 않는다.
    expect(out.jellySlackAt, isNull);
  });

  IndividualBug five(String id) => IndividualBug(
    id: id,
    speciesId: 'stag_giant',
    sizeMm: 60,
    potential: 5,
    temperament: Temperament.cunning,
    sex: Sex.male,
    stage: LifeStage.adult,
  );

  test('저장본에 있던 5성 10마리를 한 업로드에 분해하면 젤리를 다 받는다(여유와 따로)', () {
    final per = cfg.pet.disassembleJelly(5);
    expect(per, greaterThan(0));
    final base = stored().copyWith(
      bugs: [for (var i = 0; i < 10; i++) five('s$i')],
    );
    final client = withJelly(base, 100 + 10 * per).copyWith(bugs: const []);
    final out = upAt(t0, base, client);
    expect(out.materialCount(MaterialKind.jelly), 100 + 10 * per);
    expect(out.jellySlackAt, isNull, reason: '근거로 설명되면 여유를 안 쓴다');
  });

  test('저장본에 없던 곤충(업로드 사이에만 있던 5성)은 분해 근거가 아니다', () {
    // 여유를 먼저 다 쓴다.
    var s = stored();
    s = upAt(t0, s, withJelly(s, 120));
    final t1 = t0.add(const Duration(seconds: 60));
    // 업로드 사이에 5성을 만들어 분해했다고 젤리만 올린다 — 서버가 모르는 곤충이라 0.
    s = upAt(t1, s, withJelly(s, 120 + 3 * cfg.pet.disassembleJelly(5)));
    expect(s.materialCount(MaterialKind.jelly), 120);
    // 이번 업로드에 새로 넣은 곤충도 이번 업로드에서는 분해 근거가 아니다.
    final t2 = t1.add(const Duration(seconds: 60));
    final withBug = withJelly(s, 130).copyWith(bugs: [five('new1')]);
    s = upAt(t2, s, withBug);
    expect(s.materialCount(MaterialKind.jelly), 120);
  });

  test('개체 등급 시대(ng) 뽑기 아닌 5성을 넣었다 다음 업로드에 지우면 분해 근거 0', () {
    // 여유를 먼저 다 쓴다.
    var s = stored();
    s = upAt(t0, s, withJelly(s, 120));
    final t1 = t0.add(const Duration(seconds: 60));
    final fake = [
      for (var i = 0; i < 10; i++) five('f$i').copyWith(newGen: true),
    ];
    s = upAt(t1, s, s.copyWith(bugs: fake));
    expect(s.bugs.length, 10);
    final t2 = t1.add(const Duration(seconds: 60));
    s = upAt(t2, s, withJelly(s, 150).copyWith(bugs: const []));
    expect(s.materialCount(MaterialKind.jelly), 120);
    // 뽑기 출신(gc)이면 산 젤리가 따로 잡히므로 그대로 센다.
    final gacha = stored().copyWith(
      bugs: [five('g1').copyWith(newGen: true, fromGacha: true)],
    );
    final out = upAt(
      t0,
      gacha,
      withJelly(
        gacha,
        100 + cfg.pet.disassembleJelly(5),
      ).copyWith(bugs: const []),
    );
    expect(
      out.materialCount(MaterialKind.jelly),
      100 + cfg.pet.disassembleJelly(5),
    );
  });

  test('옛 5성 분해 근거는 서버 하루 60 까지 — 다음 날 다시', () {
    final per = cfg.pet.disassembleJelly(5);
    expect(per * 20, 60, reason: '상한 = 5성 20마리');
    // 여유를 먼저 다 써서 분해 근거만 보이게 한다.
    var s = stored().copyWith(bugs: [for (var i = 0; i < 30; i++) five('o$i')]);
    s = upAt(t0, s, withJelly(s, 120));
    final t1 = t0.add(const Duration(seconds: 60));
    s = upAt(t1, s, withJelly(s, 120 + 30 * per).copyWith(bugs: const []));
    expect(s.materialCount(MaterialKind.jelly), 180);
    expect(s.salvageJellyCount, 60);
    // 같은 날 더 분해해도 근거 0.
    final more = s.copyWith(bugs: [for (var i = 0; i < 5; i++) five('m$i')]);
    final t2 = t1.add(const Duration(seconds: 60));
    final s2 = upAt(
      t2,
      more,
      withJelly(more, 180 + 5 * per).copyWith(bugs: const []),
    );
    expect(s2.materialCount(MaterialKind.jelly), 180);
    // 다음 날은 다시 센다.
    final t3 = t1.add(const Duration(days: 1));
    final s3 = upAt(
      t3,
      more.copyWith(jellySlackAt: t3),
      withJelly(more, 180 + 5 * per).copyWith(bugs: const []),
    );
    expect(s3.materialCount(MaterialKind.jelly), 180 + 5 * per);
  });

  // 여유를 먼저 다 쓴 저장본(근거만 보이게).
  SaveGame drained(SaveGame s) =>
      s.copyWith(jellySlackAt: t0.add(const Duration(minutes: 5)));

  test('받은 도감 마일스톤을 지웠다 다시 넣어도 젤리 근거가 다시 열리지 않는다', () {
    final run = cfg.run;
    final ms = cfg.dex!.bossMilestones.first;
    var s = drained(stored()).copyWith(
      bossDex: {for (var z = 1; z <= 5; z++) run.bossArtId(0, z)},
      claimedDex: {ms.id},
    );
    final t1 = t0.add(const Duration(minutes: 6));
    // A: 기록을 뺀 채 올린다 — 서버는 저장본 기록을 남긴다.
    s = upAt(t1, s, s.copyWith(claimedDex: const {}));
    expect(s.claimedDex, contains(ms.id));
    // B: 다시 넣고 마일스톤 젤리를 더한다 — 근거 0.
    final t2 = t1.add(const Duration(seconds: 60));
    s = upAt(t2, s, withJelly(s, 100 + ms.jelly).copyWith(claimedDex: {ms.id}));
    expect(s.materialCount(MaterialKind.jelly), 100);
  });

  test('사냥터 클리어 기록을 지웠다 다시 넣어도 최종 클리어 젤리가 다시 열리지 않는다', () {
    final run = cfg.run;
    final roadmap = cfg.roadmap!;
    final keys = {for (final ch in roadmap.chapters) chapterClearKey(ch.id, 0)};
    var s = drained(stored()).copyWith(
      stageNumber: run.zoneStartStage(run.zonesPerTier),
      bestStage: run.zoneStartStage(run.zonesPerTier),
      bossDex: {run.bossArtId(0, run.zonesPerTier)},
      clearedChapters: keys,
    );
    final t1 = t0.add(const Duration(minutes: 6));
    s = upAt(t1, s, s.copyWith(clearedChapters: const {}));
    expect(s.clearedChapters, containsAll(keys));
    final t2 = t1.add(const Duration(seconds: 60));
    s = upAt(
      t2,
      s,
      withJelly(
        s,
        100 + roadmap.chapters.last.rewardJelly,
      ).copyWith(clearedChapters: keys),
    );
    expect(s.materialCount(MaterialKind.jelly), 100);
  });

  test('지금 난이도만 올린 업로드(옛 앱)도 최고 난이도에 들어선 시각을 적는다', () {
    final run = cfg.run;
    final base = stored();
    final out = upAt(
      t0,
      base,
      base.copyWith(
        difficultyTier: 1,
        bossDex: {run.bossArtId(0, run.zonesPerTier)},
      ),
    );
    expect(out.topTier, 1);
    expect(out.topTierAt, t0);
  });

  test('최종 보스를 잡고 같은 업로드에 다음 난이도로 — 앞 난이도 최종 클리어 젤리를 인정한다', () {
    final run = cfg.run;
    final roadmap = cfg.roadmap!;
    final last = roadmap.chapters.last;
    final base = drained(stored()).copyWith(
      stageNumber: run.zoneStartStage(run.zonesPerTier),
      bestStage: run.zoneStartStage(run.zonesPerTier),
      clearedChapters: {
        for (final ch in roadmap.chapters)
          if (!identical(ch, last)) chapterClearKey(ch.id, 0),
      },
    );
    final client = withJelly(base, 100 + last.rewardJelly).copyWith(
      difficultyTier: 1,
      maxTierReached: 1,
      stageNumber: 1,
      bestStage: 0,
      bossDex: {run.bossArtId(0, run.zonesPerTier)},
      clearedChapters: {...base.clearedChapters, chapterClearKey(last.id, 0)},
    );
    final out = upAt(t0.add(const Duration(minutes: 6)), base, client);
    expect(out.maxTierReached, 1);
    expect(out.materialCount(MaterialKind.jelly), 100 + last.rewardJelly);
  });

  test('업로드 상한 노출값은 여유 최대치', () {
    expect(GameActions.uploadCapFor(MaterialKind.jelly), 20);
  });
}
