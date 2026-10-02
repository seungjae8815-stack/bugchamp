import 'dart:convert';

import 'package:core_run/core_run.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'combat_power.dart';
import 'game_server.dart';
import 'providers.dart';
import 'server_sync.dart';
import 'save_controller.dart';

/// 길드 한 줄(목록·내 길드 공용). 서버 `/guild/*` 응답 모양 그대로.
class GuildInfo {
  const GuildInfo({
    required this.id,
    required this.name,
    this.lang = 'ko',
    this.level = 1,
    this.maxMembers = 20,
    this.joinMode = GuildJoinMode.open,
    this.notice = '',
    this.memberCount = 0,
    this.avgPower = 0,
    this.exp = 0,
    this.expNeed = 0,
    this.skills = const {},
    this.pointsLeft = 0,
    this.tier = 'bronze',
  });

  final String id;
  final String name;
  final String lang;
  final int level;
  final int maxMembers;
  final GuildJoinMode joinMode;
  final String notice;
  final int memberCount;
  final double avgPower;

  /// 이번 레벨에서 쌓은 경험치 · 다음 레벨까지(만렙이면 0).
  final int exp;
  final int expNeed;

  /// 길드 버프 스킬 레벨(스킬 id → 레벨).
  final Map<String, int> skills;
  final int pointsLeft;

  /// 길드전 티어(5단계).
  final String tier;

  bool get full => memberCount >= maxMembers;

  factory GuildInfo.fromJson(Map<String, dynamic> j) => GuildInfo(
    id: '${j['id']}',
    name: j['name'] as String? ?? '',
    lang: j['lang'] as String? ?? 'ko',
    level: (j['level'] as num?)?.toInt() ?? 1,
    maxMembers: (j['maxMembers'] as num?)?.toInt() ?? 20,
    joinMode: GuildJoinMode.fromKey(j['joinMode'] as String?),
    notice: j['notice'] as String? ?? '',
    memberCount: (j['memberCount'] as num?)?.toInt() ?? 0,
    avgPower: (j['avgPower'] as num?)?.toDouble() ?? 0,
    exp: (j['exp'] as num?)?.toInt() ?? 0,
    expNeed: (j['expNeed'] as num?)?.toInt() ?? 0,
    skills: {
      for (final e in ((j['skills'] as Map?) ?? const {}).entries)
        '${e.key}': (e.value as num).toInt(),
    },
    pointsLeft: (j['pointsLeft'] as num?)?.toInt() ?? 0,
    tier: j['tier'] as String? ?? 'bronze',
  );
}

/// 상점 품목 + 이번 기간 구매 수.
class GuildShopEntry {
  const GuildShopEntry(this.item, this.bought);
  final GuildShopItem item;
  final int bought;
  bool get soldOut => bought >= item.limit;
}

class GuildMemberInfo {
  const GuildMemberInfo({
    required this.userId,
    required this.role,
    required this.nickname,
    required this.power,
    required this.lastSeen,
    this.badge = '',
  });

  final String userId;
  final GuildRole role;
  final String nickname;
  final double power;
  final DateTime lastSeen;
  final String badge;

  factory GuildMemberInfo.fromJson(Map<String, dynamic> j) => GuildMemberInfo(
    userId: '${j['userId']}',
    role: GuildRole.fromKey(j['role'] as String?),
    nickname: j['nickname'] as String? ?? '',
    power: (j['power'] as num?)?.toDouble() ?? 0,
    lastSeen:
        DateTime.tryParse('${j['lastSeen']}')?.toUtc() ?? DateTime.utc(2000),
    badge: j['badge'] as String? ?? '',
  );
}

class GuildRequestInfo {
  const GuildRequestInfo({
    required this.userId,
    required this.nickname,
    required this.power,
  });

  final String userId;
  final String nickname;
  final double power;

  factory GuildRequestInfo.fromJson(Map<String, dynamic> j) => GuildRequestInfo(
    userId: '${j['userId']}',
    nickname: j['nickname'] as String? ?? '',
    power: (j['power'] as num?)?.toDouble() ?? 0,
  );
}

/// 내 길드 상태. [guild] 가 null 이면 길드 없음.
class GuildView {
  const GuildView({
    this.available = true,
    this.guild,
    this.myRole = GuildRole.member,
    this.members = const [],
    this.requests = const [],
    this.cooldownUntil,
    this.requested = const [],
    this.myCoins = 0,
    this.donatedToday = false,
    this.shop = const [],
  });

