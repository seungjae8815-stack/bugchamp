# 연구소 · 연구 패스 · 올인원 패스 · 하단 탭 2쪽 — 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 계정 단위 영구 연구(14종 · 레벨제 · 칸 1~3)를 넣어 사냥·육성 타이머·결투/대회 능력치를 올리고, 연구 패스·올인원 패스를 팔고, 하단 탭을 2쪽(⇄ 전환)으로 바꾼다.

**Architecture:** 규칙·수치는 `research.json` → `core_run` `ResearchConfig`(효과·비용·시간 계산, 순수 Dart). 세이브 필드와 시작/완료/칸 구매/드롭은 `core_save` `research_progress.dart` 한 곳(앱·서버 공용). 효과는 기존 배율 사슬 한 곳씩에 끼운다(사냥 `huntStatsUncapped` · 결투 `_buildDuelTeam`/앱 `duelBugFor` · 타이머 호출부). 서버는 업로드마다 연구 레벨·재화 증가를 자른다.

**Tech Stack:** Dart 3 pub workspace (core_run · core_save · core_battle · server(shelf) · app(Flutter, Riverpod)), ARB ko/en/ja, 시뮬 `balance_sim` · `duel_build_sim` · `jelly_sim`.

**Spec:** `docs/superpowers/specs/2026-10-22-research-lab-design.md` (§9 사장님 답이 §3.7 보다 우선)

## Global Constraints

- 수치는 `packages/app/assets/data/research.json` 에만(CLAUDE.md §6). Dart 에 밸런스 매직넘버 금지.
- 순수 패키지에 Flutter/`Random()`/`DateTime.now()` 금지 — rng·now 는 주입(훅이 막는다).
- 연구 재화는 **새 `MaterialKind` 금지, 세이브의 별도 필드**.
- 연구 칸: 기본 1 · `topTier`(0 쉬움 1 보통 2 어려움 3 극한) 2 이상이면 2칸 · 3 이면 3칸 · **최대 3** · 젤리로 영구 구매 가능(5·10 단위 `roundJellyCost`).
- 레벨 Lv N 이 끝나야 Lv N+1 시작. 취소·환불 없음. 초기화 없음.
- 젤리로 파는 것 = 시간(즉시 완료)·칸. 레벨·상한 직접 판매 금지.
- 골드·재료 비용 = **가 본 최고 사냥터(극한 최종까지, 심연 배율 제외)의 사냥 N분치**(`huntMinutesReward`), 시작 때 확정·차감.
- 곡선: 무과금 · **앱 켜 둔 하루 3시간 사냥 수입** · 그 **50%** 를 연구가 씀 · 전 연구 **약 180일**.
- 결투 분야 전부 vs 전무(그 외 동일) **승률 80% 이상, 95% 미만**. 방어팀에도 적용.
- 시간 단축 연구 각각 최대 −50%.
- 방치(오프라인)에서 연구 재화는 **연구 패스가 켜진 구간만**.
- 연구 패스 `research_pass` ₩5,500 · 30일 · 혜택은 방치 중 연구 재화뿐. 올인원 `all_pass` ₩16,500 · 4패스 각 30일 연장.
- 하단 1쪽 `홈·채집함·결투·길드·상점·⇄`, 2쪽 `홈·장비·스킬·요정·연구소·⇄`. 캐릭터 탭 삭제.
- 세이브 `kSaveFeatureLevel` 27 → **28**. 서버·앱 같은 날 배포 + 강제 업데이트.
- 사용자에게 보이는 글은 ARB ko/en/ja. iOS 스토어 문구에 "짝짓기" 금지.

## Review Focus

1. **연구 진행 중 앱을 꺼 둠 / 기기 시계를 앞으로 돌림** → 완료 판정은 `now >= endsAt` 만, 서버가 경과 시간으로 레벨 증가를 자른다(Task 8 테스트 `clock_forward_upload_is_clamped`).
2. **구버전 앱(feat 27)이 연구 필드를 모른 채 업로드** → 서버가 저장본의 연구 필드를 지킨다(Task 8 `old_app_upload_keeps_research`).
3. **난이도를 내려간 뒤 연구 시작** → 비용은 최고 자리 기준이라 싸지지 않는다(Task 2 `price_uses_top_zone_not_current`).
4. **연구 재화·골드가 모자란 상태에서 시작 누름 / 칸이 꽉 참 / 같은 연구를 두 칸에** → 실패 코드로 거절, 세이브 그대로(Task 2 `start_fails_*`).
5. **작은 폰(본문 260px)·일본어 라벨에서 하단 6칸** → 글자 잘림·넘침 없음(Task 10 `nav_fits_260px_ja`).

---

### Task 1: `ResearchConfig` + `research.json` 골격

