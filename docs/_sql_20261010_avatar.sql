-- 목적: 1.0.19 프로필 그림(2026-10-10 사장님 확정) — profiles.avatar(앱이 고를 때 올린다) · 채팅 메시지에 보낸 사람의 그림
--       (넣는 순간 트리거가 profiles.avatar 에서 찍는다 — 뱃지와 같은 방식) · 순위 함수 4개가 그림 id 도 돌려주게.
--       · leaderboard_top(랭킹 심연·레벨·진행도 탭) · pvp_league_top(결투 리그 순위표) · abyss_top(심연 주간 순위표) · event_top(왕충 선발대회 순위·명예의 전당)
-- 작성: 2026-10-10
-- 위험: 함수 4개의 반환 컬럼이 늘어 drop → create 한다(트랜잭션 안 — 밖에서는 함수가 없는 순간이 보이지 않는다).
--       데이터는 바꾸지 않는다(칸 추가만). 구버전 앱·서버는 avatar 를 모르고 무시한다. 서버 전용 함수의 권한(revoke)은 다시 건다.
-- 순서: 운영 서버 재배포보다 먼저가 좋다(순서가 바뀌어도 깨지지 않는다 — 그동안 남의 그림이 기본으로 보일 뿐).
--       새 앱은 이 칸이 없으면 그림만 빼고 프로필을 다시 올린다.
-- 기준(지금 운영 DB 정의): leaderboard_top·abyss_top = _sql_20261005_rank_hidden(2026-10-10 확인 — rank_hidden 칸이 있다 = 이미 적용,
--       숨긴 계정 건너뛰기 조건을 그대로 둔다) · pvp_league_top = _sql_20261001_pvp_board_power · event_top = _sql_20260826_badge ·
--       chat_stamp_badge = _sql_20260915_chat_badge.
-- 안 바꾸는 것: pvp_league_range·pvp_league_idle(결투 후보) — 서버가 상대 그림을 그 사람 세이브에서 읽는다.
-- 되돌리기: 맨 아래 ROLLBACK 절(옛 반환 형식으로 다시 만든다 · 칸은 지우지 않는다).

-- ⓪ 먼저 확인 — true 여야 한다(rank_hidden 이 적용된 DB 기준으로 쓴 판이다 · 2026-10-10 사장님 확인 true).
--    false 면 아래 rank_hidden 조건이 없는 칸을 가리켜 실패한다 — 멈추고 알려 줄 것.
select exists(
  select 1 from information_schema.columns
  where table_name = 'profiles' and column_name = 'rank_hidden') as rank_hidden_already_applied;

begin;

-- ① 프로필 그림 칸 · 형식 검사(앱 avatars.json 의 id 꼴) · 앱 쓰기 권한(기존 upsert 컬럼과 같은 방식 — 컬럼 UPDATE 권한을 더한다)
alter table profiles add column if not exists avatar text;
alter table profiles drop constraint if exists profiles_avatar_format;
alter table profiles add constraint profiles_avatar_format
  check (avatar is null or avatar ~ '^avatar_[a-z0-9_]{1,24}$');
grant update (avatar) on profiles to authenticated;

-- ② 채팅 — 보낸 사람의 그림을 넣는 순간 찍는다(클라이언트가 보낸 값은 덮어쓴다). 트리거는 그대로, 함수 본문만 바꾼다.
alter table chat_messages add column if not exists avatar text;

create or replace function public.chat_stamp_badge()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- 프로필 행이 없으면(닉네임 미설정 등) 뱃지 빈 문자열 · 그림 null(앱이 기본 프로필로 그린다).
  new.badge := coalesce(
    (select p.badge from profiles p where p.id = new.user_id), '');
  new.avatar := (select p.avatar from profiles p where p.id = new.user_id);
  return new;
end;
$$;

-- ③ 랭킹(심연·레벨·진행도 탭) — 앱이 부른다(권한 기본값 그대로).
drop function if exists leaderboard_top(int, text);
create function leaderboard_top(lim int, sort text default 'trophies')
returns table(rank bigint, id uuid, nickname text,
              trophies int, level int, stage int, tier int, badge text,
              power double precision, abyss_best int, avatar text)
language sql stable security definer set search_path = public as $$
  with ranked as (
    select p.id, p.nickname, p.trophies, p.level, p.stage, p.tier,
           coalesce(p.badge, '') as badge, p.power, p.abyss_best, p.avatar,
           row_number() over (
             order by
               case sort
                 when 'level' then p.tier
                 when 'stage' then p.tier
                 else p.trophies
               end desc,
               case sort
                 when 'level' then p.level
                 when 'stage' then (greatest(p.stage, 1) - 1) / 100
                 else 0
               end desc,
               case sort when 'stage' then p.abyss_best else 0 end desc,
               case sort when 'stage' then p.power else 0 end desc,
               case sort when 'stage' then p.stage else 0 end desc,
               p.id
           ) as rank
    from profiles p
    where not p.rank_hidden          -- 2026-10-05 개발자·운영 계정 제외(rank_hidden — 그대로 둔다)
  )
  select r.rank, r.id, r.nickname, r.trophies, r.level, r.stage, r.tier,
         r.badge, r.power, r.abyss_best, r.avatar
  from ranked r
  order by r.rank
  limit lim;
$$;

-- ④ 결투 리그 순위표 — 서버 전용.
drop function if exists pvp_league_top(text, text, int);
create function pvp_league_top(p_season text, p_league text, lim int default 100)
returns table(rank bigint, user_id uuid, nickname text, trophies int,
              power double precision, badge text, sp text, avatar text)
