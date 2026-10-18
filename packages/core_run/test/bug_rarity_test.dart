import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:test/test.dart';

// 곤충마다 희귀도(2026-10-16 사장님 확정, 1.0.22, docs/design_bug_rarity.md) — 규칙.
void main() {
  const legendSpecies = Species(
    id: 'hornet_giant',
    name: LocalizedText(ko: '장수말벌', en: 'Hornet', ja: 'スズメバチ'),
    grade: Grade.legendary,
    specialty: Specialty.strike,
    baseStats: Stats(hp: 150, atk: 120, def: 55, spd: 128),
    sizeMinMm: 30,
    sizeMaxMm: 45,
  );

  IndividualBug bug(String id, {Grade? rarity, bool gacha = false}) =>
      IndividualBug(
        id: id,
        speciesId: legendSpecies.id,
        sizeMm: 40,
        potential: 1,
        temperament: Temperament.cunning,
        sex: Sex.male,
        rarity: rarity,
        fromGacha: gacha,
      );

  const on = BugRarityConfig(enabled: true);

  test('꺼져 있으면 종 희귀도 그대로 — 옛 규칙', () {
    const off = BugRarityConfig();
    expect(off.rarityOf(bug('a'), legendSpecies), Grade.legendary);
    expect(
      off.rarityOf(bug('a', rarity: Grade.common), legendSpecies),
      Grade.legendary,
    );
    expect(off.huntMultOf(Grade.legendary), 1.0);
    expect(off.duelMultOf(Grade.legendary), 1.0);
  });

  test('켜지면 정해 준 값이 이기고, 없으면 id 롤 — 같은 id 는 늘 같은 희귀도', () {
    expect(
      on.rarityOf(bug('a', rarity: Grade.epic), legendSpecies),
      Grade.epic,
    );
    final r = on.rarityOf(bug('same-id'), legendSpecies);
    for (var i = 0; i < 5; i++) {
      expect(on.rarityOf(bug('same-id'), legendSpecies), r);
    }
  });

  test('id 롤 분포 = 야생 표 · 뽑기 출신은 뽑기 표(일반 없음)', () {
    const n = 40000;
    final wild = <Grade, int>{};
    final gacha = <Grade, int>{};
    for (var i = 0; i < n; i++) {
      final w = on.rarityOf(bug('w$i'), legendSpecies);
      wild[w] = (wild[w] ?? 0) + 1;
      final g = on.rarityOf(bug('g$i', gacha: true), legendSpecies);
      gacha[g] = (gacha[g] ?? 0) + 1;
    }
    double pct(Map<Grade, int> m, Grade g) => (m[g] ?? 0) / n * 100;
    expect(pct(wild, Grade.common), closeTo(52, 1.5));
    expect(pct(wild, Grade.uncommon), closeTo(28, 1.5));
    expect(pct(wild, Grade.rare), closeTo(14, 1.0));
    expect(pct(wild, Grade.epic), closeTo(5, 0.6));
    expect(pct(wild, Grade.legendary), closeTo(1, 0.3));
    expect(gacha[Grade.common], isNull);
    expect(pct(gacha, Grade.legendary), closeTo(17, 1.2));
  });

  test('천장 표 — 정한 희귀도 아래는 나오지 않는다', () {
    final w = BugRarityConfig.atLeast(on.wildWeights, Grade.rare);
    for (var i = 0; i < 100; i++) {
      final g = BugRarityConfig.pickWith(w, i / 100);
      expect(g.index, greaterThanOrEqualTo(Grade.rare.index));
    }
  });

  test('사냥 배율은 야생 확률로 평균 ≈ 1(평균 유저 90일 표 그대로 — 사장님 확정)', () {
    final total = on.wildWeights.fold<double>(0, (a, b) => a + b);
    var mean = 0.0;
    for (final g in Grade.values) {
      mean += on.wildWeights[g.index] / total * on.huntMultOf(g);
    }
    expect(mean, closeTo(1.0, 0.03));
  });

  test('세이브 키 ry — 정해 준 값만 싣고, 모르는 키는 id 롤로', () {
    final withR = bug('a', rarity: Grade.rare);
    expect(withR.toJson()['ry'], 'rare');
    expect(IndividualBug.fromJson(withR.toJson()).rarity, Grade.rare);
    expect(bug('a').toJson().containsKey('ry'), isFalse);
    final odd = bug('a').toJson()..['ry'] = 'mythic';
    expect(IndividualBug.fromJson(odd).rarity, isNull);
  });

  test('실데이터 — 표가 5칸이고 사냥 배율이 희귀도 순으로 오른다', () {
    final pets = PetConfig.fromJson(
      jsonDecode(File('../app/assets/data/pets.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    final c = pets.bugRarity;
    expect(c.wildWeights.length, Grade.values.length);
    expect(c.gachaWeights.length, Grade.values.length);
    expect(c.huntMult.length, Grade.values.length);
    expect(c.duelMult.length, Grade.values.length);
    for (var i = 1; i < c.huntMult.length; i++) {
      expect(c.huntMult[i], greaterThan(c.huntMult[i - 1]));
      expect(c.duelMult[i], greaterThanOrEqualTo(c.duelMult[i - 1]));
    }
  });

  test('패시브 legacyRandom — 켜면 업데이트 전 곤충도 종류가 id 롤', () {
    const kinds = {'attack': 0.3, 'maxHp': 0.3, 'reward': 0.3};
    const keep = PassiveV2Config(enabled: true, kinds: kinds);
    const rand = PassiveV2Config(
      enabled: true,
      kinds: kinds,
      legacyRandom: true,
    );
    final old = bug('legacy-1'); // p2 없음
    expect(keep.kindOf(old, 'bossDamage'), 'bossDamage');
    expect(kinds.keys, contains(rand.kindOf(old, 'bossDamage')));
    // 새 곤충은 둘 다 같은 id 롤.
    final fresh = old.copyWith(passiveV2: true);
    expect(rand.kindOf(fresh, 'x'), keep.kindOf(fresh, 'x'));
  });

  group('야생 드롭(pickWildDrop — 방치·실시간·채집망 공용)', () {
    final petJson =
        jsonDecode(File('../app/assets/data/pets.json').readAsStringSync())
            as Map<String, dynamic>;
    final run = RunConfig.fromJson(
      jsonDecode(File('../app/assets/data/run_config.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    final species = [
      for (final j
          in (jsonDecode(
                    File('../app/assets/data/species.json').readAsStringSync(),
                  )
                  as Map<String, dynamic>)['species']
              as List)
        Species.fromJson(j as Map<String, dynamic>),
    ];
    PetConfig petWith(bool on) => PetConfig.fromJson({
      ...petJson,
      'bugRarity': <String, dynamic>{
        ...(petJson['bugRarity'] as Map<String, dynamic>),
        'enabled': on,
      },
    });

    test('꺼져 있으면 옛 규칙 — 희귀도 = 종 희귀도, 고정 값 없음', () {
      final pet = petWith(false);
      final rng = Random(1);
      for (var i = 0; i < 200; i++) {
        final d = pickWildDrop(rng, species, run: run, pet: pet, id: 'o$i')!;
        expect(d.rarity, d.species.grade);
        expect(d.fixed, isNull);
      }
    });

    test('켜지면 종은 고르게, 희귀도는 id 롤(같은 id = 같은 희귀도)', () {
      final pet = petWith(true);
      final rng = Random(2);
      final bySpecies = <String, int>{};
      const n = 20000;
      for (var i = 0; i < n; i++) {
        final id = 'n$i';
        final d = pickWildDrop(rng, species, run: run, pet: pet, id: id)!;
        bySpecies[d.species.id] = (bySpecies[d.species.id] ?? 0) + 1;
        expect(d.fixed, isNull);
        expect(
          d.rarity,
          BugRarityConfig.pickWith(
            pet.bugRarity.wildWeights,
            IndividualBug.rarityRollOf(id),
          ),
        );
      }
      // 20종 고르게 — 한 종 5% 안팎.
      for (final c in bySpecies.values) {
        expect(c / n, closeTo(1 / species.length, 0.012));
      }
    });

    test('희귀 천장이면 희귀 이상을 정해서 준다(곤충에 ry 로 실을 값)', () {
      final pet = petWith(true);
      final rng = Random(3);
      for (var i = 0; i < 300; i++) {
        final d = pickWildDrop(
          rng,
          species,
          run: run,
          pet: pet,
          id: 'p$i',
          pity: true,
        )!;
        expect(d.fixed, isNotNull);
        expect(d.rarity, d.fixed);
        // id 로 정해진다 — 서버가 같은 id 로 다시 계산해 맞춰 본다(`guardGradeBugFields`).
        expect(d.fixed, pet.bugRarity.pityRarityOf('p$i'));
        expect(d.rarity.index, greaterThanOrEqualTo(Grade.rare.index));
      }
    });
  });
}
