# 특정 계정에 IAP 상품 지급 (`/admin/grant`)

보상·사과·테스트 목적으로 **결제 없이** 상품을 넣어 준다.

## 왜 이렇게 만들었나

지급 로직을 따로 쓰지 않고 **결제 경로(`grantPurchase`)를 그대로 재사용**한다.
따로 쓰면 "산 사람과 받은 사람의 상태가 다른" 버그가 조용히 생긴다 — 패스
연장 규칙, 스타터 1회 제한, 스킨 소유가 전부 결제와 똑같이 처리된다.

세이브는 **서버 저장본을 직접 고친다**. 패스·스타터는 서버 소유 필드
(`GameActions._serverOwnedKeys`)라 앱이 올려도 서버 값으로 덮이므로, 서버에
넣어야 실제로 들어간다.

## 쓰는 법 — 운영 패널 (권장)

`https://bugchamp-server-.../admin` → **지급** 탭.

1. 유저 uuid 붙여넣기
2. 상품 고르기 (목록은 서버의 `iap.json` 에서 실시간으로 받아온다 —
   화면에 박아 두면 상품이 바뀔 때 조용히 낡는다)
3. **사유** 입력 (중복 지급을 막는 열쇠 — 아래 참고)
4. 지급하기

지급 후 화면에 **패스 만료일·스타터 보유 여부**가 그대로 찍힌다. "이미
지급된 건입니다"와 "지급 완료"를 구분해서 보여준다 — 뭉쳐 놓으면 두 번
눌러 놓고 두 배로 들어간 줄 안다.

## 쓰는 법 — 명령줄

```powershell
$key  = "<ADMIN_KEY>"    # Secret Manager 의 bugchamp-admin-key
$url  = "https://bugchamp-server-867649520275.asia-northeast3.run.app/admin/grant"
$uid  = "<유저 uuid>"     # 아래 '유저 찾기' 참고

# 스타터 패키지
irm $url -Method Post -Headers @{ "x-admin-key" = $key } `
  -ContentType "application/json" `
  -Body (@{ userId=$uid; productId="starter_pack"; reason="2026-09-보상" } | ConvertTo-Json)

# 곤충학자 패스 (30일)
irm $url -Method Post -Headers @{ "x-admin-key" = $key } `
  -ContentType "application/json" `
  -Body (@{ userId=$uid; productId="idle_pass"; reason="2026-09-보상" } | ConvertTo-Json)

# 무한 버프 패스 (30일)
irm $url -Method Post -Headers @{ "x-admin-key" = $key } `
  -ContentType "application/json" `
  -Body (@{ userId=$uid; productId="buff_pass"; reason="2026-09-보상" } | ConvertTo-Json)
```

응답에 `passExpiresAt` · `buffPassExpiresAt` · `starterBought` 가 실려 온다 —
**들어갔는지 눈으로 확인할 것**.

## ⚠️ `reason` 이 중복 지급을 막는다

`purchaseId` 를 `admin:<상품>:<사유>` 로 만든다. 같은 사유로 두 번 부르면
두 번째는 **조용히 무시**되고 `alreadyGranted: true` 가 온다(멱등).

- 실수로 두 번 눌러도 두 배로 나가지 않는다.
- **일부러 더 주려면 사유를 바꾼다** — `reason="2026-09-보상2"`.
- 나중에 세이브만 봐도 `admin:` 접두사로 **결제가 아니라 지급**임을 구분한다.

## 유저 찾기 (uuid)

Supabase SQL Editor:

```sql
select id, nickname, trophies, stage, tier
from profiles where nickname = '<닉네임>';
```

닉네임은 바뀔 수 있으니 **uuid 를 기록해 둔다**. 문의(텔레그램)로 들어온 건은
메시지 하단에 uid 가 함께 찍힌다 — 그걸 쓰면 정확하다.

## 상품 id

| id | 종류 | 내용 |
|---|---|---|
| `starter_pack` | starter | 스타터 패키지(계정당 1회) |
| `idle_pass` | pass | 곤충학자 패스 30일 |
| `buff_pass` | buffPass | 무한 버프 패스 30일 |
| `jelly_s` … `jelly_xxl` | jelly | 젤리 팩 |
| `skin_gold_rhino` · `skin_albino_stag` | skin | 스킨 |

id 를 틀리면 404 와 함께 **아는 id 목록**을 돌려준다.

## 적용 시점

서버 저장본을 바꾸므로, 유저 앱은 다음 동기화(최대 60초) 또는 재접속에
반영된다. 앱이 켜져 있으면 로컬이 더 진행된 것으로 판단해 잠깐 미뤄질 수
있다 — 그때도 다음 업로드/재접속에 서버 값이 이긴다(패스는 서버 소유 필드).

## 주의

- `starter_pack` 은 이미 산 계정에 못 넣는다(`already_owned`). 스타터는
  **계정당 1회**가 상품 정의라, 여기서 뚫으면 결제한 사람과 형평이 깨진다.
- 패스는 남은 기간에 **이어 붙는다**. 이미 20일 남은 계정에 주면 50일이 된다.
