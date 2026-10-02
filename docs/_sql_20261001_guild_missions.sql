-- ────────────────────────────────────────────────────────────────
-- Bug Champ — 2026-10-01 길드 2단계: 길드 미션 + 도와주기 + 보상 받기
-- Supabase 대시보드 → SQL Editor 에 통째로 붙여넣고 한 번 실행. 재실행해도 안전.
-- 설계: docs/design_guild.md §2 · 규칙 packages/core_run/lib/src/guild_mission.dart
-- ────────────────────────────────────────────────────────────────
-- 목적: 미션·도움·수령 기록은 **서버가 소유**한다. RLS 를 켜고 정책을 만들지 않는다 = 앱은
--       읽기·쓰기 모두 불가(권위 서버 service_role 만). 판정은 끝난 뒤 첫 조회 때 서버가 한다(cron 없음).
--       보상은 우편이 아니라 **미션 화면의 "보상 받기"**(2026-10-01 사장님 확정) — 수령 기록
--       (`guild_mission_claims` 기본키)이 두 번 받기를 막는다(`mail_claims` 와 같은 구조).
-- 작성: 2026-10-01
-- 위험: 없음(새 테이블·새 함수만). `guilds.exp`·`guild_members.coins/contribution` 을 더하는 함수가 생긴다.
-- 되돌리기: 맨 아래 ROLLBACK 절. 서버를 먼저 이전 리비전으로(안 돌리면 /guild/mission* 만 503).
-- 순서: ⚠️ `_sql_20261001_guild_base.sql` **다음**, **서버 재배포보다 먼저**.

begin;

-- ① 미션 ─────────────────────────────────────────────────────────
create table if not exists guild_missions (
  id          uuid        primary key default gen_random_uuid(),
  guild_id    uuid        references guilds(id) on delete set null,  -- 길드가 없어져도 보상은 남는다
  owner       uuid        not null references auth.users(id) on delete cascade,
  owner_nick  text        not null default '',
  day_key     text        not null,               -- 하루(KST 09시 경계) — 하루 출발 3회를 센다
  slot        int         not null,
  kind        text        not null default '',
  mult        double precision not null,          -- 요구 전투력 배율 = 보상 배율
  wait_sec    int         not null,
  need_power  double precision not null,          -- 출발자 전투력 × 배율
  owner_power double precision not null,
  owner_stage int         not null default 1,     -- 보상 규모(자기 사냥터)
  helper_max  int         not null default 3,     -- 도움 인원 상한(JSON 값을 행에 적는다 — 트리거가 본다)
  started_at  timestamptz not null default now(),
  ends_at     timestamptz not null,
  settled     boolean     not null default false,
  ratio       double precision not null default 0,
  success     boolean     not null default false,
  solo        boolean     not null default false  -- 혼자 바로 성공(대기 배율 없음)
);
create index if not exists guild_missions_guild_idx on guild_missions (guild_id, started_at desc);
create index if not exists guild_missions_owner_idx on guild_missions (owner, started_at desc);

-- ② 도움 — 한 미션에 한 사람 한 번(기본키) ────────────────────────────
create table if not exists guild_mission_helpers (
  mission_id uuid        not null references guild_missions(id) on delete cascade,
  user_id    uuid        not null references auth.users(id) on delete cascade,
  nickname   text        not null default '',
  power      double precision not null,            -- 요구치의 60% 로 자른 몫
  stage      int         not null default 1,       -- 돕는 사람 보상은 **자기** 사냥터 기준
  day_key    text        not null,
  rewarded   boolean     not null default false,   -- 하루 도움 보상 5회 안이었나
  created_at timestamptz not null default now(),
  primary key (mission_id, user_id)
);
create index if not exists guild_mission_helpers_user_idx on guild_mission_helpers (user_id, created_at desc);

-- 도움 인원 상한 — 동시에 두 명이 마지막 자리를 누르는 경우를 미션 행을 잠가 한 줄로 세운다.
create or replace function public.guild_mission_helper_cap()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  cap int;
  n   int;
begin
  select helper_max into cap from guild_missions where id = new.mission_id for update;
  if cap is null then raise exception 'mission_not_found'; end if;
  select count(*) into n from guild_mission_helpers where mission_id = new.mission_id;
  if n >= cap then raise exception 'helpers_full'; end if;
  return new;
end;
$$;
drop trigger if exists guild_mission_helper_cap_trg on guild_mission_helpers;
create trigger guild_mission_helper_cap_trg
  before insert on guild_mission_helpers
  for each row execute function public.guild_mission_helper_cap();

-- ③ 보상 수령 기록(1회성) ───────────────────────────────────────────
create table if not exists guild_mission_claims (
  mission_id uuid        not null references guild_missions(id) on delete cascade,
  user_id    uuid        not null references auth.users(id) on delete cascade,
  claimed_at timestamptz not null default now(),
  primary key (mission_id, user_id)
);
create index if not exists guild_mission_claims_user_idx on guild_mission_claims (user_id, claimed_at desc);

alter table guild_missions        enable row level security;
alter table guild_mission_helpers enable row level security;
alter table guild_mission_claims  enable row level security;
-- ⚠️ 정책 없음 = 서버 전용.

-- ④ 원자적 더하기(서버 전용) — 읽고-더하고-쓰기를 REST 로 두 번 하면 동시에 받을 때 값이 먹힌다.
create or replace function guild_add_coins(p_user uuid, p_coins int)
returns void language sql security definer set search_path = public as $$
  update guild_members
     set coins = coins + greatest(0, p_coins),
         contribution = contribution + greatest(0, p_coins)
   where user_id = p_user;
$$;

create or replace function guild_add_exp(p_guild uuid, p_exp int)
returns void language sql security definer set search_path = public as $$
  update guilds set exp = exp + greatest(0, p_exp) where id = p_guild;
$$;

revoke execute on function guild_add_coins(uuid, int) from public, anon, authenticated;
revoke execute on function guild_add_exp(uuid, int) from public, anon, authenticated;

commit;

-- ────────────────────────────────────────────────────────────────
-- 확인 — `ok` 가 전부 true 여야 한다.
-- ────────────────────────────────────────────────────────────────
select '① 테이블 3개' as check, (select count(*) from information_schema.tables
         where table_name in ('guild_missions','guild_mission_helpers','guild_mission_claims')) = 3 as ok
union all
select '② 도움 인원 트리거', exists(select 1 from pg_trigger where tgname = 'guild_mission_helper_cap_trg')
union all
select '③ RLS 켜짐(정책 없음)', (select bool_and(relrowsecurity) from pg_class
         where relname in ('guild_missions','guild_mission_helpers','guild_mission_claims'))
  and not exists(select 1 from pg_policies
         where tablename in ('guild_missions','guild_mission_helpers','guild_mission_claims'));

-- ────────────────────────────────────────────────────────────────
-- ROLLBACK (서버를 먼저 이전 리비전으로)
-- ────────────────────────────────────────────────────────────────
-- begin;
--   drop function if exists guild_add_exp(uuid, int);
--   drop function if exists guild_add_coins(uuid, int);
--   drop table if exists guild_mission_claims;
--   drop table if exists guild_mission_helpers;   -- 트리거도 함께
--   drop function if exists public.guild_mission_helper_cap();
--   drop table if exists guild_missions;
-- commit;
