import 'package:core_models/core_models.dart';
import 'package:core_save/core_save.dart';
import 'package:test/test.dart';

/// 암수 크기 차이(2026-10-24 §12) — 암컷 범위로 옮기는 마이그레이션 · 짝짓기 평균 · 표식.
const _stag = Species(
  id: 'stag_x',
  name: LocalizedText(ko: '사슴', en: 'Stag', ja: 'クワガタ'),
  grade: Grade.common,
  specialty: Specialty.grip,
  baseStats: Stats(hp: 100, atk: 40, def: 30, spd: 20),
  sizeMinMm: 40,
  sizeMaxMm: 92,
  femaleSizeMinMm: 30,
  femaleSizeMaxMm: 50,
);

const _chafer = Species(
  id: 'chafer_x',
  name: LocalizedText(ko: '꽃무지', en: 'Chafer', ja: 'ハナムグリ'),
  grade: Grade.common,
  specialty: Specialty.strike,
  baseStats: Stats(hp: 100, atk: 40, def: 30, spd: 20),
  sizeMinMm: 22,
  sizeMaxMm: 38,
);

IndividualBug _bug(
  String id,
  Species s, {
  required Sex sex,
  required double mm,
}) => IndividualBug(
  id: id,
  speciesId: s.id,
  sizeMm: mm,
  potential: 3,
  temperament: Temperament.values.first,
  sex: sex,
  element: Element.values.first,
);

Species? _speciesOf(String id) => {'stag_x': _stag, 'chafer_x': _chafer}[id];

void main() {
  final t0 = DateTime.utc(2026, 10, 24);

  test(
    'migrateFemaleSizes keeps male-equivalent mm: 암컷 66mm(수컷 범위 한가운데) → 40mm(암컷 한가운데), 수컷은 그대로, 표식 켜짐',
    () {
      final f = _bug('f', _stag, sex: Sex.female, mm: 66);
      final m = _bug('m', _stag, sex: Sex.male, mm: 66);
      final s = SaveGame.initial(
        createdAt: t0,
      ).copyWith(bugs: [f, m], sexSizeMigrated: false);
      expect(s.sexSizeMigrated, isFalse);
      final out = migrateFemaleSizes(s, _speciesOf);
      expect(out.sexSizeMigrated, isTrue);
      final nf = out.bugs.firstWhere((b) => b.id == 'f');
      expect(nf.sizeMm, closeTo(40, 1e-9));
      expect(_stag.maleEquivalentMm(nf), closeTo(66, 1e-9));
      expect(out.bugs.firstWhere((b) => b.id == 'm').sizeMm, 66);
    },
  );

  test(
    'migrateFemaleSizes is idempotent and skips unknown species / species without female range',
    () {
      final s = SaveGame.initial(createdAt: t0).copyWith(
        bugs: [
          _bug('c', _chafer, sex: Sex.female, mm: 30),
          _bug(
            'u',
            _stag,
            sex: Sex.female,
            mm: 66,
          ).copyWith(speciesId: 'ghost'),
        ],
      );
      final once = migrateFemaleSizes(s, _speciesOf);
      expect(once.bugs[0].sizeMm, 30);
      expect(once.bugs[1].sizeMm, 66);
      expect(once.sexSizeMigrated, isTrue);
      final twice = migrateFemaleSizes(once, _speciesOf);
      expect(identical(twice, once), isTrue);
    },
  );

  test('BreedingSlot.from with species averages male-equivalent mm', () {
    final mother = _bug('mo', _stag, sex: Sex.female, mm: 50); // 수컷 환산 92
    final father = _bug('fa', _stag, sex: Sex.male, mm: 92);
    BreedingSlot slot({Species? species}) => BreedingSlot.from(
      id: 's',
      mother: mother,
      father: father,
      endsAt: t0,
      seed: 1,
      species: species,
    );
    expect(slot(species: _stag).parentAvgSizeMm, closeTo(92, 1e-9));
    expect(slot().parentAvgSizeMm, closeTo(71, 1e-9));
  });

  test('sxm round-trips in toJson/fromJson and is omitted when false', () {
    expect(SaveGame.initial(createdAt: t0).sexSizeMigrated, isTrue);
    final base = SaveGame.initial(
      createdAt: t0,
    ).copyWith(sexSizeMigrated: false);
    expect(base.toJson().containsKey('sxm'), isFalse);
    final on = base.copyWith(sexSizeMigrated: true);
    expect(on.toJson()['sxm'], true);
    expect(SaveGame.fromJson(on.toJson()).sexSizeMigrated, isTrue);
    expect(SaveGame.fromJson(base.toJson()).sexSizeMigrated, isFalse);
  });
}
