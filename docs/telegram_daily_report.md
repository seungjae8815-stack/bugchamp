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
📅 2026-07-22 리포트

👥 총 사용자      1,234명
🆕 오늘 신규      56명
🎮 최근 24h 활동  320명
⚔️ PvP 참여       210명
💰 누적 결제      18건
```

| 항목 | 소스 |
|---|---|
| 총 사용자 | `auth.users` 전체(익명 계정 = 설치 후 백엔드 접속한 사람) |
| 오늘 신규 | 최근 24h 에 생성된 `auth.users` |
| 최근 24h 활동 | 최근 24h 에 세이브 업로드한 `saves`(DAU 근사) |
| PvP 참여 | `profiles` 행 수 |
| 누적 결제 | `verified_purchases` 행 수 |

---

## 설정 순서 (1회)

### 1) 통계 RPC 생성 — SQL Editor 에 실행

```sql
-- 곤충키우기 일일 통계: service_role(Edge Function)만 실행. 없는 테이블은 0 처리.
create or replace function public.bugchamp_daily_stats()
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  total_users     bigint := 0;
  new_today       bigint := 0;
  active_24h      bigint := 0;
  pvp_players     bigint := 0;
  purchases_total bigint := 0;
begin
  select count(*) into total_users from auth.users;
  select count(*) into new_today
    from auth.users where created_at >= now() - interval '24 hours';

  if to_regclass('public.saves') is not null then
    execute 'select count(*) from public.saves
             where updated_at >= now() - interval ''24 hours''' into active_24h;
  end if;
  if to_regclass('public.profiles') is not null then
    execute 'select count(*) from public.profiles' into pvp_players;
  end if;
  if to_regclass('public.verified_purchases') is not null then
    execute 'select count(*) from public.verified_purchases' into purchases_total;
  end if;

  return jsonb_build_object(
    'total_users',     total_users,
    'new_today',       new_today,
    'active_24h',      active_24h,
    'pvp_players',     pvp_players,
    'purchases_total', purchases_total
  );
end;
$$;

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
supabase functions deploy daily-report --no-verify-jwt \
  --project-ref rvmpwyycivmtrbbynjyy
```
> `--no-verify-jwt`: 크론(pg_net)이 JWT 없이 호출한다. 대신 함수가 `REPORT_SECRET` 로 막는다.

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
