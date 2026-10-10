import 'dart:math' as math;

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:meta/meta.dart';

import 'save_game.dart';
import 'training_progress.dart';

/// 훈련 v2 — 훈련 포인트 배분 · 다시 찍기 · 결투석(2026-10-08, docs/design_training_v2.md).
///
/// 곤충마다 포인트(포텐셜 1성당 6 · 수련 5레벨마다 1 · 돌파 6/10/16/24)가 **무료로** 생기고, 칸 10종
/// ([TrainSlot])에 골라 찍는다. 포인트를 **처음 쓸 때만** 재료·시간이 든다(훈련소 1칸 대기열 —
/// 옛 [TrainingJob] 과 같은 방식). 다시 찍기는 무료 + 대기(젤리로 당긴다).
///
/// 솔로 루프와 같은 **기기 권위**다(재료·곤충이 기기 권위). 앱과 서버가 이 함수들을 같이 쓰고, 서버는
/// 업로드 때 배분을 예산·칸 상한으로 자르고([sanitizeTrainPoints]) 결투 팀을 만들 때도 한 번 더 자른다
/// ([trainingBonusOf]). 곤충을 서버 발급으로 바꿀 때 함께 봉인한다.
///
/// **이전**: 옛 부위 강화(곤충의 `enhancement` — 세이브에 남는다)와 옛 훈련 단계([SaveGame.duelTraining])를
/// **같은 효과량이 되는 포인트**로 칸에 옮긴다([legacyTrainPoints]). 예산을 넘친 만큼은 보너스 포인트로
/// 영구히 남기고, 칸 상한을 넘친 칸은 그 칸의 상한이 옮긴 값까지 늘어난다 — **아무도 약해지지 않는다.**
/// ⚠️ 2026-10-10 사장님 확정으로 보너스·넘친 칸 상한을 **없앴다**(새 유저와의 공정함 — 옛 투자자에게는 젤리 보상).
/// 이전 자체(옛 투자 → 칸)는 그대로이고, 기본 예산·칸 상한을 넘친 몫만 [sanitizeTrainPoints] 가 자른다.

/// 곤충 1마리의 훈련 포인트 기록.
@immutable
class BugTrain {
  const BugTrain({
    this.alloc = const {},
    this.paid = 0,
    this.bonus = 0,
    this.pending,
    this.respecUntil,
    this.freeRespec = false,
  });

  /// 칸 → 찍은 포인트.
  final Map<TrainSlot, int> alloc;

  /// 재료를 낸 포인트 수(이전분 포함). 찍은 포인트가 이보다 적으면 남는 만큼은 재료 없이 바로 찍는다.
  final int paid;

  /// 이전 때 예산을 넘친 만큼(영구). 서버는 옛 기록으로 다시 계산한 값을 넘지 않게 자른다.
  final int bonus;

  /// 다시 찍기 대기 중인 새 배분(대기가 끝나면 [alloc] 이 된다).
  final Map<TrainSlot, int>? pending;
  final DateTime? respecUntil;

  /// 다음 다시 찍기 1회는 대기 없음(이전된 곤충의 첫 1회 — design §2).
  final bool freeRespec;

  int get allocated => alloc.values.fold(0, (a, b) => a + math.max(0, b));

  bool get isEmpty =>
      allocated == 0 && paid == 0 && bonus == 0 && pending == null;

  BugTrain copyWith({
    Map<TrainSlot, int>? alloc,
    int? paid,
    int? bonus,
    Map<TrainSlot, int>? pending,
    DateTime? respecUntil,
    bool clearPending = false,
    bool? freeRespec,
  }) => BugTrain(
    alloc: alloc ?? this.alloc,
    paid: paid ?? this.paid,
    bonus: bonus ?? this.bonus,
    pending: clearPending ? null : (pending ?? this.pending),
    respecUntil: clearPending ? null : (respecUntil ?? this.respecUntil),
    freeRespec: freeRespec ?? this.freeRespec,
  );

  static Map<String, int> _slotsToJson(Map<TrainSlot, int> m) => {
    for (final e in m.entries)
      if (e.value > 0) e.key.key: e.value,
  };

  // 옛 키 `speed` 는 밀어내기 힘(push)으로 읽는다([TrainSlot.fromKeyOrNull]). 둘 다 적혀 있으면(세이브를
  // 고친 경우뿐) 큰 쪽 — 더하면 같은 점수가 두 번 들어간다.
  static Map<TrainSlot, int> _slotsFromJson(Object? raw) {
    final out = <TrainSlot, int>{};
    for (final e in ((raw as Map?) ?? const {}).entries) {
      final k = TrainSlot.fromKeyOrNull('${e.key}');
      final v = e.value;
      if (k == null || v is! num || v <= 0) continue;
      out[k] = math.max(out[k] ?? 0, v.toInt());
    }
    return out;
  }

  Map<String, dynamic> toJson() => {
    'a': _slotsToJson(alloc),
    if (paid > 0) 'p': paid,
    if (bonus > 0) 'x': bonus,
    if (pending != null) 'n': _slotsToJson(pending!),
    if (pending != null && respecUntil != null)
      'u': respecUntil!.toUtc().toIso8601String(),
    if (freeRespec) 'f': 1,
  };

  static BugTrain? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final until = DateTime.tryParse('${raw['u']}')?.toUtc();
    final hasPending = raw['n'] is Map && until != null;
    return BugTrain(
      alloc: _slotsFromJson(raw['a']),
      paid: math.max(0, (raw['p'] as num?)?.toInt() ?? 0),
      bonus: math.max(0, (raw['x'] as num?)?.toInt() ?? 0),
      pending: hasPending ? _slotsFromJson(raw['n']) : null,
      respecUntil: hasPending ? until : null,
      freeRespec: raw['f'] == 1 || raw['f'] == true,
    );
  }
}

/// 훈련소 1칸 — 재료를 낸 포인트 [count]개를 칸 [slot] 에 찍는 중.
@immutable
class TrainPointJob {
  const TrainPointJob({
    required this.bugId,
    required this.slot,
    required this.count,
    required this.until,
  });

