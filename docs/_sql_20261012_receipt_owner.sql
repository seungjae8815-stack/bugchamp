-- 2026-10-12 결제 이상 알림 확인(읽기만) — skin_gold_rhino 영수증의 원래 주인과, 알림에 뜬 새 계정 비교.
-- 같은 구글 계정의 영수증이라 두 계정은 같은 사람일 가능성이 높다(게스트로 하다 앱을 지우고 새 계정).
select
  case when v.user_id = '8463e77e-fe85-42e6-8bad-fb25fe1cb9b6' then '알림 계정' else '영수증 주인' end as "구분",
  v.user_id,
  v.product_id,
  v.environment                    as "결제 환경",
  v.verified_at                    as "결제 확인 시각",
  s.data->>'nickname'              as "닉네임",
  s.updated_at                     as "마지막 저장",
  u.is_anonymous                   as "게스트",
  u.created_at                     as "계정 생성"
from verified_purchases v
left join saves s on s.id = v.user_id
left join auth.users u on u.id = v.user_id
where v.product_id = 'skin_gold_rhino'
union all
select '알림 계정', u.id, null, null, null, s.data->>'nickname', s.updated_at, u.is_anonymous, u.created_at
from auth.users u left join saves s on s.id = u.id
where u.id = '8463e77e-fe85-42e6-8bad-fb25fe1cb9b6'
order by "결제 확인 시각" nulls last;
