-- A. 계정 종류별 진짜 이용자 가려내기 (읽기 전용)
-- 앱은 켜질 때마다 익명 계정을 만든다 → 재설치·에뮬레이터 테스트마다 가입자 +1.
-- 레벨(세이브 data->>'level')·구글 연결·닉네임으로 나눠서 어디가 테스트 찌꺼기인지 본다.

with u as (
  select au.id,
         au.created_at,
         coalesce(s.updated_at, au.created_at) as last_seen,
         coalesce(au.is_anonymous, false) as anon,
         p.nickname is not null as has_nick,
         coalesce((s.data->>'level')::int, 0) as lv
  from auth.users au
  left join profiles p on p.id = au.id
  left join saves s on s.id = au.id
),
pay as (
  select distinct user_id from verified_purchases where environment = 'production'
)
select case when anon then '익명' else '구글 연결' end                         as "계정",
       case when has_nick then '있음' else '없음' end                          as "닉네임",
       case when lv = 0 then '세이브 없음'
            when lv < 5 then '1~4'
            when lv < 20 then '5~19'
            when lv < 50 then '20~49'
            else '50+' end                                                    as "레벨",
       count(*)                                                               as "계정 수",
       count(*) filter (where last_seen >= created_at + interval '1 day')     as "하루 넘게 플레이",
       count(*) filter (where last_seen >= now() - interval '7 days')         as "최근 7일 활동",
       count(pay.user_id)                                                     as "결제자",
       min(created_at)::date                                                  as "가장 이른 가입",
       max(created_at)::date                                                  as "가장 늦은 가입"
from u
left join pay on pay.user_id = u.id
group by 1, 2, 3
order by 1, 2, 3;
