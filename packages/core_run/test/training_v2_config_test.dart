import 'dart:convert';
import 'dart:io';

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:test/test.dart';

/// 훈련 v2 설정(`battle.json → training`, docs/design_training_v2.md) — 실데이터가 설계 값으로 읽히는지.
void main() {
  final cfg = BattleConfig.fromJson(
    jsonDecode(File('../app/assets/data/battle.json').readAsStringSync())
        as Map<String, dynamic>,
  ).training;

  test('포인트 = 포텐셜 1성당 6 · 수련 5레벨마다 1 · 돌파 6/10/16/24(누적)', () {
    expect(cfg.pointBudget(potential: 5, level: 80, breakthroughTier: 4), 102);
    expect(cfg.pointBudget(potential: 1, level: 4, breakthroughTier: 0), 6);
    expect(cfg.pointBudget(potential: 1, level: 5, breakthroughTier: 1), 13);
  });

  test('칸 효과·기본 상한(§1.2 표 · 2026-10-09 출시 전 점검)', () {
    expect(cfg.slotEffect[TrainSlot.attack], 0.05);
    expect(cfg.slotEffect[TrainSlot.defense], 0.055);
    expect(cfg.slotEffect[TrainSlot.hp], 0.09);
    expect(cfg.slotEffect[TrainSlot.push], 0.025);
    expect(cfg.slotEffect[TrainSlot.mass], 0.010);
    expect(cfg.slotBaseCap[TrainSlot.attack], 30);
    expect(cfg.slotBaseCap[TrainSlot.push], 20);
    expect(cfg.slotBaseCap[TrainSlot.mass], 10);
    expect(cfg.slotBaseCap[TrainSlot.grit], 10);
    // 우직 방어 +12 · 회피 −6 (설계 예)
    expect(
      cfg.slotCap(
        TrainSlot.defense,
        temperament: Temperament.steadfast,
        specialty: Specialty.toss,
      ),
      42,
    );
    expect(
      cfg.slotCap(
        TrainSlot.evade,
        temperament: Temperament.steadfast,
        specialty: Specialty.grip,
      ),
      14,
    );
  });

  test('체급은 무게 + · 속도 − · 밀어내기 힘은 미는 힘 × · 기술은 주특기마다 · 근성은 단계', () {
    final b = cfg.slotBonuses({
      TrainSlot.mass: 10,
      TrainSlot.push: 5,
      TrainSlot.tech: 10,
      TrainSlot.grit: 4,
    }, Specialty.strike);
    expect(b.massMult, closeTo(1 + 10 * cfg.slotEffect[TrainSlot.mass]!, 1e-9));
    expect(b.pushMult, closeTo(1 + 5 * cfg.slotEffect[TrainSlot.push]!, 1e-9));
    // 속도 칸은 없어졌다 — 속도는 체급의 대가로만 준다.
    expect(b.spdMult, closeTo(1 - 10 * cfg.massSpeedPenalty, 1e-9));
    expect(b.tech, closeTo(0.4, 1e-9));
    expect(b.grit, 4);
    expect(
      cfg.slotBonuses({TrainSlot.tech: 10}, Specialty.grip).tech,
      closeTo(0.3, 1e-9),
    );
  });

  test('옛 칸 키 speed 는 밀어내기 힘(push)으로 읽는다', () {
    final c = TrainingConfig.fromJson({
      'slots': {
        'speed': {'effect': 0.07, 'cap': 15},
      },
      'presets': {
        'x': {'speed': 4, 'attack': 2},
      },
    });
    expect(c.slotEffect[TrainSlot.push], 0.07);
    expect(c.slotBaseCap[TrainSlot.push], 15);
    expect(c.presets['x'], {TrainSlot.push: 4, TrainSlot.attack: 2});
    expect(TrainSlot.fromKeyOrNull('speed'), TrainSlot.push);
    expect(TrainSlot.push.key, 'push');
  });

  test('이전 환산 계수는 칸 효과와 따로 고정된다(옛 고인물 보너스 포인트 그대로)', () {
    // 처음 이전(2026-10-08)의 칸 효과 — 밸런스로 slots 를 바꿔도 이 값은 그대로여야 한다.
    expect(cfg.legacySlotEffect, {
      TrainSlot.attack: 0.03,
      TrainSlot.defense: 0.03,
      TrainSlot.hp: 0.04,
      TrainSlot.push: 0.02,
      TrainSlot.evade: 0.006,
      TrainSlot.crit: 0.01,
      TrainSlot.recovery: 0.015,
    });
    expect(const TrainingConfig().legacySlotEffect, cfg.legacySlotEffect);
    // 이전된 곤충이 약해지지 않으려면 칸 효과가 환산 계수보다 작으면 안 된다(밀어내기 힘 = 옛 속도 칸은 예외).
    for (final e in cfg.legacySlotEffect.entries) {
      if (e.key == TrainSlot.push) continue;
      expect(
        cfg.slotEffect[e.key]!,
        greaterThanOrEqualTo(e.value),
        reason: e.key.key,
      );
    }
  });

  test('추천 배분 — 칸 키 오타가 없고 주특기마다 기본 배분이 있다', () {
    final raw =
        ((jsonDecode(File('../app/assets/data/battle.json').readAsStringSync())
                    as Map<String, dynamic>)['training']
                as Map<String, dynamic>)['presets']
            as Map<String, dynamic>;
    expect(cfg.presets.keys, ['balanced', 'tank', 'heavy']);
    for (final e in raw.entries) {
      if (e.key.startsWith('_')) continue;
      // 오타 난 칸은 로딩을 통과하고 조용히 빠진다 — 키 수로 잡는다.
      expect(
        cfg.presets[e.key]!.length,
        (e.value as Map).length,
        reason: e.key,
      );
    }
    for (final s in Specialty.values) {
      expect(cfg.presets.containsKey(cfg.presetIdFor(s)), isTrue);
    }
    expect(cfg.presetIdFor(Specialty.toss), 'heavy');
  });

  test('다시 찍기 대기 = 30분 + 포인트당 3분, 최대 8시간', () {
    expect(cfg.respecWait(0), const Duration(minutes: 30));
    expect(cfg.respecWait(10), const Duration(minutes: 60));
    expect(cfg.respecWait(102), const Duration(minutes: 336));
    expect(cfg.respecWait(200), const Duration(hours: 8)); // 보너스 포인트가 큰 이전 곤충
  });

  test('포인트 비용은 낸 수만큼 오르고 102번째도 v1 14단계 근처', () {
    expect(
      cfg.pointCost(2, Grade.common),
      greaterThanOrEqualTo(cfg.pointCost(1, Grade.common)),
    );
    final last = cfg.pointCost(102, Grade.legendary);
    final v1Top = cfg.costFor(14, Grade.legendary);
    expect(last, lessThan(v1Top * 2));
    expect(last, greaterThan(v1Top / 4));
    expect(cfg.pointTime(102), lessThan(const Duration(hours: 12)));
  });

  test('결투석 — 젤리 40·60(5의 배수) · 드롭 확률 · 심연 10층마다 2·1', () {
    final st = cfg.stones;
    expect(st.jelly[DuelStone.element], 40);
    expect(st.jelly[DuelStone.temperament], 60);
    for (final p in st.jelly.values) {
      expect(roundJellyCost(p), p);
    }
    expect(st.eliteChance[DuelStone.element], 0.002);
    expect(st.eliteChance[DuelStone.temperament], isNull);
    expect(st.bossRepeatChance[DuelStone.element], 0.01);
    expect(st.bossRepeatChance[DuelStone.temperament], 0.005);
    expect(st.abyssEvery, 10);
    expect(st.abyssCount, {DuelStone.element: 2, DuelStone.temperament: 1});
  });

  test('펫 기여 계수 — 102포인트가 옛 부위 강화 만렙(×1.25)과 비슷', () {
    expect(1 + 102 * cfg.petPerPoint, closeTo(1.255, 1e-9));
    expect(cfg.legacyEnhancePetScale, 0.005);
  });
}
