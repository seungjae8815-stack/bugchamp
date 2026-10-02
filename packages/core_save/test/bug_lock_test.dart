import 'package:core_models/core_models.dart';
import 'package:core_save/core_save.dart';
import 'package:test/test.dart';

IndividualBug _bug(String id, {int pot = 1}) => IndividualBug(
  id: id,
  speciesId: 'sp',
  sizeMm: 30,
  potential: pot,
  element: Element.wood,
  temperament: Temperament.cautious,
  sex: Sex.male,
  stage: LifeStage.adult,
);

void main() {
  final t0 = DateTime.utc(2026, 10, 2);

  test('잠근 곤충은 소멸 보호 목록(pinnedBugIds)에 들어가고 세이브 왕복에 남는다', () {
    final s = SaveGame.initial(
      createdAt: t0,
    ).copyWith(bugs: [_bug('a'), _bug('b')], lockedBugIds: {'a'});
    expect(s.pinnedBugIds, contains('a'));
    expect(s.pinnedBugIds, isNot(contains('b')));
    final back = SaveGame.fromJson(s.toJson());
    expect(back.lockedBugIds, {'a'});
    expect(
      SaveGame.initial(createdAt: t0).toJson().containsKey('lockedBugs'),
      isFalse,
    );
  });

  test('없는 곤충의 잠금은 치운다', () {
    final s = SaveGame.initial(
      createdAt: t0,
    ).copyWith(bugs: [_bug('a')], lockedBugIds: {'a', 'ghost'});
    expect(s.trimmedToStorage().lockedBugIds, {'a'});
  });

  test('상한 정리에서 잠금은 약한 보호 — 칸이 남는 만큼만, 잠금으로 상한을 넘기지 못한다', () {
    final bugs = [for (var i = 0; i < 6; i++) _bug('b$i', pot: 5 - (i % 5))];
    final s = SaveGame.initial(createdAt: t0).copyWith(
      bugs: bugs,
      storageCapacity: 3,
      lockedBugIds: {for (final b in bugs) b.id},
    );
    final out = s.trimmedToStorage();
    expect(out.bugs.length, 3);
    expect(out.lockedBugIds.length, 3);
    // 잠금이 일부일 때는 잠근 쪽을 먼저 남긴다(포텐셜이 낮아도).
    final some = SaveGame.initial(createdAt: t0).copyWith(
      bugs: bugs,
      storageCapacity: 2,
      lockedBugIds: {'b4'}, // 포텐셜 1
    );
    expect(some.trimmedToStorage().bugs.map((b) => b.id), contains('b4'));
  });
}
