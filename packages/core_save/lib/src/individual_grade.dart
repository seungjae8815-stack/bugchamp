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
  Map<String, Species> speciesById, {
  // 곤충 희귀도(1.0.22) — 정수 가치는 곤충 희귀도로. 꺼져 있으면 종 희귀도.
  BugRarityConfig rarity = const BugRarityConfig(),
}) {
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
    final v = cfg.essenceOf(b, rarity.rarityOf(b, sp));
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

/// 업데이트 전 곤충이 **놓친 능력치 굴리기 횟수**(2026-10-16 사장님 확정, 1.0.22) — 옛 규칙으로 오른 등급 단계 수.
/// 새 곤충은 일반 → 지금 등급까지 등급마다 한 번씩 굴렸다(등급 − 1번). 업데이트 전 곤충은 옛 합성·태생 등급으로 올라
/// 한 번도 못 굴렸다 — 그만큼을 무료로 준다. 새 규칙으로 올린 단계(옛 합성 단계 `ls` 뒤)는 이미 굴렸으니 뺀다.
int legacyMissedRolls(IndividualBug b) {
  if (b.newGen) return 0;
  final ls = b.legacySynthUps;
  final newUps = ls == null ? 0 : math.max(0, b.synthUps - ls);
  return math.max(0, b.potential - 1 - newUps);
}

/// 남은 놓친 굴리기 횟수.
int legacyRollsLeft(IndividualBug b) =>
    math.max(0, legacyMissedRolls(b) - b.legacyRollUps);

/// 놓친 굴리기 한 번 — 등급 올리기와 **같은 규칙**(칸마다 기존 값과 새 롤 중 큰 쪽 + 물약 1개당 +3점, 내려가지 않는다).
/// 정수는 들지 않는다(무료 — 이미 그 등급까지 키운 몫). 물약은 [potions] 개 쓴다.
GradeOp legacyRollUp(
  SaveGame s,
  String bugId,
  IndividualGradeConfig cfg,
  math.Random rng, {
  int potions = 0,
}) {
  final i = s.bugs.indexWhere((b) => b.id == bugId);
  if (i < 0) return const GradeOp.fail('no_bug');
  final b = s.bugs[i];
  if (b.stage == LifeStage.egg) return const GradeOp.fail('egg');
  if (legacyRollsLeft(b) <= 0) return const GradeOp.fail('none_left');
  if (potions < 0 || potions > cfg.potionMaxPerUse) {
    return const GradeOp.fail('potion_count');
  }
  if (potions > s.growthPotions) return const GradeOp.fail('no_potion');
  final before = b.statRolls;
  final after = cfg.rollUp(before, rng, potions);
  final bugs = [...s.bugs]
    ..[i] = b.copyWith(rolls: after, legacyRollUps: b.legacyRollUps + 1);
  return GradeOp.ok(
    s.copyWith(bugs: bugs, growthPotions: s.growthPotions - potions),
    extra: {'before': before, 'after': after},
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

/// 성장물약 무료 획득처. 정예 확률 드롭은 **방치 정산에서도** 굴린다(2026-10-14 사장님 확정 —
/// `offline_buffs.dart rollIdleRareDrops`, 같은 하루 한도 [grantDropPotions]).
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
  DateTime? now,
  double rareMult = 1.0,
  ResearchEffects research = ResearchEffects.none,
}) {
  if (!cfg.enabled) return (save: s, got: 0);
  var got = 0;
  // [rareMult] — 채집꾼 버프의 희귀 드롭 배율(2026-10-14). 확률 드롭에만 곱한다(난수 소비 수는 그대로).
  // [research] — 연구소 "약초학"(`potionChance`)도 확률 드롭에만 × (1 + v). 하루 한도 `potionDropDaily` 는 그대로.
  switch (src) {
    case PotionSource.elite:
      if (rng.nextDouble() <
          potionDropChance(cfg.potionEliteChance, research) * rareMult) {
        got = 1;
      }
    case PotionSource.boss:
      got = firstKill
          ? cfg.potionBossFirst
          : (rng.nextDouble() <
                    potionDropChance(cfg.potionBossChance, research) * rareMult
                ? 1
                : 0);
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
  // 확률 드롭(정예·보스 재처치)은 **서버 날짜(UTC) 하루 `potionDropDaily` 개**까지만 — 서버 업로드 검사와 같은
  // 한도다(2026-10-14). 앱이 모르고 더 주면 서버가 1분 안에 되돌려 "물약이 사라졌다"가 됐다. 안내 없이 멈춘다
  // (사장님 확정). 난수는 위에서 이미 썼다 — 한도에 걸려도 같은 seed 의 다른 보상 순서가 안 바뀐다.
  final capped =
      src == PotionSource.elite || (src == PotionSource.boss && !firstKill);
  if (capped && got > 0 && now != null && cfg.potionDropDaily > 0) {
    return grantDropPotions(s, cfg, got, now);
  }
  return (save: grantPotions(s, got), got: got);
}

/// 성장물약 확률 드롭(정예·보스 재처치) 한 번의 확률 — 설정 확률 × (1 + 약초학). 온라인·방치 정산 공용.
/// 확정 지급(보스 첫 처치·심연·미션)과 하루 한도(`potionDropDaily`)는 연구와 무관하다.
double potionDropChance(double base, ResearchEffects research) =>
    researchScaledChance(base, research, ResearchEffect.potionChance);

/// 확률 드롭 물약 [count]개를 **서버 날짜(UTC) 하루 `potionDropDaily` 개** 한도 안에서 넣는다
/// (정예·보스 재처치·방치 정예 공용 — 서버 업로드 검사 `psR` 과 같은 한도). 받은 수를 돌려준다.
({SaveGame save, int got}) grantDropPotions(
  SaveGame s,
  IndividualGradeConfig cfg,
  int count,
  DateTime now,
) {
  if (count <= 0) return (save: s, got: 0);
  if (cfg.potionDropDaily <= 0) {
    return (save: grantPotions(s, count), got: count);
  }
  final today = dailyDateKey(now.toUtc());
  final used = potionDropsOn(s, today);
  if (used >= cfg.potionDropDaily) return (save: s, got: 0);
  final got = math.min(count, cfg.potionDropDaily - used);
  s = s.copyWith(
    dailyClaims: {
      ...s.dailyClaims,
      kPotionDropKey: '$today:${(used + got).toString().padLeft(2, '0')}',
    },
  );
  return (save: grantPotions(s, got), got: got);
}

/// 오늘(서버 날짜 UTC) 확률 드롭으로 더 받을 수 있는 물약 수. 한도가 없으면 큰 수.
int potionDropRoom(SaveGame s, IndividualGradeConfig cfg, DateTime now) {
  if (!cfg.enabled) return 0;
  if (cfg.potionDropDaily <= 0) return 1 << 20;
  final used = potionDropsOn(s, dailyDateKey(now.toUtc()));
  return math.max(0, cfg.potionDropDaily - used);
}

/// 기기의 하루 확률 물약 드롭 기록 키(`dailyClaims`) — 값은 `yyyy-MM-dd:NN`(두 자리라 문자열 비교가 곧 순서다.
/// 서버가 dailyClaims 를 합칠 때 늦은 쪽을 남긴다).
const kPotionDropKey = 'potion:drop';

/// [day] 에 기기에서 받은 확률 물약 수.
int potionDropsOn(SaveGame s, String day) {
  final v = s.dailyClaims[kPotionDropKey];
  if (v == null || !v.startsWith('$day:')) return 0;
  return int.tryParse(v.substring(day.length + 1)) ?? 0;
}

/// 롤 정리(서버 업로드 · 앱 로드 공용) — **등급 올리기를 한 적 없는 곤충(합성 단계 0)의 롤은 처음 롤**이다.
/// 처음 롤은 id 로 다시 계산되므로, 저장값이 붙어 있으면 위조(또는 옛 데이터)라 지운다. 칸 수가 다르면 지운다.
/// 놓친 능력치 굴리기(`lru`)로 남은 롤은 **놓친 굴리기가 있는 곤충**(업데이트 전 곤충)만 인정한다 —
/// 새 곤충에 `lru` 를 붙여 만점 롤을 남기던 구멍(2026-10-16 출시 전 검토).
SaveGame sanitizeGradeRolls(SaveGame s) {
  var changed = false;
  bool earned(IndividualBug b) =>
      b.synthUps > 0 || (b.legacyRollUps > 0 && legacyMissedRolls(b) > 0);
  final bugs = [
    for (final b in s.bugs)
      if (b.rolls != null &&
          (!earned(b) || b.rolls!.length != StatRoll.values.length))
        () {
          changed = true;
          return IndividualBug.fromJson(b.toJson()..remove('rl'));
        }()
      else
        b,
  ];
  return changed ? s.copyWith(bugs: bugs) : s;
}

/// 펫 패시브 크기 재굴림(2026-10-14 사장님 확정, `pets.json → passiveV2`) — 그 종 정수 [PassiveV2Config.rerollEssence]
/// 또는 젤리 [PassiveV2Config.rerollJelly] 를 내고 새 롤(0~100)을 굴린다. 곤충은 아직 그대로 —
/// 화면이 새 값/지금 값을 보여 주고 [applyPassiveRoll] 로 고른다(요정 재굴림·장비 다듬기와 같은 문법, 손해 없음).
/// 알은 굴리지 못한다(능력치가 숨겨진 상태). 결과 `extra['roll']`(새 롤) · `extra['cost']`.
GradeOp rollPassiveReroll(
  SaveGame s,
  PassiveV2Config cfg,
  String bugId,
  math.Random rng, {
  required bool useJelly,
  bool free = false,
}) {
  if (!cfg.enabled) return const GradeOp.fail('off');
  final bug = s.bugs.where((b) => b.id == bugId).firstOrNull;
  if (bug == null) return const GradeOp.fail('no_bug');
  if (bug.stage == LifeStage.egg) return const GradeOp.fail('egg');
  // 고르지 않은 결과가 남아 있으면 그것부터 고른다(2026-10-14 — 비용을 두 번 내지 않게).
  if (s.passiveRerollBug != null) return const GradeOp.fail('pending');
  var next = s;
  if (free) {
    // 업데이트 전 곤충의 무료 재굴림(2026-10-14 사장님 확정) — 굴리는 순간 한 번을 쓴다(고르든 안 고르든).
    if (cfg.freeRerollsLeft(bug) <= 0) return const GradeOp.fail('no_free');
    next = s.copyWith(
      bugs: [
        for (final b in s.bugs)
          b.id == bugId
              ? b.copyWith(passiveFreeUsed: b.passiveFreeUsed + 1)
              : b,
      ],
    );
  } else if (useJelly) {
    final jelly = s.materialCount(MaterialKind.jelly);
    if (cfg.rerollJelly <= 0 || jelly < cfg.rerollJelly) {
      return const GradeOp.fail('no_jelly');
    }
    next = s.copyWith(
      materials: Map<MaterialKind, int>.from(s.materials)
        ..[MaterialKind.jelly] = jelly - cfg.rerollJelly,
    );
  } else {
    final have = s.essence[bug.speciesId] ?? 0;
    if (cfg.rerollEssence <= 0 || have < cfg.rerollEssence) {
      return const GradeOp.fail('no_essence');
    }
    next = s.copyWith(
      essence: {...s.essence, bug.speciesId: have - cfg.rerollEssence},
    );
  }
  final roll = rng.nextInt(101);
  return GradeOp.ok(
    next.copyWith(passiveRerollBug: bugId, passiveRerollRoll: roll),
    extra: {
      'roll': roll,
      'cost': free ? 0 : (useJelly ? cfg.rerollJelly : cfg.rerollEssence),
      if (free) 'free': true,
    },
  );
}

/// 대기 중인 재굴림 결과를 고른다 — [accept] 면 새 롤을 적고, 아니면 지금 값을 지킨다. 어느 쪽이든 대기를 지운다.
/// 그 사이 곤충이 사라졌으면 대기만 지운다.
SaveGame choosePassiveReroll(SaveGame s, {required bool accept}) {
  final id = s.passiveRerollBug;
  final roll = s.passiveRerollRoll;
  final cleared = s.copyWith(clearPassiveReroll: true);
  if (!accept || id == null || roll == null) return cleared;
  if (!s.bugs.any((b) => b.id == id)) return cleared;
  return applyPassiveRoll(cleared, id, roll);
}

/// 재굴림 결과를 고른다 — 새 롤 [roll] 을 [bugId] 에 적는다(지금 값을 지키려면 부르지 않는다).
SaveGame applyPassiveRoll(SaveGame s, String bugId, int roll) => s.copyWith(
  bugs: [
    for (final b in s.bugs)
      b.id == bugId ? b.copyWith(passiveRoll: roll.clamp(0, 100)) : b,
  ],
);
