# 텔레그램 일일 사용자 리포트 (매일 아침 9시)

> 매일 **09:00 KST** 에 곤충키우기 사용자 통계를 텔레그램으로 보낸다.
> 서버리스(Supabase Edge Function + pg_cron) — 별도 서버 안 띄운다.
> 함수 소스: `supabase/functions/daily-report/index.ts`

- **받는 사람 chat_id**: `1025640548` (강대표 / @TLTL1982)
- **봇**: 아스트레일과 **같은 봇**을 공유 → 메시지 맨 앞에 `🐛 곤충키우기 (Bug Champ)` 를 붙여 구분한다.
- **프로젝트 ref**: `rvmpwyycivmtrbbynjyy`

---

## 보내는 내용 (예시)

```
🐛 곤충키우기 (Bug Champ)
📅 2026-08-05 리포트

🎮 실사용(24h): 12명
📆 주간(7일): 53명
🗓 월간(30일): 107명
🌱 정착 사용자: 43명
🔁 D1 리텐션: 27% (15명 중 4명)

🔑 로그인 유저: 10명 (구글 9·애플 2)
💾 세이브 보유자: 110명
👥 누적 계정(익명포함): 138명
🆕 오늘 신규: 9명
💰 결제: 0건 (테스트 4건 제외)
```

> ⚠️ **배포된 함수가 저장소와 어긋난 적이 있다.** 2026-08 에 대시보드에서 직접
> 배포한 버전이 돌고 있어, 저장소 코드를 고쳐도 리포트가 안 바뀌었다.
> **반드시 이 저장소를 고친 뒤 배포**하고, 대시보드 편집기로 직접 수정하지 않는다.

| 항목 | 소스 |
|---|---|
| **실사용(24h)** | 최근 24h 에 세이브를 올린 `saves` = **DAU. 실질 사용자는 이 숫자다.** |
| 주간/월간 | 같은 기준의 7일·30일 |
| 정착 사용자 | 가입 24h 넘긴 계정 중 최근 7일 접속 — 설치만 하고 떠난 사람 제외 |
| D1 리텐션 | 어제 신규(`d1_new`) 중 오늘 접속한 수(`d1_returned`) |
| 계정 연동 | `auth.users.is_anonymous = false` (구글·애플 로그인) |
| 누적 설치 | `auth.users` 전체 |
| 결제 | `verified_purchases` 중 `environment = 'production'` |

> ⚠️ **`누적 설치`를 사용자 수로 읽으면 안 된다.** 앱이 첫 실행에 `signInAnonymously()`
> 를 부르므로 **설치 1회 = 계정 1개**이고, 앱을 지우면 신원이 사라져 재설치하면
> **또 새 계정**이 생긴다. 사람 수가 아니라 설치 시도 횟수에 가깝다.
>
> ⚠️ **결제는 `environment` 로 걸러야 한다.** 예전엔 테이블 전체를 세서 라이선스
> 테스터·샌드박스(TestFlight·심사) 결제가 매출로 잡혔다. `verify-purchase` 가
> Apple 은 응답의 `environment`, Google 은 `purchaseType`(0=Test, 1=Promo)을 보고
> 기록한다. **지급은 어느 값이든 정상 진행한다** — 테스트도 아이템이 나와야 QA 가 된다.

---

## 설정 순서 (1회)

### 1) 통계 RPC 생성 — SQL Editor 에 실행

```sql
-- 결제 출처 컬럼(테스트/샌드박스 구분). 없으면 매출 집계에 테스트가 섞인다.
alter table public.verified_purchases
  add column if not exists environment text not null default 'production';

create index if not exists verified_purchases_env_idx
  on public.verified_purchases (environment);

-- 곤충키우기 일일 통계: service_role(Edge Function)만 실행.
-- ※ saves 는 user_id 컬럼이 없다 — **id 가 곧 auth.users.id** 다.
create or replace function public.bugchamp_daily_stats()
returns jsonb language plpgsql security definer
set search_path = public, auth as $$
declare r jsonb;
begin
  select jsonb_build_object(
    'installs',       (select count(*) from auth.users),
    'new_today',      (select count(*) from auth.users
                         where created_at >= now() - interval '24 hours'),

    'dau',            (select count(*) from public.saves
                         where updated_at >= now() - interval '24 hours'),
    'wau',            (select count(*) from public.saves
                         where updated_at >= now() - interval '7 days'),
    'mau',            (select count(*) from public.saves
                         where updated_at >= now() - interval '30 days'),

    -- 정착: 가입 하루 넘긴 계정 중 최근 7일 접속(설치만 하고 떠난 사람 제외)
    'retained',       (select count(*) from public.saves s
                         join auth.users u on u.id = s.id
                        where s.updated_at >= now() - interval '7 days'
                          and u.created_at <  now() - interval '24 hours'),

    'd1_new',         (select count(*) from auth.users
                        where created_at >= now() - interval '48 hours'
                          and created_at <  now() - interval '24 hours'),
    'd1_returned',    (select count(*) from public.saves s
                         join auth.users u on u.id = s.id
                        where u.created_at >= now() - interval '48 hours'
                          and u.created_at <  now() - interval '24 hours'
                          and s.updated_at >= now() - interval '24 hours'),

    'linked',         (select count(*) from auth.users where is_anonymous = false),
    'linked_google',  (select count(distinct user_id) from auth.identities
                        where provider = 'google'),
    'linked_apple',   (select count(distinct user_id) from auth.identities
                        where provider = 'apple'),

    -- 세이브를 한 번이라도 올린 계정(서버까지 도달한 설치)
    'saves_total',    (select count(*) from public.saves),

    'purchases',      (select count(*) from public.verified_purchases
                        where environment = 'production'),
    'purchases_test', (select count(*) from public.verified_purchases
                        where environment <> 'production')
  ) into r;
  return r;
end; $$;

-- 클라이언트(anon/authenticated)는 실행 불가. Edge Function 의 service_role 만 실행.
revoke all on function public.bugchamp_daily_stats() from public, anon, authenticated;
grant execute on function public.bugchamp_daily_stats() to service_role;
```

