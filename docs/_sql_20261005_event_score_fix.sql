-- 목적: 왕충 선발대회 2회차(round_id 2026-1005) 운영 보정 — "세계최고채집가" 기록을 73웨이브로 맞춘다.
--       사장님 확인(2026-10-05): 유저 측 근거 있음. 근거 자료는 운영 기록에 따로 보관할 것.
--       점수 = 웨이브 × 1,000 + 동점 가르기 잔돈(0~999) → 73웨이브 = 73,500(잔돈 중간값).
-- 작성: 2026-10-05
-- 위험: 실물 경품 순위가 바뀐다. 회차가 끝나면(10-19 00:00 KST) 이 순위로 뱃지·보상이 확정된다.
--       이후 그 유저가 더 높은 점수를 내면 event_submit 이 greatest 로 덮는다(더 낮은 판은 무시).
-- 되돌리기: ①의 결과(원래 score·wave·updated_at)를 적어 두었다가 같은 update 로 되돌린다.

-- ① 대상 확인 — 반드시 1줄. 원래 값을 적어 둔다.
select e.user_id, e.nickname, e.score, e.wave, e.tries, e.updated_at
from event_scores e
where e.round_id = '2026-1005' and e.nickname = '세계최고채집가';

-- (①이 0줄이면: 2회차에 아직 한 판도 안 뛴 것 — 프로필 id 를 확인해 알려 주면 insert 로 바꾼다)
-- select id, nickname from profiles where nickname = '세계최고채집가';

-- ② 보정 — ①이 1줄일 때만.
begin;

update event_scores
set score = 73500,
    wave  = 73,
    updated_at = now()
where round_id = '2026-1005' and nickname = '세계최고채집가';

commit;

-- ③ 확인 — 순위표 상위 10
select rank, nickname, score, wave from event_top('2026-1005', 10);
