import 'dart:convert';
import 'dart:io';

import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:test/test.dart';

/// 처음 써 보는 기능 1회 무료 · 신규 부화 단축 · 초반 강화 골드로만(2026-11-12).
void main() {
  final t0 = DateTime.utc(2026, 11, 12);
  final s = SaveGame.initial(createdAt: t0);
  final pets = PetConfig.fromJson(
    jsonDecode(File('../app/assets/data/pets.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  final run = RunConfig.fromJson(
    jsonDecode(File('../app/assets/data/run_config.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  test('기능마다 즉시 완료 첫 1회만 무료', () {
    expect(firstFreeCost(s, 'hatch', 40), 0);
    final used = markFirstFree(s, 'hatch');
    expect(firstFreeCost(used, 'hatch', 40), 40);
    expect(firstFreeCost(used, 'breed', 80), 0);
    expect(firstFreeCost(s, 'research', 80), 80); // 서버가 시간을 재는 기능은 없다
    expect(SaveGame.fromJson(used.toJson()).firstFreeUsed, {'hatch'});
  });

  test('처음 몇 번의 부화는 짧다 · 그 뒤로는 원래 시간', () {
    expect(pets.beginnerHatchCount, greaterThan(0));
    final max = pets.beginnerHatchMaxSec;
    expect(beginnerHatchSeconds(s, pets, 5400), max);
    expect(beginnerHatchSeconds(s, pets, 60), 60);
    final done = s.copyWith(beginnerHatches: pets.beginnerHatchCount);
    expect(beginnerHatchSeconds(done, pets, 5400), 5400);
  });

  test('초반 강화는 재료 없이 골드로만', () {
    final spec = run.upgrade(UpgradeKind.attack);
    expect(spec.materialFreeLevels, greaterThan(0));
    expect(upgradeMaterialCost(spec, 0), 0);
    expect(upgradeMaterialCost(spec, spec.materialFreeLevels - 1), 0);
    expect(upgradeMaterialCost(spec, spec.materialFreeLevels), greaterThan(0));
  });
}