  /// 서버 미연결·조회 실패 — 화면은 "잠시 후 다시" 로 보인다.
  const GuildView.unavailable() : this(available: false);

  final bool available;
  final GuildInfo? guild;
  final GuildRole myRole;
  final List<GuildMemberInfo> members;
  final List<GuildRequestInfo> requests;

  /// 스스로 나간 뒤 다른 길드에 들어갈 수 있는 시각(길드가 없을 때만).
  final DateTime? cooldownUntil;

  /// 가입 신청을 넣어 둔 길드 id(승인제).
  final List<String> requested;

  /// 내 길드 코인(서버 소유).
  final int myCoins;
  final bool donatedToday;
  final List<GuildShopEntry> shop;

  factory GuildView.fromJson(Map<String, dynamic> j) {
    final g = j['guild'];
    return GuildView(
      guild: g is Map<String, dynamic> ? GuildInfo.fromJson(g) : null,
      myRole: GuildRole.fromKey(j['myRole'] as String?),
      members: [
        for (final m in (j['members'] as List? ?? const []))
          GuildMemberInfo.fromJson(m as Map<String, dynamic>),
      ],
      requests: [
        for (final r in (j['requests'] as List? ?? const []))
          GuildRequestInfo.fromJson(r as Map<String, dynamic>),
      ],
      cooldownUntil: DateTime.tryParse('${j['cooldownUntil']}')?.toUtc(),
      requested: [
        for (final id in (j['requested'] as List? ?? const [])) '$id',
      ],
      myCoins: (j['myCoins'] as num?)?.toInt() ?? 0,
      donatedToday: j['donatedToday'] == true,
      shop: [
        for (final x in (j['shop'] as List? ?? const []))
          GuildShopEntry(
            GuildShopItem.fromJson(x as Map<String, dynamic>),
            ((x)['bought'] as num?)?.toInt() ?? 0,
          ),
      ],
    );
  }
}

/// 내 길드. **앱 시작 때 한 번**(홈 아이콘이 지켜본다 — 서버가 마지막 접속을 적는다)과
/// 길드 화면을 열 때 [refresh] 로만 조회한다. 화면 밖 폴링은 하지 않는다(요금).
///
/// 액션은 실패하면 서버 오류 코드(`name_taken` 등)를 돌려주고, 성공하면 null.
class GuildController extends AsyncNotifier<GuildView> {
  GameServer get _server => ref.read(gameServerProvider);

  @override
  Future<GuildView> build() async {
    final server = ref.watch(gameServerProvider);
    if (!server.available) return const GuildView.unavailable();
    final r = await server.guildMe();
    if (!r.isOk) return const GuildView.unavailable();
    return _remember(GuildView.fromJson(r.data!));
  }

  Future<void> refresh() async {
    final r = await _server.guildMe();
    if (r.isOk) state = AsyncData(_remember(GuildView.fromJson(r.data!)));
  }

  /// 길드 버프를 기기에 적어 둔다 — 다음 실행의 **오프라인 정산**(길드 조회보다 먼저 돈다)이 쓴다.
  GuildView _remember(GuildView v) {
    final defs = ref.read(gameDataProvider).value?.guildConfig.skills;
    if (v.available && defs != null) {
      GuildBuffCache.save(
        v.guild == null ? const {} : guildBonus(defs, v.guild!.skills),
      );
    }
    return v;
  }

  /// 응답이 `/guild/me` 모양이면 그대로 갈아 끼우고, 아니면(승인제 신청 등) 다시 조회한다.
  Future<String?> _apply(Future<ServerResult> call) async {
    final r = await call;
    if (!r.isOk) return r.error ?? 'network';
    if (r.data!.containsKey('guild')) {
      state = AsyncData(_remember(GuildView.fromJson(r.data!)));
    } else {
      await refresh();
    }
    return null;
  }

  Future<({List<GuildInfo> guilds, List<String> requested})?> search({
    required String lang,
    String query = '',
  }) async {
    final r = await _server.guildList(lang: lang, query: query);
    if (!r.isOk) return null;
    return (
      guilds: [
        for (final g in (r.data!['guilds'] as List? ?? const []))
          GuildInfo.fromJson(g as Map<String, dynamic>),
      ],
      requested: [
        for (final id in (r.data!['requested'] as List? ?? const [])) '$id',
      ],
    );
  }

