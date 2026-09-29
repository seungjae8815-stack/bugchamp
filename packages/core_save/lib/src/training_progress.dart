import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:meta/meta.dart';

import 'save_game.dart';

/// 훈련소(2026-09-29 사장님 확정) — 곤충마다 결투 능력치 5종을 훈련한다.
///
/// 솔로 루프와 같은 **기기 권위**다(재료·곤충이 기기 권위라서). 앱과 서버가 이 함수들을 같이 쓰고,
/// 서버는 결투 팀을 만들 때 단계를 **최대 단계로 자른다**([trainingBonusOf]) — 부위 강화·수련과 같은
/// 수준의 방어이고, 곤충을 서버 발급으로 바꿀 때 함께 봉인한다.

/// 훈련소 1칸에서 진행 중인 훈련.
@immutable
class TrainingJob {
  const TrainingJob({
    required this.bugId,
    required this.stat,
    required this.level,
    required this.until,
  });

  final String bugId;
  final TrainStat stat;

  /// 끝나면 이 단계가 된다.
  final int level;
  final DateTime until;

  bool doneAt(DateTime now) => !now.toUtc().isBefore(until);

  Map<String, dynamic> toJson() => {
    'b': bugId,
    's': stat.key,
    'l': level,
    'u': until.toUtc().toIso8601String(),
  };

  static TrainingJob? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final stat = TrainStat.fromKeyOrNull('${raw['s']}');
    final until = DateTime.tryParse('${raw['u']}')?.toUtc();
    if (stat == null || until == null) return null;
    return TrainingJob(
      bugId: '${raw['b']}',
      stat: stat,
      level: (raw['l'] as num?)?.toInt() ?? 1,
      until: until,
    );
  }
}

/// 이 곤충의 훈련 단계(없으면 빈 맵).
Map<TrainStat, int> trainLevelsOf(SaveGame s, String bugId) =>
    s.duelTraining[bugId] ?? const {};

/// 이 곤충의 [stat] 최대 단계.
int trainCapOf(
  IndividualBug b,
  Species sp,
  TrainStat stat,
  TrainingConfig cfg,
) => cfg.cap(
  stat,
  potential: b.potential,
  temperament: b.temperament,
  specialty: sp.specialty,
  trait: b.trait,
);

/// 결투 보너스 — 훈련 단계는 **최대 단계로**, 수련 레벨은 **돌파 티어 상한([levelCap])으로** 잘라서
/// 계산한다(서버가 위조를 자르는 곳). 수련 레벨 → 체력·공격 × (1 + (레벨-1) × duelLevelBonus)
/// (2026-09-29 사장님 확정: 펫이 강해지면 결투도 강해진다).
({
  double atkMult,
  double defMult,
  double hpMult,
  double evade,
  double crit,
  double recovery,
})
trainingBonusOf(
  SaveGame s,
  IndividualBug b,
  Species sp,
  TrainingConfig cfg, {
  int? levelCap,
}) {
  final raw = trainLevelsOf(s, b.id);
  final t = cfg.bonuses({
    for (final e in raw.entries)
      e.key: e.value.clamp(0, trainCapOf(b, sp, e.key, cfg)),
  });
  final lv = levelCap == null ? b.level : b.level.clamp(1, levelCap);
  final lm = 1 + (lv - 1) * cfg.duelLevelBonus;
  return (
    atkMult: t.atkMult * lm,
    defMult: t.defMult,
    hpMult: lm,
    evade: t.evade,
    crit: t.crit,
    recovery: t.recovery,
  );
}

/// 끝난 훈련을 반영한다(끝나지 않았으면 그대로).
SaveGame finishTrainingIfDue(SaveGame s, DateTime now) {
  final job = s.trainingJob;
  if (job == null || !job.doneAt(now)) return s;
  return _applyJob(s, job);
}

SaveGame _applyJob(SaveGame s, TrainingJob job) {
  final all = Map<String, Map<TrainStat, int>>.from(s.duelTraining);
  // 곤충이 사라졌으면(분해·합성) 기록하지 않는다.
  if (s.bugs.any((b) => b.id == job.bugId)) {
    final lv = Map<TrainStat, int>.from(all[job.bugId] ?? const {});
    lv[job.stat] = job.level;
    all[job.bugId] = lv;
  }
  return s.copyWith(duelTraining: all, clearTrainingJob: true);
}

