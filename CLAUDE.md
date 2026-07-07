# CLAUDE.md — Bug Champ (곤충 채집 배틀 게임)

> 이 파일은 Claude Code가 매 세션 로드하는 프로젝트 헌법이다.
> 여기 적힌 **기획 확정사항·아키텍처 규칙**은 사용자의 명시적 승인 없이 변경하지 않는다.

---

## 1. 프로젝트 개요

- **장르**: 방치형 채집 + 개체 수집·육성 + 비동기 PvP
- **플랫폼**: iOS / Android, 글로벌 출시
- **언어**: ko / en / ja (텍스트 하드코딩 금지, ARB 기반)
- **개발 형태**: 1인 개발, Windows + PowerShell 환경

---

## 2. 게임 핵심 규칙 (기획 확정 — 임의 변경 금지)

수치의 **구체적 값**은 코드가 아니라 `packages/app/assets/data/*.json` 에 존재한다.
아래는 **규칙(모델·공식)의 정의**이며, 계수를 바꿀 땐 JSON을 바꾼다.

### 2.1 개체 시스템 — 곤충 = 종(Species) × 개체 변수(Individual)
- **종(Species)**: 5등급(일반/고급/희귀/영웅/전설), 기본 스탯 `HP/ATK/DEF/SPD`,
  주특기 1개(`치기`/`집기`/`던지기`), 사이즈 범위(mm, min~max).
- **개체(IndividualBug)**:
  - **사이즈**: 종 범위 내 **정규분포** 롤 → 스탯 배율 **0.85 ~ 1.20** 로 선형 매핑.
  - **포텐셜**: 1~5성. 강화 상한 레벨 = `포텐셜 × 10`.
  - **기질**: 호전적/신중/교활/우직/변덕 — 전투 AI의 기술선택 성향.
  - **성별**: ♂/♀ (브리딩 조건).

### 2.2 부위 강화
| 부위 | 효과 | 재료 |
|------|------|------|
| 뿔·큰턱 | ATK +4%/Lv | 채집 부산물 |
| 표피 | DEF +4%/Lv | 〃 |
| 날개 | SPD +3%/Lv, 회피 +0.3%p/Lv | 〃 |
| 체격 | HP +5%/Lv | 〃 |

재료 종류: `키틴조각 / 미네랄 / 수액결정 / 곤충젤리`.

### 2.3 전투 (core_battle, 완전 결정론)
- 3마리 팀, **1:1 순차전**, 라운드제(최대 20R), **시드 기반 완전 결정론**.
- 매 라운드: 양측 기술 선택(기질 가중치 확률) → **상성** `치기 > 집기 > 던지기 > 치기` → 승자만 공격.
- 데미지: `DMG = ATK × 1.0 × 1.5(상성승) × 1.3(주특기 일치) × 100/(100+DEF)`
- **회피 성공 시 데미지 50% 경감**.
- 동일 기술 무승부 시 **양측 HP 3% 소모**.
- 20R 종료 시 **HP% 판정**, 동률이면 **SPD 승**.
- ⚠️ **결정론 필수**: 모든 무작위는 주입된 `Random(seed)` 로만. 전역 `Random()`/시간 기반 시드 금지.
  `simulate(seed, teamA, teamB) → BattleResult`.

### 2.4 채집 (방치)
- **트랩 슬롯 3개**. `필드 × 트랩` 조합별 출현 테이블.
- **오프라인 보상 최대 8시간 누적**.

### 2.5 브리딩
- 같은 종 ♂+♀ → `알 → 유충 → 번데기 → 성충` 타이머.
- 사이즈: **부모 평균 ± 변이**, 5% 확률 **돌연변이 대물림**.
- 포텐셜 상속: **유지 60% / 상승 10% / 하락 30%**.

### 2.6 수익화
- 보상형 광고(AdMob) + IAP(광고제거 스타터 패키지 / 젤리 / 스킨).
- ❌ **스탯 직접 판매 금지** (P2W 방지 원칙).

---

## 3. 기술 스택 (확정)

| 영역 | 선택 |
|------|------|
| 프레임워크 | Flutter + Dart |
| 상태관리 | Riverpod |
| 로컬 저장 | Hive (`schemaVersion` 마이그레이션 포함) |
| 백엔드 | Supabase (비동기 PvP·리더보드 — **Phase 4**에서 연동, 지금은 인터페이스만) |
| 전투 로직 | `core_battle` 순수 Dart 패키지 (Flutter 의존 금지) |
| 다국어 | ARB (ko/en/ja) |
| 시간 | 서버시간 보정 인터페이스 추상화 (초기 로컬, 추후 교체) |

---

## 4. 폴더 구조 (pub workspace 멀티패키지)

