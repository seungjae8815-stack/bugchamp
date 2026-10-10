-- 목적: 개발자·운영 계정을 랭킹에서 뺀다(2026-10-05 사장님 — 개발자 계정 "오리"가 스테이지 이동으로 생긴
--       기록 그대로 진행도 랭킹에 떠 있다). profiles.rank_hidden 칸 + 랭킹 함수 3개가 그 계정을 건너뛴다.
--       · leaderboard_top(심연·레벨·진행도 탭) · abyss_top(심연 주간 순위표) · abyss_rank_of(심연 주간 보상 판정)
--       숨긴 계정은 순위 번호도 차지하지 않는다(뒤 사람이 한 칸씩 올라간다) — 보상 판정도 같다.
-- 작성: 2026-10-05
-- 위험: leaderboard_top·abyss_top·abyss_rank_of 를 다시 만든다(반환 형식은 그대로 — create or replace).
--       결투 리그 순위(pvp_season_scores)는 건드리지 않는다.
-- 되돌리기: update profiles set rank_hidden = false where ...; (함수는 그대로 둬도 결과가 같다)
-- ✅ 이미 적용됨(2026-10-10 확인 — profiles.rank_hidden 칸 있음). 그 뒤 프로필 그림 SQL(_sql_20261010_avatar.sql)이 두 함수를
--    rank_hidden 조건 그대로 두고 avatar 반환을 더해 다시 만든다. 이 파일을 다시 돌릴 일이 있으면 avatar 포함판(지금 내용)으로 —
--    옛 판(avatar 없음)으로 돌리면 create or replace 가 반환 형식이 달라 실패한다.

-- ① 먼저 대상 확인 — 1줄이어야 한다(닉네임이 겹치면 id 로 고른다).
select id, nickname, tier, stage, level, abyss_best from profiles where nickname = '오리';

begin;

alter table profiles add column if not exists rank_hidden boolean not null default false;

create or replace function leaderboard_top(lim int, sort text default 'trophies')
returns table(rank bigint, id uuid, nickname text,
              trophies int, level int, stage int, tier int, badge text,
              power double precision, abyss_best int, avatar text)
language sql stable security definer set search_path = public as $$
  with ranked as (
    select p.id, p.nickname, p.trophies, p.level, p.stage, p.tier,
           coalesce(p.badge, '') as badge, p.power, p.abyss_best, p.avatar,
           row_number() over (
             order by
               case sort
                 when 'level' then p.tier
                 when 'stage' then p.tier
                 else p.trophies
               end desc,
               case sort
                 when 'level' then p.level
                 when 'stage' then (greatest(p.stage, 1) - 1) / 100
                 else 0
               end desc,
               case sort when 'stage' then p.abyss_best else 0 end desc,
               case sort when 'stage' then p.power else 0 end desc,
               case sort when 'stage' then p.stage else 0 end desc,
               p.id
           ) as rank
    from profiles p
    where not p.rank_hidden          -- 2026-10-05 개발자·운영 계정 제외
  )
  select r.rank, r.id, r.nickname, r.trophies, r.level, r.stage, r.tier,
         r.badge, r.power, r.abyss_best, r.avatar
  from ranked r
  order by r.rank
  limit lim;
$$;

create or replace function abyss_rank_of(p_week text, p_user uuid)
returns table(rank bigint, floor int, boss_pm int, total bigint)
language sql stable security definer set search_path = public as $$
  select r.rank, r.floor, r.boss_pm,
         (select count(*) from abyss_weekly_scores s2
           where s2.week_id = p_week and s2.floor > 1
             and not exists (select 1 from profiles h where h.id = s2.user_id and h.rank_hidden)) as total
  from (
    select s.user_id, s.floor, s.boss_pm,
           row_number() over (order by s.floor desc, s.boss_pm desc, s.updated_at asc) as rank
    from abyss_weekly_scores s
    where s.week_id = p_week and s.floor > 1
      and not exists (select 1 from profiles h where h.id = s.user_id and h.rank_hidden)
  ) r
  where r.user_id = p_user;
$$;

create or replace function abyss_top(p_week text, lim int default 100)
returns table(rank bigint, user_id uuid, nickname text, floor int, boss_pm int,
              updated_at timestamptz, power double precision, badge text, sp text, avatar text)
language sql stable security definer set search_path = public as $$
  select row_number() over (order by s.floor desc, s.boss_pm desc, s.updated_at asc) as rank,
         s.user_id, coalesce(nullif(p.nickname, ''), s.nickname), s.floor, s.boss_pm, s.updated_at,
         coalesce(p.power, 0)::double precision, coalesce(p.badge, ''),
         coalesce(d.team -> 0 ->> 'sp', ''),
         p.avatar
  from abyss_weekly_scores s
  left join profiles p on p.id = s.user_id
  left join defenders d on d.id = s.user_id
  where s.week_id = p_week and s.floor > 1
    and not coalesce(p.rank_hidden, false)
  order by s.floor desc, s.boss_pm desc, s.updated_at asc
  limit lim;
$$;

revoke execute on function abyss_rank_of(text, uuid) from public, anon, authenticated;
revoke execute on function abyss_top(text, int) from public, anon, authenticated;

-- ② 개발자 계정 숨기기 — ①에서 1줄이었을 때만.
update profiles set rank_hidden = true where nickname = '오리';

commit;

-- 확인: 숨긴 계정 목록 · 진행도 상위 5명에 '오리'가 없어야 한다.
select id, nickname from profiles where rank_hidden;
select rank, nickname, tier, stage from leaderboard_top(5, 'stage');
