import 'dart:async';

import 'package:core_models/core_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/chat_service.dart';
import '../../domain/providers.dart';
import '../../domain/save_controller.dart';
import 'package:core_save/core_save.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/game_dialog.dart';

/// 전체 채팅 화면.
///
/// **사용자 제작 콘텐츠(UGC)** 이므로 구글 플레이 정책상 아래가 필수다:
/// - 금칙어 필터 (보낼 때 + 보여줄 때 양쪽)
/// - 메시지 신고
/// - 사용자 차단
/// - 도배 방지
/// 넷 다 이 화면에 있다. 하나라도 빼면 심사에서 거부될 수 있다.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <ChatMessage>[];
  StreamSubscription<ChatMessage>? _sub;

  /// 마지막 전송 시각 — 도배 방지(클라이언트 1차 방어).
  DateTime? _lastSentAt;
  bool _loading = true;
  bool _sending = false;

  ChatRules get _rules =>
      ref.read(gameDataProvider).value?.chatRules ?? const ChatRules();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final svc = ref.read(chatServiceProvider);
    final list = await svc.recent(limit: _rules.historyLimit);
    if (!mounted) return;
    setState(() {
      _messages
        ..clear()
        ..addAll(list);
      _loading = false;
    });
    _jumpToBottom();
    _sub = svc.subscribe().listen((m) {
      if (!mounted) return;
      setState(() {
        _messages.add(m);
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
    _sub?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

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

    setState(() => _sending = true);
    final save = ref.read(saveControllerProvider).requireValue;
    final ok = await ref
        .read(chatServiceProvider)
        .send(nickname: save.nickname, body: body);
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) {
      _lastSentAt = now;
      _input.clear();
    } else {
      _snack(l.chatSendFailed);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
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
    final done = await ref
        .read(chatServiceProvider)
        .deleteOwn(messageId: m.id);
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

    return Scaffold(
      appBar: AppBar(title: Text(l.chatTitle)),
      body: Column(
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
                      l.chatEmpty,
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
      ),
    );
  }

  Widget _bubble(
    ChatMessage m,
    SaveGame save,
    String? myId,
    AppLocalizations l,
  ) {
    // 차단한 사용자의 메시지는 내용을 보여주지 않는다.
    if (save.isBlocked(m.userId)) {
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
    // 보여줄 때도 필터를 건다 — 목록 갱신 전에 서버에 들어간 과거 메시지 대비.
    final body = _rules.mask(m.body);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(
            // 이미 등록된 부적절한 닉네임은 표시 단계에서 대체한다.
            _rules.maskNickname(m.nickname, fallback: l.nicknameFallback),
            style: TextStyle(
              color: mine ? const Color(0xFFEBA52F) : const Color(0x99FFFFFF),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          GestureDetector(
            // 내 메시지 길게누르기=삭제, 남의 메시지=신고/차단 메뉴.
            onLongPress: () => mine ? _deleteMine(m, l) : _actions(m, l),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 280),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: mine ? const Color(0x33EBA52F) : const Color(0x22FFFFFF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                body,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  height: 1.35,
                ),
              ),
            ),
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
              backgroundColor: const Color(0xFFEBA52F),
              foregroundColor: const Color(0xFF1A1200),
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
