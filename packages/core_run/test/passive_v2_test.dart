import 'dart:convert';
import 'dart:io';

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:test/test.dart';

/// 펫 패시브 v2(2026-10-14 사장님 확정) — 실데이터로 돈다.
void main() {
  final raw =
      jsonDecode(File('../app/assets/data/pets.json').readAsStringSync())
          as Map<String, dynamic>;
  final cfg = PetConfig.fromJson(raw);
  final v2 = cfg.passiveV2;
  const common = Species(
    id: 'stag_saw',
    name: LocalizedText(ko: '톱사슴벌레', en: 'c', ja: 'c'),
    grade: Grade.common,
    specialty: Specialty.grip,
    baseStats: Stats(hp: 90, atk: 34, def: 30, spd: 28),
    sizeMinMm: 20,
    sizeMaxMm: 60,
    passive: SpeciesPassive(statKey: 'reward', value: 0.06),
  );
  const legend = Species(
    id: 'hornet_giant',
    name: LocalizedText(ko: '장수말벌', en: 'l', ja: 'l'),
    grade: Grade.legendary,
    specialty: Specialty.strike,
    baseStats: Stats(hp: 150, atk: 120, def: 55, spd: 128),
    sizeMinMm: 30,
    sizeMaxMm: 45,
    passive: SpeciesPassive(statKey: 'attack', value: 0.35),
  );
  IndividualBug bug(String id, int pot, {bool v2 = false, int? roll}) =>
      IndividualBug(
        id: id,
        speciesId: 'x',
        sizeMm: 40,
        potential: pot,
        temperament: Temperament.steadfast,
        sex: Sex.male,
        passiveV2: v2,
        passiveRoll: roll,
      );

  test('데이터 — 켜짐 · 종류 키는 모두 아는 강화 키(오타는 조용히 사라진다)', () {
    expect(v2.enabled, isTrue);
    expect(v2.kinds, isNotEmpty);
    for (final k in v2.kinds.keys) {
      expect(UpgradeKind.fromKeyOrNull(k), isNotNull, reason: k);
    }
    expect(v2.gradeFactor.length, 5);
    for (final g in Grade.values) {
      expect(v2.rarityFactor[g], isNotNull, reason: g.key);
    }
  });

  test('업데이트 전 곤충 = 종 패시브 종류 · 크기는 등급 × 희귀도 × 롤', () {
    final p1 = passiveOf(bug('a', 1, roll: 0), common, cfg)!;
    expect(p1.statKey, 'reward');
    // 골드: 일반 종 · 일반 등급 ≈ 6%(지금 톱사슴벌레와 같은 눈금).
    expect(p1.value, closeTo(0.35 * 0.30 * 0.57 * 0.8, 1e-9));
    final p5 = passiveOf(bug('a', 5, roll: 100), common, cfg)!;
    expect(
      p5.value,
      closeTo(0.35 * 1.0 * 0.57, 1e-9),
      reason: '일반 종 전설 등급 ≈ 20%',
    );
    final l5 = passiveOf(bug('b', 5, roll: 100), legend, cfg)!;
    expect(l5.statKey, 'attack');
    expect(l5.value, closeTo(0.35, 1e-9), reason: '전설 종 · 전설 등급 · 롤 100');
  });

  test('새 곤충(p2)은 종류가 개체마다 다르다 — 같은 종이어도', () {
    final kinds = {
      for (var i = 0; i < 200; i++)
        passiveOf(bug('n$i', 3, v2: true), legend, cfg)!.statKey,
    };
    expect(kinds.length, greaterThan(8));
    expect(kinds.every(v2.kinds.containsKey), isTrue);
    // 같은 id 면 같은 종류(결정론).
    expect(
      passiveOf(bug('same', 3, v2: true), legend, cfg)!.statKey,
      passiveOf(bug('same', 5, v2: true), common, cfg)!.statKey,
    );
  });

  test('등급이 오를수록 커진다 · 롤 100 이 롤 0 보다 크다', () {
    double at(int pot, int roll) =>
        passiveOf(bug('g', pot, roll: roll), legend, cfg)!.value;
    for (var p = 1; p < 5; p++) {
      expect(at(p + 1, 50), greaterThan(at(p, 50)));
    }
    expect(at(3, 100), greaterThan(at(3, 0)));
  });

  test('꺼져 있으면 종 패시브 그대로(옛 규칙)', () {
    final off = PetConfig.fromJson({...raw}..remove('passiveV2'));
    final p = passiveOf(bug('z', 5, v2: true), legend, off)!;
    expect(p.statKey, 'attack');
    expect(p.value, 0.35);
  });
}
