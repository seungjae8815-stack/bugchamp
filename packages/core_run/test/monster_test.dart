import 'dart:convert';
import 'dart:io';

import 'package:core_run/core_run.dart';
import 'package:test/test.dart';

/// 실데이터로 검증한다 — 코드 기본값이 아니라 **게임이 쓰는 값**이 기준이다(§6).
RunConfig _runConfig() => RunConfig.fromJson(
  jsonDecode(File('../app/assets/data/run_config.json').readAsStringSync())
      as Map<String, dynamic>,
);

void main() {
  const ids = ['tree', 'rock', 'flower', 'stump', 'mushroom'];

  group('몬스터 등장 순서', () {
    test('결정론 — 같은 스테이지는 언제 봐도 같은 순서다', () {
      final a = monsterOrder(ids: ids, stageNumber: 7, count: 20);
      final b = monsterOrder(ids: ids, stageNumber: 7, count: 20);
      expect(a, b);
    });

    test('스테이지가 다르면 순서가 다르다 — 예전엔 주기가 딱 떨어져 늘 같았다', () {
      final a = monsterOrder(ids: ids, stageNumber: 7, count: 20);
      final b = monsterOrder(ids: ids, stageNumber: 8, count: 20);
      expect(a, isNot(b));
    });

    test('같은 몬스터가 연달아 나오지 않는다 — 단조로움의 가장 큰 원인', () {
      for (var stage = 1; stage <= 200; stage++) {
        final order = monsterOrder(ids: ids, stageNumber: stage, count: 20);
        for (var i = 1; i < order.length; i++) {
          expect(
            order[i],
            isNot(order[i - 1]),
            reason: 'stage $stage, index $i 에서 연속 중복',
          );
        }
      }
    });

    test('종류가 3개뿐이어도 연속 중복이 없다 — 풀숲 초원이 그렇다', () {
      const few = ['flower', 'tree', 'mushroom'];
      for (var stage = 1; stage <= 100; stage++) {
        final order = monsterOrder(ids: few, stageNumber: stage, count: 20);
        for (var i = 1; i < order.length; i++) {
          expect(order[i], isNot(order[i - 1]));
        }
      }
    });

    test('모든 종류가 고르게 나온다 — 한 종이 묻히면 그림을 넣은 보람이 없다', () {
      final counts = <String, int>{};
      for (var stage = 1; stage <= 100; stage++) {
        for (final id in monsterOrder(
          ids: ids,
          stageNumber: stage,
          count: 20,
        )) {
          counts[id] = (counts[id] ?? 0) + 1;
        }
      }
      // 완전 균등(400)에서 크게 벗어나지 않아야 한다.
      for (final id in ids) {
        expect(counts[id], greaterThan(300));
        expect(counts[id], lessThan(500));
      }
    });

    test('종류가 하나뿐이면 그것만 — 연속 중복 회피가 무한 루프에 빠지면 안 된다', () {
      expect(monsterOrder(ids: ['tree'], stageNumber: 3, count: 4), [
        'tree',
        'tree',
        'tree',
        'tree',
      ]);
    });

    test('목록이 비면 빈 결과 — 던지지 않는다(구버전 JSON 방어)', () {
      expect(monsterOrder(ids: const [], stageNumber: 1, count: 20), isEmpty);
    });
  });

  group('엘리트 판정', () {
    test('결정론 — 같은 칸은 언제 와도 같다', () {
      for (var i = 0; i < 20; i++) {
        final a = isEliteAt(
          stageNumber: 12,
          habitatIndex: i,
          chance: 0.06,
          boss: false,
        );
        final b = isEliteAt(
          stageNumber: 12,
          habitatIndex: i,
          chance: 0.06,
          boss: false,
        );
        expect(a, b);
      }
    });

    test('보스 칸에는 안 걸린다 — 벽 앞에서 난이도를 두 번 곱하면 안 된다', () {
      expect(
        isEliteAt(stageNumber: 5, habitatIndex: 0, chance: 1.0, boss: true),
        isFalse,
      );
    });

    test('확률 0 이면 안 나오고 1 이면 늘 나온다', () {
      expect(
        isEliteAt(stageNumber: 5, habitatIndex: 3, chance: 0, boss: false),
        isFalse,
      );
      expect(
        isEliteAt(stageNumber: 5, habitatIndex: 3, chance: 1, boss: false),
        isTrue,
      );
    });

    test('실데이터: 보상 배율이 체력 배율보다 크다 — 아니면 정예가 세금이 된다', () {
      // 시간은 (1-c+c*hp) 배, 수입은 (1-c+c*reward) 배로 늘어난다.
      // reward < hp 면 **시간당 수입이 줄어** 정예를 만나는 게 손해가 된다.
      // 초안(체력 x4 · 보상 x3)이 정확히 그랬다 — 시간당 -5.1%.
      final c = _runConfig();
      expect(c.eliteRewardMult, greaterThan(c.eliteHpMult));
      final time = (1 - c.eliteChance) + c.eliteChance * c.eliteHpMult;
      final gain = (1 - c.eliteChance) + c.eliteChance * c.eliteRewardMult;
      expect(gain / time, greaterThan(1.0));
      // 너무 후하면 정예 사냥이 본 게임을 밀어낸다.
      expect(gain / time, lessThan(1.25));
    });

    test('실제 빈도가 설정값 근처다 — 씨앗이 치우쳐 있으면 수입 계산이 어긋난다', () {
      var hits = 0, total = 0;
      for (var stage = 1; stage <= 500; stage++) {
        for (var i = 0; i < 20; i++) {
          total++;
          if (isEliteAt(
            stageNumber: stage,
            habitatIndex: i,
            chance: 0.06,
            boss: false,
          )) {
            hits++;
          }
        }
      }
      expect(hits / total, closeTo(0.06, 0.015));
    });
  });
}
