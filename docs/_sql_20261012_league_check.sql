-- 2026-10-12 리그 결산 확인(읽기만) — 지난 시즌(10/5~10/11) 리그별 인원과, 각자 지금 세이브의 리그·결산 기록.
-- pvpLeague: 0 브론즈 · 1 실버 · 2 골드 · 3 플래티넘 · 4 다이아 (-1 = 옛 세이브)
-- pvpRankRewardSeason = '2026-10-05' 이면 옛 서버가 이미 결산을 끝낸 사람이다.
select
  p.league                                   as "지난주 리그",
  count(*) over (partition by p.league)      as "그 리그 인원",
  p.nickname                                 as "닉네임",
  p.trophies                                 as "점수",
  (s.data->>'pvpLeague')::int                as "지금 리그(0~4)",
  s.data->>'pvpRankRewardSeason'             as "결산 기록",
  p.user_id
from pvp_season_scores p
left join saves s on s.id = p.user_id
where p.season_id = '2026-10-05'
order by p.league, p.trophies desc;