language sql stable security definer set search_path = public as $$
  select row_number() over (order by s.trophies desc, s.updated_at asc) as rank,
         s.user_id, coalesce(nullif(p.nickname, ''), s.nickname), s.trophies,
         greatest(s.power, 0)::double precision,
         coalesce(p.badge, ''),
         coalesce(nullif(s.sp, ''), d.team -> 0 ->> 'sp', ''),
         p.avatar
  from pvp_season_scores s
  left join profiles p on p.id = s.user_id
  left join defenders d on d.id = s.user_id
  where s.season_id = p_season and s.league = p_league
  order by s.trophies desc, s.updated_at asc
  limit lim;
$$;
revoke execute on function pvp_league_top(text, text, int) from public, anon, authenticated;

-- ⑤ 심연 주간 순위표 — 서버 전용.
drop function if exists abyss_top(text, int);
create function abyss_top(p_week text, lim int default 100)
returns table(rank bigint, user_id uuid, nickname text, floor int, boss_pm int,
              updated_at timestamptz, power double precision, badge text, sp text, avatar text)
language sql stable security definer set search_path = public as $$
  select row_number() over (order by s.floor desc, s.boss_pm desc, s.updated_at asc) as rank,
         s.user_id, coalesce(nullif(p.nickname, ''), s.nickname), s.floor, s.boss_pm, s.updated_at,
         coalesce(p.power, 0)::double precision, coalesce(p.badge, ''),
         coalesce(d.team -> 0 ->> 'sp', ''),
         p.avatar
  from abyss_weekly_scores s
  left join profiles p on p.id = s.user_id
  left join defenders d on d.id = s.user_id
  where s.week_id = p_week and s.floor > 1
    and not coalesce(p.rank_hidden, false)   -- 2026-10-05 개발자·운영 계정 제외(그대로 둔다)
  order by s.floor desc, s.boss_pm desc, s.updated_at asc
  limit lim;
$$;
revoke execute on function abyss_top(text, int) from public, anon, authenticated;

-- ⑥ 왕충 선발대회 순위 — 서버가 부른다(권한 기본값 그대로 — 예전 정의도 revoke 가 없었다).
drop function if exists event_top(text, int);
create function event_top(p_round text, lim int)
returns table(rank bigint, user_id uuid, nickname text, score bigint,
              wave int, badge text, avatar text)
language sql stable security definer set search_path = public as $$
  select row_number() over (order by e.score desc, e.updated_at asc) as rank,
         e.user_id, e.nickname, e.score, e.wave,
         coalesce(p.badge, '') as badge,
         p.avatar
  from event_scores e
  left join profiles p on p.id = e.user_id
  where e.round_id = p_round
  order by e.score desc, e.updated_at asc
  limit lim;
$$;

commit;

-- 확인 — `ok` 가 전부 true 여야 한다.
select '① profiles.avatar 칸' as check, exists(
         select 1 from information_schema.columns
         where table_name = 'profiles' and column_name = 'avatar') as ok
union all
select '② 앱이 avatar 를 쓸 수 있다', exists(
         select 1 from information_schema.column_privileges
         where table_name = 'profiles' and grantee = 'authenticated'
           and privilege_type = 'UPDATE' and column_name = 'avatar')
union all
select '③ 앱은 여전히 badge 를 못 쓴다', not exists(
         select 1 from information_schema.column_privileges
         where table_name = 'profiles' and grantee = 'authenticated'
           and privilege_type = 'UPDATE' and column_name = 'badge')
union all
select '④ chat_messages.avatar 칸', exists(
         select 1 from information_schema.columns
         where table_name = 'chat_messages' and column_name = 'avatar')
union all
select '⑤ 함수 4개가 avatar 반환', (
         select count(*) = 4 from pg_proc p
         where p.proname in ('leaderboard_top', 'pvp_league_top', 'abyss_top', 'event_top')
           and pg_get_function_result(p.oid) like '%avatar%')
union all
select '⑥ 서버 전용 함수는 앱이 못 부른다', not exists(
         select 1 from information_schema.routine_privileges
         where routine_name in ('pvp_league_top', 'abyss_top')
           and grantee in ('anon', 'authenticated', 'PUBLIC'))
union all
select '⑦ 숨긴 계정 건너뛰기가 그대로다', (
         select count(*) = 2 from pg_proc p
         where p.proname in ('leaderboard_top', 'abyss_top')
           and pg_get_functiondef(p.oid) like '%rank_hidden%');

-- ROLLBACK (문제가 생기면 — 서버·앱은 avatar 가 없어도 기본 프로필로 동작한다)
-- begin;
--   drop function if exists leaderboard_top(int, text);  ·  drop function if exists abyss_top(text, int);
--   (`git show 9fa3ed6:docs/_sql_20261005_rank_hidden.sql` 의 leaderboard_top·abyss_top 정의 + abyss_top revoke 를 다시 실행 — avatar 없는 판)
--   drop function if exists pvp_league_top(text, text, int);
--   (docs/_sql_20261001_pvp_board_power.sql 의 pvp_league_top 정의 + revoke 를 다시 실행)
--   drop function if exists event_top(text, int);
--   (docs/_sql_20260826_badge.sql 의 event_top 정의를 다시 실행)
--   (docs/_sql_20260915_chat_badge.sql 의 chat_stamp_badge 함수를 다시 실행 — 그림 찍기만 빠진다)
-- commit;
-- 칸(profiles.avatar · chat_messages.avatar)은 지우지 않는다 — 새 앱이 읽는다.
