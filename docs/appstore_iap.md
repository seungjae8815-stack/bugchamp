# App Store 인앱결제 등록 가이드 (iOS)

> 제품 ID·구성은 `packages/app/assets/data/iap.json` 이 원본. App Store Connect 에
> **제품 ID 를 한 글자도 다르지 않게** 등록해야 앱이 상품을 조회할 수 있다.
> Android(Play) 등록표는 `docs/iap_products_table.md`.

---

## 0. 사전 조건 (안 하면 상품이 "판매 준비 안 됨")

- [ ] **유료 앱 계약(Paid Apps Agreement)** 동의 — App Store Connect → 계약/세금/뱅킹
- [ ] **은행 정보 + 세금 정보** 입력 (없으면 유료 상품 심사·판매 불가)
- [ ] **App-Specific Shared Secret** 발급 (아래 §3 영수증 검증에 필요)

---

## 1. 제품 등록 (App Store Connect → 내 앱 → 앱 내 구입)

**"앱 내 구입"** 에서 **+** → 유형 선택 → 아래 표대로 14개 생성.

| # | 제품 ID (**정확히**) | App Store 유형 | 참조 이름 | 가격(₩ 티어) |
|---|---|---|---|---|
| 1 | `jelly_s`  | **소모성**(Consumable) | 곤충젤리 소 | 1,200 |
| 2 | `jelly_m`  | **소모성** | 곤충젤리 중 | 5,500 |
| 3 | `jelly_l`  | **소모성** | 곤충젤리 대 | 11,000 |
| 4 | `jelly_xl` | **소모성** | 곤충젤리 특대 | 29,000 |
| 5 | `jelly_xxl`| **소모성** | 곤충젤리 최대 | 59,000 |
| 6 | `starter_pack`     | **비소모성**(Non-Consumable) | 스타터 패키지 | 5,500 |
| 7 | `idle_pass_c`      | **소모성** ⚠️ | 곤충학자 패스 30일 | 9,900 |
| 8 | `buff_pass`        | **소모성** ⚠️ | 무한 버프 패스 30일 | 6,600 |
| 9 | `skin_gold_rhino`  | **비소모성** | 황금 장수풍뎅이 | 3,300 |
| 10| `skin_albino_stag` | **비소모성** | 알비노 사슴벌레 | 3,300 |
| 11| `fairy_starter`    | **비소모성** | 요정 입문 패키지 | 4,400 |
| 12| `skill_starter`    | **비소모성** | 스킬 입문 패키지 | 4,400 |
| 13| `growth_pass`      | **소모성** ⚠️ | 요정·스킬 성장 패스 30일 | 5,500 |
| 14| `weekly_bundle`    | **소모성** ⚠️ | 주간 묶음 | 2,200 |

> 2026-10-08 추가: 11~14(요정·스킬 상품). 입문 패키지 2종은 계정당 1회라 **비소모성**,
> 성장 패스(30일)·주간 묶음(주 1회)은 다시 사야 하므로 **소모성** — 앱도 그 방식으로 산다
> (`store_iap_service.dart`). 1회·주간·기간 기록은 서버 세이브(서버 소유 필드)가 든다.

> ⚠️ **패스 2종은 반드시 소모성으로 등록한다**(2026-08-20 수정 — 예전 지침의
> "idle_pass 비소모성"은 틀렸다). 비소모성은 계정당 1회 구매라 **30일 만료 후
> 연장 재구매가 영영 불가능**하다. 소모성이면 만료 후 다시 살 수 있고, 패스
> 상태는 스토어가 아니라 서버 세이브(`passExpiresAt`, 서버 소유)가 들고 있어
> 재설치·복원에서 잃는 게 없다. 앱도 timed 상품을 consume 경로로 산다
> (`store_iap_service.dart`). **idle_pass 는 실제로 비소모성으로 생성돼 있었다**
> (2026-08-20 확인) — 유형 변경·ID 재사용이 불가능해 iOS 만 새 ID
> `idle_pass_c`(소모성)를 쓴다. 기존 `idle_pass` 는 ASC 에서 판매 중단 처리.
> 앱·서버는 `iap.json → iosId` 별칭으로 두 ID 를 같은 상품으로 해석한다
> (Play 는 기존 `idle_pass` 그대로).
>
> `remove_ads`(판매 중단)·`theme_arena`(판매 숨김)는 **등록하지 않는다**.

