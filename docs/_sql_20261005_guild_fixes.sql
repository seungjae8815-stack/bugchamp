-- ────────────────────────────────────────────────────────────────
-- Bug Champ — 2026-10-05 길드 공개 전 점검 수정(서버 원자화 · 유저 기준 상한 · 보스 체력 · 길드전 판정)
-- Supabase 대시보드 → SQL Editor 에 통째로 붙여넣고 한 번 실행. 재실행해도 안전(create or replace ·
-- add column if not exists · on conflict do nothing).
-- 설계: docs/design_guild.md §7.5 (2026-10-05 개정분)
-- ────────────────────────────────────────────────────────────────
-- 목적:
--   ① 미션 출발 — 하루 3회·진행 중 1개 검사를 **유저 잠금 아래** 세고 insert(`guild_mission_start`).
--      조회 후 insert 라 동시 요청으로 무한 출발되던 구멍.
--   ② 도움 보상 하루 5회 — 같은 방식(`guild_mission_help`).
--   ③ 길드 보스 체력 — 그 주에 공격하는 길드원의 몫(전투력 × hitsPerMember × 현재 단계 배율)을
--      공격 순간 체력에 더한다(`guild_boss_hit_v2`, 새 칸 `guild_boss.est_power`·`guild_boss_hits.power`).
--      방어팀을 비우고 보스를 열면 체력 4 가 되던 구멍. 하루 공격 수는 **유저 기준**(길드를 옮겨도 이어진다).
--   ④ 출석 — 유저 기준 하루 1회(`guild_user_daily` · `guild_donate_v2`). 추방 → 다른 길드 가입으로 두 번 받던 구멍.
--      길드전 점수 — 같은 사람·같은 날은 길드를 옮겨도 합쳐서 상한까지(`guild_war_set_v2`·`guild_war_add_v2`).
--   ⑤ 길드전 판정 — 동시에 여러 요청이 결투 30판을 다 돌리지 않게 판정 표시(`guild_war_resolve_lock`,
--      새 칸 `guild_war_matches.resolving_at`). 하루 승자 판정용 집계(`guild_war_day_stats`·
--      `guild_war_tier_avg_stats`, 새 칸 `guild_war_scores.updated_at` = 그 점수에 도달한 시각).
--   ⑥ 상점 환불 — 코인 차감 뒤 세이브 저장이 실패하면 코인·구매 수를 되돌린다(`guild_shop_refund`).
--   ⑦ 직책 권한 재정리(2026-10-05 사장님 확정) — 부길드장 가입 수락 허용 스위치(`guilds.deputy_can_accept`,
--      기본 켜짐, 길드장만 바꾼다). `guild_get` 이 이 칸을 돌려주게 다시 만든다(반환 모양이 바뀌어 drop 후 create).
--      멤버 등급은 `guild_members.contribution` 의 파생값이라 DB 변경 없음.
--   ⑧ 길드 문장(2026-10-05) — `guilds.emblem smallint`(null 허용, 1~10 check · null = 앱이 길드 id 해시로 기본 문장).
--      문장을 돌려줘야 하는 조회 `guild_get`(⑦ 의 deputy_can_accept 와 **한 번에** 다시 만든다) · `guild_list` ·
--      `guild_boss_top`(다른 길드 이름을 돌려주는 순위) — 반환 모양이 바뀌어 drop 후 create.
--      길드전 상대 문장은 서버가 `guild_get` 으로 상대 길드를 읽어 붙인다(`guild_war_match` 변경 없음).
-- 작성: 2026-10-05
-- 위험: 낮음. 새 함수·새 테이블·기본값 있는 새 칸만 더한다(⑦ guild_get 은 칸 하나를 더해 다시 만든다 —
--       옛 서버는 모르는 칸을 무시한다). 기존 함수(guild_boss_hit · guild_war_set/add ·
--       guild_donate · guild_war_totals/tier_avg)는 **그대로 둔다** — 새 서버가 뜨기 전까지 옛 서버가 계속 쓴다.
--       `guild_war_scores.updated_at` 은 기존 행에 실행 시각이 들어간다(길드전이 닫혀 있어 영향 없음).
-- 되돌리기: 맨 아래 ROLLBACK 절. 서버를 먼저 이전 리비전으로(새 서버는 새 함수가 없으면 해당 요청만 503).
-- 순서: ⚠️ `_sql_20261001_guild_base/missions/growth/boss/war` **다음**, **서버 재배포보다 먼저**.

