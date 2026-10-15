-- 목적: 텔레그램 일일 리포트 숫자 바로잡기 — 활동을 saves.updated_at(일괄 SQL 등으로 플레이 안 한 계정도 갱신됨,
--       월간 812 vs 실제 289) 대신 세이브 안의 lastSeen 으로 세고, 테스트 설치(앱을 깔 때마다 생기는 익명 계정)를 뺀
--       '진짜 이용자'(닉네임 있고 레벨 5 이상)·결제자 수를 더한다. 점검: docs/_sql_20261015_report_check.sql
-- 작성: 2026-10-15
-- 위험: 없음 — 함수 본문만 바꾼다(데이터·스키마 변경 없음). 옛 키는 모두 그대로 돌려준다(이름만 같고 세는 기준이 바뀜).
--       리포트 함수(supabase/functions/daily-report)는 새 키(real_users)가 없으면 옛 모양으로 보내므로 순서가 어긋나도 깨지지 않는다.
-- 되돌리기: 아래 ROLLBACK 절(docs/telegram_daily_report.md 에 적힌 옛 본문).

begin;

create or replace function public.bugchamp_daily_stats()
returns jsonb language plpgsql security definer
set search_path = public, auth as $$
declare r jsonb;
begin
  with s as (
    select s.id,
           u.created_at,
           -- 앱이 플레이할 때 적는 시각. 기기 시계를 앞으로 돌린 값은 서버 저장 시각으로 자른다.
           -- 형식이 이상하면(없으면) 저장 시각으로 — least 는 null 을 건너뛴다.
           least(case when s.data->>'lastSeen' ~ '^\d{4}-\d{2}-\d{2}T'
                      then (s.data->>'lastSeen')::timestamptz end,
                 s.updated_at) as seen,
           -- 진짜 이용자 = 닉네임 있고 레벨 5 이상(테스트 재설치로 생긴 익명 계정을 거른다).
           p.nickname is not null
             and coalesce(case when s.data->>'level' ~ '^\d+$'
                               then (s.data->>'level')::int end, 0) >= 5 as real_user
    from public.saves s
    join auth.users u on u.id = s.id
    left join public.profiles p on p.id = s.id
  )
  select jsonb_build_object(
    'installs',        (select count(*) from auth.users),
    'new_today',       (select count(*) from auth.users
                          where created_at >= now() - interval '24 hours'),
    'new_named_today', (select count(*) from auth.users u
                          join public.profiles p on p.id = u.id
                         where u.created_at >= now() - interval '24 hours'),

    'dau',             count(*) filter (where seen >= now() - interval '24 hours'),
    'wau',             count(*) filter (where seen >= now() - interval '7 days'),
    'mau',             count(*) filter (where seen >= now() - interval '30 days'),
    'real_dau',        count(*) filter (where real_user and seen >= now() - interval '24 hours'),
    'real_wau',        count(*) filter (where real_user and seen >= now() - interval '7 days'),
    'real_mau',        count(*) filter (where real_user and seen >= now() - interval '30 days'),
    'real_users',      count(*) filter (where real_user),

    -- 정착: 진짜 이용자 중 가입 하루 넘겼고 최근 7일 접속
    'retained',        count(*) filter (where real_user
                                          and seen >= now() - interval '7 days'
                                          and created_at < now() - interval '24 hours'),

    -- D1: 분모는 어제 가입한 계정 전체(옛 정의 그대로), 돌아옴은 앱 접속 시각 기준
    'd1_new',          (select count(*) from auth.users
                         where created_at >= now() - interval '48 hours'
                           and created_at <  now() - interval '24 hours'),
    'd1_returned',     count(*) filter (where created_at >= now() - interval '48 hours'
                                          and created_at <  now() - interval '24 hours'
                                          and seen >= now() - interval '24 hours'),

    'linked',          (select count(*) from auth.users where is_anonymous = false),
    'linked_google',   (select count(distinct user_id) from auth.identities
                         where provider = 'google'),
    'linked_apple',    (select count(distinct user_id) from auth.identities
                         where provider = 'apple'),

    'saves_total',     count(*),

    'payers',          (select count(distinct user_id) from public.verified_purchases
                         where environment = 'production'),
    'purchases',       (select count(*) from public.verified_purchases
                         where environment = 'production'),
    'purchases_test',  (select count(*) from public.verified_purchases
                         where environment <> 'production')
  ) into r
  from s;
  return r;
end; $$;

revoke all on function public.bugchamp_daily_stats() from public, anon, authenticated;
grant execute on function public.bugchamp_daily_stats() to service_role;

commit;

-- 확인(적용 뒤 실행): real_users ≈ 300 · mau ≈ 289 · real_mau ≈ 160 · payers = 7 근처면 정상
-- select public.bugchamp_daily_stats();

-- ROLLBACK (적용 후 문제가 생기면 이걸 돌린다 — 옛 본문)
-- begin;
-- create or replace function public.bugchamp_daily_stats()
-- returns jsonb language plpgsql security definer
-- set search_path = public, auth as $$
-- declare r jsonb;
-- begin
--   select jsonb_build_object(
--     'installs',       (select count(*) from auth.users),
--     'new_today',      (select count(*) from auth.users where created_at >= now() - interval '24 hours'),
--     'dau',            (select count(*) from public.saves where updated_at >= now() - interval '24 hours'),
--     'wau',            (select count(*) from public.saves where updated_at >= now() - interval '7 days'),
--     'mau',            (select count(*) from public.saves where updated_at >= now() - interval '30 days'),
--     'retained',       (select count(*) from public.saves s join auth.users u on u.id = s.id
--                         where s.updated_at >= now() - interval '7 days' and u.created_at < now() - interval '24 hours'),
--     'd1_new',         (select count(*) from auth.users
--                         where created_at >= now() - interval '48 hours' and created_at < now() - interval '24 hours'),
--     'd1_returned',    (select count(*) from public.saves s join auth.users u on u.id = s.id
--                         where u.created_at >= now() - interval '48 hours' and u.created_at < now() - interval '24 hours'
--                           and s.updated_at >= now() - interval '24 hours'),
--     'linked',         (select count(*) from auth.users where is_anonymous = false),
--     'linked_google',  (select count(distinct user_id) from auth.identities where provider = 'google'),
--     'linked_apple',   (select count(distinct user_id) from auth.identities where provider = 'apple'),
--     'saves_total',    (select count(*) from public.saves),
--     'purchases',      (select count(*) from public.verified_purchases where environment = 'production'),
--     'purchases_test', (select count(*) from public.verified_purchases where environment <> 'production')
--   ) into r;
--   return r;
-- end; $$;
-- revoke all on function public.bugchamp_daily_stats() from public, anon, authenticated;
-- grant execute on function public.bugchamp_daily_stats() to service_role;
-- commit;
