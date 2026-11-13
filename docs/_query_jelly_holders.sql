-- 젤리 보유자 목록 (2026-11-12) — 읽기 전용 조회. 데이터를 바꾸지 않는다.
-- Supabase → SQL Editor 에 붙여 넣고 실행한다. 1) 요약 · 2) 목록 두 결과가 나온다(하나씩 선택해 실행해도 된다).
-- 젤리 = 서버 저장본 세이브의 materials.jelly (앱이 60초마다 올린 값 — 기기에 아직 안 올라온 몫은 없다).

-- 1) 요약: 보유자 수 · 합계 · 구간별 인원
with j as (
  select s.id,
         coalesce((s.data->'materials'->>'jelly')::bigint, 0) as jelly
  from public.saves s
)
select
  count(*) filter (where jelly > 0)                       as holders,
  sum(jelly)                                              as total_jelly,
  round(avg(jelly) filter (where jelly > 0))              as avg_of_holders,
  percentile_cont(0.5) within group (order by jelly) filter (where jelly > 0) as median_of_holders,
  count(*) filter (where jelly between 1 and 99)          as "1~99",
  count(*) filter (where jelly between 100 and 499)       as "100~499",
  count(*) filter (where jelly between 500 and 1999)      as "500~1999",
  count(*) filter (where jelly >= 2000)                   as "2000+"
from j;

-- 2) 목록: 젤리 많은 순 (상위 200명)
select
  s.id                                                   as user_id,
  coalesce(p.nickname, s.data->>'nickname')              as nickname,
  coalesce((s.data->'materials'->>'jelly')::bigint, 0)   as jelly,
  (s.data->>'level')::int                                as level,
  (s.data->>'maxTierReached')::int                       as top_tier,     -- 0 쉬움 · 1 보통 · 2 어려움 · 3 극한
  (select count(*) from jsonb_array_elements_text(coalesce(s.data->'redeemedPurchases', '[]'::jsonb)) r
    where r not like 'admin:%')                          as purchases,    -- 결제 영수증 수(0 = 무과금, 운영 지급 제외)
  s.data->>'lastSeen'                                    as last_seen,
  s.updated_at
from public.saves s
left join public.profiles p on p.id = s.id
where coalesce((s.data->'materials'->>'jelly')::bigint, 0) > 0
order by jelly desc
limit 200;
