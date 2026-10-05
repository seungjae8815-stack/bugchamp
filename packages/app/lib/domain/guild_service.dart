import 'dart:async';
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
    this.deputyCanAccept = true,
    this.emblem,
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

  /// 부길드장이 가입 신청을 수락·거절할 수 있는지(길드장 스위치, 기본 켜짐).
  final bool deputyCanAccept;

  /// 길드장이 고른 문장(1~10). null = 고른 적 없음(옛 길드 · 서버 SQL 적용 전).
  final int? emblem;

  /// 화면에 보일 문장 — 고른 값, 없으면 길드 id 해시로 정한 기본 문장(늘 같은 그림).
  int get emblemShown => guildEmblemOf(id, emblem);

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
    deputyCanAccept: j['deputyCanAccept'] as bool? ?? true,
    emblem: (j['emblem'] as num?)?.toInt(),
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
    this.contribution = 0,
  });

  final String userId;
  final GuildRole role;
  final String nickname;
  final double power;
  final DateTime lastSeen;
  final String badge;

  /// 이 길드에서 번 코인 누적 — 멤버 등급([guildMemberRank])의 근거.
  final int contribution;

  factory GuildMemberInfo.fromJson(Map<String, dynamic> j) => GuildMemberInfo(
    userId: '${j['userId']}',
    role: GuildRole.fromKey(j['role'] as String?),
    nickname: j['nickname'] as String? ?? '',
    power: (j['power'] as num?)?.toDouble() ?? 0,
    lastSeen:
        DateTime.tryParse('${j['lastSeen']}')?.toUtc() ?? DateTime.utc(2000),
    badge: j['badge'] as String? ?? '',
    contribution: (j['contribution'] as num?)?.toInt() ?? 0,
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

  /// 가입 신청을 수락·거절할 수 있나(길드장 · 스위치가 켜진 부길드장). 서버와 같은 함수.
  bool get canAnswerRequests =>
      myRole.canAnswerRequests(deputyCanAccept: guild?.deputyCanAccept ?? true);

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

/// 내 길드. **앱 시작 때 한 번**(이 provider 의 build — 하단 길드 아이콘의 가입 신청 빨간 점과
/// 길드 버프가 지켜본다. 서버가 마지막 접속을 적고, 오프라인 골드용 버프 캐시도 이때 채운다)과
/// 하단 길드 탭에 들어올 때·길드 탭에서 앱으로 돌아올 때 [refreshIfStale] 로만 조회한다.
/// 화면 밖 폴링은 하지 않는다(요금).
///
/// 액션은 실패하면 서버 오류 코드(`name_taken` 등)를 돌려주고, 성공하면 null.
class GuildController extends AsyncNotifier<GuildView> {
  GameServer get _server => ref.read(gameServerProvider);

  /// 마지막으로 서버에서 받은 시각(기기 시계 — 조회 간격만 잰다).
  DateTime? _fetchedAt;

  @override
  Future<GuildView> build() async {
    final server = ref.watch(gameServerProvider);
    if (!server.available) return const GuildView.unavailable();
    final r = await server.guildMe();
    if (!r.isOk) return const GuildView.unavailable();
    _fetchedAt = DateTime.now();
    return _remember(GuildView.fromJson(r.data!));
  }

  Future<void> refresh() async {
    final r = await _server.guildMe();
    if (r.isOk) {
      _fetchedAt = DateTime.now();
      state = AsyncData(_remember(GuildView.fromJson(r.data!)));
    }
  }

  /// 방금([minGap] 안에) 받았으면 건너뛴다 — 탭을 빠르게 오가거나 앱을 잠깐 내렸다 올려도
  /// 조회가 쌓이지 않게. 첫 조회(build)가 아직 진행 중이면 그 결과를 쓴다.
  Future<void> refreshIfStale({
    Duration minGap = const Duration(seconds: 15),
  }) async {
    final at = _fetchedAt;
    if (at == null && state.isLoading) return;
    if (at != null && DateTime.now().difference(at) < minGap) return;
    return refresh();
  }

  /// 길드 버프를 기기에 적어 둔다 — 다음 실행의 **오프라인 정산**(길드 조회보다 먼저 돈다)이 쓴다.
  GuildView _remember(GuildView v) {
    final defs = ref.read(gameDataProvider).value?.guildConfig.skills;
    if (v.available) GuildWarTally.inGuild = v.guild != null;
    if (v.available && defs != null) {
      GuildBuffCache.save(
        v.guild == null ? const {} : guildBonus(defs, v.guild!.skills),
      );
    }
    return v;
  }

  /// 응답이 `/guild/me` 모양이면 그대로 갈아 끼우고, 아니면(승인제 신청 등) 다시 조회한다.
  /// 실패 코드가 "화면의 길드 상태가 낡았다"는 뜻이면(그 사이 추방·해산·다른 기기에서 가입) 다시 받는다.
  Future<String?> _apply(Future<ServerResult> call) async {
    final r = await call;
    if (!r.isOk) {
      final code = r.error ?? 'network';
      if (guildStateStale(code)) unawaited(refresh());
      return code;
    }
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
    int? emblem,
  }) async {
    // 서버는 **자기 저장본**의 젤리로 판정·차감한다 — 먼저 최신 세이브를 올린다(방금 모은 젤리로
    // 잘못 거절되거나, 이미 쓴 젤리로 통과하지 않게).
    // 올리기 → 개설 → 젤리 차감(필요하면 채택)을 한 줄로 돈다([withServerSaveLock]).
    final ctrl = ref.read(saveControllerProvider.notifier);
    final r = await withServerSaveLock(() async {
      if (!await flushSaveBeforeServerAction(_server, () => ctrl.latestSave)) {
        return null;
      }
      final r = await _server.guildCreate(
        name: name,
        lang: lang,
        joinMode: joinMode.key,
        emblem: emblem,
      );
      if (!r.isOk) return r;
      final spent = (r.data!['jellySpent'] as num?)?.toInt() ?? 0;
      if (spent > 0 && !await ctrl.trySpendJelly(spent)) {
        // 올린 뒤 그 사이 젤리를 써서 로컬 잔액이 모자라다 — 서버는 이미 치렀다.
        // 로컬을 그대로 두면 공짜 길드가 되고 다음 업로드가 서버 차감을 덮는다(젤리는 기기 권위).
        // 서버 세이브(차감 반영본)를 받아 채택한다 — 이 순간은 서버가 진실이다.
        final st = await _server.fetchState();
        final sv = st.save;
        if (st.isOk && sv != null) await ctrl.adoptServerSave(sv);
      }
      return r;
    });
    if (r == null) return 'network';
    if (!r.isOk) {
      final code = r.error ?? 'network';
      if (guildStateStale(code)) unawaited(refresh());
      return code;
    }
    _fetchedAt = DateTime.now();
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
    // 올리기 → 서버 행동 → 채택을 한 줄로 돈다([withServerSaveLock]).
    final ctrl = ref.read(saveControllerProvider.notifier);
    final r = await withServerSaveLock(() async {
      if (!await flushSaveBeforeServerAction(_server, () => ctrl.latestSave)) {
        return null;
      }
      final r = await _server.guildShopBuy(itemId);
      if (r.isOk && r.save != null) await ctrl.adoptServerSave(r.save!);
      return r;
    });
    if (r == null) {
      return (error: 'network', granted: const <String, dynamic>{});
    }
    if (!r.isOk || r.save == null) {
      return (error: r.error ?? 'network', granted: const <String, dynamic>{});
    }
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
  Future<String?> settings({
    String? notice,
    GuildJoinMode? joinMode,
    bool? deputyCanAccept,
    int? emblem,
  }) => _apply(
    _server.guildSettings(
      notice: notice,
      joinMode: joinMode?.key,
      deputyCanAccept: deputyCanAccept,
      emblem: emblem,
    ),
  );
}

final guildProvider = AsyncNotifierProvider<GuildController, GuildView>(
  GuildController.new,
);

/// 이 오류 코드가 오면 화면의 길드 상태가 낡았다 — 다시 조회한다.
bool guildStateStale(String code) =>
    code == 'not_in_guild' ||
    code == 'already_in_guild' ||
    code == 'guild_not_found';

/// 로그아웃·계정 전환·계정 삭제 — 이전 계정의 길드 상태·버프 캐시·활동 집계를 잊는다.
/// (버프 캐시를 남기면 새 계정의 오프라인 골드에 이전 계정의 길드 버프가 붙는다.)
void forgetGuildSession(WidgetRef ref) {
  GuildBuffCache.save(const {});
  GuildWarTally.reset();
  ref.invalidate(guildProvider);
  ref.invalidate(guildMissionProvider);
  ref.invalidate(guildBossProvider);
  ref.invalidate(guildWarProvider);
}

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
/// 기본은 닫힘. 테스트 빌드는 `--dart-define=GUILD_OPEN=true`, 출시 때는 `true` 로 바꾼다.
const bool kGuildOpen = bool.fromEnvironment('GUILD_OPEN');

/// 홈 길드 아이콘의 빨간 점 — 신청을 받을 수 있는 사람인데 가입 신청이 쌓여 있을 때.
final guildHasRequestsProvider = Provider<bool>((ref) {
  if (!kGuildOpen) return false;
  final v = ref.watch(guildProvider).value;
  return v != null && v.canAnswerRequests && v.requests.isNotEmpty;
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

  /// 마지막으로 받은 시각(조회 간격만 잰다).
  DateTime? _fetchedAt;

  @override
  Future<GuildMissionsView> build() async {
    final server = ref.watch(gameServerProvider);
    if (!server.available) return const GuildMissionsView.unavailable();
    final r = await server.guildMissions();
    if (!r.isOk) return const GuildMissionsView.unavailable();
    _fetchedAt = DateTime.now();
    return GuildMissionsView.fromJson(r.data!, _now);
  }

  Future<void> refresh() async {
    final r = await _server.guildMissions();
    if (r.isOk) {
      _fetchedAt = DateTime.now();
      state = AsyncData(GuildMissionsView.fromJson(r.data!, _now));
    } else if (guildStateStale(r.error ?? '')) {
      unawaited(ref.read(guildProvider.notifier).refresh());
    }
  }

  /// 방금 받았으면(탭을 처음 열 때 build 가 막 받아 왔으면) 건너뛴다.
  Future<void> refreshIfStale({
    Duration minGap = const Duration(seconds: 3),
  }) async {
    final at = _fetchedAt;
    if (at == null && state.isLoading) return;
    if (at != null && DateTime.now().difference(at) < minGap) return;
    return refresh();
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
    if (!r.isOk) {
      final code = r.error ?? 'network';
      if (guildStateStale(code)) {
        unawaited(ref.read(guildProvider.notifier).refresh());
      }
      return code;
    }
    _fetchedAt = DateTime.now();
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
    // 올리기 → 서버 행동 → 채택을 한 줄로 돈다([withServerSaveLock]).
    final ctrl = ref.read(saveControllerProvider.notifier);
    final r = await withServerSaveLock(() async {
      if (!await flushSaveBeforeServerAction(_server, () => ctrl.latestSave)) {
        return null;
      }
      final r = await _server.guildMissionClaim();
      if (r.isOk && r.save != null) await ctrl.adoptServerSave(r.save!);
      return r;
    });
    if (r == null) {
      return (error: 'network', reward: none, eggs: 0);
    }
    if (!r.isOk || r.save == null) {
      return (error: r.error ?? 'network', reward: none, eggs: 0);
    }
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
/// 살려 둬도 요금이 들지 않는다(주기 조회는 하단 길드 탭 · 미션 탭 · 앱 전면일 때만 화면이 한다).
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

  /// 순위표 — [emblem] 은 보일 문장(서버 값이 없으면 길드 id 해시).
  final List<({int rank, String name, int stage, double progress, int emblem})>
  top;

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
            emblem: guildEmblemOf(
              '${r['guild_id'] ?? r['name'] ?? ''}',
              (r['emblem'] as num?)?.toInt(),
            ),
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
      if (guildStateStale(r.error ?? '')) {
        unawaited(ref.read(guildProvider.notifier).refresh());
      }
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
    // 올리기 → 서버 행동 → 채택을 한 줄로 돈다([withServerSaveLock]).
    final ctrl = ref.read(saveControllerProvider.notifier);
    final r = await withServerSaveLock(() async {
      if (!await flushSaveBeforeServerAction(_server, () => ctrl.latestSave)) {
        return null;
      }
      final r = await _server.guildBossClaim();
      if (r.isOk && r.save != null) await ctrl.adoptServerSave(r.save!);
      return r;
    });
    if (r == null) {
      return (error: 'network', jelly: 0);
    }
    if (!r.isOk || r.save == null) {
      return (error: r.error ?? 'network', jelly: 0);
    }
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

  /// 길드에 들어가 있나 — `/guild/me` 를 받을 때마다 [GuildController] 가 적는다.
  /// 모르거나(시작 직후) 길드가 없으면 업로드에 집계를 싣지 않는다(서버가 길드를 조회하지 않게).
  /// 안 실은 집계는 dirty 로 남아 다음 업로드에 간다.
  static bool inGuild = false;

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

  /// 계정 전환([forgetGuildSession])·테스트용.
  static void reset() {
    _day = '';
    _counts = {};
    _dirty = false;
    inGuild = false;
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
    this.opponentEmblem,
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

  /// 상대 길드 문장(보일 값). 가상 길드·옛 서버(상대 id 없음)면 null.
  final int? opponentEmblem;
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
      opponentEmblem: m?['opponentId'] == null
          ? null
          : guildEmblemOf(
              '${m!['opponentId']}',
              (m['opponentEmblem'] as num?)?.toInt(),
            ),
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
    // 올리기 → 서버 행동 → 채택을 한 줄로 돈다([withServerSaveLock]).
    final ctrl = ref.read(saveControllerProvider.notifier);
    final r = await withServerSaveLock(() async {
      if (!await flushSaveBeforeServerAction(_server, () => ctrl.latestSave)) {
        return null;
      }
      final r = await _server.guildWarClaim();
      if (r.isOk && r.save != null) await ctrl.adoptServerSave(r.save!);
      return r;
    });
    if (r == null) {
      return (error: 'network', jelly: 0, coins: 0);
    }
    if (!r.isOk || r.save == null) {
      return (error: r.error ?? 'network', jelly: 0, coins: 0);
    }
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
