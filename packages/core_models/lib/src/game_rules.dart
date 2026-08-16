/// 게임의 **구조적 규칙 상수** 모음 (CLAUDE.md §6 예외 항목).
///
/// 여기 있는 값은 "밸런스 수치"가 아니라 **시스템 규칙을 정의하는 확정값**이다.
/// 밸런스 계수(종 스탯, 드롭율, 강화 %/Lv, 데미지 배율 등)는 코드가 아니라
/// `packages/app/assets/data/*.json` 에 둔다.
library;

import 'enums.dart';

/// 트랩 슬롯 개수 (§2.4).
const int kTrapSlots = 3;

/// 전투 최대 라운드 (§2.3).
const int kMaxBattleRounds = 20;

/// 오프라인 보상 누적 상한 (§2.4).
const Duration kMaxOfflineAccrual = Duration(hours: 8);

// --- 개체 사이즈 → 스탯 배율 매핑 (§2.1) ---

/// 사이즈 최소값에 대응하는 스탯 배율.
const double kStatMultiplierMin = 0.85;

/// 사이즈 최대값에 대응하는 스탯 배율.
const double kStatMultiplierMax = 1.20;

/// 사이즈 정규분포 롤의 표준편차 분모.
/// σ = (max - min) / kSizeSigmaDivisor. 6 이면 [min,max] 가 평균±3σ 를 덮는다(≈99.7%).
const double kSizeSigmaDivisor = 6.0;

// --- 포텐셜 / 강화 상한 (§2.1) ---

/// 포텐셜 최소 성.
const int kPotentialMin = 1;

/// 포텐셜 최대 성.
const int kPotentialMax = 5;

/// 포텐셜 1성당 강화 상한 레벨. maxLevel = potential * kLevelsPerPotential.
const int kLevelsPerPotential = 10;

/// 돌파(§2.7)가 요구하는 재료 종류. **수량**은 밸런스라 `pets.json` 에 있고,
/// "어떤 재료를 쓰는가"는 시스템 규칙이라 여기 둔다.
///
/// 한 곳에 모은 이유: 앱(`SaveController.breakthrough`)·서버(`GameActions`)·
/// UI(비용 표시)가 각자 목록을 들고 있었다. 목록이 어긋나면 "화면엔 3종인데
/// 실제로는 2종만 차감"처럼 조용히 틀린다.
const List<MaterialKind> kBreakthroughMaterials = [
  MaterialKind.chitin,
  MaterialKind.mineral,
  MaterialKind.sap,
];

/// 처치·분해·방생에서 무작위로 하나 골라 주는 **일반 재료** 3종.
///
/// 젤리(프리미엄, §2.6)와 화석 조각(제련 전용, §2.7)은 여기 없다 —
/// 각자 다른 수도꼭지를 가져야 조절이 되기 때문이다.
/// 앱·서버가 같은 목록을 써야 "앱에선 수액이 나왔는데 서버는 키틴"이 안 생긴다.
const List<MaterialKind> kRegularMaterials = [
  MaterialKind.chitin,
  MaterialKind.mineral,
  MaterialKind.sap,
];
