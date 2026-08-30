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

/// 재화(골드·경험치)의 상한. **int64 오버플로 방어선**이다.
///
/// ⚠️ Dart 의 int 는 64비트이고 **넘치면 조용히 음수로 감싼다**
/// (`9223372036854775807 + 1 == -9223372036854775808`). 예외도 안 난다.
/// 실제로 스테이지 1708 유저의 골드가 9.289e18 까지 자연 누적돼 한계를 넘고
/// **음수가 됐다**(2026-08-30 제보). 조작이 아니라 정상 진행의 결과다 —
/// 골드는 스테이지마다 지수로 자라고 월드마다 x2.2 가 더 곱해진다.
///
/// 값을 int64 최대값 **바로 아래**로 잡는다. 낮게 잡으면(예: 1e18) 후반
/// 유저의 자산을 통째로 깎고 업그레이드 비용을 감당 못 하게 만든다 —
/// 오버플로를 막으려다 진행을 막는 셈이다.
///
/// ⚠️ 상한만으로는 부족하다. `gold + reward` 가 **더하는 순간** 넘치기
/// 때문에, 반드시 [addCurrency] 로 **double 에서 더한 뒤** 자른다.
const int kMaxCurrency = 9000000000000000000; // 9e18 (int64 최대의 97.6%)

/// [v] 를 0 ~ [kMaxCurrency] 로 자른다.
///
/// 음수도 함께 막는다 — 이미 감싸서 음수가 된 세이브를 읽었을 때 그대로 두면
/// 화면에 마이너스가 뜨고, 거기서 또 더하면 계속 음수다.
int clampCurrency(num v) {
  if (v.isNaN) return 0;
  if (v <= 0) return 0;
  return v >= kMaxCurrency ? kMaxCurrency : v.toInt();
}

/// 재화를 **안전하게 더한다**. 재화를 더하는 모든 곳에서 이걸 쓴다.
///
/// ⚠️ `clampCurrency(a + b)` 는 **틀렸다.** int 끼리의 덧셈이 먼저 일어나
/// 자르기 전에 이미 감싼다. double 로 올려 더한 뒤 자른다 —
/// double 은 1e308 까지 담고 넘쳐도 음수가 아니라 무한대가 된다.
///
/// 큰 값에서 정밀도(약 9e15 이상은 정수 단위가 벌어진다)를 잃지만,
/// 9e18 규모에서 1골드 차이는 의미가 없다.
int addCurrency(int a, num b) => clampCurrency(a.toDouble() + b.toDouble());

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
