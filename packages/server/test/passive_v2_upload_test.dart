import 'package:core_models/core_models.dart';
import 'package:core_save/core_save.dart';
import 'package:server/src/actions.dart';
import 'package:server/src/game_config.dart';
import 'package:test/test.dart';

/// 펫 패시브 v2(2026-10-14 · feat 26) — `p2`(새 곤충 표식) · `pr`(크기 롤) 업로드 검사.
final t0 = DateTime.utc(2026, 10, 14, 12);

void main() {
  late GameActions actions;
  setUpAll(() async {
    final cfg = await GameConfig.load(dir: '../app/assets/data');
    actions = GameActions(config: cfg, now: () => t0);
  });

  IndividualBug b(String id, {bool p2 = false, int? pr}) => IndividualBug(
    id: id,
    speciesId: 'stag_saw',
    sizeMm: 40,
    potential: 1,
    temperament: Temperament.steadfast,
    sex: Sex.male,
    stage: LifeStage.larva,
    passiveV2: p2,
    passiveRoll: pr,
  );

  SaveGame stored(List<IndividualBug> bugs) => SaveGame.initial(
    createdAt: t0,
  ).copyWith(lastSeen: t0.subtract(const Duration(seconds: 60)), bugs: bugs);

  test('옛 곤충에 p2 를 붙이거나 새 곤충에서 떼도 저장본 그대로 · 새 id 에는 붙는다', () {
    final s = stored([b('old'), b('new', p2: true)]);
    final client = s.copyWith(
      bugs: [b('old', p2: true), b('new'), b('fresh', p2: true)],
    );
    final out = actions.mergeSave(s, client.toJson()).save!;
    final by = {for (final x in out.bugs) x.id: x};
    expect(by['old']!.passiveV2, isFalse);
    expect(by['new']!.passiveV2, isTrue);
    expect(by['fresh']!.passiveV2, isTrue);
  });

  test('구버전(feat 25)이 떨어뜨린 p2·pr 는 저장본 값으로 되돌린다', () {
    final s = stored([b('x', p2: true, pr: 97)]);
    final j = s.toJson()..['feat'] = 25;
    j['bugs'] = [
      for (final m in j['bugs'] as List)
        Map<String, dynamic>.from(m as Map)
          ..remove('p2')
          ..remove('pr'),
    ];
    final got = actions.mergeSave(s, j).save!.bugs.single;
    expect(got.passiveV2, isTrue);
    expect(got.passiveRoll, 97);
  });

  /// 무료 재굴림 사용 횟수(`pfu`, 2026-10-14) — 줄지 않고, 구버전이 떨궈도 되돌린다.
  test('무료 재굴림 사용 횟수는 줄지 않는다 · 구버전이 떨군 것도 되돌린다', () {
    final s = stored([b('x').copyWith(passiveFreeUsed: 3)]);
    // 0 으로 고쳐 올려도 3 그대로.
    final forged = s.copyWith(bugs: [b('x')]);
    expect(
      actions.mergeSave(s, forged.toJson()).save!.bugs.single.passiveFreeUsed,
      3,
    );
    // 늘어난 것은 받는다.
    final used = s.copyWith(bugs: [b('x').copyWith(passiveFreeUsed: 4)]);
    expect(
      actions.mergeSave(s, used.toJson()).save!.bugs.single.passiveFreeUsed,
      4,
    );
    // 구버전(feat 25) — 모르는 키를 떨궈 올림.
    final j = s.toJson()..['feat'] = 25;
    j['bugs'] = [
      for (final m in j['bugs'] as List)
        Map<String, dynamic>.from(m as Map)..remove('pfu'),
    ];
    expect(actions.mergeSave(s, j).save!.bugs.single.passiveFreeUsed, 3);
  });
}