begin;

-- ① 미션 출발 — 유저 잠금 아래 오늘 출발 수·진행 중 여부를 세고 넣는다 ─────────────────
-- 결과: 성공이면 넣은 행(jsonb), 아니면 {"error": "no_starts_left" | "mission_running"}.
create or replace function guild_mission_start(
  p_guild uuid, p_owner uuid, p_owner_nick text, p_day text, p_slot int, p_kind text,
  p_mult double precision, p_wait int, p_need double precision, p_owner_power double precision,
  p_owner_stage int, p_started timestamptz, p_ends timestamptz, p_solo boolean, p_helper_max int,
  p_daily int
) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  n int;
  m guild_missions%rowtype;
begin
  perform pg_advisory_xact_lock(hashtext('guild_mission_start:' || p_owner::text));
  select count(*) into n from guild_missions where owner = p_owner and day_key = p_day;
  if n >= p_daily then return jsonb_build_object('error', 'no_starts_left'); end if;
  if exists(select 1 from guild_missions
             where owner = p_owner and not settled and ends_at > p_started) then
    return jsonb_build_object('error', 'mission_running');
  end if;
  insert into guild_missions (guild_id, owner, owner_nick, day_key, slot, kind, mult, wait_sec,
                              need_power, owner_power, owner_stage, helper_max, started_at,
                              ends_at, solo)
  values (p_guild, p_owner, coalesce(p_owner_nick, ''), p_day, p_slot, coalesce(p_kind, ''),
          p_mult, p_wait, p_need, p_owner_power, greatest(1, p_owner_stage), p_helper_max,
          p_started, p_ends, p_solo)
  returning * into m;
  return to_jsonb(m);
end;
$$;

-- ② 도와주기 — 유저 잠금 아래 오늘 받은 도움 보상 수를 세고, 보상 여부를 정해 넣는다 ────────
-- 결과: {"ok": true, "rewarded": bool} 또는 {"error": "already_helped" | "helpers_full" | "mission_not_found"}.
-- 도움 인원 상한은 기존 트리거(guild_mission_helper_cap)가 그대로 본다.
create or replace function guild_mission_help(
  p_mission uuid, p_user uuid, p_nick text, p_power double precision, p_stage int,
  p_day text, p_max_rewards int
) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  n  int;
  rw boolean;
begin
  perform pg_advisory_xact_lock(hashtext('guild_mission_help:' || p_user::text));
  select count(*) into n from guild_mission_helpers
   where user_id = p_user and day_key = p_day and rewarded;
  rw := n < p_max_rewards;
  begin
    insert into guild_mission_helpers (mission_id, user_id, nickname, power, stage, day_key, rewarded)
    values (p_mission, p_user, coalesce(p_nick, ''), greatest(0, p_power), greatest(1, p_stage),
            p_day, rw);
  exception
    when unique_violation then
      return jsonb_build_object('error', 'already_helped');
    when foreign_key_violation then
      return jsonb_build_object('error', 'mission_not_found');
    when raise_exception then
      return jsonb_build_object('error',
        case when sqlerrm = 'mission_not_found' then 'mission_not_found' else 'helpers_full' end);
  end;
  return jsonb_build_object('ok', true, 'rewarded', rw);
end;
$$;

-- ③ 길드 보스 — 공격자 몫을 체력에 더하고, 하루 공격 수는 유저 기준 ─────────────────────
alter table guild_boss      add column if not exists est_power double precision not null default 0;
alter table guild_boss_hits add column if not exists power     double precision not null default 0;
comment on column guild_boss.est_power is '만들 때 추정(방어팀 있는 길드원 합). 체력 = max(est_power, base_power) × 단계 배율';
comment on column guild_boss.base_power is '2026-10-05~: 그 주 공격자 몫의 합(공격할 때마다 늘어난 만큼 더한다)';
comment on column guild_boss_hits.power is '이 길드 보스 체력에 이미 넣은 내 전투력(더 세지면 차이만 더 넣는다)';

-- 공격 한 번. 결과 jsonb: {ok, killed, stage, hp_max, hp_left, hp_hit(이번 공격 순간의 최대 체력)}.
create or replace function guild_boss_hit_v2(
  p_week text, p_guild uuid, p_user uuid, p_day text, p_damage double precision,
  p_power double precision, p_hpm double precision,
  p_max_daily int, p_growth double precision, p_kill_coins int
) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  b        guild_boss%rowtype;
  h        guild_boss_hits%rowtype;
  had      boolean;
  today    int := 0;
  counted  double precision := 0;
  delta    double precision;
  new_base double precision;
  new_max  double precision;
  grow     double precision;
  left_hp  double precision;
  nxt      double precision;
