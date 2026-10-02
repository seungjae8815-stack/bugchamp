import 'dart:math' as math;

import 'package:core_models/core_models.dart';
import 'package:meta/meta.dart';

import 'character_stats.dart';

/// 요정 능력치 키 — 데이터 검사가 이 목록으로 오타를 잡는다.
/// 모르는 키는 로딩을 통과하고 **능력치만 조용히 사라진다**(종 패시브와 같은 구멍).
///
/// ⚠️ 치명 **확률**은 없다 — `critBudget*` 예산이 장비·스킬로 이미 찼다(design_fairy.md §1.2).
const Set<String> kFairyStatKeys = {
  'attack',
  'hp',
  'defense',
  'attackSpeed',
  'critDamage',
  'bossDamage',
  'petShare',
};

/// 요정 스킬 효과 키(방치 런에 붙이는 해석은 3단계에서 호출부가 한다).
/// ⚠️ 재화를 그냥 주는 효과는 만들지 않는다(쿨타임이 기기 시계라 무한 발동 — §2.8).
const Set<String> kFairySkillEffects = {
  'burstDamage',
  'heal',
  'damageReduce',
  'attackSpeed',
  'critWindow',
  'bossBurst',
  'petPower',
  'lastStand',
};

/// 요정 스킬 정의(종류마다 하나).
@immutable
class FairySkillDef {
  const FairySkillDef({
    required this.effect,
    required this.base,
    this.perLevel = 0,
    this.cooldown = Duration.zero,
    this.duration = Duration.zero,
  });

  final String effect;

  /// 일반 등급 · 레벨 1 효과값. 등급 배율([FairyConfig.gradeSkillMult])이 곱해진다.
  final double base;

  /// 레벨당 증가 비율(효과값 × (1 + perLevel × (레벨−1))).
  final double perLevel;
  final Duration cooldown;
  final Duration duration;

  factory FairySkillDef.fromJson(Map<String, dynamic> json) => FairySkillDef(
    effect: json['effect'] as String,
    base: (json['base'] as num).toDouble(),
    perLevel: (json['perLevel'] as num?)?.toDouble() ?? 0,
    cooldown: Duration(seconds: (json['cooldown'] as num?)?.toInt() ?? 0),
    duration: Duration(seconds: (json['duration'] as num?)?.toInt() ?? 0),
  );
}

/// 요정 종류 1개(fairies.json → kinds).
@immutable
class FairyKindDef {
  const FairyKindDef({
    required this.id,
    required this.name,
    required this.title,
    required this.stats,
    required this.skill,
  });

  final String id;

  /// 이름(이그니스·운디네 …).
  final LocalizedText name;

  /// 칭호(불꽃의 요정 …) — 이름만으로는 무엇을 하는 요정인지 안 읽힌다.
  final LocalizedText title;

  /// 기본 능력치: 키 → 비중(주 능력치 1.0). 실제 값 = 비중 × 등급 계수 × 레벨 배율.
  final Map<String, double> stats;
  final FairySkillDef skill;

  factory FairyKindDef.fromJson(Map<String, dynamic> json) => FairyKindDef(
    id: json['id'] as String,
    name: LocalizedText.fromJson(
      Map<String, dynamic>.from(json['name'] as Map),
    ),
    title: LocalizedText.fromJson(
      Map<String, dynamic>.from(json['title'] as Map),
    ),
    stats: {
      for (final e in (json['stats'] as Map).entries)
        e.key as String: (e.value as num).toDouble(),
    },
    skill: FairySkillDef.fromJson(
      Map<String, dynamic>.from(json['skill'] as Map),
    ),
  );
}

/// 가속기 — 둥지 남은 시간을 [minutes] 분 줄인다. 젤리로 산다(시간 판매, §2.8).
@immutable
class FairyAccelDef {
  const FairyAccelDef({
    required this.id,
    required this.minutes,
    required this.jelly,
  });

  final String id;
  final int minutes;

  /// 1개 가격. 5·10 단위여야 한다(§2.6 젤리 가격 단위 — 테스트가 검사).
  final int jelly;

  factory FairyAccelDef.fromJson(Map<String, dynamic> json) => FairyAccelDef(
    id: json['id'] as String,
    minutes: (json['minutes'] as num).toInt(),
    jelly: (json['jelly'] as num).toInt(),
  );
}

