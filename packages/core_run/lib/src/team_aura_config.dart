import 'dart:math' as math;

import 'package:meta/meta.dart';

/// 결투 팀 역할 오라(1.0.21 D3, 2026-10-14 사장님 확정, docs/design_growth_1021.md §3 ·
/// `battle.json → duel.teamAura`).
///
/// 종마다 역할(공격형·방어형·체력형, `species.json → duelRole`)이 있고, **3마리 결투**에 나선 곤충마다
/// 팀 전체에 그 역할 능력치 +% 를 준다. 곤충 1마리의 오라 = 개체 등급 기본([baseByGrade]) + 지휘 칸 포인트 ×
/// 1점당 효과(`training.slots.command.effect`). 팀 합은 능력치마다 [capPerStat] 까지.
/// 왕충 선발대회(1마리)에는 붙지 않는다.
@immutable
class TeamAuraConfig {
  const TeamAuraConfig({
    this.enabled = true,
    this.baseByGrade = const [0.02, 0.03, 0.04, 0.05, 0.06],
    this.capPerStat = 0.20,
  });

  /// 끄면 오라가 없다(엔진·화면 모두).
  final bool enabled;

  /// 개체 등급(포텐셜 1~5 = 일반·고급·희귀·영웅·전설)별 기본 오라.
  final List<double> baseByGrade;

  /// 팀 합의 능력치별 상한.
  final double capPerStat;

  /// 개체 등급 [potential](1~5) 의 기본 오라.
  double baseFor(int potential) {
    if (baseByGrade.isEmpty) return 0;
    final i = (potential - 1).clamp(0, baseByGrade.length - 1);
    return math.max(0, baseByGrade[i]);
  }

  factory TeamAuraConfig.fromJson(Object? raw) {
    if (raw is! Map) return const TeamAuraConfig();
    const d = TeamAuraConfig();
    final base = raw['baseByGrade'];
    return TeamAuraConfig(
      enabled: raw['enabled'] is bool ? raw['enabled'] as bool : d.enabled,
      baseByGrade: base is List
          ? [for (final x in base) (x as num).toDouble()]
          : d.baseByGrade,
      capPerStat: (raw['capPerStat'] as num?)?.toDouble() ?? d.capPerStat,
    );
  }
}