begin
  select * into b from guild_boss where week = p_week and guild_id = p_guild for update;
  if not found then return jsonb_build_object('ok', false); end if;

  select * into h from guild_boss_hits where week = p_week and user_id = p_user for update;
  had := found;
  -- 하루 공격 수는 **유저 기준**(길드를 옮겨도 이어진다 — 추방 → 재가입으로 하루 두 번 받던 구멍).
  if had and h.day_key = p_day then today := h.day_hits; end if;
  if today >= p_max_daily then return jsonb_build_object('ok', false); end if;
  if had and h.guild_id = p_guild then counted := h.power; end if;

  -- 내 몫을 체력에 넣는다 — 처음이면 전부, 그 사이 세졌으면 차이만. 현재 단계 배율로.
  delta := greatest(0, p_power - counted);
  if delta > 0 then
    new_base := b.base_power + delta;
    new_max  := greatest(b.est_power, new_base) * p_hpm * power(p_growth, greatest(0, b.stage - 1));
    grow     := greatest(0, new_max - b.hp_max);
    b.base_power := new_base;
    b.hp_max     := b.hp_max + grow;
    b.hp_left    := b.hp_left + grow;
  end if;

  insert into guild_boss_hits (week, user_id, guild_id, damage, hits, day_key, day_hits, power)
  values (p_week, p_user, p_guild, p_damage, 1, p_day, 1, greatest(0, p_power))
  on conflict (week, user_id) do update set
    damage   = case when guild_boss_hits.guild_id = p_guild
                    then guild_boss_hits.damage + p_damage else p_damage end,
    hits     = case when guild_boss_hits.guild_id = p_guild
                    then guild_boss_hits.hits + 1 else 1 end,
    power    = greatest(counted, p_power),
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
    update guild_boss set stage = b.stage + 1, hp_max = nxt, hp_left = nxt,
                          base_power = b.base_power, updated_at = now()
     where week = p_week and guild_id = p_guild;
    return jsonb_build_object('ok', true, 'killed', 1, 'stage', b.stage + 1,
                              'hp_max', nxt, 'hp_left', nxt, 'hp_hit', b.hp_max);
  end if;
  update guild_boss set hp_max = b.hp_max, hp_left = left_hp, base_power = b.base_power,
                        updated_at = now()
   where week = p_week and guild_id = p_guild;
  return jsonb_build_object('ok', true, 'killed', 0, 'stage', b.stage,
                            'hp_max', b.hp_max, 'hp_left', left_hp, 'hp_hit', b.hp_max);
end;
$$;

-- ④ 출석 — 유저 기준 하루 1회 ──────────────────────────────────────────
create table if not exists guild_user_daily (
  user_id    uuid not null primary key references auth.users(id) on delete cascade,
  donate_day text not null default ''
);
alter table guild_user_daily enable row level security;   -- 정책 없음 = 서버 전용
-- 이미 오늘 출석한 기록을 옮긴다(재실행해도 덮지 않는다).
insert into guild_user_daily (user_id, donate_day)
select user_id, donate_day from guild_members where donate_day <> ''
on conflict (user_id) do nothing;

-- 그날 처음이면 코인·기여도를 더하고 true. 길드를 옮겨도 같은 날엔 false
-- (그때 지금 길드의 멤버 행에도 오늘 날짜를 적어 화면의 "출석함" 표시를 맞춘다).
create or replace function guild_donate_v2(p_user uuid, p_day text, p_coins int)
returns boolean language plpgsql security definer set search_path = public as $$
declare
  n int;
begin
  perform 1 from guild_members where user_id = p_user for update;
  if not found then return false; end if;
  insert into guild_user_daily (user_id, donate_day) values (p_user, p_day)
  on conflict (user_id) do update set donate_day = excluded.donate_day
   where guild_user_daily.donate_day <> excluded.donate_day;
  get diagnostics n = row_count;
  if n = 0 then
    update guild_members set donate_day = p_day where user_id = p_user and donate_day <> p_day;
    return false;
  end if;
  update guild_members
     set donate_day = p_day,
         coins = coins + greatest(0, p_coins),
         contribution = contribution + greatest(0, p_coins)
   where user_id = p_user;
  return true;
