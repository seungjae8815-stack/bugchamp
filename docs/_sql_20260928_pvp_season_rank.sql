-- 목적: 결투 **리그** 순위(2026-09-29 사장님 확정) — 리그 = 등급 하나(브론즈~다이아). 같은 리그끼리
--       이번 주 승리 점수로 경쟁하고, 주간 결산에서 상위 20% 승급 · 하위 20% 강등, 리그별 1~10위 젤리.
--       상대 후보 = 순위표에서 내 위 3명·아래 2명(pvp_league_range). 월 09시 시작 · 일 09시 마감.
--       **서버 전용** 기록이다. profiles.trophies 는 앱이 직접 쓰는 칸이라 보상 근거로 쓸 수 없다.
-- 작성: 2026-09-28 (2026-09-29 리그 방식으로 개정 — 적용 전이라 파일을 고쳤다)
-- 위험: 없음(새 테이블·새 함수만. 기존 객체를 바꾸지 않는다)
-- 되돌리기: 아래 ROLLBACK 절. ⚠️ 서버를 이전 리비전으로 먼저 돌린다.
-- 순서: ⚠️ **서버 재배포보다 먼저** 돌린다.

begin;

create table if not exists pvp_season_scores (
  season_id  text        not null,                 -- '2026-09-28' (시즌 시작 KST 날짜)
  user_id    uuid        not null references auth.users(id) on delete cascade,
  league     text        not null default 'bronze', -- 그 시즌에 뛴 리그(승강은 서버가 결산 때 세이브에 적는다)
  nickname   text        not null default '',
  trophies   int         not null default 0,
  power      double precision not null default 0,     -- 결투 방어팀 3마리 전투력(서버가 계산) — 순위표 표시용
  sp         text        not null default '',       -- 방어팀 1번 곤충(순위표 그림)
  updated_at timestamptz not null default now(),   -- 트로피가 **바뀐** 시각(동률 판정)
  primary key (season_id, user_id)
);

-- 동률은 **먼저 도달한 쪽이 위**다 — 정렬 인덱스도 그 순서로(리그 안에서).
create index if not exists pvp_season_scores_league_idx
  on pvp_season_scores (season_id, league, trophies desc, updated_at asc);

alter table pvp_season_scores enable row level security;
-- ⚠️ 정책을 만들지 않는다 = 클라이언트는 읽기·쓰기 모두 불가(service_role 은 RLS 우회).

-- 점수 기록: **서버만** 부른다. **지금 트로피**로 덮는다(시즌 순위 = 끝나는 순간의 트로피).
-- updated_at 은 값이 바뀔 때만 올린다 — 같은 트로피로 다시 기록돼도 먼저 도달한 순서가 뒤집히지 않게.
create or replace function pvp_season_submit(
  p_season text, p_user uuid, p_nick text, p_trophies int, p_league text default 'bronze',
  p_power double precision default 0, p_sp text default ''
) returns void
language sql security definer set search_path = public as $$
  insert into pvp_season_scores (season_id, user_id, league, nickname, trophies, power, sp, updated_at)
  values (p_season, p_user, p_league, p_nick, p_trophies, p_power, p_sp, now())
  on conflict (season_id, user_id) do update set
    league     = excluded.league,
    nickname   = excluded.nickname,
    power      = excluded.power,
    sp         = excluded.sp,
    updated_at = case when pvp_season_scores.trophies = excluded.trophies
                      then pvp_season_scores.updated_at else now() end,
    trophies   = excluded.trophies;
$$;

-- 리그 안 한 사람의 순위 + 그 리그 인원 — 결산(서버)과 순위표의 내 줄이 부른다.
-- 트로피 0 도 인원에 넣는다(승강 비율은 뛴 사람 전체 기준). 보상·승급은 서버가 트로피 0 을 거른다.
create or replace function pvp_league_rank_of(p_season text, p_league text, p_user uuid)
returns table(rank bigint, trophies int, total bigint)
language sql stable security definer set search_path = public as $$
  select r.rank, r.trophies,
         (select count(*) from pvp_season_scores
           where season_id = p_season and league = p_league) as total
  from (
    select user_id, trophies,
           row_number() over (order by trophies desc, updated_at asc) as rank
    from pvp_season_scores where season_id = p_season and league = p_league
  ) r
  where r.user_id = p_user;
