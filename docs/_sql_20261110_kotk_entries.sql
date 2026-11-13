-- 목적: 왕중왕전(2026-11-10 사장님 확정) 참가 기록 — 주마다 한 사람 곤충 1마리. 서버만 읽고 쓴다(앱은 못 읽고 못 쓴다).
--       대진·결과는 이 표의 스냅샷으로 서버가 늘 같은 결과로 다시 계산한다(결과 표 없음). 명예의 전당도 여기서 만든다.
-- 작성: 2026-11-10
-- 위험: 없음(새 테이블만)
-- 되돌리기: 아래 ROLLBACK 절. 서버를 먼저 이전 리비전으로 돌린다(안 돌리면 왕중왕전 화면이 "연결 안 됨"으로만 보인다).
-- 순서: 서버 재배포보다 먼저 돌린다.

begin;

create table if not exists kotk_entries (
  week_id    text        not null,                 -- 결투 시즌과 같은 주 id('2026-11-09')
  user_id    uuid        not null references auth.users(id) on delete cascade,
  nickname   text        not null default '',
  avatar     text,
  bug_id     text        not null,
  species_id text        not null,
  bug        jsonb       not null,                 -- 참가할 때의 결투 곤충(DuelBug) 스냅샷 — 이걸로 싸운다
  power      double precision not null default 0,  -- 시드 순서(전투력)
  skin       text,                                 -- 그림용(스킨·이색)
  created_at timestamptz not null default now(),
  primary key (week_id, user_id)
);

create index if not exists kotk_entries_week_idx on kotk_entries (week_id, power desc);

alter table kotk_entries enable row level security;
-- ⚠️ 정책을 만들지 않는다 = 클라이언트는 읽기·쓰기 모두 불가(service_role 은 RLS 우회).

commit;

-- 확인(적용 후):
--   select week_id, count(*) from kotk_entries group by 1 order by 1 desc;

-- ROLLBACK
-- begin;
--   drop table if exists kotk_entries;
-- commit;
