/// 게임 개체·데이터에서 쓰는 열거형과 JSON 키 매핑.
///
/// 모든 enum 은 안정적인 문자열 `key` 를 가지며 JSON 직렬화에 이 키를 쓴다
/// (enum index 저장 금지 — 순서 바뀌면 세이브 깨짐).
library;

/// 종 등급 5단계 (§2.1). 일반/고급/희귀/영웅/전설.
enum Grade {
  common('common'),
  uncommon('uncommon'),
  rare('rare'),
  epic('epic'),
  legendary('legendary');

  const Grade(this.key);
  final String key;

  static Grade fromKey(String key) => values.firstWhere(
    (e) => e.key == key,
    orElse: () => throw ArgumentError('Unknown Grade key: $key'),
  );

  /// 모르는 키면 null. **세이브에서 온 키**를 읽을 때 쓴다 — 신버전이 값을
  /// 추가해도 구버전 앱이 세이브를 통째로 못 읽는 일이 없어야 한다.
  /// (애셋 JSON 은 [fromKey] 로 읽어 오타를 로딩에서 잡는다.)
  static Grade? fromKeyOrNull(String key) {
    for (final e in values) {
      if (e.key == key) return e;
    }
    return null;
  }
}

/// 주특기 / 기술 종류 (§2.3). 치기(strike)/집기(grip)/던지기(toss).
/// 상성: 치기 > 집기 > 던지기 > 치기.
enum Specialty {
  strike('strike'), // 치기
  grip('grip'), // 집기
  toss('toss'); // 던지기

  const Specialty(this.key);
  final String key;

  static Specialty fromKey(String key) => values.firstWhere(
    (e) => e.key == key,
    orElse: () => throw ArgumentError('Unknown Specialty key: $key'),
  );

  /// 모르는 키면 null. **세이브에서 온 키**를 읽을 때 쓴다 — 신버전이 값을
  /// 추가해도 구버전 앱이 세이브를 통째로 못 읽는 일이 없어야 한다.
  /// (애셋 JSON 은 [fromKey] 로 읽어 오타를 로딩에서 잡는다.)
  static Specialty? fromKeyOrNull(String key) {
    for (final e in values) {
      if (e.key == key) return e;
    }
    return null;
  }

  /// this 가 [other] 를 상성으로 이기면 true.
  bool beats(Specialty other) => switch (this) {
    Specialty.strike => other == Specialty.grip,
    Specialty.grip => other == Specialty.toss,
    Specialty.toss => other == Specialty.strike,
  };
}

/// 기질 (§2.1). 전투 AI 기술선택 성향. 호전적/신중/교활/우직/변덕.
enum Temperament {
  aggressive('aggressive'), // 호전적
  cautious('cautious'), // 신중
  cunning('cunning'), // 교활
  steadfast('steadfast'), // 우직
  fickle('fickle'); // 변덕

  const Temperament(this.key);
  final String key;

  static Temperament fromKey(String key) => values.firstWhere(
    (e) => e.key == key,
    orElse: () => throw ArgumentError('Unknown Temperament key: $key'),
  );

  /// 모르는 키면 null. **세이브에서 온 키**를 읽을 때 쓴다 — 신버전이 값을
  /// 추가해도 구버전 앱이 세이브를 통째로 못 읽는 일이 없어야 한다.
  /// (애셋 JSON 은 [fromKey] 로 읽어 오타를 로딩에서 잡는다.)
  static Temperament? fromKeyOrNull(String key) {
    for (final e in values) {
      if (e.key == key) return e;
    }
    return null;
  }
}

/// 혈통 특성 (§2.5) — **짝짓기로 태어난 개체만** 가질 수 있다.
///
/// 왜 있는가: 짝짓기 자식이 야생 개체와 사실상 구분되지 않아 짝짓기를 돌릴
/// 이유가 없었다(사이즈·포텐셜만 부모 기준이고 오행·기질은 재추첨이었다).
/// 특성은 **대를 이어 굳혀가는 축**이다 — 부모 둘이 같은 특성이면 자식에게
/// 확정 상속되므로, 원하는 계통을 몇 세대에 걸쳐 만들어낼 수 있다.
///
/// ⚠️ 효과는 **애완펫 기여(공격/체력)** 에만 실린다. PvP 전투 스탯에 실으면
/// 세이브 편집으로 특성을 찍어 랭킹을 오염시킬 수 있다(기기 권위 롤 문제).
/// 계수는 밸런스라 `pets.json → traitBonus`.
enum BugTrait {
  /// 특성 없음 — 야생 개체는 항상 이 값이다.
  none('none'),

