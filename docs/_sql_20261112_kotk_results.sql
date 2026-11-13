-- 왕중왕전 확정 결과(2026-11-12 출시 전 점검) — 서버가 처음 계산한 대진·순위를 적어 두고 그 뒤로는 이것을 읽는다.
-- 예전엔 참가 기록으로 매번 다시 계산해서, 결과가 나온 뒤 결투 수치·엔진을 고쳐 배포하면 대진이 바뀌어
-- 우승자가 둘이 되거나 이미 표본이 된 사람과 어긋날 수 있었다.
-- 서버(service role)만 읽고 쓴다 — 앱(anon·authenticated)은 접근하지 않는다.
-- ⚠️ 서버 배포 전에 적용한다(없어도 서버는 예전처럼 다시 계산만 한다 — 깨지지는 않는다).

create table if not exists public.kotk_results (
  week_id text primary key,
  result jsonb not null,
  created_at timestamptz not null default now()
);

alter table public.kotk_results enable row level security;
revoke all on public.kotk_results from anon, authenticated;

-- 보안 점검 권고(2026-11-12): 정책을 잘못 더해도 앱이 못 열게 앞서 만든 두 표도 권한을 거둔다.
revoke all on public.kotk_entries from anon, authenticated;
revoke all on public.species_size_records from anon, authenticated;
