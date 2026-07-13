# Bug Champ — 프로젝트 현황 & 다음 작업 (인계 문서)

> 이 문서는 "지금까지 뭘 만들었고, 다음에 뭘 하면 되는지"를 담은 **작업 재개용 스냅샷**이다.
> 게임 규칙의 원본(헌법)은 `CLAUDE.md`. 단, 아래 §"헌법 드리프트"에 적힌 항목은 CLAUDE.md가 아직 옛 스펙이라 **이 문서가 실제 구현 기준**이다.
> 마지막 갱신: 2026-07 (PvP 아레나 + 오행 전투엔진까지 반영, 전체 점검 후).

---

## 1. 한눈에 보기

- **장르**: 방치형 채집 + 개체 수집·육성 + 비동기 PvP. Flutter/Dart, Riverpod, Hive, ARB(ko/en/ja, **한국어 우선**).
- **패키지 구조**(의존 방향 `app → core_battle/core_run → core_models`):
  - `core_models` — 모델·enum·롤. **오행 `Element`(상극/상생)**, `IndividualBug.element`(랜덤).
  - `core_battle` — **결정론 전투 엔진**(공/방/회 스탠스 + 기력 + 오행). `simulate()`, `initBattle()/step()`.
  - `core_run` — 방치 수학(오프라인 보상), `PetConfig`(수련·돌파·부화기), buff/craft/enhance/mission/daily/gift/roadmap 설정.
  - `core_gathering` — 레거시 트랩 채집(v1, 현재 UI 미사용).
  - `app` — UI·저장·데이터·다국어.
- **검증 상태**: 전체 테스트 114개 통과, 5개 패키지 analyze 무결, 데이터 정합성 통과(이미지 38장·종 20·로드맵 1–40·버프 5·ko↔en 키 동기화).
- **세이브 스키마**: `kSaveSchemaVersion = 11` (마이그레이션 v0→v11 전부 존재).

---

## 2. 완료된 시스템 (기능 → 코드/데이터 위치)

| 시스템 | 요약 | 핵심 위치 |
|---|---|---|
| 방치 사이드스크롤 전투 | Ticker 자동타격, 서식지/보스, 오프라인 정산 | `features/play/play_screen.dart`, `core_run/run_math.dart` |
| 상단 HUD | 초상화/능력치카드·골드/다이아·랭킹/메일/설정·버프 스트립·채팅바(placeholder) | play_screen `_topBar` |
| 광고 버프 5종 | 황금러시/성장가속/광폭화/채집가/행운의바람, 누적 6h | `buffs.json`, `core_run/buff_config.dart` |
| 미션(순차) | 몬스터/보스/강화, 완료칸 탭 수집 | `missions.json`, `mission_config.dart` |
| 채집함(그리드) | 아이콘 정렬·등급 액자·상세 팝업 | `features/storage/storage_screen.dart` |
| 펫(신수) 장착 3슬롯 | 캐릭터 뒤 동행, 보너스 | play_screen `_petStats`, storage `_equipStrip` |
| 진화 + **부화기** | 알→유충은 **부화기 슬롯**에서만(자동진화 폐지), 등급별 시간, 수동 수령, 캡슐 3슬롯 UI(젤리 확장) | `pet_config.dart`, storage `_showIncubator`/`_capsule` |
| 합성 / 부위강화 / 분해 | 포텐셜↑ / §2.2 4부위 / 젤리 환원 | save_controller, `enhance.json` |
| **수련 + 돌파** | 성충 레벨(골드), 상한 도달 시 돌파(재화+타이머), **젤리 즉시완료** | `pet_config.dart` tierCaps/breakthrough*, storage `_trainRow` |
| 재화 경제 | 골드/키틴·미네랄·수액/젤리(프리미엄) | 전역 |
| 일일보상 | 점심 12시/저녁 18시(로컬), 편지함 | `daily.json`, `claimDaily` |
| 깜짝 선물 | 온라인 중 주기 도착, 3h 만료, **광고 2배**, ✉ 알림점 | `gifts.json`, `maybeSpawnGift`/`claimGift` |
| 온라인>오프라인 | `offlineEfficiency`(0.3), 복귀 보상 팝업 | run_config, play_screen `_showOfflineReward` |
| 로드맵 | 난이도 4챕터(쉬움~극한) 세로 지도, 배너 탭 진입, **첫 클리어 보상** | `roadmap.json`, `features/roadmap/roadmap_screen.dart` |
| **PvP(곤충 결투)** | 하단 전투 탭, 팀 편성(성충3), 로컬 상대 생성, **전투 아레나 애니메이션**, 트로피 | `features/battle/battle_screen.dart` + `battle_arena.dart` |
| 공용 팝업 테마 | 다크그린+허니, 보상 나열 | `ui/game_dialog.dart` |
| 시스템 | 뒤로가기(탭→홈/홈→종료), 데이터 초기화, 개발자 모드(**디버그 전용**) | app_shell, play_screen |
| 이미지 | 곤충 38장(누끼·측면), 버프 5, 부화기 캡슐 | `assets/images/` |

---

## 3. 전투 엔진 현행 스펙 (★ CLAUDE.md §2.3 대체)

CLAUDE.md는 아직 "치기/집기/던지기"로 적혀 있으나 **실제 구현은 아래**다. (사장님과 합의해 변경한 것)

