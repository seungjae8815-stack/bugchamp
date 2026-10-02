import 'package:meta/meta.dart';

import 'guild_boss.dart';
import 'guild_mission.dart';
import 'guild_progress.dart';
import 'guild_war.dart';

/// 길드 기본 규칙(docs/design_guild.md §1, 2026-09-30 사장님 확정 방향).
///
/// 길드 상태 본체(길드·멤버·신청)는 **서버 테이블이 소유**한다 — 세이브에는 없다.
/// 이 설정은 앱(화면 안내)과 서버(검사)가 같은 값을 보려고 JSON 에 둔다(`guild.json`).
@immutable
class GuildConfig {
  const GuildConfig({
    this.maxMembers = 20,
    this.createJellyCost = 200,
    this.nameMinLength = 2,
    this.nameMaxLength = 12,
    this.noticeMaxLength = 80,
    this.rejoinCooldownHours = 24,
    this.deputyMax = 2,
    this.leaderInactiveDays = 7,
    this.listLimit = 20,
    this.maxPendingRequests = 3,
    this.requestLimit = 30,
    this.mission = const GuildMissionConfig(),
    this.level = const GuildLevelConfig(),
    this.donateExp = 5,
    this.donateCoins = 10,
    this.skills = const [],
    this.shop = const [],
    this.boss = const GuildBossConfig(),
    this.war = const GuildWarConfig(),
  });

  /// 길드 인원(길드 레벨로 늘어나는 몫은 3단계에서 더한다).
  final int maxMembers;

  /// 길드 개설 비용(젤리, 2026-10-01 사장님 확정). 골드는 회차마다 초기화라 정액 비용이 성립하지 않는다.
  /// 서버가 먼저 치르고(`/guild/create`) 앱은 같은 금액을 로컬에서 뺀다(결투 티켓 젤리 충전과 같은 방식).
  final int createJellyCost;

  final int nameMinLength;
  final int nameMaxLength;

  /// 길드 소개(길드장이 쓴다).
  final int noticeMaxLength;

  /// 탈퇴·추방 뒤 다른 길드에 들어가기까지(시간) — 길드전 보상 사냥을 막는다.
  final int rejoinCooldownHours;

  /// 부길드장 최대 수.
  final int deputyMax;

  /// 길드장이 이 일수 동안 접속하지 않으면 자동 위임(부길드장 → 기여도 순).
  final int leaderInactiveDays;

  /// 추천·검색 목록 길이.
  final int listLimit;

  /// 한 사람이 동시에 넣어 둘 수 있는 가입 신청 수(승인제 길드).
  final int maxPendingRequests;

  /// 한 길드에 쌓이는 가입 신청 상한(넘치면 오래된 것부터 안 받는다).
  final int requestLimit;

  /// 길드 미션(2단계).
  final GuildMissionConfig mission;

  /// 길드 레벨(3단계) — 경험치 곡선·인원·스킬 포인트.
  final GuildLevelConfig level;

  /// 하루 한 번 출석(무료) — 길드 경험치 + 내 코인.
  final int donateExp;
  final int donateCoins;

  /// 길드 버프 스킬 — 길드장·부길드장이 포인트를 찍는다(모두에게 적용).
  final List<GuildSkillDef> skills;

  /// 길드 상점(코인).
  final List<GuildShopItem> shop;

  /// 길드 보스(4단계).
  final GuildBossConfig boss;

  /// 주간 길드전(5단계).
  final GuildWarConfig war;

  GuildSkillDef? skill(String id) =>
      skills.where((s) => s.id == id).firstOrNull;
  GuildShopItem? shopItem(String id) =>
      shop.where((s) => s.id == id).firstOrNull;

  factory GuildConfig.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const GuildConfig();
    int i(String k, int d) => (j[k] as num?)?.toInt() ?? d;
    return GuildConfig(
      maxMembers: i('maxMembers', 20),
      createJellyCost: i('createJellyCost', 200),
      nameMinLength: i('nameMinLength', 2),
      nameMaxLength: i('nameMaxLength', 12),
      noticeMaxLength: i('noticeMaxLength', 80),
      rejoinCooldownHours: i('rejoinCooldownHours', 24),
      deputyMax: i('deputyMax', 2),
      leaderInactiveDays: i('leaderInactiveDays', 7),
      listLimit: i('listLimit', 20),
      maxPendingRequests: i('maxPendingRequests', 3),
      requestLimit: i('requestLimit', 30),
      mission: GuildMissionConfig.fromJson(
        j['mission'] as Map<String, dynamic>?,
      ),
      level: GuildLevelConfig.fromJson(j['level'] as Map<String, dynamic>?),
      donateExp: (j['donate'] as Map?)?['exp'] is num
          ? ((j['donate'] as Map)['exp'] as num).toInt()
          : 5,
      donateCoins: (j['donate'] as Map?)?['coins'] is num
          ? ((j['donate'] as Map)['coins'] as num).toInt()
          : 10,
      skills: [
        for (final x in (j['skills'] as List? ?? const []))
          GuildSkillDef.fromJson(x as Map<String, dynamic>),
      ],
      shop: [
        for (final x in (j['shop'] as List? ?? const []))
          GuildShopItem.fromJson(x as Map<String, dynamic>),
      ],
      boss: GuildBossConfig.fromJson(j['boss'] as Map<String, dynamic>?),
      war: GuildWarConfig.fromJson(j['war'] as Map<String, dynamic>?),
    );
  }
}

/// 길드 직책. 문자열은 DB `guild_members.role` 값 그대로다.
enum GuildRole {
  leader('leader'),
  deputy('deputy'),
  member('member');

  const GuildRole(this.key);
  final String key;

  static GuildRole fromKey(String? k) => switch (k) {
    'leader' => GuildRole.leader,
    'deputy' => GuildRole.deputy,
    _ => GuildRole.member,
  };

  /// 가입 승인·추방·소개 수정을 할 수 있는지.
  bool get canManage => this != GuildRole.member;
}

/// 가입 방식.
enum GuildJoinMode {
  open('open'),
  approval('approval');

  const GuildJoinMode(this.key);
  final String key;

  static GuildJoinMode fromKey(String? k) =>
      k == 'approval' ? GuildJoinMode.approval : GuildJoinMode.open;
}
