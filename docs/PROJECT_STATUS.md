# Bug Champ — 프로젝트 현황 & 다음 작업 (인계 문서)

> 이 문서는 "지금까지 뭘 만들었고, 다음에 뭘 하면 되는지"를 담은 **작업 재개용 스냅샷**이다.
> 게임 규칙의 원본(헌법)은 `CLAUDE.md` (2026-07-15 현행화 완료 — 전투·신규 시스템 반영). 이 문서는 상세 현황·다음 작업 스냅샷.
> 마지막 갱신: 2026-08-11 (**1.0.5 안드로이드 출시** — 캐릭터 탭(장비 8부위·공방 제련·씬 채집 미니게임)·서버 위조 개체 차단·구버전 하드컷.
> ⚠️ 20260810 빌드가 **dart-define 없이 나가는 사고**(로그인·채팅·동기화 전멸) → 20260811 로 재출시. 재발 방지는 release_cadence.md §5 체크리스트.
> 그 전 2026-08-08 (**성장 밸런스 개편** — 적응형 몬스터 체력·주간 시즌·접속 보너스·체력 숫자 숨김. 그 전 2026-08-06 (**결투 티켓** — PvP 하루 판수 제한. 그 전 2026-07-18 (**Phase 4 Inc.2 — 진짜 비동기 대전**: 방어팀 등록 `registerDefender` + 스카우트 보드가 실 유저 방어팀 `fetchOpponents`. 그 전 2026-07-15: 수동 배틀·부상/회복·PvP 보상 JSON화·스카우트 보드·리그/티어·시즌 리셋·아레나 폴리시. 그 전: PvP 아레나 + 오행 전투엔진))).

---

## 1. 한눈에 보기

- **장르**: 방치형 채집 + 개체 수집·육성 + 비동기 PvP. Flutter/Dart, Riverpod, Hive, ARB(ko/en/ja, **한국어 우선**).
- **패키지 구조**(의존 방향 `app → core_battle/core_run → core_models`):
  - `core_models` — 모델·enum·롤. **오행 `Element`(상극/상생)**, `IndividualBug.element`(랜덤).
  - `core_battle` — **결정론 전투 엔진**(공/방/회 스탠스 + 기력 + 오행). `simulate()`, `initBattle()/step()`.
  - `core_run` — 방치 수학(오프라인 보상), `PetConfig`(수련·돌파·부화기·**부상회복**), buff/craft/enhance/mission/daily/gift/roadmap 설정.
  - `core_gathering` — 레거시 트랩 채집(v1, 현재 UI 미사용).
  - `app` — UI·저장·데이터·다국어.
- **검증 상태**(2026-08-11): core_models 58 · core_battle 10 · core_run 124 · core_save 41 · **server 241** · 앱 137 = **총 611 통과**, 전 패키지 analyze 무결.
- **세이브 스키마**: `kSaveSchemaVersion = 18` — 이후 추가 필드는 **버전을 올리지 않는 호환 필드**(§4).
- **출시 상태**: 안드로이드 **1.0.5+20260811**(프로덕션) · iOS 1.0.4 심사 중(통과 시 1.0.5 제출).
  버전 게이트: 공용 min=20260810(1.0.4 이하 하드컷), `LATEST_VERSION_ANDROID` 는 프로덕션 반영본과 일치시킨다.

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
| 온라인>오프라인 | `offlineEfficiency`(0.3), 복귀 보상 팝업, **접속 골드 보너스 +60%**(직접 처치만) | run_config `onlineGoldBonus`, play_screen `_showOfflineReward` |
| **적응형 몬스터 체력** | 몬스터 체력이 **영구 전력(업그레이드+펫)** 에 맞춰 상승 — 초반 1방 방지. 버프·탭부스트는 기준 제외, 월드 관문은 보정 없음. 체력 **숫자는 보스만** 노출 | `run_config.json` `hpAdapt*`, `core_run/run_math.dart` `habitatMaxHp/bossMaxHp`, `core_run/tool/balance_sim.dart` |
| 로드맵 | 난이도 4챕터(쉬움~극한) 세로 지도, 배너 탭 진입, **첫 클리어 보상** | `roadmap.json`, `features/roadmap/roadmap_screen.dart` |
| **PvP(곤충 결투)** | 하단 전투 탭, 팀 편성(성충3), **스카우트 보드(상대 3택1·난이도 티어)**, **자동/수동 2모드**, 트로피, 보상 `battle.json` | `features/battle/battle_screen.dart` + `battle_arena.dart` |
| **리그/티어 + 시즌** | 트로피→브론즈~다이아·진행바·**승급 보상 1회**, **주간 시즌(KST 월 09:00) 종료 시 소프트리셋(×0.5)+최고등급 보상(×3)** | `battle.json` leagues/season, `BattleConfig.leagueFor/season*`, `claimLeagueRewards`·`SeasonReport`, 리그 패널·시즌 다이얼로그 |
| **아레나 폴리시** | 파이터 슬라이드-인/아웃 교대, 오행 克 링 버스트, 햅틱 | `arena_widgets.dart`(ArenaFighter AnimatedSwitcher·`BurstFx`/`ArenaBurst`), 오토·수동 공용 |
| **순서·상생 미리보기** | 편성 슬롯 ①②③ 순서 배지 + 상생(生) 연결 화살표·팀 시너지% 미리보기 | battle_screen `_orderBadge`/`_synergyBar`, `teamSynergy`(core_battle) 재사용 |
| **브리딩(§2.5)** | 같은 종 ♂+♀ 성충 → 산란 타이머 → **알** 획득(부모평균±변이·돌연변이5%·포텐셜 60/10/30) → 부화기로 육성. 슬롯제·젤리 | `IndividualBug.breed`, save v15 `breeding`, `startBreeding`/`collectBreeding`, storage `_showBreeding`/짝 피커 |
| **랭킹/백엔드(Phase 4 Inc.1·2)** | `PvpBackend` 인터페이스(리더보드+**`registerDefender`**+**`fetchOpponents`**+`isRemote`) + `LocalPvpBackend`(폴백) + `SupabasePvpBackend`(실연동) + **랭킹 화면**. Inc.2: 진입 시 편성=방어팀 upsert, 스카우트 보드에 **실 유저 방어팀** 병합(파워비율로 티어 배치, 부족분 합성), **승패 직후 `pushTrophies` 로 프로필·방어팀 트로피 라이브 갱신** | `domain/pvp_backend.dart`·`supabase_pvp_backend.dart`, `features/battle/battle_screen.dart`, `features/leaderboard/leaderboard_screen.dart`, `docs/backend_supabase.md` |
| **수동 배틀(심리전)** | 매 라운드 공/방/회 직접 선택 → `step(playerAStance:)` → 양측 동시 공개 + 판정배너·기력 표시, 결착 후 보상 | `features/battle/manual_battle_screen.dart` + 공용 `arena_widgets.dart` |
| **공지·운영우편·선물코드(2026-08-07)** | 셋 다 "서버가 유저에게 보낸다"는 한 시스템. **점검/업데이트 보상 = 전체 발송 우편 한 통**(별도 기능 아님). 지급은 **서버가 확정**하고 앱은 결과 세이브 채택 — 앱이 더하면 골드 급증 상한에 걸려 정당한 보상이 잘린다. 중복 지급은 DB 기본키(`mail_claims`/`code_redemptions`)가 차단. 음수 보상은 무시(운영 실수로 재화를 뺏지 않음) | SQL·운영법 `docs/backend_supabase.md` §12, `state_store.dart`(loadNotices/loadMail/claimMail/loadGiftCode/redeemGiftCode), `GameActions.grantRewardRow`, `/notices`·`/mail`·`/mail/claim`·`/code/redeem`, 앱 `domain/notice_service.dart`·`features/notice/notice_screen.dart`, 편지함 운영우편 섹션, 설정 선물코드 |
| **스토어 리뷰 유도(2026-08-07)** | 챕터 클리어 직후 1회 + 설정 버튼. **보상 없음** — 스토어 API 가 작성 여부·별점을 알려주지 않아 검증이 불가능하고, 플레이·앱스토어 정책이 평점 대가 보상을 금지한다 | `domain/review_service.dart`, save `reviewAsked` |
| **결투 티켓(2026-08-06)** | 결투 1판=티켓 1장. 최대 10, **30분당 1장** 자연충전, 광고 +3장(**하루 30회**), 젤리 10=만땅. 무제한 결투 탓에 트로피 랭킹이 "많이 돌린 사람" 순이 되던 문제를 막는다(실측: 스테이지 86 유저가 스테이지 413 유저의 3.5배 트로피). **서버 소유 필드** — 세이브 편집·구버전 앱으로 못 늘린다 | `battle.json → tickets`, `core_run/battle_config.dart`(`regenTickets`/`consumeTicket`/`grantTickets`/`refillTickets`), save `pvpTickets`·`ticketsAt`·`adUseCounts`·`adUseDate`, `GameActions.consumePvpTicket`/`grantAdTicket`/`refillPvpTickets` + `/pvp/ticket/ad`·`/pvp/ticket/refill`, battle_screen `TicketBar` |
| **부상/회복** | 결투에서 KO된 내 곤충 → 등급별 회복 타이머(부상 중 편성 불가), **젤리 즉시회복**, 채집함 🩹배지·상세카드, 편성 피커 비활성 | `save_game.injured`(v12), `applyBattleResult(koedBugIds:)`/`healInjury`, `pet_config.injuryDuration/Jelly`, `pets.json` |
| **캐릭터 탭(2026-08-11)** | 장비 8부위×10등급(옵션 15종), **공방 제련**(곤충화석→모루 스택 10칸·자동·옵션 필터·망치질 3연타 사운드 동기), 씬에서 **야생 곤충 탭 채집** 미니게임(알로 획득·쿨다운), 한 화면 레이아웃. 펫·스킬 탭은 준비 중 패널 | `features/character/*`, `items.json`·`forge.json`·`skills.json`, `run_config.json` sceneCatch*, save `equippedItems`/`forgeStack` 등 |
| **서버 위조 차단(2026-08-11)** | PvP 편성 시 `IndividualBug.integrityError` 로 스탯 상한 검증(사이즈 종범위·포텐셜·강화총량·수련/돌파, NaN 거름) → `bug_forged:*` 거부. `forgeStack` 서버 상한 10 | core_models `individual_bug.dart`, server `actions.dart` validateTeam/enforceStorage |
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

`kSaveSchemaVersion = 18`. 필드 추가 이력:
- v4 닉네임·버프 / v5 미션 / v6 장착 / v7 일일보상 / v8 선물 / v9 클리어챕터 / v10 부화기 / v11 PvP 트로피 / v12 부상(injured) / v13 승급보상(claimedLeagues) / v14 시즌(seasonStartedAt·seasonPeakTrophies) / **v15 브리딩(breeding·breedingCapacity)**.
- `seasonStartedAt` 은 마이그레이션에서 미표기 → 로드 시 컨트롤러가 now로 초기화(시간을 만들지 않는 원칙).
- **v16 결제(adsRemoved·starterBought·ownedSkins·passExpiresAt) / v17 구매원장(redeemedPurchases) / v18 채팅차단(blockedUserIds)**.
- ⚠️ **버전을 올리지 않는 필드**(호환 필드): `storageCapacity`(2026-08-03),
  `pvpTickets`·`ticketsAt`·`adUseCounts`·`adUseDate`(결투 티켓, 2026-08-06),
  **장비/공방(2026-08-10)**: `equippedItems`·`forgeStack`·`skillLevels`·`equippedSkills`·
  `forgeLevel`·`forgeSteps`·`forgeUpAt`·`autoForgeOptions`·`autoForgeStopOnHit`.
  없으면 기본값으로 읽히므로 구/신 버전이 서로의 세이브를 그대로 읽는다. 버전을 올리면
  서버가 새 세이브를 저장하는 순간 **스토어의 구버전 앱이 "다운그레이드 불가"로 죽는다**.
- ⚠️ **중첩 enum 키는 이 정책의 구멍이다**: `materials` 맵에 새 `MaterialKind`(예: 1.0.5 의
  `fossil`)를 넣으면 **그 재료를 모르는 구버전 앱이 파싱에서 죽는다**(`fromKey` 가 throw).
  → **1.0.6 첫 작업 = 파서 방어**(모르는 키 건너뛰기). 메모: bugchamp-save-parser-hardening.
- 로드 시 **자가치유**: 존재하지 않는 곤충을 가리키는 `incubating`·`injured` 항목 자동 정리(슬롯 누수 방지). `injured` 는 **회복 완료된 항목도 프룬**.

---

## 5. 알려진 이슈 / 사장님 결정 필요

1. **§6 위반(수치는 JSON)**: ✅ **모두 이관 완료**. PvP 보상 → `battle.json`(2026-07-15). 분해 보상 → **`pets.json`/`PetConfig.disassembleJelly`**(2026-07-18, `disassembleJellyBase`+`disassembleJellyPerPotential`, 기본값=포텐셜과 동일). 현재 알려진 밸런스 하드코딩 없음.
2. ~~**CLAUDE.md 드리프트**~~ ✅ **현행화 완료**(2026-07-15).
3. ~~**트랩(core_gathering) 유지/삭제**~~ ✅ **결정: 유지**(2026-07-18). 근거: `TrapInstallation`/`installations`·`unlockedFieldIds` 는 **SaveGame 에 영속**(toJson·마이그레이션 포함)되고 `GatherService`/`gatherServiceProvider`/`GameData.spawnTable`·`trap`·`fields` 에 결합됨. **UI 호출은 완전히 없음(dormant)**이나, 삭제하려면 세이브 스키마 변경 + GameData 로더/에셋(traps/fields/spawns.json) 해체 + 테스트 정리가 필요 → 위험·노력 대비 이득 적음. 격리된 채 컴파일·테스트 통과하므로 **의도적 레거시로 보존**. (되살릴 계획 없어지고 정말 제거 원하면 별도 스코프 작업으로 승인 후 진행)
4. ~~`PetConfig.maxLevel`(30) 사문화~~ ✅ **제거 완료**(2026-07-18, `tierCaps` 로 대체됨. `IndividualBug.maxLevel`=포텐셜×10 강화상한은 별개로 유지).
5. ja.arb 미번역 — **한국어 우선 방침상 의도됨**(영어 폴백).

---

## 6. 미완성 / 자리표시자

- 채팅 바(placeholder).
- **랭킹/비동기 대전** → ✅ 화면 + Inc.1(리더보드) + **Inc.2(방어팀 등록·스카우트 실데이터) 코드 완료**. 남은 것: `docs/backend_supabase.md` §4 에 **`nearby_defenders` RPC SQL 추가 실행** + 2계정 실기로 비동기 대전 확인(승패→트로피 라이브 갱신은 후속). 키/셋업 → `docs/backend_supabase.md`.
- ~~브리딩~~ → ✅ **완료**(2026-07-15). v15 `breeding`, `IndividualBug.breed`, 채집함 브리딩 시트.
- ~~수동 배틀 화면~~ → ✅ **완료**(2026-07-15). `manual_battle_screen.dart`, 오토와 `arena_widgets.dart` 공유.
- ~~부상/회복 시스템~~ → ✅ **완료**(2026-07-15). v12 `injured` 맵, 등급별 타이머+젤리, 채집함/편성 UI 연동.
- ~~PvP 보상 JSON화 + 스카우트 보드~~ → ✅ **완료**(2026-07-15). `battle.json`·`BattleConfig`, 상대 3택1(난이도 티어별 보상배율), 광고 새로고침.
- ~~리그/티어~~ → ✅ **완료**(2026-07-15). v13 `claimedLeagues`, 브론즈~다이아 + 진행바 + 승급 보상.

---

## 7. 업그레이드 제안 (우선순위)

1. ~~**수동 배틀 화면**~~ ✅ **완료**(2026-07-15) — `manual_battle_screen.dart`. 다음 폴리시 여지: 심리전 서스펜스(내 수 먼저 확정→상대 후공개), KO 교대 연출, 克 버스트 VFX.
2. ~~**부상/회복 시스템**~~ ✅ **완료**(2026-07-15) — `injured` v12·`injuryDuration/Jelly`·채집함/편성 UI. 폴리시 여지: 결과 다이얼로그에 "부상 N마리" 표기, 채집함 부상 타이머 라이브 카운트다운(현재는 열 때 렌더값), KO 즉시 회복 광고.
3. ~~**PvP 보상 JSON화 + 스카우트 보드**~~ ✅ **완료**(2026-07-15) — `battle.json`·`BattleConfig`·스카우트 3택1. 폴리시 여지: 리롤 실제 광고 연동(현재 플레이스홀더), 스카우트 세이브 영속화(현재 세션 위젯 상태), 전투 후 자동 리롤.
4. ~~**리그/티어**~~ ✅ **완료**(2026-07-15) — 브론즈~다이아·진행바·승급 보상 1회. **+시즌 리셋도 완료**(아래).
5. ~~**아레나 폴리시**~~ ✅ **완료**(2026-07-15) — 슬라이드-인/아웃 교대(AnimatedSwitcher), 克 버스트 VFX(링), 햅틱(克=medium/수 선택=selection). 남은 여지: KO 쓰러짐 포즈, 사운드(에셋 없음), 벤치 곤충 대기열 표시.
6. ~~**시즌 리셋**~~ ✅ **완료**(2026-07-15) — `battle.json` season(**주간·KST 월 09:00**·리셋0.5·보상×3), v14 `seasonStartedAt`/`seasonPeakTrophies`, 로드 시 정산+다이얼로그. 남은 여지: 시즌 카운트다운 UI, 시즌 랭킹.
7. ~~**순서 ①②③ + 상생 미리보기** UI~~ ✅ **완료**(2026-07-15) — 슬롯 순서 배지 + 상생 연결·팀 시너지% 미리보기. **+슬롯 드래그 순서 변경 완료**(2026-07-18, `Draggable`/`DragTarget` 삽입 재배치·드롭 하이라이트·손가락 피드백). 남은 여지: 상성(克) 상대 대비 미리보기.
8. ~~**CLAUDE.md 현행화**~~ ✅ 완료 — 헌법 §2.3 전투가 공/방/회+오행+기력으로 갱신됨.

### 2026-07-18 ~ 07-20 추가 완료
9. ~~**비동기 PvP 실연동(Inc.2)**~~ ✅ — Supabase `defenders`·`nearby_defenders` RPC, 방어팀 자동 등록, 실 유저 스카우트, 트로피 라이브 갱신. 남은 여지: 재대결 제한, 매칭 폭 정교화.
10. ~~**시즌 카운트다운 UI · 슬롯 드래그**~~ ✅
11. ~~**전투 화면 리디자인**~~ ✅ — VS 매치업 중심, 전투 장소(상대별 고정)·장소 상성(+20% ATK), 상성 원형 휠(수동=선택/자동=표시전용), 수동전투 10초 카운터, 배경 아트(전투 씬 영역 한정).
12. ~~**수익화 기획·상점 UI·패스 효과**~~ ✅ — `iap.json`·`IapConfig`·세이브 v16. `docs/monetization.md`.
13. ~~**로그인 + 클라우드 세이브**~~ ✅ — 구글 로그인 + Supabase `saves` 백업/복원(결제 선행조건).
14. ~~**스킨 실제 적용**~~ ✅ (2026-07-20) — ColorFilter 방식. 상세는 `docs/monetization.md` ④.

### 다음 작업 (1.0.6 — 순서대로)

1. **세이브 파서 방어** ⭐ 첫 작업 — `_materialsFromJson` 이 모르는 재료 키를 건너뛰게.
   새 기능(새 재료·enum)보다 **먼저** 넣어야 1.0.7 에서 재료를 추가해도 1.0.6 이 안 죽는다.
2. ~~**Play Billing 8.0.0**~~ ✅ **완료(2026-08-11, 20260811 에 포함)** — `dependency_overrides`
   로 android 구현만 0.5.0(Billing 8.0.0) 강제. iOS 는 StoreKit1 유지(서버 verifyReceipt 호환).
   gradle 해석으로 `billingclient:billing:8.0.0` 확인. **남은 정리**: iOS 영수증을 JWS 검증으로
   전환하면 오버라이드를 지우고 in_app_purchase 3.3.0 으로 — pubspec 주석 참조.
   ⚠️ **결제 실기 확인 필요**: 20260811 프로덕션에서 젤리 구매 1건 테스트(Billing 6→8 전환 검증).
3. **iOS 1.0.4 통과 즉시 1.0.5 제출** — 공용 min=20260810 하드컷 때문에 iOS 1.0.4 는
   라이브되는 순간 막힌 채 시작한다. Codemagic `ios-release` 워크플로.
4. **펫·스킬 탭 완성** — 지금은 준비 중 패널(`_PetsPanel`/`_SkillsPanel` 코드는 보존,
   `character_screen.dart` 분기만 되돌리면 복구). 펫 슬롯 채집함→캐릭터 이동도 이때.
5. 캐릭터 씬 폴리시 — 하의 아트 반영 확인, 걷기/공격 스프라이트 추가 프레임.

### 남은 큰 축 (기존)
- ~~**in_app_purchase 실연동**~~ ✅ 코드 완료(2026-07-20) — `StoreIapService`·세이브 v17 구매 원장·
  스토어 현지가격 표시·릴리즈 자동 스토어모드. **다음은 사장님의 Play Console 작업** → `docs/play_console_iap.md`.
- **영수증 서버 검증** ⭐ — 매출 나기 전 필수. `docs/monetization.md` §6.
- **릴리즈 키스토어** — `android/key.properties` 만들면 자동으로 그 키로 서명(gradle 연결 완료).
- **⛔ 출시 보류** — **서버 권위 전환** 결정(2026-07-20). `docs/server_authority_design.md`.
  전환 완료 후 콘솔 재제출. 기존 절차는 `docs/RELEASE_CHECKLIST.md`(보존).
  스토어 문안 `docs/store_listing.md`, 방침 `docs/privacy-policy.html`.
- ~~**AdMob 실광고**~~ ✅ 코드 완료(2026-07-20) — `AdMobAdService`. 보상은 광고를 **끝까지 본 경우에만**.
  AdMob 계정/광고단위 ID 는 사장님 작업 → `docs/RELEASE_CHECKLIST.md` B-3.
- **릴리즈 키스토어** + 그 SHA-1 을 Google Cloud 에 등록(안 하면 릴리즈 빌드에서 구글 로그인 실패).

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
- [ ] 폰 연결 후 `flutter run` — 실기 확인 항목:
  - 수동 배틀: 공/방/회 진행·기력 증감·상대수 ❓→공개·판정배너·KO 교대·결과·포기(X)
  - 자동 배틀(아레나 위젯 리팩터 회귀): 재생·1x/2x·건너뛰기·데미지숫자·克 흔들림
  - **부상/회복**: 결투 KO 후 채집함 🩹배지 + 상세 회복카드(타이머·젤리 즉시회복), 편성 피커에서 부상곤충 비활성, 회복 완료 후 복귀
  - **스카우트 보드**: 상대 3택1(약/대등/강 배지·상대 미리보기·보상 미리보기), 카드 탭 선택, 새로고침(광고 플레이스홀더), 난이도별 보상배율(강할수록 골드·트로피↑)
  - **리그/티어**: 전투탭 상단 리그 패널(엠블럼·등급명·🏆·다음 티어 진행바), 트로피 100/300/700/1500에서 등급 변화, 승급 보상 수령 버튼(골드·젤리 일괄) → 재수령 불가
  - **시즌 리셋**: 시즌 만료 시 로드 직후 "시즌 종료" 다이얼로그(최고 등급·트로피 A→B·보상), 트로피 절반 강등 (개발자 모드로 seasonStartedAt 조작해 확인하거나 월요일 09:00 KST 경과 필요)
  - **성장 밸런스(2026-08-08)**: 일반 몬스터가 초반에 **4대 안팎**(1방이 아님), 월드 관문(스테이지 101·201…)에서 확 막힘 → 업그레이드·펫 투자 후 뚫림. **버프(광폭화)를 켜면 확실히 빨라진다**(몬스터가 같이 세지지 않는지)
  - **체력 숫자**: 일반 몬스터·플레이어 게이지에 숫자 없음, **보스만 숫자 표시**
  - **접속 보너스**: 직접 처치 골드가 방치 정산보다 유리한지(깜짝선물도 7~15분마다)
  - **아레나 폴리시**: 곤충 KO/교대 시 **슬라이드 인/아웃**, 오행 克 히트에 **링 버스트** + **햅틱 진동**(폰 실기에서만 체감), 수동 배틀 수 선택 시 가벼운 햅틱
- [ ] **출시**: 안드로이드 우선 · iOS 는 통과할 때마다 따라잡기 → `docs/release_cadence.md`
      (버전·빌드번호 규칙, 플랫폼별 `LATEST_VERSION_*` 갱신 시점)
- [ ] **1.0.5 실기 확인(캐릭터 탭)**: 장비 8칸 그림·등급 바탕색, 모루 두드리기(3연타 소리 동기·연타 차단),
      자동 제련(만석/화석 소진 시 정지), 필터, 쌓인 아이템 열기(바깥 탭=보존), 씬 채집("지금 탭!"→알 획득),
      **백그라운드 복귀 시 연결 확인**(끊김 배너 즉시 갱신)
- [ ] 위 "다음 작업(1.0.6)" 순서대로 — ① 파서 방어 ② **Billing 8(마감 8/31)**
- [ ] 실기 확인은 `docs/DEVICE_CHECKLIST.md` 를 볼 것 (그동안 쌓인 항목 정리됨)
