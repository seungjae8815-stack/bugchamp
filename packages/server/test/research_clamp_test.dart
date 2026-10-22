// 연구소 사냥 분야(골드·공격…)를 다 찍은 계정의 정당한 60초 수입이 업로드 골드 상한에 잘리지 않는다(설계 §8).
//
// 봉투(`_envelopeStats`)가 연구 배율을 모르면 연구 골드 +30% 만큼 정당한 수입이 1분 뒤 되돌아간다.
// 실제 유저 쪽은 `core_run/tool/clamp_check.dart --research` 와 같은 가정(펫 x4 · 장비 x3 · 광폭화 · 골드러시 ·
// 탭 부스트 최대 · 접속 보너스 + 연구 최대)이다.
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:server/src/actions.dart';
import 'package:server/src/game_config.dart';
import 'package:test/test.dart';

final t0 = DateTime.utc(2026, 10, 22, 12);

void main() {
  late GameConfig cfg;
  late GameActions actions;
  late Map<String, int> maxed;
  late ResearchEffects fx;

  setUpAll(() async {
    cfg = await GameConfig.load(dir: '../app/assets/data');
    actions = GameActions(config: cfg, now: () => t0);
    maxed = {for (final d in cfg.research!.defs) d.id: d.maxLevel};
    fx = researchEffects(cfg.research!, maxed);
  });

  const fill = [0.5, 0.65, 0.75, 0.85];

  SaveGame storedAt(int tier, int zone, {required bool research}) {
    final run = cfg.run;
    final stage = run.zoneStartStage(zone);
    return SaveGame.initial(createdAt: t0).copyWith(
      lastSeen: t0.subtract(const Duration(seconds: 60)),
      difficultyTier: tier,
      maxTierReached: tier,
      stageNumber: stage,
      bestStage: stage,
      upgradeLevels: {
        for (final e in run.upgrades.entries)
          e.key: ((e.value.maxLevel ?? 100) * fill[tier]).round(),
      },
      gold: 1000000,
      level: 30,
      nextGiftAt: t0.add(const Duration(minutes: 5)),
      researchLevels: research ? maxed : const {},
    );
  }

  test('연구를 다 찍은 계정의 열심히 한 60초 수입(clamp_check 가정)은 잘리지 않는다', () {
    final run = cfg.run;
    const petAtk = 4.04, frenzy = 1.8, goldRush = 2.0, gearDps = 3.0;
    for (var tier = 0; tier < run.zoneTiers.length; tier++) {
      for (final zone in [1, 6, run.zonesPerTier]) {
        final stored = storedAt(tier, zone, research: true);
        final stage = stored.stageNumber;
        final s = applyResearchStats(
          deriveStats(
            run,
            upgradeLevels: stored.upgradeLevels,
            characterLevel: 30,
            bugsCollected: stored.bugBuffCount,
          ),
          fx,
        );
        final hit = baselineHitPower(s) * petAtk;
        final dps = hit * s.attackSpeed * frenzy * run.boostMultMax * gearDps;
        final speedMul = 1 + (run.boostMultMax - 1) * run.boostSpeedFactor;
        final hp = habitatMaxHp(run, stage - 1, tier: tier).toDouble();
        final perKill = hp / dps + 0.6 / speedMul;
        final goldPerKill =
            rewardGold(
              run,
              stage - 1,
              goldRush * s.rewardMultiplier,
              tier: tier,
            ) *
            (1 + run.onlineGoldBonus);
        final actual = (60 / perKill * goldPerKill).round();
        final client = stored.copyWith(gold: stored.gold + actual);
        final r = actions.mergeSave(stored, client.toJson());
        expect(
          r.save!.gold,
          client.gold,
          reason: '난이도 $tier 사냥터 $zone: ${r.extra['clampDetail']}',
        );
      }
    }
  });

  test('봉투가 연구 골드 배율을 탄다 — 연구 없는 봉투의 1.2배는 연구 계정만 통과한다', () {
    final run = cfg.run;
    for (final (tier, zone) in [(0, 6), (2, 1), (3, run.zonesPerTier)]) {
      final bare = storedAt(tier, zone, research: false);
      final envBare = deriveStats(
        run,
        upgradeLevels: bare.upgradeLevels,
        characterLevel: bare.level,
        bugsCollected: bare.bugBuffCount,
      );
      final generous = simulateIdleProgress(
        config: run,
        startStage: bare.stageNumber,
        stats: CharacterStats(
          attack: envBare.attack * 100,
          attackSpeed: envBare.attackSpeed,
          rewardMultiplier: envBare.rewardMultiplier,
          critChance: envBare.critChance,
          critDamage: envBare.critDamage,
          bossDamage: envBare.bossDamage,
          maxHp: envBare.maxHp,
          defense: envBare.defense,
          hpRegen: envBare.hpRegen,
          xpMultiplier: envBare.xpMultiplier,
          bugFind: envBare.bugFind,
          materialFind: envBare.materialFind,
          evade: envBare.evade,
          boostBonus: envBare.boostBonus,
        ),
        elapsed: const Duration(seconds: 60),
        efficiency: 30,
        tier: tier,
      ).gold;
      final gain = GameActions.goldUploadCap + (generous * 1.2).round();

      final noResearch = actions.mergeSave(
        bare,
        bare.copyWith(gold: bare.gold + gain).toJson(),
      );
      expect(noResearch.extra['clampReasons'], contains('gold'));

      final withResearch = storedAt(tier, zone, research: true);
      final ok = actions.mergeSave(
        withResearch,
        withResearch.copyWith(gold: withResearch.gold + gain).toJson(),
      );
      expect(ok.save!.gold, withResearch.gold + gain, reason: '$tier·$zone');

      // 저장본엔 연구가 없고 이번 업로드에서 처음 올라온 레벨도 봉투에 든다(max(저장본, 클라)).
      final fresh = actions.mergeSave(
        bare,
        bare.copyWith(gold: bare.gold + gain, researchLevels: maxed).toJson(),
      );
      expect(fresh.save!.gold, bare.gold + gain, reason: '$tier·$zone 새 레벨');
    }
  });

  test('방치 정산(sync)은 연구 골드·방치 효율을 곱한다', () {
    final run = cfg.run;
    final base = storedAt(
      1,
      5,
      research: false,
    ).copyWith(lastSeen: t0.subtract(const Duration(hours: 2)));
    final a = actions.sync(base).save!;
    final b = actions.sync(base.copyWith(researchLevels: maxed)).save!;
    final gainA = a.gold - base.gold;
    final gainB = b.gold - base.gold;
    final mult =
        (1 + fx.of(ResearchEffect.gold)) * (1 + fx.of(ResearchEffect.offline));
    expect(gainA, greaterThan(0));
    expect(gainB / gainA, closeTo(mult, 0.01));
    expect(run.offlineEfficiency, greaterThan(0));
  });
}