/// 훈련 시작 — 재료를 내고 타이머를 건다. 실패하면 error:
/// `busy`(다른 훈련 중) · `maxed`(최대 단계) · `materials`(재료 부족) · `no_bug`.
({SaveGame? save, String? error}) startTraining(
  SaveGame s,
  TrainingConfig cfg,
  IndividualBug bug,
  Species sp,
  TrainStat stat,
  DateTime now,
) {
  s = finishTrainingIfDue(s, now);
  if (s.trainingJob != null) return (save: null, error: 'busy');
  if (!s.bugs.any((b) => b.id == bug.id)) return (save: null, error: 'no_bug');
  final cur = trainLevelsOf(s, bug.id)[stat] ?? 0;
  if (cur >= trainCapOf(bug, sp, stat, cfg)) {
    return (save: null, error: 'maxed');
  }
  final next = cur + 1;
  final cost = cfg.costFor(next, sp.grade);
  const kinds = kTrainingMaterials;
  if (kinds.any((k) => s.materialCount(k) < cost)) {
    return (save: null, error: 'materials');
  }
  final mats = Map<MaterialKind, int>.from(s.materials);
  for (final k in kinds) {
    mats[k] = (mats[k] ?? 0) - cost;
  }
  return (
    save: s.copyWith(
      materials: mats,
      trainingJob: TrainingJob(
        bugId: bug.id,
        stat: stat,
        level: next,
        until: now.toUtc().add(cfg.timeFor(next)),
      ),
    ),
    error: null,
  );
}

/// 젤리로 지금 훈련을 끝낸다. error: `none`(훈련 없음) · `jelly`(부족).
({SaveGame? save, String? error, int jelly}) instantFinishTraining(
  SaveGame s,
  TrainingConfig cfg,
  DateTime now,
) {
  final job = s.trainingJob;
  if (job == null) return (save: null, error: 'none', jelly: 0);
  final cost = cfg.instantJelly(job.until.difference(now.toUtc()));
  if (s.materialCount(MaterialKind.jelly) < cost) {
    return (save: null, error: 'jelly', jelly: cost);
  }
  final mats = Map<MaterialKind, int>.from(s.materials)
    ..[MaterialKind.jelly] = s.materialCount(MaterialKind.jelly) - cost;
  return (
    save: _applyJob(s.copyWith(materials: mats), job),
    error: null,
    jelly: cost,
  );
}

/// 훈련 초기화 — 쓴 재료의 [TrainingConfig.resetRefund] 만큼 돌려받고 단계를 0으로.
/// 이 곤충을 훈련하는 중이면 `busy`.
({SaveGame? save, String? error, int refund}) resetTraining(
  SaveGame s,
  TrainingConfig cfg,
  IndividualBug bug,
  Species sp,
) {
  if (s.trainingJob?.bugId == bug.id) {
    return (save: null, error: 'busy', refund: 0);
  }
  final lv = trainLevelsOf(s, bug.id);
  if (lv.isEmpty) return (save: null, error: 'none', refund: 0);
  var spent = 0;
  for (final n in lv.values) {
    for (var i = 1; i <= n; i++) {
      spent += cfg.costFor(i, sp.grade);
    }
  }
  final refund = (spent * cfg.resetRefund).floor();
  final mats = Map<MaterialKind, int>.from(s.materials);
  for (final k in kTrainingMaterials) {
    mats[k] = (mats[k] ?? 0) + refund;
  }
  final all = Map<String, Map<TrainStat, int>>.from(s.duelTraining)
    ..remove(bug.id);
  return (
    save: s.copyWith(materials: mats, duelTraining: all),
    error: null,
    refund: refund,
  );
}

/// 훈련에 드는 재료(키틴·미네랄·수액 — 같은 양씩).
const kTrainingMaterials = [
  MaterialKind.chitin,
  MaterialKind.mineral,
  MaterialKind.sap,
];

/// 사라진 곤충의 훈련 기록을 지운다(분해·합성·상한 정리 뒤). 바뀐 게 없으면 그대로.
SaveGame pruneTraining(SaveGame s) {
  if (s.duelTraining.isEmpty && s.trainingJob == null) return s;
  final ids = {for (final b in s.bugs) b.id};
  final gone = s.duelTraining.keys.where((k) => !ids.contains(k)).toList();
  final jobGone = s.trainingJob != null && !ids.contains(s.trainingJob!.bugId);
  if (gone.isEmpty && !jobGone) return s;
  final all = Map<String, Map<TrainStat, int>>.from(s.duelTraining);
  for (final k in gone) {
    all.remove(k);
  }
  return s.copyWith(duelTraining: all, clearTrainingJob: jobGone);
}

/// 훈련 → 방치(펫) 배율 = 1 + 훈련 단계 합계 × [TrainingConfig.petScale](2026-09-29).
/// 펫이 강해지면 사냥도 결투도 강해진다 — 훈련도 펫 기여에 들어간다.
double trainPetMult(SaveGame s, String bugId, TrainingConfig cfg) {
  final total = trainLevelsOf(s, bugId).values.fold<int>(0, (a, x) => a + x);
  return 1 + total * cfg.petScale;
}
