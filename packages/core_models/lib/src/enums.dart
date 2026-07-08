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
}

/// 채집 부산물 재료 종류 (§2.2). 키틴조각/미네랄/수액결정/곤충젤리.
enum MaterialKind {
  chitin('chitin'), // 키틴조각
  mineral('mineral'), // 미네랄
  sap('sap'), // 수액결정
  jelly('jelly'); // 곤충젤리

  const MaterialKind(this.key);
  final String key;

  static MaterialKind fromKey(String key) => values.firstWhere(
    (e) => e.key == key,
    orElse: () => throw ArgumentError('Unknown MaterialKind key: $key'),
  );
}