Map<FairyGrade, T> _byGrade<T>(Object? raw, T Function(num) conv) => {
  if (raw is Map)
    for (final e in raw.entries)
      FairyGrade.fromKey(e.key as String): conv(e.value as num),
};

/// 요정 설정 전체(assets/data/fairies.json). 수치 설명은 docs/design_fairy.md.
@immutable
class FairyConfig {
  const FairyConfig({
    required this.kinds,
    this.gradeStatMin = const {},
    this.gradeStatMax = const {},
    this.rollSkew = 1.5,
    this.gradeSkillMult = const {},
    this.maxLevel = const {},
    this.levelStatPerLevel = 0.02,
    this.levelDustBase = const {},
    this.levelDustGrowth = 1.15,
    this.mergeCount = 3,
    this.mergeDustRefund = 0.7,
    this.hatchSec = const {},
    this.boxCap = 30,
    this.releaseDust = const {},
    this.subRatio = 0.5,
    this.subWeight = const {},
    this.stoneChance = 0.5,
    this.stoneJelly = 20,
    this.accelerators = const [],
    this.gachaJelly = 30,
    this.gachaWeights = const {},
    this.gachaPity = 10,
    this.gachaPityGrade = FairyGrade.legendary,
    this.exchangeDustPerJelly = 0,
    this.exchangeDustDailyCap = 0,
    this.dexMilestones = const [],
    this.drops = const FairyDrops(),
  });

  final List<FairyKindDef> kinds;

  /// 등급별 주 능력치 범위(레벨 1). 0.03 = +3%. 개체값이 이 사이의 자리를 정한다 —
  /// **등급마다 최대치가 다르고**, 같은 등급이라도 개체마다 세기가 다르다(뽑는 재미).
  final Map<FairyGrade, double> gradeStatMin;
  final Map<FairyGrade, double> gradeStatMax;

  /// 개체값 치우침 = 균등난수^[rollSkew]. 1 이면 균등, 클수록 **최대치 근처가 드물다**
  /// (1.5 → 상위 10%(개체값 900↑)가 나올 확률 약 7%).
  final double rollSkew;

  /// 등급별 스킬 효과 배율(일반 1.0).
  final Map<FairyGrade, double> gradeSkillMult;

  /// 등급별 레벨 상한.
  final Map<FairyGrade, int> maxLevel;

  /// 레벨당 능력치 증가 비율 — 값 × (1 + 이 값 × (레벨−1)).
  final double levelStatPerLevel;

  /// 등급별 레벨 1→2 가루 비용. 레벨마다 × [levelDustGrowth].
  final Map<FairyGrade, int> levelDustBase;
  final double levelDustGrowth;

  /// 합성에 드는 같은 종류·같은 등급 수(확률 없음 — 곤충 합성과 같은 이유).
  final int mergeCount;

  /// 합성·분해 때 재료 요정에 쓴 레벨업 가루를 돌려주는 비율(투자를 잃지 않게).
  final double mergeDustRefund;

  /// 등급별 부화 시간(초).
  final Map<FairyGrade, int> hatchSec;

  /// 요정함 상한(요정 + 알 + 둥지 속 알). 세이브 크기 방어선(§2.1).
  final int boxCap;

  /// 등급별 분해·넘친 알 가루. ❌ 젤리 없음(합성으로 무한히 만든 요정을 분해하면 무한 통로).
  final Map<FairyGrade, int> releaseDust;

  /// 부가 능력치 크기 = 등급 범위의 부가 개체값 자리 × 레벨 배율 × [subRatio] × [subWeight]. 기본의 절반 정도.
  final double subRatio;

  /// 부가 능력치 키 → 비중. **이 맵의 키가 부가로 나올 수 있는 능력치 전부**다
  /// (공격속도처럼 같은 %가 더 센 능력치는 비중을 낮춘다).
  final Map<String, double> subWeight;

  /// 속성석을 넣었을 때 그 부가 능력치가 나올 확률. 안 나오면 나머지 중 균등.
  final double stoneChance;

  /// 속성석 1개 젤리 가격(5·10 단위).
  final int stoneJelly;

  final List<FairyAccelDef> accelerators;

  /// 요정 알 뽑기 1회 젤리.
  final int gachaJelly;

