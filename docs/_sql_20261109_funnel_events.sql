-- 목적: 신규 유저 이정표 기록(1.0.28) — 어디서 떠나는지를 시각과 함께 남긴다. 2026-11-09 이탈 조사를
--       세이브 상태로 거꾸로 추정해야 했다(언제 닿았는지 몰랐다). 앱 `domain/funnel_log.dart` 가 이정표마다
--       처음 닿은 순간 한 줄을 넣는다. 계정당 이정표 하나에 한 줄(기본키), 시각은 서버가 찍는다.
-- 작성: 2026-11-09
-- 위험: 없음 — 새 테이블만 만든다(기존 테이블·데이터 변경 없음). 이 SQL 전에 1.0.28 이 풀리면 앱의 기록만
--       조용히 실패한다(게임 영향 없음, 다음 저장 때 다시 보낸다).
-- 쓰기: 로그인 사용자가 **자기 줄만** 넣는다(RLS). 읽기·고치기·지우기는 앱에 없다 — 조회는 SQL 편집기(관리자)만.
-- 이름 목록: 앱 `kFunnelEvents` 와 같아야 한다(없는 이름은 아래 check 가 거절한다).
-- 되돌리기: 아래 ROLLBACK 절.

begin;

create table if not exists public.funnel_events (
  user_id uuid not null default auth.uid()
    references auth.users(id) on delete cascade,
  event text not null check (event in (
    'zone2', 'zone3', 'zone5', 'easy_clear',
    'egg', 'hatch', 'pet', 'daily', 'level10', 'duel_win'
  )),
  at timestamptz not null default now(),
  primary key (user_id, event)
);

-- 정책을 먼저 만들고 RLS 를 켠다(순서를 바꾸면 그 순간부터 아무도 못 넣는다).
drop policy if exists funnel_events_insert_own on public.funnel_events;
create policy funnel_events_insert_own on public.funnel_events
  for insert to authenticated
  with check (user_id = auth.uid());
alter table public.funnel_events enable row level security;

revoke all on public.funnel_events from anon, authenticated;
grant insert (user_id, event) on public.funnel_events to authenticated;

commit;

-- 조회 예시(설치 뒤 이정표까지 걸린 시간 · 1.0.28 이후 가입자만 — 그 전 계정은 기준선이라 줄이 없다):
-- select e.event,
--        count(*) as 인원,
--        round((percentile_cont(0.5) within group (order by extract(epoch from e.at - u.created_at) / 60))::numeric, 1) as 중앙_분
-- from public.funnel_events e
-- join auth.users u on u.id = e.user_id
-- where u.created_at >= '2026-11-20'   -- ← 1.0.28 출시일로 바꾼다
-- group by e.event
-- order by 3;

-- ROLLBACK
-- begin;
--   drop table if exists public.funnel_events;
-- commit;
