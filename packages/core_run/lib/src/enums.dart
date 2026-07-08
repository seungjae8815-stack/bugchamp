/// v2 런 엔진 열거형. JSON 직렬화는 안정 문자열 key 사용.
library;

/// 서식지 종류 (측면 파괴 오브젝트).
enum HabitatKind {
  tree('tree'),
  flower('flower'),
  rock('rock'),
  stump('stump'),
  mushroom('mushroom');

  const HabitatKind(this.key);
  final String key;

  static HabitatKind fromKey(String key) => values.firstWhere(
    (e) => e.key == key,
    orElse: () => throw ArgumentError('Unknown HabitatKind key: $key'),
  );
}

/// 캐릭터 능력치 업그레이드 종류 (테마명은 UI/ARB 에서).
/// ⚔전투 · 🛡생존 · 💰보상 · 🏃편의
enum UpgradeKind {
  // ⚔ 전투
  attack('attack'), // 채집력
  attackSpeed('attackSpeed'), // 손놀림
  crit('crit'), // 급소 노리기 (치명타 확률)
  critDamage('critDamage'), // 강타 (치명타 배수)
  bossDamage('bossDamage'), // 투지 (보스 추가 데미지)
  // 🛡 생존
  maxHp('maxHp'), // 근성 (최대 체력)
  defense('defense'), // 맷집 (방어력)
  regen('regen'), // 회복력 (체력 재생)
  // 💰 보상·수집
  reward('reward'), // 판매 수완 (골드 배율)
  xp('xp'), // 채집 지식 (경험치)
  bugFind('bugFind'), // 곤충 감각 (곤충 조우율)
  materialFind('materialFind'), // 꼼꼼한 손질 (재료 획득)
  // 🏃 진행·편의
  moveSpeed('moveSpeed'), // 발걸음 (이동속도)
  boost('boost'), // 집중력 (부스트 강화)
  bugBuff('bugBuff'); // 도감 통달 (곤충 버프 증폭)

  const UpgradeKind(this.key);
  final String key;

  static UpgradeKind fromKey(String key) => values.firstWhere(
    (e) => e.key == key,
    orElse: () => throw ArgumentError('Unknown UpgradeKind key: $key'),
  );
}

/// 광고 시청으로 일정 시간 활성화되는 일시 버프 종류.
/// 효과 계수·지속시간은 코드가 아니라 assets/data/buffs.json 에 있다(§6).
/// 버프는 전투 시드 로직이 아니라 유효 스탯/보상 **배율에만** 곱해지므로
/// core_battle 의 결정론(§2.3)에는 영향이 없다.
enum BuffKind {
  goldRush('goldRush'), // 황금 러시 — 골드 획득 배율
  xpBoost('xpBoost'), // 성장 가속 — 경험치 배율
  frenzy('frenzy'), // 광폭화 — 공격력/공격속도
  gatherer('gatherer'), // 채집가의 손길 — 재료 획득 배율
  luckyWind('luckyWind'); // 행운의 바람 — 곤충 발견율 배율

  const BuffKind(this.key);
  final String key;

  /// 알 수 없는 key 는 null (미래 버전 세이브가 새 버프를 담아도 안전하게 무시).
  static BuffKind? fromKey(String key) {
    for (final e in values) {
      if (e.key == key) return e;
    }
    return null;
  }
}
