import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'device_session.dart';
import 'guild_service.dart' show GuildWarTally, kGuildOpen;

/// 권위 서버 호출 결과.
class ServerResult {
  const ServerResult.ok(this.data)
    : error = null,
      status = 200,
      errorData = const {};
  const ServerResult.fail(this.error, this.status, {this.errorData = const {}})
    : data = null;

  /// 서버가 돌려준 JSON(성공 시). `save` 키에 갱신된 세이브가 들어 있다.
  final Map<String, dynamic>? data;
  final String? error;
  final int status;

  /// 실패 응답 본문. 거절 사유와 함께 온 값이 있으면 담긴다
  /// (예: `no_tickets` 일 때 서버가 아는 티켓 잔량).
  final Map<String, dynamic> errorData;

  bool get isOk => data != null;

  /// 일시적 오류라 재시도할 가치가 있는지(네트워크·5xx).
  bool get isRetryable => !isOk && (status == 0 || status >= 500);

  Map<String, dynamic>? get save => data?['save'] as Map<String, dynamic>?;
}

/// 권위 서버 계약.
///
/// **재화가 변하는 액션은 서버가 확정한다.** 클라이언트는 "무엇을 하고 싶다"만
/// 보내고 결과를 받는다. 서버가 붙어 있지 않으면 [available] 이 false 이고,
/// 호출부는 기존 로컬 경로로 폴백한다(전환 중 안전장치).
abstract interface class GameServer {
  bool get available;

  /// 내 세이브 조회.
  Future<ServerResult> fetchState();

  /// 구매 지급 — 서버가 영수증을 검증한 뒤 지급한다.
  Future<ServerResult> purchase({
    required String productId,
    required String purchaseToken,
  });

  /// PvP 전투 — 서버가 시뮬레이션하고 승패·보상을 확정한다.
  ///
  /// [opponentUserId] 는 실제 유저 상대, [tierId] 는 야생(합성) 상대.
  /// 야생은 **서버가 상대를 만들어** 응답의 `foe` 로 돌려준다 — 앱이 따로
  /// 만들면 연출과 서버 결과가 갈린다.
  /// [locale] = 화면 표시 언어('ko'/'en'/'ja'). 서버가 전투 로그의 곤충
  /// 이름을 이 언어로 굽는다 — 예전엔 서버가 'ko' 로 하드코딩해서, 영어로
  /// 바꿔도 상대 이름만 한글로 나왔다(2026-08-27).
  Future<ServerResult> battle({
    required List<String> teamBugIds,
    String? opponentUserId,
    String? tierId,
    String? locale,
  });

  /// 수동 전투 시작 — 세션을 열고 상대 스탯을 받는다.
  /// **시드는 응답에 없다**(있으면 상대의 수를 미리 계산할 수 있다).
  Future<ServerResult> startManualBattle({
    required List<String> teamBugIds,
    String? opponentUserId,
    String? tierId,
    String? locale,
  });

  /// 수동 전투 한 수 — 이번 라운드 결과만 돌아온다.
  Future<ServerResult> stepManualBattle({
    required String sessionId,
    required String stance,
  });

  /// 상대 후보 5명(같은 리그 순위 위 3명·아래 2명, 모자라면 야생) — `offerId`·`slots`(점수 포함).
  /// 정산 기간이면 `season_closed`.
  Future<ServerResult> duelOffer({String? locale});

  /// 순위표에서 누른 사람의 방어팀(곤충 3마리·전투력).
  Future<ServerResult> pvpProfile(String userId);

  /// 결투(곤충 배틀 스타디움) 시작 — 출전 순서 3마리 + 후보 제안의 한 칸([offerId]·[pick]).
  /// 세션 id·상대 3마리·승리 점수가 온다(시드는 없다).
  Future<ServerResult> duelStart({
    required List<String> teamBugIds,
    required String offerId,
    required int pick,
  });

  /// 결투 한 판 던지기 — [launch] 는 게이지 값(0~1). 그 판의 궤적·결판이 온다.
  /// 두 판을 먼저 이기면 `done: true` 와 세이브가 함께 온다.
  Future<ServerResult> duelThrow({
    required String sessionId,
    required double launch,
  });

  /// 결투 티켓 충전 — 광고 보상(+N장, 하루 상한은 서버가 센다).
  ///
  /// 티켓은 서버 소유라 앱이 로컬로 늘려도 업로드 때 덮인다. 광고를 끝까지 본
  /// 뒤 이걸 호출해야 실제로 늘어난다. 응답은 `tickets`·`ticketsAt`·`adUsed`
  /// 만 담는다(세이브 왕복 없음 — 이그레스 절약).
  Future<ServerResult> pvpTicketAd();

  /// 결투 티켓 충전 — 젤리로 즉시 만땅.
  Future<ServerResult> pvpTicketRefill();

