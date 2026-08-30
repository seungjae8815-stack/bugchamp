-- ────────────────────────────────────────────────────────────────
-- Bug Champ — 2026-08-31 진행도 랭킹에 **회차(난이도)** 반영
-- Supabase 대시보드 → SQL Editor 에 **통째로 붙여넣고 한 번 실행**한다.
-- 재실행해도 안전(idempotent).
-- 원본·설명: docs/backend_supabase.md
-- ────────────────────────────────────────────────────────────────
--
-- 왜: 회차제(쉬움 1-1000 → 보통 1부터 다시)를 넣으면서 진행도 랭킹이
-- 스테이지 숫자만 본다. 그러면 회차를 넘어가는 순간 스테이지가 1 로 돌아가
-- **랭킹 꼴찌가 된다** — 어렵게 뚫고 올라간 유저가 벌을 받는 꼴이라
-- 아무도 넘어가지 않는다. 회차가 먼저, 그다음 스테이지로 줄을 세운다.

-- ① profiles.tier 컬럼 (0 = 쉬움)
--
-- 기본값 0 이라 기존 행은 전부 "쉬움"으로 남는다 — 회차를 넘어간 유저가
-- 아직 없으니 정확하다.
alter table profiles add column if not exists tier int not null default 0;

-- ② 앱이 tier 를 쓸 수 있게 컬럼 권한에 추가
--
-- ⚠️ GRANT 는 **덮어쓰기가 아니라 목록 전체를 다시 준다**. 기존 컬럼을
-- 빠뜨리면 그 컬럼 쓰기가 죽고 앱 랭킹이 통째로 로컬 폴백으로 떨어진다
-- (2026-08-27 `id` 누락으로 겪음). badge 는 **일부러 빠져 있다** —
-- 들어가면 누구나 챔피언 뱃지를 단다.
revoke update on profiles from authenticated;
grant  update (id, nickname, trophies, level, stage, tier) on profiles
  to authenticated;

-- ③ 순위표가 tier 를 반환하고, 진행도 정렬에 tier 를 먼저 본다
--
-- ⚠️ 반환 컬럼이 늘어나므로 **반드시 먼저 지운다** —
--    create or replace 는 반환 타입 변경을 거부한다(42P13).
-- ⚠️ 인자 순서는 (int, text) 다. 틀리면 `if exists` 라 조용히 넘어간 뒤
--    아래 create 가 "이미 있다"로 실패한다.
drop function if exists leaderboard_top(int, text);

create or replace function leaderboard_top(lim int, sort text default 'trophies')
returns table(rank bigint, id uuid, nickname text,
              trophies int, level int, stage int, tier int, badge text)
language sql stable security definer set search_path = public as $$
  select row_number() over (
           order by case sort
                      when 'level' then p.level
                      when 'stage' then p.tier
                      else p.trophies
                    end desc,
                    -- 2차 키. 진행도일 때만 의미가 있고, 나머지 축에서는
                    -- 1차 키가 이미 갈라 놓아 순서를 바꾸지 않는다.
                    case when sort = 'stage' then p.stage else 0 end desc
         ) as rank,
         p.id, p.nickname, p.trophies, p.level, p.stage, p.tier,
         coalesce(p.badge, '') as badge
  from profiles p
  order by case sort
             when 'level' then p.level
             when 'stage' then p.tier
             else p.trophies
           end desc,
           case when sort = 'stage' then p.stage else 0 end desc
  limit lim;
$$;


-- ────────────────────────────────────────────────────────────────
-- 확인 — `ok` 가 전부 true 여야 한다.
-- ────────────────────────────────────────────────────────────────
select '① tier 컬럼' as check, exists(
         select 1 from information_schema.columns
         where table_name='profiles' and column_name='tier') as ok
union all
select '② 앱이 tier 쓰기 가능', exists(
         select 1 from information_schema.column_privileges
         where table_name='profiles' and grantee='authenticated'
           and privilege_type='UPDATE' and column_name='tier')
union all
select '③ badge 는 여전히 차단', not exists(
         select 1 from information_schema.column_privileges
         where table_name='profiles' and grantee='authenticated'
           and privilege_type='UPDATE' and column_name='badge')
union all
select '④ 기존 컬럼 권한 유지', (
         select count(*) = 5 from information_schema.column_privileges
         where table_name='profiles' and grantee='authenticated'
           and privilege_type='UPDATE'
           and column_name in ('id','nickname','trophies','level','stage'))
union all
select '⑤ 순위표가 tier 반환', (
         select count(*) = 1 from pg_proc p
         where p.proname='leaderboard_top'
           and pg_get_function_result(p.oid) like '%tier%');

-- ③ 이 false 면 **누구나 챔피언 뱃지를 달 수 있는 상태**다 — ② 의 GRANT 목록에
--    badge 가 섞여 들어갔다는 뜻이니 즉시 다시 실행할 것.
-- ④ 가 false 면 GRANT 에서 컬럼을 빠뜨린 것 — 앱 랭킹이 폴백으로 떨어진다.
