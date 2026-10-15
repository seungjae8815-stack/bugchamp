-- 텔레그램 리포트 숫자 점검 (읽기 전용)
-- 지금 리포트 = saves.updated_at(서버 저장 시각) 기준 → 일괄 SQL 등으로 플레이 안 한 계정도 갱신된다.
-- 비교 = 세이브 안의 lastSeen(앱이 플레이할 때 적는 시각, 서버는 /save 업로드 때만 갱신).
-- '진짜 이용자' = 닉네임 있고 레벨 5 이상.

with s as (
  select s.id,
         s.updated_at,
         least((s.data->>'lastSeen')::timestamptz, s.updated_at) as seen,  -- 기기 시계를 앞으로 돌린 값은 저장 시각으로 자름
         p.nickname is not null and coalesce((s.data->>'level')::int, 0) >= 5 as real_user,
         u.created_at
  from saves s
  join auth.users u on u.id = s.id
  left join profiles p on p.id = s.id
)
select '지금 방식(updated_at)'                                   as "기준",
       count(*) filter (where updated_at >= now() - interval '24 hours') as "24시간",
       count(*) filter (where updated_at >= now() - interval '7 days')   as "7일",
       count(*) filter (where updated_at >= now() - interval '30 days')  as "30일",
       count(*) filter (where updated_at >= now() - interval '7 days'
                          and created_at < now() - interval '24 hours')  as "정착"
from s
union all
select '앱 접속 시각(lastSeen)',
       count(*) filter (where seen >= now() - interval '24 hours'),
       count(*) filter (where seen >= now() - interval '7 days'),
       count(*) filter (where seen >= now() - interval '30 days'),
       count(*) filter (where seen >= now() - interval '7 days'
                          and created_at < now() - interval '24 hours')
from s
union all
select '앱 접속 시각 + 진짜 이용자만',
       count(*) filter (where real_user and seen >= now() - interval '24 hours'),
       count(*) filter (where real_user and seen >= now() - interval '7 days'),
       count(*) filter (where real_user and seen >= now() - interval '30 days'),
       count(*) filter (where real_user and seen >= now() - interval '7 days'
                          and created_at < now() - interval '24 hours')
from s;
