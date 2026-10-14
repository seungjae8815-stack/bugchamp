import 'dart:math';

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:test/test.dart';

/// 펫 패시브 크기 재굴림(2026-10-14 사장님 확정) — 정수 3 또는 젤리 10 · 새 값/지금 값 고르기.
void main() {
  const cfg = PassiveV2Config(
    enabled: true,
    kinds: {'attack': 0.35},
    rerollEssence: 3,
    rerollJelly: 10,
  );
  final t = DateTime.utc(2026, 10, 14);
  IndividualBug bug({LifeStage stage = LifeStage.larva}) => IndividualBug(
    id: 'b1',
    speciesId: 'stag_saw',
    sizeMm: 40,
    potential: 2,
    temperament: Temperament.steadfast,
    sex: Sex.male,
    stage: stage,
  );
  SaveGame save({int essence = 0, int jelly = 0, LifeStage? stage}) =>
      SaveGame.initial(createdAt: t).copyWith(
        bugs: [bug(stage: stage ?? LifeStage.larva)],
        essence: {'stag_saw': essence},
        materials: {MaterialKind.jelly: jelly},
      );

  test('정수로 굴리면 그 종 정수 3 · 젤리로 굴리면 젤리 10 · 곤충은 고르기 전까지 그대로', () {
    final a = rollPassiveReroll(
      save(essence: 5),
      cfg,
      'b1',
      Random(1),
      useJelly: false,
    );
    expect(a.isOk, isTrue);
    expect(a.save!.essence['stag_saw'], 2);
    expect(a.save!.bugs.single.passiveRoll, isNull);
    final roll = a.extra['roll']! as int;
    expect(roll, inInclusiveRange(0, 100));
    expect(applyPassiveRoll(a.save!, 'b1', roll).bugs.single.passiveRoll, roll);

    final j = rollPassiveReroll(
      save(jelly: 15),
      cfg,
      'b1',
      Random(1),
      useJelly: true,
    );
    expect(j.save!.materialCount(MaterialKind.jelly), 5);
  });

  test('모자라면 · 알이면 · 꺼져 있으면 실패', () {
    expect(
      rollPassiveReroll(
        save(essence: 2),
        cfg,
        'b1',
        Random(1),
        useJelly: false,
      ).error,
      'no_essence',
    );
    expect(
      rollPassiveReroll(
        save(jelly: 9),
        cfg,
        'b1',
        Random(1),
        useJelly: true,
      ).error,
      'no_jelly',
    );
    expect(
      rollPassiveReroll(
        save(essence: 9, stage: LifeStage.egg),
        cfg,
        'b1',
        Random(1),
        useJelly: false,
      ).error,
      'egg',
    );
    expect(
      rollPassiveReroll(
        save(essence: 9),
        const PassiveV2Config(),
        'b1',
        Random(1),
        useJelly: false,
      ).error,
      'off',
    );
  });

  test('결과는 세이브에 대기로 남고(앱을 꺼도) · 고르기 전엔 다시 못 굴린다 · 고르면 지운다', () {
    final a = rollPassiveReroll(
      save(essence: 9),
      cfg,
      'b1',
      Random(1),
      useJelly: false,
    );
    final pending = a.save!;
    expect(pending.passiveRerollBug, 'b1');
    expect(pending.passiveRerollRoll, a.extra['roll']);
    // 세이브 왕복(앱 재시작)에도 남는다.
    final back = SaveGame.fromJson(pending.toJson());
    expect(back.passiveRerollBug, 'b1');
    expect(back.passiveRerollRoll, a.extra['roll']);
    expect(
      rollPassiveReroll(back, cfg, 'b1', Random(2), useJelly: false).error,
      'pending',
    );
    final keep = choosePassiveReroll(back, accept: false);
    expect(keep.passiveRerollBug, isNull);
    expect(keep.bugs.single.passiveRoll, isNull);
    final take = choosePassiveReroll(back, accept: true);
    expect(take.passiveRerollBug, isNull);
    expect(take.bugs.single.passiveRoll, a.extra['roll']);
  });
}
