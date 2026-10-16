import 'package:core_models/core_models.dart';

/// 곤충마다 희귀도(2026-10-16 사장님 확정, 1.0.22, `docs/design_bug_rarity.md`) — `pets.json → bugRarity`.
///
/// 희귀도가 종이 아니라 **곤충마다** 정해진다. 같은 장수말벌도 일반~전설이 따로 나온다.
/// 개체 등급(포텐셜 1~5)은 별개 축 그대로다 — 곤충 = 종 × 희귀도 × 개체 등급.
/// 값이 없으면 [enabled] = false — 희귀도는 옛 규칙대로 종 희귀도(`Species.grade`)다(단계적 배포).
class BugRarityConfig {
  const BugRarityConfig({
    this.enabled = false,
    this.wildWeights = const [52, 28, 14, 5, 1],
    this.gachaWeights = const [0, 25, 30, 28, 17],
    this.huntMult = const [0.90, 1.00, 1.15, 1.35, 1.60],
    this.duelMult = const [1.0, 1.0, 1.0, 1.0, 1.0],
    this.upFodder = 3,
  });

  final bool enabled;

  /// 야생·짝짓기 희귀도 확률(일반 → 전설). 업데이트 전 곤충도 이 표로 새로 굴린다(사장님 확정 C안).
  final List<double> wildWeights;

  /// 알 뽑기·결제 알(`gc`) 희귀도 확률(일반 → 전설).
  final List<double> gachaWeights;

  /// 펫 기여(사냥) 배율(일반 → 전설) — 야생 확률로 평균 ≈ 1(평균 유저 90일 표 그대로, 사장님 확정).
  final List<double> huntMult;

  /// 결투·대회 체력·공격·방어 배율(일반 → 전설) — 전설 희귀도 대 일반 희귀도 65%(`duel_build_sim` 으로 맞춘다).
  final List<double> duelMult;

  /// 희귀도 올리기 재료 — 같은 종 · 같은 희귀도 곤충 몇 마리로 한 단계(2026-10-16 사장님 확정 3). 0 = 끔.
  final int upFodder;

  /// [bug] 의 희귀도. 앱·서버·시뮬이 모두 이 함수를 거친다 — 갈리면 "화면 희귀도와 실제 효과가 다르다"가 된다.
  /// 꺼져 있으면 종 희귀도(옛 규칙). 켜져 있으면 곤충에 정해 준 값, 없으면 id 롤(뽑기 출신은 뽑기 표).
  Grade rarityOf(IndividualBug bug, Species species) {
    if (!enabled) return species.grade;
    return ownRarityOf(bug);
  }

  /// 켜졌을 때의 곤충 희귀도(종을 보지 않는다) — 정해 준 값, 없으면 id 롤. 서버 업로드 검사용.
  Grade ownRarityOf(IndividualBug bug) =>
      bug.rarity ??
      pickWith(
        bug.fromGacha ? gachaWeights : wildWeights,
        IndividualBug.rarityRollOf(bug.id),
      );

  /// 희귀 천장 곤충의 희귀도 — **희귀 이상 표 + 같은 id 롤**(난수 아님). 정해서 주는 값(`ry`)도 id 로 정해야
  /// 서버가 다시 계산해 맞춰 볼 수 있다(세이브 검토 2026-10-16 — 아니면 `ry: legendary` 한 줄로 전설을 무한히 만든다).
  Grade pityRarityOf(String id) => pickWith(
    atLeast(wildWeights, Grade.rare),
    IndividualBug.rarityRollOf(id),
  );

  /// [weights](일반 → 전설)에서 [r](0 이상 1 미만)로 희귀도를 고른다. 무게가 없으면 일반.
  static Grade pickWith(List<double> weights, double r) {
    final n = weights.length < Grade.values.length
        ? weights.length
        : Grade.values.length;
    var total = 0.0;
    for (var i = 0; i < n; i++) {
      if (weights[i] > 0) total += weights[i];
    }
    if (total <= 0) return Grade.common;
    var x = r * total;
    for (var i = 0; i < n; i++) {
      if (weights[i] <= 0) continue;
      x -= weights[i];
      if (x < 0) return Grade.values[i];
    }
    for (var i = n - 1; i >= 0; i--) {
      if (weights[i] > 0) return Grade.values[i];
    }
    return Grade.common;
  }

  /// [min] 이상만 남긴 표(천장 — 그 아래 희귀도를 잘라 낸다).
  static List<double> atLeast(List<double> weights, Grade min) => [
    for (var i = 0; i < weights.length; i++) i >= min.index ? weights[i] : 0.0,
  ];

  static double _at(List<double> v, Grade g) =>
      g.index < v.length ? v[g.index] : 1.0;

  /// 펫 기여 배율. 꺼져 있으면 1.
  double huntMultOf(Grade rarity) => enabled ? _at(huntMult, rarity) : 1.0;

  /// 결투 체력·공격·방어 배율. 꺼져 있으면 1.
  double duelMultOf(Grade rarity) => enabled ? _at(duelMult, rarity) : 1.0;

  factory BugRarityConfig.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const BugRarityConfig();
    const d = BugRarityConfig();
    List<double> dl(String k, List<double> v) => j[k] is List
        ? [for (final x in j[k] as List) (x as num).toDouble()]
        : v;
    return BugRarityConfig(
      enabled: j['enabled'] as bool? ?? false,
      wildWeights: dl('wildWeights', d.wildWeights),
      gachaWeights: dl('gachaWeights', d.gachaWeights),
      huntMult: dl('huntMult', d.huntMult),
      duelMult: dl('duelMult', d.duelMult),
      upFodder: (j['upFodder'] as num?)?.toInt() ?? d.upFodder,
    );
  }
}
