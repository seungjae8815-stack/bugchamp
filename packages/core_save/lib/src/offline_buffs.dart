import 'dart:math' as math;

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';

import 'fairy_progress.dart';
import 'individual_grade.dart';
import 'save_game.dart';
import 'train_points.dart';

// 방치 정산의 버프(2026-10-14 사장님 확정).
//
// 버프 5종은 실제 시간으로 만료된다(`SaveGame.buffExpiry`, 무한 버프 패스는 늘 켜짐). 예전 방치 정산은 맨몸
// 능력치로만 계산해서, 버프를 켜 두고 앱을 끄면 그 시간만큼 버프가 허공에 사라졌다. 이제 정산 구간을
// **버프 만료 시각들로 잘라** 구간마다 그때 켜져 있던 버프를 입힌 능력치로 계산한다.
//
// 정산 구간 = 마지막 접속([SaveGame.lastSeen])부터 오프라인 상한까지의 **앞쪽**이다 — 버프를 켜 두고 나간
// 시간이 곧 버프가 돌던 시간이라서다.
//
// 앱 방치 정산(`SaveController._applyOffline`)이 쓰고, 시뮬·서버가 나중에 같은 함수를 쓸 수 있게 여기 둔다.

/// 정산 구간 한 토막 — [length] 동안 [active] 버프가 켜져 있었다.
class BuffSpan {
  const BuffSpan(this.length, this.active);

  final Duration length;
  final Set<BuffKind> active;
}

/// [from] 부터 [accrued] 동안을 버프 만료 시각(·무한 버프 패스 만료)으로 자른다.
/// 앞에서부터 차례로, 길이 0 인 토막은 없다. 켜진 버프가 같은 이웃 토막은 합친다.
List<BuffSpan> offlineBuffSpans(
  SaveGame save,
  DateTime from,
  Duration accrued,
) {
  if (accrued <= Duration.zero) return const [];
  final end = from.add(accrued);
  final cuts = <DateTime>{from, end};
  void cut(DateTime? t) {
    if (t != null && t.isAfter(from) && t.isBefore(end)) cuts.add(t);
  }

  for (final t in save.buffExpiry.values) {
    cut(t);
  }
  cut(save.buffPassExpiresAt);
  final points = cuts.toList()..sort();
  final out = <BuffSpan>[];
  for (var i = 0; i + 1 < points.length; i++) {
    final len = points[i + 1].difference(points[i]);
    if (len <= Duration.zero) continue;
    final active = save.activeBuffs(points[i]);
    if (out.isNotEmpty && _sameSet(out.last.active, active)) {
      out[out.length - 1] = BuffSpan(out.last.length + len, active);
    } else {
      out.add(BuffSpan(len, active));
    }
  }
  return out;
}

bool _sameSet(Set<BuffKind> a, Set<BuffKind> b) =>
    a.length == b.length && a.containsAll(b);

/// 정산 한 토막의 결과.
class OfflinePart {
  const OfflinePart({
    required this.span,
    required this.stats,
    required this.clears,
    required this.gold,
    required this.xp,
    required this.rareMult,
  });

  final BuffSpan span;

  /// 이 토막의 능력치(버프 입힘).
  final CharacterStats stats;

  /// 처치 수(소수).
  final double clears;
  final int gold;
  final int xp;

  /// 희귀 드롭 배율(채집꾼).
  final double rareMult;
}

/// 토막들의 방치 정산(골드·경험치·처치 수) — 패스·길드 골드 배율은 호출자가 곱한다.
class OfflinePlan {
  const OfflinePlan(this.parts);

  final List<OfflinePart> parts;

  int get gold => parts.fold(0, (a, p) => a + p.gold);
  int get xp => parts.fold(0, (a, p) => a + p.xp);
  double get clears => parts.fold(0.0, (a, p) => a + p.clears);
  Duration get accrued =>
      parts.fold(Duration.zero, (a, p) => a + p.span.length);

