import 'dart:math';

import 'package:meta/meta.dart';

import 'enums.dart';
import 'game_rules.dart';
import 'part_levels.dart';
import 'size_roll.dart';
import 'species.dart';
import 'stats.dart';

/// 채집·브리딩으로 얻은 **개체**. 종(Species) × 개체 변수 (§2.1).
///
/// 종 정보는 [speciesId] 로만 참조한다(모델은 종 테이블을 들고 있지 않음).
/// 유효 스탯 계산 등 종이 필요한 연산은 [Species] 를 인자로 받는다.
@immutable
class IndividualBug {
  const IndividualBug({
    required this.id,
    required this.speciesId,
    required this.sizeMm,
    required this.potential,
    required this.temperament,
    required this.sex,
    this.enhancement = PartLevels.zero,
    this.stage = LifeStage.adult,
    this.stageSince,
    this.level = 1,
    this.breakthroughTier = 0,
    this.breakthroughEndsAt,
    this.trait = BugTrait.none,
    this.variant = BugVariant.none,
    Element? element,
  }) : _element = element;

  /// id 기반 안정 배정(기존 개체·미지정 시). 롤 시엔 랜덤 주입.
  static Element _elementFor(String id) =>
      Element.values[id.hashCode.abs() % Element.values.length];

  /// 개체 고유 id (앱 레이어에서 생성해 주입).
  final String id;

  /// 소속 종 id.
  final String speciesId;

  /// 롤된 사이즈(mm).
  final double sizeMm;

  /// 포텐셜 성 (1~5). 강화 상한 = potential × 10.
  final int potential;

  /// 기질 (전투 AI 성향).
  final Temperament temperament;

  /// 성별.
  final Sex sex;

  /// 부위 강화 레벨.
  final PartLevels enhancement;

  /// 생애주기 단계 (§2.5). 새로 잡으면 알로 시작.
  final LifeStage stage;

  /// 현재 단계 진입 UTC 시각 (진화 타이머 기준). null=아주 오래전(즉시 진화 가능).
  final DateTime? stageSince;

  /// 성충 수련 레벨(1~). 펫 보너스에 곱해진다.
  final int level;

  /// 돌파 티어(0~). 티어가 높을수록 레벨 상한이 커진다.
  final int breakthroughTier;

  /// 돌파 진행 종료 UTC 시각(진행 중이면 non-null). 도달 후 수령하면 티어 상승.
  final DateTime? breakthroughEndsAt;

  /// 혈통 특성 (§2.5) — 짝짓기 자식만 가진다. 야생 롤은 항상 [BugTrait.none].
  final BugTrait trait;

  /// 이색(무지개·알비노) — 순수 외형. 스탯을 붙이지 않는 이유는 [BugVariant].
  final BugVariant variant;

  final Element? _element;

  /// 오행 속성(전투 상성). 개체마다 랜덤(미지정 개체는 id 기반 안정 배정).
  Element get element => _element ?? _elementFor(id);

  /// 강화 상한 레벨 (§2.1).
  int get maxLevel => potential * kLevelsPerPotential;

