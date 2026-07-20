# 구글 플레이 인앱결제 — 콘솔 설정 가이드

> 코드는 다 붙었다(`StoreIapService`). **결제를 실제로 테스트하려면 아래 콘솔 작업이 먼저**다.
> 앱이 Play Console 에 한 번도 올라가지 않으면 결제창 자체가 뜨지 않는다 —
> 이건 코드 문제가 아니라 구글의 구조다.

---

## 0. 왜 폰에 그냥 깔아서는 테스트가 안 되나

구글 결제는 **"Play 가 배포한 앱"** 에서만 동작한다. `flutter run` 으로 직접 설치한
APK 는 Play 를 거치지 않았으므로 `queryProductDetails` 가 상품을 못 찾는다
(로그에 `[iap] 스토어에 없는 상품 id: ...` 가 찍힌다).

따라서 순서는 **① 서명 키 만들기 → ② 내부 테스트로 업로드 → ③ 상품 등록 →
④ 테스터 등록 → ⑤ Play 에서 설치해서 테스트** 다.

---

## 1. 릴리즈 서명 키(키스토어) 만들기

아직 안 했다면 이게 첫 단계다. **이 키를 잃어버리면 앱을 영영 업데이트할 수 없으니**
반드시 안전한 곳에 백업할 것(비밀번호도 함께).

```powershell
keytool -genkey -v -keystore $env:USERPROFILE\bugchamp-upload.jks `
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

그다음 `packages\app\android\key.properties` 를 만든다(**커밋 금지** — gitignore 확인):

```properties
storePassword=<위에서 정한 비밀번호>
keyPassword=<위에서 정한 비밀번호>
keyAlias=upload
storeFile=C:/Users/<사용자>/bugchamp-upload.jks
```

> ⚠️ 이 키의 **SHA-1** 을 Google Cloud OAuth 클라이언트에도 등록해야
> 릴리즈 빌드에서 **구글 로그인**이 동작한다(지금은 디버그 키만 등록돼 있음).
> ```powershell
> keytool -list -v -keystore $env:USERPROFILE\bugchamp-upload.jks -alias upload
> ```

---

## 2. 내부 테스트 트랙에 업로드

```powershell
cd packages\app
flutter build appbundle --dart-define-from-file=supabase.env.json
# 산출물: build\app\outputs\bundle\release\app-release.aab
```

> 릴리즈 빌드는 `STORE_IAP` 를 안 줘도 **자동으로 스토어 결제**를 쓴다
> (`main.dart` 의 `_useStoreIap` 기본값 = `kReleaseMode`).
> 개발용 무료 지급(`LocalIapService`)이 릴리즈에 딸려 나가는 사고를 막는 구조다.

Play Console → **테스트 → 내부 테스트 → 새 버전 만들기** → `.aab` 업로드 → 출시.

---

## 3. 인앱 상품 등록 (⚠️ id 가 정확히 일치해야 함)

Play Console → **수익 창출 → 인앱 상품 / 구독**.

`packages/app/assets/data/iap.json` 의 `id` 와 **글자 하나까지 똑같이** 등록한다.
하나라도 다르면 그 상품만 조용히 "판매 준비 중"으로 뜬다.

**11개 전부** 등록해야 한다(2026-07-20 기준):

| 상품 ID | 가격(참고) | 소모성? |
|---|---|---|
| `remove_ads` | ₩7,700 | ✗ 1회 |
| `starter_pack` | ₩5,500 | ✗ 1회 |
| `idle_pass` | ₩9,900 / 30일 | ✗ (아래 참고) |
| `jelly_s` | ₩1,200 | ✓ 반복 구매 |
| `jelly_m` | ₩5,500 | ✓ |
| `jelly_l` | ₩11,000 | ✓ |
| `jelly_xl` | ₩29,000 | ✓ |
| `jelly_xxl` | ₩59,000 | ✓ |
| `skin_gold_rhino` | ₩3,300 | ✗ 1회 |
| `skin_albino_stag` | ₩3,300 | ✗ 1회 |
| `theme_arena` | ₩2,200 | ✗ 1회 |

