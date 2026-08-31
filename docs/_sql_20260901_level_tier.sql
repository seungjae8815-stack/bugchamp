-- ────────────────────────────────────────────────────────────────
-- Bug Champ — 2026-09-01 **레벨 랭킹도 회차가 먼저**
-- Supabase 대시보드 → SQL Editor 에 통째로 붙여넣고 한 번 실행.
-- 재실행해도 안전(idempotent). 원본·설명: docs/backend_supabase.md
-- ────────────────────────────────────────────────────────────────
--
-- 왜: 회차 전환은 캐릭터 레벨을 1 로 되돌린다(프레스티지).
--  · 현재 레벨만 보면 → 회차를 넘긴 유저가 **꼴찌**가 된다.
--  · 최고 기록으로 보면 → 이번엔 "쉬움에 눌러앉아 레벨만 올리는 것"이 최적이 된다.
-- 진행도 랭킹과 **같은 규칙**(회차가 1차 키)이 둘 다 막는다:
-- 보통 Lv1 > 쉬움 Lv70.

-- ⚠️ 반환 컬럼은 그대로라 drop 없이 replace 가 된다(42P13 은 반환 타입이
--    바뀔 때만 난다). 그래도 시그니처는 (int, text) 로 정확히 맞춘다.
create or replace function leaderboard_top(lim int, sort text default 'trophies')
returns table(rank bigint, id uuid, nickname text,
              trophies int, level int, stage int, tier int, badge text)
language sql stable security definer set search_path = public as $$
  select row_number() over (
           order by case sort
                      -- 레벨·진행도 모두 **회차가 1차 키**다.
                      when 'level' then p.tier
                      when 'stage' then p.tier
                      else p.trophies
                    end desc,
                    -- 2차 키. 트로피 축에서는 1차 키가 이미 갈라 놓아 무해하다.
                    case sort
                      when 'level' then p.level
                      when 'stage' then p.stage
                      else 0
                    end desc
         ) as rank,
         p.id, p.nickname, p.trophies, p.level, p.stage, p.tier,
         coalesce(p.badge, '') as badge
  from profiles p
  order by case sort
             when 'level' then p.tier
             when 'stage' then p.tier
             else p.trophies
           end desc,
           case sort
             when 'level' then p.level
             when 'stage' then p.stage
             else 0
           end desc
  limit lim;
$$;

-- ────────────────────────────────────────────────────────────────
-- 확인 — `ok` 가 전부 true 여야 한다.
-- ────────────────────────────────────────────────────────────────
select '① 순위표가 tier 반환' as check, (
         select count(*) = 1 from pg_proc p
         where p.proname='leaderboard_top'
           and pg_get_function_result(p.oid) like '%tier%') as ok
union all
select '② 레벨 정렬이 tier 를 본다', (
         select count(*) = 1 from pg_proc p
         where p.proname='leaderboard_top'
           and pg_get_functiondef(p.oid) like '%when ''level'' then p.tier%');
