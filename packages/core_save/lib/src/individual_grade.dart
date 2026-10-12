import 'dart:math' as math;

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';

import 'save_game.dart';

/// 개체 등급 진행 규칙(2026-10-11 사장님 확정, docs/design_individual_grade.md) —
/// **정수로 바꾸기 · 등급 올리기 · 성장물약**. 앱·서버가 같은 함수를 쓴다(두 벌이 되면 "앱에선 됐는데 서버가 거부").
/// 시간·날짜는 인자로, 무작위는 주입된 [math.Random] 으로만(§5).

/// 결과. 실패면 [save] 가 null 이고 [error] 에 사유 키.
class GradeOp {
  const GradeOp.ok(SaveGame this.save, {this.extra = const {}}) : error = null;
  const GradeOp.fail(String this.error) : save = null, extra = const {};

  final SaveGame? save;
  final String? error;
  final Map<String, Object?> extra;

  bool get isOk => save != null;
}

/// 곤충들을 그 종 **정수**로 바꾼다. 알·보호 곤충(장착·부화·훈련·잠금)은 건너뛴다.
///
/// extra: `gained`(종 → 정수) · `converted`(마리) · `skippedEggs` · `skippedPinned` ·
/// `potionBugs`(등급 올리기로 롤이 좋아진 곤충 수 — 화면이 미리 확인 창을 띄운다).
GradeOp convertToEssence(
  SaveGame s,
  Iterable<String> bugIds,
  IndividualGradeConfig cfg,
  Map<String, Species> speciesById,
) {
  final want = bugIds.toSet();
  if (want.isEmpty) return const GradeOp.fail('none');
  final pinned = s.pinnedBugIds;
  final bag = Map<String, int>.from(s.essence);
  final gained = <String, int>{};
  final keep = <IndividualBug>[];
  var converted = 0, eggs = 0, pinnedSkip = 0, potionBugs = 0;
  for (final b in s.bugs) {
    if (!want.contains(b.id)) {
      keep.add(b);
      continue;
    }
    final sp = speciesById[b.speciesId];
    if (sp == null) {
      keep.add(b);
      continue;
    }
    if (pinned.contains(b.id)) {
      pinnedSkip++;
      keep.add(b);
      continue;
    }
    final v = cfg.essenceOf(b, sp.grade);
    if (v <= 0) {
      eggs++;
      keep.add(b);
      continue;
    }
    if (b.rolls != null) potionBugs++;
    bag[sp.id] = (bag[sp.id] ?? 0) + v;
    gained[sp.id] = (gained[sp.id] ?? 0) + v;
    converted++;
  }
  if (converted == 0) {
    return GradeOp.fail(
      eggs > 0 ? 'egg' : (pinnedSkip > 0 ? 'pinned' : 'none'),
    );
  }
  return GradeOp.ok(
    s.copyWith(bugs: keep, essence: bag),
    extra: {
      'gained': gained,
      'converted': converted,
      'skippedEggs': eggs,
      'skippedPinned': pinnedSkip,
      'potionBugs': potionBugs,
    },
  );
}

/// 곤충 [bugId] 를 한 등급 올린다 — 그 종 정수 [IndividualGradeConfig.upgradeCost] 개 + 물약 [potions] 개.
/// 롤은 칸마다 다시 굴려 큰 쪽(내려가지 않는다), 물약 1개마다 새 롤 +[IndividualGradeConfig.potionRollBonus]점.
/// 합성 단계(`synthUps`)도 1 올린다 — 분해 젤리는 태생 등급(`bornPotential`)으로만 준다(무한 젤리 차단).
GradeOp gradeUp(
  SaveGame s,
  String bugId,
  IndividualGradeConfig cfg,
  Map<String, Species> speciesById,
  math.Random rng, {
  int potions = 0,
}) {
  final i = s.bugs.indexWhere((b) => b.id == bugId);
  if (i < 0) return const GradeOp.fail('no_bug');
  final b = s.bugs[i];
  if (b.stage == LifeStage.egg) return const GradeOp.fail('egg');
  if (b.potential >= kPotentialMax) return const GradeOp.fail('max');
  if (potions < 0 || potions > cfg.potionMaxPerUse) {
    return const GradeOp.fail('potion_count');
  }
  if (potions > s.growthPotions) return const GradeOp.fail('no_potion');
  final cost = cfg.upgradeCost(b.potential);
  final have = s.essence[b.speciesId] ?? 0;
  if (have < cost) return const GradeOp.fail('no_essence');
  final before = b.statRolls;
  final after = cfg.rollUp(before, rng, potions);
  // 업데이트 전 곤충은 처음 올릴 때 옛 합성 단계를 따로 적는다 — 옛 단계(3마리분)와 새 단계(들인 정수)의
  // 정수 가치가 달라서, 섞이면 올리기·바꾸기 반복으로 정수가 늘어난다(`essenceOf`).
  final up = b.copyWith(
    potential: b.potential + 1,
    synthUps: b.synthUps + 1,
    rolls: after,
    legacySynthUps: !b.newGen && b.legacySynthUps == null ? b.synthUps : null,
  );
  final bag = Map<String, int>.from(s.essence);
  final left = have - cost;
  if (left > 0) {
    bag[b.speciesId] = left;
  } else {
    bag.remove(b.speciesId);
  }
  final bugs = [...s.bugs]..[i] = up;
  return GradeOp.ok(
    s.copyWith(
      bugs: bugs,
      essence: bag,
      growthPotions: s.growthPotions - potions,
    ),
    extra: {'before': before, 'after': after, 'cost': cost},
  );
}

