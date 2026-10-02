-- ────────────────────────────────────────────────────────────────
-- Bug Champ — 2026-10-01 길드 4단계: 길드 보스(주 1마리 · 체력 공유 · 주간 순위 젤리)
-- Supabase 대시보드 → SQL Editor 에 통째로 붙여넣고 한 번 실행. 재실행해도 안전.
-- 설계: docs/design_guild.md §3 · 규칙 packages/core_run/lib/src/guild_boss.dart
-- ────────────────────────────────────────────────────────────────
-- 목적: 보스·공격 기록·순위 보상 수령 기록을 서버 전용 테이블로 둔다(RLS 켜고 정책 없음).
--       피해는 서버가 결투 방어팀 전투력으로 계산하고, 공격 한 번(하루 횟수 확인·체력 차감·처치·
--       처치 코인 지급)을 `guild_boss_hit` 한 함수 안에서 **보스 행을 잠그고** 처리한다.
-- 작성: 2026-10-01
-- 위험: 없음(새 테이블·새 함수만).
-- 되돌리기: 맨 아래 ROLLBACK 절. 서버를 먼저 이전 리비전으로.
-- 순서: ⚠️ `_guild_base` → `_guild_missions` → `_guild_growth` **다음**, **서버 재배포보다 먼저**.

begin;

create table if not exists guild_boss (
  week       text        not null,                  -- 주 시작(월 09시 KST) 날짜
  guild_id   uuid        not null references guilds(id) on delete cascade,
  tier       text        not null default 'bronze', -- 만들 때의 티어 — 주간 순위는 이 안에서
  stage      int         not null default 1,
  hp_max     double precision not null,
  hp_left    double precision not null,
  base_power double precision not null default 0,
  updated_at timestamptz not null default now(),    -- 마지막으로 체력이 줄어든 시각(동률 = 먼저 도달)
  primary key (week, guild_id)
);
create index if not exists guild_boss_rank_idx on guild_boss (week, tier, stage desc);

create table if not exists guild_boss_hits (
  week     text        not null,
  user_id  uuid        not null references auth.users(id) on delete cascade,
  guild_id uuid        not null,                    -- 공격한 길드(주중에 옮기면 새 길드로 다시 센다)
  damage   double precision not null default 0,
  hits     int         not null default 0,
  day_key  text        not null default '',
  day_hits int         not null default 0,          -- 그날 공격 수(하루 2회)
  primary key (week, user_id)
);
create index if not exists guild_boss_hits_guild_idx on guild_boss_hits (week, guild_id);

create table if not exists guild_boss_claims (
  week       text        not null,
  user_id    uuid        not null references auth.users(id) on delete cascade,
  claimed_at timestamptz not null default now(),
  primary key (week, user_id)
);

alter table guild_boss        enable row level security;
alter table guild_boss_hits   enable row level security;
alter table guild_boss_claims enable row level security;
-- ⚠️ 정책 없음 = 서버 전용.

-- 공격 한 번. 결과 jsonb: {ok, killed, stage, hp_max, hp_left}.
create or replace function guild_boss_hit(
  p_week text, p_guild uuid, p_user uuid, p_day text, p_damage double precision,
  p_max_daily int, p_growth double precision, p_kill_coins int
) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  b      guild_boss%rowtype;
  h      guild_boss_hits%rowtype;
  today  int := 0;
  left_hp double precision;
  nxt    double precision;
