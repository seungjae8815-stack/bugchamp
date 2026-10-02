import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/auth_service.dart';
import '../../domain/guild_service.dart';
import '../../domain/providers.dart';
import '../../domain/save_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/event_badge.dart';
import '../../ui/format.dart';
import '../../ui/game_dialog.dart';
import '../../ui/labels.dart';
import '../../ui/art.dart';
import '../../ui/toast.dart';
import '../chat/chat_screen.dart';
import 'guild_boss_tab.dart';
import 'guild_growth.dart';
import 'guild_war_tab.dart';
import 'guild_mission_tab.dart';

const _honey = Color(0xFFEBC24A);
const _dim = Color(0x99FFFFFF);

/// 길드(1.0.15 1단계 — docs/design_guild.md §1).
///
/// 길드가 없으면 **추천·검색 목록 + 만들기**, 있으면 **길드원 · 채팅 · 가입 신청** 탭.
/// 상태는 서버가 소유한다 — 화면은 [guildProvider] 를 열 때 한 번 새로 받고, 액션 응답으로 갈아 끼운다.
/// ⚠️ 화면이 열려 있어도 주기 조회는 하지 않는다(2단계 미션 도움 요청부터 필요하면 그때 붙인다).
class GuildScreen extends ConsumerStatefulWidget {
  const GuildScreen({super.key});

  @override
  ConsumerState<GuildScreen> createState() => _GuildScreenState();
}

class _GuildScreenState extends ConsumerState<GuildScreen> {
  @override
  void initState() {
    super.initState();
    // 열 때마다 최신으로 — 그 사이 신청이 들어왔거나 추방됐을 수 있다.
    Future.microtask(() => ref.read(guildProvider.notifier).refresh());
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(guildProvider);
    final view = async.value;
    final Widget body;
    if (view == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (!view.available) {
      body = _Unavailable(
        onRetry: () => ref.invalidate(guildProvider),
        text: l.guildUnavailable,
        retry: l.guildRetry,
      );
    } else if (view.guild == null) {
      body = _NoGuild(view: view);
    } else {
      body = _MyGuild(view: view);
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(view?.guild?.name ?? l.guildTitle),
        actions: [if (view?.guild != null) _GuildMenu(view: view!)],
      ),
      body: body,
    );
  }
}

/// 서버 오류 코드 → 안내 문구.
String guildErrorText(AppLocalizations l, String code) => switch (code) {
  'name_taken' => l.guildErrNameTaken,
  'name_invalid' => l.guildErrNameInvalid,
  'insufficient_jelly' => l.guildErrJelly,
  'cooldown' => l.guildErrCooldown,
  'guild_full' => l.guildErrFull,
  'too_many_requests' => l.guildErrTooManyRequests,
  'requests_full' => l.guildErrRequestsFull,
  'deputy_full' => l.guildErrDeputyFull,
  'notice_invalid' => l.guildErrNoticeInvalid,
  _ => l.guildErrGeneric,
};

String guildRoleLabel(AppLocalizations l, GuildRole r) => switch (r) {
  GuildRole.leader => l.guildRoleLeader,
  GuildRole.deputy => l.guildRoleDeputy,
  GuildRole.member => l.guildRoleMember,
};

Widget _roleIcon(GuildRole r, {double size = 16}) => switch (r) {
  GuildRole.leader => Icon(
    Icons.workspace_premium_rounded,
    color: _honey,
    size: size,
  ),
  GuildRole.deputy => Icon(
    Icons.star_rounded,
    color: const Color(0xFF9FD3F5),
    size: size,
  ),
  GuildRole.member => SizedBox(width: size),
};

class _Unavailable extends StatelessWidget {
  const _Unavailable({
    required this.onRetry,
    required this.text,
    required this.retry,
  });
  final VoidCallback onRetry;
  final String text;
  final String retry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _dim),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: Text(retry)),
        ],
      ),
    ),
  );
}

