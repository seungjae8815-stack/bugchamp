import 'dart:convert';
import 'dart:io';

import 'package:app/data/game_data.dart';
import 'package:app/data/save_repository.dart';
import 'package:app/domain/providers.dart';
import 'package:app/domain/save_controller.dart';
import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repo implements SaveRepository {
  @override
  SaveLoadFailure? get lastFailure => null;

  _Repo(this._g);
  SaveGame _g;
  @override
  Future<SaveGame> load() async => _g;
  @override
  Future<void> save(SaveGame g) async => _g = g;
  @override
  Future<void> clear() async =>
      _g = SaveGame.initial(createdAt: DateTime.utc(2026));
}

Map<String, dynamic> _read(String f) =>
    jsonDecode(File('assets/data/$f').readAsStringSync())
        as Map<String, dynamic>;

GameData _data() => GameData.fromDecoded(
  species: _read('species.json'),
  traps: _read('traps.json'),
  fields: _read('fields.json'),
  spawns: _read('spawns.json'),
  runConfig: _read('run_config.json'),
  petConfig: _read('pets.json'),
  itemConfig: _read('items.json'),
  forgeConfig: _read('forge.json'),
  dailyConfig: _read('daily.json'),
  giftConfig: _read('gifts.json'),
  iapConfig: _read('iap.json'),
  researchConfig: _read('research.json'),
);

