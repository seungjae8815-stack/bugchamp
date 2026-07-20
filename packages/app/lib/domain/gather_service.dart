import 'dart:math';

import 'package:core_gathering/core_gathering.dart';
import 'package:core_models/core_models.dart';

import '../data/game_data.dart';
import 'package:core_save/core_save.dart';

/// 채집 수령 결과: 갱신된 세이브 + 이번에 얻은 산출.
class CollectResult {
  const CollectResult({required this.save, required this.harvest});

  final SaveGame save;
  final GatherYield harvest;
}

/// 방치 채집 로직을 **실제 세이브 상태**에 연결하는 순수 서비스.
/// Hive/Riverpod 을 모른다 → 단위테스트 용이.
class GatherService {
  const GatherService({
    required this.data,
    required this.clock,
    required this.idFactory,
  });

  final GameData data;
  final Clock clock;

  /// 새 개체 id 공급 (앱: uuid v4).
  final String Function() idFactory;

  /// 슬롯에 트랩을 설치(또는 교체)한다. installedAt = 현재 시각.
  SaveGame installTrap(
    SaveGame save, {
    required int slotIndex,
    required String fieldId,
    required String trapId,
  }) {
    if (slotIndex < 0 || slotIndex >= kTrapSlots) {
      throw ArgumentError.value(slotIndex, 'slotIndex', '0..${kTrapSlots - 1}');
    }
    if (!save.unlockedFieldIds.contains(fieldId)) {
      throw ArgumentError.value(fieldId, 'fieldId', '해금되지 않은 필드');
    }
    if (data.spawnTable.lookup(fieldId, trapId) == null) {
      throw ArgumentError('출현표에 없는 조합: $fieldId × $trapId');
    }
    final others = save.installations
        .where((i) => i.slotIndex != slotIndex)
        .toList();
    return save.copyWith(
      installations: [
        ...others,
        TrapInstallation(
          slotIndex: slotIndex,
          fieldId: fieldId,
          trapId: trapId,
          installedAt: clock.now().toUtc(),
        ),
      ],
    );
  }

  /// 슬롯 트랩의 방치분을 수령한다. 산출을 세이브에 반영하고 타이머를 리셋한다.
  /// 산출 seed 는 설치 상태에서 파생 → 재수령으로 리롤 불가(어뷰징 방지).
  CollectResult collect(SaveGame save, {required int slotIndex}) {
    final inst = save.installationAt(slotIndex);
    if (inst == null) {
      return CollectResult(save: save, harvest: GatherYield.empty);
    }
    final entry = data.spawnTable.lookup(inst.fieldId, inst.trapId);
    if (entry == null) {
      return CollectResult(save: save, harvest: GatherYield.empty);
    }

    final now = clock.now().toUtc();
    final harvest = accrue(
      installedAt: inst.installedAt,
      now: now,
      entry: entry,
      trap: data.trap(inst.trapId),
      rng: Random(_seedFor(inst)),
      resolveSpecies: data.species,
      idFactory: idFactory,
    );

    if (harvest.isEmpty) {
      // 산출 없음: 타이머 유지(아주 짧은 방치 손해 방지).
      return CollectResult(save: save, harvest: harvest);
    }

    final newMaterials = Map<MaterialKind, int>.from(save.materials);
    for (final m in harvest.materials) {
      newMaterials[m.kind] = (newMaterials[m.kind] ?? 0) + m.amount;
    }
    final newInstallations = save.installations
        .map((i) => i.slotIndex == slotIndex ? i.copyWith(installedAt: now) : i)
        .toList();

    final updated = save.copyWith(
      bugs: [...save.bugs, ...harvest.encounters],
      materials: newMaterials,
      installations: newInstallations,
    );
    return CollectResult(save: updated, harvest: harvest);
  }

  int _seedFor(TrapInstallation inst) =>
      inst.installedAt.microsecondsSinceEpoch ^ (inst.slotIndex * 0x9E3779B1);
}