**Files:**
- Create: `packages/core_run/lib/src/research_config.dart`, `packages/app/assets/data/research.json`
- Modify: `packages/core_run/lib/core_run.dart` (export), 앱 데이터 로더(`GameData` — `pets.json` 로드하는 곳 옆), `packages/app/pubspec.yaml` 에셋 목록이 디렉터리 단위가 아니면 추가
- Test: `packages/core_run/test/research_config_test.dart`, `packages/app/test/data_test.dart`(키 유효성 한 줄)

**Interfaces:**
- Produces:
  - `enum ResearchBranch { hunt, nurture, duel }`
  - `enum ResearchEffect { huntAtk, huntHpDef, find, gold, bossDmg, offline, hatchTime, breedTime, trainTime, researchTime, duelAtk, duelDef, duelHp, injuryTime }` (열거 순서 = JSON 키, 새 항목은 맨 뒤)
  - `class ResearchDef { String id; ResearchBranch branch; ResearchEffect effect; int maxLevel; ({String id, int level})? requires; Map<String,String> name; }`
  - `class ResearchCost { int samples; double goldMinutes; double materialMinutes; int fossil; }`
  - `class ResearchConfig` with `List<ResearchDef> defs`, `List<int> slotsByTier` (`[1,1,2,3]`), `List<int> slotJelly` (2·3번째 칸 가격), `double effectAt(ResearchDef d, int level)` (누적 효과, 0 레벨 = 0), `Duration timeAt(ResearchDef d, int level)` (Lv `level` 하나에 걸리는 시간), `ResearchCost costAt(ResearchDef d, int level)`, `int instantJelly(Duration remaining)`, `int slotsFor(int topTier, int bought)` (= max(진행도 칸, 1+bought) 를 3 으로 자름), 드롭 값 `double eliteDropChance`, `int eliteDropAmount`, `int bossFirstDrop`, `int bossRepeatDrop`, `double bossRepeatChance`, `factory ResearchConfig.fromJson(Map)`.
  - `class ResearchEffects { double of(ResearchEffect e); }` + `ResearchEffects researchEffects(ResearchConfig c, Map<String,int> levels)` — 같은 효과 여러 연구는 곱 아닌 합(한 효과에 연구 하나뿐이라 실제론 단일). 시간 단축 효과는 `[0, 0.5]` 로 자른다.
- 곡선 표현(JSON): 연구마다 `maxLevel`, `effect: {perLevel, growth}`(누적 = Σ perLevel×growth^(i-1)), `time: {firstSeconds, growth}`, `cost: {samplesFirst, goldMinutesFirst, materialMinutesFirst, fossilFrom, fossilFirst, growth}`. 실제 숫자는 Task 3 이 채운다 — 지금은 임시 값.
  JSON 공통: `instantJellyPerMinute`, `instantJellyExponent`(0.58), `slotsByTier`, `slotJelly`, 드롭 값, `duelCap`(주석용).

- [ ] **Step 1: 실패 테스트** — `research_config_test.dart`:
  - `effectAt(def,0) == 0`, `effectAt` 레벨마다 증가, `timeAt` 레벨마다 증가, `costAt(...).goldMinutes` 레벨마다 줄지 않음.
  - `slotsFor(0,0)==1`, `slotsFor(2,0)==2`, `slotsFor(3,0)==3`, `slotsFor(0,1)==2`, `slotsFor(0,5)==3`, `slotsFor(3,2)==3`.
  - `researchEffects` 에서 `hatchTime` 이 0.5 를 넘지 않음.
  - `instantJelly` 결과 `% 5 == 0`.
  - 실데이터: 14개 id 유일, `requires` 가 존재하는 id 를 가리킴, 분야별 개수 사냥 6·육성 4·결투 4.
- [ ] **Step 2:** `cd packages/core_run ; dart test test/research_config_test.dart` → FAIL(타입 없음)
- [ ] **Step 3:** 구현 + `research.json` 14개 항목(id: `jaw, shell, instinct, antenna, bossHunter, idleEff, incubator, nest, trainLore, researchEff, duelMuscle, duelArmor, duelVigor, recovery`), 분야 안 선행: 앞 항목 Lv5.
- [ ] **Step 4:** 테스트 PASS · `data_test` 에 research.json 로드·효과 키 검사 추가 후 `cd packages/app ; flutter test test/data_test.dart` PASS
- [ ] **Step 5:** 커밋 `feat(core_run): 연구소 설정 모델·research.json 골격`

### Task 2: 세이브 필드 + `research_progress.dart`

**Files:**
- Modify: `packages/core_save/lib/src/save_game.dart` (필드·copyWith·fromJson·toJson, `kSaveFeatureLevel` 28)
- Create: `packages/core_save/lib/src/research_progress.dart` (+ export)
- Test: `packages/core_save/test/research_progress_test.dart`

