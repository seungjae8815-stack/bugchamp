import 'dart:convert';
import 'dart:io';

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:test/test.dart';

// 희귀도 올리기(2026-10-16 사장님 확정, 1.0.22) — 같은 종 · 같은 희귀도 3마리 → +1.
void main() {
  final pet = PetConfig.fromJson(
    jsonDecode(File('../app/assets/data/pets.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  const sp = Species(
    id: 'stag_saw',
    name: LocalizedText(ko: '톱사슴벌레', en: 's', ja: 's'),
    grade: Grade.common,
    specialty: Specialty.grip,
    baseStats: Stats(hp: 90, atk: 34, def: 30, spd: 28),
    sizeMinMm: 20,
    sizeMaxMm: 60,
  );
  final byId = {sp.id: sp};
  final t0 = DateTime.utc(2026, 10, 16);

  IndividualBug bug(
    String id, {
    Grade r = Grade.common,
    String species = 'stag_saw',
    int level = 1,
    LifeStage stage = LifeStage.adult,
  }) => IndividualBug(
    id: id,
    speciesId: species,
    sizeMm: 40,
    potential: 1,
    temperament: Temperament.cunning,
    sex: Sex.male,
    stage: stage,
    level: level,
    rarity: r,
  );

  SaveGame save(List<IndividualBug> bugs) =>
      SaveGame.initial(createdAt: t0).copyWith(bugs: bugs);

  test('실데이터 — 켜져 있고 재료 3마리', () {
    expect(pet.bugRarity.enabled, isTrue);
    expect(pet.bugRarity.upFodder, 3);
  });

  test('같은 종 · 같은 희귀도 3마리를 쓰고 한 단계 오른다 · 키운 것은 그대로', () {
    final s = save([
      bug('t', level: 5),
      bug('a'),
      bug('b'),
      bug('c'),
      bug('d'),
    ]);
    final r = rarityUp(s, 't', pet, byId);
    expect(r.isOk, isTrue);
    final out = r.save!;
    final t = out.bugs.firstWhere((b) => b.id == 't');
    expect(pet.rarityOf(t, sp), Grade.uncommon);
    expect(t.level, 5);
    expect(out.bugs.length, 2); // 재료 3마리 사라짐
    expect((r.extra['fodder'] as List).length, 3);
  });

  test('재료가 아닌 것 — 다른 종 · 다른 희귀도 · 알 · 투자한 곤충 · 잠금', () {
    final s = save([
      bug('t'),
      bug('other', species: 'stag_flat'),
      bug('rare', r: Grade.rare),
      bug('egg', stage: LifeStage.egg),
      bug('trained', level: 3),
      bug('locked'),
    ]).copyWith(lockedBugIds: {'locked'});
    expect(rarityUpFodder(s, s.bugs.first, pet, byId), isEmpty);
    expect(rarityUp(s, 't', pet, byId).error, 'no_fodder');
  });

  test('전설은 더 못 올린다 · 알은 못 올린다', () {
    final s = save([
      bug('l', r: Grade.legendary),
      bug('a', r: Grade.legendary),
      bug('b', r: Grade.legendary),
      bug('c', r: Grade.legendary),
      bug('e', stage: LifeStage.egg),
    ]);
    expect(rarityUp(s, 'l', pet, byId).error, 'max');
    expect(rarityUp(s, 'e', pet, byId).error, 'egg');
  });

  test('정수가 늘지 않는다 — 일반 3마리 정수 > 고급 1마리 정수(올리기·바꾸기 반복으로 못 불린다)', () {
    final g = pet.individualGrade;
    final three = 3 * g.essenceOf(bug('x'), Grade.common);
    final one = g.essenceOf(bug('y', r: Grade.uncommon), Grade.uncommon);
    expect(one, lessThan(three + g.essenceOf(bug('t'), Grade.common)));
  });

  test('서버 검사 rarityUpAllowed — 단계마다 그 희귀도 재료 3마리 · 모자라면 아무것도 안 쓴다', () {
    final cfg = pet.bugRarity;
    List<({String id, String speciesId, Grade rarity})> gone(
      int common,
      int uncommon,
    ) => [
      for (var i = 0; i < common; i++)
        (id: 'c$i', speciesId: 'stag_saw', rarity: Grade.common),
      for (var i = 0; i < uncommon; i++)
        (id: 'u$i', speciesId: 'stag_saw', rarity: Grade.uncommon),
    ];
    final used = <String>{};
    final g1 = gone(3, 0);
    expect(
      rarityUpAllowed(
        from: Grade.common,
        to: Grade.uncommon,
        speciesId: 'stag_saw',
        gone: g1,
        cfg: cfg,
        used: used,
      ),
      isTrue,
    );
    expect(used, {'c0', 'c1', 'c2'});
    expect(g1, isEmpty);
    // 두 단계(일반 → 희귀) = 일반 3 + 고급 3.
    expect(
      rarityUpAllowed(
        from: Grade.common,
        to: Grade.rare,
        speciesId: 'stag_saw',
        gone: gone(3, 3),
        cfg: cfg,
      ),
      isTrue,
    );
    // 모자라면 false 이고 목록·사용 기록을 건드리지 않는다.
    final g2 = gone(2, 0);
    final used2 = <String>{};
    expect(
      rarityUpAllowed(
        from: Grade.common,
        to: Grade.uncommon,
        speciesId: 'stag_saw',
        gone: g2,
        cfg: cfg,
        used: used2,
      ),
      isFalse,
    );
    expect(g2.length, 2);
    expect(used2, isEmpty);
    // 다른 종 재료는 안 된다.
    expect(
      rarityUpAllowed(
        from: Grade.common,
        to: Grade.uncommon,
        speciesId: 'stag_flat',
        gone: gone(3, 0),
        cfg: cfg,
      ),
      isFalse,
    );
  });
}
