-- ────────────────────────────────────────────────────────────────
-- Bug Champ — 2026-10-03 언어별 공지(영어·일본어 칸)
-- Supabase 대시보드 → SQL Editor 에 통째로 붙여넣고 한 번 실행. 재실행해도 안전.
-- ────────────────────────────────────────────────────────────────
-- 목적: 공지가 한국어 하나만 저장돼 해외 유저도 한국어 글을 봤다. 영어·일본어 제목·본문 칸을 더해
--       앱이 기기 언어의 글을 보여 주게 한다(일본어 없으면 영어 → 한국어 순으로 대체).
-- 작성: 2026-10-03
-- 위험: 없음(비워 둘 수 있는 열 4개 추가). 구버전 앱은 title·body 만 읽으므로 영향 없음.
-- 순서: **서버 재배포보다 먼저**(서버는 새 칸이 없으면 예전 방식으로 물러서지만, 운영 패널의
--       영어·일본어 입력이 저장되지 않는다).
-- 되돌리기: 맨 아래 ROLLBACK 절(새 칸에 쓴 영어·일본어 글은 함께 사라진다).

begin;

alter table notices add column if not exists title_en text;
alter table notices add column if not exists body_en  text;
alter table notices add column if not exists title_ja text;
alter table notices add column if not exists body_ja  text;

commit;

-- 확인 — 4 가 나와야 한다.
select count(*) as lang_columns from information_schema.columns
 where table_name = 'notices' and column_name in ('title_en','body_en','title_ja','body_ja');

-- ROLLBACK
-- begin;
--   alter table notices drop column if exists title_en;
--   alter table notices drop column if exists body_en;
--   alter table notices drop column if exists title_ja;
--   alter table notices drop column if exists body_ja;
-- commit;
