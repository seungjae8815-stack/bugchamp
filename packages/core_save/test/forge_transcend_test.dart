import 'dart:convert';
import 'dart:io';

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:test/test.dart';

/// 공방 초월 — 시간 + 젤리 즉시 완료(2026-10-12 사장님 확정). 실제 forge.json 으로 돈다.
final _forge = ForgeConfig.fromJson(
  jsonDecode(File('../app/assets/data/forge.json').readAsStringSync())
      as Map<String, dynamic>,
);

void main() {
  final t0 = DateTime.utc(2026, 10, 12, 9);
  const ring = EquipItem(
    slot: EquipSlot.ring,
    tier: 9,
    options: [ItemOption(kind: ItemOptionKind.attack, value: 10)],
  );

  SaveGame maxed({int transcend = 0, int fossil = 100000, int jelly = 0}) =>
      SaveGame.initial(createdAt: t0).copyWith(
        forgeLevel: _forge.maxLevel,
        forgeTranscend: transcend,
        equippedItems: {EquipSlot.ring: ring},
        forgeStack: const [ring],
        autoForgeMinTier: 7,
        materials: {MaterialKind.fossil: fossil, MaterialKind.jelly: jelly},
      );

  test('시작: 화석·장비·모루·공방 레벨은 바로 정리되고, 단계는 아직 그대로다', () {
    final r = startForgeTranscend(maxed(), _forge, t0);
    expect(r.error, isNull);
    final s = r.save!;
    expect(s.forgeTranscend, 0);
    expect(s.forgeTranscendAt, t0.add(const Duration(hours: 24)));
    expect(s.forgeLevel, 0);
    expect(s.equippedItems, isEmpty);
    expect(s.forgeStack, isEmpty);
    expect(s.autoForgeMinTier, 0);
    expect(
      s.materialCount(MaterialKind.fossil),
      100000 - _forge.transcendFossilCost(0),
    );
  });

  test('단계마다 시간이 24·36·48·60·72시간', () {
    for (var n = 0; n < _forge.transcendMax; n++) {
      final s = startForgeTranscend(maxed(transcend: n), _forge, t0).save!;
      expect(s.forgeTranscendAt, t0.add(Duration(hours: 24 + 12 * n)));
    }
  });

  test('진행 중에는 다시 초월할 수 없다(공방이 다시 최대여도)', () {
    final s = startForgeTranscend(maxed(), _forge, t0).save!;
    final again = s.copyWith(forgeLevel: _forge.maxLevel);
    expect(startForgeTranscend(again, _forge, t0).error, 'in_progress');
  });

  test('실패 이유 — 최대 레벨 아님 · 초월 끝 · 화석 부족', () {
    expect(
      startForgeTranscend(maxed().copyWith(forgeLevel: 3), _forge, t0).error,
      'not_max',
    );
    expect(
      startForgeTranscend(
        maxed(transcend: _forge.transcendMax),
        _forge,
        t0,
      ).error,
      'maxed',
    );
    expect(
      startForgeTranscend(maxed(fossil: 10), _forge, t0).error,
      'not_enough_fossil',
    );
  });

  test('수령: 시간이 끝나야 단계 +1, 진행 기록이 지워진다', () {
    final s = startForgeTranscend(maxed(), _forge, t0).save!;
    final early = t0.add(const Duration(hours: 23));
    expect(claimForgeTranscendSave(s, _forge, early).error, 'not_ready');
    final done = claimForgeTranscendSave(
      s,
      _forge,
      t0.add(const Duration(hours: 24)),
    ).save!;
    expect(done.forgeTranscend, 1);
    expect(done.forgeTranscendAt, isNull);
    expect(claimForgeTranscendSave(done, _forge, t0).error, 'none');
  });

  test('진행 중인 초월도 등급업 비용 단계에 센다 — 이전 싼 비용으로 다시 올리는 구멍 차단', () {
    final s = startForgeTranscend(maxed(transcend: 1), _forge, t0).save!;
    expect(s.forgeTranscend, 1);
    expect(forgeCostTranscend(s), 2);
    expect(
      _forge.levelUpStepGold(s.forgeLevel, transcend: forgeCostTranscend(s)),
      _forge.levelUpStepGold(0, transcend: 2),
    );
    final done = claimForgeTranscendSave(
      s,
      _forge,
      t0.add(const Duration(days: 3)),
    ).save!;
    expect(forgeCostTranscend(done), 2, reason: '수령해도 비용 단계는 그대로');
    expect(forgeCostTranscend(maxed()), 0);
  });

  test('젤리 즉시 완료 — 등급업과 같은 값표, 모자라면 실패', () {
    final s = startForgeTranscend(maxed(jelly: 1000), _forge, t0).save!;
    final cost = forgeTranscendRushJelly(s, _forge, t0);
    expect(cost, _forge.levelUpJelly(const Duration(hours: 24)));
    expect(cost, 70); // 2026-10-25 시간당 3젤리 — 24시간 72 → 가격 단위 70
    final r = rushForgeTranscendSave(s, _forge, t0).save!;
    expect(r.forgeTranscend, 1);
    expect(r.forgeTranscendAt, isNull);
    expect(r.materialCount(MaterialKind.jelly), 1000 - cost);

    final poor = s.copyWith(materials: {...s.materials, MaterialKind.jelly: 5});
    expect(rushForgeTranscendSave(poor, _forge, t0).error, 'not_enough_jelly');
  });

  test('세이브 왕복 — 끝 시각은 짧은 키 ftAt, 없으면 키를 생략한다', () {
    final s = startForgeTranscend(maxed(), _forge, t0).save!;
    final j = s.toJson();
    expect(j['ftAt'], isA<String>());
    expect(SaveGame.fromJson(j).forgeTranscendAt, s.forgeTranscendAt);
    final none = maxed().toJson();
    expect(none.containsKey('ftAt'), isFalse);
    expect(SaveGame.fromJson(none).forgeTranscendAt, isNull);
    expect(none['feat'], kSaveFeatureLevel);
    expect(kSaveFeatureLevel, greaterThanOrEqualTo(25));
  });
}
