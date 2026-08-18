import 'dart:convert';
import 'dart:io';

import 'package:core_run/core_run.dart';
import 'package:test/test.dart';

/// 젤리 **소비처**가 유한하면 안 된다는 규칙을 못 박는다.
///
/// 2026-08-18 분석: 영구 소비처가 총 390젤리라 패스 보유자는 13일이면 다 사고,
/// 그 뒤로 젤리를 쓸 데가 없어 팩이 안 팔렸다. 소비처가 마르면 수익 모델이
/// 통째로 멈추므로, 수치가 아니라 **구조**를 검사한다.
void main() {
  PetConfig pets() => PetConfig.fromJson(
    jsonDecode(File('../app/assets/data/pets.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  RunConfig run() => RunConfig.fromJson(
    jsonDecode(File('../app/assets/data/run_config.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  group('확장 소비처', () {
    test('확장은 살수록 비싸진다 — 정액이면 사고 끝이다', () {
      final c = pets();
      expect(c.expandCostGrowth, greaterThan(1.0));
      final first = c.storageExpandCost(50);
      final later = c.storageExpandCost(200);
      expect(later, greaterThan(first));
    });

    test('채집함 상한이 예전(100)보다 넉넉하다', () {
      expect(pets().storageSlotsMax, greaterThan(100));
    });

    test('⚠️ 세이브 크기 방어선 — 상한이 무한은 아니다 (§2.1)', () {
      // 2026-07 장애: 3만 마리 = 13.6MB 세이브 → 업로드마다 DB 타임아웃.
      // 칸당 약 450바이트라 500칸이면 약 225KB — 여기가 마지노선이다.
      expect(pets().storageSlotsMax, lessThanOrEqualTo(500));
    });

    test('전부 확장하는 총비용이 예전 390젤리보다 훨씬 크다', () {
      final c = pets();
      var total = 0;
      for (
        var cap = 50;
        cap < c.storageSlotsMax;
        cap += c.storageExpandAmount
      ) {
        total += c.storageExpandCost(cap);
      }
      for (var cap = 1; cap < c.incubatorSlotsMax; cap++) {
        total += c.incubatorExpandCost(cap);
      }
      for (var cap = 1; cap < c.breedingSlotsMax; cap++) {
        total += c.breedingExpandCost(cap);
      }
      expect(total, greaterThan(1500), reason: '총 $total 젤리');
    });
  });

  group('교환소', () {
    test('지급량이 스테이지에 비례한다 — 정액이면 후반에 안 쓴다', () {
      final c = run();
      final early = rewardGold(c, 10, 1.0);
      final late = rewardGold(c, 200, 1.0);
      expect(late, greaterThan(early * 10));
    });

    test('교환 단위가 설정에서 온다(§6)', () {
      final c = run();
      expect(c.exchangeJellyPerTrade, greaterThan(0));
      expect(c.exchangeKillsPerHour, greaterThan(0));
    });
  });
}
