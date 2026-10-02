-- ────────────────────────────────────────────────────────────────
-- Bug Champ — 2026-10-01 길드 5단계: 주간 길드전(점수 · 매칭 · 결과 · 보상)
-- Supabase 대시보드 → SQL Editor 에 통째로 붙여넣고 한 번 실행. 재실행해도 안전.
-- 설계: docs/design_guild.md §4 · 규칙 packages/core_run/lib/src/guild_war.dart
-- ────────────────────────────────────────────────────────────────
-- 목적: 멤버·일차별 점수, 주간 대전(매칭·결과), 보상 수령 기록 — 전부 서버 전용(RLS 켜고 정책 없음).
--       매칭은 그 주 첫 조회 때 `guild_war_match` 가 한다(주별 advisory lock 으로 한 줄로 세운다 —
--       두 길드가 동시에 조회해도 같은 상대를 두 번 잡지 않는다). 결과는 7일차 첫 조회 때 서버가
--       `result is null` 조건으로 한 번만 적는다.
-- 작성: 2026-10-01
-- 위험: 없음(새 테이블·새 함수만). `guilds.gr`·`tier` 는 서버가 결과 때 바꾼다(1단계부터 있던 칸).
-- 되돌리기: 맨 아래 ROLLBACK 절. 서버를 먼저 이전 리비전으로.
-- 순서: ⚠️ `_guild_base` → `_guild_missions` → `_guild_growth` → `_guild_boss` **다음**, **서버 재배포보다 먼저**.

begin;

create table if not exists guild_war_scores (
  week     text not null,
  guild_id uuid not null references guilds(id) on delete cascade,
  user_id  uuid not null references auth.users(id) on delete cascade,
  day      int  not null check (day between 1 and 7),
  score    int  not null default 0,
  primary key (week, guild_id, user_id, day)
);
create index if not exists guild_war_scores_user_idx on guild_war_scores (week, user_id);

create table if not exists guild_war_matches (
  id         uuid        primary key default gen_random_uuid(),
  week       text        not null,
  guild_a    uuid        not null references guilds(id) on delete cascade,
  guild_b    uuid        references guilds(id) on delete set null,   -- null = 가상 길드
  tier_a     text        not null default 'bronze',                  -- 매칭 때 티어(보상 기준)
  tier_b     text        not null default 'bronze',
  result     jsonb,                                                  -- 7일차에 한 번
  created_at timestamptz not null default now()
);
create unique index if not exists guild_war_matches_a_uq on guild_war_matches (week, guild_a);
create unique index if not exists guild_war_matches_b_uq on guild_war_matches (week, guild_b)
  where guild_b is not null;

create table if not exists guild_war_claims (
  week       text        not null,
  user_id    uuid        not null references auth.users(id) on delete cascade,
  claimed_at timestamptz not null default now(),
  primary key (week, user_id)
);

alter table guild_war_scores  enable row level security;
alter table guild_war_matches enable row level security;
alter table guild_war_claims  enable row level security;
-- ⚠️ 정책 없음 = 서버 전용.

-- 앱 누적값 — **올리기만**(같은 값을 두 번 보내도 한 번).
create or replace function guild_war_set(p_week text, p_guild uuid, p_user uuid, p_day int, p_score int)
returns void language sql security definer set search_path = public as $$
  insert into guild_war_scores (week, guild_id, user_id, day, score)
  values (p_week, p_guild, p_user, p_day, greatest(0, p_score))
  on conflict (week, guild_id, user_id, day)
  do update set score = greatest(guild_war_scores.score, excluded.score);
$$;

-- 서버 확정 행동 — 더한다(상한까지).
create or replace function guild_war_add(
  p_week text, p_guild uuid, p_user uuid, p_day int, p_add int, p_cap int
) returns void language sql security definer set search_path = public as $$
  insert into guild_war_scores (week, guild_id, user_id, day, score)
  values (p_week, p_guild, p_user, p_day, least(greatest(0, p_add), p_cap))
  on conflict (week, guild_id, user_id, day)
  do update set score = least(p_cap, guild_war_scores.score + greatest(0, p_add));
$$;

create or replace function guild_war_totals(p_week text, p_guild uuid)
returns table(day int, total bigint)
language sql stable security definer set search_path = public as $$
  select day, sum(score)::bigint from guild_war_scores
   where week = p_week and guild_id = p_guild group by day;
