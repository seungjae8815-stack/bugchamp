import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:server/src/actions.dart';
import 'package:server/src/game_config.dart';
import 'package:test/test.dart';

/// 교환소 허용치(2026-10-05) — 교환 1회가 "직접 사냥 1시간치"가 되어 60초 골드 상한에 잘리지 않게,
/// 서버가 **줄어든 젤리**만큼 교환을 인정한다.
void main() {
  late GameConfig cfg;
  late GameActions actions;
  final t0 = DateTime.utc(2026, 10, 5, 3);

  setUpAll(() async {
    cfg = await GameConfig.load(dir: '../app/assets/data');
    actions = GameActions(config: cfg, now: () => t0);
  });

  for (final c in [
    (tier: 1, zone: 6),
    (tier: 2, zone: 11),
    (tier: 3, zone: 11),
  ]) {
    final label = '난이도 ${c.tier} 사냥터 ${c.zone}';
    SaveGame stored() {
      final stage = cfg.run.zoneStartStage(c.zone);
      return SaveGame.initial(createdAt: t0).copyWith(
        lastSeen: t0.subtract(const Duration(seconds: 60)),
        zoneEpoch: kZoneEpoch,
        difficultyTier: c.tier,
        maxTierReached: c.tier,
        stageNumber: stage,
        bestStage: stage,
        upgradeLevels: {for (final k in UpgradeKind.values) k: 200},
        gold: 1000,
        materials: {MaterialKind.jelly: 500},
      );
    }

    // 펫·장비·도감을 갖춘 유저 — 저장본 강화만으로 잰 전력보다 공격 10배·골드 배율 5배.
    ({int gold, int materialsEach}) strongTrade(SaveGame s, int trades) {
      final b = deriveStats(
        cfg.run,
        upgradeLevels: s.upgradeLevels,
        characterLevel: s.level,
        bugsCollected: s.bugs.length,
      );
      final strong = CharacterStats(
        attack: b.attack * 10,
        attackSpeed: b.attackSpeed,
        rewardMultiplier: b.rewardMultiplier * 5,
        critChance: b.critChance,
        critDamage: b.critDamage,
        bossDamage: b.bossDamage,
        maxHp: b.maxHp,
        defense: b.defense,
        hpRegen: b.hpRegen,
        xpMultiplier: b.xpMultiplier,
        bugFind: b.bugFind,
        materialFind: b.materialFind * 3,
        evade: b.evade,
        boostBonus: b.boostBonus,
      );
      return exchangeOutput(
        cfg.run,
        stats: strong,
        stage: s.stageNumber,
        trades: trades,
        tier: c.tier,
      );
    }

    test('$label — 젤리 100(교환 10회) 골드는 잘리지 않는다', () {
      final s = stored();
      final out = strongTrade(s, 10);
      final client = s.copyWith(
        gold: s.gold + out.gold,
        materials: {MaterialKind.jelly: 400},
      );
      final r = actions.mergeSave(s, client.toJson());
      expect(r.extra['clampReasons'] ?? const [], isNot(contains('gold')));
      expect(r.save!.gold, s.gold + out.gold);
    });

    test('$label — 젤리 100(교환 10회) 재료는 잘리지 않는다', () {
      final s = stored();
      final out = strongTrade(s, 10);
      final client = s.copyWith(
        materials: {
          MaterialKind.jelly: 400,
          MaterialKind.chitin: out.materialsEach,
          MaterialKind.mineral: out.materialsEach,
          MaterialKind.sap: out.materialsEach,
        },
      );
      final r = actions.mergeSave(s, client.toJson());
      expect(
        (r.extra['clampReasons'] as List? ?? const []).where(
          (e) => '$e'.startsWith('material'),
        ),
        isEmpty,
      );
    });

    test('$label — 젤리를 안 쓰고 올린 같은 골드는 잘린다', () {
      final s = stored();
      final out = strongTrade(s, 10);
      final r = actions.mergeSave(
        s,
        s.copyWith(gold: s.gold + out.gold).toJson(),
      );
      expect(r.extra['clampReasons'], contains('gold'));
    });
  }
}
