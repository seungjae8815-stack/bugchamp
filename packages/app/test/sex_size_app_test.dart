import 'dart:convert';
import 'dart:io';

import 'package:app/data/game_data.dart';
import 'package:app/features/battle/duel_bug_build.dart';
import 'package:core_models/core_models.dart';
import 'package:core_save/core_save.dart';
import 'package:flutter_test/flutter_test.dart';

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
  enhanceConfig: _read('enhance.json'),
  battleConfig: _read('battle.json'),
  researchConfig: _read('research.json'),
);

/// (2026-10-24 §12 암수) 앱 결투 유닛도 서버 `validateDuelTeam` 과 같은 값 —
/// 무게는 수컷 환산 크기, 성별은 표시용으로 싣는다.
void main() {
  final data = _data();
  final t0 = DateTime.utc(2026, 10, 24, 9);
  IndividualBug bug(Sex sex, double mm) => IndividualBug(
    id: 'a',
    speciesId: 'stag_giant',
    element: Element.wood,
    sizeMm: mm,
    potential: 3,
    temperament: Temperament.steadfast,
    sex: sex,
    stage: LifeStage.adult,
    stageSince: t0,
  );

  test('암컷 40mm(암컷 범위 30~50) 는 결투에서 수컷 환산 66mm · female', () {
    final b = bug(Sex.female, 40);
    final save = SaveGame.initial(createdAt: t0).copyWith(bugs: [b]);
    final d = duelBugFor(b, data, save, 'ko');
    expect(d.sizeMm, closeTo(66, 1e-6));
    expect(d.sex, Sex.female);
  });

  test('결투 창 표시 mm 는 암컷을 암컷 범위로 되돌린다', () {
    final b = bug(Sex.female, 40);
    final save = SaveGame.initial(createdAt: t0).copyWith(bugs: [b]);
    final d = duelBugFor(b, data, save, 'ko');
    expect(d.sizeMm, closeTo(66, 1e-6));
    expect(duelDisplayMm(d, data.species('stag_giant')), closeTo(40, 1e-6));
  });

  test('수컷은 크기 그대로 · male', () {
    final b = bug(Sex.male, 60);
    final save = SaveGame.initial(createdAt: t0).copyWith(bugs: [b]);
    final d = duelBugFor(b, data, save, 'ko');
    expect(d.sizeMm, 60);
    expect(d.sex, Sex.male);
  });

  test('speciesById 조회로 미이전 암컷을 암컷 범위로 옮기고 두 번째는 그대로', () {
    final b = bug(Sex.female, 66); // 수컷 범위 40~92 안의 위치 -> 암컷 40mm
    final save = SaveGame.initial(
      createdAt: t0,
    ).copyWith(bugs: [b], sexSizeMigrated: false);
    final moved = migrateFemaleSizes(save, (id) => data.speciesById[id]);
    expect(moved.bugs.single.sizeMm, closeTo(40, 1e-6));
    expect(moved.sexSizeMigrated, isTrue);
    expect(
      identical(
        migrateFemaleSizes(moved, (id) => data.speciesById[id]),
        moved,
      ),
      isTrue,
    );
  });
}
