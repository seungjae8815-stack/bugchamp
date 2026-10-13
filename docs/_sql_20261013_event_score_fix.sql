-- 목적: 왕충 선발대회 2회차(round_id 2026-1005) 운영 보정 — "세계최고채집가" 기록을 76웨이브 · 76,080점으로 맞춘다.
--       사장님 지시(2026-10-13). 근거 자료는 운영 기록에 따로 보관할 것. (이전 보정: _sql_20261005_event_score_fix.sql)
--       보정 뒤에도 순위는 2위 그대로(1위 헤라헤라 76,153).
-- 작성: 2026-10-13
-- 위험: 실물 경품 순위표의 점수가 바뀐다. 회차가 끝나면(10-19 00:00 KST) 이 순위로 뱃지·보상이 확정된다.
--       이후 그 유저가 더 높은 점수를 내면 event_submit 이 greatest 로 덮는다(더 낮은 판은 무시).
-- 원래 값(2026-10-13 조회): score 74522 · wave 74 · tries 1 · updated_at 2026-10-05 12:56:41.099286+00
-- 되돌리기:
--   update event_scores set score = 74522, wave = 74, updated_at = '2026-10-05 12:56:41.099286+00'
--   where round_id = '2026-1005' and user_id = '2f6929fb-ce53-4f91-be69-f453d4fc3672';

-- ① 대상 확인 — 반드시 1줄.
select e.user_id, p.nickname, e.score, e.wave, e.tries, e.updated_at
from event_scores e join profiles p on p.id = e.user_id
where e.round_id = '2026-1005' and e.user_id = '2f6929fb-ce53-4f91-be69-f453d4fc3672';

-- ② 보정
update event_scores
set score = 76080,
    wave  = 76,
    updated_at = now()
where round_id = '2026-1005' and user_id = '2f6929fb-ce53-4f91-be69-f453d4fc3672';

-- ③ 확인 — 순위표 상위 10
select rank, nickname, score, wave from event_top('2026-1005', 10);
