# 🚀 Play 스토어 출시 체크리스트

> 사업자(조직) 계정 기준. **비공개 테스트 14일 요건은 면제**되므로
> 준비물만 갖추면 내부 테스트 → 프로덕션까지 빠르게 갈 수 있다.
> (요건은 구글이 자주 바꾸므로 콘솔 안내를 최종 기준으로 볼 것.)

진행 순서: **A(코드) → B(계정·키) → C(콘솔 등록) → D(테스트) → E(출시)**

---

## A. 코드 — ✅ 완료

- [x] 인앱결제 실연동 (`StoreIapService`, 중복 지급 차단)
- [x] AdMob 보상형 광고 실연동 — 광고를 **끝까지 본 경우에만** 보상
- [x] 릴리즈 서명 설정(gradle 이 `key.properties` 를 읽음)
- [x] 릴리즈 빌드는 자동으로 실결제·실광고 모드
- [x] 개인정보처리방침 문서 작성 (`docs/privacy-policy.html`)
- [x] 스토어 등록정보 문안 작성 (`docs/store_listing.md`)

---

## B. 계정·키 — ⚠️ 사장님 작업

### B-1. 릴리즈 키스토어 만들기 (제일 먼저)
```powershell
keytool -genkey -v -keystore $env:USERPROFILE\bugchamp-upload.jks `
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
그다음 `packages\app\android\key.properties` 생성:
```properties
storePassword=<비밀번호>
keyPassword=<비밀번호>
keyAlias=upload
storeFile=C:/Users/Lenovo/bugchamp-upload.jks
```
> 🔴 **이 키를 잃어버리면 앱을 영영 업데이트할 수 없다.** 반드시 백업.
> (커밋은 안 된다 — 이미 gitignore 처리됨)

### B-2. 키 SHA-1 을 Google Cloud 에 등록 (구글 로그인용)
```powershell
keytool -list -v -keystore $env:USERPROFILE\bugchamp-upload.jks -alias upload
```
출력된 SHA-1 을 Google Cloud Console → 사용자 인증 정보 →
**Android 클라이언트**에 추가. 안 하면 릴리즈에서 구글 로그인이 실패한다.

> Play 앱 서명을 쓰면 구글이 **재서명**하므로, 업로드 후 Play Console →
> 설정 → 앱 서명 에 나오는 **앱 서명 키의 SHA-1도 함께 등록**해야 한다. (중요)

### B-3. AdMob 계정·광고 단위
1. https://admob.google.com 에서 앱 등록(Android, 패키지 `com.bugchamp.app`)
2. **보상형 광고 단위** 생성 → 두 개의 ID 를 받는다
   - 앱 ID: `ca-app-pub-XXXX~YYYY`
   - 광고 단위 ID: `ca-app-pub-XXXX/ZZZZ`
3. 앱 ID → `packages\app\android\local.properties` 에 추가:
   ```properties
   admobAppId=ca-app-pub-XXXX~YYYY
   ```
4. 광고 단위 ID → 빌드할 때 주입:
   ```
   --dart-define=ADMOB_REWARDED_ANDROID=ca-app-pub-XXXX/ZZZZ
   ```
> 넣지 않으면 **구글 테스트 광고**가 나온다(광고는 뜨지만 수익 0).
> 개발 중엔 오히려 이게 안전하다 — 실광고를 본인이 누르면 계정 정지될 수 있다.

### B-4. 개인정보처리방침 호스팅
`docs/privacy-policy.html` 을 공개 URL 로 올린다. GitHub Pages 가 가장 간단:
```powershell
gh api -X POST repos/seungjae8815-stack/bugchamp/pages `
  -f "source[branch]=main" -f "source[path]=/docs"
```
→ `https://seungjae8815-stack.github.io/bugchamp/privacy-policy.html`

---

## C. 그래픽 자산 — ⚠️ 사장님 작업

- [ ] 앱 아이콘 **512×512** PNG
- [ ] 피처 그래픽 **1024×500** (프롬프트는 `store_listing.md` §4)
- [ ] 폰 스크린샷 **최소 2장**(권장 6장) — 추천 구성도 `store_listing.md`

---

## D. Play Console 등록

- [ ] 앱 만들기(이름/언어/게임/무료)
- [ ] **스토어 등록정보** — `docs/store_listing.md` 복붙
- [ ] **개인정보처리방침 URL** 입력 (B-4)
- [ ] **콘텐츠 등급** 설문 — 예상 답변 `store_listing.md` §6
- [ ] **데이터 보안** 양식 — 예상 답변 `store_listing.md` §7
- [ ] **광고 포함** 신고 → 예
- [ ] **인앱 상품 11개 등록** → `docs/play_console_iap.md` §3 (id 정확히 일치!)
- [ ] 대상 연령·타겟 국가 설정

### 빌드 & 업로드
```powershell
cd packages\app
flutter build appbundle --dart-define-from-file=supabase.env.json `
  --dart-define=ADMOB_REWARDED_ANDROID=ca-app-pub-XXXX/ZZZZ
```
→ `build\app\outputs\bundle\release\app-release.aab` 업로드

---

## E. 테스트 → 출시

- [ ] **내부 테스트** 트랙에 업로드 → 본인 계정으로 설치
- [ ] 라이선스 테스터 등록 후 **결제 전 항목 테스트**
      (체크리스트: `docs/play_console_iap.md` §5)
- [ ] 실광고(테스트 단위)로 보상 흐름 확인 — 끝까지 안 보면 보상 없어야 함
- [ ] 구글 로그인 → 클라우드 세이브 동작 확인(SHA-1 등록 후)
- [ ] 프로덕션 출시 신청

---

## 🔴 출시 전 마지막으로 다시 볼 것

1. **영수증 서버 검증이 아직 없다** (`docs/monetization.md` §6).
   소규모 출시는 가능하나, 매출이 붙으면 반드시 추가.
2. **일본어 번역이 미완성**이다. 일본 대상 출시는 미루거나 영어 폴백으로 나간다.
3. 첫 출시는 **한국만** 대상으로 좁게 시작하는 편이 안전하다
   (문제 발견 시 영향 범위가 작다).
