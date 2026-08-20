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

    test('가격이 절대 제자리걸음하지 않는다 — 눈금 올림의 전제', () {
      // 반올림이면 37.6과 42.1이 둘 다 40이 되어 3→4칸과 4→5칸이 같은 값이
      // 된다(실제로 그랬다). 올림이라야 단조증가가 보장된다.
      final c = pets();
      void rising(
        String what,
        int Function(int) cost,
        int from,
        int to,
        int step,
      ) {
        var prev = 0;
        for (var cap = from; cap < to; cap += step) {
          final v = cost(cap);
          expect(v, greaterThan(prev), reason: '$what $cap칸에서 $prev → $v');
          prev = v;
        }
      }

      rising('부화기', c.incubatorExpandCost, 1, c.incubatorSlotsMax, 1);
      rising('짝짓기', c.breedingExpandCost, 1, c.breedingSlotsMax, 1);
      rising(
        '채집함',
        c.storageExpandCost,
        50,
        c.storageSlotsMax,
        c.storageExpandAmount,
      );
    });

    test('가격이 딱 떨어지는 숫자다 — 자릿수별 눈금의 배수', () {
      final c = pets();
      int stepFor(int v) {
        var step = 1;
        for (final t in c.expandCostRound) {
          step = t[1];
          if (t[0] == 0 || v <= t[0]) break;
        }
        return step;
      }

      for (
        var cap = 50;
        cap < c.storageSlotsMax;
        cap += c.storageExpandAmount
      ) {
        final v = c.storageExpandCost(cap);
        expect(v % stepFor(v), 0, reason: '$cap칸 비용 $v 가 눈금에 안 맞는다');
      }
    });

    test('⚠️ 세이브 크기 방어선 — 상한이 무한은 아니다 (§2.1)', () {
      // 2026-07 장애: 3만 마리 = 13.6MB 세이브 → 업로드마다 DB 타임아웃.
      // 칸당 약 450바이트라 500칸이면 약 225KB — 여기가 마지노선이다.
      expect(pets().storageSlotsMax, lessThanOrEqualTo(500));
    });

    test('첫 개방이 충분히 비싸다 — 싸면 "쓰는 결정"이 아니게 된다', () {
      final c = pets();
      expect(c.incubatorExpandCost(1), greaterThanOrEqualTo(100));
      expect(c.breedingExpandCost(1), greaterThanOrEqualTo(100));
      expect(c.storageExpandCost(50), greaterThanOrEqualTo(100));
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

  group('스킨 계열 보너스(§2.6 P2W 방지)', () {
    IapConfig iap() => IapConfig.fromJson(
      jsonDecode(File('../app/assets/data/iap.json').readAsStringSync())
          as Map<String, dynamic>,
    );

    test('보너스는 편의(재료·시간)뿐 — 전투 스탯 필드가 없다', () {
      // 실물 경품 대회가 돌아가는 이상 결제로 전투력이 오르면 도박성 시비가
      // 된다. 필드가 늘어나면 이 테스트가 먼저 깨지게 둔다.
      final raw =
          jsonDecode(File('../app/assets/data/iap.json').readAsStringSync())
              as Map<String, dynamic>;
      const allowed = {
        'id',
        'effect',
        'speciesPrefix',
        'releaseBonusPct', // 편의: 분해·방생 재료
        'incubateSpeedPct', // 편의: 부화 시간
        'artSpecies', // 전용 그림이 있는 종(그림 파일 목록 — 효과 아님)
      };
      for (final s in raw['skins'] as List) {
        for (final k in (s as Map).keys) {
          expect(allowed, contains(k), reason: '스킨에 새 필드 "$k" — 전투 스탯인가?');
        }
      }
    });

    test('보유해야만 붙는다 — 안 산 사람은 기본값', () {
      final c = iap();
      expect(c.skinnedReleaseMaterial(100, const {}, 'rhino_japanese'), 100);
      expect(c.skinnedIncubateSeconds(600, const {}, 'stag_giant'), 600);
    });

    test('계열이 맞아야 붙는다 — 사슴벌레 스킨이 장수풍뎅이에 안 붙는다', () {
      final c = iap();
      const owned = {'albino_stag'};
      expect(c.skinnedIncubateSeconds(600, owned, 'stag_giant'), 540);
      expect(c.skinnedIncubateSeconds(600, owned, 'rhino_japanese'), 600);
    });

    test('황금은 재료만, 알비노는 시간만 건드린다', () {
      final c = iap();
      expect(
        c.skinnedReleaseMaterial(100, const {'gold_rhino'}, 'rhino_lesser'),
        115,
      );
      expect(
        c.skinnedIncubateSeconds(600, const {'gold_rhino'}, 'rhino_lesser'),
        600,
      );
      expect(
        c.skinnedReleaseMaterial(100, const {'albino_stag'}, 'stag_saw'),
        100,
      );
    });

    test('부화 시간은 1초 밑으로 안 내려간다', () {
      final c = iap();
      expect(
        c.skinnedIncubateSeconds(1, const {'albino_stag'}, 'stag_saw'),
        greaterThanOrEqualTo(1),
      );
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
