import 'dart:async';

import 'package:core_models/core_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 전체 채팅 서비스 계약. 다른 서비스들과 같은 "인터페이스 + 구현 교체" 패턴.
///
/// ⚠️ 채팅은 **사용자 제작 콘텐츠(UGC)** 다. 구글 플레이 정책상
/// 신고·차단 수단이 반드시 있어야 하므로 [report] 를 계약에 포함한다.
/// (차단은 기기 로컬 목록으로 처리 — `SaveGame.blockedUserIds`)
abstract interface class ChatService {
  /// 서버에 연결돼 채팅을 쓸 수 있는지.
  bool get available;

  /// 최근 메시지를 시간순(오래된 것 → 최신)으로 가져온다.
  Future<List<ChatMessage>> recent({int limit = 50});

  /// 새 메시지 실시간 스트림.
  Stream<ChatMessage> subscribe();

  /// 메시지 전송. 성공 시 true.
  /// **금칙어·길이·도배 검사는 호출 전에 [ChatRules.check] 로 끝내야 한다.**
  Future<bool> send({required String nickname, required String body});

  /// 메시지 신고(UGC 정책 필수). 같은 메시지를 두 번 신고해도 오류가 아니다.
  Future<bool> report({required String messageId, required String reason});

  /// **본인이 쓴 메시지 삭제**(UGC 정책 — Apple 1.2). 성공 시 true.
  /// 서버 RLS 로 본인 메시지만 지워진다(남의 것은 지워지지 않음).
  Future<bool> deleteOwn({required String messageId});

  void dispose();
}

/// 백엔드 미연결 — 채팅 사용 불가.
class NoChatService implements ChatService {
  const NoChatService();

  @override
  bool get available => false;
  @override
  Future<List<ChatMessage>> recent({int limit = 50}) async => const [];
  @override
  Stream<ChatMessage> subscribe() => const Stream.empty();
  @override
  Future<bool> send({required String nickname, required String body}) async =>
      false;
  @override
  Future<bool> report({
    required String messageId,
    required String reason,
  }) async => false;
  @override
  Future<bool> deleteOwn({required String messageId}) async => false;
  @override
  void dispose() {}
}

/// Supabase `chat_messages` 기반 구현.
///
/// 스키마·RLS·도배 방지 트리거는 `docs/backend_supabase.md` §8 참조.
/// 서버에도 전송 간격 제한을 두는 이유: 클라이언트 검사만으로는
/// 앱을 조작한 사용자를 막지 못한다.
class SupabaseChatService implements ChatService {
  SupabaseChatService(this._client);

  final SupabaseClient _client;
  RealtimeChannel? _channel;

  String? get _uid => _client.auth.currentUser?.id;

  /// 내 계정 id(표시용).
  String? get myUserId => _uid;

  @override
  bool get available => _uid != null;