  /// 토막마다 굴릴 처치 수(정수) — 누적 처치 수의 내림 차이라 합이 `clears.floor()` 와 같다.
  /// [maxRolls] 를 넘으면 비율대로 줄인다(연산 방어).
  List<int> rolls({int? maxRolls}) {
    final total = clears;
    final scale = (maxRolls != null && total > maxRolls && total > 0)
        ? maxRolls / total
        : 1.0;
    var cum = 0.0;
    var prev = 0;
    final out = <int>[];
    for (final p in parts) {
      cum += p.clears * scale;
      final f = cum.floor();
      out.add(math.max(0, f - prev));
      prev = f;
    }
    return out;
  }
}

/// [spans] 마다 버프를 입힌 능력치로 `computeOfflineReward`·`estimateClears` 를 돌린다.
/// [base] 는 맨몸 능력치(강화·레벨·도감 — 펫·장비 밖, 기존 방치 정산과 같다).
OfflinePlan planOffline({
  required RunConfig config,
  required CharacterStats base,
  required BuffConfig? buffs,
  required List<BuffSpan> spans,
  required int stageNumber,
  int tier = 0,
  int abyssFloor = 0,
  int? finalStage,
  required double efficiency,
}) {
  final parts = <OfflinePart>[];
  for (final span in spans) {
    final stats = applyBuffs(base, span.active, buffs);
    final r = computeOfflineReward(
      config: config,
      stageNumber: stageNumber,
      stats: stats,
      elapsed: span.length,
      maxAccrual: span.length,
      tier: tier,
      abyssFloor: abyssFloor,
      finalStage: finalStage,
      efficiency: efficiency,
    );
    final clears = estimateClears(
      config: config,
      stageNumber: stageNumber,
      stats: stats,
      elapsed: span.length,
      maxAccrual: span.length,
      tier: tier,
      abyssFloor: abyssFloor,
      efficiency: efficiency,
    );
    parts.add(
      OfflinePart(
        span: span,
        stats: stats,
        clears: clears,
        gold: r.gold,
        xp: r.xp,
        rareMult: rareDropMultOf(span.active, buffs),
      ),
    );
  }
  return OfflinePlan(parts);
}

/// [plan] 의 **기댓값**(팝업의 "더 받았어요/놓쳤어요" 비교용 — 난수를 또 굴리지 않는다).
///
/// 곤충 = 처치 × 드롭 확률 × 받는 등급 몫(등급 필터), 채집함 여유분까지. 희귀 종 = 그중 희귀 이상.
/// 재료 = 처치 × 재료 드롭 기댓값. 희귀 드롭 = 처치 × 정예 비율 × 확률 × 채집꾼 배율(물약은 오늘 남은 한도까지).
/// [goldMult] — 패스·길드 골드 배율(실제 지급과 같은 값).
OfflineGain expectedOfflineGain(
  OfflinePlan plan, {
  required SaveGame save,
  required RunConfig run,
  required List<Species> species,
  FairyConfig? fairy,
  DuelStoneConfig? stones,
  IndividualGradeConfig? grade,
  BugRarityConfig? rarity,
  required DateTime now,
  double goldMult = 1.0,
}) {
  final share = _gradeShares(run, species, save, rarity: rarity);
  var bugs = 0.0, rare = 0.0, mats = 0.0;
  var fStones = 0.0, dStones = 0.0, potions = 0.0;
  for (final p in plan.parts) {
    final bugP = math.min(1.0, run.bugDropChance * p.stats.bugFind);
    bugs += p.clears * bugP * share.accepted;
    rare += p.clears * bugP * share.rareAccepted;
    final md = materialDrop(run, p.stats.materialFind);
    final perDrop =
        (math.max(1, (1 * md.amountMult).round()) +
            math.max(1, (2 * md.amountMult).round())) /
        2;
    mats += p.clears * md.chance * perDrop;
    // 방치 희귀 드롭은 **채집꾼 버프가 켜진 구간만**(2026-10-14 사장님 확정) — 버프가 없으면 0(놓친 몫으로만 보인다).
    final elites = idleRareDropsOn(p.rareMult)
        ? p.clears * run.eliteChance
        : 0.0;
    if (fairy != null && fairy.subWeight.isNotEmpty) {
      fStones +=
          elites * math.min(1.0, fairy.drops.eliteStoneChance * p.rareMult);
    }
    if (stones != null) {
      for (final c in stones.eliteChance.values) {
        if (c > 0) dStones += elites * math.min(1.0, c * p.rareMult);
      }
    }
    if (grade != null && grade.enabled) {
      potions += elites * math.min(1.0, grade.potionEliteChance * p.rareMult);
    }
  }
  final room = math.max(0, save.storageFree).toDouble();
  if (bugs > room) {
    rare = bugs <= 0 ? 0 : rare * room / bugs;
    bugs = room;
  }
  if (grade != null) {
    potions = math.min(potions, potionDropRoom(save, grade, now).toDouble());
  }
  return OfflineGain(
    gold: (plan.gold * goldMult).round(),
    xp: plan.xp,
    materials: mats,
    bugs: bugs,
    rareBugs: rare,
    fairyStones: fStones,
    duelStones: dStones,
    potions: potions,
  );
}

