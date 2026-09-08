# 곤충이 함께 때린다 — 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 방치 런에서 장착 곤충 3마리가 캐릭터와 **따로** 타격하게 만들고, 오행 상극일 때만 그 곤충의 타격을 1.5배로 올린다.

**Architecture:** 펫의 공격력 배율(`computePetBonus().attackMult`)을 **지분**으로 재해석해 오늘의 DPS 를 플레이어와 곤충에게 나눈다. 총량이 중립이라 §7 적응형 체력 기준(`baselineHitPower`·`_petStats`)은 **한 줄도 안 바뀐다**. 유일한 순증가는 오행 상극 배율이고, 이것만 기준 밖이다.

**Tech Stack:** Dart(순수 패키지 `core_run`/`core_models`) + Flutter(`app`). 테스트는 `dart test`(순수) / `flutter test`(앱).

**Spec:** `docs/superpowers/specs/2026-09-08-pet-attackers-design.md`

## Global Constraints

- **밸런스 수치는 JSON 에만**(CLAUDE.md §6). Dart 에 매직넘버 금지. 새 수치는
  `packages/app/assets/data/run_config.json` 과 `packages/app/assets/data/pets.json` 에 넣는다.
- **순수 패키지에서 `flutter`/`hive`/`riverpod`/`dart:ui` import 금지**(§5).
  훅(`tool/hook_arch_guard.dart`)이 편집 전에 막는다.
- **전역 `Random()`·`DateTime.now()` 금지**(§5). 주입된 seed/clock 만.
- **의존 방향**: `core_run → core_models`. `core_run` 은 `core_battle` 을 모른다(§4).
- **§7 기준을 건드리지 않는다**: `run_math.dart` 의 `baselineHitPower`·`habitatMaxHp`·
  `habitatThreat`, 그리고 `play_screen.dart` 의 `_petStats`/`_baseStats` 는 **수정 금지**.
  기준 안에 새 이득이 들어가면 이 설계의 전제(재조정 불필요)가 무너진다.
- **UI 문자열 하드코딩 금지** → ARB(ko/en/ja, 한국어 우선).
- **이름이 겹치는 둘을 헷갈리지 말 것**: `petRestrainMult(...)` 는 `core_run` 의
  **함수**(상극이면 배율, 아니면 1.0)이고, `RunConfig.petRestrainMult` 는 그 함수에
  넘길 **설정값**(1.5)이다. 호출은 `petRestrainMult(펫속성, 지역속성, _config.petRestrainMult)`
  형태가 된다 — Dart 에서 톱레벨 함수와 인스턴스 필드는 충돌하지 않는다.
- 각 태스크 끝에 `dart format .` 를 돌리고 커밋한다.
- PowerShell 환경: 명령은 한 줄에 하나 또는 `;` 로 잇는다. 경로 구분자 `\`.

---

### Task 1: 지역에 오행 속성을 붙인다

**Files:**
- Modify: `packages/core_run/lib/src/run_config.dart:67-100` (`RegionConfig`)
- Modify: `packages/app/assets/data/run_config.json` (`regions[]`)
- Test: `packages/core_run/test/run_config_test.dart` (없으면 생성)

**Interfaces:**
- Consumes: `Element` (`package:core_models/core_models.dart`, `enums.dart:133`)
- Produces: `RegionConfig.element` — `Element?`. **null 이면 무속성**(상극이 안 걸린다).

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`packages/core_run/test/run_config_test.dart` (파일이 없으면 아래 import 로 새로 만든다):

```dart
import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:test/test.dart';

void main() {
  group('지역 오행 속성', () {
    test('JSON 에 적힌 속성을 읽는다', () {
      final r = RegionConfig.fromJson({
        'id': 'oak_forest',
        'name': {'ko': '참나무 숲'},
        'bossName': {'ko': '숲지기'},
        'habitatKinds': ['tree'],
        'element': 'wood',
      });
      expect(r.element, Element.wood);
    });

    test('속성이 없으면 null — 무속성 지역이 되고 상극이 안 걸린다', () {
      // 여기서 던지면 구버전 JSON 을 얹은 앱이 로딩에서 죽는다.
      final r = RegionConfig.fromJson({
        'id': 'grass_field',
        'name': {'ko': '풀밭'},
        'bossName': {'ko': '들풀왕'},
        'habitatKinds': ['flower'],
      });
      expect(r.element, isNull);
    });
  });
}
```

- [ ] **Step 2: 실패를 확인한다**

Run: `cd packages\core_run ; dart test test/run_config_test.dart`
Expected: FAIL — `The getter 'element' isn't defined for the class 'RegionConfig'`

- [ ] **Step 3: 최소 구현**

`run_config.dart` 의 `RegionConfig` 에 필드를 넣는다.

```dart
  /// 이 지역 몬스터의 오행 속성. **null 이면 무속성**(상극이 안 걸린다).
  ///
  /// 지역 단위인 이유: 지역마다 편성을 바꾸는 것이 이 시스템이 만들려는
  /// 행동이다. 몬스터 개체마다 무작위로 주면 편성을 미리 고를 수 없어
  /// **판단 자체가 사라진다**.
  final Element? element;
```

생성자에 `this.element,` 를 추가(required 아님)하고, `fromJson` 에 다음을 넣는다.

