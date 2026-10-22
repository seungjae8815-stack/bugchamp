import 'dart:math' as math;

import 'package:meta/meta.dart';

import 'jelly_cost.dart';

/// 연구소 분야 3개(설계 `docs/superpowers/specs/2026-10-22-research-lab-design.md`).
enum ResearchBranch {
  hunt('hunt'),
  nurture('nurture'),
  duel('duel');

  const ResearchBranch(this.key);
  final String key;

  static ResearchBranch fromKey(String key) => values.firstWhere(
    (e) => e.key == key,
    orElse: () => throw ArgumentError('Unknown ResearchBranch key: $key'),
  );
}

/// 연구가 올리는 효과 14종. ⚠️ 열거 순서 = JSON 키 — 새 항목은 **맨 뒤**에만.
enum ResearchEffect {
  huntAtk('huntAtk'),
  huntHpDef('huntHpDef'),
  find('find'),
  gold('gold'),
  bossDmg('bossDmg'),
  offline('offline'),
  hatchTime('hatchTime'),
  breedTime('breedTime'),
  trainTime('trainTime'),
  researchTime('researchTime'),
  duelAtk('duelAtk'),
  duelDef('duelDef'),
  duelHp('duelHp'),
  injuryTime('injuryTime');

  const ResearchEffect(this.key);
  final String key;

  /// 시간 단축 효과(합이 [0, [kResearchTimeCutMax]] 로 잘린다).
  bool get isTimeCut => switch (this) {
    hatchTime || breedTime || trainTime || researchTime || injuryTime => true,
    _ => false,
  };

  static ResearchEffect fromKey(String key) => values.firstWhere(
    (e) => e.key == key,
    orElse: () => throw ArgumentError('Unknown ResearchEffect key: $key'),
  );
}

/// 시간 단축 효과 합의 상한(절반까지만 줄인다) — 기획 확정 규칙값.
const double kResearchTimeCutMax = 0.5;

/// 연구 1종의 정의 (assets/data/research.json).
@immutable
class ResearchDef {
  const ResearchDef({
    required this.id,
    required this.branch,
    required this.effect,
    required this.maxLevel,
    this.requires,
    this.name = const {},
    this.perLevel = 0,
    this.effectGrowth = 1,
    this.firstSeconds = 0,
    this.timeGrowth = 1,
    this.samplesFirst = 0,
    this.goldMinutesFirst = 0,
    this.materialMinutesFirst = 0,
    this.fossilFrom = 0,
    this.fossilFirst = 0,
    this.costGrowth = 1,
  });

  final String id;
  final ResearchBranch branch;
  final ResearchEffect effect;
  final int maxLevel;

  /// 선행 연구(없으면 null) — 그 연구가 `level` 이상이어야 시작할 수 있다.
  final ({String id, int level})? requires;
  final Map<String, String> name;

  // 곡선(JSON): 누적 효과 = Σ perLevel × growth^(i-1).
  final double perLevel;
  final double effectGrowth;
  final double firstSeconds;
  final double timeGrowth;
  final double samplesFirst;
  final double goldMinutesFirst;
  final double materialMinutesFirst;
  final int fossilFrom;
  final double fossilFirst;
  final double costGrowth;

  factory ResearchDef.fromJson(Map<String, dynamic> j) {
    Map<String, dynamic> m(String k) =>
        (j[k] as Map?)?.cast<String, dynamic>() ?? const {};
    final eff = m('effect');
    final time = m('time');
    final cost = m('cost');
    final req = (j['requires'] as Map?)?.cast<String, dynamic>();
    double n(Map<String, dynamic> src, String k, double d) =>
        (src[k] as num?)?.toDouble() ?? d;
    return ResearchDef(
      id: j['id'] as String,
      branch: ResearchBranch.fromKey(j['branch'] as String),
      effect: ResearchEffect.fromKey(j['kind'] as String),
      maxLevel: (j['maxLevel'] as num).toInt(),
      requires: req == null
          ? null
          : (id: req['id'] as String, level: (req['level'] as num).toInt()),
      name: {
        for (final e in ((j['name'] as Map?) ?? const {}).entries)
          '${e.key}': '${e.value}',
      },
      perLevel: n(eff, 'perLevel', 0),
      effectGrowth: n(eff, 'growth', 1),
      firstSeconds: n(time, 'firstSeconds', 0),
      timeGrowth: n(time, 'growth', 1),
      samplesFirst: n(cost, 'samplesFirst', 0),
      goldMinutesFirst: n(cost, 'goldMinutesFirst', 0),
      materialMinutesFirst: n(cost, 'materialMinutesFirst', 0),
      fossilFrom: (cost['fossilFrom'] as num?)?.toInt() ?? 0,
      fossilFirst: n(cost, 'fossilFirst', 0),
      costGrowth: n(cost, 'growth', 1),
    );
  }
}

/// 연구 한 단계의 비용. 골드·재료는 "사냥 N분치"(선물과 같은 단위)로 둔다.
@immutable
class ResearchCost {
  const ResearchCost({
    required this.samples,
    required this.goldMinutes,
    required this.materialMinutes,
    required this.fossil,
  });

  final int samples;
  final double goldMinutes;
  final double materialMinutes;
  final int fossil;
}

