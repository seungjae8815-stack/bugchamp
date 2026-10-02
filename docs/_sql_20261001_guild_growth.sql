-- ────────────────────────────────────────────────────────────────
-- Bug Champ — 2026-10-01 길드 3단계: 레벨·버프 스킬 · 출석 · 코인 상점
-- Supabase 대시보드 → SQL Editor 에 통째로 붙여넣고 한 번 실행. 재실행해도 안전.
-- 설계: docs/design_guild.md §5·§6 · 규칙 packages/core_run/lib/src/guild_progress.dart
-- ────────────────────────────────────────────────────────────────
-- 목적: 출석 기록(`guild_members.donate_day`) · 상점 구매 기록(`guild_shop_buys`) · 원자적 출석/구매 함수.
--       `guild_get`·`guild_list` 가 경험치·스킬·티어를 함께 돌려주도록 다시 만든다(반환 모양이 바뀌어 drop 후 create).
--       레벨·인원(`level`·`max_members`)은 서버가 경험치로 계산해 고쳐 적는다(곡선은 JSON).
-- 작성: 2026-10-01
-- 위험: `guild_get`·`guild_list` 를 **drop 후 다시 만든다** — 실행 순간 잠깐 없다(한 트랜잭션 안이라 밖에서는 안 보인다).
-- 되돌리기: 맨 아래 ROLLBACK 절. 서버를 먼저 이전 리비전으로.
-- 순서: ⚠️ `_sql_20261001_guild_base.sql` → `_guild_missions.sql` **다음**, **서버 재배포보다 먼저**.

begin;

-- ① 출석 기록 ────────────────────────────────────────────────────
alter table guild_members add column if not exists donate_day text not null default '';

-- 출석 — 그날 처음이면 코인·기여도를 더하고 true. 조건부 update 한 줄이라 두 번 눌러도 한 번만 된다.
create or replace function guild_donate(p_user uuid, p_day text, p_coins int)
returns boolean language plpgsql security definer set search_path = public as $$
declare
  n int;
begin
  update guild_members
     set donate_day = p_day,
         coins = coins + greatest(0, p_coins),
         contribution = contribution + greatest(0, p_coins)
   where user_id = p_user and donate_day <> p_day;
  get diagnostics n = row_count;
  return n > 0;
end;
$$;

-- ② 상점 구매 기록 — (유저, 품목)당 한 줄, 기간이 바뀌면 0부터 ─────────────
create table if not exists guild_shop_buys (
  user_id    uuid not null references auth.users(id) on delete cascade,
  item       text not null,
  period_key text not null,          -- '2026-10-05'(하루) · 'w2026-10-05'(주)
  n          int  not null default 0,
  primary key (user_id, item)
);
alter table guild_shop_buys enable row level security;   -- 정책 없음 = 서버 전용

-- 구매 — 한도·코인 확인과 차감을 **한 번에**(멤버 행을 잠근다). 'ok' · 'limit' · 'coins'.
create or replace function guild_shop_buy(
  p_user uuid, p_item text, p_period text, p_limit int, p_cost int
) returns text language plpgsql security definer set search_path = public as $$
declare
  have bigint;
  cur  int;
begin
  select coins into have from guild_members where user_id = p_user for update;
  if have is null then return 'coins'; end if;
  select case when period_key = p_period then n else 0 end into cur
    from guild_shop_buys where user_id = p_user and item = p_item for update;
  cur := coalesce(cur, 0);
  if cur >= p_limit then return 'limit'; end if;
  if have < p_cost then return 'coins'; end if;
  update guild_members set coins = coins - p_cost where user_id = p_user;
  insert into guild_shop_buys (user_id, item, period_key, n)
  values (p_user, p_item, p_period, 1)
  on conflict (user_id, item) do update
    set n = case when guild_shop_buys.period_key = excluded.period_key
                 then guild_shop_buys.n + 1 else 1 end,
        period_key = excluded.period_key;
  return 'ok';
end;
$$;

-- ③ 조회 RPC 다시 만들기(경험치·스킬·티어 포함) ─────────────────────────
drop function if exists guild_get(uuid);
create function guild_get(p_guild uuid)
returns table(id uuid, name text, lang text, level int, exp bigint, max_members int,
              join_mode text, notice text, leader uuid, skill_points jsonb,
              tier text, gr int, created_at timestamptz,
              member_count bigint, avg_power double precision)
language sql stable security definer set search_path = public as $$
  select g.id, g.name, g.lang, g.level, g.exp, g.max_members, g.join_mode, g.notice, g.leader,
         g.skill_points, g.tier, g.gr, g.created_at,
         (select count(*) from guild_members m where m.guild_id = g.id),
         coalesce((select avg(coalesce(p.power, 0)) from guild_members m
                     left join profiles p on p.id = m.user_id
                    where m.guild_id = g.id), 0)::double precision
  from guilds g where g.id = p_guild;
$$;

drop function if exists guild_list(uuid, text, text, int);
create function guild_list(p_user uuid, p_lang text, p_query text default '', lim int default 20)
returns table(id uuid, name text, lang text, level int, exp bigint, max_members int,
              join_mode text, notice text, leader uuid, skill_points jsonb,
              tier text, gr int, created_at timestamptz,
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
  select g.id, g.name, g.lang, g.level, g.exp, g.max_members, g.join_mode, g.notice, g.leader,
         g.skill_points, g.tier, g.gr, g.created_at, g.member_count, g.avg_power
  from g, me
  order by (g.lang = p_lang) desc,
           (g.member_count >= g.max_members) asc,
           abs(ln(g.avg_power + 1) - ln(me.pw + 1)) asc,
           g.created_at desc
  limit lim;
$$;

revoke execute on function guild_get(uuid) from public, anon, authenticated;
revoke execute on function guild_list(uuid, text, text, int) from public, anon, authenticated;
revoke execute on function guild_donate(uuid, text, int) from public, anon, authenticated;
revoke execute on function guild_shop_buy(uuid, text, text, int, int) from public, anon, authenticated;

commit;

-- 확인
select '① donate_day' as check, exists(select 1 from information_schema.columns
         where table_name = 'guild_members' and column_name = 'donate_day') as ok
union all
select '② 상점 기록', exists(select 1 from information_schema.tables where table_name = 'guild_shop_buys')
union all
select '③ guild_get 에 exp', exists(select 1 from information_schema.routines r
         join information_schema.parameters p on p.specific_name = r.specific_name
         where r.routine_name = 'guild_get' and p.parameter_name = 'exp');

-- ROLLBACK (서버를 먼저 이전 리비전으로) — guild_get·guild_list 는 _sql_20261001_guild_base.sql 의 정의로 되돌린다.
-- begin;
--   drop function if exists guild_shop_buy(uuid, text, text, int, int);
--   drop table if exists guild_shop_buys;
--   drop function if exists guild_donate(uuid, text, int);
--   alter table guild_members drop column if exists donate_day;
--   -- 그다음 guild_base 의 ⑤ guild_get · guild_list 정의를 drop 후 다시 실행
-- commit;