```dart
    // `fromKey` 가 아니라 `fromKeyOrNull` 이다. 애셋 오타를 로딩에서 잡는
    // 다른 필드와 달리, 이건 **없어도 정상**(무속성)이라 던지면 안 된다.
    element: json['element'] == null
        ? null
        : Element.fromKeyOrNull(json['element'] as String),
```

- [ ] **Step 4: 통과를 확인한다**

Run: `cd packages\core_run ; dart test test/run_config_test.dart`
Expected: PASS

- [ ] **Step 5: 실데이터에 속성을 적는다**

`packages/app/assets/data/run_config.json` 의 `regions` 배열 각 원소에 `"element"` 를 넣는다.
지역 순서(현재 `grass_field` / `oak_forest` / `valley_stream` / `night_mountain`)를 확인하고
아래 배정을 쓴다. **오행 5개를 골고루 돌려** 어느 한 속성만 정답이 되지 않게 한다.

```
grass_field    → "wood"    (풀밭 = 나무)
oak_forest     → "earth"   (숲 바닥 = 흙)
valley_stream  → "water"   (계곡 = 물)
night_mountain → "metal"   (밤산 = 쇠)
```

지역이 5개 이상이면 다섯째부터 `"fire"` 를 넣고 위 순서를 반복한다.

- [ ] **Step 6: 앱이 실데이터를 읽는지 확인**

Run: `cd packages\app ; flutter test`
Expected: PASS (`data_test.dart` 가 실 JSON 을 파싱한다)

- [ ] **Step 7: 커밋**

```bash
dart format .
git add packages/core_run packages/app/assets/data/run_config.json
git commit -m "feat(방치): 지역마다 오행 속성 — 편성을 바꿀 이유를 만든다"
```

---

### Task 2: 타격 분배 순수 함수

**Files:**
- Create: `packages/core_run/lib/src/pet_attack.dart`
- Modify: `packages/core_run/lib/core_run.dart` (export 추가)
- Test: `packages/core_run/test/pet_attack_test.dart`

**Interfaces:**
- Consumes: `Element` (`core_models`), Task 1 의 `RegionConfig.element`
- Produces:
  - `typedef PetAttackerInput = ({String bugId, Element element, int spd, double attack});`
  - `typedef PetAttacker = ({String bugId, Element element, double damageMult, double interval});`
  - `({double playerMult, List<PetAttacker> pets}) splitAttack({required List<PetAttackerInput> pets, required double playerInterval, required double spdReference, required double intervalMin, required double intervalMax})`
  - `double petRestrainMult(Element pet, Element? monster, double mult)`

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`packages/core_run/test/pet_attack_test.dart`:

