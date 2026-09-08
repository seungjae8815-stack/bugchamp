import 'dart:convert';
import 'dart:io';

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:test/test.dart';

/// `packages/app/assets/data/$f` 를 읽는다. `RunConfig`/`PetConfig` 는 다른
/// 필드가 required 라 빈 맵으로 `fromJson` 을 못 돌린다 — 실데이터로 키가
/// 실제로 박혀 있는지를 검사한다(`packages/app/test/forge_flow_test.dart` 패턴).
Map<String, dynamic> _readAppData(String f) =>
    jsonDecode(File('../app/assets/data/$f').readAsStringSync())
        as Map<String, dynamic>;

/// 한 세트의 총 DPS(플레이어 + 곤충들). 오늘의 한 대를 1.0 으로 본다.
double _totalDps(
  ({double playerMult, double playerHpMult, List<PetAttacker> pets}) r,
  double pInt,
) {
  var dps = r.playerMult / pInt;
  for (final p in r.pets) {
    dps += p.damageMult / p.interval;
  }
  return dps;
}

void main() {
  const pInt = 0.5; // 플레이어 타격 간격 0.5초 = 공속 2.0

  ({double playerMult, double playerHpMult, List<PetAttacker> pets}) split(
    List<PetAttackerInput> pets,
  ) => splitAttack(
    pets: pets,
    playerInterval: pInt,
    spdReference: 100,
    intervalMin: 0.25,
    intervalMax: 2.5,
  );

  group('타격 분배', () {
    test('펫이 없으면 플레이어가 전부 때린다', () {
      final r = split(const []);
      expect(r.playerMult, 1.0);
      expect(r.pets, isEmpty);
    });

    test('총 DPS 가 오늘과 같다 — 나눌 뿐 늘리지 않는다', () {
      // 이게 깨지면 §7 적응형 체력을 재조정해야 한다. 이 설계의 전제다.
      final r = split(const [
        (bugId: 'a', element: Element.wood, spd: 100, attack: 0.25, hp: 0.25),
        (bugId: 'b', element: Element.fire, spd: 60, attack: 0.25, hp: 0.25),
        (bugId: 'c', element: Element.water, spd: 180, attack: 0.25, hp: 0.25),
      ]);
      expect(_totalDps(r, pInt), closeTo(1 / pInt, 1e-9));
    });

    test('간격을 바꿔도 DPS 가 안 변한다 — 빠른 종만 정답이 되면 안 된다', () {
      final slow = split(const [
        (bugId: 'a', element: Element.wood, spd: 50, attack: 0.5, hp: 0.5),
      ]);
      final fast = split(const [
        (bugId: 'a', element: Element.wood, spd: 200, attack: 0.5, hp: 0.5),
      ]);
      expect(_totalDps(slow, pInt), closeTo(_totalDps(fast, pInt), 1e-9));
      // 다만 **간격은 달라야** 한다 — 그래야 종이 화면에서 구분된다.
      expect(slow.pets.single.interval, greaterThan(fast.pets.single.interval));
    });

    test('느린 종은 한 대가 크다 — 큰 숫자를 가끔', () {
      final slow = split(const [
        (bugId: 'a', element: Element.wood, spd: 50, attack: 0.5, hp: 0.5),
      ]);
      final fast = split(const [
        (bugId: 'a', element: Element.wood, spd: 200, attack: 0.5, hp: 0.5),
      ]);
      expect(
        slow.pets.single.damageMult,
        greaterThan(fast.pets.single.damageMult),
      );
    });

    test('간격은 상하한으로 잘린다 — 프레임마다 때리거나 영영 안 때리면 안 된다', () {
      final r = split(const [
        (bugId: 'a', element: Element.wood, spd: 100000, attack: 0.5, hp: 0.5),
        (bugId: 'b', element: Element.fire, spd: 1, attack: 0.5, hp: 0.5),
      ]);
      expect(r.pets[0].interval, 0.25);
      expect(r.pets[1].interval, 2.5);
    });

    test('기여가 0 인 곤충은 목록에서 빠진다 — 0 데미지 팝업이 뜨면 안 된다', () {
      final r = split(const [
        (bugId: 'a', element: Element.wood, spd: 100, attack: 0.0, hp: 0.0),
        (bugId: 'b', element: Element.fire, spd: 100, attack: 0.25, hp: 0.25),
      ]);
      expect(r.pets.map((p) => p.bugId), ['b']);
    });
  });

  group('체력 분배', () {
    test('펫이 없으면 플레이어가 체력을 전부 갖는다', () {
      expect(split(const []).playerHpMult, 1.0);
    });

    test('플레이어 몫 + 곤충 몫 = 1 — 팀 총 체력은 오늘과 같다', () {
      // ⚠️ 이게 깨지면 팀이 더 단단해지거나 물러진다. 위협도(§7) 기준은
      // 그대로인데 실제 내구도만 바뀌어 밸런스가 조용히 어긋난다.
      final r = split(const [
        (bugId: 'a', element: Element.wood, spd: 100, attack: 0.25, hp: 0.30),
        (bugId: 'b', element: Element.fire, spd: 60, attack: 0.25, hp: 0.10),
        (bugId: 'c', element: Element.water, spd: 180, attack: 0.25, hp: 0.20),
      ]);
      final sum = r.playerHpMult + r.pets.fold(0.0, (a, p) => a + p.hpMult);
      expect(sum, closeTo(1.0, 1e-12));
    });

    test('체력 몫은 공격 몫과 따로 간다 — 맹렬·강인 특성이 갈라놓는다', () {
      // 강인(체력만 높은) 곤충은 더 맞아 주고, 맹렬(공격만 높은) 곤충은 덜 맞는다.
      final r = split(const [
        (
          bugId: 'fierce',
          element: Element.wood,
          spd: 100,
          attack: 0.4,
          hp: 0.1,
        ),
        (bugId: 'tough', element: Element.wood, spd: 100, attack: 0.1, hp: 0.4),
      ]);
      final fierce = r.pets.firstWhere((p) => p.bugId == 'fierce');
      final tough = r.pets.firstWhere((p) => p.bugId == 'tough');
      expect(fierce.damageMult, greaterThan(tough.damageMult));
      expect(tough.hpMult, greaterThan(fierce.hpMult));
    });

    test('체력 기여가 0 이면 곤충 몫도 0 — 플레이어가 전부 맞는다', () {
      final r = split(const [
        (bugId: 'a', element: Element.wood, spd: 100, attack: 0.5, hp: 0.0),
      ]);
      expect(r.playerHpMult, 1.0);
      expect(r.pets.single.hpMult, 0.0);
    });
  });

  group('오행 상극 배율', () {
    test('상극이면 배율이 붙는다 — 水克火', () {
      expect(petRestrainMult(Element.water, Element.fire, 1.5), 1.5);
    });

    test('상극이 아니면 1.0 — 어긋나도 손해는 없다', () {
      // 1.0 미만을 주면 "곤충이 약해졌다"가 되고, 편성을 못 맞춘 유저에게
      // 벌을 주는 시스템이 된다.
      expect(petRestrainMult(Element.fire, Element.water, 1.5), 1.0);
      expect(petRestrainMult(Element.wood, Element.wood, 1.5), 1.0);
    });

    test('무속성 지역이면 1.0', () {
      expect(petRestrainMult(Element.water, null, 1.5), 1.0);
    });

    test('3마리 다 상극이어도 총 DPS 상한은 1 + petShare x 0.5 다', () {
      // 전설 성충 3마리 수준(합 0.75) → petShare = 0.75/1.75
      const pets = [
        (bugId: 'a', element: Element.water, spd: 100, attack: 0.25, hp: 0.25),
        (bugId: 'b', element: Element.water, spd: 100, attack: 0.25, hp: 0.25),
        (bugId: 'c', element: Element.water, spd: 100, attack: 0.25, hp: 0.25),
      ];
      final r = split(pets);
      var dps = r.playerMult / pInt;
      for (final p in r.pets) {
        dps += p.damageMult * 1.5 / p.interval;
      }
      final petShare = 0.75 / 1.75;
      expect(dps * pInt, closeTo(1 + petShare * 0.5, 1e-9));
      expect(dps * pInt, lessThan(1.25)); // 업그레이드 한 레벨 반쯤
    });
  });

  group('설정 기본값', () {
    // `RunConfig.fromJson(const {})` / `PetConfig.fromJson(const {})` 는 다른
    // 필드가 required 라 빈 맵에서 던진다. 대신 실데이터(§6)를 **실제 파서에
    // 그대로 먹여서** 키 매핑까지 검증한다 — 원시 키만 보면 파서 쪽의 오타
    // (예: `petRestrainMultiplier`)를 못 잡는다.
    test('상극 배율이 run_config.json 에서 RunConfig 로 파싱된다', () {
      final run = RunConfig.fromJson(_readAppData('run_config.json'));
      expect(run.petRestrainMult, 1.5);
    });

    test('곤충 타격 간격 설정이 pets.json 에서 PetConfig 로 파싱된다', () {
      final pets = PetConfig.fromJson(_readAppData('pets.json'));
      expect(pets.attackSpdReference, 100);
      expect(pets.attackIntervalMin, 0.25);
      expect(pets.attackIntervalMax, 2.5);
    });
  });
}
