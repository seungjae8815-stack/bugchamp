# server — Bug Champ 권위 서버

재화·진행도를 **서버가 소유**하기 위한 순수 Dart 서버.
설계·단계 계획은 `docs/server_authority_design.md`.

## 왜 Dart 인가

`core_models` / `core_run` / `core_battle` 을 **그대로 import** 하기 위해서다.
게임 로직이 3,700줄인데 TypeScript 로 다시 짜면 밸런스 JSON 하나 고칠 때마다
두 벌을 맞춰야 하고, 결정론 전투는 한쪽만 달라도 결과가 갈린다.
**로직은 한 벌이어야 한다.**

## 현재 상태 (P1)

| 엔드포인트 | 인증 | 설명 |
|---|---|---|
| `GET /healthz` | 불필요 | Cloud Run 헬스체크 |
| `GET /state` | 필요 | 내 세이브 조회 |

아직 **읽기 전용**이다. 쓰기(액션) 이관은 P2 부터.

## 환경변수

| 이름 | 용도 |
|---|---|
| `SUPABASE_URL` | 프로젝트 URL |
| `SUPABASE_SERVICE_ROLE_KEY` | RLS 우회 쓰기 (🔴 비밀) |
| `PORT` | Cloud Run 이 주입(기본 8080) |

> 🔴 `SUPABASE_SERVICE_ROLE_KEY` 는 **절대 앱·저장소에 넣지 않는다.**

### JWT 시크릿은 필요 없다

이 프로젝트는 **비대칭 서명(ES256 / ECC P-256)** 을 쓴다.
서버는 `/auth/v1/.well-known/jwks.json` 의 **공개키**로 검증하므로
공유 시크릿을 들고 있을 필요가 없다.

대칭키(HS256)였다면 그 값을 아는 쪽은 누구든 임의의 사용자로 위장할 수 있어
서버 유출이 곧 전면 위조로 이어진다. 공개키만 두면 서버가 털려도
토큰을 만들어낼 수는 없다.

**HS256 토큰은 알고리즘 단계에서 거부한다** — 레거시 공유 시크릿이 남아 있어도
그것으로 서명한 토큰이 통과하면 다운그레이드 통로가 되기 때문이다.

## 로컬 실행

```powershell
$env:SUPABASE_URL="https://xxx.supabase.co"
$env:SUPABASE_SERVICE_ROLE_KEY="..."
dart run bin/server.dart
```

## 테스트

```powershell
cd packages\server ; dart test
```

인증은 보안 핵심이라 위조 서명·`alg:none`·**HS256 다운그레이드**·페이로드 교체·
만료·nbf·발급자 불일치까지 테스트로 막아두었다.
손댈 때 반드시 테스트를 함께 확인할 것.

## 배포 (Cloud Run)

```powershell
# 워크스페이스 루트에서
gcloud run deploy bugchamp-server `
  --source . `
  --region asia-northeast3 `
  --set-secrets "SUPABASE_SERVICE_ROLE_KEY=supabase-service-role:latest" `
  --set-env-vars "SUPABASE_URL=https://xxx.supabase.co"
```

비밀은 **Secret Manager** 로 주입한다(`--set-env-vars` 로 넣으면 콘솔에 노출된다).
