import 'dart:convert';
import 'dart:io';

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:test/test.dart';

/// 순차 미션 — 목표 상한 · 강화 미션의 남은 레벨 · 교체(2026-10-10). 실제 게임 데이터로 돈다.
Map<String, dynamic> _json(String name) =>
    jsonDecode(File('../app/assets/data/$name').readAsStringSync())
        as Map<String, dynamic>;

final _t = DateTime.utc(2026, 10, 10, 12);

void main() {
  final cfg = MissionConfig.fromJson(_json('missions.json'));
  final run = RunConfig.fromJson(_json('run_config.json'));
  final hunt = cfg.missions.firstWhere(
    (m) => m.type == MissionType.killMonsters,
  );
  final power = cfg.missions.firstWhere(
    (m) => m.type == MissionType.buyUpgrades,
  );
  final huntIdx = cfg.missions.indexOf(hunt);
  final powerIdx = cfg.missions.indexOf(power);

  /// [active] 가 진행 중이 되게 순환 위치를 맞춘 세이브.
  SaveGame at(int active, {Map<UpgradeKind, int>? levels, int jelly = 100}) {
    final s = SaveGame.initial(createdAt: _t);
    return s.copyWith(
      missionClaims: {kMissionSwapKey: active},
      upgradeLevels: levels,
      materials: {...s.materials, MaterialKind.jelly: jelly},
    );
  }

  Map<UpgradeKind, int> maxed({int short = 0}) {
    final m = {
      for (final e in run.upgrades.entries) e.key: e.value.maxLevel ?? 0,
    };
    if (short > 0) {
      m[UpgradeKind.attack] = m[UpgradeKind.attack]! - short;
    }
    return m;
  }

  test('목표는 받을수록 커지지만 goalMax 에서 멈춘다(사냥 1,000 · 강화 50)', () {
    expect(hunt.goalMax, 1000);
    expect(power.goalMax, 50);
    expect(hunt.goalAt(0), 20);
    expect(hunt.goalAt(20), 1000); // 상한 전엔 1,734
    expect(power.goalAt(20), 50); // 상한 전엔 2,850
    expect(hunt.goalAt(200), 1000);
  });

  test('교체 횟수도 순환 위치에 들어간다(받은 횟수 + 교체 횟수의 합)', () {
    expect(cfg.activeIndex({hunt.id: 2, kMissionSwapKey: 1}), 0);
    expect(cfg.activeIndex({hunt.id: 2}), 2 % cfg.missions.length);
  });

  test('강화 미션 목표는 남은 강화 레벨보다 크지 않다', () {
    final s = at(powerIdx, levels: maxed(short: 7));
    expect(upgradeLevelsLeft(s, run), 7);
    expect(missionGoal(s, power, run), 7);
    // 7레벨을 사서 다 채우면 받을 수 있다(진행도 + 남은 레벨로 잰다).
    final bought = s.copyWith(
      upgradeLevels: maxed(),
      missionProgress: {power.id: 7},
    );
    expect(missionGoal(bought, power, run), 7);
    expect(missionClaimable(bought, power, run), isTrue);
  });

  test('다 키웠으면 깰 수 없는 미션 — 받을 수 없고 교체는 무료', () {
    final s = at(powerIdx, levels: maxed());
    expect(missionImpossible(s, power, run), isTrue);
    // 목표 0 이라고 공짜로 받으면 안 된다.
    expect(missionClaimable(s, power, run), isFalse);
    expect(missionSwapCost(s, cfg, run), 0);

    final r = applyMissionSwap(s.copyWith(materials: const {}), cfg, run);
    expect(r.error, isNull);
    expect(r.jelly, 0);
    expect(cfg.activeIndex(r.save!.missionClaims), isNot(powerIdx));
  });

  test('교체 = 젤리 swapJelly(5 단위) · 보상 없이 다음 미션 · 진행도 초기화', () {
    expect(cfg.swapJelly, 5);
    final s = at(
      huntIdx,
    ).copyWith(missionProgress: {hunt.id: hunt.goalAt(0) - 1});
    expect(missionSwapCost(s, cfg, run), cfg.swapJelly);
    final r = applyMissionSwap(s, cfg, run);
    expect(r.error, isNull);
    final out = r.save!;
    expect(out.materialCount(MaterialKind.jelly), 100 - cfg.swapJelly);
    expect(out.missionClaims[kMissionSwapKey], huntIdx + 1);
    expect(out.missionClaimCount(hunt.id), 0); // 받은 걸로 치지 않는다(다음 목표가 안 커진다)
    expect(out.missionProgress, isEmpty);
    expect(
      cfg.activeIndex(out.missionClaims),
      (huntIdx + 1) % cfg.missions.length,
    );
  });

  test('젤리가 모자라거나 다 채운 미션이면 바꾸지 않는다', () {
    expect(
      applyMissionSwap(at(huntIdx, jelly: cfg.swapJelly - 1), cfg, run).error,
      'not_enough_jelly',
    );
    final done = at(
      huntIdx,
    ).copyWith(missionProgress: {hunt.id: hunt.goalAt(0)});
    expect(applyMissionSwap(done, cfg, run).error, 'claimable');
  });
}
