import 'dart:math';

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';

import 'save_game.dart';

/// 방치 처치 [rolls]번의 곤충·재료 드롭 결과.
class IdleDrops {
  const IdleDrops({
    required this.bugs,
    required this.materials,
    required this.rarePity,
    this.blocked = 0,
  });

  /// 새로 얻은 곤충(알 상태). 채집함 여유분까지만.
  final List<IndividualBug> bugs;

  /// 드롭·자동 방생을 더한 재료(저장본 재료 포함 — 그대로 세이브에 넣는다).
  final Map<MaterialKind, int> materials;

  /// 굴린 뒤의 희귀 천장 카운터.
  final int rarePity;

  /// 채집함이 가득 차서 **못 받은** 곤충 수(§2.1 "가득 차면 안내" — 복귀 팝업이 알린다).
  final int blocked;
}

/// 방치 정산(오프라인)의 곤충·재료 드롭 — **앱 오프라인 정산과 서버 `/sync` 가 같은 함수**를 쓴다.
///
/// 처치 하나마다 온라인과 같은 규칙으로 굴린다: 등급 가중치(`pickDropSpecies`) · 희귀 천장 ·
/// 등급 필터(미달은 재료로 자동 방생, 젤리 없음 §2.1) · 채집함 여유분 · 이색 · 재료 드롭(`materialDrop`).
///
/// ⚠️ 앱은 2026-07 기기 권위 전환 뒤 서버 `/sync` 를 부르지 않아, 이 드롭이 **오프라인에서 통째로 빠져 있었다**
/// (2026-10-04 발견 — 꺼 둔 동안 곤충·재료 0). 펫 곡선(§2.4 `petFillByDay`)은 이 드롭을 전제로 쟀다.
///
/// [bugFind]·[materialFind] 는 정산에 쓰는 능력치(강화만 — 펫·장비 밖, 온라인보다 낮다).
/// [rng]·[newId] 는 바깥에서 주입한다(순수 패키지 — 전역 난수·uuid 를 모른다).
/// [research] = 연구소 "분해 기술"(`salvageMat`) — 자동 방생 재료(젤리 없음)에만.
IdleDrops rollIdleDrops({
  required SaveGame save,
  required int rolls,
  required List<Species> species,
  required RunConfig run,
  required PetConfig pet,
  IapConfig? iap,
  required double bugFind,
  required double materialFind,
  required DateTime now,
  required Random rng,
  required String Function() newId,
  ResearchEffects research = ResearchEffects.none,
}) {
  final newBugs = <IndividualBug>[];
  final mats = Map<MaterialKind, int>.from(save.materials);
  // 채집함 여유분까지만 받는다(가득 차면 곤충 획득 차단 — 재료는 계속).
  var bugRoom = save.storageFree;
  var pity = save.rarePity;
  var blocked = 0;
  const regular = kRegularMaterials;

  for (var i = 0; i < rolls; i++) {
    final pityDue = run.rarePityKills > 0 && pity >= run.rarePityKills;
    pity++;
    if (species.isNotEmpty &&
        (pityDue || rng.nextDouble() < run.bugDropChance * bugFind)) {
      // 종·희귀도는 앱 실시간 처치·채집망과 같은 함수(곤충 희귀도 — 1.0.22). id 를 먼저 만든다(희귀도가 id 롤).
      final id = newId();
      final drop = pickWildDrop(
        rng,
        species,
        run: run,
        pet: pet,
        id: id,
        now: now,
        pity: pityDue,
      );
      if (drop != null) {
        final sp = drop.species;
        // 천장은 실제로 받았거나 필터로 재료가 됐을 때만 되감는다 — 채집함이 가득 차
        // 버려진 롤로 되감으면 천장이 허공에 쓰인다.
        final rarePlus = drop.rarity.index >= Grade.rare.index;
        // 온라인과 같은 분포: rng*rng 라 고포텐셜이 드물다.
        final potential = pet.wildPotential(rng.nextDouble(), rng.nextDouble());
        if (!save.acceptsGrade(drop.rarity)) {
          // 분해 기술(연구) → 스킨 계열 보너스 순(앱 손 분해·실시간 방생과 같다).
          final base = pet.releaseMaterial(drop.rarity, research: research);
          final give = iap == null
              ? base
              : iap.skinnedReleaseMaterial(base, save.ownedSkins, sp.id);
          if (give > 0) {
            final kind = regular[rng.nextInt(regular.length)];
            mats[kind] = (mats[kind] ?? 0) + give;
          }
          if (rarePlus) pity = 0;
        } else if (bugRoom > 0) {
          newBugs.add(
            IndividualBug.roll(
              id: id,
              species: sp,
              rng: rng,
              potential: potential.clamp(1, 5),
              variantChance: pet.variantWildChance,
            ).copyWith(
              stage: LifeStage.egg,
              stageSince: now,
              newGen: pet.individualGrade.enabled,
              rarity: drop.fixed,
            ),
          );
          bugRoom--;
          if (rarePlus) pity = 0;
        } else {
          blocked++;
        }
      }
    }
    // ⚠️ 수량에 스테이지 배율(`materialAmountMult`)을 **일부러 곱하지 않는다**(2026-10-04 측정·확정).
    // 재료가 병목인 곳은 사냥터 1~2 뿐이고 그 뒤는 98% 가 남는다 — 곱하면 오프라인 재료가 온라인의
    // 1.2배가 되어 켜 두는 보상만 깎인다. 이 덕에 오프라인 재료는 초반에만 의미가 있다.
    final drop = materialDrop(run, materialFind);
    if (rng.nextDouble() < drop.chance) {
      final kind = regular[rng.nextInt(regular.length)];
      mats[kind] =
          (mats[kind] ?? 0) +
          max(1, ((1 + rng.nextInt(2)) * drop.amountMult).round());
    }
  }
  return IdleDrops(
    bugs: newBugs,
    materials: mats,
    rarePity: pity,
    blocked: blocked,
  );
}