begin
  select * into b from guild_boss where week = p_week and guild_id = p_guild for update;
  if not found then return jsonb_build_object('ok', false); end if;

  select * into h from guild_boss_hits where week = p_week and user_id = p_user for update;
  if found and h.day_key = p_day and h.guild_id = p_guild then today := h.day_hits; end if;
  if today >= p_max_daily then return jsonb_build_object('ok', false); end if;

  insert into guild_boss_hits (week, user_id, guild_id, damage, hits, day_key, day_hits)
  values (p_week, p_user, p_guild, p_damage, 1, p_day, 1)
  on conflict (week, user_id) do update set
    damage   = case when guild_boss_hits.guild_id = p_guild
                    then guild_boss_hits.damage + p_damage else p_damage end,
    hits     = case when guild_boss_hits.guild_id = p_guild
                    then guild_boss_hits.hits + 1 else 1 end,
    guild_id = p_guild,
    day_key  = p_day,
    day_hits = today + 1;

  left_hp := b.hp_left - p_damage;
  if left_hp <= 0 then
    -- 처치 — 그 주에 이 보스를 친 길드원 **모두** 코인(방금 친 사람 포함).
    update guild_members
       set coins = coins + p_kill_coins * b.stage,
           contribution = contribution + p_kill_coins * b.stage
     where user_id in (select user_id from guild_boss_hits
                        where week = p_week and guild_id = p_guild);
    nxt := b.hp_max * p_growth;
    update guild_boss set stage = b.stage + 1, hp_max = nxt, hp_left = nxt, updated_at = now()
     where week = p_week and guild_id = p_guild;
    return jsonb_build_object('ok', true, 'killed', 1, 'stage', b.stage + 1,
                              'hp_max', nxt, 'hp_left', nxt);
  end if;
  update guild_boss set hp_left = left_hp, updated_at = now()
   where week = p_week and guild_id = p_guild;
  return jsonb_build_object('ok', true, 'killed', 0, 'stage', b.stage,
                            'hp_max', b.hp_max, 'hp_left', left_hp);
end;
$$;

-- 같은 티어 안 순위 — 단계 → 그 단계 피해율 → 먼저 도달. 한 대도 안 친 길드는 순위 밖.
create or replace function guild_boss_rank(p_week text, p_guild uuid)
returns int language sql stable security definer set search_path = public as $$
  with me as (select tier from guild_boss where week = p_week and guild_id = p_guild),
  r as (
    select g.guild_id,
           row_number() over (order by g.stage desc, (1 - g.hp_left / nullif(g.hp_max, 0)) desc,
                                       g.updated_at asc) as rn
    from guild_boss g, me
    where g.week = p_week and g.tier = me.tier and (g.stage > 1 or g.hp_left < g.hp_max)
  )
  select rn::int from r where guild_id = p_guild;
$$;

create or replace function guild_boss_top(p_week text, p_tier text, lim int default 10)
returns table(rank bigint, guild_id uuid, name text, stage int, progress double precision)
language sql stable security definer set search_path = public as $$
  select row_number() over (order by b.stage desc, (1 - b.hp_left / nullif(b.hp_max, 0)) desc,
                                     b.updated_at asc),
         b.guild_id, coalesce(g.name, ''), b.stage,
         (1 - b.hp_left / nullif(b.hp_max, 0))::double precision
  from guild_boss b left join guilds g on g.id = b.guild_id
  where b.week = p_week and b.tier = p_tier and (b.stage > 1 or b.hp_left < b.hp_max)
  order by b.stage desc, (1 - b.hp_left / nullif(b.hp_max, 0)) desc, b.updated_at asc
  limit lim;
$$;

revoke execute on function guild_boss_hit(text, uuid, uuid, text, double precision, int, double precision, int) from public, anon, authenticated;
revoke execute on function guild_boss_rank(text, uuid) from public, anon, authenticated;
revoke execute on function guild_boss_top(text, text, int) from public, anon, authenticated;

commit;

-- 확인
select '① 테이블 3개' as check, (select count(*) from information_schema.tables
         where table_name in ('guild_boss','guild_boss_hits','guild_boss_claims')) = 3 as ok
union all
select '② RLS 켜짐(정책 없음)', (select bool_and(relrowsecurity) from pg_class
         where relname in ('guild_boss','guild_boss_hits','guild_boss_claims'))
  and not exists(select 1 from pg_policies
         where tablename in ('guild_boss','guild_boss_hits','guild_boss_claims'));

-- ROLLBACK (서버를 먼저 이전 리비전으로)
-- begin;
--   drop function if exists guild_boss_top(text, text, int);
--   drop function if exists guild_boss_rank(text, uuid);
--   drop function if exists guild_boss_hit(text, uuid, uuid, text, double precision, int, double precision, int);
--   drop table if exists guild_boss_claims;
--   drop table if exists guild_boss_hits;
--   drop table if exists guild_boss;
-- commit;
