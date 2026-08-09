# 출시 리듬 — 안드로이드 우선, iOS 는 따라잡기

> 2026-08-08 확정. iOS 심사가 느려 **두 스토어의 버전이 벌어지는 것을 정상으로
> 받아들인다.** 안드로이드는 계속 내보내고, iOS 는 심사가 통과할 때마다
> "그 시점의 최신 코드"를 올린다.

---

## 1. 버전 규칙

| 항목 | 규칙 |
|------|------|
| `versionName` (1.0.5) | 스토어에 **내보낼 때마다** 올린다. 두 플랫폼이 공유한다. |
| 빌드번호 (20260809) | **매 빌드 +1.** 날짜처럼 생겼지만 이제 날짜가 아니라 **단조 증가 숫자**다. |
| 고치는 곳 | `packages/app/pubspec.yaml` 의 `version:` **한 줄뿐**. 앱 내 표기는 여기서 읽는다. |

> ⚠️ 빌드번호는 하루에 여러 번 빌드해도 겹치면 안 된다. 실제로 1.0.4 와 1.0.5 가
> 둘 다 `20260808` 이었다 — 그대로 올렸으면 두 스토어 모두 거부했다.
> 날짜에 맞추려 하지 말고 **그냥 1 씩 올린다.**

iOS 가 뒤처져 있으면 **버전 이름을 건너뛴다**. 안드로이드가 1.0.5→1.0.7 까지
갔는데 iOS 심사가 이제 끝났다면, iOS 는 1.0.4 다음에 **1.0.7 을 올린다**.
중간 버전을 따로 만들지 않는다 — 스토어는 건너뛰기를 허용한다.

## 2. 업데이트 안내는 플랫폼별로 따로

서버 `/version?platform=ios|android` 가 플랫폼별 값을 돌려준다. **한쪽만
출시됐는데 양쪽에 업데이트를 권하면, 아직 못 받는 쪽은 없는 업데이트를
안내받고 스토어에 갔다가 되돌아온다.**

```powershell
# 안드로이드 1.0.5(20260809) 가 프로덕션에 올라간 뒤에만 실행
gcloud run services update bugchamp-server --region asia-northeast3 `
  --update-env-vars "LATEST_VERSION_ANDROID=20260809"

# iOS 심사가 통과해 실제로 내려받을 수 있게 된 뒤에만 실행
gcloud run services update bugchamp-server --region asia-northeast3 `
  --update-env-vars "LATEST_VERSION_IOS=20260812"
```

- `LATEST_VERSION_*` = 이 미만이면 **권장** 업데이트(닫을 수 있다).
- `MIN_SUPPORTED_VERSION_*` = 이 미만이면 **강제** 업데이트(입장 차단).
  → **iOS 쪽은 함부로 올리지 않는다.** 심사 대기 중에 올리면 iOS 유저가
  받을 수 있는 버전이 없는데 입장이 막힌다.
- 값이 안 잡혀 있으면 공용 `LATEST_VERSION`/`MIN_SUPPORTED_VERSION` 으로
  떨어진다(구버전 앱 호환). 재배포 없이 env 만 바꾸면 된다.

## 3. 안드로이드 출시 (자주)

```powershell
# 1) 버전 올리기 — pubspec.yaml 의 version: 한 줄
# 2) 빌드
cd packages\app
flutter build appbundle `
  --dart-define-from-file=supabase.env.json `
  --dart-define-from-file=admob.env.json `
  --dart-define=GAME_SERVER_URL=https://bugchamp-server-867649520275.asia-northeast3.run.app
# 3) build\app\outputs\bundle\release\app-release.aab 업로드
# 4) 출시 노트 = docs\_release_notes_<버전>.txt 를 통째로 붙여넣기
# 5) 프로덕션 반영 확인 후 LATEST_VERSION_ANDROID 갱신(§2)
```

**서버가 먼저다.** 서버 변경이 있으면 앱보다 **먼저** 배포한다 —
구버전 앱 + 새 서버는 안전하지만, 새 앱 + 구버전 서버는 깨진다.

## 4. iOS 출시 (심사 통과할 때마다)

Codemagic `ios-release` 워크플로가 IPA 를 빌드해 **TestFlight 까지** 올린다
(`submit_to_app_store: false` — 심사 제출은 콘솔에서 수동).

```
1) 안드로이드와 같은 코드 상태에서 워크플로 실행
2) TestFlight 확인 → App Store Connect 에서 심사 제출
3) 심사 통과·출시 완료 후에만 LATEST_VERSION_IOS 갱신(§2)
```

- 노트는 `docs\_appstore_whatsnew_<버전>.txt` — **이모지 금지**(심사 지적 이력).
- iOS 는 직전 출시본이 오래됐을 수 있으니, 노트에 **그 사이 안드로이드에
  나간 내용까지 합쳐서** 적는다.
- ⚠️ **심사 대기 중에는 새 버전을 제출할 수 없다.** 올리려면 진행 중인 심사를
  먼저 취소해야 한다 — 그래서 iOS 는 "쌓아서 한 번에" 가 맞다.

## 5. 체크리스트 (매 안드로이드 출시)

- [ ] ⚠️ **곤충 위조 구멍**이 아직 열려 있는지 확인 — 세이브를 편집해 5성 전설을
      만들면 PvP 를 이기고 **트로피·랭킹이 오염된다**. 서버 `validateTeam` 이
      소유 여부만 보고 스탯을 검증하지 않는다. 다음 업로드 전에 최소한
      **편성 시 스탯 상한 검증**을 넣을 것(종별 사이즈 범위·포텐셜 1~5·
      강화 총량 ≤ maxLevel).
- [ ] `pubspec.yaml` 빌드번호 +1 (직전 출시본과 겹치지 않는지 눈으로 확인)
- [ ] 서버 변경이 있으면 서버 먼저 배포
- [ ] `flutter test` · `flutter analyze` 통과
- [ ] 출시 노트 3개 언어 (ko 500자 / en 500자 / ja 500자 한도)
- [ ] AAB 업로드 → 프로덕션 반영
- [ ] `LATEST_VERSION_ANDROID` 갱신
- [ ] iOS 를 같이 낼 차례인지 판단 (§4)