$$;

-- 가상 길드 점수 = 같은 티어 길드들의 일차별 합의 평균.
create or replace function guild_war_tier_avg(p_week text, p_tier text)
returns table(day int, total bigint)
language sql stable security definer set search_path = public as $$
  select x.day, round(avg(x.total))::bigint
  from (select s.guild_id, s.day, sum(s.score) as total
          from guild_war_scores s join guilds g on g.id = s.guild_id
         where s.week = p_week and g.tier = p_tier
         group by s.guild_id, s.day) x
  group by x.day;
$$;

-- 매칭 — 있으면 그대로, 없으면 아직 짝이 없는 길드 중에서 고른다:
--   **직전 주(p_prev) 상대가 아닌 길드** → 같은 티어 → 가까운 등급점 → 무작위.
--   (직전 상대 회피는 우선순위다 — 후보가 그 길드뿐이면 가상 길드보다 낫기 때문에 다시 붙는다.)
-- 인원 미달이면 null. 상대가 없으면 guild_b = null(가상 길드).
drop function if exists guild_war_match(text, uuid, int);
create or replace function guild_war_match(p_week text, p_guild uuid, p_min int, p_prev text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  m    guild_war_matches%rowtype;
  me   guilds%rowtype;
  n    int;
  opp  uuid;
  prev uuid;
begin
  perform pg_advisory_xact_lock(hashtext('guild_war_match:' || p_week));
  select * into m from guild_war_matches
   where week = p_week and (guild_a = p_guild or guild_b = p_guild) limit 1;
  if found then return to_jsonb(m); end if;
  select count(*) into n from guild_members where guild_id = p_guild;
  if n < p_min then return null; end if;
  select * into me from guilds where id = p_guild;
  select case when w.guild_a = p_guild then w.guild_b else w.guild_a end into prev
    from guild_war_matches w
   where w.week = p_prev and (w.guild_a = p_guild or w.guild_b = p_guild)
   limit 1;
  select g.id into opp from guilds g
   where g.id <> p_guild
     and (select count(*) from guild_members x where x.guild_id = g.id) >= p_min
     and not exists (select 1 from guild_war_matches w
                      where w.week = p_week and (w.guild_a = g.id or w.guild_b = g.id))
   order by (g.id is not distinct from prev) asc, (g.tier = me.tier) desc,
            abs(g.gr - me.gr), random()
   limit 1;
  insert into guild_war_matches (week, guild_a, guild_b, tier_a, tier_b)
  values (p_week, p_guild, opp, me.tier,
          coalesce((select tier from guilds where id = opp), me.tier))
  returning * into m;
  return to_jsonb(m);
end;
$$;

revoke execute on function guild_war_set(text, uuid, uuid, int, int) from public, anon, authenticated;
revoke execute on function guild_war_add(text, uuid, uuid, int, int, int) from public, anon, authenticated;
revoke execute on function guild_war_totals(text, uuid) from public, anon, authenticated;
revoke execute on function guild_war_tier_avg(text, text) from public, anon, authenticated;
revoke execute on function guild_war_match(text, uuid, int, text) from public, anon, authenticated;

commit;

-- 확인
select '① 테이블 3개' as check, (select count(*) from information_schema.tables
         where table_name in ('guild_war_scores','guild_war_matches','guild_war_claims')) = 3 as ok
union all
select '② RLS 켜짐(정책 없음)', (select bool_and(relrowsecurity) from pg_class
         where relname in ('guild_war_scores','guild_war_matches','guild_war_claims'))
  and not exists(select 1 from pg_policies
         where tablename in ('guild_war_scores','guild_war_matches','guild_war_claims'));

-- ROLLBACK (서버를 먼저 이전 리비전으로)
-- begin;
--   drop function if exists guild_war_match(text, uuid, int, text);
--   drop function if exists guild_war_tier_avg(text, text);
--   drop function if exists guild_war_totals(text, uuid);
--   drop function if exists guild_war_add(text, uuid, uuid, int, int, int);
--   drop function if exists guild_war_set(text, uuid, uuid, int, int);
--   drop table if exists guild_war_claims;
--   drop table if exists guild_war_matches;
--   drop table if exists guild_war_scores;
-- commit;