  /// 개설(젤리). 서버가 서버 세이브에서 먼저 치르고, 성공하면 **같은 금액을 로컬에서 뺀다**
  /// — 젤리는 기기 권위 필드라 서버 잔액을 받지 않는다(결투 티켓 젤리 충전과 같은 방식).
  Future<String?> create({
    required String name,
    required String lang,
    required GuildJoinMode joinMode,
  }) async {
    // 서버는 **자기 저장본**의 젤리로 판정·차감한다 — 먼저 최신 세이브를 올린다(방금 모은 젤리로
    // 잘못 거절되거나, 이미 쓴 젤리로 통과하지 않게).
    final save = ref.read(saveControllerProvider).value;
    if (!await flushSaveBeforeServerAction(_server, save)) return 'network';
    final r = await _server.guildCreate(
      name: name,
      lang: lang,
      joinMode: joinMode.key,
    );
    if (!r.isOk) return r.error ?? 'network';
    final spent = (r.data!['jellySpent'] as num?)?.toInt() ?? 0;
    if (spent > 0) {
      await ref.read(saveControllerProvider.notifier).trySpendJelly(spent);
    }
    state = AsyncData(_remember(GuildView.fromJson(r.data!)));
    return null;
  }

  Future<String?> donate() => _apply(_server.guildDonate());
  Future<String?> skillUp(String skillId) =>
      _apply(_server.guildSkillUp(skillId));
  Future<String?> skillReset() => _apply(_server.guildSkillReset());

  /// 상점 — 먼저 최신 세이브를 올리고(서버가 자기 저장본에 품목을 넣는다) 돌아온 세이브를 채택한다.
  Future<({String? error, Map<String, dynamic> granted})> buy(
    String itemId,
  ) async {
    final save = ref.read(saveControllerProvider).value;
    if (!await flushSaveBeforeServerAction(_server, save)) {
      return (error: 'network', granted: const <String, dynamic>{});
    }
    final r = await _server.guildShopBuy(itemId);
    if (!r.isOk || r.save == null) {
      return (error: r.error ?? 'network', granted: const <String, dynamic>{});
    }
    await ref.read(saveControllerProvider.notifier).adoptServerSave(r.save!);
    state = AsyncData(_remember(GuildView.fromJson(r.data!)));
    return (
      error: null,
      granted: (r.data!['granted'] as Map?)?.cast<String, dynamic>() ?? {},
    );
  }

  Future<String?> join(String guildId) => _apply(_server.guildJoin(guildId));
  Future<String?> cancelRequest(String guildId) =>
      _apply(_server.guildCancelRequest(guildId));
  Future<String?> leave() => _apply(_server.guildLeave());
  Future<String?> kick(String userId) => _apply(_server.guildKick(userId));
  Future<String?> setRole(String userId, GuildRole role) =>
      _apply(_server.guildSetRole(userId, role.key));
  Future<String?> answer(String userId, {required bool accept}) =>
      _apply(_server.guildAnswerRequest(userId, accept: accept));
  Future<String?> settings({String? notice, GuildJoinMode? joinMode}) =>
      _apply(_server.guildSettings(notice: notice, joinMode: joinMode?.key));
}

final guildProvider = AsyncNotifierProvider<GuildController, GuildView>(
  GuildController.new,
);

/// 지금 걸린 길드 버프(stat → 값). 길드가 없거나 모르면 빈 맵.
final guildBonusProvider = Provider<Map<String, double>>((ref) {
  if (!kGuildOpen) return const {};
  final v = ref.watch(guildProvider).value;
  final defs = ref.watch(gameDataProvider).value?.guildConfig.skills;
  if (v == null || !v.available || v.guild == null || defs == null) {
    return GuildBuffCache.bonus;
  }
  return guildBonus(defs, v.guild!.skills);
});

/// 길드 버프 기기 캐시 — 앱 시작 때 [load] 한다. 오프라인 골드 정산이 길드 조회보다 먼저 돌아서
/// 서버 값을 기다릴 수 없다. 기기 권위 루프라 위조해도 얻는 건 골드 상한(서버 `/save`)까지다.
class GuildBuffCache {
  static const _key = 'guild_buff_v1';
  static Map<String, double> bonus = const {};

  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_key);
      if (raw == null) return;
      bonus = {
        for (final e in (jsonDecode(raw) as Map).entries)
          '${e.key}': (e.value as num).toDouble(),
      };
    } catch (_) {
      bonus = const {};
    }
  }

  static void save(Map<String, double> b) {
    bonus = b;
    SharedPreferences.getInstance()
        .then((p) => p.setString(_key, jsonEncode(b)))
        .catchError((_) => false);
  }
}

