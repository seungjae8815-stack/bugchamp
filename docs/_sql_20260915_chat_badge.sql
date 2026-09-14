-- ────────────────────────────────────────────────────────────────
-- Bug Champ — 2026-09-15 채팅에 대회 뱃지
-- Supabase 대시보드 → SQL Editor 에 통째로 붙여넣고 한 번 실행.
-- 재실행해도 안전. 원본·설명: docs/backend_supabase.md §8-5
-- ────────────────────────────────────────────────────────────────
-- 목적: 대회 뱃지는 "남이 봐야 자랑거리"인데 순위표에만 실려 있었다. 채팅
--       메시지에 보낸 사람의 **대표 뱃지**를 함께 싣는다.
--       ⚠️ 앱이 뱃지를 보내게 하면 누구나 챔피언을 달고 말할 수 있다
--       (chat_insert 정책은 컬럼을 가리지 못한다). 그래서 **넣는 순간 트리거가
--       profiles.badge 에서 찍는다** — 클라이언트가 무엇을 보내도 덮어쓴다.
--       profiles.badge 는 권위 서버만 쓴다(_sql_20260826_badge.sql ③).
-- 작성: 2026-09-15
-- 위험: 없음(컬럼 추가 + insert 트리거). 구버전 앱은 badge 를 모르고 무시한다.
--       Realtime 게시는 테이블 단위라 새 컬럼이 자동으로 실린다.
-- 되돌리기: 맨 아래 ROLLBACK 절(트리거만 지운다 — 컬럼은 남긴다).

begin;

alter table chat_messages
  add column if not exists badge text not null default '';

create or replace function public.chat_stamp_badge()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- 프로필 행이 없으면(닉네임 미설정 등) 빈 문자열.
  new.badge := coalesce(
    (select p.badge from profiles p where p.id = new.user_id), '');
  return new;
end;
$$;

drop trigger if exists chat_stamp_badge_trg on chat_messages;
create trigger chat_stamp_badge_trg
  before insert on chat_messages
  for each row execute function public.chat_stamp_badge();

commit;

-- ────────────────────────────────────────────────────────────────
-- 확인 — `ok` 가 전부 true 여야 한다.
-- ────────────────────────────────────────────────────────────────
select '① badge 컬럼' as check, exists(
         select 1 from information_schema.columns
         where table_name='chat_messages' and column_name='badge') as ok
union all
select '② 찍는 트리거', exists(
         select 1 from pg_trigger
         where tgname='chat_stamp_badge_trg' and not tgisinternal);

-- ────────────────────────────────────────────────────────────────
-- ROLLBACK (문제가 생기면 이것만 돌린다)
-- ────────────────────────────────────────────────────────────────
-- begin;
-- drop trigger if exists chat_stamp_badge_trg on chat_messages;
-- drop function if exists public.chat_stamp_badge();
-- commit;
