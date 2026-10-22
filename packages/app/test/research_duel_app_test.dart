import 'dart:convert';
import 'dart:io';

import 'package:app/data/game_data.dart';
import 'package:app/features/battle/duel_bug_build.dart';
import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
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

/// 연구소 결투 분야(설계 §9) — 앱 결투 유닛·전투력도 서버 `_buildDuelTeam` 과 같은 배율
/// (공격·방어·체력 × (1 + 연구 효과))을 받는다. 서버 쪽은 server/test/research_duel_test.dart.
void main() {
  final t0 = DateTime.utc(2026, 10, 22, 9);
  final data = _data();
  final bug = IndividualBug(
    id: 'a',
    speciesId: 'stag_giant',
    element: Element.wood,
    sizeMm: 60,
    potential: 3,
    temperament: Temperament.steadfast,
    sex: Sex.male,
    stage: LifeStage.adult,
    stageSince: t0,
  );
  final maxed = {
    for (final d in data.researchConfig!.defs)
      if (d.branch == ResearchBranch.duel) d.id: d.maxLevel,
  };

  test(
    '결투 연구를 다 찍으면 duelBugFor 의 공격·방어·체력 × (1 + 효과) · 치명 + · 문턱 −, 없으면 그대로',
    () {
      final none = SaveGame.initial(createdAt: t0).copyWith(bugs: [bug]);
      final full = none.copyWith(researchLevels: maxed);
      final fx = data.researchFx(maxed);
      final a = duelBugFor(bug, data, none, 'ko');
      final b = duelBugFor(bug, data, full, 'ko');
      expect(fx.of(ResearchEffect.duelAtk), greaterThan(0));
      expect(b.atk, closeTo(a.atk * (1 + fx.of(ResearchEffect.duelAtk)), 1e-6));
      expect(b.def, closeTo(a.def * (1 + fx.of(ResearchEffect.duelDef)), 1e-6));
      expect(
        b.maxHp,
        closeTo(a.maxHp * (1 + fx.of(ResearchEffect.duelHp)), 1e-6),
      );
      expect(b.spd, a.spd);
      // 급소 공략(치명 %p)·근성 단련(탭 반격 문턱) — 서버 `_buildDuelTeam` 과 같은 값.
      expect(fx.of(ResearchEffect.duelCrit), greaterThan(0));
      expect(b.crit, closeTo(a.crit + fx.of(ResearchEffect.duelCrit), 1e-9));
      expect(a.clutchEase, 0);
      expect(b.clutchEase, closeTo(fx.of(ResearchEffect.duelGrit), 1e-9));
    },
  );

  test('전투력 캐시는 연구 레벨이 바뀌면 다시 계산한다', () {
    final none = SaveGame.initial(createdAt: t0).copyWith(bugs: [bug]);
    final p0 = duelPowersOf(none, data)['a']!;
    final p1 = duelPowersOf(none.copyWith(researchLevels: maxed), data)['a']!;
    expect(p1, greaterThan(p0));
  });
}
