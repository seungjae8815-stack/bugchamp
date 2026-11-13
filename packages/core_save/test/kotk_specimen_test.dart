import 'dart:convert';
import 'dart:io';

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:test/test.dart';

/// 왕중왕전 표본(2026-11-10) — 칸 밖 · 재료 보호 · 업적.
void main() {
  final t0 = DateTime.utc(2026, 11, 10);
  final run = RunConfig.fromJson(
    jsonDecode(File('../app/assets/data/run_config.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  IndividualBug bug(String id) => IndividualBug(
    id: id,
    speciesId: 'stag_giant',
    sizeMm: 70,
    potential: 1,
    temperament: Temperament.aggressive,
    sex: Sex.male,
    element: Element.wood,
    stage: LifeStage.adult,
    stageSince: t0,
  );

  test('표본은 채집함 칸을 차지하지 않고 정리에서 늘 남는다', () {
    final s = SaveGame.initial(createdAt: t0).copyWith(
      storageCapacity: 2,
      bugs: [bug('a'), bug('b'), bug('c')],
      retiredBugs: {'a'},
    );
    expect(s.storageUsed, 2);
    expect(s.storageFull, isTrue);
    expect(s.storageFree, 0);
    expect(s.trimmedToStorage().bugs.length, 3);
    final over = s.copyWith(bugs: [...s.bugs, bug('d')]);
    final trimmed = over.trimmedToStorage();
    expect(trimmed.bugs.map((b) => b.id), contains('a'));
    expect(trimmed.storageUsed, 2);
  });

  test('표본·참가 곤충은 재료에서 빠진다', () {
    final s = SaveGame.initial(
      createdAt: t0,
    ).copyWith(retiredBugs: {'a'}, kotkEntryBug: 'b');
    expect(s.pinnedBugIds, containsAll(['a', 'b']));
  });

  test('업적 — 왕중왕전 성적·표본 수', () {
    AchievementDef def(String id) =>
        run.achievements.firstWhere((d) => d.id == id);
    final s = SaveGame.initial(
      createdAt: t0,
    ).copyWith(kotkBest: 4, retiredBugs: {'a'});
    expect(achievementDone(s, def('kotk16')), isTrue);
    expect(achievementDone(s, def('kotk4')), isTrue);
    expect(achievementDone(s, def('kotk1')), isFalse);
    expect(achievementDone(s, def('spec1')), isTrue);
  });
}