**Interfaces:**
- Consumes: Task 1 `ResearchConfig`, `huntMinutesReward` (`core_run/lib/src/exchange.dart:58`), `roundJellyCost`.
- Produces (SaveGame 필드, 기본값이면 JSON 키 생략):
  - `Map<String,int> researchLevels` → `'rsL'`
  - `List<ResearchSlot> researchSlots` → `'rsS'` ; `class ResearchSlot { String id; int level; DateTime endsAt; }` JSON `{i,l,e}`
  - `int researchSamples` → `'rsC'`
  - `int researchSlotsBought` → `'rsB'`
  - `DateTime? researchPassExpiresAt` → `'researchPassExpiresAt'` + `bool researchPassActive(DateTime now)`
- Produces (함수, 모두 `ResearchOp` = `.ok(save,{extra})`/`.fail(code)` — `SkillOp` 과 같은 모양):
  - `ResearchPrice researchPrice(SaveGame s, ResearchConfig cfg, String id, {required ({int gold, int materialsEach}) Function(double minutes) huntAtTop})` → `{int samples, int gold, int materialsEach, int fossil, Duration time, int level}` (level = 다음 레벨, 시간에 `researchTime` 효과 적용)
  - `ResearchOp startResearch(SaveGame s, ResearchConfig cfg, String id, DateTime now, ResearchPrice price)` — 실패 코드: `max_level`, `locked`(선행 미달), `slots_full`, `already_running`, `not_enough`.
  - `SaveGame claimResearch(SaveGame s, ResearchConfig cfg, DateTime now)` — 끝난 칸을 레벨에 반영하고 칸을 비운다.
  - `ResearchOp finishResearchNow(SaveGame s, ResearchConfig cfg, String id, DateTime now)` — 젤리 차감 후 즉시 반영, `not_enough_jelly`.
  - `ResearchOp buyResearchSlot(SaveGame s, ResearchConfig cfg)` — `max_slots`, `not_enough_jelly`.
  - `SaveGame grantResearchSamples(SaveGame s, int n)`
  - `int rollResearchDrop(ResearchConfig cfg, Random rng, ResearchDropSource src)` ; `enum ResearchDropSource { elite, bossFirst, bossRepeat }`
- "최고 자리" 는 호출자가 `huntAtTop` 으로 넘긴다(앱: `topTier` 의 최고 사냥터 스테이지·극한 최종까지·`abyssFloor: 0`).

- [ ] **Step 1: 실패 테스트** — `research_progress_test.dart`:
  - `roundtrip_json` — 필드 넣고 toJson→fromJson 동일, 기본값이면 키 없음.
  - `start_spends_and_sets_slot` — 재화 차감, `researchSlots.single.endsAt == now + price.time`.
  - `start_fails_not_enough` · `start_fails_slots_full`(칸 1, 두 번째 시작) · `start_fails_already_running`(같은 id) · `start_fails_locked` · `start_fails_max_level` — 각각 세이브 불변.
  - `claim_after_end_levels_up` · `claim_before_end_noop`.
  - `finish_now_spends_jelly` — 젤리 = `cfg.instantJelly(remaining)`.
  - `buy_slot_to_three_then_max_slots`.
  - `price_uses_top_zone_not_current` — `huntAtTop` 콜백이 받은 값만 쓰는지(현재 스테이지를 바꿔도 같은 가격).
  - `rollResearchDrop` 같은 seed 같은 결과.
- [ ] **Step 2:** `cd packages/core_save ; dart test test/research_progress_test.dart` → FAIL
- [ ] **Step 3:** 구현
- [ ] **Step 4:** PASS + `dart test` 전체(core_save) PASS — feat 28 로 깨지는 테스트는 기대값만 갱신
- [ ] **Step 5:** 커밋 `feat(core_save): 연구 세이브 필드·시작/완료/칸 구매/드롭 (feat 28)`

### Task 3: 비용·시간 표 맞추기 도구 + 사장님 확인 (게이트)

**Files:**
- Create: `packages/core_run/tool/research_table.dart`
- Modify: `packages/core_run/tool/balance_sim.dart` (`--active-hours=3` 플래그 → `_activeHoursPerDay` 대체, `--income` 표에 하루 온라인 골드·재료·화석·정예/보스 수 출력)
- Modify: `packages/app/assets/data/research.json` (실제 값)
- Test: `packages/core_run/test/research_curve_test.dart`