  /// 맹렬 — 공격 기여 상승.
  fierce('fierce'),

  /// 강인 — 체력 기여 상승.
  sturdy('sturdy'),

  /// 강건 — 공격·체력 소폭 동시 상승.
  vital('vital'),

  /// 고귀 — 공격·체력 큰 폭 동시 상승(가장 드물다).
  noble('noble');

  const BugTrait(this.key);
  final String key;

  bool get isNone => this == BugTrait.none;

  /// 모르는 키는 [none] 으로 떨어뜨린다 — 구버전 앱이 신규 특성을 만나도
  /// 세이브 파싱이 통째로 죽지 않아야 한다.
  static BugTrait fromKey(String key) =>
      values.firstWhere((e) => e.key == key, orElse: () => BugTrait.none);
}

/// 오행 속성 (전투 상성). 개체마다 랜덤 부여.
/// 상극(克): 水火 · 火金 · 金木 · 木土 · 土水.  상생(生): 木火 · 火土 · 土金 · 金水 · 水木.
enum Element {
  fire('fire'), // 화
  water('water'), // 수
  wood('wood'), // 목
  metal('metal'), // 금
  earth('earth'); // 토

  const Element(this.key);
  final String key;

  static Element fromKey(String key) => values.firstWhere(
    (e) => e.key == key,
    orElse: () => throw ArgumentError('Unknown Element key: $key'),
  );

  /// 모르는 키면 null. **세이브에서 온 키**를 읽을 때 쓴다 — 신버전이 값을
  /// 추가해도 구버전 앱이 세이브를 통째로 못 읽는 일이 없어야 한다.
  /// (애셋 JSON 은 [fromKey] 로 읽어 오타를 로딩에서 잡는다.)
  static Element? fromKeyOrNull(String key) {
    for (final e in values) {
      if (e.key == key) return e;
    }
    return null;
  }

  /// this 가 [other] 를 상극(克)하면 true.
  bool restrains(Element other) => switch (this) {
    Element.water => other == Element.fire, // 水克火
    Element.fire => other == Element.metal, // 火克金
    Element.metal => other == Element.wood, // 金克木
    Element.wood => other == Element.earth, // 木克土
    Element.earth => other == Element.water, // 土克水
  };

  /// this 가 [other] 를 상생(生)하면 true.
  bool generates(Element other) => switch (this) {
    Element.wood => other == Element.fire, // 木生火
    Element.fire => other == Element.earth, // 火生土
    Element.earth => other == Element.metal, // 土生金
    Element.metal => other == Element.water, // 金生水
    Element.water => other == Element.wood, // 水生木
  };
}

/// 성별 (§2.1, 브리딩 조건).
enum Sex {
  male('male'),
  female('female');

  const Sex(this.key);
  final String key;

  static Sex fromKey(String key) => values.firstWhere(
    (e) => e.key == key,
    orElse: () => throw ArgumentError('Unknown Sex key: $key'),
  );

  /// 모르는 키면 null. **세이브에서 온 키**를 읽을 때 쓴다 — 신버전이 값을
  /// 추가해도 구버전 앱이 세이브를 통째로 못 읽는 일이 없어야 한다.
  /// (애셋 JSON 은 [fromKey] 로 읽어 오타를 로딩에서 잡는다.)
  static Sex? fromKeyOrNull(String key) {
    for (final e in values) {
      if (e.key == key) return e;
    }
    return null;
  }
}

/// 곤충 생애주기 단계 (§2.5). 알 → 유충 → 번데기 → 성충.
enum LifeStage {
  egg('egg'),
  larva('larva'),
  pupa('pupa'),
  adult('adult');

  const LifeStage(this.key);
  final String key;

  /// 다음 단계 (성충은 그대로).
  LifeStage get next => switch (this) {
    LifeStage.egg => LifeStage.larva,
    LifeStage.larva => LifeStage.pupa,
    LifeStage.pupa => LifeStage.adult,
    LifeStage.adult => LifeStage.adult,
  };

  bool get isFinal => this == LifeStage.adult;

