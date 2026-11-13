import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';

import 'individual_grade.dart';
import 'save_game.dart';

/// 희귀도 올리기(2026-10-16 사장님 확정, 1.0.22, `docs/design_bug_rarity.md`). 앱·서버가 같은 함수를 쓴다.
///
/// 두 가지 규칙이 있다 — `pets.json → bugRarity.worth` 가 있으면 **양분 게이지**, 없으면 옛 3마리 규칙.
/// - **양분 게이지**(2026-11-09 사장님 확정): 같은 종 곤충을 먹이면 그 곤충의 가치(희귀도가 낮을수록 적다 —
///   [BugRarityConfig.worth])만큼 게이지([IndividualBug.rarityWorth])가 차고, 총 가치가 다음 희귀도 가치에 닿으면
///   희귀도가 오른다. 희귀도가 달라도 먹일 수 있다(목표보다 높은 희귀도는 재료가 되지 않는다 — 실수로 갈아 넣지 않게).
///   서버는 "오른 가치 ≤ 이번 업로드에서 사라진 같은 종 곤충의 가치"로 검사한다([takeRarityWorth]).
/// - **옛 규칙**: 곤충 하나 + 같은 종 · 같은 희귀도 곤충 [BugRarityConfig.upFodder] 마리(사라짐) → 희귀도 +1.
/// 키운 것(등급·롤·훈련·패시브)은 그대로다. 무료 경로뿐(결투 능력치 — 젤리로 팔지 않는다 §2.8).

/// [b] 의 양분(희귀도 문턱 + 모은 양분) — 희귀도를 정하는 값. 게이지가 꺼져 있으면 0.
int bugRarityWorth(IndividualBug b, BugRarityConfig cfg) =>
    cfg.worthOn ? cfg.worthOfRarity(cfg.ownRarityOf(b)) + b.rarityWorth : 0;

/// [b] 를 **먹이면 채우는 양**(희귀도별 채우는 양 + 그 곤충이 모은 양분, 2026-11-09 2배씩). 문턱보다 작거나 같다 —
/// 그래서 먹일수록 총량이 줄어 서버 검사([takeRarityWorth])가 보수적으로 맞는다. 게이지가 꺼져 있으면 0.
int bugFeedValue(IndividualBug b, BugRarityConfig cfg) =>
    cfg.worthOn ? cfg.feedOfRarity(cfg.ownRarityOf(b)) + b.rarityWorth : 0;

