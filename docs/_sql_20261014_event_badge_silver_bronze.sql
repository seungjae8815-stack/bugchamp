-- 1회차 왕충 선발대회 2위·3위 뱃지를 입상 → 은·동으로 (2026-10-14 사장님 확정: 1위 금 · 2위 은 · 3위 동 · 4~10위 입상 · 나머지 참가)
--
-- ⚠️ 1.0.21 서버를 배포한 **뒤에** 돌린다. 1.0.20 서버·앱은 silver/bronze 를 몰라서
--    대표 뱃지가 비거나(서버) 뱃지가 안 보인다(앱).
-- 대상(2026-10-14 조회, event_scores round 2026-0901 · 점수 → 먼저 달성 순):
--   2위 397e2be2-b6b0-4ea2-b81b-4fa51731fc73 → silver:1
--   3위 17e3d543-a240-4e18-8930-bd663205d7d7 → bronze:1
-- 2회차(2026-1005)는 회차가 끝난 뒤 각자 접속할 때 새 서버가 새 규칙으로 준다 — 이 SQL 대상 아님.
-- eventBadges 는 서버 소유 필드라 기기 업로드가 되돌리지 못한다.

begin;

update saves
set data = jsonb_set(
  data, '{eventBadges}',
  (select jsonb_agg(case when v = 'finalist:1' then 'silver:1' else v end)
     from jsonb_array_elements_text(data->'eventBadges') v))
where id = '397e2be2-b6b0-4ea2-b81b-4fa51731fc73'
  and data->'eventBadges' ? 'finalist:1';

update saves
set data = jsonb_set(
  data, '{eventBadges}',
  (select jsonb_agg(case when v = 'finalist:1' then 'bronze:1' else v end)
     from jsonb_array_elements_text(data->'eventBadges') v))
where id = '17e3d543-a240-4e18-8930-bd663205d7d7'
  and data->'eventBadges' ? 'finalist:1';

-- 대표 뱃지(순위표·채팅) = 급(champion 5 > silver 4 > bronze 3 > finalist 2 > participant 1) → 최근 회차.
-- ⚠️ 2회차 보상이 이 SQL 보다 먼저 나가면 profiles.badge 가 이미 'finalist:2' 일 수 있다(2026-10-14 점검) —
--    그래서 '지금 값이 새 뱃지보다 급이 낮으면' 덮는다. champion:N 이면 그대로 두고, bronze:2 는 bronze:1 과 같은 급이라 최근 회차 유지.
update profiles set badge = 'silver:1'
where id = '397e2be2-b6b0-4ea2-b81b-4fa51731fc73'
  and (badge is null or badge = '' or badge like 'finalist:%' or badge like 'bronze:%' or badge like 'participant:%');
update profiles set badge = 'bronze:1'
where id = '17e3d543-a240-4e18-8930-bd663205d7d7'
  and (badge is null or badge = '' or badge like 'finalist:%' or badge like 'participant:%');

-- 확인
select s.id, s.data->'eventBadges' as badges, p.badge
from saves s join profiles p on p.id = s.id
where s.id in ('397e2be2-b6b0-4ea2-b81b-4fa51731fc73', '17e3d543-a240-4e18-8930-bd663205d7d7');

commit;
