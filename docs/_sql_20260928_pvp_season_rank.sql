-- 목적: 결투 **리그** 순위(2026-09-29 사장님 확정) — 리그 = 등급 하나(브론즈~다이아). 같은 리그끼리
--       이번 주 트로피로 경쟁하고, 주간 결산에서 상위 20% 승급 · 하위 20% 강등, 리그별 1~10위 젤리.
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
  p_season text, p_user uuid, p_nick text, p_trophies int, p_league text default 'bronze'
) returns void
language sql security definer set search_path = public as $$
  insert into pvp_season_scores (season_id, user_id, league, nickname, trophies, updated_at)
  values (p_season, p_user, p_league, p_nick, p_trophies, now())
  on conflict (season_id, user_id) do update set
    league     = excluded.league,
    nickname   = excluded.nickname,
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

-- 리그 순위표 상위 N 명 — 닉네임·전투력·대표 뱃지(profiles) + 대표 곤충(방어팀 1번, defenders).
create or replace function pvp_league_top(p_season text, p_league text, lim int default 100)
returns table(rank bigint, user_id uuid, nickname text, trophies int,
              power double precision, badge text, sp text)
language sql stable security definer set search_path = public as $$
  select row_number() over (order by s.trophies desc, s.updated_at asc) as rank,
         s.user_id, coalesce(nullif(p.nickname, ''), s.nickname), s.trophies,
         coalesce(p.power, 0)::double precision, coalesce(p.badge, ''),
         coalesce(d.team -> 0 ->> 'sp', '')
  from pvp_season_scores s
  left join profiles p on p.id = s.user_id
  left join defenders d on d.id = s.user_id
  where s.season_id = p_season and s.league = p_league
  order by s.trophies desc, s.updated_at asc
  limit lim;
$$;

revoke execute on function pvp_season_submit(text, uuid, text, int, text) from public, anon, authenticated;
revoke execute on function pvp_league_rank_of(text, text, uuid) from public, anon, authenticated;
revoke execute on function pvp_league_top(text, text, int) from public, anon, authenticated;

commit;

-- 확인(적용 후):
--   select * from pvp_league_top('2026-10-05', 'diamond', 10);

-- ROLLBACK (서버를 먼저 이전 리비전으로)
-- begin;
--   drop function if exists pvp_league_top(text, text, int);
--   drop function if exists pvp_league_rank_of(text, text, uuid);
--   drop function if exists pvp_season_submit(text, uuid, text, int, text);
--   drop table if exists pvp_season_scores;
-- commit;