/// 연구소 추가 연구 2부(설계 §10) — 앱 지급 경로(일일보상·깜짝선물·교환소·분해·별 강화·공방 초월·다듬기)가
/// core 함수의 연구 배율을 탄다. 연구 0 이면 그대로, 다 찍으면 기대 배율. 서버 상한은 server/test/research_economy_server_test.dart.
void main() {
  final t0 = DateTime.utc(2026, 10, 23, 12);
  final data = _data();
  final maxed = {for (final d in data.researchConfig!.defs) d.id: d.maxLevel};
  final fx = data.researchFx(maxed);
  // 한 연구만 다 찍은 레벨 — 사냥 분야(골드·공격)가 같이 오르면 분치 자체가 커져 배율을 못 본다.
  Map<String, int> only(ResearchEffect e) {
    final d = data.researchConfig!.defs.firstWhere((d) => d.effect == e);
    return {d.id: d.maxLevel};
  }

  double v(ResearchEffect e) => fx.of(e);

  ProviderContainer make(SaveGame seed) {
    final c = ProviderContainer(
      overrides: [
        gameDataProvider.overrideWith((ref) => data),
        saveRepositoryProvider.overrideWithValue(_Repo(seed)),
        clockProvider.overrideWithValue(FixedClock(t0)),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  SaveGame seed(Map<String, int> research) {
    final run = data.runConfig!;
    final stage = run.zoneStartStage(6);
    return SaveGame.initial(createdAt: t0).copyWith(
      lastSeen: t0,
      zoneEpoch: kZoneEpoch,
      difficultyTier: 1,
      maxTierReached: 1,
      stageNumber: stage,
      bestStage: stage,
      upgradeLevels: {for (final k in UpgradeKind.values) k: 60},
      materials: {MaterialKind.jelly: 500, MaterialKind.fossil: 1 << 30},
      researchLevels: research,
    );
  }

  Future<SaveController> ctrl(SaveGame s) async {
    final c = make(s);
    await c.read(saveControllerProvider.future);
    return c.read(saveControllerProvider.notifier);
  }

  test('선물 감각 — 일일보상 골드·재료 × (1 + v), 젤리는 그대로', () async {
    final reward = data.dailyConfig!.rewards.firstWhere(
      (r) => r.huntMinutes > 0,
    );
    final a = (await ctrl(seed(const {}))).dailyRewardAmount(reward);
    final b = (await ctrl(
      seed(only(ResearchEffect.giftGold)),
    )).dailyRewardAmount(reward);
    final m = 1 + v(ResearchEffect.giftGold);
    expect(b.gold, (a.gold * m).round());
    for (final k in kBreakthroughMaterials) {
      expect(b.materials[k], ((a.materials[k] ?? 0) * m).round());
    }
    expect(b.materials[MaterialKind.jelly], a.materials[MaterialKind.jelly]);
  });

  test('선물 감각 — 깜짝선물 금액(젤리 제외)', () async {
    Future<GiftMail> spawn(Map<String, int> r) async {
      final c = make(
        seed(r).copyWith(nextGiftAt: t0.subtract(const Duration(minutes: 1))),
      );
      await c.read(saveControllerProvider.future);
      await c.read(saveControllerProvider.notifier).maybeSpawnGift();
      return c.read(saveControllerProvider).requireValue.gifts.single;
    }

    // 선물 티어는 기기 난수라 같은 티어(같은 분치)가 나올 때까지 굴려 금액 비율을 본다.
    final a = await spawn(const {});
    final gift = only(ResearchEffect.giftGold);
    var b = await spawn(gift);
    for (var i = 0; i < 40 && b.minutes != a.minutes; i++) {
      b = await spawn(gift);
    }
    expect(b.minutes, a.minutes);
    final m = 1 + v(ResearchEffect.giftGold);
    expect(b.gold / a.gold, closeTo(m, 0.01));
    expect(b.chitin / a.chitin, closeTo(m, 0.02));
    // 젤리는 티어 값 그대로(배율 없음).
    final tierJelly = {for (final t in data.giftConfig!.tiers) t.jelly};
    expect(tierJelly, contains(b.jelly));
  });

  test('교환 협상 — 교환소 골드 × (1 + v)', () async {
    final a = (await ctrl(
      seed(const {}),
    )).exchangeJelly(trades: 2, wantGold: true)!;
    final b = (await ctrl(
      seed(only(ResearchEffect.exchangeGain)),
    )).exchangeJelly(trades: 2, wantGold: true)!;
    expect(
      b.gold,
      closeTo(a.gold * (1 + v(ResearchEffect.exchangeGain)), a.gold * 0.01),
    );
  });

  test('분해 기술 — 손 분해 재료 × (1 + v), 젤리는 그대로', () async {
    final bug = IndividualBug(
      id: 'b1',
      speciesId: data.allSpecies.first.id,
      sizeMm: data.allSpecies.first.sizeMinMm,
      potential: 5,
      temperament: Temperament.cunning,
      sex: Sex.male,
      element: Element.fire,
      stage: LifeStage.adult,
      stageSince: t0,
    );
    final a = await (await ctrl(
      seed(const {}).copyWith(bugs: [bug]),
    )).disassembleBug('b1');
    final b = await (await ctrl(
      seed(maxed).copyWith(bugs: [bug]),
    )).disassembleBug('b1');
    expect(a.ok, isTrue);
    expect(b.amount, (a.amount * (1 + v(ResearchEffect.salvageMat))).round());
    expect(b.jelly, a.jelly);
  });

  test('제련 비법 — 공방 초월 시간', () async {
    final forge = data.forgeConfig!;
    Future<DateTime?> start(Map<String, int> r) async {
      final c = make(seed(r).copyWith(forgeLevel: forge.maxLevel));
      await c.read(saveControllerProvider.future);
      expect(
        await c.read(saveControllerProvider.notifier).transcendForge(),
        isNull,
      );
      return c.read(saveControllerProvider).requireValue.forgeTranscendAt;
    }

    expect(await start(const {}), t0.add(forge.transcendDuration(0)));
    expect(
      await start(maxed),
      t0.add(forge.transcendDuration(0, research: fx)),
    );
  });

  test('별빛 연마 — 별 강화 시간', () async {
    final items = data.itemConfig!;
    final item = EquipItem(
      slot: EquipSlot.tool,
      tier: 9,
      starExp: items.starNeedAt(0),
      options: const [ItemOption(kind: ItemOptionKind.attack, value: 5)],
    );
    Future<DateTime?> start(Map<String, int> r) async {
      final c = make(seed(r).copyWith(equippedItems: {EquipSlot.tool: item}));
      await c.read(saveControllerProvider.future);
      expect(
        await c
            .read(saveControllerProvider.notifier)
            .startStarUp(EquipSlot.tool),
        isNull,
      );
      return c
          .read(saveControllerProvider)
          .requireValue
          .equippedItems[EquipSlot.tool]!
          .starUntil;
    }

    expect(await start(const {}), t0.add(items.starUpDuration(0, tier: 9)));
    expect(
      await start(maxed),
      t0.add(items.starUpDuration(0, tier: 9, research: fx)),
    );
  });
}