  /// 뽑기 등급 가중치. ⚠️ 드롭보다 반드시 좋아야 한다(§2.6 — 돈을 내면 확률이 나빠지는 상품 금지).
  final Map<FairyGrade, double> gachaWeights;

  /// 상점 교환소: 젤리 1개당 요정 가루(2026-10-01). 0 이면 교환소에 안 뜬다.
  /// 서버는 쓴 젤리 × 이 값만큼 가루 증가를 더 허용한다.
  final double exchangeDustPerJelly;

  /// 교환소에서 하루에 받을 수 있는 가루(2026-10-01 사장님 (가) — 1:1 유지 + 하루 상한).
  /// 한도 없이 팔면 "시간"이 아니라 "레벨(능력치)"을 파는 쪽이 된다(§2.8). 0 = 상한 없음.
  final int exchangeDustDailyCap;

  /// [gachaPity] 회째는 [gachaPityGrade] 이상 확정.
  final int gachaPity;
  final FairyGrade gachaPityGrade;

  /// 무료 획득(보스 첫 처치·정예).
  final FairyDrops drops;

  FairyKindDef? byId(String id) {
    for (final k in kinds) {
      if (k.id == id) return k;
    }
    return null;
  }

  FairyAccelDef? accelById(String id) {
    for (final a in accelerators) {
      if (a.id == id) return a;
    }
    return null;
  }

  int maxLevelOf(FairyGrade g) => maxLevel[g] ?? 1;

  Duration hatchDuration(FairyGrade g) =>
      Duration(seconds: hatchSec[g] ?? 1800);

  /// [level] → [level]+1 가루 비용.
  int levelCost(FairyGrade g, int level) =>
      ((levelDustBase[g] ?? 0) *
              math.pow(levelDustGrowth, (level - 1).clamp(0, 1 << 10)))
          .round();

  /// 레벨 1 에서 [level] 까지 쓴 가루 합.
  int dustSpentTo(FairyGrade g, int level) {
    var sum = 0;
    for (var lv = 1; lv < level; lv++) {
      sum += levelCost(g, lv);
    }
    return sum;
  }

  double _levelMult(int level) =>
      1 + levelStatPerLevel * (level - 1).clamp(0, 1 << 10);

  /// 개체값을 굴린다(0~[kFairyRollMax]).
  int rollQuality(math.Random rng) =>
      (math.pow(rng.nextDouble(), rollSkew) * kFairyRollMax).round();

  /// 등급 [g] 의 범위에서 개체값 [roll] 자리의 값(레벨 1).
  double statAt(FairyGrade g, int roll) {
    final lo = gradeStatMin[g] ?? 0;
    final hi = gradeStatMax[g] ?? lo;
    return lo + (hi - lo) * roll.clamp(0, kFairyRollMax) / kFairyRollMax;
  }

  /// 기본 능력치(키 → 비율). 모르는 종류면 빈 맵.
  Map<String, double> mainBonus(Fairy f) {
    final def = byId(f.kind);
    if (def == null) return const {};
    final base = statAt(f.grade, f.baseRoll) * _levelMult(f.level);
    return {for (final e in def.stats.entries) e.key: e.value * base};
  }

  /// 부가 능력치 값(키는 [Fairy.sub]). 모르는 부가면 0.
  double subBonus(Fairy f) {
    final w = subWeight[f.sub];
    if (w == null) return 0;
    return statAt(f.grade, f.subRoll) * _levelMult(f.level) * subRatio * w;
  }

  /// 이 요정이 동행할 때 주는 능력치(키 → 비율) = 기본 + 부가. 모르는 종류면 빈 맵.
  Map<String, double> statBonus(Fairy f) {
    if (byId(f.kind) == null) return const {};
    final out = Map<String, double>.from(mainBonus(f));
    final sub = subBonus(f);
    if (sub > 0) out[f.sub] = (out[f.sub] ?? 0) + sub;
    return out;
  }

  /// 이 요정 스킬의 효과값. 모르는 종류면 0.
  double skillValue(Fairy f) {
    final def = byId(f.kind);
    if (def == null) return 0;
    final s = def.skill;
    return s.base *
        (gradeSkillMult[f.grade] ?? 1) *
        (1 + s.perLevel * (f.level - 1).clamp(0, 1 << 10));
  }

