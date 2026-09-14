-- ────────────────────────────────────────────────────────────────
-- Bug Champ — 2026-09-15 진행도 랭킹: 같은 사냥터는 **전투력**으로 가른다
-- Supabase 대시보드 → SQL Editor 에 통째로 붙여넣고 한 번 실행.
-- 재실행해도 안전. 원본·설명: docs/backend_supabase.md §2
-- ────────────────────────────────────────────────────────────────
-- 목적: 사냥터 구조(난이도마다 사냥터 10 + 최종 보스)에서는 진행도가 사냥터
--       시작 스테이지로만 움직여 같은 칸에 사람이 몰린다. 예전 정렬(회차 →
--       스테이지)은 동률 순서가 **임의**라 새로고침마다 순위가 바뀔 수 있었다.
--       회차 → 사냥터 → 전투력 순으로 세운다(사장님 결정).
-- 작성: 2026-09-15
-- 위험: leaderboard_top 의 반환 컬럼이 늘어 drop → create 한다. 트랜잭션 안이라
--       중간 상태(함수 없음)는 밖에서 보이지 않는다. 구버전 앱은 power 를 모르고
--       무시한다. ⚠️ **새 앱보다 먼저** 돌린다 — 새 앱은 power 를 올리는데,
--       컬럼이 없으면 한 번 실패한 뒤 power 없이 다시 올린다(랭킹은 안 깨진다).
-- 되돌리기: 맨 아래 ROLLBACK 절(09-01 정의로 복귀). power 컬럼은 지우지 않는다
--       (구버전이 다 빠지기 전엔 컬럼을 삭제하지 않는다 — sql-migration 규칙).

begin;

-- ① 전투력 컬럼. 홈 상단에 보이는 값 그대로(double — 후반엔 int64 를 넘는다).
--    구버전 앱은 안 올리므로 0 으로 남는다 → 같은 사냥터에서 아래로 간다.
alter table profiles
  add column if not exists power double precision not null default 0;

-- ② 앱이 upsert 로 쓸 수 있게 컬럼 UPDATE 권한을 **더한다**.
--    ⚠️ badge 는 여전히 목록에 없다(서버만 쓴다 — _sql_20260826_badge.sql ③).
grant update (power) on profiles to authenticated;

-- ③ 순위표 — power 반환 + 진행도 정렬 키 교체.
--    ⚠️ 반환 컬럼이 바뀌므로 **반드시 먼저 지운다**(create or replace 는 거부한다).
drop function if exists leaderboard_top(int, text);

create function leaderboard_top(lim int, sort text default 'trophies')
returns table(rank bigint, id uuid, nickname text,
              trophies int, level int, stage int, tier int, badge text,
              power double precision)
language sql stable security definer set search_path = public as $$
  with ranked as (
    select p.id, p.nickname, p.trophies, p.level, p.stage, p.tier,
           coalesce(p.badge, '') as badge, p.power,
           row_number() over (
             order by
               -- 1차: 레벨·진행도 모두 **회차가 먼저**다(09-01 과 같다).
               case sort
                 when 'level' then p.tier
                 when 'stage' then p.tier
                 else p.trophies
               end desc,
               -- 2차: 진행도는 스테이지가 아니라 **사냥터**다.
               -- 사냥터 k = 스테이지 (k-1)×100+1 (CLAUDE.md §2.4, run_config
               -- worldSize). 사냥터로 묶어야 구버전 앱의 옛 스테이지(715 등)도
               -- 같은 칸 안에서 전투력으로 갈린다.
               case sort
                 when 'level' then p.level
                 when 'stage' then (greatest(p.stage, 1) - 1) / 100
                 else 0
               end desc,
               -- 3차: 같은 사냥터면 전투력이 높은 쪽이 위.
               case sort when 'stage' then p.power else 0 end desc,
               -- 4차: 그래도 같으면 스테이지(옛 구조) → id 로 고정한다.
               -- 마지막 키가 없으면 완전 동률의 순서가 조회마다 달라져
               -- 새로고침할 때마다 두 사람의 순위가 뒤바뀐다.
               case sort when 'stage' then p.stage else 0 end desc,
               p.id
           ) as rank
    from profiles p
  )
  select r.rank, r.id, r.nickname, r.trophies, r.level, r.stage, r.tier,
         r.badge, r.power
  from ranked r
  order by r.rank
  limit lim;
$$;

commit;

-- ────────────────────────────────────────────────────────────────
-- 확인 — `ok` 가 전부 true 여야 한다.
-- ────────────────────────────────────────────────────────────────
select '① power 컬럼' as check, exists(
         select 1 from information_schema.columns
         where table_name='profiles' and column_name='power') as ok
union all
select '② power 쓰기 허용', exists(
         select 1 from information_schema.column_privileges
         where table_name='profiles' and grantee='authenticated'
           and privilege_type='UPDATE' and column_name='power')
union all
select '③ badge 쓰기는 여전히 차단', not exists(
         select 1 from information_schema.column_privileges
         where table_name='profiles' and grantee='authenticated'
           and privilege_type='UPDATE' and column_name='badge')
union all
select '④ 순위표가 power 반환', (
         select count(*) = 1 from pg_proc p
         where p.proname='leaderboard_top'
           and pg_get_function_result(p.oid) like '%power%');

-- 진행도 상위 20명 미리보기(선택):
-- select rank, nickname, tier, stage, power from leaderboard_top(20, 'stage');

-- ────────────────────────────────────────────────────────────────
-- ROLLBACK (문제가 생기면 이것만 돌린다 — 09-01 정의로 복귀)
-- ────────────────────────────────────────────────────────────────
-- begin;
-- drop function if exists leaderboard_top(int, text);
-- create function leaderboard_top(lim int, sort text default 'trophies')
-- returns table(rank bigint, id uuid, nickname text,
--               trophies int, level int, stage int, tier int, badge text)
-- language sql stable security definer set search_path = public as $$
--   select row_number() over (
--            order by case sort when 'level' then p.tier when 'stage' then p.tier
--                               else p.trophies end desc,
--                     case sort when 'level' then p.level when 'stage' then p.stage
--                               else 0 end desc
--          ) as rank,
--          p.id, p.nickname, p.trophies, p.level, p.stage, p.tier,
--          coalesce(p.badge, '') as badge
--   from profiles p
--   order by case sort when 'level' then p.tier when 'stage' then p.tier
--                      else p.trophies end desc,
--            case sort when 'level' then p.level when 'stage' then p.stage
--                      else 0 end desc
--   limit lim;
-- $$;
-- commit;