/// 길드를 열었나(2026-10-02 사장님 — 1.0.15 는 **창만 만들고 "준비 중"**, SQL·서버 점검 뒤에 연다).
/// false 면 길드 서버 호출(`/guild/me`)·길드 버프·길드전 집계 전송을 전부 하지 않는다 —
/// DB 표가 없을 때 앱 시작마다 503 이 찍히던 것도 같이 사라진다.
const bool kGuildOpen = false;

/// 홈 길드 아이콘의 빨간 점 — 관리자인데 가입 신청이 쌓여 있을 때.
final guildHasRequestsProvider = Provider<bool>((ref) {
  if (!kGuildOpen) return false;
  final v = ref.watch(guildProvider).value;
  return v != null && v.myRole.canManage && v.requests.isNotEmpty;
});

// ── 길드 미션(2단계) ─────────────────────────────────────────────────

/// 진행 중·끝난 미션 한 건(내 길드).
class GuildMissionInfo {
  const GuildMissionInfo({
    required this.id,
    required this.ownerNick,
    required this.mine,
    required this.kind,
    required this.mult,
    required this.need,
    required this.total,
    required this.endsAt,
    required this.settled,
    required this.success,
    required this.ratio,
    required this.helpers,
    required this.helped,
    required this.helperMax,
  });

  final String id;
  final String ownerNick;
  final bool mine;
  final String kind;
  final double mult;
  final double need;
  final double total;
  final DateTime endsAt;
  final bool settled;
  final bool success;
  final double ratio;
  final List<String> helpers;
  final bool helped;
  final int helperMax;

  double get progress => need <= 0 ? 1 : (total / need).clamp(0.0, 1.0);

  factory GuildMissionInfo.fromJson(Map<String, dynamic> j) => GuildMissionInfo(
    id: '${j['id']}',
    ownerNick: j['ownerNick'] as String? ?? '',
    mine: j['mine'] == true,
    kind: j['kind'] as String? ?? '',
    mult: (j['mult'] as num?)?.toDouble() ?? 1,
    need: (j['need'] as num?)?.toDouble() ?? 0,
    total: (j['total'] as num?)?.toDouble() ?? 0,
    endsAt: DateTime.tryParse('${j['endsAt']}')?.toUtc() ?? DateTime.utc(2000),
    settled: j['settled'] == true,
    success: j['success'] == true,
    ratio: (j['ratio'] as num?)?.toDouble() ?? 0,
    helpers: [
      for (final h in (j['helpers'] as List? ?? const []))
        '${(h as Map)['nickname'] ?? ''}',
    ],
    helped: j['helped'] == true,
    helperMax: (j['helperMax'] as num?)?.toInt() ?? 3,
  );
}

/// 미션 탭 전체.
class GuildMissionsView {
  const GuildMissionsView({
    this.available = true,
    this.board = const [],
    this.startsLeft = 0,
    this.helpRewardsLeft = 0,
    this.active = const [],
    this.recent = const [],
    this.claimable = 0,
    this.claimReward = const GuildMissionReward(),
    this.nextDayAt,
    this.serverOffset = Duration.zero,
  });

  const GuildMissionsView.unavailable() : this(available: false);

  final bool available;
  final List<GuildMissionSlot> board;
  final int startsLeft;
  final int helpRewardsLeft;
  final List<GuildMissionInfo> active;
  final List<GuildMissionInfo> recent;

  /// 받을 수 있는 미션 수와 그 합.
  final int claimable;
  final GuildMissionReward claimReward;
  final DateTime? nextDayAt;

  /// 서버 시각 − 기기 시각. 남은 시간은 서버 시각으로 잰다(기기 시계가 틀려도 맞게).
  final Duration serverOffset;

  bool get hasRunning => active.any((m) => m.mine);

