-- ────────────────────────────────────────────────────────────────
-- Bug Champ — 2026-08-26 대회 보상·뱃지 SQL
-- Supabase 대시보드 → SQL Editor 에 **통째로 붙여넣고 한 번 실행**한다.
-- 재실행해도 안전(idempotent).
-- 원본·설명: docs/backend_supabase.md
-- ────────────────────────────────────────────────────────────────

-- ① 회차 보상 판정용 순위 조회 (권위 서버가 부른다)
--
-- ⚠️ 기존 `event_my_rank` 는 못 쓴다. 그건 auth.uid() 를 보는데
--    서버는 service key 로 부르므로 null 이다.
create or replace function event_rank_of(p_round text, p_user uuid)
returns table(rank bigint, score bigint, wave int, total bigint)
language sql stable security definer set search_path = public as $$
  select r.rank, r.score, r.wave, (select count(*) from event_scores
                                   where round_id = p_round) as total
  from (
    select user_id,
           row_number() over (order by score desc, updated_at asc) as rank,
           score, wave
    from event_scores where round_id = p_round
  ) r
  where r.user_id = p_user;
$$;
revoke execute on function event_rank_of(text, uuid) from anon, authenticated;


-- ② profiles 컬럼
--
-- ⚠️ `level`·`stage` 는 **랭킹 3축**(§2.7)에 필요한데 실서버에 아직 없었다
-- (2026-08-26 확인). 없으면 앱의 profiles upsert 와 leaderboard_top 이 통째로
-- 실패하고, 랭킹 화면은 조용히 로컬 NPC 사다리로 폴백한다 — **화면은 멀쩡한데
-- 실제 유저 순위가 아니다.** 여기서 같이 만든다.
alter table profiles add column if not exists level int  not null default 1;
alter table profiles add column if not exists stage int  not null default 1;
alter table profiles add column if not exists badge text not null default '';

-- ③ ⚠️ 가장 중요 — 뱃지 쓰기 권한 회수
--
-- profiles 는 **앱도 upsert** 하는 테이블이고 own_profile 정책이 본인 행
-- UPDATE 를 허용한다. 그냥 두면 누구나 챔피언 뱃지를 단다.
-- RLS 는 컬럼을 못 가리므로 **컬럼 권한**으로 막는다.
-- (권위 서버는 service key 라 이 GRANT 의 영향을 받지 않는다.)
revoke update on profiles from authenticated;
grant  update (nickname, trophies, level, stage) on profiles to authenticated;


-- ④ 순위표가 뱃지를 함께 반환하도록 재정의
--
-- ⚠️ 반환 컬럼이 바뀌므로 **반드시 먼저 지운다** —
--    create or replace 는 반환 타입 변경을 거부한다.
-- ⚠️ 인자 순서까지 정확해야 한다(leaderboard_top 은 (int, text)).
--    틀리면 if exists 라 조용히 넘어간 뒤 아래 create 가 실패한다.
drop function if exists event_top(text, int);
drop function if exists leaderboard_top(int, text);

create or replace function event_top(p_round text, lim int)
returns table(rank bigint, user_id uuid, nickname text, score bigint,
              wave int, badge text)
language sql stable security definer set search_path = public as $$
  select row_number() over (order by e.score desc, e.updated_at asc) as rank,
         e.user_id, e.nickname, e.score, e.wave,
         coalesce(p.badge, '') as badge
  from event_scores e
  left join profiles p on p.id = e.user_id
  where e.round_id = p_round
  order by e.score desc, e.updated_at asc
  limit lim;
$$;

create or replace function leaderboard_top(lim int, sort text default 'trophies')
returns table(rank bigint, id uuid, nickname text,
              trophies int, level int, stage int, badge text)
language sql stable security definer set search_path = public as $$
  select row_number() over (
           order by case sort
                      when 'level' then p.level
                      when 'stage' then p.stage
                      else p.trophies
                    end desc
         ) as rank,
         p.id, p.nickname, p.trophies, p.level, p.stage,
         coalesce(p.badge, '') as badge
  from profiles p
  order by case sort
             when 'level' then p.level
             when 'stage' then p.stage
             else p.trophies
           end desc
  limit lim;
$$;


-- ────────────────────────────────────────────────────────────────
-- 확인 — 넷 다 결과가 나오면 성공
-- ────────────────────────────────────────────────────────────────
-- select count(*) from information_schema.columns
--   where table_name='profiles' and column_name='badge';            -- 1
-- select * from leaderboard_top(5, 'trophies');                     -- badge 컬럼 보임
-- select proname from pg_proc where proname = 'event_rank_of';      -- 1행
-- select privilege_type, column_name from information_schema.column_privileges
--   where table_name='profiles' and grantee='authenticated'
--     and privilege_type='UPDATE';   -- nickname/trophies/level/stage 만 (badge 없어야 함)
