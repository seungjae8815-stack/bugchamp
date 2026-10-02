-- ────────────────────────────────────────────────────────────────
-- Bug Champ — 2026-10-01 길드 1단계(기본): 길드·멤버·가입 신청·재가입 제한 + 길드 채팅
-- Supabase 대시보드 → SQL Editor 에 통째로 붙여넣고 한 번 실행. 재실행해도 안전.
-- 설계: docs/design_guild.md §1 · §7.1
-- ────────────────────────────────────────────────────────────────
-- 목적: 길드 상태는 **서버가 소유**한다(세이브에 없음). 새 테이블 4개는 RLS 를 켜고 정책을
--       만들지 않는다 = 앱은 읽기·쓰기 모두 불가, 권위 서버(service_role)만 쓴다
--       (`abyss_weekly_scores` 와 같은 형식). 조회용 RPC 도 서버에게만 연다.
--       길드 채팅은 기존 `chat_messages` 에 `guild_id` 칸을 더해 같은 테이블을 쓴다
--       (null = 전체 채팅). **읽기·쓰기 정책을 "전체 + 내 길드"로 좁힌다** — 안 그러면 누구나
--       REST 로 남의 길드 채팅을 읽는다. Realtime 도 이 정책을 따르므로 채널을 따로 열 필요가 없다.
-- 작성: 2026-10-01
-- 위험: chat_read·chat_insert 정책 **교체**(나머지는 새 테이블·새 함수).
--       전체 채팅(guild_id null)은 예전과 똑같이 누구나 읽고 쓴다 — 구버전 앱 영향 없음.
-- 되돌리기: 맨 아래 ROLLBACK 절. 서버를 먼저 이전 리비전으로 돌린다
--           (안 돌리면 /guild/* 만 503 — 다른 기능은 영향 없음).
-- 순서: ⚠️ **서버 재배포보다 먼저** 돌린다.

begin;

-- ① 길드 ─────────────────────────────────────────────────────────
create table if not exists guilds (
  id           uuid        primary key default gen_random_uuid(),
  name         text        not null check (char_length(name) between 1 and 24),
  lang         text        not null default 'ko',          -- 추천 목록 1차 기준(같은 언어)
  level        int         not null default 1,             -- 3단계(레벨·버프)부터 쓴다
  exp          bigint      not null default 0,
  tier         text        not null default 'bronze',      -- 5단계(길드전 티어)부터 쓴다
  gr           int         not null default 0,
  leader       uuid        references auth.users(id) on delete set null,
  max_members  int         not null default 20,            -- 인원 트리거가 보는 상한(레벨로 늘어난다)
  join_mode    text        not null default 'open' check (join_mode in ('open', 'approval')),
  notice       text        not null default '',
  skill_points jsonb       not null default '{}'::jsonb,
  created_at   timestamptz not null default now()
);
-- 이름은 대소문자를 무시하고 유일하다(`Beetle` 과 `beetle` 은 같은 이름).
create unique index if not exists guilds_name_lower_uq on guilds (lower(name));
create index if not exists guilds_lang_idx on guilds (lang);

-- ② 멤버 — **한 사람 한 길드**를 기본키(user_id)가 보장한다 ─────────
create table if not exists guild_members (
  user_id      uuid        primary key references auth.users(id) on delete cascade,
  guild_id     uuid        not null references guilds(id) on delete cascade,
  role         text        not null default 'member' check (role in ('leader', 'deputy', 'member')),
  joined_at    timestamptz not null default now(),
  last_seen    timestamptz not null default now(),         -- 길드장 자동 위임(7일) 판정
  contribution bigint      not null default 0,             -- 위임 순서·2단계 이후 기여도
  coins        bigint      not null default 0              -- 길드 코인(3단계 상점) — 서버 소유
);
create index if not exists guild_members_guild_idx on guild_members (guild_id);

-- 인원 상한 — 서버가 먼저 세어 봐도 **동시에 들어오는 두 요청**은 못 막는다.
-- 길드 행을 잠그고(for update) 센다 → 같은 길드 가입이 한 줄로 선다.
create or replace function public.guild_member_cap()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  cap int;
  n   int;
begin
  select max_members into cap from guilds where id = new.guild_id for update;
  if cap is null then raise exception 'guild_not_found'; end if;
  select count(*) into n from guild_members where guild_id = new.guild_id;
  if n >= cap then raise exception 'guild_full'; end if;
  return new;
end;
$$;
drop trigger if exists guild_member_cap_trg on guild_members;
create trigger guild_member_cap_trg
  before insert on guild_members
  for each row execute function public.guild_member_cap();

-- ③ 가입 신청(승인제 길드) ──────────────────────────────────────────
create table if not exists guild_requests (
  guild_id   uuid        not null references guilds(id) on delete cascade,
  user_id    uuid        not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (guild_id, user_id)
);
create index if not exists guild_requests_user_idx on guild_requests (user_id);

-- ④ 재가입 제한 — 스스로 나간 시각(추방은 적지 않는다) ───────────────
create table if not exists guild_cooldowns (
  user_id uuid        primary key references auth.users(id) on delete cascade,
  left_at timestamptz not null
);

alter table guilds          enable row level security;
alter table guild_members   enable row level security;
alter table guild_requests  enable row level security;
alter table guild_cooldowns enable row level security;
-- ⚠️ 정책을 만들지 않는다 = 클라이언트는 읽기·쓰기 모두 불가(service_role 은 RLS 우회).

-- ⑤ 조회 RPC(서버 전용) ───────────────────────────────────────────
-- 길드 하나 + 인원·평균 전투력.
create or replace function guild_get(p_guild uuid)
returns table(id uuid, name text, lang text, level int, max_members int, join_mode text,
              notice text, leader uuid, created_at timestamptz,
              member_count bigint, avg_power double precision)
language sql stable security definer set search_path = public as $$
  select g.id, g.name, g.lang, g.level, g.max_members, g.join_mode, g.notice, g.leader,
         g.created_at,
         (select count(*) from guild_members m where m.guild_id = g.id),
         coalesce((select avg(coalesce(p.power, 0)) from guild_members m
                     left join profiles p on p.id = m.user_id
                    where m.guild_id = g.id), 0)::double precision
  from guilds g where g.id = p_guild;
$$;

-- 멤버 목록 — 닉네임·전투력·뱃지는 profiles 에서(없으면 빈 값).
create or replace function guild_member_list(p_guild uuid)
returns table(guild_id uuid, user_id uuid, role text, joined_at timestamptz,
              last_seen timestamptz, contribution bigint,
              nickname text, power double precision, badge text)
language sql stable security definer set search_path = public as $$
  select m.guild_id, m.user_id, m.role, m.joined_at, m.last_seen, m.contribution,
         coalesce(p.nickname, ''), coalesce(p.power, 0)::double precision, coalesce(p.badge, '')
  from guild_members m
  left join profiles p on p.id = m.user_id
  where m.guild_id = p_guild;
$$;

-- 가입 신청 목록(오래된 순).
create or replace function guild_request_list(p_guild uuid)
returns table(guild_id uuid, user_id uuid, created_at timestamptz,
              nickname text, power double precision)
language sql stable security definer set search_path = public as $$
  select r.guild_id, r.user_id, r.created_at,
         coalesce(p.nickname, ''), coalesce(p.power, 0)::double precision
  from guild_requests r
  left join profiles p on p.id = r.user_id
  where r.guild_id = p_guild
  order by r.created_at asc;
$$;

-- 추천·검색 목록 — 같은 언어 → 자리 있음 → 평균 전투력이 내 전투력과 가까운 순(로그 거리).
-- 전투력은 난이도마다 수만 배 차이라 뺄셈 거리로는 늘 최상위·최하위 길드만 뜬다.
create or replace function guild_list(p_user uuid, p_lang text, p_query text default '', lim int default 20)
returns table(id uuid, name text, lang text, level int, max_members int, join_mode text,
              notice text, leader uuid, created_at timestamptz,
              member_count bigint, avg_power double precision)
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
  select g.id, g.name, g.lang, g.level, g.max_members, g.join_mode, g.notice, g.leader,
         g.created_at, g.member_count, g.avg_power
  from g, me
  order by (g.lang = p_lang) desc,
           (g.member_count >= g.max_members) asc,
           abs(ln(g.avg_power + 1) - ln(me.pw + 1)) asc,
           g.created_at desc
  limit lim;
$$;

revoke execute on function guild_get(uuid) from public, anon, authenticated;
revoke execute on function guild_member_list(uuid) from public, anon, authenticated;
revoke execute on function guild_request_list(uuid) from public, anon, authenticated;
revoke execute on function guild_list(uuid, text, text, int) from public, anon, authenticated;

-- ⑥ 길드 채팅 ──────────────────────────────────────────────────────
alter table chat_messages
  add column if not exists guild_id uuid references guilds(id) on delete cascade;
create index if not exists chat_messages_guild_idx
  on chat_messages (guild_id, created_at desc) where guild_id is not null;

-- 내 길드 id(없으면 null). 정책 안에서 `(select my_guild_id())` 로 불러 **쿼리당 한 번**만 계산한다.
-- security definer — guild_members 는 정책이 없어 호출자 권한으로는 못 읽는다.
create or replace function public.my_guild_id()
returns uuid language sql stable security definer set search_path = public as $$
  select guild_id from guild_members where user_id = auth.uid();
$$;
revoke execute on function public.my_guild_id() from public, anon;
grant  execute on function public.my_guild_id() to authenticated;

-- 읽기: 전체 채팅 + 내 길드 채팅. (추방·탈퇴하면 그 순간부터 못 읽는다.)
drop policy if exists chat_read on chat_messages;
create policy chat_read on chat_messages
  for select to authenticated
  using (guild_id is null or guild_id = (select public.my_guild_id()));

-- 쓰기: 본인 명의 + 운영자 표시 금지(기존) + 길드 채팅은 내 길드에만.
drop policy if exists chat_insert on chat_messages;
create policy chat_insert on chat_messages
  for insert to authenticated
  with check (
    auth.uid() = user_id
    and is_admin = false
    and (guild_id is null or guild_id = (select public.my_guild_id()))
  );

commit;

-- ────────────────────────────────────────────────────────────────
-- 확인 — `ok` 가 전부 true 여야 한다.
-- ────────────────────────────────────────────────────────────────
select '① 테이블 4개' as check, (select count(*) from information_schema.tables
         where table_name in ('guilds','guild_members','guild_requests','guild_cooldowns')) = 4 as ok
union all
select '② 인원 트리거', exists(select 1 from pg_trigger where tgname = 'guild_member_cap_trg')
union all
select '③ 채팅 guild_id', exists(select 1 from information_schema.columns
         where table_name = 'chat_messages' and column_name = 'guild_id')
union all
select '④ RLS 켜짐(정책 없음)', (select bool_and(relrowsecurity) from pg_class
         where relname in ('guilds','guild_members','guild_requests','guild_cooldowns'))
  and not exists(select 1 from pg_policies
         where tablename in ('guilds','guild_members','guild_requests','guild_cooldowns'));

-- ────────────────────────────────────────────────────────────────
-- ROLLBACK (서버를 먼저 이전 리비전으로)
-- ────────────────────────────────────────────────────────────────
-- begin;
--   drop policy if exists chat_read on chat_messages;
--   create policy chat_read on chat_messages for select to authenticated using (true);
--   drop policy if exists chat_insert on chat_messages;
--   create policy chat_insert on chat_messages for insert to authenticated
--     with check (auth.uid() = user_id and is_admin = false);
--   drop function if exists public.my_guild_id();
--   alter table chat_messages drop column if exists guild_id;   -- 길드 채팅 기록도 함께 사라진다
--   drop function if exists guild_list(uuid, text, text, int);
--   drop function if exists guild_request_list(uuid);
--   drop function if exists guild_member_list(uuid);
--   drop function if exists guild_get(uuid);
--   drop table if exists guild_cooldowns;
--   drop table if exists guild_requests;
--   drop table if exists guild_members;     -- 트리거도 함께
--   drop function if exists public.guild_member_cap();
--   drop table if exists guilds;
-- commit;