  // ── 공지 · 운영 우편 · 선물코드 ──
  //
  // 셋 다 "서버가 유저에게 보낸다"는 같은 일이다. **지급은 서버가 확정**하고
  // 앱은 돌려받은 세이브를 채택한다 — 앱이 직접 재화를 더하면 다음 업로드에서
  // 골드 급증 상한에 걸려 정당한 보상이 잘린다.

  /// 진행 중인 공지 목록.
  Future<ServerResult> notices();

  /// 내가 **아직 받지 않은** 우편(개인 + 전체 발송).
  Future<ServerResult> mail();

  /// 우편 수령. 성공하면 지급이 반영된 세이브가 온다.
  Future<ServerResult> claimMail(String id);

  /// 선물코드 사용(계정당 1회). 성공하면 지급된 세이브가 온다.
  Future<ServerResult> redeemCode(String code);

  // ── 길드(1.0.15, docs/design_guild.md) ──
  //
  // 길드 상태는 서버 테이블이 소유한다(세이브에 없음). 응답은 대부분 `/guild/me` 와 같은
  // 모양(`guild`·`myRole`·`members`·`requests`)이라 화면은 받은 걸 그대로 갈아 끼운다.
  // ⚠️ 길드 화면이 열려 있을 때·앱 시작 때만 부른다(화면 밖 폴링 금지 — 요금).

  /// 내 길드. 없으면 `guild: null` + `cooldownUntil`·`requested`.
  Future<ServerResult> guildMe();

  /// 추천·검색 목록(같은 언어 → 자리 있음 → 전투력이 가까운 순).
  Future<ServerResult> guildList({required String lang, String query = ''});
  Future<ServerResult> guildCreate({
    required String name,
    required String lang,
    required String joinMode,
    int? emblem,
  });

  /// 가입 — 공개 길드는 바로(`guild` 가 온다), 승인제는 신청(`requested: true`).
  Future<ServerResult> guildJoin(String guildId);
  Future<ServerResult> guildCancelRequest(String guildId);
  Future<ServerResult> guildLeave();
  Future<ServerResult> guildKick(String userId);

  /// 직책(`leader` = 위임 · `deputy` · `member`) — 길드장만.
  Future<ServerResult> guildSetRole(String userId, String role);
  Future<ServerResult> guildAnswerRequest(
    String userId, {
    required bool accept,
  });
  Future<ServerResult> guildSettings({
    String? notice,
    String? joinMode,
    bool? deputyCanAccept,
    int? emblem,
  });

  /// 길드 미션 탭 — 게시판·남은 출발·도움 목록·받을 보상. ⚠️ 탭을 보고 있을 때만 주기 조회.
  Future<ServerResult> guildMissions();

  /// 출발 — [power] 는 홈 상단 전투력(요구치 = 이 값 × 배율이라 부풀려도 얻는 게 없다).
  Future<ServerResult> guildMissionStart({
    required int slot,
    required int waitSec,
    required double power,
  });
  Future<ServerResult> guildMissionHelp(
    String missionId, {
    required double power,
  });

  /// 받을 수 있는 미션 보상을 모두 받는다 — 응답의 `save` 를 채택한다(우편 수령과 같은 방식).
  Future<ServerResult> guildMissionClaim();

  /// 하루 한 번 출석(무료) — `/guild/me` 모양 + `attend`(이번 일차·받은 것).
  /// 출석 표 큰 보상(화석·가루)이 있는 날엔 `save`(서버 세이브 — 채택한다)도 온다.
  Future<ServerResult> guildDonate();

  /// 길드원 정보(같은 길드만, 아니면 403) — `member`(직책·기여도·등급·전투력) + `summary`(세이브 요약).
  Future<ServerResult> guildMember(String userId);
  Future<ServerResult> guildSkillUp(String skillId);
  Future<ServerResult> guildSkillReset();

  /// 코인 상점 — `/guild/me` 모양 + `save`(채택) + `granted`.
  Future<ServerResult> guildShopBuy(String itemId);

  /// 길드 보스 — 단계·체력·남은 공격·순위·지난주 보상.
  Future<ServerResult> guildBoss();

  /// 공격 — 피해는 서버가 결투 방어팀으로 계산한다. 응답 = [guildBoss] 모양 + `hit`.
  Future<ServerResult> guildBossAttack();

  /// 지난주 순위 보상(젤리) — `save` 를 채택한다.
  Future<ServerResult> guildBossClaim();

  /// 길드전 — 일차·주제·내 점수·양 길드 일차 합·결과·보상.
  Future<ServerResult> guildWar();

  /// 길드전 보상(코인 + 젤리) — `save` 를 채택한다.
  Future<ServerResult> guildWarClaim();

  /// 방치 수입 정산 — 금액은 서버가 정한다.
  Future<ServerResult> sync();

  /// 업그레이드 1단계.
  Future<ServerResult> upgrade(String kindKey, {int count});

  /// 부위 강화 1단계.
  Future<ServerResult> enhance(String bugId, String partKey);