**Interfaces:**
- Consumes: Task 1·2.
- `research_table.dart` 입력: `balance_sim --active-hours=3 --income` 가 내는 날짜별 하루 온라인 수입(골드 분치는 이미 "분" 단위라 수입 대비 비율로 바로 계산), 무과금 칸 곡선(`slotsByTier` + 시뮬의 어려움·극한 도착일).
  출력: ① 연구별 레벨 표(시간 · 연구 재화 · 골드 분 · 재료 분 · 화석 · 즉시완료 젤리) ② 무과금이 칸을 쉬지 않고 돌릴 때 전체 완료일 ③ 날짜별 "연구 비용 ÷ 하루 3시간 수입" 평균.
  `--fit` 이면 `time.firstSeconds/growth` 와 `cost.*First/growth` 를 맞춰 **완료 175~185일 · 비용 비율 평균 45~55%** 가 되는 값을 JSON 조각으로 출력.
- 연구 재화 드롭(정예 확률·보스) 하루 기대값도 같은 수입 표에서 잡아, 재화가 병목이 되지 않게(시간이 병목) 맞춘다.

- [ ] **Step 1: 실패 테스트** — `research_curve_test.dart`(실데이터):
  - 모든 레벨 `costAt.goldMinutes <= 540` · `materialMinutes <= 540` — 한 레벨이 **하루 3시간(180분) 수입의 3배를 넘지 않는다**.
  - `instantJelly(timeAt(lv)) % 5 == 0` 모든 레벨, 최댓값 ≤ 3,000(젤리 터무니없음 차단 — Task 3 표를 보고 사장님 확인 뒤 확정).
  - 시간·비용 레벨마다 단조 증가, Lv1 시간 ≤ 10분.
- [ ] **Step 2:** FAIL(임시 값)
- [ ] **Step 3:** `cd packages/core_run ; dart run tool/balance_sim.dart --tiers=4 --no-fairy --active-hours=3 --income > %TEMP%/income3h.txt` → `dart run tool/research_table.dart --income=<그 파일> --fit` → JSON 반영
- [ ] **Step 4:** 테스트 PASS · `research_table.dart` 출력이 완료 175~185일 · 비율 45~55%
- [ ] **Step 5: 게이트** — 레벨 표를 사장님께 보여 주고 승인받기 전 다음 Task 로 가지 않는다(표·완료일·비율·최대 젤리).
- [ ] **Step 6:** 커밋 `balance(research): 3시간 수입 50%·180일 비용·시간 표`

### Task 4: 사냥 효과 (온라인·방치) + 90일 영향 측정

**Files:**
- Create: `packages/core_run/lib/src/research_apply.dart` — `CharacterStats applyResearchStats(CharacterStats s, ResearchEffects e)`
- Modify: `packages/app/lib/domain/combat_power.dart:103` `huntStatsUncapped` (guild 다음·dex 앞에 한 줄), `packages/app/lib/domain/save_controller.dart:447` `_applyOffline`(효율 × (1+offline) · 골드/찾기), `packages/server/lib/src/actions.dart:3328` `sync`(같은 배율), `packages/core_run/tool/balance_sim.dart` `_Player._statsWith`(`--research=<일수 곡선 or full>`), `packages/core_run/tool/clamp_check.dart`(연구 다 찍은 경우 포함)
- Modify: 서버 업로드 골드·재료 상한(`actions.dart` `maxGain` :1470 · 재료 :1576) — `generous` 계산에 연구 배율
- Test: `packages/core_run/test/research_apply_test.dart`, `packages/server/test/research_clamp_test.dart`

**Interfaces:**
- 효과 적용: `huntAtk`·`gold`·`find`·`bossDmg` 는 곱(1+v), `huntHpDef` 는 체력 곱 + 방어 맷집 `(100+def)×(1+v)` (`applySpeciesPassives` 와 같은 해석). **적응형 기준(`permanentStatsOf`)에는 넣지 않는다.**
- 방치 효율: `efficiency = config.offlineEfficiency × (1 + offline)`, 곤충학자 패스 골드 배율과 곱.

- [ ] **Step 1: 실패 테스트** — `research_apply_test.dart`: 레벨 0 이면 입력과 같음 · `huntAtk` 0.3 이면 공격 ×1.3 · 방어 맷집 공식. `research_clamp_test.dart`: 연구 다 찍은(최대 효과) 계정의 60초 정당 수입이 서버 상한에 잘리지 않는다(`clamp_check` 와 같은 방식).
- [ ] **Step 2:** FAIL → **Step 3:** 구현 → **Step 4:** PASS + `cd packages/app ; flutter test` 중 combat_power 관련 PASS
- [ ] **Step 5: 측정** — `dart run tool/balance_sim.dart --tiers=4 --no-fairy` 를 연구 없음 / `--research` (Task 3 곡선, 골드 50% 차감 포함) 로 두 번 → 극한 최종 일수 두 개를 기록(허용치 없음 — 보고만, 사장님 확정).
- [ ] **Step 6:** 커밋 `feat(research): 사냥·방치 효과 + 서버 상한 반영`

### Task 5: 시간 단축 효과(부화·산란·돌파·훈련·부상)

