# SQL 마이그레이션 적용 대장

Supabase 스키마 변경 SQL 의 **적용 여부**를 기록한다.
파일만 있고 적용 기록이 없으면 "이거 돌렸던가?"를 매번 다시 확인해야 한다.

작성 규칙과 안전 수칙은 `.claude/skills/sql-migration/SKILL.md` 를 볼 것.

| 파일 | 목적 | 상태 |
|---|---|---|
| `_sql_20260826_badge.sql` | 뱃지 | 미확인 |
| `_sql_20260831_tier.sql` | 랭킹 회차(tier) 정렬 키 | 미확인 |
| `_sql_20260901_level_tier.sql` | 레벨 랭킹 회차 1차 정렬 | 미확인 |
| `_sql_20260901_wealth_audit.sql` | 재화 감사 | 미확인 |
| `_sql_20260902_find_event2.sql` | 이벤트 조회(일회성) | 미확인 |
| `_sql_gold_overflow.sql` | 골드 오버플로 보정(일회성) | 미확인 |
| `_sql_usage_check.sql` | 사용량 점검(일회성 조회) | 미확인 |
| `_sql_20260915_rank_power.sql` | 진행도 랭킹 동률을 전투력으로(profiles.power + leaderboard_top 재정의) — **새 앱보다 먼저** | 대기 |
| `_sql_20260915_chat_badge.sql` | 채팅 메시지에 대표 대회 뱃지(insert 트리거가 profiles.badge 에서 찍음) | 대기 |

> `미확인` = 이 대장을 만들기(2026-09-08) 전에 있던 파일이라 적용 여부를 알 수 없다.
> 다음에 각 파일을 다룰 때 확인해서 `적용` / `대기` / `폐기` 로 바꾼다.
> 새로 만드는 파일은 처음부터 `대기` 로 적고, 사용자가 돌린 뒤 `적용`으로 바꾼다.
