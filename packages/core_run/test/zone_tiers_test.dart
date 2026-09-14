import 'dart:convert';
import 'dart:io';

import 'package:core_models/core_models.dart' show kMaxMonsterHp;
import 'package:core_run/core_run.dart';
import 'package:test/test.dart';

/// 난이도별 사냥터 표(`run_config.json → zoneTiers`, 2026-09-15)의 **구조 규칙**.
///
/// 수치가 아니라 규칙을 검사한다 — 표는 balance_sim --fit-tiers 가 뽑으므로
/// 값을 못 박으면 다시 뽑을 때마다 테스트가 방해만 된다.
void main() {
  Map<String, dynamic> raw() =>
      jsonDecode(File('../app/assets/data/run_config.json').readAsStringSync())
          as Map<String, dynamic>;
  RunConfig load() => RunConfig.fromJson(raw());

  /// 실데이터를 바탕으로 일부만 바꾼 설정(필수 키를 다시 쓰지 않으려고).
  RunConfig withOverrides(Map<String, dynamic> o) =>
      RunConfig.fromJson({...raw(), ...o});

  group('실데이터', () {
    final c = load();

    test('네 난이도 모두 표가 있고 사냥터 수만큼 칸이 있다', () {
      expect(c.zoneTiers, hasLength(4));
      for (final t in c.zoneTiers) {
        expect(t.hp, hasLength(c.zonesPerTier));
        expect(t.bossHp, hasLength(c.zonesPerTier));
        expect(t.threat, hasLength(c.zonesPerTier));
        expect(t.gold, hasLength(c.zonesPerTier));
      }
    });

    /// 벽은 보스 하나뿐이어야 한다 — 보스가 그 사냥터 일반 몬스터보다 약하면
    /// "보스가 정예보다 약하다"가 된다(2026-09-15 지적).
    test('보스는 같은 사냥터의 정예보다 단단하다', () {
      for (var tier = 0; tier < c.zoneTiers.length; tier++) {
        for (var z = 1; z <= c.zonesPerTier; z++) {
          final stage = c.zoneStartStage(z);
          final elite = habitatMaxHp(c, stage - 1, tier: tier) * c.eliteHpMult;
          final boss = bossMaxHp(c, stage - 1, tier: tier);
          expect(boss, greaterThan(elite), reason: '난이도 $tier 사냥터 $z');
        }
      }
    });

    /// 사냥터를 올라갈수록 벌이도 올라야 낮은 사냥터에 눌러앉지 않는다.
    test('난이도 안에서 골드는 사냥터마다 오른다', () {
      for (final t in c.zoneTiers) {
        for (var i = 1; i < t.gold.length; i++) {
          expect(t.gold[i], greaterThan(t.gold[i - 1]));
        }
      }
    });

    test('int64 에 닿지 않는다', () {
      for (final t in c.zoneTiers) {
        for (final v in [...t.hp, ...t.bossHp]) {
          expect(v, lessThan(kMaxMonsterHp.toDouble()));
        }
      }
    });
  });

  group('표가 회차 배율을 대신한다', () {
    RunConfig cfg({List<Map<String, dynamic>> tiers = const []}) =>
        withOverrides({
          'hpAdaptTargetHits': 0,
          'threatAdaptTargetPct': 0,
          'zoneMode': true,
          'worldSize': 100,
          'zonesPerTier': 2,
          'tierHitsMult': 3.0,
          'tierThreatMult': 2.0,
          'tierRewardMult': 3.0,
          'zoneHp': [10, 20],
          'zoneBossHp': [100, 200],
          'zoneThreat': [1, 2],
          'zoneGold': [5, 8],
          'zoneTiers': tiers,
        });

    test('표가 없으면 예전처럼 한 표 × 회차 배율', () {
      final c = cfg();
      expect(habitatMaxHp(c, 0, tier: 1), 30);
      expect(bossMaxHp(c, 100, tier: 1), 600);
      expect(rewardGold(c, 0, 1.0, tier: 1), 15);
      expect(habitatThreat(c, 0, tier: 1), 2);
    });

    test('회차 표가 있으면 그 값을 그대로 쓴다(배율 없음)', () {
      final c = cfg(
        tiers: [
          {
            'hp': [11, 21],
            'bossHp': [111, 211],
            'threat': [3, 4],
            'gold': [6, 9],
          },
          {
            'hp': [50, 70],
            'bossHp': [500, 700],
            'threat': [7, 9],
            'gold': [40, 60],
            'threatAdaptMult': 1.2,
          },
        ],
      );
      expect(habitatMaxHp(c, 0, tier: 1), 50);
      expect(bossMaxHp(c, 100, tier: 1), 700);
      expect(rewardGold(c, 0, 1.0, tier: 1), 40);
      expect(habitatThreat(c, 0, tier: 1), 7);
      // 표가 없는 회차(2)는 예전 규칙으로 떨어진다.
      expect(habitatMaxHp(c, 0, tier: 2), 90);
    });

    test('적응형 위협은 표의 threatAdaptMult 를 곱한다(회차 배율 대신)', () {
      final c = withOverrides({
        'zoneMode': true,
        'worldSize': 100,
        'zonesPerTier': 2,
        'tierThreatMult': 2.0,
        'threatAdaptTargetPct': 0.1,
        'zoneTiers': [
          {
            'threat': [0, 0],
          },
          {
            'threat': [0, 0],
            'threatAdaptMult': 1.5,
          },
        ],
      });
      expect(habitatThreat(c, 0, tier: 1, playerToughness: 1000), 150);
    });
  });
}
