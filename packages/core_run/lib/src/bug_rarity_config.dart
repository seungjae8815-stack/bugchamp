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
    this.worth = const [],
    this.feed = const [],
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

  /// 곤충 양분 **문턱**(일반 → 전설, 2026-11-09 사장님 확정 — "전설까지 양분 약 1,000"). 곤충의 양분 = 이 희귀도 문턱 +
  /// 모은 양분(`IndividualBug.rarityWorth`). 양분이 다음 희귀도 문턱에 닿으면 그 희귀도가 된다([rarityForWorth]).
  /// 비어 있으면 끔(옛 3마리 규칙).
  final List<int> worth;

  /// 먹이면 채우는 양(일반 → 전설, 2026-11-09 사장님 확정 **2배씩** 4·8·16·32 — "영웅이 나오면 전설이 쉬워진다").
  /// 문턱(4배씩)보다 완만해서 높은 희귀도 곤충 하나가 지름길이 되지 않는다(영웅 하나 = 전설의 3%). 같은 종을 야생 확률로
  /// 먹이면 전설까지 약 100마리(4배씩이던 첫안은 약 38마리, 간이 시뮬). 비어 있으면 문턱과 같은 값([worth]).
  /// 문턱보다 크면 안 된다 — 업로드 사이에 올린 곤충을 바로 먹일 때 서버 검사가 총량 보존에 기댄다(`takeRarityWorth`).
  final List<int> feed;

  /// 양분 게이지가 켜졌는가.
  bool get worthOn => enabled && worth.length >= Grade.values.length;

  /// [rarity] 곤충의 양분 문턱(양분 게이지가 꺼져 있으면 0).
  int worthOfRarity(Grade rarity) => worthOn ? worth[rarity.index] : 0;

  /// [rarity] 곤충 하나를 먹이면 채우는 양(그 곤충이 모은 양분은 따로 더한다).
  int feedOfRarity(Grade rarity) {
    if (!worthOn) return 0;
    if (feed.length < Grade.values.length) return worth[rarity.index];
    return feed[rarity.index];
  }

  /// 총 가치 [w] 가 닿는 가장 높은 희귀도.
  Grade rarityForWorth(int w) {
    var r = Grade.common;
    if (!worthOn) return r;
    for (final g in Grade.values) {
      if (w >= worth[g.index]) r = g;
    }
    return r;
  }

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
      worth: j['worth'] is List
          ? [for (final x in j['worth'] as List) (x as num).toInt()]
          : d.worth,
      feed: j['feed'] is List
          ? [for (final x in j['feed'] as List) (x as num).toInt()]
          : d.feed,
    );
  }
}
