import 'package:app/features/chat/chat_unread.dart';
import 'package:core_models/core_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 안 읽은 채팅 표시(2026-10-10 사장님) — 남의 새 글이면 NEW, 내 글·이미 본 글·기록을 읽기 전이면 없음.
ChatMessage _msg(String user, DateTime at) => ChatMessage(
  id: '${user}_${at.millisecondsSinceEpoch}',
  userId: user,
  nickname: user,
  body: 'hi',
  createdAt: at,
);

void main() {
  final t0 = DateTime.utc(2026, 10, 10, 12);

  test('판정 — 남의 새 글만 · 기록을 읽기 전엔 띄우지 않는다', () {
    const loadedNone = (at: null, loaded: true);
    final seenT0 = (at: t0, loaded: true);
    expect(chatUnread(null, loadedNone, 'me'), isFalse);
    expect(chatUnread(_msg('a', t0), (at: null, loaded: false), 'me'), isFalse);
    expect(chatUnread(_msg('a', t0), loadedNone, 'me'), isTrue);
    expect(
      chatUnread(_msg('me', t0.add(const Duration(minutes: 1))), seenT0, 'me'),
      isFalse,
    );
    expect(chatUnread(_msg('a', t0), seenT0, 'me'), isFalse);
    expect(
      chatUnread(_msg('a', t0.add(const Duration(seconds: 1))), seenT0, 'me'),
      isTrue,
    );
  });

  test('읽음 기록은 뒤로 가지 않고 기기에 남는다', () async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(chatSeenProvider);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(chatSeenProvider).loaded, isTrue);
    c.read(chatSeenProvider.notifier).markSeen(t0);
    c
        .read(chatSeenProvider.notifier)
        .markSeen(t0.subtract(const Duration(hours: 1)));
    expect(c.read(chatSeenProvider).at, t0);
    await Future<void>.delayed(Duration.zero);
    final p = await SharedPreferences.getInstance();
    expect(p.getString('chat.seenAt'), t0.toIso8601String());
  });
}
