-- 목적: 랭킹 화면(leaderboard_top — 심연·레벨·진행도 탭)에서 **최근 7일 동안 서버 세이브 저장이 없는 계정**을 뺀다
--       (2026-11-12 사장님 — 오래 안 들어온 계정이 누적 랭킹에 계속 남는다). 기준 = saves.updated_at(서버가 업로드마다 적는다 —
--       앱을 켜 두면 60초마다). 돌아와서 앱을 켜면 다음 저장에 바로 다시 보인다(휴면 = 순위에서만 숨김).
--       결투 리그·심연 주간 순위는 그 주에 기록을 낸 사람만 나와 원래 해당 없음 — 건드리지 않는다.
-- 작성: 2026-11-12
-- 위험: 데이터 변경 없음. leaderboard_top 하나를 create or replace(인자·반환 형식 그대로 → 앱 호출·권한 그대로).
--       세이브 행이 아예 없는 프로필(서버에 한 번도 안 올린 계정)도 빠진다.
-- 되돌리기: 맨 아래 ROLLBACK(_sql_20261010_avatar.sql 의 정의 그대로).
-- 기준(지금 운영 DB 정의): _sql_20261010_avatar.sql(✅ 적용 2026-10-10) — rank_hidden 조건·avatar 반환을 그대로 둔다.

-- ① 먼저 영향 확인(읽기만) — 지금 랭킹 대상 중 몇 명이 빠지는지
select count(*)                                                            as ranked_now,
       count(*) filter (where s.updated_at > now() - interval '7 days')    as ranked_after,
       count(*) filter (where s.updated_at is null
                           or s.updated_at <= now() - interval '7 days')   as hidden_after
from profiles p
left join saves s on s.id = p.id
where not p.rank_hidden;

begin;

create or replace function leaderboard_top(lim int, sort text default 'trophies')
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
      -- 2026-11-12 최근 7일 안에 서버에 세이브를 저장한 계정만(숨긴 계정은 순위 번호도 차지하지 않는다)
      and exists (
        select 1 from saves s
        where s.id = p.id and s.updated_at > now() - interval '7 days'
      )
  )
  select r.rank, r.id, r.nickname, r.trophies, r.level, r.stage, r.tier,
         r.badge, r.power, r.abyss_best, r.avatar
  from ranked r
  order by r.rank
  limit lim;
$$;

commit;

-- ② 확인 — 둘 다 true 여야 한다. ⚠️ 운영 DB 에는 인자 하나짜리 옛 leaderboard_top(lim) 이 따로 남아 있다(앱은 lim·sort 판만 부른다) —
--    그래서 인자로 골라 본다(2026-11-12 적용 때 이름만으로 보다 옛 판을 집어 false 가 나왔다).
select '① 7일 조건이 들어갔다' as check, (
         select pg_get_functiondef(p.oid) like '%7 days%' from pg_proc p
         where p.proname = 'leaderboard_top'
           and pg_get_function_identity_arguments(p.oid) = 'lim integer, sort text')
union all
select '② 숨긴 계정 조건·avatar 반환 그대로', (
         select pg_get_functiondef(p.oid) like '%rank_hidden%'
            and pg_get_function_result(p.oid) like '%avatar%'
         from pg_proc p
         where p.proname = 'leaderboard_top'
           and pg_get_function_identity_arguments(p.oid) = 'lim integer, sort text');

-- ROLLBACK (적용 후 문제가 생기면 — 7일 조건만 빠진 예전 정의)
-- begin;
-- create or replace function leaderboard_top(lim int, sort text default 'trophies')
-- returns table(rank bigint, id uuid, nickname text,
--               trophies int, level int, stage int, tier int, badge text,
--               power double precision, abyss_best int, avatar text)
-- language sql stable security definer set search_path = public as $$
--   with ranked as (
--     select p.id, p.nickname, p.trophies, p.level, p.stage, p.tier,
--            coalesce(p.badge, '') as badge, p.power, p.abyss_best, p.avatar,
--            row_number() over (
--              order by
--                case sort when 'level' then p.tier when 'stage' then p.tier else p.trophies end desc,
--                case sort when 'level' then p.level when 'stage' then (greatest(p.stage, 1) - 1) / 100 else 0 end desc,
--                case sort when 'stage' then p.abyss_best else 0 end desc,
--                case sort when 'stage' then p.power else 0 end desc,
--                case sort when 'stage' then p.stage else 0 end desc,
--                p.id
--            ) as rank
--     from profiles p
--     where not p.rank_hidden
--   )
--   select r.rank, r.id, r.nickname, r.trophies, r.level, r.stage, r.tier,
--          r.badge, r.power, r.abyss_best, r.avatar
--   from ranked r
--   order by r.rank
--   limit lim;
-- $$;
-- commit;