```dart
import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:test/test.dart';

/// 한 세트의 총 DPS(플레이어 + 곤충들). 오늘의 한 대를 1.0 으로 본다.
double _totalDps(({double playerMult, List<PetAttacker> pets}) r, double pInt) {
  var dps = r.playerMult / pInt;
  for (final p in r.pets) {
    dps += p.damageMult / p.interval;
  }
  return dps;
}

void main() {
  const pInt = 0.5; // 플레이어 타격 간격 0.5초 = 공속 2.0

  ({double playerMult, List<PetAttacker> pets}) split(
    List<PetAttackerInput> pets,
  ) => splitAttack(
    pets: pets,
    playerInterval: pInt,
    spdReference: 100,
    intervalMin: 0.25,
    intervalMax: 2.5,
  );

  group('타격 분배', () {
    test('펫이 없으면 플레이어가 전부 때린다', () {
      final r = split(const []);
      expect(r.playerMult, 1.0);
      expect(r.pets, isEmpty);
    });

    test('총 DPS 가 오늘과 같다 — 나눌 뿐 늘리지 않는다', () {
      // 이게 깨지면 §7 적응형 체력을 재조정해야 한다. 이 설계의 전제다.
      final r = split(const [
        (bugId: 'a', element: Element.wood, spd: 100, attack: 0.25),
        (bugId: 'b', element: Element.fire, spd: 60, attack: 0.25),
        (bugId: 'c', element: Element.water, spd: 180, attack: 0.25),
      ]);
      expect(_totalDps(r, pInt), closeTo(1 / pInt, 1e-9));
    });

    test('간격을 바꿔도 DPS 가 안 변한다 — 빠른 종만 정답이 되면 안 된다', () {
      final slow = split(const [
        (bugId: 'a', element: Element.wood, spd: 50, attack: 0.5),
      ]);
      final fast = split(const [
        (bugId: 'a', element: Element.wood, spd: 200, attack: 0.5),
      ]);
      expect(_totalDps(slow, pInt), closeTo(_totalDps(fast, pInt), 1e-9));
      // 다만 **간격은 달라야** 한다 — 그래야 종이 화면에서 구분된다.
      expect(slow.pets.single.interval, greaterThan(fast.pets.single.interval));
    });

    test('느린 종은 한 대가 크다 — 큰 숫자를 가끔', () {
      final slow = split(const [
        (bugId: 'a', element: Element.wood, spd: 50, attack: 0.5),
      ]);
      final fast = split(const [
        (bugId: 'a', element: Element.wood, spd: 200, attack: 0.5),
      ]);
      expect(
        slow.pets.single.damageMult,
        greaterThan(fast.pets.single.damageMult),
      );
    });

    test('간격은 상하한으로 잘린다 — 프레임마다 때리거나 영영 안 때리면 안 된다', () {
      final r = split(const [
        (bugId: 'a', element: Element.wood, spd: 100000, attack: 0.5),
        (bugId: 'b', element: Element.fire, spd: 1, attack: 0.5),
      ]);
      expect(r.pets[0].interval, 0.25);
      expect(r.pets[1].interval, 2.5);
    });

    test('기여가 0 인 곤충은 목록에서 빠진다 — 0 데미지 팝업이 뜨면 안 된다', () {
      final r = split(const [
        (bugId: 'a', element: Element.wood, spd: 100, attack: 0.0),
        (bugId: 'b', element: Element.fire, spd: 100, attack: 0.25),
      ]);
      expect(r.pets.map((p) => p.bugId), ['b']);
    });
  });

  group('오행 상극 배율', () {
    test('상극이면 배율이 붙는다 — 水克火', () {
      expect(petRestrainMult(Element.water, Element.fire, 1.5), 1.5);
    });

    test('상극이 아니면 1.0 — 어긋나도 손해는 없다', () {
      // 1.0 미만을 주면 "곤충이 약해졌다"가 되고, 편성을 못 맞춘 유저에게
      // 벌을 주는 시스템이 된다.
      expect(petRestrainMult(Element.fire, Element.water, 1.5), 1.0);
      expect(petRestrainMult(Element.wood, Element.wood, 1.5), 1.0);
    });

    test('무속성 지역이면 1.0', () {
      expect(petRestrainMult(Element.water, null, 1.5), 1.0);
    });

    test('3마리 다 상극이어도 총 DPS 상한은 1 + petShare x 0.5 다', () {
      // 전설 성충 3마리 수준(합 0.75) → petShare = 0.75/1.75
      const pets = [
        (bugId: 'a', element: Element.water, spd: 100, attack: 0.25),
        (bugId: 'b', element: Element.water, spd: 100, attack: 0.25),
        (bugId: 'c', element: Element.water, spd: 100, attack: 0.25),
      ];
      final r = split(pets);
      var dps = r.playerMult / pInt;
      for (final p in r.pets) {
        dps += p.damageMult * 1.5 / p.interval;
      }
      final petShare = 0.75 / 1.75;
      expect(dps * pInt, closeTo(1 + petShare * 0.5, 1e-9));
      expect(dps * pInt, lessThan(1.25)); // 업그레이드 한 레벨 반쯤
    });
  });
}
```

- [ ] **Step 2: 실패를 확인한다**

Run: `cd packages\core_run ; dart test test/pet_attack_test.dart`
Expected: FAIL — `Undefined name 'splitAttack'`

- [ ] **Step 3: 최소 구현**

`packages/core_run/lib/src/pet_attack.dart` 를 만든다.

```dart
import 'package:core_models/core_models.dart';

/// 분배 입력 — 곤충 1마리. [attack] 은 `petContribution(...).attack`,
/// [spd] 는 종 기본 SPD(`Species.baseStats.spd`).
typedef PetAttackerInput = ({
  String bugId,
  Element element,
  int spd,
  double attack,
});

/// 분배 결과 — 곤충 1마리가 [interval] 초마다 `오늘의 한 대 x damageMult` 를 넣는다.
typedef PetAttacker = ({
  String bugId,
  Element element,
  double damageMult,
  double interval,
});

/// 오늘의 DPS 를 플레이어와 곤충들에게 **나눈다**(늘리지 않는다).
///
/// 펫의 공격력 배율(`computePetBonus().attackMult` = 1 + 기여합)을 지분으로
/// 재해석한 것이다. petShare = 합/(1+합), playerMult = 1 - petShare,
/// 곤충 i 의 damageMult = petShare x (a_i/합) x (interval_i/playerInterval).
///
/// 마지막 항이 **간격 보정**이다. 이게 없으면 빠른 종이 곧 더 센 종이 되어
/// 종 선택이 다시 하나로 수렴한다.
///
/// 총량이 중립이라 **§7 적응형 체력 기준을 안 건드린다**. 이 성질이 깨지면
/// `habitatMaxHp` 를 처음부터 다시 잡아야 한다.
({double playerMult, List<PetAttacker> pets}) splitAttack({
  required List<PetAttackerInput> pets,
  required double playerInterval,
  required double spdReference,
  required double intervalMin,
  required double intervalMax,
}) {
  var sum = 0.0;
  for (final p in pets) {
    if (p.attack > 0) sum += p.attack;
  }
  if (sum <= 0) return (playerMult: 1.0, pets: const []);

  final petShare = sum / (1 + sum);
  final out = <PetAttacker>[];
  for (final p in pets) {
    // 기여가 0 인 곤충은 뺀다 — 남겨 두면 0 데미지 팝업이 뜬다.
    if (p.attack <= 0) continue;
    final spd = p.spd <= 0 ? spdReference : p.spd.toDouble();
    final interval = (playerInterval * spdReference / spd).clamp(
      intervalMin,
      intervalMax,
    );
    out.add((
      bugId: p.bugId,
      element: p.element,
      damageMult: petShare * (p.attack / sum) * (interval / playerInterval),
      interval: interval,
    ));
  }
  return (playerMult: 1 - petShare, pets: out);
}

/// 곤충 속성이 몬스터를 克하면 [mult], 아니면 1.0.
///
/// **1.0 미만을 돌려주지 않는다.** 어긋났다고 깎으면 "곤충이 약해졌다"가
/// 되고, 편성을 못 맞춘 유저를 벌하는 시스템이 된다.
double petRestrainMult(Element pet, Element? monster, double mult) =>
    monster != null && pet.restrains(monster) ? mult : 1.0;
```

