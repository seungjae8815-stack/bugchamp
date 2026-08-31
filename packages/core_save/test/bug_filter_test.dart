import 'dart:math';

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:test/test.dart';

/// 채집함 등급 필터(§2.1)와 짝짓기 슬롯의 부모 스냅샷(§2.5).
///
/// 둘 다 **세이브에 새로 생긴 필드**라, 구버전 세이브를 읽을 때의 기본값과
/// JSON 왕복이 무너지면 조용히 기능이 꺼지거나 세이브가 안 열린다.
void main() {
  const species = Species(
    id: 'stag_dorcus',
    name: LocalizedText(ko: '사슴벌레', en: 'Stag', ja: 'クワガタ'),
    grade: Grade.common,
    specialty: Specialty.grip,
    baseStats: Stats(hp: 100, atk: 40, def: 30, spd: 20),
    sizeMinMm: 30,
    sizeMaxMm: 75,
  );

  IndividualBug parent({
    required Sex sex,
    Element element = Element.fire,
    Temperament temperament = Temperament.cunning,
    BugTrait trait = BugTrait.none,
    int potential = 3,
  }) => IndividualBug(
    id: 'p_${sex.key}',
    speciesId: species.id,
    sizeMm: 50,
    potential: potential,
    temperament: temperament,
    sex: sex,
    element: element,
    trait: trait,
  );

  group('채집함 등급 필터', () {
    test('기본값은 일반 = 필터 없음(전부 받는다)', () {
      final s = SaveGame.initial(createdAt: DateTime.utc(2026, 1, 1));
      expect(s.bugFilterMinGrade, Grade.common);
      for (final g in Grade.values) {
        expect(s.acceptsGrade(g), isTrue);
      }
    });

    test('기준 이상만 받는다', () {
      final s = SaveGame.initial(
        createdAt: DateTime.utc(2026, 1, 1),
      ).copyWith(bugFilterMinGrade: Grade.rare);
      expect(s.acceptsGrade(Grade.common), isFalse);
      expect(s.acceptsGrade(Grade.uncommon), isFalse);
      expect(s.acceptsGrade(Grade.rare), isTrue);
      expect(s.acceptsGrade(Grade.epic), isTrue);
      expect(s.acceptsGrade(Grade.legendary), isTrue);
    });

    test('JSON 왕복에서 보존된다', () {
      final s = SaveGame.initial(
        createdAt: DateTime.utc(2026, 1, 1),
      ).copyWith(bugFilterMinGrade: Grade.epic);
      expect(SaveGame.fromJson(s.toJson()).bugFilterMinGrade, Grade.epic);
    });

    test('기본값이면 키를 싣지 않는다 — 세이브 크기가 곧 업로드 비용이다', () {
      final s = SaveGame.initial(createdAt: DateTime.utc(2026, 1, 1));
      expect(s.toJson().containsKey('bugFilterMinGrade'), isFalse);
    });

    test('모르는 등급 키는 일반(=전부 받음)으로 — 필터 때문에 세이브가 안 열리면 안 된다', () {
      final json = SaveGame.initial(
        createdAt: DateTime.utc(2026, 1, 1),
      ).toJson()..['bugFilterMinGrade'] = 'mythic_from_the_future';
      expect(SaveGame.fromJson(json).bugFilterMinGrade, Grade.common);
    });
  });

  group('BreedingSlot — 부모 스냅샷', () {
    final mother = parent(
      sex: Sex.female,
      element: Element.water,
      temperament: Temperament.aggressive,
      trait: BugTrait.sturdy,
    );
    final father = parent(
      sex: Sex.male,
      element: Element.water,
      temperament: Temperament.aggressive,
      trait: BugTrait.sturdy,
    );

    test('from() 이 오행·기질·특성을 찍는다 — 부모가 사라져도 상속된다', () {
      final slot = BreedingSlot.from(
        id: 's1',
        mother: mother,
        father: father,
        endsAt: DateTime.utc(2026, 1, 1),
        seed: 7,
      );
      expect(slot.motherElement, Element.water);
      expect(slot.fatherElement, Element.water);
      expect(slot.motherTemperament, Temperament.aggressive);
      expect(slot.motherTrait, BugTrait.sturdy);
      expect(slot.parentAvgSizeMm, 50);
    });

    test('JSON 왕복에서 스냅샷이 보존된다', () {
      final slot = BreedingSlot.from(
        id: 's1',
        mother: mother,
        father: father,
        endsAt: DateTime.utc(2026, 1, 1),
        seed: 7,
      );
      final back = BreedingSlot.fromJson(slot.toJson());
      expect(back.motherElement, Element.water);
      expect(back.fatherTemperament, Temperament.aggressive);
      expect(back.fatherTrait, BugTrait.sturdy);
      expect(back.seed, 7);
    });

    test('개편 전 슬롯(스냅샷 없음)도 읽히고, 수령이 깨지지 않는다', () {
      // 신규 키가 통째로 없는 예전 JSON.
      final legacy = {
        'id': 's0',
        'speciesId': species.id,
        'parentAvgSizeMm': 50.0,
        'motherPotential': 3,
        'fatherPotential': 3,
        'endsAt': '2026-01-01T00:00:00.000Z',
        'seed': 7,
      };
      final slot = BreedingSlot.fromJson(legacy);
      expect(slot.motherElement, isNull);
      expect(slot.motherTrait, BugTrait.none);
      // 상속 확률을 켜 둔 설정에서도 예외 없이 자식이 나온다(랜덤 폴백).
      final cfg = PetConfig.fromJson(const {
        'gradeAttackPct': <String, dynamic>{},
        'gradeHpPct': <String, dynamic>{},
        'stageMult': <String, dynamic>{},
        'stageDurationsSec': <String, dynamic>{},
        'breedingElementInherit': 1.0,
        'breedingTraitInherit': 1.0,
      });
      final egg = slot.hatch(id: 'e', species: species, cfg: cfg);
      expect(egg.stage, LifeStage.egg);
      expect(egg.trait, BugTrait.none);
    });

    test('hatch() 는 결정론적이다 — 같은 슬롯이면 앱과 서버가 같은 자식을 낸다', () {
      final slot = BreedingSlot.from(
        id: 's1',
        mother: mother,
        father: father,
        endsAt: DateTime.utc(2026, 1, 1),
        seed: 12345,
      );
      final cfg = PetConfig.fromJson(const {
        'gradeAttackPct': <String, dynamic>{},
        'gradeHpPct': <String, dynamic>{},
        'stageMult': <String, dynamic>{},
        'stageDurationsSec': <String, dynamic>{},
        'breedingElementInherit': 0.8,
        'breedingTemperamentInherit': 0.65,
        'breedingTraitInherit': 0.55,
        'breedingTraitNew': 0.2,
        'traitWeights': {'fierce': 1.0, 'noble': 1.0},
      });
      final a = slot.hatch(id: 'e1', species: species, cfg: cfg);
      final b = slot.hatch(id: 'e2', species: species, cfg: cfg);
      expect(a.element, b.element);
      expect(a.temperament, b.temperament);
      expect(a.trait, b.trait);
      expect(a.sizeMm, b.sizeMm);
      expect(a.potential, b.potential);
      // 부모가 같은 값이면 자식도 확정으로 물려받는다.
      expect(a.element, Element.water);
      expect(a.trait, anyOf(BugTrait.sturdy, BugTrait.none));
    });
  });

  group('혈통 특성 → 펫 기여', () {
    PetConfig cfg() => PetConfig.fromJson(const {
      'gradeAttackPct': {'common': 0.10},
      'gradeHpPct': {'common': 0.10},
      'stageMult': {'adult': 1.0},
      'stageDurationsSec': <String, dynamic>{},
      'potentialScale': 0.0,
      'enhanceScale': 0.0,
      'levelBonus': 0.0,
      'traitAttackBonus': {'fierce': 0.35, 'sturdy': 0.0},
      'traitHpBonus': {'fierce': 0.0, 'sturdy': 0.35},
    });

    PetStat stat(BugTrait t) => (
      grade: Grade.common,
      variant: BugVariant.none,
      sizeMult: 1.0,
      potential: 0,
      enhanceTotal: 0,
      stage: LifeStage.adult,
      level: 1,
      trait: t,
      passive: null,
    );

    test('맹렬은 공격만, 강인은 체력만 올린다 — 축이 갈려야 노리고 교배한다', () {
      final c = cfg();
      final plain = petContribution(stat(BugTrait.none), c);
      final fierce = petContribution(stat(BugTrait.fierce), c);
      final sturdy = petContribution(stat(BugTrait.sturdy), c);

      expect(fierce.attack, closeTo(plain.attack * 1.35, 1e-9));
      expect(fierce.hp, closeTo(plain.hp, 1e-9));
      expect(sturdy.hp, closeTo(plain.hp * 1.35, 1e-9));
      expect(sturdy.attack, closeTo(plain.attack, 1e-9));
    });

    test('설정에 없는 특성은 보너스 0 — JSON 미설정이 곱셈을 깨지 않는다', () {
      final c = cfg();
      expect(
        petContribution(stat(BugTrait.noble), c).attack,
        closeTo(petContribution(stat(BugTrait.none), c).attack, 1e-9),
      );
    });
  });

  group('자동 방생 보상', () {
    test('등급이 높을수록 재료를 더 준다, 미설정이면 0', () {
      final cfg = PetConfig.fromJson(const {
        'gradeAttackPct': <String, dynamic>{},
        'gradeHpPct': <String, dynamic>{},
        'stageMult': <String, dynamic>{},
        'stageDurationsSec': <String, dynamic>{},
        'releaseMaterialByGrade': {'common': 2, 'rare': 8},
      });
      expect(cfg.releaseMaterial(Grade.common), 2);
      expect(cfg.releaseMaterial(Grade.rare), 8);
      expect(cfg.releaseMaterial(Grade.legendary), 0);

      final empty = PetConfig.fromJson(const {
        'gradeAttackPct': <String, dynamic>{},
        'gradeHpPct': <String, dynamic>{},
        'stageMult': <String, dynamic>{},
        'stageDurationsSec': <String, dynamic>{},
      });
      expect(empty.releaseMaterial(Grade.common), 0);
    });

    test('방생 보상은 젤리가 아니다 — 자동 통로로 프리미엄 재화가 새면 안 된다', () {
      // 규칙 자체를 고정한다: 방생은 `releaseMaterialByGrade`(일반 재료) 로만
      // 정의되고, 젤리 환원은 손으로 하는 분해(`disassembleJelly`) 쪽이다.
      final cfg = PetConfig.fromJson(const {
        'gradeAttackPct': <String, dynamic>{},
        'gradeHpPct': <String, dynamic>{},
        'stageMult': <String, dynamic>{},
        'stageDurationsSec': <String, dynamic>{},
        'releaseMaterialByGrade': {'legendary': 32},
        'disassembleJellyPerPotential': 1.0,
      });
      expect(cfg.releaseMaterial(Grade.legendary), 32);
      expect(cfg.disassembleJelly(5), 5);
    });
  });

  test('랜덤 주입 없이 hatch 가 seed 만으로 굴러간다(전역 Random 금지)', () {
    // 결정론 규칙(§5): 같은 슬롯이면 언제 어디서 굴려도 같은 결과.
    final slot = BreedingSlot.from(
      id: 's',
      mother: parent(sex: Sex.female),
      father: parent(sex: Sex.male),
      endsAt: DateTime.utc(2026, 1, 1),
      seed: Random(1).nextInt(1 << 31),
    );
    final cfg = PetConfig.fromJson(const {
      'gradeAttackPct': <String, dynamic>{},
      'gradeHpPct': <String, dynamic>{},
      'stageMult': <String, dynamic>{},
      'stageDurationsSec': <String, dynamic>{},
    });
    final first = slot.hatch(id: 'a', species: species, cfg: cfg);
    for (var i = 0; i < 20; i++) {
      final again = slot.hatch(id: 'a', species: species, cfg: cfg);
      expect(again.sizeMm, first.sizeMm);
      expect(again.element, first.element);
    }
  });
}
