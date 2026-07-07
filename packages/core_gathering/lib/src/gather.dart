import 'dart:math';

import 'package:core_models/core_models.dart';
import 'package:meta/meta.dart';

import 'weighted_pick.dart';

/// 한 번의 채집 수령 결과: 획득 재료 + 조우 개체 + 실제 반영된 경과시간.
@immutable
class GatherYield {
  const GatherYield({
    required this.materials,
    required this.encounters,
    required this.accrued,
  });

  final List<MaterialStack> materials;
  final List<IndividualBug> encounters;

  /// 상한(8h) clamp 후 실제 산출에 반영된 경과시간.
  final Duration accrued;

  static const GatherYield empty = GatherYield(
    materials: [],
    encounters: [],
    accrued: Duration.zero,
  );

  bool get isEmpty => materials.isEmpty && encounters.isEmpty;
}

/// 방치 채집 산출 계산 (§2.4). **완전 결정론**: 같은 입력 + 같은 [rng] → 같은 결과.
///
/// - 경과시간은 [maxAccrual](기본 8h)로 clamp (오프라인 상한).
/// - [installedAt] 이후 [now] 까지의 시간에 비례해 재료/조우가 늘어난다.
/// - [now] 가 [installedAt] 보다 이르면(시계 역행/조작) 산출 없음 → 기기시간 조작 방어.
/// - 트랩 [Trap.yieldMultiplier] 가 산출량에 곱해진다.
///
/// 재료 수량은 결정론 공식(floor)으로, 조우 개체의 정체(종/포텐셜/개체 변수)는
/// 주입된 [rng] 로 롤한다. [resolveSpecies] 는 speciesId→[Species], [idFactory] 는
/// 새 개체의 고유 id 를 공급한다(앱에서 uuid 등).
GatherYield accrue({
  required DateTime installedAt,
  required DateTime now,
  required SpawnEntry entry,
  required Trap trap,
  required Random rng,
  required Species Function(String speciesId) resolveSpecies,
  required String Function() idFactory,
  Duration maxAccrual = kMaxOfflineAccrual,
}) {
  final elapsed = now.difference(installedAt);
  if (elapsed <= Duration.zero) return GatherYield.empty;

  final capped = elapsed > maxAccrual ? maxAccrual : elapsed;
  final hours = capped.inMilliseconds / Duration.millisecondsPerHour;
  final mult = trap.yieldMultiplier;

  // 재료: 결정론 floor 공식.
  final materials = <MaterialStack>[];
  for (final rate in entry.materialsPerHour) {
    final amount = (rate.perHour * hours * mult).floor();
    if (amount > 0) {
      materials.add(MaterialStack(kind: rate.kind, amount: amount));
    }
  }

  // 조우: 개수는 결정론 floor, 정체는 seed 롤.
  final encounters = <IndividualBug>[];
  final count = (entry.encountersPerHour * hours * mult).floor();
  for (var i = 0; i < count; i++) {
    final sw = weightedPick(rng, entry.speciesWeights, (w) => w.weight);
    final pw = weightedPick(rng, entry.potentialWeights, (w) => w.weight);
    encounters.add(
      IndividualBug.roll(
        id: idFactory(),
        species: resolveSpecies(sw.speciesId),
        rng: rng,
        potential: pw.potential,
      ),
    );
  }

  return GatherYield(
    materials: materials,
    encounters: encounters,
    accrued: capped,
  );
}

/// 수령하지 않고 **현재까지 쌓인 산출량을 미리보기**한다 (개체를 롤하지 않음).
/// 개수는 [accrue] 와 동일한 결정론 floor 공식을 쓰므로, 실제 수령 시 개수와 일치한다.
class GatherEstimate {
  const GatherEstimate({
    required this.materialCount,
    required this.encounterCount,
    required this.accrued,
  });

  final int materialCount;
  final int encounterCount;
  final Duration accrued;

  bool get hasYield => materialCount > 0 || encounterCount > 0;

  static const GatherEstimate empty = GatherEstimate(
    materialCount: 0,
    encounterCount: 0,
    accrued: Duration.zero,
  );
}

/// [accrue] 와 같은 입력으로, rng 없이 대기 중인 산출 개수만 계산한다(홈 화면 미리보기용).
GatherEstimate estimateYield({
  required DateTime installedAt,
  required DateTime now,
  required SpawnEntry entry,
  required Trap trap,
  Duration maxAccrual = kMaxOfflineAccrual,
}) {
  final elapsed = now.difference(installedAt);
  if (elapsed <= Duration.zero) return GatherEstimate.empty;

  final capped = elapsed > maxAccrual ? maxAccrual : elapsed;
  final hours = capped.inMilliseconds / Duration.millisecondsPerHour;
  final mult = trap.yieldMultiplier;

  var materials = 0;
  for (final rate in entry.materialsPerHour) {
    materials += (rate.perHour * hours * mult).floor();
  }
  final encounters = (entry.encountersPerHour * hours * mult).floor();

  return GatherEstimate(
    materialCount: materials,
    encounterCount: encounters,
    accrued: capped,
  );
}
