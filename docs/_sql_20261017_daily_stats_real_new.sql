-- 목적: 텔레그램 일일 리포트의 신규·D1 을 '진짜 신규'(레벨 3 이상까지 간 계정)로도 센다.
--       2026-10-16 신규 설치 19명 중 실제 이용자는 7~8명이었다 — 구글 출시 전 자동 테스트 로봇(Player1·User9988·BugHunt7 등
--       1시간에 7개), 첫 실행 중복 익명 계정, 설치만 하고 나간 계정이 섞였다. 새 키: new_real_today · d1_new_real · d1_returned_real.
-- 작성: 2026-10-17
-- 위험: 없음 — 함수 본문만 바꾼다(데이터·스키마 변경 없음). 옛 키는 모두 그대로.
--       리포트 함수(supabase/functions/daily-report)는 새 키가 없으면 지금 모양으로 보내므로 순서가 어긋나도 깨지지 않는다.
-- 되돌리기: docs/_sql_20261015_daily_stats_real_users.sql 의 begin~commit 을 다시 돌린다(직전 본문).

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
                               then (s.data->>'level')::int end, 0) >= 5 as real_user,
           -- 진짜 신규 = 레벨 3 이상까지 감(2026-10-17 — 구글 출시 전 자동 테스트 로봇 `Player1`·`BugHunt7` 등은
           -- 닉네임을 적고 Lv1~2 에서 2~3분 만에 멈춘다. 설치만 하고 나간 계정·첫 실행 중복 익명 계정도 빠진다).
           coalesce(case when s.data->>'level' ~ '^\d+$'
                         then (s.data->>'level')::int end, 0) >= 3 as played
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
    'new_real_today',  count(*) filter (where played
                                          and created_at >= now() - interval '24 hours'),

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
    -- D1(진짜 신규 기준) — 분모·분자 모두 레벨 3 이상까지 간 어제 가입자. 로봇·바로 나간 계정이 분모를 부풀렸다.
    'd1_new_real',     count(*) filter (where played
                                          and created_at >= now() - interval '48 hours'
                                          and created_at <  now() - interval '24 hours'),
    'd1_returned_real', count(*) filter (where played
                                          and created_at >= now() - interval '48 hours'
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

-- 확인(적용 뒤 실행): new_real_today 가 new_named_today 보다 작고(2026-10-17 기준 6 근처) d1_new_real ≤ d1_new 면 정상
-- select public.bugchamp_daily_stats();