> **유형 근거**: 앱은 소모성(젤리·주간 묶음)과 기간제(패스 3종)를 `buyConsumable`(재구매 가능), 나머지(스타터·스킨·입문 2종)는 `buyNonConsumable` 로 산다(`store_iap_service.dart`).
> App Store 유형을 앱의 구매 방식과 일치시켜야 한다.
> **idle_pass** 는 자동갱신 구독이 아니라 소모성으로 등록(앱이 서버 `passExpiresAt`
> 로 30일 만료를 관리). 구독 그룹/자동갱신 만들지 말 것.

### 각 제품 입력
- **참조 이름**: 위 표(내부용, 사용자에게 안 보임)
- **가격**: 한국 원화 기준 티어 선택(다른 나라는 Apple 자동 환산)
- **현지화(표시 이름/설명)**: ko/en/ja — `iap.json` 의 `name`/`desc` 값 사용. ⚠️ **스킨 2종은 아래 iOS 전용 설명을 쓴다**
  (`iap.json` 설명의 "짝짓기·breeding·交配" 는 App Store 심사 1.1 거절 이력 단어다). 설명 칸 길이 한도는 콘솔에서 확인하고, 넘치면 줄을 줄인다.

### iOS 짧은 설명(55자 이하 · 2026-10-09) — App Store Connect 설명 칸은 **55자까지**라 Play 설명을 그대로 못 넣는다
| 제품 | ko | en | ja |
|---|---|---|---|
| `starter_pack` | 젤리 400·부화기 슬롯 +1·2시간 가속기 3 (계정당 1회) | 400 jelly, +1 incubator slot, 3 2h accelerators | ゼリー400・孵化器スロット+1・2時間加速器3(1回限り) |
| `fairy_starter` | 영웅 요정 알 1·희귀 요정 알 3·8시간 가속기 3 등 (1회) | 1 Epic + 3 Rare fairy eggs, 3 8h accelerators & more | 英雄の妖精の卵1・希少の卵3・8時間加速器3など(1回限り) |
| `skill_starter` | 희귀 만능 조각 100·영웅 만능 조각 30 (계정당 1회) | 100 Rare + 30 Epic universal skill shards (once) | 希少の万能かけら100・英雄の万能かけら30(1回限り) |
| `idle_pass_c` | 30일: 오프라인 16시간·방치 골드 +30%·매일 젤리 20 | 30 days: 16h offline, +30% idle gold, 20 jelly daily | 30日間: オフライン16時間・放置ゴールド+30%・毎日ゼリー20 |
| `buff_pass` | 30일: 버프 5종 항상 켜짐·깜짝선물 자동 수령·2배 | 30 days: all 5 buffs always on, gifts auto x2 | 30日間: バフ5種が常時発動・ギフト自動受取・常に2倍 |
| `growth_pass` | 30일 동안 접속한 날마다 요정 가루·만능 조각·가속기 | 30 days: daily fairy dust, skill shards & accelerator | 30日間ログインした日ごとに妖精の粉・かけら・加速器 |
| `weekly_bundle` | 2시간 가속기 3·속성석 2·희귀 만능 조각 20 (주 1회) | 3 2h accelerators, 2 stones, 20 Rare shards (weekly) | 2時間加速器3・属性石2・希少の万能かけら20(週1回) |
| `skin_gold_rhino` | 장수풍뎅이 계열 황금빛·재료 +30%·부화 시간 −25% 등 | Golden rhino beetles, +30% materials, faster hatching | カブトムシ系が黄金色に・素材+30%・孵化時間−25%など |
| `skin_albino_stag` | 사슴벌레 계열 알비노·재료 +30%·부화 시간 −25% 등 | Albino stag beetles, +30% materials, faster hatching | クワガタ系がアルビノに・素材+30%・孵化時間−25%など |

> 젤리 5종 설명("곤충젤리 300개 (보너스 +9%)" 등)은 원래 짧아 `iap.json` 그대로. 스킨은 아래 긴 판(지뢰 단어 없음)이 55자를 넘으면 위 짧은 판을 쓴다.