end;
$$;

-- ④-b 길드전 점수 — 같은 사람·같은 날은 길드를 옮겨도 합쳐서 상한까지 ──────────────────
alter table guild_war_scores add column if not exists updated_at timestamptz not null default now();
comment on column guild_war_scores.updated_at is '점수가 마지막으로 오른 시각(하루 동점 → 먼저 도달한 쪽)';

-- 앱 누적값(그날 내 행동 전체 기준 점수) — 다른 길드에서 이미 받은 몫을 빼고 **올리기만**.
create or replace function guild_war_set_v2(
  p_week text, p_guild uuid, p_user uuid, p_day int, p_score int, p_cap int
) returns void language plpgsql security definer set search_path = public as $$
declare
  other   int;
  allowed int;
begin
  perform pg_advisory_xact_lock(hashtext('guild_war_user:' || p_week || ':' || p_user::text || ':' || p_day));
  select coalesce(sum(score), 0) into other from guild_war_scores
   where week = p_week and user_id = p_user and day = p_day and guild_id <> p_guild;
  allowed := least(greatest(0, p_score), greatest(0, p_cap)) - other;
  if allowed <= 0 then return; end if;
  insert into guild_war_scores (week, guild_id, user_id, day, score, updated_at)
  values (p_week, p_guild, p_user, p_day, allowed, now())
  on conflict (week, guild_id, user_id, day) do update
    set score = excluded.score, updated_at = now()
  where guild_war_scores.score < excluded.score;
end;
$$;

-- 서버 확정 행동 — 더한다(다른 길드 몫과 합쳐 상한까지).
create or replace function guild_war_add_v2(
  p_week text, p_guild uuid, p_user uuid, p_day int, p_add int, p_cap int
) returns void language plpgsql security definer set search_path = public as $$
declare
  other int;
  room  int;
begin
  perform pg_advisory_xact_lock(hashtext('guild_war_user:' || p_week || ':' || p_user::text || ':' || p_day));
  select coalesce(sum(score), 0) into other from guild_war_scores
   where week = p_week and user_id = p_user and day = p_day and guild_id <> p_guild;
  room := greatest(0, p_cap - other);
  if room <= 0 or p_add <= 0 then return; end if;
  insert into guild_war_scores (week, guild_id, user_id, day, score, updated_at)
  values (p_week, p_guild, p_user, p_day, least(p_add, room), now())
  on conflict (week, guild_id, user_id, day) do update
    set score = least(room, guild_war_scores.score + p_add), updated_at = now()
  where least(room, guild_war_scores.score + p_add) > guild_war_scores.score;
end;
$$;

-- ⑤ 하루 승자 판정용 집계 — 합 · 점수 낸 인원 · 그 합에 도달한 시각 ───────────────────
create or replace function guild_war_day_stats(p_week text, p_guild uuid)
returns table(day int, total bigint, members bigint, last_at timestamptz)
language sql stable security definer set search_path = public as $$
  select s.day, sum(s.score)::bigint,
         count(*) filter (where s.score > 0),
         max(s.updated_at) filter (where s.score > 0)
    from guild_war_scores s
   where s.week = p_week and s.guild_id = p_guild
   group by s.day;
$$;

-- 가상 길드 = 같은 티어 길드들의 일차별 합·인원의 평균(도달 시각은 없다 → 서버가 seed 로 가른다).
create or replace function guild_war_tier_avg_stats(p_week text, p_tier text)
returns table(day int, total bigint, members bigint)
language sql stable security definer set search_path = public as $$
  select x.day, round(avg(x.total))::bigint, round(avg(x.members))::bigint
  from (select s.guild_id, s.day, sum(s.score) as total,
               count(*) filter (where s.score > 0) as members
          from guild_war_scores s join guilds g on g.id = s.guild_id
         where s.week = p_week and g.tier = p_tier
         group by s.guild_id, s.day) x
  group by x.day;
$$;

-- 판정 표시 — 결과가 아직 없고 아무도 판정 중이 아니면(또는 p_stale_sec 넘게 멈췄으면) 이번 요청이 맡는다.
alter table guild_war_matches add column if not exists resolving_at timestamptz;
create or replace function guild_war_resolve_lock(p_match uuid, p_stale_sec int default 120)
returns boolean language plpgsql security definer set search_path = public as $$
declare
  n int;
