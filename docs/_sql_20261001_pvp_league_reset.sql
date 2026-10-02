-- ────────────────────────────────────────────────────────────────
-- Bug Champ — 2026-10-01 결투 리그 초기화(1.0.14 출시 직후 1회성)
-- Supabase 대시보드 → SQL Editor. **① 미리보기 → ② 실행** 순서로 나눠 돌린다.
-- ────────────────────────────────────────────────────────────────
-- 목적: 1.0.14 리그(브론즈~다이아)가 옛 세이브의 **이전 트로피로 정해져** 옛 고트로피 유저가 높은
--       리그에 들어가 있고, 이번 주(시즌 2026-09-28) 순위표에 구버전 앱 결투 기록이 섞여 있다.
--       사장님 결정(2026-10-01): **전원 브론즈 + 이번 주 점수 0** — 모두 같은 출발선에서 시작.
-- 바꾸는 것(전부 서버 소유 필드 — 앱이 옛 값을 올려도 서버 값이 이긴다):
--   saves.data.pvpLeague          → 0 (브론즈)
--   saves.data.pvpTrophies        → 0 (이번 주 점수)
--   saves.data.seasonPeakTrophies → 0
--   saves.data.pvpScoreSeason     → 이번 시즌('2026-09-28')이면 지운다(이번 주에 안 뛴 것으로)
--   pvp_season_scores             → 이번 시즌 행 삭제(순위표 비움)
-- 안 바꾸는 것: 지난 시즌 결산 기록(pvpRankRewardSeason), 결투 티켓, 곤충·부상, profiles.
-- 작성: 2026-10-01
-- 위험: 전 유저 세이브를 한 번에 고친다. 그래서 **바꾸기 전 값을 백업 테이블에 먼저 복사**한다
--       (`pvp_reset_backup_20261001`). 되돌리기 = 맨 아래 ROLLBACK 절.
-- 시점: 이번 시즌 마감(일 2026-10-04 09:00 KST) **전**에 돌린다. 마감 뒤면 시즌 id 가 바뀐다.
-- ⚠️ 실행 중 들어온 업로드가 덮을까? — 아니다. 이 필드들은 서버 소유라 업로드가 저장본 값을 유지한다.
--    다만 그 순간 결투를 끝낸 사람의 점수는 다시 생길 수 있다(정상 — 초기화 뒤 결투한 것).

-- ① 미리보기(아무것도 바꾸지 않는다) ─────────────────────────────────
select coalesce(data->>'pvpLeague', '(없음=트로피로 유도)') as league, count(*) as users
  from saves group by 1 order by 1;
select count(*) as this_week_score_rows from pvp_season_scores where season_id = '2026-09-28';

-- ② 실행 ──────────────────────────────────────────────────────────
begin;

create table if not exists pvp_reset_backup_20261001 as
  select id,
         data->'pvpLeague'          as pvp_league,
         data->'pvpTrophies'        as pvp_trophies,
         data->'seasonPeakTrophies' as season_peak,
         data->'pvpScoreSeason'     as score_season,
         now()                      as backed_up_at
    from saves;
alter table pvp_reset_backup_20261001 enable row level security;  -- 정책 없음 = 앱이 못 읽음

create table if not exists pvp_scores_backup_20261001 as
  select * from pvp_season_scores where season_id = '2026-09-28';
alter table pvp_scores_backup_20261001 enable row level security;

update saves
   set data = (
         jsonb_set(jsonb_set(jsonb_set(data,
           '{pvpLeague}', '0'::jsonb),
           '{pvpTrophies}', '0'::jsonb),
           '{seasonPeakTrophies}', '0'::jsonb)
         - case when data->>'pvpScoreSeason' = '2026-09-28' then 'pvpScoreSeason' else '' end
       ),
       updated_at = now();

delete from pvp_season_scores where season_id = '2026-09-28';

commit;

-- 확인 — 전부 브론즈(0) · 이번 주 점수 0 · 순위표 비었는지
select data->>'pvpLeague' as league, count(*) from saves group by 1;
select count(*) as nonzero_trophies from saves where coalesce((data->>'pvpTrophies')::int, 0) <> 0;
select count(*) as this_week_score_rows from pvp_season_scores where season_id = '2026-09-28';

-- ROLLBACK(백업으로 되돌리기 — 문제가 생기면)
-- begin;
--   update saves s set data =
--       case when b.pvp_league   is null then s.data - 'pvpLeague'          else jsonb_set(s.data, '{pvpLeague}', b.pvp_league) end
--     from pvp_reset_backup_20261001 b where b.id = s.id;
--   update saves s set data = jsonb_set(s.data, '{pvpTrophies}', coalesce(b.pvp_trophies, '0'::jsonb))
--     from pvp_reset_backup_20261001 b where b.id = s.id;
--   update saves s set data = jsonb_set(s.data, '{seasonPeakTrophies}', coalesce(b.season_peak, '0'::jsonb))
--     from pvp_reset_backup_20261001 b where b.id = s.id;
--   update saves s set data = jsonb_set(s.data, '{pvpScoreSeason}', b.score_season)
--     from pvp_reset_backup_20261001 b where b.id = s.id and b.score_season is not null;
--   insert into pvp_season_scores select * from pvp_scores_backup_20261001 on conflict do nothing;
-- commit;
-- 백업이 필요 없어지면(다음 시즌 결산 뒤):
--   drop table pvp_reset_backup_20261001; drop table pvp_scores_backup_20261001;
