-- ────────────────────────────────────────────────────────────────
-- 골드 음수(int64 오버플로) 조사 — 2026-08-30
--
-- ⚠️ Dart 의 int 는 64비트라 9223372036854775807 을 넘으면 **음수로 감싼다**.
--    표시(K/M/B/T)와는 무관한 저장값 문제다.
-- 앱 쪽 방어는 382b4fb 로 들어갔다(상한 1e18 + 읽을 때 자르기).
-- 이 SQL 은 **얼마나 퍼졌는지와 어쩌다 그랬는지**를 본다.
-- ────────────────────────────────────────────────────────────────

-- ① 제보된 유저 한 명
select p.nickname,
       (s.data->>'gold')::numeric  as gold,
       (s.data->>'xp')::numeric    as xp,
       (s.data->>'stageNumber')::numeric as stage,
       (s.data->>'level')::numeric as lv,
       jsonb_array_length(coalesce(s.data->'bugs','[]'::jsonb)) as bugs,
       s.updated_at
from profiles p
join saves s on s.id = p.id
where p.nickname = '참나무향알콜';

-- ② 얼마나 퍼졌나 — 음수이거나 상한(1e18)을 넘은 세이브 전부
select p.nickname,
       (s.data->>'gold')::numeric as gold,
       (s.data->>'stageNumber')::numeric as stage,
       s.updated_at
from saves s
left join profiles p on p.id = s.id
where (s.data->>'gold')::numeric < 0
   or (s.data->>'gold')::numeric > 1000000000000000000
order by (s.data->>'gold')::numeric asc;

-- ③ 정상 범위 유저들의 골드 분포 — "자연 누적으로 도달 가능한가"를 본다.
--    최고값이 1e15 언저리면 자연 누적이 아니라 **곱셈 폭주나 조작**이다.
select count(*)                                        as saves,
       max((data->>'gold')::numeric)                    as max_gold,
       percentile_cont(0.99) within group (
         order by (data->>'gold')::numeric)             as p99_gold,
       percentile_cont(0.50) within group (
         order by (data->>'gold')::numeric)             as median_gold
from saves
where (data->>'gold')::numeric between 0 and 1000000000000000000;

-- ────────────────────────────────────────────────────────────────
-- 복구 (원인을 확인한 **뒤에만**). ⚠️ 되돌릴 수 없다.
--
-- 앱이 382b4fb 부터 읽을 때 0 으로 되돌리므로 그 유저는 다음 접속에 0 이 된다.
-- 0 대신 적당한 값을 넣어주고 싶을 때만 아래를 쓴다.
-- 값은 ③ 의 p99 언저리로 — 남들보다 유리해지면 그것대로 문제다.
--
-- update saves
-- set data = jsonb_set(data, '{gold}', to_jsonb(1000000000000::bigint))
-- where id = (select id from profiles where nickname = '참나무향알콜');
-- ────────────────────────────────────────────────────────────────