**Files:**
- Create: `core_run/lib/src/research_apply.dart` 에 `int researchScaledSeconds(int seconds, ResearchEffects e, ResearchEffect kind)` (`seconds × (1 − v)`, 올림, 최소 1)
- Modify (호출부): 부화 `save_controller.dart:3445-3450`·`storage_screen.dart:1931, 4196` · 산란 서버 `actions.dart:4059` · 앱 `save_controller.dart:4737` · 돌파 서버 `actions.dart:3743` · 앱 `save_controller.dart:3374` · 훈련 `core_save/lib/src/train_points.dart:602, 618, 638, 709`(respec 대기 포함) · 결투 부상 `actions.dart:2698, 3035, 3092`·`app.dart:1984`·앱 `save_controller.dart:1740, 1774` · 대회 부상 `actions.dart:5282, 5569`
- Test: `packages/core_save/test/research_timers_test.dart`

**Interfaces:** 각 호출부는 `researchEffects(cfg, save.researchLevels)` 를 한 번 만들고 해당 kind 로 감싼다. 스킨 단축(`skinnedIncubateSeconds` 등) 결과에 **곱**(스킨 먼저, 연구 나중). 화면 표시 시간도 같은 함수.

- [ ] **Step 1: 실패 테스트** — 부화 50% 연구면 시간 절반 · 0 이면 그대로 · 스킨 + 연구 곱 · 훈련 찍기 `until` 단축 · 서버 산란 시작 `endsAt` 단축.
- [ ] **Step 2:** FAIL → **Step 3:** 구현 → **Step 4:** `dart test`(core_save, server) · `flutter test`(app) PASS
- [ ] **Step 5:** 커밋 `feat(research): 부화·산란·돌파·훈련·부상 시간 단축`

### Task 6: 결투·대회 효과 + 80% 맞추기

**Files:**
- Modify: `packages/server/lib/src/actions.dart` `_buildDuelTeam`(:2828, aura 앞에 `.withTraining(atkMult:, defMult:, hpMult:)` 한 번), 앱 거울 `packages/app/lib/features/battle/duel_bug_build.dart:102-112`
- Modify: `packages/server/tool/duel_build_sim.dart` — `--research-a=atk,def,hp` (A 쪽만 곱), 결과 줄에 A 승률
- Modify: `research.json` 결투 3종 `effect` 곡선
- Test: `packages/server/test/research_duel_test.dart`

**Interfaces:** 배율 = `1 + duelAtk/Def/Hp`. `validateDuelTeam` 을 거치는 모든 경로(리그·방어팀 `defenderDuelTeam` · 대회 `teamSize: 1`)가 자동으로 받는다. 앱 전투력(`duelPowerOf`)은 앱 `duelBugFor` 를 타므로 같이 반영.

- [ ] **Step 1: 실패 테스트** — `research_duel_test.dart`: 연구 0 이면 팀 능력치 그대로 · 결투 근육 최대면 atk ×(1+cap) · 상대 세이브(방어팀)의 연구가 방어팀에 입혀짐 · 대회 팀(`teamSize: 1`)에도 입혀짐 · 서버 팀과 앱 `duelBugFor` 의 atk/def/hp 가 같다.
- [ ] **Step 2:** FAIL → **Step 3:** 구현
- [ ] **Step 4: 맞추기** — `cd packages/server ; dart run tool/duel_build_sim.dart --team-eval --research-a=<atk>,<def>,<hp>` 로 3마리 경기 A 승률이 **80~90%** 가 되는 최대 효과를 찾고(시작점 각 +15%), 1마리(`--only1`)도 기록. 결과를 JSON 결투 3종 곡선의 최종 누적값으로.
- [ ] **Step 5:** 테스트 PASS · `dart test`(server) PASS
- [ ] **Step 6:** 커밋 `feat(research): 결투·대회 공격/방어/체력 (다 찍은 쪽 80%대)`

### Task 6b: 추가 연구 15종 효과 연결 (스펙 §10)