  /// 부화 종류 — 전 종류 균등.
  String rollKind(math.Random rng) => kinds[rng.nextInt(kinds.length)].id;

  /// 부가 능력치를 굴린다. [stoneSub] 가 있으면 그 능력치가 [stoneChance],
  /// 아니면 나머지 중 균등. 없으면 전부 균등.
  String rollSub(math.Random rng, {String? stoneSub}) {
    final pool = subWeight.keys.toList();
    if (stoneSub != null && subWeight.containsKey(stoneSub)) {
      if (rng.nextDouble() < stoneChance || pool.length == 1) return stoneSub;
      final rest = [
        for (final k in pool)
          if (k != stoneSub) k,
      ];
      return rest[rng.nextInt(rest.length)];
    }
    return pool[rng.nextInt(pool.length)];
  }

  /// 뽑기 1회 등급. [pityDue] 면 천장 등급 이상에서만 굴린다.
  FairyGrade? rollGacha(math.Random rng, {bool pityDue = false}) {
    final pool = {
      for (final e in gachaWeights.entries)
        if (e.value > 0 && (!pityDue || e.key.index >= gachaPityGrade.index))
          e.key: e.value,
    };
    if (pool.isEmpty) return pityDue ? gachaPityGrade : null;
    final total = pool.values.fold<double>(0, (a, b) => a + b);
    var pick = rng.nextDouble() * total;
    FairyGrade? last;
    for (final e in pool.entries) {
      last = e.key;
      pick -= e.value;
      if (pick < 0) return e.key;
    }
    return last;
  }

  /// 도감 마일스톤(2026-10-01 사장님 — **젤리 없이 재료 위주**). 도감 칸(등급 40 + 부가 56) 수가
  /// [FairyDexMilestone.count] 에 닿으면 앞에서부터 차례로 받는다.
  final List<FairyDexMilestone> dexMilestones;

  factory FairyConfig.fromJson(Map<String, dynamic> json) => FairyConfig(
    kinds: [
      for (final k in json['kinds'] as List)
        FairyKindDef.fromJson(Map<String, dynamic>.from(k as Map)),
    ],
    gradeStatMin: _byGrade(json['gradeStatMin'], (v) => v.toDouble()),
    gradeStatMax: _byGrade(json['gradeStatMax'], (v) => v.toDouble()),
    rollSkew: (json['rollSkew'] as num?)?.toDouble() ?? 1.5,
    gradeSkillMult: _byGrade(json['gradeSkillMult'], (v) => v.toDouble()),
    maxLevel: _byGrade(json['maxLevel'], (v) => v.toInt()),
    levelStatPerLevel: (json['levelStatPerLevel'] as num?)?.toDouble() ?? 0.02,
    levelDustBase: _byGrade(json['levelDustBase'], (v) => v.toInt()),
    levelDustGrowth: (json['levelDustGrowth'] as num?)?.toDouble() ?? 1.15,
    mergeCount: (json['mergeCount'] as num?)?.toInt() ?? 3,
    mergeDustRefund: (json['mergeDustRefund'] as num?)?.toDouble() ?? 0.7,
    hatchSec: _byGrade(json['hatchSec'], (v) => v.toInt()),
    boxCap: (json['boxCap'] as num?)?.toInt() ?? 30,
    releaseDust: _byGrade(json['releaseDust'], (v) => v.toInt()),
    subRatio: (json['subRatio'] as num?)?.toDouble() ?? 0.5,
    subWeight: {
      if (json['subWeight'] is Map)
        for (final e in (json['subWeight'] as Map).entries)
          e.key as String: (e.value as num).toDouble(),
    },
    stoneChance: (json['stoneChance'] as num?)?.toDouble() ?? 0.5,
    stoneJelly: (json['stoneJelly'] as num?)?.toInt() ?? 20,
    accelerators: [
      if (json['accelerators'] is List)
        for (final a in json['accelerators'] as List)
          FairyAccelDef.fromJson(Map<String, dynamic>.from(a as Map)),
    ],
    gachaJelly: (json['gachaJelly'] as num?)?.toInt() ?? 30,
    gachaWeights: _byGrade(json['gachaWeights'], (v) => v.toDouble()),
    gachaPity: (json['gachaPity'] as num?)?.toInt() ?? 10,
    exchangeDustPerJelly:
        (json['exchangeDustPerJelly'] as num?)?.toDouble() ?? 0,
    exchangeDustDailyCap: (json['exchangeDustDailyCap'] as num?)?.toInt() ?? 0,
    gachaPityGrade: FairyGrade.fromKey(
      json['gachaPityGrade'] as String? ?? 'legendary',
    ),
    drops: FairyDrops.fromJson(
      json['drops'] is Map
          ? Map<String, dynamic>.from(json['drops'] as Map)
          : null,
    ),
    dexMilestones: [
      if (json['dexMilestones'] is List)
        for (final m in json['dexMilestones'] as List)
          FairyDexMilestone.fromJson(Map<String, dynamic>.from(m as Map)),
    ],
  );
}

