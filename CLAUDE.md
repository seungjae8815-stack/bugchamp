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
  주특기 1개(`치기`/`집기`/`던지기` → 전투에서 **선호 스탠스**로 매핑), 사이즈 범위(mm, min~max).
- **개체(IndividualBug)**:
  - **오행 속성(Element)**: 목/화/토/금/수 중 1개(랜덤). 전투 상극(克)·상생(生)에 사용 → §2.3.
  - **사이즈**: 종 범위 내 **정규분포** 롤 → 스탯 배율 **0.85 ~ 1.20** 로 선형 매핑.
  - **포텐셜**: 1~5성. 강화 상한 레벨 = `포텐셜 × 10`. 돌파(§2.7)로 성충 수련 상한 확장.
  - **기질**: 호전적/신중/교활/우직/변덕 — 전투 오토 **스탠스 선택 성향**.
  - **성별**: ♂/♀ (브리딩 조건).
  - **생애주기**: 알 → 유충 → 번데기 → 성충(부화기·경과시간으로 진화 §2.7).

### 2.2 부위 강화
| 부위 | 효과 | 재료 |
|------|------|------|
| 뿔·큰턱 | ATK +4%/Lv | 채집 부산물 |
| 표피 | DEF +4%/Lv | 〃 |
| 날개 | SPD +3%/Lv, 회피 +0.3%p/Lv | 〃 |
| 체격 | HP +5%/Lv | 〃 |

재료 종류: `키틴조각 / 미네랄 / 수액결정 / 곤충젤리`.

### 2.3 전투 (core_battle, 완전 결정론)
> ⚠️ 2026-07 개편: 기존 "치기/집기/던지기" 상성을 **공/방/회 스탠스 + 오행 + 기력**으로 교체(사장님 합의).
- 3마리 팀, **1:1 순차전**, 라운드제(최대 20R), **시드 기반 완전 결정론**.
- **스탠스 RPS**: 매 라운드 **공격 / 방어 / 회복** 중 선택(기질 가중치 확률) → 상성 **공격 > 회복 > 방어 > 공격**.
- **기력(에너지)**: 시작 1, 최대 3. 공격 `+1` / 방어·회복 `−1`. 기력 0이면 **공격만** 가능(무한 힐·방어 스톨 방지).
- **오행 상극(克)**: 내 속성이 상대를 克하면 데미지 **×1.5** (水火·火金·金木·木土·土水).
- **오행 상생(生) 순서 시너지**: 편성 순서에서 앞 슬롯이 뒤 슬롯을 生하면 팀 공격/회복 배율 **연결당 +10%**
  (木火·火土·土金·金水·水木) → **순서가 전략의 핵심**.
- 데미지: `DMG = ATK × (스탠스 조합 배율) × (상생 시너지) × 1.5(상극 시) × 100/(100+DEF)`. 회복 = 최대HP의 일정%.
- **주특기(치/집/던)** = 개체의 **선호 스탠스**(공/방/회), **기질** = 오토 스탠스 성향.
- 20R 종료 시 **HP% 판정**, 동률이면 **SPD 승**.
- API: 오토 `simulate(seed, teamA, teamB) → BattleResult`, **수동 `initBattle()+step(playerAStance:)`**(심리전 화면).
- 스탠스별 조합/배율·기력 규칙은 `core_battle/lib/src/core_battle_base.dart` 참조.
- ⚠️ **결정론 필수**: 모든 무작위는 주입된 `Random(seed)` 로만. 전역 `Random()`/시간 기반 시드 금지.

### 2.4 채집 (방치)
- **현행**: 횡스크롤 방치 런(`core_run`) — 서식지/보스 자동타격으로 곤충·재화 획득, **오프라인 보상 상한 8시간**.
- **레거시**: v1 트랩 채집(`core_gathering`, 필드×트랩 출현 테이블)은 **현재 UI 미사용**(세이브 호환용 잔존).

### 2.5 브리딩 — ⚠️ 미구현 (로드맵 예정)
- (계획) 같은 종 ♂+♀ → `알 → 유충 → 번데기 → 성충` 타이머.
- (계획) 사이즈 **부모 평균 ± 변이**, 5% 확률 돌연변이 / 포텐셜 상속 **유지60·상승10·하락30**.
- 현재 알→성충 진화는 **부화기(§2.7)**로만 진행(브리딩 산란은 아직 없음).

### 2.6 수익화
- 보상형 광고(AdMob) + IAP(광고제거 스타터 패키지 / 젤리 / 스킨). *현재 광고는 플레이스홀더(테스트 지급).*
- ❌ **스탯 직접 판매 금지** (P2W 방지 원칙).