  final String bugId;
  final TrainSlot slot;
  final int count;
  final DateTime until;

  bool doneAt(DateTime now) => !now.toUtc().isBefore(until);

  Map<String, dynamic> toJson() => {
    'b': bugId,
    's': slot.key,
    'n': count,
    'u': until.toUtc().toIso8601String(),
  };

  static TrainPointJob? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final slot = TrainSlot.fromKeyOrNull('${raw['s']}');
    final until = DateTime.tryParse('${raw['u']}')?.toUtc();
    if (slot == null || until == null) return null;
    return TrainPointJob(
      bugId: '${raw['b']}',
      slot: slot,
      count: math.max(1, (raw['n'] as num?)?.toInt() ?? 1),
      until: until,
    );
  }
}

// ── 이전(옛 부위 강화·옛 훈련 단계 → 칸) ───────────────────────────────

/// 옛 부위 강화 계수(`enhance.json`). 없으면 §2.2 표 값.
typedef LegacyEnhance = ({
  double hornJaw,
  double cuticle,
  double wing,
  double build,
  double wingEvade,
});

LegacyEnhance legacyEnhanceOf(EnhanceConfig? e) {
  double per(BugPart p, double d) {
    final s = e?.parts[p];
    return s?.effectPerLevel ?? d;
  }

  return (
    hornJaw: per(BugPart.hornJaw, 0.04),
    cuticle: per(BugPart.cuticle, 0.04),
    wing: per(BugPart.wing, 0.03),
    build: per(BugPart.build, 0.05),
    wingEvade: e?.parts[BugPart.wing]?.evadePerLevel ?? 0.003,
  );
}

/// 효과량 [amount] 를 1포인트 효과 [per] 로 덮는 최소 포인트(올림 — 약해지지 않게).
int _ptsFor(double amount, double per) {
  if (amount <= 0 || per <= 0) return 0;
  return math.max(0, (amount / per - 1e-9).ceil());
}

/// 옛 훈련 단계(최대 단계로 자른 값) — 진행 중이던 옛 훈련은 **끝난 것으로** 친다.
Map<TrainStat, int> _legacyLevels(
  SaveGame s,
  IndividualBug b,
  Species sp,
  TrainingConfig cfg,
) {
  final raw = Map<TrainStat, int>.from(trainLevelsOf(s, b.id));
  final job = s.trainingJob;
  if (job != null && job.bugId == b.id) {
    raw[job.stat] = math.max(raw[job.stat] ?? 0, job.level);
  }
  return {
    for (final e in raw.entries)
      e.key: e.value.clamp(0, trainCapOf(b, sp, e.key, cfg)),
  };
}

/// 옛 투자 → **같은 효과량이 되는** 칸 포인트(design §2).
///
/// - 뿔·큰턱 × 옛 공격 훈련 → 공격 칸: (1 + 뿔×4%)(1 + 단계×1.5%) − 1 을 3% 로 덮는 포인트.
/// - 표피 × 옛 방어 훈련 → 방어 칸(같은 방식).
/// - 체격 → 체력 칸(5%/Lv → 4%/포인트) · 날개 → 밀어내기 힘 칸(옛 속도 칸 — 3% → 2% 로 센 포인트 수 그대로).
/// - 날개 회피(0.3%p/Lv) + 옛 회피 훈련 → 회피 칸 · 옛 치명 → 치명 칸 · 옛 회복력 → 회복력 칸.
///
/// 1:1 이 아니라 효과량 환산인 이유: 칸 1포인트 효과(공격 3%)가 옛 1레벨(뿔 4%)보다 작아 1:1 로 옮기면
/// 약해진다. 늘 **올림**이라 옮긴 뒤 결투 스탯은 같거나 크다(training_v2_test 가 증명한다).
///
/// 환산 계수는 [TrainingConfig.legacySlotEffect](**고정** — 처음 이전 때의 칸 효과)다. 칸 효과를 밸런스로
/// 올려도 옮긴 포인트·보너스 포인트·칸 상한은 그대로이고, 칸 효과가 오른 만큼 이전된 곤충도 같이 세진다
/// (2026-10-09 사장님 확정: 옛 고인물 보너스 포인트는 그대로).
Map<TrainSlot, int> legacyTrainPoints(
  SaveGame s,
  IndividualBug b,
  Species sp,
  TrainingConfig cfg, {
  EnhanceConfig? enhance,
}) {
  final e = legacyEnhanceOf(enhance);
  final lv = _legacyLevels(s, b, sp, cfg);
  final enh = b.enhancement;
  double old(TrainStat st) => (lv[st] ?? 0) * (cfg.perLevel[st] ?? 0);
  double eff(TrainSlot sl) => cfg.legacySlotEffect[sl] ?? 0;
  final horn = math.max(0, enh.levelOf(BugPart.hornJaw));
  final cut = math.max(0, enh.levelOf(BugPart.cuticle));
  final wing = math.max(0, enh.levelOf(BugPart.wing));
  final build = math.max(0, enh.levelOf(BugPart.build));
  final out = <TrainSlot, int>{
    TrainSlot.attack: _ptsFor(
      (1 + horn * e.hornJaw) * (1 + old(TrainStat.attack)) - 1,
      eff(TrainSlot.attack),
    ),
    TrainSlot.defense: _ptsFor(
      (1 + cut * e.cuticle) * (1 + old(TrainStat.defense)) - 1,
      eff(TrainSlot.defense),
    ),
    TrainSlot.hp: _ptsFor(build * e.build, eff(TrainSlot.hp)),
    TrainSlot.push: _ptsFor(wing * e.wing, eff(TrainSlot.push)),
    TrainSlot.evade: _ptsFor(
      wing * e.wingEvade + old(TrainStat.evade),
      eff(TrainSlot.evade),
    ),
    TrainSlot.crit: _ptsFor(old(TrainStat.crit), eff(TrainSlot.crit)),
    TrainSlot.recovery: _ptsFor(
      old(TrainStat.recovery),
      eff(TrainSlot.recovery),
    ),
  }..removeWhere((_, v) => v <= 0);
  return out;
}

