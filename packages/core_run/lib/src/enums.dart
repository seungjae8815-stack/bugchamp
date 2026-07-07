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
