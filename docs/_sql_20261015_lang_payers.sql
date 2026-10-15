-- 언어권별 이용자·잔존·결제자 비율 (읽기 전용 — 아무것도 바꾸지 않는다)
-- Supabase 대시보드 → SQL Editor 에 통째로 붙여 넣고 Run.
--
-- ⚠️ DB 에 나라 정보가 없어서 **닉네임 글자**로 언어권을 추정한다.
--    가나(ぁ・ァ)가 있으면 일본어 → 한글이 있으면 한국어 → 한자만 있으면 중·일 → 영문.
--    한국인이 영문 닉네임을 쓰는 경우가 있어 '영문'에는 한국인이 섞여 있다.
-- 매출은 원화 정가 × 건수 추정(스토어 수수료·세금·환율 전). 테스트 결제는 뺐다.

with u as (
  select au.id,
         au.created_at,
         coalesce(s.updated_at, au.created_at) as last_seen,
         case
           when p.nickname ~ '[ぁ-んァ-ヶ]' then '일본어(가나)'
           when p.nickname ~ '[가-힣ㄱ-ㅎㅏ-ㅣ]' then '한국어'
           when p.nickname ~ '[一-龥]' then '한자만(중·일)'
           when p.nickname ~ '[A-Za-z]' then '영문'
           when p.nickname is null then '닉네임 없음'
           else '기타'
         end as grp
  from auth.users au
  left join profiles p on p.id = au.id
  left join saves s on s.id = au.id
),
pay as (
  select user_id,
         count(*) as n,
         sum(case product_id
               when 'starter_pack' then 5500   when 'idle_pass' then 9900
               when 'jelly_s' then 1200        when 'jelly_m' then 5500
               when 'jelly_l' then 11000       when 'jelly_xl' then 29000
               when 'jelly_xxl' then 59000     when 'skin_gold_rhino' then 3300
               when 'skin_albino_stag' then 3300 when 'theme_arena' then 2200
               when 'buff_pass' then 6600      when 'fairy_starter' then 4400
               when 'skill_starter' then 4400  when 'growth_pass' then 5500
               when 'weekly_bundle' then 2200  else 0 end) as krw
  from verified_purchases
  where environment = 'production'
  group by user_id
)
select coalesce(u.grp, '★ 전체')                                              as "언어권",
       count(*)                                                                as "가입",
       count(*) filter (where u.last_seen >= u.created_at + interval '1 day')  as "하루 넘게 플레이",
       round(100.0 * count(*) filter (where u.last_seen >= u.created_at + interval '1 day')
             / nullif(count(*) filter (where u.created_at <= now() - interval '1 day'), 0), 1)
                                                                               as "하루 잔존 %",
       round(100.0 * count(*) filter (where u.last_seen >= u.created_at + interval '7 days')
             / nullif(count(*) filter (where u.created_at <= now() - interval '7 days'), 0), 1)
                                                                               as "7일 잔존 %",
       count(*) filter (where u.last_seen >= now() - interval '7 days')        as "최근 7일 활동",
       count(pay.user_id)                                                      as "결제자",
       round(100.0 * count(pay.user_id) / nullif(count(*), 0), 2)              as "결제자 % (가입 기준)",
       round(100.0 * count(pay.user_id)
             / nullif(count(*) filter (where u.last_seen >= u.created_at + interval '1 day'), 0), 2)
                                                                               as "결제자 % (하루 넘게 한 사람 기준)",
       coalesce(sum(pay.n), 0)                                                 as "결제 건수",
       coalesce(sum(pay.krw), 0)                                               as "매출 원(추정)",
       round(coalesce(sum(pay.krw), 0)::numeric / nullif(count(*), 0))         as "가입자 1명당 원",
       round(coalesce(sum(pay.krw), 0)::numeric / nullif(count(pay.user_id), 0)) as "결제자 1명당 원"
from u
left join pay on pay.user_id = u.id
group by grouping sets ((u.grp), ())
order by count(*) desc;