int _sum(Map<TrainSlot, int> m) =>
    m.values.fold(0, (a, b) => a + math.max(0, b));

/// 이 곤충의 기본 예산(보너스 제외). [levelCap] 이 있으면 수련 레벨을 그 상한으로 자른다(서버).
int trainBaseBudget(IndividualBug b, TrainingConfig cfg, {int? levelCap}) =>
    cfg.pointBudget(
      potential: b.potential,
      level: levelCap == null ? b.level : b.level.clamp(1, levelCap),
      breakthroughTier: b.breakthroughTier,
    );

/// 옛 투자로 새로 만든 기록(옮길 것이 없으면 null).
BugTrain? migratedRecordOf(
  SaveGame s,
  IndividualBug b,
  Species sp,
  TrainingConfig cfg, {
  EnhanceConfig? enhance,
}) {
  final legacy = legacyTrainPoints(s, b, sp, cfg, enhance: enhance);
  final total = _sum(legacy);
  if (total <= 0) return null;
  return BugTrain(
    alloc: legacy,
    paid: total,
    bonus: math.max(0, total - trainBaseBudget(b, cfg)),
    freeRespec: true,
  );
}

/// **이전** — 기록이 없는 곤충의 옛 투자를 칸으로 옮긴다. 앱 로드·저장과 서버 업로드가 같은 함수를 쓴다.
/// 멱등이다(기록이 있는 곤충은 건드리지 않는다). 진행 중이던 옛 훈련은 끝난 것으로 친다(옛 단계에
/// 반영하고 대기열을 비운다 — 서버가 이전 상한을 다시 계산할 때도 그 단계가 보이게).
/// 바뀐 게 없으면 [s] 그대로.
SaveGame migrateTrainingV2(
  SaveGame s,
  TrainingConfig cfg, {
  required Species? Function(String speciesId) speciesOf,
  EnhanceConfig? enhance,
}) {
  var out = s;
  final job = out.trainingJob;
  if (job != null) {
    final all = Map<String, Map<TrainStat, int>>.from(out.duelTraining);
    if (out.bugs.any((b) => b.id == job.bugId)) {
      final lv = Map<TrainStat, int>.from(all[job.bugId] ?? const {});
      lv[job.stat] = math.max(lv[job.stat] ?? 0, job.level);
      all[job.bugId] = lv;
    }
    out = out.copyWith(duelTraining: all, clearTrainingJob: true);
  }
  Map<String, BugTrain>? next;
  for (final b in out.bugs) {
    if (out.trainPoints.containsKey(b.id)) continue;
    if (b.enhancement.total <= 0 && !out.duelTraining.containsKey(b.id)) {
      continue;
    }
    final sp = speciesOf(b.speciesId);
    if (sp == null) continue;
    final rec = migratedRecordOf(out, b, sp, cfg, enhance: enhance);
    if (rec == null) continue;
    (next ??= Map<String, BugTrain>.from(out.trainPoints))[b.id] = rec;
  }
  if (next != null) out = out.copyWith(trainPoints: next);
  return out;
}

// ── 예산·상한·효과 ───────────────────────────────────────────────────

/// 이 곤충의 기록(없으면 옛 투자로 만든 가상 기록 — 이전 전에도 결투 값이 같게).
BugTrain bugTrainOf(
  SaveGame s,
  IndividualBug b,
  Species sp,
  TrainingConfig cfg, {
  EnhanceConfig? enhance,
}) =>
    s.trainPoints[b.id] ??
    migratedRecordOf(s, b, sp, cfg, enhance: enhance) ??
    const BugTrain();

/// 포인트 예산 = 기본 예산(포텐셜·수련·돌파)뿐이다.
///
/// ⚠️ 2026-10-10 사장님 확정: 이전 보너스(옛 투자가 예산을 넘친 몫)를 **없앴다** — 뒤에 시작한 유저는 영원히 못
/// 가지는 몫이라 같은 곤충끼리 결투가 갈렸다(최대 +50). 옛 투자자에게는 부위 강화 보상 젤리를 우편으로 보냈고,
/// 줄어든 곤충은 무료 다시 찍기 1회를 받는다([sanitizeTrainPoints]). [BugTrain.bonus] 는 세이브 호환으로만 남는다.
int trainBudgetOf(
  SaveGame s,
  IndividualBug b,
  Species sp,
  TrainingConfig cfg, {
  int? levelCap,
  EnhanceConfig? enhance,
}) => trainBaseBudget(b, cfg, levelCap: levelCap);

/// 칸 [slot] 상한 = 기본 + 기질·주특기·특성 보정. 옛 투자로 상한을 넘던 것도 2026-10-10 부터 인정하지 않는다
/// (예산 보너스와 같은 이유 — [trainBudgetOf]).
int trainSlotCapOf(
  SaveGame s,
  IndividualBug b,
  Species sp,
  TrainSlot slot,
  TrainingConfig cfg, {
  EnhanceConfig? enhance,
  Map<TrainSlot, int>? legacy,
}) {
  final base = cfg.slotCap(
    slot,
    temperament: b.temperament,
    specialty: sp.specialty,
    trait: b.trait,
  );
  return base;
}

/// [alloc] 을 칸 상한·예산으로 자른다(넘치면 칸 순서의 **뒤에서부터** 깎는다 — 결정론).
Map<TrainSlot, int> clampAlloc(
  Map<TrainSlot, int> alloc, {
  required int Function(TrainSlot) capOf,
  required int budget,
}) {
  final out = <TrainSlot, int>{
    for (final sl in TrainSlot.values)
      if ((alloc[sl] ?? 0) > 0) sl: (alloc[sl] ?? 0).clamp(0, capOf(sl)),
  }..removeWhere((_, v) => v <= 0);
  var over = _sum(out) - (budget < 0 ? 0 : budget);
  for (final sl in TrainSlot.values.reversed) {
    if (over <= 0) break;
    final v = out[sl] ?? 0;
    final int cut = v < over ? v : over;
    if (cut <= 0) continue;
    over -= cut;
    if (v - cut <= 0) {
      out.remove(sl);
    } else {
      out[sl] = v - cut;
    }
  }
  return out;
}

