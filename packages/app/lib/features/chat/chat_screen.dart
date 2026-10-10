import 'dart:async';

import 'package:core_models/core_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/auth_service.dart';
import '../../domain/chat_service.dart';
import '../../domain/game_server.dart';
import '../../domain/guild_service.dart' show guildProvider, kGuildOpen;
import '../../domain/providers.dart';
import '../../domain/save_controller.dart';
import 'package:core_save/core_save.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/event_badge.dart';
import '../../ui/game_dialog.dart';
import '../../ui/toast.dart';
import '../../ui/colors.dart';
import '../../ui/avatar.dart';
import '../guild/guild_mission_tab.dart' show guildHelpMission;

/// 전체 채팅 화면.
///
/// **사용자 제작 콘텐츠(UGC)** 이므로 구글 플레이 정책상 아래가 필수다:
/// - 금칙어 필터 (보낼 때 + 보여줄 때 양쪽)
/// - 메시지 신고
/// - 사용자 차단
/// - 도배 방지
/// 넷 다 이 화면에 있다. 하나라도 빼면 심사에서 거부될 수 있다.
///
/// **전체 / 길드 탭**(2026-10-05) — 길드에 들어가 있으면 위에 두 탭이 생긴다.
/// - 전체: 전체 글 + 내 길드 글(길드 글은 [길드] 표시). 여기서 쓰면 전체 글.
/// - 길드: 내 길드 글만. 여기서 쓰면 길드 글(`guild_id`).
/// 길드가 없으면 탭 없이 전체 채팅만. DB 정책(`chat_read`)은 원래 전체 + 내 길드 글을 읽게 해 줘서 SQL 변경은 없다.
///
/// [embedded] 면 앱바·탭 없이 [guildId] 의 **길드 채팅만** — 길드 화면의 채팅 탭(같은 [ChatPane]).
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, this.guildId, this.embedded = false});

  final String? guildId;
  final bool embedded;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  /// 0 = 전체, 1 = 길드.
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return ChatPane(
        key: ValueKey('chatPane:guild:${widget.guildId}'),
        guildId: widget.guildId,
        guildOnly: widget.guildId != null,
      );
    }
    final l = AppLocalizations.of(context);
    // 길드는 아직 닫혀 있을 수 있다(kGuildOpen) — 닫혔으면 길드 탭 없이 예전처럼 전체 채팅만.
    final gid = kGuildOpen
        ? ref.watch(guildProvider).value?.guild?.id
        : widget.guildId;
    final Widget body;
    if (gid == null) {
      body = const ChatPane(key: ValueKey('chatPane:all'));
    } else {
      final tab = _tab.clamp(0, 1);
      body = Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                for (final (i, text) in [l.chatTabAll, l.chatTabGuild].indexed)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: InkWell(
                        key: ValueKey('chatTab:$i'),
                        onTap: () => setState(() => _tab = i),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: i == tab
                                ? kHoney.withValues(alpha: 0.22)
                                : const Color(0x18FFFFFF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: i == tab
                                  ? kHoney
                                  : const Color(0x22FFFFFF),
                            ),
                          ),
                          child: Text(
                            text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: i == tab
                                  ? kHoney
                                  : const Color(0x99FFFFFF),
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
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
            // 탭을 오가도 대화·입력이 날아가지 않게 둘 다 살려 둔다(같은 실시간 채널을 나눠 쓴다).
            child: IndexedStack(
              index: tab,
              children: [
                ChatPane(key: ValueKey('chatPane:mixed:$gid'), guildId: gid),
                ChatPane(
                  key: ValueKey('chatPane:guild:$gid'),
                  guildId: gid,
                  guildOnly: true,
                ),
              ],
            ),
          ),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(l.chatTitle),
        actions: [
          // 채팅으로 버그를 알리는 유저가 많은데(2026-08-30) 채팅은 흘러가서
          // 운영자가 놓친다. 놓치면 안 되는 신호는 따로 받는다.
          TextButton.icon(
            onPressed: _showSupport,
            icon: const Icon(Icons.support_agent_rounded, size: 18),
            label: Text(l.supportTitle),
            style: TextButton.styleFrom(
              foregroundColor: kHoney,
              textStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: body,
    );
  }

  void _snack(String msg) => showCenterToast(context, msg);

  /// 운영자에게 문의 — 서버가 텔레그램으로 밀어 준다.
  ///
  /// 닉네임·스테이지 같은 상황 값은 **서버가 세이브에서 읽는다**. 앱이
  /// 보내면 조작할 수 있고, 무엇보다 앱이 빠뜨리면 운영자가 아무것도 못 본다.
  Future<void> _showSupport() async {
    final l = AppLocalizations.of(context);
    final input = TextEditingController();
    var sending = false;

    await showGameDialog<void>(
      context,
      title: l.supportTitle,
      icon: Icons.support_agent_rounded,
      content: StatefulBuilder(
        builder: (ctx, setLocal) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.supportHint,
              style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 11.5),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: input,
              enabled: !sending,
              maxLines: 4,
              maxLength: 500,
              style: const TextStyle(color: Colors.white, fontSize: 13.5),
              decoration: const InputDecoration(
                filled: true,
                fillColor: Color(0x22000000),
                border: OutlineInputBorder(),
                counterStyle: TextStyle(color: Color(0x66FFFFFF)),
              ),
            ),
            const SizedBox(height: 6),
            FilledButton(
              onPressed: sending
                  ? null
                  : () async {
                      final body = input.text.trim();
                      if (body.isEmpty) return;
                      setLocal(() => sending = true);
                      final r = await ref
                          .read(gameServerProvider)
                          .sendSupport(message: body);
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      if (!mounted) return;
                      _snack(
                        r.isOk
                            ? l.supportSent
                            : (r.status == 429
                                  ? l.supportTooFast
                                  : l.supportFailed),
                      );
                    },
              child: Text(sending ? '...' : l.supportSend),
            ),
          ],
        ),
      ),
      actions: const [],
    );
    input.dispose();
  }
}

