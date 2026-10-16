import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';

import 'individual_grade.dart';
import 'save_game.dart';

/// 희귀도 올리기(2026-10-16 사장님 확정, 1.0.22, `docs/design_bug_rarity.md`) — 곤충 하나 +
/// **같은 종 · 같은 희귀도 곤충 [BugRarityConfig.upFodder] 마리**(사라짐) → 희귀도 +1(전설까지).
/// 키운 것(등급·롤·훈련·패시브)은 그대로다. 무료 경로뿐(결투 능력치 — 젤리로 팔지 않는다 §2.8).
/// 앱·서버가 같은 함수를 쓴다 — 서버 업로드 검사 [rarityUpAllowed] 도 같은 재료 규칙을 본다.

/// [target] 의 재료가 될 수 있는 곤충(덜 아까운 것부터) — 같은 종 · 같은 희귀도 · 알 아님 ·
/// 보호(장착·부화·훈련·잠금 — `pinnedBugIds`) 아님 · 투자 안 한 곤충(`isPreciousBug` 아님).
List<IndividualBug> rarityUpFodder(
  SaveGame s,
  IndividualBug target,
  PetConfig pet,
  Map<String, Species> speciesById,
) {
  final sp = speciesById[target.speciesId];
  if (sp == null) return const [];
  final r = pet.rarityOf(target, sp);
  final pinned = s.pinnedBugIds;
  final out = [
    for (final b in s.bugs)
      if (b.id != target.id &&
          b.speciesId == target.speciesId &&
          b.stage != LifeStage.egg &&
          !pinned.contains(b.id) &&
          !isPreciousBug(b) &&
          pet.rarityOf(b, sp) == r)
        b,
  ]..sort((a, b) => bugFodderRank(a).compareTo(bugFodderRank(b)));
  return out;
}

/// [bugId] 의 희귀도를 한 단계 올린다 — 재료는 [rarityUpFodder] 의 앞에서부터 자동으로 고른다.
/// extra: `from`·`to`(희귀도 키) · `fodder`(사라진 id 목록).
GradeOp rarityUp(
  SaveGame s,
  String bugId,
  PetConfig pet,
  Map<String, Species> speciesById,
) {
  final cfg = pet.bugRarity;
  if (!cfg.enabled || cfg.upFodder <= 0) return const GradeOp.fail('off');
  final i = s.bugs.indexWhere((b) => b.id == bugId);
  if (i < 0) return const GradeOp.fail('no_bug');
  final b = s.bugs[i];
  if (b.stage == LifeStage.egg) return const GradeOp.fail('egg');
  final sp = speciesById[b.speciesId];
  if (sp == null) return const GradeOp.fail('no_species');
  final r = pet.rarityOf(b, sp);
  if (r == Grade.legendary) return const GradeOp.fail('max');
  final fodder = rarityUpFodder(s, b, pet, speciesById);
  if (fodder.length < cfg.upFodder) return const GradeOp.fail('no_fodder');
  final used = {for (final f in fodder.take(cfg.upFodder)) f.id};
  final next = Grade.values[r.index + 1];
  final up = b.copyWith(rarity: next);
  return GradeOp.ok(
    s.copyWith(
      bugs: [
        for (final x in s.bugs)
          if (x.id == b.id) up else if (!used.contains(x.id)) x,
      ],
      // 사라진 곤충의 표식 정리(펫 장착·부화 칸은 재료에서 이미 빠졌다).
      lockedBugIds: s.lockedBugIds.difference(used),
    ),
    extra: {'from': r.key, 'to': next.key, 'fodder': used.toList()},
  );
}

/// 서버 업로드 검사 — 같은 id 의 희귀도가 [from] 에서 [to] 로 오른 것을 인정할지.
/// 단계마다 **이번 업로드에서 사라진 같은 종 · 그 단계 희귀도 곤충** [BugRarityConfig.upFodder] 마리를 쓴다
/// ([gone] 에서 꺼내 쓰므로 같은 재료를 두 번 세지 않는다). 모자라면 false. 쓴 재료 id 는 [used] 에 넣는다
/// (서버가 정수 허용치에서 뺀다 — 재료로 쓴 곤충을 정수로도 또 받지 못하게).
bool rarityUpAllowed({
  required Grade from,
  required Grade to,
  required String speciesId,
  required List<({String id, String speciesId, Grade rarity})> gone,
  Set<String>? used,
  required BugRarityConfig cfg,
}) {
  if (!cfg.enabled || cfg.upFodder <= 0 || to.index <= from.index) {
    return false;
  }
  // 사본에서 먼저 다 찾아본다 — 모자라면 [gone]·[used] 를 건드리지 않는다(다른 곤충의 재료를 빼앗지 않게).
  final left = [...gone];
  final take = <String>[];
  for (var g = from.index; g < to.index; g++) {
    for (var k = 0; k < cfg.upFodder; k++) {
      final j = left.indexWhere(
        (x) => x.speciesId == speciesId && x.rarity.index == g,
      );
      if (j < 0) return false;
      take.add(left[j].id);
      left.removeAt(j);
    }
  }
  gone
    ..clear()
    ..addAll(left);
  used?.addAll(take);
  return true;
}