  /// 이 개체가 **정상 플레이로 만들어질 수 있는 값인지** 검사한다.
  ///
  /// 위반이 없으면 null, 있으면 짧은 사유 코드(로그·에러 응답용).
  ///
  /// 서버 PvP 편성 검증이 쓴다 — 드롭 롤이 기기 권위라 세이브 편집으로
  /// 5성 만렙 전설을 위조할 수 있는데, 소유 여부만 보면 그 곤충으로 트로피를
  /// 쌓아 **랭킹이 오염**된다. 위조 자체는 못 막아도 *효과*는 여기서 막는다.
  ///
  /// ⚠️ 생성자 `assert` 는 릴리스에서 **꺼진다** — 서버 컨테이너는 릴리스로
  /// 돌므로 assert 를 믿으면 안 되고, 반드시 이 함수로 검사해야 한다.
  ///
  /// [levelCap] 은 **이 개체의 돌파 티어**에 해당하는 수련 상한
  /// (`PetConfig.levelCap(breakthroughTier)`), [maxBreakthroughTier] 는
  /// 설정의 최대 티어. core_models 는 core_run 을 모르므로 값으로 받는다.
  String? integrityError(
    Species species, {
    required int levelCap,
    required int maxBreakthroughTier,
  }) {
    // ⚠️ NaN 은 모든 비교가 false 라 범위 검사를 **통과해 버린다** — 먼저 거른다.
    if (!sizeMm.isFinite) return 'size_not_finite';
    // 롤·브리딩 모두 종 범위로 clamp 하므로 범위 밖 = 위조다.
    // 부동소수 저장/파싱 오차만 허용한다.
    if (sizeMm < species.sizeMinMm - 0.001 ||
        sizeMm > species.sizeMaxMm + 0.001) {
      return 'size_out_of_range';
    }
    if (potential < kPotentialMin || potential > kPotentialMax) {
      return 'potential_out_of_range';
    }
    for (final part in BugPart.values) {
      if (enhancement.levelOf(part) < 0) return 'enhance_negative';
    }
    if (enhancement.total > maxLevel) return 'enhance_over_cap';
    if (breakthroughTier < 0 || breakthroughTier > maxBreakthroughTier) {
      return 'breakthrough_out_of_range';
    }
    if (level < 1 || level > levelCap) return 'level_over_cap';
    return null;
  }

  /// 이 개체의 사이즈에 대응하는 스탯 배율 (종 사이즈 범위 기준).
  double statMultiplier(Species species) =>
      sizeToStatMultiplier(sizeMm, species.sizeMinMm, species.sizeMaxMm);

  /// 사이즈 배율만 적용한 유효 기본 스탯 (강화 미적용).
  Stats baseEffectiveStats(Species species) =>
      species.baseStats.scaled(statMultiplier(species));

  /// 채집/조우 시 개체 하나를 롤한다.
  ///
  /// - 사이즈: 종 범위 내 정규분포 (§2.1)
  /// - 기질/성별: 미지정 시 균등 롤 (기질 5종 균등, 성별 50/50)
  /// - [potential]: 출현 테이블이 정하는 값이라 **필수 주입** (밸런스를 모델에 박지 않음)
  ///
  /// 결정론: 같은 [rng] 상태 + 같은 인자 → 같은 개체.
  factory IndividualBug.roll({
    required String id,
    required Species species,
    required Random rng,
    required int potential,
    Temperament? temperament,
    Sex? sex,
    double variantChance = 0,
  }) {
    assert(
      potential >= kPotentialMin && potential <= kPotentialMax,
      'potential must be in [$kPotentialMin, $kPotentialMax], got $potential',
    );
    final size = rollSizeMm(rng, species.sizeMinMm, species.sizeMaxMm);
    final temp =
        temperament ??
        Temperament.values[rng.nextInt(Temperament.values.length)];
    final resolvedSex = sex ?? (rng.nextBool() ? Sex.male : Sex.female);
    final element = Element.values[rng.nextInt(Element.values.length)];
    // 이색 롤은 **맨 마지막** — 앞의 rng 소비 순서를 바꾸면 같은 seed 의
    // 기존 롤 결과가 달라진다(breed 와 같은 규칙).
    return IndividualBug(
      id: id,
      speciesId: species.id,
      sizeMm: size,
      potential: potential,
      temperament: temp,
      sex: resolvedSex,
      element: element,
      variant: _rollVariant(rng, variantChance),
    );
  }

  /// 이색 롤. 걸리면 무지개/알비노를 절반씩.
  static BugVariant _rollVariant(Random rng, double chance) {
    if (chance <= 0 || rng.nextDouble() >= chance) return BugVariant.none;
    return rng.nextBool() ? BugVariant.rainbow : BugVariant.albino;
  }

