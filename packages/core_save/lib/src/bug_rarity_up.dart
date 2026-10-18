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
/// 그 밖에도 재료로 쓰지 않는다(2026-10-16 출시 전 검토 — 아까운 곤충이 조용히 사라지지 않게):
/// 등급 올린·높게 태어난 곤충(포텐셜 > 1) · 옛 합성 곤충(`su` > 0) · 뽑기·결제 출신(`gc`) · 패시브 재굴림한 곤충(`pr`).
/// 서버 [rarityUpAllowed] 는 사라진 곤충만 보므로 이 규칙과 무관하다(앱이 덜 쓰는 쪽이라 안전).
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
          _fodderOk(b, pinned) &&
          pet.rarityOf(b, sp) == r)
        b,
  ]..sort((a, b) => bugFodderRank(a).compareTo(bugFodderRank(b)));
  return out;
}

/// 희귀도 올리기 재료가 될 수 있는 곤충인가(종·희귀도 말고) — [rarityUpFodder]·[rarityUpReadyIds] 공용.
bool _fodderOk(IndividualBug b, Set<String> pinned) =>
    b.stage != LifeStage.egg &&
    !pinned.contains(b.id) &&
    !isPreciousBug(b) &&
    b.potential <= 1 &&
    b.synthUps == 0 &&
    !b.fromGacha &&
    b.passiveRoll == null;

/// 지금 바로 희귀도를 올릴 수 있는 곤충 id(채집함 "올릴 수 있음" 표시·거르기, 1.0.22) — [rarityUp] 이 성공할 곤충과 같다.
/// 한 번 훑기(곤충 100마리 칸마다 [rarityUpFodder] 를 부르지 않게).
Set<String> rarityUpReadyIds(
  SaveGame s,
  PetConfig pet,
  Map<String, Species> speciesById,
) {
  final cfg = pet.bugRarity;
  if (!cfg.enabled || cfg.upFodder <= 0) return const {};
  final pinned = s.pinnedBugIds;
  final rarity = <String, Grade>{};
  final fodderN = <String, int>{};
  String key(IndividualBug b, Grade r) => '${b.speciesId}|${r.index}';
  for (final b in s.bugs) {
    final sp = speciesById[b.speciesId];
    if (sp == null) continue;
    final r = pet.rarityOf(b, sp);
    rarity[b.id] = r;
    if (_fodderOk(b, pinned))
      fodderN.update(key(b, r), (n) => n + 1, ifAbsent: () => 1);
  }
  return {
    for (final b in s.bugs)
      if (rarity[b.id] case final r?)
        if (b.stage != LifeStage.egg &&
            r != Grade.legendary &&
            (fodderN[key(b, r)] ?? 0) - (_fodderOk(b, pinned) ? 1 : 0) >=
                cfg.upFodder)
          b.id,
  };
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

/// 희귀도 자동 올리기(1.0.22 출시 점검 — 같은 종이 쌓이면 하나씩 올리기가 번거로웠다).
/// 올릴 수 있는 곤충을 **아끼는 것부터**(보호 곤충 → [bugFodderRank] 큰 쪽) 골라 [rarityUp] 을 되풀이한다 —
/// 올린 곤충이 다시 위 희귀도 재료가 되는 것까지 이어서(서버 [rarityUpAllowed] 가 같은 이음을 센다).
/// 재료 규칙은 [rarityUpFodder] 그대로라 키운·잠근·장착한 곤충은 사라지지 않는다.
/// extra: `ups`(올린 횟수) · `fodder`(사라진 재료 수) · `bugs`(올린 곤충 id → 최종 희귀도 키).
/// 한 번도 못 올리면 `none` 실패. [dryRun] 이어도 같은 결과(세이브는 화면 미리보기용).
GradeOp autoRarityUp(
  SaveGame s,
  PetConfig pet,
  Map<String, Species> speciesById,
) {
  final cfg = pet.bugRarity;
  if (!cfg.enabled || cfg.upFodder <= 0) return const GradeOp.fail('off');
  var cur = s;
  var ups = 0;
  var fodder = 0;
  final finals = <String, String>{};
  // 한 번에 1마리 이상 사라지므로 곤충 수만큼이면 반드시 끝난다(안전장치).
  for (var guard = 0; guard <= s.bugs.length; guard++) {
    final pinned = cur.pinnedBugIds;
    final cands =
        [
          for (final b in cur.bugs)
            if (b.stage != LifeStage.egg) b,
        ]..sort((a, b) {
          final pa = pinned.contains(a.id) ? 1 : 0;
          final pb = pinned.contains(b.id) ? 1 : 0;
          if (pa != pb) return pb - pa;
          return bugFodderRank(b).compareTo(bugFodderRank(a));
        });
    GradeOp? hit;
    for (final c in cands) {
      final r = rarityUp(cur, c.id, pet, speciesById);
      if (r.isOk) {
        hit = r;
        finals[c.id] = r.extra['to'] as String;
        break;
      }
    }
    if (hit == null) break;
    cur = hit.save!;
    ups++;
    final used = (hit.extra['fodder'] as List).cast<String>();
    fodder += used.length;
    for (final id in used) {
      finals.remove(id); // 앞서 올렸다가 재료가 된 곤충은 결과 목록에서 뺀다
    }
  }
  if (ups == 0) return const GradeOp.fail('none');
  return GradeOp.ok(cur, extra: {'ups': ups, 'fodder': fodder, 'bugs': finals});
}

/// 서버 업로드 검사 — 같은 id 의 희귀도가 [from] 에서 [to] 로 오른 것을 인정할지.
/// 단계마다 **이번 업로드에서 사라진 같은 종 · 그 단계 희귀도 곤충** [BugRarityConfig.upFodder] 마리를 쓴다
/// ([gone] 에서 꺼내 쓰므로 같은 재료를 두 번 세지 않는다). 모자라면 false. 쓴 재료 id 는 [used] 에 넣는다
/// (서버가 정수 허용치에서 뺀다 — 재료로 쓴 곤충을 정수로도 또 받지 못하게).
///
/// 그 희귀도 재료가 모자라면 **한 단계 아래 곤충 1 + [BugRarityConfig.upFodder] 마리**를 재료 하나로 센다(1.0.22 출시 점검):
/// 업로드 사이(1분)에 올린 곤충을 바로 다음 올리기의 재료로 쓰면, 그 곤충은 저장본의 옛 희귀도로 사라진 것으로 보인다.
/// 이걸 안 세면 서버가 다음 올리기를 되돌리고 재료만 잃었다(희귀도 자동 올리기는 늘 이렇게 이어진다).
/// 아래 단계 4마리는 실제로 그 올리기에 든 곤충과 같은 수라 재료를 늘려 주지 않는다.
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
  // 희귀도 [g] 재료 하나를 꺼낸다 — 없으면 한 단계 아래 1 + upFodder 마리로.
  bool one(int g) {
    final j = left.indexWhere(
      (x) => x.speciesId == speciesId && x.rarity.index == g,
    );
    if (j >= 0) {
      take.add(left[j].id);
      left.removeAt(j);
      return true;
    }
    if (g <= 0) return false;
    for (var k = 0; k <= cfg.upFodder; k++) {
      if (!one(g - 1)) return false;
    }
    return true;
  }

  for (var g = from.index; g < to.index; g++) {
    for (var k = 0; k < cfg.upFodder; k++) {
      if (!one(g)) return false;
    }
  }
  gone
    ..clear()
    ..addAll(left);
  used?.addAll(take);
  return true;
}
