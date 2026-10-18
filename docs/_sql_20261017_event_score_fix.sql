-- 목적: 왕충 선발대회 2회차(round_id 2026-1005) 운영 보정 — "세계최고채집가" 기록을 84웨이브 · 84,405점으로 맞춘다.
--       사장님 지시(2026-10-17). 근거 자료는 운영 기록에 따로 보관할 것. (이전 보정: _sql_20261013_event_score_fix.sql — 76웨이브 · 76,080)
-- 작성: 2026-10-17
-- 위험: 실물 경품 순위표의 점수가 바뀐다. 회차가 끝나면(10-19 00:00 KST) 이 순위로 뱃지·보상이 확정된다.
--       이후 그 유저가 더 높은 점수를 내면 event_submit 이 greatest 로 덮는다(더 낮은 판은 무시).
--       세이브의 eventBestScore·eventBestWave 는 고치지 않는다(이전 보정과 같음 — 순위·보상은 event_scores 기준).
-- 원래 값: ① 결과를 여기 적어 둘 것 → score ______ · wave ____ · updated_at ______________________
-- 되돌리기(① 에서 적은 값으로):
--   update event_scores set score = <원래 score>, wave = <원래 wave>, updated_at = '<원래 updated_at>'
--   where round_id = '2026-1005' and user_id = '2f6929fb-ce53-4f91-be69-f453d4fc3672';

-- ① 대상 확인 — 반드시 1줄, 닉네임이 세계최고채집가인지 본다. (값을 위 "원래 값"에 적는다)
select e.user_id, p.nickname, e.score, e.wave, e.tries, e.updated_at
from event_scores e join profiles p on p.id = e.user_id
where e.round_id = '2026-1005' and e.user_id = '2f6929fb-ce53-4f91-be69-f453d4fc3672';

-- ② 보정
begin;
update event_scores
set score = 84405,
    wave  = 84,
    updated_at = now()
where round_id = '2026-1005' and user_id = '2f6929fb-ce53-4f91-be69-f453d4fc3672';
commit;

-- ③ 확인 — 순위표 상위 10
select rank, nickname, score, wave from event_top('2026-1005', 10);