  /// 브리딩(§2.5)으로 자식 개체(**알**)를 롤한다.
  ///
  /// - 사이즈: **부모 평균 ± 변이**(정규분포), [mutationChance] 확률로 돌연변이 보너스,
  ///   최종적으로 종 범위로 clamp.
  /// - 포텐셜: 부모 중 **높은 쪽**을 기준으로 상속 — [potUpChance] 상승(+1) /
  ///   [potDownChance] 하락(−1) / 나머지 유지. [kPotentialMin]~[kPotentialMax] clamp.
  /// - **오행·기질: 부모에게서 상속**([elementInheritChance]/[temperamentInheritChance]).
  /// - **혈통 특성**: 부모 특성을 상속하거나 새로 얻는다([traitWeights] 참조).
  /// - 성별: 균등 랜덤. 생애주기: **알**.
  ///
  /// ## 오행·기질을 상속시키는 이유 (2026-08-15 개편)
  /// 예전엔 둘 다 **균등 재추첨**이라, 짝짓기 자식이 야생 드롭과 구분되지 않았다.
  /// 오행 상생 순서가 편성 전략의 핵심(§2.3)인데 원하는 속성을 노릴 수단이
  /// 없어서, 짝짓기를 돌릴 이유 자체가 없었다. 부모에게서 물려받게 하면
  /// **같은 오행 부모를 모아 계통을 만든다**는 목표가 생긴다.
  ///
  /// 계수는 밸런스라 **인자로 주입**(모델에 상수 박지 않음). 결정론: 같은 [rng]+인자 → 같은 자식.
  ///
  /// ⚠️ rng 소비 순서를 바꾸면 **같은 seed 의 기존 브리딩 슬롯 결과가 달라진다**.
  /// 새 롤은 반드시 기존 롤 **뒤에** 붙인다(사이즈 → 포텐셜 → 오행 → 기질 → 특성 → 성별).
  factory IndividualBug.breed({
    required String id,
    required Species species,
    required Random rng,
    required double parentAvgSizeMm,
    required int motherPotential,
    required int fatherPotential,
    required double sizeVariancePct,
    required double mutationChance,
    required double mutationBonusPct,
    required double potUpChance,
    required double potDownChance,
    Element? motherElement,
    Element? fatherElement,
    Temperament? motherTemperament,
    Temperament? fatherTemperament,
    BugTrait motherTrait = BugTrait.none,
    BugTrait fatherTrait = BugTrait.none,
    double elementInheritChance = 0,
    double temperamentInheritChance = 0,
    double traitInheritChance = 0,
    double traitNewChance = 0,
    Map<BugTrait, double> traitWeights = const {},
    double variantChance = 0,
  }) {
    var size = parentAvgSizeMm * (1 + nextGaussian(rng) * sizeVariancePct);
    if (rng.nextDouble() < mutationChance) size *= (1 + mutationBonusPct);
    size = size.clamp(species.sizeMinMm, species.sizeMaxMm).toDouble();

    final basePot = motherPotential > fatherPotential
        ? motherPotential
        : fatherPotential;
    final r = rng.nextDouble();
    var pot = basePot;
    if (r < potUpChance) {
      pot = basePot + 1;
    } else if (r < potUpChance + potDownChance) {
      pot = basePot - 1;
    }
    pot = pot.clamp(kPotentialMin, kPotentialMax);

    // 부모 값이 하나라도 없으면(구버전 슬롯) 상속을 건너뛰고 예전처럼 랜덤 —
    // 이미 돌고 있던 짝짓기가 수령 시점에 터지지 않게 한다.
    final element = _inherit<Element>(
      rng,
      motherElement,
      fatherElement,
      elementInheritChance,
      Element.values,
    );
    final temperament = _inherit<Temperament>(
      rng,
      motherTemperament,
      fatherTemperament,
      temperamentInheritChance,
      Temperament.values,
    );
    final trait = _rollTrait(
      rng,
      motherTrait,
      fatherTrait,
      traitInheritChance,
      traitNewChance,
      traitWeights,
    );

    final sex = rng.nextBool() ? Sex.male : Sex.female;
    // ⚠️ 이색 롤은 기존 롤(사이즈→포텐셜→오행→기질→특성→성별) **뒤에** 붙는다 —
    // 순서를 바꾸면 돌고 있던 슬롯의 결과가 달라진다.
    final variant = _rollVariant(rng, variantChance);
    return IndividualBug(
      id: id,
      speciesId: species.id,
      sizeMm: size,
      potential: pot,
      temperament: temperament,
      sex: sex,
      element: element,
      trait: trait,
      stage: LifeStage.egg,
      variant: variant,
    );
  }