- **스탠스 RPS**: 매 라운드 **공격 / 방어 / 회복** 중 선택 → 상성 **공격 > 회복 > 방어 > 공격**.
- **기력(에너지)**: 시작 1, 최대 3. 공격 +1 / 방어·회복 −1. 기력 0이면 공격만 → **무한 힐·방어 스톨 방지**.
- **오행 상극(克)**: 내 속성이 상대를 克하면 데미지 **×1.5**. (水火·火金·金木·木土·土水)
- **오행 상생(生) 순서 시너지**: 앞 슬롯이 뒤 슬롯을 生하게 배치하면 **팀 공격/회복 배율↑**(연결당 +10%). → **순서 전략의 핵심**. (木火·火土·土金·金水·水木)
- **기질 = 오토 스탠스 성향**(호전→공/신중→방/교활→변수/우직→선호고집/변덕→랜덤). 기존 주특기(치/집/던)는 **선호 스탠스**로 매핑(공/방/회).
- **판정**: 3v3 1:1 순차, 최대 20R, 20R 시 HP% → 동률 SPD.
- **결정론 유지**: `simulate(seed, teamA, teamB)`. **수동용 `initBattle()+step(playerAStance:)`** 이미 구현됨(수동 배틀 화면만 붙이면 됨).
- 스탠스별 조합/배율은 `core_battle/lib/src/core_battle_base.dart` 참조.

---

## 4. 세이브 스키마 & 마이그레이션

`kSaveSchemaVersion = 11`. 필드 추가 이력:
- v4 닉네임·버프 / v5 미션 / v6 장착 / v7 일일보상 / v8 선물+다음선물시각 / v9 클리어챕터 / v10 부화기(용량+진행) / v11 PvP 트로피.
- 로드 시 **자가치유**: 존재하지 않는 곤충을 가리키는 `incubating` 항목 자동 정리(슬롯 누수 방지).

---

## 5. 알려진 이슈 / 사장님 결정 필요

1. **§6 위반(수치는 JSON)**: PvP 보상이 Dart 하드코딩 — `골드 4000+트로피×30`, `트로피 +12/−8`, `분해 보상=포텐셜`. → **`battle.json` 신설 권장**.
2. **CLAUDE.md 드리프트**(헌법 현행화 필요 — 승인 사항):
   - §2.3 전투: 치/집/던 → **공/방/회+오행+기력** 으로 갱신.
   - 신규 시스템 미기재: 부화기·수련돌파·로드맵·일일보상·깜짝선물·PvP·오행.
   - §2.5 브리딩 **미구현**(로드맵에만 존재).
   - §2.4 트랩 채집(core_gathering)은 **레거시**(현재 UI 없음) — 유지/삭제 결정.
3. `PetConfig.maxLevel`(30) **사문화**(돌파 tierCaps로 대체) — 정리 대상.
4. ja.arb 160키 미번역 — **한국어 우선 방침상 의도됨**(영어 폴백).

---

## 6. 미완성 / 자리표시자

- 채팅 바(placeholder), 랭킹(coming soon), 브리딩(미구현), Supabase 비동기 매칭·리더보드(Phase 4 예정).
- **수동 배틀 화면**(엔진 `step()`은 완비, UI만 필요).
- **부상/회복 시스템**(기획만: KO된 곤충만 회복 타이머, 젤리 즉시회복).

---

## 7. 업그레이드 제안 (우선순위)

1. **수동 배틀 화면** ⭐ — `initBattle()+step(playerAStance:)` 이미 준비. 하단 공/방/회 버튼 → step → 양쪽 수 공개 → 아레나 재생(심리전). 오토와 아레나 위젯 재사용.
2. **부상/회복 시스템** — KO된 곤충만 회복 타이머(등급별), 젤리 즉시회복. 로스터 깊이+과금 연결. (부화기·돌파와 동일 "타이머+젤리" 패턴 재사용)
3. **PvP 보상 JSON화 + 스카우트 보드**(상대 3택1, 새로고침=광고) — §6 준수 + 광고 경제 연결.
4. **리그/티어**(트로피→브론즈~다이아 + 다음 티어 진행바 + 시즌 보상).
5. **아레나 폴리시**: KO 쓰러짐/페이드, 벤치 곤충 슬라이드-인 교대, 克 버스트 VFX, 사운드/햅틱.
6. **순서 ①②③ + 상생 미리보기** UI(현재 3슬롯에 순서·시너지 표시 강화).
7. **CLAUDE.md 현행화**(위 §5-2).

---

## 8. 자주 쓰는 명령 (Windows PowerShell)

```powershell
# 워크스페이스 의존성
dart pub get

# 순수 패키지 테스트
cd packages\core_models ; dart test
cd packages\core_battle ; dart test
cd packages\core_run ; dart test

# 앱: 다국어 생성 / 정적분석 / 포맷 / 테스트 / 실행
cd packages\app
flutter gen-l10n
flutter analyze
dart format .
flutter test
flutter run -d <device-id>   # 예: R3CX5075YNT (SM S928N)
```

> ⚠️ `flutter run`은 반드시 `packages\app` 안에서 실행(루트에서 하면 `lib\main.dart` 못 찾음).
> ⚠️ 큰 원본 이미지 백업 `packages\app\assets\images\bugs\_raw_backup\` 은 `.gitignore` 제외(로컬 전용).

---

## 9. 다음 세션 바로 시작 체크리스트

- [ ] `dart pub get` → `flutter analyze` → `flutter test` 그린 확인
- [ ] 폰 연결 후 `flutter run` (전투 아레나·부화기·로드맵 눈으로 확인)
- [ ] 위 §7에서 다음 작업 1개 선택 (추천: **수동 배틀 화면**)