**Files:** 효과마다 그 수치를 계산하는 기존 함수 한 곳(앱·서버·시뮬 공용인 곳)에 `researchEffects` 를 곱한다. 찾을 곳(구현자가 확인):
치명 피해·재생·경험치 = `huntStatsUncapped` 의 `applyResearchStats`(Task 4) 확장 · 회피 = 회피 예산(`evadeBudget*`, run_config) 에 `evadeBudgetResearch` 0.20 추가 · 스킬 쿨 = `skillCooldownBudgetGear` 옆 `skillCooldownBudgetResearch` 0.20 ·
제련/초월 시간 = forge_config 시간 함수 · 별 강화 시간 = 별 강화 시간 함수 · 다듬기 비용 = polish 비용 함수 · 혈통 = `BreedingSlot.hatch()` 의 `breedingTraitNew` · 약초학 = `rollPotionDrop` 의 확률(한도 그대로) ·
분해 = 분해·방생 재료 함수(젤리 제외) · 교환 = `exchangeOutput` · 선물·일일 = `huntMinutesReward` 를 부르는 선물·일일보상 지급(젤리 제외) · 결투 치명 = `_buildDuelTeam`(Task 6) `withTraining(crit:)` · 근성 = 같은 곳 `grit` 또는 탭 문턱.
서버 허용치: `_huntRewardAllowance`·`_exchangeAllowance`·`_enforceGrade`·재료 상한에 같은 배율.
- [ ] Step 1: 효과마다 "연구 0 이면 그대로 · 최대면 기대 배율" 테스트 + 서버 허용치 테스트(연구 최대 계정의 정당 수입이 안 잘림)
- [ ] Step 2: FAIL → Step 3: 구현 → Step 4: 전 패키지 테스트 PASS
- [ ] Step 5: `balance_sim --tiers=4 --no-fairy --research` 재측정(회피 60% 포함) — 극한 일수 보고
- [ ] Step 6: 커밋 `feat(research): 추가 연구 15종 효과`

### Task 7: 연구 재화 드롭 — 온라인 + 패스 방치

**Files:**
- Modify: `app/lib/domain/save_controller.dart` 보스 `_advanceZoneImpl`(:1000, `grantBossShards` 옆) · 정예 `grantEliteShards`(:4608) · 오프라인 `_applyOffline`(:447 — 패스 구간만)
- Modify: `core_save/lib/src/offline_buffs.dart` — `int idleResearchSamples(SaveGame s, ResearchConfig cfg, {required DateTime from, required Duration accrued, required int eliteKills, required Random rng})` (패스 만료 시각으로 자른 구간의 정예 처치 비율만큼 굴림)
- Test: `packages/core_save/test/research_drops_test.dart`

- [ ] **Step 1: 실패 테스트** — 패스 없음 → 방치 재화 0 · 패스가 방치 구간 절반에서 만료 → 절반 몫만 · 보스 첫 처치 `bossFirstDrop` 확정 · 같은 seed 같은 결과.
- [ ] **Step 2:** FAIL → **Step 3:** 구현 → **Step 4:** PASS
- [ ] **Step 5:** 커밋 `feat(research): 연구 재화 드롭(정예·보스, 방치는 연구 패스 구간만)`

### Task 8: 서버 검증 · 구버전 호환

**Files:**
- Modify: `packages/server/lib/src/actions.dart` — `_serverOwnedKeys`(:135)에 `researchPassExpiresAt` · `_keepFieldsOldAppDoesNotKnow`(:463) `28: ['rsL','rsS','rsC','rsB']` · 새 `SaveGame _enforceResearch(SaveGame stored, SaveGame client, Duration elapsed, int jellySpent, ResearchConfig cfg)` 를 `mergeSave` 에서 `_enforceSkills`(:1681) 옆에 호출
- Test: `packages/server/test/research_upload_test.dart`

**Interfaces / 규칙:**
- 레벨 증가 허용: 저장본 대비 오른 레벨들의 `timeAt` 합 ≤ `elapsed × slotsFor + 젤리로 설명되는 시간 + 저장본 진행 칸의 남은 몫` (+1분 여유). 넘치면 연구 필드 전체를 저장본으로.
- 재화 증가 허용: `(새 보스 수 × bossFirstDrop) + 60 × max(eliteDropAmount, bossRepeatDrop) + 패스 방치 몫` — 넘치면 저장본 값.
- 칸 구매: `rsB` 증가분 × 가격이 이번 업로드에서 줄어든 젤리보다 크면 되돌림. `rsB ≤ 2`.

- [ ] **Step 1: 실패 테스트** — `old_app_upload_keeps_research`(feat 27 JSON, 연구 필드 없음 → 저장본 유지) · `clock_forward_upload_is_clamped`(1분 경과에 Lv20 → 되돌림) · `honest_progress_accepted`(경과 시간 안 레벨업 인정) · `jelly_finish_accepted`(젤리 줄어든 만큼 인정) · `samples_surge_clamped` · `research_pass_server_owned`(클라가 만료일을 늘려도 저장본 값).
- [ ] **Step 2:** FAIL → **Step 3:** 구현 → **Step 4:** `cd packages/server ; dart test` PASS
- [ ] **Step 5:** 커밋 `feat(server): 연구 업로드 검증·구버전 호환·연구 패스 서버 소유`

### Task 9: 연구 패스 · 올인원 패스 · 칸 젤리 가격 — 경제 확인

