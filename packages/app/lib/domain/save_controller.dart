import 'package:core_gathering/core_gathering.dart';
import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/save_repository.dart';
import 'gather_service.dart';
import 'providers.dart';
import 'save_game.dart';

/// 세이브 상태를 보유·변경하는 Riverpod 컨트롤러.
/// 변경 액션은 상태를 갱신하고 즉시 저장소에 반영(자동 저장)한다.
class SaveController extends AsyncNotifier<SaveGame> {
  /// 마지막 로드 시 계산된 오프라인 보상(UI 가 1회 표시 후 [consumeOffline]).
  OfflineReport? pendingOffline;

  @override
  Future<SaveGame> build() async {
    final data = await ref.watch(gameDataProvider.future);
    final repo = ref.watch(saveRepositoryProvider);
    final clock = ref.read(clockProvider);
    var save = await repo.load();
    final now = clock.now().toUtc();

    // 오프라인 정산
    final config = data.runConfig;
    if (config != null) {
      final elapsed = now.difference(save.lastSeen);
      if (elapsed.inSeconds > 60) {
        final stats = deriveStats(
          config,
          upgradeLevels: save.upgradeLevels,
          characterLevel: save.level,
          bugsCollected: save.bugs.length,
        );
        final report = computeOfflineReward(
          config: config,
          stageNumber: save.stageNumber,
          stats: stats,
          elapsed: elapsed,
        );
        if (!report.isEmpty) {
          var xp = save.xp + report.xp;
          var level = save.level;
          while (xp >= xpForNextLevel(level)) {
            xp -= xpForNextLevel(level);
            level++;
          }
          save = save.copyWith(
            gold: save.gold + report.gold,
            xp: xp,
            level: level,
          );
          pendingOffline = report;
        }
      }
    }

    save = save.copyWith(lastSeen: now);
    await repo.save(save);
    return save;
  }

  void consumeOffline() => pendingOffline = null;

  GatherService get _service => ref.read(gatherServiceProvider);
  SaveRepository get _repo => ref.read(saveRepositoryProvider);

  Future<void> _commit(SaveGame save) async {
    final stamped = save.copyWith(
      lastSeen: ref.read(clockProvider).now().toUtc(),
    );
    state = AsyncData(stamped);
    await _repo.save(stamped);
  }

  /// 슬롯에 트랩 설치/교체 후 저장.
  Future<void> installTrap({
    required int slotIndex,
    required String fieldId,
    required String trapId,
  }) async {
    final updated = _service.installTrap(
      state.requireValue,
      slotIndex: slotIndex,
      fieldId: fieldId,
      trapId: trapId,
    );
    await _commit(updated);
  }

  /// 슬롯 수령. 산출이 있으면 세이브에 반영·저장하고, 획득분을 반환한다.
  Future<GatherYield> collect(int slotIndex) async {
    final result = _service.collect(state.requireValue, slotIndex: slotIndex);
    if (!result.harvest.isEmpty) {
      await _commit(result.save);
    }
    return result.harvest;
  }

  // --- v2 런 액션 ---

  /// 서식지/보스 파괴 보상 반영. 경험치 초과 시 레벨업(넘침 이월).
  Future<void> applyReward({
    required int gold,
    required int xp,
    IndividualBug? bug,
    Map<MaterialKind, int>? materials,
  }) async {
    final s = state.requireValue;
    var newXp = s.xp + xp;
    var newLevel = s.level;
    while (newXp >= xpForNextLevel(newLevel)) {
      newXp -= xpForNextLevel(newLevel);
      newLevel++;
    }
    final newMaterials = Map<MaterialKind, int>.from(s.materials);
    if (materials != null) {
      for (final e in materials.entries) {
        newMaterials[e.key] = (newMaterials[e.key] ?? 0) + e.value;
      }
    }
    await _commit(
      s.copyWith(
        gold: s.gold + gold,
        xp: newXp,
        level: newLevel,
        materials: newMaterials,
        bugs: bug == null ? null : [...s.bugs, bug],
      ),
    );
  }

  /// 업그레이드를 최대 [count] 레벨까지 구매(골드 되는 만큼). 구매한 레벨 수 반환.
  Future<int> buyUpgrade(UpgradeKind kind, {int count = 1}) async {
    final config = ref.read(gameDataProvider).requireValue.runConfig;
    if (config == null) return 0;
    final s = state.requireValue;
    final spec = config.upgrade(kind);
    var level = s.upgradeLevel(kind);
    var gold = s.gold;
    var bought = 0;
    for (var i = 0; i < count; i++) {
      final cost = upgradeCost(spec, level);
      if (gold < cost) break;
      gold -= cost;
      level++;
      bought++;
    }
    if (bought == 0) return 0;
    final levels = Map<UpgradeKind, int>.from(s.upgradeLevels)..[kind] = level;
    await _commit(s.copyWith(gold: gold, upgradeLevels: levels));
    return bought;
  }

  /// 도달 스테이지 갱신(최고 기록만).
  Future<void> reachStage(int stage) async {
    final s = state.requireValue;
    if (stage <= s.stageNumber) return;
    await _commit(s.copyWith(stageNumber: stage));
  }
}

final saveControllerProvider = AsyncNotifierProvider<SaveController, SaveGame>(
  SaveController.new,
);