/// 채팅 한 칸(목록 + 입력) — 전체 탭 · 길드 탭 · 길드 화면 채팅 탭이 같은 위젯이다.
///
/// [guildOnly] 면 [guildId] 길드 글만 보이고 쓴 글도 길드 글. 아니면 전체 글 + [guildId] 길드 글
/// (있으면, [길드] 표시)이 보이고 쓴 글은 전체 글. 거르는 규칙은 [chatMessageVisible].
class ChatPane extends ConsumerStatefulWidget {
  const ChatPane({super.key, this.guildId, this.guildOnly = false});

  final String? guildId;
  final bool guildOnly;

  @override
  ConsumerState<ChatPane> createState() => _ChatPaneState();
}

class _ChatPaneState extends ConsumerState<ChatPane> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <ChatMessage>[];
  StreamSubscription<ChatMessage>? _sub;

  /// 마지막 전송 시각 — 도배 방지(클라이언트 1차 방어).
  DateTime? _lastSentAt;
  bool _loading = true;
  bool _sending = false;

  /// 낙관적으로 먼저 띄운 메시지의 id 접두어. 서버가 준 id 와 구분한다.
  static const _localPrefix = 'local:';

  /// 아직 서버 id 를 못 받은(임시) 메시지인가. `local:`(내가 즉시 띄운 것)과
  /// `echo:`(서비스가 넣자마자 방송한 것) 둘 다 임시다.
  static bool _isTemp(String id) =>
      id.startsWith(_localPrefix) || id.startsWith('echo:');

  ChatRules get _rules =>
      ref.read(gameDataProvider).value?.chatRules ?? const ChatRules();

  /// 앱이 백그라운드에 있던 동안 올라온 글 — 실시간 구독은 그 사이 글을 다시 보내 주지 않는다(2026-10-10).
  /// 돌아오면 최근 글을 다시 받아 빈 곳을 채운다.
  AppLifecycleListener? _lifecycle;

  /// 실시간이 조용할 때 직접 확인하는 안전망(2026-10-10 실기 지적 — 켜 둔 채 채팅이 안 바뀜).
  /// 실시간 구독은 폰·통신·절전에 따라 **오류 없이** 끊길 수 있다(서버 구독 목록에서 빠져 있었다).
  /// 열린 화면에서만, [_pollGap] 동안 실시간 글이 없을 때만 최근 글을 받아 새 것만 붙인다(작은 조회 1번).
  Timer? _poll;
  DateTime _lastLive = DateTime.now();
  bool _polling = false;
  static const _pollGap = Duration(seconds: 8);

  @override
  void initState() {
    super.initState();
    _load();
    _lifecycle = AppLifecycleListener(onResume: _refill);
    _poll = Timer.periodic(_pollGap, (_) => _checkNew());
  }

  Future<void> _checkNew() async {
    if (_loading || _polling || !mounted) return;
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    if (DateTime.now().difference(_lastLive) < _pollGap) return;
    _polling = true;
    try {
      final list = await ref
          .read(chatServiceProvider)
          .recent(limit: 20, guildId: widget.guildId, mixed: !widget.guildOnly);
      if (mounted) _merge(list);
    } finally {
      _polling = false;
    }
  }

  Future<void> _refill() async {
    if (_loading) return;
    final list = await ref
        .read(chatServiceProvider)
        .recent(
          limit: _rules.historyLimit,
          guildId: widget.guildId,
          mixed: !widget.guildOnly,
        );
    if (mounted) _merge(list);
  }

  /// 서버 목록을 합친다 — 이미 있는 글(같은 id)은 그대로, 새 글만 붙이고, 서버 글로 바뀐 내 임시 글은 뺀다.
  void _merge(List<ChatMessage> list) {
    if (list.isEmpty) return;
    final have = {for (final x in _messages) x.id};
    final fresh = [
      for (final m in list)
        if (!have.contains(m.id)) m,
    ];
    if (fresh.isEmpty) return;
    setState(() {
      _messages.removeWhere(
        (x) =>
            _isTemp(x.id) &&
            fresh.any((m) => m.userId == x.userId && m.body == x.body),
      );
      _messages
        ..addAll(fresh)
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      if (_messages.length > _rules.historyLimit) {
        _messages.removeRange(0, _messages.length - _rules.historyLimit);
      }
    });
    _jumpToBottom();
  }

  Future<void> _load() async {
    final svc = ref.read(chatServiceProvider);
    final list = await svc.recent(
      limit: _rules.historyLimit,
      guildId: widget.guildId,
      mixed: !widget.guildOnly,
    );
    if (!mounted) return;
    setState(() {
      _messages
        ..clear()
        ..addAll(list);
      _loading = false;
    });
    _jumpToBottom();
    _sub = svc.subscribe(guildId: widget.guildId, mixed: !widget.guildOnly).listen((
      m,
    ) {
      if (!mounted) return;
      _lastLive = DateTime.now();
      // 안전망 조회(8초 · 복귀 시 채우기)가 같은 글을 먼저 받아 두었으면 실시간이 늦게 준 것은 버린다(2026-10-10 점검).
      if (!_isTemp(m.id) && _messages.any((x) => x.id == m.id)) return;
      setState(() {
        // 같은 글이 세 경로로 들어올 수 있다 —
        //  ① 내가 즉시 띄운 것(`local:`)  ② 서비스가 보낸 자체 방송(`echo:`)
        //  ③ 서버 실시간 브로드캐스트(진짜 id)
        // 셋을 합쳐 **한 줄만** 남긴다. 안 그러면 같은 말이 두세 번 보인다.
        final dup = _messages.any(
          (x) =>
              !_isTemp(x.id) &&
              x.userId == m.userId &&
              x.body == m.body &&
              m.createdAt.difference(x.createdAt).abs() <
                  const Duration(seconds: 20),
        );
        _messages.removeWhere(
          (x) => _isTemp(x.id) && x.userId == m.userId && x.body == m.body,
        );
        // ③ 이 이미 들어와 있으면 ②(에코)는 버린다.
        if (!(dup && _isTemp(m.id))) _messages.add(m);
        // 화면에 무한정 쌓이지 않게 상한 유지.
        if (_messages.length > _rules.historyLimit) {
          _messages.removeRange(0, _messages.length - _rules.historyLimit);
        }
      });
      _jumpToBottom();
    });
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _lifecycle?.dispose();
    _sub?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// 이 칸에서 쓴 글이 갈 곳 — 길드 탭이면 길드 글, 아니면 전체 글.
  String? get _sendGuildId => widget.guildOnly ? widget.guildId : null;

  Future<void> _send() async {
    final l = AppLocalizations.of(context);
    final body = _input.text.trim();
    final now = ref.read(clockProvider).now().toUtc();

    // 전송 전 검사 — 금칙어/길이/도배.
    final check = _rules.check(body, lastSentAt: _lastSentAt, now: now);
    if (check != ChatCheckResult.ok) {
      final msg = switch (check) {
        ChatCheckResult.empty => null, // 조용히 무시
        ChatCheckResult.tooLong => l.chatTooLong(_rules.maxLength),
        ChatCheckResult.blocked => l.chatBlockedWord,
        ChatCheckResult.tooFast => l.chatTooFast,
        ChatCheckResult.ok => null,
      };
      if (msg != null) _snack(msg);
      return;
    }

    final save = ref.read(saveControllerProvider).requireValue;
    // ⚠️ **먼저 화면에 띄운다.** 예전에는 서버에 넣고 그 브로드캐스트가
    // 되돌아올 때까지 기다렸다 — 왕복(insert → Postgres → realtime → 앱)이
    // 통째로 지연으로 보였다(2026-08-30 지적). 내가 쓴 글이 내 화면에 늦게
    // 뜨는 건 네트워크가 아니라 설계 문제다.
    //
    // 실패하면 되돌린다(아래). 티켓 낙관 차감과 같은 원칙이다.
    final localId = '$_localPrefix${now.microsecondsSinceEpoch}';
    // 내 대표 뱃지 — 서버 트리거가 찍을 값과 **같은 규칙**(bestEventBadge)이다.
    final badge = bestEventBadge(save.eventBadges);
    setState(() {
      _sending = true;
      _messages.add(
        ChatMessage(
          id: localId,
          userId: ref.read(authServiceProvider).userId ?? '',
          nickname: save.nickname,
          body: body,
          createdAt: now,
          badge: badge,
          guildId: _sendGuildId,
          avatar: save.avatar,
        ),
      );
    });
    _input.clear();
    _jumpToBottom();

    final ok = await ref
        .read(chatServiceProvider)
        .send(
          nickname: save.nickname,
          body: body,
          badge: badge,
          guildId: _sendGuildId,
          avatar: save.avatar,
        );
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (!ok) {
        // 못 보냈으면 화면에서도 지운다 — 보낸 줄 알고 넘어가면 안 된다.
        _messages.removeWhere((x) => x.id == localId);
      }
    });
    if (ok) {
      _lastSentAt = now;
    } else {
      _input.text = body; // 다시 쓰게 하지 않는다
      _snack(l.chatSendFailed);
    }
  }

  void _snack(String msg) {
    showCenterToast(context, msg);
  }

  /// 메시지 신고 — 확인 후 서버에 기록.
  Future<void> _report(ChatMessage m, AppLocalizations l) async {
    final ok = await showGameDialog<bool>(
      context,
      title: l.chatReportTitle,
      icon: Icons.flag_rounded,
      content: Text(
        l.chatReportBody,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xD9FFFFFF),
          fontSize: 13,
          height: 1.4,
        ),
      ),
      actions: [
        gameDialogButton(
          l.actionClose,
          () => Navigator.pop(context, false),
          primary: false,
        ),
        gameDialogButton(
          l.chatReport,
          () => Navigator.pop(context, true),
          color: const Color(0xFF9A3434),
        ),
      ],
    );
    if (ok != true || !mounted) return;
    await ref
        .read(chatServiceProvider)
        .report(messageId: m.id, reason: 'user_report');
    if (!mounted) return;
    _snack(l.chatReported);
  }

  /// 내가 쓴 메시지 삭제 — 확인 후 서버에서 제거(UGC 정책, Apple 1.2).
  Future<void> _deleteMine(ChatMessage m, AppLocalizations l) async {
    final ok = await showGameDialog<bool>(
      context,
      title: l.chatDeleteTitle,
      icon: Icons.delete_outline_rounded,
      content: Text(
        l.chatDeleteBody,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xD9FFFFFF),
          fontSize: 13,
          height: 1.4,
        ),
      ),
      actions: [
        gameDialogButton(
          l.actionClose,
          () => Navigator.pop(context, false),
          primary: false,
        ),
        gameDialogButton(
          l.chatDelete,
          () => Navigator.pop(context, true),
          color: const Color(0xFF9A3434),
        ),
      ],
    );
    if (ok != true || !mounted) return;
    final done = await ref.read(chatServiceProvider).deleteOwn(messageId: m.id);
    if (!mounted) return;
    if (done) setState(() => _messages.removeWhere((x) => x.id == m.id));
    _snack(done ? l.chatDeleted : l.chatUnavailable);
  }

  /// 사용자 차단 — 확인 후 로컬 목록에 추가(즉시 반영).
  Future<void> _block(ChatMessage m, AppLocalizations l) async {
    final ok = await showGameDialog<bool>(
      context,
      title: l.chatBlockTitle(
        _rules.maskNickname(m.nickname, fallback: l.nicknameFallback),
      ),
      icon: Icons.block_rounded,
      content: Text(
        l.chatBlockBody,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xD9FFFFFF),
          fontSize: 13,
          height: 1.4,
        ),
      ),
      actions: [
        gameDialogButton(
          l.actionClose,
          () => Navigator.pop(context, false),
          primary: false,
        ),
        gameDialogButton(
          l.chatBlock,
          () => Navigator.pop(context, true),
          color: const Color(0xFF9A3434),
        ),
      ],
    );
    if (ok != true || !mounted) return;
    await ref
        .read(saveControllerProvider.notifier)
        .setUserBlocked(m.userId, true);
    if (!mounted) return;
    _snack(
      l.chatBlockedUser(
        _rules.maskNickname(m.nickname, fallback: l.nicknameFallback),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final save = ref.watch(saveControllerProvider).requireValue;
    final available = ref.watch(chatServiceProvider).available;
    final myId = ref.watch(chatMyUserIdProvider);

    final body = Column(
      children: [
        // 대화 규칙 안내 — UGC 정책상 이용 기준을 명시해 둔다.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          color: const Color(0x22EBA52F),
          child: Text(
            l.chatRules,
            style: const TextStyle(
              color: Color(0xCCEBD24A),
              fontSize: 11.5,
              height: 1.35,
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : !available
              ? Center(
                  child: Text(
                    l.chatUnavailable,
                    style: const TextStyle(color: Color(0x99FFFFFF)),
                  ),
                )
              : _messages.isEmpty
              ? Center(
                  child: Text(
                    widget.guildOnly ? l.guildChatEmpty : l.chatEmpty,
                    style: const TextStyle(color: Color(0x99FFFFFF)),
                  ),
                )
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  itemCount: _messages.length,
                  itemBuilder: (context, i) =>
                      _bubble(_messages[i], save, myId, l),
                ),
        ),
        _composer(l, available),
      ],
    );
    return body;
  }

  Widget _bubble(
    ChatMessage m,
    SaveGame save,
    String? myId,
    AppLocalizations l,
  ) {
    // 운영자 메시지는 **차단으로 가려지지 않는다** — 점검·보상 안내를 못 보면
    // 그 피해는 유저가 본다. is_admin 은 서버만 세울 수 있어 우회도 안 된다.
    if (!m.isAdmin && save.isBlocked(m.userId)) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Text(
          l.chatBlockedMessage,
          style: const TextStyle(
            color: Color(0x55FFFFFF),
            fontSize: 11.5,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
    final mine = myId != null && m.userId == myId;
    // 길드 미션 도움 요청 카드(서버가 `#help:<id>` 로 넣는다) — 말풍선 대신 "도와주기" 버튼.
    // 길드 글에만 들어간다(전체 탭에서도 내 길드 글이면 카드). 누가 손으로 같은 글을 써도 서버가 없는 미션으로 거절한다.
    if (m.guildId != null && m.body.startsWith(_helpPrefix)) {
      return _helpCard(m, mine, l);
    }
    // 보여줄 때도 필터를 건다 — 목록 갱신 전에 서버에 들어간 과거 메시지 대비.
    final body = _rules.mask(m.body);

    // 프로필 그림(2026-10-10 사장님): 남의 글 = [그림][윗줄 아이디 · 아랫줄 글], 내 글 = [윗줄 아이디 · 아랫줄 글][그림].
    // 내 글은 서버가 찍은 값이 아니라 **지금 고른 그림**을 쓴다(바꾸자마자 보이게). 운영자 글은 그림 없이.
    final avatar = m.isAdmin
        ? null
        : AvatarCircle(
            id: mine ? (save.avatar ?? m.avatar) : m.avatar,
            // 윗줄 아이디(⋯ 버튼 포함 약 28) + 아랫줄 한 줄 글(약 34)을 합친 높이 — 두 줄을 감싸는 크기(사장님 요청).
            size: 60,
          );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!mine && avatar != null) ...[avatar, const SizedBox(width: 8)],
          Flexible(
            child: Column(
              crossAxisAlignment: mine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (m.isAdmin) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3F7FB5),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          l.chatAdminBadge,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    // 전체 탭에 섞여 보이는 내 길드 글 — [길드] 표시로 가른다(2026-10-05).
                    if (!widget.guildOnly && m.guildId != null) ...[
                      Container(
                        key: const ValueKey('chatGuildTag'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x337FBF5A),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: const Color(0x997FBF5A)),
                        ),
                        child: Text(
                          l.chatTabGuild,
                          style: const TextStyle(
                            color: Color(0xFF9CE37D),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      // 이미 등록된 부적절한 닉네임은 표시 단계에서 대체한다.
                      // 운영자 이름은 예약어라 일반 유저는 쓸 수 없다(그래서 안 가린다).
                      _rules.maskNickname(
                        m.nickname,
                        fallback: l.nicknameFallback,
                        isAdmin: m.isAdmin,
                      ),
                      style: TextStyle(
                        color: m.isAdmin
                            ? const Color(0xFF9FD3F5)
                            : (mine ? kHoney : const Color(0x99FFFFFF)),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    // 대회 뱃지(2026-09-15) — 자랑거리는 남이 봐야 자랑거리다.
                    // 순위표를 열지 않는 사람도 채팅에서는 본다.
                    if (!m.isAdmin) EventBadgeChip(id: m.badge, size: 9.5),
                    // 신고·차단(남의 글)·삭제(내 글)는 이 버튼으로(2026-10-03). 말풍선 꾹 누르기는
                    // **글자 선택**에 내줬다 — 안드로이드는 거기서 기기 번역이 뜬다.
                    // 운영자 메시지는 신고·차단 대상이 아니다(공지 성격).
                    if (!m.isAdmin)
                      InkWell(
                        onTap: () => mine ? _deleteMine(m, l) : _actions(m, l),
                        borderRadius: BorderRadius.circular(10),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          child: Icon(
                            Icons.more_horiz_rounded,
                            size: 16,
                            color: Color(0x99FFFFFF),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Container(
                  constraints: const BoxConstraints(maxWidth: 280),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: m.isAdmin
                        ? const Color(0x333F7FB5)
                        : (mine
                              ? const Color(0x33EBA52F)
                              : const Color(0x22FFFFFF)),
                    borderRadius: BorderRadius.circular(12),
                    border: m.isAdmin
                        ? Border.all(color: const Color(0x883F7FB5))
                        : null,
                  ),
                  // 선택 가능한 글자 — 꾹 누르면 복사, 안드로이드는 설치된 번역 앱(구글 번역 등)의
                  // "번역"이 같이 뜬다(Flutter 가 시스템 텍스트 처리 메뉴를 붙인다). 채팅 번역 서버를
                  // 따로 두지 않는다(2026-10-03 사장님 — 비용).
                  child: SelectableText(
                    body,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (mine && avatar != null) ...[const SizedBox(width: 8), avatar],
        ],
      ),
    );
  }

  static const _helpPrefix = '#help:';

  Widget _helpCard(ChatMessage m, bool mine, AppLocalizations l) {
    final name = _rules.maskNickname(m.nickname, fallback: l.nicknameFallback);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0x22EBC24A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x88EBC24A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.flag_rounded, color: kHoney, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              mine ? l.guildMissionChatMine : l.guildMissionChatAsk(name),
              style: const TextStyle(color: Colors.white, fontSize: 12.5),
            ),
          ),
          if (!mine)
            TextButton(
              onPressed: () => guildHelpMission(
                context,
                ref,
                m.body.substring(_helpPrefix.length),
              ),
              style: TextButton.styleFrom(foregroundColor: kHoney),
              child: Text(l.guildMissionHelp),
            ),
        ],
      ),
    );
  }

  /// 신고/차단 선택 시트(길게 누르기).
  Future<void> _actions(ChatMessage m, AppLocalizations l) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xF2141F0E),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.flag_rounded, color: Color(0xFFE79A9A)),
              title: Text(
                l.chatReport,
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _report(m, l);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.block_rounded,
                color: Color(0xFFE79A9A),
              ),
              title: Text(
                l.chatBlock,
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _block(m, l);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _composer(AppLocalizations l, bool available) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              enabled: available && !_sending,
              maxLength: _rules.maxLength,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: l.chatHint,
                hintStyle: const TextStyle(color: Color(0x55FFFFFF)),
                counterText: '',
                filled: true,
                fillColor: const Color(0x22000000),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: available && !_sending ? _send : null,
            style: FilledButton.styleFrom(
              backgroundColor: kHoney,
              foregroundColor: kHoneyInk,
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(14),
            ),
            child: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded, size: 20),
          ),
        ],
      ),
    ),
  );
}
