import 'dart:math';

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:test/test.dart';

/// 연구소 진행 규칙(`research_progress.dart`) — 작은 가짜 설정으로 규칙만 본다.
void main() {
  const a = ResearchDef(
    id: 'a',
    branch: ResearchBranch.hunt,
    effect: ResearchEffect.huntAtk,
    maxLevel: 3,
    perLevel: 0.01,
    firstSeconds: 600,
    timeGrowth: 2,
    samplesFirst: 2,
    goldMinutesFirst: 10,
    materialMinutesFirst: 5,
    fossilFrom: 2,
    fossilFirst: 4,
    costGrowth: 2,
  );
  const b = ResearchDef(
    id: 'b',
    branch: ResearchBranch.hunt,
    effect: ResearchEffect.gold,
    maxLevel: 2,
    requires: (id: 'a', level: 2),
    perLevel: 0.01,
    firstSeconds: 60,
    samplesFirst: 1,
  );
  const speed = ResearchDef(
    id: 'sp',
    branch: ResearchBranch.hunt,
    effect: ResearchEffect.researchTime,
    maxLevel: 2,
    perLevel: 0.1,
    firstSeconds: 60,
    samplesFirst: 1,
  );
  const cfg = ResearchConfig(
    defs: [a, b, speed],
    slotsByTier: [1, 1, 2, 3],
    slotJelly: [100, 300],
    eliteDropChance: 0.5,
    eliteDropAmount: 1,
    bossFirstDrop: 5,
    bossRepeatDrop: 2,
    bossRepeatChance: 0.5,
  );
  final t = DateTime.utc(2026, 10, 22, 12);

  ({int gold, int materialsEach}) top(double m) =>
      (gold: (m * 100).round(), materialsEach: (m * 10).round());

  SaveGame rich({int tier = 0}) => SaveGame.initial(createdAt: t).copyWith(
    gold: 100000,
    maxTierReached: tier,
    researchSamples: 50,
    materials: const {
      MaterialKind.chitin: 1000,
      MaterialKind.mineral: 1000,
      MaterialKind.sap: 1000,
      MaterialKind.fossil: 100,
      MaterialKind.jelly: 1000,
    },
  );

  ResearchPrice priceOf(SaveGame s, String id) =>
      researchPrice(s, cfg, id, huntAtTop: top);

  test('roundtrip_json', () {
    final base = SaveGame.initial(createdAt: t);
    final j = base.toJson();
    for (final k in ['rsL', 'rsS', 'rsC', 'rsB', 'researchPassExpiresAt']) {
      expect(j.containsKey(k), isFalse, reason: k);
    }
    final s = base.copyWith(
      researchLevels: const {'a': 2},
      researchSlots: [ResearchSlot(id: 'a', level: 3, endsAt: t)],
      researchSamples: 7,
      researchSlotsBought: 1,
      researchPassExpiresAt: t.add(const Duration(days: 30)),
    );
    final back = SaveGame.fromJson(s.toJson());
    expect(back.researchLevels, {'a': 2});
    expect(back.researchSlots.single.id, 'a');
    expect(back.researchSlots.single.level, 3);
    expect(back.researchSlots.single.endsAt, t);
    expect(back.researchSamples, 7);
    expect(back.researchSlotsBought, 1);
    expect(back.researchPassActive(t), isTrue);
    expect(back.researchPassActive(t.add(const Duration(days: 31))), isFalse);
    expect(back.toJson(), s.toJson());
  });

  test('start_spends_and_sets_slot', () {
    final s = rich();
    final p = priceOf(s, 'a');
    expect(p.level, 1);
    final r = startResearch(s, cfg, 'a', t, p);
    expect(r.isOk, isTrue);
    final n = r.save!;
    expect(n.researchSamples, 50 - p.samples);
    expect(n.gold, 100000 - p.gold);
    for (final m in kRegularMaterials) {
      expect(n.materialCount(m), 1000 - p.materialsEach);
    }
    expect(n.materialCount(MaterialKind.fossil), 100);
    expect(n.researchSlots.single.endsAt, t.add(p.time));
    expect(n.researchSlots.single.level, 1);
  });

  test('start_fails_not_enough', () {
    final s = rich().copyWith(researchSamples: 0);
    final r = startResearch(s, cfg, 'a', t, priceOf(s, 'a'));
    expect(r.error, 'not_enough');
  });

  test('start_fails_slots_full', () {
    final s = rich().copyWith(
      researchLevels: const {'a': 2},
      researchSlots: [
        ResearchSlot(
          id: 'sp',
          level: 1,
          endsAt: t.add(const Duration(hours: 1)),
        ),
      ],
    );
    final r = startResearch(s, cfg, 'b', t, priceOf(s, 'b'));
    expect(r.error, 'slots_full');
  });

  test('start_fails_already_running', () {
    final s = rich(tier: 3).copyWith(
      researchSlots: [
        ResearchSlot(
          id: 'a',
          level: 1,
          endsAt: t.add(const Duration(hours: 1)),
        ),
      ],
    );
    final r = startResearch(s, cfg, 'a', t, priceOf(s, 'a'));
    expect(r.error, 'already_running');
  });

  test('start_fails_locked', () {
    final s = rich().copyWith(researchLevels: const {'a': 1});
    final r = startResearch(s, cfg, 'b', t, priceOf(s, 'b'));
    expect(r.error, 'locked');
  });

  test('start_fails_max_level', () {
    final s = rich().copyWith(researchLevels: const {'sp': 2});
    final r = startResearch(
      s,
      cfg,
      'sp',
      t,
      const ResearchPrice(
        samples: 0,
        gold: 0,
        materialsEach: 0,
        fossil: 0,
        time: Duration(seconds: 1),
        level: 3,
      ),
    );
    expect(r.error, 'max_level');
  });

  test('claim_after_end_levels_up', () {
    final s = rich();
    final n = startResearch(s, cfg, 'a', t, priceOf(s, 'a')).save!;
    final end = n.researchSlots.single.endsAt;
    final c = claimResearch(n, cfg, end);
    expect(c.researchLevels['a'], 1);
    expect(c.researchSlots, isEmpty);
  });

  test('claim_before_end_noop', () {
    final s = rich();
    final n = startResearch(s, cfg, 'a', t, priceOf(s, 'a')).save!;
    final c = claimResearch(n, cfg, t.add(const Duration(seconds: 1)));
    expect(c.researchLevels, isEmpty);
    expect(c.researchSlots.length, 1);
  });

  test('finish_now_spends_jelly', () {
    final s = rich();
    final n = startResearch(s, cfg, 'a', t, priceOf(s, 'a')).save!;
    final now = t.add(const Duration(minutes: 1));
    final remaining = n.researchSlots.single.endsAt.difference(now);
    final cost = cfg.instantJelly(remaining);
    expect(cost, greaterThan(0));
    final r = finishResearchNow(n, cfg, 'a', now);
    expect(r.isOk, isTrue);
    expect(r.save!.materialCount(MaterialKind.jelly), 1000 - cost);
    expect(r.save!.researchLevels['a'], 1);
    expect(r.save!.researchSlots, isEmpty);
    final poor = n.copyWith(materials: const {MaterialKind.jelly: 0});
    expect(finishResearchNow(poor, cfg, 'a', now).error, 'not_enough_jelly');
  });

  test('buy_slot_to_three_then_max_slots', () {
    final r1 = buyResearchSlot(rich(), cfg);
    expect(r1.save!.researchSlotsBought, 1);
    expect(r1.save!.materialCount(MaterialKind.jelly), 900);
    final r2 = buyResearchSlot(r1.save!, cfg);
    expect(r2.save!.researchSlotsBought, 2);
    expect(r2.save!.materialCount(MaterialKind.jelly), 600);
    expect(buyResearchSlot(r2.save!, cfg).error, 'max_slots');
    final poor = rich().copyWith(materials: const {MaterialKind.jelly: 5});
    expect(buyResearchSlot(poor, cfg).error, 'not_enough_jelly');
    // 진행도로 이미 3칸이면 사 봐야 소용없다.
    expect(buyResearchSlot(rich(tier: 3), cfg).error, 'max_slots');
  });

  test('price_uses_top_zone_not_current', () {
    final s = rich();
    final p1 = priceOf(s, 'a');
    final p2 = priceOf(s.copyWith(stageNumber: 301, zoneKills: 50), 'a');
    expect(p1.gold, p2.gold);
    expect(p1.materialsEach, p2.materialsEach);
    expect(p1.gold, 1000);
    expect(p1.materialsEach, 50);
  });

  test('price_applies_time_cut_and_fossil', () {
    final s = rich().copyWith(researchLevels: const {'a': 1, 'sp': 2});
    final p = priceOf(s, 'a');
    expect(p.level, 2);
    expect(p.fossil, 4);
    // 600 x 2 = 1200초, 연구 시간 -20%.
    expect(p.time, const Duration(seconds: 960));
  });

  test('rollResearchDrop_deterministic', () {
    List<int> run() {
      final rng = Random(7);
      return [
        for (var i = 0; i < 20; i++)
          rollResearchDrop(cfg, rng, ResearchDropSource.elite),
        rollResearchDrop(cfg, rng, ResearchDropSource.bossFirst),
        rollResearchDrop(cfg, rng, ResearchDropSource.bossRepeat),
      ];
    }

    expect(run(), run());
    expect(run()[20], 5);
    expect(run().take(20).toSet(), {0, 1});
  });

  test('start_fails_stale_price_and_negative_price', () {
    final s = rich();
    final p = priceOf(s, 'a');
    ResearchPrice with_({int? level, int? gold}) => ResearchPrice(
      samples: p.samples,
      gold: gold ?? p.gold,
      materialsEach: p.materialsEach,
      fossil: p.fossil,
      time: p.time,
      level: level ?? p.level,
    );
    final stale = startResearch(s, cfg, 'a', t, with_(level: 2));
    expect(stale.error, 'stale_price');
    expect(stale.save, isNull);
    final neg = startResearch(s, cfg, 'a', t, with_(gold: -1000));
    expect(neg.error, 'not_enough');
    expect(neg.save, isNull);
  });

  test('finish_now_after_end_is_free', () {
    final s = rich();
    final n = startResearch(s, cfg, 'a', t, priceOf(s, 'a')).save!;
    final late = n.researchSlots.single.endsAt.add(const Duration(seconds: 5));
    final r = finishResearchNow(n, cfg, 'a', late);
    expect(r.save!.materialCount(MaterialKind.jelly), 1000);
    expect(r.save!.researchLevels['a'], 1);
    expect(r.save!.researchSlots, isEmpty);
  });

  test('grant_samples', () {
    expect(grantResearchSamples(rich(), 3).researchSamples, 53);
    expect(grantResearchSamples(rich(), 0).researchSamples, 50);
  });
}