  /// 부모 둘 중 하나에게서 물려받거나([chance]), 실패하면 [all] 중 균등 랜덤.
  ///
  /// **부모가 같은 값이면 그 값이 확정**이다(둘 중 무엇을 고르든 같으므로).
  /// 이게 계통 육성의 핵심 — 같은 오행 부모를 모으면 자식도 그 오행이 된다.
  static T _inherit<T>(
    Random rng,
    T? mother,
    T? father,
    double chance,
    List<T> all,
  ) {
    // rng 소비 횟수를 분기마다 다르게 하면 결정론이 깨지기 쉬우므로
    // **항상 두 번** 뽑고(상속 판정 + 선택) 쓰지 않는 쪽만 버린다.
    final roll = rng.nextDouble();
    final pick = rng.nextDouble();
    if (mother != null && father != null && roll < chance) {
      return pick < 0.5 ? mother : father;
    }
    return all[(pick * all.length).floor().clamp(0, all.length - 1)];
  }

  /// 혈통 특성 롤.
  ///
  /// 1. 부모 중 특성 보유자가 있으면 [inheritChance] 로 물려받는다
  ///    (둘 다 있고 같으면 그 특성 확정, 다르면 50/50).
  /// 2. 상속에 실패했고 부모가 특성이 없으면 [newChance] 로 새 특성이 열린다
  ///    — 1세대에서도 특성이 나올 수 있어야 시작할 동기가 생긴다.
  /// 3. 그 외에는 [BugTrait.none].
  static BugTrait _rollTrait(
    Random rng,
    BugTrait mother,
    BugTrait father,
    double inheritChance,
    double newChance,
    Map<BugTrait, double> weights,
  ) {
    final roll = rng.nextDouble();
    final pick = rng.nextDouble();
    final parents = [if (!mother.isNone) mother, if (!father.isNone) father];
    if (parents.isNotEmpty) {
      if (roll >= inheritChance) return BugTrait.none;
      return parents[(pick * parents.length).floor().clamp(
        0,
        parents.length - 1,
      )];
    }
    if (roll >= newChance) return BugTrait.none;
    return _weightedTrait(pick, weights);
  }

  /// [t] (0~1) 위치로 가중 추첨. 가중치가 비어 있으면 특성 없음.
  static BugTrait _weightedTrait(double t, Map<BugTrait, double> weights) {
    var total = 0.0;
    for (final e in weights.entries) {
      if (e.key.isNone || e.value <= 0) continue;
      total += e.value;
    }
    if (total <= 0) return BugTrait.none;
    var acc = 0.0;
    final target = t * total;
    for (final e in weights.entries) {
      if (e.key.isNone || e.value <= 0) continue;
      acc += e.value;
      if (target < acc) return e.key;
    }
    return BugTrait.none;
  }

  IndividualBug copyWith({
    String? id,
    String? speciesId,
    double? sizeMm,
    int? potential,
    Temperament? temperament,
    Sex? sex,
    PartLevels? enhancement,
    LifeStage? stage,
    DateTime? stageSince,
    int? level,
    int? breakthroughTier,
    DateTime? breakthroughEndsAt,
    bool clearBreakthrough = false,
    BugTrait? trait,
    BugVariant? variant,
    Element? element,
  }) => IndividualBug(
    id: id ?? this.id,
    speciesId: speciesId ?? this.speciesId,
    sizeMm: sizeMm ?? this.sizeMm,
    potential: potential ?? this.potential,
    temperament: temperament ?? this.temperament,
    sex: sex ?? this.sex,
    enhancement: enhancement ?? this.enhancement,
    stage: stage ?? this.stage,
    stageSince: stageSince ?? this.stageSince,
    level: level ?? this.level,
    breakthroughTier: breakthroughTier ?? this.breakthroughTier,
    breakthroughEndsAt: clearBreakthrough
        ? null
        : (breakthroughEndsAt ?? this.breakthroughEndsAt),
    trait: trait ?? this.trait,
    variant: variant ?? this.variant,
    element: element ?? this.element,
  );

