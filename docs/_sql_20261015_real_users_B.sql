-- B. 주별 가입 추이 (읽기 전용)
-- 테스트 기간(출시 전·업데이트 점검 주)에 익명 계정이 몰렸는지 본다.
-- '진짜 후보' = 닉네임이 있고 레벨 5 이상.

with u as (
  select au.id,
         au.created_at,
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
select date_trunc('week', created_at + interval '9 hours')::date              as "가입 주(월요일, KST)",
       count(*)                                                               as "전체 가입",
       count(*) filter (where not has_nick and lv < 5)                        as "닉네임 없음·레벨 5 미만",
       count(*) filter (where has_nick and lv >= 5)                           as "진짜 후보",
       count(*) filter (where not anon)                                       as "구글 연결",
       count(pay.user_id)                                                     as "결제자"
from u
left join pay on pay.user_id = u.id
group by 1
order by 1;