`packages/core_run/lib/core_run.dart` 에 export 를 한 줄 추가한다.

```dart
export 'src/pet_attack.dart';
```

- [ ] **Step 4: 통과를 확인한다**

Run: `cd packages\core_run ; dart test test/pet_attack_test.dart`
Expected: PASS (10 tests)

- [ ] **Step 5: 커밋**

```bash
dart format .
git add packages/core_run
git commit -m "feat(방치): 타격 분배 순수 함수 — 총 DPS 중립 + 오행 상극"
```

---

### Task 3: 설정값을 JSON 으로 뺀다

**Files:**
- Modify: `packages/core_run/lib/src/run_config.dart` (`RunConfig` 필드 + `fromJson`)
- Modify: `packages/core_run/lib/src/pet_config.dart` (`PetConfig` 필드 + `fromJson`)
- Modify: `packages/app/assets/data/run_config.json`, `packages/app/assets/data/pets.json`
- Test: `packages/core_run/test/pet_attack_test.dart` (기본값 테스트 추가)

**Interfaces:**
- Produces: `RunConfig.petRestrainMult` (double, 기본 1.5),
  `PetConfig.attackSpdReference` (기본 100), `PetConfig.attackIntervalMin` (기본 0.25),
  `PetConfig.attackIntervalMax` (기본 2.5)

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`packages/core_run/test/pet_attack_test.dart` 의 `main()` 끝에 추가:

```dart
  group('설정 기본값', () {
    test('상극 배율은 JSON 이 없으면 1.5', () {
      // 코드에 매직넘버로 두면 안 된다(§6) — 여기서 읽는 건 **폴백**이다.
      expect(RunConfig.fromJson(const {}).petRestrainMult, 1.5);
    });

    test('곤충 타격 간격 설정 기본값', () {
      final c = PetConfig.fromJson(const {});
      expect(c.attackSpdReference, 100);
      expect(c.attackIntervalMin, 0.25);
      expect(c.attackIntervalMax, 2.5);
    });
  });
```

`RunConfig.fromJson(const {})` / `PetConfig.fromJson(const {})` 가 빈 맵에서 던지면
(다른 필드가 required 라서) 이 테스트를 실데이터 검사로 바꾼다: `run_config.json` 을
`File(...).readAsStringSync()` 로 읽어 `petRestrainMult` 키가 있는지 본다
(`packages/app/test/forge_flow_test.dart:29-32` 의 `_read` 패턴 참고).

- [ ] **Step 2: 실패를 확인한다**

Run: `cd packages\core_run ; dart test test/pet_attack_test.dart`
Expected: FAIL — `The getter 'petRestrainMult' isn't defined`

- [ ] **Step 3: 최소 구현**

`RunConfig` 에:

```dart
  /// 곤충 속성이 몬스터를 克할 때 **그 곤충의 타격에만** 곱하는 배율(§2.3).
  ///
  /// 이것이 이 시스템의 **유일한 §7 기준 밖 이득**이다. 3마리 다 상극이어도
  /// 총 DPS 는 `1 + petShare x (이 값 - 1)` 을 넘지 않는다 — 전설 3마리 기준
  /// x1.21. 올리기 전에 `balance_sim --pet-restrain` 을 반드시 돌린다.
  ///
  /// "편성을 맞췄는데 체감이 약하다"면 이 값이 아니라 **곤충 지분**
  /// (`pets.json → gradeAttackPct`)을 키운다 — 여기만 올리면 편성을 못 맞춘
  /// 유저와의 격차만 벌어지고 총량은 별로 안 는다.
  final double petRestrainMult;
```

생성자에 `this.petRestrainMult = 1.5,`, `fromJson` 에
`petRestrainMult: (json['petRestrainMult'] as num?)?.toDouble() ?? 1.5,`.

`PetConfig` 에:

```dart
  /// 곤충 타격 간격의 기준 SPD. 종 SPD 가 이 값이면 플레이어와 같은 간격이다.
  final double attackSpdReference;

  /// 곤충 타격 간격 상하한(초). 프레임마다 때리거나 영영 안 때리는 걸 막는다.
  final double attackIntervalMin;
  final double attackIntervalMax;
```

생성자 기본값 `this.attackSpdReference = 100, this.attackIntervalMin = 0.25,
this.attackIntervalMax = 2.5,` 와 `fromJson` 의 대응 파싱
(`(json['attackSpdReference'] as num?)?.toDouble() ?? 100` 형태)을 넣는다.

- [ ] **Step 4: 실데이터에 값을 적는다**

`packages/app/assets/data/run_config.json` 최상위에:

```json
  "petRestrainMult": 1.5,
  "_petRestrainComment": "곤충 속성이 지역 속성을 克하면 그 곤충의 타격만 x1.5. 유일한 적응형 체력 기준 밖 이득이다 — 올리기 전 balance_sim --pet-restrain 을 돌릴 것.",
```

`packages/app/assets/data/pets.json` 최상위에:

```json
  "attackSpdReference": 100,
  "attackIntervalMin": 0.25,
  "attackIntervalMax": 2.5,
  "_attackIntervalComment": "곤충 타격 간격은 종 SPD 로 정하되 DPS 는 중립이다(느린 종은 한 대가 크다). 연출 리듬만 바꾸고 총량은 안 바꾼다.",
```

- [ ] **Step 5: 통과를 확인한다**

Run: `cd packages\core_run ; dart test`
Expected: PASS (전체)

Run: `cd packages\app ; flutter test test/data_test.dart`
Expected: PASS

- [ ] **Step 6: 커밋**

```bash
dart format .
git add packages/core_run packages/app/assets/data
git commit -m "feat(방치): 상극 배율·곤충 타격 간격을 JSON 으로"
```

---

### Task 4: 타격 루프를 나눈다 (앱)

**Files:**
- Create: `packages/app/lib/features/play/pet_attackers.dart`
- Modify: `packages/app/lib/features/play/play_screen.dart:395` 부근 (상태 필드)
- Modify: `packages/app/lib/features/play/play_screen.dart:641` 아래 (헬퍼)
- Modify: `packages/app/lib/features/play/play_screen.dart:885-948` (`_step` 타격부)
- Test: `packages/app/test/pet_attack_flow_test.dart` (신규)

**Interfaces:**
- Consumes: Task 2 의 `splitAttack`/`petRestrainMult`/`PetAttacker`/`PetAttackerInput`,
  Task 3 의 `RunConfig.petRestrainMult`·`PetConfig.attackSpdReference/attackIntervalMin/attackIntervalMax`,
  Task 1 의 `RegionConfig.element`
- Produces: `buildPetAttackers(...)`, 상태 `_petAcc`·`_petHits`(Task 5 가 소비)

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`play_screen` 은 위젯이라 단위테스트가 어렵다. **분배 조립부만** 별도 파일로 빼서 검사한다.

`packages/app/test/pet_attack_flow_test.dart`:

```dart
import 'package:app/features/play/pet_attackers.dart';
import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('장착 곤충 → 타격자 조립', () {
    test('장착이 없으면 플레이어가 전부', () {
      final r = buildPetAttackers(
        equipped: const [],
        playerInterval: 0.5,
        petConfig: PetConfig.fromJson(const {}),
      );
      expect(r.playerMult, 1.0);
      expect(r.pets, isEmpty);
    });

    test('장착 곤충의 종 SPD 가 간격이 된다', () {
      final r = buildPetAttackers(
        equipped: const [
          (bugId: 'a', element: Element.wood, spd: 200, attack: 0.5),
        ],
        playerInterval: 0.5,
        petConfig: PetConfig.fromJson(const {}),
      );
      // spdReference(100) 의 2배로 빠르다 → 간격 절반
      expect(r.pets.single.interval, closeTo(0.25, 1e-9));
    });
  });
}
```

- [ ] **Step 2: 실패를 확인한다**

Run: `cd packages\app ; flutter test test/pet_attack_flow_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:app/features/play/pet_attackers.dart'`

- [ ] **Step 3: 조립부를 별도 파일로 만든다**

`packages/app/lib/features/play/pet_attackers.dart`:

```dart
import 'package:core_run/core_run.dart';

/// 장착 곤충 목록 → 타격자 분배.
///
/// `play_screen` 밖에 두는 이유: 위젯 안에 있으면 단위테스트가 안 되고,
/// 이 계산은 **총 DPS 중립성**이라는 검사할 값이 있는 부분이다.
({double playerMult, List<PetAttacker> pets}) buildPetAttackers({
  required List<PetAttackerInput> equipped,
  required double playerInterval,
  required PetConfig petConfig,
}) => splitAttack(
  pets: equipped,
  playerInterval: playerInterval,
  spdReference: petConfig.attackSpdReference,
  intervalMin: petConfig.attackIntervalMin,
  intervalMax: petConfig.attackIntervalMax,
);
```

- [ ] **Step 4: 통과를 확인한다**

Run: `cd packages\app ; flutter test test/pet_attack_flow_test.dart`
Expected: PASS

- [ ] **Step 5: 장착 곤충 → 입력 헬퍼**

`play_screen.dart` 의 `_petStats`(`:641`) **아래**에 추가한다.
`_petStats` 자체는 **절대 수정하지 않는다**(§7 기준).

```dart
  /// 장착 곤충 → 분배 입력. `_petStats` 와 같은 목록을 훑되 **기준은 안 건드린다**.
  List<PetAttackerInput> _equippedAttackerInputs(SaveGame save) {
    final cfg = _data.petConfig;
    if (cfg == null || save.equippedBugIds.isEmpty) return const [];
    final now = _clock.now().toUtc();
    final out = <PetAttackerInput>[];
    for (final id in save.equippedBugIds) {
      IndividualBug? bug;
      for (final b in save.bugs) {
        if (b.id == id) {
          bug = b;
          break;
        }
      }
      if (bug == null) continue;
      final sp = _data.speciesById[bug.speciesId];
      if (sp == null) continue;
      out.add((
        bugId: bug.id,
        element: bug.element,
        spd: sp.baseStats.spd,
        attack: petContribution(petStatOf(bug, sp, cfg, now), cfg).attack,
      ));
    }
    return out;
  }
```