/// 결과 처리 공용 — 실패면 문구, 성공이면 [okText](있을 때만).
Future<void> _run(
  BuildContext context,
  Future<String?> action, {
  String? okText,
}) async {
  final l = AppLocalizations.of(context);
  final err = await action;
  if (!context.mounted) return;
  if (err != null) {
    showCenterToast(context, guildErrorText(l, err));
  } else if (okText != null) {
    showCenterToast(context, okText);
  }
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
  bool danger = true,
}) async {
  final l = AppLocalizations.of(context);
  final ok = await showGameDialog<bool>(
    context,
    title: title,
    icon: Icons.groups_rounded,
    content: Text(
      body,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Color(0xD9FFFFFF),
        fontSize: 13,
        height: 1.4,
      ),
    ),
    actions: [
      gameDialogButton(
        l.actionCancel,
        () => Navigator.pop(context, false),
        primary: false,
      ),
      gameDialogButton(
        action,
        () => Navigator.pop(context, true),
        color: danger ? const Color(0xFF9A3434) : null,
      ),
    ],
  );
  return ok == true;
}

// ── 길드 없음: 추천·검색 + 만들기 ─────────────────────────────────────

class _NoGuild extends ConsumerStatefulWidget {
  const _NoGuild({required this.view});
  final GuildView view;

  @override
  ConsumerState<_NoGuild> createState() => _NoGuildState();
}

class _NoGuildState extends ConsumerState<_NoGuild> {
  final _query = TextEditingController();

  /// 개설 대화상자의 이름 칸. ⚠️ 대화상자가 닫히는 **애니메이션 중에도** 입력칸이 이 컨트롤러를
  /// 그린다 — 닫히자마자 폐기하면 "disposed 된 컨트롤러 사용"으로 터진다. 화면과 수명을 같이 한다.
  final _name = TextEditingController();
  List<GuildInfo>? _list;
  List<String> _requested = const [];
  bool _busy = false;

  String get _lang => Localizations.localeOf(context).languageCode;

  @override
  void initState() {
    super.initState();
    _requested = widget.view.requested;
    Future.microtask(_search);
  }

  @override
  void dispose() {
    _query.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final r = await ref
        .read(guildProvider.notifier)
        .search(lang: _lang, query: _query.text);
    if (!mounted) return;
    setState(() {
      _list = r?.guilds ?? const [];
      if (r != null) _requested = r.requested;
    });
  }

  Future<void> _join(GuildInfo g) async {
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    final n = ref.read(guildProvider.notifier);
    if (_requested.contains(g.id)) {
      await _run(context, n.cancelRequest(g.id));
    } else {
      await _run(
        context,
        n.join(g.id),
        okText: g.joinMode == GuildJoinMode.approval
            ? l.guildRequestSent
            : l.guildJoined,
      );
    }
    if (!mounted) return;
    setState(() => _busy = false);
    await _search();
  }

