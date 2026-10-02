-- ────────────────────────────────────────────────────────────────
-- Bug Champ — 2026-10-01 결투 순위표 전투력 = **결투 방어팀 전투력만**
-- Supabase 대시보드 → SQL Editor 에 통째로 붙여넣고 한 번 실행. 재실행해도 안전.
-- ────────────────────────────────────────────────────────────────
-- 목적: 순위표·상대 후보의 전투력이 결투 기록에 없으면(0) **profiles.power(홈 전투력 — 캐릭터 포함)**로
--       떨어져, 결투 팀 1.21k 인 사람이 1.84M 로 보였다(사장님 실기 2026-10-01). 결투 화면에는 결투 팀
--       전투력만 보여야 한다 — 모르면 0(앱은 0 이면 숫자를 숨긴다).
--       또 점수 기록이 전투력 0(방어팀 검증 실패 등)으로 오면 앞서 적힌 값을 0 으로 덮던 것도 막는다.
-- 작성: 2026-10-01
-- 위험: 없음(같은 이름·같은 반환 모양의 함수 3개를 다시 만든다).
-- 되돌리기: `_sql_20260928_pvp_season_rank.sql` 의 세 함수 정의를 다시 실행.

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
    power      = case when excluded.power > 0 then excluded.power else pvp_season_scores.power end,
    sp         = case when excluded.sp <> '' then excluded.sp else pvp_season_scores.sp end,
    updated_at = case when pvp_season_scores.trophies = excluded.trophies
                      then pvp_season_scores.updated_at else now() end,
    trophies   = excluded.trophies;
$$;

create or replace function pvp_league_top(p_season text, p_league text, lim int default 100)
returns table(rank bigint, user_id uuid, nickname text, trophies int,
              power double precision, badge text, sp text)
language sql stable security definer set search_path = public as $$
  select row_number() over (order by s.trophies desc, s.updated_at asc) as rank,
         s.user_id, coalesce(nullif(p.nickname, ''), s.nickname), s.trophies,
         greatest(s.power, 0)::double precision,
         coalesce(p.badge, ''),
         coalesce(nullif(s.sp, ''), d.team -> 0 ->> 'sp', '')
  from pvp_season_scores s
  left join profiles p on p.id = s.user_id
  left join defenders d on d.id = s.user_id
  where s.season_id = p_season and s.league = p_league
  order by s.trophies desc, s.updated_at asc
  limit lim;
$$;

create or replace function pvp_league_range(p_season text, p_league text, p_from int, p_to int)
returns table(rank bigint, user_id uuid, nickname text, trophies int,
              power double precision, badge text, sp text)
language sql stable security definer set search_path = public as $$
  select * from (
    select row_number() over (order by s.trophies desc, s.updated_at asc) as rank,
           s.user_id, coalesce(nullif(p.nickname, ''), s.nickname), s.trophies,
           greatest(s.power, 0)::double precision,
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

revoke execute on function pvp_season_submit(text, uuid, text, int, text, double precision, text) from public, anon, authenticated;
revoke execute on function pvp_league_top(text, text, int) from public, anon, authenticated;
revoke execute on function pvp_league_range(text, text, int, int) from public, anon, authenticated;
