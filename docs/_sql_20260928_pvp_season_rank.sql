-- 목적: 결투 시즌 순위 보상(1위 100 · 2위 50 · 3위 30 · 4~10위 10젤리)의 근거가 되는
--       **서버 전용** 시즌 트로피 기록. profiles.trophies 는 앱이 직접 쓰는 칸이라
--       보상 근거로 쓸 수 없다(누구나 99999 를 적을 수 있다).
-- 작성: 2026-09-28
-- 위험: 없음(새 테이블·새 함수만. 기존 객체를 바꾸지 않는다)
-- 되돌리기: 아래 ROLLBACK 절. ⚠️ 서버가 이 함수들을 부르므로, 되돌리기 전에
--           서버를 이전 리비전으로 돌린다(안 돌리면 기록·조회가 실패 로그만 남기고
--           보상이 나가지 않는다 — 결투·업로드 자체는 막히지 않는다).
-- 순서: ⚠️ **서버 재배포보다 먼저** 돌린다.

begin;

create table if not exists pvp_season_scores (
  season_id  text        not null,                 -- '2026-09-28' (시즌 시작 KST 날짜)
  user_id    uuid        not null references auth.users(id) on delete cascade,
  nickname   text        not null default '',
  trophies   int         not null default 0,
  updated_at timestamptz not null default now(),  -- 트로피가 **바뀐** 시각(동률 판정)
  primary key (season_id, user_id)
);

-- 동률은 **먼저 도달한 쪽이 위**다 — 정렬 인덱스도 그 순서로.
create index if not exists pvp_season_scores_rank_idx
  on pvp_season_scores (season_id, trophies desc, updated_at asc);

alter table pvp_season_scores enable row level security;
-- ⚠️ 정책을 만들지 않는다 = 클라이언트는 읽기·쓰기 모두 불가(service_role 은 RLS 우회).

-- 점수 기록: **서버만** 부른다. 대회(event_submit)와 달리 최고 기록이 아니라
-- **지금 트로피**로 덮는다(시즌 순위 = 끝나는 순간의 트로피).
-- updated_at 은 값이 바뀔 때만 올린다 — 같은 트로피로 다시 기록돼도 먼저 도달한
-- 순서가 뒤집히지 않게.
create or replace function pvp_season_submit(
  p_season text, p_user uuid, p_nick text, p_trophies int
) returns void
language sql security definer set search_path = public as $$
  insert into pvp_season_scores (season_id, user_id, nickname, trophies, updated_at)
  values (p_season, p_user, p_nick, p_trophies, now())
  on conflict (season_id, user_id) do update set
    nickname   = excluded.nickname,
    updated_at = case when pvp_season_scores.trophies = excluded.trophies
                      then pvp_season_scores.updated_at else now() end,
    trophies   = excluded.trophies;
$$;

-- 한 사람의 순위 — 서버가 시즌이 끝난 뒤 보상을 판정할 때 부른다.
-- 트로피 0 은 순위에 넣지 않는다(한 판 지고 끝난 사람이 인원이 적은 주에 순위권에
-- 드는 것을 막는다 — 서버도 0 이면 주지 않는다).
create or replace function pvp_season_rank_of(p_season text, p_user uuid)
returns table(rank bigint, trophies int, total bigint)
language sql stable security definer set search_path = public as $$
  select r.rank, r.trophies,
         (select count(*) from pvp_season_scores
           where season_id = p_season and trophies > 0) as total
  from (
    select user_id, trophies,
           row_number() over (order by trophies desc, updated_at asc) as rank
    from pvp_season_scores where season_id = p_season and trophies > 0
  ) r
  where r.user_id = p_user;
$$;

-- 운영용 상위 N 명(누가 받았나 확인).
create or replace function pvp_season_top(p_season text, lim int default 10)
returns table(rank bigint, user_id uuid, nickname text, trophies int, updated_at timestamptz)
language sql stable security definer set search_path = public as $$
  select row_number() over (order by trophies desc, updated_at asc) as rank,
         user_id, nickname, trophies, updated_at
  from pvp_season_scores where season_id = p_season and trophies > 0
  order by trophies desc, updated_at asc
  limit lim;
$$;

revoke execute on function pvp_season_submit(text, uuid, text, int) from public, anon, authenticated;
revoke execute on function pvp_season_rank_of(text, uuid) from public, anon, authenticated;
revoke execute on function pvp_season_top(text, int) from public, anon, authenticated;

commit;

-- 확인(적용 후):
--   select * from pvp_season_top('2026-09-28', 10);   -- 이번 시즌 상위 10

-- ROLLBACK (적용 후 문제가 생기면 — 서버를 먼저 이전 리비전으로)
-- begin;
--   drop function if exists pvp_season_top(text, int);
--   drop function if exists pvp_season_rank_of(text, uuid);
--   drop function if exists pvp_season_submit(text, uuid, text, int);
--   drop table if exists pvp_season_scores;
-- commit;