begin
  update guild_war_matches set resolving_at = now()
   where id = p_match and result is null
     and (resolving_at is null or resolving_at < now() - make_interval(secs => p_stale_sec));
  get diagnostics n = row_count;
  return n > 0;
end;
$$;

-- ⑥ 상점 환불 — 세이브 저장 실패 때 코인·이번 기간 구매 수를 되돌린다(기여도는 원래 안 늘었다) ──
create or replace function guild_shop_refund(p_user uuid, p_item text, p_period text, p_cost int)
returns void language plpgsql security definer set search_path = public as $$
begin
  update guild_members set coins = coins + greatest(0, p_cost) where user_id = p_user;
  update guild_shop_buys set n = greatest(0, n - 1)
   where user_id = p_user and item = p_item and period_key = p_period;
end;
$$;

-- ⑦ 부길드장 가입 수락 허용 스위치 + guild_get 이 돌려주게 ───────────────────────────
alter table guilds add column if not exists deputy_can_accept boolean not null default true;
comment on column guilds.deputy_can_accept is '부길드장이 가입 신청을 수락·거절할 수 있나(길드장만 바꾼다, 기본 켜짐) — 2026-10-05';

-- guild_get 은 ⑧ 에서 문장 칸과 함께 한 번에 다시 만든다(deputy_can_accept 포함).

-- ⑧ 길드 문장 + 조회 RPC 가 돌려주게 ───────────────────────────────────────
-- null 허용(기본 null) — 옛 길드·고르지 않은 길드는 앱이 길드 id 해시로 기본 문장을 보인다(core_run guildDefaultEmblem).
-- 1~10 = 그림 emblem_01~10(core_run kGuildEmblemCount). 그림을 늘리면 이 check 도 함께 바꾼다.
alter table guilds add column if not exists emblem smallint
  constraint guilds_emblem_range check (emblem between 1 and 10);
comment on column guilds.emblem is '길드 문장 1~10(null = 고른 적 없음 → 앱이 id 해시로 기본 문장) — 2026-10-05';

-- _sql_20261001_guild_growth.sql 정의 + deputy_can_accept(⑦) + emblem. 반환 칸이 바뀌어 create or replace 로는 안 된다.
drop function if exists guild_get(uuid);
create function guild_get(p_guild uuid)
returns table(id uuid, name text, lang text, level int, exp bigint, max_members int,
              join_mode text, notice text, leader uuid, skill_points jsonb,
              tier text, gr int, created_at timestamptz,
              member_count bigint, avg_power double precision, deputy_can_accept boolean,
              emblem smallint)
language sql stable security definer set search_path = public as $$
  select g.id, g.name, g.lang, g.level, g.exp, g.max_members, g.join_mode, g.notice, g.leader,
         g.skill_points, g.tier, g.gr, g.created_at,
         (select count(*) from guild_members m where m.guild_id = g.id),
         coalesce((select avg(coalesce(p.power, 0)) from guild_members m
                     left join profiles p on p.id = m.user_id
                    where m.guild_id = g.id), 0)::double precision,
         g.deputy_can_accept,
         g.emblem
  from guilds g where g.id = p_guild;
$$;
revoke execute on function guild_get(uuid) from public, anon, authenticated;

-- _sql_20261001_guild_growth.sql 정의 + emblem(맨 끝 칸).
drop function if exists guild_list(uuid, text, text, int);
create function guild_list(p_user uuid, p_lang text, p_query text default '', lim int default 20)
returns table(id uuid, name text, lang text, level int, exp bigint, max_members int,
              join_mode text, notice text, leader uuid, skill_points jsonb,
              tier text, gr int, created_at timestamptz,
              member_count bigint, avg_power double precision, emblem smallint)