  factory GuildMissionsView.fromJson(
    Map<String, dynamic> j,
    DateTime deviceNow,
  ) {
    final c = (j['claimable'] as Map?)?.cast<String, dynamic>() ?? const {};
    int n(String k) => (c[k] as num?)?.toInt() ?? 0;
    final serverNow = DateTime.tryParse('${j['now']}')?.toUtc();
    return GuildMissionsView(
      board: [
        for (final b in (j['board'] as List? ?? const []))
          GuildMissionSlot(
            slot: ((b as Map)['slot'] as num).toInt(),
            kind: '${b['kind']}',
            mult: (b['mult'] as num).toDouble(),
          ),
      ],
      startsLeft: (j['startsLeft'] as num?)?.toInt() ?? 0,
      helpRewardsLeft: (j['helpRewardsLeft'] as num?)?.toInt() ?? 0,
      active: [
        for (final m in (j['active'] as List? ?? const []))
          GuildMissionInfo.fromJson(m as Map<String, dynamic>),
      ],
      recent: [
        for (final m in (j['recent'] as List? ?? const []))
          GuildMissionInfo.fromJson(m as Map<String, dynamic>),
      ],
      claimable: n('missions'),
      claimReward: GuildMissionReward(
        chitin: n('chitin'),
        mineral: n('mineral'),
        sap: n('sap'),
        fossil: n('fossil'),
        coins: n('coins'),
      ),
      nextDayAt: DateTime.tryParse('${j['nextDayAt']}')?.toUtc(),
      serverOffset: serverNow == null
          ? Duration.zero
          : serverNow.difference(deviceNow.toUtc()),
    );
  }
}

/// 미션 탭. 탭을 **보고 있을 때만** 화면이 [refresh] 를 주기적으로 부른다.
class GuildMissionController extends AsyncNotifier<GuildMissionsView> {
  GameServer get _server => ref.read(gameServerProvider);

  DateTime get _now => ref.read(clockProvider).now().toUtc();

  @override
  Future<GuildMissionsView> build() async {
    final server = ref.watch(gameServerProvider);
    if (!server.available) return const GuildMissionsView.unavailable();
    final r = await server.guildMissions();
    return r.isOk
        ? GuildMissionsView.fromJson(r.data!, _now)
        : const GuildMissionsView.unavailable();
  }

  Future<void> refresh() async {
    final r = await _server.guildMissions();
    if (r.isOk) state = AsyncData(GuildMissionsView.fromJson(r.data!, _now));
  }

  /// 내 전투력(홈 상단 값). 모르면 0 — 서버가 1 로 본다.
  double _power() {
    final save = ref.read(saveControllerProvider).value;
    final data = ref.read(gameDataProvider).value;
    if (save == null) return 0;
    return displayCombatPower(save, data, _now) ?? 0;
  }

  Future<String?> _apply(Future<ServerResult> call) async {
    final r = await call;
    if (!r.isOk) return r.error ?? 'network';
    state = AsyncData(GuildMissionsView.fromJson(r.data!, _now));
    return null;
  }

  Future<String?> start(int slot, int waitSec) => _apply(
    _server.guildMissionStart(slot: slot, waitSec: waitSec, power: _power()),
  );

  Future<String?> help(String missionId) =>
      _apply(_server.guildMissionHelp(missionId, power: _power()));

  /// 보상 받기 — **먼저 최신 세이브를 올리고**(서버는 자기 저장본에 보상을 얹어 돌려준다),
  /// 돌아온 세이브를 채택한다(우편 수령과 같은 순서). 성공하면 받은 양, 실패하면 오류 코드.
  Future<({String? error, GuildMissionReward reward, int eggs})> claim() async {
    const none = GuildMissionReward();
    final save = ref.read(saveControllerProvider).value;
    if (!await flushSaveBeforeServerAction(_server, save)) {
      return (error: 'network', reward: none, eggs: 0);
    }
    final r = await _server.guildMissionClaim();
    if (!r.isOk || r.save == null) {
      return (error: r.error ?? 'network', reward: none, eggs: 0);
    }
    await ref.read(saveControllerProvider.notifier).adoptServerSave(r.save!);
    final g = (r.data!['granted'] as Map?)?.cast<String, dynamic>() ?? const {};
    int n(String k) => (g[k] as num?)?.toInt() ?? 0;
    await refresh();
    return (
      error: null,
      reward: GuildMissionReward(
        chitin: n('chitin'),
        mineral: n('mineral'),
        sap: n('sap'),
        fossil: n('fossil'),
        coins: n('coins'),
      ),
      eggs: n('eggs'),
    );
  }
}