### 2) 시크릿 등록 — **별도 터미널**에서 (Claude 에게 값 주지 말 것)

```bash
# 공유 비밀 하나 생성(크론↔함수 인증용). 이 값을 아래 3)의 크론에도 똑같이 넣는다.
openssl rand -hex 16          # 예: 출력된 32자리 문자열을 복사

supabase secrets set \
  TELEGRAM_BOT_TOKEN="<아스트레일과 같은 봇 토큰>" \
  REPORT_SECRET="<위에서 생성한 32자리>" \
  --project-ref rvmpwyycivmtrbbynjyy
```
> `TELEGRAM_CHAT_ID` 는 기본값 `1025640548` 이라 안 넣어도 됨(바꾸려면 함께 set).
> `SUPABASE_URL`·`SUPABASE_SERVICE_ROLE_KEY` 는 Supabase 가 자동 주입.

### 3) 함수 배포

```bash
# supabase CLI 가 전역 설치돼 있지 않다면 npx 로 그대로 쓸 수 있다(Node 필요).
npx supabase login          # 최초 1회
npx supabase functions deploy daily-report --no-verify-jwt \
  --project-ref rvmpwyycivmtrbbynjyy
npx supabase functions deploy verify-purchase \
  --project-ref rvmpwyycivmtrbbynjyy
```
> `--no-verify-jwt` 는 `daily-report` 에만 준다: 크론(pg_net)이 JWT 없이 호출한다.
> 대신 함수가 `REPORT_SECRET` 로 막는다. `verify-purchase` 는 앱이 JWT 를 달고 부른다.

### 4) 크론 등록 — SQL Editor 에 실행 (매일 09:00 KST)

```sql
-- pg_cron / pg_net 확장 활성화(이미 켜져 있으면 무시됨)
create extension if not exists pg_cron;
create extension if not exists pg_net;

-- 09:00 KST = 00:00 UTC. (Supabase 크론은 UTC 기준)
select cron.schedule(
  'bugchamp-daily-report',
  '0 0 * * *',
  $$
    select net.http_post(
      url     := 'https://rvmpwyycivmtrbbynjyy.supabase.co/functions/v1/daily-report',
      headers := '{"Content-Type": "application/json"}'::jsonb,
      body    := jsonb_build_object('secret', '<위 2)의 REPORT_SECRET 과 동일한 값>')
    );
  $$
);
```
> 크론 이름(`bugchamp-daily-report`)이 이미 있으면 먼저
> `select cron.unschedule('bugchamp-daily-report');` 후 다시 등록.

---

## 바로 테스트 (9시까지 안 기다리고)

```bash
curl -X POST "https://rvmpwyycivmtrbbynjyy.supabase.co/functions/v1/daily-report" \
  -H "Content-Type: application/json" \
  -d '{"secret":"<REPORT_SECRET>"}'
```
→ 텔레그램에 리포트가 오면 성공. `{"ok":true,...}` 응답.
- `403 forbidden` → secret 불일치
- `503 bot token missing` → `TELEGRAM_BOT_TOKEN` 시크릿 미설정
- `500 stats failed` → RPC 문제(1번 SQL 재실행 확인)

---

## 운영 메모

- **시간 변경**: 크론식 `0 0 * * *`(UTC) 를 바꾼다. 예) 08:00 KST = `0 23 * * *`(전날 23 UTC).
- **크론 목록 확인**: `select * from cron.job;`
- **최근 크론 실행 로그**: `select * from cron.job_run_details order by start_time desc limit 10;`
- **받는 사람 추가**: 다른 chat_id 로도 보내려면 함수의 `sendTelegram` 를 여러 chat_id 반복 호출로 확장.
- **봇 토큰 보안**: 토큰은 Supabase 시크릿에만 존재. 저장소·앱에 넣지 않는다.