/// 요정 도감 마일스톤 한 칸 — 요정 가루 · 가속기 · 화석(젤리 없음, 유한 — §2.6).
@immutable
class FairyDexMilestone {
  const FairyDexMilestone({
    required this.count,
    this.dust = 0,
    this.accelerators = const {},
    this.fossil = 0,
  });

  /// 모아야 하는 도감 칸 수.
  final int count;
  final int dust;
  final Map<String, int> accelerators;
  final int fossil;

  int get acceleratorCount => accelerators.values.fold(0, (a, b) => a + b);

  factory FairyDexMilestone.fromJson(Map<String, dynamic> j) =>
      FairyDexMilestone(
        count: (j['count'] as num).toInt(),
        dust: (j['dust'] as num?)?.toInt() ?? 0,
        accelerators: {
          if (j['accelerators'] is Map)
            for (final e in (j['accelerators'] as Map).entries)
              '${e.key}': (e.value as num).toInt(),
        },
        fossil: (j['fossil'] as num?)?.toInt() ?? 0,
      );
}

/// 동행 요정 능력치([FairyConfig.statBonus])를 캐릭터 능력치에 얹는다 — 앱(`_stats`)과 시뮬이 같은 함수.
///
/// **적응형 위협 기준 밖**이다(스킬·종 패시브와 같은 층, §2.8) — 기준에 넣으면 요정을 데려오는 순간
/// 몬스터도 세져 요정을 고르는 의미가 사라진다.
///
/// - 공격·체력·공격속도는 **비율**, 치명 피해는 **가산**, 보스 피해는 **곱**(종 패시브와 같은 이유 — 가산이면
///   강화로 11배까지 자라는 보스 피해에 묽어진다).
/// - 방어는 **"받는 피해 −v"** 로 읽히게 바꾼다([fairyDefenseFor]). 방어력에 절대값을 더하면 초반엔 과하고
///   후반엔 무의미해져, 같은 "+8%" 가 단계마다 다른 뜻이 된다.
/// - 곤충 몫(`petShare`)은 능력치가 아니라 곤충 피해 배율이다 — [fairyPetMult].
CharacterStats applyFairyStats(CharacterStats s, Map<String, double> bonus) {
  if (bonus.isEmpty) return s;
  double v(String k) => bonus[k] ?? 0;
  return CharacterStats(
    attack: s.attack * (1 + v('attack')),
    maxHp: s.maxHp * (1 + v('hp')),
    attackSpeed: s.attackSpeed * (1 + v('attackSpeed')),
    critDamage: s.critDamage + v('critDamage'),
    bossDamage: s.bossDamage * (1 + v('bossDamage')),
    defense: fairyDefenseFor(s.defense, v('defense')),
    rewardMultiplier: s.rewardMultiplier,
    critChance: s.critChance,
    hpRegen: s.hpRegen,
    xpMultiplier: s.xpMultiplier,
    bugFind: s.bugFind,
    materialFind: s.materialFind,
    moveSpeed: s.moveSpeed,
    boostBonus: s.boostBonus,
  );
}

/// 받는 피해를 [reduce] 만큼 줄이는 방어력. 피격 공식이 `위협 × 100 / (100 + 방어)` 라
/// `(100 + 방어) / (1 − reduce) − 100` 이면 어느 단계에서도 정확히 −reduce 다. 80% 에서 자른다.
double fairyDefenseFor(double defense, double reduce) {
  if (reduce <= 0) return defense;
  return (100 + defense) / (1 - reduce.clamp(0.0, 0.8)) - 100;
}

