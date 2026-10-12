import 'dart:convert';
import 'dart:io';

import 'package:app/data/game_data.dart';
import 'package:app/data/save_repository.dart';
import 'package:app/domain/providers.dart';
import 'package:app/domain/save_controller.dart';
import 'package:app/features/battle/duel_bug_build.dart';
import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';
import 'package:core_save/core_save.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repo implements SaveRepository {
  _Repo(this._g);
  SaveGame _g;
  @override
  SaveLoadFailure? get lastFailure => null;
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

/// 실제 게임 데이터(pets.json 개체 등급 켬 — 1.0.20 출시값).
GameData _data() => GameData.fromDecoded(
  species: _read('species.json'),
  traps: _read('traps.json'),
  fields: _read('fields.json'),
  spawns: _read('spawns.json'),
  runConfig: _read('run_config.json'),
  petConfig: _read('pets.json'),
  enhanceConfig: _read('enhance.json'),
  battleConfig: _read('battle.json'),
);

final _t0 = DateTime.utc(2026, 10, 19, 1);

ProviderContainer _make(SaveGame seed) {
  final c = ProviderContainer(
    overrides: [
      gameDataProvider.overrideWith((ref) => _data()),
      saveRepositoryProvider.overrideWithValue(_Repo(seed)),
      clockProvider.overrideWithValue(FixedClock(_t0)),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

/// 개체 등급(2026-10-12 출시 전 점검) — 켠 상태의 뽑기 천장 · 결투 능력치가 서버와 같은 계산인지.
void main() {
  final data = _data();
  final ig = data.petConfig!.individualGrade;

  test('pets.json 은 켠 채 출시한다', () {
    expect(ig.enabled, isTrue);
    expect(ig.gachaLegendPity, 50);
  });

  test(
    'G — 뽑기 전설 천장: 49번 전설 없이 뽑았으면 다음은 전설 · 표식(뽑기 출신·켜진 뒤 생김) · 카운터 되감기',
    () async {
      final seed = SaveGame.initial(createdAt: _t0).copyWith(
        materials: {MaterialKind.jelly: 100000},
        gachaLegendPity: ig.gachaLegendPity - 1,
      );
      final c = _make(seed);
      await c.read(saveControllerProvider.future);
      final ctrl = c.read(saveControllerProvider.notifier);
      final r = await ctrl.gachaDraw();
      expect(r.error, isNull);
      expect(r.bug!.potential, 5);
      expect(r.bug!.fromGacha, isTrue);
      expect(r.bug!.newGen, isTrue);
      final s = c.read(saveControllerProvider).requireValue;
      expect(s.gachaLegendPity, 0);
      expect(s.gachaPity, 0, reason: '전설은 영웅 이상 천장도 되감는다');
    },
  );

  test('G — 전설이 아니면 전설 천장 카운터가 오른다(영웅 이상 천장과 따로)', () async {
    final seed = SaveGame.initial(
      createdAt: _t0,
    ).copyWith(materials: {MaterialKind.jelly: 100000});
    final c = _make(seed);
    await c.read(saveControllerProvider.future);
    final ctrl = c.read(saveControllerProvider.notifier);
    var legend = 0, worst = 0, since = 0;
    for (var i = 0; i < 120; i++) {
      final before = c.read(saveControllerProvider).requireValue;
      final r = await ctrl.gachaDraw();
      expect(r.error, isNull);
      final after = c.read(saveControllerProvider).requireValue;
      if (r.bug!.potential == 5) {
        legend++;
        expect(after.gachaLegendPity, 0);
        since = 0;
      } else {
        expect(after.gachaLegendPity, before.gachaLegendPity + 1);
        since++;
        if (since > worst) worst = since;
      }
      // 채집함이 차지 않게 비운다.
      await ctrl.devClearBugs();
    }
    expect(legend, greaterThanOrEqualTo(2), reason: '120번이면 천장만으로도 2번');
    expect(worst, lessThan(ig.gachaLegendPity));
  });

  test('P — 앱 duelBugFor = 공용 계산(서버 validateDuelTeam 테스트와 같은 순서·같은 함수)', () {
    final rolls = [10, 95, 40, 70, 50, 100, 0, 80];
    IndividualBug b(String id, int pot, {List<int>? rl}) => IndividualBug(
      id: id,
      speciesId: 'stag_giant',
      sizeMm: 60,
      potential: pot,
      temperament: Temperament.aggressive,
      sex: Sex.male,
      element: Element.wood,
      stage: LifeStage.adult,
      stageSince: _t0.subtract(const Duration(days: 30)),
      synthUps: rl == null ? 0 : 1,
      rolls: rl,
      newGen: true,
    );
    final bugs = [b('x', 2, rl: rolls), b('y', 5), b('z', 3)];
    final s = SaveGame.initial(createdAt: _t0).copyWith(bugs: bugs);
    final pet = data.petConfig!;
    for (final bug in bugs) {
      final sp = data.species(bug.speciesId);
      final tb = trainingBonusOf(
        s,
        bug,
        sp,
        data.battleConfig!.training,
        levelCap: pet.levelCap(bug.breakthroughTier),
        enhance: data.enhanceConfig,
      );
      final m = pet.individualGrade.battleMods(bug, sp);
      final want =
          DuelBug.fromBattleBug(
                buildBattleBug(
                  bug: bug,
                  species: sp,
                  locale: 'ko',
                  trainAtkMult: tb.atkMult,
                  trainDefMult: tb.defMult,
                  trainHpMult: tb.hpMult,
                  trainSpdMult: tb.spdMult,
                  traitAtkBonus: pet.traitBattleAtk(bug.trait),
                  variantAtkBonus: pet.variantBattleAtk(bug.variant),
                  variantHpBonus: pet.variantBattleHp(bug.variant),
                  traitHpBonus: pet.traitBattleHp(bug.trait),
                ),
                speciesId: bug.speciesId,
                sizeMm: bug.sizeMm,
                specialty: sp.specialty,
                sizeStatMult: bug.statMultiplier(sp),
              )
              .withTraining(
                evade: tb.evade,
                crit: tb.crit,
                recovery: tb.recovery,
                massMult: tb.massMult,
                pushMult: tb.pushMult,
                tech: tb.tech,
                grit: tb.grit,
              )
              .withTraining(
                hpMult: m.hp,
                atkMult: m.atk,
                defMult: m.def,
                spdMult: m.spd,
                crit: m.crit,
                evade: m.evade,
                recovery: m.recovery,
                pushMult: m.push,
              );
      final got = duelBugFor(bug, data, s, 'ko');
      expect(got.maxHp, closeTo(want.maxHp, 1e-6), reason: bug.id);
      expect(got.atk, closeTo(want.atk, 1e-6), reason: bug.id);
      expect(got.def, closeTo(want.def, 1e-6), reason: bug.id);
      expect(got.spd, closeTo(want.spd, 1e-6), reason: bug.id);
      expect(got.crit, closeTo(want.crit, 1e-9), reason: bug.id);
      expect(got.evade, closeTo(want.evade, 1e-9), reason: bug.id);
      expect(got.recovery, closeTo(want.recovery, 1e-9), reason: bug.id);
      expect(got.pushMult, closeTo(want.pushMult, 1e-9), reason: bug.id);
    }
  });
}
