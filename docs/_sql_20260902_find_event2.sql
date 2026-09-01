-- 대회 순위 2위의 실제 닉네임·uid 확인 (읽기 전용)
-- 앱은 닉네임이 금칙어/예약어/허용 문자셋 밖이면 "이용자"로 **가려서** 보여준다.
-- 그래서 화면 이름으로는 검색되지 않는다 — 원문은 여기서 본다.
select rank, user_id, nickname, score, wave, updated_at
from (
  select row_number() over (order by score desc, updated_at asc) as rank,
         user_id, nickname, score, wave, updated_at
  from event_scores
  where round_id = (select round_id from event_scores
                    order by updated_at desc limit 1)
) t
order by rank
limit 10;