/// 자동 폐기하지 않는다 — 길드 채팅의 "도와주기" 카드도 이걸 쓴다. 스스로 조회하지는 않으므로
/// 살려 둬도 요금이 들지 않는다(주기 조회는 미션 탭이 보일 때만 화면이 한다).
final guildMissionProvider =
    AsyncNotifierProvider<GuildMissionController, GuildMissionsView>(
      GuildMissionController.new,
    );

// ── 길드 보스(4단계) ────────────────────────────────────────────────

class GuildBossView {
  const GuildBossView({
    this.available = true,
    this.stage = 1,
    this.hpMax = 1,
    this.hpLeft = 1,
    this.attacksLeft = 0,
    this.myDamage = 0,
    this.rank,
    this.top = const [],
    this.hasTeam = true,
    this.lastRank,
    this.lastJelly = 0,
    this.lastClaimed = true,
    this.endsAt,
  });

  const GuildBossView.unavailable() : this(available: false);

  final bool available;
  final int stage;
  final double hpMax;
  final double hpLeft;
  final int attacksLeft;
  final double myDamage;
  final int? rank;
  final List<({int rank, String name, int stage, double progress})> top;

  /// 결투 방어팀이 있나(없으면 공격 불가).
  final bool hasTeam;
  final int? lastRank;
  final int lastJelly;
  final bool lastClaimed;
  final DateTime? endsAt;

  double get progress => hpMax <= 0 ? 0 : (1 - hpLeft / hpMax).clamp(0.0, 1.0);
  bool get canClaimLast => lastJelly > 0 && !lastClaimed;

  factory GuildBossView.fromJson(Map<String, dynamic> j) {
    final last = (j['lastWeek'] as Map?)?.cast<String, dynamic>();
    return GuildBossView(
      stage: (j['stage'] as num?)?.toInt() ?? 1,
      hpMax: (j['hpMax'] as num?)?.toDouble() ?? 1,
      hpLeft: (j['hpLeft'] as num?)?.toDouble() ?? 1,
      attacksLeft: (j['attacksLeft'] as num?)?.toInt() ?? 0,
      myDamage: (j['myDamage'] as num?)?.toDouble() ?? 0,
      rank: (j['rank'] as num?)?.toInt(),
      top: [
        for (final r in (j['top'] as List? ?? const []))
          (
            rank: ((r as Map)['rank'] as num).toInt(),
            name: '${r['name'] ?? ''}',
            stage: (r['stage'] as num?)?.toInt() ?? 1,
            progress: (r['progress'] as num?)?.toDouble() ?? 0,
          ),
      ],
      hasTeam: j['hasTeam'] != false,
      lastRank: (last?['rank'] as num?)?.toInt(),
      lastJelly: (last?['jelly'] as num?)?.toInt() ?? 0,
      lastClaimed: last == null || last['claimed'] == true,
      endsAt: DateTime.tryParse('${j['endsAt']}')?.toUtc(),
    );
  }
}

/// 길드 보스 탭. 스스로 주기 조회하지 않는다(탭을 열 때·공격 뒤에만).
class GuildBossController extends AsyncNotifier<GuildBossView> {
  GameServer get _server => ref.read(gameServerProvider);

  @override
  Future<GuildBossView> build() async {
    final server = ref.watch(gameServerProvider);
    if (!server.available) return const GuildBossView.unavailable();
    final r = await server.guildBoss();
    return r.isOk
        ? GuildBossView.fromJson(r.data!)
        : const GuildBossView.unavailable();
  }

  Future<void> refresh() async {
    final r = await _server.guildBoss();
    if (r.isOk) state = AsyncData(GuildBossView.fromJson(r.data!));
  }

  /// 공격 — 성공하면 (피해, 받은 코인, 처치 여부), 실패하면 오류 코드.
  Future<({String? error, double damage, int coins, bool killed})>
  attack() async {
    final r = await _server.guildBossAttack();
    if (!r.isOk) {
      return (
        error: r.error ?? 'network',
        damage: 0.0,
        coins: 0,
        killed: false,
      );
    }
    state = AsyncData(GuildBossView.fromJson(r.data!));
    final h = (r.data!['hit'] as Map?)?.cast<String, dynamic>() ?? const {};
    // 공격이 길드 코인·경험치를 바꿨다 — 머리 줄을 다시 받는다.
    ref.read(guildProvider.notifier).refresh();
    return (
      error: null,
      damage: (h['damage'] as num?)?.toDouble() ?? 0,
      coins: (h['coins'] as num?)?.toInt() ?? 0,
      killed: ((h['killed'] as num?)?.toInt() ?? 0) > 0,
    );
  }

