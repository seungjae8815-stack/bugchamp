# 출시 프로필 (빌드에 필요한 값 요약)

상세 절차·사고 기록은 `docs/release_cadence.md` 가 원본이다. 이 파일은 빠르게 찾기 위한 요약이다.

- 앱 폴더: `packages/app` · 패키지명 `com.bugchamp.app` (개발용 `com.bugchamp.app.dev`)
- dart-define(AAB·릴리즈 APK 공통, 하나라도 빠지면 로그인·동기화가 죽은 빌드가 나간다):
  `--dart-define-from-file=supabase.env.json` · `--dart-define-from-file=admob.env.json` ·
  `--dart-define=GAME_SERVER_URL=https://bugchamp-server-867649520275.asia-northeast3.run.app`
- 검증: `release_cadence.md` §3 의 2.5(서버 주소·supabase 문자열) · 2.6(R8 keep) 스니펫
- 서버: Cloud Run(asia-northeast3). 배포는 사장님이 `!` 로 직접. **앱보다 서버가 먼저**, SQL 이 있으면 SQL 이 서버보다 먼저.
  출시 뒤 `LATEST_VERSION_ANDROID/IOS`(업데이트 안내) · `MIN_SUPPORTED_VERSION_*`(강제 업데이트) env 갱신.
- iOS: Codemagic 워크플로 `ios-release`(main 푸시 후 사장님이 Start build) → TestFlight → 심사 제출
- 출시 노트: `docs/_release_notes_<버전>.txt`(Play, 세 언어 합계 500자) · `docs/_appstore_whatsnew_<버전>.txt`(iOS, 이모지·지뢰 단어 금지)
- adb: `C:\Users\Lenovo\AppData\Local\Android\Sdk\platform-tools\adb.exe` — 안 잡히면 `kill-server` → `start-server`