  static LifeStage fromKey(String key) =>
      values.firstWhere((e) => e.key == key, orElse: () => LifeStage.adult);
}

/// 미션(퀘스트) 종류. 자동 진행 후 완료 시 클릭 수집.
enum MissionType {
  killMonsters('killMonsters'), // 일반 몬스터 처치
  killBosses('killBosses'), // 보스 처치
  buyUpgrades('buyUpgrades'), // 능력치 강화 구매
  reachStage('reachStage'); // 스테이지 도달(마일스톤)

  const MissionType(this.key);
  final String key;

  static MissionType? fromKey(String key) {
    for (final e in values) {
      if (e.key == key) return e;
    }
    return null;
  }
}

/// 부위 강화 대상 부위 (§2.2). 뿔·큰턱→ATK / 표피→DEF / 날개→SPD·회피 / 체격→HP.
enum BugPart {
  hornJaw('hornJaw'), // 뿔·큰턱
  cuticle('cuticle'), // 표피
  wing('wing'), // 날개
  build('build'); // 체격

  const BugPart(this.key);
  final String key;

  static BugPart fromKey(String key) => values.firstWhere(
    (e) => e.key == key,
    orElse: () => throw ArgumentError('Unknown BugPart key: $key'),
  );

  /// 모르는 키면 null. **세이브에서 온 키**를 읽을 때 쓴다 — 신버전이 값을
  /// 추가해도 구버전 앱이 세이브를 통째로 못 읽는 일이 없어야 한다.
  /// (애셋 JSON 은 [fromKey] 로 읽어 오타를 로딩에서 잡는다.)
  static BugPart? fromKeyOrNull(String key) {
    for (final e in values) {
      if (e.key == key) return e;
    }
    return null;
  }
}

/// 채집 부산물 재료 종류 (§2.2). 키틴조각/미네랄/수액결정/곤충젤리.
enum MaterialKind {
  chitin('chitin'), // 키틴조각
  mineral('mineral'), // 미네랄
  sap('sap'), // 수액결정
  jelly('jelly'), // 곤충젤리
  /// 화석 조각 — **제련 전용**. 1개 = 망치질 1번 = 장비 1개.
  ///
  /// 기존 재료와 통을 나눈 이유: 강화·연마와 소비처가 겹치면 어느 쪽도
  /// 조절이 안 된다. 제련은 무한히 도는 축이라 자기 재화를 가져야 한다.
  /// 처치당 **잡는 데 걸린 시간에 비례**해 쌓인다(스테이지를 보지 않는다).
  fossil('fossil');

  const MaterialKind(this.key);
  final String key;

  static MaterialKind fromKey(String key) => values.firstWhere(
    (e) => e.key == key,
    orElse: () => throw ArgumentError('Unknown MaterialKind key: $key'),
  );

  /// 모르는 키면 null. **세이브에서 온 키**를 읽을 때 쓴다 — 신버전이 값을
  /// 추가해도 구버전 앱이 세이브를 통째로 못 읽는 일이 없어야 한다.
  /// (애셋 JSON 은 [fromKey] 로 읽어 오타를 로딩에서 잡는다.)
  static MaterialKind? fromKeyOrNull(String key) {
    for (final e in values) {
      if (e.key == key) return e;
    }
    return null;
  }
}

/// 이색 개체(§2.1, 2026-08-31 신설) — 아주 낮은 확률로 나오는 **색이 다른**
/// 개체. 순수 외형이다(스탯 없음).
///
/// 스탯을 붙이지 않는 이유 둘:
/// - 적응형 체력(§7) 기준 안팎 문제를 아예 만들지 않는다.
/// - 곤충 롤은 기기 권위라 위조를 못 막는데(§2.5 특성과 같은 구멍),
///   외형뿐이면 위조해 봐야 자랑거리 하나다 — 랭킹이 오염되지 않는다.
enum BugVariant {
  none('none'),

  /// 무지개 — 최상급 이색.
  rainbow('rainbow'),

  /// 알비노(백화).
  albino('albino');

  const BugVariant(this.key);
  final String key;

  /// 모르는 키는 none — 신버전이 이색을 추가해도 구버전 앱이 세이브를
  /// 통째로 못 읽으면 안 된다(기질·성별과 같은 방침).
  static BugVariant fromKey(String k) =>
      values.firstWhere((e) => e.key == k, orElse: () => none);
}