- [ ] **Step 6: 곤충 누산기 상태를 추가한다**

`_attackAcc`(`:395`) 옆에:

```dart
  /// 곤충별 타격 누산기(bugId → 쌓인 초). 플레이어 `_attackAcc` 와 같은 방식.
  ///
  /// 스폰마다 리셋하지 않는다 — `_enemyAtkAcc` 와 같은 이유로, 빨리 죽는
  /// 구간에서 곤충이 영영 한 대도 못 때리게 된다(`:622-628` 주석 참조).
  final Map<String, double> _petAcc = {};

  /// 이번 프레임에 곤충이 낸 타격(연출용). `_step` 이 채우고 Task 5 가 비운다.
  final List<({String bugId, double damage, bool restrained})> _petHits = [];
```

- [ ] **Step 7: `_step` 의 타격부를 나눈다**

`play_screen.dart:885-948` 에서 `perHit` 을 다 구한 **직후**(보스 배율까지 곱한 뒤)
분배를 계산하고 플레이어 지분을 곱한다.

```dart
    // 오늘의 한 대를 플레이어와 곤충이 나눠 갖는다. 총량은 그대로다 —
    // §7 기준(`_petStats`)은 이 아래로 내려오지 않는다.
    final region = _config.regionForStage(_stage);
    final split = buildPetAttackers(
      equipped: _equippedAttackerInputs(save),
      playerInterval: interval,
      petConfig: _data.petConfig ?? PetConfig.fromJson(const {}),
    );
    // 곤충 데미지는 **나누기 전** 값을 기준으로 한다. 나눈 값을 쓰면 플레이어
    // 지분만큼 한 번 더 깎인다(가장 흔한 실수다).
    final perHitFull = perHit;
    perHit *= split.playerMult;
```

플레이어 while 루프 **뒤**, `if (_hp <= 0) _beginDeath(stats);`(`:948`) **앞**에:

```dart
    // 곤충 타격 — 각자 자기 간격으로. 플레이어와 같은 누산기 방식이라
    // 프레임이 튀어도 넣어야 할 대수가 안 사라진다.
    for (final p in split.pets) {
      if (_hp <= 0) break;
      var left = (_petAcc[p.bugId] ?? 0) + dt;
      var petGuard = 0;
      final rest = petRestrainMult(
        p.element,
        region.element,
        _config.petRestrainMult,
      );
      while (left >= p.interval && _hp > 0 && petGuard < 20) {
        left -= p.interval;
        petGuard++;
        // 곤충 타격에는 치명타를 굴리지 않는다 — 굴리면 화면이 노란 숫자로
        // 덮이고, 무엇보다 치명 기대값이 분배에 이미 들어 있어 **총량이
        // 어긋난다**.
        final dmg = perHitFull * p.damageMult * rest;
        _hp -= dmg;
        _petHits.add((bugId: p.bugId, damage: dmg, restrained: rest > 1));
      }
      _petAcc[p.bugId] = left;
    }
```

- [ ] **Step 8: 회귀를 확인한다**

Run: `cd packages\app ; flutter analyze`
Expected: No issues found

Run: `cd packages\app ; flutter test`
Expected: PASS (기존 217개 + 신규 2개)

- [ ] **Step 9: 커밋**

```bash
dart format .
git add packages/app
git commit -m "feat(방치): 곤충이 자기 간격으로 따로 때린다 — 총량은 그대로"
```

---

### Task 5: 곤충 타격 연출

**Files:**
- Modify: `packages/app/lib/features/play/play_screen.dart:812` 부근 (감쇠부)
- Modify: `packages/app/lib/features/play/play_screen.dart:2965-3016` (`_petFollowers`)

**Interfaces:**
- Consumes: Task 4 의 `_petHits`·`_petAcc`
- Produces: 없음(화면만)

- [ ] **Step 1: 곤충별 연출 상태를 만든다**

`_petAcc` 옆에 추가:

```dart
  /// 곤충별 공격 모션 펄스(0~1). 플레이어 `_attackPulse` 와 같은 감쇠.
  final Map<String, double> _petPulse = {};

  /// 곤충별 데미지 팝업 쿨다운 — 4주체가 각자 팝업을 띄우면 화면이 숫자로
  /// 덮인다. 플레이어 `_dmgCooldown = 0.12` 와 같은 방식.
  final Map<String, double> _petPopCd = {};
```

- [ ] **Step 2: `_step` 에서 감쇠시킨다**

`_attackPulse` 감쇠(`:812`) 옆에:

```dart
    for (final k in _petPulse.keys.toList()) {
      final v = _petPulse[k]! - dt * 2.6;
      v <= 0 ? _petPulse.remove(k) : _petPulse[k] = v;
    }
    for (final k in _petPopCd.keys.toList()) {
      final v = _petPopCd[k]! - dt;
      v <= 0 ? _petPopCd.remove(k) : _petPopCd[k] = v;
    }
```

