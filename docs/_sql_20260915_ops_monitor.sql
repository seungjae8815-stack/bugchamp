-- ────────────────────────────────────────────────────────────────
-- Bug Champ — 2026-09-15 운영 감시(리포트 복구 · 서버 생존 · 리포트 누락 감시)
-- Supabase 대시보드 → SQL Editor 에 통째로 붙여넣고 한 번 실행.
-- 재실행해도 안전. 설명: docs/telegram_daily_report.md "운영 감시"
-- ────────────────────────────────────────────────────────────────
-- 목적:
--  ① 일일 리포트 크론을 **REPORT_SECRET 과 함께** 다시 건다. 2026-09 에 함수 시크릿이 빠진 채
--     크론만 돌아 몇 주 동안 리포트가 조용히 멈춰 있었다(함수가 403).
--  ② ops_heartbeat — 감시 함수의 상태(연속 실패 수·마지막 알림·리포트 발송 시각). 함수는 매번
--     새로 떠서 메모리에 둘 수 없다. **서비스 롤만** 읽고 쓴다(RLS 켜고 정책 없음).
--  ③ ops-watchdog 을 10분마다 부른다(서버 /health · 9시 반 리포트 누락).
-- 위험: 없음(새 표 + 크론). 앱은 이 표를 모른다.
-- ⚠️ 아래 <REPORT_SECRET> 두 곳을 실제 값으로 바꿔 실행한다. 값은 Supabase Edge Function 시크릿
--    REPORT_SECRET 과 같아야 한다. **실제 값을 넣은 SQL 은 저장소에 커밋하지 않는다.**
-- 되돌리기: 맨 아래 ROLLBACK 절.

create extension if not exists pg_cron;
create extension if not exists pg_net;

create table if not exists public.ops_heartbeat (
  name        text primary key,
  last_ok_at  timestamptz,
  fail_count  integer not null default 0,
  alerted_at  timestamptz
);
alter table public.ops_heartbeat enable row level security;
revoke all on public.ops_heartbeat from anon, authenticated;

-- ① 일일 리포트(09:00 KST = 00:00 UTC) — 있으면 지우고 다시 건다.
select cron.unschedule(jobid) from cron.job where jobname = 'bugchamp-daily-report';
select cron.schedule(
  'bugchamp-daily-report',
  '0 0 * * *',
  $$
    select net.http_post(
      url     := 'https://rvmpwyycivmtrbbynjyy.supabase.co/functions/v1/daily-report',
      headers := '{"Content-Type": "application/json"}'::jsonb,
      body    := jsonb_build_object('secret', '<REPORT_SECRET>')
    );
  $$
);

-- ③ 운영 감시(10분마다).
select cron.unschedule(jobid) from cron.job where jobname = 'bugchamp-ops-watchdog';
select cron.schedule(
  'bugchamp-ops-watchdog',
  '*/10 * * * *',
  $$
    select net.http_post(
      url     := 'https://rvmpwyycivmtrbbynjyy.supabase.co/functions/v1/ops-watchdog',
      headers := '{"Content-Type": "application/json"}'::jsonb,
      body    := jsonb_build_object('secret', '<REPORT_SECRET>')
    );
  $$
);

-- 확인
select jobname, schedule, active from cron.job where jobname like 'bugchamp-%';

-- ── ROLLBACK ──
-- select cron.unschedule(jobid) from cron.job where jobname in ('bugchamp-ops-watchdog');
-- drop table if exists public.ops_heartbeat;