/// 드롭 등급 가중치에서 **받는 등급**(필터) 몫과 그중 희귀 이상 몫. 가중치가 없으면 종 수 비율.
({double accepted, double rareAccepted}) _gradeShares(
  RunConfig run,
  List<Species> species,
  SaveGame save, {
  BugRarityConfig? rarity,
}) {
  final present = {for (final s in species) s.grade};
  if (present.isEmpty) return (accepted: 0, rareAccepted: 0);
  final w = <Grade, double>{};
  if (rarity != null && rarity.enabled) {
    // 곤충 희귀도(1.0.22) — 희귀도는 종이 아니라 곤충 롤(야생 표, `pickWildDrop` 과 같은 몫).
    for (final g in Grade.values) {
      if (g.index < rarity.wildWeights.length)
        w[g] = rarity.wildWeights[g.index];
    }
  } else if (run.dropGradeWeights.isEmpty) {
    for (final s in species) {
      w[s.grade] = (w[s.grade] ?? 0) + 1;
    }
  } else {
    for (final g in present) {
      w[g] = run.dropGradeWeights[g] ?? 0;
    }
  }
  final total = w.values.fold(0.0, (a, b) => a + b);
  if (total <= 0) return (accepted: 0, rareAccepted: 0);
  var acc = 0.0, rare = 0.0;
  for (final e in w.entries) {
    if (!save.acceptsGrade(e.key)) continue;
    acc += e.value;
    if (e.key.index >= Grade.rare.index) rare += e.value;
  }
  return (accepted: acc / total, rareAccepted: rare / total);
}

/// 방치 정예 희귀 드롭 결과.
class IdleRareDrops {
  const IdleRareDrops({
    required this.save,
    this.fairyStones = 0,
    this.duelStones = const {},
    this.potions = 0,
  });

  final SaveGame save;
  final int fairyStones;
  final Map<DuelStone, int> duelStones;
  final int potions;
}

/// 방치 중 희귀 드롭이 나오는 구간인가 — **채집꾼 버프(희귀 배율 > 1)가 켜진 구간만**(2026-10-14 사장님 확정).
/// 버프가 없던 사람에게는 0 이고, 복귀 팝업의 "놓쳤어요"에 버프를 켰을 때의 기댓값으로 보인다.
bool idleRareDropsOn(double rareMult) => rareMult > 1.0;