- [ ] **Step 3: `_petHits` 를 소비해 팝업을 만든다**

Task 4 의 곤충 루프 **뒤**에 넣는다:

```dart
    for (final h in _petHits) {
      _petPulse[h.bugId] = 1;
      if (_petPopCd.containsKey(h.bugId)) continue;
      _petPopCd[h.bugId] = 0.12;
      // 상극이 먹고 있다는 걸 **숫자 색**으로 알게 한다. 따로 설명을 띄우면
      // 방치 화면에서 아무도 안 읽는다.
      // 크기는 플레이어(20/26)보다 작게 — 주인공의 한 방이 묻히면 안 된다.
      _pops.add(/* _Pop(...) — 아래 주의 참조 */);
    }
    _petHits.clear();
```

`_Pop` 의 실제 생성자 필드명·인자 순서는 `play_screen.dart:912-918` 을 열어 **그대로 맞춘다**.
색은 상극이면 `const Color(0xFF7CFF9E)`, 아니면 `Colors.white70`. 크기는 15.
좌표는 플레이어 팝업과 같은 `ex/ey`(`:1578-1579`)를 쓰되 `ex` 를 곤충마다 조금 흩어
겹치지 않게 한다.

- [ ] **Step 4: 공격 자세 프레임을 쓴다**

`_petFollowers()`(`:2965`)의 `bugStageImage(...)` 호출(`:3003`)을 바꾼다.
성충만 공격 자세 프레임이 있다(`bugs/{id}_adult_2.webp`).

```dart
                // 유충·알은 지금처럼 단계 그림을 그대로 쓴다.
                child: stage == LifeStage.adult
                    ? bugPoseImage(
                        bug.speciesId,
                        (_petPulse[bug.id] ?? 0) > 0.12
                            ? BugPose.attack
                            : BugPose.idle,
                        size: size,
                        fallback: bugAvatar(sp, size: size - 4),
                        skin: bugView(bug, sp),
                      )
                    : bugStageImage(/* 기존 인자 그대로 */),
```

`BugPose` 의 실제 enum 값 이름은 `packages/app/lib/ui/art.dart:239` 부근을 열어
확인해 그대로 쓴다(`attack`/`idle` 이 아닐 수 있다).

- [ ] **Step 5: 칠 때 앞으로 나오게 한다**

`:3000` 의 `Transform.translate(Offset(_attackPulse * 8, bob))` 를 자기 펄스로 바꾼다:

```dart
              // 캐릭터를 따라 움직이던 것을 **자기 타격**에 반응하게 바꾼다.
              // 캐릭터 펄스를 그대로 쓰면 곤충이 자기 리듬으로 때리는 게
              // 화면에 안 보인다.
              Transform.translate(
                Offset((_petPulse[bug.id] ?? 0) * 14, bob),
```

- [ ] **Step 6: 정적분석·테스트**

Run: `cd packages\app ; flutter analyze`
Expected: No issues found

Run: `cd packages\app ; flutter test`
Expected: PASS

- [ ] **Step 7: 실기로 확인한다**

```powershell
cd packages\app
flutter build apk --profile --dart-define-from-file=supabase.env.json --dart-define-from-file=admob.env.json --dart-define=GAME_SERVER_URL=https://bugchamp-server-867649520275.asia-northeast3.run.app
```
그 다음 `adb install -r build\app\outputs\flutter-apk\app-profile.apk`

눈으로 확인할 것:
- 곤충 3마리가 **각자 다른 리듬**으로 때린다(같이 움직이면 펄스를 안 나눈 것)
- 상극 지역에서 곤충 숫자가 **초록색**으로 뜬다
- 숫자가 화면을 덮지 않는다(쿨다운이 먹고 있다)
- 곤충을 다 빼면 오늘과 같은 화면이다

- [ ] **Step 8: 커밋**

```bash
dart format .
git add packages/app
git commit -m "feat(방치): 곤충 타격 연출 — 자기 리듬·공격 자세·상극은 초록 숫자"
```

---

### Task 6: 지역 속성을 화면에 보여준다

**Files:**
- Modify: `packages/app/lib/features/play/play_screen.dart:1487` 부근 (전투 HUD)
- Modify: `packages/app/lib/features/roadmap/roadmap_screen.dart` (칸마다 속성 아이콘)
- Modify: `packages/app/lib/l10n/app_ko.arb`, `app_en.arb`, `app_ja.arb`

**Interfaces:**
- Consumes: Task 1 의 `RegionConfig.element`,
  `elementIcon`(`packages/app/lib/ui/labels.dart:52`)·`elementLabel`(`:31`)

- [ ] **Step 1: ARB 에 문구를 넣는다**

`app_ko.arb`:
```json
  "regionElementTitle": "지역 속성",
  "regionElementHint": "이 속성을 克하는 곤충을 끼면 그 곤충의 타격이 세져요",
```
`app_en.arb`:
```json
  "regionElementTitle": "Region element",
  "regionElementHint": "Equip bugs whose element overcomes it and their hits get stronger",
```
`app_ja.arb`:
```json
  "regionElementTitle": "地域の属性",
  "regionElementHint": "この属性を克する昆虫を装備すると、その攻撃が強くなります",
```