**Files:**
- Modify: `core_run/lib/src/iap_config.dart:17-28` `IapType` 에 `researchPass`, `allPass` (맨 뒤) + `researchPassDurationDays`
- Modify: `core_save/lib/src/iap_grant.dart:89` `applyIapGrant` — researchPass → `researchPassExpiresAt` 연장 · allPass → `passExpiresAt`·`buffPassExpiresAt`·`growthPassExpiresAt`·`researchPassExpiresAt` 각각 `extend(cur, 30)`
- Modify: `app/assets/data/iap.json` — `research_pass`(5500, kind timed) · `all_pass`(16500) 항목(ko/en/ja 이름·설명), `app/lib/domain/store_iap_service.dart` 상품 id 목록(스토어에 없는 상품은 상점에서 숨김 — 기존 처리 그대로)
- Modify: `core_run/tool/jelly_sim.dart` — 소비처에 연구 칸 2개 + 연구 즉시완료(무과금은 0), IAP 대비 표에 `all_pass`
- Test: `packages/core_save/test/iap_grant_test.dart`(추가), `packages/server/test/iap_products_test.dart`(추가)

- [ ] **Step 1: 실패 테스트** — 올인원이 네 만료일을 모두 30일 연장(이미 남은 기간 위에) · 연구 패스 단독 연장 · 서버 `grantPurchase` 경로 동일.
- [ ] **Step 2:** FAIL → **Step 3:** 구현
- [ ] **Step 4:** `cd packages/core_run ; dart run tool/jelly_sim.dart` — `all_pass` 의 젤리당 가치가 젤리 팩 사다리보다 싸지 않은지 확인. 싸면 가격 후보를 사장님께 보고(코드는 ₩16,500 유지).
- [ ] **Step 5:** 테스트 PASS → 커밋 `feat(iap): 연구 패스·올인원 패스`

### Task 10: 하단 탭 2쪽 + 캐릭터 탭 분해

**Files:**
- Modify: `app/lib/domain/providers.dart:23-36` — 탭 번호 재정의(아래), `navPageProvider`(0/1, `SharedPreferences` 키 `nav.page` 로 기억)
- Modify: `app/lib/features/app_shell.dart` — IndexedStack 자식·`_GameNavBar`(쪽별 항목 + ⇄ `_NavSwitch`)·dots·뒤로가기(index≠0 → 홈)
- Create: `app/lib/features/character/equipment_tab.dart` (`EquipmentTab` = 옛 stats 패널: `CharacterScene`·`_StatsPanel`·`_EquipGrid`·`ForgeBar` 를 public 으로 옮김), `skill_tab.dart`(`Scaffold`+`SkillPanel`), `fairy_tab.dart`(`Scaffold`+`FairyPanel`)
- Delete: `app/lib/features/character/character_screen.dart` (옮긴 뒤)
- Modify: `app/lib/domain/red_dots.dart` — `characterTab` 대신 `equipTab`(=stats), `skillsTab`, `researchTab`(Task 11), `int otherPageHasDot(page)` 계산용 getter
- Modify: ARB ko/en/ja — `navEquip`(장비/Gear/装備), `navSkills`(스킬/Skills/スキル), `navFairy`(요정/Fairy/妖精), `navResearch`(연구소/Lab/研究所), `navSwitch`(전환/More/切替) → `flutter gen-l10n`
- Test: `app/test/nav_pages_test.dart`, `app/test/widget_test.dart`(라벨 기대 갱신), `app/test/guild_screen_test.dart`(상수 이름 그대로면 무변경)

**Interfaces:** 탭 번호(IndexedStack 순서) 고정: `0 홈 · 1 채집함 · 2 결투 · 3 길드 · 4 상점 · 5 장비 · 6 스킬 · 7 요정 · 8 연구소`. `kGuildTabIndex = 3`, `kShopTabIndex = 4`, 새 `kEquipTabIndex = 5`, `kSkillTabIndex = 6`, `kFairyTabIndex = 7`, `kResearchTabIndex = 8`. 1쪽 항목 `[0,1,2,3,4]`, 2쪽 `[0,5,6,7,8]`. 상점으로 가는 기존 호출(`set(kShopTabIndex)`)은 쪽을 1쪽으로 바꾼다(`TabIndexNotifier.set` 안에서 그 번호가 속한 쪽으로 `navPageProvider` 갱신). 아트: 2쪽은 `assets/images/ui/tab/{stats,skills,fairy}.webp` 재사용, 연구소·⇄ 는 Material 아이콘 폴백.

