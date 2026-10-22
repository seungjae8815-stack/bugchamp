import 'dart:convert';
import 'dart:io';

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:test/test.dart';

/// 연구소 추가 연구 2부(설계 §10) — 제련 비법 · 별빛 연마 · 절약 다듬기 · 분해 기술 · 교환 협상 · 선물 감각 · 확률 보조.
/// 효과마다 "연구 0 이면 그대로 · 다 찍으면 기대 배율". 실데이터(research.json 최대치)로 돈다.
Map<String, dynamic> _json(String f) =>
    jsonDecode(File('../app/assets/data/$f').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  final forge = ForgeConfig.fromJson(_json('forge.json'));
  final items = ItemConfig.fromJson(_json('items.json'));
  final pets = PetConfig.fromJson(_json('pets.json'));
  final run = RunConfig.fromJson(_json('run_config.json'));
  final rc = ResearchConfig.fromJson(_json('research.json'));
  final maxed = researchEffects(rc, {
    for (final d in rc.defs) d.id: d.maxLevel,
  });
  const none = ResearchEffects.none;
  double v(ResearchEffect e) => maxed.of(e);

  test('실데이터 최대치 — 시간·비용 단축은 0.5 이하, 수량·확률 보너스는 양수', () {
    for (final e in [
      ResearchEffect.forgeTime,
      ResearchEffect.starTime,
      ResearchEffect.polishCost,
    ]) {
      expect(v(e), greaterThan(0), reason: e.key);
      expect(v(e), lessThanOrEqualTo(kResearchTimeCutMax), reason: e.key);
    }
    for (final e in [
      ResearchEffect.traitChance,
      ResearchEffect.potionChance,
      ResearchEffect.salvageMat,
      ResearchEffect.exchangeGain,
      ResearchEffect.giftGold,
    ]) {
      expect(v(e), greaterThan(0), reason: e.key);
    }
  });

  test('제련 비법 — 공방 등급업·초월 시간(0 이면 그대로, 최대면 × (1 − v) 올림)', () {
    for (final (lv, t) in [(0, 0), (5, 0), (12, 0), (3, 2)]) {
      final base = forge.levelUpDuration(lv, transcend: t);
      expect(forge.levelUpDuration(lv, transcend: t, research: none), base);
      expect(
        forge.levelUpDuration(lv, transcend: t, research: maxed).inSeconds,
        (base.inSeconds * (1 - v(ResearchEffect.forgeTime))).ceil(),
      );
    }
    for (var n = 0; n < forge.transcendMax; n++) {
      final base = forge.transcendDuration(n);
      expect(
        base,
        Duration(
          hours: forge.transcendBaseHours + forge.transcendStepHours * n,
        ),
      );
      expect(
        forge.transcendDuration(n, research: maxed).inSeconds,
        (base.inSeconds * (1 - v(ResearchEffect.forgeTime))).ceil(),
      );
    }
    // 다른 연구(별빛 연마)는 공방 시간을 건드리지 않는다.
    final starOnly = researchEffects(rc, {'starPolish': 30});
    expect(
      forge.levelUpDuration(5, research: starOnly),
      forge.levelUpDuration(5),
    );
  });

  test('별빛 연마 — 별 강화 시간 · startStarUp 이 같은 값을 쓴다', () {
    for (final (stars, tier) in [(0, 9), (2, 4), (4, 0)]) {
      final base = items.starUpDuration(stars, tier: tier);
      expect(items.starUpDuration(stars, tier: tier, research: none), base);
      expect(
        items.starUpDuration(stars, tier: tier, research: maxed).inSeconds,
        (base.inSeconds * (1 - v(ResearchEffect.starTime))).ceil(),
      );
    }
    final now = DateTime.utc(2026, 10, 23);
    final ready = EquipItem(
      slot: EquipSlot.tool,
      tier: 9,
      starExp: items.starNeedAt(0),
      options: const [ItemOption(kind: ItemOptionKind.attack, value: 5)],
    );
    final a = startStarUp(items, ready, now)!;
    final b = startStarUp(items, ready, now, research: maxed)!;
    expect(a.starUntil, now.add(items.starUpDuration(0, tier: 9)));
    expect(
      b.starUntil,
      now.add(items.starUpDuration(0, tier: 9, research: maxed)),
    );
    expect(b.starUntil!.isBefore(a.starUntil!), isTrue);
  });

  test('절약 다듬기 — 화석 올림 · 젤리 5·10 단위 · 원래보다 늘지 않는다', () {
    final cut = v(ResearchEffect.polishCost);
    for (final tier in [0, 4, 9]) {
      for (final pick in [false, true]) {
        for (var done = 0; done <= items.polishMaxStacks; done++) {
          final base = forge.polishCost(tier, pickKind: pick, done: done);
          expect(
            forge.polishCost(tier, pickKind: pick, done: done, research: none),
            base,
          );
          final r = forge.polishCost(
            tier,
            pickKind: pick,
            done: done,
            research: maxed,
          );
          final g = forge.polishCostGrowth;
          var raw = forge.polishFossilPerTier * (tier + 1) * 1.0;
          if (pick) raw *= forge.polishKindMult;
          for (var i = 0; i < done; i++) {
            raw *= g;
          }
          expect(r.fossils, (raw * (1 - cut)).ceil(), reason: '$tier·$done');
          expect(r.fossils, lessThan(base.fossils));
          expect(r.jelly % 5, 0, reason: '젤리 가격표(roundJellyCost)');
          expect(r.jelly, lessThanOrEqualTo(base.jelly));
          expect(r.jelly, greaterThanOrEqualTo(5));
        }
      }
    }
  });

  test('분해 기술 — 방생 재료 × (1 + v) 반올림(0 이면 그대로)', () {
    for (final g in Grade.values) {
      final base = pets.releaseMaterial(g);
      expect(pets.releaseMaterial(g, research: none), base);
      expect(
        pets.releaseMaterial(g, research: maxed),
        (base * (1 + v(ResearchEffect.salvageMat))).round(),
      );
    }
  });

  test('교환 협상 — 교환소 골드·재료 × (1 + v)', () {
    final stats = deriveStats(
      run,
      upgradeLevels: {for (final k in UpgradeKind.values) k: 100},
      characterLevel: 30,
      bugsCollected: 0,
    );
    final stage = run.zoneStartStage(6);
    final base = exchangeOutput(run, stats: stats, stage: stage, trades: 3);
    expect(
      exchangeOutput(
        run,
        stats: stats,
        stage: stage,
        trades: 3,
        research: none,
      ),
      base,
    );
    final r = exchangeOutput(
      run,
      stats: stats,
      stage: stage,
      trades: 3,
      research: maxed,
    );
    final m = 1 + v(ResearchEffect.exchangeGain);
    expect(r.gold, (base.gold * m).round());
    expect(r.materialsEach, (base.materialsEach * m).round());
  });

  test('수량·확률 보조 — 0 이면 그대로 · 확률은 1 로 자른다', () {
    expect(researchScaledAmount(100, none, ResearchEffect.giftGold), 100);
    expect(
      researchScaledAmount(100, maxed, ResearchEffect.giftGold),
      (100 * (1 + v(ResearchEffect.giftGold))).round(),
    );
    expect(researchScaledAmount(0, maxed, ResearchEffect.giftGold), 0);
    // 선물 감각 공용 함수(앱 지급·서버 상한 공용).
    expect(giftRewardScaled((gold: 1000, materialsEach: 50), none), (
      gold: 1000,
      materialsEach: 50,
    ));
    final m = 1 + v(ResearchEffect.giftGold);
    expect(giftRewardScaled((gold: 1000, materialsEach: 50), maxed), (
      gold: (1000 * m).round(),
      materialsEach: (50 * m).round(),
    ));
    expect(giftAmountScaled(1000, maxed), (1000 * m).round());
    expect(researchScaledChance(0.1, none, ResearchEffect.traitChance), 0.1);
    expect(
      researchScaledChance(0.1, maxed, ResearchEffect.traitChance),
      closeTo(0.1 * (1 + v(ResearchEffect.traitChance)), 1e-12),
    );
    expect(researchScaledChance(0.9, maxed, ResearchEffect.traitChance), 1.0);
  });
}