$$;

-- 리그 순위표 상위 N 명 — 닉네임·뱃지(profiles) + **결투 방어팀 전투력·대표 곤충**(점수 기록 때 서버가 적은 값,
-- 없으면 profiles.power·defenders 로 떨어진다). 계정 전투력이 아니라 결투 팀 전투력을 보여 준다(2026-09-29).
create or replace function pvp_league_top(p_season text, p_league text, lim int default 100)
returns table(rank bigint, user_id uuid, nickname text, trophies int,
              power double precision, badge text, sp text)
language sql stable security definer set search_path = public as $$
  select row_number() over (order by s.trophies desc, s.updated_at asc) as rank,
         s.user_id, coalesce(nullif(p.nickname, ''), s.nickname), s.trophies,
         (case when s.power > 0 then s.power else coalesce(p.power, 0) end)::double precision,
         coalesce(p.badge, ''),
         coalesce(nullif(s.sp, ''), d.team -> 0 ->> 'sp', '')
  from pvp_season_scores s
  left join profiles p on p.id = s.user_id
  left join defenders d on d.id = s.user_id
  where s.season_id = p_season and s.league = p_league
  order by s.trophies desc, s.updated_at asc
  limit lim;
$$;

-- 순위 구간 [p_from, p_to] — 상대 후보 5명(내 위 3명·아래 2명)을 뽑을 때 서버가 부른다(2026-09-29).
create or replace function pvp_league_range(p_season text, p_league text, p_from int, p_to int)
returns table(rank bigint, user_id uuid, nickname text, trophies int,
              power double precision, badge text, sp text)
language sql stable security definer set search_path = public as $$
  select * from (
    select row_number() over (order by s.trophies desc, s.updated_at asc) as rank,
           s.user_id, coalesce(nullif(p.nickname, ''), s.nickname), s.trophies,
           (case when s.power > 0 then s.power else coalesce(p.power, 0) end)::double precision,
           coalesce(p.badge, ''),
           coalesce(nullif(s.sp, ''), d.team -> 0 ->> 'sp', '')
    from pvp_season_scores s
    left join profiles p on p.id = s.user_id
    left join defenders d on d.id = s.user_id
    where s.season_id = p_season and s.league = p_league
  ) r
  where r.rank between p_from and p_to
  order by r.rank;
$$;

-- 리그 인원(아직 점수가 없는 사람의 후보 = 맨 아래 5명을 찾을 때).
create or replace function pvp_league_count(p_season text, p_league text)
returns bigint
language sql stable security definer set search_path = public as $$
  select count(*) from pvp_season_scores where season_id = p_season and league = p_league;
$$;

-- 그 시즌에 **어느 리그에서** 뛰었나 — 정산 기간 순위표는 결산으로 리그가 바뀐 뒤에도 뛴 리그를 보여 준다.
create or replace function pvp_season_row(p_season text, p_user uuid)
returns table(league text, trophies int)
language sql stable security definer set search_path = public as $$
  select league, trophies from pvp_season_scores where season_id = p_season and user_id = p_user;
$$;

revoke execute on function pvp_season_submit(text, uuid, text, int, text, double precision, text) from public, anon, authenticated;
revoke execute on function pvp_league_range(text, text, int, int) from public, anon, authenticated;
revoke execute on function pvp_league_count(text, text) from public, anon, authenticated;
revoke execute on function pvp_season_row(text, uuid) from public, anon, authenticated;
revoke execute on function pvp_league_rank_of(text, text, uuid) from public, anon, authenticated;
revoke execute on function pvp_league_top(text, text, int) from public, anon, authenticated;

commit;

-- 확인(적용 후):
--   select * from pvp_league_top('2026-10-05', 'diamond', 10);

-- ROLLBACK (서버를 먼저 이전 리비전으로)
-- begin;
--   drop function if exists pvp_season_row(text, uuid);
--   drop function if exists pvp_league_count(text, text);
--   drop function if exists pvp_league_range(text, text, int, int);
--   drop function if exists pvp_league_top(text, text, int);
--   drop function if exists pvp_league_rank_of(text, text, uuid);
--   drop function if exists pvp_season_submit(text, uuid, text, int, text, double precision, text);
--   drop table if exists pvp_season_scores;
-- commit;
