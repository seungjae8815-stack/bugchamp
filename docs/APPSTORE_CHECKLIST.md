# iOS App Store 출시 체크리스트 (심사 거절 방지 중심)

> 앱은 Flutter 라 iOS 를 지원하지만 **빌드·제출은 Mac 이 필요**하다.
> Mac 이 없으면 **Codemagic**(클라우드 맥, `codemagic.yaml`)으로 빌드한다.
> 아래 ✅ = 코드/설정에 이미 반영됨, ⏳ = 사장님이 Mac/웹에서 할 일.

---

## A. 코드·설정 (✅ 이미 준비됨 — Windows 에서 완료)

| 항목 | 심사 근거 | 상태 |
|---|---|---|
| **Sign in with Apple** (구글 로그인과 나란히, iOS 한정 버튼) | 4.8 | ✅ 코드 |
| **App Tracking Transparency** 프롬프트 + `NSUserTrackingUsageDescription` | 5.1.2 | ✅ |
| **SKAdNetwork** ID 목록(Info.plist) | 광고 어트리뷰션 | ✅ |
| **무관용 이용약관**(불쾌콘텐츠·학대 금지) + 앱 내 링크 | 1.2(UGC/채팅) | ✅ (호스팅만 ⏳) |
| 채팅 **필터·신고·차단** | 1.2 | ✅ 구현됨 |
| **계정 삭제** 앱 내 제공 | 5.1.1(v) | ✅ (설정→계정삭제) |
| `ITSAppUsesNonExemptEncryption=false` (수출규정 질문 제거) | — | ✅ |
| 개발자/치트 메뉴 비노출(kDebugMode 게이트) | 2.3.1 | ✅ |
| 표시명 Bug Champ (ko 곤충 키우기·ja 昆虫育成 은 Mac 에서 lproj) | — | ✅ 기본 |

---

## B. Mac / App Store Connect 에서 할 일 (⏳)

### B-1. 계정·기본
- [ ] **Apple Developer Program** 가입($99/년)
- [ ] App Store Connect → 앱 생성, 번들 ID **`com.bugchamp.app`** (안드로이드와 동일)
- [ ] `docs/terms_of_use.html` 을 **`https://dkc260701.github.io/bugchamp-policy/terms.html`** 로 호스팅
      (앱 내 이용약관 링크가 이 주소를 가리킨다)

### B-2. Sign in with Apple (4.8 — 안 하면 거절)
- [ ] Apple Developer → Identifiers → App ID `com.bugchamp.app` 에 **Sign In with Apple** capability 체크
- [ ] **Services ID** + **Sign in with Apple 키(.p8)** 생성
- [ ] **Supabase → Authentication → Providers → Apple** 활성화, 위 Services ID·키·Team ID 입력
- [ ] Xcode(또는 Codemagic 서명)에서 **Sign In with Apple** entitlement 포함

### B-3. Google 로그인 (iOS)
- [ ] Google Cloud → 사용자 인증 정보 → **iOS OAuth 클라이언트** 생성(번들 ID)
- [ ] 그 클라이언트의 **역방향 클라이언트 ID** 를 iOS `Info.plist` `CFBundleURLTypes` 에 추가
      (Mac 에서 추가 — 없으면 iOS 구글 로그인 실패)

### B-4. 광고(AdMob iOS)
- [ ] AdMob → **iOS 앱 별도 생성**(안드로이드와 다름) → 앱 ID 획득
- [ ] `ios/Runner/Info.plist` 의 `GADApplicationIdentifier` 를 **실제 iOS 앱 ID** 로 교체
      (지금은 구글 테스트 앱 ID 플레이스홀더)
- [ ] **보상형 광고 단위** 생성 → Codemagic 환경변수 `ADMOB_REWARDED_IOS` 에 넣기

### B-5. 인앱결제 (App Store Connect)
- [ ] **소비형/비소비형 상품 11개** 생성 — **제품 ID 를 `iap.json` 과 정확히 일치**
      (`docs/iap_products_table.md` 의 제품 ID 그대로). 앱은 같은 ID 로 조회한다.
- [ ] 유료 계약(Paid Apps) 동의 + 은행·세금 정보
- [ ] 심사 제출 시 IAP 도 함께 "심사에 추가"

### B-6. 개인정보·등급·메타데이터
- [ ] **개인정보 보호 항목(Privacy Nutrition Labels)** — Play 데이터 보안과 동일하게:
      이름·이메일·사용자ID·구매내역·메시지(채팅)·앱상호작용·기기ID(광고)
- [ ] **연령 등급** 설문 — 만화적 곤충 대결(경미), 사용자 간 소통(채팅) 예
- [ ] **스크린샷**(6.7"·6.5"·5.5" 아이폰, iPad 필요 시)
- [ ] 개인정보처리방침 URL: `https://dkc260701.github.io/bugchamp-policy/`
- [ ] **심사 메모(App Review Notes)**: "로그인 없이 모든 기능 이용 가능(익명 계정).
      채팅은 금칙어 필터·신고·차단 구현. 결제는 서버 영수증 검증." — 데모 계정 불필요.

---

## C. 빌드 (Codemagic)

`codemagic.yaml` 참조. 환경변수 그룹 `bugchamp_ios` 에 시크릿을 넣고
`ios-release` 워크플로 실행 → TestFlight 자동 배포 → 콘솔에서 심사 제출.

> 안드로이드와 달리 iOS 는 **위 B 항목(특히 Sign in with Apple·iOS OAuth·
> AdMob iOS·IAP)이 끝나야** 실제로 로그인·광고·결제가 동작한다.

---

## D. 사장님이 과거에 자주 걸렸을 포인트 — 이번엔 이렇게 막았다

- **4.8(제3자 로그인만 있음)** → Sign in with Apple 추가 ✅
- **1.2(UGC 조정 수단·약관 없음)** → 필터·신고·차단 + 무관용 약관 ✅
- **5.1.1(v)(계정 삭제 없음)** → 앱 내 계정 삭제 ✅
- **5.1.2(ATT 없이 IDFA 사용)** → ATT 프롬프트 + 문구 ✅
- **2.1(불완전·크래시·플레이스홀더)** → 결제 외 전 기능 동작, 아트 폴백 있음
- **3.1.1(외부 결제 유도)** → 플랫폼 결제만, 외부 링크 없음 ✅
