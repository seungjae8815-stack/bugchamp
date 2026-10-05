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
    this.memberRanks = kDefaultGuildMemberRanks,
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

  /// 멤버 등급(기여도 자동 · 표시 전용) — [guildMemberRank].
  final List<GuildMemberRankDef> memberRanks;

  /// [war] 만 바꾼 사본(서버가 환경변수로 길드전 첫 주를 덮을 때).
  GuildConfig withWar(GuildWarConfig war) => GuildConfig(
    maxMembers: maxMembers,
    createJellyCost: createJellyCost,
    nameMinLength: nameMinLength,
    nameMaxLength: nameMaxLength,
    noticeMaxLength: noticeMaxLength,
    rejoinCooldownHours: rejoinCooldownHours,
    deputyMax: deputyMax,
    leaderInactiveDays: leaderInactiveDays,
    listLimit: listLimit,
    maxPendingRequests: maxPendingRequests,
    requestLimit: requestLimit,
    mission: mission,
    level: level,
    donateExp: donateExp,
    donateCoins: donateCoins,
    skills: skills,
    shop: shop,
    boss: boss,
    war: war,
    memberRanks: memberRanks,
  );

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
      memberRanks: [
        for (final x in (j['memberRanks'] as List? ?? const []))
          GuildMemberRankDef.fromJson(x as Map<String, dynamic>),
      ].where((r) => r.id.isNotEmpty).toList().orDefaultRanks(),
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

  /// 직책 권한(2026-10-05 사장님 확정, docs/design_guild.md §1). 길드장만 추방·설정·스킬·임명을 한다.
  /// 부길드장은 길드장이 켠 경우([deputyCanAccept], 기본 켜짐)에만 가입 신청을 수락·거절한다.
  /// 앱(버튼 표시)과 서버(검사)가 같은 함수를 본다.
  bool canAnswerRequests({required bool deputyCanAccept}) =>
      this == GuildRole.leader || (this == GuildRole.deputy && deputyCanAccept);

  /// 추방(길드장 → 부길드장·멤버).
  bool get canKick => this == GuildRole.leader;

  /// 공지·소개·가입 방식·부길드장 수락 허용 스위치.
  bool get canEditSettings => this == GuildRole.leader;

  /// 길드 스킬 찍기·초기화.
  bool get canEditSkills => this == GuildRole.leader;

  /// 직책 임명·위임.
  bool get canAssignRoles => this == GuildRole.leader;
}

/// 멤버 등급 한 단계(`guild.json → memberRanks`) — 그 길드에서 번 코인 누적(기여도)이 [min] 이상.
/// **표시 전용**이다(혜택·권한 없음, 2026-10-05 사장님 확정).
@immutable
class GuildMemberRankDef {
  const GuildMemberRankDef(this.id, this.min);

  final String id;
  final int min;

  factory GuildMemberRankDef.fromJson(Map<String, dynamic> j) =>
      GuildMemberRankDef(
        j['id'] as String? ?? '',
        (j['min'] as num?)?.toInt() ?? 0,
      );
}

/// 기본 등급표(JSON 이 비었을 때) — 새내기 · 일꾼 · 정예 · 원로.
const kDefaultGuildMemberRanks = [
  GuildMemberRankDef('rookie', 0),
  GuildMemberRankDef('worker', 500),
  GuildMemberRankDef('elite', 3000),
  GuildMemberRankDef('elder', 10000),
];

/// 기여도 → (지금 등급, 다음 등급 또는 null). 앱·서버 공용(새 DB 칸 없이 파생값).
/// [ranks] 는 순서와 상관없이 [GuildMemberRankDef.min] 으로 정렬해 본다.
({GuildMemberRankDef rank, GuildMemberRankDef? next}) guildMemberRank(
  List<GuildMemberRankDef> ranks,
  int contribution,
) {
  final list = [...(ranks.isEmpty ? kDefaultGuildMemberRanks : ranks)]
    ..sort((a, b) => a.min.compareTo(b.min));
  var i = 0;
  for (var k = 0; k < list.length; k++) {
    if (contribution >= list[k].min) i = k;
  }
  return (rank: list[i], next: i + 1 < list.length ? list[i + 1] : null);
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

/// 길드 문장 수(그림 `assets/images/ui/guild/emblem_01`~`emblem_10`, DB `guilds.emblem` check 1~10).
/// 그림 개수에 묶인 **구조 상수**다 — 늘리면 그림·SQL check 를 함께 바꾼다.
const kGuildEmblemCount = 10;

/// 길드장이 고를 수 있는 문장 번호인가(1~[kGuildEmblemCount]).
bool guildEmblemValid(int emblem) => emblem >= 1 && emblem <= kGuildEmblemCount;

/// 문장을 고른 적 없는 길드(옛 길드 · SQL 적용 전)의 기본 문장 — 길드 id 의 간단한 해시.
/// `String.hashCode` 는 플랫폼·버전 사이 같음을 보장하지 않아 직접 센다(같은 길드는 어디서나 같은 문장).
int guildDefaultEmblem(String guildId) {
  var h = 0;
  for (final c in guildId.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return h % kGuildEmblemCount + 1;
}

/// 보여 줄 문장 — 고른 값이 유효하면 그것, 아니면 [guildDefaultEmblem].
int guildEmblemOf(String guildId, int? emblem) =>
    emblem != null && guildEmblemValid(emblem)
    ? emblem
    : guildDefaultEmblem(guildId);

extension on List<GuildMemberRankDef> {
  List<GuildMemberRankDef> orDefaultRanks() =>
      isEmpty ? kDefaultGuildMemberRanks : this;
}