  /// 수련(성충 레벨업).
  Future<ServerResult> train(String bugId);

  /// 돌파 시작(레벨 상한 확장 — 재화 소비 + 타이머).
  Future<ServerResult> breakthrough(String bugId);

  /// 돌파 완료 수령(타이머 종료 후 또는 젤리 즉시완료).
  Future<ServerResult> completeBreakthrough(String bugId, {bool viaJelly});

  /// 짝짓기 시작 — **시드는 서버가 정한다**(클라가 고를 수 없다).
  Future<ServerResult> breed(String motherId, String fatherId);

  // ── 실물 경품 랭킹 이벤트(웨이브 방어전) ────────────────────────
  //
  // ⚠️ 이 모드는 **서버 없이는 성립하지 않는다.** 순위가 그대로 실물 상품이라
  // 로컬 계산으로 점수를 만들 수 있으면 안 된다 — `available` 이 false 면
  // 앱은 이벤트 진입 자체를 막는다(docs/event_ranking_prize.md §3).

  /// 이벤트 현황(회차·참가권·내 최고 기록).
  Future<ServerResult> eventState();

  /// 이벤트 도전 1회(구버전 — 판을 한 번에 확정). 카드 방식을 못 쓸 때의 폴백.
  Future<ServerResult> eventChallenge(List<String> teamBugIds);

  /// 이벤트 도전 시작 — 참가권을 깎고 **1웨이브만** 치른다.
  /// 응답에 세션 id 와 다음 카드 후보가 온다.
  Future<ServerResult> eventStart(List<String> teamBugIds);

  /// 카드를 고르고 다음 웨이브로. 판이 끝나면 점수가 확정된다.
  /// [leadBugId] 를 주면 다음 웨이브에 그 곤충을 앞세운다(순서 교체).
  Future<ServerResult> eventPick(
    String sessionId,
    String cardId, {
    String? leadBugId,
  });

  /// 왕충 선발대회(2회차부터) — 곤충 1마리로 도전 시작. 참가권 −1 · 그 곤충 부상.
  Future<ServerResult> eventDuelStart(String bugId);

  /// 대회 한 판 — 카드가 걸려 있으면 [cardId] 를 먼저 적용하고 지금 웨이브를 [launch] 로 싸운다.
  Future<ServerResult> eventDuelThrow({
    required String sessionId,
    required double launch,
    String? cardId,
  });

  /// 대회 그만하기 — 지금까지의 기록으로 확정(부상은 남은 체력만큼 줄어든다).
  Future<ServerResult> eventDuelQuit(String sessionId);

  /// 광고 시청 보상 참가권.
  Future<ServerResult> eventAdTicket();

  /// 대회 부상 젤리 즉시 회복 — 대회 부상은 서버 소유라 서버가 젤리를 깎고 지운다.
  Future<ServerResult> eventDuelHeal(String bugId);

  /// 요정 재굴림(2026-10-04) — 서버가 굴려 대기 결과로 적는다. 응답 `save` 를 채택한다.
  Future<ServerResult> fairyReroll(String fairyId);

  /// 재굴림 결과 고르기 — [accept] 면 새 값, 아니면 원래 값.
  Future<ServerResult> fairyRerollChoose({required bool accept});

  /// 이벤트 순위(상위 100). 서버가 대신 읽어 준다 — 앱에는 RPC 권한이 없다.
  Future<ServerResult> eventLeaderboard();

  /// 명예의 전당 — 가장 최근에 끝난 회차의 순위 전체 + 다음 회차 일정.
  /// 대회가 닫혀 있어도 답한다(그때 보라고 만든 화면이다).
  Future<ServerResult> eventHall();

  /// 결투 리그 순위표 — 내 리그의 이번 시즌 상위 100명 + 내 순위 · 승강 구간 · 결산 시각.
  Future<ServerResult> pvpLeagueBoard();

  /// 심연 주간 순위표 — 이번 주 전체 상위 100명 + 내 순위.
  Future<ServerResult> abyssBoard();

  /// **개발자 모드 전용** — 이벤트 참가권 지급. 운영 키가 있어야 한다.
  ///
  /// 참가권은 서버 소유 필드라 앱이 세이브를 고쳐 늘릴 수 없다. 아무나 부르면
  /// 그 회차 순위가 통째로 무효가 되므로 서버가 `x-admin-key` 를 검사한다.
  Future<ServerResult> adminEventTicket({
    required String adminKey,
    required String userId,
    required int amount,
    bool resetDaily = false,
  });

  /// 산란 완료 수령.
  Future<ServerResult> collectBreeding(String slotId, {bool viaJelly});

  /// 부화 수령(알 → 유충).
  Future<ServerResult> collectIncubated(String bugId);

  /// 곤충 분해 → 젤리.
  Future<ServerResult> disassemble(String bugId);

