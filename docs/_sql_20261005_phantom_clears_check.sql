-- 목적: (조회 전용 — 아무것도 바꾸지 않는다) 최종 보스 직후 난이도 자동 전환 경쟁 버그로
--       "깨지 않은 사냥터가 깬 것으로 기록된" 계정을 찾는다(2026-10-05 발견, 앱 수정은 다음 버전).
--       버그: 다음 난이도로 넘어간 세이브에 옛 스테이지(1001)가 써져, 새 난이도 사냥터 1~10 클리어 기록
--       (clearedChapters 의 'wN@T')과 클리어 골드가 한꺼번에 들어갔다.
-- 판별: 정상 클리어는 advanceZone 이 보스 도감(bossDex)에 그 보스를 반드시 남긴다.
--       클리어 기록은 있는데 도감에 그 보스가 없으면 유령 클리어다.
--       ⚠️ 보스 도감이 생기기 전(2026-09-15 이전)에 깬 기록도 같은 모양이라 소수는 오탐일 수 있다 —
--       유령 개수가 많고(5개↑), 지금 난이도가 그 난이도인 계정이 진짜 피해 계정이다.
-- 작성: 2026-10-05
-- 위험: 없음(select 만)
-- 되돌리기: 해당 없음

with keys as (
  select s.id as user_id,
         k.key,
         split_part(k.key, '@', 2)::int as tier,
         substring(split_part(k.key, '@', 1) from 2)::int as zone
  from public.saves s,
       jsonb_array_elements_text(coalesce(s.data -> 'clearedChapters', '[]'::jsonb)) as k(key)
  where k.key ~ '^w([1-9]|10)@[1-3]$'
),
phantom as (
  select k.user_id, k.tier, count(*) as phantom_zones,
         string_agg(k.key, ',' order by k.zone) as keys
  from keys k
  join public.saves s on s.id = k.user_id
  where not coalesce(s.data -> 'bossDex', '[]'::jsonb)
        ? ((array['e','n','h','x'])[k.tier + 1] || lpad(k.zone::text, 2, '0'))
  group by k.user_id, k.tier
)
select p.user_id,
       pr.nickname,
       p.tier            as 유령_난이도,
       p.phantom_zones   as 유령_사냥터_수,
       p.keys,
       coalesce((s.data ->> 'difficultyTier')::int, 0) as 지금_난이도,
       (s.data ->> 'stageNumber')::int    as 지금_스테이지,
       (s.data ->> 'gold')                as 골드
from phantom p
join public.saves s on s.id = p.user_id
left join public.profiles pr on pr.id = p.user_id
order by p.phantom_zones desc, p.tier desc;
