-- ────────────────────────────────────────────────────────────────
-- Supabase 용량 점검 — "지금도 초과 상태인가"를 가른다.
--
-- 배경: 2026-07 에 채집함 상한이 없던 시절 곤충 3만 마리 = 세이브 13.6MB 가
-- 쌓여 업로드마다 DB 타임아웃·요금 폭증을 일으켰다(CLAUDE.md §2.1).
-- 트래픽(egress)은 주기마다 리셋되지만 **DB 용량은 리셋되지 않는다** —
-- 그때 부푼 행이 남아 있으면 지금도 초과 상태다.
-- ────────────────────────────────────────────────────────────────

-- ① 전체 DB 크기 (무료 한도와 비교할 값)
select pg_size_pretty(pg_database_size(current_database())) as db_total;

-- ② 어느 테이블이 먹고 있나 (큰 순)
-- ⚠️ `relname` 은 pg_class 와 pg_stat_user_tables 양쪽에 있다 — 반드시 c. 를 붙인다.
select c.relname as table_name,
       pg_size_pretty(pg_total_relation_size(c.oid)) as total,
       pg_size_pretty(pg_relation_size(c.oid))       as data_only,
       s.n_live_tup as rows
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
left join pg_stat_user_tables s on s.relid = c.oid
where n.nspname = 'public' and c.relkind = 'r'
order by pg_total_relation_size(c.oid) desc;

-- ③ ⭐ 비대한 세이브 찾기 — 여기가 사고 지점이다.
--    곤충 수와 JSON 크기를 같이 본다.
select id,
       pg_size_pretty(length(data::text)::bigint) as save_size,
       jsonb_array_length(coalesce(data->'bugs', '[]'::jsonb)) as bugs,
       updated_at
from saves
order by length(data::text) desc
limit 20;

-- ④ 세이브 총량 · 평균 · 최대
select count(*) as saves,
       pg_size_pretty(sum(length(data::text))::bigint) as total,
       pg_size_pretty(avg(length(data::text))::bigint) as avg,
       pg_size_pretty(max(length(data::text))::bigint) as max
from saves;

-- ⑤ 죽은 행(dead tuple) — 지웠는데 공간이 안 돌아온 경우.
--    많으면 `vacuum full saves;` 로 회수한다(잠깐 테이블이 잠긴다).
select relname, n_live_tup as live, n_dead_tup as dead,
       last_vacuum, last_autovacuum
from pg_stat_user_tables
where schemaname = 'public'
order by n_dead_tup desc;

-- ────────────────────────────────────────────────────────────────
-- 판단
--  · ③ 에 bugs 가 수천~수만인 행이 있다 → 그게 원인. 앱·서버가 이미 상한
--    (기본 50 · 최대 100칸)을 강제하므로, 그 계정이 한 번 접속하면 정리된다.
--    접속하지 않는 유령 계정이면 아래로 직접 자른다.
--  · ⑤ 의 dead 가 크다 → 이미 지웠는데 공간만 안 돌아온 것. vacuum 으로 해결.
--  · 둘 다 아니고 DB 가 작다 → **초과는 대역폭이었고 이미 리셋됐다. 결제 불필요.**
-- ────────────────────────────────────────────────────────────────

-- (필요할 때만) 유령 계정의 곤충 배열만 잘라낸다. ⚠️ 되돌릴 수 없다.
-- 실행 전에 반드시 ③ 으로 대상 id 를 눈으로 확인할 것.
--
-- update saves
-- set data = jsonb_set(data, '{bugs}',
--       (select jsonb_agg(b) from (
--          select b from jsonb_array_elements(data->'bugs') b limit 100
--        ) t))
-- where id = '여기에-대상-uuid';
