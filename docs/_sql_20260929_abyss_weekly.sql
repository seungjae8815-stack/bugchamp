-- 목적: 심연(극한 이후 무한 층) 주간 최고 층 순위 — 1위 100 · 2위 50 · 3위 30 · 4~10위 10젤리.
--       서버가 업로드마다 층 증가 상한을 건 뒤의 값만 기록한다(앱은 이 테이블을 못 읽고 못 쓴다).
-- 작성: 2026-09-29
-- 위험: 없음(새 테이블·새 함수만)
-- 되돌리기: 아래 ROLLBACK 절. 서버를 이전 리비전으로 먼저 돌린다(안 돌리면 기록·조회가
--           실패 로그만 남기고 보상이 안 나간다 — 업로드 자체는 막히지 않는다).
-- 순서: ⚠️ **서버 재배포보다 먼저** 돌린다. `_sql_20260928_pvp_season_rank.sql` 과 함께.

begin;

create table if not exists abyss_weekly_scores (
  week_id    text        not null,                 -- '2026-09-28' (주 시작 KST 날짜 = 결투 시즌과 같은 경계)
  user_id    uuid        not null references auth.users(id) on delete cascade,
  nickname   text        not null default '',
  floor      int         not null default 1,       -- 그 주에 닿은 최고 층
  updated_at timestamptz not null default now(),   -- 그 층에 **처음** 닿은 시각(동률 판정)
  primary key (week_id, user_id)
);

create index if not exists abyss_weekly_scores_rank_idx
  on abyss_weekly_scores (week_id, floor desc, updated_at asc);

alter table abyss_weekly_scores enable row level security;
-- ⚠️ 정책을 만들지 않는다 = 클라이언트는 읽기·쓰기 모두 불가(service_role 은 RLS 우회).

-- 기록: **서버만** 부른다. 층은 **오를 때만** 갱신한다(한 주 안에서 층은 줄지 않는다 —
-- 1층으로 돌아가는 건 주가 바뀔 때뿐이고, 그땐 다른 week_id 행이다).
create or replace function abyss_submit(
  p_week text, p_user uuid, p_nick text, p_floor int
) returns void
language sql security definer set search_path = public as $$
  insert into abyss_weekly_scores (week_id, user_id, nickname, floor, updated_at)
  values (p_week, p_user, p_nick, p_floor, now())
  on conflict (week_id, user_id) do update set
    nickname   = excluded.nickname,
    updated_at = case when excluded.floor > abyss_weekly_scores.floor
                      then now() else abyss_weekly_scores.updated_at end,
    floor      = greatest(abyss_weekly_scores.floor, excluded.floor);
$$;

-- 한 사람의 순위 — 주가 끝난 뒤 서버가 보상을 판정할 때. 1층(아무것도 못 깸)은 순위에 넣지 않는다.
create or replace function abyss_rank_of(p_week text, p_user uuid)
returns table(rank bigint, floor int, total bigint)
language sql stable security definer set search_path = public as $$
  select r.rank, r.floor,
         (select count(*) from abyss_weekly_scores
           where week_id = p_week and floor > 1) as total
  from (
    select user_id, floor,
           row_number() over (order by floor desc, updated_at asc) as rank
    from abyss_weekly_scores where week_id = p_week and floor > 1
  ) r
  where r.user_id = p_user;
$$;

-- 운영용 상위 N 명.
create or replace function abyss_top(p_week text, lim int default 10)
returns table(rank bigint, user_id uuid, nickname text, floor int, updated_at timestamptz)
language sql stable security definer set search_path = public as $$
  select row_number() over (order by floor desc, updated_at asc) as rank,
         user_id, nickname, floor, updated_at
  from abyss_weekly_scores where week_id = p_week and floor > 1
  order by floor desc, updated_at asc
  limit lim;
$$;

revoke execute on function abyss_submit(text, uuid, text, int) from public, anon, authenticated;
revoke execute on function abyss_rank_of(text, uuid) from public, anon, authenticated;
revoke execute on function abyss_top(text, int) from public, anon, authenticated;

commit;

-- 확인(적용 후):
--   select * from abyss_top('2026-10-05', 10);   -- 그 주 상위 10

-- ROLLBACK (서버를 먼저 이전 리비전으로)
-- begin;
--   drop function if exists abyss_top(text, int);
--   drop function if exists abyss_rank_of(text, uuid);
--   drop function if exists abyss_submit(text, uuid, text, int);
--   drop table if exists abyss_weekly_scores;
-- commit;
