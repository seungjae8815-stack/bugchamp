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
  boss_pm    int         not null default 0,       -- 그 층(막힌 층) 보스에게 넣은 최대 피해 천분율(0~999)
  updated_at timestamptz not null default now(),   -- (층, 보스 피해)가 마지막으로 **오른** 시각(동률 판정)
  primary key (week_id, user_id)
);

-- 순위 = 층 → 벽 보스 피해 → 먼저 도달(2026-09-29 사장님 확정). 오래 한 유저는 성장이 상한에 닿아
-- 같은 층에 몰리는데, "먼저 도착"으로만 가르면 월요일 자정에 달려야 이긴다 — 보스 피해가 **전력**으로 가른다.
create index if not exists abyss_weekly_scores_rank_idx
  on abyss_weekly_scores (week_id, floor desc, boss_pm desc, updated_at asc);

alter table abyss_weekly_scores enable row level security;
-- ⚠️ 정책을 만들지 않는다 = 클라이언트는 읽기·쓰기 모두 불가(service_role 은 RLS 우회).

-- 기록: **서버만** 부른다. (층, 보스 피해)가 **오를 때만** 갱신한다 — 층이 오르면 그 층의 보스 피해로
-- 새로 시작하고, 같은 층이면 보스 피해가 더 클 때만. 한 주 안에서 층은 줄지 않는다(1층으로 돌아가는 건
-- 주가 바뀔 때뿐이고, 그땐 다른 week_id 행이다).
create or replace function abyss_submit(
  p_week text, p_user uuid, p_nick text, p_floor int, p_boss int default 0
) returns void
language sql security definer set search_path = public as $$
  insert into abyss_weekly_scores (week_id, user_id, nickname, floor, boss_pm, updated_at)
  values (p_week, p_user, p_nick, p_floor, greatest(0, least(999, p_boss)), now())
  on conflict (week_id, user_id) do update set
    nickname   = excluded.nickname,
    updated_at = case
      when excluded.floor > abyss_weekly_scores.floor then now()
      when excluded.floor = abyss_weekly_scores.floor
           and excluded.boss_pm > abyss_weekly_scores.boss_pm then now()
      else abyss_weekly_scores.updated_at end,
    boss_pm = case
      when excluded.floor > abyss_weekly_scores.floor then excluded.boss_pm
      when excluded.floor = abyss_weekly_scores.floor
        then greatest(abyss_weekly_scores.boss_pm, excluded.boss_pm)
      else abyss_weekly_scores.boss_pm end,
    floor      = greatest(abyss_weekly_scores.floor, excluded.floor);
$$;

-- 한 사람의 순위 — 주가 끝난 뒤 서버가 보상을 판정할 때. 1층(아무것도 못 깸)은 순위에 넣지 않는다.
create or replace function abyss_rank_of(p_week text, p_user uuid)
returns table(rank bigint, floor int, boss_pm int, total bigint)
language sql stable security definer set search_path = public as $$
  select r.rank, r.floor, r.boss_pm,
         (select count(*) from abyss_weekly_scores
           where week_id = p_week and floor > 1) as total
  from (
    select user_id, floor, boss_pm,
           row_number() over (order by floor desc, boss_pm desc, updated_at asc) as rank
    from abyss_weekly_scores where week_id = p_week and floor > 1
  ) r
  where r.user_id = p_user;
$$;

-- 운영용 상위 N 명.
create or replace function abyss_top(p_week text, lim int default 10)
returns table(rank bigint, user_id uuid, nickname text, floor int, boss_pm int, updated_at timestamptz)
language sql stable security definer set search_path = public as $$
  select row_number() over (order by floor desc, boss_pm desc, updated_at asc) as rank,
         user_id, nickname, floor, boss_pm, updated_at
  from abyss_weekly_scores where week_id = p_week and floor > 1
  order by floor desc, boss_pm desc, updated_at asc
  limit lim;
$$;

revoke execute on function abyss_submit(text, uuid, text, int, int) from public, anon, authenticated;
revoke execute on function abyss_rank_of(text, uuid) from public, anon, authenticated;
revoke execute on function abyss_top(text, int) from public, anon, authenticated;

commit;

-- 확인(적용 후):
--   select * from abyss_top('2026-10-05', 10);   -- 그 주 상위 10

-- ROLLBACK (서버를 먼저 이전 리비전으로)
-- begin;
--   drop function if exists abyss_top(text, int);
--   drop function if exists abyss_rank_of(text, uuid);
--   drop function if exists abyss_submit(text, uuid, text, int, int);
--   drop table if exists abyss_weekly_scores;
-- commit;