  /// 지난주 순위 젤리 — 먼저 최신 세이브를 올리고 돌아온 세이브를 채택한다.
  Future<({String? error, int jelly})> claim() async {
    final save = ref.read(saveControllerProvider).value;
    if (!await flushSaveBeforeServerAction(_server, save)) {
      return (error: 'network', jelly: 0);
    }
    final r = await _server.guildBossClaim();
    if (!r.isOk || r.save == null) {
      return (error: r.error ?? 'network', jelly: 0);
    }
    await ref.read(saveControllerProvider.notifier).adoptServerSave(r.save!);
    await refresh();
    return (error: null, jelly: (r.data!['jelly'] as num?)?.toInt() ?? 0);
  }
}

final guildBossProvider =
    AsyncNotifierProvider<GuildBossController, GuildBossView>(
      GuildBossController.new,
    );

// ── 길드전 활동 집계(5단계) ──────────────────────────────────────────

/// 길드전 1~6일차 **앱이 세는** 행동(짝짓기 완료·부화·합성·제련·정예·사냥터 클리어·수련·훈련·스킬 수련).
///
/// 그날(KST 09시 경계) 누적 수를 기기에 적어 두고, 바뀌었으면 **60초 세이브 업로드 본문 옆칸**으로 보낸다
/// (`/save` 의 `guildTally` — 새 요청을 만들지 않는다, 요금). 서버가 그날 주제에 맞는 것만 세고 멤버 하루
/// 상한으로 자른다 — 위조해도 얻는 최대치가 상한이다. 결투·보스는 서버가 확정 결과로 센다.
/// ⚠️ 젤리로 당긴 완료는 **부르지 않는다**(돈이 길드전 점수가 되지 않게, §0-2).
class GuildWarTally {
  static const _key = 'guild_war_tally_v1';
  static String _day = '';
  static Map<String, int> _counts = {};
  static bool _dirty = false;

  /// 젤리로 즉시 부화한 알(수령해도 세지 않는다). 기기 메모리 — 재시작하면 잊는다(드문 경우라 허용).
  static final Set<String> rushed = {};

  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_key);
      if (raw == null) return;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      _day = '${j['day']}';
      _counts = {
        for (final e in ((j['counts'] as Map?) ?? const {}).entries)
          '${e.key}': (e.value as num).toInt(),
      };
    } catch (_) {}
  }

  static void _roll(DateTime now) {
    final d = guildDayKey(now);
    if (d != _day) {
      _day = d;
      _counts = {};
    }
  }

  /// 행동 [n] 번. [now] 는 주입 시계(UTC).
  static void add(String action, DateTime now, [int n = 1]) {
    if (n <= 0) return;
    _roll(now);
    _counts[action] = (_counts[action] ?? 0) + n;
    _dirty = true;
    final body = jsonEncode({'day': _day, 'counts': _counts});
    SharedPreferences.getInstance()
        .then((p) => p.setString(_key, body))
        .catchError((_) => false);
  }

  /// 업로드에 실을 값(바뀐 게 없으면 null — 서버가 길드를 조회하지 않게).
  static Map<String, dynamic>? payload(DateTime now) {
    _roll(now);
    if (!_dirty || _counts.isEmpty) return null;
    return {'day': _day, 'counts': Map<String, int>.from(_counts)};
  }

  /// 업로드가 성공했으면 부른다.
  static void sent() => _dirty = false;

  /// 테스트용.
  static void reset() {
    _day = '';
    _counts = {};
    _dirty = false;
  }
}

// ── 길드전 화면(5단계) ───────────────────────────────────────────────

class GuildWarReward {
  const GuildWarReward({
    required this.won,
    required this.eligible,
    required this.coins,
    required this.jelly,
    required this.claimed,
  });
  final bool won;
  final bool eligible;
  final int coins;
  final int jelly;
  final bool claimed;
  bool get claimable => eligible && !claimed;

  static GuildWarReward? fromJson(Object? j) {
    if (j is! Map) return null;
    return GuildWarReward(
      won: j['won'] == true,
      eligible: j['eligible'] == true,
      coins: (j['coins'] as num?)?.toInt() ?? 0,
      jelly: (j['jelly'] as num?)?.toInt() ?? 0,
      claimed: j['claimed'] == true,
    );
  }
}

