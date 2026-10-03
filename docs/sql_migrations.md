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
| `_sql_20260915_rank_power.sql` | 진행도 랭킹 동률을 전투력으로(profiles.power + leaderboard_top 재정의) — **새 앱보다 먼저** | 적용(2026-09-15) |
| `_sql_20260915_chat_badge.sql` | 채팅 메시지에 대표 대회 뱃지(insert 트리거가 profiles.badge 에서 찍음) | 적용(2026-09-15) |
| `_sql_20260915_ops_monitor.sql` | 운영 감시 — 리포트 크론 재등록 · `ops_heartbeat` · `ops_settings`(텔레그램 확인 버튼 대기·채팅 요약) · ops-watchdog 10분 크론. ⚠️ **서버 재배포보다 먼저** (없으면 확인 버튼·채팅 요약이 동작하지 않는다) | 적용(2026-09-16) |
| `_sql_20260928_pvp_season_rank.sql` | 결투 **리그** 순위(리그 = 등급, 상위 20% 승급·하위 20% 강등) — 서버 전용 `pvp_season_scores`(league 칸) + `pvp_season_submit`·`pvp_league_rank_of`·`pvp_league_top`·`pvp_league_range`·`pvp_league_count`·`pvp_season_row`(상대 후보·정산 기간 순위표). ⚠️ **서버 재배포보다 먼저** | 적용(2026-10-02 DB 확인 — 표·함수 있음) |
| `_sql_20260929_abyss_weekly.sql` | 심연 주간 최고 층 순위 — 서버 전용 `abyss_weekly_scores` + `abyss_submit`·`abyss_rank_of`·`abyss_top`. ⚠️ **서버 재배포보다 먼저** | 적용(2026-10-02 DB 확인) |
| `_sql_20260929_rank_abyss.sql` | 진행도 랭킹: 극한 최종 사냥터 다음은 **심연 역대 최고 층**(`profiles.abyss_best` — 서버만 씀 · `leaderboard_top` 재정의). 보상 없음(명예용). ⚠️ **서버 재배포보다 먼저** | 적용(2026-10-02 DB 확인 — profiles.abyss_best 있음) |
| `_sql_20261001_guild_base.sql` | 길드 1단계 — 서버 전용 `guilds`·`guild_members`(인원 트리거)·`guild_requests`·`guild_cooldowns` + 조회 RPC 4개 · 채팅 `guild_id` + `chat_read`·`chat_insert` 정책 교체(전체 + 내 길드) · `my_guild_id()`. ⚠️ **서버 재배포보다 먼저** | 적용(2026-10-02) |
| `_sql_20261001_guild_missions.sql` | 길드 2단계 — 서버 전용 `guild_missions`·`guild_mission_helpers`(도움 인원 트리거)·`guild_mission_claims`(1회 수령) + `guild_add_coins`·`guild_add_exp`. ⚠️ `guild_base` **다음**, **서버 재배포보다 먼저** | 적용(2026-10-02) |
| `_sql_20261001_guild_growth.sql` | 길드 3단계 — `guild_members.donate_day` · `guild_donate` · 서버 전용 `guild_shop_buys` + `guild_shop_buy`(코인·한도 원자 처리) · `guild_get`·`guild_list` 재정의(경험치·스킬·티어). ⚠️ `guild_missions` **다음**, **서버 재배포보다 먼저** | 적용(2026-10-02) |
| `_sql_20261001_guild_boss.sql` | 길드 4단계 — 서버 전용 `guild_boss`·`guild_boss_hits`·`guild_boss_claims` + `guild_boss_hit`(보스 행 잠금 · 처치 코인)·`guild_boss_rank`·`guild_boss_top`. ⚠️ `guild_growth` **다음**, **서버 재배포보다 먼저** | 적용(2026-10-02) |
| `_sql_20261001_guild_war.sql` | 길드 5단계 — 서버 전용 `guild_war_scores`·`guild_war_matches`·`guild_war_claims` + `guild_war_set`·`guild_war_add`·`guild_war_totals`·`guild_war_tier_avg`·`guild_war_match`(주별 advisory lock). ⚠️ `guild_boss` **다음**, **서버 재배포보다 먼저** | 적용(2026-10-02) |
| `_sql_20261001_pvp_league_reset.sql` | **1회성** 결투 리그 초기화(1.0.14 출시 직후, 사장님 결정) — 전 세이브 pvpLeague·pvpTrophies·seasonPeakTrophies 0 · 이번 시즌 pvpScoreSeason 삭제 · 이번 시즌 순위표 삭제. 백업 테이블 2개 먼저 생성. ⚠️ **일 2026-10-04 09:00 KST 전**에 | 적용(2026-10-02 확인 — 같은 트랜잭션의 백업 표 2개가 있다). ⚠️ **다시 돌리지 말 것** — 그 뒤 쌓인 이번 주 점수가 지워진다 |
| `_sql_20261001_pvp_league_idle.sql` | 결투 상대 후보 — 순위표가 모자라면 이번 주 안 싸운 같은 리그 사람(방어팀 있음)을 야생 전에 넣는 `pvp_league_idle`. 서버보다 먼저(없으면 서버가 예전처럼 야생) | 적용(2026-10-01) |
| `_sql_20261001_pvp_board_power.sql` | 결투 순위표·후보 전투력 = 결투 방어팀만(홈 전투력 대체 제거) · 점수 기록이 전투력 0 으로 덮지 않게(`pvp_season_submit`·`pvp_league_top`·`pvp_league_range` 재정의). 순서 무관 | 적용(2026-10-02) |
| `_sql_20261003_notice_lang.sql` | 언어별 공지 — `notices` 에 `title_en`·`body_en`·`title_ja`·`body_ja`(비워 둘 수 있음). ⚠️ **서버 재배포보다 먼저**(없으면 서버가 예전 방식으로 물러서지만 영어·일본어 입력이 저장 안 됨) | 대기 |

> `미확인` = 이 대장을 만들기(2026-09-08) 전에 있던 파일이라 적용 여부를 알 수 없다.
> 다음에 각 파일을 다룰 때 확인해서 `적용` / `대기` / `폐기` 로 바꾼다.
> 새로 만드는 파일은 처음부터 `대기` 로 적고, 사용자가 돌린 뒤 `적용`으로 바꾼다.