/// 성장물약을 젤리로 산다(§2.8 예외 — 사장님 확정) · 하루 [IndividualGradeConfig.potionDailyBuy] 개까지.
/// [dayKey] = 기기 날짜 키(다른 하루 기록과 같은 규칙 — 시계 조작에 약한 건 알 뽑기·선물과 같은 수준으로 용인).
GradeOp buyPotions(
  SaveGame s,
  int count,
  IndividualGradeConfig cfg,
  String dayKey,
) {
  if (count <= 0) return const GradeOp.fail('none');
  // 기록보다 이른 날짜(시계를 되돌림)면 거절 — 날짜를 바꿔 가며 하루 상한을 다시 채우지 못하게(2026-10-12).
  // 날짜 키는 'yyyy-MM-dd' 라 문자열 비교가 곧 날짜 비교다.
  final last = s.potionBuyDay;
  if (last != null && dayKey.compareTo(last) < 0) {
    return const GradeOp.fail('daily_limit');
  }
  final today = last == dayKey ? s.potionBuyCount : 0;
  if (today + count > cfg.potionDailyBuy) {
    return const GradeOp.fail('daily_limit');
  }
  final cost = count * cfg.potionJelly;
  final jelly = s.materialCount(MaterialKind.jelly);
  if (jelly < cost) return const GradeOp.fail('no_jelly');
  final mats = Map<MaterialKind, int>.from(s.materials)
    ..[MaterialKind.jelly] = jelly - cost;
  return GradeOp.ok(
    s.copyWith(
      materials: mats,
      growthPotions: s.growthPotions + count,
      potionBuyDay: dayKey,
      potionBuyCount: today + count,
    ),
    extra: {'jelly': cost},
  );
}

/// 성장물약을 넣는다(정예·보스·미션·심연 보상).
SaveGame grantPotions(SaveGame s, int count) =>
    count <= 0 ? s : s.copyWith(growthPotions: s.growthPotions + count);

/// 성장물약 무료 획득처(직접 사냥만 — 방치 정산 X).
enum PotionSource { elite, boss, abyssMilestone, mission }

/// 무료 물약 굴리기 — 정예 [IndividualGradeConfig.potionEliteChance] · 보스 첫 처치 확정, 재처치 확률 ·
/// 심연 10층 첫 도달 · 그날 첫 미션 1개. **다른 보상(조각·결투석) 뒤에** 굴린다(같은 seed 의 기존 보상이 안 바뀌게).
/// 개체 등급이 꺼져 있으면 아무것도 하지 않는다(난수도 안 쓴다).
({SaveGame save, int got}) rollPotionDrop(
  SaveGame s,
  IndividualGradeConfig cfg,
  math.Random rng,
  PotionSource src, {
  bool firstKill = false,
  String? dayKey,
}) {
  if (!cfg.enabled) return (save: s, got: 0);
  var got = 0;
  switch (src) {
    case PotionSource.elite:
      if (rng.nextDouble() < cfg.potionEliteChance) got = 1;
    case PotionSource.boss:
      got = firstKill
          ? cfg.potionBossFirst
          : (rng.nextDouble() < cfg.potionBossChance ? 1 : 0);
    case PotionSource.abyssMilestone:
      got = cfg.potionAbyss10;
    case PotionSource.mission:
      // 그날 첫 미션 보상에만 1개(dailyClaims 날짜 — 서버가 날짜를 뒤로 돌리지 못하게 합친다).
      const key = 'potion:mission';
      if (dayKey == null || s.dailyClaims[key] == dayKey) {
        return (save: s, got: 0);
      }
      return (
        save: grantPotions(
          s.copyWith(dailyClaims: {...s.dailyClaims, key: dayKey}),
          1,
        ),
        got: 1,
      );
  }
  return (save: grantPotions(s, got), got: got);
}

/// 롤 정리(서버 업로드 · 앱 로드 공용) — **등급 올리기를 한 적 없는 곤충(합성 단계 0)의 롤은 처음 롤**이다.
/// 처음 롤은 id 로 다시 계산되므로, 저장값이 붙어 있으면 위조(또는 옛 데이터)라 지운다. 칸 수가 다르면 지운다.
SaveGame sanitizeGradeRolls(SaveGame s) {
  var changed = false;
  final bugs = [
    for (final b in s.bugs)
      if (b.rolls != null &&
          (b.synthUps <= 0 || b.rolls!.length != StatRoll.values.length))
        () {
          changed = true;
          return IndividualBug.fromJson(b.toJson()..remove('rl'));
        }()
      else
        b,
  ];
  return changed ? s.copyWith(bugs: bugs) : s;
}
