// 연구소 추가 연구 2부(설계 §10) — 서버 쪽: 선물 감각·교환 협상을 다 찍은 계정의 정당한 수입이 업로드 상한에
// 잘리지 않는다(`_huntRewardAllowance`·`_exchangeAllowance`), 서버 지급 경로(일일보상·분해·짝짓기)도 같은 함수를 탄다.
//
// 봉투 경계 시험: 서버가 쓰는 봉투(강화 + 연구 사냥 배율 · 공격 ×100 · 효율 30)를 여기서 똑같이 다시 계산해,
// "연구 몫까지 받은 금액"이 그 연구가 0 인 계정에서는 잘리고 다 찍은 계정에서는 통과하는지 본다.
// 약초학은 서버 검사가 확률이 아니라 하루 한도(`potionDropDaily`, `psR`)로 묶여 있어 바꿀 것이 없다(그대로).
import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:server/src/actions.dart';
import 'package:server/src/game_config.dart';
import 'package:test/test.dart';

final t0 = DateTime.utc(2026, 10, 23, 12);

void main() {
  late GameConfig cfg;
  late GameActions actions;
  late Map<String, int> maxed;

  setUpAll(() async {
    cfg = await GameConfig.load(dir: '../app/assets/data');
    actions = GameActions(config: cfg, now: () => t0);
    maxed = {for (final d in cfg.research!.defs) d.id: d.maxLevel};
  });

  String idOf(ResearchEffect e) =>
      cfg.research!.defs.firstWhere((d) => d.effect == e).id;
  Map<String, int> without(ResearchEffect e) => {...maxed, idOf(e): 0};
  double vOf(ResearchEffect e) => researchEffects(cfg.research!, maxed).of(e);

  SaveGame storedAt(int tier, int zone, Map<String, int> research) {
    final run = cfg.run;
    final stage = run.zoneStartStage(zone);
    return SaveGame.initial(createdAt: t0).copyWith(
      lastSeen: t0.subtract(const Duration(seconds: 60)),
      zoneEpoch: kZoneEpoch,
      difficultyTier: tier,
      maxTierReached: tier,
      stageNumber: stage,
      bestStage: stage,
      upgradeLevels: {
        for (final e in run.upgrades.entries)
          e.key: ((e.value.maxLevel ?? 100) * 0.6).round(),
      },
      gold: 1000000,
      level: 30,
      nextGiftAt: t0.add(const Duration(minutes: 5)),
      materials: {MaterialKind.jelly: 1000},
      researchLevels: research,
    );
  }

  // 서버 `_envelopeStats` 와 같은 봉투(연구 사냥 배율 · 공격 ×100).
  CharacterStats envelope(SaveGame s) {
    final b = applyResearchStats(
      deriveStats(
        cfg.run,
        upgradeLevels: s.upgradeLevels,
        characterLevel: s.level,
        bugsCollected: s.bugBuffCount,
      ),
      researchEffects(cfg.research!, s.researchLevels),
      evadeBudget: cfg.run.evadeBudgetResearch,
    );
    return CharacterStats(
      attack: b.attack * 100,
      attackSpeed: b.attackSpeed,
      rewardMultiplier: b.rewardMultiplier,
      critChance: b.critChance,
      critDamage: b.critDamage,
      bossDamage: b.bossDamage,
      maxHp: b.maxHp,
      defense: b.defense,
      hpRegen: b.hpRegen,
      xpMultiplier: b.xpMultiplier,
      bugFind: b.bugFind,
      materialFind: b.materialFind,
      evade: b.evade,
      boostBonus: b.boostBonus,
    );
  }

  int generous60s(SaveGame s) => simulateIdleProgress(
    config: cfg.run,
    startStage: s.stageNumber,
    stats: envelope(s),
    elapsed: const Duration(seconds: 60),
    efficiency: 30,
    tier: s.difficultyTier,
  ).gold;

  int huntCapGold(SaveGame s, double minutes) {
    ({int gold, int materialsEach}) at(int stage) => huntMinutesReward(
      cfg.run,
      stats: envelope(s),
      stage: stage,
      minutes: minutes,
      tier: s.difficultyTier,
      efficiency: 30,
    );
    final here = at(s.stageNumber).gold;
    final top = at(cfg.run.zoneStartStage(cfg.run.zonesPerTier)).gold;
    return here > top ? here : top;
  }

  final today = dailyDateKey(t0);

  test('선물 감각 — 일일보상(저녁 + 한 번 더) 몫이 연구만큼 넓어진다', () {
    final dinner = cfg.daily!.rewards.firstWhere((r) => r.id == 'dinner');
    final v = vOf(ResearchEffect.giftGold);
    for (final (tier, zone) in [(2, 6), (3, 11)]) {
      // 연구 몫(×(1+v))까지 받은 두 번의 저녁 보상 — 상한 경계의 99%.
      final s = storedAt(tier, zone, maxed);
      final base = huntCapGold(s, dinner.huntMinutes);
      final gain =
          GameActions.goldUploadCap +
          generous60s(s) +
          (base * (1 + v) * 2 * 0.99).round();
      Map<String, dynamic> client(SaveGame st) => st
          .copyWith(
            gold: st.gold + gain,
            dailyClaims: {'dinner': today, dailyBonusKey('dinner'): today},
          )
          .toJson();

      final ok = actions.mergeSave(s, client(s));
      expect(ok.save!.gold, s.gold + gain, reason: '$tier·$zone 다 찍음');

      final noGift = storedAt(tier, zone, without(ResearchEffect.giftGold));
      final cut = actions.mergeSave(noGift, client(noGift));
      expect(
        cut.extra['clampReasons'],
        contains('gold'),
        reason: '$tier·$zone',
      );
    }
  });

  test('선물 감각 — 깜짝선물 몫도 연구만큼 넓어진다', () {
    final gift = cfg.gift!;
    final v = vOf(ResearchEffect.giftGold);
    var maxMin = 0.0;
    for (final t in gift.tiers) {
      if (t.huntMinutes > maxMin) maxMin = t.huntMinutes;
    }
    final mult = [
      1,
      gift.adMultiplier,
      gift.adMultiplierMax,
    ].reduce((a, b) => a > b ? a : b);
    const tier = 3, zone = 11;
    final mail = GiftMail(id: 'g1', expiry: t0.add(const Duration(hours: 3)));
    SaveGame st(Map<String, int> r) =>
        storedAt(tier, zone, r).copyWith(gifts: [mail]);
    final s = st(maxed);
    final gain =
        GameActions.goldUploadCap +
        generous60s(s) +
        (huntCapGold(s, maxMin) * (1 + v) * mult * 0.99).round();
    Map<String, dynamic> client(SaveGame x) =>
        x.copyWith(gold: x.gold + gain, gifts: const []).toJson();
    expect(actions.mergeSave(s, client(s)).save!.gold, s.gold + gain);
    final noGift = st(without(ResearchEffect.giftGold));
    expect(
      actions.mergeSave(noGift, client(noGift)).extra['clampReasons'],
      contains('gold'),
    );
  });

  test('교환 협상 — 교환소 허용치가 연구만큼 넓어진다', () {
    final v = vOf(ResearchEffect.exchangeGain);
    final per = cfg.run.exchangeJellyPerTrade;
    const trades = 10;
    for (final (tier, zone) in [(2, 6), (3, 11)]) {
      final s = storedAt(tier, zone, maxed);
      final out = exchangeOutput(
        cfg.run,
        stats: envelope(s),
        stage: s.stageNumber,
        trades: trades,
        tier: tier,
        efficiency: 30,
      );
      final gain =
          GameActions.goldUploadCap +
          generous60s(s) +
          (out.gold * (1 + v) * 0.99).round();
      Map<String, dynamic> client(SaveGame x) => x
          .copyWith(
            gold: x.gold + gain,
            materials: {MaterialKind.jelly: 1000 - per * trades},
          )
          .toJson();
      expect(
        actions.mergeSave(s, client(s)).save!.gold,
        s.gold + gain,
        reason: '$tier·$zone 다 찍음',
      );
      final noBarter = storedAt(
        tier,
        zone,
        without(ResearchEffect.exchangeGain),
      );
      expect(
        actions.mergeSave(noBarter, client(noBarter)).extra['clampReasons'],
        contains('gold'),
        reason: '$tier·$zone',
      );
    }
  });

  test('선물 감각 — 서버 일일보상 경로(claimDaily)도 연구 몫까지 받는다', () {
    final dinner = cfg.daily!.rewards.firstWhere((r) => r.id == 'dinner');
    final v = vOf(ResearchEffect.giftGold);
    final s = storedAt(2, 6, maxed);
    final want = (huntCapGold(s, dinner.huntMinutes) * (1 + v) * 0.99).round();
    final r = actions.claimDaily(s, 'dinner', clientGold: want);
    expect(r.save!.gold, s.gold + want);
    final none = storedAt(2, 6, without(ResearchEffect.giftGold));
    final r0 = actions.claimDaily(none, 'dinner', clientGold: want);
    expect(r0.save!.gold, lessThan(none.gold + want));
  });

  test('분해 기술 — 서버 분해 재료 × (1 + v) · 젤리는 그대로', () {
    final sp = cfg.speciesList.first;
    final bug = IndividualBug(
      id: 'b1',
      speciesId: sp.id,
      sizeMm: sp.sizeMinMm,
      potential: 5,
      temperament: Temperament.cunning,
      sex: Sex.male,
      element: Element.fire,
      stage: LifeStage.adult,
    );
    int regular(SaveGame x) =>
        kRegularMaterials.fold<int>(0, (a, k) => a + x.materialCount(k));
    ({int mats, int jelly}) run(Map<String, int> r) {
      final s = storedAt(0, 1, r).copyWith(bugs: [bug]);
      final out = actions.disassembleBug(s, 'b1', petConfig: cfg.pet).save!;
      return (
        mats: regular(out) - regular(s),
        jelly:
            out.materialCount(MaterialKind.jelly) -
            s.materialCount(MaterialKind.jelly),
      );
    }

    final a = run(const {});
    final b = run(maxed);
    final base = cfg.pet.releaseMaterial(cfg.pet.rarityOf(bug, sp));
    expect(a.mats, base);
    expect(b.mats, (base * (1 + vOf(ResearchEffect.salvageMat))).round());
    expect(b.jelly, a.jelly);
  });

  test('혈통 연구 — 서버 짝짓기 수령(collectBreeding)이 연구 레벨로 굴린다', () {
    final sp = cfg.speciesList.first;
    IndividualBug parent(Sex sex) => IndividualBug(
      id: 'p_${sex.key}',
      speciesId: sp.id,
      sizeMm: sp.sizeMinMm,
      potential: 3,
      temperament: Temperament.cunning,
      sex: sex,
      element: Element.fire,
      stage: LifeStage.adult,
    );
    int traits(Map<String, int> r) {
      var n = 0;
      for (var seed = 0; seed < 3000; seed++) {
        final slot = BreedingSlot.from(
          id: 's',
          mother: parent(Sex.female),
          father: parent(Sex.male),
          endsAt: t0.subtract(const Duration(minutes: 1)),
          seed: seed,
        );
        final s = storedAt(0, 1, r).copyWith(breeding: [slot]);
        final out = actions
            .collectBreeding(
              s,
              's',
              speciesById: {for (final x in cfg.speciesList) x.id: x},
              petConfig: cfg.pet,
            )
            .save!;
        if (!out.bugs.last.trait.isNone) n++;
      }
      return n;
    }

    final p = cfg.pet.breedingTraitNew;
    final v = vOf(ResearchEffect.traitChance);
    expect(traits(const {}) / 3000, closeTo(p, 0.03));
    expect(traits(maxed) / 3000, closeTo(p * (1 + v), 0.03));
  });
}