  @override
  Future<List<ChatMessage>> recent({int limit = 50}) async {
    try {
      final rows = await _client
          .from('chat_messages')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);
      // 최신순으로 받아 화면 표시용(오래된 것 → 최신)으로 뒤집는다.
      return [
        for (final r in (rows as List).reversed)
          ChatMessage.fromJson(r as Map<String, dynamic>),
      ];
    } catch (e) {
      debugPrint('[chat] recent 실패: $e');
      return const [];
    }
  }

  /// 구독자 전체가 나눠 쓰는 브로드캐스트 스트림.
  StreamController<ChatMessage>? _events;

  /// ⚠️ **구독자가 둘 이상이다** — 홈 상단 채팅 바와 전체 채팅 화면.
  ///
  /// 예전엔 호출마다 같은 토픽(`public:chat_messages`)으로 채널을 새로 만들고
  /// `_channel` 을 덮어썼다. 그러면 나중에 붙은 쪽이 먼저 붙은 쪽을 밀어내
  /// **홈 채팅 바가 조용히 갱신을 멈췄고**, 채팅 화면을 나갈 때 채널을 지워
  /// 남은 구독자까지 끊겼다. 채널은 하나만 두고 스트림을 공유한다.
  @override
  Stream<ChatMessage> subscribe() {
    final controller = _events ??= StreamController<ChatMessage>.broadcast();
    _channel ??= _client
        .channel('public:chat_messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          callback: (payload) {
            try {
              controller.add(ChatMessage.fromJson(payload.newRecord));
            } catch (e) {
              debugPrint('[chat] payload 파싱 실패: $e');
            }
          },
        )
        .subscribe();
    // 개별 구독자가 떠나도 채널은 유지한다 — 정리는 [dispose] 한 곳에서만.
    return controller.stream;
  }

  @override
  Future<bool> send({required String nickname, required String body}) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      await _client.from('chat_messages').insert({
        'user_id': uid,
        'nickname': nickname,
        'body': body,
      });
      // ⚠️ **넣자마자 스스로 방송한다.** 예전에는 Postgres → realtime →
      // 앱 왕복이 돌아올 때까지 기다렸고, 그 시간이 그대로 "내가 쓴 글이 늦게
      // 뜬다"로 보였다(2026-08-30 지적). 홈 상단 채팅 바도 같은 스트림을
      // 보므로 여기서 한 번 방송하면 두 화면이 함께 즉시 갱신된다.
      //
      // 실제 브로드캐스트가 뒤따라 오면 같은 내용이 한 번 더 들어온다 —
      // 받는 쪽이 **내가 먼저 띄운 것과 같은 글이면 대체**한다(chat_screen).
      _events?.add(
        ChatMessage(
          id: 'echo:${DateTime.now().microsecondsSinceEpoch}',
          userId: uid,
          nickname: nickname,
          body: body,
          createdAt: DateTime.now().toUtc(),
        ),
      );
      return true;
    } catch (e) {
      // 서버 도배 제한(트리거)에 걸리면 여기로 온다.
      debugPrint('[chat] send 실패: $e');
      return false;
    }
  }

  @override
  Future<bool> report({
    required String messageId,
    required String reason,
  }) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      await _client.from('chat_reports').upsert({
        'message_id': int.tryParse(messageId) ?? 0,
        'reporter_id': uid,
        'reason': reason,
      }, onConflict: 'message_id,reporter_id');
      return true;
    } catch (e) {
      debugPrint('[chat] report 실패: $e');
      return false;
    }
  }

  @override
  Future<bool> deleteOwn({required String messageId}) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      // RLS(chat_delete)로 본인 메시지만 삭제된다. user_id 조건도 명시(방어).
      await _client
          .from('chat_messages')
          .delete()
          .eq('id', int.tryParse(messageId) ?? 0)
          .eq('user_id', uid);
      return true;
    } catch (e) {
      debugPrint('[chat] delete 실패: $e');
      return false;
    }
  }

  @override
  void dispose() {
    final ch = _channel;
    _channel = null;
    if (ch != null) _client.removeChannel(ch);
    unawaited(_events?.close());
    _events = null;
  }
}

/// 내 계정 id — 내 말풍선을 오른쪽에 붙이는 용도.
/// 미연결이면 null(모든 메시지가 남의 것으로 보인다).
final chatMyUserIdProvider = Provider<String?>((ref) {
  final svc = ref.watch(chatServiceProvider);
  return svc is SupabaseChatService ? svc.myUserId : null;
});

/// 교체 가능한 채팅 서비스. 기본은 미연결.
final chatServiceProvider = Provider<ChatService>((ref) {
  const s = NoChatService();
  ref.onDispose(s.dispose);
  return s;
});

/// 홈 상단 채팅 바에 보여줄 **가장 최근 메시지 1건**.
///
/// 처음엔 최근 목록에서 마지막 하나를 집고, 그 뒤로는 실시간 구독으로 갱신한다.
/// 채팅이 미연결이거나 아직 아무 말도 없으면 null → 바는 안내 문구를 보여준다.
final chatLatestProvider = StreamProvider<ChatMessage?>((ref) async* {
  final svc = ref.watch(chatServiceProvider);
  if (!svc.available) {
    yield null;
    return;
  }
  ChatMessage? latest;
  try {
    final recent = await svc.recent(limit: 1);
    if (recent.isNotEmpty) latest = recent.last;
  } catch (_) {
    // 조회 실패는 조용히 넘긴다 — 홈 화면이 채팅 때문에 깨지면 안 된다.
  }
  yield latest;
  await for (final m in svc.subscribe()) {
    yield latest = m;
  }
});
