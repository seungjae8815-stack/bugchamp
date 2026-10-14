import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';

import 'save_game.dart';
import 'train_points.dart';

/// 결투 팀 역할 오라 — 곤충 1마리가 팀에 주는 몫(1.0.21 D3, docs/design_growth_1021.md §3).
///
/// 역할 = 종의 `duelRole`, 크기 = 개체 등급(포텐셜 1~5) 기본 + 지휘 칸 포인트 × 1점당 효과(칸 상한·예산으로
/// 자른 배분 — [trainingBonusOf] 와 같은 [effectiveAllocOf]). 앱(`duelBugFor`·화면 요약)과 서버(`validateDuelTeam`)가
/// **같은 함수**를 쓴다. 꺼져 있거나 역할이 없으면 `(role: null, value: 0)`.
({DuelRole? role, double value}) duelAuraOf(
  SaveGame s,
  IndividualBug b,
  Species sp,
  TrainingConfig training,
  TeamAuraConfig aura, {
  int? levelCap,
  EnhanceConfig? enhance,
}) {
  final role = sp.duelRole;
  if (!aura.enabled || role == null) return (role: null, value: 0);
  final t = training.slotBonuses(
    effectiveAllocOf(s, b, sp, training, levelCap: levelCap, enhance: enhance),
    sp.specialty,
  );
  return (role: role, value: aura.baseFor(b.potential) + t.aura);
}