- [ ] **Step 1: 실패 테스트** — `nav_pages_test.dart`: 처음 1쪽 라벨 5개+전환 · ⇄ 누르면 2쪽 라벨(장비·스킬·요정·연구소) · 2쪽에서 상점으로 `set(kShopTabIndex)` → 1쪽 · 2쪽 탭에 빨간 점이 있으면 1쪽에서 ⇄ 에 점 · `nav_fits_260px_ja`(폭 260, ja 로캘, `tester.takeException()` null).
- [ ] **Step 2:** FAIL → **Step 3:** 구현 → **Step 4:** `cd packages/app ; flutter test` 전체 PASS · `flutter analyze` 0
- [ ] **Step 5:** `flutter-layout-reviewer` 에이전트로 바뀐 파일 검사, 지적 반영
- [ ] **Step 6:** 커밋 `feat(app): 하단 탭 2쪽(⇄ 전환) · 캐릭터 탭을 장비·스킬·요정 탭으로`

### Task 11: 연구소 화면 · 빨간 점 · 완료 알림

**Files:**
- Create: `app/lib/features/research/research_screen.dart` (`ResearchScreen`: 위 = 칸 1~3(진행 바·남은 시간·즉시 완료 젤리·빈 칸 / 잠긴 칸은 "어려움에서 열림 · 젤리 N" 구매 버튼), 아래 = 분야 3묶음 목록(아이콘·이름·Lv·현재/다음 효과·다음 레벨 비용 미리보기·잠김 사유), 상단에 연구 재화 보유량)
- Modify: `app/lib/domain/save_controller.dart` — `startResearch(String id)`, `finishResearchNow(String id)`, `buyResearchSlot()`, `claimResearch()`(로드·`_commit` 에서 자동 수령) — 모두 core_save 함수 호출, `huntAtTop` 은 `huntMinutesReward(run, stats: huntStatsOf(...), stage: <topTier 최고 사냥터 스테이지, 극한 최종으로 자름>, minutes: m, tier: topTier)`
- Modify: `app/lib/domain/red_dots.dart` — `researchIdle`(빈 칸 있고 시작 가능한 연구가 있음), `researchDone`; `researchTab` getter
- Modify: `app/lib/domain/notification_service.dart` — `scheduleResearch(List<DateTime> endsAt, {title, body, quiet})` id `920+`, `cancelResearch`; `app_shell.dart:129-180` 에서 호출, `NotifyPrefs` 에 `researchDone`(기본 켬)
- Modify: ARB ko/en/ja — 화면 문구·14개 이름·효과 설명·실패 코드 문구·알림 문구
- Test: `app/test/research_screen_test.dart`, `app/test/red_dots_test.dart`(추가)

- [ ] **Step 1: 실패 테스트** — 빈 세이브로 화면: 칸 1 열림·2·3 잠김 문구 · 연구 누르면 칸에 진행 표시 · 재화 부족이면 버튼 비활성 + 이유 · 빨간 점: 빈 칸+시작 가능 → true, 칸이 다 차 있으면 false · 끝난 연구 있으면 true.
- [ ] **Step 2:** FAIL → **Step 3:** 구현 → **Step 4:** `flutter test` PASS · `flutter analyze` 0 · `flutter-layout-reviewer` 검사
- [ ] **Step 5:** 에뮬로 개발 빌드 켜서 연구 시작→즉시 완료→레벨 반영 확인, 화면 캡처를 사장님께 · 끝나면 에뮬 종료
- [ ] **Step 6:** 커밋 `feat(app): 연구소 화면·빨간 점·완료 알림`

### Task 12: 문서 · 업데이트 창 · 출시 준비

**Files:**
- Modify: `CLAUDE.md` — §2.7 에 "연구소(2026-10-22 사장님 확정)" 단락(칸·비용 기준·50%·180일·80%·패스·위조 방지·feat 28) · §2.8 에 "연구 칸 젤리 판매는 사장님 결정(스킬 칸 규칙과 별개)" · §3 세이브 feat 28
- Modify: `app/lib/ui/whats_new.dart` + ARB(`whatsNew26*` 3줄: 연구소 · 하단 탭 2쪽 · 새 패스) + `app/test/whats_new_test.dart`
- Create: 연구소 아이콘 15장(14 + 탭) 프롬프트 HTML 작업 페이지 — `tool/make_prompt_page.py` 사용(사장님 규칙: 프롬프트는 HTML 작업 페이지로)
- Test: 앱·서버·core 전 패키지 테스트

- [ ] **Step 1:** 문서·업데이트 창 수정
- [ ] **Step 2:** `dart test`(core_models, core_run, core_save, core_battle, server) · `flutter test`(app) · `flutter analyze` 모두 PASS
- [ ] **Step 3:** 측정 결과 요약(Task 3 표 · Task 4 일수 · Task 6 승률 · Task 9 젤리 가치)을 사장님께 보고
- [ ] **Step 4:** 커밋 `docs: 연구소 규칙·업데이트 창(1.0.26)`
- 출시(버전 올림·서버 배포·강제 업데이트·스토어 상품 등록 안내)는 사장님 지시 때 `flutter-release` 스킬로 — 이 계획 밖.