/// 결투에 실리는 배분 — 칸 상한·예산으로 잘라서(서버가 위조를 자르는 곳).
Map<TrainSlot, int> effectiveAllocOf(
  SaveGame s,
  IndividualBug b,
  Species sp,
  TrainingConfig cfg, {
  int? levelCap,
  EnhanceConfig? enhance,
}) {
  final rec = bugTrainOf(s, b, sp, cfg, enhance: enhance);
  if (rec.allocated <= 0) return const {};
  final legacy = legacyTrainPoints(s, b, sp, cfg, enhance: enhance);
  return clampAlloc(
    rec.alloc,
    capOf: (sl) =>
        trainSlotCapOf(s, b, sp, sl, cfg, enhance: enhance, legacy: legacy),
    budget: trainBudgetOf(s, b, sp, cfg, levelCap: levelCap, enhance: enhance),
  );
}

/// 결투 보너스 — 배분은 **칸 상한·예산으로**, 수련 레벨은 **돌파 티어 상한([levelCap])으로** 잘라서
/// 계산한다. 수련 레벨 → 체력·공격 × (1 + (레벨-1) × duelLevelBonus)(2026-09-29 교차 반영 그대로).
/// 날개 회피(옛 부위 강화)는 더 이상 따로 붙지 않는다 — 이전이 회피 칸으로 옮겼다.
({
  double atkMult,
  double defMult,
  double hpMult,
  double spdMult,
  double evade,
  double crit,
  double recovery,
  double massMult,
  double pushMult,
  double tech,
  int grit,
})
trainingBonusOf(
  SaveGame s,
  IndividualBug b,
  Species sp,
  TrainingConfig cfg, {
  int? levelCap,
  EnhanceConfig? enhance,
}) {
  final t = cfg.slotBonuses(
    effectiveAllocOf(s, b, sp, cfg, levelCap: levelCap, enhance: enhance),
    sp.specialty,
  );
  final lv = levelCap == null ? b.level : b.level.clamp(1, levelCap);
  final lm = 1 + (lv - 1) * cfg.duelLevelBonus;
  return (
    atkMult: t.atkMult * lm,
    defMult: t.defMult,
    hpMult: t.hpMult * lm,
    spdMult: t.spdMult,
    evade: t.evade,
    crit: t.crit,
    recovery: t.recovery,
    massMult: t.massMult,
    pushMult: t.pushMult,
    tech: t.tech,
    grit: t.grit,
  );
}

/// 찍은 포인트(기록 그대로 — 화면·보호 판정용).
int trainedPointsOf(SaveGame s, String bugId) =>
    s.trainPoints[bugId]?.allocated ?? 0;

/// 훈련 → 방치(펫) 배율 = 1 + 찍은 포인트 × [TrainingConfig.petPerPoint].
/// 옛 투자가 있는 곤충은 max(새 식, 옛 식) — 옛 식 = (1 + 부위 강화 합 × legacyEnhancePetScale) ×
/// (1 + 옛 훈련 단계 합 × petScale). 이전 때문에 펫이 약해지지 않게.
double trainPetMult(SaveGame s, String bugId, TrainingConfig cfg) {
  final pts = trainedPointsOf(s, bugId);
  final now = 1 + pts * cfg.petPerPoint;
  final bug = s.bugs.where((b) => b.id == bugId).firstOrNull;
  final enh = bug?.enhancement.total ?? 0;
  final old = trainLevelsOf(s, bugId).values.fold<int>(0, (a, x) => a + x);
  if (enh <= 0 && old <= 0) return now;
  final legacy =
      (1 + enh * cfg.legacyEnhancePetScale) * (1 + old * cfg.petScale);
  return math.max(now, legacy);
}

// ── 찍기 · 다시 찍기 ────────────────────────────────────────────────

typedef TrainOp = ({SaveGame? save, String? error});

BugTrain _materialized(
  SaveGame s,
  IndividualBug b,
  Species sp,
  TrainingConfig cfg,
  EnhanceConfig? enhance,
) => bugTrainOf(s, b, sp, cfg, enhance: enhance);

SaveGame _putRecord(SaveGame s, String bugId, BugTrain rec) =>
    s.copyWith(trainPoints: {...s.trainPoints, bugId: rec});

/// 이 곤충이 훈련 때문에 출전할 수 없나(포인트 찍는 중 · 다시 찍기 대기 중).
bool trainBusy(SaveGame s, String bugId, DateTime now) {
  final job = s.trainPointJob;
  if (job != null && job.bugId == bugId && !job.doneAt(now)) return true;
  final rec = s.trainPoints[bugId];
  final u = rec?.respecUntil;
  return rec?.pending != null && u != null && now.toUtc().isBefore(u);
}

/// 훈련 때문에 출전할 수 없는 끝 시각(없으면 null) — 화면의 "훈련 중" 표시용.
DateTime? trainBusyUntil(SaveGame s, String bugId, DateTime now) {
  if (!trainBusy(s, bugId, now)) return null;
  final job = s.trainPointJob;
  if (job != null && job.bugId == bugId && !job.doneAt(now)) return job.until;
  return s.trainPoints[bugId]?.respecUntil;
}

/// 끝난 포인트 찍기·다시 찍기를 반영한다(바뀐 게 없으면 그대로).
SaveGame finishTrainPointsIfDue(SaveGame s, DateTime now) {
  var out = s;
  final job = out.trainPointJob;
  if (job != null && job.doneAt(now)) out = _applyPointJob(out, job);
  Map<String, BugTrain>? next;
  for (final e in out.trainPoints.entries) {
    final r = e.value;
    final u = r.respecUntil;
    if (r.pending == null || u == null || now.toUtc().isBefore(u)) continue;
    (next ??= Map<String, BugTrain>.from(out.trainPoints))[e.key] = r.copyWith(
      alloc: r.pending,
      clearPending: true,
    );
  }
  if (next != null) out = out.copyWith(trainPoints: next);
  return out;
}