class GuildWarView {
  const GuildWarView({
    this.available = true,
    this.open = false,
    this.startWeek = '',
    this.tier = 'bronze',
    this.gr = 0,
    this.day = 0,
    this.theme,
    this.cap = 0,
    this.myToday = 0,
    this.hasMatch = false,
    this.minMembers = 5,
    this.opponent,
    this.virtual = false,
    this.mine = const [],
    this.theirs = const [],
    this.result,
    this.reward,
    this.lastWeek,
    this.endsAt,
  });

  const GuildWarView.unavailable() : this(available: false);

  final bool available;
  final bool open;
  final String startWeek;
  final String tier;
  final int gr;
  final int day;
  final String? theme;
  final int cap;
  final int myToday;
  final bool hasMatch;
  final int minMembers;
  final String? opponent;
  final bool virtual;
  final List<int> mine;
  final List<int> theirs;
  final Map<String, dynamic>? result;
  final GuildWarReward? reward;
  final GuildWarReward? lastWeek;
  final DateTime? endsAt;

  /// 지금 받을 수 있는 보상(이번 주 → 지난주 순).
  GuildWarReward? get claimable => (reward?.claimable ?? false)
      ? reward
      : ((lastWeek?.claimable ?? false) ? lastWeek : null);

  factory GuildWarView.fromJson(Map<String, dynamic> j) {
    final m = (j['match'] as Map?)?.cast<String, dynamic>();
    List<int> ints(Object? x) => [
      for (final v in (x as List? ?? const [])) (v as num).toInt(),
    ];
    return GuildWarView(
      open: j['open'] == true,
      startWeek: j['startWeek'] as String? ?? '',
      tier: j['tier'] as String? ?? 'bronze',
      gr: (j['gr'] as num?)?.toInt() ?? 0,
      day: (j['day'] as num?)?.toInt() ?? 0,
      theme: j['theme'] as String?,
      cap: (j['cap'] as num?)?.toInt() ?? 0,
      myToday: (j['myToday'] as num?)?.toInt() ?? 0,
      hasMatch: m != null,
      minMembers: (j['minMembers'] as num?)?.toInt() ?? 5,
      opponent: m?['opponent'] as String?,
      virtual: m?['virtual'] == true,
      mine: ints(m?['mine']),
      theirs: ints(m?['theirs']),
      result: (j['result'] as Map?)?.cast<String, dynamic>(),
      reward: GuildWarReward.fromJson(j['reward']),
      lastWeek: GuildWarReward.fromJson(j['lastWeek']),
      endsAt: DateTime.tryParse('${j['endsAt']}')?.toUtc(),
    );
  }
}

class GuildWarController extends AsyncNotifier<GuildWarView> {
  GameServer get _server => ref.read(gameServerProvider);

  @override
  Future<GuildWarView> build() async {
    final server = ref.watch(gameServerProvider);
    if (!server.available) return const GuildWarView.unavailable();
    final r = await server.guildWar();
    return r.isOk
        ? GuildWarView.fromJson(r.data!)
        : const GuildWarView.unavailable();
  }

  Future<void> refresh() async {
    final r = await _server.guildWar();
    if (r.isOk) state = AsyncData(GuildWarView.fromJson(r.data!));
  }

  /// 보상 받기 — 먼저 최신 세이브를 올리고 돌아온 세이브를 채택한다.
  Future<({String? error, int jelly, int coins})> claim() async {
    final save = ref.read(saveControllerProvider).value;
    if (!await flushSaveBeforeServerAction(_server, save)) {
      return (error: 'network', jelly: 0, coins: 0);
    }
    final r = await _server.guildWarClaim();
    if (!r.isOk || r.save == null) {
      return (error: r.error ?? 'network', jelly: 0, coins: 0);
    }
    await ref.read(saveControllerProvider.notifier).adoptServerSave(r.save!);
    await refresh();
    ref.read(guildProvider.notifier).refresh();
    return (
      error: null,
      jelly: (r.data!['jelly'] as num?)?.toInt() ?? 0,
      coins: (r.data!['coins'] as num?)?.toInt() ?? 0,
    );
  }
}

final guildWarProvider =
    AsyncNotifierProvider<GuildWarController, GuildWarView>(
      GuildWarController.new,
    );