  Future<void> _create() async {
    final l = AppLocalizations.of(context);
    final cfg =
        ref.read(gameDataProvider).value?.guildConfig ?? const GuildConfig();
    final name = _name..clear();
    var mode = GuildJoinMode.open;
    final go = await showGameDialog<bool>(
      context,
      title: l.guildCreate,
      icon: Icons.groups_rounded,
      content: StatefulBuilder(
        builder: (ctx, setLocal) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: name,
              maxLength: cfg.nameMaxLength,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: l.guildNameHint(cfg.nameMinLength, cfg.nameMaxLength),
                hintStyle: const TextStyle(color: Color(0x55FFFFFF)),
                filled: true,
                fillColor: const Color(0x22000000),
                border: const OutlineInputBorder(),
                counterStyle: const TextStyle(color: Color(0x66FFFFFF)),
              ),
            ),
            const SizedBox(height: 8),
            for (final m in GuildJoinMode.values)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: InkWell(
                  onTap: () => setLocal(() => mode = m),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: m == mode
                          ? _honey.withValues(alpha: 0.18)
                          : const Color(0x18FFFFFF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: m == mode ? _honey : const Color(0x22FFFFFF),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          m == mode
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          color: m == mode ? _honey : _dim,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _joinModeLabel(l, m),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        gameDialogButton(
          l.actionCancel,
          () => Navigator.pop(context, false),
          primary: false,
        ),
        gameDialogButton(
          l.guildCreateWithCost(cfg.createJellyCost),
          () => Navigator.pop(context, true),
        ),
      ],
    );
    final text = name.text;
    if (go != true || !mounted) return;
    await _run(
      context,
      ref
          .read(guildProvider.notifier)
          .create(name: text, lang: _lang, joinMode: mode),
      okText: l.guildCreated,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cfg =
        ref.watch(gameDataProvider).value?.guildConfig ?? const GuildConfig();
    final save = ref.watch(saveControllerProvider).value;
    final canCreate =
        (save?.materialCount(MaterialKind.jelly) ?? 0) >= cfg.createJellyCost;
    final now = ref.read(clockProvider).now().toUtc();
    final cd = widget.view.cooldownUntil;
    final cooling = cd != null && now.isBefore(cd);
    final list = _list;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          color: const Color(0x22EBA52F),
          child: Text(
            l.guildIntro,
            style: const TextStyle(
              color: Color(0xCCEBD24A),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
        if (cooling)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              l.guildCooldown(remainLabel(l, cd.difference(now))),
              style: const TextStyle(color: Color(0xFFEF9A9A), fontSize: 12),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: TextField(
            controller: _query,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: l.guildSearchHint,
              hintStyle: const TextStyle(color: Color(0x55FFFFFF)),
              filled: true,
              fillColor: const Color(0x22000000),
              isDense: true,
              prefixIcon: const Icon(Icons.search_rounded, color: _dim),
              suffixIcon: IconButton(
                icon: const Icon(Icons.refresh_rounded, color: _dim),
                onPressed: _search,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: list == null
              ? const Center(child: CircularProgressIndicator())
              : list.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      l.guildEmptyList,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: _dim),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: list.length,
                  itemBuilder: (context, i) => _guildRow(l, list[i], cooling),
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!canCreate)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      l.guildCreateNeedJelly(cfg.createJellyCost),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: _dim, fontSize: 12),
                    ),
                  ),
                FilledButton.icon(
                  onPressed: canCreate && !cooling ? _create : null,
                  icon: jellyIcon(size: 18),
                  label: Text(l.guildCreateWithCost(cfg.createJellyCost)),
                  style: FilledButton.styleFrom(
                    backgroundColor: _honey,
                    foregroundColor: const Color(0xFF1A1200),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _guildRow(AppLocalizations l, GuildInfo g, bool cooling) {
    final rules =
        ref.read(gameDataProvider).value?.chatRules ?? const ChatRules();
    final requested = _requested.contains(g.id);
    final String label;
    if (requested) {
      label = l.guildCancelRequest;
    } else if (g.full) {
      label = l.guildFull;
    } else {
      label = g.joinMode == GuildJoinMode.approval
          ? l.guildRequest
          : l.guildJoin;
    }
    final enabled = !_busy && (requested || (!g.full && !cooling));
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x18000000),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        g.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _chip(_joinModeShort(l, g.joinMode)),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${l.guildMembersCount(g.memberCount, g.maxMembers)} · '
                  '${l.guildAvgPower(formatCompact(g.avgPower))}',
                  style: const TextStyle(color: _dim, fontSize: 11.5),
                ),
                if (g.notice.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    rules.mask(g.notice),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xCCFFFFFF),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: enabled ? () => _join(g) : null,
            style: OutlinedButton.styleFrom(
              foregroundColor: requested ? _dim : _honey,
              side: BorderSide(
                color: requested ? const Color(0x44FFFFFF) : _honey,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _joinModeLabel(AppLocalizations l, GuildJoinMode m) =>
    m == GuildJoinMode.open ? l.guildJoinModeOpen : l.guildJoinModeApproval;

String _joinModeShort(AppLocalizations l, GuildJoinMode m) =>
    m == GuildJoinMode.open
    ? l.guildJoinModeOpenShort
    : l.guildJoinModeApprovalShort;

Widget _chip(String text, {Color color = _dim}) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(6),
    border: Border.all(color: color.withValues(alpha: 0.6)),
  ),
  child: Text(
    text,
    style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800),
  ),
);

// ── 내 길드: 길드원 · 채팅 · 가입 신청 ────────────────────────────────

class _MyGuild extends ConsumerStatefulWidget {
  const _MyGuild({required this.view});
  final GuildView view;

  @override
  ConsumerState<_MyGuild> createState() => _MyGuildState();
}

class _MyGuildState extends ConsumerState<_MyGuild> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final v = widget.view;
    final g = v.guild!;
    final manage = v.myRole.canManage;
    final tabs = [
      l.guildTabMembers,
      l.guildTabMissions,
      l.guildTabBoss,
      l.guildTabWar,
      l.guildTabChat,
      if (manage) l.guildTabRequests(v.requests.length),
    ];
    final tab = _tab.clamp(0, tabs.length - 1);
    final rules =
        ref.watch(gameDataProvider).value?.chatRules ?? const ChatRules();

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          color: const Color(0x22000000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GuildGrowthBar(view: v),
              Row(
                children: [
                  Text(
                    l.guildMembersCount(g.memberCount, g.maxMembers),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _chip(_joinModeShort(l, g.joinMode)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l.guildAvgPower(formatCompact(g.avgPower)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: const TextStyle(color: _dim, fontSize: 11.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                g.notice.isEmpty ? l.guildNoticeEmpty : rules.mask(g.notice),
                style: TextStyle(
                  color: g.notice.isEmpty
                      ? const Color(0x66FFFFFF)
                      : const Color(0xDDFFFFFF),
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              for (var i = 0; i < tabs.length; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: GestureDetector(
                      onTap: () => setState(() => _tab = i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: i == tab
                              ? _honey.withValues(alpha: 0.22)
                              : const Color(0x18FFFFFF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: i == tab ? _honey : const Color(0x22FFFFFF),
                          ),
                        ),
                        child: Text(
                          tabs[i],
                          style: TextStyle(
                            color: i == tab ? _honey : _dim,
                            fontWeight: FontWeight.w900,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          // 채팅 탭을 오가도 대화·입력이 날아가지 않게 셋 다 살려 둔다.
          child: IndexedStack(
            index: tab,
            children: [
              _members(l, v, rules),
              // 미션 탭은 **보일 때만** 주기 조회한다.
              GuildMissionTab(visible: tab == 1),
              GuildBossTab(visible: tab == 2),
              GuildWarTab(visible: tab == 3),
              ChatScreen(
                key: ValueKey('guildChat:${g.id}'),
                guildId: g.id,
                embedded: true,
              ),
              if (manage) _requests(l, v, rules),
            ],
          ),
        ),
      ],
    );
  }

  Widget _members(AppLocalizations l, GuildView v, ChatRules rules) {
    final myId = ref.watch(authServiceProvider).userId;
    final now = ref.read(clockProvider).now().toUtc();
    return ListView.builder(
      padding: EdgeInsets.only(
        top: 4,
        bottom: 8 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      itemCount: v.members.length,
      itemBuilder: (context, i) {
        final m = v.members[i];
        final me = m.userId == myId;
        final canAct = !me && _outranks(v.myRole, m.role);
        return InkWell(
          onTap: canAct ? () => _memberActions(l, v, m, rules) : null,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: me
                  ? _honey.withValues(alpha: 0.14)
                  : const Color(0x18000000),
              borderRadius: BorderRadius.circular(10),
              border: me
                  ? Border.all(color: _honey.withValues(alpha: 0.6))
                  : null,
            ),
            child: Row(
              children: [
                SizedBox(width: 22, child: Center(child: _roleIcon(m.role))),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      EventBadgeChip(
                        id: m.badge,
                        size: 10,
                        margin: EventBadgeChip.aboveName,
                      ),
                      Text(
                        rules.maskNickname(
                          m.nickname,
                          fallback: l.nicknameFallback,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        ),
                      ),
                      Text(
                        '${guildRoleLabel(l, m.role)} · ${_lastSeen(l, now, m.lastSeen)}',
                        style: const TextStyle(color: _dim, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${l.combatPowerLabel} ${formatCompact(m.power)}',
                  style: const TextStyle(
                    color: _honey,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                if (canAct)
                  const Icon(Icons.more_vert_rounded, color: _dim, size: 18),
              ],
            ),
          ),
        );
      },
    );
  }

  static int _rank(GuildRole r) => switch (r) {
    GuildRole.leader => 2,
    GuildRole.deputy => 1,
    GuildRole.member => 0,
  };

  static bool _outranks(GuildRole a, GuildRole b) => _rank(a) > _rank(b);

  String _lastSeen(AppLocalizations l, DateTime now, DateTime at) {
    final d = now.difference(at);
    if (d.inHours < 1) return l.guildLastSeenNow;
    if (d.inDays < 1) return l.guildLastSeenHours(d.inHours);
    return l.guildLastSeenDays(d.inDays);
  }

  Future<void> _memberActions(
    AppLocalizations l,
    GuildView v,
    GuildMemberInfo m,
    ChatRules rules,
  ) async {
    final name = rules.maskNickname(m.nickname, fallback: l.nicknameFallback);
    final n = ref.read(guildProvider.notifier);
    final leader = v.myRole == GuildRole.leader;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xF2141F0E),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leader && m.role == GuildRole.member)
              _sheetItem(
                ctx,
                Icons.star_rounded,
                l.guildMakeDeputy,
                () => _run(context, n.setRole(m.userId, GuildRole.deputy)),
              ),
            if (leader && m.role == GuildRole.deputy)
              _sheetItem(
                ctx,
                Icons.star_border_rounded,
                l.guildRemoveDeputy,
                () => _run(context, n.setRole(m.userId, GuildRole.member)),
              ),
            if (leader)
              _sheetItem(
                ctx,
                Icons.workspace_premium_rounded,
                l.guildTransfer,
                () async {
                  if (await _confirm(
                    context,
                    title: l.guildTransfer,
                    body: l.guildTransferConfirm(name),
                    action: l.guildTransfer,
                  )) {
                    if (!mounted) return;
                    await _run(context, n.setRole(m.userId, GuildRole.leader));
                  }
                },
              ),
            _sheetItem(ctx, Icons.person_remove_rounded, l.guildKick, () async {
              if (await _confirm(
                context,
                title: l.guildKick,
                body: l.guildKickConfirm(name),
                action: l.guildKick,
              )) {
                if (!mounted) return;
                await _run(context, n.kick(m.userId));
              }
            }, danger: true),
          ],
        ),
      ),
    );
  }

  Widget _sheetItem(
    BuildContext ctx,
    IconData icon,
    String text,
    Future<void> Function() onTap, {
    bool danger = false,
  }) => ListTile(
    leading: Icon(icon, color: danger ? const Color(0xFFE79A9A) : _honey),
    title: Text(text, style: const TextStyle(color: Colors.white)),
    onTap: () {
      Navigator.pop(ctx);
      onTap();
    },
  );

  Widget _requests(AppLocalizations l, GuildView v, ChatRules rules) {
    if (v.requests.isEmpty) {
      return Center(
        child: Text(l.guildNoRequests, style: const TextStyle(color: _dim)),
      );
    }
    final n = ref.read(guildProvider.notifier);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: v.requests.length,
      itemBuilder: (context, i) {
        final r = v.requests[i];
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0x18000000),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rules.maskNickname(
                        r.nickname,
                        fallback: l.nicknameFallback,
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                    Text(
                      '${l.combatPowerLabel} ${formatCompact(r.power)}',
                      style: const TextStyle(color: _dim, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () =>
                    _run(context, n.answer(r.userId, accept: false)),
                style: TextButton.styleFrom(foregroundColor: _dim),
                child: Text(l.guildReject),
              ),
              const SizedBox(width: 4),
              FilledButton(
                onPressed: () =>
                    _run(context, n.answer(r.userId, accept: true)),
                style: FilledButton.styleFrom(
                  backgroundColor: _honey,
                  foregroundColor: const Color(0xFF1A1200),
                ),
                child: Text(l.guildAccept),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 앱바 메뉴 — 소개 수정·가입 방식(관리자) · 탈퇴(모두).
class _GuildMenu extends ConsumerWidget {
  const _GuildMenu({required this.view});
  final GuildView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final manage = view.myRole.canManage;
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded),
      color: const Color(0xF2141F0E),
      onSelected: (k) => switch (k) {
        'notice' => _editNotice(context, ref),
        'mode' => _toggleMode(context, ref),
        _ => _leave(context, ref),
      },
      itemBuilder: (_) => [
        if (manage)
          PopupMenuItem(
            value: 'notice',
            child: Text(
              l.guildEditNotice,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        if (manage)
          PopupMenuItem(
            value: 'mode',
            child: Text(
              '${l.guildChangeJoinMode}: ${_joinModeShort(l, view.guild!.joinMode)}',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        PopupMenuItem(
          value: 'leave',
          child: Text(
            l.guildLeave,
            style: const TextStyle(color: Color(0xFFE79A9A)),
          ),
        ),
      ],
    );
  }

  Future<void> _editNotice(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final cfg =
        ref.read(gameDataProvider).value?.guildConfig ?? const GuildConfig();
    final input = TextEditingController(text: view.guild!.notice);
    final ok = await showGameDialog<bool>(
      context,
      title: l.guildEditNotice,
      icon: Icons.edit_rounded,
      content: TextField(
        controller: input,
        maxLength: cfg.noticeMaxLength,
        maxLines: 3,
        style: const TextStyle(color: Colors.white, fontSize: 13.5),
        decoration: InputDecoration(
          hintText: l.guildNoticeHint,
          hintStyle: const TextStyle(color: Color(0x55FFFFFF)),
          filled: true,
          fillColor: const Color(0x22000000),
          border: const OutlineInputBorder(),
          counterStyle: const TextStyle(color: Color(0x66FFFFFF)),
        ),
      ),
      actions: [
        gameDialogButton(
          l.actionCancel,
          () => Navigator.pop(context, false),
          primary: false,
        ),
        gameDialogButton(l.guildSave, () => Navigator.pop(context, true)),
      ],
    );
    // 폐기하지 않는다 — 닫히는 애니메이션 중에도 입력칸이 쓴다(리스너가 없어 GC 로 충분).
    final text = input.text;
    if (ok != true || !context.mounted) return;
    await _run(
      context,
      ref.read(guildProvider.notifier).settings(notice: text),
    );
  }

  Future<void> _toggleMode(BuildContext context, WidgetRef ref) => _run(
    context,
    ref
        .read(guildProvider.notifier)
        .settings(
          joinMode: view.guild!.joinMode == GuildJoinMode.open
              ? GuildJoinMode.approval
              : GuildJoinMode.open,
        ),
  );

  Future<void> _leave(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final cfg =
        ref.read(gameDataProvider).value?.guildConfig ?? const GuildConfig();
    final last = view.members.length <= 1;
    final body = [
      if (last)
        l.guildLeaveLastConfirm
      else
        l.guildLeaveConfirm(cfg.rejoinCooldownHours),
      if (!last && view.myRole == GuildRole.leader) l.guildLeaderLeaveNote,
    ].join('\n\n');
    if (!await _confirm(
      context,
      title: l.guildLeave,
      body: body,
      action: l.guildLeave,
    )) {
      return;
    }
    if (!context.mounted) return;
    await _run(context, ref.read(guildProvider.notifier).leave());
  }
}

/// 길드 "준비 중" 화면 — 하단 메뉴 길드 탭([kGuildOpen] 이 false 일 때, 1.0.15).
/// 길드전 그림(글씨 없음, `assets/images/ui/guild_coming_soon.webp`) 위에 **"준비 중" 띠를 코드로** 얹는다 —
/// 그림에 글씨를 넣으면 영어·일본어로 바꿀 수 없다. 그림이 없으면 띠만 보인다(§6 폴백).
class GuildComingSoon extends StatelessWidget {
  const GuildComingSoon({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    const honey = Color(0xFFEBA52F);
    // 그림을 **탭 전체에 꽉 차게**(cover) 깔고, 가운데에 "준비 중" + 안내를 한 판에 얹는다(2026-10-02 사장님).
    // 그림 아래 워터마크 띠는 애셋에서 잘라 냈다(tool/import_guild_art.py).
    return Scaffold(
      backgroundColor: const Color(0xFF140E06),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/ui/guild_coming_soon.webp',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, _, _) =>
                const ColoredBox(color: Color(0xFF2A2417)),
          ),
          // 위·아래를 살짝 어둡게 — 글씨 판과 하단 메뉴가 그림에 묻히지 않게.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x66000000),
                  Color(0x11000000),
                  Color(0x88000000),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                  decoration: BoxDecoration(
                    color: const Color(0xCC140E06),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0x88EBA52F),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l.guildTitle,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l.guildComingSoonTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: honey,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          shadows: [Shadow(color: Colors.black, blurRadius: 6)],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l.guildComingSoonBody,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