SaveGame _applyPointJob(SaveGame s, TrainPointJob job) {
  final out = s.copyWith(clearTrainPointJob: true);
  final rec = s.trainPoints[job.bugId];
  // 곤충이 사라졌으면(분해·합성) 기록하지 않는다. 찍기를 시작할 때 기록을 만들어 두므로 없으면 사라진 것이다.
  if (rec == null || !s.bugs.any((b) => b.id == job.bugId)) return out;
  final alloc = Map<TrainSlot, int>.from(rec.alloc);
  alloc[job.slot] = (alloc[job.slot] ?? 0) + job.count;
  return _putRecord(
    out,
    job.bugId,
    rec.copyWith(alloc: alloc, paid: rec.paid + job.count),
  );
}

/// [count]포인트를 칸 [slot] 에 찍는다.
///
/// 재료를 이미 낸 포인트가 남아 있으면(다시 찍기로 뺀 몫) 그만큼은 **재료·시간 없이 바로** 찍고 끝난다
/// (남는 수만큼만 — 나머지는 다시 부르면 된다). 남는 게 없으면 재료를 내고 훈련소 1칸에서 시간을 건다.
/// n번째로 재료를 내는 포인트의 비용 = [TrainingConfig.pointCost](n).
///
/// error: `no_bug` · `respec`(다시 찍기 대기 중) · `busy`(훈련소 1칸이 차 있음) · `maxed`(칸 상한) ·
/// `points`(예산 부족) · `materials`.
TrainOp allocTrainPoint(
  SaveGame s,
  TrainingConfig cfg,
  IndividualBug bug,
  Species sp,
  TrainSlot slot,
  DateTime now, {
  int count = 1,
  EnhanceConfig? enhance,
}) {
  if (count < 1) return (save: null, error: 'count');
  s = finishTrainPointsIfDue(s, now);
  if (!s.bugs.any((b) => b.id == bug.id)) return (save: null, error: 'no_bug');
  final rec = _materialized(s, bug, sp, cfg, enhance);
  if (rec.pending != null) return (save: null, error: 'respec');
  final job = s.trainPointJob;
  final cap = trainSlotCapOf(s, bug, sp, slot, cfg, enhance: enhance);
  final pendingSame = job != null && job.bugId == bug.id && job.slot == slot
      ? job.count
      : 0;
  final have = rec.alloc[slot] ?? 0;
  if (have + pendingSame + count > cap) return (save: null, error: 'maxed');

  final free = rec.paid - rec.allocated;
  if (free > 0) {
    final n = math.min(free, count);
    final alloc = Map<TrainSlot, int>.from(rec.alloc)..[slot] = have + n;
    return (
      save: _putRecord(s, bug.id, rec.copyWith(alloc: alloc)),
      error: null,
    );
  }

  if (job != null) return (save: null, error: 'busy');
  final budget = trainBudgetOf(s, bug, sp, cfg, enhance: enhance);
  if (rec.paid + count > budget) return (save: null, error: 'points');
  var cost = 0;
  var secs = 0;
  for (var k = 1; k <= count; k++) {
    cost += cfg.pointCost(rec.paid + k, sp.grade);
    secs += cfg.pointTime(rec.paid + k).inSeconds;
  }
  if (kTrainingMaterials.any((k) => s.materialCount(k) < cost)) {
    return (save: null, error: 'materials');
  }
  final mats = Map<MaterialKind, int>.from(s.materials);
  for (final k in kTrainingMaterials) {
    mats[k] = (mats[k] ?? 0) - cost;
  }
  return (
    save: _putRecord(s, bug.id, rec).copyWith(
      materials: mats,
      trainPointJob: TrainPointJob(
        bugId: bug.id,
        slot: slot,
        count: count,
        until: now.toUtc().add(Duration(seconds: secs)),
      ),
    ),
    error: null,
  );
}

/// [count]포인트를 찍을 때 드는 재료(종류마다)·시간 — 화면 표시용(재료를 낸 포인트가 남으면 0).
({int cost, Duration time}) trainPointQuote(
  BugTrain rec,
  TrainingConfig cfg,
  Grade grade, {
  int count = 1,
}) {
  final free = math.max(0, rec.paid - rec.allocated);
  if (free >= count) return (cost: 0, time: Duration.zero);
  var cost = 0;
  var secs = 0;
  for (var k = 1; k <= count - free; k++) {
    cost += cfg.pointCost(rec.paid + k, grade);
    secs += cfg.pointTime(rec.paid + k).inSeconds;
  }
  return (cost: cost, time: Duration(seconds: secs));
}

/// 젤리로 지금 포인트 찍기를 끝낸다. error: `none` · `jelly`.
({SaveGame? save, String? error, int jelly}) instantFinishTrainPoint(
  SaveGame s,
  TrainingConfig cfg,
  DateTime now,
) {
  final job = s.trainPointJob;
  if (job == null) return (save: null, error: 'none', jelly: 0);
  final cost = cfg.instantJelly(job.until.difference(now.toUtc()));
  if (s.materialCount(MaterialKind.jelly) < cost) {
    return (save: null, error: 'jelly', jelly: cost);
  }
  final mats = Map<MaterialKind, int>.from(s.materials)
    ..[MaterialKind.jelly] = s.materialCount(MaterialKind.jelly) - cost;
  return (
    save: _applyPointJob(s.copyWith(materials: mats), job),
    error: null,
    jelly: cost,
  );
}

