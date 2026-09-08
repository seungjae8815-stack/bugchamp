import 'dart:convert';
import 'dart:io';

import 'package:app/features/play/pet_attackers.dart';
import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:flutter_test/flutter_test.dart';

/// 실제 밸런스로 검증한다 — 더미 계수면 간격 기준(spdReference)이 달라진다.
final _petConfig = PetConfig.fromJson(
  jsonDecode(File('assets/data/pets.json').readAsStringSync())
      as Map<String, dynamic>,
);

void main() {
  group('장착 곤충 → 타격자 조립', () {
    test('장착이 없으면 플레이어가 전부', () {
      final r = buildPetAttackers(
        equipped: const [],
        playerInterval: 0.5,
        petConfig: _petConfig,
      );
      expect(r.playerMult, 1.0);
      expect(r.pets, isEmpty);
    });

    test('장착 곤충의 종 SPD 가 간격이 된다', () {
      final r = buildPetAttackers(
        equipped: const [
          (bugId: 'a', element: Element.wood, spd: 200, attack: 0.5),
        ],
        playerInterval: 0.5,
        petConfig: _petConfig,
      );
      // spdReference(100) 의 2배로 빠르다 → 간격 절반
      expect(r.pets.single.interval, closeTo(0.25, 1e-9));
    });
  });
}