  /// 미션 보상 수령(진행도·목표는 서버가 판정).
  Future<ServerResult> claimMission(String missionId);

  /// 깜짝선물 수령([doubled]=광고 배수).
  Future<ServerResult> claimGift(String giftId, {bool doubled});

  /// 일일보상 수령(UTC 날짜당 1회). [gold]·[materialsEach] 는 앱이 계산한 금액(사냥 분치) —
  /// 서버가 상한으로 자른다. [bonus] = "한 번 더 받기"(슬롯마다 하루 1회).
  Future<ServerResult> claimDaily(
    String rewardId, {
    int gold,
    int materialsEach,
    bool bonus,
  });

  /// 로드맵 챕터 클리어 보상(스테이지 기준, 서버 확정).
  Future<ServerResult> claimRoadmap();

  /// 기기 권위 세이브 **주기 업로드**(저장). 서버가 보호필드·골드상한만 손대고
  /// 저장한다. 최초 1회는 [bootstrap] 이 먼저(저장본 없으면 이 호출은 409).
  Future<ServerResult> uploadSave(Map<String, dynamic> save);

  /// 로컬 세이브를 서버로 **최초 1회 이관**한다.
  /// 서버에 이미 세이브가 있으면 409 와 함께 서버 것을 돌려준다.
  Future<ServerResult> bootstrap(Map<String, dynamic> save);

  /// 운영자에게 문의 — 서버가 텔레그램으로 밀어 준다.
  /// 상황 값(닉네임·스테이지 등)은 **서버가 세이브에서 읽으므로** 보내지 않는다.
  Future<ServerResult> sendSupport({
    required String message,
    String? appVersion,
    String? device,
  });
}

/// 업로드가 **다른 기기에 밀려나** 거절됐는가(한 기기만 접속, 1.0.16).
bool isSessionTaken(ServerResult r) =>
    r.status == 409 && r.error == 'session_taken';

/// 서버 미설정 — 항상 사용 불가.
class NoGameServer implements GameServer {
  const NoGameServer();

  @override
  bool get available => false;
  @override
  Future<ServerResult> fetchState() async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> purchase({
    required String productId,
    required String purchaseToken,
  }) async => const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> battle({
    required List<String> teamBugIds,
    String? opponentUserId,
    String? tierId,
    String? locale,
  }) async => const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> sendSupport({
    required String message,
    String? appVersion,
    String? device,
  }) async => const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> bootstrap(Map<String, dynamic> save) async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> uploadSave(Map<String, dynamic> save) async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> sync() async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> upgrade(String kindKey, {int count = 1}) async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> enhance(String bugId, String partKey) async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> train(String bugId) async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> breakthrough(String bugId) async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> completeBreakthrough(
    String bugId, {
    bool viaJelly = false,
  }) async => const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> breed(String motherId, String fatherId) async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> eventState() async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> eventChallenge(List<String> teamBugIds) async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> eventStart(List<String> teamBugIds) async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> eventPick(
    String sessionId,
    String cardId, {
    String? leadBugId,
  }) async => const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> eventDuelStart(String bugId) async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> eventDuelThrow({
    required String sessionId,
    required double launch,
    String? cardId,
  }) async => const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> eventDuelQuit(String sessionId) async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> eventAdTicket() async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> fairyReroll(String fairyId) async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> fairyRerollChoose({required bool accept}) async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> eventDuelHeal(String bugId) async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> pvpLeagueBoard() async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> abyssBoard() async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> eventLeaderboard() async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> eventHall() async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> adminEventTicket({
    required String adminKey,
    required String userId,
    required int amount,
    bool resetDaily = false,
  }) async => const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> collectBreeding(
    String slotId, {
    bool viaJelly = false,
  }) async => const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> collectIncubated(String bugId) async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> disassemble(String bugId) async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> claimMission(String missionId) async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> claimGift(String giftId, {bool doubled = false}) async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> claimDaily(
    String rewardId, {
    int gold = 0,
    int materialsEach = 0,
    bool bonus = false,
  }) async => const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> claimRoadmap() async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> startManualBattle({
    required List<String> teamBugIds,
    String? opponentUserId,
    String? tierId,
    String? locale,
  }) async => const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> stepManualBattle({
    required String sessionId,
    required String stance,
  }) async => const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> duelOffer({String? locale}) async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> pvpProfile(String userId) async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> duelStart({
    required List<String> teamBugIds,
    required String offerId,
    required int pick,
  }) async => const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> duelThrow({
    required String sessionId,
    required double launch,
  }) async => const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> pvpTicketAd() async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> pvpTicketRefill() async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> notices() async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> mail() async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> claimMail(String id) async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> redeemCode(String code) async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> guildMe() async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> guildList({
    required String lang,
    String query = '',
  }) async => const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> guildCreate({
    required String name,
    required String lang,
    required String joinMode,
    int? emblem,
  }) async => const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> guildJoin(String guildId) async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> guildCancelRequest(String guildId) async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> guildLeave() async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> guildKick(String userId) async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> guildSetRole(String userId, String role) async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> guildAnswerRequest(
    String userId, {
    required bool accept,
  }) async => const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> guildSettings({
    String? notice,
    String? joinMode,
    bool? deputyCanAccept,
    int? emblem,
  }) async => const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> guildMissions() async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> guildMissionStart({
    required int slot,
    required int waitSec,
    required double power,
  }) async => const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> guildMissionHelp(
    String missionId, {
    required double power,
  }) async => const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> guildMissionClaim() async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> guildDonate() async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> guildMember(String userId) async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> guildSkillUp(String skillId) async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> guildSkillReset() async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> guildShopBuy(String itemId) async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> guildBoss() async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> guildBossAttack() async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> guildBossClaim() async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> guildWar() async =>
      const ServerResult.fail('unavailable', 0);
  @override
  Future<ServerResult> guildWarClaim() async =>
      const ServerResult.fail('unavailable', 0);
}

