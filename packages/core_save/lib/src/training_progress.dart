import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:meta/meta.dart';

import 'save_game.dart';
import 'train_points.dart';

/// 훈련소 v1(2026-09-29) — 곤충마다 결투 능력치 5종을 훈련했다. **2026-10-08 훈련 v2(train_points.dart)로 대체** —
/// 여기 남은 것은 옛 기록 읽기·이전 환산(옛 단계 상한)·정리뿐이다. 옛 단계를 올리는 함수는 지웠다.
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

/// 옛 진행 중 훈련을 반영한다 — 훈련 v2 이전([migrateTrainingV2])이 대신한다(옛 대기열은 이전 때 끝난 것으로 친다).
/// 남겨 두는 이유: 이전 전에 저장된 세이브를 읽는 도구·테스트가 쓴다.
SaveGame finishTrainingIfDue(SaveGame s, DateTime now) {
  final job = s.trainingJob;
  if (job == null || !job.doneAt(now)) return s;
  final all = Map<String, Map<TrainStat, int>>.from(s.duelTraining);
  if (s.bugs.any((b) => b.id == job.bugId)) {
    final lv = Map<TrainStat, int>.from(all[job.bugId] ?? const {});
    lv[job.stat] = job.level;
    all[job.bugId] = lv;
  }
  return s.copyWith(duelTraining: all, clearTrainingJob: true);
}

/// 훈련에 드는 재료(키틴·미네랄·수액 — 같은 양씩).
const kTrainingMaterials = [
  MaterialKind.chitin,
  MaterialKind.mineral,
  MaterialKind.sap,
];

/// 사라진 곤충의 훈련 기록(옛 단계 + v2 배분)을 지운다(분해·합성·상한 정리 뒤). 바뀐 게 없으면 그대로.
SaveGame pruneTraining(SaveGame s) {
  s = pruneTrainPoints(s);
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
