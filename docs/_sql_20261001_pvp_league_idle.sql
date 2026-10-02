-- ────────────────────────────────────────────────────────────────
-- Bug Champ — 2026-10-01 결투 상대 후보: 이번 주 아직 안 싸운 같은 리그 사람
-- Supabase 대시보드 → SQL Editor 에 통째로 붙여넣고 한 번 실행. 재실행해도 안전.
-- ────────────────────────────────────────────────────────────────
-- 목적: 상대 후보 5칸은 같은 리그 **이번 주 순위표**에서 고른다. 출시 직후·작은 리그는 순위표가 비어
--       전부 야생 팀(1점)이 됐다(사장님 실기 2026-10-01). 순위표가 모자라면 야생 전에 **방어팀은 있는데
--       이번 주 점수가 없는 같은 리그 사람**을 넣는다. 점수는 서버가 전투력 비율로 정한다
--       (battle.json → match.idleSteps).
-- 작성: 2026-10-01
-- 위험: 없음(새 함수 하나, 읽기 전용). 이 함수가 없으면 서버는 예전처럼 야생으로 채운다(404 를 빈 목록으로 본다).
-- 리그 = saves.data.pvpLeague(서버 소유, 0 = 브론즈). 키가 없는 옛 세이브는 브론즈로 본다.
-- 되돌리기: drop function if exists pvp_league_idle(text, int, uuid, int);

create or replace function pvp_league_idle(p_season text, p_league int, p_user uuid, lim int default 10)
returns table(user_id uuid, nickname text)
language sql stable security definer set search_path = public as $$
  select d.id, coalesce(p.nickname, '')
  from defenders d
  join saves s on s.id = d.id
  left join profiles p on p.id = d.id
  where d.id <> p_user
    and coalesce((s.data->>'pvpLeague')::int, 0) = p_league
    and not exists (select 1 from pvp_season_scores x
                     where x.season_id = p_season and x.user_id = d.id)
  order by random()
  limit lim;
$$;

revoke execute on function pvp_league_idle(text, int, uuid, int) from public, anon, authenticated;

-- 확인: select * from pvp_league_idle('2026-09-28', 0, '00000000-0000-0000-0000-000000000000', 5);