/// [target] 의 재료가 될 수 있는 곤충 — 같은 종 · 알 아님 · 보호(장착·부화·훈련·잠금 — `pinnedBugIds`) 아님 ·
/// 투자 안 한 곤충(`isPreciousBug` 아님). 그 밖에도 재료로 쓰지 않는다(2026-10-16 출시 전 검토 — 아까운 곤충이 조용히
/// 사라지지 않게): 등급 올린·높게 태어난 곤충(포텐셜 > 1) · 옛 합성 곤충(`su` > 0) · 뽑기·결제 출신(`gc`) · 패시브 재굴림한 곤충(`pr`).
/// 희귀도: 양분 게이지면 **목표 이하**(가치 작은 것부터), 옛 규칙이면 **같은 희귀도**(덜 아까운 것부터).
/// 서버 검사는 사라진 곤충만 보므로 이 규칙과 무관하다(앱이 덜 쓰는 쪽이라 안전).
List<IndividualBug> rarityUpFodder(
  SaveGame s,
  IndividualBug target,
  PetConfig pet,
  Map<String, Species> speciesById,
) {
  final sp = speciesById[target.speciesId];
  if (sp == null) return const [];
  final cfg = pet.bugRarity;
  final r = pet.rarityOf(target, sp);
  final pinned = s.pinnedBugIds;
  final worthOn = cfg.worthOn;
  final out = [
    for (final b in s.bugs)
      if (b.id != target.id &&
          b.speciesId == target.speciesId &&
          _fodderOk(b, pinned) &&
          (worthOn
              ? pet.rarityOf(b, sp).index <= r.index
              : pet.rarityOf(b, sp) == r))
        b,
  ];
  if (worthOn) {
    out.sort((a, b) {
      final w = bugFeedValue(a, cfg).compareTo(bugFeedValue(b, cfg));
      return w != 0 ? w : bugFodderRank(a).compareTo(bugFodderRank(b));
    });
  } else {
    out.sort((a, b) => bugFodderRank(a).compareTo(bugFodderRank(b)));
  }
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

/// 양분 게이지 — [target] 에 먹일 재료를 고른다(가치 작은 것부터). [toNext] 면 다음 희귀도에 닿을 만큼만,
/// 아니면 전설에 닿을 만큼까지(넘치는 재료는 먹이지 않는다). 다음 희귀도에 못 닿으면 [toNext] 는 빈 목록.
List<IndividualBug> rarityFeedPlan(
  SaveGame s,
  IndividualBug target,
  PetConfig pet,
  Map<String, Species> speciesById, {
  required bool toNext,
}) {
  final cfg = pet.bugRarity;
  final sp = speciesById[target.speciesId];
  if (!cfg.worthOn || sp == null) return const [];
  final r = pet.rarityOf(target, sp);
  final fodder = rarityUpFodder(s, target, pet, speciesById);
  // 전부 먹이기 — 등급 양분(정수 흡수, 2026-11-09)도 함께 차므로 전설에서 멈추지 않는다. 전설 희귀도도 등급 양분을 위해 먹인다.
  if (!toNext)
    return pet.individualGrade.enabled || r != Grade.legendary
        ? fodder
        : const [];
  if (r == Grade.legendary) return const [];
  final goal = cfg.worthOfRarity(Grade.values[r.index + 1]);
  var total = bugRarityWorth(target, cfg);
  final out = <IndividualBug>[];
  for (final f in fodder) {
    if (total >= goal) break;
    out.add(f);
    total += bugFeedValue(f, cfg);
  }
  if (total < goal) return const [];
  return out;
}

/// [b] 를 먹이면 쌓이는 등급 양분(그 곤충의 정수 가치 + 그 곤충이 모은 등급 양분, 2026-11-09 정수 흡수). 등급이 꺼져 있으면 0.
int bugGradeFeedValue(IndividualBug b, PetConfig pet, Species sp) =>
    pet.individualGrade.enabled
    ? pet.individualGrade.essenceOf(b, pet.rarityOf(b, sp)) + b.gradeWorth
    : 0;

/// 양분 게이지 — [targetId] 에 [fodderIds] 를 먹인다(모두 [rarityUpFodder] 후보여야 한다). 총 가치로 희귀도를 다시 정하고
/// 남는 몫은 게이지에 둔다(전설이면 0 — 넘친 양분은 버려진다, [rarityFeedPlan] 은 넘치게 고르지 않는다).
/// extra: `from`·`to`(희귀도 키) · `fodder`(사라진 id 목록) · `worth`(먹인 뒤 총 가치).
GradeOp rarityFeed(
  SaveGame s,
  String targetId,
  List<String> fodderIds,
  PetConfig pet,
  Map<String, Species> speciesById,
) {
  final cfg = pet.bugRarity;
  if (!cfg.worthOn) return const GradeOp.fail('off');
  final i = s.bugs.indexWhere((b) => b.id == targetId);
  if (i < 0) return const GradeOp.fail('no_bug');
  final b = s.bugs[i];
  if (b.stage == LifeStage.egg) return const GradeOp.fail('egg');
  final sp = speciesById[b.speciesId];
  if (sp == null) return const GradeOp.fail('no_species');
  final from = pet.rarityOf(b, sp);
  final gradeOn = pet.individualGrade.enabled;
  // 전설 희귀도라도 등급 양분은 쌓인다(정수 흡수) — 등급까지 꺼져 있을 때만 더 먹일 이유가 없다.
  if (from == Grade.legendary && !gradeOn) return const GradeOp.fail('max');
  if (fodderIds.isEmpty) return const GradeOp.fail('no_fodder');
  final ok = {for (final f in rarityUpFodder(s, b, pet, speciesById)) f.id: f};
  final used = fodderIds.toSet();
  if (used.length != fodderIds.length || !used.every(ok.containsKey)) {
    return const GradeOp.fail('bad_fodder');
  }
  var total = bugRarityWorth(b, cfg);
  var grade = b.gradeWorth;
  for (final id in used) {
    total += bugFeedValue(ok[id]!, cfg);
    grade += bugGradeFeedValue(ok[id]!, pet, sp);
  }
  final to = cfg.rarityForWorth(total);
  final rest = to == Grade.legendary ? 0 : total - cfg.worthOfRarity(to);
  final up = b.copyWith(rarity: to, rarityWorth: rest, gradeWorth: grade);
  return GradeOp.ok(
    s.copyWith(
      bugs: [
        for (final x in s.bugs)
          if (x.id == b.id) up else if (!used.contains(x.id)) x,
      ],
      // 사라진 곤충의 표식 정리(펫 장착·부화 칸은 재료에서 이미 빠졌다).
      lockedBugIds: s.lockedBugIds.difference(used),
    ),
    extra: {
      'from': from.key,
      'to': to.key,
      'fodder': used.toList(),
      'worth': total,
      'grade': grade - b.gradeWorth,
    },
  );
}

/// 지금 바로 희귀도를 올릴 수 있는 곤충 id(채집함 "올릴 수 있음" 표시·거르기, 1.0.22) — [rarityUp] 이 성공할 곤충과 같다.
/// 한 번 훑기(곤충 100마리 칸마다 [rarityUpFodder] 를 부르지 않게).
Set<String> rarityUpReadyIds(
  SaveGame s,
  PetConfig pet,
  Map<String, Species> speciesById,
) {
  final cfg = pet.bugRarity;
  if (cfg.worthOn) return _worthReadyIds(s, pet, speciesById);
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
    if (_fodderOk(b, pinned)) {
      fodderN.update(key(b, r), (n) => n + 1, ifAbsent: () => 1);
    }
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

/// 양분 게이지의 "올릴 수 있음" — 자기 가치 + 목표 이하 재료 가치 합이 다음 희귀도에 닿는다.
Set<String> _worthReadyIds(
  SaveGame s,
  PetConfig pet,
  Map<String, Species> speciesById,
) {
  final cfg = pet.bugRarity;
  final pinned = s.pinnedBugIds;
  // 종 → 희귀도별 재료 가치 합(곤충 100마리 × 5칸 — 칸마다 다시 훑지 않게).
  final pool = <String, List<int>>{};
  final rarity = <String, Grade>{};
  for (final b in s.bugs) {
    final sp = speciesById[b.speciesId];
    if (sp == null) continue;
    final r = pet.rarityOf(b, sp);
    rarity[b.id] = r;
    if (_fodderOk(b, pinned)) {
      final p = pool.putIfAbsent(
        b.speciesId,
        () => List.filled(Grade.values.length, 0),
      );
      p[r.index] += bugFeedValue(b, cfg);
    }
  }
  return {
    for (final b in s.bugs)
      if (rarity[b.id] case final r?)
        if (b.stage != LifeStage.egg && r != Grade.legendary)
          if (pool[b.speciesId] case final p?)
            if (bugRarityWorth(b, cfg) +
                    [
                      for (var g = 0; g <= r.index; g++) p[g],
                    ].fold(0, (a, v) => a + v) -
                    (_fodderOk(b, pinned) ? bugFeedValue(b, cfg) : 0) >=
                cfg.worthOfRarity(Grade.values[r.index + 1]))
              b.id,
  };
}

/// [bugId] 의 희귀도를 한 단계 올린다 — 재료는 [rarityUpFodder] 의 앞에서부터 자동으로 고른다.
/// 양분 게이지면 다음 희귀도에 닿을 만큼만 먹인다([rarityFeedPlan] `toNext`).
/// extra: `from`·`to`(희귀도 키) · `fodder`(사라진 id 목록).
GradeOp rarityUp(
  SaveGame s,
  String bugId,
  PetConfig pet,
  Map<String, Species> speciesById,
) {
  final cfg = pet.bugRarity;
  if (cfg.worthOn) {
    final i = s.bugs.indexWhere((b) => b.id == bugId);
    if (i < 0) return const GradeOp.fail('no_bug');
    final plan = rarityFeedPlan(s, s.bugs[i], pet, speciesById, toNext: true);
    if (plan.isEmpty) {
      final b = s.bugs[i];
      final sp = speciesById[b.speciesId];
      if (b.stage == LifeStage.egg) return const GradeOp.fail('egg');
      if (sp != null && pet.rarityOf(b, sp) == Grade.legendary) {
        return const GradeOp.fail('max');
      }
      return const GradeOp.fail('no_fodder');
    }
    return rarityFeed(s, bugId, [for (final f in plan) f.id], pet, speciesById);
  }
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
/// 올린 곤충이 다시 위 희귀도 재료가 되는 것까지 이어서(서버 검사가 같은 이음을 센다).
/// 재료 규칙은 [rarityUpFodder] 그대로라 키운·잠근·장착한 곤충은 사라지지 않는다.
/// extra: `ups`(올린 횟수) · `fodder`(사라진 재료 수) · `bugs`(올린 곤충 id → 최종 희귀도 키).
/// 한 번도 못 올리면 `none` 실패. [dryRun] 이어도 같은 결과(세이브는 화면 미리보기용).
GradeOp autoRarityUp(
  SaveGame s,
  PetConfig pet,
  Map<String, Species> speciesById,
) {
  final cfg = pet.bugRarity;
  if (!cfg.worthOn && (!cfg.enabled || cfg.upFodder <= 0)) {
    return const GradeOp.fail('off');
  }
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

/// 서버 업로드 검사(옛 3마리 규칙) — 같은 id 의 희귀도가 [from] 에서 [to] 로 오른 것을 인정할지.
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

/// 서버 업로드 검사(양분 게이지, 2026-11-09) — 같은 id 의 총 가치가 [gain] 만큼 오른 것을 인정할지.
/// [pool] 은 종마다 **이번 업로드에서 사라진 곤충**의 가치 목록(저장본 기준 — `id`·`worth`)이다. 그 종 가치 합이 [gain] 이상이면
/// 가치 작은 것부터 꺼내 쓰고 true. 마지막에 넘친 몫은 같은 종 다음 곤충을 위해 남긴다(`id` 빈 값 — [used] 에 넣지 않는다).
/// 모자라면 false 이고 [pool]·[used] 를 건드리지 않는다. 쓴 재료 id 는 [used] 에 넣는다(서버가 정수 허용치에서 뺀다).
///
/// 업로드 사이에 올린 곤충을 바로 재료로 써도 맞는다 — 그 곤충은 저장본의 옛 가치로 사라진 것으로 보이지만, 그걸 올리는 데 든
/// 재료도 함께 사라져 [pool] 에 들어 있다(총 가치가 보존된다). 옛 3마리 규칙으로 올린 구버전 앱도 같은 가치라 통과한다.
bool takeRarityWorth({
  required String speciesId,
  required int gain,
  required Map<String, List<({String id, int worth})>> pool,
  Set<String>? used,
}) {
  if (gain <= 0) return true;
  final list = pool[speciesId];
  if (list == null) return false;
  if (list.fold(0, (a, x) => a + x.worth) < gain) return false;
  list.sort((a, b) => a.worth.compareTo(b.worth));
  var got = 0;
  while (got < gain) {
    final x = list.removeAt(0);
    got += x.worth;
    if (x.id.isNotEmpty) used?.add(x.id);
  }
  if (got > gain) list.add((id: '', worth: got - gain));
  return true;
}