/// 방치 처치 [rolls]번 중 정예(`run.eliteChance`)에게서 굴리는 희귀 드롭(2026-10-14 사장님 확정) —
/// 요정 속성석 · 결투석 · 성장물약(서버 날짜 하루 `potionDropDaily` 한도 안). 온라인 정예와 같은 확률에
/// 채집꾼 배율 [rareMult] 를 곱한다. 요정 알·가속기·스킬 조각은 굴리지 않는다(온라인 전용).
IdleRareDrops rollIdleRareDrops(
  SaveGame save, {
  required int rolls,
  required RunConfig run,
  FairyConfig? fairy,
  DuelStoneConfig? stones,
  IndividualGradeConfig? grade,
  required double rareMult,
  required DateTime now,
  required math.Random rng,
}) {
  if (rolls <= 0 || run.eliteChance <= 0 || !idleRareDropsOn(rareMult)) {
    return IdleRareDrops(save: save);
  }
  final subs = fairy?.subWeight.keys.toList() ?? const <String>[];
  final fairyGot = <String, int>{};
  final stoneGot = <DuelStone, int>{};
  var potionRolls = 0;
  var out = save;
  for (var i = 0; i < rolls; i++) {
    if (rng.nextDouble() >= run.eliteChance) continue;
    if (fairy != null && subs.isNotEmpty) {
      if (rng.nextDouble() < fairy.drops.eliteStoneChance * rareMult) {
        final k = subs[rng.nextInt(subs.length)];
        fairyGot[k] = (fairyGot[k] ?? 0) + 1;
      }
    }
    if (stones != null) {
      final st = rollDuelStones(
        out,
        stones,
        rng,
        DuelStoneSource.elite,
        rareMult: rareMult,
      );
      out = st.save;
      for (final e in st.got.entries) {
        stoneGot[e.key] = (stoneGot[e.key] ?? 0) + e.value;
      }
    }
    if (grade != null && grade.enabled) {
      if (rng.nextDouble() < grade.potionEliteChance * rareMult) {
        potionRolls++;
      }
    }
  }
  if (fairyGot.isNotEmpty) {
    out = out.copyWith(fairy: grantFairyItems(out.fairy, stones: fairyGot));
  }
  var potions = 0;
  if (grade != null && potionRolls > 0) {
    final po = grantDropPotions(out, grade, potionRolls, now);
    out = po.save;
    potions = po.got;
  }
  return IdleRareDrops(
    save: out,
    fairyStones: fairyGot.values.fold(0, (a, b) => a + b),
    duelStones: stoneGot,
    potions: potions,
  );
}

// ── 서버 업로드 허용치 ──────────────────────────────────────────────

/// 희귀 드롭 허용치의 처치 속도 상한(초당) — 온라인 최상위 계정(한 방·걷기 0.12초)도 넘기 어려운 값.
/// 방치 정산은 효율 0.3 이라 이보다 훨씬 느리다. 밸런스 값이 아니라 위조 방어 봉투다.
const kRareDropKillsPerSecondCap = 2.0;

/// 기댓값 위 여유(운 좋은 정상 유저의 꼬리).
const kRareDropAllowanceMargin = 2.0;

/// 경과 시간 상한 — 오래 쉬었다 올린 업로드도 하루치까지만 센다(방치 상한은 8~12시간).
const kRareDropAllowanceMaxElapsed = Duration(hours: 24);

/// 업로드 사이 [elapsed](서버 시각) 동안 **정예 드롭으로** 늘 수 있는 요정 속성석·결투석 수(서버 업로드 검사).
///
/// = min(경과, 24시간) × 처치 속도 상한 × 정예 비율 × 확률 × 모든 버프의 희귀 배율 × 여유.
/// 앱 굴림([rollIdleRareDrops]·온라인 정예)과 같은 확률·배율을 쓴다. 물약은 따로 하루 한도(`psR`)로 묶인다.
({int fairyStones, int duelStones}) rareDropUploadAllowance({
  required Duration elapsed,
  required RunConfig run,
  FairyConfig? fairy,
  DuelStoneConfig? stones,
  BuffConfig? buffs,
}) {
  if (elapsed <= Duration.zero) return (fairyStones: 0, duelStones: 0);
  final e = elapsed > kRareDropAllowanceMaxElapsed
      ? kRareDropAllowanceMaxElapsed
      : elapsed;
  final elites =
      e.inMilliseconds / 1000.0 * kRareDropKillsPerSecondCap * run.eliteChance;
  final mult = buffs?.maxRareDropMult ?? 1.0;
  var f = 0.0;
  if (fairy != null && fairy.subWeight.isNotEmpty) {
    f = elites * math.min(1.0, fairy.drops.eliteStoneChance * mult);
  }
  var d = 0.0;
  if (stones != null) {
    for (final c in stones.eliteChance.values) {
      if (c > 0) d += elites * math.min(1.0, c * mult);
    }
  }
  return (
    fairyStones: (f * kRareDropAllowanceMargin).ceil(),
    duelStones: (d * kRareDropAllowanceMargin).ceil(),
  );
}