### 스킨 2종 iOS 설명(지뢰 단어 없는 판)
| 제품 | ko | en | ja |
|---|---|---|---|
| `skin_gold_rhino` | 장수풍뎅이 계열이 황금빛으로 · 그 계열 재료 +30% · 부화·육성 시간 −25% · 구매 즉시 젤리 100 + 4성 장수풍뎅이 알 | Rhinoceros beetles turn gold · +30% materials from that family · −25% hatch & raise time · Bonus: 100 jelly + a 4★ Rhino Beetle egg | カブトムシ系が黄金色に・その系統の素材+30%・孵化・育成時間−25%・購入特典 ゼリー100＋4★カブトムシの卵 |
| `skin_albino_stag` | 사슴벌레 계열이 알비노로 · 그 계열 재료 +30% · 부화·육성 시간 −25% · 구매 즉시 젤리 100 + 4성 사슴벌레 알 | Stag beetles turn albino · +30% materials from that family · −25% hatch & raise time · Bonus: 100 jelly + a 4★ Stag Beetle egg | クワガタ系がアルビノに・その系統の素材+30%・孵化・育成時間−25%・購入特典 ゼリー100＋4★ミヤマクワガタの卵 |
- **심사 스크린샷**: 상점 화면 캡처 1장(14개 공통으로 같은 화면 써도 됨)
- **가격 티어**: 정확한 원화가 티어가 없으면 가장 가까운 티어

---

## 2. 심사 제출

- 첫 제출은 **앱 버전과 IAP 를 함께** 제출한다(앱 심사에 IAP 추가).
- 심사 메모에 "익명 계정으로 로그인 없이 구매 가능, 서버 영수증 검증" 명시.

---

## 3. iOS 영수증 서버 검증 (필수 — 안 하면 결제가 "보류"됨)

앱은 iOS 에서 **App Store 영수증**(base64)을 서버로 보내고, Edge Function
`verify-purchase` 가 Apple 에 검증한다. 코드는 이미 iOS 분기를 처리한다
(`supabase/functions/verify-purchase/index.ts`). **Shared Secret 만 넣으면 된다.**

### 3-1. App-Specific Shared Secret 발급
```
App Store Connect → 내 앱 → 앱 정보(또는 사용자 및 액세스 → 공유 암호)
  → "앱 전용 공유 암호(App-Specific Shared Secret)" 생성 → 복사
```

### 3-2. Supabase 시크릿 등록 (별도 터미널, Claude 에게 값 주지 말 것)
```bash
npx supabase secrets set APPLE_SHARED_SECRET="<복사한 공유 암호>" \
  --project-ref rvmpwyycivmtrbbynjyy
npx supabase functions deploy verify-purchase --project-ref rvmpwyycivmtrbbynjyy
```

### 3-3. 동작
- iOS 영수증(수천 자 base64) → Apple `verifyReceipt` 검증
  (프로덕션 먼저 → 21007 이면 **샌드박스 자동 재시도** → 심사·테스트 OK)
- 재사용 방지 키 = `transaction_id`(소비형 재구매도 매번 다름)
- Android 는 기존 Google Play API 검증 그대로(분기).

> ⚠️ Shared Secret 미설정이면 iOS 결제가 `server_misconfigured` 로 **보류**된다
> (지급 안 됨). 결제 켜기 전 반드시 등록.

---

## 4. 샌드박스 테스트 (심사 전 본인 확인)

1. App Store Connect → 사용자 및 액세스 → **Sandbox 테스터** 생성
2. 아이폰 설정 → App Store → **샌드박스 계정**으로 로그인
3. TestFlight 빌드에서 각 상품 구매 → 지급되는지 확인
4. 젤리(소모성) 재구매 되는지, 비소모성 **구매 복원** 되는지 확인

---

## 5. 체크리스트
- [ ] 14개 제품 **제품 ID 정확히** 등록 + 유형 맞음(젤리5 + 패스3(`idle_pass_c`·`buff_pass`·`growth_pass`) + 주간 묶음 = 소모성 / 스타터 + 스킨2 + 입문2 = 비소모성)
- [ ] 스킨 2종 설명은 iOS 전용 판(지뢰 단어 없음)
- [ ] 유료 계약 + 은행/세금
- [ ] `APPLE_SHARED_SECRET` 시크릿 등록 + 함수 재배포
- [ ] 샌드박스에서 구매·복원 확인
- [ ] 앱 버전과 IAP 함께 심사 제출
