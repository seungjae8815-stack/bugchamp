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

    test('장착이 없으면 체력도 플레이어가 전부 갖는다', () {
      // 펫을 안 끼면 오늘과 완전히 같은 화면이어야 한다 — 체력바가 줄면 안 된다.
      final r = buildPetAttackers(
        equipped: const [],
        playerInterval: 0.5,
        petConfig: _petConfig,
      );
      expect(r.playerHpMult, 1.0);
    });

    test('곤충이 체력을 나눠 가지면 캐릭터 몫이 그만큼 줄어든다', () {
      // ⚠️ 합이 1 이어야 팀 총 체력이 오늘과 같다. 어긋나면 위협도(§7) 기준은
      // 그대로인데 실제 내구도만 바뀐다.
      final r = buildPetAttackers(
        equipped: const [
          (bugId: 'a', element: Element.wood, spd: 100, attack: 0.3, hp: 0.3),
          (bugId: 'b', element: Element.fire, spd: 100, attack: 0.2, hp: 0.1),
        ],
        playerInterval: 0.5,
        petConfig: _petConfig,
      );
      final sum = r.playerHpMult + r.pets.fold(0.0, (a, p) => a + p.hpMult);
      expect(sum, closeTo(1.0, 1e-12));
      expect(r.playerHpMult, lessThan(1.0));
    });

    test('장착 곤충의 종 SPD 가 간격이 된다', () {
      final r = buildPetAttackers(
        equipped: const [
          (bugId: 'a', element: Element.wood, spd: 200, attack: 0.5, hp: 0.5),
        ],
        playerInterval: 0.5,
        petConfig: _petConfig,
      );
      // spdReference(100) 의 2배로 빠르다 → 간격 절반
      expect(r.pets.single.interval, closeTo(0.25, 1e-9));
    });
  });
}
