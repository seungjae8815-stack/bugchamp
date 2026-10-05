-- 목적: 운영 우편·선물코드 골드 칸을 integer(최대 약 21억) → bigint 로 넓힌다.
--       난이도별 골드가 수조까지 커서 100억 우편이 "out of range for type integer"(22003)로 실패했다(2026-10-05).
--       서버 상한(adminMaxGold)은 1,000조로 이미 올려 배포함(bugchamp-server-00119).
-- 작성: 2026-10-05
-- 위험: 두 표를 다시 쓰는 동안 짧은 잠금(행이 적어 수 초 안). 값은 그대로 보존된다(integer → bigint 는 손실 없음).
--       이 칸을 쓰는 뷰가 있으면 alter 가 실패하고 트랜잭션째 되돌아간다(반쯤 바뀌지 않는다).
-- 되돌리기: 아래 ROLLBACK 절(21억을 넘는 값이 이미 있으면 실패한다 — 그 행을 먼저 처리할 것).

begin;

alter table public.user_mail  alter column gold type bigint;
alter table public.gift_codes alter column gold type bigint;

commit;

-- 확인(둘 다 bigint 여야 한다)
select table_name, column_name, data_type
from information_schema.columns
where table_schema = 'public'
  and table_name in ('user_mail', 'gift_codes')
  and column_name = 'gold';

-- ROLLBACK (적용 후 문제가 생기면 이걸 돌린다)
-- begin;
--   alter table public.user_mail  alter column gold type integer;
--   alter table public.gift_codes alter column gold type integer;
-- commit;
