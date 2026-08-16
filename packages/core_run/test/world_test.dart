import 'package:core_run/core_run.dart';
import 'package:test/test.dart';

/// 월드 구조(2026-08 개편) — "구간 내 순항 + 월드 경계 벽 + 월드 보스 관문".
///
/// 벽·보상 점프가 무너지면 진행 곡선(35일 캠페인)이 통째로 무너지므로
/// 수식 자체를 고정해 둔다. 수치 튜닝 근거는 tool/balance_sim.dart.
void main() {
  RunConfig config({int worldSize = 100}) => RunConfig.fromJson({
    'hpBase': 40,
    'hpGrowth': 1.025,
    'bossHpMult': 5.0,
    'goldBase': 1.5,
    'goldGrowth': 1.0165,
    'xpBase': 5,
    'xpGrowth': 1.005,
    'bossRewardMult': 8.0,
    'threatBase': 2.0,
    'threatGrowth': 1.025,
    'habitatsPerStage': 20,
    'bugDropChance': 0.03,
    'materialDropChance': 0.5,
    'stagesPerRegion': 25,
    'worldSize': worldSize,
    'worldHpMult': 3.0,
    'worldGoldMult': 2.2,
    'worldBossHpMult': 3.0,
    'regions': [
      for (final id in ['a', 'b', 'c', 'd'])
        {
          'id': id,
          'name': {'ko': id, 'en': id, 'ja': id},
          'bossName': {'ko': id, 'en': id, 'ja': id},
          'habitatKinds': ['tree'],
        },
    ],
    'upgrades': [
      {
        'kind': 'attack',
        'baseCost': 15,
        'costGrowth': 1.15,
        'baseValue': 8,
        'perLevel': 4,
        'valueGrowth': 1.15,
      },
    ],
  });

  group('월드 좌표', () {
    final c = config();
    test('worldOf / stageInWorld — "1-37" 표기의 근거', () {
      expect(c.worldOf(1), 1);
      expect(c.worldOf(100), 1);
      expect(c.worldOf(101), 2);
      expect(c.worldOf(1000), 10);
      expect(c.stageInWorld(1), 1);
      expect(c.stageInWorld(100), 100);
      expect(c.stageInWorld(101), 1);
      expect(c.stageInWorld(237), 37);
    });

    test('isWorldFinal 은 월드 마지막 스테이지만', () {
      expect(c.isWorldFinal(100), isTrue);
      expect(c.isWorldFinal(99), isFalse);
      expect(c.isWorldFinal(101), isFalse);
      expect(c.isWorldFinal(1000), isTrue);
    });

    test('worldSize=0 이면 월드 없음(구버전 호환)', () {
      final flat = config(worldSize: 0);
      expect(flat.worldOf(999), 1);
      expect(flat.stageInWorld(999), 999);
      expect(flat.isWorldFinal(100), isFalse);
      // 월드 배율도 항상 1 — 벽 점프가 없어야 한다.
      final walled = config();
      expect(
        habitatMaxHp(flat, 150) * 3.0,
        closeTo(habitatMaxHp(walled, 150), habitatMaxHp(walled, 150) * 0.01),
      );
    });
  });

  group('월드 경계 점프(벽)', () {
    final c = config();
    test('경계를 넘으면 HP 가 worldHpMult 배로 점프한다', () {
      // depth 99(스테이지 100) → depth 100(스테이지 101): 성장 1.025 + 벽 ×3.
      final before = habitatMaxHp(c, 99);
      final after = habitatMaxHp(c, 100);
      expect(after / before, closeTo(1.025 * 3.0, 0.01));
    });

    test('골드·경험치는 worldGoldMult 배로 점프한다(벽보다 작아야 벽이 성립)', () {
      // 배율을 크게 줘서 정수 반올림 오차를 줄인다(수식 검증이 목적).
      final gBefore = rewardGold(c, 99, 10000.0);
      final gAfter = rewardGold(c, 100, 10000.0);
      expect(gAfter / gBefore, closeTo(1.0165 * 2.2, 0.03));
      expect(c.worldGoldMult, lessThan(c.worldHpMult));
    });

    test('위협도는 HP 와 같은 점프(플레이어 체력도 곱연산이라 상쇄 가능)', () {
      final tBefore = habitatThreat(c, 99);
      final tAfter = habitatThreat(c, 100);
      expect(tAfter / tBefore, closeTo(1.025 * 3.0, 0.01));
    });

    test('월드 마지막 보스는 관문 — 일반 보스보다 worldBossHpMult 배 세다', () {
      // 스테이지 100 보스(depth 99) vs 일반 보스 규칙.
      final gate = bossMaxHp(c, 99);
      final normal = habitatMaxHp(c, 99) * c.bossHpMult;
      expect(gate / normal, closeTo(3.0, 0.01));
      // 월드 중간 보스는 추가 배율 없음.
      final mid = bossMaxHp(c, 49);
      expect(mid / (habitatMaxHp(c, 49) * c.bossHpMult), closeTo(1.0, 0.01));
    });

    test('최종 스테이지(10-100)에서도 int64 를 넘지 않는다', () {
      // .round() 는 9.2e18 에서 조용히 포화한다 — 포화 전에 캠페인이 끝나야 한다.
      final maxHp = bossMaxHp(c, 999); // 10-100 월드 보스
      expect(maxHp, lessThan(9.2e18));
      expect(maxHp, greaterThan(1e15)); // 실제로 지수 성장이 일어났는지도 확인
    });

    test('적응형 상한까지 붙은 최강 계정도 int64 를 넘지 않는다', () {
      // 실제 run_config.json 과 같은 모양(hpBase 150 · hpGrowth 1.0092 ·
      // worldHpMult 8 · 적응형 상한 3000)에서 재는 **진짜 최댓값**.
      // ⚠️ hpAdaptMaxRatio 를 올리면 여기가 먼저 터진다 — 캠페인 종료 전에
      //    HP 가 포화하면 후반 보스가 전부 같은 체력이 되어 벽이 사라진다.
      final live = RunConfig.fromJson({
        'hpBase': 150,
        'hpGrowth': 1.0092,
        'bossHpMult': 5.0,
        'goldBase': 1.5,
        'goldGrowth': 1.0165,
        'xpBase': 5,
        'xpGrowth': 1.005,
        'bossRewardMult': 8.0,
        'habitatsPerStage': 20,
        'bugDropChance': 0.03,
        'materialDropChance': 0.5,
        'stagesPerRegion': 25,
        'worldSize': 100,
        'worldHpMult': 8.0,
        'worldGoldMult': 2.2,
        'worldBossHpMult': 3.0,
        'hpAdaptTargetHits': 12,
        'hpAdaptPower': 0.88,
        'hpAdaptMinRatio': 0.6,
        'hpAdaptMaxRatio': 3000,
        'regions': [
          {
            'id': 'a',
            'name': {'ko': 'a', 'en': 'a', 'ja': 'a'},
            'bossName': {'ko': 'a', 'en': 'a', 'ja': 'a'},
            'habitatKinds': ['tree'],
          },
        ],
        'upgrades': <Map<String, dynamic>>[],
      });
      // 공격력을 무한대에 가깝게 줘도 ratio 는 상한에서 잘린다.
      final worst = bossMaxHp(live, 999, playerAttack: 1e300);
      expect(worst, lessThan(9.2e18));
      expect(worst, greaterThan(1e18)); // 상한이 실제로 걸렸는지(여유가 얼마 없다)
    });
  });

  group('지역 순환', () {
    final c = config();
    test('25스테이지마다 다음 지역, 100 넘으면 처음부터 다시', () {
      expect(c.regionForStage(1).id, 'a');
      expect(c.regionForStage(25).id, 'a');
      expect(c.regionForStage(26).id, 'b');
      expect(c.regionForStage(75).id, 'c');
      expect(c.regionForStage(100).id, 'd');
      expect(c.regionForStage(101).id, 'a'); // 월드 2 → 다시 참나무숲
      expect(c.regionForStage(937).id, c.regionForStage(137).id);
    });
  });

  group('곱연산 업그레이드(valueGrowth)', () {
    test('스탯이 쓴 골드에 비례한다 — "모으면 뚫린다"의 근거', () {
      final spec = config().upgrade(UpgradeKind.attack);
      // valueGrowth == costGrowth 이므로 레벨 n 의 값/비용 비율이 일정하다.
      final r10 = spec.valueAt(10) / upgradeCost(spec, 10);
      final r50 = spec.valueAt(50) / upgradeCost(spec, 50);
      expect(r10, closeTo(r50, r10 * 0.01));
    });

    test('valueGrowth 없으면 기존 덧셈 그대로(하위호환)', () {
      const spec = UpgradeSpec(
        kind: UpgradeKind.regen,
        baseCost: 50,
        costGrowth: 1.22,
        baseValue: 1.0,
        perLevel: 0.6,
      );
      expect(spec.valueAt(10), closeTo(1.0 + 6.0, 1e-9));
    });
  });

  group('로드맵 칸(징검다리) 구성', () {
    final c = config();
    final roadmap = RoadmapConfig.fromJson({
      'nodeStep': 10,
      'chapters': [
        for (var w = 0; w < 10; w++)
          {
            'id': 'w${w + 1}',
            'difficulty': {'ko': 'd', 'en': 'd', 'ja': 'd'},
            'boss': {'ko': 'b', 'en': 'b', 'ja': 'b'},
            'startStage': w * 100 + 1,
            'endStage': (w + 1) * 100,
            'color': '0xFF000000',
          },
      ],
    });

    /// 화면과 같은 규칙으로 칸을 편다(roadmap_screen._buildNodes).
    List<int> nodes() => [
      for (final ch in roadmap.chapters)
        for (
          var s = ch.startStage + roadmap.nodeStep - 1;
          s <= ch.endStage;
          s += roadmap.nodeStep
        )
          s,
    ];

    test('월드당 10칸 × 10월드 = 100칸', () {
      expect(nodes(), hasLength(100));
    });

    test('칸 이름은 그 구간의 마지막 스테이지 — 1-10, 1-20 … 1-100, 2-10', () {
      final n = nodes();
      expect(c.worldOf(n[0]), 1);
      expect(c.stageInWorld(n[0]), 10);
      expect(c.stageInWorld(n[1]), 20);
      expect(c.stageInWorld(n[9]), 100); // 월드 보스
      expect(c.worldOf(n[10]), 2);
      expect(c.stageInWorld(n[10]), 10);
    });

    test('월드 보스 칸은 월드마다 정확히 1개(x-100)', () {
      final bosses = nodes().where(c.isWorldFinal).toList();
      expect(bosses, hasLength(10));
      expect(bosses.last, 1000); // 최종 보스 = 10-100
    });

    test('2줄 × 5칸 뱀 배치에서 줄이 바뀌는 칸이 세로로 이어진다', () {
      // 아래줄(0) 왼→오: 마지막 칸은 col 4. 윗줄(1) 오→왼: 첫 칸도 col 4.
      int colOf(int index) {
        final row = index ~/ 5;
        final c0 = index % 5;
        return row.isEven ? c0 : 4 - c0;
      }

      expect(colOf(4), 4); // 1-50
      expect(colOf(5), 4); // 1-60 — 바로 위
      expect(colOf(9), 0); // 1-100 (월드 보스, 왼쪽 끝)
      expect(colOf(10), 0); // 2-10 — 바로 위
    });
  });
}
