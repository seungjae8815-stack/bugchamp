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
);

/// 채집함 결투 전투력(2026-10-12 사장님 요청) — 결투 탭과 **같은 값**이고, 같은 입력이면 다시 계산하지 않는다.
void main() {
  final t0 = DateTime.utc(2026, 10, 12, 9);
  final data = _data();

  IndividualBug bug(String id, {int potential = 3, int level = 10}) =>
      IndividualBug(
        id: id,
        speciesId: 'stag_dorcus',
        element: Element.wood,
        sizeMm: 40,
        potential: potential,
        temperament: Temperament.aggressive,
        sex: Sex.male,
        stage: LifeStage.adult,
        stageSince: t0,
        level: level,
      );

  test('곤충별 값 = 결투 탭이 쓰는 duelPowerOf(duelBugFor(...))', () {
    final save = SaveGame.initial(
      createdAt: t0,
    ).copyWith(bugs: [bug('a'), bug('b', potential: 5, level: 40)]);
    final m = duelPowersOf(save, data);
    for (final b in save.bugs) {
      expect(
        m[b.id],
        duelPowerOf(duelBugFor(b, data, save, 'ko'), data),
        reason: b.id,
      );
      expect(m[b.id], greaterThan(0));
    }
  });

  test('같은 입력이면 다시 계산하지 않는다(같은 객체) — 골드만 바뀐 세이브도 그대로', () {
    final save = SaveGame.initial(createdAt: t0).copyWith(bugs: [bug('a')]);
    final m1 = duelPowersOf(save, data);
    final m2 = duelPowersOf(save.copyWith(gold: 999), data);
    expect(identical(m1, m2), isTrue);
    final m3 = duelPowersOf(save.copyWith(bugs: [bug('a', level: 30)]), data);
    expect(identical(m1, m3), isFalse);
  });
}