```
BugChamp/
├── CLAUDE.md
├── pubspec.yaml                 # 워크스페이스 루트 (resolution: workspace 멤버 나열)
├── packages/
│   ├── core_models/            # 순수 Dart. 데이터 모델·enum·롤 로직. Flutter/Hive/Riverpod import 금지.
│   │   ├── lib/
│   │   └── test/
│   ├── core_battle/            # 순수 Dart. simulate(). core_models 에만 의존. Flutter 금지.
│   │   ├── lib/
│   │   └── test/
│   └── app/                    # Flutter 앱. UI·Riverpod·Hive·assets·다국어.
│       ├── lib/
│       │   ├── data/           # JSON 로더, 리포지토리
│       │   ├── domain/         # 방치 루프 등 게임 서비스
│       │   ├── features/       # home / collect / storage 등 화면별
│       │   └── l10n/           # ARB
│       ├── assets/
│       │   └── data/           # ★ 모든 게임 수치 JSON (species.json, traps.json, fields.json, ...)
│       └── test/
```

**의존 방향(엄수)**: `app → core_battle → core_models`.
core_models 는 어떤 상위 패키지도 모른다. 역참조·순환 금지.

---

## 5. 코딩 컨벤션

- **순수 패키지(core_models, core_battle)** 에서 `flutter`, `hive`, `riverpod`, `dart:ui` import **금지**. 위반 시 아키텍처 위반으로 취급.
- **결정론**: 게임 무작위는 반드시 **주입된 seed 기반 `Random`**. 전역 `Random()`·`DateTime.now()` 기반 롤 금지 (시간은 주입된 clock 인터페이스로).
- **모델**: 불변(immutable). `copyWith`, `fromJson`/`toJson` 제공. (Hive TypeAdapter/영속화는 **app 레이어**에서 처리 — 모델은 저장소를 모른다.)
- **네이밍**: 파일 `snake_case.dart`, 타입 `PascalCase`, 상수 `lowerCamelCase`.
- **텍스트**: UI 문자열 하드코딩 금지 → ARB(`AppLocalizations`). 종 이름 등 게임 데이터의 다국어는 JSON 내 `{ "ko":..., "en":..., "ja":... }` 필드.
- **포맷/린트**: `dart format .` + `flutter analyze` 통과 필수. lints 패키지 기준.
- **테스트**: 사이즈 정규분포 롤·오프라인 보상 계산·전투 결정론은 **반드시 단위테스트** 동반.

---

## 6. ★ 게임 수치 규칙 (최우선 규칙)

> **게임 밸런스 수치(종 스탯, 강화 계수, 출현 확률, 타이머, 드롭율 등)는
> 오직 `packages/app/assets/data/*.json` 에서만 정의·수정한다.**

- Dart 코드에 밸런스 상수를 **매직넘버로 넣지 않는다**. 계수는 JSON → 로더 → 모델 주입.
- 예외: 순수 *구조적* 상수(트랩 슬롯 3개, 최대 20R, 오프라인 상한 8h 같은 **기획 확정 규칙값**)는
  코드 상수로 두되 `game_rules.dart` 한 곳에 모으고 이 파일 §2 와 일치시킨다.
- **이미지 애셋 경로도 데이터로**: 종/필드/트랩 이미지는 `species.json→"image"`, `fields.json→"bg"`, `traps.json→"icon"` 로 참조. 코드에 이미지 경로 하드코딩 금지. 애셋 없으면 UI 가 아이콘/이모지/그라데이션으로 폴백(파일명 = JSON id). 아트 생성 가이드는 `docs/art_prompts.md`.
- 밸런싱 요청 = "JSON 고쳐줘". 밸런싱 때문에 Dart 로직을 고쳐야 한다면 그건 설계 결함 신호.

---

## 7. PowerShell 환경 주의사항 (Windows)

- 셸은 **PowerShell**. 명령 연결 `&&` 는 PowerShell 7+ 에서만 동작 — 안전하게 **한 줄에 하나** 또는 `;` 사용.
- 경로 구분자는 `\` (예: `packages\app`). 스크립트/URL 은 `/` 유지.
- 삭제는 `Remove-Item`, 복사는 `Copy-Item`. `rm -rf` 는 쓰지 말 것.
- 장시간 명령(`flutter run`)은 별도 터미널에서. 인터랙티브 로그인 등은 사용자가 `! <command>` 로 직접 실행.

---

## 8. 자주 쓰는 명령

```powershell
# 의존성 설치 (워크스페이스 루트에서 1회)
dart pub get

# 순수 패키지 테스트
cd packages\core_models ; dart test
cd packages\core_battle ; dart test

# 앱 테스트 / 정적분석 / 포맷
cd packages\app ; flutter test
flutter analyze
dart format .

# 앱 실행
cd packages\app ; flutter run
```

---

## 9. 로드맵 (현재 = Phase 1, 3주 스코프)

**Phase 1 작업 순서**: CLAUDE.md → 스캐폴드 → 모델+단위테스트 → 데이터 JSON → 방치 루프+단위테스트 → 저장(Hive) → UI(홈/채집/보관함).

- 각 단계 완료 시 **실행·테스트 방법을 보고하고 사용자 승인 후** 다음 단계 진행.
- Supabase 연동은 Phase 4. 지금은 **인터페이스만** 둔다.