/// 다시 찍기 — 배분을 [next] 로 바꾼다. **재료는 다시 들지 않는다**(재료를 낸 포인트 안에서만).
/// 대기 = [TrainingConfig.respecWait](재료를 낸 포인트) — 대기 중엔 출전할 수 없다. 이전된 곤충의 첫 1회는 대기 없음.
///
/// error: `no_bug` · `busy`(이 곤충 포인트 찍는 중) · `respec`(이미 대기 중) · `bad`(음수) · `maxed`(칸 상한) ·
/// `points`(재료를 낸 포인트·예산 초과) · `same`(그대로).
TrainOp startTrainRespec(
  SaveGame s,
  TrainingConfig cfg,
  IndividualBug bug,
  Species sp,
  Map<TrainSlot, int> next,
  DateTime now, {
  EnhanceConfig? enhance,
}) {
  s = finishTrainPointsIfDue(s, now);
  if (!s.bugs.any((b) => b.id == bug.id)) return (save: null, error: 'no_bug');
  if (s.trainPointJob?.bugId == bug.id) return (save: null, error: 'busy');
  final rec = _materialized(s, bug, sp, cfg, enhance);
  if (rec.pending != null) return (save: null, error: 'respec');
  final clean = <TrainSlot, int>{};
  for (final e in next.entries) {
    if (e.value < 0) return (save: null, error: 'bad');
    if (e.value > 0) clean[e.key] = e.value;
  }
  final legacy = legacyTrainPoints(s, bug, sp, cfg, enhance: enhance);
  for (final e in clean.entries) {
    final cap = trainSlotCapOf(
      s,
      bug,
      sp,
      e.key,
      cfg,
      enhance: enhance,
      legacy: legacy,
    );
    if (e.value > cap) return (save: null, error: 'maxed');
  }
  final budget = trainBudgetOf(s, bug, sp, cfg, enhance: enhance);
  if (_sum(clean) > math.min(rec.paid, budget)) {
    return (save: null, error: 'points');
  }
  final same =
      clean.length == rec.alloc.entries.where((e) => e.value > 0).length &&
      clean.entries.every((e) => rec.alloc[e.key] == e.value);
  if (same) return (save: null, error: 'same');
  final wait = rec.freeRespec ? Duration.zero : cfg.respecWait(rec.paid);
  final updated = wait <= Duration.zero
      ? rec.copyWith(alloc: clean, freeRespec: false, clearPending: true)
      : rec.copyWith(pending: clean, respecUntil: now.toUtc().add(wait));
  return (save: _putRecord(s, bug.id, updated), error: null);
}

/// 다시 찍기 대기를 젤리로 당긴다(즉시 완료 공식 — 5·10 단위). error: `none` · `jelly`.
({SaveGame? save, String? error, int jelly}) instantFinishTrainRespec(
  SaveGame s,
  TrainingConfig cfg,
  String bugId,
  DateTime now,
) {
  final rec = s.trainPoints[bugId];
  final u = rec?.respecUntil;
  if (rec == null || rec.pending == null || u == null) {
    return (save: null, error: 'none', jelly: 0);
  }
  final cost = cfg.instantJelly(u.difference(now.toUtc()));
  if (s.materialCount(MaterialKind.jelly) < cost) {
    return (save: null, error: 'jelly', jelly: cost);
  }
  final mats = Map<MaterialKind, int>.from(s.materials)
    ..[MaterialKind.jelly] = s.materialCount(MaterialKind.jelly) - cost;
  return (
    save: _putRecord(
      s.copyWith(materials: mats),
      bugId,
      rec.copyWith(alloc: rec.pending, clearPending: true),
    ),
    error: null,
    jelly: cost,
  );
}

/// 다시 찍기 대기를 취소한다(배분은 그대로). error: `none`.
TrainOp cancelTrainRespec(SaveGame s, String bugId) {
  final rec = s.trainPoints[bugId];
  if (rec == null || rec.pending == null) return (save: null, error: 'none');
  return (
    save: _putRecord(s, bugId, rec.copyWith(clearPending: true)),
    error: null,
  );
}

// ── 추천 배분(2026-10-09) ─────────────────────────────────────────────

/// 비율 [weights](칸 → 가중치, `battle.json → training.presets`)대로 [points] 포인트를 칸 상한 안에서 나눈다.
///
/// [floor] 는 이미 찍힌 배분 — 그 아래로는 내리지 않는다(남는 포인트 채우기). 1점씩 **목표 몫보다 가장 모자란
/// 칸**에 준다(동률이면 칸 순서 — 결정론). 비율 칸이 모두 목표에 닿았거나 상한이면 비율이 큰 칸(상한이 남은)
/// → 그래도 없으면 상한이 남은 아무 칸(칸 순서). 어느 칸에도 못 넣으면 거기서 멈춘다(합이 [points] 보다 작다).
Map<TrainSlot, int> distributeTrainPoints(
  Map<TrainSlot, int> weights,
  int points, {
  required int Function(TrainSlot) capOf,
  Map<TrainSlot, int> floor = const {},
}) {
  final out = <TrainSlot, int>{
    for (final sl in TrainSlot.values)
      sl: math.min(math.max(0, floor[sl] ?? 0), math.max(0, capOf(sl))),
  };
  final w = {
    for (final e in weights.entries)
      if (e.value > 0) e.key: e.value,
  };
  final wsum = w.values.fold<int>(0, (a, b) => a + b);
  var remaining = points - _sum(out);
  while (remaining > 0) {
    TrainSlot? pick;
    var best = 0.0;
    if (wsum > 0) {
      for (final sl in TrainSlot.values) {
        final wt = w[sl] ?? 0;
        if (wt <= 0 || out[sl]! >= capOf(sl)) continue;
        final deficit = points * wt / wsum - out[sl]!;
        if (deficit > best + 1e-9) {
          best = deficit;
          pick = sl;
        }
      }
    }
    if (pick == null) {
      var bw = 0;
      for (final sl in TrainSlot.values) {
        final wt = w[sl] ?? 0;
        if (wt > bw && out[sl]! < capOf(sl)) {
          bw = wt;
          pick = sl;
        }
      }
    }
    pick ??= TrainSlot.values.where((sl) => out[sl]! < capOf(sl)).firstOrNull;
    if (pick == null) break;
    out[pick] = out[pick]! + 1;
    remaining--;
  }
  out.removeWhere((_, v) => v <= 0);
  return out;
}

