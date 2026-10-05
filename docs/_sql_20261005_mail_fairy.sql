-- 목적: 운영 우편으로 (1) 골드·재료를 1조 이상, (2) 요정 재료(가루·속성석·가속기)를 보낼 수 있게 한다.
--       · 골드·키틴·미네랄·수액 칸 integer(최대 약 21억) → bigint. 100억 우편이 22003 으로 실패했다.
--       · user_mail.fairy jsonb 칸 추가 — {"dust":N,"stones":{"attack":n},"accelerators":{"acc2h":n}}.
--       _sql_20261005_mail_gold_bigint.sql 을 포함한다(이미 돌렸어도 다시 돌려도 된다 — bigint → bigint 는 그대로).
-- 작성: 2026-10-05
-- 위험: 두 표를 다시 쓰는 동안 짧은 잠금(행이 적어 수 초 안). 값은 그대로 보존된다.
--       ⚠️ **서버 재배포보다 먼저** — 새 서버는 우편을 읽을 때 `fairy` 칸을 고른다. 칸이 없으면 모든 유저의 우편함이 400.
-- 되돌리기: 아래 ROLLBACK 절(21억을 넘는 값이 이미 있으면 integer 되돌리기는 실패한다).

begin;

alter table public.user_mail
  alter column gold    type bigint,
  alter column chitin  type bigint,
  alter column mineral type bigint,
  alter column sap     type bigint;

alter table public.gift_codes
  alter column gold    type bigint,
  alter column chitin  type bigint,
  alter column mineral type bigint,
  alter column sap     type bigint;

alter table public.user_mail add column if not exists fairy jsonb;

commit;

-- 확인: gold·chitin·mineral·sap 8줄이 bigint, fairy 1줄이 jsonb
select table_name, column_name, data_type
from information_schema.columns
where table_schema = 'public'
  and table_name in ('user_mail', 'gift_codes')
  and column_name in ('gold', 'chitin', 'mineral', 'sap', 'fairy')
order by table_name, column_name;

-- ROLLBACK (서버를 이전 리비전으로 먼저 되돌린 뒤에)
-- begin;
--   alter table public.user_mail drop column if exists fairy;
--   alter table public.user_mail  alter column gold type integer, alter column chitin type integer,
--                                 alter column mineral type integer, alter column sap type integer;
--   alter table public.gift_codes alter column gold type integer, alter column chitin type integer,
--                                 alter column mineral type integer, alter column sap type integer;
-- commit;