Run: `cd packages\app ; flutter gen-l10n`

- [ ] **Step 2: 전투 HUD 에 아이콘을 단다**

`_combatViewport`(`:1311`) 안, 적 HP 바(`:1487-1495`) 근처에 지역 속성 아이콘을 놓는다.
누르면 `showGameDialog` 로 `regionElementTitle` + `regionElementHint` 를 띄운다.

```dart
              // 안 보이면 편성을 바꿀 이유가 생기지 않아 이 시스템 전체가
              // 죽는다(스펙 §4.4). 아이콘 하나가 이 기능의 진입로다.
              if (region.element != null)
                elementIcon(region.element!, size: 18),
```

- [ ] **Step 3: 로드맵 칸에도 단다**

`roadmap_screen.dart` 의 칸(스테이지) 위젯에서 `run.regionForStage(stageNumber).element` 를
읽어 같은 아이콘을 작게 붙인다. **다음 지역의 속성을 미리 보고 편성을 준비**할 수 있어야 한다.

- [ ] **Step 4: 확인**

Run: `cd packages\app ; flutter analyze`
Expected: No issues found

Run: `cd packages\app ; flutter test`
Expected: PASS

- [ ] **Step 5: 커밋**

```bash
dart format .
git add packages/app
git commit -m "feat(방치): 지역 속성을 전투 HUD·로드맵에 표시"
```

---

### Task 7: 밸런스 검증

**Files:**
- Modify: `packages/core_run/tool/balance_sim.dart:556` 부근(`_outsideBaselineAttack`), `:903-993`(`_parseArgs`)
- Modify: `docs/superpowers/specs/2026-09-08-pet-attackers-design.md` (§6 표에 실측값)

**Interfaces:**
- Consumes: Task 2·3 의 함수와 설정

- [ ] **Step 1: 작업 전 기준선을 먼저 뜬다**

이 단계를 건너뛰면 **중립성을 증명할 방법이 없다.**

```powershell
cd packages\core_run
git stash
dart run tool/balance_sim.dart > ..\..\baseline_before.txt
git stash pop
```

- [ ] **Step 2: 시뮬에 옵션을 붙인다**

`_parseArgs`(`:903-993`)에 `--pet-restrain=<0~3>` 를 더한다 — **상극이 걸린 곤충 수**다.
`_outsideBaselineAttack`(`:556`)에서 기준 밖 배율에 다음을 곱한다:

```dart
  // 상극은 §7 기준 밖이다 — 곤충 지분 중 상극이 걸린 몫만큼만 늘어난다.
  final petShare =
      petAttackMult <= 1 ? 0.0 : (petAttackMult - 1) / petAttackMult;
  final restrainedShare = petShare * (_petRestrainCount / 3.0);
  mult *= 1 + restrainedShare * (_petRestrainMult - 1);
```

정확한 변수명(`petAttackMult`, `mult`)은 `balance_sim.dart:540-570` 을 열어 그대로 맞춘다.
**`playerAttack`(기준)에는 절대 곱하지 않는다** — 곱하면 시뮬 안에서 스스로 상쇄되어
0 이 나온다(`:47-60` 주석이 정확히 그 사고를 기록해 두었다).

- [ ] **Step 3: 상극 0으로 돌려 중립을 확인한다**

Run: `cd packages\core_run ; dart run tool/balance_sim.dart --pet-restrain=0`

Expected: `── 결과 ──` 의 최종보스 도달 일수가 `baseline_before.txt` 와 **동일**.
다르면 분배가 중립이 아니다 — Task 2 의 `splitAttack` 이나 Task 4 의 `perHitFull` 을
의심한다(플레이어 지분을 두 번 곱한 게 가장 흔한 실수다).

- [ ] **Step 4: 상극 3으로 돌려 상한을 확인한다**

Run: `cd packages\core_run ; dart run tool/balance_sim.dart --pet-restrain=3`

Expected: 최종보스 도달 일수가 **20% 안쪽**으로 단축. 그 이상이면 `petRestrainMult` 를
JSON 에서 낮춘다(코드가 아니라 JSON — §6).

- [ ] **Step 5: 결과를 스펙에 적는다**

`docs/superpowers/specs/2026-09-08-pet-attackers-design.md` §6 표에 실측 일수를 적는다.
이 숫자가 다음 사람이 `petRestrainMult` 를 만질 때의 기준선이 된다.

- [ ] **Step 6: 임시 파일을 지우고 커밋**

```powershell
Remove-Item baseline_before.txt
```

```bash
dart format .
git add packages/core_run docs
git commit -m "test(밸런스): balance_sim 에 상극 반영 + 실측값 기록"
```

---

## 완료 조건

- [ ] `dart test`(core_models·core_battle·core_run) 전부 통과
- [ ] `cd packages\app ; flutter analyze` 무이슈, `flutter test` 전부 통과
- [ ] `balance_sim --pet-restrain=0` 이 작업 전과 **같은** 일수
- [ ] 실기에서: 곤충 3마리가 각자 리듬으로 때리고, 상극 지역에서 초록 숫자가 뜨고,
      곤충을 다 빼면 오늘과 같은 화면
- [ ] `docs/PROJECT_STATUS.md` 에 한 줄 추가