/// 추천 배분 [weights] 로 다음 1점을 넣을 칸(지금 배분 [alloc] 기준). 넣을 칸이 없으면 null.
TrainSlot? nextPresetSlot(
  Map<TrainSlot, int> weights,
  Map<TrainSlot, int> alloc, {
  required int Function(TrainSlot) capOf,
}) {
  final next = distributeTrainPoints(
    weights,
    _sum(alloc) + 1,
    capOf: capOf,
    floor: alloc,
  );
  for (final sl in TrainSlot.values) {
    if ((next[sl] ?? 0) > (alloc[sl] ?? 0)) return sl;
  }
  return null;
}

/// 재료를 낸 남는 포인트(다시 찍기로 뺀 몫)를 추천 배분 [weights] 대로 **한 번에** 찍는다 — 지금 배분은
/// 그대로 두고 남는 몫만 더한다. [allocTrainPoint] 의 "재료 없이 바로" 경로를 칸마다 부른 것과 같다.
///
/// error: `no_bug` · `respec`(다시 찍기 대기 중) · `none`(남는 포인트 없음) · `maxed`(넣을 칸이 없음).
TrainOp fillTrainFreePoints(
  SaveGame s,
  TrainingConfig cfg,
  IndividualBug bug,
  Species sp,
  Map<TrainSlot, int> weights,
  DateTime now, {
  EnhanceConfig? enhance,
}) {
  s = finishTrainPointsIfDue(s, now);
  if (!s.bugs.any((b) => b.id == bug.id)) return (save: null, error: 'no_bug');
  final rec = _materialized(s, bug, sp, cfg, enhance);
  if (rec.pending != null) return (save: null, error: 'respec');
  final free = rec.paid - rec.allocated;
  if (free <= 0) return (save: null, error: 'none');
  final legacy = legacyTrainPoints(s, bug, sp, cfg, enhance: enhance);
  final job = s.trainPointJob;
  // 이 곤충이 찍는 중인 칸은 그 몫만큼 상한이 줄어 있다([allocTrainPoint] 의 상한 검사와 같다).
  int capOf(TrainSlot sl) => math.max(
    0,
    trainSlotCapOf(s, bug, sp, sl, cfg, enhance: enhance, legacy: legacy) -
        (job != null && job.bugId == bug.id && job.slot == sl ? job.count : 0),
  );
  final next = distributeTrainPoints(
    weights,
    rec.allocated + free,
    capOf: capOf,
    floor: rec.alloc,
  );
  if (_sameSlots(next, rec.alloc)) return (save: null, error: 'maxed');
  return (save: _putRecord(s, bug.id, rec.copyWith(alloc: next)), error: null);
}

/// 사라진 곤충의 v2 기록·대기열을 지운다(바뀐 게 없으면 그대로).
SaveGame pruneTrainPoints(SaveGame s) {
  if (s.trainPoints.isEmpty && s.trainPointJob == null) return s;
  final ids = {for (final b in s.bugs) b.id};
  final gone = s.trainPoints.keys.where((k) => !ids.contains(k)).toList();
  final jobGone =
      s.trainPointJob != null && !ids.contains(s.trainPointJob!.bugId);
  if (gone.isEmpty && !jobGone) return s;
  final all = Map<String, BugTrain>.from(s.trainPoints);
  for (final k in gone) {
    all.remove(k);
  }
  return s.copyWith(trainPoints: all, clearTrainPointJob: jobGone);
}

/// **서버 업로드 검사 · 앱 로드/저장** — 기록을 칸 상한·예산 안으로 자른다(배분·대기 배분 모두). 재료를 낸 포인트는
/// 기본 예산을 넘지 않는다(보너스는 2026-10-10 폐지 — 잘린 곤충은 무료 다시 찍기). 없는 곤충 기록은 지운다. 바뀐 게 없으면 [s] 그대로.
SaveGame sanitizeTrainPoints(
  SaveGame s,
  TrainingConfig cfg, {
  required Species? Function(String speciesId) speciesOf,
  required int Function(int breakthroughTier) levelCapOf,
  EnhanceConfig? enhance,
}) {
  final pruned = pruneTrainPoints(s);
  if (pruned.trainPoints.isEmpty) return pruned;
  final byId = {for (final b in pruned.bugs) b.id: b};
  Map<String, BugTrain>? next;
  for (final e in pruned.trainPoints.entries) {
    final b = byId[e.key]!;
    final sp = speciesOf(b.speciesId);
    if (sp == null) continue;
    final rec = e.value;
    // 보너스·옛 칸 상한은 2026-10-10 부터 인정하지 않는다([trainBudgetOf]) — 예산은 기본뿐.
    final budget = trainBaseBudget(
      b,
      cfg,
      levelCap: levelCapOf(b.breakthroughTier),
    );
    int capOf(TrainSlot sl) =>
        trainSlotCapOf(pruned, b, sp, sl, cfg, enhance: enhance);
    final paid = rec.paid.clamp(0, budget);
    final alloc = clampAlloc(rec.alloc, capOf: capOf, budget: paid);
    final pending = rec.pending == null
        ? null
        : clampAlloc(rec.pending!, capOf: capOf, budget: paid);
    // 배분이 잘렸으면(보너스로 찍었던 몫) 무료 다시 찍기 1회 — 뒤에서부터 깎인 자리를 직접 다시 고르게.
    final trimmed = !_sameSlots(alloc, rec.alloc);
    final fixed = BugTrain(
      alloc: alloc,
      paid: paid,
      pending: pending,
      respecUntil: pending == null ? null : rec.respecUntil,
      freeRespec: rec.freeRespec || trimmed,
    );
    if (!_sameRecord(fixed, rec)) {
      (next ??= Map<String, BugTrain>.from(pruned.trainPoints))[e.key] = fixed;
    }
  }
  return next == null ? pruned : pruned.copyWith(trainPoints: next);
}

bool _sameSlots(Map<TrainSlot, int>? a, Map<TrainSlot, int>? b) {
  if (a == null || b == null) return a == b;
  final x = {
    for (final e in a.entries)
      if (e.value > 0) e.key: e.value,
  };
  final y = {
    for (final e in b.entries)
      if (e.value > 0) e.key: e.value,
  };
  return x.length == y.length && x.entries.every((e) => y[e.key] == e.value);
}

