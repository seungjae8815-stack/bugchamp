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

  test('업로드 상한 노출값은 여유 최대치', () {
    expect(GameActions.uploadCapFor(MaterialKind.jelly), 20);
  });
}