전부 **"인앱 상품(관리형 상품)"** 으로 만들면 된다. 구글은 소모성/비소모성을
상품 등록 때 구분하지 않고, 앱이 `consume` 하느냐로 갈린다 — 그건 코드가
`iap.json` 의 `kind` 를 보고 알아서 처리한다.

> 정확한 최신 목록은 항상 `iap.json` 이 원본이다. 확인:
> ```powershell
> cd packages\app
> python -c "import json,io;d=json.load(io.open('assets/data/iap.json',encoding='utf-8'));[print(p['id'],p['kind'],p['priceKrw']) for p in d['products']]"
> ```

**가격은 콘솔이 원본이다.** 앱은 스토어가 알려준 현지 가격을 표시하고,
`iap.json` 의 원화 값은 스토어 조회 전 폴백용 참고치일 뿐이다.

### `idle_pass` — 구독으로 갈지 결정 필요
현재 코드는 **관리형 상품(30일치를 사면 남은 기간에 누적)** 으로 동작한다.
자동 갱신 구독으로 바꾸려면 갱신·해지·유예 처리가 추가로 필요하다.
**출시 초기에는 관리형이 단순하고 분쟁도 적다** — 이대로 가길 권한다.

---

## 4. 라이선스 테스터 등록 (실제 결제 없이 테스트)

Play Console → **설정 → 라이선스 테스트** 에 본인 구글 계정 추가.
그러면 결제창이 뜨되 **실제로 청구되지 않는다**(테스트 카드).

- 내부 테스트 트랙의 **테스터 목록**에도 같은 계정을 넣어야 한다.
- 폰에서 **그 계정으로 로그인**한 뒤, 내부 테스트 링크로 설치할 것.
  (`flutter run` 으로 깐 앱은 안 된다 — §0)

---

## 5. 테스트 체크리스트

- [ ] 상점에 **개발 모드 배너가 사라짐**(스토어 연결됨)
- [ ] 가격이 콘솔에 등록한 **현지 가격**으로 표시됨
- [ ] 젤리 구매 → 결제창 → 완료 → 젤리 지급
- [ ] **같은 젤리 팩을 다시 구매 가능**(소모성 consume 확인)
- [ ] 광고제거 구매 → 이후 "보유중"으로 잠김
- [ ] 결제창에서 **뒤로가기(취소)** → "구매를 취소했어요"(실패 아님)
- [ ] 구매 도중 **앱 강제종료** → 재실행 시 자동 지급(스트림 재전달)
- [ ] **구매 복원** 버튼 → 비소모성(광고제거·스킨) 복구, 젤리는 중복 지급 안 됨
- [ ] 비행기모드에서 구매 시도 → 실패 안내

---

## 6. ⚠️ 아직 안 된 것 — 영수증 서버 검증

현재는 **클라이언트만으로** 구매를 인정한다. 루팅 기기 + 결제 후킹 앱으로
가짜 구매를 만들어 상품을 공짜로 받을 수 있다는 뜻이다.

- 지금 있는 방어: 구매 식별자 원장(`redeemedPurchases`)으로 **중복 지급만** 차단.
- 없는 것: 그 영수증이 **진짜 구글이 발급한 것인지** 확인하는 절차.

제대로 하려면 Supabase Edge Function 에서 **Google Play Developer API** 로
`purchases.products.get` 을 호출해 토큰을 검증해야 하고, 그러려면 GCP 서비스 계정과
Play Console 연결이 필요하다.

**판단**: 무료 테스트/소규모 출시 단계에선 이대로도 굴러간다. 다만
**매출이 의미 있게 나기 시작하면 반드시 붙여야 한다.** 준비되면 말해달라.