/// 연구소 설정 (assets/data/research.json).
@immutable
class ResearchConfig {
  const ResearchConfig({
    this.defs = const [],
    this.slotsByTier = const [1, 1, 2, 3],
    this.slotJelly = const [100, 300],
    this.instantJellyPerMinute = 1.0,
    this.instantJellyExponent = 0.58,
    this.eliteDropChance = 0,
    this.eliteDropAmount = 1,
    this.bossFirstDrop = 0,
    this.bossRepeatDrop = 0,
    this.bossRepeatChance = 0,
  });

  final List<ResearchDef> defs;

  /// 처음 가 본 난이도(0 쉬움~3 극한)별 연구 칸 수.
  final List<int> slotsByTier;

  /// 2·3번째 칸을 젤리로 사는 가격.
  final List<int> slotJelly;
  final double instantJellyPerMinute;
  final double instantJellyExponent;
  final double eliteDropChance;
  final int eliteDropAmount;
  final int bossFirstDrop;
  final int bossRepeatDrop;
  final double bossRepeatChance;

  /// 칸 수 최대(코드 상수 — 기획 확정 규칙값).
  static const int maxSlots = 3;

  ResearchDef? byId(String id) {
    for (final d in defs) {
      if (d.id == id) return d;
    }
    return null;
  }

  /// 레벨 [level] 까지의 누적 효과(0 레벨 = 0).
  double effectAt(ResearchDef d, int level) {
    final lv = math.min(level, d.maxLevel);
    var sum = 0.0;
    for (var i = 1; i <= lv; i++) {
      sum += d.perLevel * math.pow(d.effectGrowth, i - 1);
    }
    return sum;
  }

  /// Lv [level] **하나**에 걸리는 시간.
  Duration timeAt(ResearchDef d, int level) => Duration(
    seconds: (d.firstSeconds * math.pow(d.timeGrowth, level - 1)).round(),
  );

  /// Lv [level] 하나의 비용.
  ResearchCost costAt(ResearchDef d, int level) {
    final g = math.pow(d.costGrowth, level - 1);
    return ResearchCost(
      samples: (d.samplesFirst * g).round(),
      goldMinutes: d.goldMinutesFirst * g,
      materialMinutes: d.materialMinutesFirst * g,
      fossil: d.fossilFrom > 0 && level >= d.fossilFrom
          ? (d.fossilFirst * math.pow(d.costGrowth, level - d.fossilFrom))
                .round()
          : 0,
    );
  }

  /// 남은 [remaining] 을 젤리로 즉시 끝내는 값(5·10 단위).
  int instantJelly(Duration remaining) {
    if (remaining <= Duration.zero) return 0;
    final minutes = remaining.inSeconds / 60;
    return roundJellyCost(
      instantJellyPerMinute * math.pow(minutes, instantJellyExponent),
    );
  }

  /// 연구 칸 수 = max(진행도 칸, 1 + 산 칸) 을 [maxSlots] 로 자른다.
  int slotsFor(int topTier, int bought) {
    final byTier = slotsByTier.isEmpty
        ? 1
        : slotsByTier[topTier.clamp(0, slotsByTier.length - 1)];
    return math.min(maxSlots, math.max(byTier, 1 + bought));
  }

  factory ResearchConfig.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const ResearchConfig();
    const d = ResearchConfig();
    List<int> ints(Object? raw, List<int> def) =>
        raw is List ? [for (final e in raw) (e as num).toInt()] : def;
    return ResearchConfig(
      defs: [
        for (final e in (j['research'] as List? ?? const []))
          ResearchDef.fromJson((e as Map).cast<String, dynamic>()),
      ],
      slotsByTier: ints(j['slotsByTier'], d.slotsByTier),
      slotJelly: ints(j['slotJelly'], d.slotJelly),
      instantJellyPerMinute:
          (j['instantJellyPerMinute'] as num?)?.toDouble() ??
          d.instantJellyPerMinute,
      instantJellyExponent:
          (j['instantJellyExponent'] as num?)?.toDouble() ??
          d.instantJellyExponent,
      eliteDropChance:
          (j['eliteDropChance'] as num?)?.toDouble() ?? d.eliteDropChance,
      eliteDropAmount:
          (j['eliteDropAmount'] as num?)?.toInt() ?? d.eliteDropAmount,
      bossFirstDrop: (j['bossFirstDrop'] as num?)?.toInt() ?? d.bossFirstDrop,
      bossRepeatDrop:
          (j['bossRepeatDrop'] as num?)?.toInt() ?? d.bossRepeatDrop,
      bossRepeatChance:
          (j['bossRepeatChance'] as num?)?.toDouble() ?? d.bossRepeatChance,
    );
  }
}

/// 연구 레벨 합산 결과. 시간 단축 효과는 [0, 0.5] 로 잘려 있다.
@immutable
class ResearchEffects {
  const ResearchEffects(this._v);
  static const ResearchEffects none = ResearchEffects({});
  final Map<ResearchEffect, double> _v;

  double of(ResearchEffect e) => _v[e] ?? 0;
}

/// [levels](연구 id → 완료 레벨)를 효과로 합친다. 같은 효과 여러 연구는 합.
ResearchEffects researchEffects(ResearchConfig c, Map<String, int> levels) {
  final sum = <ResearchEffect, double>{};
  for (final d in c.defs) {
    final lv = levels[d.id] ?? 0;
    if (lv <= 0) continue;
    sum[d.effect] = (sum[d.effect] ?? 0) + c.effectAt(d, lv);
  }
  for (final e in sum.keys.toList()) {
    if (e.isTimeCut) {
      sum[e] = sum[e]!.clamp(0.0, kResearchTimeCutMax).toDouble();
    }
  }
  return ResearchEffects(sum);
}
