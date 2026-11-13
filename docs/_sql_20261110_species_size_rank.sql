-- 목적: 종별 최대 크기 순위(2026-11-10 사장님 확정) — 다 키운 뒤에도 같은 종을 계속 잡을 이유.
--       서버가 업로드 때 도감 최고 크기(수컷 기록)가 오른 종만, 종 범위로 자른 값을 기록한다(앱은 못 읽고 못 쓴다).
-- 작성: 2026-11-10
-- 위험: 없음(새 테이블·새 함수만)
-- 되돌리기: 아래 ROLLBACK 절. 서버를 이전 리비전으로 먼저 돌릴 필요는 없다(기록 실패는 로그만 남기고 업로드는 막지 않는다).
-- 순서: 서버 재배포보다 먼저 돌린다(안 돌리면 크기 순위 창이 비어 보인다).

begin;

create table if not exists species_size_records (
  species_id text        not null,
  user_id    uuid        not null references auth.users(id) on delete cascade,
  nickname   text        not null default '',
  size_mm    double precision not null default 0,
  updated_at timestamptz not null default now(),   -- 크기가 마지막으로 **오른** 시각(동률은 먼저 잡은 쪽이 위)
  primary key (species_id, user_id)
);

create index if not exists species_size_records_rank_idx
  on species_size_records (species_id, size_mm desc, updated_at asc);

alter table species_size_records enable row level security;
-- ⚠️ 정책을 만들지 않는다 = 클라이언트는 읽기·쓰기 모두 불가(service_role 은 RLS 우회).

-- 기록: **서버만** 부른다. p_sizes = {"종 id": mm, ...}. 크기는 **오를 때만** 갱신한다.
create or replace function size_submit(p_user uuid, p_nick text, p_sizes jsonb)
returns void
language sql security definer set search_path = public as $$
  insert into species_size_records (species_id, user_id, nickname, size_mm, updated_at)
  select e.key, p_user, p_nick, (e.value)::text::double precision, now()
  from jsonb_each(p_sizes) e
  on conflict (species_id, user_id) do update set
    nickname   = excluded.nickname,
    updated_at = case when excluded.size_mm > species_size_records.size_mm
                      then now() else species_size_records.updated_at end,
    size_mm    = greatest(species_size_records.size_mm, excluded.size_mm);
$$;

-- 종 하나의 상위 N 명 — 닉네임·프로필 그림은 profiles 에서(바꾼 이름이 바로 보이게).
create or replace function size_top(p_species text, lim int default 30)
returns table(rank bigint, user_id uuid, nickname text, size_mm double precision, avatar text)
language sql stable security definer set search_path = public as $$
  select row_number() over (order by s.size_mm desc, s.updated_at asc) as rank,
         s.user_id, coalesce(nullif(p.nickname, ''), s.nickname), s.size_mm, p.avatar
  from species_size_records s
  left join profiles p on p.id = s.user_id
  where s.species_id = p_species and s.size_mm > 0
  order by s.size_mm desc, s.updated_at asc
  limit lim;
$$;

-- 한 사람의 그 종 순위(없으면 빈 결과).
create or replace function size_rank_of(p_species text, p_user uuid)
returns table(rank bigint, size_mm double precision, total bigint)
language sql stable security definer set search_path = public as $$
  select r.rank, r.size_mm,
         (select count(*) from species_size_records
           where species_id = p_species and size_mm > 0) as total
  from (
    select user_id, size_mm,
           row_number() over (order by size_mm desc, updated_at asc) as rank
    from species_size_records where species_id = p_species and size_mm > 0
  ) r
  where r.user_id = p_user;
$$;

revoke execute on function size_submit(uuid, text, jsonb) from public, anon, authenticated;
revoke execute on function size_top(text, int) from public, anon, authenticated;
revoke execute on function size_rank_of(text, uuid) from public, anon, authenticated;

commit;

-- 확인(적용 후):
--   select * from size_top('rhinoceros_beetle', 10);

-- ROLLBACK
-- begin;
--   drop function if exists size_rank_of(text, uuid);
--   drop function if exists size_top(text, int);
--   drop function if exists size_submit(uuid, text, jsonb);
--   drop table if exists species_size_records;
-- commit;
