-- ────────────────────────────────────────────────────────────────
-- Bug Champ — 기존 유저 재화 실태 조사 (2026-09-01)
-- Supabase → SQL Editor. **읽기 전용이다** — 아무것도 바꾸지 않는다.
-- ────────────────────────────────────────────────────────────────
--
-- 왜 먼저 재는가: "재화가 많이 쌓였다"는 체감이지 수치가 아니다.
-- 몇 명이, 얼마나 갖고 있는지 모르면 조정이 아니라 도박이 된다.
-- 특히 **소수의 이상치**(구버전 오버플로·옛 수도꼭지)와 **다수의 정상 축적**은
-- 완전히 다른 문제이고, 다른 처방이 필요하다.

-- ① 분포 — 중앙값·상위 10%·상위 1%·최대
with w as (
  select
    id,
    coalesce((data->>'gold')::numeric, 0)                        as gold,
    coalesce((data->'materials'->>'jelly')::numeric, 0)          as jelly,
    coalesce((data->'materials'->>'chitin')::numeric, 0)
      + coalesce((data->'materials'->>'mineral')::numeric, 0)
      + coalesce((data->'materials'->>'sap')::numeric, 0)        as mats,
    coalesce((data->'materials'->>'fossil')::numeric, 0)         as fossil,
    coalesce((data->>'stageNumber')::int, 1)                     as stage,
    coalesce((data->>'level')::int, 1)                           as lv,
    jsonb_array_length(coalesce(data->'bugs', '[]'::jsonb))      as bugs
  from saves
)
select '골드' as 항목,
       round(percentile_cont(0.5)  within group (order by gold))  as 중앙값,
       round(percentile_cont(0.9)  within group (order by gold))  as "상위10%",
       round(percentile_cont(0.99) within group (order by gold))  as "상위1%",
       round(max(gold))                                          as 최대,
       count(*)                                                  as 인원
from w
union all
select '젤리',
       round(percentile_cont(0.5)  within group (order by jelly)),
       round(percentile_cont(0.9)  within group (order by jelly)),
       round(percentile_cont(0.99) within group (order by jelly)),
       round(max(jelly)), count(*) from w
union all
select '재료(키틴+미네랄+수액)',
       round(percentile_cont(0.5)  within group (order by mats)),
       round(percentile_cont(0.9)  within group (order by mats)),
       round(percentile_cont(0.99) within group (order by mats)),
       round(max(mats)), count(*) from w
union all
select '화석',
       round(percentile_cont(0.5)  within group (order by fossil)),
       round(percentile_cont(0.9)  within group (order by fossil)),
       round(percentile_cont(0.99) within group (order by fossil)),
       round(max(fossil)), count(*) from w;

-- ② 이상치 — 정상 플레이로는 나올 수 없는 값
--
-- 기준의 근거:
--  · 젤리 3000  = ₩59,000 짜리 최대 팩(4200젤리)에 근접. 무과금 수입 24.8/일
--    기준으로 **121일치**다. 결제 이력이 없는데 이 값이면 옛 수도꼭지(하루 193개)
--    시절의 축적이거나 세이브 조작이다.
--  · 골드 1e15  = 후반 유저도 도달하기 어려운 자릿수(2026-08 오버플로 사고 잔재).
select id,
       data->>'nickname'                              as 닉네임,
       (data->>'gold')::numeric                       as 골드,
       (data->'materials'->>'jelly')::numeric         as 젤리,
       jsonb_array_length(coalesce(data->'bugs','[]'::jsonb)) as 곤충,
       (data->>'stageNumber')::int                    as 스테이지,
       (data->>'difficultyTier')::int                 as 회차,
       jsonb_array_length(coalesce(data->'redeemedPurchases','[]'::jsonb)) as 결제건수,
       updated_at
from saves
where coalesce((data->'materials'->>'jelly')::numeric, 0) > 3000
   or coalesce((data->>'gold')::numeric, 0) > 1000000000000000
order by (data->'materials'->>'jelly')::numeric desc nulls last
limit 50;

-- ③ 젤리를 많이 가진 사람이 **결제자인가** — 여기서 처방이 갈린다
--
-- 결제로 산 젤리를 깎으면 그건 환불 사유다. 절대 건드리면 안 된다.
select case when jsonb_array_length(coalesce(data->'redeemedPurchases','[]'::jsonb)) > 0
            then '결제 있음' else '무과금' end as 구분,
       count(*) as 인원,
       round(avg(coalesce((data->'materials'->>'jelly')::numeric,0))) as 평균젤리,
       round(max(coalesce((data->'materials'->>'jelly')::numeric,0))) as 최대젤리
from saves
group by 1;