/// HTTP 구현. 인증은 **Supabase 세션 토큰**을 그대로 실어 보낸다
/// (서버가 JWKS 공개키로 검증한다).
class HttpGameServer implements GameServer {
  HttpGameServer({
    required this.baseUrl,
    required SupabaseClient client,
    http.Client? httpClient,
  }) : _client = client,
       _http = httpClient ?? http.Client();

  final String baseUrl;
  final SupabaseClient _client;
  final http.Client _http;

  @override
  bool get available => baseUrl.isNotEmpty;

  String? get _token => _client.auth.currentSession?.accessToken;

  /// 요청 하나의 시간 제한. 세이브 업로드(최대 1MB)가 느린 망에서도 들어가는 여유.
  static const _requestTimeout = Duration(seconds: 30);

  Future<ServerResult> _send(
    String method,
    String path, [
    Map<String, dynamic>? body,
    // 운영 라우트(`x-admin-key`)처럼 인증 헤더가 더 필요한 경우에만 쓴다.
    Map<String, String>? extraHeaders,
  ]) async {
    final token = _token;
    if (token == null) return const ServerResult.fail('no_session', 401);
    try {
      final uri = Uri.parse('$baseUrl$path');
      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        ...?extraHeaders,
      };
      // 시간 제한 — 없으면 던지기 직후 통신이 끊겼을 때 스피너만 돌고 뒤로가기도 막혀 앱을
      // 강제 종료해야 했다(2026-09-30 점검). 걸리면 네트워크 오류(status 0)와 같이 다룬다.
      final res =
          await (method == 'GET'
                  ? _http.get(uri, headers: headers)
                  : _http.post(uri, headers: headers, body: jsonEncode(body)))
              .timeout(_requestTimeout);

      final decoded = res.body.isEmpty
          ? const <String, dynamic>{}
          : jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return ServerResult.ok(decoded);
      }
      return ServerResult.fail(
        decoded['error']?.toString() ?? 'http_${res.statusCode}',
        res.statusCode,
        errorData: decoded,
      );
    } catch (e) {
      debugPrint('[server] $method $path 실패: $e');
      // status 0 = 네트워크 오류 → 재시도 대상.
      return const ServerResult.fail('network', 0);
    }
  }

  /// 이 기기가 계정을 쥔다(한 기기만 접속, 1.0.16 · [DeviceSession]).
  ///
  /// 실패해도 막지 않는다 — 표식 없이 올리면 서버는 구버전 앱처럼 받아 준다(지금과 같은 동작).
  /// [force] 가 아니면 실패 뒤 2분은 다시 두드리지 않는다(업로드마다 요청이 하나 더 붙지 않게).
  /// 지금 로그인한 계정으로 쥐고 있나.
  bool get _claimedHere =>
      DeviceSession.claimed &&
      DeviceSession.claimedUser == _client.auth.currentUser?.id;

  void _markClaimed() {
    DeviceSession.claimed = true;
    DeviceSession.claimedUser = _client.auth.currentUser?.id;
    DeviceSession.firstUploadPending = true;
    DeviceSession.claimEpoch++;
  }

  Future<void> _ensureSession({bool force = false}) async {
    if (_claimedHere) return;
    final now = DateTime.now();
    final tried = DeviceSession.triedAt;
    if (!force &&
        tried != null &&
        now.difference(tried) < const Duration(minutes: 2)) {
      return;
    }
    DeviceSession.triedAt = now;
    final r = await _send('POST', '/session/claim', {
      'session': DeviceSession.id,
    });
    if (r.isOk && r.data?['claimed'] == true) _markClaimed();
  }

  /// 켤 때의 첫 조회가 곧 접속이다 — 쥔 뒤에 서버 저장본을 받아야 그 사이 다른 기기의
  /// 업로드에 덮이지 않는다.
  @override
  Future<ServerResult> fetchState() async {
    // 계정이 바뀌었다(게스트 → 로그인) — 옛 계정에서 밀려났던 표시는 새 계정과 무관하다.
    if (DeviceSession.claimed &&
        DeviceSession.claimedUser != _client.auth.currentUser?.id) {
      DeviceSession.taken.value = false;
    }
    await _ensureSession(force: true);
    return _send('GET', '/state');
  }

  @override
  Future<ServerResult> purchase({
    required String productId,
    required String purchaseToken,
  }) => _send('POST', '/purchase', {
    'productId': productId,
    'purchaseToken': purchaseToken,
  });

  @override
  Future<ServerResult> battle({
    required List<String> teamBugIds,
    String? opponentUserId,
    String? tierId,
    String? locale,
  }) => _send('POST', '/battle', {
    'teamBugIds': teamBugIds,
    'opponentUserId': ?opponentUserId,
    'tierId': ?tierId,
    'locale': ?locale,
  });

  @override
  Future<ServerResult> sendSupport({
    required String message,
    String? appVersion,
    String? device,
  }) => _send('POST', '/support', {
    'message': message,
    'appVersion': ?appVersion,
    'device': ?device,
  });

  @override
  Future<ServerResult> bootstrap(Map<String, dynamic> save) async {
    // 새 계정 — 첫 이관이 표식을 채운다(서버는 비어 있을 때만 쓴다).
    final r = await _send('POST', '/state', {
      'save': save,
      'session': DeviceSession.id,
    });
    if (r.isOk) _markClaimed();
    return r;
  }

  @override
  Future<ServerResult> uploadSave(Map<String, dynamic> save) async {
    // 길드전 활동 수는 세이브가 아니라 **본문 옆칸**으로(세이브 스키마를 안 건드린다).
    // 길드를 열기 전(kGuildOpen)·길드가 없을 때(또는 아직 모를 때)는 싣지 않는다 — 서버가
    // 업로드마다 길드를 조회하지 않게. 안 실은 집계는 dirty 로 남아 길드가 확인된 뒤 업로드에 간다.
    final tally = kGuildOpen && GuildWarTally.inGuild
        ? GuildWarTally.payload(DateTime.now().toUtc())
        : null;
    await _ensureSession();
    Future<ServerResult> send() => _send('POST', '/save', {
      'save': save,
      'guildTally': ?tally,
      'session': ?(_claimedHere ? DeviceSession.id : null),
    });
    final epoch = DeviceSession.claimEpoch;
    var r = await send();
    if (isSessionTaken(r)) {
      if (DeviceSession.claimEpoch != epoch && _claimedHere) {
        // 이 업로드가 나간 사이 다른 호출이 이미 다시 쥐었다 — 새 표식으로 한 번 더 올린다.
        r = await send();
      } else if (DeviceSession.firstUploadPending) {
        // 쥔 뒤 첫 업로드인데 밀려났다 = 다른 쓰기와 겹쳐 표식이 되돌려진 경쟁이다
        // ([DeviceSession.firstUploadPending]). 한 번만 다시 쥐고 다시 올린다. 진짜로 밀려난 기기는
        // 이미 첫 업로드를 통과했으니 여기 걸리지 않는다.
        DeviceSession.firstUploadPending = false; // 두 번은 안 한다
        DeviceSession.claimed = false;
        await _ensureSession(force: true);
        if (_claimedHere) {
          DeviceSession.firstUploadPending = false;
          r = await send();
        }
      }
    }
    // 표식을 실은 업로드가 통과했다 — 이제부터 "밀려남"은 진짜다.
    if (r.isOk && _claimedHere) DeviceSession.firstUploadPending = false;
    if (r.isOk && tally != null) GuildWarTally.sent();
    // 다른 기기가 나중에 켜졌다 — 이 기기의 세이브는 낡았다.
    if (isSessionTaken(r)) DeviceSession.taken.value = true;
    return r;
  }

  @override
  Future<ServerResult> sync() => _send('POST', '/sync', const {});

  @override
  Future<ServerResult> upgrade(String kindKey, {int count = 1}) =>
      _send('POST', '/upgrade', {'kind': kindKey, 'count': count});

  @override
  Future<ServerResult> enhance(String bugId, String partKey) =>
      _send('POST', '/enhance', {'bugId': bugId, 'part': partKey});

  @override
  Future<ServerResult> train(String bugId) =>
      _send('POST', '/train', {'bugId': bugId});

  @override
  Future<ServerResult> breakthrough(String bugId) =>
      _send('POST', '/breakthrough', {'bugId': bugId});

  @override
  Future<ServerResult> completeBreakthrough(
    String bugId, {
    bool viaJelly = false,
  }) => _send('POST', '/breakthrough/complete', {
    'bugId': bugId,
    'viaJelly': viaJelly,
  });

  @override
  Future<ServerResult> breed(String motherId, String fatherId) =>
      _send('POST', '/breed', {'motherId': motherId, 'fatherId': fatherId});

  @override
  Future<ServerResult> eventState() => _send('GET', '/event');

  @override
  Future<ServerResult> eventChallenge(List<String> teamBugIds) =>
      _send('POST', '/event/challenge', {'teamIds': teamBugIds});

  @override
  Future<ServerResult> eventStart(List<String> teamBugIds) =>
      _send('POST', '/event/start', {'teamIds': teamBugIds});

  @override
  Future<ServerResult> eventDuelStart(String bugId) =>
      _send('POST', '/event/duel/start', {'bugId': bugId});

  @override
  Future<ServerResult> eventDuelQuit(String sessionId) =>
      _send('POST', '/event/duel/quit', {'sessionId': sessionId});

  @override
  Future<ServerResult> eventDuelThrow({
    required String sessionId,
    required double launch,
    String? cardId,
  }) => _send('POST', '/event/duel/throw', {
    'sessionId': sessionId,
    'launch': launch,
    'cardId': ?cardId,
  });

  @override
  Future<ServerResult> eventPick(
    String sessionId,
    String cardId, {
    String? leadBugId,
  }) => _send('POST', '/event/pick', {
    'sessionId': sessionId,
    'cardId': cardId,
    // 값이 null 이면 키 자체를 빼서, 서버가 "순서 유지"로 받게 한다.
    'leadBugId': ?leadBugId,
  });

  @override
  Future<ServerResult> eventAdTicket() =>
      _send('POST', '/event/ad-ticket', const {});

  @override
  Future<ServerResult> fairyReroll(String fairyId) =>
      _send('POST', '/fairy/reroll', {'fairyId': fairyId});

  @override
  Future<ServerResult> fairyRerollChoose({required bool accept}) =>
      _send('POST', '/fairy/reroll/choose', {'accept': accept});

  @override
  Future<ServerResult> eventDuelHeal(String bugId) =>
      _send('POST', '/event/duel/heal', {'bugId': bugId});

  @override
  Future<ServerResult> eventLeaderboard() => _send('GET', '/event/leaderboard');

  @override
  Future<ServerResult> pvpLeagueBoard() => _send('GET', '/pvp/league');

  @override
  Future<ServerResult> abyssBoard() => _send('GET', '/abyss/top');

  @override
  Future<ServerResult> eventHall() => _send('GET', '/event/hall');

  @override
  Future<ServerResult> adminEventTicket({
    required String adminKey,
    required String userId,
    required int amount,
    bool resetDaily = false,
  }) => _send(
    'POST',
    '/admin/event-ticket',
    {'userId': userId, 'amount': amount, if (resetDaily) 'resetDaily': true},
    {'x-admin-key': adminKey},
  );

  @override
  Future<ServerResult> collectBreeding(
    String slotId, {
    bool viaJelly = false,
  }) =>
      _send('POST', '/breed/collect', {'slotId': slotId, 'viaJelly': viaJelly});

  @override
  Future<ServerResult> collectIncubated(String bugId) =>
      _send('POST', '/incubate/collect', {'bugId': bugId});

  @override
  Future<ServerResult> disassemble(String bugId) =>
      _send('POST', '/disassemble', {'bugId': bugId});

  @override
  Future<ServerResult> claimMission(String missionId) =>
      _send('POST', '/mission/claim', {'missionId': missionId});

  @override
  Future<ServerResult> claimGift(String giftId, {bool doubled = false}) =>
      _send('POST', '/gift/claim', {'giftId': giftId, 'doubled': doubled});

  @override
  Future<ServerResult> claimDaily(
    String rewardId, {
    int gold = 0,
    int materialsEach = 0,
    bool bonus = false,
  }) => _send('POST', '/daily/claim', {
    'rewardId': rewardId,
    'gold': gold,
    'materialsEach': materialsEach,
    if (bonus) 'bonus': true,
  });

  @override
  Future<ServerResult> claimRoadmap() =>
      _send('POST', '/roadmap/claim', const {});

  @override
  Future<ServerResult> startManualBattle({
    required List<String> teamBugIds,
    String? opponentUserId,
    String? tierId,
    String? locale,
  }) => _send('POST', '/battle/manual/start', {
    'teamBugIds': teamBugIds,
    'opponentUserId': ?opponentUserId,
    'tierId': ?tierId,
    'locale': ?locale,
  });

  @override
  Future<ServerResult> stepManualBattle({
    required String sessionId,
    required String stance,
  }) => _send('POST', '/battle/manual/step', {
    'sessionId': sessionId,
    'stance': stance,
  });

  @override
  Future<ServerResult> duelOffer({String? locale}) =>
      _send('POST', '/duel/offer', {'locale': ?locale});

  @override
  Future<ServerResult> pvpProfile(String userId) =>
      _send('GET', '/pvp/profile?user=${Uri.encodeQueryComponent(userId)}');

  @override
  Future<ServerResult> duelStart({
    required List<String> teamBugIds,
    required String offerId,
    required int pick,
  }) => _send('POST', '/duel/start', {
    'teamBugIds': teamBugIds,
    'offerId': offerId,
    'pick': pick,
  });

  @override
  Future<ServerResult> duelThrow({
    required String sessionId,
    required double launch,
  }) =>
      _send('POST', '/duel/throw', {'sessionId': sessionId, 'launch': launch});

  @override
  Future<ServerResult> pvpTicketAd() =>
      _send('POST', '/pvp/ticket/ad', const {});

  @override
  Future<ServerResult> pvpTicketRefill() =>
      _send('POST', '/pvp/ticket/refill', const {});

  @override
  Future<ServerResult> notices() => _send('GET', '/notices');

  @override
  Future<ServerResult> mail() => _send('GET', '/mail');

  @override
  Future<ServerResult> claimMail(String id) =>
      _send('POST', '/mail/claim', {'id': id});

  @override
  Future<ServerResult> redeemCode(String code) =>
      _send('POST', '/code/redeem', {'code': code});

  @override
  Future<ServerResult> guildMe() => _send('GET', '/guild/me');

  @override
  Future<ServerResult> guildList({required String lang, String query = ''}) =>
      _send(
        'GET',
        '/guild/list?lang=${Uri.encodeQueryComponent(lang)}'
            '&q=${Uri.encodeQueryComponent(query)}',
      );

  @override
  Future<ServerResult> guildCreate({
    required String name,
    required String lang,
    required String joinMode,
    int? emblem,
  }) => _send('POST', '/guild/create', {
    'name': name,
    'lang': lang,
    'joinMode': joinMode,
    'emblem': ?emblem,
  });

  @override
  Future<ServerResult> guildJoin(String guildId) =>
      _send('POST', '/guild/join', {'guildId': guildId});

  @override
  Future<ServerResult> guildCancelRequest(String guildId) =>
      _send('POST', '/guild/request/cancel', {'guildId': guildId});

  @override
  Future<ServerResult> guildLeave() => _send('POST', '/guild/leave', const {});

  @override
  Future<ServerResult> guildKick(String userId) =>
      _send('POST', '/guild/kick', {'userId': userId});

  @override
  Future<ServerResult> guildSetRole(String userId, String role) =>
      _send('POST', '/guild/role', {'userId': userId, 'role': role});

  @override
  Future<ServerResult> guildAnswerRequest(
    String userId, {
    required bool accept,
  }) => _send('POST', '/guild/request/answer', {
    'userId': userId,
    'accept': accept,
  });

  @override
  Future<ServerResult> guildMissions() => _send('GET', '/guild/missions');

  @override
  Future<ServerResult> guildMissionStart({
    required int slot,
    required int waitSec,
    required double power,
  }) => _send('POST', '/guild/mission/start', {
    'slot': slot,
    'wait': waitSec,
    'power': power,
  });

  @override
  Future<ServerResult> guildMissionHelp(
    String missionId, {
    required double power,
  }) => _send('POST', '/guild/mission/help', {
    'missionId': missionId,
    'power': power,
  });

  @override
  Future<ServerResult> guildMissionClaim() =>
      _send('POST', '/guild/mission/claim', const {});

  @override
  Future<ServerResult> guildDonate() =>
      _send('POST', '/guild/donate', const {});

  @override
  Future<ServerResult> guildMember(String userId) =>
      _send('GET', '/guild/member/${Uri.encodeComponent(userId)}');

  @override
  Future<ServerResult> guildSkillUp(String skillId) =>
      _send('POST', '/guild/skill/up', {'skillId': skillId});

  @override
  Future<ServerResult> guildSkillReset() =>
      _send('POST', '/guild/skill/reset', const {});

  @override
  Future<ServerResult> guildShopBuy(String itemId) =>
      _send('POST', '/guild/shop/buy', {'itemId': itemId});

  @override
  Future<ServerResult> guildBoss() => _send('GET', '/guild/boss');

  @override
  Future<ServerResult> guildBossAttack() =>
      _send('POST', '/guild/boss/attack', const {});

  @override
  Future<ServerResult> guildBossClaim() =>
      _send('POST', '/guild/boss/claim', const {});

  @override
  Future<ServerResult> guildWar() => _send('GET', '/guild/war');

  @override
  Future<ServerResult> guildWarClaim() =>
      _send('POST', '/guild/war/claim', const {});

  @override
  Future<ServerResult> guildSettings({
    String? notice,
    String? joinMode,
    bool? deputyCanAccept,
    int? emblem,
  }) => _send('POST', '/guild/settings', {
    'notice': ?notice,
    'joinMode': ?joinMode,
    'deputyCanAccept': ?deputyCanAccept,
    'emblem': ?emblem,
  });
}

/// 교체 가능한 권위 서버. 기본은 미설정(로컬 경로 유지).
final gameServerProvider = Provider<GameServer>((ref) => const NoGameServer());