language sql stable security definer set search_path = public as $$
  with me as (
    select coalesce((select power from profiles where id = p_user), 0)::double precision as pw
  ),
  g as (
    select g.*,
           (select count(*) from guild_members m where m.guild_id = g.id) as member_count,
           coalesce((select avg(coalesce(p.power, 0)) from guild_members m
                       left join profiles p on p.id = m.user_id
                      where m.guild_id = g.id), 0)::double precision as avg_power
    from guilds g
    where coalesce(p_query, '') = ''
       or g.name ilike '%' || replace(replace(replace(p_query, '\', '\\'), '%', '\%'), '_', '\_') || '%'
  )
  select g.id, g.name, g.lang, g.level, g.exp, g.max_members, g.join_mode, g.notice, g.leader,
         g.skill_points, g.tier, g.gr, g.created_at, g.member_count, g.avg_power, g.emblem
  from g, me
  order by (g.lang = p_lang) desc,
           (g.member_count >= g.max_members) asc,
           abs(ln(g.avg_power + 1) - ln(me.pw + 1)) asc,
           g.created_at desc
  limit lim;
$$;
revoke execute on function guild_list(uuid, text, text, int) from public, anon, authenticated;

-- _sql_20261001_guild_boss.sql 정의 + emblem(다른 길드 이름을 돌려주는 순위표라 문장도 같이).
drop function if exists guild_boss_top(text, text, int);
create function guild_boss_top(p_week text, p_tier text, lim int default 10)
returns table(rank bigint, guild_id uuid, name text, stage int, progress double precision,
              emblem smallint)
language sql stable security definer set search_path = public as $$
  select row_number() over (order by b.stage desc, (1 - b.hp_left / nullif(b.hp_max, 0)) desc,
                                     b.updated_at asc),
         b.guild_id, coalesce(g.name, ''), b.stage,
         (1 - b.hp_left / nullif(b.hp_max, 0))::double precision,
         g.emblem
  from guild_boss b left join guilds g on g.id = b.guild_id
  where b.week = p_week and b.tier = p_tier and (b.stage > 1 or b.hp_left < b.hp_max)
  order by b.stage desc, (1 - b.hp_left / nullif(b.hp_max, 0)) desc, b.updated_at asc
  limit lim;
$$;
revoke execute on function guild_boss_top(text, text, int) from public, anon, authenticated;

revoke execute on function guild_mission_start(uuid, uuid, text, text, int, text, double precision, int, double precision, double precision, int, timestamptz, timestamptz, boolean, int, int) from public, anon, authenticated;
revoke execute on function guild_mission_help(uuid, uuid, text, double precision, int, text, int) from public, anon, authenticated;
revoke execute on function guild_boss_hit_v2(text, uuid, uuid, text, double precision, double precision, double precision, int, double precision, int) from public, anon, authenticated;
revoke execute on function guild_donate_v2(uuid, text, int) from public, anon, authenticated;
revoke execute on function guild_war_set_v2(text, uuid, uuid, int, int, int) from public, anon, authenticated;
revoke execute on function guild_war_add_v2(text, uuid, uuid, int, int, int) from public, anon, authenticated;
revoke execute on function guild_war_day_stats(text, uuid) from public, anon, authenticated;
revoke execute on function guild_war_tier_avg_stats(text, text) from public, anon, authenticated;
revoke execute on function guild_war_resolve_lock(uuid, int) from public, anon, authenticated;
revoke execute on function guild_shop_refund(uuid, text, text, int) from public, anon, authenticated;

commit;

-- ────────────────────────────────────────────────────────────────
-- 확인 — `ok` 가 전부 true 여야 한다.
-- ────────────────────────────────────────────────────────────────
select '① 새 함수 10개' as check, (select count(*) from pg_proc where proname in (
         'guild_mission_start','guild_mission_help','guild_boss_hit_v2','guild_donate_v2',
         'guild_war_set_v2','guild_war_add_v2','guild_war_day_stats','guild_war_tier_avg_stats',
         'guild_war_resolve_lock','guild_shop_refund')) = 10 as ok
union all
select '② 새 칸 4개', (select count(*) from information_schema.columns where
         (table_name = 'guild_boss' and column_name = 'est_power') or
         (table_name = 'guild_boss_hits' and column_name = 'power') or
         (table_name = 'guild_war_scores' and column_name = 'updated_at') or
         (table_name = 'guild_war_matches' and column_name = 'resolving_at')) = 4
union all
select '③ guild_user_daily RLS 켜짐(정책 없음)',
       (select relrowsecurity from pg_class where relname = 'guild_user_daily')
       and not exists(select 1 from pg_policies where tablename = 'guild_user_daily')
union all
select '④ 앱(anon·authenticated)이 새 함수를 못 부른다', not exists(
         select 1 from pg_proc p where p.proname in (
           'guild_mission_start','guild_mission_help','guild_boss_hit_v2','guild_donate_v2',
           'guild_war_set_v2','guild_war_add_v2','guild_war_day_stats','guild_war_tier_avg_stats',
           'guild_war_resolve_lock','guild_shop_refund')
           and (has_function_privilege('anon', p.oid, 'execute')
                or has_function_privilege('authenticated', p.oid, 'execute')))
union all
select '⑤ guilds.deputy_can_accept(기본 true)', exists(select 1 from information_schema.columns
         where table_name = 'guilds' and column_name = 'deputy_can_accept'
           and column_default = 'true' and is_nullable = 'NO')
union all
select '⑥ guild_get 이 deputy_can_accept 를 돌려준다', exists(select 1 from information_schema.routines r
         join information_schema.parameters p on p.specific_name = r.specific_name
         where r.routine_name = 'guild_get' and p.parameter_name = 'deputy_can_accept')
union all
select '⑦ 앱이 guild_get 을 못 부른다', not exists(select 1 from pg_proc p where p.proname = 'guild_get'
         and (has_function_privilege('anon', p.oid, 'execute')
              or has_function_privilege('authenticated', p.oid, 'execute')))
union all
select '⑧ guilds.emblem(null 허용 · 1~10 check)', exists(select 1 from information_schema.columns
         where table_name = 'guilds' and column_name = 'emblem' and is_nullable = 'YES')
       and exists(select 1 from pg_constraint where conname = 'guilds_emblem_range')
union all
select '⑨ guild_get·guild_list·guild_boss_top 이 emblem 을 돌려준다', (select count(distinct r.routine_name)
         from information_schema.routines r
         join information_schema.parameters p on p.specific_name = r.specific_name
         where r.routine_name in ('guild_get','guild_list','guild_boss_top')
           and p.parameter_name = 'emblem') = 3
union all
select '⑩ 앱이 guild_list·guild_boss_top 을 못 부른다', not exists(select 1 from pg_proc p
         where p.proname in ('guild_list','guild_boss_top')
           and (has_function_privilege('anon', p.oid, 'execute')
                or has_function_privilege('authenticated', p.oid, 'execute')));

-- ────────────────────────────────────────────────────────────────
-- ROLLBACK (서버를 먼저 이전 리비전으로 — 옛 서버는 옛 함수만 쓴다)
-- 새 칸은 기본값이 있어 옛 서버에 무해하므로 남겨도 된다. 지우려면 마지막 다섯 줄까지.
-- ⑦ guild_get 은 남겨 둬도 옛 서버가 모르는 칸을 무시한다. 굳이 되돌리려면 deputy_can_accept 를 지우기 **전에**
--    _sql_20261001_guild_growth.sql 의 guild_get 정의를 drop 후 다시 실행(칸을 먼저 지우면 guild_get 이 깨진다).
-- ────────────────────────────────────────────────────────────────
-- begin;
--   drop function if exists guild_shop_refund(uuid, text, text, int);
--   drop function if exists guild_war_resolve_lock(uuid, int);
--   drop function if exists guild_war_tier_avg_stats(text, text);
--   drop function if exists guild_war_day_stats(text, uuid);
--   drop function if exists guild_war_add_v2(text, uuid, uuid, int, int, int);
--   drop function if exists guild_war_set_v2(text, uuid, uuid, int, int, int);
--   drop function if exists guild_donate_v2(uuid, text, int);
--   drop table if exists guild_user_daily;
--   drop function if exists guild_boss_hit_v2(text, uuid, uuid, text, double precision, double precision, double precision, int, double precision, int);
--   drop function if exists guild_mission_help(uuid, uuid, text, double precision, int, text, int);
--   drop function if exists guild_mission_start(uuid, uuid, text, text, int, text, double precision, int, double precision, double precision, int, timestamptz, timestamptz, boolean, int, int);
--   alter table guild_war_matches drop column if exists resolving_at;
--   alter table guild_war_scores  drop column if exists updated_at;
--   alter table guild_boss_hits   drop column if exists power;
--   alter table guild_boss        drop column if exists est_power;
--   -- (위 ⑦ 안내대로 guild_get 을 먼저 옛 정의로 되돌린 뒤에만)
--   alter table guilds            drop column if exists deputy_can_accept;
--   -- ⑧ 문장: emblem 을 지우기 **전에** guild_get·guild_list(growth 정의)·guild_boss_top(boss 정의)을
--   --    drop 후 옛 정의로 다시 만든다(칸을 먼저 지우면 세 함수가 깨진다). 옛 서버는 emblem 칸을 무시하므로 남겨도 된다.
--   alter table guilds            drop column if exists emblem;
-- commit;
