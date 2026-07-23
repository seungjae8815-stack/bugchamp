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

**"앱 내 구입"** 에서 **+** → 유형 선택 → 아래 표대로 11개 생성.

| # | 제품 ID (**정확히**) | App Store 유형 | 참조 이름 | 가격(₩ 티어) |
|---|---|---|---|---|
| 1 | `jelly_s`  | **소모성**(Consumable) | 곤충젤리 소 | 1,200 |
| 2 | `jelly_m`  | **소모성** | 곤충젤리 중 | 5,500 |
| 3 | `jelly_l`  | **소모성** | 곤충젤리 대 | 11,000 |
| 4 | `jelly_xl` | **소모성** | 곤충젤리 특대 | 29,000 |
| 5 | `jelly_xxl`| **소모성** | 곤충젤리 최대 | 59,000 |
| 6 | `remove_ads`       | **비소모성**(Non-Consumable) | 광고 제거 패스 | 7,700 |
| 7 | `starter_pack`     | **비소모성** | 스타터 패키지 | 5,500 |
| 8 | `idle_pass`        | **비소모성** | 곤충학자 패스 30일 | 9,900 |
| 9 | `skin_gold_rhino`  | **비소모성** | 황금 장수풍뎅이 | 3,300 |
| 10| `skin_albino_stag` | **비소모성** | 알비노 사슴벌레 | 3,300 |
| 11| `theme_arena`      | **비소모성** | 아레나 테마 | 2,200 |

> **유형 근거**: 앱은 젤리만 `buyConsumable`(재구매 가능), 나머지는 `buyNonConsumable`.
> App Store 유형을 앱의 구매 방식과 일치시켜야 한다.
> **idle_pass** 는 자동갱신 구독이 아니라 비소모성으로 등록(앱이 서버 `passExpiresAt`
> 로 30일 만료를 관리). 구독 그룹/자동갱신 만들지 말 것.

### 각 제품 입력
- **참조 이름**: 위 표(내부용, 사용자에게 안 보임)
- **가격**: 한국 원화 기준 티어 선택(다른 나라는 Apple 자동 환산)
- **현지화(표시 이름/설명)**: ko/en/ja — `iap.json` 의 `name`/`desc` 값 사용
- **심사 스크린샷**: 상점 화면 캡처 1장(11개 공통으로 같은 화면 써도 됨)
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
- [ ] 11개 제품 **제품 ID 정확히** 등록 + 유형 맞음(젤리5=소모성 / 나머지6=비소모성)
- [ ] 유료 계약 + 은행/세금
- [ ] `APPLE_SHARED_SECRET` 시크릿 등록 + 함수 재배포
- [ ] 샌드박스에서 구매·복원 확인
- [ ] 앱 버전과 IAP 함께 심사 제출