/// 곤충 피해 배율(티타니아 등 `petShare`). 1 = 없음.
double fairyPetMult(Map<String, double> bonus) => 1 + (bonus['petShare'] ?? 0);

/// 요정 스킬을 **지금** 쓸까 — 요정 스킬은 늘 자동이다(요정 칸에는 누르는 버튼이 없다).
///
/// - 회복: 체력이 [healBelow] 아래일 때만(꽉 찬 체력에 쓰면 쿨만 날린다).
/// - 보스 일격: 보스전에서만(일반 몬스터에 쓰면 정작 보스 때 쿨이다).
/// - 버티기(`lastStand`): 쓰지 않는다 — 죽는 순간 저절로 터진다([fairyShouldStand]).
/// - 나머지: 싸우는 중이면 쿨마다.
bool fairySkillShouldCast(
  String effect, {
  required bool inCombat,
  required bool boss,
  required double hpRatio,
  double healBelow = 0.6,
}) {
  if (!inCombat) return false;
  return switch (effect) {
    'heal' => hpRatio < healBelow,
    'bossBurst' => boss,
    'lastStand' => false,
    _ => true,
  };
}

/// 무료 획득(fairies.json → drops). 온라인 처치만 — 방치 정산에는 없다(스킬 조각과 같다).
@immutable
class FairyDrops {
  const FairyDrops({
    this.bossFirstEggGradeByTier = const [],
    this.bossFirstStones = 0,
    this.eliteEggChance = 0,
    this.eliteEggWeights = const {},
    this.eliteStoneChance = 0,
    this.eliteAccelChance = 0,
    this.eliteAccelId,
  });

  /// 난이도별 보스 **첫 처치** 알 등급(확정). 난이도가 목록보다 크면 마지막 값.
  final List<FairyGrade> bossFirstEggGradeByTier;

  /// 보스 첫 처치 때 주는 무작위 속성석 수.
  final int bossFirstStones;

  final double eliteEggChance;

  /// 정예 알 등급 가중치. ⚠️ 뽑기보다 반드시 나빠야 한다(§2.6 — 돈을 내면 확률이 좋아져야 상품이다).
  final Map<FairyGrade, double> eliteEggWeights;
  final double eliteStoneChance;
  final double eliteAccelChance;
  final String? eliteAccelId;

  FairyGrade? bossFirstEggGrade(int tier) => bossFirstEggGradeByTier.isEmpty
      ? null
      : bossFirstEggGradeByTier[tier.clamp(
          0,
          bossFirstEggGradeByTier.length - 1,
        )];

  /// 정예 알 등급을 굴린다(가중치가 비었으면 null).
  FairyGrade? rollEliteEgg(math.Random rng) {
    final total = eliteEggWeights.values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return null;
    var pick = rng.nextDouble() * total;
    FairyGrade? last;
    for (final e in eliteEggWeights.entries) {
      last = e.key;
      pick -= e.value;
      if (pick < 0) return e.key;
    }
    return last;
  }

  factory FairyDrops.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const FairyDrops();
    return FairyDrops(
      bossFirstEggGradeByTier: [
        for (final g in (json['bossFirstEggGradeByTier'] as List? ?? const []))
          FairyGrade.fromKey(g as String),
      ],
      bossFirstStones: (json['bossFirstStones'] as num?)?.toInt() ?? 0,
      eliteEggChance: (json['eliteEggChance'] as num?)?.toDouble() ?? 0,
      eliteEggWeights: _byGrade(json['eliteEggWeights'], (v) => v.toDouble()),
      eliteStoneChance: (json['eliteStoneChance'] as num?)?.toDouble() ?? 0,
      eliteAccelChance: (json['eliteAccelChance'] as num?)?.toDouble() ?? 0,
      eliteAccelId: json['eliteAccelId'] as String?,
    );
  }
}

/// 요정 스킬 효과를 **상대에게** 보여 줄지(공격형) — 아니면 우리 캐릭터에게(회복·방어·버프형).
/// 화면 연출용(앱)이다. 새 스킬 효과를 만들면 여기에 넣는다.
bool fairySkillTargetsEnemy(String effect) =>
    const {'burstDamage', 'bossBurst', 'critWindow'}.contains(effect);
