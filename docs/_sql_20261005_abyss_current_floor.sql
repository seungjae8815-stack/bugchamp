-- 목적: 심연 주간 순위를 **지금 층** 기준으로 — 쓰러져 층이 내려가면 기록도 내려간다
--       (2026-10-05 사장님 확정 "쓰러지면 한 칸 아래로", core_save/zone_fall.dart).
--       예전 abyss_submit 은 floor = greatest(기존, 새 값)이라 한 주 안에서 층이 줄지 않았다.
-- 작성: 2026-10-05
-- 위험: 없음(함수 본문만 교체 — 테이블·인덱스·권한 그대로). 데이터를 바꾸지 않는다.
--       이미 쌓인 이번 주 기록은 그 사람이 다음에 층이 바뀔 때 지금 층으로 덮인다.
-- 되돌리기: 아래 ROLLBACK 절(예전 본문 = _sql_20260929_abyss_weekly.sql 그대로).
-- 순서: 서버와 무관하게 언제 돌려도 된다.
--       · 이 SQL 만 먼저 → 옛 서버는 층이 오를 때만 부르므로 동작이 그대로다.
--       · 서버(1.0.17)만 먼저 → 내려간 층을 보내도 greatest 라 무시된다(순위가 안 내려갈 뿐, 오류 없음).

begin;

-- 기록: **서버만** 부른다. 층은 **보낸 값 그대로**(내려가도 덮는다).
--  - 층이 바뀌면(오르든 내리든) 그 층의 보스 피해로 새로 시작하고, 시각을 지금으로 — 동률이면 그 층에
--    **먼저 닿은** 사람이 위다. 내려갔다 다시 오른 사람은 다시 닿은 시각으로 선다.
--  - 같은 층이면 보스 피해가 더 클 때만 올리고 그때 시각을 지금으로(예전과 같다).
create or replace function abyss_submit(
  p_week text, p_user uuid, p_nick text, p_floor int, p_boss int default 0
) returns void
language sql security definer set search_path = public as $$
  insert into abyss_weekly_scores (week_id, user_id, nickname, floor, boss_pm, updated_at)
  values (p_week, p_user, p_nick, p_floor, greatest(0, least(999, p_boss)), now())
  on conflict (week_id, user_id) do update set
    nickname   = excluded.nickname,
    updated_at = case
      when excluded.floor <> abyss_weekly_scores.floor then now()
      when excluded.boss_pm > abyss_weekly_scores.boss_pm then now()
      else abyss_weekly_scores.updated_at end,
    boss_pm = case
      when excluded.floor <> abyss_weekly_scores.floor then excluded.boss_pm
      else greatest(abyss_weekly_scores.boss_pm, excluded.boss_pm) end,
    floor      = excluded.floor;
$$;

-- create or replace 는 권한을 유지하지만, 혹시 몰라 예전과 같이 다시 막는다(서버 service_role 만).
revoke execute on function abyss_submit(text, uuid, text, int, int) from public, anon, authenticated;

commit;

-- 확인(적용 후): 본문에 greatest(abyss_weekly_scores.floor 가 없어야 한다 → 0
--   select count(*) from pg_proc
--    where proname = 'abyss_submit'
--      and prosrc like '%greatest(abyss_weekly_scores.floor%';

-- ROLLBACK (적용 후 문제가 생기면 이걸 돌린다 — 예전 "오를 때만" 본문)
-- begin;
-- create or replace function abyss_submit(
--   p_week text, p_user uuid, p_nick text, p_floor int, p_boss int default 0
-- ) returns void
-- language sql security definer set search_path = public as $$
--   insert into abyss_weekly_scores (week_id, user_id, nickname, floor, boss_pm, updated_at)
--   values (p_week, p_user, p_nick, p_floor, greatest(0, least(999, p_boss)), now())
--   on conflict (week_id, user_id) do update set
--     nickname   = excluded.nickname,
--     updated_at = case
--       when excluded.floor > abyss_weekly_scores.floor then now()
--       when excluded.floor = abyss_weekly_scores.floor
--            and excluded.boss_pm > abyss_weekly_scores.boss_pm then now()
--       else abyss_weekly_scores.updated_at end,
--     boss_pm = case
--       when excluded.floor > abyss_weekly_scores.floor then excluded.boss_pm
--       when excluded.floor = abyss_weekly_scores.floor
--         then greatest(abyss_weekly_scores.boss_pm, excluded.boss_pm)
--       else abyss_weekly_scores.boss_pm end,
--     floor      = greatest(abyss_weekly_scores.floor, excluded.floor);
-- $$;
-- revoke execute on function abyss_submit(text, uuid, text, int, int) from public, anon, authenticated;
-- commit;
