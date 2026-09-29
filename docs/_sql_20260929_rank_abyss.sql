-- ────────────────────────────────────────────────────────────────
-- Bug Champ — 2026-09-29 진행도 랭킹: 극한 최종 사냥터 다음은 **심연 역대 최고 층**
-- Supabase 대시보드 → SQL Editor 에 통째로 붙여넣고 한 번 실행. 재실행해도 안전.
-- ────────────────────────────────────────────────────────────────
-- 목적: 진행도 정렬(회차 → 사냥터 → 전투력)은 극한 최종 사냥터에서 멈춰, 그 뒤로는 계정 전투력으로만 갈렸다.
--       심연(극한 이후 무한 층)을 몇 층까지 갔는지를 넣는다: 회차 → 사냥터 → **심연 역대 최고 층** → 전투력.
--       보상은 없다(명예용 — 누적 기록에 보상을 걸면 먼저 시작한 사람이 계속 받는다, CLAUDE.md §2.6).
-- 작성: 2026-09-29
-- 위험: leaderboard_top 반환 컬럼이 늘어 drop → create 한다(트랜잭션 안). 구버전 앱은 abyss_best 를 모르고 무시한다.
-- 쓰기: abyss_best 는 **서버만** 쓴다(세이브 업로드 때 서버가 층 증가를 경과 시간으로 자른 값) — 앱에 UPDATE 권한을 주지 않는다.
-- 순서: ⚠️ **서버 재배포보다 먼저**(서버가 이 칸을 쓴다 — 없으면 쓰기가 실패하고 로그만 남는다).
-- 되돌리기: 맨 아래 ROLLBACK 절(09-15 정의로 복귀). 컬럼은 지우지 않는다.

begin;

alter table profiles
  add column if not exists abyss_best int not null default 0;

drop function if exists leaderboard_top(int, text);
create function leaderboard_top(lim int, sort text default 'trophies')
returns table(rank bigint, id uuid, nickname text,
              trophies int, level int, stage int, tier int, badge text,
              power double precision, abyss_best int)
language sql stable security definer set search_path = public as $$
  with ranked as (
    select p.id, p.nickname, p.trophies, p.level, p.stage, p.tier,
           coalesce(p.badge, '') as badge, p.power, p.abyss_best,
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
               -- 3차(2026-09-29): 극한 최종 사냥터 다음 — 심연 역대 최고 층.
               case sort when 'stage' then p.abyss_best else 0 end desc,
               case sort when 'stage' then p.power else 0 end desc,
               case sort when 'stage' then p.stage else 0 end desc,
               p.id
           ) as rank
    from profiles p
  )
  select r.rank, r.id, r.nickname, r.trophies, r.level, r.stage, r.tier,
         r.badge, r.power, r.abyss_best
  from ranked r
  order by r.rank
  limit lim;
$$;

commit;

-- 확인 — `ok` 가 전부 true 여야 한다.
select '① abyss_best 컬럼' as check, exists(
         select 1 from information_schema.columns
         where table_name='profiles' and column_name='abyss_best') as ok
union all
select '② 앱은 abyss_best 를 쓸 수 없다', not exists(
         select 1 from information_schema.column_privileges
         where table_name='profiles' and grantee='authenticated'
           and privilege_type='UPDATE' and column_name='abyss_best')
union all
select '③ 순위표가 abyss_best 반환', (
         select count(*) = 1 from pg_proc p
         where p.proname='leaderboard_top'
           and pg_get_function_result(p.oid) like '%abyss_best%');

-- ROLLBACK (09-15 정의로 복귀 — 서버를 먼저 이전 리비전으로)
-- begin;
-- drop function if exists leaderboard_top(int, text);
-- (docs/_sql_20260915_rank_power.sql 의 create function leaderboard_top ... 를 다시 실행)
-- commit;