### 2.7 육성·전투 부가 시스템 (현행 구현)
- **부화기**: 알→유충은 부화기 슬롯에서만(등급별 시간·수동 수령, 젤리 확장). 유충→성충은 경과시간 자동.
- **수련·돌파**: 성충 레벨업(골드), 상한 도달 시 돌파(재화+타이머, 젤리 즉시완료)로 상한 확장.
- **PvP(곤충 결투)**: 성충3 팀, **스카우트 보드(상대 3택1·난이도 티어)**, 오토/수동 2모드, 트로피.
- **리그/시즌**: 트로피→브론즈~다이아 등급·승급 보상, **N일 시즌 종료 시 소프트리셋+최고등급 보상**.
- **부상/회복**: 결투 KO 곤충은 등급별 회복 타이머 동안 편성 불가(젤리 즉시회복).
- **버프/미션/일일보상/깜짝선물/펫(장착)/로드맵(난이도 챕터)**: 방치 루프 부가.
- 이 부가 시스템의 수치도 모두 JSON(`buffs/missions/pets/daily/gifts/roadmap/battle.json`).

---

## 3. 기술 스택 (확정)

| 영역 | 선택 |
|------|------|
| 프레임워크 | Flutter + Dart |
| 상태관리 | Riverpod |
| 로컬 저장 | Hive (`schemaVersion` 마이그레이션 포함) |
| 백엔드 | Supabase (비동기 PvP·리더보드 — **Phase 4**에서 연동, 지금은 로컬 상대·인터페이스만) |
| 전투 로직 | `core_battle` 순수 Dart 패키지 (오행·기력·스탠스. Flutter 의존 금지) |
| 방치 수학·설정 | `core_run` 순수 Dart (오프라인 보상·펫·부화기·돌파·버프·전투보상 등 config) |
| 다국어 | ARB (ko/en/ja, **한국어 우선**) |
| 시간 | 서버시간 보정 인터페이스(`clock`) 추상화 (초기 로컬, 추후 교체) |

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
│   ├── core_battle/            # 순수 Dart. simulate()/initBattle()/step(). 오행·기력. core_models 에만 의존.
│   │   ├── lib/
│   │   └── test/
│   ├── core_run/               # 순수 Dart. 방치 수학(오프라인 보상) + 설정 모델
│   │   ├── lib/                #   (PetConfig·BattleConfig·Buff/Craft/Enhance/Mission/Daily/Gift/Roadmap).
│   │   └── test/               #   core_models 에만 의존. Flutter 금지.
│   ├── core_gathering/         # 순수 Dart. 레거시 v1 트랩 채집(현재 UI 미사용).
│   └── app/                    # Flutter 앱. UI·Riverpod·Hive·assets·다국어.
│       ├── lib/
│       │   ├── data/           # JSON 로더(game_data), 세이브 리포지토리·마이그레이션
│       │   ├── domain/         # save_controller(세이브 상태·액션), 방치 서비스, clock
│       │   ├── features/       # play / storage / battle / roadmap 등 화면별
│       │   └── l10n/           # ARB
│       ├── assets/
│       │   ├── data/           # ★ 모든 게임 수치 JSON (species·traps·fields·spawns·run_config·
│       │   │                   #    buffs·enhance·craft·missions·pets·daily·gifts·roadmap·battle.json)
│       │   └── images/         # 곤충·서식지·보스·버프·부화기 등 아트
│       └── test/
```

**의존 방향(엄수)**: `app → core_battle / core_run → core_models` (core_gathering 도 core_models 만).
core_models 는 어떤 상위 패키지도 모른다. core_run 은 core_battle 을 모른다(형제). 역참조·순환 금지.

---

## 5. 코딩 컨벤션

- **순수 패키지(core_models, core_battle, core_run, core_gathering)** 에서 `flutter`, `hive`, `riverpod`, `dart:ui` import **금지**. 위반 시 아키텍처 위반으로 취급.
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
cd packages\core_run ; dart test

# 앱: 다국어 생성 / 테스트 / 정적분석 / 포맷
cd packages\app
flutter gen-l10n          # ARB 수정 후 필수(생성 코드 갱신)
flutter test
flutter analyze
dart format .

# 앱 실행 (반드시 packages\app 안에서)
cd packages\app ; flutter run -d <device-id>
```

> 상세 현황·다음 작업은 `docs/PROJECT_STATUS.md`(작업 재개용 스냅샷)를 함께 볼 것.

---

## 9. 로드맵 / 진행 단계

**Phase 1~3 (대부분 완료)**: 모델·전투엔진·방치 루프·저장(Hive/마이그레이션)·UI(플레이/보관함/전투) +
버프·미션·펫·부화기·수련돌파·로드맵·일일보상·깜짝선물·PvP(오행 전투·수동배틀·스카우트·리그·시즌)·아레나 폴리시까지 구현.

**남은 큰 축**
- **Phase 4 (백엔드)**: Supabase 비동기 PvP 매칭·리더보드 연동(현재 로컬 상대·인터페이스만).
- **브리딩(§2.5)**: 아직 미구현.
- **수익화 실연동**: AdMob 실광고·IAP(현재 광고는 플레이스홀더).
- 세부 다음 작업·우선순위는 **`docs/PROJECT_STATUS.md` §7**(업그레이드 제안) 참조 — 완료 항목이 체크되어 있음.

**진행 원칙**
- 각 단계 완료 시 **실행·테스트 방법을 보고하고 사용자 승인 후** 다음 단계 진행(단계별 게이트).
- 기능은 **한국어로 먼저 완성**, 타 언어(en/ja)는 나중(영어 폴백).