bool _sameRecord(BugTrain a, BugTrain b) =>
    a.paid == b.paid &&
    a.bonus == b.bonus &&
    a.freeRespec == b.freeRespec &&
    a.respecUntil == b.respecUntil &&
    _sameSlots(a.alloc, b.alloc) &&
    _sameSlots(a.pending, b.pending);

// ── 결투석 ───────────────────────────────────────────────────────────

/// 결투석 드롭이 굴러가는 자리.
enum DuelStoneSource { elite, bossRepeat }

SaveGame _addStones(SaveGame s, Map<DuelStone, int> got) {
  if (got.isEmpty) return s;
  final m = Map<DuelStone, int>.from(s.duelStones);
  for (final e in got.entries) {
    m[e.key] = (m[e.key] ?? 0) + e.value;
  }
  return s.copyWith(duelStones: m);
}

/// 정예·보스 재처치 결투석 드롭. 종류마다 한 번씩 굴린다(오행 → 기질 순 — 순서를 바꾸면 같은 seed 의
/// 결과가 달라진다). 아무것도 안 나오면 [s] 그대로.
({SaveGame save, Map<DuelStone, int> got}) rollDuelStones(
  SaveGame s,
  DuelStoneConfig cfg,
  math.Random rng,
  DuelStoneSource source,
) {
  final table = switch (source) {
    DuelStoneSource.elite => cfg.eliteChance,
    DuelStoneSource.bossRepeat => cfg.bossRepeatChance,
  };
  final got = <DuelStone, int>{};
  for (final k in DuelStone.values) {
    final p = table[k] ?? 0;
    if (p <= 0) continue;
    if (rng.nextDouble() < p) got[k] = 1;
  }
  return (save: _addStones(s, got), got: got);
}

/// 심연 [floor]층 **첫 도달** 결투석(10층마다 오행 2 · 기질 1). 마일스톤 층이 아니면 그대로.
/// 첫 도달 판정은 호출자(심연 층 클리어의 `milestone`)가 한다.
({SaveGame save, Map<DuelStone, int> got}) grantAbyssDuelStones(
  SaveGame s,
  DuelStoneConfig cfg,
  int floor,
) {
  if (cfg.abyssEvery <= 0 || floor <= 0 || floor % cfg.abyssEvery != 0) {
    return (save: s, got: const {});
  }
  final got = {
    for (final e in cfg.abyssCount.entries)
      if (e.value > 0) e.key: e.value,
  };
  return (save: _addStones(s, got), got: got);
}

/// 젤리로 결투석 [count]개를 산다. error: `off`(값 없음) · `count` · `jelly`.
({SaveGame? save, String? error, int jelly}) buyDuelStone(
  SaveGame s,
  DuelStoneConfig cfg,
  DuelStone kind, {
  int count = 1,
}) {
  final price = cfg.jelly[kind] ?? 0;
  if (price <= 0) return (save: null, error: 'off', jelly: 0);
  if (count < 1) return (save: null, error: 'count', jelly: 0);
  final cost = price * count;
  if (s.materialCount(MaterialKind.jelly) < cost) {
    return (save: null, error: 'jelly', jelly: cost);
  }
  final mats = Map<MaterialKind, int>.from(s.materials)
    ..[MaterialKind.jelly] = s.materialCount(MaterialKind.jelly) - cost;
  return (
    save: _addStones(s.copyWith(materials: mats), {kind: count}),
    error: null,
    jelly: cost,
  );
}

/// 결투석으로 곤충 [bugId] 의 오행([element]) 또는 기질([temperament])을 바꾼다. 바뀐 값은 그 곤충의 값이다
/// (짝짓기에도 상속된다). 혈통 특성은 바꾸지 않는다(design §3).
/// error: `no_bug` · `bad`(바꿀 값 없음) · `same`(이미 그 값) · `stone`(돌 부족).
TrainOp useDuelStone(
  SaveGame s,
  String bugId, {
  Element? element,
  Temperament? temperament,
}) {
  if ((element == null) == (temperament == null)) {
    return (save: null, error: 'bad');
  }
  final idx = s.bugs.indexWhere((b) => b.id == bugId);
  if (idx < 0) return (save: null, error: 'no_bug');
  final bug = s.bugs[idx];
  final kind = element != null ? DuelStone.element : DuelStone.temperament;
  if ((element != null && bug.element == element) ||
      (temperament != null && bug.temperament == temperament)) {
    return (save: null, error: 'same');
  }
  if (s.duelStoneCount(kind) < 1) return (save: null, error: 'stone');
  final bugs = List<IndividualBug>.from(s.bugs)
    ..[idx] = bug.copyWith(element: element, temperament: temperament);
  final stones = Map<DuelStone, int>.from(s.duelStones)
    ..[kind] = s.duelStoneCount(kind) - 1;
  return (save: s.copyWith(bugs: bugs, duelStones: stones), error: null);
}

/// 이번 업로드에서 **젤리 없이** 늘 수 있는 결투석 수(서버 급증 검사). 정예 0.2%·보스 재처치 1% 는 한 업로드
/// (60초)에 한 번도 드물다 — 네트워크가 끊긴 채 몇 시간 논 경우까지 덮게 넉넉히 둔다(스킬 조각 여유와 같은 역할).
const kDuelStoneDropSlack = 10;

/// 결투석 증가 허용치 = 쓴 젤리로 살 수 있던 수 + 새 심연 마일스톤 × 마일스톤 개수 + 드롭 여유.
int duelStoneAllowance(
  DuelStoneConfig cfg, {
  required int jellySpent,
  required int abyssMilestones,
}) {
  final cheapest = cfg.jelly.values
      .where((p) => p > 0)
      .fold<int>(1 << 30, math.min);
  final bought = cheapest >= 1 << 30 ? 0 : math.max(0, jellySpent) ~/ cheapest;
  final perMilestone = cfg.abyssCount.values.fold<int>(0, (a, b) => a + b);
  return bought +
      math.max(0, abyssMilestones) * perMilestone +
      kDuelStoneDropSlack;
}