  factory IndividualBug.fromJson(Map<String, dynamic> json) => IndividualBug(
    id: json['id'] as String,
    speciesId: json['speciesId'] as String,
    sizeMm: (json['sizeMm'] as num).toDouble(),
    potential: (json['potential'] as num).toInt(),
    // 모르는 기질·성별·오행 키는 **던지지 않고 기본값으로 떨어뜨린다** —
    // 신버전이 값을 추가해도 구버전 앱이 세이브를 통째로 못 읽으면 안 된다
    // (BugTrait·LifeStage 가 이미 쓰던 방식을 나머지에도 맞췄다).
    temperament:
        Temperament.fromKeyOrNull(json['temperament'] as String? ?? '') ??
        Temperament.steadfast,
    sex: Sex.fromKeyOrNull(json['sex'] as String? ?? '') ?? Sex.male,
    enhancement: json['enhancement'] == null
        ? PartLevels.zero
        : PartLevels.fromJson(json['enhancement'] as Map<String, dynamic>),
    stage: json['stage'] == null
        ? LifeStage.adult
        : LifeStage.fromKey(json['stage'] as String),
    stageSince: json['stageSince'] == null
        ? null
        : DateTime.parse(json['stageSince'] as String).toUtc(),
    level: (json['level'] as num?)?.toInt() ?? 1,
    breakthroughTier: (json['breakthroughTier'] as num?)?.toInt() ?? 0,
    breakthroughEndsAt: json['breakthroughEndsAt'] == null
        ? null
        : DateTime.parse(json['breakthroughEndsAt'] as String).toUtc(),
    // 모르는 특성 키는 none 으로 떨어진다(BugTrait.fromKey) — 신규 특성이
    // 추가돼도 구버전 앱이 세이브를 통째로 못 읽는 일이 없어야 한다.
    trait: json['trait'] == null
        ? BugTrait.none
        : BugTrait.fromKey(json['trait'] as String),
    // 이색도 모르는 키는 none(구버전 호환). 없는 키 = 평범한 개체(대다수).
    variant: json['variant'] == null
        ? BugVariant.none
        : BugVariant.fromKey(json['variant'] as String),
    element: json['element'] == null
        ? null
        : Element.fromKeyOrNull(json['element'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'speciesId': speciesId,
    'sizeMm': sizeMm,
    'potential': potential,
    'temperament': temperament.key,
    'sex': sex.key,
    'enhancement': enhancement.toJson(),
    'stage': stage.key,
    if (stageSince != null) 'stageSince': stageSince!.toUtc().toIso8601String(),
    'level': level,
    'breakthroughTier': breakthroughTier,
    if (breakthroughEndsAt != null)
      'breakthroughEndsAt': breakthroughEndsAt!.toUtc().toIso8601String(),
    // 특성 없는 개체(야생 = 대다수)는 키를 아예 싣지 않는다 — 세이브 크기가
    // 곧 업로드 비용이라, 곤충 100마리 × 상시 필드는 그냥 낭비다(§3).
    if (trait != BugTrait.none) 'trait': trait.key,
    // 이색 아닌 개체(대다수)는 키를 싣지 않는다 — trait 와 같은 이유(§3).
    if (variant != BugVariant.none) 'variant': variant.key,
    'element': element.key,
  };

  @override
  bool operator ==(Object other) => other is IndividualBug && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'IndividualBug($id, $speciesId, ${sizeMm.toStringAsFixed(1)}mm, '
      'P$potential, ${temperament.key}, ${sex.key})';
}
