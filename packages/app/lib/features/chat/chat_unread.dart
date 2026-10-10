import 'dart:async';

import 'package:core_models/core_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/auth_service.dart';
import '../../domain/chat_service.dart';
import '../../domain/save_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/colors.dart';

/// 안 읽은 채팅 표시(2026-10-10 사장님 — 채팅이 올라와도 화면에 아무 표시가 없어 참여할 계기가 없었다).
///
/// 마지막으로 본 글의 **서버 시각**을 기기에 적어 두고(세이브가 아니라 기기 설정 — 진행·보상과 무관),
/// 그보다 늦은 **남의 글**이 오면 홈 채팅 바에 NEW 를 붙이고 테두리를 반짝인다. 기기 시계가 아니라 글의
/// `createdAt`(서버 시각)끼리 비교해 시계가 틀린 기기에서도 맞다.
const _kSeenKey = 'chat.seenAt';

typedef ChatSeen = ({DateTime? at, bool loaded});

class ChatSeenNotifier extends Notifier<ChatSeen> {
  @override
  ChatSeen build() {
    unawaited(_load());
    return (at: null, loaded: false);
  }

  Future<void> _load() async {
    DateTime? saved;
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_kSeenKey);
      saved = raw == null ? null : DateTime.tryParse(raw)?.toUtc();
    } catch (_) {
      // 못 읽으면 처음 보는 것으로 — NEW 가 한 번 뜰 뿐이다.
    }
    final cur = state.at;
    final at = cur == null
        ? saved
        : (saved != null && saved.isAfter(cur) ? saved : cur);
    state = (at: at, loaded: true);
  }

  /// [at](글의 서버 시각)까지 봤다. 뒤로는 가지 않는다.
  void markSeen(DateTime at) {
    final u = at.toUtc();
    final cur = state.at;
    if (cur != null && !u.isAfter(cur)) return;
    state = (at: u, loaded: state.loaded);
    unawaited(_save(u));
  }

  Future<void> _save(DateTime at) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_kSeenKey, at.toIso8601String());
    } catch (_) {}
  }
}

final chatSeenProvider = NotifierProvider<ChatSeenNotifier, ChatSeen>(
  ChatSeenNotifier.new,
);

/// 안 읽은 남의 글이 있나 — 기기 기록을 다 읽기 전에는 띄우지 않는다(켤 때마다 NEW 가 번쩍이지 않게).
bool chatUnread(
  ChatMessage? last,
  ChatSeen seen,
  String? myId, {
  bool Function(String userId)? blocked,
}) {
  if (last == null || !seen.loaded) return false;
  if (myId != null && last.userId == myId) return false;
  // 내 임시 글(기기 시각)·차단한 사람 글은 알리지 않는다(2026-10-10 점검 — 차단한 글을 NEW 로 키우지 않게).
  if (last.id.startsWith('echo:') || last.id.startsWith('local:')) return false;
  if (blocked != null && blocked(last.userId)) return false;
  final at = seen.at;
  return at == null || last.createdAt.isAfter(at);
}

/// 지금 홈 채팅 바가 보여 줄 "안 읽음" 여부.
final chatHasUnreadProvider = Provider<bool>((ref) {
  final last = ref.watch(chatLatestProvider).value;
  final seen = ref.watch(chatSeenProvider);
  final myId = ref.watch(authServiceProvider).userId;
  final blocked = ref.watch(
    saveControllerProvider.select((s) => s.value?.blockedUserIds),
  );
  return chatUnread(last, seen, myId, blocked: blocked?.contains);
});

/// 채팅 바 오른쪽의 빨간 NEW.
class ChatNewPill extends ConsumerWidget {
  const ChatNewPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(chatHasUnreadProvider)) return const SizedBox.shrink();
    return Container(
      key: const ValueKey('chatNewPill'),
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFF4D4D),
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [BoxShadow(color: Color(0x88FF4D4D), blurRadius: 6)],
      ),
      child: Text(
        AppLocalizations.of(context).chatNewBadge,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// 채팅 바 틀 — 안 읽은 글이 있으면 꿀빛 테두리, 새 글이 막 들어오면 세 번 반짝인다.
class ChatBarFrame extends ConsumerStatefulWidget {
  const ChatBarFrame({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ChatBarFrame> createState() => _ChatBarFrameState();
}

class _ChatBarFrameState extends ConsumerState<ChatBarFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  int _flashes = 0;

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        _c.reverse();
      } else if (s == AnimationStatus.dismissed && _flashes > 0) {
        _flashes--;
        _c.forward();
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 새 글(id 가 바뀜)이 안 읽음으로 들어오면 반짝인다.
    ref.listen(chatLatestProvider, (prev, next) {
      final a = prev?.value;
      final b = next.value;
      if (b == null || a?.id == b.id) return;
      final blocked = ref.read(saveControllerProvider).value?.blockedUserIds;
      if (!chatUnread(
        b,
        ref.read(chatSeenProvider),
        ref.read(authServiceProvider).userId,
        blocked: blocked?.contains,
      )) {
        return;
      }
      _flashes = 2;
      _c.forward(from: 0);
    });
    final unread = ref.watch(chatHasUnreadProvider);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Color.lerp(
              const Color(0x33000000),
              kHoney.withValues(alpha: 0.28),
              t,
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: unread
                  ? kHoney.withValues(alpha: 0.75 + 0.25 * t)
                  : const Color(0x22FFFFFF),
              width: unread ? 1.4 : 1,
            ),
            boxShadow: t > 0
                ? [
                    BoxShadow(
                      color: kHoney.withValues(alpha: 0.55 * t),
                      blurRadius: 10 * t,
                    ),
                  ]
                : null,
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
